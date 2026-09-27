class_name SkillBehavior
extends Node3D
## Base for a skill's behavior scene root. Loadout sets skill, level and taln
## before adding it as a child, so they're ready in _ready. It's a Node3D so
## behaviors follow Taln.

signal level_changed(level: int)

var skill: SkillDef
var level: int = 1
var taln: Taln
## Seconds until the skill can act again (a Weapon's next swing, a Surge's
## next cast); 0 means ready. Skills without a timer leave it at 0.
var cooldown_left: float = 0.0


## This level's entry from skill.level_params.
func params() -> Dictionary:
	return skill.params_for(level)


func set_level(value: int) -> void:
	level = value
	level_changed.emit(level)


## A flat fan in the XZ plane pointing along +Z, cone_deg wide and radius
## long. UV.x runs across the fan (0 to 1), UV.y out from the apex.
static func build_fan_mesh(cone_deg: float, radius: float, segments: int) -> ArrayMesh:
	var half: float = deg_to_rad(cone_deg) * 0.5
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for k in segments:
		var u0: float = float(k) / segments
		var u1: float = float(k + 1) / segments
		var a0: float = lerpf(-half, half, u0)
		var a1: float = lerpf(-half, half, u1)
		vertices.append_array([Vector3.ZERO, Vector3(sin(a1), 0.0, cos(a1)) * radius,
				Vector3(sin(a0), 0.0, cos(a0)) * radius])
		uvs.append_array([Vector2((u0 + u1) * 0.5, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Places node flat at origin (lifted by lift) with its +Z along direction.
static func place_on_ground(node: Node3D, origin: Vector3, direction: Vector3, lift: float) -> void:
	node.global_transform = Transform3D(Basis(Vector3.UP, atan2(direction.x, direction.z)), origin + Vector3.UP * lift)
