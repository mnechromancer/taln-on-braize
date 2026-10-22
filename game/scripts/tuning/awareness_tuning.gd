class_name AwarenessTuning
extends Resource
## Awareness numbers (spec v1.4 #6, P2-13). Values live in
## data/tuning/awareness_tuning.tres; the defaults here are deliberately zero.

## Any enemy this close to Taln (XZ) sees him, spotter or not.
@export_range(0.0, 30.0, 0.5, "suffix:m") var close_sight: float = 0.0
## After the last sighting the swarm keeps hunting the last known position
## this long, then loses him and wanders.
@export_range(0.0, 60.0, 0.5, "suffix:s") var memory_seconds: float = 0.0
## A noise heard sends the swarm to where it came from for this long.
@export_range(0.0, 60.0, 0.5, "suffix:s") var noise_memory: float = 0.0
## Enemies within these radii hear a Voidlight use (a Surge through Toa'uma,
## a Draw) or a hard landing at Taln's position.
@export_range(0.0, 100.0, 0.5, "suffix:m") var voidlight_noise_radius: float = 0.0
@export_range(0.0, 100.0, 0.5, "suffix:m") var landing_noise_radius: float = 0.0
## Landings slower than this make no noise.
@export_range(0.0, 50.0, 0.5, "suffix:m/s") var landing_noise_min_speed: float = 0.0
