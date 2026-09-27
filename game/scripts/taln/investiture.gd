class_name Investiture
extends Node
## Taln's Investiture reservoir (spec §2.1): one pool, no cap, shared by Surge
## use and leveling. P2-03 stub: it starts at the debug amount from tuning;
## kill and Well income arrive in P2-04.

signal changed(current: float)

@export var tuning: InvestitureTuning

var current: float = 0.0


func _ready() -> void:
	current = tuning.debug_start_investiture


func can_afford(amount: float) -> bool:
	return current >= amount


## Deducts amount if Taln can afford it. Returns false, and spends nothing,
## otherwise.
func spend(amount: float) -> bool:
	if amount < 0.0 or not can_afford(amount):
		return false
	if amount > 0.0:
		_set_current(current - amount)
	return true


## Adds income. The source (e.g. &"kill", &"well", &"draw", &"debug") is
## unused until P2-04 applies the station value multiplier and telemetry.
func add(amount: float, _source: StringName) -> void:
	if amount > 0.0:
		_set_current(current + amount)


func _set_current(value: float) -> void:
	current = value
	changed.emit(current)
