extends SceneTree
## P2-12 (Meteor: launches, air steering, landings, Heave, Impact, launch
## pads, contact height, the airborne camera) checks, run headless against the
## Braize slice at a fixed 60 fps. Prints PASS/FAIL per check and exits with
## the number of failures. Meta state goes to user://checks_meta.json;
## telemetry for the one check that records goes to user://checks_telemetry_p2_12.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_12_checks.gd

const SLICE := "res://scenes/braize_slice.tscn"
const ASH_WALKER := "res://data/swarm/ash_walker.tres"
const CHECKS_META := "user://checks_meta.json"
const CHECKS_TELEMETRY := "user://checks_telemetry_p2_12"
## Open, level ground in The Shelf, clear of features, pads and pools.
const OPEN := Vector3(20.0, 0.0, 115.0)

var station: BraizeSlice
var taln: Taln
var swarm: SwarmServer
var spawner: SpawnDirector
var ground: StationGround
var rig: CameraRig
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
	meta.set_aspect(&"meteor")
	cycle = Cycle.director()
	_check_data()
	print("")
	await _check_meteor_kit()
	await _check_heave_arc()
	await _check_heave_ground_only()
	await _check_air_steering()
	await _check_ledge_drop()
	await _check_impact()
	await _check_mass()
	await _check_contact_height()
	await _check_pad()
	await _check_ridge()
	await _check_camera()
	await _check_telemetry()
	print("")
	print("MANUAL  Launch and landing feel, the pillar and Impact rings, the camera pulling out in flight and the landing shake need a rendered recording.")
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
	rig = station.get_node("CameraRig")
	spawner.paused = true
	await ground.ground_changed
	_place(at)
	await _ticks(3)


func _place(at: Vector3) -> void:
	taln.global_position = Vector3(at.x, ground.get_surface_height_at(at.x, at.z), at.z)
	taln.velocity = Vector3.ZERO


## Ticks until Taln lands (or max_ticks pass). Returns [landed, fall speed,
## where, peak height above start, highest horizontal speed seen].
func _fly(max_ticks: int = 400) -> Array:
	var start_y: float = taln.global_position.y
	var result: Array = [false, 0.0, Vector3.ZERO, 0.0, 0.0]
	var on_landed := func(speed: float, at: Vector3) -> void:
		if not result[0]:
			result[0] = true
			result[1] = speed
			result[2] = at
	taln.landed.connect(on_landed)
	for i in max_ticks:
		await physics_frame
		result[3] = maxf(result[3], taln.global_position.y - start_y)
		result[4] = maxf(result[4], Vector2(taln.velocity.x, taln.velocity.z).length())
		if result[0]:
			break
	taln.landed.disconnect(on_landed)
	return result


func _heave() -> Heave:
	return taln.loadout.get_behavior(&"heave")


# --- data --------------------------------------------------------------------

func _check_data() -> void:
	var tt: TalnTuning = load("res://data/tuning/taln_tuning.tres")
	var st: SwarmTuning = load("res://data/tuning/swarm_tuning.tres")
	var lt: LaunchTuning = load("res://data/tuning/launch_tuning.tres")
	var ct: CameraTuning = load("res://data/tuning/camera_tuning.tres")
	_check("Air steering 12 m/s²; the swarm touches Taln only within 1.6 m of his height; pads 1.5 m, rearm 1 s, reach 0.6 m",
			tt.air_acceleration == 12.0 and st.contact_height == 1.6 and lt.pad_radius == 1.5
			and lt.pad_rearm_seconds == 1.0 and lt.pad_reach_height == 0.6,
			"%.0f, %.1f, %.1f/%.1f/%.1f" % [tt.air_acceleration, st.contact_height, lt.pad_radius,
			lt.pad_rearm_seconds, lt.pad_reach_height])
	_check("Camera pulls out 3 m in the air at 3 m/s; landings shake it 0.03 trauma per m/s past 6 m/s",
			ct.airborne_zoom_add == 3.0 and ct.airborne_zoom_rate == 3.0 and ct.landing_trauma_per_speed == 0.03
			and ct.landing_trauma_min_speed == 6.0, "%.1f, %.1f, %.2f, %.1f" % [ct.airborne_zoom_add,
			ct.airborne_zoom_rate, ct.landing_trauma_per_speed, ct.landing_trauma_min_speed])
	var heave: SkillDef = load("res://data/skills/heave.tres")
	var impact: SkillDef = load("res://data/skills/impact.tres")
	var h1: Dictionary = heave.params_for(1)
	var i1: Dictionary = impact.params_for(1)
	_check("Heave: a Blade-eligible Surge, cost 0, 1.6 s cooldown, 9 m and a 4.5 m apex at level 1; levels 1–9 defined",
			heave.kind == SkillDef.Kind.SURGE and heave.investiture_cost == 0.0 and heave.cooldown == 1.6
			and heave.routing == SkillDef.Routing.BLADE_ELIGIBLE and h1.distance == 9.0 and h1.apex == 4.5
			and heave.level_params.size() == 9, "%s" % [h1])
	_check("Impact: a Weapon striking from 6 m/s, 24 + 3 per m/s over it, radius 3 + 0.2 per m/s up to 7 m, knockback 10",
			impact.kind == SkillDef.Kind.WEAPON and i1.min_speed == 6.0 and i1.damage == 24.0 and i1.damage_per_speed == 3.0
			and i1.radius == 3.0 and i1.radius_per_speed == 0.2 and i1.max_radius == 7.0 and i1.knockback == 10.0
			and impact.level_params.size() == 9, "%s" % [i1])


# --- Meteor ------------------------------------------------------------------

func _check_meteor_kit() -> void:
	await _fresh()
	var ids: Array = taln.loadout.slots.map(func(s: SkillDef) -> StringName: return s.id)
	_check("Meteor starts with Impact and Heave (Heave on Surge 1), no Breaking Stroke, no Anchored or Fracture",
			ids == [&"impact", &"heave"] and taln.loadout.get_bound_surge(0).id == &"heave"
			and not taln.aspect.anchored and not taln.aspect.fracture, "%s" % [ids])


func _check_heave_arc() -> void:
	await _fresh()
	var start: Vector3 = taln.global_position
	var heave: Heave = _heave()
	var cast: bool = heave.try_cast()
	var flight: Array = await _fly()
	var travelled: float = Vector2(flight[2].x - start.x, flight[2].z - start.z).length()
	var expected_speed: float = sqrt(2.0 * taln.tuning.gravity * 4.5)
	_check("Heave throws Taln on an arc that peaks ~4.5 m up and lands ~9 m out, at ~%.1f m/s" % expected_speed,
			cast and flight[0] and absf(flight[3] - 4.5) < 0.35 and absf(travelled - 9.0) < 0.6
			and absf(flight[1] - expected_speed) < 0.8 and not taln.airborne,
			"cast %s, landed %s, peak %.2f m, %.2f m out, %.2f m/s" % [cast, flight[0], flight[3], travelled, flight[1]])


func _check_heave_ground_only() -> void:
	await _fresh()
	var heave: Heave = _heave()
	heave.try_cast()
	await _ticks(10)
	heave.cooldown_left = 0.0
	var in_air: bool = not heave.try_cast()
	await _fly()
	heave.cooldown_left = 0.0
	await _ticks(2)
	var on_ground: bool = heave.try_cast()
	_check("Heave throws only from the ground: refused mid-flight, ready again once Taln lands", in_air and on_ground,
			"refused in the air %s, cast after landing %s" % [in_air, on_ground])


func _check_air_steering() -> void:
	await _fresh()
	taln.launch(Vector3(10.0, 8.0, 0.0))
	var coast: Array = await _fly()
	var coast_ok: bool = absf(coast[4] - 10.0) < 0.05
	await _fresh()
	Input.action_press(&"move_back", 1.0)
	taln.launch(Vector3(10.0, 8.0, 0.0))
	var steered: Array = await _fly()
	Input.action_release(&"move_back")
	var start := Vector2(OPEN.x, OPEN.z)
	var drift: float = steered[2].z - OPEN.z
	var forward: float = steered[2].x - OPEN.x
	_check("In the air Taln keeps the launch's speed with no braking, and steering bends the arc without speeding it up",
			coast_ok and steered[4] <= 10.0 + 0.05 and absf(drift) > 1.0 and forward < 8.0 + 0.5,
			"coasting %.2f m/s; steered top %.2f m/s, drift %.2f m, forward %.2f m" % [coast[4], steered[4], drift, forward])


func _check_ledge_drop() -> void:
	await _fresh(Vector3(-30.0, 0.0, 100.0))  # On top of The Shelf's 3 m ledge.
	await _ticks(5)
	var top: float = taln.global_position.y
	Input.action_press(&"move_left", 1.0)
	var flight: Array = await _fly(240)
	Input.action_release(&"move_left")
	var expected: float = sqrt(2.0 * taln.tuning.gravity * top)
	_check("Walking off a 3 m ledge is a landing too, at ~%.1f m/s" % expected,
			top > 2.5 and flight[0] and absf(flight[1] - expected) < 1.0, "from %.2f m: landed %s at %.2f m/s"
			% [top, flight[0], flight[1]])


func _check_impact() -> void:
	await _fresh()
	var impact: Impact = taln.loadout.get_behavior(&"impact")
	var slow: Vector2 = impact.strike_for(5.0)
	var hard: Vector2 = impact.strike_for(13.0)
	var cap: Vector2 = impact.strike_for(60.0)
	_check("Impact scales with fall speed: nothing under 6 m/s; 45 within 4.4 m at 13 m/s; radius capped at 7 m",
			slow == Vector2.ZERO and is_equal_approx(hard.x, 45.0) and is_equal_approx(hard.y, 4.4) and cap.y == 7.0,
			"5 m/s %s, 13 m/s %s, 60 m/s %s" % [slow, hard, cap])
	# A real landing among the swarm.
	var ash: SwarmType = load(ASH_WALKER)
	var heave: Heave = _heave()
	var land_at: Vector3 = taln.global_position + heave.aim_direction() * 9.0
	var slots: Array[int] = []
	for k in 6:
		slots.append(swarm.spawn(ash, land_at + Vector3.FORWARD.rotated(Vector3.UP, k * TAU / 6.0) * 2.0, 1.0, 1.0))
	swarm.set_frozen(true)
	var struck: Array = []
	impact.impacted.connect(func(speed: float, hits: int) -> void: struck.append([speed, hits]))
	heave.try_cast()
	await _fly()
	swarm.set_frozen(false)
	await _ticks(4)
	var dead: int = slots.filter(func(s: int) -> bool: return not swarm.is_enemy_alive(s)).size()
	_check("A Heave landing among six ash walkers strikes them all and kills them", struck.size() == 1
			and struck[0][1] == 6 and dead == 6, "impacts %s, %d of 6 dead" % [struck, dead])


func _check_mass() -> void:
	await _fresh()
	var impact: Impact = taln.loadout.get_behavior(&"impact")
	var heave: Heave = _heave()
	var light: float = taln.mass
	var reach_light: float = Vector2(heave.launch_velocity(Vector3.FORWARD, 1.0).x, heave.launch_velocity(Vector3.FORWARD, 1.0).z).length()
	impact.set_level(9)
	var heavy: float = taln.mass
	var reach_heavy: float = Vector2(heave.launch_velocity(Vector3.FORWARD, 1.0).x, heave.launch_velocity(Vector3.FORWARD, 1.0).z).length()
	var hard: Vector2 = impact.strike_for(13.0)
	# Level 9: 72 + 7 per m/s over 6, times mass 1.4.
	_check("Mass (spec v1.7 #1): Impact's levels take Taln from 1.0 to 1.4; a level-9 landing at 13 m/s hits (72 + 49) × 1.4, and a Heave throws him 1.4× less far",
			light == 1.0 and is_equal_approx(heavy, 1.4) and is_equal_approx(hard.x, 121.0 * 1.4)
			and absf(reach_light / reach_heavy - 1.4) < 0.01, "mass %.2f → %.2f, strike %.1f, reach %.2f → %.2f"
			% [light, heavy, hard.x, reach_light, reach_heavy])
	impact.set_level(1)


func _check_contact_height() -> void:
	await _fresh()
	var ash: SwarmType = load(ASH_WALKER)
	# A crowd under the arc's midpoint, frozen in place.
	var heave: Heave = _heave()
	var mid: Vector3 = taln.global_position + heave.aim_direction() * 4.5
	for k in 9:
		swarm.spawn(ash, mid + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)), 1.0, 1.0)
	var hits: Array = [0]
	swarm.taln_contacted.connect(func(_d: float, _t: int) -> void: hits[0] += 1)
	heave.try_cast()
	var high_over: Array = [0]
	for i in 30:
		await physics_frame
		if taln.global_position.y - mid.y > 2.0:
			high_over[0] += 1
	var flying_hits: int = hits[0]
	await _fly()
	# Standing in a crowd on the ground still gets hit (a fresh, tough one: the landing killed the first).
	for k in 3:
		swarm.spawn(ash, taln.global_position + Vector3(0.5 * k, 0.0, 0.5), 100.0, 1.0)
	await _ticks(30)
	_check("Over the swarm in flight Taln takes no contact; standing in it he does",
			high_over[0] > 10 and flying_hits == 0 and hits[0] > 0, "%d ticks high, %d contacts in flight, %d on the ground"
			% [high_over[0], flying_hits, hits[0]])


func _check_pad() -> void:
	await _fresh()
	var pad: LaunchPad = station.get_node("LaunchPad1")
	_place(pad.global_position)
	var flight: Array = await _fly(400)
	var miss: float = Vector2(flight[2].x - pad.target.x, flight[2].z - pad.target.z).length()
	var peak_ok: bool = flight[3] > pad.apex - 0.5
	# Landing on the plateau, Taln stands at its height.
	_check("A launch pad throws Taln on its arc (peak ~%.0f m) onto its target (within 1.5 m)" % pad.apex,
			flight[0] and miss < 1.5 and peak_ok and absf(flight[2].y - pad.target.y) < 0.6,
			"landed %s, %.2f m from the target, peak %.2f m, at y %.2f" % [flight[0], miss, flight[3], flight[2].y])
	# Mid-air over a pad: nothing happens.
	taln.launch(Vector3(0.0, 6.0, 0.0))
	await _ticks(2)
	var threw: Array = [0]
	pad.threw.connect(func(_v: Vector3) -> void: threw[0] += 1)
	taln.global_position = pad.global_position + Vector3.UP * 2.0
	await _ticks(5)
	_check("A pad doesn't throw Taln while he's airborne", threw[0] == 0, "%d throws" % threw[0])


func _check_ridge() -> void:
	await _fresh(Vector3(60.0, 0.0, 48.0))  # 4 m south of the Tier I ridge, far from its passage.
	var ridge: CSGBox3D = station.get_node("RaisedGeometry/RidgeI1")
	var heave: Heave = _heave()
	# The longest throw a Heave can make: level 9, Overcharged, straight at the ridge.
	taln.loadout.get_behavior(&"heave").set_level(9)
	taln.launch(heave.launch_velocity(Vector3.FORWARD, taln.toauma.tuning.overcharge_mult))
	var flight: Array = await _fly()
	_check("12 m ridges stop the longest Heave from clearing a seal", ridge.size.y == 12.0 and flight[0]
			and flight[2].z > 44.0 and flight[3] < 12.0, "ridge %.0f m; peak %.2f m, landed at z %.2f"
			% [ridge.size.y, flight[3], flight[2].z])


func _check_camera() -> void:
	await _fresh()
	await _frames(5)
	var base: float = rig.get_node("PitchPivot/SpringArm3D").spring_length
	taln.launch(Vector3(0.0, 14.0, 0.0))
	await _ticks(60)
	var aloft: float = rig.get_node("PitchPivot/SpringArm3D").spring_length
	await _fly()
	var trauma: float = rig._trauma
	await _ticks(120)
	var after: float = rig.get_node("PitchPivot/SpringArm3D").spring_length
	_check("The camera pulls out up to 3 m in flight and back after; a hard landing shakes it",
			aloft > base + 2.5 and aloft <= base + 3.01 and absf(after - base) < 0.01 and trauma > 0.0,
			"%.2f → %.2f in the air → %.2f; trauma at landing %.2f" % [base, aloft, after, trauma])


func _check_telemetry() -> void:
	var telemetry: Telemetry = Telemetry.recorder()
	telemetry.enabled = true
	telemetry.directory = CHECKS_TELEMETRY
	await _fresh()
	_heave().try_cast()
	await _fly()
	await _ticks(10)
	cycle.end_cycle(Cycle.Outcome.CLOSED)
	await _frames(2)
	telemetry.enabled = false
	var file: Dictionary = TelemetryAnalysis.read(telemetry.path)
	var a: Dictionary = TelemetryAnalysis.analyze(file)
	var air: float = float(file.summary.get("airtime", 0.0))
	_check("Telemetry logs landings and Impacts and the cycle's air time", a.landings >= 1 and a.impacts == 1
			and air > 1.0 and air < 2.0, "%d landings, %d Impacts, %.2f s airborne" % [a.landings, a.impacts, air])
	for f in DirAccess.get_files_at(CHECKS_TELEMETRY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKS_TELEMETRY.path_join(f)))
	paused = false
