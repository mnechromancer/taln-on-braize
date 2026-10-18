class_name Gate
extends Node3D
## A gate on the persistent map (spec v1.4 #4): its CSGBox3D children block
## a route until MetaState records the gate open, which lasts every later
## cycle. The station opens it at cycle start.

@export var def: GateDef


func open(ground: StationGround) -> Rect2:
	return MapBarrier.remove_all(self, ground)


func is_closed() -> bool:
	return get_child_count() > 0
