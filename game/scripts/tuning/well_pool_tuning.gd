class_name WellPoolTuning
extends Resource
## Well pool numbers (spec §2.3). Values live in
## data/tuning/well_pool_tuning.tres; the defaults here are deliberately zero.

@export_range(0.0, 20.0, 0.1, "suffix:m") var pool_radius: float = 0.0
