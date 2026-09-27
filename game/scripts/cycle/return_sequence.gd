class_name ReturnSequence
extends CanvasLayer
## The Return (spec §6.6, Art Direction: death is a beat): when Taln's Health
## reaches 0 the world freezes (swarm, motes, spawner, the Well, Agony,
## Investiture income, Fracture), he breaks into ash, the screen drains to
## black, and he reassembles with one breath. It lasts `duration` real
## seconds; once the Return has been seen in full (MetaState return_seen),
## any press skips it after `skip_after`.
##
## On reform: full Health; a shockwave kills swarm-tier enemies (mass up to
## shockwave_max_mass) within shockwave_radius, unrewarded, and knocks
## heavier ones back with shockwave_force; +return_agony Agony (a fill opens
## the Welcome prompt once control is back); Braize takes braize_share of
## held Investiture; the station's Return pressure rises. Taln reforms where
## he fell unless that cell is closed or off the ground, then at the nearest
## open cell. The ninth Return has no reform: the cycle closes.
##
## Placeholder visuals: the body sinks and dims to ash-dark, a black overlay
## fades in and out. Timings are fractions of `duration` in tuning. The world
## stops at once rather than slowing first (for confirmation at the gate).
## Taln can't move or act meanwhile: his skills stop and his inputs are shut;
## he reforms with a fresh Fracture timer.

signal began(closing: bool)
signal reformed(at: Vector3)

@export var tuning: ReturnTuning
@export var taln: Taln
@export var swarm: SwarmServer
@export var motes: MoteServer
@export var spawner: SpawnDirector
@export var well: Well
@export var catalysis: Catalysis
@export var menu: LevelUpMenu
@export var ground: StationGround
## Placeholder look: how far the body sinks into ash (share of its height) and
## the least of it left.
@export_range(0.0, 1.0, 0.01) var ash_sink: float = 0.8
@export_range(0.0, 1.0, 0.01) var ash_floor: float = 0.05

var active: bool = false
var closing: bool = false
## Real seconds into the sequence.
var elapsed: float = 0.0
var _fade: ColorRect
var _body: MeshInstance3D
var _body_scale: Vector3
var _loadout_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body = taln.get_node(^"Body")
	_body_scale = _body.scale
	taln.health.depleted.connect(start)


## Begins the Return (Health reached 0). Ignored while one is running.
func start() -> void:
	if active:
		return
	active = true
	elapsed = 0.0
	var cycle: Cycle = Cycle.director()
	cycle.add_return()
	closing = cycle.is_closing_return()
	# A fill being decided banks: accepting is never a trap, and neither is dying.
	catalysis.force_bank()
	catalysis.hold(&"return", true)
	menu.blocked = true
	taln.health.set_invulnerable(&"return", true)
	taln.frozen = true
	taln.control_locked = true
	# His skills stop too: no auto-swings, Echoes or casts.
	_loadout_mode = taln.loadout.process_mode
	taln.loadout.process_mode = Node.PROCESS_MODE_DISABLED
	_freeze(true)
	began.emit(closing)


func can_skip() -> bool:
	return active and not closing and Meta.state().return_seen and elapsed >= tuning.skip_after


func _unhandled_input(event: InputEvent) -> void:
	if can_skip() and event.is_pressed() and not event.is_echo() \
			and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
			or event is InputEventAction):
		get_viewport().set_input_as_handled()
		reform()


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	var t: float = elapsed / tuning.duration
	# Ash: the body sinks and darkens; black drains in; he reassembles as it lifts.
	var ash: float = clampf(t / tuning.ash_end, 0.0, 1.0)
	var black_in: float = clampf((t - tuning.ash_end * 0.5) / (tuning.black_start - tuning.ash_end * 0.5), 0.0, 1.0)
	var black_out: float = clampf((t - tuning.black_hold_end) / (tuning.reassembled - tuning.black_hold_end), 0.0, 1.0)
	_fade.color.a = black_in * (1.0 - black_out) if not closing else black_in
	var gone: float = ash * (1.0 - black_out)
	_body.scale = _body_scale * Vector3(1.0, maxf(1.0 - ash_sink * gone, ash_floor), 1.0)
	_body.transparency = gone
	if closing:
		if t >= tuning.black_start:
			active = false
			Cycle.director().end_cycle(Cycle.Outcome.CLOSED)
		return
	if elapsed >= tuning.duration:
		reform()


## Reforms Taln now (the sequence's end, or a skip).
func reform() -> void:
	if not active or closing:
		return
	active = false
	Meta.state().mark_return_seen()
	_fade.color.a = 0.0
	_body.scale = _body_scale
	_body.transparency = 0.0
	var at: Vector3 = _reform_point(taln.global_position)
	taln.global_position = at
	taln.velocity = Vector3.ZERO
	taln.reset_physics_interpolation()
	taln.health.refill()
	taln.fracture.reset()
	_freeze(false)
	swarm.kill_in_radius(at, tuning.shockwave_radius, tuning.shockwave_max_mass)
	swarm.apply_impulse_in_radius(at, tuning.shockwave_radius, tuning.shockwave_force)
	taln.investiture.spend(taln.investiture.current * tuning.braize_share, &"braize")
	spawner.returns_this_station += 1
	taln.loadout.process_mode = _loadout_mode
	# After this frame's physics: the press that skipped (Shoulder, say) mustn't
	# also act as a fresh press.
	taln.set_deferred(&"frozen", false)
	taln.set_deferred(&"control_locked", false)
	taln.health.set_invulnerable(&"return", false)
	menu.blocked = false
	taln.agony.add(tuning.return_agony, &"return")
	# Control is back: a fill waiting on the Return opens its prompt now.
	catalysis.hold(&"return", false)
	reformed.emit(at)


func _freeze(on: bool) -> void:
	swarm.set_frozen(on)
	motes.set_frozen(on)
	spawner.frozen = on
	well.frozen = on
	taln.investiture.frozen = on
	taln.agony.set_suspended(&"return", on)


## Where he fell if that cell is open ground, else the nearest open cell
## center (searching rings out from the nearest on-ground cell, one ring past
## the first hit, since a corner of ring r can be farther than ring r + 1).
func _reform_point(at: Vector3) -> Vector3:
	if not ground.is_blocked_at(at.x, at.z):
		return at
	var origin: Vector2 = ground.get_origin()
	var cell: float = ground.get_cell_size()
	var cx: int = clampi(floori((at.x - origin.x) / cell), 0, ground.get_width() - 1)
	var cz: int = clampi(floori((at.z - origin.y) / cell), 0, ground.get_depth() - 1)
	var best: Variant = null
	var best_dist: float = INF
	var last_ring: int = maxi(ground.get_width(), ground.get_depth())
	for r in range(0, maxi(ground.get_width(), ground.get_depth())):
		if r > last_ring:
			break
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x: float = origin.x + (cx + dx + 0.5) * cell
				var z: float = origin.y + (cz + dz + 0.5) * cell
				if ground.is_blocked_at(x, z):
					continue
				var d: float = Vector2(x - at.x, z - at.z).length()
				if d < best_dist:
					best_dist = d
					best = Vector3(x, ground.get_surface_height_at(x, z), z)
		if best != null and last_ring > r + 1:
			last_ring = r + 1
	return best if best != null else at
