class_name CycleTuning
extends Resource
## The cycle's numbers (spec §1.1–1.3; the Phase 2 stand-in cycle). Values
## live in data/tuning/cycle_tuning.tres; the defaults here are deliberately zero.

## Stations per cycle (spec §1.1: three).
@export_range(1, 9, 1) var stations: int = 0
## The ninth Return closes the cycle (spec §1.3).
@export_range(1, 99, 1) var returns_to_close: int = 0
## Seconds of lull between stations (stand-in; spec §1.2's lull is player-paced).
@export_range(0.0, 300.0, 0.5, "suffix:s") var lull_seconds: float = 0.0
## The scene a new cycle loads.
@export_file("*.tscn") var station_scene: String = ""

@export_group("Aspects")
## Every Aspect the between-run screen offers, in order (Design Doc v2.0 §10).
@export var aspects: Array[AspectDef] = []
## The Aspect a cycle uses until one is chosen.
@export var default_aspect: AspectDef
