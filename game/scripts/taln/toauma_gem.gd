class_name ToaumaGem
extends MeshInstance3D
## Placeholder for the peakspren gem on Taln's chest (Art Direction). Warm and
## dim at rest, pulsing faster as Strain rises; a Voidlight flicker on every
## routed use; a bright pulse when Toa'uma speaks. Emissive only, no light.

@export var toauma: Toauma

@export var rest_color: Color = Color.BLACK
@export var voidlight_core: Color = Color.BLACK
@export var voidlight_rim: Color = Color.BLACK
@export_range(0.0, 10.0, 0.05) var rest_energy: float = 0.0
## Energy swing of the resting pulse, as a fraction of rest_energy.
@export_range(0.0, 1.0, 0.01) var pulse_depth: float = 0.0
@export_range(0.0, 10.0, 0.05, "suffix:Hz") var pulse_rate_base: float = 0.0
@export_range(0.0, 5.0, 0.05, "suffix:Hz") var pulse_rate_per_strain: float = 0.0
@export_range(0.0, 2.0, 0.01, "suffix:s") var flicker_time: float = 0.0
@export_range(0.0, 20.0, 0.1) var flicker_energy: float = 0.0
@export_range(0.0, 2.0, 0.01, "suffix:s") var speak_time: float = 0.0
@export_range(0.0, 20.0, 0.1) var speak_energy: float = 0.0

var flicker_left: float = 0.0
var speak_left: float = 0.0
var _phase: float = 0.0
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.emission_enabled = true
	material_override = _material
	toauma.used.connect(func(_is_draw: bool, _effect: Toauma.Effect) -> void: flicker_left = flicker_time)
	toauma.spoke.connect(func(_line: String) -> void: speak_left = speak_time)
	_show(rest_color, rest_energy)


func pulse_rate() -> float:
	return pulse_rate_base + pulse_rate_per_strain * toauma.strain


func _process(delta: float) -> void:
	_phase = fmod(_phase + pulse_rate() * delta, 1.0)
	flicker_left = maxf(flicker_left - delta, 0.0)
	speak_left = maxf(speak_left - delta, 0.0)
	if flicker_left > 0.0:
		# Glitchy: a random Voidlight hue and energy every frame.
		_show(voidlight_core if randf() < 0.5 else voidlight_rim, flicker_energy * randf())
		return
	var energy: float = rest_energy * (1.0 + pulse_depth * sin(_phase * TAU))
	if speak_left > 0.0 and speak_time > 0.0:
		energy += speak_energy * speak_left / speak_time
	_show(rest_color, energy)


func _show(color: Color, energy: float) -> void:
	_material.albedo_color = color
	_material.emission = color
	_material.emission_energy_multiplier = energy
