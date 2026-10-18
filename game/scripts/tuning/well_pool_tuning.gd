class_name WellPoolTuning
extends Resource
## The Well's numbers (spec §2.3): ambient income and the pools. Values live
## in data/tuning/well_pool_tuning.tres; the defaults here are deliberately zero.

@export_range(0.0, 20.0, 0.1, "suffix:m") var pool_radius: float = 0.0

@export_group("Ambient")
## Investiture per second while a wave runs (times v).
@export_range(0.0, 20.0, 0.05, "suffix:/s") var ambient_rate: float = 0.0

@export_group("Pools")
## Draw per second standing in a pool, Anchored and not (times v).
@export_range(0.0, 50.0, 0.1, "suffix:/s") var draw_rate_anchored: float = 0.0
@export_range(0.0, 50.0, 0.1, "suffix:/s") var draw_rate_standing: float = 0.0
## Base Investiture a pool holds before it's drained.
@export_range(0.0, 1000.0, 1.0) var pool_capacity: float = 0.0
## Seconds after draining before a pool reappears elsewhere.
@export_range(0.0, 120.0, 0.5, "suffix:s") var respawn_delay: float = 0.0
## A reappearing pool's disc is all open ground at least this far from Taln
## and from the other pools' centers.
@export_range(0.0, 100.0, 0.5, "suffix:m") var min_distance_taln: float = 0.0
@export_range(0.0, 100.0, 0.5, "suffix:m") var min_distance_pools: float = 0.0
## New spots stay within this distance of Taln (P2-10, a big map); 0 for no limit.
@export_range(0.0, 500.0, 0.5, "suffix:m") var max_distance_taln: float = 0.0
## Its cells' heights may differ by at most this much (a pool is a flat disc).
@export_range(0.0, 2.0, 0.05, "suffix:m") var max_height_spread: float = 0.0
## Random spots tried per placement, and the wait before trying again if none fit.
@export_range(1, 1000, 1) var placement_attempts: int = 1
@export_range(0.0, 10.0, 0.1, "suffix:s") var retry_delay: float = 0.0

@export_group("Look")
## A drained pool's disc shrinks to this scale and dims to this brightness.
@export_range(0.0, 1.0, 0.01) var drained_scale: float = 0.0
@export_range(0.0, 1.0, 0.01) var drained_brightness: float = 0.0
