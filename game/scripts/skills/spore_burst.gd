class_name SporeBurst
extends SurgeBehavior
## Spore Burst, a Plaguebringer Surge (Ashynite; P2-15): the culture bursts
## at a point along the aim, infecting every enemy in the radius (Overcharge
## widens it). No damage of its own: the disease takes them. Routed through
## Toa'uma like any Surge, so it is loud (spec v1.7, for confirmation).
##
## level_params keys: distance (m), radius (m).

@export var flash_color: Color = Color("#7a9a3a")
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
	var radius: float = p.radius * magnitude
	var newly: int = swarm.infect_in_radius(center, radius)
	_flash.show_at(center, radius)
	return newly
