class_name SentinelTower
extends Structure
## A stone tower (Sentinel, P2-11): every interval it drops a shard on the
## nearest enemy within range, dealing Kinetic damage in a small burst. A
## lure: the swarm near it attacks it instead of Taln, and breaks it once
## its Health is gone.

const HEIGHT := 3.0

var damage: float = 0.0
var interval: float = 1.0
var range: float = 0.0
var burst_radius: float = 0.0
var flash_color: Color = Color("d9a55b", 0.85)
var flash_time: float = 0.2

var _cooldown: float = 0.0
var _flash: FlashRing


func _init() -> void:
	kind = &"tower"


func _ready() -> void:
	var column := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = body_radius * 0.7
	mesh.bottom_radius = body_radius
	mesh.height = HEIGHT
	column.mesh = mesh
	column.position.y = HEIGHT * 0.5
	column.material_override = stone_material()
	add_child(column)
	_flash = FlashRing.new()
	_flash.color = flash_color
	_flash.time = flash_time
	add_child(_flash)


func _act(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0 or swarm == null:
		return
	var target: Vector3 = swarm.find_nearest(global_position, range)
	if target == Vector3.INF:
		return
	var hits: int = swarm.apply_damage_in_radius(target, burst_radius, damage, Damage.Type.KINETIC)
	_cooldown = interval
	_flash.show_at(target, burst_radius)
	struck.emit(hits, damage * hits)
