class_name FlashRing
extends MeshInstance3D
## Placeholder visual for the P2-10 kit skills: a flat ring that appears where
## a skill lands and fades within its time (Art Direction VFX rule: never
## hides telegraphs for long). Top-level, so it stays where it was shown.

const LIFT := 0.03
const WIDTH := 0.15
const SEGMENTS := 48

var color: Color = Color.WHITE
var time: float = 0.2

var _left: float = 0.0
var _material := StandardMaterial3D.new()


func _ready() -> void:
	top_level = true
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Animated in _process, so engine interpolation would only smear it.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mesh = SkillBehavior.build_ring_mesh(1.0 - WIDTH, 1.0, SEGMENTS)
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _material


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(_left - delta, 0.0)
	visible = _left > 0.0
	_material.albedo_color = Color(color, color.a * _left / time)


func show_at(at: Vector3, radius: float) -> void:
	global_position = at + Vector3.UP * LIFT
	scale = Vector3(radius, 1.0, radius)
	_material.albedo_color = color
	_left = time
	visible = time > 0.0
