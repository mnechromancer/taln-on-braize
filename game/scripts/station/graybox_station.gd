class_name GrayboxStation
extends Node3D
## P2-01 gray-box station. It has no directional light by design; F4 toggles
## a temporary one (off by default) for inspecting geometry. Also wires Taln's
## Shoulder wall hits to camera shake, the swarm (SwarmServer) to Taln and the
## ground, and the Investiture loop (P2-05): the station value, and motes from
## rewarded kills paying Taln on pickup.
##
## It also runs the Phase 2 stand-in cycle (P2-07, ruled): on load it begins a
## cycle with the CycleDirector; each station is nine waves, then a lull, then
## the next station (up to the cycle's three); after the last station's ninth
## wave the cycle ends Held.
##
## Debug keys: Ctrl+1 hits every enemy near Taln hard, Ctrl+2 toggles spawner
## stress mode, Ctrl+3 pauses the spawner, Ctrl+4 grants Investiture, Ctrl+5
## toggles the Honorblade, Ctrl+6 adds Strain, Ctrl+7 resets Strain, Ctrl+8
## grants 9 banked Agony and Ctrl+9 held for a second wipes MetaState (both
## handled by the between-run screen, so they work there too), Ctrl+0 ends
## the cycle Held.

## Ctrl+1: radius and damage of the debug blast around Taln.
const DEBUG_BLAST_RADIUS := 6.0
const DEBUG_BLAST_DAMAGE := 50.0


## Print a line for every enemy_died.
@export var verbose_kill_log := false

## Rewarded kills since the station loaded (deaths that aren't kills, like a
## Notice hunter's time running out, don't count).
var kills: int = 0
## Base Investiture in motes that sank before Taln reached them.
var motes_lost: float = 0.0
## Seconds left in the lull between stations; 0 outside one.
var lull_left: float = 0.0

@onready var _inspect_light: DirectionalLight3D = $InspectLight
@onready var _taln: Taln = $Taln
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _ground: StationGround = $StationGround
@onready var _swarm: SwarmServer = $SwarmServer
@onready var _spawner: SpawnDirector = $SpawnDirector
@onready var _context: StationContext = $StationContext
@onready var _motes: MoteServer = $MoteServer
@onready var _catalysis: Catalysis = $Catalysis
@onready var _well: Well = $Well


func _ready() -> void:
	var world: WorldEnvironment = $WorldEnvironment
	world.environment = world.environment.duplicate()
	_taln.shoulder.blocked.connect(_on_shoulder_blocked)

	_swarm.target_move_speed = _taln.tuning.move_speed
	_swarm.target_radius = _taln.tuning.capsule_radius
	_swarm.set_target(_taln)
	_taln.loadout.swarm = _swarm
	_swarm.set_mote_server(_motes)
	_motes.set_target(_taln)
	_motes.mote_collected.connect(_on_mote_collected)
	_motes.mote_lost.connect(func(value: float, _tag: int) -> void: motes_lost += value)
	_taln.investiture.station = _context
	_taln.agony.swarm = _swarm
	(_taln.get_node("AgonyBody") as AgonyBody).watch(_catalysis)
	_spawner.station_index = _context.station_index
	_context.station_changed.connect(func(index: int) -> void: _spawner.station_index = index)
	_ground.ground_changed.connect(_on_ground_changed)
	_swarm.taln_contacted.connect(_on_taln_contacted)
	_swarm.enemy_died.connect(_on_enemy_died)
	_taln.toauma.notice.connect(_on_notice)
	_spawner.waves_done.connect(_on_waves_done)
	Cycle.director().begin_cycle(self)


func station_index() -> int:
	return _context.station_index


## Everything in-run back to a cycle's start, and every random stream seeded
## from the cycle's seed (spec §11.5). Called by the CycleDirector on a
## freshly loaded station (it doesn't unwind a running Return or cooldowns).
func reset_for_cycle() -> void:
	var cycle: Cycle = Cycle.director()
	_spawner._rng.seed = cycle.seed_for("spawner")
	_swarm.set_seed(cycle.seed_for("swarm"))
	_motes.set_seed(cycle.seed_for("motes"))
	_well.rng.seed = cycle.seed_for("well")
	_taln.toauma.rng.seed = cycle.seed_for("toauma")
	_taln.leveling.rng.seed = cycle.seed_for("leveling")
	_catalysis.force_bank()
	_catalysis.history.clear()
	_swarm.clear_all()
	_motes.clear_all()
	_taln.investiture.reset()
	_taln.leveling.reset()
	_taln.loadout.reset_levels()
	_taln.toauma.reset_strain()
	_taln.agony.reset()
	_taln.fracture.reset()
	_taln.health.refill()
	_context.station_index = 0
	_spawner.begin_station(0)
	kills = 0
	motes_lost = 0.0
	lull_left = 0.0


func _on_waves_done() -> void:
	var cycle: Cycle = Cycle.director()
	if _context.station_index + 1 >= cycle.tuning.stations:
		cycle.end_cycle(Cycle.Outcome.HELD)
		return
	_spawner.lull = true
	lull_left = cycle.tuning.lull_seconds
	cycle.lull_began.emit(_context.station_index)


func _next_station() -> void:
	_context.station_index += 1
	_spawner.begin_station(_context.station_index)
	Cycle.director().station_began.emit(_context.station_index)


func _physics_process(delta: float) -> void:
	if lull_left > 0.0 and not _spawner.frozen and not _spawner.paused:
		lull_left -= delta
		if lull_left <= 0.0:
			lull_left = 0.0
			_next_station()
	if _taln.shoulder.is_charging:
		_swarm.apply_impulse_in_radius(_taln.global_position,
				_taln.tuning.shoulder_knockback_radius, _taln.tuning.shoulder_knockback_force)


func _on_ground_changed(_cells: Rect2i) -> void:
	_swarm.set_ground(_ground.get_height_array(), _ground.get_blocked_mask(), _ground.get_width(),
			_ground.get_depth(), _ground.get_cell_size(), _ground.get_origin())


func _on_taln_contacted(damage: float, type: int) -> void:
	_taln.health.damage(damage, type as Damage.Type)


func _on_enemy_died(type_id: StringName, at: Vector3, rewarded: bool) -> void:
	if not rewarded:
		return
	kills += 1
	if verbose_kill_log:
		print("enemy_died %s at (%.1f, %.1f, %.1f)  [kill %d]" % [type_id, at.x, at.y, at.z, kills])


## Swarm-tier motes are kill income, elite motes elite income (spec §2.3).
func _on_mote_collected(value: float, tier: int) -> void:
	_taln.investiture.add(value, &"elite" if tier == SwarmType.TIER_ELITE else &"kill")


func _on_notice(threshold: float, hunters: int, lifetime: float) -> void:
	var slots: Array[int] = _spawner.spawn_pack(_taln.toauma.tuning.notice_hunter_type, hunters)
	if lifetime > 0.0:
		for slot in slots:
			_swarm.set_enemy_lifetime(slot, lifetime)
	print("Notice at Strain %.0f: %d hunters, %s" % [threshold, slots.size(),
			"%.0f s to live" % lifetime if lifetime > 0.0 else "until killed"])


func _on_shoulder_blocked(_position: Vector3, _normal: Vector3) -> void:
	_camera_rig.add_trauma(_camera_rig.tuning.shoulder_wall_trauma)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_inspect_light"):
		_inspect_light.visible = not _inspect_light.visible
	elif event.is_action_pressed("debug_blast"):
		var hit: int = _swarm.apply_damage_in_radius(_taln.global_position, DEBUG_BLAST_RADIUS,
				DEBUG_BLAST_DAMAGE, Damage.Type.KINETIC)
		print("Debug blast hit %d enemies" % hit)
	elif event.is_action_pressed("debug_stress"):
		_spawner.stress = not _spawner.stress
		print("Spawner stress mode ", "on" if _spawner.stress else "off")
	elif event.is_action_pressed("debug_pause_spawner"):
		_spawner.paused = not _spawner.paused
		print("Spawner ", "paused" if _spawner.paused else "running")
	elif event.is_action_pressed("debug_grant_investiture"):
		_taln.investiture.add(_taln.investiture.tuning.debug_grant_amount, &"debug")
		print("Investiture now %.0f" % _taln.investiture.current)
	elif event.is_action_pressed("debug_honorblade"):
		_taln.loadout.honorblade_held = not _taln.loadout.honorblade_held
		print("Honorblade ", "held" if _taln.loadout.honorblade_held else "not held")
	elif event.is_action_pressed("debug_add_strain"):
		_taln.toauma.add_strain(_taln.toauma.tuning.debug_strain_step)
		print("Strain now %.2f" % _taln.toauma.strain)
	elif event.is_action_pressed("debug_reset_strain"):
		_taln.toauma.reset_strain()
		print("Strain reset")
	elif event.is_action_pressed("debug_end_cycle"):
		Cycle.director().end_cycle(Cycle.Outcome.HELD)
