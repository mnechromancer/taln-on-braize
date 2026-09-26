class_name Fracture
extends Node3D
## Fracture: Braize punishes stillness (spec §6.4). Tracks where Taln stands,
## not input. When he stops, his position becomes the anchor point; the timer
## builds while he stays within fracture_radius of it, so shuffling in place
## doesn't reset it. Warning after fracture_warning_time; from
## fracture_active_time, Kinetic damage pulses every fracture_pulse_interval at
## fracture_base_rate of max Health, rising by fracture_rate_ramp per pulse.
## Beyond the radius the timer holds and nothing happens; fracture_reset_time
## away clears it.

enum State { NONE, WARNING, ACTIVE }

signal fracture_state_changed(state: State)

const WARNING_COLOR := Color("0b0b0e", 0.75)
const ACTIVE_COLOR := Color("c2185b", 0.6)

@export var tuning: TalnTuning
@export var health: Health

var state: State = State.NONE
## Seconds built up at the current anchor point.
var still_time: float:
	get:
		return _still_time
## Seconds spent continuously beyond the radius.
var away_time: float:
	get:
		return _away_time

var _has_anchor: bool = false
var _anchor: Vector3 = Vector3.ZERO
var _still_time: float = 0.0
var _away_time: float = 0.0
var _pulses: int = 0

@onready var _zone: MeshInstance3D = $Zone
@onready var _zone_material: StandardMaterial3D = _zone.get_active_material(0)


func _ready() -> void:
	_zone.top_level = true
	_zone.scale = Vector3(tuning.fracture_radius, 1.0, tuning.fracture_radius)
	_zone.visible = false


## Called by Taln every physics frame.
func update(taln_position: Vector3, horizontal_speed: float, delta: float) -> void:
	if not _has_anchor:
		if horizontal_speed < tuning.stop_speed:
			_has_anchor = true
			_anchor = taln_position
			_zone.global_position = taln_position + Vector3.UP * 0.015
		return

	if Vector2(taln_position.x - _anchor.x, taln_position.z - _anchor.z).length() > tuning.fracture_radius:
		_away_time += delta
		if _away_time >= tuning.fracture_reset_time - 0.0001:
			_has_anchor = false
			_still_time = 0.0
			_away_time = 0.0
			_pulses = 0
		_set_state(State.NONE)
		return

	_away_time = 0.0
	_still_time += delta
	if _still_time >= tuning.fracture_active_time - 0.0001:
		_set_state(State.ACTIVE)
		while _still_time >= tuning.fracture_active_time + _pulses * tuning.fracture_pulse_interval - 0.0001:
			var rate: float = tuning.fracture_base_rate + tuning.fracture_rate_ramp * _pulses
			health.damage(tuning.max_health * rate, Damage.Type.KINETIC)
			_pulses += 1
	elif _still_time >= tuning.fracture_warning_time - 0.0001:
		_set_state(State.WARNING)
	else:
		_set_state(State.NONE)


func _set_state(value: State) -> void:
	if value == state:
		return
	state = value
	_zone.visible = state != State.NONE
	_zone_material.albedo_color = ACTIVE_COLOR if state == State.ACTIVE else WARNING_COLOR
	fracture_state_changed.emit(state)
