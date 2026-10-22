class_name Fade
extends SurgeBehavior
## Fade, a Plaguebringer Surge (Ashynite; P2-15): Taln slips out of every
## eye for its duration (Awareness loses him at once) and moves faster
## meanwhile, to get clear of the buffed crowd while the disease works.
## Blade-eligible: through the Honorblade it's silent; through Toa'uma the
## cast itself is heard first. Overcharge lengthens it.
##
## level_params keys: duration (s), speed_mult.

const SPEED_SOURCE := &"fade"

signal faded(seconds: float)

var fade_left: float = 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if fade_left > 0.0:
		fade_left -= delta
		if fade_left <= 0.0:
			fade_left = 0.0
			taln.clear_speed_multiplier(SPEED_SOURCE)


func _exit_tree() -> void:
	taln.clear_speed_multiplier(SPEED_SOURCE)


func _fire(_origin: Vector3, _direction: Vector3, _through_toa_uma: bool, magnitude: float) -> int:
	var p: Dictionary = params()
	var seconds: float = p.duration * magnitude
	var awareness: Awareness = taln.loadout.awareness
	if awareness:
		awareness.hide(seconds)
	taln.set_speed_multiplier(SPEED_SOURCE, p.speed_mult)
	fade_left = maxf(fade_left, seconds)
	faded.emit(seconds)
	return 0
