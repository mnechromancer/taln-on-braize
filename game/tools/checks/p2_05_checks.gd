extends SceneTree
## P2-05 (Investiture loop and leveling) checks, run headless against the real
## station scene at a fixed 60 fps. Prints PASS/FAIL per check (INFO lines are
## not judged) and exits with the number of failures. Meta state goes to
## user://checks_meta.json, never the player's file.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_05_checks.gd

const STATION := "res://scenes/graybox_station.tscn"
const ASH_WALKER := "res://data/swarm/ash_walker.tres"
const NOTICE_HUNTER := "res://data/swarm/notice_hunter.tres"
const CHECKS_META := "user://checks_meta.json"
## Words the UI must never use (Narrative Bible §8, spec §1.3; handoff rule 6).
const BANNED := ["win", "won", "lose", "lost", "victory", "defeat", "game over", "you died", "success", "failure"]
## An open spot on flat ground, well away from pools and walls.
const OPEN := Vector3(-40.0, 0.0, -10.0)

var station: GrayboxStation
var taln: Taln
var swarm: SwarmServer
var motes: MoteServer
var spawner: SpawnDirector
var well: Well
var menu: LevelUpMenu
var context: StationContext
var ash: SwarmType
var hunter: SwarmType
var meta: Meta
var failures: int = 0


func _init() -> void:
	_run()


func _run() -> void:
	await _ticks(2)
	meta = Meta.state()
	meta.redirect(CHECKS_META)
	meta.wipe()
	ash = load(ASH_WALKER)
	hunter = load(NOTICE_HUNTER)
	await _check_data()
	await _check_station_value()
	print("")
	await _check_mote_drops()
	await _check_mote_pickup()
	await _check_mote_lifetime()
	await _check_mote_overflow()
	print("")
	await _check_ambient()
	await _check_pool_rates()
	await _check_pool_drain()
	await _check_pool_spots()
	print("")
	await _check_invest_refused()
	await _check_invest_pick()
	await _check_invest_other_inputs()
	await _check_offer_weights()
	await _check_consolidate()
	await _check_caps()
	await _check_level_params()
	print("")
	await _check_meta_state()
	print("")
	await _check_hud()
	_check_ui_words()
	print("")
	await _check_bot()
	await _check_performance()
	print("")
	print("MANUAL  HUD, Invest menu, motes (Honor hue, faceted, sink and fade) and pools shrinking need a rendered recording.")
	print("MANUAL  Economy readout: tools/bots/run_bot.gd over 3 seeds (report only).")
	print("")
	meta.wipe()
	print("%d check(s) failed." % failures if failures > 0 else "All automated checks passed.")
	quit(failures)


# --- helpers ---------------------------------------------------------------

func _check(label: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _info(label: String, detail: String) -> void:
	print("INFO  %s  (%s)" % [label, detail])


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


## Real (unpaused-clock) seconds, for the menu's input delay.
func _wait_real(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


## A new station after its first ground sample: spawner paused, Taln
## invulnerable at OPEN, his skills off unless a check turns them on.
func _fresh(at: Vector3 = OPEN) -> void:
	if station:
		paused = false
		station.queue_free()
		await _ticks(1)
	station = (load(STATION) as PackedScene).instantiate()
	root.add_child(station)
	taln = station.get_node("Taln")
	swarm = station.get_node("SwarmServer")
	motes = station.get_node("MoteServer")
	spawner = station.get_node("SpawnDirector")
	well = station.get_node("Well")
	menu = station.get_node("LevelUpMenu")
	context = station.get_node("StationContext")
	spawner.paused = true
	taln.health.set_invulnerable(&"checks", true)
	taln.loadout.process_mode = Node.PROCESS_MODE_DISABLED
	await (station.get_node("StationGround") as StationGround).ground_changed
	taln.global_position = at
	taln.velocity = Vector3.ZERO
	await _ticks(2)


func _tap(action: StringName) -> void:
	_send(action, true)
	await process_frame
	await process_frame
	_send(action, false)
	await process_frame


func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The slot of the one live mote, or -1.
func _only_mote() -> int:
	for i in motes.capacity:
		if motes.is_mote_alive(i):
			return i
	return -1


# --- data --------------------------------------------------------------------

func _check_data() -> void:
	await _fresh()
	var t: InvestitureTuning = taln.investiture.tuning
	_check("Investiture tuning: v 1/2/3, C(n) = round(54 × 1.1^n), heals 9% / 25%, 3 offered, cycle starts at 0",
			t.station_values == [1.0, 2.0, 3.0] and t.level_cost_base == 54.0 and t.level_cost_growth == 1.1
			and t.level_heal_fraction == 0.09 and t.consolidate_heal_fraction == 0.25 and t.offer_size == 3
			and t.debug_start_investiture == 0.0 and taln.investiture.current == 0.0,
			"v %s, base %.0f × %.2f^n, start %.0f" % [t.station_values, t.level_cost_base, t.level_cost_growth,
			taln.investiture.current])
	var table: Dictionary = {0: 54, 4: 79, 8: 116, 13: 186, 17: 273, 22: 440, 26: 644}
	var got: Dictionary = {}
	for n: int in table:
		got[n] = roundi(taln.leveling.cost_of(n))
	_check("C(n) matches the spec §2.4 table", got == table, "%s" % got)
	var mt: MoteTuning = motes.tuning
	_check("Motes: pickup 2.5 m, fly 18 m/s, persist 30 s", mt.pickup_radius == 2.5 and mt.fly_speed == 18.0
			and mt.lifetime == 30.0, "%.1f m, %.0f m/s, %.0f s (then sink %.1f s)" % [mt.pickup_radius, mt.fly_speed,
			mt.lifetime, mt.sink_time])
	_check("Drops: swarm 1, Notice hunter 9 (elite tier)", ash.investiture_drop == 1.0 and hunter.investiture_drop == 9.0
			and ash.tier == SwarmType.TIER_SWARM and hunter.tier == SwarmType.TIER_ELITE,
			"ash %.0f, hunter %.0f" % [ash.investiture_drop, hunter.investiture_drop])
	var w: WellPoolTuning = well.tuning
	_check("Well: ambient 0.5/s, pools 4/s Anchored and 1/s standing, hold 90, back after 20 s ≥ 12 m from Taln, ≥ 15 m apart",
			w.ambient_rate == 0.5 and w.draw_rate_anchored == 4.0 and w.draw_rate_standing == 1.0 and w.pool_capacity == 90.0
			and w.respawn_delay == 20.0 and w.min_distance_taln == 12.0 and w.min_distance_pools == 15.0
			and well.pools().size() == 3 and w.pool_radius == 3.0, "%d pools of %.0f m" % [well.pools().size(), w.pool_radius])


func _check_station_value() -> void:
	await _fresh()
	var gains: Array[String] = []
	var ok: bool = true
	for index in 3:
		context.station_index = index
		var before: float = taln.investiture.current
		taln.investiture.add(10.0, &"ambient")
		var got: float = taln.investiture.current - before
		ok = ok and is_equal_approx(got, 10.0 * (index + 1)) and spawner.station_index == index
		gains.append("%.0f" % got)
	context.station_index = 1
	var before: float = taln.investiture.current
	taln.toauma.draw()
	var drawn: float = taln.investiture.current - before
	before = taln.investiture.current
	taln.investiture.add(100.0, &"debug")
	var debug: float = taln.investiture.current - before
	_check("Income × v by station (10 base → %s); Draw × v too (ruled); the debug grant isn't" % ", ".join(gains),
			ok and is_equal_approx(drawn, 60.0) and is_equal_approx(debug, 100.0),
			"Draw at v 2: +%.0f; debug +%.0f; the spawner follows the index" % [drawn, debug])


# --- motes ---------------------------------------------------------------------

func _check_mote_drops() -> void:
	await _fresh()
	var died: Array = []
	swarm.enemy_died.connect(func(id: StringName, at: Vector3, rewarded: bool) -> void: died.append([id, at, rewarded]))
	var at: Vector3 = OPEN + Vector3(6.0, 0.0, 0.0)
	swarm.set_target(null)
	swarm.spawn(ash, at, 1.0, 1.0)
	swarm.apply_damage_in_radius(at, 0.5, 100.0, Damage.Type.KINETIC)
	await _ticks(3)
	var slot: int = _only_mote()
	var mote_at: Vector3 = motes.get_mote_position(slot) if slot >= 0 else Vector3.INF
	_check("A rewarded kill drops one mote where it died, and counts as a kill", died.size() == 1 and died[0][2] == true
			and motes.get_count() == 1 and _flat_dist(mote_at, at) < 0.01 and station.kills == 1,
			"enemy_died rewarded %s, %d mote(s) %.2f m from the death, kills %d" % [died[0][2] if died.size() > 0 else "-",
			motes.get_count(), _flat_dist(mote_at, at) if slot >= 0 else -1.0, station.kills])

	died.clear()
	var brief: int = swarm.spawn(hunter, OPEN + Vector3(-6.0, 0.0, 0.0), 1.0, 1.0)
	swarm.set_enemy_lifetime(brief, 0.2)
	await _ticks(30)
	_check("A hunter whose time runs out: enemy_died(rewarded = false), no mote, not a kill", died.size() == 1
			and died[0][2] == false and motes.get_count() == 1 and station.kills == 1,
			"rewarded %s, motes still %d, kills %d" % [died[0][2] if died.size() > 0 else "-", motes.get_count(), station.kills])

	motes.clear_all()
	var hunter_at: Vector3 = OPEN + Vector3(0.0, 0.0, 6.0)
	swarm.spawn(hunter, hunter_at, 1.0, 1.0)
	swarm.apply_damage_in_radius(hunter_at, 0.5, 1000.0, Damage.Type.KINETIC)
	await _ticks(3)
	var gained: Array = []
	taln.investiture.gained.connect(func(amount: float, source: StringName) -> void: gained.append([amount, source]))
	taln.global_position = hunter_at + Vector3(0.0, 0.0, 1.0)
	await _ticks(30)
	_check("A hunter kill drops one large mote worth 9: elite income", gained.size() == 1 and gained[0][1] == &"elite"
			and is_equal_approx(gained[0][0], 9.0) and motes.get_count() == 0,
			"income %s" % [gained])


func _check_mote_pickup() -> void:
	await _fresh()
	motes.spawn(OPEN + Vector3(3.0, 0.0, 0.0), 1.0, SwarmType.TIER_SWARM)
	var slot: int = _only_mote()
	await _ticks(10)
	var waiting: bool = motes.is_mote_alive(slot) and not motes.is_mote_flying(slot)
	context.station_index = 2
	var gained: Array = []
	taln.investiture.gained.connect(func(amount: float, source: StringName) -> void: gained.append([amount, source]))
	motes.spawn(OPEN + Vector3(2.3, 0.0, 0.0), 1.0, SwarmType.TIER_SWARM)
	var near: int = -1
	for i in motes.capacity:
		if motes.is_mote_alive(i) and i != slot:
			near = i
	var from: Vector3 = motes.get_mote_position(near)
	await _ticks(1)
	var flying: bool = motes.is_mote_flying(near)
	var moved: float = motes.get_mote_position(near).distance_to(from)
	await _ticks(20)
	_check("Outside 2.5 m a mote waits; inside it flies to Taln at 18 m/s and pays its value × v",
			waiting and flying and absf(moved - 18.0 / 60.0) < 0.01 and gained.size() == 1 and gained[0][1] == &"kill"
			and is_equal_approx(gained[0][0], 3.0) and motes.is_mote_alive(slot),
			"3 m one waiting: %s; 2.3 m one flew %.3f m in a tick; paid %s at v 3" % [waiting, moved, gained])

	# Once flying it follows Taln even when he moves away.
	motes.clear_all()
	gained.clear()
	motes.spawn(OPEN + Vector3(2.0, 0.0, 0.0), 1.0, SwarmType.TIER_SWARM)
	await _ticks(1)
	taln.global_position = OPEN + Vector3(-4.0, 0.0, 0.0)
	await _ticks(40)
	_check("A mote that started flying still reaches Taln after he moves out of range", gained.size() == 1,
			"%d collected" % gained.size())


func _check_mote_lifetime() -> void:
	await _fresh()
	var lost: Array[float] = []
	var gained: Array[float] = []
	motes.mote_lost.connect(func(value: float, _tag: int) -> void: lost.append(value))
	taln.investiture.gained.connect(func(amount: float, _source: StringName) -> void: gained.append(amount))
	motes.spawn(OPEN + Vector3(10.0, 0.0, 0.0), 1.0, SwarmType.TIER_SWARM)
	var slot: int = _only_mote()
	var rest_y: float = motes.get_mote_position(slot).y
	await _ticks(30 * 60 - 5)
	var alive_at_30: bool = motes.is_mote_alive(slot)
	await _ticks(35)
	var sinking_y: float = motes.get_mote_position(slot).y
	# Taln walks over it while it sinks: too late.
	taln.global_position = OPEN + Vector3(10.0, 0.0, 0.0)
	await _ticks(60)
	_check("A mote left 30 s sinks into the ground and is lost, and pays nothing even if Taln arrives as it sinks",
			alive_at_30 and sinking_y < rest_y and lost == [1.0] and gained.is_empty() and motes.get_count() == 0,
			"alive at 29.9 s %s; %.2f m lower half a second into the sink; lost %s, paid %s" % [alive_at_30,
			rest_y - sinking_y, lost, gained])


func _check_mote_overflow() -> void:
	await _fresh()
	var lost: Array[float] = []
	motes.mote_lost.connect(func(value: float, _tag: int) -> void: lost.append(value))
	motes.capacity = 2
	var slots: Array[int] = []
	for k in 3:
		slots.append(motes.spawn(OPEN + Vector3(10.0 + k, 0.0, 0.0), 1.0 + k, SwarmType.TIER_SWARM))
	_check("A mote with no free slot is reported lost at once, so no income goes missing from the tallies",
			slots[2] == -1 and lost == [3.0] and motes.get_count() == 2, "slots %s, lost %s" % [slots, lost])


# --- the Well --------------------------------------------------------------------

func _check_ambient() -> void:
	await _fresh()
	var paused_before: float = taln.investiture.income_by_source.get(&"ambient", 0.0)
	await _ticks(120)
	var paused_gain: float = taln.investiture.income_by_source.get(&"ambient", 0.0) - paused_before
	context.station_index = 1
	spawner.paused = false
	await _ticks(120)
	spawner.paused = true
	var wave_gain: float = taln.investiture.income_by_source.get(&"ambient", 0.0) - paused_before
	_check("Ambient Well: 0.5/s × v while a wave runs, nothing while the spawner is paused",
			paused_gain == 0.0 and absf(wave_gain - 2.0) < 0.02, "paused 2 s: %.2f; 2 s of wave at v 2: %.2f"
			% [paused_gain, wave_gain])


func _check_pool_rates() -> void:
	var pool_at: Vector3 = Vector3(-22.0, 0.0, 24.0)
	await _fresh(pool_at)
	await _ticks(60)
	var anchored: bool = taln.anchored.is_anchored
	var inside: bool = (station.get_node("WellPool1") as WellPool).is_taln_inside
	var before: float = taln.investiture.income_by_source.get(&"pool", 0.0)
	await _ticks(60)
	var anchored_rate: float = taln.investiture.income_by_source.get(&"pool", 0.0) - before
	# Creep with a light stick: inside the pool, never Anchored.
	Input.action_press(&"move_left", 0.3)
	await _ticks(10)
	before = taln.investiture.income_by_source.get(&"pool", 0.0)
	await _ticks(60)
	var standing_rate: float = taln.investiture.income_by_source.get(&"pool", 0.0) - before
	var still_inside: bool = (station.get_node("WellPool1") as WellPool).is_taln_inside and not taln.anchored.is_anchored
	Input.action_release(&"move_left")
	_check("Pool draw: 4/s Anchored inside, 1/s inside but not Anchored", anchored and inside and still_inside
			and absf(anchored_rate - 4.0) < 0.05 and absf(standing_rate - 1.0) < 0.05,
			"Anchored %.2f/s, moving inside %.2f/s" % [anchored_rate, standing_rate])


func _check_pool_drain() -> void:
	var pool_at: Vector3 = Vector3(-22.0, 0.0, 24.0)
	await _fresh(pool_at)
	var pool: WellPool = station.get_node("WellPool1")
	var others: Array[WellPool] = [station.get_node("WellPool2"), station.get_node("WellPool3")]
	await _ticks(60 * 11)
	var half_scale: float = pool._disc.scale.x
	var half_color: Color = pool._material.albedo_color
	await _ticks(60 * 12)
	var drained: float = taln.investiture.income_by_source.get(&"pool", 0.0)
	var gone: bool = not pool.is_active and not pool.visible
	var t: WellPoolTuning = well.tuning
	_check("A pool holds 90: drained after ~23 s Anchored, its disc shrinking and dimming on the way",
			absf(drained - 90.0) < 0.01 and gone and half_scale < 0.9 and half_scale > t.drained_scale
			and half_color.v < pool._base_color.v, "paid %.2f; half-way disc scale %.2f, brightness %.2f of %.2f; gone %s"
			% [drained, half_scale, half_color.v, pool._base_color.v, gone])
	await _ticks(60 * 19)
	var early: bool = pool.is_active
	await _ticks(60 * 2)
	var at: Vector3 = pool.global_position
	var spot_ok: bool = well._disc_height(at, t.pool_radius) != null
	var far_taln: float = _flat_dist(at, taln.global_position)
	var far_pools: float = minf(_flat_dist(at, others[0].global_position), _flat_dist(at, others[1].global_position))
	_check("20 s later it reappears, full, on open flat ground ≥ 12 m from Taln and ≥ 15 m from the other pools",
			not early and pool.is_active and pool.visible and pool.remaining == t.pool_capacity and spot_ok
			and far_taln >= 12.0 and far_pools >= 15.0, "back after 20 s: %s; at (%.1f, %.1f), %.1f m from Taln, %.1f m from the nearest pool"
			% [pool.is_active and not early, at.x, at.z, far_taln, far_pools])


func _check_pool_spots() -> void:
	await _fresh()
	var pool: WellPool = station.get_node("WellPool1")
	var others: Array[WellPool] = [station.get_node("WellPool2"), station.get_node("WellPool3")]
	var ground: StationGround = station.get_node("StationGround")
	var bad: int = 0
	var found: int = 0
	var on_plateau: int = 0
	for k in 300:
		taln.global_position = Vector3(-50.0 + (k % 10) * 11.0, 0.0, -50.0 + (k / 10) * 3.5)
		var at: Variant = well.find_spot(pool)
		if at == null:
			continue
		found += 1
		var p: Vector3 = at
		if (p as Vector3).y > 1.0:
			on_plateau += 1
		# Every cell the 3 m disc touches must be open.
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				var q := Vector2(p.x + dx, p.z + dz)
				var near := Vector2(clampf(p.x, floorf(q.x), floorf(q.x) + 1.0), clampf(p.z, floorf(q.y), floorf(q.y) + 1.0))
				if near.distance_to(Vector2(p.x, p.z)) <= 3.0 and ground.is_blocked_at(floorf(q.x) + 0.5, floorf(q.y) + 0.5):
					bad += 1
		if _flat_dist(p, taln.global_position) < 12.0 or _flat_dist(p, others[0].global_position) < 15.0 \
				or _flat_dist(p, others[1].global_position) < 15.0:
			bad += 1
	_check("Pool spots over 300 draws: whole disc open, ≥ 12 m from Taln, ≥ 15 m from the others (ruled)",
			found > 290 and bad == 0, "%d found, %d violations, %d up on the plateau" % [found, bad, on_plateau])


# --- leveling ----------------------------------------------------------------------

func _check_invest_refused() -> void:
	await _fresh()
	taln.investiture.add(53.0, &"debug")
	await _tap(&"invest")
	_check("Invest with less than C(0) = 54 held does nothing", not menu.is_open and not paused
			and taln.investiture.current == 53.0, "held %.0f: menu open %s, paused %s" % [taln.investiture.current,
			menu.is_open, paused])


func _check_invest_pick() -> void:
	await _fresh()
	taln.investiture.add(100.0, &"debug")
	taln.health.set_invulnerable(&"checks", false)
	taln.health.damage(60.0, Damage.Type.KINETIC)
	taln.health.set_invulnerable(&"checks", true)
	var hurt: float = taln.health.current
	await _tap(&"invest")
	var opened: bool = menu.is_open and paused
	var texts: Array[String] = menu.option_texts()
	var offer: Array[SkillDef] = menu._offer.duplicate()
	await _ticks(10)
	await _tap(&"pick_1")  # Inside the input delay: ignored.
	var early: bool = menu.is_open
	await _wait_real(menu.taln.leveling.tuning.menu_input_delay)
	var level_before: int = taln.loadout.get_level(offer[0].id) if not offer.is_empty() else 0
	await _tap(&"pick_1")
	var level_after: int = taln.loadout.get_level(offer[0].id) if not offer.is_empty() else 0
	# Since P2-06 the innate Bearer of Agonies is offered too.
	_check("Invest with C(0) held pauses the whole game and offers the owned skills below cap (up to 3)",
			opened and offer.size() == 3 and texts.size() == 3 and texts[0].begins_with("1") and texts[2].begins_with("3"),
			"paused %s; offered %s" % [paused or opened, texts])
	_check("A pick inside the 0.2 s input delay is ignored", early, "still open after an early 1: %s" % early)
	_check("Key 1 takes the first: spends C(0), n → 1, that skill +1 level, heals 9% of max Health, unpauses",
			not menu.is_open and not paused and taln.investiture.current == 46.0 and taln.leveling.levels_taken == 1
			and level_after == level_before + 1 and is_equal_approx(taln.health.current, hurt + 13.5),
			"held %.0f, n %d, %s L%d → L%d, Health %.1f → %.1f" % [taln.investiture.current, taln.leveling.levels_taken,
			offer[0].id if not offer.is_empty() else "-", level_before, level_after, hurt, taln.health.current])


func _check_invest_other_inputs() -> void:
	await _fresh()
	taln.investiture.add(500.0, &"debug")
	# A click: the second button's pressed signal, as a mouse click fires it.
	await _tap(&"invest")
	await _wait_real(menu.taln.leveling.tuning.menu_input_delay)
	var offer: Array[SkillDef] = menu._offer.duplicate()
	var second: int = taln.loadout.get_level(offer[1].id)
	(menu._buttons[1] as Button).pressed.emit()
	await process_frame
	var clicked: bool = not menu.is_open and taln.loadout.get_level(offer[1].id) == second + 1
	# D-pad and A: focus sits on the first option; ui_accept (pad A) presses it.
	await _tap(&"invest")
	await _wait_real(menu.taln.leveling.tuning.menu_input_delay)
	offer = menu._offer.duplicate()
	var first: int = taln.loadout.get_level(offer[0].id)
	var focused: bool = menu._buttons[0].has_focus()
	await _tap(&"ui_accept")
	var accepted: bool = not menu.is_open and taln.loadout.get_level(offer[0].id) == first + 1
	# Invest again closes without spending.
	await _tap(&"invest")
	var held: float = taln.investiture.current
	var n: int = taln.leveling.levels_taken
	await _tap(&"invest")
	var cancelled: bool = not menu.is_open and not paused and taln.investiture.current == held and taln.leveling.levels_taken == n
	_check("Picks also by click and by D-pad focus + A; Invest again closes it without spending",
			clicked and focused and accepted and cancelled, "click %s, focus on option 1 %s, A %s, closed unspent %s"
			% [clicked, focused, accepted, cancelled])


func _check_offer_weights() -> void:
	await _fresh()
	var single: InvestitureTuning = taln.leveling.tuning.duplicate()
	single.offer_size = 1
	taln.leveling.tuning = single
	taln.loadout.level_up(&"settle")
	taln.leveling.rng.seed = 5
	var stroke_first: int = 0
	var draws: int = 6000
	for k in draws:
		if taln.leveling.offer()[0].id == &"breaking_stroke":
			stroke_first += 1
	var share: float = float(stroke_first) / draws
	single.offer_size = 3
	var all: Array[SkillDef] = taln.leveling.offer()
	# Breaking Stroke L1, Settle L2, Bearer of Agonies L1 (P2-06): weights 1, 1/2, 1.
	_check("Offers weight 1 / level, without replacement (ruled): L1, L2, L1 → 0.4 / 0.2 / 0.4",
			absf(share - 0.4) < 0.02 and all.size() == 3 and all[0] != all[1] and all[1] != all[2] and all[0] != all[2],
			"Breaking Stroke (L1) offered first %.3f of %d; a 3-wide offer of 3 eligible holds each once" % [share, draws])


func _check_consolidate() -> void:
	await _fresh()
	for id: StringName in [&"breaking_stroke", &"settle", &"bearer_of_agonies"]:
		while taln.loadout.level_up(id):
			pass
	var capped: bool = taln.loadout.get_level(&"breaking_stroke") == 3 and taln.loadout.get_level(&"settle") == 3 \
			and taln.loadout.get_level(&"bearer_of_agonies") == 2
	taln.investiture.add(200.0, &"debug")
	taln.health.set_invulnerable(&"checks", false)
	taln.health.damage(100.0, Damage.Type.KINETIC)
	taln.health.set_invulnerable(&"checks", true)
	var hurt: float = taln.health.current
	await _tap(&"invest")
	var texts: Array[String] = menu.option_texts()
	await _wait_real(menu.taln.leveling.tuning.menu_input_delay)
	await _tap(&"pick_1")
	_check("Every owned skill at its cap (3; Bearer 2): only Consolidate — spends C(n), n + 1, heals 25%",
			capped and texts.size() == 1 and texts[0].contains("Consolidate") and taln.investiture.current == 146.0
			and taln.leveling.levels_taken == 1 and is_equal_approx(taln.health.current, hurt + 37.5),
			"offer %s; held %.0f, n %d, Health %.1f → %.1f" % [texts, taln.investiture.current,
			taln.leveling.levels_taken, hurt, taln.health.current])


func _check_caps() -> void:
	await _fresh()
	_check("Caps come from MetaState: 3 for skills, 2 for Bearer of Agonies", taln.loadout.get_cap(&"breaking_stroke") == 3
			and taln.loadout.get_cap(&"settle") == 3 and meta.get_cap(&"bearer_of_agonies") == 2,
			"stroke %d, settle %d, bearer %d" % [taln.loadout.get_cap(&"breaking_stroke"), taln.loadout.get_cap(&"settle"),
			meta.get_cap(&"bearer_of_agonies")])
	var short := SkillDef.new()
	short.id = &"check_short"
	short.kind = SkillDef.Kind.PERK
	short.level_params = [{"n": 1}, {"n": 2}, {"n": 3}]
	taln.loadout.add_skill(short)
	meta.caps[&"check_short"] = 5
	var clamped: int = taln.loadout.get_cap(&"check_short")
	meta.caps.erase(&"check_short")
	_check("A cap past a skill's defined levels clamps to them (with a warning)", clamped == 3, "cap 5 on 3 levels → %d" % clamped)


func _check_level_params() -> void:
	var stroke: SkillDef = load("res://data/skills/breaking_stroke.tres")
	var settle: SkillDef = load("res://data/skills/settle.tres")
	var intervals: Array = stroke.level_params.map(func(p: Dictionary) -> float: return p.interval)
	var damage: Array = stroke.level_params.map(func(p: Dictionary) -> float: return p.damage)
	var cones: Array = settle.level_params.map(func(p: Dictionary) -> float: return p.cone_deg)
	var roots: Array = settle.level_params.map(func(p: Dictionary) -> float: return p.root_duration)
	_check("Levels to 9 continue each L2→L3 step (placeholders, ruled): Stroke interval floored at 0.5 s, Settle cone capped at 120°",
			stroke.level_params.size() == 9 and settle.level_params.size() == 9
			and intervals == [0.8, 0.75, 0.7, 0.65, 0.6, 0.55, 0.5, 0.5, 0.5]
			and damage == [24.0, 29.0, 35.0, 41.0, 47.0, 53.0, 59.0, 65.0, 71.0]
			and cones == [70.0, 80.0, 90.0, 100.0, 110.0, 120.0, 120.0, 120.0, 120.0] and is_equal_approx(roots[8], 4.4),
			"Stroke interval %s; Settle cone %s" % [intervals, cones])
	await _fresh()
	taln.loadout.level_up(&"breaking_stroke")
	var behavior: SkillBehavior = taln.loadout.get_behavior(&"breaking_stroke")
	_check("A level-up reaches the skill's behavior", behavior.level == 2 and behavior.params().interval == 0.75,
			"behavior level %d, interval %.2f" % [behavior.level, behavior.params().interval])


# --- MetaState ----------------------------------------------------------------------

func _check_meta_state() -> void:
	meta.wipe()
	var path: String = ProjectSettings.globalize_path(CHECKS_META)
	meta.bank_agony(9)
	var raised: bool = meta.raise_cap(&"settle")
	var cost_next: int = meta.cap_raise_cost(&"settle")
	var bearer_cost: int = meta.cap_raise_cost(&"bearer_of_agonies")
	meta.unlock_catalysis()
	meta.mark_return_seen()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CHECKS_META))
	meta.caps.clear()
	meta.banked_agony = 0
	meta.load_state()
	_check("MetaState saves on every change to versioned JSON (schema 1) and loads it back",
			int(saved.get("schema_version", 0)) == 1 and int(saved.get("banked_agony", -1)) == 7
			and bool(saved.get("catalysis_unlocked", false)) and bool(saved.get("return_seen", false))
			and meta.get_cap(&"settle") == 4 and meta.banked_agony == 7 and meta.banked_total == 9,
			"%s: %s" % [path.get_file(), saved])
	_check("Cap raise costs c − 1 banked points (spec §9)", raised and cost_next == 3 and bearer_cost == 1,
			"settle 3 → 4 cost 2 (now 3 for the next); Bearer 2 → 3 costs %d" % bearer_cost)
	var real_path: String = ProjectSettings.globalize_path(Meta.DEFAULT_PATH)
	_check("Checks write only their own file", meta.path == CHECKS_META, "writing %s, not %s" % [path.get_file(),
			real_path.get_file()])
	meta.wipe()


# --- HUD and words ---------------------------------------------------------------------

func _check_hud() -> void:
	await _fresh()
	var hud: Hud = station.get_node("Hud")
	taln.investiture.add(60.0, &"debug")
	taln.toauma.add_strain(2.5)
	taln.toauma.draw_cooldown_left = 3.0
	await process_frame
	await process_frame
	var ok: bool = hud._health_value.text == "150 / 150" and hud._investiture_value.text == "60" \
			and hud._next_level.text == "Next level 54" and hud._ready_mark.visible \
			and hud._investiture_value.get_theme_color(&"font_color") == Color("cfe8ff") \
			and hud._surge_name.text == "Settle  25" and hud._surge_state.text == "ready" \
			and hud._draw_state.text.ends_with(" s") and hud._pips.size() == 9 \
			and is_equal_approx(hud._pip_fills[0].size.x, 14.0) and is_equal_approx(hud._pip_fills[2].size.x, 7.0) \
			and hud._pip_fills[3].size.x == 0.0 and hud._wave.text == "Wave 1 / 9"
	taln.investiture.spend(20.0, &"checks")
	await process_frame
	var not_ready: bool = not hud._ready_mark.visible
	_check("HUD: Health, Investiture in Honor hue, next level cost with a ready mark, Surge and Draw timers, 9 Strain pips, wave",
			ok and not_ready, "Health '%s', Investiture '%s', '%s', ready %s then %s; '%s' %s; Draw %s; pips %.0f/%.0f/%.0f; '%s'"
			% [hud._health_value.text, hud._investiture_value.text, hud._next_level.text, ok, not not_ready,
			hud._surge_name.text, hud._surge_state.text, hud._draw_state.text, hud._pip_fills[0].size.x,
			hud._pip_fills[2].size.x, hud._pip_fills[3].size.x, hud._wave.text])


## Every player-visible string: UiText's constants, string literals in UI
## scripts, text in scenes, skill names and Toa'uma's lines.
func _check_ui_words() -> void:
	var strings: Array[String] = []
	var sources: Array[String] = []
	for path in _files("res://scripts/ui", ".gd"):
		sources.append(path)
		strings.append_array(_literals(FileAccess.get_file_as_string(path)))
	var text_prop := RegEx.create_from_string("(?m)^(?:text|tooltip_text|placeholder_text) = \"((?:[^\"\\\\]|\\\\.)*)\"")
	for path in _files("res://scenes", ".tscn"):
		sources.append(path)
		for found in text_prop.search_all(FileAccess.get_file_as_string(path)):
			strings.append(found.get_string(1))
	for path in _files("res://data/skills", ".tres"):
		strings.append((load(path) as SkillDef).display_name)
	strings.append_array((load("res://data/tuning/toauma_tuning.tres") as ToaumaTuning).speaks_lines)
	var pattern := RegEx.create_from_string("(?i)\\b(" + "|".join(BANNED) + ")\\b")
	var hits: Array[String] = []
	for s in strings:
		if pattern.search(s):
			hits.append(s)
	_check("No UI string or scene text says win, won, lose, lost, victory, defeat, game over, you died, success or failure",
			strings.size() > 10 and hits.is_empty(), "%d strings from %d files: %s" % [strings.size(), sources.size(),
			"hits %s" % [hits] if not hits.is_empty() else "clean"])


func _files(dir: String, ext: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(ext):
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_files(dir.path_join(sub), ext))
	return found


## Double-quoted string literals in GDScript source, comments skipped.
func _literals(source: String) -> Array[String]:
	var out: Array[String] = []
	var literal := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	for line in source.split("\n"):
		var code: String = line
		var cut: int = line.find("#")
		if cut >= 0 and line.left(cut).count("\"") % 2 == 0:
			code = line.left(cut)
		for found in literal.search_all(code):
			out.append(found.get_string(1))
	return out


# --- bot and performance -----------------------------------------------------------

func _check_bot() -> void:
	await _fresh(Vector3(0.0, 0.0, 30.0))
	var bot := KiteBot.new()
	bot.taln = taln
	bot.swarm = swarm
	bot.ground = station.get_node("StationGround")
	bot.camera_rig = station.get_node("CameraRig")
	bot.menu = menu
	bot.well = well
	station.add_child(bot)
	taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT
	taln.investiture.add(100.0, &"debug")  # Enough to invest at once.
	var start: Vector3 = taln.global_position
	var travelled: float = 0.0
	var last: Vector3 = start
	spawner.paused = false
	# 90 s of play: the Invest menu's pauses don't count (they wait on real time).
	var played: int = 0
	while played < 90 * 60:
		await physics_frame
		if not paused:
			played += 1
		travelled += _flat_dist(taln.global_position, last)
		last = taln.global_position
	spawner.paused = true
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(action)
	_check("KiteBot plays 90 s: moves, casts Settle, Draws, invests through the menu",
			travelled > 100.0 and bot.casts >= 1 and bot.draws >= 1 and taln.leveling.levels_taken >= 1 and not paused,
			"walked %.0f m, %d Settles, %d Draws, %d level-ups, %d kills, %.0f s in pools" % [travelled, bot.casts,
			bot.draws, taln.leveling.levels_taken, station.kills, bot.pool_seconds])
	bot.queue_free()


func _check_performance() -> void:
	await _fresh(Vector3(0.0, 0.0, 30.0))
	taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT
	motes.set_target(null)  # Let motes pile up: the worst case for their cost.
	var ground: StationGround = station.get_node("StationGround")
	var samples: PackedFloat32Array = []
	var worst_step: float = 0.0
	var k: int = 0
	for f in 1200:
		while swarm.get_alive_count() < 400:
			var angle: float = k * 2.39996
			var at: Vector3 = taln.global_position + Vector3(cos(angle), 0.0, sin(angle)) * (3.0 + fmod(k * 0.37, 23.0))
			k += 1
			if not ground.is_blocked_at(at.x, at.z):
				swarm.spawn(ash, at, 1.0, 1.0)
		if f % 3 == 0:
			swarm.apply_damage_in_radius(taln.global_position, 6.0, 100.0, Damage.Type.KINETIC)
		var before: int = Time.get_ticks_usec()
		await _ticks(1)
		samples.append((Time.get_ticks_usec() - before) / 1000.0)
		worst_step = maxf(worst_step, swarm.get_last_step_ms())
	var total: float = 0.0
	for ms in samples:
		total += ms
	var sorted: PackedFloat32Array = samples.duplicate()
	sorted.sort()
	var p99: float = sorted[int(sorted.size() * 0.99)]
	_check("400 alive, kills every 3 ticks and ~%d motes on the ground: step < 2 ms, frame fits 60 fps (CPU side)" % motes.get_count(),
			worst_step < 2.0 and total / samples.size() < 4.0 and p99 < 4.0 and motes.get_count() > 500,
			"step worst %.3f ms; frame avg %.3f ms, p99 %.3f ms, worst %.3f ms; %d motes"
			% [worst_step, total / samples.size(), p99, sorted[-1], motes.get_count()])
