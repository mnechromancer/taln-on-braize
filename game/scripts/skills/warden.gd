class_name Warden
extends SurgeBehavior
## Warden, an Earthshaper Surge (Stoneward, Cohesion; P2-11): calls a stone
## construct up beside Taln. It walks to its rally point and holds it,
## striking everything in reach, and the swarm near it attacks it instead of
## Taln. While one stands, casting again costs nothing and moves its rally
## point rally_distance along the aim (the RTS half of the loop). Overcharge
## lengthens its life.
##
## level_params keys: hp, duration (s), damage, interval (s), strike_radius
## (m), speed (m/s), pull_radius (m), body_radius (m), max, rally_distance
## (m), rally_cooldown (s).

signal called(warden: StoneWarden)
signal rallied(at: Vector3)

@export var flash_color: Color = Color("#D9A55B")
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_time: float = 0.0

@onready var _flash: FlashRing = $Flash


func _ready() -> void:
	_flash.color = flash_color
	_flash.time = flash_time


## The standing warden, or null.
func current() -> StoneWarden:
	var structures: Structures = taln.loadout.structures
	if structures == null:
		return null
	var standing: Array[Structure] = structures.of_kind(&"warden")
	return standing[0] as StoneWarden if not standing.is_empty() else null


## A free rally order while a warden stands; otherwise a normal cast.
func is_ready() -> bool:
	return cooldown_left <= 0.0 and (current() != null or taln.investiture.can_afford(skill.investiture_cost))


func try_cast() -> bool:
	var warden: StoneWarden = current()
	if warden == null:
		return super()
	if cooldown_left > 0.0:
		return false
	var p: Dictionary = params()
	var direction: Vector3 = aim_direction()
	var at: Vector3 = taln.global_position + direction * p.rally_distance
	at.y = taln.loadout.structures.ground.get_surface_height_at(at.x, at.z)
	warden.rally = at
	cooldown_left = p.rally_cooldown
	_flash.show_at(at, 1.0)
	rallied.emit(at)
	return true


func _aim_range() -> float:
	return params().rally_distance


func _fire(origin: Vector3, direction: Vector3, _through_toa_uma: bool, magnitude: float) -> int:
	var structures: Structures = taln.loadout.structures
	if structures == null:
		return 0
	var p: Dictionary = params()
	var warden := StoneWarden.new()
	warden.max_hp = p.hp
	warden.lifetime_left = p.duration * magnitude
	warden.damage = p.damage
	warden.interval = p.interval
	warden.strike_radius = p.strike_radius
	warden.speed = p.speed
	warden.pull_radius = p.pull_radius
	warden.body_radius = p.body_radius
	warden.flash_color = flash_color
	warden.flash_time = flash_time
	# Up beside Taln, then off toward the aim.
	var at: Vector3 = origin + direction * 1.5
	at.y = structures.ground.get_surface_height_at(at.x, at.z)
	structures.add(warden, at, int(p.max))
	var rally: Vector3 = origin + direction * p.rally_distance
	rally.y = structures.ground.get_surface_height_at(rally.x, rally.z)
	warden.rally = rally
	_flash.show_at(at, 1.0)
	called.emit(warden)
	return 0
