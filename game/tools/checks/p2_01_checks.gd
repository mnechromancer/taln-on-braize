extends SceneTree
## P2-01 step 12: the "before calling it done" checks, run headless against
## the real station scene at a fixed 60 fps. Prints PASS/FAIL per check and
## exits with the number of failures. Rendering frame rate and visuals can't
## be judged headless; they're listed as MANUAL at the end.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_01_checks.gd

const STATION := "res://scenes/graybox_station.tscn"
const MOVE_ACTIONS: Array[String] = ["move_forward", "move_back", "move_left", "move_right"]

var station: GrayboxStation
var taln: Taln
var rig: CameraRig
var overlay: DebugOverlay
var failures: int = 0
var tick: int = 0
var frame_ms: PackedFloat32Array = []
var _last_usec: int = 0


func _init() -> void:
	_run()


func _run() -> void:
	await _ticks(2)
	await _check_speed()
	await _check_terrain()
	await _check_ledge()
	await _check_shoulder()
	await _check_shoulder_terrain()
	await _check_anchored()
	await _check_fracture()
	await _check_pool()
	await _check_camera()
	await _check_tuning()
	await _check_performance()
	print("")
	print("MANUAL  60 fps with rendering: play the station (F5) with the F3 overlay open.")
	print("MANUAL  Visuals: lighting, fog, discs and the facing box read correctly.")
	print("")
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
		tick += 1


func _until(target_tick: int) -> void:
	while tick < target_tick:
		await _ticks(1)


func _fresh() -> void:
	_release_all()
	if station:
		station.queue_free()
		await _ticks(1)
	station = (load(STATION) as PackedScene).instantiate()
	root.add_child(station)
	taln = station.get_node("Taln")
	rig = station.get_node("CameraRig")
	overlay = station.get_node("DebugOverlay")
	await _ticks(2)


func _release_all() -> void:
	for action: StringName in InputMap.get_actions():
		Input.action_release(action)


func _place(pos: Vector3, yaw_deg: float = 0.0) -> void:
	taln.global_position = pos
	taln.velocity = Vector3.ZERO
	taln.rotation.y = deg_to_rad(yaw_deg)
	taln.reset_physics_interpolation()


## Walks along dir (by pointing the camera that way) for ticks, then lets go.
func _walk(dir: Vector3, ticks: int) -> void:
	rig.rotation.y = atan2(-dir.x, -dir.z)
	Input.action_press("move_forward")
	await _ticks(ticks)
	Input.action_release("move_forward")


func _walk_from(start: Vector3, dir: Vector3, ticks: int) -> Vector3:
	_place(start)
	await _ticks(1)
	await _walk(dir, ticks)
	await _ticks(30)
	return taln.global_position


## Presses and releases action through the input event queue, like a real
## key: is_action_just_pressed() only sees presses that arrive this way.
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


func _speed() -> float:
	return Vector2(taln.velocity.x, taln.velocity.z).length()


func _overlay_text() -> String:
	await process_frame
	return (overlay.get_node("Panel/Label") as Label).text


func _plateau_normal(face: int) -> Vector3:
	return Vector3(sin(TAU / 9.0 * face), 0.0, cos(TAU / 9.0 * face))


# --- checks ----------------------------------------------------------------

func _check_speed() -> void:
	await _fresh()
	_place(Vector3(0, 0, 40))
	rig.rotation.y = 0.0
	Input.action_press("move_forward")
	var ticks: int = 0
	while _speed() < taln.tuning.move_speed - 0.01 and ticks < 60:
		await _ticks(1)
		ticks += 1
	_check("Reaches full speed in about 0.15 s", ticks / 60.0 <= 0.17, "%.3f s" % (ticks / 60.0))
	await _ticks(10)
	Input.action_release("move_forward")
	var released_at: Vector3 = taln.global_position
	ticks = 0
	while _speed() > 0.0 and ticks < 60:
		await _ticks(1)
		ticks += 1
	var slide: float = Vector2(taln.global_position.x - released_at.x, taln.global_position.z - released_at.z).length()
	_check("Stops within about 0.3 m", slide <= 0.35, "%.3f m in %.3f s" % [slide, ticks / 60.0])


func _check_terrain() -> void:
	await _fresh()
	var n20: Vector3 = _plateau_normal(0)
	var n35: Vector3 = _plateau_normal(3)
	var n45: Vector3 = _plateau_normal(6)
	var p: Vector3 = await _walk_from(n20 * 20.0, -n20, 240)
	_check("20° ramp is walkable", absf(p.y - 1.5) < 0.05, "ended at y=%.2f" % p.y)
	p = await _walk_from(n35 * 20.0, -n35, 240)
	_check("35° ramp is walkable", absf(p.y - 1.5) < 0.05, "ended at y=%.2f" % p.y)
	p = await _walk_from(n45 * 20.0, -n45, 240)
	_check("45° ramp is not walkable", p.y < 0.2, "ended at y=%.2f" % p.y)
	p = await _walk_from(Vector3(26, 0, -14), Vector3.RIGHT, 90)
	_check("0.3 m steps are climbable", absf(p.y - 1.5) < 0.05, "ended at y=%.2f" % p.y)
	p = await _walk_from(Vector3(-45, 0, 0), Vector3.RIGHT, 150)
	_check("0.4 m steps are not climbable", p.y < 0.1, "ended at y=%.2f" % p.y)


func _check_ledge() -> void:
	await _fresh()
	var p: Vector3 = await _walk_from(Vector3(14, 0, 0), Vector3.RIGHT, 170)
	_check("Ledge ramp leads up to the 3 m ledge", absf(p.y - 3.0) < 0.05, "ended at y=%.2f" % p.y)
	await _walk(Vector3.RIGHT, 120)
	await _ticks(30)
	_check("Dropping off the ledge lands on the ground", taln.global_position.y < 0.05, "y=%.2f" % taln.global_position.y)

	var attempts := {
		"north face": [Vector3(32, 0, 12), Vector3.FORWARD],
		"east face": [Vector3(45, 0, 0), Vector3.LEFT],
		"south face": [Vector3(29, 0, -10), Vector3.BACK],
		"west face beside the ramp": [Vector3(20, 0, 4), Vector3.RIGHT],
	}
	var highest: float = 0.0
	var worst: String = "-"
	for face: String in attempts:
		p = await _walk_from(attempts[face][0], attempts[face][1], 180)
		if p.y > highest:
			highest = p.y
			worst = face
	_place(Vector3(40, 0, 0), 90.0)
	await _ticks(200)  # Let any earlier cooldown run out.
	await _tap("shoulder")
	await _ticks(30)
	if taln.global_position.y > highest:
		highest = taln.global_position.y
		worst = "Shoulder into east face"
	_check("Only the ramp leads back up (walls and Shoulder fail)", highest < 0.1,
			"highest y=%.2f (%s)" % [highest, worst])


func _check_shoulder() -> void:
	await _fresh()
	var starts: Array = []  # [tick, origin]
	var ends: Array = []  # [tick, position]
	var blocks: Array[Vector3] = []
	taln.shoulder.shouldered.connect(func(origin: Vector3, _d: Vector3) -> void: starts.append([tick, origin]))
	taln.shoulder.ended.connect(func() -> void: ends.append([tick, taln.global_position]))
	taln.shoulder.blocked.connect(func(pos: Vector3, _n: Vector3) -> void: blocks.append(pos))

	_place(Vector3(0, 0, 40))
	await _ticks(2)
	await _tap("shoulder")
	await _ticks(30)
	var moved: float = -1.0
	var ticks: int = -1
	if starts.size() == 1 and ends.size() == 1:
		var origin: Vector3 = starts[0][1]
		var end: Vector3 = ends[0][1]
		moved = Vector2(end.x - origin.x, end.z - origin.z).length()
		ticks = ends[0][0] - starts[0][0] + 1
	_check("Shoulder covers 4.5 m in 0.25 s", absf(moved - 4.5) < 0.01 and ticks == 15,
			"%.3f m over %d ticks (%.3f s)" % [moved, ticks, ticks / 60.0])

	var first: int = starts[0][0] if starts.size() > 0 else tick
	await _tap("shoulder")
	var refused_at_once: bool = starts.size() == 1
	_place(Vector3(0, 0, -32))
	await _until(first + 165)
	await _tap("shoulder")  # About 2.75 s after the first charge started.
	await _ticks(2)
	var refused_late: bool = starts.size() == 1
	await _until(first + 185)
	await _tap("shoulder")  # About 3.1 s after.
	await _ticks(30)
	var accepted: bool = starts.size() == 2
	var second_at: float = (starts[1][0] - first) / 60.0 if accepted else -1.0
	_check("Shoulder respects the 3 s cooldown", refused_at_once and refused_late and accepted,
			"refused at once=%s, refused at ~2.75 s=%s, next charge at %.2f s" % [refused_at_once, refused_late, second_at])
	_check("Shoulder stops at walls", blocks.size() == 1 and absf(taln.global_position.z + 35.05) < 0.05,
			"blocked=%s, stopped at z=%.2f (wall face at -35.5, capsule radius 0.45)" % [blocks.size() == 1, taln.global_position.z])


## Charges once from pos along dir on a fresh station (optionally with two
## test lanes at the west end: a 0.9 m gap at z=0 and a 1.3 m gap at z=10,
## both 1 m deep) and reports where Taln ends up.
func _shoulder_from(pos: Vector3, dir: Vector3, lanes: bool) -> Dictionary:
	await _fresh()
	if lanes:
		_platform(Vector3(-55, 0.5, 0), Vector3(10, 1, 6))
		_platform(Vector3(-46.6, 0.5, 0), Vector3(5, 1, 6))
		_platform(Vector3(-55, 0.5, 10), Vector3(10, 1, 6))
		_platform(Vector3(-46.2, 0.5, 10), Vector3(5, 1, 6))
	var blocks: Array[Vector3] = []
	taln.shoulder.blocked.connect(func(p: Vector3, _n: Vector3) -> void: blocks.append(p))
	_place(pos, rad_to_deg(atan2(-dir.x, -dir.z)))
	await _ticks(3)
	var start: Vector3 = taln.global_position
	await _tap("shoulder")
	await _ticks(60)
	var end: Vector3 = taln.global_position
	return {"end": end, "blocked": not blocks.is_empty(),
			"moved": Vector2(end.x - start.x, end.z - start.z).length()}


func _platform(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)
	body.position = center
	station.add_child(body)


func _check_shoulder_terrain() -> void:
	var r: Dictionary = await _shoulder_from(Vector3(35, 3, 0), Vector3.RIGHT, false)
	var end: Vector3 = r.end
	_check("Shoulder off a drop flings Taln through the air", end.y < 0.05 and end.x > 39.0,
			"from the ledge at x=35 (edge at 37) landed at x=%.2f, y=%.2f" % [end.x, end.y])
	r = await _shoulder_from(Vector3(-52, 1, 0), Vector3.RIGHT, true)
	end = r.end
	_check("Shoulder crosses a 0.9 m gap", absf(end.y - 1.0) < 0.05 and end.x > -49.1,
			"landed at x=%.2f, y=%.2f (far side starts at -49.1)" % [end.x, end.y])
	r = await _shoulder_from(Vector3(-52, 1, 10), Vector3.RIGHT, true)
	end = r.end
	_check("Shoulder drops Taln into a 1.3 m gap", end.y < 0.5 and end.x > -50.0 and end.x < -48.7,
			"ended at x=%.2f, y=%.2f (gap spans -50 to -48.7, floor at 0)" % [end.x, end.y])
	var glancing := Vector3(cos(deg_to_rad(20.0)), 0.0, -sin(deg_to_rad(20.0)))
	r = await _shoulder_from(Vector3(-4, 0, -34.6), glancing, false)
	end = r.end
	# Sliding drops the into-wall part of the motion: about 4.5 × cos 20° = 4.23 m.
	_check("Shoulder slides along a wall hit at a shallow angle", not r.blocked and r.moved > 4.0,
			"20° into WallLong: blocked=%s, moved %.2f m, ended at z=%.2f" % [r.blocked, r.moved, end.z])


func _check_anchored() -> void:
	await _fresh()
	overlay.visible = true
	_place(Vector3(0, 0, 40))
	await _walk(Vector3.FORWARD, 30)
	await _ticks(37)
	var text: String = await _overlay_text()
	_check("0.6 s idle shows Anchored with armor 40 on the overlay",
			text.contains("Stance     Anchored") and text.contains("armor 40"), _line(text, "Stance") + " | " + _line(text, "Health"))
	var cleared: Array[String] = []
	for action in MOVE_ACTIONS:
		await _ticks(40)
		var was: bool = taln.anchored.is_anchored
		await _tap(action)
		text = await _overlay_text()
		if was and not taln.anchored.is_anchored and not text.contains("Anchored") and text.contains("armor 0"):
			cleared.append(action)
	_check("Any movement input clears Anchored", cleared.size() == MOVE_ACTIONS.size(), "cleared by %s" % ", ".join(cleared))


func _check_fracture() -> void:
	await _fresh()
	var changes: Array = []
	var pulses: PackedFloat32Array = []
	taln.fracture.fracture_state_changed.connect(func(s: Fracture.State) -> void:
		changes.append([Fracture.State.keys()[s], taln.fracture.still_time]))
	taln.health.damaged.connect(func(amount: float, _t: Damage.Type) -> void: pulses.append(amount))
	await _ticks(60 * 12)
	var warning_at: float = -1.0
	var active_at: float = -1.0
	for change: Array in changes:
		if change[0] == "WARNING" and warning_at < 0.0:
			warning_at = change[1]
		if change[0] == "ACTIVE" and active_at < 0.0:
			active_at = change[1]
	_check("Standing still: warning at 6 s", absf(warning_at - 6.0) < 0.03, "WARNING at %.2f s" % warning_at)
	_check("Standing still: damage from 9 s", absf(active_at - 9.0) < 0.03 and pulses.size() >= 1, "ACTIVE at %.2f s" % active_at)
	var rising: bool = pulses.size() >= 3 and pulses[1] > pulses[0] and pulses[2] > pulses[1]
	_check("Damage increases each second", rising, "pulses %s" % str(Array(pulses).map(func(v: float) -> String: return "%.2f" % v)))

	var before: float = taln.fracture.still_time
	await _walk(Vector3.FORWARD, 10)
	await _walk(Vector3.BACK, 10)
	await _ticks(30)
	_check("Shuffling within 3 m doesn't reset it", taln.fracture.still_time > before,
			"still %.2f s -> %.2f s, state %s" % [before, taln.fracture.still_time, Fracture.State.keys()[taln.fracture.state]])

	await _walk(Vector3.RIGHT, 60)
	await _ticks(20)
	var away_state: String = Fracture.State.keys()[taln.fracture.state]
	await _ticks(180)
	# After the reset a new anchor starts where he stands, so the timer is small, not zero.
	_check("Staying away for 3 s resets it", away_state == "NONE" and taln.fracture.still_time < 2.0,
			"state away=%s, timer %.2f s before -> %.2f s after 3 s away" % [away_state, before, taln.fracture.still_time])


func _check_pool() -> void:
	await _fresh()
	overlay.visible = true
	_place(Vector3(22, 0, 24))
	await _ticks(45)
	var text: String = await _overlay_text()
	_check("Standing Anchored in a Well pool shows \"in pool\"",
			text.contains("Anchored") and text.contains("in pool"), _line(text, "Stance") + " | " + _line(text, "Well pool"))


func _check_camera() -> void:
	await _fresh()
	var total_yaw: float = 0.0
	var last_yaw: float = rig.rotation.y
	Input.action_press("cam_orbit_right")
	for i in 150:
		await _ticks(1)
		total_yaw += absf(wrapf(rig.rotation.y - last_yaw, -PI, PI))
		last_yaw = rig.rotation.y
	Input.action_release("cam_orbit_right")
	_check("Camera orbits a full 360°", rad_to_deg(total_yaw) >= 360.0, "%.0f° in 2.5 s" % rad_to_deg(total_yaw))

	Input.action_press("cam_orbit_up")
	await _ticks(60)
	Input.action_release("cam_orbit_up")
	var top: float = rig.pitch_deg
	Input.action_press("cam_orbit_down")
	await _ticks(90)
	Input.action_release("cam_orbit_down")
	var bottom: float = rig.pitch_deg
	_check("Camera respects the pitch limits", is_equal_approx(top, rig.tuning.pitch_max_deg) and is_equal_approx(bottom, rig.tuning.pitch_min_deg),
			"stops at %.1f° and %.1f°" % [top, bottom])

	Input.action_press("cam_zoom_in")
	await _ticks(90)
	Input.action_release("cam_zoom_in")
	var near: float = rig.distance
	Input.action_press("cam_zoom_out")
	await _ticks(120)
	Input.action_release("cam_zoom_out")
	var far: float = rig.distance
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await _ticks(2)
	var after_wheel: float = rig.distance
	_check("Camera respects the zoom range (buttons and wheel)",
			is_equal_approx(near, rig.tuning.zoom_min) and is_equal_approx(far, rig.tuning.zoom_max) and is_equal_approx(after_wheel, far - rig.tuning.zoom_step),
			"%.1f–%.1f m, one wheel notch -> %.1f m" % [near, far, after_wheel])

	var camera: Camera3D = rig.get_node("PitchPivot/SpringArm3D/Camera3D")
	var space: PhysicsDirectSpaceState3D = station.get_world_3d().direct_space_state
	var lowest: float = INF
	var worst: String = ""
	var spots: Array[Vector3] = [Vector3(0, 1.5, 0), Vector3(9, 1.5, 0), Vector3(-9, 1.5, 0), Vector3(0, 1.5, 9), Vector3(0, 1.5, -9)]
	for spot in spots:
		_place(spot)
		for yaw_step in 12:
			for pitch: float in [rig.tuning.pitch_max_deg, rig.tuning.pitch_min_deg]:
				for dist: float in [rig.tuning.zoom_min, rig.tuning.zoom_max]:
					rig.rotation.y = deg_to_rad(yaw_step * 30.0)
					rig._pitch_deg = pitch
					rig._distance = dist
					rig.global_position = spot + Vector3.UP * rig.tuning.target_height
					await _ticks(2)
					var cam_pos: Vector3 = camera.global_position
					var query := PhysicsRayQueryParameters3D.create(Vector3(cam_pos.x, 100, cam_pos.z), Vector3(cam_pos.x, -10, cam_pos.z))
					query.exclude = [taln.get_rid()]
					var hit: Dictionary = space.intersect_ray(query)
					var clearance: float = cam_pos.y - ((hit.position as Vector3).y if hit else 0.0)
					if clearance < lowest:
						lowest = clearance
						worst = "Taln at %s, yaw %d°, pitch %.0f°, %.0f m" % [spot, yaw_step * 30, pitch, dist]
	_check("Camera stays above the ground with Taln on the plateau", lowest > camera.near,
			"lowest clearance %.2f m (%s)" % [lowest, worst])


func _check_tuning() -> void:
	var tuning: TalnTuning = load("res://data/tuning/taln_tuning.tres")
	var pool_tuning: WellPoolTuning = load("res://data/tuning/well_pool_tuning.tres")
	var results: PackedStringArray = []
	var ok: bool = true

	var saved_speed: float = tuning.move_speed
	var saved_distance: float = tuning.shoulder_distance
	var saved_delay: float = tuning.anchor_delay
	var saved_warning: float = tuning.fracture_warning_time
	var saved_radius: float = pool_tuning.pool_radius
	tuning.move_speed = 3.0
	tuning.shoulder_distance = 2.0
	tuning.anchor_delay = 1.0
	tuning.fracture_warning_time = 2.0
	pool_tuning.pool_radius = 5.0

	await _fresh()
	_place(Vector3(0, 0, 40))
	await _walk(Vector3.FORWARD, 40)
	var speed_ok: bool = absf(_speed() - 3.0) < 0.05
	results.append("move_speed 3 -> %.2f m/s" % _speed())
	ok = ok and speed_ok
	await _ticks(40)
	var anchored_early: bool = taln.anchored.is_anchored
	await _ticks(30)
	var anchored_late: bool = taln.anchored.is_anchored
	results.append("anchor_delay 1.0 -> anchored at 0.67 s=%s, 1.17 s=%s" % [anchored_early, anchored_late])
	ok = ok and not anchored_early and anchored_late

	var start: Vector3 = taln.global_position
	await _tap("shoulder")
	await _ticks(30)
	var moved: float = Vector2(taln.global_position.x - start.x, taln.global_position.z - start.z).length()
	results.append("shoulder_distance 2 -> %.2f m" % moved)
	ok = ok and absf(moved - 2.0) < 0.01

	await _fresh()
	await _ticks(125)
	results.append("fracture_warning_time 2 -> %s at 2.1 s" % Fracture.State.keys()[taln.fracture.state])
	ok = ok and taln.fracture.state == Fracture.State.WARNING

	_place(Vector3(22 + 4.5, 0, 24))
	await _ticks(10)
	var pool: WellPool = station.get_node("WellPool2")
	results.append("pool_radius 5 -> inside at 4.5 m=%s" % pool.is_taln_inside)
	ok = ok and pool.is_taln_inside

	tuning.move_speed = saved_speed
	tuning.shoulder_distance = saved_distance
	tuning.anchor_delay = saved_delay
	tuning.fracture_warning_time = saved_warning
	pool_tuning.pool_radius = saved_radius
	_check("Numbers come from the .tres files (edits take effect without code changes)", ok, "; ".join(results))


## Headless runs as fast as it can, so the wall-clock time between physics
## ticks is the real cost of a frame without rendering.
func _check_performance() -> void:
	await _fresh()
	_place(Vector3(0, 0, 40))
	await _ticks(2)
	var samples: PackedFloat32Array = []
	var dirs: Array[Vector3] = [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]
	for i in 8:
		rig.rotation.y = atan2(-dirs[i % 4].x, -dirs[i % 4].z)
		Input.action_press("move_forward")
		if i % 2 == 0:
			_send("shoulder", true)
		for t in 45:
			var before: int = Time.get_ticks_usec()
			await _ticks(1)
			samples.append((Time.get_ticks_usec() - before) / 1000.0)
		_send("shoulder", false)
		Input.action_release("move_forward")
	var total: float = 0.0
	var worst: float = 0.0
	for ms in samples:
		total += ms
		worst = maxf(worst, ms)
	_check("Gameplay frame cost fits 60 fps with room for rendering (CPU side, no rendering)", worst < 4.0,
			"avg %.3f ms, worst %.3f ms over %d frames of walking and Shoulder" % [total / samples.size(), worst, samples.size()])


func _line(text: String, prefix: String) -> String:
	for line in text.split("\n"):
		if line.begins_with(prefix):
			return line.strip_edges()
	return "(no %s line)" % prefix
