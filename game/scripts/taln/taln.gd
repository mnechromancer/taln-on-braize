class_name Taln
extends CharacterBody3D
## Taln's movement (spec §7.1): camera-relative on the ground plane, no jump,
## gravity for ledge drops only, and a manual step-up that CharacterBody3D
## lacks. While a Shoulder charge runs it replaces normal movement. The origin
## is at his feet; the collider and placeholder mesh are sized from tuning in
## _ready.

## Spacing of the downward probes that look for edges ahead of a charge.
const GAP_PROBE_SPACING := 0.05

## What a charge finds past an edge: nothing, a gap it can cross, a gap too
## wide to cross, or a drop with no ground at the same level beyond it.
enum Edge { NONE, CROSSABLE, WIDE_GAP, DROP }

@export var tuning: TalnTuning

## This frame's movement input, camera-relative on XZ, length 0–1.
var move_direction: Vector3 = Vector3.ZERO

@onready var health: Health = $Health
@onready var shoulder: Shoulder = $Shoulder
@onready var anchored: Anchored = $Anchored
@onready var fracture: Fracture = $Fracture
@onready var _collider: CollisionShape3D = $CollisionShape3D
@onready var _body_mesh: MeshInstance3D = $Body
@onready var _anchor_disc: MeshInstance3D = $AnchorDisc


func _ready() -> void:
	var shape: CapsuleShape3D = _collider.shape
	shape.height = tuning.capsule_height
	shape.radius = tuning.capsule_radius
	_collider.position.y = tuning.capsule_height / 2.0
	var mesh: CapsuleMesh = _body_mesh.mesh
	mesh.height = tuning.capsule_height
	mesh.radius = tuning.capsule_radius
	_body_mesh.position.y = tuning.capsule_height / 2.0

	floor_max_angle = deg_to_rad(tuning.max_slope_deg)
	floor_snap_length = tuning.step_height
	floor_constant_speed = true

	shoulder.shouldered.connect(_on_shouldered)
	shoulder.ended.connect(_on_shoulder_ended)
	anchored.anchored_changed.connect(_on_anchored_changed)
	_anchor_disc.visible = false


func _physics_process(delta: float) -> void:
	fracture.update(global_position, Vector2(velocity.x, velocity.z).length(), delta)
	move_direction = _read_move_direction()

	if Input.is_action_just_pressed("shoulder"):
		var dir: Vector3 = move_direction if not move_direction.is_zero_approx() else -global_basis.z
		shoulder.try_start(global_position, dir)
	anchored.update(not move_direction.is_zero_approx() or shoulder.is_charging, delta)
	if shoulder.is_charging:
		_charge(delta)
		return

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate: float = tuning.deceleration if move_direction.is_zero_approx() else tuning.acceleration
	horizontal = horizontal.move_toward(move_direction * tuning.move_speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - tuning.gravity * delta

	if not move_direction.is_zero_approx():
		var target_yaw: float = atan2(-move_direction.x, -move_direction.z)
		rotation.y = rotate_toward(rotation.y, target_yaw, deg_to_rad(tuning.turn_rate_deg) * delta)

	_try_step_up(horizontal * delta)
	move_and_slide()


## One frame of a Shoulder charge: fixed direction, no steering. Off a drop
## it keeps going through the air; over a gap wider than shoulder_max_gap it
## ends just past the edge so Taln falls in. Head-on wall hits stop it;
## shallow ones slide along the wall.
func _charge(delta: float) -> void:
	var dir: Vector3 = shoulder.direction
	var step: float = shoulder.step_distance(delta)
	var edge: Array = _edge_ahead(dir, step, shoulder.remaining)
	if edge[0] == Edge.WIDE_GAP:
		shoulder.limit_remaining(edge[1] + tuning.capsule_radius)
		step = shoulder.step_distance(delta)

	var horizontal: Vector3 = dir * (step / delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - tuning.gravity * delta
	_try_step_up(horizontal * delta)
	move_and_slide()

	if is_on_wall():
		var into_wall: float = dir.dot(-get_wall_normal())
		if into_wall >= cos(deg_to_rad(tuning.shoulder_wall_stop_angle_deg)):
			var hit: KinematicCollision3D = get_last_slide_collision()
			shoulder.hit_wall(hit.get_position(), get_wall_normal())
			return
	shoulder.record_move(step)


## Looks for an edge within this frame's step and classifies what lies past it
## within the rest of the charge. Returns [Edge, distance to the edge].
## Ground is traced sample by sample: each must sit within a step (plus a
## walkable slope over the spacing) of the last ground found, so ramps pass
## and drops show up. Anything taller than a step counts as solid and is left
## to the wall check.
func _edge_ahead(dir: Vector3, step: float, remaining: float) -> Array:
	var tolerance: float = tuning.step_height + GAP_PROBE_SPACING * tan(floor_max_angle)
	var ground_y: float = global_position.y
	var edge: float = -1.0
	var d: float = GAP_PROBE_SPACING
	while d <= remaining + 0.0001:
		var hit_y: float = _ground_height(global_position + dir * d, ground_y, tolerance)
		var solid: bool = not is_nan(hit_y)
		if edge < 0.0:
			if not solid:
				if d > step:
					return [Edge.NONE, 0.0]
				edge = d
			elif hit_y - ground_y <= tolerance:
				ground_y = hit_y
		elif solid:
			var kind: Edge = Edge.CROSSABLE if d - edge <= tuning.shoulder_max_gap else Edge.WIDE_GAP
			return [kind, edge]
		d += GAP_PROBE_SPACING
	return [Edge.DROP, edge] if edge >= 0.0 else [Edge.NONE, 0.0]


## Height of whatever is below point, from a capsule-height above ground_y
## down to tolerance below it; NAN if nothing is there.
func _ground_height(point: Vector3, ground_y: float, tolerance: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(
			Vector3(point.x, ground_y + tuning.capsule_height, point.z),
			Vector3(point.x, ground_y - tolerance, point.z))
	query.exclude = [get_rid()]
	query.hit_from_inside = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return (hit.position as Vector3).y if not hit.is_empty() else NAN


## Adds a knockback velocity change; ignored while Anchored (spec §6.2).
func apply_knockback(impulse: Vector3) -> void:
	if anchored.is_anchored:
		return
	velocity += impulse


func _on_anchored_changed(is_anchored: bool) -> void:
	if is_anchored:
		health.set_armor_bonus(&"anchored", tuning.anchored_armor_bonus)
	else:
		health.clear_armor_bonus(&"anchored")
	_anchor_disc.visible = is_anchored


func _on_shouldered(_origin: Vector3, dir: Vector3) -> void:
	health.set_invulnerable(&"shoulder", true)
	rotation.y = atan2(-dir.x, -dir.z)


func _on_shoulder_ended() -> void:
	health.set_invulnerable(&"shoulder", false)
	velocity.x = 0.0
	velocity.z = 0.0


func _read_move_direction() -> Vector3:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.is_zero_approx():
		return Vector3.ZERO
	var yaw: float = 0.0
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		var forward: Vector3 = -camera.global_basis.z
		yaw = atan2(-forward.x, -forward.z)
	return Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)


## Lifts Taln onto a ledge no taller than step_height when this frame's
## motion runs into it. move_and_slide() then carries him forward.
func _try_step_up(motion: Vector3) -> void:
	if not is_on_floor() or motion.is_zero_approx():
		return
	var blocked := KinematicCollision3D.new()
	if not test_move(global_transform, motion, blocked):
		return
	if blocked.get_normal().angle_to(Vector3.UP) <= floor_max_angle:
		return  # A walkable slope; move_and_slide() climbs it.

	var lift: Vector3 = Vector3.UP * tuning.step_height
	if test_move(global_transform, lift):
		return  # No headroom.
	# Probe far enough ahead that the capsule's rounded bottom clears the edge.
	var probe: Vector3 = motion.normalized() * (tuning.capsule_radius + motion.length())
	var raised: Transform3D = global_transform.translated(lift)
	if test_move(raised, probe):
		return  # Taller than a step.
	var landing := KinematicCollision3D.new()
	if not test_move(raised.translated(probe), -lift, landing):
		return  # Nothing to stand on.
	if landing.get_normal().angle_to(Vector3.UP) > floor_max_angle:
		return  # Too steep to stand on.

	var rise: float = tuning.step_height - landing.get_travel().length()
	if rise > 0.0:
		global_position.y += rise
