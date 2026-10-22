class_name StoneWall
extends Structure
## A wall of raised stone (Bulwark, P2-11): a solid box the swarm has to go
## around. It joins the ground's wall group and rebuilds the ground's blocked
## cells on both ends of its life, so the flow field routes around it while
## it stands. It isn't a lure: nothing attacks a wall.

var size: Vector3 = Vector3(7.0, 2.5, 1.0)
## Yaw so the wall runs across the aim.
var yaw: float = 0.0

var _mesh: MeshInstance3D


func _init() -> void:
	kind = &"wall"


func _ready() -> void:
	rotation.y = yaw
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	body.add_child(shape)
	add_child(body)
	_mesh = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh.mesh = mesh
	_mesh.position.y = size.y * 0.5
	_mesh.material_override = stone_material()
	add_child(_mesh)
	_mesh.add_to_group(StationGround.WALL_BLOCK_GROUP)
	_rebuild_ground()


## The ground cells under the wall, with a margin for the step checks.
func footprint() -> Rect2:
	var reach: float = maxf(size.x, size.z) * 0.5 + 1.0
	var local: Vector3 = global_position - ground.global_position
	return Rect2(local.x - reach, local.z - reach, reach * 2.0, reach * 2.0)


func crumble(by_swarm: bool) -> void:
	if _gone:
		return
	_mesh.remove_from_group(StationGround.WALL_BLOCK_GROUP)
	var rect: Rect2 = footprint()
	super(by_swarm)
	# Sampled next physics frame, once this wall is gone.
	ground.rebuild_region(rect)


func _rebuild_ground() -> void:
	ground.rebuild_region(footprint())
