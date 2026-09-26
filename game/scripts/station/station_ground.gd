@tool
class_name StationGround
extends StaticBody3D
## Station ground as a heightfield on a 1 m grid centered on this node.
## Collision is one HeightMapShape3D; rendering is split into chunks so
## rebuild_region() only remeshes what changed. Cohesion edits the ground by
## calling set_height() and then rebuild_region(). Built at runtime (and in
## the editor), so the generated children are never saved into the scene.

## Side length in meters (and cells). Must be a multiple of chunk_cells.
@export var size_m: int = 128
## Cells per side of one render chunk.
@export var chunk_cells: int = 16
@export var material: Material

var _verts_per_side: int = 0
var _heights: PackedFloat32Array = PackedFloat32Array()
var _shape: HeightMapShape3D
var _chunks: Array[MeshInstance3D] = []


func _ready() -> void:
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
