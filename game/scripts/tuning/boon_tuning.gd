class_name BoonTuning
extends Resource
## Bargains (P2-16): the pool and the offer rules. Values live in
## data/tuning/boon_tuning.tres; the defaults here are deliberately zero.

## Every bargain that can be offered.
@export var pool: Array[BoonDef] = []
## Bargains per offer (pick one).
@export_range(0, 9, 1) var offer_size: int = 0
## A commander's death offers bargains (the encounter stand-in).
@export var offer_on_commander_kill: bool = false
## Landings slower than this trigger no landing effects.
@export_range(0.0, 50.0, 0.5, "suffix:m/s") var landing_min_speed: float = 0.0
