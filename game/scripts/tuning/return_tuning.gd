class_name ReturnTuning
extends Resource
## The Return's numbers (spec §6.6). Values live in
## data/tuning/return_tuning.tres; the defaults here are deliberately zero.

@export_group("Timing")
## Real seconds of the whole sequence (the first viewing always plays it all).
@export_range(0.0, 20.0, 0.1, "suffix:s") var duration: float = 0.0
## Once seen in full, any press skips it after this many real seconds.
@export_range(0.0, 20.0, 0.1, "suffix:s") var skip_after: float = 0.0
## Beats as fractions of duration: the ash dissolve ends, the screen is black,
## black starts lifting, he's reassembled (one breath follows).
@export_range(0.0, 1.0, 0.01) var ash_end: float = 0.0
@export_range(0.0, 1.0, 0.01) var black_start: float = 0.0
@export_range(0.0, 1.0, 0.01) var black_hold_end: float = 0.0
@export_range(0.0, 1.0, 0.01) var reassembled: float = 0.0

@export_group("On reform")
## Swarm-tier enemies (mass up to shockwave_max_mass) within shockwave_radius
## die, unrewarded; heavier ones get shockwave_force of knockback.
@export_range(0.0, 50.0, 0.5, "suffix:m") var shockwave_radius: float = 0.0
@export_range(0.0, 100.0, 0.5) var shockwave_max_mass: float = 0.0
@export_range(0.0, 100.0, 0.5) var shockwave_force: float = 0.0
@export_range(0.0, 900.0, 1.0) var return_agony: float = 0.0
## Share of held Investiture Braize takes.
@export_range(0.0, 1.0, 0.001) var braize_share: float = 0.0
