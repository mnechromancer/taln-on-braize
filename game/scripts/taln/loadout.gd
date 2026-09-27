class_name Loadout
extends Node3D
## Taln's owned skills (spec §2.5): the slots, the Surge bindings and each
## skill's level. Every owned skill's behavior scene is a child of this node.
## New skills start at level 1. Starting skills are added once Taln is ready,
## so behaviors can use his components in _ready.

## Input action per Surge binding, in binding order.
const SURGE_ACTIONS: Array[StringName] = [&"surge_1", &"surge_2", &"surge_3"]

signal skill_added(skill: SkillDef, behavior: SkillBehavior)
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
	if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
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


## Adds skill at level 1 and binds it to the first free Surge binding if it's a
## Surge. Returns false if it's already owned or every slot is taken.
func add_skill(skill: SkillDef) -> bool:
	if has_skill(skill.id) or is_full():
		return false
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
