class_name Tremor
extends SkillBehavior
## Tremor, a placeholder Weapon (Stoneward, P2-10 kit pool). Auto-fires: when
## ready and an enemy is within the radius, the ground around Taln shudders,
## dealing Kinetic damage to everything in the radius, then waits the level's
## interval.
##
## level_params keys: damage, interval (s), radius (m).

signal pulsed(hits: int)

@export var flash_color: Color = Color("#D9A55B")
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
	var origin: Vector3 = taln.global_position
	if swarm.find_nearest(origin, p.radius) == Vector3.INF:
		return
	var hits: int = swarm.apply_damage_in_radius(origin, p.radius, p.damage, Damage.Type.KINETIC)
	cooldown_left = p.interval
	_flash.show_at(origin, p.radius)
	pulsed.emit(hits)
