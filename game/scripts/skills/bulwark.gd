class_name Bulwark
extends SurgeBehavior
## Bulwark, an Earthshaper Surge (Stoneward, Cohesion; P2-11): raises a wall
## of stone across the aim, distance meters out, that the swarm has to go
## around for its duration (Overcharge lengthens it). At most max stand at
## once; raising another crumbles the oldest.
##
## level_params keys: width, height, thickness (m), distance (m), duration (s), max.

signal raised(wall: StoneWall)

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
	var wall := StoneWall.new()
	wall.size = Vector3(p.width, p.height, p.thickness)
	wall.yaw = atan2(direction.x, direction.z)
	wall.lifetime_left = p.duration * magnitude
	var at: Vector3 = origin + direction * p.distance
	at.y = structures.ground.get_surface_height_at(at.x, at.z)
	structures.add(wall, at, int(p.max))
	_flash.show_at(at, p.width * 0.5)
	raised.emit(wall)
	return 0
