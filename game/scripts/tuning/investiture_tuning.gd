class_name InvestitureTuning
extends Resource
## Investiture numbers (spec §2). Values live in
## data/tuning/investiture_tuning.tres; the defaults here are deliberately zero.

@export_group("Debug")
## Investiture Taln starts each station with until income lands (P2-04).
@export_range(0.0, 10000.0, 1.0) var debug_start_investiture: float = 0.0
## Amount the debug grant key (Ctrl+4) adds.
@export_range(0.0, 10000.0, 1.0) var debug_grant_amount: float = 0.0
