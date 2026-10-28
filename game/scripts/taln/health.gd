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
## Multipliers on damage taken by source (a culture bargain's bane); they multiply together.
var _damage_mults: Dictionary[StringName, float] = {}
var _invulnerable_sources: Dictionary[StringName, bool] = {}
## Time left on the global invulnerability that follows every hit (spec §6.2).
var _hit_invulnerable_left: float = 0.0


func _ready() -> void:
	current = tuning.max_health


func _physics_process(delta: float) -> void:
	_hit_invulnerable_left = maxf(_hit_invulnerable_left - delta, 0.0)
	if tuning.health_regen > 0.0 and current < tuning.max_health:
		_set_current(minf(current + tuning.health_regen * delta, tuning.max_health))


## Applies mitigated damage and returns the amount actually taken. Sources
## with ignore_invulnerability (Voidlight Burn) land through Shoulder or
## post-hit invulnerability, so nothing can cancel their cost.
func damage(raw: float, type: Damage.Type, ignore_invulnerability: bool = false) -> float:
	if raw <= 0.0 or (is_invulnerable() and not ignore_invulnerability):
		return 0.0
	# Past 0 nothing more is lost (so Agony counts only real Health).
	var taken: float = minf(raw * get_damage_mult() * 100.0 / (100.0 + get_armor()), current)
	_hit_invulnerable_left = tuning.hit_invulnerability_time
	var was_up: bool = current > 0.0
	_set_current(current - taken)
	damaged.emit(taken, type)
	# The Return (spec §6.6) listens; it refills Health on reform.
	if was_up and current <= 0.0:
		depleted.emit()
	return taken


## Back to max Health (the Return's reform; a new cycle).
func refill() -> void:
	_hit_invulnerable_left = 0.0
	_set_current(tuning.max_health)


## Restores up to amount, never past max Health.
func heal(amount: float) -> void:
	if amount > 0.0 and current < tuning.max_health:
		_set_current(minf(current + amount, tuning.max_health))


func get_armor() -> float:
	var armor: float = tuning.base_armor
	for bonus: float in _armor_bonuses.values():
		armor += bonus
	return armor


func get_damage_mult() -> float:
	var mult: float = 1.0
	for value: float in _damage_mults.values():
		mult *= value
	return mult


func set_damage_mult(source: StringName, value: float) -> void:
	_damage_mults[source] = value


func clear_damage_mult(source: StringName) -> void:
	_damage_mults.erase(source)


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
	return _hit_invulnerable_left > 0.0 or not _invulnerable_sources.is_empty()


func _set_current(value: float) -> void:
	current = maxf(value, 0.0)
	health_changed.emit(current, tuning.max_health)
