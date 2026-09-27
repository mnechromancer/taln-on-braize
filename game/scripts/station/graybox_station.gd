class_name GrayboxStation
extends Node3D
## P2-01 gray-box station. It has no directional light by design; F4 toggles
## a temporary one (off by default) for inspecting geometry. Also wires Taln's
## Shoulder wall hits to camera shake, and the swarm (SwarmServer v0) to Taln
## and the ground.
##
## Debug keys: F5 hits every enemy near Taln hard, F6 toggles spawner stress
## mode, F7 pauses the spawner.

## F5: radius and damage of the debug blast around Taln.
const DEBUG_BLAST_RADIUS := 6.0
const DEBUG_BLAST_DAMAGE := 50.0

## enemy_died count since the station loaded, for the log.
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
	_ground.ground_changed.connect(_on_ground_changed)
	_swarm.taln_contacted.connect(_on_taln_contacted)
	_swarm.enemy_died.connect(_on_enemy_died)


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
	print("enemy_died %s at (%.1f, %.1f, %.1f)  [kill %d]" % [type_id, at.x, at.y, at.z, kills])


func _on_shoulder_blocked(_position: Vector3, _normal: Vector3) -> void:
	_camera_rig.add_trauma(_camera_rig.tuning.shoulder_wall_trauma)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_inspect_light"):
		_inspect_light.visible = not _inspect_light.visible
	elif event.is_action_pressed("debug_blast"):
		var hit: int = _swarm.apply_damage_in_radius(_taln.global_position, DEBUG_BLAST_RADIUS,
				DEBUG_BLAST_DAMAGE, Damage.Type.KINETIC)
		print("F5 blast hit %d enemies" % hit)
	elif event.is_action_pressed("debug_stress"):
		_spawner.stress = not _spawner.stress
		print("Spawner stress mode ", "on" if _spawner.stress else "off")
	elif event.is_action_pressed("debug_pause_spawner"):
		_spawner.paused = not _spawner.paused
		print("Spawner ", "paused" if _spawner.paused else "running")
