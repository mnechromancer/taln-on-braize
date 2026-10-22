class_name StoneWarden
extends Structure
## A stone construct (Warden, P2-11): walks to its rally point and holds it,
## striking everything within its reach every interval. A lure: the swarm
## near it attacks it instead of Taln. Casting Warden again moves the rally
## point. It walks over the ground's sampled surface and ignores walls (a
## graybox construct).

const HEIGHT := 1.8
const WIDTH := 0.9

var damage: float = 0.0
var interval: float = 1.0
var strike_radius: float = 0.0
var speed: float = 0.0
## Where it heads (world XZ); it stops within stop_distance.
var rally: Vector3 = Vector3.ZERO
var stop_distance: float = 0.5
var flash_color: Color = Color("d9a55b", 0.85)
var flash_time: float = 0.2

var _cooldown: float = 0.0
var _flash: FlashRing
var _body: MeshInstance3D


func _init() -> void:
	kind = &"warden"


func _ready() -> void:
	_body = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(WIDTH, HEIGHT, WIDTH)
	_body.mesh = mesh
	_body.position.y = HEIGHT * 0.5
	_body.material_override = stone_material(Color("a08a5a"))
	add_child(_body)
	_flash = FlashRing.new()
	_flash.color = flash_color
	_flash.time = flash_time
	add_child(_flash)
	rally = global_position


func _act(delta: float) -> void:
	var to := Vector3(rally.x - global_position.x, 0.0, rally.z - global_position.z)
	if to.length() > stop_distance:
		var step: Vector3 = to.normalized() * minf(speed * delta, to.length())
		var next: Vector3 = global_position + step
		if ground and not ground.is_blocked_at(next.x, next.z):
			next.y = ground.get_surface_height_at(next.x, next.z)
			global_position = next
		rotation.y = atan2(-to.x, -to.z)
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0 or swarm == null:
		return
	if swarm.find_nearest(global_position, strike_radius) == Vector3.INF:
		return
	var hits: int = swarm.apply_damage_in_radius(global_position, strike_radius, damage, Damage.Type.KINETIC)
	_cooldown = interval
	_flash.show_at(global_position, strike_radius)
	struck.emit(hits, damage * hits)
