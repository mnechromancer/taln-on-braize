class_name WellPool
extends Area3D
## A Well pool (spec §2.3). Reports whether Taln (any body in the "taln"
## group) is standing in it. Pools put themselves in the "well_pools" group
## and size their disc and trigger from tuning.

signal taln_presence_changed(inside: bool)

@export var tuning: WellPoolTuning

var is_taln_inside: bool = false


func _ready() -> void:
	var shape: CylinderShape3D = ($CollisionShape3D as CollisionShape3D).shape
	shape.radius = tuning.pool_radius
	var disc: CylinderMesh = ($Disc as MeshInstance3D).mesh
	disc.top_radius = tuning.pool_radius
	disc.bottom_radius = tuning.pool_radius
	add_to_group(&"well_pools")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


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
