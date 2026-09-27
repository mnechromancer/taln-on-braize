class_name StationGroundTuning
extends Resource
## What the ground data handed to SwarmServer counts as walkable. Values live
## in data/tuning/station_ground_tuning.tres and match Taln's max slope and
## step height (spec §7.1); the defaults here are deliberately zero.

## Cells steeper than this are blocked.
@export_range(0.0, 90.0, 0.5, "suffix:°") var max_slope_deg: float = 0.0
## Cells with a rise or drop bigger than this to a neighbor are blocked,
## after taking out the rise that walkable slopes between them explain.
@export_range(0.0, 2.0, 0.05, "suffix:m") var max_step_m: float = 0.0
