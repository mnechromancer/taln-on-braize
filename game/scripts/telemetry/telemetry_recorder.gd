class_name Telemetry
extends Node
## Cycle telemetry (spec §13 step 7), autoloaded as TelemetryRecorder. Each
## cycle writes JSON Lines to user://telemetry/cycle_<timestamp>_<seed>.jsonl:
## one object per line, "t" = seconds of play into the cycle, "ev" = kind.
##
## Events: kill (with rewarded), income (per second, summed by source and
## stamped with the station; flushed before station, lull and wave changes),
## spend, level, fill (choice, fired and committed catalysts), return and
## reform, strain (on change), notice, side_effect, wave, station, lull; a
## snapshot every SNAPSHOT_INTERVAL seconds (alive, kill rate, held
## Investiture, Health, Agony, Strain); a summary line at cycle end, or an
## "abandoned" line if the station goes away first. The cycle_begin line
## logs the numbers the report's C(n) prediction and pacing need. Reach it
## with Telemetry.recorder().

const SCHEMA := 1
const DIR := "user://telemetry"
## Seconds of play between snapshots, and between income lines.
const SNAPSHOT_INTERVAL := 10.0
const INCOME_INTERVAL := 1.0

## False to record nothing. Off by default inside check scripts
## (tools/checks/), so they don't fill the folder; a check can turn it on.
var enabled: bool = true
## Where cycle files go (a check points it elsewhere).
var directory: String = DIR
var path: String = ""
var _file: FileAccess
var _station: GrayboxStation
var _income: Dictionary[StringName, float] = {}
var _income_left: float = INCOME_INTERVAL
var _snapshot_left: float = SNAPSHOT_INTERVAL
var _kills_at_snapshot: int = 0
var _spent: Dictionary[StringName, float] = {}
var _connections: Array[Array] = []
var _last_strain: float = -1.0
var _snapshot_t: float = 0.0
var _last_t: float = 0.0
var _finished: bool = false
## Game seconds Taln spent airborne this cycle (P2-12).
var _airtime: float = 0.0
## Structures (P2-11): raised and lost by kind, and what they struck.
var _structures_raised: Dictionary[StringName, int] = {}
var _structures_lost: Dictionary[StringName, int] = {}
var _structures_lost_to_swarm: int = 0
var _structure_damage: Dictionary[StringName, float] = {}
var _structure_hits: Dictionary[StringName, int] = {}
## The disease's kills (P2-15) and the infected count's peak.
var _blight_kills: int = 0
var _infected_peak: int = 0


static func recorder() -> Telemetry:
	return (Engine.get_main_loop() as SceneTree).root.get_node(^"TelemetryRecorder") as Telemetry


func _ready() -> void:
	var main: Script = (Engine.get_main_loop() as Object).get_script()
	if main and main.resource_path.begins_with("res://tools/checks/"):
		enabled = false
	var cycle: Cycle = Cycle.director()
	cycle.cycle_began.connect(_on_cycle_began)
	cycle.cycle_ended.connect(_on_cycle_ended)
	cycle.station_began.connect(func(i: int) -> void:
		_flush_income()
		_write({"ev": "station", "index": i}))
	cycle.lull_began.connect(func(i: int) -> void:
		_flush_income()
		_write({"ev": "lull", "after": i}))


func _process(delta: float) -> void:
	if _file == null or get_tree().paused or not is_instance_valid(_station):
		return
	# Game-time intervals (the windows' slow-down stretches them in real time).
	if (_station.get_node("Taln") as Taln).airborne:
		_airtime += delta
	_income_left -= delta
	if _income_left <= 0.0:
		_income_left += INCOME_INTERVAL
		_flush_income()
	_snapshot_left -= delta
	if _snapshot_left <= 0.0:
		_snapshot_left += SNAPSHOT_INTERVAL
		_snapshot()


func _on_cycle_began(cycle_seed: int) -> void:
	_close()
	if not enabled:
		return
	_station = Cycle.director().station
	DirAccess.make_dir_recursive_absolute(directory)
	var stamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "").replace(" ", "_").replace("-", "")
	path = "%s/cycle_%s_%d.jsonl" % [directory, stamp, cycle_seed]
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("Telemetry can't write %s" % path)
		return
	_income.clear()
	_spent.clear()
	_last_strain = -1.0
	_finished = false
	_last_t = 0.0
	_income_left = INCOME_INTERVAL
	_snapshot_left = SNAPSHOT_INTERVAL
	_kills_at_snapshot = 0
	_airtime = 0.0
	_structures_raised.clear()
	_structures_lost.clear()
	_structures_lost_to_swarm = 0
	_structure_damage.clear()
	_structure_hits.clear()
	_blight_kills = 0
	_infected_peak = 0
	var spawn: SpawnTuning = (_station.get_node("SpawnDirector") as SpawnDirector).tuning
	var leveling: InvestitureTuning = (_station.get_node("Taln") as Taln).leveling.tuning
	_write({"ev": "cycle_begin", "schema": SCHEMA, "seed": cycle_seed, "wave_length": spawn.wave_length,
			"waves": spawn.waves, "stations": Cycle.director().tuning.stations,
			"lull_seconds": Cycle.director().tuning.lull_seconds, "level_cost_base": leveling.level_cost_base,
			"level_cost_growth": leveling.level_cost_growth, "map": _station.scene_file_path.get_file().get_basename()})
	_snapshot_t = 0.0
	_hook()
	# The slice's first region was entered before the cycle began.
	if _station is BraizeSlice and (_station as BraizeSlice).current:
		_write_region((_station as BraizeSlice).current, &"region")
	# A station freed mid-cycle (a check, a bot, quitting) closes its file.
	_station.tree_exiting.connect(_close, CONNECT_ONE_SHOT)
	print("Telemetry: %s" % ProjectSettings.globalize_path(path))


func _on_cycle_ended(outcome: Cycle.Outcome, summary: Dictionary) -> void:
	if _file == null:
		return
	_flush_income()
	_snapshot()
	var taln: Taln = _station.get_node("Taln")
	var out: Dictionary = summary.duplicate()
	out["ev"] = "summary"
	out["outcome"] = Cycle.Outcome.keys()[outcome]
	out["income"] = _as_strings(taln.investiture.income_by_source)
	out["spent"] = _as_strings(taln.investiture.spent_by_reason)
	out["levels"] = taln.leveling.levels_taken
	out["agony"] = _as_strings(taln.agony.gained_by_source)
	out["airtime"] = snappedf(_airtime, 0.01)
	var awareness: Awareness = _station.get_node_or_null("Awareness")
	if awareness:
		out["seen_time"] = snappedf(awareness.seen_time, 0.01)
		out["unseen_time"] = snappedf(awareness.unseen_time, 0.01)
	if _station is BraizeSlice:
		out["commanders_killed"] = (_station as BraizeSlice).commanders_killed
	out["structures_raised"] = _as_ints(_structures_raised)
	out["structures_lost"] = _as_ints(_structures_lost)
	out["structures_lost_to_swarm"] = _structures_lost_to_swarm
	out["structure_damage"] = _as_strings(_structure_damage)
	out["structure_hits"] = _as_ints(_structure_hits)
	var boons: Boons = _station.get_node_or_null("Boons")
	if boons:
		out["boons"] = boons.owned.map(func(b: BoonDef) -> String: return String(b.id))
	out["blight_kills"] = _blight_kills
	out["infected_peak"] = _infected_peak
	_write(out)
	_finished = true
	_close()


func _hook() -> void:
	var taln: Taln = _station.get_node("Taln")
	var swarm: SwarmServer = _station.get_node("SwarmServer")
	var spawner: SpawnDirector = _station.get_node("SpawnDirector")
	var catalysis: Catalysis = _station.get_node("Catalysis")
	var sequence: ReturnSequence = _station.get_node("ReturnSequence")
	_connect(swarm.enemy_died, func(id: StringName, _at: Vector3, rewarded: bool) -> void:
		_write({"ev": "kill", "type": id, "rewarded": rewarded}))
	_connect(taln.investiture.gained, func(amount: float, source: StringName) -> void:
		_income[source] = _income.get(source, 0.0) + amount)
	_connect(taln.investiture.spent, func(amount: float, reason: StringName) -> void:
		_write({"ev": "spend", "amount": snappedf(amount, 0.01), "reason": reason}))
	_connect(taln.leveling.leveled, func(n: int, skill: SkillDef, cost: float) -> void:
		_write({"ev": "level", "n": n, "choice": skill.id if skill else &"consolidate", "cost": cost,
				"station": _station.station_index()}))
	_connect(catalysis.resolved, func(choice: StringName, fired: Array[SkillDef], held: Array[SkillDef]) -> void:
		_write({"ev": "fill", "choice": choice, "fired": fired.map(func(s: SkillDef) -> StringName: return s.id),
				"committed": held.map(func(s: SkillDef) -> StringName: return s.id), "station": _station.station_index()}))
	_connect(sequence.began, func(closing: bool) -> void:
		_write({"ev": "return", "n": Cycle.director().returns, "closing": closing, "station": _station.station_index()}))
	_connect(sequence.reformed, func(_at: Vector3) -> void: _write({"ev": "reform"}))
	_connect(taln.toauma.strain_changed, func(strain: float) -> void:
		if strain != _last_strain:
			_last_strain = strain
			_write({"ev": "strain", "value": strain}))
	_connect(taln.toauma.notice, func(threshold: float, hunters: int, _life: float) -> void:
		_write({"ev": "notice", "threshold": threshold, "hunters": hunters}))
	_connect(taln.toauma.used, func(is_draw: bool, effect: Toauma.Effect) -> void:
		if effect != Toauma.Effect.NONE:
			_write({"ev": "side_effect", "effect": Toauma.Effect.keys()[effect].to_lower(), "draw": is_draw}))
	if _station is BraizeSlice:
		var slice: BraizeSlice = _station
		_connect(slice.region_entered, _write_region.bind(&"region"))
		_connect(slice.siege_began, _write_region.bind(&"siege"))
		_connect(slice.breaker_fell, _write_region.bind(&"breaker_fell"))
		_connect(slice.kit_offered, func(offer: Array[SkillDef]) -> void:
			_write({"ev": "kit_offer", "offer": offer.map(func(s: SkillDef) -> StringName: return s.id)}))
		_connect(slice.kit_taken, func(skill: SkillDef) -> void: _write({"ev": "kit_take", "skill": skill.id}))
		# P2-13: commanders coming and going.
		_connect(slice.commander_spawned, func(_slot: int, escort: Array[int]) -> void:
			_write({"ev": "commander", "escort": escort.size()}))
		_connect(slice.commander_killed, func(_at: Vector3) -> void: _write({"ev": "commander_kill"}))
	# P2-16: bargains offered and taken.
	var boons: Boons = _station.get_node_or_null("Boons")
	if boons:
		_connect(boons.offered, func(offer: Array[BoonDef]) -> void:
			_write({"ev": "boon_offer", "offer": offer.map(func(b: BoonDef) -> StringName: return b.id)}))
		_connect(boons.taken, func(boon: BoonDef) -> void:
			_write({"ev": "boon_take", "boon": boon.id, "source": BoonDef.Source.keys()[boon.source].to_lower()}))
	# P2-13: whether the swarm sees Taln, on every change.
	var awareness: Awareness = _station.get_node_or_null("Awareness")
	if awareness:
		_connect(awareness.state_changed, func(state: Awareness.State) -> void:
			_write({"ev": "seen", "state": Awareness.State.keys()[state].to_lower()}))
	# P2-11: structures raised, lost and striking (their damage is summed for the summary).
	var structures: Structures = _station.get_node_or_null("Structures")
	if structures:
		_connect(structures.raised, func(s: Structure) -> void:
			_structures_raised[s.kind] = _structures_raised.get(s.kind, 0) + 1
			_write({"ev": "structure", "kind": s.kind}))
		_connect(structures.lost, func(s: Structure, by_swarm: bool) -> void:
			_structures_lost[s.kind] = _structures_lost.get(s.kind, 0) + 1
			if by_swarm:
				_structures_lost_to_swarm += 1
			_write({"ev": "structure_lost", "kind": s.kind, "by_swarm": by_swarm}))
		_connect(structures.struck, func(kind: StringName, hits: int, damage: float) -> void:
			_structure_damage[kind] = _structure_damage.get(kind, 0.0) + damage
			_structure_hits[kind] = _structure_hits.get(kind, 0) + hits)
	# P2-15: the disease's kills.
	_connect(swarm.enemy_blighted, func(_id: StringName, _at: Vector3) -> void: _blight_kills += 1)
	# P2-11: Fracture's rhythm (warning, active, clear).
	_connect(taln.fracture.fracture_state_changed, func(state: Fracture.State) -> void:
		_write({"ev": "fracture", "state": Fracture.State.keys()[state].to_lower()}))
	# P2-12: every landing, and Impact's strikes (its behavior may come later, from a drop).
	_connect(taln.landed, func(speed: float, _at: Vector3) -> void:
		_write({"ev": "landing", "speed": snappedf(speed, 0.01)}))
	for behavior: Node in taln.loadout.get_children():
		_hook_impact(behavior)
	_connect(taln.loadout.skill_added, func(_skill: SkillDef, behavior: SkillBehavior) -> void: _hook_impact(behavior))
	_connect(spawner.wave_changed, func(wave: int) -> void:
		_flush_income()
		_write({"ev": "wave", "wave": wave, "station": _station.station_index()}))


## Region events on the Braize slice (P2-10): entered, siege began, breaker fell.
func _write_region(region: Region, ev: StringName) -> void:
	_flush_income()
	_write({"ev": ev, "region": region.id, "tier": region.tier, "station": _station.station_index()})


func _hook_impact(behavior: Node) -> void:
	if behavior is Impact:
		_connect((behavior as Impact).impacted, func(speed: float, hits: int) -> void:
			_write({"ev": "impact", "speed": snappedf(speed, 0.01), "hits": hits}))


func _connect(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_connections.append([sig, callable])


func _flush_income() -> void:
	if _file == null or _income.is_empty():
		return
	_write({"ev": "income", "by": _as_strings(_income),
			"station": _station.station_index() if is_instance_valid(_station) else 0})
	_income.clear()


func _snapshot() -> void:
	if _file == null or not is_instance_valid(_station):
		return
	var taln: Taln = _station.get_node("Taln")
	var swarm: SwarmServer = _station.get_node("SwarmServer")
	var kills: int = _station.kills
	# The last snapshot of a cycle can cover less than a full interval.
	var now: float = Cycle.director().play_time
	var span: float = maxf(now - _snapshot_t, 0.001)
	_snapshot_t = now
	_infected_peak = maxi(_infected_peak, swarm.get_infected_count())
	_write({"ev": "snapshot", "alive": swarm.get_alive_count(), "infected": swarm.get_infected_count(),
			"commanders": swarm.get_commander_slots().size(),
			"kill_rate": snappedf((kills - _kills_at_snapshot) / span * 60.0, 0.01),
			"investiture": snappedf(taln.investiture.current, 0.01), "health": snappedf(taln.health.current, 0.01),
			"agony": snappedf(taln.agony.value, 0.01), "strain": taln.toauma.strain,
			"station": _station.station_index(), "wave": (_station.get_node("SpawnDirector") as SpawnDirector).wave})
	_kills_at_snapshot = kills


func _write(event: Dictionary) -> void:
	if _file == null:
		return
	# Never back in time (an "abandoned" line lands after the next cycle's clock reset).
	_last_t = maxf(_last_t, Cycle.director().play_time)
	event["t"] = snappedf(_last_t, 0.01)
	_file.store_line(JSON.stringify(event))


func _close() -> void:
	for pair in _connections:
		var sig: Signal = pair[0]
		if not sig.is_null() and sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	_connections.clear()
	if _file and not _finished:
		# Gone before its end (freed mid-cycle): keep what's pending and say so.
		_flush_income()
		_write({"ev": "abandoned"})
	if _file:
		_file.flush()
		_file = null
	if is_instance_valid(_station) and _station.tree_exiting.is_connected(_close):
		_station.tree_exiting.disconnect(_close)
	_station = null


func _as_strings(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in d:
		out[String(key)] = snappedf(d[key], 0.01)
	return out


func _as_ints(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in d:
		out[String(key)] = int(d[key])
	return out
