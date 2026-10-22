extends SceneTree
## P2-07 (Return, cycle structure, between-run screen) checks, run headless
## against the real station scene at a fixed 60 fps. Prints PASS/FAIL per
## check and exits with the number of failures. Meta state goes to
## user://checks_meta.json. One process frame is 1/60 s of real time here.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_07_checks.gd

const STATION := "res://scenes/graybox_station.tscn"
const ASH_WALKER := "res://data/swarm/ash_walker.tres"
const NOTICE_HUNTER := "res://data/swarm/notice_hunter.tres"
const CHECKS_META := "user://checks_meta.json"
const OPEN := Vector3(40.0, 0.0, 30.0)
const EMPTY := 0.1

var station: GrayboxStation
var taln: Taln
var swarm: SwarmServer
var spawner: SpawnDirector
var context: StationContext
var catalysis: Catalysis
var sequence: ReturnSequence
var screen: BetweenRunScreen
var cycle: Cycle
var meta: Meta
var ash: SwarmType
var hunter: SwarmType
var failures: int = 0


func _init() -> void:
	_run()


func _run() -> void:
	await _frames(2)
	meta = Meta.state()
	meta.redirect(CHECKS_META)
	# These checks are the gate build's: Stroke + Settle, Anchored and Fracture (P2-11 gave Earthshaper its own kit).
	Cycle.director().tuning.default_aspect = load("res://data/aspects/gate_build.tres")
	meta.wipe()
	cycle = Cycle.director()
	ash = load(ASH_WALKER)
	hunter = load(NOTICE_HUNTER)
	await _check_data()
	await _check_seed()
	await _check_reset()
	print("")
	await _check_cycle_structure()
	print("")
	await _check_return_freeze()
	await _check_reform()
	await _check_reform_blocked()
	await _check_skip()
	await _check_no_acting()
	await _check_return_fill()
	await _check_killing_blow_fill()
	await _check_return_during_window()
	await _check_reform_out_of_bounds()
	await _check_ninth_return()
	print("")
	await _check_screen()
	await _check_end_during_window()
	await _check_next_cycle()
	await _check_debug_keys()
	await _check_performance()
	print("")
	print("MANUAL  The Return beat (ash, black, reassembly) and the between-run screen need a rendered recording.")
	print("")
	meta.wipe()
	Engine.time_scale = 1.0
	paused = false
	print("%d check(s) failed." % failures if failures > 0 else "All automated checks passed.")
	quit(failures)


# --- helpers ---------------------------------------------------------------

func _check(label: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _fresh(at: Vector3 = OPEN) -> void:
	if station:
		paused = false
		Engine.time_scale = 1.0
		station.queue_free()
		await _frames(1)
	station = (load(STATION) as PackedScene).instantiate()
	root.add_child(station)
	_bind()
	spawner.paused = true
	taln.loadout.process_mode = Node.PROCESS_MODE_DISABLED
	await (station.get_node("StationGround") as StationGround).ground_changed
	taln.global_position = at
	taln.velocity = Vector3.ZERO
	await _ticks(2)


func _bind() -> void:
	taln = station.get_node("Taln")
	swarm = station.get_node("SwarmServer")
	spawner = station.get_node("SpawnDirector")
	context = station.get_node("StationContext")
	catalysis = station.get_node("Catalysis")
	sequence = station.get_node("ReturnSequence")
	screen = station.get_node("BetweenRunScreen")


func _tap(action: StringName) -> void:
	_send(action, true)
	await _frames(2)
	_send(action, false)
	await _frames(1)


func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


## Brings Taln's Health to 0.
func _kill_taln() -> void:
	taln.health.damage(10000.0, Damage.Type.KINETIC, true)
	await _frames(1)


## Runs frames until the Return reforms (or limit frames). Returns the count.
func _until_reformed(limit: int) -> int:
	var frames: int = 0
	while sequence.active and frames < limit:
		await _frames(1)
		frames += 1
	return frames


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


# --- data, seed, reset -----------------------------------------------------------

func _check_data() -> void:
	await _fresh()
	var ct: CycleTuning = cycle.tuning
	var rt: ReturnTuning = sequence.tuning
	var st: SpawnTuning = spawner.tuning
	_check("Cycle stand-in (ruled): 3 stations of 9 waves, a 15 s lull at 15% of the wave-9 budget; the ninth Return closes",
			ct.stations == 3 and ct.returns_to_close == 9 and ct.lull_seconds == 15.0 and st.lull_budget_fraction == 0.15
			and st.waves == 9, "stations %d, lull %.0f s at %.0f%%" % [ct.stations, ct.lull_seconds, st.lull_budget_fraction * 100.0])
	_check("Return: 4.5 s, skippable after 1.5 s once seen; shockwave 9 m kills mass ≤ 1 unrewarded, force 12 beyond; +300 Agony; Braize takes 1/3",
			rt.duration == 4.5 and rt.skip_after == 1.5 and rt.shockwave_radius == 9.0 and rt.shockwave_max_mass == 1.0
			and rt.shockwave_force == 12.0 and rt.return_agony == 300.0 and is_equal_approx(rt.braize_share, 1.0 / 3.0), "")


## First spawn positions after a cycle begins with this seed, and the first
## roll of every other seeded stream.
func _streams_with(seed_value: int) -> Array:
	cycle.next_seed = seed_value
	await _fresh()
	var rolls: Array = [taln.toauma.rng.randi(), taln.leveling.rng.randi(),
			(station.get_node("Well") as Well).rng.randi()]
	var spots: Array[Vector3] = []
	spawner.spawned.connect(func(_slot: int, at: Vector3) -> void: spots.append(at))
	spawner.paused = false
	await _ticks(300)
	spawner.paused = true
	var speeds: Array[float] = []  # SwarmServer's speed rolls show in how far enemies got.
	for s in 4:
		speeds.append(snappedf(swarm.get_enemy_position(s).x, 0.001))
	return [spots, rolls, speeds]


func _check_seed() -> void:
	var a: Array = await _streams_with(12345)
	var seed_a: int = cycle.cycle_seed
	var b: Array = await _streams_with(12345)
	var c: Array = await _streams_with(999)
	_check("The cycle's seed drives every stream: spawner, swarm, Toa'uma, leveling, the Well (same seed, same rolls)",
			seed_a == 12345 and (a[0] as Array).size() > 3 and a == b and a[0] != c[0] and a[1] != c[1],
			"%d spawns; rolls %s vs %s" % [(a[0] as Array).size(), a[1], c[1]])


func _check_reset() -> void:
	await _fresh()
	# Dirty everything, then start a cycle over on this station.
	taln.investiture.add(500.0, &"debug")
	taln.leveling.take(taln.leveling.offer()[0])
	taln.toauma.add_strain(4.0)
	taln.agony.add(400.0, &"checks")
	cycle.add_return()
	context.station_index = 1
	spawner.begin_station(1)
	await _ticks(60 * 12)  # Fracture builds while he stands.
	cycle.begin_cycle(station)
	await _frames(1)
	var levels_ok: bool = taln.loadout.owned().all(func(s: SkillDef) -> bool: return taln.loadout.get_level(s.id) == 1)
	_check("A cycle starts clean: Investiture 0, skills level 1, n 0, Strain 0 (Notices armed), Agony 0, Returns 0, wave 0, station 0, Fracture cleared",
			taln.investiture.current == 0.0 and levels_ok and taln.leveling.levels_taken == 0 and taln.toauma.strain == 0.0
			and taln.toauma.next_notice_threshold() == 3.0 and taln.agony.value < EMPTY and cycle.returns == 0
			and spawner.wave == 0 and context.station_index == 0 and taln.fracture.state == Fracture.State.NONE
			and taln.fracture.still_time == 0.0, "Investiture %.0f, n %d, Strain %.1f, Agony %.1f, Returns %d, wave %d, station %d, Fracture %s"
			% [taln.investiture.current, taln.leveling.levels_taken, taln.toauma.strain, taln.agony.value, cycle.returns,
			spawner.wave, context.station_index, Fracture.State.keys()[taln.fracture.state]])


# --- cycle structure -----------------------------------------------------------

func _check_cycle_structure() -> void:
	await _fresh()
	taln.health.set_invulnerable(&"checks", true)
	var fast: SpawnTuning = spawner.tuning.duplicate()
	fast.wave_length = 2.0
	spawner.tuning = fast
	var events: Array[String] = []
	cycle.lull_began.connect(func(i: int) -> void: events.append("lull %d" % i))
	cycle.station_began.connect(func(i: int) -> void: events.append("station %d" % i))
	var ended: Array = []
	cycle.cycle_ended.connect(func(o: Cycle.Outcome, _s: Dictionary) -> void: ended.append(o))
	spawner.paused = false
	# Station 1: nine 2 s waves, then the lull.
	await _ticks(60 * 18 + 5)
	var in_lull: bool = spawner.lull and not spawner.is_in_wave()
	var wave9: float = fast.base_budget * (1.0 + fast.wave_slope * 8) * fast.station_pressure[0]
	var lull_budget: float = spawner.budget_per_second()
	var ambient_before: float = taln.investiture.income_by_source.get(&"ambient", 0.0)
	await _ticks(60 * 5)
	var ambient_lull: float = taln.investiture.income_by_source.get(&"ambient", 0.0) - ambient_before
	spawner.returns_this_station = 2
	await _ticks(60 * 10 + 5)
	var station2: bool = context.station_index == 1 and spawner.wave == 0 and not spawner.lull \
			and spawner.returns_this_station == 0 and is_equal_approx(context.value(), 2.0) \
			and is_equal_approx(spawner.hp_multiplier(), fast.station_hp_mults[1])
	# Stations 2 and 3.
	await _ticks(60 * 18 + 60 * 15 + 60 * 18 + 10)
	_check("Stand-in cycle: 3 stations of 9 waves with a lull between; station 2 takes v 2 and S/D/P index 1",
			events == ["lull 0", "station 1", "lull 1", "station 2"] and station2,
			"events %s" % [events])
	_check("The lull: spawner at 15% of the wave-9 budget, no wave clock, no ambient Well", in_lull
			and is_equal_approx(lull_budget, wave9 * 0.15) and ambient_lull == 0.0, "lull budget %.3f/s vs wave 9's %.3f/s; ambient %.2f"
			% [lull_budget, wave9, ambient_lull])
	_check("After station 3's wave 9 the cycle ends Held", ended == [Cycle.Outcome.HELD] and screen.is_open and paused,
			"ended %s" % [ended])


# --- the Return ---------------------------------------------------------------

func _check_return_freeze() -> void:
	await _fresh()
	meta.wipe()
	swarm.set_target(taln)
	var slot: int = swarm.spawn(ash, OPEN + Vector3(12.0, 0.0, 0.0), 1.0, 1.0)
	taln.investiture.add(90.0, &"debug")
	spawner.paused = false
	await _ticks(30)
	await _kill_taln()
	var at: Vector3 = swarm.get_enemy_position(slot)
	var bank: float = spawner.bank
	var agony: float = taln.agony.value
	var fracture: float = taln.fracture.still_time
	var held: float = taln.investiture.current
	Input.action_press(&"move_left")
	await _frames(60 * 2)
	Input.action_release(&"move_left")
	_check("During the Return the world is frozen: swarm, spawner, Agony, Investiture income, Fracture; Taln can't move",
			sequence.active and swarm.is_frozen() and swarm.get_enemy_position(slot) == at and spawner.bank == bank
			and taln.agony.value == agony and taln.fracture.still_time == fracture and taln.investiture.current == held
			and _flat(taln.global_position - OPEN).length() < 0.01, "active %s, enemy still %s, Taln moved %.2f m"
			% [sequence.active, swarm.get_enemy_position(slot) == at, _flat(taln.global_position - OPEN).length()])
	# First viewing: presses don't skip it; it runs 4.5 s.
	var frames: int = 120
	for k in 3:
		await _tap(&"shoulder")
		frames += 3
	frames += await _until_reformed(600)
	_check("The first Return plays its full 4.5 s (real time); presses can't skip it", absf(frames - 270.0) <= 8.0
			and meta.return_seen, "reformed after %d frames (%.2f s)" % [frames, frames / 60.0])


func _check_reform() -> void:
	await _fresh()
	swarm.set_target(null)
	var near: Array[int] = []
	for k in 6:
		near.append(swarm.spawn(ash, OPEN + Vector3(cos(k), 0.0, sin(k)) * 6.0, 10.0, 1.0))
	var far: int = swarm.spawn(ash, OPEN + Vector3(12.0, 0.0, 0.0), 1.0, 1.0)
	var elite: int = swarm.spawn(hunter, OPEN + Vector3(0.0, 0.0, 5.0), 1.0, 1.0)
	var elite_at: Vector3 = swarm.get_enemy_position(elite)
	var died: Array = []
	swarm.enemy_died.connect(func(_id: StringName, _at: Vector3, rewarded: bool) -> void: died.append(rewarded))
	var motes: MoteServer = station.get_node("MoteServer")
	taln.investiture.add(90.0, &"debug")
	var budget_before: float = spawner.budget_per_second()
	var kills_before: int = station.kills
	await _kill_taln()
	sequence.reform()
	await _ticks(60)
	var pushed: float = _flat(swarm.get_enemy_position(elite) - elite_at).length()
	_check("Reform: full Health; ash-walkers within 9 m die unrewarded (no motes, not kills); the hunter is knocked 12 ÷ 4 = 3 m",
			taln.health.current == taln.tuning.max_health and died.size() == 6 and not died.has(true)
			and motes.get_count() == 0 and station.kills == kills_before and swarm.is_enemy_alive(far)
			and swarm.is_enemy_alive(elite) and absf(pushed - 3.0) < 0.1,
			"%d died (rewarded %s), motes %d, hunter pushed %.2f m" % [died.size(), died.has(true), motes.get_count(), pushed])
	_check("Reform: +300 Agony, Braize takes a third of held Investiture, Return pressure +9% budget",
			absf(taln.agony.gained_by_source.get(&"return", 0.0) - 300.0) < 0.01 and absf(taln.investiture.current - 60.0) < 0.01
			and absf(spawner.budget_per_second() - budget_before * 1.09) < 0.001 and spawner.returns_this_station == 1
			and cycle.returns == 1, "Agony +%.0f, held 90 → %.0f, budget %.3f → %.3f"
			% [taln.agony.gained_by_source.get(&"return", 0.0), taln.investiture.current, budget_before,
			spawner.budget_per_second()])


func _check_reform_blocked() -> void:
	await _fresh()
	var where: Vector3 = OPEN
	await _kill_taln()
	sequence.reform()
	await _ticks(2)
	var in_place: float = _flat(taln.global_position - where).length()
	# Die inside WallBlock's closed cells (a place he could have been flung into).
	var ground: StationGround = station.get_node("StationGround")
	taln.global_position = Vector3(-24.0, 3.0, -30.0)
	await _kill_taln()
	sequence.reform()
	await _ticks(2)
	var p: Vector3 = taln.global_position
	_check("Taln reforms where he fell; from a closed cell, at the nearest open one", in_place < 0.01
			and not ground.is_blocked_at(p.x, p.z) and _flat(p - Vector3(-24.0, 0.0, -30.0)).length() < 4.0,
			"in place %.3f m off; from inside WallBlock to (%.1f, %.1f)" % [in_place, p.x, p.z])


func _check_skip() -> void:
	await _fresh()
	meta.mark_return_seen()
	await _kill_taln()
	await _frames(60)
	await _tap(&"shoulder")
	var early: bool = sequence.active
	await _frames(35)
	await _tap(&"shoulder")
	_check("Once seen, any press skips the Return after 1.5 s (not before)", early and not sequence.active
			and taln.health.current == taln.tuning.max_health, "still running at ~1.05 s: %s; skipped at ~1.7 s: %s"
			% [early, not sequence.active])


func _check_return_fill() -> void:
	await _fresh()
	meta.unlock_catalysis()
	taln.agony.add(700.0, &"checks")
	await _kill_taln()
	var during: bool = catalysis.is_open()
	sequence.reform()
	await _frames(2)
	_check("+300 on reform fills the meter: the Welcome prompt opens once control is back, not during the Return",
			not during and catalysis.state == Catalysis.State.PROMPT and not taln.frozen, "open during %s, after %s"
			% [during, Catalysis.State.keys()[catalysis.state]])


func _check_return_during_window() -> void:
	await _fresh()
	meta.unlock_catalysis()
	var banked: int = meta.banked_agony
	taln.agony.add(900.0, &"checks")
	await _frames(2)
	var open: bool = catalysis.is_open()
	await _kill_taln()
	_check("Dying while a fill is being decided banks it (clarified) and restores time", open and not catalysis.is_open()
			and meta.banked_agony == banked + 1 and Engine.time_scale == 1.0 and sequence.active, "banked %d → %d"
			% [banked, meta.banked_agony])
	sequence.reform()


func _check_ninth_return() -> void:
	await _fresh()
	meta.mark_return_seen()
	var ended: Array = []
	cycle.cycle_ended.connect(func(o: Cycle.Outcome, _s: Dictionary) -> void: ended.append(o))
	for k in 8:
		await _kill_taln()
		sequence.reform()
		await _frames(1)
	var eighth_ok: bool = cycle.returns == 8 and ended.is_empty()
	await _kill_taln()
	var frames: int = 0
	while ended.is_empty() and frames < 600:
		await _frames(1)
		frames += 1
	_check("The ninth Return has no reform: the cycle ends Closed", eighth_ok and ended == [Cycle.Outcome.CLOSED]
			and cycle.returns == 9 and taln.health.current == 0.0 and screen.is_open, "after 8 Returns ok %s; ninth ended %s after %d frames"
			% [eighth_ok, ended, frames])


func _check_no_acting() -> void:
	await _fresh()
	meta.mark_return_seen()
	taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT
	taln.investiture.add(100.0, &"debug")
	swarm.set_target(null)
	var near: int = swarm.spawn(ash, OPEN + Vector3(2.0, 0.0, 0.0), 1.0, 1.0)
	await _kill_taln()
	var swings: Array[int] = [0]
	(taln.loadout.get_behavior(&"breaking_stroke") as BreakingStroke).swung.connect(
			func(_d: Vector3, _h: int) -> void: swings[0] += 1)
	var held: float = taln.investiture.current
	var strain: float = taln.toauma.strain
	await _tap(&"surge_1")
	await _tap(&"draw")
	await _frames(40)
	var idle: bool = swings[0] == 0 and swarm.is_enemy_alive(near) and taln.investiture.current == held \
			and taln.toauma.strain == strain
	await _frames(60)
	await _tap(&"shoulder")  # Skips; must not also charge.
	await _ticks(3)
	_check("During the Return Taln can't act: no auto-swing, Surge or Draw; the press that skips doesn't Shoulder",
			idle and not sequence.active and not taln.shoulder.is_charging and taln.shoulder.cooldown_left == 0.0,
			"idle %s, skipped %s, charging %s" % [idle, not sequence.active, taln.shoulder.is_charging])


func _check_killing_blow_fill() -> void:
	await _fresh()
	meta.unlock_catalysis()
	taln.agony.add(850.0, &"checks")
	# The killing blow's own Agony fills the meter.
	await _kill_taln()
	var during: bool = catalysis.is_open()
	var banked: int = meta.banked_agony
	sequence.reform()
	await _frames(2)
	_check("A killing blow that fills the meter holds its prompt until Taln reforms (not auto-banked)",
			not during and banked == 0 and catalysis.state == Catalysis.State.PROMPT, "open during %s, banked %d, after %s"
			% [during, banked, Catalysis.State.keys()[catalysis.state]])


func _check_reform_out_of_bounds() -> void:
	await _fresh()
	var ground: StationGround = station.get_node("StationGround")
	taln.global_position = Vector3(70.0, 0.0, 10.0)  # Past the 128 m ground's east edge.
	await _kill_taln()
	sequence.reform()
	await _ticks(2)
	var p: Vector3 = taln.global_position
	_check("Out of bounds, Taln reforms at the nearest open cell on the ground", not ground.is_blocked_at(p.x, p.z)
			and p.x < 64.0 and p.x > 60.0 and absf(p.z - 10.0) < 1.5, "reformed at (%.1f, %.1f)" % [p.x, p.z])


func _check_end_during_window() -> void:
	await _fresh()
	meta.wipe()
	meta.unlock_catalysis()
	taln.agony.add(900.0, &"checks")
	await _frames(2)
	var open: bool = catalysis.is_open()
	await _tap(&"debug_end_cycle")
	_check("Ending the cycle with a fill being decided banks it first; the summary counts it and no window runs under the screen",
			open and not catalysis.is_open() and meta.banked_agony == 1 and screen.stats.get("banked", 0) == 1
			and Engine.time_scale == 1.0 and paused, "banked %d, summary banked %s" % [meta.banked_agony,
			screen.stats.get("banked", -1)])
	paused = false


# --- between-run screen, next cycle, debug ------------------------------------------

func _check_screen() -> void:
	await _fresh()
	meta.wipe()
	meta.bank_agony(5)
	# One fill banked this cycle, a kill, a Return.
	catalysis.history.append({"choice": &"bank", "fired": [], "msec": 0})
	station.kills = 42
	cycle.add_return()
	cycle.play_time = 125.4
	cycle.end_cycle(Cycle.Outcome.HELD)
	await _frames(2)
	var title: String = screen._title.text
	var lines: String = screen._lines.text
	var expect: String = "\n".join([UiText.SUMMARY_TIME % [2, 5], UiText.SUMMARY_KILLS % 42, UiText.SUMMARY_RETURNS % 1,
			UiText.SUMMARY_FILLS % [0, 1]])
	var agony_line: String = screen._banked.text
	var caps: Array[String] = []
	for b in screen._cap_rows:
		caps.append(b.text)
	var raised: bool = screen.raise(1)  # Settle 3 → 4 costs 2.
	var after: int = meta.banked_agony
	var bearer: bool = screen.raise(2)  # Bearer 2 → 3 costs 1.
	_check("Between-run screen: Held stated plainly; time, kills, Returns, fills; caps rise at c − 1 banked points",
			paused and title == UiText.OUTCOME_HELD and lines == expect and agony_line == UiText.SUMMARY_AGONY % [1, 5, 5]
			and caps.size() == 3 and raised and after == 3
			and bearer and meta.banked_agony == 2 and meta.get_cap(&"settle") == 4 and meta.get_cap(&"bearer_of_agonies") == 3,
			"'%s'; %s; banked 5 → %d → %d" % [title, caps, after, meta.banked_agony])
	paused = false
	screen._panel.visible = false


func _check_next_cycle() -> void:
	await _fresh()
	var first_seed: int = cycle.cycle_seed
	cycle.end_cycle(Cycle.Outcome.CLOSED)
	await _frames(1)
	var old: GrayboxStation = station
	screen.begin_next()
	await _frames(3)
	var fresh: GrayboxStation = cycle.station
	var ok: bool = fresh != null and fresh != old and is_instance_valid(fresh) and not is_instance_valid(old) \
			and cycle.cycle_seed != first_seed and cycle.returns == 0 and not paused
	_check("Begin the next cycle loads the station again with a new seed", ok, "seed %d → %d" % [first_seed, cycle.cycle_seed])
	station = fresh
	if fresh:
		_bind()


func _check_debug_keys() -> void:
	await _fresh()
	meta.wipe()
	await _tap(&"debug_grant_agony")
	var granted: int = meta.banked_agony
	await _tap(&"debug_wipe_meta")
	var after_tap: int = meta.banked_agony
	_send(&"debug_wipe_meta", true)
	await _frames(70)
	_send(&"debug_wipe_meta", false)
	await _frames(1)
	var wiped: int = meta.banked_agony
	var ended: Array = []
	cycle.cycle_ended.connect(func(o: Cycle.Outcome, _s: Dictionary) -> void: ended.append(o))
	await _tap(&"debug_end_cycle")
	var screen_grant: bool = false
	if paused:
		await _tap(&"debug_grant_agony")  # On the between-run screen too.
		screen_grant = meta.banked_agony == 9
	_check("Debug: Ctrl+8 grants 9 spendable points (in play and on the between-run screen), Ctrl+9 held 1 s wipes MetaState (a tap doesn't), Ctrl+0 ends the cycle Held",
			granted == 9 and after_tap == 9 and wiped == 0 and ended == [Cycle.Outcome.HELD] and screen_grant
			and meta.banked_total == 0, "granted %d, after a tap %d, after 1 s %d, ended %s, on the screen %s, banked_total %d"
			% [granted, after_tap, wiped, ended, screen_grant, meta.banked_total])
	paused = false


func _check_performance() -> void:
	await _fresh()
	var ground: StationGround = station.get_node("StationGround")
	var k: int = 0
	while swarm.get_alive_count() < 400:
		var angle: float = k * 2.39996
		var at: Vector3 = taln.global_position + Vector3(cos(angle), 0.0, sin(angle)) * (2.0 + fmod(k * 0.37, 24.0))
		k += 1
		if not ground.is_blocked_at(at.x, at.z):
			swarm.spawn(ash, at, 1.0, 1.0)
	await _ticks(4)
	var start: int = Time.get_ticks_usec()
	var killed: int = swarm.kill_in_radius(taln.global_position, 9.0, 1.0)
	var kill_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	while swarm.get_alive_count() < 400:
		var angle: float = k * 2.39996
		var at: Vector3 = taln.global_position + Vector3(cos(angle), 0.0, sin(angle)) * (10.0 + fmod(k * 0.37, 16.0))
		k += 1
		if not ground.is_blocked_at(at.x, at.z):
			swarm.spawn(ash, at, 1.0, 1.0)
	await _kill_taln()
	var total: float = 0.0
	for f in 60:
		var before: int = Time.get_ticks_usec()
		await physics_frame
		total += (Time.get_ticks_usec() - before) / 1000.0
	_check("kill_in_radius over 400 alive, and whole frames with a frozen 400-strong swarm, cost next to nothing",
			kill_ms < 2.0 and total / 60.0 < 2.0, "kill_in_radius %d in %.3f ms; frozen frames avg %.3f ms"
			% [killed, kill_ms, total / 60.0])
