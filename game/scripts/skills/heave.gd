class_name Heave
extends SurgeBehavior
## Heave, Meteor's starting Surge (Stoneward, Cohesion; P2-12): a pillar of
## stone shoves up under Taln and flings him along the aim, soft-locked
## toward the densest cluster, so he lands in the crowd. Only from the
## ground: the ground throws him, he never jumps (spec v1.4 #3). The arc
## peaks apex meters up and comes down distance meters out on level ground;
## Overcharge stretches the distance by the magnitude, and Taln's mass
## (Impact's levels) shortens it.
##
## level_params keys: distance (m), apex (m).

@export var pillar_color: Color = Color("#D9A55B")
@export_range(0.0, 1.0, 0.01, "suffix:s") var pillar_time: float = 0.0
@export_range(0.1, 3.0, 0.05, "suffix:m") var pillar_radius: float = 0.6

var _pillar: MeshInstance3D
var _pillar_left: float = 0.0
var _pillar_base: Vector3 = Vector3.ZERO

@onready var _flash: FlashRing = $Flash


func _ready() -> void:
	_flash.color = pillar_color
	_flash.time = pillar_time
	_pillar = MeshInstance3D.new()
	_pillar.top_level = true
	_pillar.visible = false
	_pillar.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var column := CylinderMesh.new()
	column.top_radius = pillar_radius
	column.bottom_radius = pillar_radius * 1.3
	column.height = 1.0
	_pillar.mesh = column
	var material := StandardMaterial3D.new()
	material.albedo_color = pillar_color
	material.roughness = 1.0
	_pillar.material_override = material
	add_child(_pillar)


func _process(delta: float) -> void:
	if _pillar_left <= 0.0:
		return
	_pillar_left = maxf(_pillar_left - delta, 0.0)
	_pillar.visible = _pillar_left > 0.0
	# Shoots up fast, then sinks back into the ground.
	var t: float = 1.0 - _pillar_left / pillar_time
	var height: float = maxf(sin(t * PI) * params().apex * 0.5, 0.01)
	_pillar.scale = Vector3(1.0, height, 1.0)
	_pillar.global_position = _pillar_base + Vector3.UP * height * 0.5


## Ready, and Taln is standing on something to be thrown from.
func is_ready() -> bool:
	return super.is_ready() and taln.is_on_floor() and not taln.airborne


func _aim_range() -> float:
	return params().distance


## The launch velocity for this level, along direction, at magnitude.
func launch_velocity(direction: Vector3, magnitude: float) -> Vector3:
	var p: Dictionary = params()
	var g: float = taln.tuning.gravity
	var up: float = sqrt(2.0 * g * p.apex)
	var flight: float = 2.0 * up / g
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	return flat * (p.distance * magnitude / maxf(taln.mass, 0.01) / flight) + Vector3.UP * up


func _fire(origin: Vector3, direction: Vector3, _through_toa_uma: bool, magnitude: float) -> int:
	# An Echo that comes while Taln is still in the air finds no ground to heave.
	if taln.airborne:
		return 0
	taln.launch(launch_velocity(direction, magnitude))
	_flash.show_at(origin, pillar_radius * 2.5)
	_pillar_base = origin
	_pillar.global_position = origin
	_pillar.scale = Vector3(1.0, 0.01, 1.0)
	_pillar_left = pillar_time
	_pillar.visible = pillar_time > 0.0
	return 0
