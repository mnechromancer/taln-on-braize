class_name KiteBot
extends Node
## A scripted player for headless economy runs (P2-05). It plays through the
## real input actions, the way a person would:
## - kites in a circle around the swarm's centroid, steering off closed ground;
## - invests whenever it can afford a level, taking the first offer;
## - casts Settle whenever it's ready and something is in range, turning the
##   camera toward the nearest enemy first (Surges aim camera-forward);
## - Draws whenever Draw is off cooldown while Strain < draw_strain_limit;
## - stands Anchored in a pool when no enemy is within safe_radius;
## - at a Welcome the Agony prompt, Welcomes every welcome_every-th prompt
##   (Banks the rest) and then holds A on the first (cheapest) catalyst.
## These are bot habits, not gameplay numbers, so they live here as exports.
## Add it as a child of a station, with the station's nodes set.

@export var taln: Taln
@export var swarm: SwarmServer
@export var ground: StationGround
@export var camera_rig: CameraRig
@export var menu: LevelUpMenu
@export var well: Well
## Optional: without it the bot leaves every prompt to time out (a bank).
@export var catalysis: Catalysis

## Keep this far from the swarm's centroid while kiting.
@export var kite_radius: float = 11.0
## How hard to correct back toward kite_radius (per meter of error).
@export var radial_gain: float = 0.25
## Enemies this close push the kite path away from them.
@export var repel_radius: float = 3.0
@export var repel_gain: float = 1.5
## No enemy this close: go stand in a pool.
@export var safe_radius: float = 6.0
## Draw only while Strain is below this.
@export var draw_strain_limit: float = 3.0
## How far ahead to look for closed ground.
@export var lookahead: float = 1.5
## Kite clockwise (1) or counter-clockwise (-1).
@export var kite_sense: float = 1.0
## Variant, off by default (the handoff's bot casts whenever Settle is
## ready): cast only if the next level stays affordable after paying for it.
@export var level_first: bool = false
## Welcome every Nth prompt, Bank the others (0: always Bank).
@export var welcome_every: int = 2

## What the bot did, for the report.
var invests: int = 0
var casts: int = 0
var draws: int = 0
var pool_seconds: float = 0.0
var prompts: int = 0

var _pressed: Array[StringName] = []
var _answered: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -10  # Inputs land before Taln reads them.


## Lets go of everything, so nothing stays held after the bot is gone.
func _exit_tree() -> void:
	_release_taps()
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"catalyze_commit"]:
		Input.action_release(action)


func _process(_delta: float) -> void:
	# The windows slow physics down, so answer them every frame.
	if catalysis == null or not catalysis.is_open():
		Input.action_release(&"catalyze_commit")
		_answered = false
		return
	_release_taps()
	_steer(Vector3.ZERO)
	if catalysis.state == Catalysis.State.PROMPT:
		if not _answered:
			_answered = true
			prompts += 1
			_tap(&"welcome" if welcome_every > 0 and prompts % welcome_every == 0 else &"bank")
	else:
		Input.action_press(&"catalyze_commit")


func _physics_process(delta: float) -> void:
	if catalysis and catalysis.is_open():
		return
	_release_taps()
	if menu.is_open:
		# Take the first offer as soon as the menu accepts picks.
		_tap(&"pick_1")
		return
	if get_tree().paused:
		return
	if taln.leveling.can_invest():
		_tap(&"invest")
		invests += 1
		_steer(Vector3.ZERO)
		return
	var nearest: Vector3 = swarm.find_nearest(taln.global_position, 1000.0)
	var nearest_dist: float = _flat(nearest - taln.global_position).length() if nearest != Vector3.INF else INF
	_try_settle(nearest, nearest_dist)
	if taln.toauma.draw_cooldown_left <= 0.0 and taln.toauma.strain < draw_strain_limit:
		_tap(&"draw")
		draws += 1
	var pool: WellPool = _nearest_pool()
	if nearest_dist > safe_radius and pool:
		var to_pool: Vector3 = pool.global_position - taln.global_position
		to_pool.y = 0.0
		if pool.is_taln_inside and to_pool.length() < pool.tuning.pool_radius * 0.5:
			_steer(Vector3.ZERO)  # Stand still: Anchored after the delay.
			pool_seconds += delta
		else:
			_steer(_avoid(to_pool.normalized()))
		return
	_steer(_avoid(_kite_direction()))


func _try_settle(nearest: Vector3, nearest_dist: float) -> void:
	var surge: SurgeBehavior = taln.loadout.get_surge_behavior(0)
	if surge == null or not surge.is_ready() or nearest_dist > surge.params().range:
		return
	if level_first and taln.investiture.current - surge.skill.investiture_cost < taln.leveling.next_cost():
		return
	# Face the camera at the target so camera-forward aim (and its soft-lock) finds it.
	var to: Vector3 = nearest - taln.global_position
	camera_rig.rotation.y = atan2(-to.x, -to.z)
	_tap(&"surge_1")
	casts += 1


func _kite_direction() -> Vector3:
	var centroid: Vector3 = swarm.get_alive_centroid()
	var p: Vector3 = taln.global_position
	if centroid == Vector3.INF:
		return Vector3.ZERO
	var out := Vector3(p.x - centroid.x, 0.0, p.z - centroid.z)
	var r: float = out.length()
	var radial: Vector3 = out / r if r > 0.01 else Vector3.RIGHT
	var tangent := Vector3(-radial.z, 0.0, radial.x) * kite_sense
	var dir: Vector3 = tangent + radial * clampf((kite_radius - r) * radial_gain, -1.0, 1.0)
	var close: Vector3 = swarm.find_nearest(p, repel_radius)
	if close != Vector3.INF:
		var away := Vector3(p.x - close.x, 0.0, p.z - close.z)
		if away.length() > 0.01:
			dir += away.normalized() * repel_gain
	return dir.normalized()


## Turns dir away from closed ground or the arena's edge, trying wider angles
## either side until the way ahead is open.
func _avoid(dir: Vector3) -> Vector3:
	if dir.is_zero_approx():
		return dir
	var p: Vector3 = taln.global_position
	for k in 12:
		for sign: float in [1.0, -1.0]:
			var turned: Vector3 = dir.rotated(Vector3.UP, sign * deg_to_rad(15.0 * k))
			var ahead: Vector3 = p + turned * lookahead
			if not ground.is_blocked_at(ahead.x, ahead.z):
				return turned
			if k == 0:
				break
	return dir


func _nearest_pool() -> WellPool:
	var best: WellPool = null
	var best_dist: float = INF
	for pool in well.pools():
		if not pool.is_active:
			continue
		var d: float = _flat(pool.global_position - taln.global_position).length()
		if d < best_dist:
			best = pool
			best_dist = d
	return best


## Presses the move actions so Taln's camera-relative input comes out as the
## world direction dir (zero releases them).
func _steer(dir: Vector3) -> void:
	var local := Vector3.ZERO
	if not dir.is_zero_approx():
		var camera: Camera3D = get_viewport().get_camera_3d()
		var yaw: float = 0.0
		if camera:
			var forward: Vector3 = -camera.global_basis.z
			yaw = atan2(-forward.x, -forward.z)
		local = Basis(Vector3.UP, yaw).inverse() * dir
	_set_axis(&"move_right", &"move_left", local.x)
	_set_axis(&"move_back", &"move_forward", local.z)


func _set_axis(positive: StringName, negative: StringName, value: float) -> void:
	if value > 0.0:
		Input.action_press(positive, value)
		Input.action_release(negative)
	elif value < 0.0:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


## A press this tick and a release next tick, through the input event queue.
func _tap(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	_pressed.append(action)


func _release_taps() -> void:
	for action in _pressed:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = false
		Input.parse_input_event(event)
	_pressed.clear()


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
