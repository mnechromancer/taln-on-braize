extends SceneTree
## P2-02 (SwarmServer v0) checks, run headless against the real station scene
## at a fixed 60 fps. Prints PASS/FAIL per check (INFO lines are not judged)
## and exits with the number of failures.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_02_checks.gd

const STATION := "res://scenes/graybox_station.tscn"
const ASH_WALKER := "res://data/swarm/ash_walker.tres"
const SWARM_TUNING := "res://data/tuning/swarm_tuning.tres"

var station: GrayboxStation
var ground: StationGround
var failures: int = 0
var changes: Array[Rect2i] = []
var taln: Taln
var swarm: SwarmServer
var ash: SwarmType
var tick: int = 0
## [tick, damage, type] per taln_contacted.
var contacts: Array = []
## [type_id, position] per enemy_died.
var deaths: Array = []
var station_swarm: SwarmServer
var spawner: SpawnDirector


func _init() -> void:
	_run()


func _run() -> void:
	station = (load(STATION) as PackedScene).instantiate()
	root.add_child(station)
	ground = station.get_node("StationGround")
	taln = station.get_node("Taln")
	ash = load(ASH_WALKER)
	# The station's own spawner stays off until the integration checks.
	(station.get_node("SpawnDirector") as SpawnDirector).paused = true
	ground.ground_changed.connect(func(rect: Rect2i) -> void: changes.append(rect))
	await ground.ground_changed

	_check_first_sample()
	_check_layout()
	_check_tuning()
	_check_surfaces()
	_check_reachability()
	_check_walls()
	await _check_edit()
	_report_sample_time()

	print("")
	_check_swarm_data()
	await _check_seek()
	await _check_contact()
	await _check_blocked_cells()
	await _check_ramp_height()
	await _check_separation()
	await _check_damage()
	await _check_cone()
	await _check_impulse()
	await _check_free_list()
	await _check_rendering()
	if swarm:
		swarm.free()
		swarm = null

	print("")
	await _check_spawner_placement()
	await _check_wave_density()
	await _check_bank_cap()
	await _check_contact_drain()
	await _check_shoulder_knockback()
	await _check_debug_blast()
	await _check_live_tuning()
	await _check_step_budget()
	print("")
	print("MANUAL  Enemy look: prism, eyes, bob, hit flash and fade-in need a rendered run.")
	print("MANUAL  60 fps at 400 alive, and fps at 800 in F6 stress mode, need a rendered run.")
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


## Cell index containing world XZ (x, z).
func _cell(x: float, z: float) -> Vector2i:
	var origin: Vector2 = ground.get_origin()
	return Vector2i(floori((x - origin.x) / ground.get_cell_size()), floori((z - origin.y) / ground.get_cell_size()))


func _index(cell: Vector2i) -> int:
	return cell.y * ground.get_width() + cell.x


func _blocked_at(x: float, z: float) -> bool:
	return ground.get_blocked_mask()[_index(_cell(x, z))] == 1


func _height_at(x: float, z: float) -> float:
	return ground.get_height_array()[_index(_cell(x, z))]


## Point on a plateau ramp's centerline, `along` meters out from its top edge.
func _ramp_point(face: int, along: float) -> Vector2:
	var face_step: float = TAU / 9.0
	var normal := Vector2(sin(face_step * face), cos(face_step * face))
	return normal * (12.0 * cos(face_step / 2.0) + along)


## Walkable cells 4-connected to start.
func _reachable(start: Vector2i) -> Dictionary:
	var mask: PackedByteArray = ground.get_blocked_mask()
	var seen := {start: true}
	var frontier: Array[Vector2i] = [start]
	var bounds := Rect2i(0, 0, ground.get_width(), ground.get_depth())
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + offset
			if bounds.has_point(next) and not seen.has(next) and mask[_index(next)] == 0:
				seen[next] = true
				frontier.append(next)
	return seen


# --- checks ------------------------------------------------------------------

func _check_first_sample() -> void:
	var full := Rect2i(0, 0, ground.get_width(), ground.get_depth())
	_check("First sample covers the whole ground", changes == [full] and ground.is_ground_data_ready(),
			"ground_changed %s, ready %s" % [changes, ground.is_ground_data_ready()])


func _check_layout() -> void:
	var cells: int = ground.get_width() * ground.get_depth()
	_check("Grid layout", ground.get_width() == 128 and ground.get_depth() == 128
			and is_equal_approx(ground.get_cell_size(), 1.0) and ground.get_origin().is_equal_approx(Vector2(-64.0, -64.0)),
			"%dx%d cells of %.2f m from %s" % [ground.get_width(), ground.get_depth(), ground.get_cell_size(), ground.get_origin()])
	_check("Array sizes", ground.get_height_array().size() == cells and ground.get_blocked_mask().size() == cells,
			"heights %d, mask %d, expected %d" % [ground.get_height_array().size(), ground.get_blocked_mask().size(), cells])


func _check_tuning() -> void:
	var t: StationGroundTuning = ground.tuning
	_check("Ground tuning matches spec §7.1 (Taln's slope and step)",
			is_equal_approx(t.max_slope_deg, 40.0) and is_equal_approx(t.max_step_m, 0.35)
			and is_equal_approx(t.max_slope_deg, taln.tuning.max_slope_deg)
			and is_equal_approx(t.max_step_m, taln.tuning.step_height),
			"slope %.1f°, step %.2f m" % [t.max_slope_deg, t.max_step_m])


func _check_surfaces() -> void:
	_check("Open ground under Taln's spawn is walkable at 0 m", not _blocked_at(0.0, 30.0) and absf(_height_at(0.0, 30.0)) < 0.01,
			"blocked %s, height %.2f (Taln stands there; rays skip characters)" % [_blocked_at(0.0, 30.0), _height_at(0.0, 30.0)])
	_check("Plateau top is walkable at 1.5 m", not _blocked_at(0.0, 0.0) and absf(_height_at(0.0, 0.0) - 1.5) < 0.01,
			"blocked %s, height %.2f" % [_blocked_at(0.0, 0.0), _height_at(0.0, 0.0)])
	var cliff: int = 0
	for z in range(0, 20):
		if _blocked_at(0.5, -z - 0.5):
			cliff += 1
	_check("Plateau cliff (1.5 m, no ramp) is blocked", cliff > 0, "%d blocked cells on the line south to north" % cliff)

	var ramp20: Vector2 = _ramp_point(0, 2.0)
	var ramp35: Vector2 = _ramp_point(3, 1.0)
	var ramp45: Vector2 = _ramp_point(6, 0.75)
	_check("20° ramp is walkable", not _blocked_at(ramp20.x, ramp20.y), "mid-ramp %s" % ramp20)
	_check("35° ramp is walkable", not _blocked_at(ramp35.x, ramp35.y), "mid-ramp %s" % ramp35)
	_check("45° ramp is blocked (over 40°)", _blocked_at(ramp45.x, ramp45.y), "mid-ramp %s" % ramp45)


func _check_reachability() -> void:
	var reach: Dictionary = _reachable(_cell(0.0, 30.0))
	_check("Plateau top reachable from the spawn", reach.has(_cell(0.0, 0.0)), "via the 20° / 35° ramps")
	_check("Ledge top reachable from the spawn", reach.has(_cell(33.0, 0.0)), "via the 20° ledge ramp")
	_check("0.4 m-step platform unreachable", not reach.has(_cell(-34.2, 0.0)), "steps above 0.35 m")
	# 0.6 m treads under 1 m cells mean neighbors can differ by two 0.3 m risers.
	_info("0.3 m-step platform reachable: %s" % reach.has(_cell(34.2, -14.0)),
			"1 m cells alias the 0.6 m treads; Taln can climb these, the data may not")


func _check_walls() -> void:
	var origin: Vector2 = ground.get_origin()
	var covered_ok := true
	var count: int = 0
	for node: Node in station.get_tree().get_nodes_in_group(StationGround.WALL_BLOCK_GROUP):
		var box: CSGBox3D = node
		var lo := Vector2(box.global_position.x - box.size.x * 0.5, box.global_position.z - box.size.z * 0.5)
		var hi := Vector2(box.global_position.x + box.size.x * 0.5, box.global_position.z + box.size.z * 0.5)
		for z in range(floori(lo.y - origin.y), ceili(hi.y - origin.y)):
			for x in range(floori(lo.x - origin.x), ceili(hi.x - origin.x)):
				count += 1
				if ground.get_blocked_mask()[_index(Vector2i(x, z))] == 0:
					covered_ok = false
	_check("Every cell under a wall block is blocked", count > 0 and covered_ok,
			"%d cells under %d walls" % [count, station.get_tree().get_nodes_in_group(StationGround.WALL_BLOCK_GROUP).size()])
	_check("Ground two cells off WallBlock stays walkable", not _blocked_at(-24.0, -26.5), "at (-24, -26.5)")


func _check_edit() -> void:
	changes.clear()
	ground.set_height(-40.0, 40.0, 1.0)
	ground.rebuild_region(Rect2(-40.0, 40.0, 0.0, 0.0))
	await ground.ground_changed
	var expected := Rect2i(22, 102, 4, 4)
	_check("Edit announces the touched cells plus one", changes == [expected], "got %s, expected %s" % [changes, expected])
	_check("A 1 m bump on one vertex blocks the cells around it",
			_blocked_at(-40.5, 39.5) and _blocked_at(-39.5, 40.5) and not _blocked_at(-43.5, 40.5),
			"heights %.2f / %.2f" % [_height_at(-40.5, 39.5), _height_at(-39.5, 40.5)])

	ground.set_height(-40.0, 40.0, 0.0)
	ground.rebuild_region(Rect2(-40.0, 40.0, 0.0, 0.0))
	await ground.ground_changed
	_check("Flattening it again unblocks them", not _blocked_at(-40.5, 39.5) and not _blocked_at(-39.5, 40.5), "")


func _report_sample_time() -> void:
	var start: int = Time.get_ticks_usec()
	ground._sample(Rect2i(0, 0, ground.get_width(), ground.get_depth()))
	_info("Full resample of %d cells" % (ground.get_width() * ground.get_depth()),
			"%.1f ms in GDScript" % ((Time.get_ticks_usec() - start) / 1000.0))


# --- swarm helpers -----------------------------------------------------------

func _ticks(count: int) -> void:
	for i in count:
		await physics_frame
		tick += 1


## A new SwarmServer on the station's ground, chasing Taln unless told not to.
func _fresh_swarm(capacity: int = 800, chase: bool = true) -> void:
	if swarm:
		swarm.free()
	swarm = SwarmServer.new()
	swarm.tuning = load(SWARM_TUNING)
	swarm.capacity = capacity
	swarm.target_move_speed = taln.tuning.move_speed
	swarm.target_radius = taln.tuning.capsule_radius
	station.add_child(swarm)
	swarm.set_ground(ground.get_height_array(), ground.get_blocked_mask(), ground.get_width(),
			ground.get_depth(), ground.get_cell_size(), ground.get_origin())
	swarm.set_target(taln if chase else null)
	contacts.clear()
	deaths.clear()
	swarm.taln_contacted.connect(func(damage: float, type: int) -> void: contacts.append([tick, damage, type]))
	swarm.enemy_died.connect(func(id: StringName, at: Vector3) -> void: deaths.append([id, at]))


func _place_taln(at: Vector3) -> void:
	taln.global_position = at
	taln.velocity = Vector3.ZERO
	await _ticks(2)


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


# --- swarm checks --------------------------------------------------------------

func _check_swarm_data() -> void:
	var ok: bool = ash.id == &"ash_walker" and ash.family == 0 and ash.hp == 12.0 and ash.contact_damage == 6.0 \
			and ash.contact_damage_type == Damage.Type.KINETIC \
			and ash.speed_min == 3.2 and ash.speed_max == 4.6 and ash.mass == 1.0 and ash.radius == 0.35 \
			and ash.separation_weight == 1.5 and ash.resist_kinetic == 1.0 and ash.resist_void == 1.0 \
			and ash.resist_blight == 1.0 and ash.spawn_cost == 1 and ash.behavior == SwarmType.BEHAVIOR_SEEK \
			and ash.mesh != null and ash.material != null
	_check("ash_walker.tres holds the step 2 values", ok, "hp %s, dmg %s, speed %s–%s, radius %s" %
			[ash.hp, ash.contact_damage, ash.speed_min, ash.speed_max, ash.radius])
	var t: SwarmTuning = load(SWARM_TUNING)
	_check("Swarm tuning", t.step_rate == 30.0 and t.grid_cell_size == 2.0 and t.max_speed_ratio == 0.8
			and t.impulse_decay == 8.0 and t.contact_cooldown == 0.75 and t.hit_flash_time == 0.1,
			"%s Hz, %s m grid, cap %s, decay %s/s, contact %s s, flash %s s" % [t.step_rate, t.grid_cell_size,
			t.max_speed_ratio, t.impulse_decay, t.contact_cooldown, t.hit_flash_time])


func _check_seek() -> void:
	_fresh_swarm()
	await _place_taln(Vector3(0.0, 0.0, 30.0))
	var slot: int = swarm.spawn(ash, Vector3(-15.0, 0.0, 30.0), 1.0, 1.0)
	var start: Vector3 = swarm.get_enemy_position(slot)
	await _ticks(60)
	var moved: Vector3 = swarm.get_enemy_position(slot) - start
	_check("Seeks Taln at its rolled speed (3.2–4.6 m/s)", moved.x > 0.0 and absf(moved.z) < 0.05
			and moved.length() >= 3.2 - 0.01 and moved.length() <= 4.6 + 0.01,
			"%.2f m in 1 s along %s" % [moved.length(), moved.normalized()])

	_fresh_swarm()
	swarm.target_move_speed = 3.5
	var slots: Array[int] = []
	for k in 10:
		slots.append(swarm.spawn(ash, Vector3(-15.0, 0.0, 21.0 + k * 2.0), 1.0, 1.0))
	var starts: Array[Vector3] = []
	for s in slots:
		starts.append(swarm.get_enemy_position(s))
	await _ticks(60)
	var fastest: float = 0.0
	for k in slots.size():
		fastest = maxf(fastest, _flat(swarm.get_enemy_position(slots[k]) - starts[k]).length())
	_check("Top speed capped at 80% of Taln's", fastest <= 2.8 + 0.01,
			"Taln at 3.5 m/s, fastest of 10: %.2f m/s" % fastest)


func _check_contact() -> void:
	_fresh_swarm()
	await _place_taln(Vector3(0.0, 0.0, 30.0))
	swarm.spawn(ash, Vector3(3.0, 0.0, 30.0), 1.0, 1.0)
	swarm.spawn(ash, Vector3(-3.0, 0.0, 30.0), 1.0, 2.0)
	var touch: float = taln.tuning.capsule_radius + ash.radius
	var closest: float = INF
	var start: int = tick
	for k in 180:
		await _ticks(1)
		for s: int in [0, 1]:
			closest = minf(closest, _flat(swarm.get_enemy_position(s) - taln.global_position).length())
	_check("Enemies are pushed out of Taln's radius", closest >= touch - 0.001,
			"closest %.3f m, touching at %.2f m" % [closest, touch])

	var ok := true
	var detail: Array[String] = []
	for damage: float in [6.0, 12.0]:
		var at: Array[int] = []
		for c: Array in contacts:
			if is_equal_approx(c[1], damage):
				at.append(c[0] - start)
				ok = ok and c[2] == Damage.Type.KINETIC
		for k in range(1, at.size()):
			ok = ok and at[k] - at[k - 1] >= 45
		ok = ok and at.size() >= 3 and at.size() <= 5
		detail.append("%s dmg at ticks %s" % [damage, at])
	_check("Contact damage at most once per 0.75 s per enemy, times its damage multiplier",
			ok and contacts.size() > 0, "; ".join(detail))


func _check_blocked_cells() -> void:
	_fresh_swarm()
	await _place_taln(Vector3(0.0, 0.0, 30.0))
	var mask: PackedByteArray = ground.get_blocked_mask()
	var spots: Array[Vector3] = []
	for k in 20:
		spots.append(Vector3(-9.5 + k, 0.0, -41.0))  # North of WallLong.
	for k in 10:
		spots.append(Vector3(-28.5 + k, 0.0, -35.0))  # North of WallBlock.
	for k in 10:
		spots.append(Vector3(-4.5 + k, 0.0, -16.5))  # Behind the plateau.
	for at in spots:
		swarm.spawn(ash, at, 1.0, 1.0)
	var inside: int = 0
	for k in 300:
		await _ticks(2)
		for s in spots.size():
			var p: Vector3 = swarm.get_enemy_position(s)
			if mask[_index(_cell(p.x, p.z))] == 1:
				inside += 1
	var past_wall: int = 0
	for s in 20:
		if swarm.get_enemy_position(s).z > -35.0:
			past_wall += 1
	_check("No enemy enters a blocked cell in 10 s", inside == 0, "%d samples inside, 40 enemies" % inside)
	_info("Enemies that slid around WallLong in 10 s: %d of 20" % past_wall, "they spawned 5 m behind it")


func _check_ramp_height() -> void:
	_fresh_swarm()
	await _place_taln(Vector3(0.0, 1.5, 0.0))
	var slot: int = swarm.spawn(ash, Vector3(0.0, 0.0, 22.0), 1.0, 1.0)
	var worst: float = 0.0
	var samples: int = 0
	var top_edge: float = 12.0 * cos(TAU / 18.0)
	# 8 s: 22 m at the slowest rolled speed (3.2 m/s) takes 6.6 s.
	for k in 480:
		await _ticks(1)
		var p: Vector3 = swarm.get_enemy_position(slot)
		if p.z > top_edge + 1.0 and p.z < top_edge + 3.0:
			var expected: float = 1.5 - (p.z - top_edge) * tan(deg_to_rad(20.0))
			worst = maxf(worst, absf(p.y - expected))
			samples += 1
	var top: Vector3 = swarm.get_enemy_position(slot)
	_check("Height follows the 20° ramp", samples > 0 and worst < 0.15,
			"%d samples mid-ramp, worst %.3f m off" % [samples, worst])
	_check("Reaches the plateau top at 1.5 m", absf(top.y - 1.5) < 0.02 and top.z < 2.0, "ended at %s" % top)


func _check_separation() -> void:
	_fresh_swarm()
	await _place_taln(Vector3(0.0, 0.0, 30.0))
	var count: int = 20
	for k in count:
		swarm.spawn(ash, Vector3(-20.0, 0.0, 0.0), 1.0, 1.0)
	await _ticks(90)
	var closest: float = INF
	for a in count:
		for b in range(a + 1, count):
			closest = minf(closest, _flat(swarm.get_enemy_position(a) - swarm.get_enemy_position(b)).length())
	_check("Separation spreads 20 enemies spawned on one point", closest > 0.3,
			"closest pair %.2f m after 1.5 s" % closest)


func _check_damage() -> void:
	_fresh_swarm(800, false)
	var a: int = swarm.spawn(ash, Vector3(-30.0, 0.0, -10.0), 1.0, 1.0)
	swarm.spawn(ash, Vector3(-30.0, 0.0, -8.5), 1.0, 1.0)
	swarm.spawn(ash, Vector3(-30.0, 0.0, -5.0), 1.0, 1.0)
	var center := Vector3(-30.0, 0.0, -9.25)
	var hits: int = swarm.apply_damage_in_radius(center, 1.0, 5.0, Damage.Type.KINETIC)
	await _ticks(4)
	_check("Radius damage hits the enemies in range", hits == 2 and deaths.is_empty() and swarm.get_alive_count() == 3,
			"%d hit, %d died" % [hits, deaths.size()])
	var at_a: Vector3 = swarm.get_enemy_position(a)
	hits = swarm.apply_damage_in_radius(center, 1.0, 7.0, Damage.Type.KINETIC)
	var again: int = swarm.apply_damage_in_radius(center, 1.0, 7.0, Damage.Type.KINETIC)
	await _ticks(4)
	_check("Enemies at 0 HP die on the next step with enemy_died(type_id, position)",
			hits == 2 and again == 0 and deaths.size() == 2 and deaths[0][0] == &"ash_walker"
			and _flat(deaths[0][1] - at_a).length() < 0.01 and swarm.get_alive_count() == 1,
			"%d hit, then %d (already dead), %d died, alive %d" % [hits, again, deaths.size(), swarm.get_alive_count()])

	var resistant: SwarmType = ash.duplicate()
	resistant.resist_void = 0.5
	deaths.clear()
	swarm.spawn(resistant, Vector3(-30.0, 0.0, 5.0), 1.0, 1.0)
	swarm.apply_damage_in_radius(Vector3(-30.0, 0.0, 5.0), 0.1, 12.0, Damage.Type.VOID)
	await _ticks(4)
	var survived: bool = deaths.is_empty()
	swarm.apply_damage_in_radius(Vector3(-30.0, 0.0, 5.0), 0.1, 6.0, Damage.Type.KINETIC)
	await _ticks(4)
	_check("Damage is scaled by the type's resistance", survived and deaths.size() == 1,
			"12 Void at 0.5 resist left it alive: %s; 6 Kinetic then killed it: %s" % [survived, deaths.size() == 1])

	deaths.clear()
	swarm.spawn(ash, Vector3(-30.0, 0.0, 10.0), 2.0, 1.0)
	swarm.apply_damage_in_radius(Vector3(-30.0, 0.0, 10.0), 0.1, 12.0, Damage.Type.KINETIC)
	await _ticks(4)
	survived = deaths.is_empty()
	swarm.apply_damage_in_radius(Vector3(-30.0, 0.0, 10.0), 0.1, 12.0, Damage.Type.KINETIC)
	await _ticks(4)
	_check("HP multiplier scales spawn HP", survived and deaths.size() == 1, "hp_mult 2 took two 12-damage hits")


func _check_cone() -> void:
	_fresh_swarm(800, false)
	var origin := Vector3(20.0, 0.0, -20.0)
	swarm.spawn(ash, origin + Vector3(5.0, 0.0, 0.0), 1.0, 1.0)  # Ahead.
	swarm.spawn(ash, origin + Vector3(5.0 * cos(PI / 3.0), 0.0, 5.0 * sin(PI / 3.0)), 1.0, 1.0)  # 60° off.
	swarm.spawn(ash, origin + Vector3(-5.0, 0.0, 0.0), 1.0, 1.0)  # Behind.
	swarm.spawn(ash, origin + Vector3(9.0, 0.0, 0.0), 1.0, 1.0)  # Past the range.
	var narrow: int = swarm.apply_damage_in_cone(origin, Vector3.RIGHT, 90.0, 8.0, 1.0, Damage.Type.KINETIC)
	var wide: int = swarm.apply_damage_in_cone(origin, Vector3.RIGHT, 150.0, 8.0, 1.0, Damage.Type.KINETIC)
	_check("Cone damage (angle_deg is the full width)", narrow == 1 and wide == 2,
			"90°: %d hit, 150°: %d hit" % [narrow, wide])
	var near: int = swarm.query_count_in_radius(origin, 5.0)
	_check("Query counts enemies in a radius", near == 3 and swarm.query_count_in_radius(origin, 1.0) == 0,
			"%d within 5 m" % near)


func _check_impulse() -> void:
	_fresh_swarm(800, false)
	var heavy: SwarmType = ash.duplicate()
	heavy.mass = 2.0
	var light: int = swarm.spawn(ash, Vector3(-40.0, 0.0, 20.0), 1.0, 1.0)
	var slow: int = swarm.spawn(heavy, Vector3(-40.0, 0.0, 30.0), 1.0, 1.0)
	swarm.apply_impulse_in_radius(Vector3(-40.5, 0.0, 20.0), 1.0, 3.0)
	swarm.apply_impulse_in_radius(Vector3(-40.5, 0.0, 30.0), 1.0, 3.0)
	await _ticks(120)
	var pushed: Vector3 = swarm.get_enemy_position(light) - Vector3(-40.0, 0.0, 20.0)
	var pushed_heavy: Vector3 = swarm.get_enemy_position(slow) - Vector3(-40.0, 0.0, 30.0)
	_check("Knockback distance = force ÷ mass (spec §6.2), pushing outward", absf(pushed.x - 3.0) < 0.05
			and absf(pushed_heavy.x - 1.5) < 0.05 and absf(pushed.z) < 0.01,
			"force 3: mass 1 moved %.3f m, mass 2 moved %.3f m" % [pushed.x, pushed_heavy.x])


func _check_free_list() -> void:
	_fresh_swarm(3, false)
	var slots: Array[int] = []
	for k in 4:
		slots.append(swarm.spawn(ash, Vector3(-40.0 + k * 3.0, 0.0, -50.0), 1.0, 1.0))
	swarm.apply_damage_in_radius(Vector3(-37.0, 0.0, -50.0), 0.1, 100.0, Damage.Type.KINETIC)
	await _ticks(4)
	var reused: int = swarm.spawn(ash, Vector3(-30.0, 0.0, -50.0), 1.0, 1.0)
	_check("Capacity is fixed and the free-list reuses dead slots", slots == [0, 1, 2, -1] and reused == 1,
			"spawned %s at capacity 3; after slot 1 died, got %d" % [slots, reused])
	deaths.clear()
	swarm.clear_all()
	await _ticks(4)
	_check("clear_all() removes everything without death signals", swarm.get_alive_count() == 0 and deaths.is_empty(),
			"alive %d, deaths %d" % [swarm.get_alive_count(), deaths.size()])


func _check_rendering() -> void:
	_fresh_swarm()
	var other: SwarmType = ash.duplicate()
	other.id = &"other_walker"
	for k in 5:
		swarm.spawn(ash, Vector3(-10.0 + k, 0.0, 40.0), 1.0, 1.0)
	swarm.spawn(other, Vector3(10.0, 0.0, 40.0), 1.0, 1.0)
	await process_frame
	await process_frame
	var instances: Array[MultiMeshInstance3D] = []
	for child in swarm.get_children():
		if child is MultiMeshInstance3D:
			instances.append(child)
	_check("One MultiMeshInstance3D per swarm type", instances.size() == 2, "%d instances" % instances.size())
	if instances.is_empty():
		return
	var mmi: MultiMeshInstance3D = instances[0]
	var mm: MultiMesh = mmi.multimesh
	_check("MultiMesh setup", mm.use_custom_data and mm.transform_format == MultiMesh.TRANSFORM_3D
			and mm.instance_count == swarm.capacity and mm.visible_instance_count == 5 and mm.mesh == ash.mesh
			and mmi.material_override == ash.material and mmi.is_set_as_top_level(),
			"%s: custom data %s, %d of %d visible" % [mmi.name, mm.use_custom_data, mm.visible_instance_count, mm.instance_count])


# --- integration helpers (steps 7–11) -----------------------------------------

## A new station with its own SwarmServer and SpawnDirector (paused), after
## its first ground sample has reached the swarm.
func _fresh_station() -> void:
	station.free()
	station = (load(STATION) as PackedScene).instantiate()
	root.add_child(station)
	ground = station.get_node("StationGround")
	taln = station.get_node("Taln")
	station_swarm = station.get_node("SwarmServer")
	spawner = station.get_node("SpawnDirector")
	spawner.paused = true
	contacts.clear()
	deaths.clear()
	station_swarm.enemy_died.connect(func(id: StringName, at: Vector3) -> void: deaths.append([id, at]))
	await ground.ground_changed
	await _ticks(1)


func _tap(action: String) -> void:
	_send(action, true)
	await _ticks(2)
	_send(action, false)
	await _ticks(1)


func _send(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


## Spawns count enemies on the given ring around Taln, off blocked cells.
func _spawn_ring(count: int, near: float, far: float) -> void:
	var spawned: int = 0
	var k: int = 0
	while spawned < count:
		var angle: float = k * 2.39996
		var at: Vector3 = taln.global_position + Vector3(cos(angle), 0.0, sin(angle)) * (near + fmod(k * 0.37, far - near))
		k += 1
		if not ground.is_blocked_at(at.x, at.z):
			station_swarm.spawn(ash, at, 1.0, 1.0)
			spawned += 1


# --- integration checks ----------------------------------------------------------

func _check_spawner_placement() -> void:
	await _fresh_station()
	taln.health.set_invulnerable(&"checks", true)
	var spots: Array[Vector3] = []
	spawner.spawned.connect(func(_slot: int, at: Vector3) -> void: spots.append(at))
	spawner.stress = true
	spawner.paused = false
	await _ticks(300)
	spawner.paused = true
	var camera: Camera3D = station.get_viewport().get_camera_3d()
	var off_ring: int = 0
	var blocked: int = 0
	var in_view: int = 0
	var t: SpawnTuning = spawner.tuning
	for at in spots:
		var dist: float = _flat(at - taln.global_position).length()
		if dist < t.ring_min - 0.01 or dist > t.ring_max + 0.01:
			off_ring += 1
		if ground.is_blocked_at(at.x, at.z):
			blocked += 1
		if camera.is_position_in_frustum(at):
			in_view += 1
	_check("Spawns land 18–26 m from Taln, never on blocked cells", spots.size() > 50 and off_ring == 0 and blocked == 0,
			"%d spawns: %d off the ring, %d blocked" % [spots.size(), off_ring, blocked])
	_check("Spawns come in from off-screen", in_view == 0, "%d of %d inside the camera's view" % [in_view, spots.size()])


func _check_wave_density() -> void:
	await _fresh_station()
	taln.health.set_invulnerable(&"checks", true)
	var fast: SpawnTuning = spawner.tuning.duplicate()
	fast.wave_length = 10.0
	spawner.tuning = fast
	var per_wave: Array[int] = []
	per_wave.resize(fast.waves)
	spawner.spawned.connect(func(_slot: int, _at: Vector3) -> void: per_wave[spawner.wave] += 1)
	spawner.paused = false
	await _ticks(roundi(fast.waves * fast.wave_length * 60.0))
	var expected: Array[int] = []
	var ok := true
	for w in fast.waves:
		expected.append(roundi(fast.base_budget * (1.0 + fast.wave_slope * w) * fast.wave_length))
		ok = ok and absi(per_wave[w] - expected[w]) <= 1 and (w == 0 or per_wave[w] > per_wave[w - 1])
	_check("Each wave spawns more (budget B0 × (1 + 0.15w), waves shortened to 10 s)", ok,
			"spawns per wave %s, expected %s" % [per_wave, expected])
	var last: int = fast.waves - 1
	_check("Spawn scaling at the last wave", spawner.wave == last and is_equal_approx(spawner.hp_multiplier(), 1.0 + 0.12 * last)
			and is_equal_approx(spawner.damage_multiplier(), 1.0 + 0.05 * last),
			"wave index %d: hp ×%.2f, dmg ×%.2f" % [spawner.wave, spawner.hp_multiplier(), spawner.damage_multiplier()])
	await _ticks(roundi(fast.wave_length * 60.0 * 1.5))
	_check("Wave index holds at the last wave (v0)", spawner.wave == last, "wave index %d" % spawner.wave)


func _check_bank_cap() -> void:
	await _fresh_station()
	taln.health.set_invulnerable(&"checks", true)
	var capped: SpawnTuning = spawner.tuning.duplicate()
	capped.alive_cap = 5
	spawner.tuning = capped
	spawner.paused = false
	await _ticks(600)
	var cap: float = spawner.budget_per_second() * capped.bank_cap_seconds
	_check("At the alive cap the bank fills to 5 s of budget and stops", station_swarm.get_alive_count() == 5
			and is_equal_approx(spawner.bank, cap), "alive %d, bank %.2f of %.2f" % [station_swarm.get_alive_count(), spawner.bank, cap])


func _check_contact_drain() -> void:
	await _fresh_station()
	var hits: Array = []
	taln.health.damaged.connect(func(amount: float, _type: Damage.Type) -> void: hits.append([tick, amount]))
	station_swarm.spawn(ash, taln.global_position + Vector3(2.0, 0.0, 0.0), 1.0, 1.0)
	var start: int = tick
	await _ticks(240)
	var anchored_hit: float = 6.0 * 100.0 / (100.0 + taln.tuning.anchored_armor_bonus)
	var ok: bool = hits.size() >= 4 and taln.anchored.is_anchored
	var amounts: Array[String] = []
	for k in hits.size():
		amounts.append("%.2f" % hits[k][1])
		if k > 0:
			ok = ok and hits[k][0] - hits[k - 1][0] >= 45 and is_equal_approx(hits[k][1], anchored_hit)
	_check("One enemy: 6 damage per 0.75 s, cut by Anchored armor", ok,
			"%d hits in 4 s: %s" % [hits.size(), ", ".join(amounts)])

	await _fresh_station()
	hits.clear()
	taln.health.damaged.connect(func(amount: float, _type: Damage.Type) -> void: hits.append([tick, amount]))
	_spawn_ring(16, 1.0, 2.5)
	start = tick
	await _ticks(240)
	var shortest: int = 1000
	for k in range(1, hits.size()):
		shortest = mini(shortest, hits[k][0] - hits[k - 1][0])
	var per_second: float = hits.size() / 4.0
	_check("Crowd of 16: hits never closer than the 0.2 s invulnerability", hits.size() > 1 and shortest >= 12,
			"%d hits in 4 s (%.1f/s), shortest gap %d ticks; uncapped would be %.1f/s" % [hits.size(), per_second,
			shortest, 16 / 0.75])


func _check_shoulder_knockback() -> void:
	await _fresh_station()
	taln.health.set_invulnerable(&"checks", true)
	var ahead: Vector3 = -taln.global_basis.z
	var offsets: Array[Vector3] = [ahead * 1.5, ahead * 3.0 + Vector3(0.4, 0.0, 0.0), ahead * 4.0 - Vector3(0.4, 0.0, 0.0)]
	var starts: Array[Vector3] = []
	for offset in offsets:
		var slot: int = station_swarm.spawn(ash, taln.global_position + offset, 1.0, 1.0)
		starts.append(station_swarm.get_enemy_position(slot))
	await _tap("shoulder")
	await _ticks(30)
	var moved: Array[String] = []
	var ok := true
	for k in starts.size():
		var d: float = _flat(station_swarm.get_enemy_position(k) - starts[k]).length()
		moved.append("%.1f m" % d)
		ok = ok and d > 5.0
	_check("Shoulder knocks enemies out of its path", ok, "moved %s in 0.5 s (force 12 → 12 m at mass 1, less the seek back)" % ", ".join(moved))


func _check_debug_blast() -> void:
	await _fresh_station()
	taln.health.set_invulnerable(&"checks", true)
	_spawn_ring(10, 2.0, 5.0)
	_spawn_ring(6, 8.0, 10.0)
	var kills_before: int = (station as GrayboxStation).kills
	await _tap("debug_blast")
	await _ticks(4)
	var kills: int = (station as GrayboxStation).kills - kills_before
	_check("F5 kills everything within 6 m, one enemy_died per kill", kills == 10 and deaths.size() == 10
			and station_swarm.get_alive_count() == 6, "%d logged kills, %d signals, %d alive" % [kills, deaths.size(),
			station_swarm.get_alive_count()])


func _check_live_tuning() -> void:
	await _fresh_station()
	var t: SpawnTuning = spawner.tuning
	var before: float = spawner.budget_per_second()
	t.base_budget *= 2.0
	var after: float = spawner.budget_per_second()
	t.base_budget /= 2.0
	var tough: SwarmType = ash.duplicate()
	tough.hp = 60.0
	station_swarm.spawn(tough, taln.global_position + Vector3(3.0, 0.0, 0.0), 1.0, 1.0)
	station_swarm.apply_damage_in_radius(taln.global_position, 6.0, 50.0, Damage.Type.KINETIC)
	await _ticks(4)
	_check("Spawn and enemy numbers come from the .tres resources", is_equal_approx(after, before * 2.0) and deaths.is_empty(),
			"doubling base_budget: %.2f → %.2f /s; a 60 HP type survived 50 damage: %s" % [before, after, deaths.is_empty()])


func _check_step_budget() -> void:
	for count: int in [400, 800]:
		await _fresh_station()
		taln.health.set_invulnerable(&"checks", true)
		_spawn_ring(count, 18.0, 26.0)
		var total: float = 0.0
		var worst: float = 0.0
		for f in 150:
			await _ticks(2)
			total += station_swarm.get_last_step_ms()
			worst = maxf(worst, station_swarm.get_last_step_ms())
		var detail: String = "step avg %.3f ms, worst %.3f ms over 5 s converging on Taln" % [total / 150.0, worst]
		if count == 400:
			_check("SwarmServer step under 2 ms at 400 alive", worst < 2.0, detail)
		else:
			_info("800 alive (stretch)", detail)
