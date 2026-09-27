class_name Loadout
extends Node3D
## Taln's owned skills (spec §2.5): the slots, the Surge bindings and each
## skill's level. Every owned skill's behavior scene is a child of this node.
## New skills start at level 1. Starting skills are added once Taln is ready,
## so behaviors can use his components in _ready.

## Input action per Surge binding, in binding order.
const SURGE_ACTIONS: Array[StringName] = [&"surge_1", &"surge_2", &"surge_3"]

signal skill_added(skill: SkillDef, behavior: SkillBehavior)
signal skill_leveled(skill: SkillDef, level: int)
signal surge_bindings_changed

@export var tuning: LoadoutTuning

## The station's swarm, for behaviors that hit or query enemies. Set by
## whoever wires the station up; null until then.
var swarm: SwarmServer
## Whether Taln holds the Honorblade this cycle (spec §5.1). Its Special Room
## comes later; until then Blade-eligible Surges route through Toa'uma.
var honorblade_held: bool = false

## Owned skills in the order they were added. Each takes one slot.
var slots: Array[SkillDef] = []
## Owned skills that take no slot (the Heraldic skill).
var innate: Array[SkillDef] = []
## One entry per binding; null where nothing is bound.
var surge_bindings: Array[SkillDef] = []
var _levels: Dictionary[StringName, int] = {}
var _behaviors: Dictionary[StringName, SkillBehavior] = {}

@onready var _taln: Taln = get_parent()


func _ready() -> void:
	surge_bindings.resize(tuning.surge_bindings)
	_taln.ready.connect(_add_starting_skills, CONNECT_ONE_SHOT)


func _unhandled_input(event: InputEvent) -> void:
	# A click that recaptures the mouse belongs to the camera, not a Surge.
	if _taln.control_locked or (event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		return
	for index in mini(surge_bindings.size(), SURGE_ACTIONS.size()):
		if event.is_action_pressed(SURGE_ACTIONS[index]):
			var surge: SurgeBehavior = get_surge_behavior(index)
			if surge:
				surge.try_cast()
			get_viewport().set_input_as_handled()
			return


func _add_starting_skills() -> void:
	for skill: SkillDef in tuning.starting_skills:
		add_skill(skill)
	for skill: SkillDef in tuning.innate_skills:
		add_skill(skill, true)


## Adds skill at level 1 and binds it to the first free Surge binding if it's a
## Surge. An innate skill takes no slot. Returns false if it's already owned
## or every slot is taken.
func add_skill(skill: SkillDef, is_innate: bool = false) -> bool:
	if has_skill(skill.id) or (is_full() and not is_innate):
		return false
	if is_innate:
		innate.append(skill)
	else:
		slots.append(skill)
	_levels[skill.id] = 1
	var behavior: SkillBehavior = null
	if skill.behavior:
		behavior = skill.behavior.instantiate()
		behavior.skill = skill
		behavior.level = 1
		behavior.taln = _taln
		behavior.name = String(skill.id)
		_behaviors[skill.id] = behavior
		add_child(behavior)
	if skill.kind == SkillDef.Kind.SURGE:
		var free: int = surge_bindings.find(null)
		if free >= 0:
			surge_bindings[free] = skill
			surge_bindings_changed.emit()
	skill_added.emit(skill, behavior)
	return true


func has_skill(id: StringName) -> bool:
	return _levels.has(id)


## Every owned skill, slotted then innate.
func owned() -> Array[SkillDef]:
	return slots + innate


## Owned skills tagged as catalysts, cheapest tier first (spec §3.4 firing order).
func catalysts() -> Array[SkillDef]:
	var found: Array[SkillDef] = owned().filter(func(s: SkillDef) -> bool:
		return s.catalyst_tier != SkillDef.CatalystTier.NONE)
	found.sort_custom(func(a: SkillDef, b: SkillDef) -> bool: return a.catalyst_tier < b.catalyst_tier)
	return found


## A catalyst's cost in ninths at the Heraldic skill's current level (spec §4.4).
func catalyst_cost(skill: SkillDef) -> int:
	var heraldic: SkillDef = tuning.heraldic_skill
	var key: String = SkillDef.CatalystTier.keys()[skill.catalyst_tier].to_lower()
	var costs: Dictionary = heraldic.params_for(maxi(get_level(heraldic.id), 1))
	if not costs.has(key):
		push_error("%s has no %s cost; %s can't be committed." % [heraldic.id, key, skill.id])
		return 999
	return int(costs[key])


## The skill's cap this cycle: its meta cap (MetaState), clamped to the levels
## the skill defines, with a warning if the meta cap is higher.
func get_cap(id: StringName) -> int:
	var skill: SkillDef = get_skill(id)
	var cap: int = Meta.state().get_cap(id)
	if skill and cap > skill.level_params.size():
		push_warning("%s's cap %d is past its %d defined levels; clamped." % [id, cap, skill.level_params.size()])
		return skill.level_params.size()
	return cap


func is_capped(id: StringName) -> bool:
	return get_level(id) >= get_cap(id)


## Raises an owned skill one level, up to its cap. False if it can't.
func level_up(id: StringName) -> bool:
	if not has_skill(id) or is_capped(id):
		return false
	_levels[id] += 1
	var behavior: SkillBehavior = get_behavior(id)
	if behavior:
		behavior.set_level(_levels[id])
	skill_leveled.emit(get_skill(id), _levels[id])
	return true


func get_skill(id: StringName) -> SkillDef:
	for skill: SkillDef in owned():
		if skill.id == id:
			return skill
	return null


func is_full() -> bool:
	return slots.size() >= tuning.slots


## Current level of an owned skill, or 0 if it isn't owned.
func get_level(id: StringName) -> int:
	return _levels.get(id, 0)


func get_behavior(id: StringName) -> SkillBehavior:
	return _behaviors.get(id)


## The Surge bound at index, or null.
func get_bound_surge(index: int) -> SkillDef:
	return surge_bindings[index] if index >= 0 and index < surge_bindings.size() else null


## The behavior of the Surge bound at index, or null.
func get_surge_behavior(index: int) -> SurgeBehavior:
	var surge: SkillDef = get_bound_surge(index)
	return get_behavior(surge.id) as SurgeBehavior if surge else null


## Binds an owned Surge to index, moving it off any other binding. Pass null
## to clear the binding.
func bind_surge(index: int, skill: SkillDef) -> bool:
	if index < 0 or index >= surge_bindings.size():
		return false
	if skill and (skill.kind != SkillDef.Kind.SURGE or not has_skill(skill.id)):
		return false
	var previous: int = surge_bindings.find(skill) if skill else -1
	if previous >= 0:
		surge_bindings[previous] = null
	surge_bindings[index] = skill
	surge_bindings_changed.emit()
	return true
