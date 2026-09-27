class_name SpawnTuning
extends Resource
## SpawnDirector numbers (spec §8.2, §8.4). Values live in
## data/tuning/spawn_tuning.tres; the defaults here are deliberately zero.

@export_group("Budget")
## Spawn budget per second at wave 0 (B0).
@export_range(0.0, 100.0, 0.1, "suffix:/s") var base_budget: float = 0.0
## Budget grows by this fraction per wave index.
@export_range(0.0, 2.0, 0.01) var wave_slope: float = 0.0
## Budget multiplier by station (P_s).
@export var station_pressure: Array[float] = []
## Budget multiplier per Return this station.
@export_range(1.0, 2.0, 0.01) var return_pressure: float = 1.0
## The bank holds at most this many seconds of budget; the rest is discarded.
@export_range(0.0, 60.0, 0.5, "suffix:s") var bank_cap_seconds: float = 0.0
@export_range(0, 4000, 1) var alive_cap: int = 0

@export_group("Waves")
@export_range(0.0, 600.0, 1.0, "suffix:s") var wave_length: float = 0.0
## Wave indices run 0 to waves - 1, then hold on the last.
@export_range(1, 99, 1) var waves: int = 1

@export_group("Placement")
@export_range(0.0, 100.0, 0.5, "suffix:m") var ring_min: float = 0.0
@export_range(0.0, 100.0, 0.5, "suffix:m") var ring_max: float = 0.0
## Ring points tried per spawn before it is skipped.
@export_range(1, 64, 1) var spawn_attempts: int = 1

@export_group("Scaling")
## HP multiplier grows by this fraction per wave index.
@export_range(0.0, 2.0, 0.01) var hp_slope: float = 0.0
## Damage multiplier grows by this fraction per wave index.
@export_range(0.0, 2.0, 0.01) var dmg_slope: float = 0.0
## HP multiplier by station (S_s).
@export var station_hp_mults: Array[float] = []
## Damage multiplier by station (D_s).
@export var station_dmg_mults: Array[float] = []

@export_group("Debug stress mode (F6)")
@export_range(0, 4000, 1) var stress_alive_cap: int = 0
@export_range(1.0, 100.0, 0.5) var stress_budget_scale: float = 1.0
