class_name DebugOverlay
extends CanvasLayer
## F3 debug overlay (P2-01 step 11). Read-only: while visible it polls Taln,
## the camera rig and the Well pools every frame. Starts hidden.

@export var taln: Taln
@export var camera_rig: CameraRig

@onready var _label: Label = $Panel/Label


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible:
		return
	var speed: float = Vector2(taln.velocity.x, taln.velocity.z).length()
	var fracture: Fracture = taln.fracture
	var health: Health = taln.health
	var shoulder: Shoulder = taln.shoulder
	_label.text = "\n".join([
		"FPS        %d" % Engine.get_frames_per_second(),
		"Speed      %.2f m/s" % speed,
		"Stance     %s" % _stance(speed),
		"Fracture   %s  (still %.1f s, away %.1f s)" % [
				Fracture.State.keys()[fracture.state], fracture.still_time, fracture.away_time],
		"Health     %.1f / %.0f   armor %.0f" % [health.current, taln.tuning.max_health, health.get_armor()],
		"Shoulder   %s" % _shoulder_status(shoulder),
		"Well pool  %s" % _pool_status(),
		"Camera     %.1f m, pitch %.1f°" % [camera_rig.distance, camera_rig.pitch_deg],
	])


func _stance(speed: float) -> String:
	if taln.anchored.is_anchored:
		return "Anchored"
	if speed >= taln.tuning.stop_speed or taln.shoulder.is_charging:
		return "Moving"
	return "Idle"


func _shoulder_status(shoulder: Shoulder) -> String:
	if shoulder.is_charging:
		return "charging"
	if shoulder.cooldown_left > 0.0:
		return "cooldown %.2f s" % shoulder.cooldown_left
	return "ready"


func _pool_status() -> String:
	for pool: WellPool in get_tree().get_nodes_in_group(&"well_pools"):
		if pool.is_taln_inside:
			return "in pool (%s)" % pool.name
	return "no"
