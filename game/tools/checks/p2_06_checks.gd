extends SceneTree
## P2-06 (Agony, Bearer of Agonies, Welcome/Catalyze) checks, run headless
## against the real station scene at a fixed 60 fps. Prints PASS/FAIL per
## check and exits with the number of failures. Meta state goes to
## user://checks_meta.json, never the player's file. With --fixed-fps 60 one
## process frame is 1/60 s of real (unscaled) time, so the windows' real-time
## lengths are counted in frames here.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_06_checks.gd

const STATION := "res://scenes/graybox_station.tscn"
const ASH_WALKER := "res://data/swarm/ash_walker.tres"
const CHECKS_META := "user://checks_meta.json"
const OPEN := Vector3(-40.0, 0.0, -10.0)
## Open ground with room to be knocked 12 m +Z.
const CLEAR := Vector3(40.0, 0.0, 30.0)
## Endurance keeps ticking after a fill resolves; under this counts as empty.
const EMPTY := 0.1

var station: GrayboxStation
var taln: Taln
var agony: AgonyMeter
var catalysis: Catalysis
var ui: CatalyzeUi
var hud: Hud
var swarm: SwarmServer
var ash: SwarmType
var meta: Meta
var failures: int = 0


func _init() -> void:
	_run()


func _run() -> void:
	await _frames(2)
	meta = Meta.state()
	meta.redirect(CHECKS_META)
	ash = load(ASH_WALKER)
	await _check_data()
	print("")
	await _check_damage_gain()
	await _check_rate_gains()
	await _check_suspension()
	await _check_lock()
	await _check_burn()
	print("")
	await _check_case_a()
	print("")
	await _check_prompt()
	await _check_prompt_inputs()
	await _check_prompt_timeout()
	await _check_full_pause()
	print("")
	await _check_commit_hold()
	await _check_auto_fire()
	await _check_release_and_order()
	await _check_catalyze_expiry()
	await _check_cataclysms()
	print("")
	await _check_body()
	await _check_hud_meter()
	await _check_bot()
	await _check_performance()
	print("")
	print("MANUAL  Agony on Taln's body at 25/50/75/100%, the vignette, Welcome charge-up, Bank pull, the prompt,")
	print("        the Catalyze icons filling and both Cataclysms need a rendered recording.")
	print("MANUAL  The UI word check for the new strings runs in p2_05_checks.gd (it scans every UI script).")
	print("")
	meta.wipe()
	Engine.time_scale = 1.0
	print("%d check(s) failed." % failures if failures > 0 else "All automated checks passed.")
	quit(failures)


# --- helpers ---------------------------------------------------------------

func _check(label: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


## Process frames: 1/60 s of real time each under --fixed-fps 60.
func _frames(count: int) -> void:
	for i in count:
		await process_frame


## A new station: spawner paused, Taln invulnerable at OPEN with his skills
## off, meta state wiped (Catalysis locked) unless unlocked is set.
func _fresh(unlocked: bool = true) -> void:
	if station:
		paused = false
		Engine.time_scale = 1.0
		station.queue_free()
		await _frames(1)
	meta.wipe()
	if unlocked:
		meta.unlock_catalysis()
	station = (load(STATION) as PackedScene).instantiate()
	root.add_child(station)
	taln = station.get_node("Taln")
	agony = taln.agony
	catalysis = station.get_node("Catalysis")
	ui = station.get_node("CatalyzeUi")
	hud = station.get_node("Hud")
	swarm = station.get_node("SwarmServer")
	(station.get_node("SpawnDirector") as SpawnDirector).paused = true
	taln.health.set_invulnerable(&"checks", true)
	taln.loadout.process_mode = Node.PROCESS_MODE_DISABLED
	await (station.get_node("StationGround") as StationGround).ground_changed
	taln.global_position = OPEN
	taln.velocity = Vector3.ZERO
	await _ticks(2)


## Fills the meter to the top (which resolves it).
func _fill() -> void:
	agony.add(agony.tuning.meter_max, &"checks")
	await _frames(1)


func _tap(action: StringName) -> void:
	_send(action, true)
	await _frames(2)
	_send(action, false)
	await _frames(1)


func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _gained(source: StringName) -> float:
	return agony.gained_by_source.get(source, 0.0)


func _skill(id: StringName) -> SkillDef:
	return taln.loadout.get_skill(id)


## Bearer of Agonies at level (raising its meta cap for the check).
func _bearer_level(level: int) -> void:
	meta.caps[&"bearer_of_agonies"] = 9
	while taln.loadout.get_level(&"bearer_of_agonies") < level:
		taln.loadout.level_up(&"bearer_of_agonies")


# --- data --------------------------------------------------------------------

func _check_data() -> void:
	await _fresh()
	var t: AgonyTuning = agony.tuning
	_check("Agony tuning: 0–900 in ninths of 100; 1 per 1% of Health, 1/s, Pressed +2/s (≥ 9 within 6 m), breaker +1/s",
			t.meter_max == 900.0 and t.per_ninth == 100.0 and t.damage_per_percent == 1.0 and t.endurance_rate == 1.0
			and t.pressed_rate == 2.0 and t.pressed_min_enemies == 9 and t.pressed_radius == 6.0 and t.breaker_rate == 1.0,
			"max %.0f, ninth %.0f" % [t.meter_max, t.per_ninth])
	_check("Windows: 0.1× time, 6 s prompt, 9 s Catalyze (real time), 0.6 s hold, budget 9 ninths, full pause off by default",
			t.window_time_scale == 0.1 and t.prompt_window == 6.0 and t.catalyze_window == 9.0 and t.commit_hold == 0.6
			and t.budget_ninths == 9 and not t.catalyze_full_pause, "")
	var bearer: SkillDef = _skill(&"bearer_of_agonies")
	var table: Array = []
	if bearer:
		table = bearer.level_params.map(func(p: Dictionary) -> Array: return [p.lesser, p.greater, p.grand])
	var spec: Array = [[5, 7, 9], [5, 7, 8], [4, 6, 8], [4, 6, 7], [4, 5, 7], [3, 5, 6], [3, 4, 6], [3, 4, 5], [2, 4, 5]]
	_check("Bearer of Agonies: Herald Perk, innate (no slot), level 1 at cycle start, cap 2, cost table = spec §4.4",
			bearer != null and bearer.kind == SkillDef.Kind.PERK and bearer.tree == SkillDef.SkillTree.HERALD
			and taln.loadout.innate.has(bearer) and not taln.loadout.slots.has(bearer)
			and taln.loadout.get_level(&"bearer_of_agonies") == 1 and taln.loadout.get_cap(&"bearer_of_agonies") == 2
			and table == spec, "%d slots used; table %s" % [taln.loadout.slots.size(), table])
	var settle: SkillDef = _skill(&"settle")
	var stroke: SkillDef = _skill(&"breaking_stroke")
	_check("Catalysts: Settle Lesser (360°, 9 m, 40, root 3 s), Breaking Stroke Greater (9 m, 80, force 12), placeholders",
			settle.catalyst_tier == SkillDef.CatalystTier.LESSER and stroke.catalyst_tier == SkillDef.CatalystTier.GREATER
			and settle.cataclysm_params == {"cone_deg": 360.0, "damage": 40.0, "radius": 9.0, "root_duration": 3.0}
			and stroke.cataclysm_params == {"damage": 80.0, "knockback": 12.0, "radius": 9.0}
			and taln.loadout.catalysts() == [settle, stroke] and taln.loadout.catalyst_cost(settle) == 5
			and taln.loadout.catalyst_cost(stroke) == 7, "costs at Bearer L1: %d / %d" % [taln.loadout.catalyst_cost(settle),
			taln.loadout.catalyst_cost(stroke)])


# --- gains -------------------------------------------------------------------

func _check_damage_gain() -> void:
	await _fresh()
	agony.set_suspended(&"checks", false)
	taln.health.set_invulnerable(&"checks", false)
	var before: float = _gained(&"damage")
	var taken: float = taln.health.damage(30.0, Damage.Type.KINETIC)
	var got: float = _gained(&"damage") - before
	taln.health.set_invulnerable(&"checks", true)
	_check("Damage taken: 1 Agony per 1% of max Health lost after mitigation", taken > 0.0
			and is_equal_approx(got, taken / 150.0 * 100.0), "took %.2f (after armor): +%.2f" % [taken, got])

	# Fracture: stand still past 9 s (plus the 3 s away from where he first stood before the move).
	await _fresh()
	taln.health.set_invulnerable(&"checks", false)
	await _ticks(60 * 13 + 10)
	var fracture: float = _gained(&"damage")
	_check("Fracture damage feeds Agony like any other", fracture > 0.0, "+%.2f from Fracture pulses" % fracture)


func _check_rate_gains() -> void:
	await _fresh()
	var before: float = _gained(&"endurance")
	await _ticks(120)
	var endurance: float = _gained(&"endurance") - before
	swarm.set_target(null)
	for k in 9:
		swarm.spawn(ash, OPEN + Vector3(cos(k * 0.7), 0.0, sin(k * 0.7)) * 3.0, 100.0, 1.0)
	await _ticks(1)
	before = _gained(&"pressed")
	await _ticks(120)
	var pressed: float = _gained(&"pressed") - before
	swarm.clear_all()
	for k in 8:
		swarm.spawn(ash, OPEN + Vector3(cos(k * 0.7), 0.0, sin(k * 0.7)) * 3.0, 100.0, 1.0)
	await _ticks(1)
	before = _gained(&"pressed")
	await _ticks(60)
	var eight: float = _gained(&"pressed") - before
	agony.breaker_active = true
	before = _gained(&"breaker")
	await _ticks(60)
	var breaker: float = _gained(&"breaker") - before
	agony.breaker_active = false
	_check("Endurance 1/s; Pressed +2/s with 9 within 6 m (not 8); breaker +1/s while one lives (hook)",
			absf(endurance - 2.0) < 0.02 and absf(pressed - 4.0) < 0.05 and eight == 0.0 and absf(breaker - 1.0) < 0.02,
			"2 s endurance %.2f; 2 s Pressed %.2f; with 8: %.2f; 1 s breaker %.2f" % [endurance, pressed, eight, breaker])


func _check_suspension() -> void:
	await _fresh()
	taln.investiture.add(100.0, &"debug")
	await _tap(&"invest")
	var menu: LevelUpMenu = station.get_node("LevelUpMenu")
	var opened: bool = menu.is_open
	var before: float = agony.value
	await _frames(120)
	var during_pause: float = agony.value - before
	menu.close(false)
	await _frames(1)
	agony.set_suspended(&"return", true)
	before = agony.value
	taln.health.set_invulnerable(&"checks", false)
	taln.health.damage(30.0, Damage.Type.KINETIC)
	taln.health.set_invulnerable(&"checks", true)
	await _ticks(60)
	var during_hold: float = agony.value - before
	agony.set_suspended(&"return", false)
	await _ticks(60)
	var after: float = agony.value - before
	_check("No gain during the Invest pause or while a source suspends it (the windows, the Return)",
			opened and during_pause == 0.0 and during_hold == 0.0 and after > 0.9,
			"Invest pause 2 s: +%.2f; suspended 1 s with a hit: +%.2f; released 1 s: +%.2f" % [during_pause, during_hold, after])


func _check_lock() -> void:
	await _fresh()
	# Keep the fill unresolved: hold resolution, as the Return sequence does.
	catalysis.hold(&"checks", true)
	var fills: Array[int] = [0]
	agony.filled.connect(func() -> void: fills[0] += 1)
	agony.add(899.0, &"checks")
	var below: bool = not agony.is_locked
	agony.add(50.0, &"checks")
	await _ticks(60)
	agony.add(100.0, &"checks")
	_check("At 900 the meter locks; further gain is discarded until the fill resolves", below and agony.is_locked
			and agony.value == 900.0 and fills[0] == 1 and agony.ninths() == 9, "value %.0f, locked %s, filled %d time(s)"
			% [agony.value, agony.is_locked, fills[0]])
	catalysis.hold(&"checks", false)
	await _frames(2)
	_check("A fill that arrives while resolution is held resolves once the hold is released", catalysis.is_open(),
			"state %s after the release" % Catalysis.State.keys()[catalysis.state])


func _check_burn() -> void:
	await _fresh()
	var forced: ToaumaTuning = taln.toauma.tuning.duplicate()
	forced.p_base = 1.0
	forced.p_max = 1.0
	for w: String in ["weight_overcharge", "weight_misfire", "weight_lurch", "weight_echo", "weight_speaks"]:
		forced.set(w, 0)
	forced.weight_burn = 1
	taln.toauma.tuning = forced
	taln.health.set_invulnerable(&"shoulder", true)  # As during a Shoulder charge.
	var before: float = taln.health.current
	taln.toauma.draw()
	var burned: float = before - taln.health.current
	taln.health.set_invulnerable(&"shoulder", false)
	_check("Voidlight Burn ignores invulnerability (ruled): it lands through a Shoulder and feeds Agony", burned > 0.0
			and _gained(&"damage") > 0.0, "Health −%.2f, Agony +%.2f" % [burned, _gained(&"damage")])


# --- Case A -------------------------------------------------------------------

func _check_case_a() -> void:
	await _fresh(false)
	var banked: Array[bool] = []
	catalysis.banked.connect(func(first: bool) -> void: banked.append(first))
	await _fill()
	await _frames(2)
	var notice: String = hud._notice.text
	_check("First fill ever (Catalysis locked): auto-banks, no prompt or slow-down; the first banked point unlocks Catalysis",
			banked == [true] and meta.banked_agony == 1 and meta.catalysis_unlocked and agony.value < EMPTY
			and not agony.is_locked and not catalysis.is_open() and Engine.time_scale == 1.0 and notice == UiText.NOTICE_UNLOCKED
			and catalysis.history[-1].choice == &"auto_bank", "banked %s, meta %d, notice '%s'" % [banked, meta.banked_agony, notice])
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CHECKS_META))
	_check("Banked points reach MetaState's file at once", int(saved.banked_agony) == 1 and bool(saved.catalysis_unlocked),
			"%s" % saved)

	# No catalyst owned.
	await _fresh()
	for skill in taln.loadout.owned():
		if skill.catalyst_tier != SkillDef.CatalystTier.NONE:
			taln.loadout.slots.erase(skill)
	await _fill()
	var no_catalyst: bool = not catalysis.is_open() and meta.banked_agony == 1 and agony.value < EMPTY
	# Nothing affordable: a budget below the cheapest cost.
	await _fresh()
	var tight: AgonyTuning = catalysis.tuning.duplicate()
	tight.budget_ninths = 4
	catalysis.tuning = tight
	await _fill()
	var unaffordable: bool = not catalysis.is_open() and meta.banked_agony == 1
	_check("Case A also when no catalyst is owned, or none fits the budget", no_catalyst and unaffordable,
			"no catalyst: banked %s; budget 4 vs cheapest 5: banked %s" % [no_catalyst, unaffordable])


# --- the prompt ---------------------------------------------------------------

func _check_prompt() -> void:
	await _fresh()
	await _fill()
	var menu: LevelUpMenu = station.get_node("LevelUpMenu")
	_check("A fill with Catalysis unlocked opens the prompt: 0.1× time, Agony held, Taln locked out of Shoulder, Surges and Draw, Invest shut",
			catalysis.state == Catalysis.State.PROMPT and is_equal_approx(Engine.time_scale, 0.1) and agony.is_suspended()
			and taln.control_locked and menu.blocked and ui._prompt.visible and not paused,
			"state %s, time scale %.2f" % [Catalysis.State.keys()[catalysis.state], Engine.time_scale])
	# Taln can still walk (clarified), but Draw and Shoulder presses do nothing.
	var draw_left: float = taln.toauma.draw_cooldown_left
	await _tap(&"draw")
	await _tap(&"shoulder")
	var rig: CameraRig = station.get_node("CameraRig")
	_check("During the window Draw and Shoulder do nothing, and a click can't recapture the mouse",
			taln.toauma.draw_cooldown_left == draw_left and not taln.shoulder.is_charging
			and taln.shoulder.cooldown_left == 0.0 and rig.capture_locked, "capture locked %s" % rig.capture_locked)
	await _tap(&"welcome")
	_check("Welcome (key 1) opens Catalyze: 9 s window, budget 9, still slowed", catalysis.state == Catalysis.State.CATALYZE
			and catalysis.budget_left == 9 and catalysis.window_left > 8.9 and catalysis.window_left <= 9.0
			and ui._catalyze.visible and ui.icon_skills() == taln.loadout.catalysts()
			and is_equal_approx(Engine.time_scale, 0.1), "window %.2f s, icons %s" % [catalysis.window_left,
			ui.icon_skills().map(func(s: SkillDef) -> StringName: return s.id)])


func _check_prompt_inputs() -> void:
	var results: Dictionary = {}
	# Bank by key 2, pad B (the bank action), and a click on Bank.
	for how: String in ["key 2", "click Bank", "click Welcome"]:
		await _fresh()
		var banked_before: int = meta.banked_agony
		await _fill()
		match how:
			"key 2":
				await _tap(&"bank")
			"click Bank":
				ui._bank.pressed.emit()
			"click Welcome":
				ui._welcome.pressed.emit()
		await _frames(1)
		if how == "click Welcome":
			results[how] = catalysis.state == Catalysis.State.CATALYZE
		else:
			results[how] = meta.banked_agony == banked_before + 1 and agony.value < EMPTY and not catalysis.is_open() \
					and Engine.time_scale == 1.0 and not taln.control_locked
	var pad: Dictionary = {}
	for action: StringName in [&"welcome", &"bank"]:
		var names: Array[int] = []
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				names.append((event as InputEventJoypadButton).button_index)
		pad[action] = names
	# A real pad B: it is Bank and also Shoulder. Banking must not charge.
	await _fresh()
	await _fill()
	var pad_b := InputEventJoypadButton.new()
	pad_b.button_index = JOY_BUTTON_B
	pad_b.pressed = true
	Input.parse_input_event(pad_b)
	await _frames(3)
	pad_b = InputEventJoypadButton.new()
	pad_b.button_index = JOY_BUTTON_B
	pad_b.pressed = false
	Input.parse_input_event(pad_b)
	await _ticks(3)
	var rig: CameraRig = station.get_node("CameraRig")
	results["pad B banks without a Shoulder"] = not catalysis.is_open() and meta.banked_agony == 1 \
			and not taln.shoulder.is_charging and taln.shoulder.cooldown_left == 0.0 and not rig.capture_locked
	var failed: Array = results.keys().filter(func(k: String) -> bool: return not results[k])
	_check("Welcome = 1 / pad A / click; Bank = 2 / pad B / click (ruled); banking empties the meter and restores time",
			failed.is_empty() and pad[&"welcome"] == [JOY_BUTTON_A] and pad[&"bank"] == [JOY_BUTTON_B],
			"failed %s; pad buttons %s" % [failed, pad])


func _check_prompt_timeout() -> void:
	await _fresh()
	await _fill()
	# Game time: physics still ticks 60 times a second, each tick scaled by the time scale.
	var game: Array[float] = [0.0]
	var counter := func() -> void: game[0] += get_root().get_physics_process_delta_time()
	physics_frame.connect(counter)
	var frames: int = 0
	while catalysis.is_open() and frames < 1000:
		await _frames(1)
		frames += 1
	physics_frame.disconnect(counter)
	# Headless frames run a little long (~2%), so allow 3%.
	_check("The prompt times out after 6 s of real time and banks (about 0.6 s passes in the slowed game)",
			absf(frames - 360.0) <= 11.0 and meta.banked_agony == 1 and catalysis.history[-1].choice == &"timeout_bank"
			and game[0] > 0.55 and game[0] < 0.65, "%d real frames (%.2f s), %.2f s of game time" % [frames, frames / 60.0, game[0]])


func _check_full_pause() -> void:
	await _fresh()
	var full: AgonyTuning = catalysis.tuning.duplicate()
	full.catalyze_full_pause = true
	catalysis.tuning = full
	await _fill()
	var paused_prompt: bool = paused and Engine.time_scale == 1.0
	await _tap(&"welcome")
	var paused_catalyze: bool = paused and catalysis.state == Catalysis.State.CATALYZE
	await _tap(&"catalyze_release")
	var frames: int = 0
	while catalysis.is_open() and frames < 700:
		await _frames(1)
		frames += 1
	# And a commit under the full pause shows its notches (the HUD runs through pauses).
	_bearer_level(5)
	await _fill()
	await _tap(&"welcome")
	catalysis.commit(_skill(&"settle"))
	await _frames(2)
	var notches: int = hud._segment_fills.filter(func(r: ColorRect) -> bool: return r.color == Hud.AGONY_SPENT).size()
	catalysis.release()
	await _frames(2)
	_check("Accessibility: catalyze_full_pause pauses fully instead of slowing time, for both windows; the HUD still shows commits",
			paused_prompt and paused_catalyze and not paused and meta.banked_agony == 1 and notches == 4,
			"prompt paused %s, Catalyze paused %s; expired after %d frames; %d notches consumed under the pause"
			% [paused_prompt, paused_catalyze, frames, notches])


# --- Catalyze -------------------------------------------------------------------

func _to_catalyze() -> void:
	await _fill()
	await _tap(&"welcome")


func _check_commit_hold() -> void:
	await _fresh()
	_bearer_level(5)  # Lesser 4, Greater 5: both fit a 9 budget, so nothing auto-fires.
	await _to_catalyze()
	var icon: Control = ui.icon_control(0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = icon.get_global_rect().get_center()
	icon.gui_input.emit(press)
	await _frames(30)
	var half_fill: float = ui._icon_fills[0].size.x / CatalyzeUi.ICON_SIZE.x
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.global_position = press.global_position
	icon.gui_input.emit(up)
	await _frames(2)
	var short: bool = catalysis.committed_skills.is_empty()
	icon.gui_input.emit(press)
	await _frames(40)
	icon.gui_input.emit(up)
	await _frames(1)
	var settle: SkillDef = _skill(&"settle")
	var committed: bool = catalysis.committed_skills == [settle] and catalysis.budget_left == 5
	var consumed: int = hud._segment_fills.filter(func(r: ColorRect) -> bool: return r.color == Hud.AGONY_SPENT).size()
	_check("Commit: hold the mouse on an icon 0.6 s real time; it fills in Agony hue, a shorter hold commits nothing",
			short and half_fill > 0.4 and half_fill < 0.95 and committed, "half-way fill %.2f; short hold committed nothing %s; full hold %s"
			% [half_fill, short, catalysis.committed_skills.map(func(s: SkillDef) -> StringName: return s.id)])
	_check("Its cost shows as notches consumed on the meter (HUD)", consumed == 4, "%d of 9 ninths consumed" % consumed)

	# Gamepad: focus the second icon and hold A; the A press that Welcomed doesn't count until A comes up.
	ui.icon_control(1).grab_focus()
	await _frames(1)
	Input.action_press(&"catalyze_commit")
	await _frames(40)
	Input.action_release(&"catalyze_commit")
	await _frames(1)
	_check("Commit with D-pad focus and A held 0.6 s (committing the last that fits fires)", catalysis.history[-1].choice == &"fire"
			and catalysis.history[-1].fired == [&"settle", &"breaking_stroke"], "%s" % [catalysis.history[-1]])

	await _fresh()
	_bearer_level(5)
	await _fill()
	Input.action_press(&"catalyze_commit")  # A held from before Welcome...
	await _tap(&"welcome")
	await _frames(60)
	var stale: bool = catalysis.committed_skills.is_empty()
	Input.action_release(&"catalyze_commit")
	await _frames(1)
	_check("An A still held from Welcoming doesn't commit", stale and catalysis.state == Catalysis.State.CATALYZE, "")


func _check_auto_fire() -> void:
	await _fresh()
	await _to_catalyze()
	catalysis.commit(_skill(&"settle"))  # 5 of 9: Breaking Stroke (7) no longer fits.
	await _frames(1)
	_check("Catalyze fires by itself when nothing uncommitted still fits the budget (ruled)", not catalysis.is_open()
			and catalysis.history[-1].choice == &"fire" and catalysis.history[-1].fired == [&"settle"]
			and agony.value < EMPTY and meta.banked_agony == 0 and Engine.time_scale == 1.0 and not taln.control_locked,
			"%s; meter %.0f, banked %d" % [catalysis.history[-1], agony.value, meta.banked_agony])


func _check_release_and_order() -> void:
	var results: Dictionary = {}
	for how: String in ["R", "click"]:
		await _fresh()
		_bearer_level(5)
		await _to_catalyze()
		catalysis.commit(_skill(&"settle"))
		var still_open: bool = catalysis.is_open()
		if how == "R":
			await _tap(&"catalyze_release")
		else:
			ui._release.pressed.emit()
			await _frames(1)
		results[how] = still_open and not catalysis.is_open() and catalysis.history[-1].fired == [&"settle"]
	var pad_y: bool = InputMap.action_get_events(&"catalyze_release").any(func(e: InputEvent) -> bool:
		return e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_Y)
	var failed: Array = results.keys().filter(func(k: String) -> bool: return not results[k])
	_check("Release = R / pad Y / click fires what's committed; unspent ninths are discarded", failed.is_empty() and pad_y
			and meta.banked_agony == 0 and agony.value < EMPTY, "failed %s, Y bound %s" % [failed, pad_y])

	await _fresh()
	_bearer_level(5)
	await _to_catalyze()
	catalysis.commit(_skill(&"breaking_stroke"))
	catalysis.commit(_skill(&"settle"))
	await _frames(1)
	_check("Committed Cataclysms fire together, cheapest tier first", catalysis.history[-1].fired == [&"settle", &"breaking_stroke"],
			"committed Stroke then Settle; fired %s" % [catalysis.history[-1].fired])


func _check_catalyze_expiry() -> void:
	await _fresh()
	await _to_catalyze()
	var frames: int = 0
	while catalysis.is_open() and frames < 1000:
		await _frames(1)
		frames += 1
	var banked_empty: bool = catalysis.history[-1].choice == &"catalyze_bank" and meta.banked_agony == 1
	await _fresh()
	_bearer_level(5)
	await _to_catalyze()
	catalysis.commit(_skill(&"settle"))
	frames = 0
	while catalysis.is_open() and frames < 1000:
		await _frames(1)
		frames += 1
	_check("Catalyze runs 9 s real: expiring with nothing committed banks; with something committed it fires (clarified)",
			banked_empty and absf(frames - 540.0) <= 16.0 and catalysis.history[-1].choice == &"fire" and meta.banked_agony == 0,
			"empty expiry banked %s; committed expiry after %d frames fired %s" % [banked_empty, frames, catalysis.history[-1].fired])


func _check_cataclysms() -> void:
	await _fresh()
	taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT  # The flashes fade in the behaviors' own frames.
	swarm.set_target(null)
	var inside: Array[int] = []
	var outside: Array[int] = []
	for k in 8:
		var dir := Vector3(cos(k * 0.785), 0.0, sin(k * 0.785))
		inside.append(swarm.spawn(ash, OPEN + dir * 8.0, 10.0, 1.0))  # 120 HP: survives 40.
		outside.append(swarm.spawn(ash, OPEN + dir * 11.0, 10.0, 1.0))
	# Exactly 40 HP dies to the 40 damage; 40.8 HP lives.
	var exact: int = swarm.spawn(ash, OPEN + Vector3(0.0, 0.0, 4.0), 40.0 / 12.0, 1.0)
	var over: int = swarm.spawn(ash, OPEN + Vector3(0.0, 0.0, -4.0), 3.4, 1.0)
	var died: Array[int] = [0]
	swarm.enemy_died.connect(func(_id: StringName, _at: Vector3, _r: bool) -> void: died[0] += 1)
	taln.loadout.get_behavior(&"settle").cataclysm()
	var rooted: bool = inside.all(func(i: int) -> bool: return is_equal_approx(swarm.get_enemy_root_time(i), 3.0))
	var spared: bool = outside.all(func(i: int) -> bool: return swarm.get_enemy_root_time(i) == 0.0)
	var cracks: MeshInstance3D = taln.loadout.get_behavior(&"settle").get_node("CataclysmCracks")
	var flashed: bool = cracks.visible
	await _ticks(45)
	var faded: bool = not cracks.visible
	_check("Settle's Cataclysm: 40 Kinetic and a 3 s root all round within 9 m, nothing beyond; its flash is gone within 0.75 s",
			rooted and spared and died[0] == 1 and not swarm.is_enemy_alive(exact) and swarm.is_enemy_alive(over)
			and flashed and faded, "40 HP one died %s, 40.8 HP one lives %s; 8 within rooted %s, 8 beyond untouched %s; flash %s then %s"
			% [not swarm.is_enemy_alive(exact), swarm.is_enemy_alive(over), rooted, spared, flashed, not faded])

	await _fresh()
	taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT
	taln.global_position = CLEAR
	await _ticks(2)
	swarm.set_target(null)
	var near: int = swarm.spawn(ash, CLEAR + Vector3(5.0, 0.0, 0.0), 5.0, 1.0)  # 60 HP: dies to 80.
	var tough: int = swarm.spawn(ash, CLEAR + Vector3(0.0, 0.0, 5.0), 10.0, 1.0)  # 120 HP: pushed.
	var tough_at: Vector3 = swarm.get_enemy_position(tough)
	var far: int = swarm.spawn(ash, CLEAR + Vector3(-11.0, 0.0, 0.0), 1.0, 1.0)
	taln.loadout.get_behavior(&"breaking_stroke").cataclysm()
	await _ticks(90)
	var pushed: float = Vector2(swarm.get_enemy_position(tough).x - tough_at.x, swarm.get_enemy_position(tough).z - tough_at.z).length()
	var ring: MeshInstance3D = taln.loadout.get_behavior(&"breaking_stroke").get_node("CataclysmRing")
	_check("Breaking Stroke's Cataclysm: 80 Kinetic within 9 m and knockback 12 ÷ mass; its ring is gone within 0.3 s",
			not swarm.is_enemy_alive(near) and swarm.is_enemy_alive(tough) and absf(pushed - 12.0) < 0.3
			and swarm.is_enemy_alive(far) and not ring.visible, "60 HP one dead %s, 120 HP one pushed %.2f m, one at 11 m alive %s"
			% [not swarm.is_enemy_alive(near), pushed, swarm.is_enemy_alive(far)])


# --- visuals, HUD, bot, performance ---------------------------------------------

func _check_body() -> void:
	await _fresh()
	catalysis.hold(&"checks", true)
	var body: AgonyBody = taln.get_node("AgonyBody")
	var steps: Array[int] = []
	var energies: Array[float] = []
	for value: float in [100.0, 300.0, 500.0, 700.0, 900.0]:
		agony.value = value
		agony.is_locked = value >= 900.0
		await _frames(2)
		steps.append(body.step())
		energies.append((taln.get_node("Body") as MeshInstance3D).material_override.emission_energy_multiplier)
	var vignette: bool = (taln.get_node("AgonyVignette/Vignette") as ColorRect).visible
	var saturation: float = taln.get_world_3d().environment.adjustment_saturation
	var rising: bool = energies[0] == 0.0 and energies[1] > 0.0 and energies[2] > energies[1] \
			and energies[3] > energies[2] and energies[4] > energies[3]
	_check("Agony on Taln's body (Art Direction table): none <25%, then stepped emissive glow at 25/50/75/100%; vignette and desaturation at 100%",
			steps == [0, 1, 2, 3, 4] and rising and vignette and saturation < 1.0,
			"steps %s, energies %s, vignette %s, saturation %.2f" % [steps, energies.map(func(e: float) -> String: return "%.2f" % e),
			vignette, saturation])
	agony.empty()
	catalysis.hold(&"checks", false)
	await _fill()
	await _tap(&"welcome")
	var charging: bool = body.charge_left > 0.0
	await _fresh()
	body = taln.get_node("AgonyBody")
	await _fill()
	await _tap(&"bank")
	var pulling: bool = body.pull_left > 0.0
	_check("Welcome plays a brief charge-up, Bank a brief inward pull", charging and pulling
			and body.charge_time <= 0.5 and body.pull_time <= 0.5, "charge %.2f s, pull %.2f s" % [body.charge_time, body.pull_time])


func _check_hud_meter() -> void:
	await _fresh()
	agony.set_suspended(&"checks", true)  # Hold the reading still.
	agony.value = 250.0
	await _frames(2)
	var full: int = hud._segment_fills.filter(func(r: ColorRect) -> bool: return is_equal_approx(r.size.x, Hud.SEGMENT_SIZE.x)).size()
	var half: bool = is_equal_approx(hud._segment_fills[2].size.x, Hud.SEGMENT_SIZE.x * 0.5)
	_check("HUD: the Agony meter in 9 segments with notches, filling in Agony hue", hud._segments.size() == 9 and full == 2
			and half and hud._segment_fills[0].color == Hud.AGONY, "%d full, third half %s" % [full, half])
	agony.set_suspended(&"checks", false)


func _check_bot() -> void:
	await _fresh()
	var bot := KiteBot.new()
	bot.taln = taln
	bot.swarm = swarm
	bot.ground = station.get_node("StationGround")
	bot.camera_rig = station.get_node("CameraRig")
	bot.menu = station.get_node("LevelUpMenu")
	bot.well = station.get_node("Well")
	bot.catalysis = catalysis
	bot.welcome_every = 1
	station.add_child(bot)
	await _fill()
	var frames: int = 0
	while catalysis.is_open() and frames < 400:
		await _frames(1)
		frames += 1
	_check("KiteBot answers a prompt: Welcomes, holds A on the cheapest catalyst, and it fires", not catalysis.is_open()
			and catalysis.history[-1].choice == &"fire" and catalysis.history[-1].fired == [&"settle"],
			"%s after %d frames" % [catalysis.history[-1], frames])
	bot.queue_free()
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"catalyze_commit"]:
		Input.action_release(action)


func _check_performance() -> void:
	await _fresh()
	taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT
	var ground: StationGround = station.get_node("StationGround")
	var samples: PackedFloat32Array = []
	var k: int = 0
	for f in 900:
		while swarm.get_alive_count() < 400:
			var angle: float = k * 2.39996
			var at: Vector3 = taln.global_position + Vector3(cos(angle), 0.0, sin(angle)) * (3.0 + fmod(k * 0.37, 23.0))
			k += 1
			if not ground.is_blocked_at(at.x, at.z):
				swarm.spawn(ash, at, 1.0, 1.0)
		var before: int = Time.get_ticks_usec()
		await _ticks(1)
		samples.append((Time.get_ticks_usec() - before) / 1000.0)
	var total: float = 0.0
	for ms in samples:
		total += ms
	var sorted: PackedFloat32Array = samples.duplicate()
	sorted.sort()
	_check("400 alive with the Agony meter's Pressed query every tick: frame fits 60 fps (CPU side), step < 2 ms",
			total / samples.size() < 4.0 and sorted[int(sorted.size() * 0.99)] < 4.0 and swarm.get_last_step_ms() < 2.0,
			"avg %.3f ms, p99 %.3f ms; Agony %.0f (%s)" % [total / samples.size(), sorted[int(sorted.size() * 0.99)],
			agony.value, "Pressed" if agony.is_pressed() else "not Pressed"])
