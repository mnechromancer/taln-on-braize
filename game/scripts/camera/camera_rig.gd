class_name CameraRig
extends Node3D
## Third-person rig (spec §7.2). This node is the yaw pivot and follows the
## target; under it sit the pitch pivot, a SpringArm3D and the Camera3D.
## It moves in _process from the target's interpolated transform, so it opts
## out of physics interpolation.
##
## TODO(spec §7.2): occluder fade to 30% (tuning.occluder_alpha). Until then
## the spring arm's collision is off (collision_mask 0 in the scene).

@export var tuning: CameraTuning
@export var target: Node3D

## Current zoom distance in meters.
var distance: float:
	get:
		return _distance
var pitch_deg: float:
	get:
		return _pitch_deg

var _pitch_deg: float = 0.0
var _distance: float = 0.0
var _trauma: float = 0.0

@onready var _pitch_pivot: Node3D = $PitchPivot
@onready var _spring_arm: SpringArm3D = $PitchPivot/SpringArm3D
@onready var _camera: Camera3D = $PitchPivot/SpringArm3D/Camera3D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_pitch_deg = tuning.default_pitch_deg
	_distance = tuning.default_distance
	_camera.fov = tuning.fov_deg
	_apply_pitch_and_zoom()
	if target:
		global_position = _focus_point()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var stick: Vector2 = Input.get_vector("cam_orbit_left", "cam_orbit_right", "cam_orbit_up", "cam_orbit_down")
	var stick_step: float = tuning.orbit_speed_deg * delta
	_orbit(-stick.x * stick_step, -stick.y * stick_step)
	_distance += Input.get_axis("cam_zoom_in", "cam_zoom_out") * tuning.zoom_rate * delta
	_apply_pitch_and_zoom()

	if target:
		var weight: float = 1.0 - exp(-tuning.follow_lerp_rate * delta)
		global_position = global_position.lerp(_focus_point(), weight)

	_update_shake(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_release"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT \
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("cam_zoom_in_step"):
			_distance -= tuning.zoom_step
		elif event.is_action_pressed("cam_zoom_out_step"):
			_distance += tuning.zoom_step
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		_orbit(-motion.relative.x * tuning.mouse_sensitivity_deg,
				-motion.relative.y * tuning.mouse_sensitivity_deg)


## Adds screen-shake trauma, clamped to 0–1.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Yaw-only basis for camera-relative movement on the ground plane.
func get_ground_basis() -> Basis:
	return Basis(Vector3.UP, rotation.y)


func _orbit(yaw_deg: float, pitch_deg: float) -> void:
	rotation.y += deg_to_rad(yaw_deg)
	_pitch_deg += pitch_deg


func _apply_pitch_and_zoom() -> void:
	_pitch_deg = clampf(_pitch_deg, tuning.pitch_min_deg, tuning.pitch_max_deg)
	_distance = clampf(_distance, tuning.zoom_min, tuning.zoom_max)
	_pitch_pivot.rotation.x = deg_to_rad(_pitch_deg)
	_spring_arm.spring_length = _distance


func _focus_point() -> Vector3:
	return target.get_global_transform_interpolated().origin + Vector3.UP * tuning.target_height


func _update_shake(delta: float) -> void:
	_trauma = maxf(_trauma - tuning.trauma_decay * delta, 0.0)
	var offset: float = tuning.shake_max_offset * tuning.shake_global_scale * _trauma * _trauma
	_camera.h_offset = randf_range(-1.0, 1.0) * offset
	_camera.v_offset = randf_range(-1.0, 1.0) * offset
