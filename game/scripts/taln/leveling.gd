class_name Leveling
extends Node
## Player-triggered leveling (spec §2.4). The nth level-up of the cycle
## (n from 0) costs C(n) = round(level_cost_base × level_cost_growth^n) held
## Investiture. An offer holds up to offer_size owned skills below their cap,
## drawn without replacement with weight 1 / current level. Taking one levels
## that skill and heals level_heal_fraction of max Health; with every owned
## skill capped the only option is Consolidate, which heals
## consolidate_heal_fraction instead. Either way C(n) is spent and n advances.
## The menu (LevelUpMenu) drives this; nothing here pauses or reads input.

## After every level-up or Consolidate. skill is null for Consolidate.
signal leveled(n: int, skill: SkillDef, cost: float)

@export var tuning: InvestitureTuning

## Level-ups taken this cycle (n).
var levels_taken: int = 0
## Seed it for reproducible runs (spec §11.5).
var rng := RandomNumberGenerator.new()

@onready var _taln: Taln = get_parent()


func _ready() -> void:
	rng.randomize()


## C(n) for the next level-up.
func next_cost() -> float:
	return cost_of(levels_taken)


func cost_of(n: int) -> float:
	return roundf(tuning.level_cost_base * pow(tuning.level_cost_growth, n))


func can_invest() -> bool:
	return _taln.investiture.can_afford(next_cost())


## Owned skills that can still level.
func eligible() -> Array[SkillDef]:
	var skills: Array[SkillDef] = []
	for skill: SkillDef in _taln.loadout.owned():
		if not _taln.loadout.is_capped(skill.id):
			skills.append(skill)
	return skills


## Up to offer_size eligible skills, weighted toward fewer levels. Empty
## means Consolidate is the only option.
func offer() -> Array[SkillDef]:
	var pool: Array[SkillDef] = eligible()
	var picked: Array[SkillDef] = []
	while picked.size() < tuning.offer_size and not pool.is_empty():
		var total: float = 0.0
		for skill in pool:
			total += 1.0 / _taln.loadout.get_level(skill.id)
		var roll: float = rng.randf() * total
		var chosen: int = pool.size() - 1
		for i in pool.size():
			roll -= 1.0 / _taln.loadout.get_level(pool[i].id)
			if roll < 0.0:
				chosen = i
				break
		picked.append(pool[chosen])
		pool.remove_at(chosen)
	return picked


## Levels skill up for C(n). False, changing nothing, if it can't be afforded
## or the skill can't level.
func take(skill: SkillDef) -> bool:
	if not eligible().has(skill):
		return false
	var cost: float = next_cost()
	if not _taln.investiture.spend(cost, &"level"):
		return false
	levels_taken += 1
	_taln.loadout.level_up(skill.id)
	_taln.health.heal(_taln.tuning.max_health * tuning.level_heal_fraction)
	leveled.emit(levels_taken - 1, skill, cost)
	return true


## Consolidate (every owned skill capped): C(n) for a bigger heal.
func consolidate() -> bool:
	if not eligible().is_empty():
		return false
	var cost: float = next_cost()
	if not _taln.investiture.spend(cost, &"level"):
		return false
	levels_taken += 1
	_taln.health.heal(_taln.tuning.max_health * tuning.consolidate_heal_fraction)
	leveled.emit(levels_taken - 1, null, cost)
	return true


## Back to a fresh cycle.
func reset() -> void:
	levels_taken = 0
