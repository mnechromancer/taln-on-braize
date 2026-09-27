class_name AgonyTuning
extends Resource
## Agony numbers (spec §3). Only the Pressed condition exists so far, for the
## debug overlay. Values live in data/tuning/agony_tuning.tres; the defaults
## here are deliberately zero.

@export_group("Pressed")
@export_range(0.0, 30.0, 0.5, "suffix:m") var pressed_radius: float = 0.0
## Pressed while at least this many enemies are within pressed_radius.
@export_range(0, 100, 1) var pressed_min_enemies: int = 0
