class_name SpawnDirector
extends Node
## Spends a per-second spawn budget on swarm enemies around Taln (spec §8.2,
## §8.4). The budget accrues into a bank capped at bank_cap_seconds of spend
## and is spent at the type's cost while the SwarmServer is under the alive
## cap. Spawns land on a ring around the target, off blocked cells and, where
## possible, out of the camera's view.
##
## v0: one swarm type, station index fixed at 0, no Returns yet. The wave index
## advances every wave_length seconds and holds on the last wave; the spec's
## post-wave lull (§1.2) arrives with Special Rooms and breakers.

signal wave_changed(wave: int)
signal spawned(slot: int, position: Vector3)

@export var tuning: SpawnTuning
@export var swarm_type: SwarmType
@export var swarm: SwarmServer
@export var ground: StationGround
@export var target: Node3D

var station_index: int = 0
var returns_this_station: int = 0
## Spawning (and the wave clock) stop while paused.
var paused: bool = false
## Debug stress mode: stress alive cap and budget scale from tuning.
var stress: bool = false

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
var _bank: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if paused or not ground.is_ground_data_ready():
		return
	_wave_time += delta
	while _wave_time >= tuning.wave_length:
		_wave_time -= tuning.wave_length
		if _wave < tuning.waves - 1:
			_wave += 1
			wave_changed.emit(_wave)

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


## B = B0 × (1 + wave_slope × w) × P_s × return_pressure^returns (spec §8.4).
func budget_per_second() -> float:
	var rate: float = tuning.base_budget * (1.0 + tuning.wave_slope * _wave) \
			* tuning.station_pressure[station_index] * pow(tuning.return_pressure, returns_this_station)
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
	var camera: Camera3D = get_viewport().get_camera_3d()
	var center: Vector3 = target.global_position
	var visible_fallback: Variant = null
	for attempt in tuning.spawn_attempts:
		var angle: float = _rng.randf() * TAU
		# Uniform over the ring's area, not bunched at its inner edge.
		var dist: float = sqrt(_rng.randf_range(tuning.ring_min * tuning.ring_min, tuning.ring_max * tuning.ring_max))
		var at: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * dist
		if ground.is_blocked_at(at.x, at.z):
			continue
		at.y = ground.get_surface_height_at(at.x, at.z)
		if camera == null or not camera.is_position_in_frustum(at):
			return at
		if visible_fallback == null:
			visible_fallback = at
	return visible_fallback
