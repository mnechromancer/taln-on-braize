class_name TalnTuning
extends Resource
## Taln's gameplay numbers (core-systems-spec §6, §7.1). Values live in
## data/tuning/taln_tuning.tres; the defaults here are deliberately zero.

@export_group("Collider")
@export_range(0.0, 5.0, 0.01, "suffix:m") var capsule_height: float = 0.0
@export_range(0.0, 2.0, 0.01, "suffix:m") var capsule_radius: float = 0.0

@export_group("Movement")
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var move_speed: float = 0.0
@export_range(0.0, 200.0, 0.1, "suffix:m/s²") var acceleration: float = 0.0
@export_range(0.0, 200.0, 0.1, "suffix:m/s²") var deceleration: float = 0.0
@export_range(0.0, 2000.0, 1.0, "suffix:°/s") var turn_rate_deg: float = 0.0
@export_range(0.0, 89.0, 0.5, "suffix:°") var max_slope_deg: float = 0.0
@export_range(0.0, 1.0, 0.01, "suffix:m") var step_height: float = 0.0
@export_range(0.0, 100.0, 0.1, "suffix:m/s²") var gravity: float = 0.0

@export_group("Health")
@export_range(0.0, 10000.0, 1.0) var max_health: float = 0.0
@export_range(0.0, 100.0, 0.1, "suffix:/s") var health_regen: float = 0.0
@export_range(0.0, 1000.0, 1.0) var base_armor: float = 0.0

@export_group("Shoulder")
@export_range(0.0, 20.0, 0.1, "suffix:m") var shoulder_distance: float = 0.0
@export_range(0.0, 2.0, 0.01, "suffix:s") var shoulder_duration: float = 0.0
@export_range(0.0, 30.0, 0.1, "suffix:s") var shoulder_cooldown: float = 0.0
## Widest gap the charge may carry Taln across.
@export_range(0.0, 5.0, 0.1, "suffix:m") var shoulder_max_gap: float = 0.0
## Walls hit within this angle of head-on stop the charge; shallower hits slide.
@export_range(0.0, 90.0, 1.0, "suffix:°") var shoulder_wall_stop_angle_deg: float = 0.0

@export_group("Anchored")
## Time since movement input stopped (not since Taln stopped moving).
@export_range(0.0, 5.0, 0.05, "suffix:s") var anchor_delay: float = 0.0
@export_range(0.0, 1000.0, 1.0) var anchored_armor_bonus: float = 0.0

@export_group("Fracture")
## Below this horizontal speed Taln counts as stopped (records the anchor point).
@export_range(0.0, 1.0, 0.01, "suffix:m/s") var stop_speed: float = 0.0
@export_range(0.0, 20.0, 0.1, "suffix:m") var fracture_radius: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var fracture_warning_time: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var fracture_active_time: float = 0.0
## Fraction of max Health per second when Fracture starts.
@export_range(0.0, 1.0, 0.001) var fracture_base_rate: float = 0.0
## Added to the rate for each further second of Fracture.
@export_range(0.0, 1.0, 0.001) var fracture_rate_ramp: float = 0.0
## Time between Fracture damage pulses.
@export_range(0.0, 10.0, 0.1, "suffix:s") var fracture_pulse_interval: float = 0.0
## Continuous time beyond fracture_radius needed to reset the timer.
@export_range(0.0, 60.0, 0.1, "suffix:s") var fracture_reset_time: float = 0.0
