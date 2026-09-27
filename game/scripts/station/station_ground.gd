@tool
class_name StationGround
extends StaticBody3D
## Station ground as a heightfield on a 1 m grid centered on this node.
## Collision is one HeightMapShape3D; rendering is split into chunks so
## rebuild_region() only remeshes what changed. Cohesion edits the ground by
## calling set_height() and then rebuild_region(). Built at runtime (and in
## the editor), so the generated children are never saved into the scene.
##
## At runtime it also keeps per-cell ground data for SwarmServer (C++): the
## height of whatever walkable surface sits in each cell (the heightfield or
## raised geometry on it, found with downward rays) and a blocked mask. Both
## are row-major, index = z * get_width() + x, and cell (x, z) spans
## get_origin() + (x, z) * get_cell_size() in world XZ. Read them after the
## first ground_changed; rebuilt regions are resampled on the next physics
## frame and announced the same way.

## Emitted after cells were resampled. rect is in cell indices and already
## includes the one-cell border whose step checks an edit can change.
signal ground_changed(rect: Rect2i)

const CELL_SIZE := 1.0
## Nodes in this group block every cell their footprint touches.
const WALL_BLOCK_GROUP := &"wall_block"
## How far above and below this node the probe rays reach.
const PROBE_REACH := 1000.0
## Physics frames to wait before the first sample, so CSG collision that
## other nodes build deferred has reached the physics space.
const FIRST_SAMPLE_DELAY := 2

## Side length in meters (and cells). Must be a multiple of chunk_cells.
@export var size_m: int = 128
## Cells per side of one render chunk.
@export var chunk_cells: int = 16
@export var material: Material
@export var tuning: StationGroundTuning

var _verts_per_side: int = 0
var _heights: PackedFloat32Array = PackedFloat32Array()
var _shape: HeightMapShape3D
var _chunks: Array[MeshInstance3D] = []

var _cell_heights: PackedFloat32Array = PackedFloat32Array()
var _cell_normals: PackedVector3Array = PackedVector3Array()
var _blocked: PackedByteArray = PackedByteArray()
var _data_ready: bool = false
var _sample_delay: int = FIRST_SAMPLE_DELAY
var _pending: Rect2i = Rect2i()


func _ready() -> void:
	set_physics_process(false)
	if not Engine.is_editor_hint():
		var cells: int = size_m * size_m
		_cell_heights.resize(cells)
		_cell_normals.resize(cells)
		_blocked.resize(cells)

	_verts_per_side = size_m + 1
	_heights.resize(_verts_per_side * _verts_per_side)
	_heights.fill(0.0)

	_shape = HeightMapShape3D.new()
	_shape.map_width = _verts_per_side
	_shape.map_depth = _verts_per_side
	var collider := CollisionShape3D.new()
	collider.shape = _shape
	add_child(collider)

	var chunks_per_side: int = size_m / chunk_cells
	for i in chunks_per_side * chunks_per_side:
		var chunk := MeshInstance3D.new()
		chunk.material_override = material
		add_child(chunk)
		_chunks.append(chunk)

	rebuild_region(Rect2(-size_m * 0.5, -size_m * 0.5, size_m, size_m))


## Ground height at local (x, z), bilinearly interpolated between grid points.
func get_height(x: float, z: float) -> float:
	var gx: float = clampf(x + size_m * 0.5, 0.0, size_m)
	var gz: float = clampf(z + size_m * 0.5, 0.0, size_m)
	var ix: int = mini(floori(gx), size_m - 1)
	var iz: int = mini(floori(gz), size_m - 1)
	var fx: float = gx - ix
	var fz: float = gz - iz
	var top: float = lerpf(_height_at(ix, iz), _height_at(ix + 1, iz), fx)
	var bottom: float = lerpf(_height_at(ix, iz + 1), _height_at(ix + 1, iz + 1), fx)
	return lerpf(top, bottom, fz)


## Sets the grid point nearest local (x, z). Call rebuild_region() afterwards.
func set_height(x: float, z: float, h: float) -> void:
	var ix: int = clampi(roundi(x + size_m * 0.5), 0, size_m)
	var iz: int = clampi(roundi(z + size_m * 0.5), 0, size_m)
	_heights[iz * _verts_per_side + ix] = h


## Pushes height edits inside rect (local XZ meters: position = min x/z) to
## collision and remeshes the chunks it touches.
func rebuild_region(rect: Rect2) -> void:
	_shape.map_data = _heights

	var chunks_per_side: int = size_m / chunk_cells
	var half: float = size_m * 0.5
	var first_x: int = clampi(floori((rect.position.x + half) / chunk_cells), 0, chunks_per_side - 1)
	var first_z: int = clampi(floori((rect.position.y + half) / chunk_cells), 0, chunks_per_side - 1)
	var last_x: int = clampi(floori((rect.end.x + half) / chunk_cells), 0, chunks_per_side - 1)
	var last_z: int = clampi(floori((rect.end.y + half) / chunk_cells), 0, chunks_per_side - 1)
	for cz in range(first_z, last_z + 1):
		for cx in range(first_x, last_x + 1):
			_chunks[cz * chunks_per_side + cx].mesh = _build_chunk_mesh(cx, cz)
	_queue_sample(rect)


## Cells along X.
func get_width() -> int:
	return size_m


## Cells along Z.
func get_depth() -> int:
	return size_m


func get_cell_size() -> float:
	return CELL_SIZE


## World XZ of the min corner of cell (0, 0).
func get_origin() -> Vector2:
	var half: float = size_m * CELL_SIZE * 0.5
	return Vector2(global_position.x - half, global_position.z - half)


## World-space surface height per cell (at its center).
func get_height_array() -> PackedFloat32Array:
	return _cell_heights


## 1 per blocked cell, 0 per walkable one.
func get_blocked_mask() -> PackedByteArray:
	return _blocked


## True if the cell under world XZ (x, z) is blocked or off the ground.
func is_blocked_at(x: float, z: float) -> bool:
	var index: int = _cell_index_at(x, z)
	return index < 0 or _blocked[index] == 1


## Sampled surface height of the cell under world XZ (x, z); 0 off the ground.
func get_surface_height_at(x: float, z: float) -> float:
	var index: int = _cell_index_at(x, z)
	return _cell_heights[index] if index >= 0 else 0.0


## False until the first sample has run and ground_changed has fired.
func is_ground_data_ready() -> bool:
	return _data_ready


func _physics_process(_delta: float) -> void:
	if _sample_delay > 0:
		_sample_delay -= 1
		return
	set_physics_process(false)
	var cells: Rect2i = _pending
	_pending = Rect2i()
	_sample(cells)
	_data_ready = true
	ground_changed.emit(cells)


## Row-major index of the cell under world XZ (x, z), or -1 off the ground.
func _cell_index_at(x: float, z: float) -> int:
	var origin: Vector2 = get_origin()
	var cx: int = floori((x - origin.x) / CELL_SIZE)
	var cz: int = floori((z - origin.y) / CELL_SIZE)
	if cx < 0 or cz < 0 or cx >= size_m or cz >= size_m:
		return -1
	return cz * size_m + cx


## Marks the cells touching rect (local XZ meters), plus one for the step
## checks, for sampling on the next physics frame.
func _queue_sample(rect: Rect2) -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var half: float = size_m * 0.5
	var first := Vector2i(ceili(rect.position.x + half) - 2, ceili(rect.position.y + half) - 2)
	var end := Vector2i(floori(rect.end.x + half) + 2, floori(rect.end.y + half) + 2)
	var cells := Rect2i(first, end - first).intersection(Rect2i(0, 0, size_m, size_m))
	if not cells.has_area():
		return
	_pending = cells if not _pending.has_area() else _pending.merge(cells)
	set_physics_process(true)


## Probes heights and normals for cells (grown by one so the step checks at
## its edge see their neighbors), then recomputes the blocked mask in cells.
func _sample(cells: Rect2i) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	var probed: Rect2i = cells.grow(1).intersection(Rect2i(0, 0, size_m, size_m))
	var origin: Vector2 = get_origin()
	for z in range(probed.position.y, probed.end.y):
		for x in range(probed.position.x, probed.end.x):
			var at := Vector3(origin.x + (x + 0.5) * CELL_SIZE, global_position.y, origin.y + (z + 0.5) * CELL_SIZE)
			var hit: Dictionary = _probe(space, query, at)
			var i: int = z * size_m + x
			if hit.is_empty():
				_cell_heights[i] = global_position.y + get_height(at.x - global_position.x, at.z - global_position.z)
				_cell_normals[i] = Vector3.ZERO  # Reads as too steep, so blocked.
			else:
				_cell_heights[i] = (hit.position as Vector3).y
				_cell_normals[i] = hit.normal

	var min_normal_y: float = cos(deg_to_rad(tuning.max_slope_deg))
	var walls: Array[Rect2] = _wall_footprints()
	for z in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			var blocked: bool = _cell_normals[z * size_m + x].y < min_normal_y \
					or _covered(x, z, walls) \
					or _steps_off(x, z, min_normal_y)
			_blocked[z * size_m + x] = 1 if blocked else 0


## Downward ray at world XZ of at, skipping characters and rigid bodies.
func _probe(space: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D, at: Vector3) -> Dictionary:
	query.from = at + Vector3.UP * PROBE_REACH
	query.to = at + Vector3.DOWN * PROBE_REACH
	var exclude: Array[RID] = []
	while true:
		query.exclude = exclude
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or not (hit.collider is CharacterBody3D or hit.collider is RigidBody3D):
			return hit
		exclude.append(hit.rid)
	return {}


## Wall-block footprints in grid meters (0..size_m on each axis).
func _wall_footprints() -> Array[Rect2]:
	var footprints: Array[Rect2] = []
	var origin: Vector2 = get_origin()
	for node: Node in get_tree().get_nodes_in_group(WALL_BLOCK_GROUP):
		var box: AABB
		if node is CSGBox3D:
			var size: Vector3 = (node as CSGBox3D).size
			box = AABB(-size * 0.5, size)
		elif node is VisualInstance3D:
			box = (node as VisualInstance3D).get_aabb()
		else:
			push_warning("%s is in %s but has no box to block with." % [node.name, WALL_BLOCK_GROUP])
			continue
		box = (node as Node3D).global_transform * box
		footprints.append(Rect2(box.position.x - origin.x, box.position.z - origin.y, box.size.x, box.size.z))
	return footprints


func _covered(x: int, z: int, walls: Array[Rect2]) -> bool:
	var cell := Rect2(x * CELL_SIZE, z * CELL_SIZE, CELL_SIZE, CELL_SIZE)
	for wall in walls:
		if cell.intersects(wall):
			return true
	return false


## True if a 4-neighbor sits more than a step above or below this cell once
## the rise its slope, or the neighbor's, explains is taken out. A rise
## anywhere between the two slopes' predictions is a crease between walkable
## planes (a ramp meeting flat ground), not a step.
func _steps_off(x: int, z: int, min_normal_y: float) -> bool:
	var i: int = z * size_m + x
	var here: Vector3 = _cell_normals[i]
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + offset.x
		var nz: int = z + offset.y
		if nx < 0 or nz < 0 or nx >= size_m or nz >= size_m:
			continue
		var j: int = nz * size_m + nx
		var rise: float = _cell_heights[j] - _cell_heights[i]
		var low: float = _slope_rise(here, offset)
		var high: float = low
		var there: Vector3 = _cell_normals[j]
		if there.y >= min_normal_y:
			var theirs: float = _slope_rise(there, offset)
			low = minf(low, theirs)
			high = maxf(high, theirs)
		var step: float = maxf(low - rise, rise - high)
		if step > tuning.max_step_m:
			return true
	return false


## Rise over one cell along offset on the plane with this normal.
func _slope_rise(normal: Vector3, offset: Vector2i) -> float:
	return -(normal.x * offset.x + normal.z * offset.y) / normal.y * CELL_SIZE


func _height_at(ix: int, iz: int) -> float:
	return _heights[iz * _verts_per_side + ix]


func _build_chunk_mesh(cx: int, cz: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = size_m * 0.5
	for iz in range(cz * chunk_cells, (cz + 1) * chunk_cells):
		for ix in range(cx * chunk_cells, (cx + 1) * chunk_cells):
			var a := Vector3(ix - half, _height_at(ix, iz), iz - half)
			var b := Vector3(ix + 1 - half, _height_at(ix + 1, iz), iz - half)
			var c := Vector3(ix - half, _height_at(ix, iz + 1), iz + 1 - half)
			var d := Vector3(ix + 1 - half, _height_at(ix + 1, iz + 1), iz + 1 - half)
			# Clockwise seen from above, which is Godot's front face.
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(d)
			st.add_vertex(c)
	st.generate_normals()
	return st.commit()
