class_name MetaTuning
extends Resource
## Meta-progression numbers (spec §2.5, §4.4, §9; provisional until the Phase
## 4 Meta-Progression Spec). Values live in data/tuning/meta_tuning.tres; the
## defaults here are deliberately zero.

## Every skill's cap until banked Agony raises it.
@export_range(0, 9, 1) var starting_cap: int = 0
## Skills that start at a different cap (e.g. Bearer of Agonies at 2).
@export var starting_cap_overrides: Dictionary[StringName, int] = {}
@export_range(0, 9, 1) var max_cap: int = 0
## Raising a cap from c to c + 1 costs c + cap_raise_cost_offset banked
## points (spec §9: c − 1, so -1).
@export_range(-9, 9, 1) var cap_raise_cost_offset: int = 0
