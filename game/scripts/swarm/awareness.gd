class_name Awareness
extends Node
## Awareness (spec v1.4 #6, P2-13): the swarm stops being omniscient. Every
## physics frame it decides whether Taln is seen: by any enemy within
## close_sight, or by a spotter (a commander, a Notice hunter) within its
## sight range with a clear line over the ground, both scaled by the
## Aspect's detection_mult. Seen, the swarm hunts his position. Unseen, it
## keeps hunting the last known position for memory_seconds (Searching),
## then loses him and wanders (Unseen). Noise (Voidlight use, hard landings)
## heard by any enemy in its radius sends the swarm there. hide() makes him
## unseen for a while (Fade). Off (enabled = false) the swarm hunts Taln
## every tick, as before P2-13.

enum State { UNSEEN, SEEN, SEARCHING }

signal state_changed(state: State)
## A noise reached the swarm (something was in its radius).
signal heard(at: Vector3, radius: float)

@export var tuning: AwarenessTuning
@export var taln: Taln
@export var swarm: SwarmServer

var state: State = State.SEEN
## Seconds of the cycle seen and unseen (Searching counts as unseen).
var seen_time: float = 0.0
var unseen_time: float = 0.0
## Seconds Taln stays hidden from sight (Fade); 0 means not hidden.
var hidden_left: float = 0.0
var enabled: bool = true:
	set(value):
		enabled = value
		swarm.set_use_awareness(value)
		if not value:
			_set_state(State.SEEN)

var _since_seen: float = 0.0
var _noise_left: float = 0.0


func _ready() -> void:
	swarm.set_use_awareness(enabled)
	swarm.set_known_position(taln.global_position)
	swarm.set_known(true)


func _physics_process(delta: float) -> void:
	if not enabled or swarm.is_frozen():
		return
	hidden_left = maxf(hidden_left - delta, 0.0)
	_noise_left = maxf(_noise_left - delta, 0.0)
	if is_seen():
		_since_seen = 0.0
		swarm.set_known_position(taln.global_position)
		swarm.set_known(true)
		_set_state(State.SEEN)
		seen_time += delta
		return
	unseen_time += delta
	_since_seen += delta
	if _since_seen < tuning.memory_seconds or _noise_left > 0.0:
		_set_state(State.SEARCHING)
	else:
		swarm.set_known(false)
		_set_state(State.UNSEEN)


## Whether anything sees Taln right now.
func is_seen() -> bool:
	if hidden_left > 0.0:
		return false
	var mult: float = taln.aspect.detection_mult if taln.aspect else 1.0
	var at: Vector3 = taln.global_position
	if mult > 0.0 and swarm.query_count_in_radius(at, tuning.close_sight * mult) > 0:
		return true
	return swarm.count_spotters_seeing(at, mult) > 0


## A noise at at: if any enemy is within radius, the swarm heads there.
func make_noise(at: Vector3, radius: float) -> void:
	if not enabled or radius <= 0.0 or swarm.query_count_in_radius(at, radius) == 0:
		return
	swarm.set_known_position(at)
	swarm.set_known(true)
	_noise_left = tuning.noise_memory
	if state == State.UNSEEN:
		_set_state(State.SEARCHING)
	heard.emit(at, radius)


## Hides Taln from every eye for seconds; the swarm loses him at once.
func hide(seconds: float) -> void:
	hidden_left = maxf(hidden_left, seconds)
	if state == State.SEEN:
		_since_seen = 0.0
		_set_state(State.SEARCHING)


## Back to a fresh cycle: seen, with no time counted.
func reset() -> void:
	seen_time = 0.0
	unseen_time = 0.0
	hidden_left = 0.0
	_since_seen = 0.0
	_noise_left = 0.0
	swarm.set_known_position(taln.global_position)
	swarm.set_known(true)
	_set_state(State.SEEN)


func _set_state(value: State) -> void:
	if value == state:
		return
	state = value
	state_changed.emit(state)
