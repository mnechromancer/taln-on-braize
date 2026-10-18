class_name StoneSkin
extends SkillBehavior
## Stone Skin, a placeholder Perk (Stoneward, P2-10 kit pool): Armor while
## owned, more per level. Stacks with Anchored's bonus (spec §6.2's
## diminishing-returns mitigation applies to the total).
##
## level_params keys: armor.

const SOURCE := &"stone_skin"


func _ready() -> void:
	_apply()
	level_changed.connect(func(_level: int) -> void: _apply())


func _exit_tree() -> void:
	taln.health.clear_armor_bonus(SOURCE)


func _apply() -> void:
	taln.health.set_armor_bonus(SOURCE, params().armor)
