class_name AgonyTuning
extends Resource
## Agony numbers (spec §3–4). Values live in data/tuning/agony_tuning.tres;
## the defaults here are deliberately zero.

@export_group("Meter")
## Internal range 0 to meter_max, shown as ninths of per_ninth each.
@export_range(0.0, 10000.0, 1.0) var meter_max: float = 0.0
@export_range(0.0, 1000.0, 1.0) var per_ninth: float = 0.0

@export_group("Gain")
## Agony per 1% of max Health lost after mitigation (spec §3.2).
@export_range(0.0, 10.0, 0.05) var damage_per_percent: float = 0.0
@export_range(0.0, 20.0, 0.05, "suffix:/s") var endurance_rate: float = 0.0
@export_range(0.0, 20.0, 0.05, "suffix:/s") var pressed_rate: float = 0.0
@export_range(0.0, 20.0, 0.05, "suffix:/s") var breaker_rate: float = 0.0

@export_group("Pressed")
@export_range(0.0, 30.0, 0.5, "suffix:m") var pressed_radius: float = 0.0
## Pressed while at least this many enemies are within pressed_radius.
@export_range(0, 100, 1) var pressed_min_enemies: int = 0

@export_group("Welcome and Catalyze")
## Time scale while the prompt or Catalyze window is open (spec §3.4).
@export_range(0.0, 1.0, 0.01) var window_time_scale: float = 1.0
## Window lengths in real (unscaled) seconds.
@export_range(0.0, 60.0, 0.1, "suffix:s") var prompt_window: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var catalyze_window: float = 0.0
## Real seconds a catalyst icon must be held to commit it.
@export_range(0.0, 5.0, 0.05, "suffix:s") var commit_hold: float = 0.0
## Ninths one fill can spend on catalysts.
@export_range(0, 9, 1) var budget_ninths: int = 0

@export_group("Accessibility")
## Full pause instead of the time-scale slow-down for both windows (spec §3.4).
@export var catalyze_full_pause: bool = false
