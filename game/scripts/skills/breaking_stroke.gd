class_name BreakingStroke
extends SkillBehavior
## Breaking Stroke, Taln's starting Weapon (Stoneward). Auto-fires: when the
## swing is ready and find_nearest() finds an enemy within range plus
## acquire_margin, it deals Kinetic damage in a cone pointed at that enemy,
## then waits the level's interval. A flat arc flashes where it swung.
##
## level_params keys: damage, interval (s), cone_deg (full width), range (m),
## acquire_margin (m).

signal swung(direction: Vector3, hits: int)

## Placeholder visual: Stoneward ochre, shown for flash_time after a swing.
@export var flash_color: Color = Color("#D9A55B")
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_time: float = 0.0
@export_range(2, 64, 1) var arc_segments: int = 16
## Height of the arc above Taln's feet, so it doesn't z-fight the ground.
@export_range(0.0, 0.5, 0.01, "suffix:m") var arc_lift: float = 0.0

var _flash_left: float = 0.0

@onready var _arc: MeshInstance3D = $Arc


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
