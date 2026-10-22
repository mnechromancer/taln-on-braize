extends "res://tools/build_graybox_station.gd"
## One-shot generator for scenes/braize_slice.tscn (P2-10): a 256 m slice of
## the persistent map with three regions, one per tier, stacked north (deeper)
## from the Tier I entry in the south. Ridges split the regions; each exit
## through a ridge is sealed until that region's breaker falls. The Tier II
## ridge has two routes: an open one far west and a gated shortcut by the
## Tier II breaker site. Reuses the station builder's wiring. Rerunning it
## overwrites manual edits to that scene, and makes it the main scene.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tools/build_braize_slice.gd

const SLICE_PATH := "res://scenes/braize_slice.tscn"
const SLICE_SIZE := 256

const SEAL_COLOR := Color("3a2f4a")
const GATE_COLOR := Color("6b3fa0")

## Taller than any launch peaks, so a launch can't clear a seal (P2-12).
const RIDGE_HEIGHT := 12.0
const RIDGE_THICKNESS := 2.0
const PASSAGE_WIDTH := 8.0
## Ridge lines (z) and the passages through each (x centers).
const RIDGE_I_Z := 43.0
const RIDGE_I_PASSAGES: Array[float] = [0.0]
const RIDGE_II_Z := -43.0
const RIDGE_II_OPEN_X := -108.0
const RIDGE_II_GATED_X := 40.0
## The gate blocker sits this far along z from the ridge line: just north of the Tier II seal.
const GATE_OFFSET := -1.5

## Launch pads (P2-12): position, landing target, apex above the pad. Each
## lands inside its own region: onto plateaus and ledges, or across the region.
const LAUNCH_PADS := [
	[Vector3(48.0, 0.0, 104.0), Vector3(20.0, 1.5, 82.0), 6.0],
	[Vector3(-10.0, 0.0, 110.0), Vector3(-30.0, 3.0, 100.0), 6.0],
	[Vector3(60.0, 0.0, 52.0), Vector3(-20.0, 0.0, 70.0), 10.0],
	[Vector3(0.0, 0.0, 35.0), Vector3(-40.0, 3.0, 0.0), 7.0],
	[Vector3(60.0, 0.0, 30.0), Vector3(30.0, 4.5, 18.0), 7.0],
	[Vector3(-90.0, 0.0, 0.0), Vector3(-100.0, 0.0, -30.0), 8.0],
	[Vector3(-100.0, 0.0, -60.0), Vector3(-40.0, 0.0, -100.0), 10.0],
	[Vector3(20.0, 0.0, -60.0), Vector3(60.0, 1.5, -90.0), 7.0],
]

## id, display name, tier, bounds (x, z, width, depth), breaker site.
const REGIONS := [
	[&"the_shelf", "The Shelf", 1, Rect2(-128.0, 44.0, 256.0, 84.0), Vector3(-80.0, 0.0, 80.0)],
	[&"ninefold_descent", "Ninefold Descent", 2, Rect2(-128.0, -42.0, 256.0, 84.0), Vector3(70.0, 0.0, -10.0)],
	[&"where_he_kept_the_count", "Where He Kept the Count", 3, Rect2(-128.0, -128.0, 256.0, 84.0), Vector3(0.0, 0.0, -100.0)],
]


func _out_path() -> String:
	return SLICE_PATH


func _root_name() -> String:
	return "BraizeSlice"


func _root_script() -> String:
	return "res://scripts/map/braize_slice.gd"


func _ground_size() -> int:
	return SLICE_SIZE


func _spawn_position() -> Vector3:
	return Vector3(60.0, 0.0, 112.0)


func _is_main_scene() -> bool:
	return true


func _add_raised_geometry() -> void:
	var raised := CSGCombiner3D.new()
	raised.name = "RaisedGeometry"
	raised.use_collision = true
	raised.material_override = _flat_material(RAISED_COLOR)
	_own(raised, _root)
	var walls: Array[CSGBox3D] = []

	# Ridges between the tiers, broken by their passages.
	walls.append_array(_add_ridge(raised, "RidgeI", RIDGE_I_Z, RIDGE_I_PASSAGES))
	walls.append_array(_add_ridge(raised, "RidgeII", RIDGE_II_Z, [RIDGE_II_OPEN_X, RIDGE_II_GATED_X]))

	# Tier I, The Shelf: a nine-sided plateau, a 3 m ledge with one ramp, two walls.
	_add_plateau(raised, "ShelfPlateau", Vector3(20.0, 0.0, 80.0), 12.0, 1.5, [0, 3, 6])
	_add_box(raised, "ShelfLedge", Vector3(10.0, 3.0, 10.0), Vector3(-30.0, 1.5, 100.0))
	_add_ramp(raised, "ShelfLedgeRamp", 20.0, 3.0, Vector3(-25.0, 0.0, 100.0), Vector3.RIGHT)
	walls.append(_add_box(raised, "ShelfWallA", Vector3(12.0, 3.0, 1.0), Vector3(-50.0, 1.5, 60.0)))
	walls.append(_add_box(raised, "ShelfWallB", Vector3(1.0, 3.0, 10.0), Vector3(85.0, 1.5, 60.0)))

	# Tier II, Ninefold Descent: a high plateau, a 4.5 m drop ledge, two walls.
	_add_plateau(raised, "DescentPlateau", Vector3(-40.0, 0.0, 0.0), 14.0, 3.0, [0, 4])
	_add_box(raised, "DescentLedge", Vector3(10.0, 4.5, 10.0), Vector3(30.0, 2.25, 20.0))
	_add_ramp(raised, "DescentLedgeRamp", 20.0, 4.5, Vector3(30.0, 0.0, 25.0), Vector3.BACK)
	walls.append(_add_box(raised, "DescentWallA", Vector3(16.0, 3.0, 1.0), Vector3(0.0, 1.5, -20.0)))
	walls.append(_add_box(raised, "DescentWallB", Vector3(1.0, 3.0, 14.0), Vector3(95.0, 1.5, 15.0)))

	# Tier III, Where He Kept the Count: a plateau and two walls by the site.
	_add_plateau(raised, "CountPlateau", Vector3(60.0, 0.0, -90.0), 12.0, 1.5, [2, 5, 8])
	walls.append(_add_box(raised, "CountWallA", Vector3(1.0, 3.0, 16.0), Vector3(-30.0, 1.5, -80.0)))
	walls.append(_add_box(raised, "CountWallB", Vector3(16.0, 3.0, 1.0), Vector3(30.0, 1.5, -112.0)))

	for wall in walls:
		wall.add_to_group(StationGround.WALL_BLOCK_GROUP, true)


func _add_pools() -> void:
	var pool_scene: PackedScene = load("res://scenes/well_pool.tscn")
	var spots: Array[Vector3] = [Vector3(40.0, 0.0, 98.0), Vector3(0.0, 0.0, 112.0), Vector3(70.0, 0.0, 66.0)]
	for i in spots.size():
		var pool: Node3D = pool_scene.instantiate()
		pool.name = "WellPool%d" % (i + 1)
		pool.position = spots[i]
		_own(pool, _root)


func _add_extras() -> void:
	var tuning: RegionTuning = load("res://data/tuning/region_tuning.tres")
	_root.set("region_tuning", tuning)
	for entry: Array in REGIONS:
		var region := Node3D.new()
		region.name = String(entry[0]).to_pascal_case()
		region.set_script(load("res://scripts/map/region.gd"))
		region.set("id", entry[0])
		region.set("display_name", entry[1])
		region.set("tier", entry[2])
		region.set("bounds", entry[3])
		_own(region, _root)
		var site := Node3D.new()
		site.name = "BreakerSite"
		site.set_script(load("res://scripts/map/breaker_site.gd"))
		site.set("tuning", tuning)
		site.position = entry[4]
		_own(site, region)
		var seals := Node3D.new()
		seals.name = "Seals"
		_own(seals, region)
		match int(entry[2]):
			1:
				_add_barrier(seals, "Seal", Vector3(RIDGE_I_PASSAGES[0], 0.0, RIDGE_I_Z), SEAL_COLOR)
			2:
				_add_barrier(seals, "SealWest", Vector3(RIDGE_II_OPEN_X, 0.0, RIDGE_II_Z), SEAL_COLOR)
				_add_barrier(seals, "SealShortcut", Vector3(RIDGE_II_GATED_X, 0.0, RIDGE_II_Z), SEAL_COLOR)

	var gate := Node3D.new()
	gate.name = "ShortcutGate"
	gate.set_script(load("res://scripts/map/gate.gd"))
	var gate_def: GateDef = load("res://data/map/shortcut_gate.tres")
	gate.set("def", gate_def)
	_own(gate, _root)
	_add_barrier(gate, "Blocker", Vector3(RIDGE_II_GATED_X, 0.0, RIDGE_II_Z + GATE_OFFSET), GATE_COLOR, 1.0)

	var gates: Array[GateDef] = [gate_def]
	var screen: Node = _root.get_node("BetweenRunScreen")
	screen.set("gates", gates)
	# Meteor's kit and the breaker-drop skills' caps can be raised too.
	var cap_skills: Array[SkillDef] = screen.get("cap_skills")
	cap_skills.append_array([load("res://data/skills/impact.tres"), load("res://data/skills/heave.tres")])
	cap_skills.append_array(tuning.breaker_offer_pool)
	screen.set("cap_skills", cap_skills)

	var launch_tuning: LaunchTuning = load("res://data/tuning/launch_tuning.tres")
	for i in LAUNCH_PADS.size():
		var pad := Node3D.new()
		pad.name = "LaunchPad%d" % (i + 1)
		pad.set_script(load("res://scripts/map/launch_pad.gd"))
		pad.set("tuning", launch_tuning)
		pad.position = LAUNCH_PADS[i][0]
		pad.set("target", LAUNCH_PADS[i][1])
		pad.set("apex", LAUNCH_PADS[i][2])
		_own(pad, _root)

	var start := CanvasLayer.new()
	start.name = "StartScreen"
	start.set_script(load("res://scripts/ui/start_screen.gd"))
	start.set("slice", _root)
	_own(start, _root)

	var kit_menu := CanvasLayer.new()
	kit_menu.name = "KitOfferMenu"
	kit_menu.set_script(load("res://scripts/ui/kit_offer_menu.gd"))
	kit_menu.set("slice", _root)
	kit_menu.set("taln", _root.get_node("Taln"))
	kit_menu.set("catalysis", _root.get_node("Catalysis"))
	kit_menu.set("level_menu", _root.get_node("LevelUpMenu"))
	_own(kit_menu, _root)


## A ridge along x at z, with a PASSAGE_WIDTH gap at each passage center.
func _add_ridge(parent: Node, ridge_name: String, z: float, passages: Array[float]) -> Array[CSGBox3D]:
	var half: float = SLICE_SIZE / 2.0
	var edges: Array[float] = [-half]
	var sorted: Array[float] = passages.duplicate()
	sorted.sort()
	for x in sorted:
		edges.append(x - PASSAGE_WIDTH / 2.0)
		edges.append(x + PASSAGE_WIDTH / 2.0)
	edges.append(half)
	var boxes: Array[CSGBox3D] = []
	for i in range(0, edges.size(), 2):
		var from: float = edges[i]
		var to: float = edges[i + 1]
		boxes.append(_add_box(parent, "%s%d" % [ridge_name, i / 2], Vector3(to - from, RIDGE_HEIGHT, RIDGE_THICKNESS),
				Vector3((from + to) / 2.0, RIDGE_HEIGHT / 2.0, z)))
	return boxes


## A nine-sided plateau at center with a 20° ramp on each listed face (face
## k points along 40k° from +Z).
func _add_plateau(parent: Node, plateau_name: String, center: Vector3, radius: float, height: float,
		ramp_faces: Array) -> void:
	var plateau := CSGPolygon3D.new()
	plateau.name = plateau_name
	var face_step: float = TAU / PLATEAU_SIDES
	var points := PackedVector2Array()
	for k in PLATEAU_SIDES:
		var a: float = face_step * (k + 0.5)
		points.append(Vector2(sin(a), cos(a)) * radius)
	plateau.polygon = points
	plateau.depth = height
	plateau.rotation.x = PI / 2.0
	plateau.position = center
	_own(plateau, parent)
	var apothem: float = radius * cos(face_step / 2.0)
	for face: int in ramp_faces:
		var normal := Vector3(sin(face_step * face), 0.0, cos(face_step * face))
		_add_ramp(parent, "%sRamp%d" % [plateau_name, face], 20.0, height, center + normal * apothem, normal)


## A standalone barrier box (a seal or a gate blocker) filling a passage at
## center: its own collision, blocking the swarm's ground cells.
func _add_barrier(parent: Node, barrier_name: String, center: Vector3, color: Color,
		thickness: float = RIDGE_THICKNESS) -> void:
	var box := CSGBox3D.new()
	box.name = barrier_name
	box.size = Vector3(PASSAGE_WIDTH + OVERLAP * 2.0, RIDGE_HEIGHT, thickness)
	box.position = center + Vector3.UP * RIDGE_HEIGHT / 2.0
	box.use_collision = true
	box.material_override = _flat_material(color)
	_own(box, parent)
	box.add_to_group(StationGround.WALL_BLOCK_GROUP, true)
