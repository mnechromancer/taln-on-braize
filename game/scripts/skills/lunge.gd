class_name Lunge
extends SurgeBehavior
## Lunge, Doomhunter's starting Surge (Stoneward, Tension; P2-14): the ground
## snaps under Taln and throws him on a low arc at the nearest commander
## within hunt_range (or along the aim, with none), over the crowd. He lands
## striking Kinetic damage around him. From the ground only, like Heave.
## Overcharge stretches the distance.
##
## level_params keys: distance (m), apex (m), damage, radius (m), hunt_range (m).

signal struck(at: Vector3, hits: int)

@export var flash_color: Color = Color("#D9A55B")
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_time: float = 0.0

var _strike_pending: bool = false

@onready var _flash: FlashRing = $Flash


func _ready() -> void:
	_flash.color = flash_color
	_flash.time = flash_time
	taln.landed.connect(_on_landed)


func is_ready() -> bool:
	return super.is_ready() and taln.is_on_floor() and not taln.airborne


## The nearest commander within hunt_range, or null.
func hunted() -> Variant:
	var swarm: SwarmServer = taln.loadout.swarm
	if swarm == null:
		return null
	var best: Variant = null
	var best_dist: float = params().hunt_range
	for slot: int in swarm.get_commander_slots():
		var at: Vector3 = swarm.get_enemy_position(slot)
		var d: float = Vector2(at.x - taln.global_position.x, at.z - taln.global_position.z).length()
		if d < best_dist:
			best = at
			best_dist = d
	return best


## Straight at the hunted commander; otherwise the usual soft-locked aim.
func aim_direction() -> Vector3:
	var target: Variant = hunted()
	if target == null:
		return super()
	var flat := Vector3((target as Vector3).x - taln.global_position.x, 0.0, (target as Vector3).z - taln.global_position.z)
	return flat.normalized() if not flat.is_zero_approx() else super()


func _aim_range() -> float:
	return params().distance


func _fire(origin: Vector3, direction: Vector3, _through_toa_uma: bool, magnitude: float) -> int:
	if taln.airborne:
		return 0
	var p: Dictionary = params()
	var distance: float = p.distance * magnitude
	# Land on the commander when it's nearer than a full lunge.
	var target: Variant = hunted()
	if target != null:
		var d: float = Vector2((target as Vector3).x - origin.x, (target as Vector3).z - origin.z).length()
		distance = minf(distance, maxf(d, 1.0))
	var g: float = taln.tuning.gravity
	var up: float = sqrt(2.0 * g * p.apex)
	var flight: float = 2.0 * up / g
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	taln.launch(flat * (distance / flight) + Vector3.UP * up)
	_strike_pending = true
	return 0


func _on_landed(_fall_speed: float, at: Vector3) -> void:
	if not _strike_pending:
		return
	_strike_pending = false
	var swarm: SwarmServer = taln.loadout.swarm
	if swarm == null:
		return
	var p: Dictionary = params()
	var hits: int = swarm.apply_damage_in_radius(at, p.radius, p.damage, Damage.Type.KINETIC)
	_flash.show_at(at, p.radius)
	struck.emit(at, hits)
