class_name DebugOverlay
extends CanvasLayer
## F3 debug overlay (P2-01 step 11). Read-only: while visible it polls Taln,
## the camera rig and the Well pools every frame. Starts hidden.

@export var taln: Taln
@export var camera_rig: CameraRig
@export var swarm: SwarmServer
@export var spawner: SpawnDirector
@export var agony_tuning: AgonyTuning

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
		"Speed      %.2f m/s%s" % [speed, _speed_mult_status()],
		"Stance     %s" % _stance(speed),
		"Fracture   %s  (still %.1f s, away %.1f s)" % [
				Fracture.State.keys()[fracture.state], fracture.still_time, fracture.away_time],
		"Health     %.1f / %.0f   armor %.0f" % [health.current, taln.tuning.max_health, health.get_armor()],
		"Investiture %.1f  (v %.0f)" % [taln.investiture.current, taln.investiture.station.value() if taln.investiture.station else 1.0],
		"Leveling   n %d, next %.0f%s" % [taln.leveling.levels_taken, taln.leveling.next_cost(),
				"  ready" if taln.leveling.can_invest() else ""],
		"Income     %s" % _income_status(),
		"Strain     %s" % _strain_status(),
		"Routing    %s" % ("Blade (Blade-eligible Surges)" if taln.loadout.honorblade_held else "Toa'uma"),
		"Loadout    %d / %d slots" % [taln.loadout.slots.size(), taln.loadout.tuning.slots],
		"Weapon     %s" % _weapon_status(),
		"Surges     %s" % _surges_status(),
		"Draw       %s" % _timer(taln.toauma.draw_cooldown_left),
		"Side eff.  %s" % _side_effect_status(),
		"Rooted     %d" % swarm.get_rooted_count(),
		"Shoulder   %s" % _shoulder_status(shoulder),
		"Well pool  %s" % _pool_status(),
		"Camera     %.1f m, pitch %.1f°" % [camera_rig.distance, camera_rig.pitch_deg],
		"Swarm      %d alive, step %.2f ms" % [swarm.get_alive_count(), swarm.get_last_step_ms()],
		"Wave       %d / %d  (%.1f / %.0f s)%s" % [spawner.wave + 1, spawner.tuning.waves,
				spawner.wave_time, spawner.tuning.wave_length, _spawner_flags()],
		"Budget     %.2f /s, bank %.2f" % [spawner.budget_per_second(), spawner.bank],
		"Nearby     %s" % _pressed_status(),
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


## "ready", or the seconds left on a timer.
func _timer(seconds: float) -> String:
	return "ready" if seconds <= 0.0 else "%.2f s" % seconds


func _speed_mult_status() -> String:
	var mult: float = taln.get_speed_multiplier()
	return "" if is_equal_approx(mult, 1.0) else "  (speed x%.2f)" % mult


func _strain_status() -> String:
	var toauma: Toauma = taln.toauma
	var next: float = toauma.next_notice_threshold()
	var notice: String = "next Notice at %.0f" % next if next != INF else "every Notice fired"
	return "%.2f / %.0f, %s, side effect %.0f%%" % [toauma.strain, toauma.tuning.strain_max, notice,
			toauma.side_effect_chance() * 100.0]


func _weapon_status() -> String:
	for skill: SkillDef in taln.loadout.slots:
		if skill.kind == SkillDef.Kind.WEAPON:
			var behavior: SkillBehavior = taln.loadout.get_behavior(skill.id)
			return "%s L%d, next swing %s" % [skill.id, taln.loadout.get_level(skill.id),
					_timer(behavior.cooldown_left) if behavior else "-"]
	return "-"


func _surges_status() -> String:
	var parts: Array[String] = []
	for index in taln.loadout.surge_bindings.size():
		var surge: SurgeBehavior = taln.loadout.get_surge_behavior(index)
		if surge == null:
			parts.append("%d -" % (index + 1))
			continue
		var state: String = _timer(surge.cooldown_left)
		if surge.cooldown_left <= 0.0 and not taln.investiture.can_afford(surge.skill.investiture_cost):
			state = "can't afford %.0f" % surge.skill.investiture_cost
		parts.append("%d %s %s" % [index + 1, surge.skill.id, state])
	return " | ".join(parts)


func _side_effect_status() -> String:
	var toauma: Toauma = taln.toauma
	if toauma.last_effect == Toauma.Effect.NONE:
		return "none yet"
	return "%s on a %s, %.1f s ago" % [Toauma.Effect.keys()[toauma.last_effect].capitalize(),
			"Draw" if toauma.last_effect_from_draw else "Surge",
			(Time.get_ticks_msec() - toauma.last_effect_msec) / 1000.0]


func _pool_status() -> String:
	for pool: WellPool in get_tree().get_nodes_in_group(&"well_pools"):
		if pool.is_taln_inside:
			return "in pool (%s)" % pool.name
	return "no"


func _spawner_flags() -> String:
	var flags: Array[String] = []
	if spawner.stress:
		flags.append("STRESS")
	if spawner.paused:
		flags.append("PAUSED")
	return "  " + " ".join(flags) if not flags.is_empty() else ""


func _income_status() -> String:
	var parts: Array[String] = []
	for source: StringName in taln.investiture.income_by_source:
		parts.append("%s %.0f" % [source, taln.investiture.income_by_source[source]])
	return ", ".join(parts) if not parts.is_empty() else "none yet"


func _pressed_status() -> String:
	var near: int = swarm.query_count_in_radius(taln.global_position, agony_tuning.pressed_radius)
	var pressed: String = "  Pressed" if near >= agony_tuning.pressed_min_enemies else ""
	return "%d within %.0f m%s" % [near, agony_tuning.pressed_radius, pressed]
