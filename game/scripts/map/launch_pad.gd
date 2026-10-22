class_name LaunchPad
extends Node3D
## Launch terrain (spec v1.4 #3, P2-12): a stretch of ground under tension
## that throws Taln when he steps onto it, on an arc that peaks apex meters
## above the pad and comes down on target. It throws every Aspect; only
## Meteor's Impact turns the landing into damage. Emissive only, no light
## (spec §12). The station sets taln.

const COLOR := Color("d9a55b")
const DISC_HEIGHT := 0.05
const ARROW_LENGTH := 2.2
const ARROW_WIDTH := 0.35

@export var tuning: LaunchTuning
## Where the arc comes down (world position, on the ground there).
@export var target: Vector3 = Vector3.ZERO
## How far above the pad the arc peaks.
@export_range(0.5, 40.0, 0.5, "suffix:m") var apex: float = 5.0

signal threw(velocity: Vector3)

var taln: Taln
var _rearm_left: float = 0.0


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = COLOR
	var disc := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = tuning.pad_radius
	cylinder.bottom_radius = tuning.pad_radius
	cylinder.height = DISC_HEIGHT
	disc.mesh = cylinder
	disc.position.y = DISC_HEIGHT
	disc.material_override = material
	disc.transparency = 0.4
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	# An arrow along the ground toward the target.
	var arrow := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(ARROW_WIDTH, DISC_HEIGHT, ARROW_LENGTH)
	arrow.mesh = box
	arrow.material_override = material
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arrow)
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if not flat.is_zero_approx():
		var dir: Vector3 = flat.normalized()
		arrow.global_transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)),
				global_position + dir * (tuning.pad_radius + ARROW_LENGTH * 0.5) + Vector3.UP * DISC_HEIGHT)


func _physics_process(delta: float) -> void:
	_rearm_left = maxf(_rearm_left - delta, 0.0)
	if taln == null or _rearm_left > 0.0 or taln.frozen or taln.airborne or not taln.is_on_floor():
		return
	var at: Vector3 = taln.global_position
	if Vector2(at.x - global_position.x, at.z - global_position.z).length() > tuning.pad_radius \
			or absf(at.y - global_position.y) > tuning.pad_reach_height:
		return
	var velocity: Vector3 = launch_velocity()
	taln.launch(velocity)
	_rearm_left = tuning.pad_rearm_seconds
	threw.emit(velocity)


## The throw that peaks apex above the pad and lands on target under Taln's gravity.
func launch_velocity() -> Vector3:
	var g: float = taln.tuning.gravity
	var up: float = sqrt(2.0 * g * apex)
	var fall: float = maxf(global_position.y + apex - target.y, 0.01)
	var flight: float = up / g + sqrt(2.0 * fall / g)
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	return flat / flight + Vector3.UP * up
