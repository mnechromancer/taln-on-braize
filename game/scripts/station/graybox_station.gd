class_name GrayboxStation
extends Node3D
## P2-01 gray-box station. It has no directional light by design; F4 toggles
## a temporary one (off by default) for inspecting geometry. Also wires Taln's
## Shoulder wall hits to camera shake.

@onready var _inspect_light: DirectionalLight3D = $InspectLight
@onready var _taln: Taln = $Taln
@onready var _camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	_taln.shoulder.blocked.connect(_on_shoulder_blocked)


func _on_shoulder_blocked(_position: Vector3, _normal: Vector3) -> void:
	_camera_rig.add_trauma(_camera_rig.tuning.shoulder_wall_trauma)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_inspect_light"):
		_inspect_light.visible = not _inspect_light.visible
