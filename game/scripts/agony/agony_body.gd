class_name AgonyBody
extends Node
## Agony on Taln's body (Art Direction, VFX: the Agony table), as placeholder
## emissive steps on his body mesh: nothing below 25%; faint ember seams from
## 25%; cracks spread with a slow pulse from 50%; bright, shimmering from 75%;
## at 100% a full-body ember glow, an Agony-hue edge vignette and a world
## desaturated further. Welcome plays a short charge-up (a flare that builds,
## then a ring bursting out); Bank a brief inward pull of ember (a ring
## drawn in). Effects run in real time: the windows slow the game down.
## Emissive only; no lights.

@export var meter: AgonyMeter
@export var body: MeshInstance3D
## An unshaded flat ring on the ground under Taln, for the Welcome and Bank beats.
@export var ring: MeshInstance3D
@export var vignette: ColorRect

@export var ember_low: Color = Color.BLACK
@export var ember_high: Color = Color.BLACK
## Emission energy at 0, 25, 50, 75 and 100% of the meter.
@export var step_energy: Array[float] = []
@export_range(0.0, 10.0, 0.05, "suffix:Hz") var pulse_rate: float = 0.0
## Energy swing of the 50% pulse and the 75% shimmer, as a fraction.
@export_range(0.0, 1.0, 0.01) var pulse_depth: float = 0.0
@export_range(0.0, 1.0, 0.01) var shimmer_depth: float = 0.0
## World saturation at a full meter (1 = unchanged).
@export_range(0.0, 1.0, 0.01) var full_saturation: float = 1.0

@export_group("Welcome and Bank")
@export_range(0.0, 2.0, 0.01, "suffix:s") var charge_time: float = 0.0
@export_range(0.0, 20.0, 0.1) var charge_energy: float = 0.0
@export_range(0.0, 2.0, 0.01, "suffix:s") var pull_time: float = 0.0
@export_range(0.0, 10.0, 0.1, "suffix:m") var ring_radius: float = 0.0

## Seconds left of the Welcome charge-up and the Bank pull.
var charge_left: float = 0.0
var pull_left: float = 0.0
var _material: StandardMaterial3D
var _ring_material: StandardMaterial3D
var _phase: float = 0.0
var _environment: Environment
var _base_saturation: float = 1.0
var _base_adjustment: bool = false
var _desaturated: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = (body.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	_material.emission_enabled = true
	_material.emission = ember_low
	body.material_override = _material
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_material.albedo_color = ember_high
	ring.mesh = SkillBehavior.build_ring_mesh(0.85, 1.0, 48)
	ring.material_override = _ring_material
	ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	ring.visible = false
	vignette.visible = false


## Hooks the Welcome and Bank beats to a Catalysis.
func watch(catalysis: Catalysis) -> void:
	catalysis.welcomed.connect(func() -> void: charge_left = charge_time)
	catalysis.banked.connect(func(_first: bool) -> void: pull_left = pull_time)


## The Art Direction step for the current fill: 0 below 25%, 1 from 25%,
## 2 from 50%, 3 from 75%, 4 at 100%.
func step() -> int:
	var f: float = meter.value / meter.tuning.meter_max
	if f >= 1.0:
		return 4
	return clampi(floori(f * 4.0), 0, 3)


func _process(delta: float) -> void:
	var real: float = delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	_phase = fmod(_phase + pulse_rate * real, 1.0)
	var s: int = step()
	var energy: float = step_energy[s] if s < step_energy.size() else 0.0
	if s == 2:
		energy *= 1.0 + pulse_depth * sin(_phase * TAU)
	elif s == 3:
		# Heat shimmer: smooth, not a flicker (flicker is Voidlight's signature).
		energy *= 1.0 + shimmer_depth * (sin(_phase * TAU * 3.0) * 0.6 + sin(_phase * TAU * 7.0 + 1.3) * 0.4)
	_material.emission = ember_high if s >= 3 else ember_low
	var ring_scale: float = 0.0
	if charge_left > 0.0:
		charge_left = maxf(charge_left - real, 0.0)
		var t: float = 1.0 - charge_left / charge_time
		# Builds for most of the beat, then bursts out as a ring.
		energy += charge_energy * minf(t / 0.7, 1.0)
		ring_scale = ring_radius * maxf((t - 0.7) / 0.3, 0.0)
		_ring_material.albedo_color.a = 1.0 - maxf((t - 0.7) / 0.3, 0.0)
	elif pull_left > 0.0:
		pull_left = maxf(pull_left - real, 0.0)
		var t: float = 1.0 - pull_left / pull_time
		ring_scale = ring_radius * (1.0 - t)
		_ring_material.albedo_color.a = 0.4 + 0.6 * t
	ring.visible = ring_scale > 0.01
	if ring.visible:
		ring.global_position = body.global_position - Vector3.UP * (body.position.y - 0.03)
		ring.scale = Vector3(ring_scale, 1.0, ring_scale)
	_material.emission_energy_multiplier = energy
	vignette.visible = s == 4
	_desaturate(s == 4)


## At a full meter the world desaturates further from its own base.
func _desaturate(on: bool) -> void:
	if on == _desaturated:
		return
	if _environment == null:
		_environment = body.get_world_3d().environment if body.is_inside_tree() else null
		if _environment == null:
			return
		_base_saturation = _environment.adjustment_saturation
		_base_adjustment = _environment.adjustment_enabled
	_desaturated = on
	_environment.adjustment_enabled = on or _base_adjustment
	_environment.adjustment_saturation = _base_saturation * (full_saturation if on else 1.0)
