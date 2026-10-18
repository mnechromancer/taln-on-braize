class_name MapBarrier
extends RefCounted
## Removing barriers (region seals, gate blockers) from the persistent map.
## A barrier is a CSGBox3D in StationGround's wall_block group, so the swarm
## treats its cells as walls; once it's gone the ground under it is resampled.


## Takes every CSGBox3D child of holder out of the world at once (so the next
## ground sample can't hit its collision), frees them and has ground resample
## the cells they covered. Returns that footprint in world XZ (empty if none).
static func remove_all(holder: Node, ground: StationGround) -> Rect2:
	var footprint := Rect2()
	for child: Node in holder.get_children():
		var box := child as CSGBox3D
		if box == null:
			continue
		var bounds: AABB = box.global_transform * AABB(-box.size * 0.5, box.size)
		var rect := Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z)
		footprint = rect if not footprint.has_area() else footprint.merge(rect)
		holder.remove_child(box)
		box.queue_free()
	if footprint.has_area() and ground:
		var local := Rect2(footprint.position - Vector2(ground.global_position.x, ground.global_position.z), footprint.size)
		ground.rebuild_region(local)
	return footprint
