class_name Rend
extends SkillBehavior
## Rend, Doomhunter's starting Weapon (Stoneward; P2-14): heavy single-target
## strokes. Auto-fires: when ready it strikes the nearest elite (a commander,
## a hunter) within elite_range, or, with none, the nearest enemy within
## range plus acquire_margin, dealing Kinetic damage in a tight burst on it,
## then waits the level's interval. Built to cut heads off, not to clear
## crowds.
##
## level_params keys: damage, interval (s), range (m), acquire_margin (m),
## elite_range (m), strike_radius (m).

signal struck(at: Vector3, hits: int, elite: bool)

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
	var elite: bool = true
	var target: Vector3 = swarm.find_nearest_of_tier(origin, p.elite_range, SwarmType.TIER_ELITE)
	if target == Vector3.INF:
		elite = false
		target = swarm.find_nearest(origin, p.range + p.acquire_margin)
	if target == Vector3.INF:
		return
	var hits: int = swarm.apply_damage_in_radius(target, p.strike_radius, p.damage, Damage.Type.KINETIC)
	cooldown_left = p.interval
	_flash.show_at(target, p.strike_radius)
	struck.emit(target, hits, elite)
