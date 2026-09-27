class_name Settle
extends SurgeBehavior
## Settle, Taln's starting Surge (Stoneward, Cohesion). Kinetic damage in a
## cone, then roots whatever is still standing in it. A ground reticle shows
## the cone while the Surge is ready; a cast leaves a cone of cracked ground
## for the root's duration. The crack glow follows the routing (Art Direction):
## Voidlight core and teal rim with flicker through Toa'uma, steady ochre
## through the Blade.
##
## level_params keys: damage, root_duration (s), cone_deg (full width), range (m).

@export_group("Reticle")
@export var reticle_color: Color = Color(1.0, 1.0, 1.0, 0.0)
@export_range(0.0, 0.5, 0.01, "suffix:m") var reticle_lift: float = 0.0
## How fast the reticle turns toward the aim, as an exponential rate: it
## closes 1 − e^(−rate × t) of the gap in t seconds. Smooths the soft-lock's
## hops between sectors; the cast itself still uses the exact aim.
@export_range(0.0, 60.0, 0.5, "suffix:/s") var reticle_follow_rate: float = 0.0

@export_group("Cracked ground")
@export var voidlight_core: Color = Color.BLACK
@export var voidlight_rim: Color = Color.BLACK
@export var blade_glow: Color = Color.BLACK
@export_range(0.0, 0.5, 0.01, "suffix:m") var cracks_lift: float = 0.0
## The cracks fade out over the root's last this-many seconds.
@export_range(0.0, 2.0, 0.01, "suffix:s") var cracks_fade_time: float = 0.0

@export_range(2, 64, 1) var fan_segments: int = 16

## Seconds left on the current cracked-ground visual.
var cracks_left: float = 0.0
## The reticle's current yaw on the ground (atan2(x, z) of its direction).
var reticle_yaw: float = 0.0

@onready var _reticle: MeshInstance3D = $Reticle
@onready var _cracks: MeshInstance3D = $Cracks
@onready var _cracks_material: ShaderMaterial = (_cracks.material_override as ShaderMaterial).duplicate()


func _ready() -> void:
	_reticle.top_level = true
	# Hidden until _process shows it, so its first frame snaps to the aim.
	_reticle.visible = false
	_cracks.top_level = true
	_cracks.visible = false
	_cracks.material_override = _cracks_material
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = reticle_color
	_reticle.material_override = material
	_build_meshes()
	level_changed.connect(func(_level: int) -> void: _build_meshes())


func _physics_process(delta: float) -> void:
	super(delta)
	if cracks_left > 0.0:
		cracks_left = maxf(cracks_left - delta, 0.0)
		_cracks.visible = cracks_left > 0.0
		var fade: float = clampf(cracks_left / cracks_fade_time, 0.0, 1.0) if cracks_fade_time > 0.0 else 1.0
		_cracks_material.set_shader_parameter(&"fade", fade)


func _process(delta: float) -> void:
	var was_visible: bool = _reticle.visible
	_reticle.visible = is_ready()
	if not _reticle.visible:
		return
	var aim: Vector3 = aim_direction()
	var target_yaw: float = atan2(aim.x, aim.z)
	# Snap when the reticle reappears; otherwise ease toward the aim.
	reticle_yaw = target_yaw if not was_visible \
			else lerp_angle(reticle_yaw, target_yaw, 1.0 - exp(-reticle_follow_rate * delta))
	place_on_ground(_reticle, taln.get_global_transform_interpolated().origin,
			Vector3(sin(reticle_yaw), 0.0, cos(reticle_yaw)), reticle_lift)


func _aim_range() -> float:
	return params().range


func _fire(origin: Vector3, direction: Vector3, through_toa_uma: bool, magnitude: float) -> int:
	var p: Dictionary = params()
	var swarm: SwarmServer = taln.loadout.swarm
	var hits: int = 0
	var root: float = p.root_duration * magnitude
	if swarm:
		hits = swarm.apply_damage_in_cone(origin, direction, p.cone_deg, p.range, p.damage * magnitude,
				Damage.Type.KINETIC)
		swarm.apply_root_in_cone(origin, direction, p.cone_deg, p.range, root)
	_show_cracks(origin, direction, through_toa_uma, root)
	return hits


func _show_cracks(origin: Vector3, direction: Vector3, through_toa_uma: bool, duration: float) -> void:
	place_on_ground(_cracks, origin, direction, cracks_lift)
	_cracks.reset_physics_interpolation()
	_cracks_material.set_shader_parameter(&"core_color", voidlight_core if through_toa_uma else blade_glow)
	_cracks_material.set_shader_parameter(&"rim_color", voidlight_rim if through_toa_uma else blade_glow)
	_cracks_material.set_shader_parameter(&"flicker", 1.0 if through_toa_uma else 0.0)
	_cracks_material.set_shader_parameter(&"seed", randf() * 100.0)
	_cracks_material.set_shader_parameter(&"fade", 1.0)
	cracks_left = duration
	_cracks.visible = duration > 0.0


func _build_meshes() -> void:
	var p: Dictionary = params()
	_reticle.mesh = build_fan_mesh(p.cone_deg, p.range, fan_segments)
	_cracks.mesh = build_fan_mesh(p.cone_deg, p.range, fan_segments)
