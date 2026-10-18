class_name SpawnDirector
extends Node
## Spends a per-second spawn budget on swarm enemies around Taln (spec §8.2,
## §8.4). The budget accrues into a bank capped at bank_cap_seconds of spend
## and is spent at the type's cost while the SwarmServer is under the alive
## cap. Spawns land on a ring around the target, off blocked cells and, where
## possible, out of the camera's view.
##
## One swarm type. The wave index advances every wave_length seconds; after
## the last wave waves_done fires once and the wave index holds. In a lull
## (between stand-in stations, spec §1.2) there's no wave clock and the budget
## is lull_budget_fraction of the last wave's. begin_station() starts a
## station's waves over. Frozen (the Return sequence), nothing happens.
##
## On the persistent map (P2-10, spec v1.4 #4) the spawner runs endless: the
## wave index is a difficulty clock that keeps rising with no last wave, the
## budget can be scaled (a breaker siege), and spawns stay inside area (the
## region Taln is in).

signal wave_changed(wave: int)
## The station's last wave ran its full length.
signal waves_done
signal spawned(slot: int, position: Vector3)
## A pack spawned outside the budget (e.g. a Notice), with its slots.
signal pack_spawned(type_id: StringName, slots: Array[int])

@export var tuning: SpawnTuning
@export var swarm_type: SwarmType
@export var swarm: SwarmServer
@export var ground: StationGround
@export var target: Node3D

var station_index: int = 0
var returns_this_station: int = 0
## Spawning (and the wave clock) stop while paused (debug) or frozen (the Return).
var paused: bool = false
var frozen: bool = false
## Between stations: a trickle at the wave-9 budget's lull share, no wave clock.
var lull: bool = false
## Debug stress mode: stress alive cap and budget scale from tuning.
var stress: bool = false
## Endless: the wave index keeps rising every wave_length; waves_done never fires.
var endless: bool = false
## Multiplies the budget (a breaker siege).
var budget_scale: float = 1.0
## World XZ rect spawns must land in; an empty rect allows the whole ground.
var area: Rect2 = Rect2()

var wave: int:
	get:
		return _wave
## Seconds into the current wave.
var wave_time: float:
	get:
		return _wave_time
var bank: float:
	get:
		return _bank

var _wave: int = 0
var _wave_time: float = 0.0
var _station_time: float = 0.0
var _done: bool = false
var _bank: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if paused or frozen or not ground.is_ground_data_ready():
		return
	if not lull:
		_wave_time += delta
		_station_time += delta
		while _wave_time >= tuning.wave_length:
			_wave_time -= tuning.wave_length
			if endless or _wave < tuning.waves - 1:
				_wave += 1
				wave_changed.emit(_wave)
		if not endless and not _done and _station_time >= tuning.wave_length * tuning.waves - 0.0001:
			_done = true
			waves_done.emit()

	var rate: float = budget_per_second()
	_bank = minf(_bank + rate * delta, rate * tuning.bank_cap_seconds)
	var cost: int = swarm_type.spawn_cost
	if cost <= 0:
		push_error("%s has spawn_cost %d; SpawnDirector can't spend on it." % [swarm_type.id, cost])
		return
	while _bank >= cost and swarm.get_alive_count() < alive_cap():
		var at: Variant = _pick_spawn_point()
		if at == null:
			break  # No usable point this tick; the bank waits for the next one.
		var slot: int = swarm.spawn(swarm_type, at, hp_multiplier(), damage_multiplier())
		_bank -= cost
		spawned.emit(slot, at)


## Spawns count enemies of type around one walkable point pack_distance from
## the target, preferring one off-camera, at this wave's multipliers. It
## spends nothing from the bank and ignores pause and the alive cap.
func spawn_pack(type: SwarmType, count: int) -> Array[int]:
	var slots: Array[int] = []
	var center: Variant = _pick_point(tuning.pack_distance, tuning.pack_distance)
	if center == null:
		push_warning("No walkable point %.0f m out for a %s pack." % [tuning.pack_distance, type.id])
		return slots
	for k in count:
		var at: Vector3 = center
		for attempt in tuning.spawn_attempts:
			var offset: Vector2 = Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * tuning.pack_spread * 0.5
			var p: Vector3 = center + Vector3(offset.x, 0.0, offset.y)
			if not ground.is_blocked_at(p.x, p.z):
				at = Vector3(p.x, ground.get_surface_height_at(p.x, p.z), p.z)
				break
		var slot: int = swarm.spawn(type, at, hp_multiplier(), damage_multiplier())
		if slot >= 0:
			slots.append(slot)
	pack_spawned.emit(type.id, slots)
	return slots


## True while a wave is running (not paused, frozen or in a lull).
func is_in_wave() -> bool:
	return not paused and not frozen and not lull and ground.is_ground_data_ready()


## A station's waves from the start: wave 0, no Returns yet, out of any lull.
func begin_station(index: int) -> void:
	station_index = index
	returns_this_station = 0
	lull = false
	_done = false
	_wave = 0
	_wave_time = 0.0
	_station_time = 0.0
	_bank = 0.0
	wave_changed.emit(0)


## B = B0 × (1 + wave_slope × w) × P_s × return_pressure^returns (spec §8.4).
func budget_per_second() -> float:
	var w: int = tuning.waves - 1 if lull and not endless else _wave
	var rate: float = tuning.base_budget * (1.0 + tuning.wave_slope * w) \
			* tuning.station_pressure[station_index] * pow(tuning.return_pressure, returns_this_station)
	if lull:
		rate *= tuning.lull_budget_fraction
	rate *= budget_scale
	return rate * tuning.stress_budget_scale if stress else rate


func alive_cap() -> int:
	return tuning.stress_alive_cap if stress else tuning.alive_cap


## (1 + hp_slope × w) × S_s (spec §8.2).
func hp_multiplier() -> float:
	return (1.0 + tuning.hp_slope * _wave) * tuning.station_hp_mults[station_index]


## (1 + dmg_slope × w) × D_s (spec §8.2).
func damage_multiplier() -> float:
	return (1.0 + tuning.dmg_slope * _wave) * tuning.station_dmg_mults[station_index]


## A walkable point on the ring around the target, preferring ones the camera
## can't see. Returns null when every try lands on a blocked cell.
func _pick_spawn_point() -> Variant:
	return _pick_point(tuning.ring_min, tuning.ring_max)


## A walkable point min_dist to max_dist from the target, as above.
func _pick_point(min_dist: float, max_dist: float) -> Variant:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var center: Vector3 = target.global_position
	var visible_fallback: Variant = null
	for attempt in tuning.spawn_attempts:
		var angle: float = _rng.randf() * TAU
		# Uniform over the ring's area, not bunched at its inner edge.
		var dist: float = sqrt(_rng.randf_range(min_dist * min_dist, max_dist * max_dist))
		var at: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * dist
		if ground.is_blocked_at(at.x, at.z) or (area.has_area() and not area.has_point(Vector2(at.x, at.z))):
			continue
		at.y = ground.get_surface_height_at(at.x, at.z)
		if camera == null or not camera.is_position_in_frustum(at):
			return at
		if visible_fallback == null:
			visible_fallback = at
	return visible_fallback
