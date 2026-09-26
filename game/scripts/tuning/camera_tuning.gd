class_name CameraTuning
extends Resource
## Camera rig numbers (core-systems-spec §7.2). Values live in
## data/tuning/camera_tuning.tres; the defaults here are deliberately zero.

@export_group("Framing")
@export_range(0.0, 50.0, 0.1, "suffix:m") var default_distance: float = 0.0
@export_range(0.0, 50.0, 0.1, "suffix:m") var zoom_min: float = 0.0
@export_range(0.0, 50.0, 0.1, "suffix:m") var zoom_max: float = 0.0
@export_range(-90.0, 0.0, 0.5, "suffix:°") var default_pitch_deg: float = 0.0
@export_range(-90.0, 0.0, 0.5, "suffix:°") var pitch_min_deg: float = 0.0
@export_range(-90.0, 0.0, 0.5, "suffix:°") var pitch_max_deg: float = 0.0
@export_range(1.0, 179.0, 0.5, "suffix:°") var fov_deg: float = 0.0
## Height above the target's origin that the rig looks at.
@export_range(0.0, 5.0, 0.05, "suffix:m") var target_height: float = 0.0

@export_group("Motion")
@export_range(0.0, 100.0, 0.1, "suffix:/s") var follow_lerp_rate: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:°/s") var orbit_speed_deg: float = 0.0
@export_range(0.0, 2.0, 0.01, "suffix:°/px") var mouse_sensitivity_deg: float = 0.0
## Distance change per mouse-wheel notch.
@export_range(0.0, 10.0, 0.1, "suffix:m") var zoom_step: float = 0.0
## Distance change per second while a zoom button is held.
@export_range(0.0, 50.0, 0.1, "suffix:m/s") var zoom_rate: float = 0.0

@export_group("Collision")
@export_range(0.0, 2.0, 0.01, "suffix:m") var spring_margin: float = 0.0
## Opacity of geometry between the camera and Taln.
@export_range(0.0, 1.0, 0.01) var occluder_alpha: float = 0.0

@export_group("Shake")
@export_range(0.0, 10.0, 0.1, "suffix:/s") var trauma_decay: float = 0.0
## Camera offset at trauma 1.0, before the global scale.
@export_range(0.0, 5.0, 0.01, "suffix:m") var shake_max_offset: float = 0.0
## Player setting; multiplies all shake.
@export_range(0.0, 2.0, 0.05) var shake_global_scale: float = 0.0
@export_range(0.0, 1.0, 0.05) var shoulder_wall_trauma: float = 0.0
