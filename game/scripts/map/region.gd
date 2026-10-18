class_name Region
extends Node3D
## One region of the persistent map, one of Braize's stations (Design Doc
## v2.0 §4, spec v1.4 #4). Its tier sets the station index (v, S, D and P).
## Children: a BreakerSite named "BreakerSite", and "Seals", whose CSGBox3D
## barriers close the region's exits until its breaker falls.

@export var id: StringName = &""
@export var display_name: String = ""
## 1 to 3, by depth.
@export_range(1, 3, 1) var tier: int = 1
## The region's extent in world XZ.
@export var bounds: Rect2 = Rect2()

@onready var site: BreakerSite = $BreakerSite
@onready var _seals: Node3D = $Seals


func contains(at: Vector3) -> bool:
	return bounds.has_point(Vector2(at.x, at.z))


## Opens every exit (the breaker fell). Returns the footprint that was cleared.
func open_seals(ground: StationGround) -> Rect2:
	return MapBarrier.remove_all(_seals, ground)


func seals_closed() -> bool:
	return _seals.get_child_count() > 0
