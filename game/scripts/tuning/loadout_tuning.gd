class_name LoadoutTuning
extends Resource
## Loadout numbers and Taln's starting kit (spec §2.5). Values live in
## data/tuning/loadout_tuning.tres; the defaults here are deliberately zero.

## Skill slots per cycle. Weapons, Surges and Perks each take one.
@export_range(0, 32, 1) var slots: int = 0
## Surges bound to inputs at once.
@export_range(0, 9, 1) var surge_bindings: int = 0
## Surge soft-lock (spec §7.3): half-angle of the cone around camera-forward,
## and how many sectors find_densest_direction() splits it into.
@export_range(0.0, 90.0, 0.5, "suffix:°") var surge_soft_lock_half_angle_deg: float = 0.0
@export_range(1, 64, 1) var surge_soft_lock_sectors: int = 0
## Owned at level 1 when a cycle starts, in this order.
@export var starting_skills: Array[SkillDef] = []
