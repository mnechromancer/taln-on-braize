extends SceneTree
## P2-13 (Awareness: sight, spotters, noise, memory and wandering; commander
## elites: their aura, spotting and spawning) checks, run headless against
## the Braize slice at a fixed 60 fps. Prints PASS/FAIL per check and exits
## with the number of failures. Meta state goes to user://checks_meta.json;
## telemetry for the one check that records goes to user://checks_telemetry_p2_13.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_13_checks.gd

const SLICE := "res://scenes/braize_slice.tscn"
const ASH_WALKER := "res://data/swarm/ash_walker.tres"
const COMMANDER := "res://data/swarm/ash_commander.tres"
const CHECKS_META := "user://checks_meta.json"
const CHECKS_TELEMETRY := "user://checks_telemetry_p2_13"
## Open, level ground in The Shelf, clear of features, pads and pools.
const OPEN := Vector3(20.0, 0.0, 115.0)
## South of the Tier I ridge (z = 43), far from its passage at x = 0.
const SOUTH_OF_RIDGE := Vector3(60.0, 0.0, 50.0)
const NORTH_OF_RIDGE := Vector3(60.0, 0.0, 36.0)

var station: BraizeSlice
var taln: Taln
var swarm: SwarmServer
var spawner: SpawnDirector
var ground: StationGround
var awareness: Awareness
var hud: Hud
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
	meta.set_aspect(&"unaspected")
	cycle = Cycle.director()
	_check_data()
	print("")
	await _check_close_sight()
	await _check_unseen_wander()
	await _check_memory()
	await _check_spotter()
	await _check_noise()
	await _check_hidden()
	await _check_detection_mult()
	print("")
	await _check_aura()
	await _check_commander_spawn()
	await _check_hud()
	await _check_telemetry()
	print("")
	print("MANUAL  Reading unseen vs seen in play, commanders' eyes and auras, and the swarm milling about when it has lost Taln need a rendered recording.")
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


func _fresh(at: Vector3 = OPEN) -> void:
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
	hud = station.get_node("Hud")
	spawner.paused = true
	# Taln's own weapon would kill the walkers these checks watch.
	taln.loadout.process_mode = Node.PROCESS_MODE_DISABLED
	await ground.ground_changed
	_place(at)
	await _ticks(3)


func _place(at: Vector3) -> void:
	taln.global_position = Vector3(at.x, ground.get_surface_height_at(at.x, at.z), at.z)
	taln.velocity = Vector3.ZERO


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _walkers(center: Vector3, count: int, hp_mult: float = 1.0) -> Array[int]:
	var ash: SwarmType = load(ASH_WALKER)
	var slots: Array[int] = []
	for k in count:
		slots.append(swarm.spawn(ash, center + Vector3(k * 0.6 - count * 0.3, 0.0, 0.0), hp_mult, 1.0))
	return slots


# --- data --------------------------------------------------------------------

func _check_data() -> void:
	var at: AwarenessTuning = load("res://data/tuning/awareness_tuning.tres")
	var st: SwarmTuning = load("res://data/tuning/swarm_tuning.tres")
	_check("Awareness: any enemy within 5 m sees Taln; the swarm remembers him 6 s, a noise 5 s; Voidlight is heard at 12 m, a landing (6 m/s+) at 10 m; lost, enemies wander at 35% speed",
			at.close_sight == 5.0 and at.memory_seconds == 6.0 and at.noise_memory == 5.0 and at.voidlight_noise_radius == 12.0
			and at.landing_noise_radius == 10.0 and at.landing_noise_min_speed == 6.0 and st.wander_speed_ratio == 0.35,
			"%.0f, %.0f, %.0f, %.0f, %.0f, %.0f, %.2f" % [at.close_sight, at.memory_seconds, at.noise_memory,
			at.voidlight_noise_radius, at.landing_noise_radius, at.landing_noise_min_speed, st.wander_speed_ratio])
	var c: SwarmType = load(COMMANDER)
	var h: SwarmType = load("res://data/swarm/notice_hunter.tres")
	var rt: RegionTuning = load("res://data/tuning/region_tuning.tres")
	_check("Ash commander: an elite of 360 Health, mass 6, cost 30, dropping 27; aura 9 m for ×1.35 speed and ×1.5 damage (lingering 1.5 s); a spotter at 26 m. Notice hunters spot at 20 m",
			c.tier == SwarmType.TIER_ELITE and c.hp == 360.0 and c.mass == 6.0 and c.spawn_cost == 30 and c.investiture_drop == 27.0
			and c.commander_radius == 9.0 and c.commander_speed_mult == 1.35 and c.commander_damage_mult == 1.5
			and st.commander_buff_linger == 1.5 and c.spotter and c.sight_range == 26.0 and h.spotter and h.sight_range == 20.0,
			"hp %.0f, aura %.0f m ×%.2f/×%.2f, sight %.0f; hunter sight %.0f" % [c.hp, c.commander_radius,
			c.commander_speed_mult, c.commander_damage_mult, c.sight_range, h.sight_range])
	_check("Regions: a commander 25 s after entering, then every 50 s, at most 3 alive, each with 6 escorts",
			rt.commander_type == c and rt.commander_first_delay == 25.0 and rt.commander_interval == 50.0
			and rt.commanders_max == 3 and rt.commander_escort == 6, "%.0f, %.0f, %d, %d" % [rt.commander_first_delay,
			rt.commander_interval, rt.commanders_max, rt.commander_escort])


# --- Awareness -------------------------------------------------------------------

func _check_close_sight() -> void:
	await _fresh()
	var slot: int = _walkers(taln.global_position + Vector3(4.0, 0.0, 0.0), 1)[0]
	swarm.apply_root_in_cone(swarm.get_enemy_position(slot), Vector3.FORWARD, 360.0, 1.0, 30.0)
	await _ticks(3)
	var seen: bool = awareness.state == Awareness.State.SEEN and swarm.is_known() \
			and swarm.get_goal_position().is_equal_approx(taln.global_position)
	_check("A walker 4 m away sees Taln: the swarm hunts his position", seen and swarm.is_using_awareness(),
			"state %s, known %s, goal %s" % [Awareness.State.keys()[awareness.state], swarm.is_known(), swarm.get_goal_position()])


func _check_unseen_wander() -> void:
	await _fresh()
	var slots: Array[int] = _walkers(taln.global_position + Vector3(22.0, 0.0, 0.0), 6)
	await _ticks(60 * 7)  # Past the 6 s memory.
	var state_after: Awareness.State = awareness.state
	var known_after: bool = swarm.is_known()
	var start: Array[Vector3] = []
	for s in slots:
		start.append(swarm.get_enemy_position(s))
	await _ticks(120)
	var closed: int = 0
	var moved: int = 0
	for i in slots.size():
		var p: Vector3 = swarm.get_enemy_position(slots[i])
		if _flat(p, taln.global_position) < _flat(start[i], taln.global_position) - 4.0:
			closed += 1
		if _flat(p, start[i]) > 0.5:
			moved += 1
	_check("Walkers 22 m away with no spotter never see Taln: after 6 s the swarm has lost him and wanders instead of closing in",
			state_after == Awareness.State.UNSEEN and not known_after and closed == 0 and moved >= 4,
			"state %s, known %s, %d closed in, %d wandered" % [Awareness.State.keys()[state_after], known_after, closed, moved])


func _check_memory() -> void:
	await _fresh()
	var slot: int = _walkers(taln.global_position + Vector3(4.0, 0.0, 0.0), 1)[0]
	swarm.apply_root_in_cone(swarm.get_enemy_position(slot), Vector3.FORWARD, 360.0, 1.0, 60.0)
	await _ticks(3)
	var last: Vector3 = taln.global_position
	# Taln vanishes 40 m away: the swarm keeps hunting where it last saw him.
	_place(taln.global_position + Vector3(-40.0, 0.0, 0.0))
	await _ticks(60 * 3)
	var searching: bool = awareness.state == Awareness.State.SEARCHING and swarm.is_known() \
			and _flat(swarm.get_goal_position(), last) < 0.1
	await _ticks(60 * 4)
	var lost: bool = awareness.state == Awareness.State.UNSEEN and not swarm.is_known()
	_check("Out of sight, the swarm searches the last known position for 6 s, then loses him", searching and lost,
			"searching %s (%s), lost %s" % [searching, Awareness.State.keys()[awareness.state], lost])


func _check_spotter() -> void:
	await _fresh(SOUTH_OF_RIDGE)
	var commander: SwarmType = load(COMMANDER)
	# A commander 14 m away across the ridge: no line, not seen.
	var slot: int = swarm.spawn(commander, NORTH_OF_RIDGE, 1.0, 1.0)
	swarm.apply_root_in_cone(NORTH_OF_RIDGE, Vector3.FORWARD, 360.0, 1.0, 60.0)
	await _ticks(60 * 7)
	var hidden: bool = awareness.state == Awareness.State.UNSEEN and swarm.count_spotters_seeing(taln.global_position, 1.0) == 0 \
			and not swarm.has_line_of_sight(NORTH_OF_RIDGE, taln.global_position)
	# Now on Taln's side, 20 m away with a clear line: seen.
	swarm.clear_all()
	var open_spot: Vector3 = SOUTH_OF_RIDGE + Vector3(0.0, 0.0, 20.0)
	slot = swarm.spawn(commander, open_spot, 1.0, 1.0)
	swarm.apply_root_in_cone(open_spot, Vector3.FORWARD, 360.0, 1.0, 60.0)
	await _ticks(3)
	var seen: bool = awareness.state == Awareness.State.SEEN and swarm.count_spotters_seeing(taln.global_position, 1.0) == 1
	# Beyond 26 m: not.
	swarm.clear_all()
	var far: Vector3 = SOUTH_OF_RIDGE + Vector3(0.0, 0.0, 30.0)
	swarm.spawn(commander, far, 1.0, 1.0)
	await _ticks(1)
	var too_far: bool = swarm.count_spotters_seeing(taln.global_position, 1.0) == 0
	_check("A commander spots Taln from 20 m with a clear line, but not through a ridge, and not from 30 m",
			hidden and seen and too_far, "through the ridge %s, clear %s, far %s" % [not hidden, seen, not too_far])


func _check_noise() -> void:
	await _fresh()
	_walkers(taln.global_position + Vector3(10.0, 0.0, 0.0), 3)
	for s in 3:
		swarm.apply_root_in_cone(taln.global_position + Vector3(10.0, 0.0, 0.0), Vector3.FORWARD, 360.0, 3.0, 60.0)
	await _ticks(60 * 7)
	var unseen: bool = awareness.state == Awareness.State.UNSEEN
	var heard: Array = []
	awareness.heard.connect(func(at: Vector3, radius: float) -> void: heard.append([at, radius]))
	taln.toauma.draw()  # Voidlight through the gem: heard within 12 m.
	await _ticks(2)
	var searching: bool = awareness.state == Awareness.State.SEARCHING and swarm.is_known() \
			and _flat(swarm.get_goal_position(), taln.global_position) < 0.1 and heard.size() == 1 and heard[0][1] == 12.0
	_check("Unseen, a Draw is heard by walkers 10 m away: the swarm comes to where it came from", unseen and searching,
			"unseen %s, then %s, heard %s" % [unseen, Awareness.State.keys()[awareness.state], heard])
	# A landing is heard too, from 6 m/s.
	taln.launch(Vector3(0.0, 9.0, 0.0))
	await _ticks(70)
	_check("A hard landing is heard within 10 m", heard.size() == 2 and heard[1][1] == 10.0, "heard %s" % [heard])


func _check_hidden() -> void:
	await _fresh()
	var slot: int = _walkers(taln.global_position + Vector3(3.0, 0.0, 0.0), 1)[0]
	swarm.apply_root_in_cone(swarm.get_enemy_position(slot), Vector3.FORWARD, 360.0, 1.0, 60.0)
	await _ticks(3)
	var before: bool = awareness.state == Awareness.State.SEEN
	awareness.hide(1.0)
	await _ticks(2)
	var hidden: bool = awareness.state == Awareness.State.SEARCHING and not awareness.is_seen()
	await _ticks(70)
	var again: bool = awareness.state == Awareness.State.SEEN
	_check("hide() takes Taln out of every eye for its time, then he's seen again (Fade's hook)", before and hidden and again,
			"seen %s, hidden %s, seen again %s" % [before, hidden, again])


func _check_detection_mult() -> void:
	meta.set_aspect(&"doomhunter_shade")
	await _fresh()
	var slot: int = _walkers(taln.global_position + Vector3(4.0, 0.0, 0.0), 1)[0]
	swarm.apply_root_in_cone(swarm.get_enemy_position(slot), Vector3.FORWARD, 360.0, 1.0, 60.0)
	await _ticks(3)
	var unseen_at_4: bool = not awareness.is_seen() and taln.aspect.detection_mult == 0.5
	var commander: SwarmType = load(COMMANDER)
	var c_at: Vector3 = taln.global_position + Vector3(0.0, 0.0, -16.0)
	swarm.spawn(commander, c_at, 1.0, 1.0)
	swarm.apply_root_in_cone(c_at, Vector3.FORWARD, 360.0, 1.0, 60.0)
	await _ticks(2)
	var unseen_by_commander: bool = not awareness.is_seen()
	_place(taln.global_position + Vector3(0.0, 0.0, -6.0))  # 10 m from the commander: within its halved 13 m.
	await _ticks(2)
	var seen_close: bool = awareness.is_seen()
	meta.set_aspect(&"unaspected")
	_check("Doomhunter (Shade) halves detection: unseen by a walker at 4 m and a commander at 16 m, seen at 10 m",
			unseen_at_4 and unseen_by_commander and seen_close, "walker %s, commander far %s, near %s"
			% [not unseen_at_4, not unseen_by_commander, seen_close])


# --- commanders ----------------------------------------------------------------

func _check_aura() -> void:
	await _fresh()
	var commander: SwarmType = load(COMMANDER)
	var c_at: Vector3 = taln.global_position + Vector3(12.0, 0.0, 12.0)
	var c_slot: int = swarm.spawn(commander, c_at, 1.0, 1.0)
	swarm.apply_root_in_cone(c_at, Vector3.FORWARD, 360.0, 1.0, 60.0)
	# One walker far outside the aura (seeing Taln via the commander): its own pace first, then
	# the same walker inside the aura (a walker's speed is rolled at spawn, so only its own ratio counts).
	var walker: int = _walkers(taln.global_position + Vector3(-16.0, 0.0, 0.0), 1)[0]
	await _ticks(2)
	var plain: bool = not swarm.is_enemy_buffed(walker)
	var start: Vector3 = swarm.get_enemy_position(walker)
	await _ticks(30)
	var plain_speed: float = _flat(swarm.get_enemy_position(walker), start) * 2.0
	var c2: int = swarm.spawn(commander, swarm.get_enemy_position(walker) + Vector3(0.0, 0.0, 3.0), 1.0, 1.0)
	swarm.apply_root_in_cone(swarm.get_enemy_position(c2), Vector3.FORWARD, 360.0, 1.0, 60.0)
	await _ticks(2)
	var buffed: bool = swarm.is_enemy_buffed(walker)
	start = swarm.get_enemy_position(walker)
	await _ticks(30)
	var buffed_speed: float = _flat(swarm.get_enemy_position(walker), start) * 2.0
	_check("A commander's aura buffs the walker inside it: ×1.35 its own pace (over the 4.8 m/s cap); outside it moves at its pace",
			plain and buffed and absf(buffed_speed / maxf(plain_speed, 0.01) - 1.35) < 0.08,
			"plain %s %.2f m/s, buffed %s %.2f m/s (×%.2f)" % [plain, plain_speed, buffed, buffed_speed, buffed_speed / maxf(plain_speed, 0.01)])
	# Contact damage ×1.5: a buffed walker on Taln hits for 9, not 6.
	swarm.clear_all()
	c_slot = swarm.spawn(commander, taln.global_position + Vector3(6.0, 0.0, 0.0), 1.0, 1.0)
	swarm.apply_root_in_cone(taln.global_position + Vector3(6.0, 0.0, 0.0), Vector3.FORWARD, 360.0, 1.0, 60.0)
	var hits: Array = []
	swarm.taln_contacted.connect(func(damage: float, _t: int) -> void: hits.append(damage))
	_walkers(taln.global_position + Vector3(0.6, 0.0, 0.0), 1)
	await _ticks(6)
	var hit_ok: bool = not hits.is_empty() and is_equal_approx(hits[0], 9.0)
	# The buff lingers 1.5 s once the commander dies.
	swarm.apply_damage_in_radius(swarm.get_enemy_position(c_slot), 0.5, 9999.0, Damage.Type.KINETIC)
	await _ticks(4)
	var walker_slot: int = -1
	for i in swarm.get_capacity():
		if swarm.is_enemy_alive(i):
			walker_slot = i
	var lingers: bool = walker_slot >= 0 and swarm.is_enemy_buffed(walker_slot)
	await _ticks(100)
	var faded: bool = walker_slot >= 0 and not swarm.is_enemy_buffed(walker_slot)
	_check("Buffed contact hits for ×1.5 (9); the buff lingers 1.5 s after the commander falls, then fades",
			hit_ok and lingers and faded, "first hit %s, lingers %s, faded %s" % [hits.slice(0, 1), lingers, faded])


func _check_commander_spawn() -> void:
	await _fresh()
	var first_delay: float = station.commander_left
	var spawned: Array = []
	station.commander_spawned.connect(func(slot: int, escort: Array[int]) -> void: spawned.append([slot, escort.size()]))
	var slot: int = station.spawn_commander()
	await _ticks(1)
	var one: bool = slot >= 0 and station.commanders_alive() == 1 and spawned.size() == 1 and spawned[0][1] == 6 \
			and swarm.get_enemy_type_id(slot) == &"ash_commander" and swarm.get_alive_count() == 7
	var escort_near: bool = true
	for i in swarm.get_capacity():
		if swarm.is_enemy_alive(i) and i != slot and _flat(swarm.get_enemy_position(i), swarm.get_enemy_position(slot)) > 4.0:
			escort_near = false
	var tracked: bool = station.nearest_commander().is_equal_approx(swarm.get_enemy_position(slot))
	var killed: Array = []
	station.commander_killed.connect(func(at: Vector3) -> void: killed.append(at))
	swarm.apply_damage_in_radius(swarm.get_enemy_position(slot), 0.5, 9999.0, Damage.Type.KINETIC)
	await _ticks(2)
	_check("The slice spawns a commander with 6 escorts around it (first after 25 s), tracks the nearest, and counts its kill",
			first_delay == 25.0 and one and escort_near and tracked and killed.size() == 1 and station.commanders_killed == 1
			and station.commanders_alive() == 0, "delay %.0f, one %s, escort near %s, tracked %s, killed %s"
			% [first_delay, one, escort_near, tracked, killed.size()])
	# The clock: with the spawner running, a commander comes once commander_left runs out.
	station.commander_left = 0.2
	spawner.paused = false
	spawner.lull = true  # No budget spawns to muddle the count.
	await _ticks(20)
	spawner.paused = true
	_check("The region's clock spawns commanders on its own", station.commanders_alive() == 1 and spawned.size() == 2
			and station.commander_left > 49.0, "%d alive, %d spawned, next in %.0f s" % [station.commanders_alive(), spawned.size(),
			station.commander_left])


func _check_hud() -> void:
	await _fresh()
	await _ticks(60 * 7)
	var line: String = hud._field_line(station)
	var unseen: bool = line == UiText.AWARENESS[Awareness.State.UNSEEN]
	var slot: int = station.spawn_commander()
	await _ticks(2)
	line = hud._field_line(station)
	var with_commander: bool = line.begins_with(UiText.AWARENESS[awareness.state]) and line.contains("Commander")
	_check("The HUD's third line reads Unseen / Seen / Searching and points to the nearest commander", unseen and with_commander,
			"'%s'" % line)


func _check_telemetry() -> void:
	var telemetry: Telemetry = Telemetry.recorder()
	telemetry.enabled = true
	telemetry.directory = CHECKS_TELEMETRY
	await _fresh()
	await _ticks(60 * 7)  # Unseen.
	var slot: int = station.spawn_commander()
	await _ticks(2)
	swarm.apply_damage_in_radius(swarm.get_enemy_position(slot), 0.5, 9999.0, Damage.Type.KINETIC)
	await _ticks(2)
	cycle.end_cycle(Cycle.Outcome.CLOSED)
	await _frames(2)
	telemetry.enabled = false
	var file: Dictionary = TelemetryAnalysis.read(telemetry.path)
	var a: Dictionary = TelemetryAnalysis.analyze(file)
	var s: Dictionary = file.summary
	var ok: bool = a.seen.size() >= 1 and a.unseen_seconds > 1.0 and a.commanders_spawned == 1 and a.commanders_killed == 1 \
			and a.first_commander_kill > 0.0 and float(s.get("unseen_time", 0.0)) > 1.0 and int(s.get("commanders_killed", 0)) == 1
	_check("Telemetry logs seen/unseen changes, commanders spawned and killed, and the summary's seen and unseen time", ok,
			"seen events %d, unseen %.1f s, commanders %d/%d, first kill %.1f" % [a.seen.size(), a.unseen_seconds,
			a.commanders_spawned, a.commanders_killed, a.first_commander_kill])
	for f in DirAccess.get_files_at(CHECKS_TELEMETRY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKS_TELEMETRY.path_join(f)))
	paused = false
