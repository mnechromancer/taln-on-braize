class_name ToaumaTuning
extends Resource
## Toa'uma numbers (spec §2.3, §5). Values live in
## data/tuning/toauma_tuning.tres; the defaults here are deliberately zero.

@export_group("Strain")
@export_range(0.0, 9.0, 0.25) var strain_max: float = 0.0
## Strain per Toa'uma-routed Surge, per 25 Investiture of its cost (spec §5.2).
@export_range(0.0, 9.0, 0.05) var surge_strain_per_25: float = 0.0
## Ctrl+6 adds this much Strain.
@export_range(0.0, 9.0, 0.25) var debug_strain_step: float = 0.0

@export_group("Draw")
@export_range(0.0, 1000.0, 1.0) var draw_investiture: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var draw_cooldown: float = 0.0
@export_range(0.0, 9.0, 0.25) var draw_strain: float = 0.0

@export_group("Side effects")
## Chance per routed use: min(p_max, p_base + p_per_strain × Strain).
@export_range(0.0, 1.0, 0.01) var p_base: float = 0.0
@export_range(0.0, 1.0, 0.01) var p_per_strain: float = 0.0
@export_range(0.0, 1.0, 0.01) var p_max: float = 0.0
@export_range(0, 20, 1) var weight_overcharge: int = 0
@export_range(0, 20, 1) var weight_burn: int = 0
@export_range(0, 20, 1) var weight_misfire: int = 0
@export_range(0, 20, 1) var weight_lurch: int = 0
@export_range(0, 20, 1) var weight_echo: int = 0
@export_range(0, 20, 1) var weight_speaks: int = 0
## At this Strain and above, Burn and Misfire weights are multiplied by
## high_strain_weight_mult (spec §5.3).
@export_range(0.0, 9.0, 0.25) var high_strain: float = 0.0
@export_range(1, 10, 1) var high_strain_weight_mult: int = 1
## Overcharge: Surge damage and root, or Draw Investiture, times this.
@export_range(1.0, 5.0, 0.1) var overcharge_mult: float = 1.0
## Voidlight burn: this fraction of max Health as Void damage.
@export_range(0.0, 1.0, 0.01) var burn_fraction: float = 0.0
## Misfire: the Surge turns up to this many degrees either side of its aim.
@export_range(0.0, 180.0, 1.0, "suffix:°") var misfire_max_deg: float = 0.0
## Lurch: enemies within lurch_radius and Taln move at lurch_factor speed.
@export_range(0.0, 20.0, 0.1, "suffix:m") var lurch_radius: float = 0.0
@export_range(0.0, 1.0, 0.01) var lurch_factor: float = 1.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var lurch_duration: float = 0.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var echo_delay: float = 0.0
## Placeholder Speaks lines until the Narrative Bible's bark set lands.
@export var speaks_lines: Array[String] = []

@export_group("Notice")
## The first time Strain reaches notice_thresholds[i] in a cycle, a pack of
## notice_hunters[i] hunters spawns (spec §5.3; sizes are placeholders, v1.2).
@export var notice_thresholds: Array[float] = []
@export var notice_hunters: Array[int] = []
## Seconds each pack's hunters live if not killed; 0 means until killed.
@export var notice_lifetimes: Array[float] = []
@export var notice_hunter_type: SwarmType
