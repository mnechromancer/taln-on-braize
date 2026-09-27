class_name InvestitureTuning
extends Resource
## Investiture numbers (spec §2). Values live in
## data/tuning/investiture_tuning.tres; the defaults here are deliberately zero.

@export_group("Station value")
## v by station index (spec §2.2); every income source is multiplied by it.
@export var station_values: Array[float] = []

@export_group("Leveling")
## C(n) = round(level_cost_base × level_cost_growth^n) (spec §2.4).
@export_range(0.0, 10000.0, 1.0) var level_cost_base: float = 0.0
@export_range(1.0, 2.0, 0.01) var level_cost_growth: float = 1.0
## Share of max Health a level-up restores.
@export_range(0.0, 1.0, 0.01) var level_heal_fraction: float = 0.0
## Share of max Health Consolidate restores.
@export_range(0.0, 1.0, 0.01) var consolidate_heal_fraction: float = 0.0
## Most skills an Invest offer shows.
@export_range(0, 9, 1) var offer_size: int = 0

@export_group("Invest menu")
## Seconds (unscaled frame time) after the menu opens before a pick counts,
## so a key still held from play doesn't pick by accident.
@export_range(0.0, 2.0, 0.05, "suffix:s") var menu_input_delay: float = 0.0

@export_group("Debug")
## Investiture at cycle start (spec §2: 0). Raise it only to test.
@export_range(0.0, 10000.0, 1.0) var debug_start_investiture: float = 0.0
## Amount the debug grant key (Ctrl+4) adds (not multiplied by v).
@export_range(0.0, 10000.0, 1.0) var debug_grant_amount: float = 0.0
