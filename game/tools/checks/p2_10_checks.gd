extends SceneTree
## P2-10 (the Braize slice: windowed flow field, regions, the breaker siege
## stand-in, the gate, Aspects) checks, run headless against the real slice
## scene at a fixed 60 fps. Prints PASS/FAIL per check and exits with the
## number of failures. Meta state goes to user://checks_meta.json; telemetry
## for the one check that records goes to user://checks_telemetry_p2_10.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_10_checks.gd

const SLICE := "res://scenes/braize_slice.tscn"
const STATION := "res://scenes/graybox_station.tscn"
const ASH_WALKER := "res://data/swarm/ash_walker.tres"
const NOTICE_HUNTER := "res://data/swarm/notice_hunter.tres"
const CHECKS_META := "user://checks_meta.json"
const CHECKS_TELEMETRY := "user://checks_telemetry_p2_10"
## Open ground in each tier, clear of features and sites.
const SHELF_OPEN := Vector3(60.0, 0.0, 112.0)
const DESCENT_OPEN := Vector3(0.0, 0.0, 20.0)
const COUNT_OPEN := Vector3(-60.0, 0.0, -100.0)
## Passage centers through the ridges.
const SHELF_PASSAGE := Vector3(0.0, 0.0, 43.0)
const SHORTCUT_PASSAGE := Vector3(40.0, 0.0, -43.0)
const WEST_PASSAGE := Vector3(-108.0, 0.0, -43.0)
## Just north of the gate blocker: the swarm can't step there while the blocker stands.
const GATE_CELL := Vector3(40.0, 0.0, -45.5)

var station: GrayboxStation
## The station as the slice; null while another scene is loaded.
var slice: BraizeSlice
var taln: Taln
var swarm: SwarmServer
var spawner: SpawnDirector
var ground: StationGround
var well: Well
var hud: Hud
var screen: BetweenRunScreen
var cycle: Cycle
var meta: Meta
var failures: int = 0


func _init() -> void:
	_run()


func _run() -> void:
	await _frames(2)
	meta = Meta.state()
	meta.redirect(CHECKS_META)
	meta.wipe()
	cycle = Cycle.director()
	_check_data()
	print("")
	await _check_window()
	await _check_window_recenter()
	await _check_outside_window()
	await _check_despawn()
	await _check_old_station_window()
	print("")
	await _check_cycle_start()
	await _check_endless_clock()
	await _check_spawn_area()
	await _check_siege()
	await _check_siege_freeze()
	await _check_breaker_fell()
	await _check_enter_region()
	await _check_held()
	print("")
	_check_kit_data()
	await _check_kit_offer()
	await _check_kit_draw()
	await _check_kit_skills()
	print("")
	await _check_gate()
	await _check_meta_file()
	await _check_screen()
	await _check_aspects()
	await _check_telemetry()
	await _check_start_screen()
	print("")
	print("MANUAL  Roaming the slice (scale, the beacons through fog, the seals and the gate, the siege) needs a rendered recording.")
	print("")
	meta.wipe()
	paused = false
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


func _frames(count: int) -> void:
	for i in count:
		await process_frame


## A fresh slice (or another scene) with the spawner paused and Taln at at.
func _fresh(at: Vector3 = SHELF_OPEN, scene: String = SLICE) -> void:
	paused = false
	if is_instance_valid(station):
		station.queue_free()
		await _frames(1)
	_bind((load(scene) as PackedScene).instantiate())
	root.add_child(station)
	spawner.paused = true
	taln.loadout.process_mode = Node.PROCESS_MODE_DISABLED
	# These checks predate Awareness (P2-13): the swarm hunts Taln wherever he is.
	var awareness: Awareness = station.get_node_or_null("Awareness")
	if awareness:
		awareness.enabled = false
	await ground.ground_changed
	_place(at)
	await _ticks(2)


func _bind(new_station: GrayboxStation) -> void:
	station = new_station
	slice = station as BraizeSlice
	taln = station.get_node("Taln")
	swarm = station.get_node("SwarmServer")
	spawner = station.get_node("SpawnDirector")
	ground = station.get_node("StationGround")
	well = station.get_node("Well")
	hud = station.get_node("Hud")
	screen = station.get_node("BetweenRunScreen")


func _place(at: Vector3) -> void:
	taln.global_position = Vector3(at.x, ground.get_surface_height_at(at.x, at.z), at.z)
	taln.velocity = Vector3.ZERO


func _cell_of(at: Vector3) -> Vector2i:
	var origin: Vector2 = ground.get_origin()
	return Vector2i(floori((at.x - origin.x) / ground.get_cell_size()), floori((at.z - origin.y) / ground.get_cell_size()))


## Breaks the current region's breaker at once: start its siege, then end it.
## Unless leave_drop, a drop it offers is taken (the first option) so play resumes.
func _fell_current(leave_drop: bool = false) -> void:
	_place(slice.current.site.global_position)
	await _ticks(2)
	slice.siege_left = 0.01
	await _ticks(2)
	var menu: KitOfferMenu = station.get_node("KitOfferMenu")
	await _frames(2)
	if menu.is_open and not leave_drop:
		await _frames(15)
		menu.pick(0)
		await _ticks(1)


# --- data --------------------------------------------------------------------

func _check_data() -> void:
	var st: SwarmTuning = load("res://data/tuning/swarm_tuning.tres")
	_check("Flow window 128 cells with a 24-cell margin; swarm-tier despawn at 70 m (spec v1.4 #5)",
			st.flow_window_cells == 128 and st.flow_window_margin == 24 and st.despawn_distance == 70.0,
			"%d, %d, %.0f m" % [st.flow_window_cells, st.flow_window_margin, st.despawn_distance])
	var rt: RegionTuning = load("res://data/tuning/region_tuning.tres")
	_check("Siege stand-in: site radius 4.5 m, 60 s at 2x budget, a 9-hunter pack living 90 s, breaker income 270",
			rt.site_radius == 4.5 and rt.siege_seconds == 60.0 and rt.siege_budget_scale == 2.0
			and rt.siege_pack_type == load(NOTICE_HUNTER) and rt.siege_pack_size == 9 and rt.siege_pack_lifetime == 90.0
			and rt.breaker_income == 270.0, "%.1f m, %.0f s, x%.1f, %d for %.0f s, %.0f" % [rt.site_radius,
			rt.siege_seconds, rt.siege_budget_scale, rt.siege_pack_size, rt.siege_pack_lifetime, rt.breaker_income])
	var gate: GateDef = load("res://data/map/shortcut_gate.tres")
	_check("The shortcut gate costs 3 banked Agony", gate.cost == 3 and gate.id == &"descent_shortcut", "%d" % gate.cost)
	var ct: CycleTuning = load("res://data/tuning/cycle_tuning.tres")
	var ids: Array = ct.aspects.map(func(a: AspectDef) -> StringName: return a.id)
	_check("Cycles load the slice; Aspects Earthshaper (default), Meteor, Doomhunter (Shade and Bastion), Plaguebringer and Unaspected",
			ct.station_scene == SLICE and ids == [&"earthshaper", &"meteor", &"doomhunter_shade", &"doomhunter_bastion",
			&"plaguebringer", &"unaspected"] and ct.default_aspect.id == &"earthshaper",
			"%s, %s, default %s" % [ct.station_scene, ids, ct.default_aspect.id])
	var earth: AspectDef = ct.aspects[0]
	var bare: AspectDef = ct.aspects[5]
	var kit := func(a: AspectDef) -> Array: return a.starting_skills.map(func(s: SkillDef) -> StringName: return s.id)
	_check("Unaspected starts with Breaking Stroke and Settle and neither Anchors nor Fractures; Earthshaper (its own kit since P2-11) has both (spec v1.4 #2)",
			kit.call(bare) == [&"breaking_stroke", &"settle"] and kit.call(earth)[0] == &"breaking_stroke"
			and earth.anchored and earth.fracture and not bare.anchored and not bare.fracture,
			"%s %s/%s, %s %s/%s" % [kit.call(earth), earth.anchored, earth.fracture, kit.call(bare), bare.anchored, bare.fracture])
	var wt: WellPoolTuning = load("res://data/tuning/well_pool_tuning.tres")
	_check("New pool spots stay within 60 m of Taln", wt.max_distance_taln == 60.0, "%.0f m" % wt.max_distance_taln)


# --- flow window -------------------------------------------------------------

func _check_window() -> void:
	await _fresh()
	await _ticks(4)
	var window: Rect2i = swarm.get_flow_window()
	var cell: Vector2i = _cell_of(taln.global_position)
	var ok: bool = window.size == Vector2i(128, 128) and Rect2i(0, 0, 256, 256).encloses(window) \
			and window.has_point(cell) and swarm.get_flow_goal_cell() == cell
	_check("On the 256 m slice the flow field covers a 128-cell window holding Taln's cell, and its goal is his cell",
			ok, "window %s, Taln cell %s, goal %s" % [window, cell, swarm.get_flow_goal_cell()])


func _check_window_recenter() -> void:
	await _fresh(DESCENT_OPEN)
	await _ticks(4)
	var first: Rect2i = swarm.get_flow_window()
	var count: int = swarm.get_flow_recenter_count()
	# A few meters: well inside the margin, so no recenter.
	_place(DESCENT_OPEN + Vector3(6.0, 0.0, 0.0))
	await _ticks(6)
	var held: bool = swarm.get_flow_window() == first and swarm.get_flow_recenter_count() == count
	# Across the region: past the margin, so it recenters on Taln.
	var far := Vector3(-100.0, 0.0, 20.0)
	_place(far)
	await _ticks(6)
	var moved: Rect2i = swarm.get_flow_window()
	var cell: Vector2i = _cell_of(taln.global_position)
	var ok: bool = held and moved != first and moved.has_point(cell) and swarm.get_flow_goal_cell() == cell \
			and swarm.get_flow_recenter_count() == count + 1 and moved.position.x == 0
	_check("The window holds while Taln stays clear of its margin, and recenters (clamped to the ground) when he nears an edge",
			ok, "held %s; %s → %s, goal %s at Taln's %s, recenters %d → %d" % [held, first, moved,
			swarm.get_flow_goal_cell(), cell, count, swarm.get_flow_recenter_count()])


func _check_outside_window() -> void:
	await _fresh(DESCENT_OPEN)
	await _ticks(4)
	var window: Rect2i = swarm.get_flow_window()
	# 66 m east of Taln: outside the window (it ends 64 cells out) but inside despawn range.
	var at := Vector3(DESCENT_OPEN.x + 66.0, 0.0, DESCENT_OPEN.z)
	var slot: int = swarm.spawn(load(ASH_WALKER), at, 1.0, 1.0)
	var before: float = Vector2(at.x - taln.global_position.x, at.z - taln.global_position.z).length()
	await _ticks(60)
	var p: Vector3 = swarm.get_enemy_position(slot)
	var after: float = Vector2(p.x - taln.global_position.x, p.z - taln.global_position.z).length()
	var outside: bool = not window.has_point(_cell_of(at))
	_check("An enemy outside the window seeks Taln directly and closes in", outside and swarm.is_enemy_alive(slot)
			and after < before - 2.0, "outside %s; %.1f m → %.1f m" % [outside, before, after])


func _check_despawn() -> void:
	await _fresh(DESCENT_OPEN)
	var died: Array = []
	swarm.enemy_died.connect(func(id: StringName, _at: Vector3, rewarded: bool) -> void: died.append([id, rewarded]))
	var far := Vector3(DESCENT_OPEN.x - 90.0, 0.0, DESCENT_OPEN.z)
	var walker: int = swarm.spawn(load(ASH_WALKER), far, 1.0, 1.0)
	var hunter: int = swarm.spawn(load(NOTICE_HUNTER), far + Vector3(0.0, 0.0, 4.0), 1.0, 1.0)
	await _ticks(4)
	var kills_before: int = slice.kills
	_check("A swarm-tier enemy left 90 m behind is removed unrewarded; an elite isn't",
			not swarm.is_enemy_alive(walker) and swarm.is_enemy_alive(hunter) and died == [[&"ash_walker", false]]
			and slice.kills == kills_before, "walker alive %s, hunter alive %s, deaths %s" % [swarm.is_enemy_alive(walker),
			swarm.is_enemy_alive(hunter), died])


func _check_old_station_window() -> void:
	await _fresh(Vector3(40.0, 0.0, 30.0), STATION)
	await _ticks(4)
	var window: Rect2i = swarm.get_flow_window()
	var count: int = swarm.get_flow_recenter_count()
	taln.global_position = Vector3(-50.0, 0.0, -50.0)
	await _ticks(6)
	_check("On the 128 m gray-box station the window is the whole ground and never moves", window == Rect2i(0, 0, 128, 128)
			and swarm.get_flow_window() == window and swarm.get_flow_recenter_count() == count,
			"%s, recenters %d → %d" % [window, count, swarm.get_flow_recenter_count()])


# --- regions and the siege ---------------------------------------------------

func _check_cycle_start() -> void:
	await _fresh()
	await _frames(2)
	var shelf: Region = slice.current
	var ok: bool = shelf.id == &"the_shelf" and shelf.tier == 1 and slice.state == BraizeSlice.State.EXPLORING \
			and slice.station_index() == 0 and spawner.endless and spawner.area == shelf.bounds and well.area == shelf.bounds \
			and slice.regions.all(func(r: Region) -> bool: return r.tier == 3 or r.seals_closed()) \
			and slice.gates.size() == 1 and slice.gates[0].is_closed() \
			and ground.is_blocked_at(SHELF_PASSAGE.x, SHELF_PASSAGE.z) and ground.is_blocked_at(GATE_CELL.x, GATE_CELL.z)
	var lines: PackedStringArray = hud._wave.text.split("\n")
	var hud_ok: bool = lines.size() == 2 and lines[0] == "The Shelf   Tier 1   Clock 1" \
			and lines[1].begins_with("Breaker site  %d m  " % roundi(slice.distance_to_site()))
	_check("A cycle starts in The Shelf (Tier I, station 1) with an endless clock, spawns and pools kept to the region, every seal and the gate shut",
			ok, "%s tier %d, state %d, station %d, endless %s, area %s, seals blocked %s, gate blocked %s"
			% [shelf.id, shelf.tier, slice.state, slice.station_index(), spawner.endless, spawner.area,
			ground.is_blocked_at(SHELF_PASSAGE.x, SHELF_PASSAGE.z), ground.is_blocked_at(GATE_CELL.x, GATE_CELL.z)])
	_check("HUD: region, tier and clock, then the distance and direction to the breaker site", hud_ok, "'%s'" % hud._wave.text.c_escape())


func _check_endless_clock() -> void:
	await _fresh()
	spawner.tuning = spawner.tuning.duplicate()
	spawner.tuning.wave_length = 0.25
	var done: Array = []
	spawner.waves_done.connect(func() -> void: done.append(true))
	spawner.paused = false
	await _ticks(60 * 3 + 10)
	spawner.paused = true
	_check("The clock keeps rising past wave 9 and never ends the station", spawner.wave >= 11 and done.is_empty()
			and slice.state == BraizeSlice.State.EXPLORING, "wave index %d, waves_done %d" % [spawner.wave, done.size()])


func _check_spawn_area() -> void:
	await _fresh(Vector3(0.0, 0.0, 52.0))  # By the sealed passage, so half the ring lies across the ridge.
	var outside: Array[Vector3] = []
	var spawned: Array[int] = [0]
	spawner.spawned.connect(func(_slot: int, at: Vector3) -> void:
		spawned[0] += 1
		if not slice.current.bounds.has_point(Vector2(at.x, at.z)):
			outside.append(at))
	spawner.stress = true
	spawner.paused = false
	await _ticks(120)
	spawner.paused = true
	spawner.stress = false
	_check("Spawns land only inside the region Taln stands in", spawned[0] > 20 and outside.is_empty(),
			"%d spawned, %d outside" % [spawned[0], outside.size()])


func _check_siege() -> void:
	await _fresh()
	var began: Array = []
	slice.siege_began.connect(func(r: Region) -> void: began.append(r.id))
	var alive_before: int = swarm.get_alive_count()
	_place(slice.current.site.global_position + Vector3(3.0, 0.0, 0.0))
	await _ticks(2)
	var hunters: int = swarm.get_alive_count() - alive_before
	await _frames(2)
	var ok: bool = slice.state == BraizeSlice.State.SIEGE and began == [&"the_shelf"] and spawner.budget_scale == 2.0 \
			and taln.agony.breaker_active and hunters == 9 and slice.current.site.state == BreakerSite.State.SIEGE
	_check("Walking into the breaker site starts its siege: 2x budget, the breaker Agony gain, a 9-hunter pack",
			ok, "state %d, began %s, budget x%.1f, breaker Agony %s, %d hunters" % [slice.state, began,
			spawner.budget_scale, taln.agony.breaker_active, hunters])
	_check("HUD shows the siege's time left", hud._wave.text.ends_with("Siege  60 s") or hud._wave.text.ends_with("Siege  59 s"),
			"'%s'" % hud._wave.text.c_escape())


func _check_siege_freeze() -> void:
	await _fresh()
	_place(slice.current.site.global_position)
	await _ticks(2)
	var left: float = slice.siege_left
	spawner.frozen = true
	await _ticks(30)
	var frozen_left: float = slice.siege_left
	spawner.frozen = false
	await _ticks(30)
	_check("The siege clock holds while the Return freezes the world, and runs otherwise",
			is_equal_approx(frozen_left, left) and slice.siege_left < left - 0.4,
			"%.2f → %.2f frozen → %.2f" % [left, frozen_left, slice.siege_left])


func _check_breaker_fell() -> void:
	await _fresh()
	var lulls: Array = []
	cycle.lull_began.connect(func(i: int) -> void: lulls.append(i), CONNECT_ONE_SHOT)
	var before: float = taln.investiture.current
	await _fell_current()
	var paid: float = taln.investiture.income_by_source.get(&"breaker", 0.0)
	await _ticks(3)  # The ground resamples the cleared cells.
	var ok: bool = slice.state == BraizeSlice.State.FALLEN and is_equal_approx(paid, 270.0) \
			and taln.investiture.current >= before + 270.0 and not slice.current.seals_closed() \
			and not ground.is_blocked_at(SHELF_PASSAGE.x, SHELF_PASSAGE.z) and spawner.lull and spawner.budget_scale == 1.0 \
			and not taln.agony.breaker_active and lulls == [0] and slice.current.site.state == BreakerSite.State.FALLEN
	_check("Holding the siege fells the breaker: 270 x v breaker income, the seals open (swarm cells too), the spawner drops to a lull",
			ok, "state %d, paid %.0f, seals %s, passage blocked %s, lull %s, lulls %s" % [slice.state, paid,
			slice.current.seals_closed(), ground.is_blocked_at(SHELF_PASSAGE.x, SHELF_PASSAGE.z), spawner.lull, lulls])
	_check("HUD says the seals are open", hud._wave.text.ends_with("Seals open: Tier 2 ahead"), "'%s'" % hud._wave.text.c_escape())


func _check_enter_region() -> void:
	await _fresh()
	await _fell_current()
	var began: Array = []
	cycle.station_began.connect(func(i: int) -> void: began.append(i), CONNECT_ONE_SHOT)
	_place(DESCENT_OPEN)
	await _ticks(3)
	var descent: Region = slice.current
	var pools_in: bool = true
	for p: WellPool in well.pools():
		var at := Vector2(p.global_position.x, p.global_position.z)
		pools_in = pools_in and descent.bounds.has_point(at) \
				and at.distance_to(Vector2(taln.global_position.x, taln.global_position.z)) <= 60.0
	var ok: bool = descent.id == &"ninefold_descent" and slice.state == BraizeSlice.State.EXPLORING \
			and slice.station_index() == 1 and spawner.station_index == 1 and spawner.wave == 0 and not spawner.lull \
			and spawner.area == descent.bounds and began == [1] and pools_in
	_check("Walking into the Tier II region starts its clock at station 2 (v, S, D, P) and moves the pools into it",
			ok, "%s, state %d, station %d, wave %d, lull %s, station_began %s, pools in region %s" % [descent.id,
			slice.state, slice.station_index(), spawner.wave, spawner.lull, began, pools_in])
	# Walking back into The Shelf doesn't lower the tier.
	_place(SHELF_OPEN)
	await _ticks(3)
	_check("Walking back into a shallower region keeps the deeper tier", slice.current == descent and slice.station_index() == 1,
			"%s, station %d" % [slice.current.id, slice.station_index()])


func _check_held() -> void:
	await _fresh()
	var ended: Array = []
	cycle.cycle_ended.connect(func(o: Cycle.Outcome, _s: Dictionary) -> void: ended.append(o), CONNECT_ONE_SHOT)
	await _fell_current()
	_place(DESCENT_OPEN)
	await _ticks(3)
	await _fell_current()
	await _ticks(3)  # The ground resamples the cleared cells.
	var both_open: bool = not ground.is_blocked_at(WEST_PASSAGE.x, WEST_PASSAGE.z) \
			and not ground.is_blocked_at(SHORTCUT_PASSAGE.x, SHORTCUT_PASSAGE.z)
	var gate_shut: bool = ground.is_blocked_at(GATE_CELL.x, GATE_CELL.z)
	_place(COUNT_OPEN)
	await _ticks(3)
	var deepest: bool = slice.current.tier == 3 and slice.station_index() == 2
	await _fell_current()
	await _frames(2)
	_check("The Tier II breaker opens both its seals (the gate still shuts the shortcut); the Tier III breaker ends the cycle Held",
			both_open and gate_shut and deepest and ended == [Cycle.Outcome.HELD],
			"seals open %s, gate shut %s, reached Tier III %s, ended %s" % [both_open, gate_shut, deepest, ended])
	paused = false


# --- the breaker drop -----------------------------------------------------------

func _check_kit_data() -> void:
	var rt: RegionTuning = load("res://data/tuning/region_tuning.tres")
	var ids: Array = rt.breaker_offer_pool.map(func(sk: SkillDef) -> StringName: return sk.id)
	var kinds: Array = rt.breaker_offer_pool.map(func(sk: SkillDef) -> int: return sk.kind)
	var defined: bool = rt.breaker_offer_pool.all(func(sk: SkillDef) -> bool:
		return sk.level_params.size() == 9 and sk.behavior != null)
	_check("Breaker drop: 3 offered from a 6-skill placeholder pool (2 Weapons, 2 Surges, 2 Perks; Settle joined it in P2-11), each defined to level 9",
			rt.breaker_offer_size == 3 and ids == [&"shardfall", &"tremor", &"upheave", &"stone_skin", &"second_wind", &"settle"]
			and kinds == [0, 0, 1, 2, 2, 1] and defined, "%d of %s, kinds %s, defined %s" % [rt.breaker_offer_size, ids, kinds, defined])


func _check_kit_offer() -> void:
	meta.wipe()
	await _fresh()
	var menu: KitOfferMenu = station.get_node("KitOfferMenu")
	var shown: Array = []
	menu.opened.connect(func(offer: Array[SkillDef]) -> void: shown.append(offer.duplicate()))
	await _fell_current(true)
	var offer: Array = shown[0] if not shown.is_empty() else []
	var pool: Array[SkillDef] = slice.region_tuning.breaker_offer_pool
	var distinct: bool = offer.size() == 3 and offer.all(func(sk: SkillDef) -> bool:
		return pool.has(sk) and offer.count(sk) == 1)
	var texts: Array[String] = menu.option_texts()
	var opened: bool = menu.is_open and paused and distinct and texts.size() == 3 \
			and texts[0] == "1   %s   %s" % [offer[0].display_name, UiText.KIT_KINDS[offer[0].kind]]
	_check("A felled Tier I breaker offers 3 distinct pool skills Taln doesn't own, in a paused menu",
			opened, "open %s, paused %s, offer %s, '%s'" % [menu.is_open, paused,
			offer.map(func(sk: SkillDef) -> StringName: return sk.id), texts[0] if not texts.is_empty() else ""])
	var early: bool = not menu.pick(0)
	await _frames(15)
	var taken: SkillDef = offer[1] if offer.size() > 1 else null
	var took: bool = menu.pick(1)
	await _frames(1)
	var ok: bool = early and took and taln.loadout.has_skill(taken.id) and taln.loadout.get_level(taken.id) == 1 \
			and not paused and not menu.is_open and not taln.loadout.has_skill(offer[0].id)
	_check("Taking one (after the input delay) adds it at level 1 and resumes play; the others aren't taken",
			ok, "early pick refused %s, took %s, owns %s at %d, paused %s" % [early, took, taken.id if taken else &"",
			taln.loadout.get_level(taken.id) if taken else 0, paused])
	# The Tier II drop never offers what Taln owns; the Tier III breaker ends the cycle with no drop.
	shown.clear()
	_place(DESCENT_OPEN)
	await _ticks(3)
	await _fell_current()
	var second: Array = shown[0] if not shown.is_empty() else []
	var fresh_only: bool = second.size() == 3 and not second.has(taken)
	shown.clear()
	_place(COUNT_OPEN)
	await _ticks(3)
	await _fell_current()
	await _frames(3)
	_check("The Tier II drop leaves out what Taln owns; the Tier III breaker ends the cycle with no drop",
			fresh_only and shown.is_empty() and cycle.outcome == Cycle.Outcome.HELD,
			"second offer %s, Tier III offers %d, outcome %d" % [second.map(func(sk: SkillDef) -> StringName: return sk.id),
			shown.size(), cycle.outcome])
	paused = false


func _check_kit_draw() -> void:
	meta.set_aspect(&"unaspected")  # Two starting skills leave room for the pool.
	await _fresh()
	var pool: Array[SkillDef] = slice.region_tuning.breaker_offer_pool
	for i in 4:  # Settle, the pool's sixth, is already Unaspected's.
		taln.loadout.add_skill(pool[i])
	var last: Array[SkillDef] = slice.draw_offer()
	var filler: Array[SkillDef] = []
	for i in 9:
		var sk := SkillDef.new()
		sk.id = StringName("filler_%d" % i)
		sk.kind = SkillDef.Kind.PERK
		filler.append(sk)
	await _fresh()
	for sk in filler:
		taln.loadout.add_skill(sk)
	var full: Array[SkillDef] = slice.draw_offer()
	_check("The draw offers fewer when fewer are unowned, and nothing once every slot is taken",
			last == [pool[4]] and full.is_empty() and taln.loadout.is_full(), "one left %s, full %s" % [
			last.map(func(sk: SkillDef) -> StringName: return sk.id), full.size()])


func _check_kit_skills() -> void:
	meta.set_aspect(&"unaspected")  # A kit with a free Surge binding for Upheave.
	await _fresh(DESCENT_OPEN)
	var pool: Array[SkillDef] = slice.region_tuning.breaker_offer_pool
	var ash: SwarmType = load(ASH_WALKER)
	taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT
	# Shardfall: an enemy 10 m out, beyond Breaking Stroke's reach.
	taln.loadout.add_skill(pool[0])
	var shard: Shardfall = taln.loadout.get_behavior(&"shardfall")
	var shard_hits: Array = [0]
	shard.struck.connect(func(_at: Vector3, hits: int) -> void: shard_hits[0] += hits)
	var far: int = swarm.spawn(ash, taln.global_position + Vector3(10.0, 0.0, 0.0), 100.0, 1.0)
	swarm.set_frozen(true)
	await _ticks(10)
	_check("Shardfall strikes the nearest enemy at range", shard_hits[0] >= 1 and swarm.is_enemy_alive(far),
			"%d hit(s)" % shard_hits[0])
	swarm.clear_all()
	# Tremor: everything within its radius around Taln.
	taln.loadout.add_skill(pool[1])
	var tremor: Tremor = taln.loadout.get_behavior(&"tremor")
	var pulses: Array = []
	tremor.pulsed.connect(func(hits: int) -> void: pulses.append(hits))
	for k in 3:
		swarm.spawn(ash, taln.global_position + Vector3.FORWARD.rotated(Vector3.UP, k * 2.1) * 3.5, 100.0, 1.0)
	await _ticks(10)
	_check("Tremor pulses around Taln, hitting every enemy in its radius", not pulses.is_empty() and pulses[0] == 3,
			"pulses %s" % [pulses])
	swarm.clear_all()
	swarm.set_frozen(false)
	# Upheave: damage and a throw at a point along the aim.
	taln.loadout.add_skill(pool[2])
	var upheave: Upheave = taln.loadout.get_behavior(&"upheave")
	taln.investiture.add(100.0, &"debug")
	var direction: Vector3 = upheave.aim_direction()
	var at: Vector3 = taln.global_position + direction * 6.0 + direction.cross(Vector3.UP) * 1.0
	var slot: int = swarm.spawn(ash, at, 100.0, 1.0)
	var cast: Array = []
	upheave.cast.connect(func(_d: Vector3, hits: int, _t: bool, _e: Toauma.Effect) -> void: cast.append(hits))
	var cast_ok: bool = upheave.try_cast()
	await _ticks(4)
	var p: Vector3 = swarm.get_enemy_position(slot)
	var moved: float = Vector2(p.x - at.x, p.z - at.z).length()
	_check("Upheave (bound to Surge 2) hits around a point 6 m along the aim and throws enemies",
			cast_ok and cast == [1] and moved > 0.5 and taln.loadout.get_bound_surge(1) == pool[2],
			"cast %s, hits %s, thrown %.2f m, binding 2 %s" % [cast_ok, cast, moved, taln.loadout.get_bound_surge(1)])
	swarm.clear_all()
	# Perks.
	var armor_before: float = taln.health.get_armor()
	taln.loadout.add_skill(pool[3])
	await _ticks(1)
	var armor_l1: float = taln.health.get_armor() - armor_before
	taln.loadout.level_up(&"stone_skin")
	var armor_l2: float = taln.health.get_armor() - armor_before
	taln.loadout.add_skill(pool[4])
	taln.health.damage(60.0, Damage.Type.KINETIC, true)
	var low: float = taln.health.current
	await _ticks(120)
	var regen: float = taln.health.current - low
	_check("Stone Skin adds 10 Armor (15 at level 2); Second Wind regenerates 0.5 Health per second",
			armor_l1 == 10.0 and armor_l2 == 15.0 and absf(regen - 1.0) < 0.05,
			"armor +%.0f, +%.0f; regen %.2f over 2 s" % [armor_l1, armor_l2, regen])


# --- the gate, meta, the screen, Aspects ---------------------------------------

func _check_gate() -> void:
	meta.wipe()
	var gate: GateDef = load("res://data/map/shortcut_gate.tres")
	var refused: bool = not meta.open_gate(gate.id, gate.cost)
	meta.grant(5)
	var opened: bool = meta.open_gate(gate.id, gate.cost)
	var again: bool = not meta.open_gate(gate.id, gate.cost)
	var spent: bool = meta.banked_agony == 2
	await _fresh()
	await _frames(2)
	await _ticks(3)  # The ground resamples the cleared cells.
	var open_now: bool = not slice.gates[0].is_closed() and not ground.is_blocked_at(GATE_CELL.x, GATE_CELL.z)
	_check("Opening a gate spends banked Agony once; from the next cycle on it starts open (swarm cells too)",
			refused and opened and again and spent and open_now,
			"refused without points %s, opened %s, refused again %s, 2 left %s, open at cycle start %s"
			% [refused, opened, again, spent, open_now])
	meta.wipe()


func _check_meta_file() -> void:
	meta.wipe()
	meta.set_aspect(&"unaspected")
	meta.grant(3)
	meta.open_gate(&"descent_shortcut", 3)
	meta.redirect(CHECKS_META)
	var kept: bool = meta.aspect == &"unaspected" and meta.opened_gates == [&"descent_shortcut"]
	var old := FileAccess.open("user://checks_meta_old.json", FileAccess.WRITE)
	old.store_string(JSON.stringify({"schema_version": 1, "caps": {}, "banked_agony": 4, "banked_total": 4,
			"catalysis_unlocked": true, "return_seen": true}))
	old.close()
	meta.redirect("user://checks_meta_old.json")
	var old_ok: bool = meta.banked_agony == 4 and meta.aspect == &"" and meta.opened_gates.is_empty()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://checks_meta_old.json"))
	meta.redirect(CHECKS_META)
	meta.wipe()
	_check("MetaState saves the chosen Aspect and opened gates; a file from before P2-10 still loads",
			kept and old_ok and cycle.aspect().id == &"earthshaper", "reloaded %s, old file %s" % [kept, old_ok])


func _check_screen() -> void:
	meta.wipe()
	await _fresh()
	cycle.end_cycle(Cycle.Outcome.CLOSED)
	await _frames(2)
	var rows_ok: bool = screen._aspect_rows.size() == 6 and screen._gate_rows.size() == 1 and screen._cap_rows.size() == 18 \
			and screen._aspect_rows[0].text == "Earthshaper   (next cycle)" and screen._aspect_rows[1].text == "Meteor" \
			and screen._aspect_rows[2].text == "Doomhunter (Shade)" and screen._aspect_rows[4].text == "Plaguebringer" \
			and screen._aspect_rows[5].text == "Unaspected" \
			and screen._gate_rows[0].disabled and screen._gate_rows[0].text == "The short way down   (costs 3)"
	var cap: float = screen.get_viewport().get_visible_rect().size.y * BetweenRunScreen.MAX_HEIGHT_FRACTION
	var rows: float = screen._box.get_combined_minimum_size().y
	var fits: bool = absf(screen._scroll.custom_minimum_size.y - minf(rows, cap)) < 0.5
	_check("The between-run screen scrolls once its rows outgrow 85% of the screen's height", fits,
			"rows %.0f px, cap %.0f px, scroll area %.0f px" % [rows, cap, screen._scroll.custom_minimum_size.y])
	screen.choose_aspect(5)
	var chose: bool = meta.aspect == &"unaspected" and screen._aspect_rows[5].text == "Unaspected   (next cycle)"
	meta.grant(3)
	var opened: bool = screen.open_gate(0) and screen._gate_rows[0].text == "The short way down   open" \
			and screen._gate_rows[0].disabled
	_check("Between-run screen: pick the next cycle's Aspect; open the gate with banked Agony",
			rows_ok and chose and opened, "rows %s, chose %s, opened %s ('%s')" % [rows_ok, chose, opened,
			screen._gate_rows[0].text])
	var old: GrayboxStation = station
	screen.begin_next()
	await _frames(3)
	var fresh := cycle.station as BraizeSlice
	var next_ok: bool = fresh != null and fresh != old and (fresh.get_node("Taln") as Taln).aspect.id == &"unaspected"
	_check("The next cycle loads the slice with the chosen Aspect", next_ok, "%s" % [fresh])
	if fresh:
		_bind(fresh)
	meta.wipe()
	paused = false


func _check_aspects() -> void:
	meta.wipe()
	await _fresh()
	await _ticks(60)
	var earth_anchored: bool = taln.anchored.is_anchored
	await _ticks(60 * 10)
	var earth_fracture: bool = taln.fracture.state != Fracture.State.NONE
	meta.set_aspect(&"unaspected")
	await _fresh()
	await _ticks(60 * 12)
	var bare_anchored: bool = taln.anchored.is_anchored
	var bare_fracture: bool = taln.fracture.state != Fracture.State.NONE or taln.fracture.still_time > 0.0
	_check("Earthshaper Anchors and Fractures when Taln stands still; Unaspected does neither (spec v1.4 #2)",
			earth_anchored and earth_fracture and not bare_anchored and not bare_fracture,
			"Earthshaper anchored %s, fracture %s; Unaspected anchored %s, fracture %s" % [earth_anchored,
			earth_fracture, bare_anchored, bare_fracture])
	meta.wipe()


func _check_telemetry() -> void:
	var telemetry: Telemetry = Telemetry.recorder()
	telemetry.enabled = true
	telemetry.directory = CHECKS_TELEMETRY
	await _fresh()
	await _ticks(10)
	await _fell_current()
	_place(DESCENT_OPEN)
	await _ticks(10)
	cycle.end_cycle(Cycle.Outcome.CLOSED)
	await _frames(2)
	telemetry.enabled = false
	var path: String = telemetry.path
	var a: Dictionary = TelemetryAnalysis.analyze(TelemetryAnalysis.read(path))
	var regions: Array = a.regions
	var ok: bool = regions.size() == 2 and regions[0].id == "the_shelf" and regions[0].siege >= 0.0 \
			and regions[0].fell >= regions[0].siege and regions[1].id == "ninefold_descent" and regions[1].tier == 2 \
			and TelemetryAnalysis.read(path).header.get("map", "") == "braize_slice" and a.kit.size() == 1
	_check("Telemetry logs each region's entry, siege and breaker, and the drop taken; the analysis reads them back",
			ok, "%s, drops %s" % [regions, a.kit])
	for file in DirAccess.get_files_at(CHECKS_TELEMETRY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKS_TELEMETRY.path_join(file)))
	paused = false


## The launch pick, driven the way a real launch runs: the slice as the current scene.
func _check_start_screen() -> void:
	paused = false
	if is_instance_valid(station):
		station.queue_free()
		await _frames(1)
	meta.wipe()
	cycle.start_chosen = false
	var seed_before: int = cycle.cycle_seed
	change_scene_to_file(SLICE)
	await _frames(4)
	var first := current_scene as BraizeSlice
	var screen_node: StartScreen = first.get_node("StartScreen")
	var waiting: bool = first.waiting_for_start and screen_node.is_open and paused and cycle.station != first \
			and screen_node.option_texts() == ["Earthshaper", "Meteor", "Doomhunter (Shade)", "Doomhunter (Bastion)", "Plaguebringer", "Unaspected"]
	_check("Launched as the first scene, the slice waits paused on the Aspect pick before its cycle begins",
			waiting, "waiting %s, open %s, paused %s, rows %s" % [first.waiting_for_start, screen_node.is_open,
			paused, screen_node.option_texts()])
	# Same Aspect as Taln has (the default): the cycle begins here, no reload.
	screen_node.pick(0)
	await _frames(2)
	var same: bool = cycle.station == first and not paused and cycle.cycle_seed != seed_before \
			and is_instance_valid(first) and cycle.start_chosen
	# A different one: the slice loads again with that kit, and doesn't ask again.
	cycle.start_chosen = false
	change_scene_to_file(SLICE)
	await _frames(4)
	var second := current_scene as BraizeSlice
	(second.get_node("StartScreen") as StartScreen).pick(1)
	await _frames(4)
	var third := current_scene as BraizeSlice
	var reloaded: bool = third != second and cycle.station == third and not third.waiting_for_start \
			and not (third.get_node("StartScreen") as StartScreen).is_open \
			and (third.get_node("Taln") as Taln).aspect.id == &"meteor" and meta.aspect == &"meteor" and not paused
	_check("Picking Taln's Aspect begins the cycle at once; picking another reloads the slice with that kit, without asking again",
			same and reloaded, "same %s, reloaded as Meteor %s" % [same, reloaded])
	_bind(third)
	meta.wipe()
