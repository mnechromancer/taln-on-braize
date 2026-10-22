extends SceneTree
## P2-11 (Earthshaper: Bulwark walls, Sentinel towers, the Warden construct,
## structures as lures the swarm attacks, the ground rebuilding around walls)
## checks, run headless against the Braize slice at a fixed 60 fps. Prints
## PASS/FAIL per check and exits with the number of failures. Meta state goes
## to user://checks_meta.json; telemetry for the one check that records goes
## to user://checks_telemetry_p2_11.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_11_checks.gd

const SLICE := "res://scenes/braize_slice.tscn"
const ASH_WALKER := "res://data/swarm/ash_walker.tres"
const CHECKS_META := "user://checks_meta.json"
const CHECKS_TELEMETRY := "user://checks_telemetry_p2_11"
## Open, level ground in The Shelf, clear of features, pads and pools.
const OPEN := Vector3(20.0, 0.0, 115.0)

var station: BraizeSlice
var taln: Taln
var swarm: SwarmServer
var spawner: SpawnDirector
var ground: StationGround
var structures: Structures
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
	meta.set_aspect(&"earthshaper")
	cycle = Cycle.director()
	_check_data()
	print("")
	await _check_kit()
	await _check_wall()
	await _check_wall_cap()
	await _check_tower()
	await _check_tower_lure()
	await _check_warden()
	await _check_warden_rally()
	await _check_new_cycle()
	await _check_telemetry()
	print("")
	print("MANUAL  Walls, towers and the warden in place, the swarm turning on them, and the land / set up / move rhythm need a rendered recording.")
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
	structures = station.get_node("Structures")
	awareness = station.get_node("Awareness")
	spawner.paused = true
	await ground.ground_changed
	_place(at)
	taln.investiture.add(500.0, &"debug")
	await _ticks(3)


func _place(at: Vector3) -> void:
	taln.global_position = Vector3(at.x, ground.get_surface_height_at(at.x, at.z), at.z)
	taln.velocity = Vector3.ZERO


func _surge(id: StringName) -> SurgeBehavior:
	return taln.loadout.get_behavior(id) as SurgeBehavior


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- data --------------------------------------------------------------------

func _check_data() -> void:
	var earth: AspectDef = load("res://data/aspects/earthshaper.tres")
	var ids: Array = earth.starting_skills.map(func(s: SkillDef) -> StringName: return s.id)
	var pool: Array = (load("res://data/tuning/region_tuning.tres") as RegionTuning).breaker_offer_pool.map(
			func(s: SkillDef) -> StringName: return s.id)
	_check("Earthshaper starts with Breaking Stroke, Bulwark, Sentinel and Warden, Anchored and Fracture on; Settle moved to the breaker pool",
			ids == [&"breaking_stroke", &"bulwark", &"sentinel", &"warden"] and earth.anchored and earth.fracture
			and pool.has(&"settle"), "%s; pool %s" % [ids, pool])
	var b: SkillDef = load("res://data/skills/bulwark.tres")
	var s: SkillDef = load("res://data/skills/sentinel.tres")
	var w: SkillDef = load("res://data/skills/warden.tres")
	var b1: Dictionary = b.params_for(1)
	var s1: Dictionary = s.params_for(1)
	var w1: Dictionary = w.params_for(1)
	_check("Bulwark: 25 Investiture, 5 s; a 7 × 2.5 × 1 m wall 4 m out for 20 s, 3 at most; levels 1–9",
			b.investiture_cost == 25.0 and b.cooldown == 5.0 and b1.width == 7.0 and b1.height == 2.5 and b1.thickness == 1.0
			and b1.distance == 4.0 and b1.duration == 20.0 and b1.max == 3.0 and b.level_params.size() == 9, "%s" % [b1])
	_check("Sentinel: 35 Investiture, 7 s; a 220-Health tower 5 m out for 25 s, 14 damage every 0.8 s within 10 m, pulling the swarm from 7 m; 3 at most",
			s.investiture_cost == 35.0 and s.cooldown == 7.0 and s1.distance == 5.0 and s1.hp == 220.0 and s1.duration == 25.0
			and s1.damage == 14.0 and s1.interval == 0.8 and s1.range == 10.0 and s1.pull_radius == 7.0 and s1.max == 3.0
			and s.level_params.size() == 9, "%s" % [s1])
	_check("Warden: 40 Investiture, 10 s; a 320-Health construct for 35 s, 12 damage every 0.9 s within 2.2 m, 4.5 m/s, pulling from 8 m; one at a time, rallied 8 m along the aim",
			w.investiture_cost == 40.0 and w.cooldown == 10.0 and w1.hp == 320.0 and w1.duration == 35.0 and w1.damage == 12.0
			and w1.interval == 0.9 and w1.strike_radius == 2.2 and w1.speed == 4.5 and w1.pull_radius == 8.0 and w1.max == 1.0
			and w1.rally_distance == 8.0 and w.level_params.size() == 9, "%s" % [w1])


# --- Earthshaper -------------------------------------------------------------

func _check_kit() -> void:
	await _fresh()
	var ids: Array = taln.loadout.slots.map(func(s: SkillDef) -> StringName: return s.id)
	var bound: Array = []
	for i in 3:
		var surge: SkillDef = taln.loadout.get_bound_surge(i)
		bound.append(surge.id if surge else &"")
	_check("Earthshaper's kit loads with Bulwark, Sentinel and Warden on Surges 1–3, and the slice has a Structures node",
			ids == [&"breaking_stroke", &"bulwark", &"sentinel", &"warden"] and bound == [&"bulwark", &"sentinel", &"warden"]
			and structures != null and taln.loadout.structures == structures, "%s, bound %s" % [ids, bound])


func _check_wall() -> void:
	await _fresh()
	var bulwark: Bulwark = _surge(&"bulwark")
	var aim: Vector3 = bulwark.aim_direction()
	var center: Vector3 = taln.global_position + aim * 4.0
	var open_before: bool = not ground.is_blocked_at(center.x, center.z)
	var cast: bool = bulwark.try_cast()
	await _ticks(4)
	var walls: Array[Structure] = structures.of_kind(&"wall")
	var wall: StoneWall = walls[0] as StoneWall if not walls.is_empty() else null
	var across: Vector3 = aim.rotated(Vector3.UP, PI / 2.0)
	var blocked_now: bool = ground.is_blocked_at(center.x, center.z) \
			and ground.is_blocked_at(center.x + across.x * 3.0, center.z + across.z * 3.0)
	var placed: bool = wall != null and _flat(wall.global_position, center) < 0.3
	# An enemy just past the wall: no straight grid line to Taln through it.
	var behind: Vector3 = center + aim * 2.0
	await _ticks(2)
	var line_blocked: bool = not swarm.has_line_of_sight(behind, taln.global_position)
	_check("Bulwark raises a 7 m wall 4 m along the aim: its cells block the swarm and break the line to Taln",
			cast and open_before and placed and blocked_now and line_blocked,
			"cast %s, open before %s, placed %s, blocked %s, line blocked %s" % [cast, open_before, placed, blocked_now, line_blocked])
	# It crumbles at the end of its life, and the ground opens again.
	wall.lifetime_left = 0.1
	await _ticks(12)
	var gone: bool = structures.count(&"wall") == 0 and not is_instance_valid(wall)
	var open_after: bool = not ground.is_blocked_at(center.x, center.z)
	_check("A wall crumbles when its time runs out, and its cells open again", gone and open_after,
			"gone %s, open %s" % [gone, open_after])


func _check_wall_cap() -> void:
	await _fresh()
	var bulwark: Bulwark = _surge(&"bulwark")
	var first: Structure = null
	var lost: Array = []
	structures.lost.connect(func(s: Structure, by_swarm: bool) -> void: lost.append([s.kind, by_swarm]))
	for k in 4:
		bulwark.cooldown_left = 0.0
		bulwark.try_cast()
		await _ticks(2)
		if k == 0:
			first = structures.of_kind(&"wall")[0]
		# Each next wall a little further along, so they don't stack.
		_place(taln.global_position + Vector3(6.0, 0.0, 0.0))
		await _ticks(1)
	await _ticks(2)
	_check("At most 3 walls stand: the fourth crumbles the oldest (lost, not to the swarm)",
			structures.count(&"wall") == 3 and not is_instance_valid(first) and lost == [[&"wall", false]],
			"%d walls, first gone %s, lost %s" % [structures.count(&"wall"), not is_instance_valid(first), lost])


func _check_tower() -> void:
	await _fresh()
	var sentinel: Sentinel = _surge(&"sentinel")
	var aim: Vector3 = sentinel.aim_direction()
	var at: Vector3 = taln.global_position + aim * 5.0
	var ash: SwarmType = load(ASH_WALKER)
	# A tough walker 6 m past the tower, rooted so it stays put (within the tower's 10 m).
	var victim: Vector3 = at + aim * 6.0
	var slot: int = swarm.spawn(ash, victim, 100.0, 1.0)
	swarm.apply_root_in_cone(victim, Vector3.FORWARD, 360.0, 1.0, 30.0)
	var hits: Array = []
	structures.struck.connect(func(kind: StringName, n: int, damage: float) -> void: hits.append([kind, n, damage]))
	var cast: bool = sentinel.try_cast()
	await _ticks(2)
	var towers: Array[Structure] = structures.of_kind(&"tower")
	var tower: SentinelTower = towers[0] as SentinelTower if not towers.is_empty() else null
	await _ticks(60)
	var hp_before: float = 1200.0
	var hp_now: float = swarm.get_enemy_hp(slot)
	_check("Sentinel raises a tower 5 m out that strikes the nearest enemy in range: 14 damage per shard, one every 0.8 s",
			cast and tower != null and _flat(tower.global_position, at) < 0.3 and hits.size() == 2 and hits[0] == [&"tower", 1, 14.0]
			and is_equal_approx(hp_before - hp_now, 28.0), "tower %s, hits %s, Health %.0f → %.0f" % [tower, hits, hp_before, hp_now])


func _check_tower_lure() -> void:
	await _fresh()
	var sentinel: Sentinel = _surge(&"sentinel")
	var aim: Vector3 = sentinel.aim_direction()
	var tower_at: Vector3 = taln.global_position + aim * 5.0
	sentinel.try_cast()
	await _ticks(2)
	var tower: SentinelTower = structures.of_kind(&"tower")[0]
	tower.damage = 0.0  # Let the crowd live to break it.
	var ash: SwarmType = load(ASH_WALKER)
	# Walkers 5 m past the tower (inside its 7 m pull, 10 m from Taln) head for the tower, not Taln.
	var slots: Array[int] = []
	for k in 6:
		slots.append(swarm.spawn(ash, tower_at + aim * 5.0 + Vector3(k * 0.4 - 1.0, 0.0, 0.0), 1.0, 1.0))
	await _ticks(100)  # ~4 m at a walker's pace, then contact.
	var nearer_tower: int = 0
	for s in slots:
		var p: Vector3 = swarm.get_enemy_position(s)
		if _flat(p, tower_at) < 1.6:
			nearer_tower += 1
	var hurt: bool = tower.hp < tower.max_hp
	_check("A tower is a lure: the swarm within its pull radius attacks it instead of Taln, and its Health falls",
			nearer_tower >= 5 and hurt, "%d of 6 at the tower, Health %.0f of %.0f" % [nearer_tower, tower.hp, tower.max_hp])
	var lost: Array = []
	structures.lost.connect(func(s: Structure, by_swarm: bool) -> void: lost.append(by_swarm))
	tower.take_damage(tower.hp + 1.0)
	await _ticks(2)
	_check("A tower with no Health left crumbles, lost to the swarm", lost == [true] and structures.count(&"tower") == 0,
			"lost %s, %d standing" % [lost, structures.count(&"tower")])


func _check_warden() -> void:
	await _fresh()
	var warden_skill: Warden = _surge(&"warden")
	var aim: Vector3 = warden_skill.aim_direction()
	var rally: Vector3 = taln.global_position + aim * 8.0
	var cast: bool = warden_skill.try_cast()
	await _ticks(2)
	var wardens: Array[Structure] = structures.of_kind(&"warden")
	var warden: StoneWarden = wardens[0] as StoneWarden if not wardens.is_empty() else null
	var start_dist: float = _flat(warden.global_position, rally) if warden else 0.0
	await _ticks(110)
	var now_dist: float = _flat(warden.global_position, rally) if warden else 0.0
	_check("Warden calls a construct beside Taln that walks to its rally point 8 m along the aim at 4.5 m/s",
			cast and warden != null and start_dist > 5.0 and now_dist < 0.8 and warden.rally.is_equal_approx(rally),
			"warden %s, %.1f m → %.1f m from the rally" % [warden, start_dist, now_dist])
	# It strikes what reaches it: a tough rooted walker beside the rally point.
	var ash: SwarmType = load(ASH_WALKER)
	var slot: int = swarm.spawn(ash, rally + Vector3(1.0, 0.0, 0.0), 100.0, 1.0)
	swarm.apply_root_in_cone(rally, Vector3.FORWARD, 360.0, 3.0, 30.0)
	var hits: Array = []
	structures.struck.connect(func(kind: StringName, n: int, _d: float) -> void: hits.append([kind, n]))
	await _ticks(60)
	_check("The warden strikes enemies within 2.2 m of it: 12 damage every 0.9 s", hits.size() >= 1 and hits[0] == [&"warden", 1]
			and swarm.get_enemy_hp(slot) < 1200.0, "hits %s, Health %.0f" % [hits, swarm.get_enemy_hp(slot)])


func _check_warden_rally() -> void:
	await _fresh()
	var warden_skill: Warden = _surge(&"warden")
	warden_skill.try_cast()
	await _ticks(2)
	var warden: StoneWarden = structures.of_kind(&"warden")[0]
	var before: float = taln.investiture.current
	warden_skill.cooldown_left = 0.0
	_place(taln.global_position + Vector3(0.0, 0.0, -12.0))
	await _ticks(1)
	var aim: Vector3 = warden_skill.aim_direction()
	var rally: Vector3 = taln.global_position + aim * 8.0
	var rallied: Array = []
	warden_skill.rallied.connect(func(at: Vector3) -> void: rallied.append(at))
	var recast: bool = warden_skill.try_cast()
	await _ticks(1)
	var still_one: bool = structures.count(&"warden") == 1 and structures.of_kind(&"warden")[0] == warden
	_check("Casting Warden while one stands is a free rally order: the same warden heads 8 m along the new aim",
			recast and still_one and rallied.size() == 1 and _flat(warden.rally, rally) < 0.3 and taln.investiture.current == before,
			"recast %s, same warden %s, rally %s, Investiture %.0f → %.0f" % [recast, still_one, rallied, before, taln.investiture.current])


func _check_new_cycle() -> void:
	await _fresh()
	_surge(&"bulwark").try_cast()
	_surge(&"sentinel").try_cast()
	await _ticks(2)
	var standing_before: int = structures.standing().size()
	station.reset_for_cycle()
	await _ticks(2)
	_check("A new cycle takes every structure down", standing_before == 2 and structures.standing().is_empty(),
			"%d before, %d after" % [standing_before, structures.standing().size()])


func _check_telemetry() -> void:
	var telemetry: Telemetry = Telemetry.recorder()
	telemetry.enabled = true
	telemetry.directory = CHECKS_TELEMETRY
	await _fresh()
	_surge(&"sentinel").try_cast()
	await _ticks(2)
	var tower: SentinelTower = structures.of_kind(&"tower")[0]
	var ash: SwarmType = load(ASH_WALKER)
	swarm.spawn(ash, tower.global_position + Vector3(3.0, 0.0, 0.0), 100.0, 1.0)
	await _ticks(30)
	tower.take_damage(9999.0)
	await _ticks(2)
	cycle.end_cycle(Cycle.Outcome.CLOSED)
	await _frames(2)
	telemetry.enabled = false
	var file: Dictionary = TelemetryAnalysis.read(telemetry.path)
	var a: Dictionary = TelemetryAnalysis.analyze(file)
	var s: Dictionary = file.summary
	var ok: bool = a.structures.size() == 1 and a.structures[0].kind == "tower" and int(s.structures_raised.get("tower", 0)) == 1 \
			and int(s.structures_lost_to_swarm) == 1 and int(s.structure_hits.get("tower", 0)) >= 1 \
			and float(s.structure_damage.get("tower", 0.0)) >= 14.0
	_check("Telemetry logs structures raised and lost, and sums what they struck", ok,
			"raised %s, lost to swarm %s, hits %s, damage %s" % [s.get("structures_raised"), s.get("structures_lost_to_swarm"),
			s.get("structure_hits"), s.get("structure_damage")])
	for f in DirAccess.get_files_at(CHECKS_TELEMETRY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKS_TELEMETRY.path_join(f)))
	paused = false
