class_name GrayboxStation
extends Node3D
## P2-01 gray-box station. It has no directional light by design; F4 toggles
## a temporary one (off by default) for inspecting geometry. Also wires Taln's
## Shoulder wall hits to camera shake, and the swarm (SwarmServer v0) to Taln
## and the ground.
##
## Debug keys: Ctrl+1 hits every enemy near Taln hard, Ctrl+2 toggles spawner
## stress mode, Ctrl+3 pauses the spawner, Ctrl+4 grants Investiture, Ctrl+5
## toggles the Honorblade, Ctrl+6 adds Strain, Ctrl+7 resets Strain.

## Ctrl+1: radius and damage of the debug blast around Taln.
const DEBUG_BLAST_RADIUS := 6.0
const DEBUG_BLAST_DAMAGE := 50.0

## Print a line for every enemy_died.
@export var verbose_kill_log := false

## enemy_died count since the station loaded.
var kills: int = 0

@onready var _inspect_light: DirectionalLight3D = $InspectLight
@onready var _taln: Taln = $Taln
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _ground: StationGround = $StationGround
@onready var _swarm: SwarmServer = $SwarmServer
@onready var _spawner: SpawnDirector = $SpawnDirector


func _ready() -> void:
	_taln.shoulder.blocked.connect(_on_shoulder_blocked)

	_swarm.target_move_speed = _taln.tuning.move_speed
	_swarm.target_radius = _taln.tuning.capsule_radius
	_swarm.set_target(_taln)
	_taln.loadout.swarm = _swarm
	_ground.ground_changed.connect(_on_ground_changed)
	_swarm.taln_contacted.connect(_on_taln_contacted)
	_swarm.enemy_died.connect(_on_enemy_died)
	_taln.toauma.notice.connect(_on_notice)


func _physics_process(_delta: float) -> void:
	if _taln.shoulder.is_charging:
		_swarm.apply_impulse_in_radius(_taln.global_position,
				_taln.tuning.shoulder_knockback_radius, _taln.tuning.shoulder_knockback_force)


func _on_ground_changed(_cells: Rect2i) -> void:
	_swarm.set_ground(_ground.get_height_array(), _ground.get_blocked_mask(), _ground.get_width(),
			_ground.get_depth(), _ground.get_cell_size(), _ground.get_origin())


func _on_taln_contacted(damage: float, type: int) -> void:
	_taln.health.damage(damage, type as Damage.Type)


func _on_enemy_died(type_id: StringName, at: Vector3) -> void:
	kills += 1
	if verbose_kill_log:
		print("enemy_died %s at (%.1f, %.1f, %.1f)  [kill %d]" % [type_id, at.x, at.y, at.z, kills])


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
