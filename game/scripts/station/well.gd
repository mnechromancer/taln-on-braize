class_name Well
extends Node
## The Well (spec §2.3): Braize's ambient Investiture and its pools. Pays Taln
## ambient_rate per second while a wave runs, and draws from any pool he
## stands in: draw_rate_anchored while Anchored, draw_rate_standing
## otherwise. Pools hold pool_capacity each (counted in base Investiture;
## income is times the station value). A drained pool vanishes and, after
## respawn_delay, reappears at a random spot whose whole disc is open, flat
## ground, at least min_distance_taln from Taln and min_distance_pools from
## the other pools. The pools are the WellPool nodes in the "well_pools" group.

signal pool_depleted(pool: WellPool)
signal pool_moved(pool: WellPool, position: Vector3)

@export var tuning: WellPoolTuning
@export var taln: Taln
@export var spawner: SpawnDirector
@export var ground: StationGround

## Seed it for reproducible runs (spec §11.5).
var rng := RandomNumberGenerator.new()
## While frozen (the Return sequence) the Well pays nothing and pools wait.
var frozen: bool = false
## Seconds until each depleted pool reappears.
var _respawn_left: Dictionary[WellPool, float] = {}


func _ready() -> void:
	rng.randomize()
	for pool in pools():
		pool.depleted.connect(_on_pool_depleted.bind(pool))


func pools() -> Array[WellPool]:
	var found: Array[WellPool] = []
	for node: Node in get_tree().get_nodes_in_group(&"well_pools"):
		found.append(node as WellPool)
	return found


func _physics_process(delta: float) -> void:
	if frozen:
		return
	if spawner.is_in_wave():
		taln.investiture.add(tuning.ambient_rate * delta, &"ambient")
	for pool in pools():
		if pool.is_active and pool.is_taln_inside:
			var rate: float = tuning.draw_rate_anchored if taln.anchored.is_anchored else tuning.draw_rate_standing
			var taken: float = pool.drain(rate * delta)
			if taken > 0.0:
				taln.investiture.add(taken, &"pool")
	for pool: WellPool in _respawn_left.keys():
		_respawn_left[pool] -= delta
		if _respawn_left[pool] <= 0.0:
			var at: Variant = find_spot(pool)
			if at == null:
				_respawn_left[pool] = tuning.retry_delay
				continue
			_respawn_left.erase(pool)
			pool.reappear(at)
			pool_moved.emit(pool, at)


## Seconds until pool reappears, or 0 if it's active.
func respawn_left(pool: WellPool) -> float:
	return _respawn_left.get(pool, 0.0)


## A random spot for pool (null if none turned up in placement_attempts
## tries): its whole disc on open cells within max_height_spread of each
## other, far enough from Taln and the other active pools.
func find_spot(pool: WellPool) -> Variant:
	var origin: Vector2 = ground.get_origin()
	var size := Vector2(ground.get_width(), ground.get_depth()) * ground.get_cell_size()
	var r: float = tuning.pool_radius
	for attempt in tuning.placement_attempts:
		var x: float = rng.randf_range(origin.x + r, origin.x + size.x - r)
		var z: float = rng.randf_range(origin.y + r, origin.y + size.y - r)
		var at := Vector3(x, 0.0, z)
		if Vector2(x - taln.global_position.x, z - taln.global_position.z).length() < tuning.min_distance_taln:
			continue
		var crowded: bool = false
		for other in pools():
			if other != pool and other.is_active \
					and Vector2(x - other.global_position.x, z - other.global_position.z).length() < tuning.min_distance_pools:
				crowded = true
				break
		if crowded:
			continue
		var height: Variant = _disc_height(at, r)
		if height != null:
			at.y = height
			return at
	return null


## The disc's ground height if every cell it touches is open and they're
## level enough; null otherwise.
func _disc_height(center: Vector3, radius: float) -> Variant:
	var cell: float = ground.get_cell_size()
	var origin: Vector2 = ground.get_origin()
	var low: float = INF
	var high: float = -INF
	var first_x: int = floori((center.x - radius - origin.x) / cell)
	var last_x: int = floori((center.x + radius - origin.x) / cell)
	var first_z: int = floori((center.z - radius - origin.y) / cell)
	var last_z: int = floori((center.z + radius - origin.y) / cell)
	for cz in range(first_z, last_z + 1):
		for cx in range(first_x, last_x + 1):
			# The cell's nearest point to the center decides whether the disc touches it.
			var near_x: float = clampf(center.x, origin.x + cx * cell, origin.x + (cx + 1) * cell)
			var near_z: float = clampf(center.z, origin.y + cz * cell, origin.y + (cz + 1) * cell)
			if Vector2(near_x - center.x, near_z - center.z).length() > radius:
				continue
			var mid_x: float = origin.x + (cx + 0.5) * cell
			var mid_z: float = origin.y + (cz + 0.5) * cell
			if ground.is_blocked_at(mid_x, mid_z):
				return null
			var h: float = ground.get_surface_height_at(mid_x, mid_z)
			low = minf(low, h)
			high = maxf(high, h)
	if high - low > tuning.max_height_spread:
		return null
	return ground.get_surface_height_at(center.x, center.z)


func _on_pool_depleted(pool: WellPool) -> void:
	_respawn_left[pool] = tuning.respawn_delay
	pool_depleted.emit(pool)
