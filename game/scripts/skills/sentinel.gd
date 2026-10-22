class_name Sentinel
extends SurgeBehavior
## Sentinel, an Earthshaper Surge (Stoneward, Cohesion; P2-11): raises a
## stone tower distance meters along the aim. The tower drops shards on the
## nearest enemy in its range for its duration, and draws the swarm near it
## onto itself until they break it. At most max stand at once. Overcharge
## lengthens its life.
##
## level_params keys: distance (m), hp, duration (s), damage, interval (s),
## range (m), burst_radius (m), pull_radius (m), body_radius (m), max.

signal raised(tower: SentinelTower)

@export var flash_color: Color = Color("#D9A55B")
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_time: float = 0.0

@onready var _flash: FlashRing = $Flash


func _ready() -> void:
	_flash.color = flash_color
	_flash.time = flash_time


func _aim_range() -> float:
	return params().distance


func _fire(origin: Vector3, direction: Vector3, _through_toa_uma: bool, magnitude: float) -> int:
	var structures: Structures = taln.loadout.structures
	if structures == null:
		return 0
	var p: Dictionary = params()
	var tower := SentinelTower.new()
	tower.max_hp = p.hp
	tower.lifetime_left = p.duration * magnitude
	tower.damage = p.damage
	tower.interval = p.interval
	tower.range = p.range
	tower.burst_radius = p.burst_radius
	tower.pull_radius = p.pull_radius
	tower.body_radius = p.body_radius
	tower.flash_color = flash_color
	tower.flash_time = flash_time
	var at: Vector3 = origin + direction * p.distance
	at.y = structures.ground.get_surface_height_at(at.x, at.z)
	structures.add(tower, at, int(p.max))
	_flash.show_at(at, p.body_radius * 2.0)
	raised.emit(tower)
	return 0
