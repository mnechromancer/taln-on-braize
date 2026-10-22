extends SceneTree
## P2-15 (the Ashynite disease core and Plaguebringer: Culture, Spore Burst,
## Fade; infection buffing, killing and spreading by density) checks, run
## headless against the Braize slice at a fixed 60 fps. Prints PASS/FAIL per
## check and exits with the number of failures. Meta state goes to
## user://checks_meta.json; telemetry for the one check that records goes to
## user://checks_telemetry_p2_15.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_15_checks.gd

const SLICE := "res://scenes/braize_slice.tscn"
const ASH_WALKER := "res://data/swarm/ash_walker.tres"
const CHECKS_META := "user://checks_meta.json"
const CHECKS_TELEMETRY := "user://checks_telemetry_p2_15"
## Open, level ground in The Shelf, clear of features, pads and pools.
const OPEN := Vector3(20.0, 0.0, 115.0)

var station: BraizeSlice
var taln: Taln
var swarm: SwarmServer
var spawner: SpawnDirector
var ground: StationGround
var awareness: Awareness
var cycle: Cycle
var meta: Meta
var failures: int = 0


func _init() -> void:
	_run()


func _run() -> void:
	await _frames(2)
	meta = Meta.state()
	meta.redirect(CHECKS_META)
	meta.wipe()
	meta.set_aspect(&"plaguebringer")
	cycle = Cycle.director()
	_check_data()
	print("")
	await _check_kit()
	await _check_culture()
	await _check_disease()
	await _check_spread()
	await _check_spore_burst()
	await _check_fade()
	await _check_telemetry()
	print("")
	print("MANUAL  The crowd sickening and turning, outrunning a buffed infected pack, and waiting on a full map need a rendered recording.")
	print("")
	meta.wipe()
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


func _fresh(at: Vector3 = OPEN, weapon_on: bool = true) -> void:
	paused = false
	if is_instance_valid(station):
		station.queue_free()
		await _frames(1)
	station = (load(SLICE) as PackedScene).instantiate()
	root.add_child(station)
	taln = station.get_node("Taln")
	swarm = station.get_node("SwarmServer")
	spawner = station.get_node("SpawnDirector")
	ground = station.get_node("StationGround")
	awareness = station.get_node("Awareness")
	spawner.paused = true
	if not weapon_on:
		taln.loadout.process_mode = Node.PROCESS_MODE_DISABLED
	await ground.ground_changed
	_place(at)
	taln.investiture.add(500.0, &"debug")
	await _ticks(3)


func _place(at: Vector3) -> void:
	taln.global_position = Vector3(at.x, ground.get_surface_height_at(at.x, at.z), at.z)
	taln.velocity = Vector3.ZERO


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## A rooted crowd on a grid, spacing apart; returns the slots.
func _crowd(center: Vector3, side: int, spacing: float, hp_mult: float = 1.0) -> Array[int]:
	var ash: SwarmType = load(ASH_WALKER)
	var slots: Array[int] = []
	for z in side:
		for x in side:
			var at: Vector3 = center + Vector3((x - side / 2.0) * spacing, 0.0, (z - side / 2.0) * spacing)
			slots.append(swarm.spawn(ash, at, hp_mult, 1.0))
	swarm.apply_root_in_cone(center, Vector3.FORWARD, 360.0, side * spacing, 120.0)
	return slots


func _infected(slots: Array[int]) -> int:
	var n: int = 0
	for s in slots:
		if swarm.is_enemy_alive(s) and swarm.is_enemy_infected(s):
			n += 1
	return n


# --- data --------------------------------------------------------------------

func _check_data() -> void:
	var p: AspectDef = load("res://data/aspects/plaguebringer.tres")
	var ids: Array = p.starting_skills.map(func(s: SkillDef) -> StringName: return s.id)
	var st: SwarmTuning = load("res://data/tuning/swarm_tuning.tres")
	_check("Plaguebringer starts with Culture, Spore Burst and Fade, detection ×0.6, no Anchored or Fracture",
			ids == [&"culture", &"spore_burst", &"fade"] and p.detection_mult == 0.6 and not p.anchored and not p.fracture,
			"%s, %.2f" % [ids, p.detection_mult])
	_check("The disease: 4 s incubation, then 3 Blight per second; spreads to each neighbor within 1.6 m at 0.6/s; the infected move ×1.25 and hit ×1.25",
			st.blight_incubation == 4.0 and st.blight_dps == 3.0 and st.blight_spread_radius == 1.6 and st.blight_spread_rate == 0.6
			and st.blight_speed_mult == 1.25 and st.blight_damage_mult == 1.25, "%.0f, %.0f, %.1f, %.1f, %.2f, %.2f"
			% [st.blight_incubation, st.blight_dps, st.blight_spread_radius, st.blight_spread_rate, st.blight_speed_mult,
			st.blight_damage_mult])
	var c: SkillDef = load("res://data/skills/culture.tres")
	var b: SkillDef = load("res://data/skills/spore_burst.tres")
	var f: SkillDef = load("res://data/skills/fade.tres")
	var c1: Dictionary = c.params_for(1)
	var b1: Dictionary = b.params_for(1)
	var f1: Dictionary = f.params_for(1)
	_check("Culture: an Ashynite Weapon infecting the nearest enemy within 3.5 m every 1.5 s. Spore Burst: 20 Investiture, 8 s, infects within 6 m of a point 5 m out. Fade: Blade-eligible, 15, 12 s, hidden 4 s at ×1.4 speed",
			c.tree == SkillDef.SkillTree.ASHYNITE and c1.interval == 1.5 and c1.range == 3.5 and b.investiture_cost == 20.0
			and b.cooldown == 8.0 and b1.distance == 5.0 and b1.radius == 6.0 and f.routing == SkillDef.Routing.BLADE_ELIGIBLE
			and f.investiture_cost == 15.0 and f.cooldown == 12.0 and f1.duration == 4.0 and f1.speed_mult == 1.4
			and c.level_params.size() == 9 and b.level_params.size() == 9 and f.level_params.size() == 9,
			"%s / %s / %s" % [c1, b1, f1])


# --- Plaguebringer --------------------------------------------------------------

func _check_kit() -> void:
	await _fresh()
	var ids: Array = taln.loadout.slots.map(func(s: SkillDef) -> StringName: return s.id)
	_check("Plaguebringer's kit loads: Culture, Spore Burst on Surge 1, Fade on Surge 2",
			ids == [&"culture", &"spore_burst", &"fade"] and taln.loadout.get_bound_surge(0).id == &"spore_burst"
			and taln.loadout.get_bound_surge(1).id == &"fade", "%s" % [ids])


func _check_culture() -> void:
	await _fresh()
	var culture: Culture = taln.loadout.get_behavior(&"culture")
	culture.cooldown_left = 0.0
	var ash: SwarmType = load(ASH_WALKER)
	var near: Vector3 = taln.global_position + Vector3(2.0, 0.0, 0.0)
	var far: Vector3 = taln.global_position + Vector3(0.0, 0.0, 3.0)
	var near_slot: int = swarm.spawn(ash, near, 1.0, 1.0)
	var far_slot: int = swarm.spawn(ash, far, 1.0, 1.0)
	swarm.apply_root_in_cone(taln.global_position, Vector3.FORWARD, 360.0, 5.0, 60.0)
	var seeded: Array = []
	culture.seeded.connect(func(_at: Vector3, newly: int) -> void: seeded.append(newly))
	await _ticks(3)
	var first: bool = swarm.is_enemy_infected(near_slot) and not swarm.is_enemy_infected(far_slot) and seeded == [1] \
			and is_equal_approx(swarm.get_enemy_hp(near_slot), 12.0)
	await _ticks(90)
	var second: bool = swarm.is_enemy_infected(far_slot) and seeded == [1, 1] and swarm.get_infected_count() == 2
	_check("Culture infects the nearest enemy within 3.5 m, one every 1.5 s, dealing no damage itself", first and second,
			"first %s, second %s, seeded %s" % [first, second, seeded])


func _check_disease() -> void:
	await _fresh(OPEN, false)
	var ash: SwarmType = load(ASH_WALKER)
	# An infected walker beside Taln, hitting him, and a healthy one far away for speed.
	var sick: int = swarm.spawn(ash, taln.global_position + Vector3(0.6, 0.0, 0.0), 1.0, 1.0)
	swarm.infect_in_radius(taln.global_position + Vector3(0.6, 0.0, 0.0), 0.5)
	var hits: Array = []
	swarm.taln_contacted.connect(func(damage: float, _t: int) -> void: hits.append(damage))
	await _ticks(6)
	var hit_ok: bool = not hits.is_empty() and is_equal_approx(hits[0], 7.5)
	var hp_at_3s: float = 0.0
	await _ticks(60 * 3 - 6)
	hp_at_3s = swarm.get_enemy_hp(sick)
	var blighted: Array = []
	var died: Array = []
	swarm.enemy_blighted.connect(func(id: StringName, _at: Vector3) -> void: blighted.append(id))
	swarm.enemy_died.connect(func(id: StringName, _at: Vector3, rewarded: bool) -> void: died.append([id, rewarded]))
	await _ticks(60 * 6)
	var took: bool = is_equal_approx(hp_at_3s, 12.0) and blighted == [&"ash_walker"] and died == [[&"ash_walker", true]] \
			and swarm.get_infected_count() == 0
	_check("An infected walker hits ×1.25 (7.5), is untouched through 4 s of incubation, then 3 Blight/s takes it in ~4 s: a rewarded kill the disease claims",
			hit_ok and took, "first hit %s, Health at 3 s %.1f, blighted %s, died %s" % [hits.slice(0, 1), hp_at_3s, blighted, died])
	# Speed ×1.25 past the cap: the same walker, healthy then sick (a walker's speed is rolled at spawn).
	swarm.clear_all()
	awareness.enabled = false  # It hunts Taln, no sight needed.
	var start: Vector3 = taln.global_position + Vector3(-20.0, 0.0, 0.0)
	var s2: int = swarm.spawn(ash, start, 100.0, 1.0)
	await _ticks(30)
	var well_speed: float = _flat(swarm.get_enemy_position(s2), start) * 2.0
	start = swarm.get_enemy_position(s2)
	swarm.infect_in_radius(start, 0.5)
	await _ticks(30)
	var sick_speed: float = _flat(swarm.get_enemy_position(s2), start) * 2.0
	_check("The infected move ×1.25 their own pace (over the 4.8 m/s cap)", absf(sick_speed / maxf(well_speed, 0.01) - 1.25) < 0.08,
			"%.2f m/s → %.2f m/s (×%.2f)" % [well_speed, sick_speed, sick_speed / maxf(well_speed, 0.01)])


func _check_spread() -> void:
	await _fresh(OPEN, false)
	# A dense rooted crowd (0.8 m apart) with one infected in the middle.
	var dense: Array[int] = _crowd(taln.global_position + Vector3(12.0, 0.0, 0.0), 6, 0.8, 100.0)
	swarm.infect_in_radius(swarm.get_enemy_position(dense[21]), 0.3)
	await _ticks(60 * 10)
	var dense_infected: int = _infected(dense)
	swarm.clear_all()
	# A sparse one (3 m apart): nothing within 1.6 m to catch it.
	var sparse: Array[int] = _crowd(taln.global_position + Vector3(12.0, 0.0, 0.0), 4, 3.0, 100.0)
	swarm.infect_in_radius(swarm.get_enemy_position(sparse[5]), 0.3)
	await _ticks(60 * 10)
	var sparse_infected: int = _infected(sparse)
	_check("The disease spreads by density: through a packed crowd of 36 within 10 s, but not across 3 m gaps",
			dense_infected >= 24 and sparse_infected == 1, "dense %d of 36, sparse %d of 16" % [dense_infected, sparse_infected])


func _check_spore_burst() -> void:
	await _fresh(OPEN, false)
	var burst: SporeBurst = taln.loadout.get_behavior(&"spore_burst")
	var aim: Vector3 = burst.aim_direction()
	var center: Vector3 = taln.global_position + aim * 5.0
	var inside: Array[int] = _crowd(center, 3, 2.0, 100.0)
	var ash: SwarmType = load(ASH_WALKER)
	var outside: int = swarm.spawn(ash, center + aim * 8.0, 100.0, 1.0)
	swarm.apply_root_in_cone(center + aim * 8.0, Vector3.FORWARD, 360.0, 1.0, 60.0)
	var before: float = taln.investiture.current
	var cast: bool = burst.try_cast()
	await _ticks(1)
	_check("Spore Burst infects everything within 6 m of a point 5 m along the aim, for 20 Investiture; nothing beyond",
			cast and _infected(inside) == 9 and not swarm.is_enemy_infected(outside) and is_equal_approx(before - taln.investiture.current, 20.0),
			"cast %s, %d of 9, outside %s, spent %.0f" % [cast, _infected(inside), swarm.is_enemy_infected(outside),
			before - taln.investiture.current])


func _check_fade() -> void:
	await _fresh(OPEN, false)
	taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT
	taln.loadout.get_behavior(&"culture").process_mode = Node.PROCESS_MODE_DISABLED
	var fade: Fade = taln.loadout.get_behavior(&"fade")
	var ash: SwarmType = load(ASH_WALKER)
	var at: Vector3 = taln.global_position + Vector3(2.5, 0.0, 0.0)
	swarm.spawn(ash, at, 1.0, 1.0)
	swarm.apply_root_in_cone(at, Vector3.FORWARD, 360.0, 1.0, 60.0)
	await _ticks(3)
	var seen_before: bool = awareness.state == Awareness.State.SEEN
	taln.loadout.honorblade_held = true  # Silent through the Blade.
	var cast: bool = fade.try_cast()
	await _ticks(2)
	var hidden: bool = awareness.state == Awareness.State.SEARCHING and awareness.hidden_left > 3.5 \
			and is_equal_approx(taln.get_speed_multiplier(), 1.4)
	await _ticks(60 * 4 + 5)
	var back: bool = awareness.state == Awareness.State.SEEN and is_equal_approx(taln.get_speed_multiplier(), 1.0)
	_check("Fade hides Taln from the walker beside him for 4 s at ×1.4 speed, then he's seen again at walking pace",
			seen_before and cast and hidden and back, "seen %s, cast %s, hidden %s, back %s" % [seen_before, cast, hidden, back])


func _check_telemetry() -> void:
	var telemetry: Telemetry = Telemetry.recorder()
	telemetry.enabled = true
	telemetry.directory = CHECKS_TELEMETRY
	await _fresh(OPEN, false)
	var crowd: Array[int] = _crowd(taln.global_position + Vector3(10.0, 0.0, 0.0), 3, 0.8)
	swarm.infect_in_radius(swarm.get_enemy_position(crowd[4]), 0.3)
	await _ticks(60 * 15)
	cycle.end_cycle(Cycle.Outcome.CLOSED)
	await _frames(2)
	telemetry.enabled = false
	var file: Dictionary = TelemetryAnalysis.read(telemetry.path)
	var a: Dictionary = TelemetryAnalysis.analyze(file)
	var s: Dictionary = file.summary
	_check("Telemetry counts the disease's kills and the infected peak", int(s.get("blight_kills", 0)) >= 5
			and int(s.get("infected_peak", 0)) >= 5 and a.infected_peak >= 5, "blight kills %s, peak %s" % [s.get("blight_kills"),
			s.get("infected_peak")])
	for f in DirAccess.get_files_at(CHECKS_TELEMETRY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKS_TELEMETRY.path_join(f)))
	paused = false
