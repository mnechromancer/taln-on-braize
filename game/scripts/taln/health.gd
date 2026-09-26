class_name Health
extends Node
## Taln's Health (spec §6.1–6.2). Armor is the tuned base plus any bonuses
## other systems add by source (e.g. Anchored). Mitigation has diminishing
## returns: taken = raw × 100 / (100 + armor).

signal damaged(amount: float, type: Damage.Type)
signal health_changed(current: float, maximum: float)
signal depleted

@export var tuning: TalnTuning

var current: float = 0.0
var _armor_bonuses: Dictionary[StringName, float] = {}
var _invulnerable_sources: Dictionary[StringName, bool] = {}


func _ready() -> void:
	current = tuning.max_health


func _physics_process(delta: float) -> void:
	if tuning.health_regen > 0.0 and current < tuning.max_health:
		_set_current(minf(current + tuning.health_regen * delta, tuning.max_health))


## Applies mitigated damage and returns the amount actually taken.
func damage(raw: float, type: Damage.Type) -> float:
	if raw <= 0.0 or is_invulnerable():
		return 0.0
	var taken: float = raw * 100.0 / (100.0 + get_armor())
	_set_current(current - taken)
	damaged.emit(taken, type)
	if current <= 0.0:
		# TODO(spec §6.6): the Return sequence replaces this refill.
		print("Health depleted; refilling to max until Return is implemented.")
		depleted.emit()
		_set_current(tuning.max_health)
	return taken


func get_armor() -> float:
	var armor: float = tuning.base_armor
	for bonus: float in _armor_bonuses.values():
		armor += bonus
	return armor


func set_armor_bonus(source: StringName, amount: float) -> void:
	_armor_bonuses[source] = amount


func clear_armor_bonus(source: StringName) -> void:
	_armor_bonuses.erase(source)


## Taln takes no damage while any source holds invulnerability.
func set_invulnerable(source: StringName, on: bool) -> void:
	if on:
		_invulnerable_sources[source] = true
	else:
		_invulnerable_sources.erase(source)


func is_invulnerable() -> bool:
	return not _invulnerable_sources.is_empty()


func _set_current(value: float) -> void:
	current = maxf(value, 0.0)
	health_changed.emit(current, tuning.max_health)
