class_name BreakingStroke
extends SkillBehavior
## Breaking Stroke, Taln's starting Weapon (Stoneward). Auto-fires: when the
## swing is ready and find_nearest() finds an enemy within range plus
## acquire_margin, it deals Kinetic damage in a cone pointed at that enemy,
## then waits the level's interval. A flat arc flashes where it swung.
##
## level_params keys: damage, interval (s), cone_deg (full width), range (m),
## acquire_margin (m).
##
## Catalyst (Greater). Its Cataclysm (cataclysm_params: radius, damage,
## knockback; placeholders) is one great stroke all around Taln: Kinetic
## damage and a knockback of that force. An ochre ring races out to the
## radius and is gone within ring_time.

signal swung(direction: Vector3, hits: int)

## Placeholder visual: Stoneward ochre, shown for flash_time after a swing.
@export var flash_color: Color = Color("#D9A55B")
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_time: float = 0.0
@export_range(2, 64, 1) var arc_segments: int = 16
## Height of the arc above Taln's feet, so it doesn't z-fight the ground.
@export_range(0.0, 0.5, 0.01, "suffix:m") var arc_lift: float = 0.0
@export_group("Cataclysm")
@export var ring_color: Color = Color.BLACK
@export_range(0.0, 2.0, 0.01, "suffix:s") var ring_time: float = 0.0
## Ring width as a fraction of its radius.
@export_range(0.01, 1.0, 0.01) var ring_width: float = 0.1

var ring_left: float = 0.0

var _flash_left: float = 0.0

@onready var _arc: MeshInstance3D = $Arc
@onready var _ring: MeshInstance3D = $CataclysmRing


func _ready() -> void:
	_arc.top_level = true
	_arc.visible = false
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = flash_color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_arc.material_override = material
	_build_arc()
	level_changed.connect(func(_level: int) -> void: _build_arc())
	_ring.top_level = true
	# Animated in _process, so engine interpolation would only smear it.
	_ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ring.visible = false
	_ring.mesh = build_ring_mesh(1.0 - ring_width, 1.0, 64)
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_material.albedo_color = ring_color
	_ring.material_override = ring_material


func _process(delta: float) -> void:
	if ring_left <= 0.0:
		return
	ring_left = maxf(ring_left - delta, 0.0)
	_ring.visible = ring_left > 0.0
	var t: float = 1.0 - ring_left / ring_time
	var r: float = maxf(skill.cataclysm_params.radius * t, 0.01)
	_ring.scale = Vector3(r, 1.0, r)
	(_ring.material_override as StandardMaterial3D).albedo_color.a = ring_color.a * (1.0 - t)


func cataclysm() -> int:
	var p: Dictionary = skill.cataclysm_params
	var origin: Vector3 = taln.global_position
	var swarm: SwarmServer = taln.loadout.swarm
	var hits: int = 0
	if swarm:
		hits = swarm.apply_damage_in_radius(origin, p.radius, p.damage, Damage.Type.KINETIC)
		swarm.apply_impulse_in_radius(origin, p.radius, p.knockback)
	_ring.global_position = origin + Vector3.UP * arc_lift
	_ring.scale = Vector3(0.01, 1.0, 0.01)
	_ring.visible = ring_time > 0.0
	ring_left = ring_time
	return hits


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if _flash_left > 0.0:
		_flash_left -= delta
		_arc.visible = _flash_left > 0.0
	var swarm: SwarmServer = taln.loadout.swarm
	if cooldown_left > 0.0 or swarm == null:
		return
	var p: Dictionary = params()
	var origin: Vector3 = taln.global_position
	var nearest: Vector3 = swarm.find_nearest(origin, p.range + p.acquire_margin)
	if nearest == Vector3.INF:
		return
	var direction := Vector3(nearest.x - origin.x, 0.0, nearest.z - origin.z)
	if direction.is_zero_approx():
		direction = -taln.global_basis.z
	direction = direction.normalized()
	var hits: int = swarm.apply_damage_in_cone(origin, direction, p.cone_deg, p.range, p.damage,
			Damage.Type.KINETIC)
	cooldown_left = p.interval
	_flash(origin, direction)
	swung.emit(direction, hits)


func _flash(origin: Vector3, direction: Vector3) -> void:
	place_on_ground(_arc, origin, direction, arc_lift)
	_arc.reset_physics_interpolation()
	_arc.visible = flash_time > 0.0
	_flash_left = flash_time


func _build_arc() -> void:
	var p: Dictionary = params()
	_arc.mesh = build_fan_mesh(p.cone_deg, p.range, arc_segments)
