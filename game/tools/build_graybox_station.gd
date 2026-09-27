extends SceneTree
## One-shot generator for scenes/graybox_station.tscn (P2-01 step 3). The
## ramp and stair geometry is computed here so the angles and rises are exact.
## Rerunning it overwrites manual edits to that scene.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tools/build_graybox_station.gd

const OUT_PATH := "res://scenes/graybox_station.tscn"

const GROUND_COLOR := Color("2a2825")
const RAISED_COLOR := Color("5a564f")
const BACKGROUND_COLOR := Color("0b0b0e")

const GROUND_SIZE := 128
const PLATEAU_RADIUS := 12.0
const PLATEAU_HEIGHT := 1.5
const PLATEAU_SIDES := 9
const RAMP_WIDTH := 4.0
## Ramp angle in degrees -> which plateau face it sits on (face 0 faces +Z).
const RAMPS := {20.0: 0, 35.0: 3, 45.0: 6}
const LEDGE_HEIGHT := 3.0
const STAIR_TREAD := 0.6
const STAIR_WIDTH := 3.0
## How far one shape overlaps the next so the CSG union has no seams.
const OVERLAP := 0.2

var _root: Node3D


func _init() -> void:
	_root = Node3D.new()
	_root.name = "GrayboxStation"
	_root.set_script(load("res://scripts/station/graybox_station.gd"))

	_add_lighting()
	_add_ground()
	_add_raised_geometry()
	_add_boundary()
	_add_pools()

	var spawn := Marker3D.new()
	spawn.name = "TalnSpawn"
	spawn.position = Vector3(0.0, 0.0, 30.0)
	_own(spawn, _root)
	_add_taln_and_camera(spawn.position)

	var packed := PackedScene.new()
	packed.pack(_root)
	print("save scene: ", ResourceSaver.save(packed, OUT_PATH))
	_root.free()
	_strip_instance_overrides()
	_update_project_settings()
	quit()


## pack() from a --script run writes each instanced scene's own script and
## tuning back out as overrides. Drop them (and the ext_resources they used)
## so edits to the instanced scenes (Taln, camera rig, pools, overlay) still apply.
func _strip_instance_overrides() -> void:
	var lines: PackedStringArray = FileAccess.get_file_as_string(OUT_PATH).split("\n")
	var kept := PackedStringArray()
	var in_instance := false
	for line in lines:
		if line.begins_with("["):
			in_instance = line.contains("instance=")
		elif in_instance and (line.begins_with("script = ") or line.begins_with("tuning = ")):
			continue
		kept.append(line)
	var text: String = "\n".join(kept)
	var cleaned := PackedStringArray()
	var id_regex := RegEx.create_from_string("^\\[ext_resource .* id=\"([^\"]+)\"\\]$")
	for line in text.split("\n"):
		var found: RegExMatch = id_regex.search(line)
		if found and not text.contains("ExtResource(\"%s\")" % found.get_string(1)):
			continue
		cleaned.append(line)
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	file.store_string("\n".join(cleaned))


func _own(node: Node, parent: Node) -> Node:
	parent.add_child(node)
	node.owner = _root
	return node


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat


func _add_lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.ambient_light_energy = 0.15
	env.fog_enabled = true
	env.fog_light_color = Color.BLACK
	env.fog_density = 0.02
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	_own(world_env, _root)

	var inspect := DirectionalLight3D.new()
	inspect.name = "InspectLight"
	inspect.visible = false
	inspect.shadow_enabled = true
	inspect.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	_own(inspect, _root)


func _add_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "StationGround"
	ground.set_script(load("res://scripts/station/station_ground.gd"))
	ground.set("size_m", GROUND_SIZE)
	ground.set("material", _flat_material(GROUND_COLOR))
	ground.set("tuning", load("res://data/tuning/station_ground_tuning.tres"))
	_own(ground, _root)


func _add_raised_geometry() -> void:
	var raised := CSGCombiner3D.new()
	raised.name = "RaisedGeometry"
	raised.use_collision = true
	raised.material_override = _flat_material(RAISED_COLOR)
	_own(raised, _root)

	# Nine-sided plateau. Vertices sit between faces, so face k points along
	# angle 40k° from +Z. Rotating +90° about X lays the polygon on XZ and
	# extrudes it upward.
	var plateau := CSGPolygon3D.new()
	plateau.name = "Plateau"
	var face_step: float = TAU / PLATEAU_SIDES
	var points := PackedVector2Array()
	for k in PLATEAU_SIDES:
		var a: float = face_step * (k + 0.5)
		points.append(Vector2(sin(a), cos(a)) * PLATEAU_RADIUS)
	plateau.polygon = points
	plateau.depth = PLATEAU_HEIGHT
	plateau.rotation.x = PI / 2.0
	_own(plateau, raised)

	var apothem: float = PLATEAU_RADIUS * cos(face_step / 2.0)
	for angle: float in RAMPS:
		var face: int = RAMPS[angle]
		var normal := Vector3(sin(face_step * face), 0.0, cos(face_step * face))
		_add_ramp(raised, "Ramp%d" % int(angle), angle, PLATEAU_HEIGHT, normal * apothem, normal)

	# 3 m ledge. The only way up is a 20° ramp from the west; the other sides drop.
	_add_box(raised, "Ledge", Vector3(10.0, LEDGE_HEIGHT, 10.0), Vector3(32.0, LEDGE_HEIGHT / 2.0, 0.0))
	_add_ramp(raised, "LedgeRamp20", 20.0, LEDGE_HEIGHT, Vector3(27.0, 0.0, 0.0), Vector3.LEFT)

	# 0.3 m steps (within Taln's step height) up to a 1.5 m platform.
	_add_box(raised, "StepPlatform030", Vector3(4.0, 1.5, 4.0), Vector3(34.2, 0.75, -14.0))
	_add_stairs(raised, "Steps030", 5, 0.3, Vector3(32.2 - 5 * STAIR_TREAD, 0.0, -14.0 + STAIR_WIDTH / 2.0))

	# 0.4 m steps (above Taln's step height) up to a 1.6 m platform.
	_add_box(raised, "StepPlatform040", Vector3(4.0, 1.6, 4.0), Vector3(-34.2, 0.8, 0.0))
	_add_stairs(raised, "Steps040", 4, 0.4, Vector3(-36.2 - 4 * STAIR_TREAD, 0.0, STAIR_WIDTH / 2.0))

	# Walls block the ground under them for swarm navigation (StationGround).
	var walls: Array[CSGBox3D] = [
		_add_box(raised, "WallLong", Vector3(12.0, 3.0, 1.0), Vector3(0.0, 1.5, -36.0)),
		_add_box(raised, "WallEast", Vector3(1.0, 3.0, 8.0), Vector3(24.0, 1.5, -30.0)),
		_add_box(raised, "WallBlock", Vector3(4.0, 3.0, 4.0), Vector3(-24.0, 1.5, -30.0)),
	]
	for wall in walls:
		wall.add_to_group(StationGround.WALL_BLOCK_GROUP, true)


## A wedge ramp of the given angle rising to height at top_edge (the middle of
## its top edge) and running down along outward.
func _add_ramp(parent: Node, ramp_name: String, angle: float, height: float,
		top_edge: Vector3, outward: Vector3) -> void:
	var length: float = height / tan(deg_to_rad(angle))
	var ramp := CSGPolygon3D.new()
	ramp.name = ramp_name
	ramp.polygon = PackedVector2Array([
		Vector2(-OVERLAP, 0.0), Vector2(length, 0.0),
		Vector2(0.0, height), Vector2(-OVERLAP, height),
	])
	ramp.depth = RAMP_WIDTH
	# Profile X runs along outward, Y is up, extrusion is -Z.
	var side: Vector3 = outward.cross(Vector3.UP)
	ramp.transform = Transform3D(Basis(outward, Vector3.UP, side), top_edge + side * (RAMP_WIDTH / 2.0))
	_own(ramp, parent)


func _add_box(parent: Node, box_name: String, size: Vector3, center: Vector3) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.position = center
	_own(box, parent)
	return box


## Stairs climbing +X from origin; the last tread runs OVERLAP past the top
## riser into whatever it leads to.
func _add_stairs(parent: Node, stairs_name: String, steps: int, rise: float, origin: Vector3) -> void:
	var points := PackedVector2Array([Vector2.ZERO])
	for i in steps:
		points.append(Vector2(i * STAIR_TREAD, (i + 1) * rise))
		if i < steps - 1:
			points.append(Vector2((i + 1) * STAIR_TREAD, (i + 1) * rise))
	points.append(Vector2(steps * STAIR_TREAD + OVERLAP, steps * rise))
	points.append(Vector2(steps * STAIR_TREAD + OVERLAP, 0.0))
	var stairs := CSGPolygon3D.new()
	stairs.name = stairs_name
	stairs.polygon = points
	stairs.depth = STAIR_WIDTH
	stairs.position = origin
	_own(stairs, parent)


func _add_boundary() -> void:
	var body := StaticBody3D.new()
	body.name = "BoundaryWalls"
	_own(body, _root)
	var half: float = GROUND_SIZE / 2.0
	var height := 20.0
	var walls := {
		"North": [Vector3(GROUND_SIZE + 2.0, height, 1.0), Vector3(0.0, height / 2.0, -half - 0.5)],
		"South": [Vector3(GROUND_SIZE + 2.0, height, 1.0), Vector3(0.0, height / 2.0, half + 0.5)],
		"West": [Vector3(1.0, height, GROUND_SIZE + 2.0), Vector3(-half - 0.5, height / 2.0, 0.0)],
		"East": [Vector3(1.0, height, GROUND_SIZE + 2.0), Vector3(half + 0.5, height / 2.0, 0.0)],
	}
	for wall_name: String in walls:
		var shape := BoxShape3D.new()
		shape.size = walls[wall_name][0]
		var collider := CollisionShape3D.new()
		collider.name = wall_name
		collider.shape = shape
		collider.position = walls[wall_name][1]
		_own(collider, body)


func _add_pools() -> void:
	var pool_scene: PackedScene = load("res://scenes/well_pool.tscn")
	var spots: Array[Vector3] = [Vector3(-22.0, 0.0, 24.0), Vector3(22.0, 0.0, 24.0), Vector3(0.0, 0.0, -24.0)]
	for i in spots.size():
		var pool: Node3D = pool_scene.instantiate()
		pool.name = "WellPool%d" % (i + 1)
		pool.position = spots[i]
		_own(pool, _root)


func _add_taln_and_camera(spawn: Vector3) -> void:
	var taln: Node3D = (load("res://scenes/taln.tscn") as PackedScene).instantiate()
	taln.position = spawn
	_own(taln, _root)
	var rig: Node3D = (load("res://scenes/camera_rig.tscn") as PackedScene).instantiate()
	rig.set("target", taln)
	_own(rig, _root)

	# SwarmServer v0: the swarm and the director that spawns it around Taln.
	var swarm := SwarmServer.new()
	swarm.name = "SwarmServer"
	swarm.tuning = load("res://data/tuning/swarm_tuning.tres")
	_own(swarm, _root)
	var spawner := Node.new()
	spawner.name = "SpawnDirector"
	spawner.set_script(load("res://scripts/swarm/spawn_director.gd"))
	spawner.set("tuning", load("res://data/tuning/spawn_tuning.tres"))
	spawner.set("swarm_type", load("res://data/swarm/ash_walker.tres"))
	spawner.set("swarm", swarm)
	spawner.set("ground", _root.get_node("StationGround"))
	spawner.set("target", taln)
	_own(spawner, _root)

	var overlay: Node = (load("res://scenes/debug_overlay.tscn") as PackedScene).instantiate()
	overlay.set("taln", taln)
	overlay.set("camera_rig", rig)
	overlay.set("swarm", swarm)
	overlay.set("spawner", spawner)
	overlay.set("agony_tuning", load("res://data/tuning/agony_tuning.tres"))
	_own(overlay, _root)


func _update_project_settings() -> void:
	ProjectSettings.set_setting("application/run/main_scene", OUT_PATH)
	print("save settings: ", ProjectSettings.save())
