class_name Culture
extends SkillBehavior
## Culture, Plaguebringer's starting Weapon (Ashynite; P2-15): the disease,
## seeded quietly. Auto-fires: every interval, if an uninfected enemy is
## within range, the nearest one is infected (spec v1.4 #8). It deals no damage itself: the
## disease does, and spreads from there through the crowd. Silent.
##
## level_params keys: interval (s), range (m), radius (m).

signal seeded(at: Vector3, newly: int)

@export var flash_color: Color = Color("#7a9a3a")
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_time: float = 0.0

@onready var _flash: FlashRing = $Flash


func _ready() -> void:
	_flash.color = flash_color
	_flash.time = flash_time


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	var swarm: SwarmServer = taln.loadout.swarm
	if cooldown_left > 0.0 or swarm == null:
		return
	var p: Dictionary = params()
	var target: Vector3 = swarm.find_nearest_uninfected(taln.global_position, p.range)
	if target == Vector3.INF:
		return
	cooldown_left = p.interval
	var newly: int = swarm.infect_in_radius(target, p.radius)
	if newly > 0:
		_flash.show_at(target, p.radius)
		seeded.emit(target, newly)
