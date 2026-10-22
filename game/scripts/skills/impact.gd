class_name Impact
extends SkillBehavior
## Impact, Meteor's starting Weapon (Stoneward; P2-12): Taln's landings are
## the attack. Landing at min_speed or faster deals Kinetic damage around him
## and throws enemies out; harder landings hit harder and wider:
##   damage = damage + damage_per_speed × (fall speed − min_speed)
##   radius = min(radius + radius_per_speed × (fall speed − min_speed), max_radius)
## Any landing counts: a Heave, a launch pad, a ledge drop.
##
## level_params keys: min_speed (m/s), damage, damage_per_speed, radius (m),
## radius_per_speed (m per m/s), max_radius (m), knockback (force).

signal impacted(fall_speed: float, hits: int)

@export var flash_color: Color = Color("#D9A55B")
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_time: float = 0.0

@onready var _flash: FlashRing = $Flash


func _ready() -> void:
	_flash.color = flash_color
	_flash.time = flash_time
	taln.landed.connect(_on_landed)


## Damage and radius for a landing at fall_speed; [0, 0] below min_speed.
func strike_for(fall_speed: float) -> Vector2:
	var p: Dictionary = params()
	if fall_speed < p.min_speed:
		return Vector2.ZERO
	var over: float = fall_speed - p.min_speed
	return Vector2(p.damage + p.damage_per_speed * over, minf(p.radius + p.radius_per_speed * over, p.max_radius))


func _on_landed(fall_speed: float, at: Vector3) -> void:
	var swarm: SwarmServer = taln.loadout.swarm
	var strike: Vector2 = strike_for(fall_speed)
	if swarm == null or strike.x <= 0.0:
		return
	var hits: int = swarm.apply_damage_in_radius(at, strike.y, strike.x, Damage.Type.KINETIC)
	swarm.apply_impulse_in_radius(at, strike.y, params().knockback)
	_flash.show_at(at, strike.y)
	impacted.emit(fall_speed, hits)
