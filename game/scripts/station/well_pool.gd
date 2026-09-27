class_name WellPool
extends Area3D
## A Well pool (spec §2.3). Reports whether Taln (any body in the "taln"
## group) is standing in it and holds pool_capacity base Investiture, which
## the Well drains from it. The disc shrinks and dims as it drains; drained,
## the pool vanishes until the Well sends it somewhere new with reappear().
## Pools put themselves in the "well_pools" group and size their disc and
## trigger from tuning.

signal taln_presence_changed(inside: bool)
signal depleted

@export var tuning: WellPoolTuning

var is_taln_inside: bool = false
var is_active: bool = true
## Base Investiture left.
var remaining: float = 0.0

@onready var _disc: MeshInstance3D = $Disc
var _material: StandardMaterial3D
var _base_color: Color


func _ready() -> void:
	var shape: CylinderShape3D = ($CollisionShape3D as CollisionShape3D).shape
	shape.radius = tuning.pool_radius
	var disc: CylinderMesh = _disc.mesh
	disc.top_radius = tuning.pool_radius
	disc.bottom_radius = tuning.pool_radius
	# Each pool dims on its own.
	_material = (disc.material as StandardMaterial3D).duplicate()
	_base_color = _material.albedo_color
	_disc.material_override = _material
	remaining = tuning.pool_capacity
	add_to_group(&"well_pools")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_show_fill()


## Takes up to amount from the pool and returns what it gave.
func drain(amount: float) -> float:
	if not is_active or amount <= 0.0:
		return 0.0
	var taken: float = minf(amount, remaining)
	remaining -= taken
	_show_fill()
	if remaining <= 0.0:
		is_active = false
		visible = false
		set_deferred(&"monitoring", false)
		_set_inside(false)
		depleted.emit()
	return taken


## Full again at a new spot.
func reappear(at: Vector3) -> void:
	global_position = at
	remaining = tuning.pool_capacity
	is_active = true
	visible = true
	set_deferred(&"monitoring", true)
	_show_fill()


## Share of pool_capacity left.
func fill() -> float:
	return remaining / tuning.pool_capacity if tuning.pool_capacity > 0.0 else 0.0


func _show_fill() -> void:
	var f: float = fill()
	var scale_now: float = lerpf(tuning.drained_scale, 1.0, f)
	_disc.scale = Vector3(scale_now, 1.0, scale_now)
	_material.albedo_color = _base_color * lerpf(tuning.drained_brightness, 1.0, f)
	_material.albedo_color.a = 1.0


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"taln"):
		_set_inside(true)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"taln"):
		_set_inside(false)


func _set_inside(inside: bool) -> void:
	if inside == is_taln_inside:
		return
	is_taln_inside = inside
	taln_presence_changed.emit(inside)
