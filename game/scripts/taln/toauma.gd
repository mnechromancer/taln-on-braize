class_name Toauma
extends Node
## Toa'uma, Taln's peakspren (spec §5). Tracks Strain (0 to strain_max, no
## decay within a cycle), runs the Draw, and rolls a side effect on every use
## routed through the gem. Effects that land on Taln (Burn, Lurch, Speaks) and
## the Draw's Overcharge apply here; a Surge applies its own Overcharge,
## Misfire and Echo from the effect use_for_surge() returns.

enum Effect { NONE, OVERCHARGE, BURN, MISFIRE, LURCH, ECHO, SPEAKS }

signal strain_changed(strain: float)
## Every routed use (Surge or Draw), with the side effect it rolled.
signal used(is_draw: bool, effect: Effect)
signal drawn(amount: float)
signal spoke(line: String)
## Strain reached a Notice threshold for the first time this cycle. The
## hunters live lifetime seconds unless killed (0: until killed).
signal notice(threshold: float, hunters: int, lifetime: float)

@export var tuning: ToaumaTuning

var strain: float = 0.0
var draw_cooldown_left: float = 0.0
## Side-effect rolls. Seed it for reproducible runs (spec §11.5).
var rng := RandomNumberGenerator.new()
## The most recent side effect that hit (NONE until one does), when it hit
## (Time.get_ticks_msec()), and whether it came from a Draw.
var last_effect: Effect = Effect.NONE
var last_effect_msec: int = 0
var last_effect_from_draw: bool = false
var _noticed: Dictionary[float, bool] = {}
var _lurch_left: float = 0.0

@onready var _taln: Taln = get_parent()


func _ready() -> void:
	rng.randomize()


func _physics_process(delta: float) -> void:
	draw_cooldown_left = maxf(draw_cooldown_left - delta, 0.0)
	if _lurch_left > 0.0:
		_lurch_left -= delta
		if _lurch_left <= 0.0:
			_taln.clear_speed_multiplier(&"lurch")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("draw") and not _taln.control_locked:
		draw()
		get_viewport().set_input_as_handled()


## Routes one Surge cast of this Investiture cost through the gem: rolls its
## side effect at the current Strain, adds the Surge's Strain and applies the
## effects that land on Taln. Returns the effect for the Surge to apply.
func use_for_surge(cost: float) -> Effect:
	var effect: Effect = roll_effect(false)
	_note(effect, false)
	used.emit(false, effect)
	add_strain(tuning.surge_strain_per_25 * cost / 25.0)
	_apply(effect)
	return effect


## Draws Investiture through the gem (spec §2.3). Returns false on cooldown.
func draw() -> bool:
	if draw_cooldown_left > 0.0:
		return false
	draw_cooldown_left = tuning.draw_cooldown
	var effect: Effect = roll_effect(true)
	_note(effect, true)
	used.emit(true, effect)
	add_strain(tuning.draw_strain)
	var amount: float = tuning.draw_investiture
	if effect == Effect.OVERCHARGE:
		amount *= tuning.overcharge_mult
	_taln.investiture.add(amount, &"draw")
	drawn.emit(amount)
	_apply(effect)
	return true


## p = min(p_max, p_base + p_per_strain × Strain) (spec §5.3).
func side_effect_chance() -> float:
	return minf(tuning.p_max, tuning.p_base + tuning.p_per_strain * strain)


## Rolls for a side effect and, on a hit, picks one by weight. A Draw can't
## Misfire or Echo (spec v1.2): those are rerolled, which is the same as
## leaving them out of the pick.
func roll_effect(is_draw: bool) -> Effect:
	if rng.randf() >= side_effect_chance():
		return Effect.NONE
	var weights: Dictionary[Effect, int] = effect_weights()
	if is_draw:
		weights.erase(Effect.MISFIRE)
		weights.erase(Effect.ECHO)
	var total: int = 0
	for weight: int in weights.values():
		total += weight
	if total <= 0:
		return Effect.NONE
	var pick: int = rng.randi_range(0, total - 1)
	for effect: Effect in weights:
		pick -= weights[effect]
		if pick < 0:
			return effect
	return Effect.NONE


## The side-effect table at the current Strain.
func effect_weights() -> Dictionary[Effect, int]:
	var high: int = tuning.high_strain_weight_mult if strain >= tuning.high_strain else 1
	return {
		Effect.OVERCHARGE: tuning.weight_overcharge,
		Effect.BURN: tuning.weight_burn * high,
		Effect.MISFIRE: tuning.weight_misfire * high,
		Effect.LURCH: tuning.weight_lurch,
		Effect.ECHO: tuning.weight_echo,
		Effect.SPEAKS: tuning.weight_speaks,
	}


## direction turned by a random angle within ±misfire_max_deg.
func misfire(direction: Vector3) -> Vector3:
	return direction.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-tuning.misfire_max_deg, tuning.misfire_max_deg)))


func add_strain(amount: float) -> void:
	strain = clampf(strain + amount, 0.0, tuning.strain_max)
	strain_changed.emit(strain)
	for i in mini(tuning.notice_thresholds.size(), tuning.notice_hunters.size()):
		var threshold: float = tuning.notice_thresholds[i]
		if strain >= threshold and not _noticed.has(threshold):
			_noticed[threshold] = true
			var lifetime: float = tuning.notice_lifetimes[i] if i < tuning.notice_lifetimes.size() else 0.0
			notice.emit(threshold, tuning.notice_hunters[i], lifetime)


## The lowest Notice threshold not yet reached this cycle, or INF if none is left.
func next_notice_threshold() -> float:
	var next: float = INF
	for threshold: float in tuning.notice_thresholds:
		if not _noticed.has(threshold):
			next = minf(next, threshold)
	return next


## Back to a fresh cycle: Strain 0 and every Notice armed again.
func reset_strain() -> void:
	strain = 0.0
	_noticed.clear()
	strain_changed.emit(strain)


func _note(effect: Effect, is_draw: bool) -> void:
	if effect != Effect.NONE:
		last_effect = effect
		last_effect_msec = Time.get_ticks_msec()
		last_effect_from_draw = is_draw


func _apply(effect: Effect) -> void:
	match effect:
		Effect.BURN:
			# Burn ignores invulnerability (P2-06 ruling): no window can cancel its cost.
			_taln.health.damage(_taln.tuning.max_health * tuning.burn_fraction, Damage.Type.VOID, true)
		Effect.LURCH:
			var swarm: SwarmServer = _taln.loadout.swarm
			if swarm:
				swarm.apply_slow_in_radius(_taln.global_position, tuning.lurch_radius, tuning.lurch_factor,
						tuning.lurch_duration)
			_taln.set_speed_multiplier(&"lurch", tuning.lurch_factor)
			_lurch_left = tuning.lurch_duration
		Effect.SPEAKS:
			var line: String = tuning.speaks_lines[rng.randi() % tuning.speaks_lines.size()] \
					if not tuning.speaks_lines.is_empty() else ""
			print(line)
			spoke.emit(line)
