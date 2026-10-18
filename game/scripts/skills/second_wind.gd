class_name SecondWind
extends SkillBehavior
## Second Wind, a placeholder Perk (Herald, P2-10 kit pool): Health regen per
## second while owned, more per level (spec §6.1: regen comes only from
## skills). Nothing regenerates while the Return freezes Taln.
##
## level_params keys: regen (Health per second).


func _physics_process(delta: float) -> void:
	if taln.frozen or taln.health.current <= 0.0:
		return
	taln.health.heal(params().regen * delta)
