class_name Shardfall
extends SkillBehavior
## Shardfall, a placeholder Weapon (Stoneward, P2-10 kit pool). Auto-fires:
## when ready and an enemy is within range, a shard of stone drops on the
## nearest one, dealing Kinetic damage in a small burst around it, then waits
## the level's interval. The ranged counterpart to Breaking Stroke.
##
## level_params keys: damage, interval (s), range (m), burst_radius (m).

signal struck(at: Vector3, hits: int)

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
	var target: Vector3 = swarm.find_nearest(taln.global_position, p.range)
	if target == Vector3.INF:
		return
	var hits: int = swarm.apply_damage_in_radius(target, p.burst_radius, p.damage, Damage.Type.KINETIC)
	cooldown_left = p.interval
	_flash.show_at(target, p.burst_radius)
	struck.emit(target, hits)
