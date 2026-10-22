class_name LaunchTuning
extends Resource
## Launch terrain on the persistent map (spec v1.4 #3, P2-12). Values live in
## data/tuning/launch_tuning.tres; the defaults here are deliberately zero.

## Taln standing within this distance (XZ) of a pad's center is thrown.
@export_range(0.0, 10.0, 0.1, "suffix:m") var pad_radius: float = 0.0
## A pad waits this long after throwing before it can throw again.
@export_range(0.0, 10.0, 0.1, "suffix:s") var pad_rearm_seconds: float = 0.0
## Taln's feet must be within this height of the pad to be on it.
@export_range(0.0, 5.0, 0.05, "suffix:m") var pad_reach_height: float = 0.0
