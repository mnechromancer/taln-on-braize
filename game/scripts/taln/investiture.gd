class_name Investiture
extends Node
## Taln's Investiture reservoir (spec §2.1): one pool, no cap, shared by Surge
## use and leveling. Every income source is multiplied by the station value v
## (spec §2.2), Draw included; the debug grant isn't. Income and spending are
## tallied by source for the HUD, telemetry and the economy bot.

signal changed(current: float)
## Income after the station value, by source (&"kill", &"elite", &"ambient",
## &"pool", &"draw", &"debug").
signal gained(amount: float, source: StringName)
## Spending by reason (&"surge", &"level", &"braize").
signal spent(amount: float, reason: StringName)

@export var tuning: InvestitureTuning

var current: float = 0.0
## Supplies v; without one, income is taken at face value.
var station: StationContext
## While frozen (the Return sequence) income is dropped.
var frozen: bool = false
## This cycle's income and spending so far, by source and reason.
var income_by_source: Dictionary[StringName, float] = {}
var spent_by_reason: Dictionary[StringName, float] = {}


func _ready() -> void:
	current = tuning.debug_start_investiture


func can_afford(amount: float) -> bool:
	return current >= amount


## Deducts amount if Taln can afford it. Returns false, and spends nothing,
## otherwise.
func spend(amount: float, reason: StringName = &"surge") -> bool:
	if amount < 0.0 or not can_afford(amount):
		return false
	if amount > 0.0:
		spent_by_reason[reason] = spent_by_reason.get(reason, 0.0) + amount
		_set_current(current - amount)
		spent.emit(amount, reason)
	return true


## Adds base income from source, times the station value.
func add(amount: float, source: StringName) -> void:
	if amount <= 0.0 or (frozen and source != &"debug"):
		return
	if source != &"debug" and station:
		amount *= station.value()
	income_by_source[source] = income_by_source.get(source, 0.0) + amount
	_set_current(current + amount)
	gained.emit(amount, source)


## Back to a fresh cycle: the starting amount and empty tallies.
func reset() -> void:
	income_by_source.clear()
	spent_by_reason.clear()
	_set_current(tuning.debug_start_investiture)


func _set_current(value: float) -> void:
	current = value
	changed.emit(current)
