class_name Upheave
extends SurgeBehavior
## Upheave, a placeholder Surge (Stoneward, Tension, P2-10 kit pool): the
## ground heaves at a point along the aim, dealing Kinetic damage around it
## and throwing enemies outward. Magnitude (Overcharge) scales the damage and
## the throw.
##
## level_params keys: damage, distance (m, to the heave's center), radius (m),
## knockback (force).

@export var flash_color: Color = Color("#D9A55B")
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_time: float = 0.0

@onready var _flash: FlashRing = $Flash


func _ready() -> void:
	_flash.color = flash_color
	_flash.time = flash_time


func _aim_range() -> float:
	var p: Dictionary = params()
	return p.distance + p.radius


func _fire(origin: Vector3, direction: Vector3, _through_toa_uma: bool, magnitude: float) -> int:
	var swarm: SwarmServer = taln.loadout.swarm
	if swarm == null:
		return 0
	var p: Dictionary = params()
	var center: Vector3 = origin + direction * p.distance
	var hits: int = swarm.apply_damage_in_radius(center, p.radius, p.damage * magnitude, Damage.Type.KINETIC)
	swarm.apply_impulse_in_radius(center, p.radius, p.knockback * magnitude)
	_flash.show_at(center, p.radius)
	return hits
