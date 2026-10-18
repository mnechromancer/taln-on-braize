class_name LoadoutTuning
extends Resource
## Loadout numbers and Taln's innate kit (spec §2.5); the starting skills
## come from the cycle's Aspect (spec v1.4 #1). Values live in
## data/tuning/loadout_tuning.tres; the defaults here are deliberately zero.

## Skill slots per cycle. Weapons, Surges and Perks each take one.
@export_range(0, 32, 1) var slots: int = 0
## Surges bound to inputs at once.
@export_range(0, 9, 1) var surge_bindings: int = 0
## Surge soft-lock (spec §7.3): half-angle of the cone around camera-forward,
## and how many sectors find_densest_direction() splits it into.
@export_range(0.0, 90.0, 0.5, "suffix:°") var surge_soft_lock_half_angle_deg: float = 0.0
@export_range(1, 64, 1) var surge_soft_lock_sectors: int = 0
## Owned at level 1 every cycle without taking a slot (spec §4.4).
@export var innate_skills: Array[SkillDef] = []
## The Heraldic cost-reduction skill: its level_params hold catalyst costs in
## ninths by tier ("lesser", "greater", "grand") (spec §4.3–4.4).
@export var heraldic_skill: SkillDef
