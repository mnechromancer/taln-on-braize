class_name Shoulder
extends Node
## Shoulder, Taln's heavy charge in place of a jump (spec §6.5). This node
## owns the charge state and cooldown; Taln moves the body and reports back.
## The cooldown runs from the start of the charge.
##
## Upgrade surface: the charge stops dead when it ends (Taln's horizontal
## velocity is zeroed). Momentum carry, steering and the like are meant to
## arrive as upgrades that shape a movement playstyle, not as base behavior.

signal shouldered(origin: Vector3, direction: Vector3)
## The charge ran into a wall.
signal blocked(position: Vector3, normal: Vector3)
## The charge is over, however it ended.
signal ended

@export var tuning: TalnTuning

var is_charging: bool = false
## Ground-plane unit direction of the current charge.
var direction: Vector3 = Vector3.ZERO
var cooldown_left: float:
	get:
		return _cooldown_left
## Distance the current charge has left to cover.
var remaining: float:
	get:
		return _remaining

var _remaining: float = 0.0
var _cooldown_left: float = 0.0


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func is_ready() -> bool:
	return not is_charging and _cooldown_left <= 0.0


## Starts a charge along dir (flattened to the ground plane) if off cooldown.
func try_start(origin: Vector3, dir: Vector3) -> bool:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if not is_ready() or flat.is_zero_approx():
		return false
	direction = flat.normalized()
	is_charging = true
	_remaining = tuning.shoulder_distance
	_cooldown_left = tuning.shoulder_cooldown
	shouldered.emit(origin, direction)
	return true


## Distance to cover this physics frame.
func step_distance(delta: float) -> float:
	return minf(tuning.shoulder_distance / tuning.shoulder_duration * delta, _remaining)


## Taln covered distance this frame; ends the charge once the full distance is done.
func record_move(distance: float) -> void:
	_remaining -= distance
	if _remaining <= 0.0001:
		stop()


## Shortens the charge so it covers at most distance more.
func limit_remaining(distance: float) -> void:
	_remaining = minf(_remaining, distance)


func hit_wall(position: Vector3, normal: Vector3) -> void:
	blocked.emit(position, normal)
	stop()


func stop() -> void:
	if not is_charging:
		return
	is_charging = false
	ended.emit()
