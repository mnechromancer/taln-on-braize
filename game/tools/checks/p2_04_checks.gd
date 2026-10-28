extends SceneTree
## P2-04 (flow field) checks, run headless against the real station scene at
## a fixed 60 fps. Prints PASS/FAIL per check (INFO lines are not judged) and
## exits with the number of failures.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_04_checks.gd

const STATION := "res://scenes/graybox_station.tscn"
const ASH_WALKER := "res://data/swarm/ash_walker.tres"
const NOTICE_HUNTER := "res://data/swarm/notice_hunter.tres"
const SWARM_TUNING := "res://data/tuning/swarm_tuning.tres"

## Behind WallLong (x -6..6, z -36.5..-35.5): north of it, and south of it.
const NORTH_OF_WALL := Vector3(0.0, 0.0, -40.0)
const SOUTH_OF_WALL := Vector3(0.0, 0.0, -30.0)
const PLATEAU_TOP := Vector3(0.0, 1.5, 0.0)
## The 0.4 m-step platform: Taln can stand there, the swarm's data can't reach it.
const HIGH_STEP_PLATFORM := Vector3(-34.2, 1.6, 0.0)
## An enemy this close to Taln (on his level) has arrived.
const ARRIVED_M := 2.0
## Stationary enemies within this of Taln are in the crowd around him.
const CROWD_M := 6.0
## A heading needs at least this much movement to count.
const MOVED_M := 0.05

var station: GrayboxStation
var taln: Taln
var ground: StationGround
var swarm: SwarmServer
var spawner: SpawnDirector
var ash: SwarmType
var failures: int = 0
var tick: int = 0


func _init() -> void:
	_run()


func _run() -> void:
	await _ticks(2)
	Meta.state().redirect("user://checks_meta.json")
	Meta.state().wipe()
	# These checks are the gate build's: Stroke + Settle, Anchored and Fracture (P2-11 gave Earthshaper its own kit).
	Cycle.director().tuning.default_aspect = load("res://data/aspects/gate_build.tres")
	ash = load(ASH_WALKER)
	await _check_tuning()
	await _check_field_on_station()
	await _check_rebuild_cost()
	print("")
	await _check_corner_cutting()
	print("")
	await _check_rebuild_on_move()
	await _check_rebuild_rate()
	await _check_rebuild_on_ground_change()
	print("")
	await _check_around_wall()
	await _check_up_plateau()
	await _check_direct_in_sight()
	await _check_direct_when_close()
	await _check_close_but_far_along_field()
	await _check_direct_when_unreachable()
	await _check_hunters()
	await _check_rooted()
	print("")
	await _check_acceptance()
	print("")
	await _check_step_budget()
	await _check_frame_cost()
	print("")
	print("MANUAL  The swarm visibly flows around the plateau ramps (rendered recording, Taln on the plateau).")
	print("MANUAL  60 fps rendered at 400 alive with the field in use.")
	print("")
	print("%d check(s) failed." % failures if failures > 0 else "All automated checks passed.")
	quit(failures)


# --- helpers ---------------------------------------------------------------

func _check(label: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _info(label: String, detail: String) -> void:
	print("INFO  %s  (%s)" % [label, detail])


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame
		tick += 1


## A new station after its first ground sample: spawner paused, Taln
## invulnerable, his skills off unless a check turns them on.
func _fresh() -> void:
	if station:
		station.queue_free()
		await _ticks(1)
	station = (load(STATION) as PackedScene).instantiate()
	root.add_child(station)
	ground = station.get_node("StationGround")
	taln = station.get_node("Taln")
	swarm = station.get_node("SwarmServer")
	spawner = station.get_node("SpawnDirector")
	spawner.paused = true
	taln.health.set_invulnerable(&"checks", true)
	taln.loadout.process_mode = Node.PROCESS_MODE_DISABLED
	await ground.ground_changed
	await _ticks(2)


## Moves Taln and waits out the rebuild interval, so the field points at him.
func _place_taln(at: Vector3) -> void:
	taln.global_position = at
	taln.velocity = Vector3.ZERO
	await _ticks(8)


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return _flat(a - b).length()


func _touching(slot: int, type: SwarmType) -> bool:
	return _flat_dist(swarm.get_enemy_position(slot), taln.global_position) \
			<= taln.tuning.capsule_radius + type.radius + 0.05


## Spawns count enemies of type on open cells along a row from start by step.
func _spawn_row(type: SwarmType, start: Vector3, step: Vector3, count: int) -> Array[int]:
	var slots: Array[int] = []
	var at: Vector3 = start
	while slots.size() < count:
		if not ground.is_blocked_at(at.x, at.z):
			slots.append(swarm.spawn(type, at, 1.0, 1.0))
		at += step
	return slots


## Runs up to seconds, stopping early once every slot has come within
## ARRIVED_M of Taln (on his level) at least once; ten can't all touch him at
## the same time. Returns the seconds it took, or INF.
func _until_all_arrive(slots: Array[int], seconds: float) -> float:
	var arrived: Dictionary[int, bool] = {}
	for k in roundi(seconds * 60.0):
		await _ticks(1)
		for s in slots:
			var p: Vector3 = swarm.get_enemy_position(s)
			if _flat_dist(p, taln.global_position) <= ARRIVED_M and absf(p.y - taln.global_position.y) < 0.2:
				arrived[s] = true
		if arrived.size() == slots.size():
			return (k + 1) / 60.0
	return INF


# --- field -------------------------------------------------------------------

func _check_tuning() -> void:
	var t: SwarmTuning = load(SWARM_TUNING)
	_check("Flow tuning: rebuild at most every 0.1 s (10 Hz), direct seek within 3 m",
			t.flow_rebuild_interval == 0.1 and t.flow_direct_range == 3.0,
			"interval %.2f s, direct range %.1f m" % [t.flow_rebuild_interval, t.flow_direct_range])


func _check_field_on_station() -> void:
	await _fresh()
	await _place_taln(SOUTH_OF_WALL)
	swarm.rebuild_flow_field()
	var open_at := Vector3(20.0, 0.0, -30.0)
	var open_dist: float = swarm.get_flow_distance(open_at)
	var straight: float = _flat_dist(open_at, SOUTH_OF_WALL)
	_check("In the open the field distance matches the straight line", swarm.is_flow_line_clear(open_at)
			and absf(open_dist - straight) <= 1.0, "%.1f m along the field, %.1f m straight" % [open_dist, straight])

	var behind := Vector3(0.0, 0.0, -40.0)
	var around: float = swarm.get_flow_distance(behind)
	var flow: Vector3 = swarm.get_flow_direction(behind)
	# Around either end of the 12 m wall: at least out to x = ±6.5 and back.
	var shortest_around: float = 2.0 * Vector2(6.5, 5.0).length()
	_check("Behind WallLong the field routes around the wall", not swarm.is_flow_line_clear(behind)
			and around >= shortest_around - 1.0 and around < shortest_around + 4.0 and absf(flow.x) > 0.6,
			"%.1f m along the field (straight %.1f m, around the end ≥ %.1f m); flow %s points sideways"
			% [around, _flat_dist(behind, SOUTH_OF_WALL), shortest_around, flow])

	var under_wall: float = swarm.get_flow_distance(Vector3(-24.0, 0.0, -30.0))
	var high_step: float = swarm.get_flow_distance(HIGH_STEP_PLATFORM)
	_check("Blocked cells and the 0.4 m-step platform are unreachable", under_wall < 0.0 and high_step < 0.0,
			"under WallBlock %.1f, on the platform %.1f" % [under_wall, high_step])

	await _place_taln(PLATEAU_TOP + Vector3.UP * 0.1)
	swarm.rebuild_flow_field()
	var north_base := Vector3(0.0, 0.0, -14.0)
	var via_ramp: float = swarm.get_flow_distance(north_base)
	var south_ramp: float = swarm.get_flow_distance(Vector3(0.0, 0.0, 18.0))
	_check("Taln on the plateau: the north cliff base routes to a ramp, the south ramp goes straight up",
			via_ramp > 25.0 and not swarm.is_flow_line_clear(north_base) and swarm.is_flow_line_clear(Vector3(0.0, 0.0, 18.0))
			and absf(south_ramp - 18.0) <= 1.0, "north base %.1f m along the field (14 m straight); south ramp %.1f m"
			% [via_ramp, south_ramp])


func _check_rebuild_cost() -> void:
	await _fresh()
	var times: Array[float] = []
	for k in 100:
		taln.global_position = Vector3(-50.0 + k, 0.0, 30.0 - (k % 7) * 9.0)
		swarm.rebuild_flow_field()
		times.append(swarm.get_last_flow_build_ms())
	var total: float = 0.0
	for ms in times:
		total += ms
	var sorted: Array[float] = times.duplicate()
	sorted.sort()
	var p95: float = sorted[94]
	_check("A full rebuild on 128×128 costs ≤ 1.0 ms (judged on avg and p95)", ground.get_width() == 128
			and ground.get_depth() == 128 and total / times.size() <= 1.0 and p95 <= 1.0,
			"%d×%d cells: avg %.3f ms, p95 %.3f ms, worst %.3f ms over 100 goals (unoptimized dev build)"
			% [ground.get_width(), ground.get_depth(), total / times.size(), p95, sorted[-1]])


# --- corner cutting (a small hand-made ground) -------------------------------

## A SwarmServer on a 5×5 open grid of 1 m cells from (0, 0), with the listed
## cells closed and the field built toward goal.
func _small_grid(closed: Array[Vector2i], goal: Vector2i) -> SwarmServer:
	var small := SwarmServer.new()
	small.tuning = load(SWARM_TUNING)
	small.capacity = 8
	small.target_move_speed = taln.tuning.move_speed
	small.target_radius = taln.tuning.capsule_radius
	station.add_child(small)
	var heights := PackedFloat32Array()
	heights.resize(25)
	var blocked := PackedByteArray()
	blocked.resize(25)
	for cell in closed:
		blocked[cell.y * 5 + cell.x] = 1
	small.set_ground(heights, blocked, 5, 5, 1.0, Vector2.ZERO)
	var marker := Node3D.new()
	small.add_child(marker)
	marker.global_position = Vector3(goal.x + 0.5, 0.0, goal.y + 0.5)
	small.set_target(marker)
	small.rebuild_flow_field()
	return small


func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)


func _check_corner_cutting() -> void:
	await _fresh()
	var both := _small_grid([Vector2i(2, 1), Vector2i(1, 2)], Vector2i(1, 1))
	var one := _small_grid([Vector2i(2, 1)], Vector2i(1, 1))
	var mirror := _small_grid([Vector2i(1, 2)], Vector2i(1, 1))
	var d_both: float = both.get_flow_distance(_cell_center(Vector2i(2, 2)))
	var d_one: float = one.get_flow_distance(_cell_center(Vector2i(2, 2)))
	var d_mirror: float = mirror.get_flow_distance(_cell_center(Vector2i(2, 2)))
	var d_open: float = one.get_flow_distance(_cell_center(Vector2i(0, 0)))
	_check("No diagonal step past a closed cell: 8 neighbors, corners never cut",
			is_equal_approx(d_open, 1.4) and is_equal_approx(d_one, 2.0) and is_equal_approx(d_mirror, 2.0) and d_both > 2.0,
			"open diagonal %.1f m; either side closed %.1f / %.1f m (around, not 1.4); both closed %.1f m"
			% [d_open, d_one, d_mirror, d_both])
	var pocket := _small_grid([Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3), Vector2i(3, 4)], Vector2i(1, 1))
	_check("A walled-off pocket is unreachable", pocket.get_flow_distance(_cell_center(Vector2i(4, 4))) < 0.0,
			"cell (4, 4) behind closed cells: %.1f" % pocket.get_flow_distance(_cell_center(Vector2i(4, 4))))
	for s: SwarmServer in [both, one, mirror, pocket]:
		s.free()


# --- rebuild triggers ----------------------------------------------------------

func _check_rebuild_on_move() -> void:
	await _fresh()
	await _place_taln(Vector3(10.5, 0.0, 30.5))
	await _ticks(10)
	var idle_from: int = swarm.get_flow_build_count()
	await _ticks(60)
	var idle: int = swarm.get_flow_build_count() - idle_from
	var before: int = swarm.get_flow_build_count()
	taln.global_position = Vector3(12.5, 0.0, 30.5)
	await _ticks(2)  # The next tick without a simulation step.
	var goal: Vector2i = swarm.get_flow_goal_cell()
	_check("Taln changing cell rebuilds the field toward his new cell; standing still doesn't",
			idle == 0 and swarm.get_flow_build_count() == before + 1 and goal == Vector2i(76, 94),
			"%d rebuilds in 1 s standing still; after the move %d, goal cell %s"
			% [idle, swarm.get_flow_build_count() - before, goal])


func _check_rebuild_rate() -> void:
	await _fresh()
	await _place_taln(Vector3(-40.5, 0.0, 30.5))
	var before: int = swarm.get_flow_build_count()
	for k in 120:
		taln.global_position = Vector3(-40.5 + k * 0.6, 0.0, 30.5)
		await _ticks(1)
	var builds: int = swarm.get_flow_build_count() - before
	_check("Rebuilds at most 10 Hz while Taln keeps changing cell", builds >= 18 and builds <= 21,
			"%d rebuilds in 2 s, crossing a cell every ~1.7 ticks" % builds)


func _check_rebuild_on_ground_change() -> void:
	await _fresh()
	await _place_taln(Vector3(-40.5, 0.0, 30.5))
	taln.global_position = Vector3(-39.5, 0.0, 30.5)
	await _ticks(1)
	var before: int = swarm.get_flow_build_count()
	var probe := Vector3(-45.5, 0.0, 40.5)
	var open_before: float = swarm.get_flow_distance(probe)
	# A ring of raised vertices walls the probe cell in.
	for dx in range(-1, 3):
		for dz in range(-1, 3):
			if dx == -1 or dx == 2 or dz == -1 or dz == 2:
				ground.set_height(-46.0 + dx, 40.0 + dz, 2.0)
	ground.rebuild_region(Rect2(-47.0, 39.0, 3.0, 3.0))
	await ground.ground_changed
	# Rebuilds wait for a tick without a simulation step: the next one or the one after.
	await _ticks(2)
	var after: int = swarm.get_flow_build_count() - before
	var walled: float = swarm.get_flow_distance(probe)
	_check("ground_changed rebuilds at once (the next tick without a step), inside the 10 Hz window", after == 1
			and open_before > 0.0 and walled < 0.0, "%d rebuild(s) within two ticks of the edit; the walled-in cell went from %.1f m to %.1f"
			% [after, open_before, walled])


# --- steering --------------------------------------------------------------------

func _check_around_wall() -> void:
	await _fresh()
	await _place_taln(SOUTH_OF_WALL)
	var slots: Array[int] = _spawn_row(ash, Vector3(-4.5, 0.0, -41.0), Vector3(1.0, 0.0, 0.0), 10)
	var took: float = await _until_all_arrive(slots, 20.0)
	_check("Enemies behind WallLong walk around it to Taln (P2-02 left them piled on the wall)", took < 20.0,
			"all 10 within 2 m of Taln after %.1f s" % took if took < INF else "not all arrived in 20 s")


func _check_up_plateau() -> void:
	await _fresh()
	await _place_taln(PLATEAU_TOP + Vector3.UP * 0.1)
	var slots: Array[int] = _spawn_row(ash, Vector3(-4.5, 0.0, -16.0), Vector3(1.0, 0.0, 0.0), 10)
	var took: float = await _until_all_arrive(slots, 30.0)
	_check("Enemies below the plateau's north cliff climb a ramp to Taln on top", took < 30.0,
			"all 10 on top within 2 m of Taln after %.1f s" % took if took < INF else "not all arrived in 30 s")


## Direction of an enemy's next few steps (one enemy alone, no separation);
## zero if it moved less than MOVED_M, so a stuck enemy never passes as
## heading the right way.
func _heading(slot: int, steps: int, server: SwarmServer = null) -> Vector2:
	var s: SwarmServer = server if server else swarm
	var from: Vector3 = s.get_enemy_position(slot)
	await _ticks(steps * 2)
	var moved: Vector2 = _flat(s.get_enemy_position(slot) - from)
	return moved.normalized() if moved.length() >= MOVED_M else Vector2.ZERO


## Degrees between a heading and a direction; 180 for a zero heading.
func _off(heading: Vector2, direction: Vector2) -> float:
	return 180.0 if heading.is_zero_approx() else rad_to_deg(absf(heading.angle_to(direction)))


func _check_direct_in_sight() -> void:
	await _fresh()
	await _place_taln(SOUTH_OF_WALL)
	var at := Vector3(18.0, 0.0, -22.0)
	var slot: int = swarm.spawn(ash, at, 1.0, 1.0)
	var direct: Vector2 = _flat(SOUTH_OF_WALL - at).normalized()
	var heading: Vector2 = await _heading(slot, 3)
	_check("In plain sight an enemy seeks Taln in a straight line", _off(heading, direct) < 1.0,
			"heading %.2f° off the straight line" % _off(heading, direct))


func _check_direct_when_close() -> void:
	await _fresh()
	# One side of the diagonal is closed, so the field steps around (west) but
	# the goal is 2 m away along it: inside the 3 m direct range.
	var small := _small_grid([Vector2i(2, 1)], Vector2i(1, 1))
	var slot: int = small.spawn(ash, _cell_center(Vector2i(2, 2)) + Vector3(0.2, 0.0, 0.2), 1.0, 1.0)
	var from: Vector3 = small.get_enemy_position(slot)
	var flow: Vector3 = small.get_flow_direction(from)
	var heading: Vector2 = await _heading(slot, 1, small)
	var direct: Vector2 = Vector2(-1.0, -1.0).normalized()
	_check("Within 3 m along the field an enemy seeks directly, not along the field", not small.is_flow_line_clear(from)
			and _off(heading, direct) < 1.0 and _off(_flat(flow), direct) > 10.0,
			"heading %.1f° off straight at Taln; the field there points %.0f° off"
			% [_off(heading, direct), _off(_flat(flow), direct)])
	small.free()


func _check_close_but_far_along_field() -> void:
	await _fresh()
	# Taln on the plateau just inside its north tip, the enemy below the cliff:
	# 2.7 m apart in a straight line, but the way up is by a ramp.
	await _place_taln(Vector3(0.5, 1.6, -10.5))
	var at := Vector3(0.5, 0.0, -13.2)
	var slot: int = swarm.spawn(ash, at, 1.0, 1.0)
	var straight: float = _flat_dist(at, taln.global_position)
	var along: float = swarm.get_flow_distance(at)
	var flow: Vector2 = _flat(swarm.get_flow_direction(at))
	var heading: Vector2 = await _heading(slot, 3)
	var direct: Vector2 = _flat(taln.global_position - at).normalized()
	_check("'Within 3 m' is measured along the field: under the cliff Taln stands on, an enemy walks for a ramp",
			straight < 3.0 and along > 20.0 and _off(heading, flow) < 20.0 and _off(heading, direct) > 45.0,
			"%.1f m straight, %.1f m along the field; heading %.0f° off the field, %.0f° off straight at Taln"
			% [straight, along, _off(heading, flow), _off(heading, direct)])


func _check_direct_when_unreachable() -> void:
	await _fresh()
	await _place_taln(HIGH_STEP_PLATFORM + Vector3.UP * 0.1)
	var at := Vector3(-34.2, 0.0, 14.0)
	var slot: int = swarm.spawn(ash, at, 1.0, 1.0)
	var direct: Vector2 = _flat(taln.global_position - at).normalized()
	var heading: Vector2 = await _heading(slot, 3)
	_check("Where Taln can't be reached, enemies seek him directly", swarm.get_flow_distance(at) < 0.0
			and swarm.get_flow_distance(taln.global_position) == 0.0 and _off(heading, direct) < 1.0,
			"field distance from the enemy %.1f (Taln's cell %.1f); heading %.2f° off straight"
			% [swarm.get_flow_distance(at), swarm.get_flow_distance(taln.global_position), _off(heading, direct)])


func _check_hunters() -> void:
	await _fresh()
	await _place_taln(SOUTH_OF_WALL)
	var hunter: SwarmType = load(NOTICE_HUNTER)
	var slots: Array[int] = _spawn_row(hunter, Vector3(-1.5, 0.0, -41.0), Vector3(1.5, 0.0, 0.0), 3)
	var took: float = await _until_all_arrive(slots, 20.0)
	_check("Notice hunters use the field too", took < 20.0,
			"3 hunters from behind WallLong within 2 m of Taln after %.1f s" % took if took < INF else "not all arrived in 20 s")


func _check_rooted() -> void:
	await _fresh()
	await _place_taln(SOUTH_OF_WALL)
	var at := Vector3(0.0, 0.0, -41.0)
	var slot: int = swarm.spawn(ash, at, 1.0, 1.0)
	swarm.apply_root_in_cone(at + Vector3(0.0, 0.0, -1.0), Vector3.BACK, 60.0, 3.0, 1.5)
	var held: Vector3 = swarm.get_enemy_position(slot)
	await _ticks(60)
	var still: float = _flat_dist(swarm.get_enemy_position(slot), held)
	await _ticks(30)
	var flow: Vector2 = _flat(swarm.get_flow_direction(swarm.get_enemy_position(slot)))
	var heading: Vector2 = await _heading(slot, 3)
	_check("Rooted enemies ignore the field; they follow it once the root ends", still < 0.001
			and _off(heading, flow) < 30.0 and absf(heading.x) > 0.5,
			"moved %.3f m in 1 s rooted; after, heading %s, %.0f° off the field (around the wall's end)"
			% [still, heading, _off(heading, flow)])


# --- acceptance ---------------------------------------------------------------------

## Per enemy (by spawn, keyed by slot): where it last moved to and when.
var _anchor_at: Dictionary[int, Vector3] = {}
var _anchor_tick: Dictionary[int, int] = {}
var _stuck: Dictionary[int, bool] = {}
var _types: Dictionary[int, SwarmType] = {}


func _track_spawn(slot: int, type: SwarmType, stats: Dictionary) -> void:
	if slot < 0:
		return
	_anchor_at[slot] = swarm.get_enemy_position(slot)
	_anchor_tick[slot] = tick
	_stuck[slot] = false
	_types[slot] = type
	stats.seen += 1


## One sample: an enemy that stays within 0.5 m of one spot for 3 s while not
## rooted and not touching Taln counts as stationary (once per enemy). Those
## more than CROWD_M from Taln are counted apart: they aren't in the crowd
## around him, so they would be piled on geometry.
func _sample_stationary(stats: Dictionary) -> void:
	for slot: int in _anchor_at:
		if not swarm.is_enemy_alive(slot):
			continue
		var p: Vector3 = swarm.get_enemy_position(slot)
		var excused: bool = swarm.get_enemy_root_time(slot) > 0.0 or _touching(slot, _types[slot])
		if excused or _flat_dist(p, _anchor_at[slot]) > 0.5:
			_anchor_at[slot] = p
			_anchor_tick[slot] = tick
		elif tick - _anchor_tick[slot] > 180 and not _stuck[slot]:
			_stuck[slot] = true
			stats.stuck += 1
			if _flat_dist(p, taln.global_position) > CROWD_M:
				stats.stuck_far += 1
				if stats.log.size() < 6:
					stats.log.append("(%.1f, %.1f) at %.0f s" % [p.x, p.z, tick / 60.0])


## Two minutes: Taln parked behind WallLong, then on the plateau, the spawner
## running from wave 1 and a Notice pack joining each half.
func _acceptance_run(weapon: bool, flow: bool = true) -> Dictionary:
	await _fresh()
	if not flow:
		# Everything within this range seeks directly: the P2-02 behavior.
		var off: SwarmTuning = swarm.tuning.duplicate()
		off.flow_direct_range = 100000.0
		swarm.tuning = off
	if weapon:
		taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT
	_anchor_at.clear()
	_anchor_tick.clear()
	_stuck.clear()
	_types.clear()
	var stats: Dictionary = {"seen": 0, "stuck": 0, "stuck_far": 0, "peak": 0, "killed": 0, "log": []}
	spawner.spawned.connect(func(slot: int, _at: Vector3) -> void: _track_spawn(slot, spawner.swarm_type, stats))
	spawner.pack_spawned.connect(func(_id: StringName, slots: Array[int]) -> void:
		for s in slots:
			_track_spawn(s, taln.toauma.tuning.notice_hunter_type, stats))
	swarm.enemy_died.connect(func(_id: StringName, _at: Vector3, rewarded: bool) -> void:
		if rewarded:
			stats.killed += 1)
	spawner.paused = false
	for at: Vector3 in [NORTH_OF_WALL, PLATEAU_TOP + Vector3.UP * 0.1]:
		await _place_taln(at)
		taln.toauma.add_strain(3.0)
		for k in 60 * 60:
			await _ticks(1)
			if k % 2 == 0:
				_sample_stationary(stats)
			stats.peak = maxi(stats.peak, swarm.get_alive_count())
	spawner.paused = true
	return stats


func _check_acceptance() -> void:
	var run: Dictionary = await _acceptance_run(true)
	var share: float = float(run.stuck) / maxf(run.seen, 1.0)
	_check("ACCEPT  2 min, Taln behind a wall then on the plateau: < 5% of enemies ever stationary > 3 s (not rooted, not touching Taln)",
			run.seen > 100 and share < 0.05, "%d of %d enemies (%.1f%%), %d of them over %.0f m from Taln; peak %d alive, %d killed%s"
			% [run.stuck, run.seen, share * 100.0, run.stuck_far, CROWD_M, run.peak, run.killed,
			"; far ones: " + ", ".join(run.log) if not run.log.is_empty() else ""])
	var idle: Dictionary = await _acceptance_run(false)
	var far_share: float = float(idle.stuck_far) / maxf(idle.seen, 1.0)
	_check("ACCEPT  Same run with the weapon off, so the crowd builds: < 5% stationary > 3 s away from the crowd around Taln",
			idle.seen > 100 and far_share < 0.05, ("%d of %d enemies (%.1f%%) more than %.0f m from Taln; %d in all "
			+ "(%.1f%%) counting the crowd packed around him; peak %d alive%s")
			% [idle.stuck_far, idle.seen, far_share * 100.0, CROWD_M, idle.stuck, 100.0 * idle.stuck / maxf(idle.seen, 1.0),
			idle.peak, "; far ones: " + ", ".join(idle.log) if not idle.log.is_empty() else ""])
	var off: Dictionary = await _acceptance_run(true, false)
	var off_share: float = float(off.stuck) / maxf(off.seen, 1.0)
	_check("Negative control: with the field off (P2-02 steering) the same measure catches the pile-up",
			off_share >= 0.05, "%d of %d enemies (%.1f%%) stationary > 3 s; peak %d alive"
			% [off.stuck, off.seen, off_share * 100.0, off.peak])


# --- performance ------------------------------------------------------------------

func _spawn_ring(count: int, center: Vector3, near: float, far: float) -> void:
	var spawned: int = 0
	var k: int = 0
	while spawned < count:
		var angle: float = k * 2.39996
		var at: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * (near + fmod(k * 0.37, far - near))
		k += 1
		if not ground.is_blocked_at(at.x, at.z):
			swarm.spawn(ash, at, 1.0, 1.0)
			spawned += 1


func _check_step_budget() -> void:
	await _fresh()
	await _place_taln(NORTH_OF_WALL)
	_spawn_ring(400, SOUTH_OF_WALL, 4.0, 26.0)
	var total: float = 0.0
	var worst: float = 0.0
	var worst_tick: float = 0.0
	var builds: Array[float] = []
	var last_count: int = swarm.get_flow_build_count()
	for f in 300:
		# Taln paces behind the wall, so the field keeps rebuilding.
		taln.global_position = NORTH_OF_WALL + Vector3(sin(f * 0.05) * 6.0, 0.0, 0.0)
		await _ticks(1)
		worst_tick = maxf(worst_tick, swarm.get_last_tick_ms())
		if f % 2 == 1:
			total += swarm.get_last_step_ms()
			worst = maxf(worst, swarm.get_last_step_ms())
		if swarm.get_flow_build_count() != last_count:
			last_count = swarm.get_flow_build_count()
			builds.append(swarm.get_last_flow_build_ms())
	var build_worst: float = 0.0
	var build_total: float = 0.0
	for ms in builds:
		build_total += ms
		build_worst = maxf(build_worst, ms)
	_check("SwarmServer step < 2 ms at 400 alive routing around WallLong, the field rebuilding as Taln paces",
			worst < 2.0 and worst_tick < 2.0 and swarm.get_alive_count() == 400 and builds.size() >= 10,
			("step avg %.3f ms, worst %.3f ms; %d rebuilds avg %.3f ms, worst %.3f ms, on ticks without a step; "
			+ "worst whole tick %.3f ms") % [total / 150.0, worst, builds.size(), build_total / maxf(builds.size(), 1.0),
			build_worst, worst_tick])


func _check_frame_cost() -> void:
	await _fresh()
	taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT
	await _place_taln(NORTH_OF_WALL)
	var samples: PackedFloat32Array = []
	for f in 1200:
		_spawn_ring(400 - swarm.get_alive_count(), taln.global_position, 18.0, 26.0)
		taln.global_position = NORTH_OF_WALL + Vector3(sin(f * 0.02) * 8.0, 0.0, 0.0)
		var before: int = Time.get_ticks_usec()
		await _ticks(1)
		samples.append((Time.get_ticks_usec() - before) / 1000.0)
	var total: float = 0.0
	for ms in samples:
		total += ms
	var sorted: PackedFloat32Array = samples.duplicate()
	sorted.sort()
	var p99: float = sorted[int(sorted.size() * 0.99)]
	_check("400 alive with the field in use and the weapon swinging: frame cost fits 60 fps (CPU side)",
			total / samples.size() < 4.0 and p99 < 4.0, "avg %.3f ms, p99 %.3f ms, worst %.3f ms over 20 s"
			% [total / samples.size(), p99, sorted[-1]])
