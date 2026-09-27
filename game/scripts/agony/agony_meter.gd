class_name AgonyMeter
extends Node
## Taln's Agony meter (spec §3.1–3.3): 0 to meter_max internally, shown as
## nine segments ("ninths"). Gains, all per spec §3.2:
## - damage taken: damage_per_percent per 1% of max Health lost after
##   mitigation, whatever the source (Burn and Fracture included);
## - endurance: endurance_rate per second while the game runs;
## - Pressed: pressed_rate per second more while at least pressed_min_enemies
##   are within pressed_radius;
## - breaker: breaker_rate per second while breaker_active (a hook; no
##   breakers exist yet).
## Gain is suspended while any source holds it (the Welcome/Catalyze windows,
## the Return sequence) and, being a paused node, during the Invest pause. At
## meter_max the meter locks: gain is discarded until the fill resolves.

signal changed(value: float)
## The meter reached meter_max and locked.
signal filled

@export var tuning: AgonyTuning

var value: float = 0.0
var is_locked: bool = false
## Set by whoever runs a breaker fight (none yet).
var breaker_active: bool = false
## The swarm, for Pressed. Set by the station; null means never Pressed.
var swarm: SwarmServer
## This cycle's gain so far, by source (&"damage", &"endurance", &"pressed",
## &"breaker", &"return"), for telemetry.
var gained_by_source: Dictionary[StringName, float] = {}
var _suspended: Dictionary[StringName, bool] = {}

@onready var _taln: Taln = get_parent()


func _ready() -> void:
	# Taln's own @onready references aren't set yet: children are ready first.
	(_taln.get_node(^"Health") as Health).damaged.connect(_on_damaged)


func _physics_process(delta: float) -> void:
	add(tuning.endurance_rate * delta, &"endurance")
	if is_pressed():
		add(tuning.pressed_rate * delta, &"pressed")
	if breaker_active:
		add(tuning.breaker_rate * delta, &"breaker")


## True while at least pressed_min_enemies are within pressed_radius (spec §3.2).
func is_pressed() -> bool:
	return swarm != null and swarm.query_count_in_radius(_taln.global_position, tuning.pressed_radius) \
			>= tuning.pressed_min_enemies


## Adds Agony from source unless suspended or locked. Returns what it added.
func add(amount: float, source: StringName) -> float:
	if amount <= 0.0 or is_locked or is_suspended():
		return 0.0
	var added: float = minf(amount, tuning.meter_max - value)
	value += added
	gained_by_source[source] = gained_by_source.get(source, 0.0) + added
	changed.emit(value)
	if value >= tuning.meter_max - 0.0001:
		value = tuning.meter_max
		is_locked = true
		filled.emit()
	return added


func set_suspended(source: StringName, on: bool) -> void:
	if on:
		_suspended[source] = true
	else:
		_suspended.erase(source)


func is_suspended() -> bool:
	return not _suspended.is_empty()


## Whole ninths filled (0–9).
func ninths() -> int:
	return floori(value / tuning.per_ninth + 0.0001)


## Back to 0 and unlocked: a fill resolved (banked or fired).
func empty() -> void:
	value = 0.0
	is_locked = false
	changed.emit(value)


## Back to a fresh cycle.
func reset() -> void:
	gained_by_source.clear()
	_suspended.clear()
	breaker_active = false
	empty()


func _on_damaged(amount: float, _type: Damage.Type) -> void:
	add(amount / _taln.tuning.max_health * 100.0 * tuning.damage_per_percent, &"damage")
