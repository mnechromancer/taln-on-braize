class_name Anchored
extends Node
## Anchored stance (spec §6.3). Entered after anchor_delay with no movement
## input, timed from when input stopped rather than from when Taln stopped
## moving. Any movement input or a Shoulder charge exits it. Taln applies the
## effects (armor bonus, knockback immunity, the disc) on anchored_changed.

signal anchored_changed(anchored: bool)

@export var tuning: TalnTuning

var is_anchored: bool = false

var _idle_time: float = 0.0


## Called by Taln every physics frame; active is true while there is movement
## input or a charge.
func update(active: bool, delta: float) -> void:
	if active:
		_idle_time = 0.0
		_set_anchored(false)
		return
	_idle_time += delta
	if _idle_time >= tuning.anchor_delay - 0.0001:
		_set_anchored(true)


func _set_anchored(value: bool) -> void:
	if value == is_anchored:
		return
	is_anchored = value
	anchored_changed.emit(value)
