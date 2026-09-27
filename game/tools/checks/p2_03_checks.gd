extends SceneTree
## P2-03 checks (weapon, Stoneward Surge, Toa'uma and Strain), run headless
## against the real station scene at a fixed 60 fps. Prints PASS/FAIL per
## check and exits with the number of failures.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_03_checks.gd

const STATION := "res://scenes/graybox_station.tscn"

var station: GrayboxStation
var taln: Taln
var failures: int = 0


func _init() -> void:
	_run()


func _run() -> void:
	await _ticks(2)
	await _check_investiture()
	await _check_loadout()
	print("")
	await _check_root()
	await _check_root_contact()
	await _check_slow()
	await _check_find_nearest()
	await _check_densest_direction()
	print("")
	await _check_weapon_data()
	await _check_weapon_swings()
	await _check_weapon_interval()
	print("")
	await _check_settle_data()
	await _check_settle_cast()
	await _check_settle_blade()
	print("")
	await _check_toauma_data()
	await _check_side_effect_table()
	await _check_strain_and_draw()
	await _check_honorblade()
	await _check_effects()
	await _check_notice()
	await _check_gem()
	print("")
	_check_input_table()
	await _check_input_triggers()
	await _check_click_recapture()
	print("")
	await _check_hunter_lifetime()
	await _check_overlay()
	print("")
	await _check_done_weapon()
	await _check_done_settle_cone()
	await _check_done_soft_lock()
	await _check_done_strain()
	await _check_done_rates()
	await _check_done_notice()
	await _check_done_honorblade()
	await _check_done_debug_keys()
	await _check_done_performance()
	print("")
	print("MANUAL  Mouse released (Esc): a click recaptures it without casting; captured, left click casts Surge 1.")
	print("MANUAL  In the editor's running game: F3, F4 and Ctrl+1 to Ctrl+7 all respond (the editor may claim some shortcuts).")
	print("MANUAL  60 fps rendered at 400 alive with Settle spammed (Ctrl+4 to refill); the soft-lock pull reads on screen.")
	print("MANUAL  Visuals: reticle, cracked ground in both routings, rooted enemies, the gem, hunters.")
	print("")
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


func _fresh() -> void:
	if station:
		station.queue_free()
		await _ticks(1)
	station = (load(STATION) as PackedScene).instantiate()
	root.add_child(station)
	(station.get_node("SpawnDirector") as SpawnDirector).paused = true
	taln = station.get_node("Taln")
	# These checks were written for a 100 Investiture start; cycles start at 0
	# since P2-05 (ruled), so fund Taln the way Ctrl+4 does, before any frame runs.
	taln.investiture.add(100.0, &"debug")
	await _ticks(2)


## Presses and releases action through the input event queue, like a real key.
func _tap(action: String) -> void:
	_send(action, true)
	await _ticks(2)
	_send(action, false)
	await _ticks(1)


func _send(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


# --- step 1: Investiture stub ----------------------------------------------

func _check_investiture() -> void:
	await _fresh()
	var inv: Investiture = taln.investiture
	var t: InvestitureTuning = inv.tuning
	var emitted: Array[float] = []
	inv.changed.connect(func(value: float) -> void: emitted.append(value))

	# _fresh() added 100 debug Investiture on top of the starting amount.
	_check("Investiture starts the cycle at debug_start_investiture = 0 (P2-05 ruling)", t.debug_start_investiture == 0.0
			and is_equal_approx(inv.current, 100.0), "tuning %.1f; %.1f after the 100 test grant" % [t.debug_start_investiture,
			inv.current])

	var start: float = inv.current
	var spent: bool = inv.spend(40.0)
	var refused: bool = inv.spend(start)
	_check("spend() deducts when affordable and refuses otherwise", spent and not refused
			and is_equal_approx(inv.current, start - 40.0) and inv.can_afford(start - 40.0)
			and not inv.can_afford(start - 39.0), "after spend 40 → %.1f; spend %.0f returned %s"
			% [inv.current, start, refused])

	inv.add(25.0, &"checks")
	_check("add() raises current; changed(current) fires once per change",
			is_equal_approx(inv.current, start - 15.0) and emitted.size() == 2
			and is_equal_approx(emitted[-1], inv.current), "current %.1f, emitted %s" % [inv.current, emitted])

	var before: float = inv.current
	await _tap("debug_grant_investiture")
	_check("Ctrl+4 grants debug_grant_amount", is_equal_approx(inv.current - before, t.debug_grant_amount)
			and t.debug_grant_amount == 100.0, "+%.1f" % (inv.current - before))


# --- step 2: skill data and Loadout ----------------------------------------

## A throwaway SkillDef whose behavior is a bare SkillBehavior.
func _test_skill(id: StringName, kind: SkillDef.Kind) -> SkillDef:
	var skill := SkillDef.new()
	skill.id = id
	skill.kind = kind
	skill.level_params = [{"n": 1}, {"n": 2}]
	var node := SkillBehavior.new()
	skill.behavior = PackedScene.new()
	skill.behavior.pack(node)
	node.free()
	return skill


func _check_loadout() -> void:
	await _fresh()
	var loadout: Loadout = taln.loadout
	var t: LoadoutTuning = loadout.tuning
	_check("Loadout has 9 slots and 3 Surge bindings from tuning", t.slots == 9 and t.surge_bindings == 3
			and loadout.surge_bindings.size() == 3, "%d slots, %d bindings" % [t.slots, loadout.surge_bindings.size()])
	var starting: Array[StringName] = []
	for skill: SkillDef in t.starting_skills:
		starting.append(skill.id)
	var owned: Array[StringName] = []
	for skill: SkillDef in loadout.slots:
		owned.append(skill.id)
	_check("Starting skills are owned at level 1 once Taln is ready", owned == starting
			and starting.all(func(id: StringName) -> bool: return loadout.get_level(id) == 1),
			"starting %s, owned %s" % [starting, owned])

	# Clear the starting kit so the rest is independent of step 4/5 content.
	for child: Node in loadout.get_children():
		child.free()
	loadout.slots.clear()
	loadout._levels.clear()
	loadout._behaviors.clear()
	loadout.surge_bindings.fill(null)

	var weapon: SkillDef = _test_skill(&"test_weapon", SkillDef.Kind.WEAPON)
	var surges: Array[SkillDef] = []
	for i in 4:
		surges.append(_test_skill(StringName("test_surge_%d" % i), SkillDef.Kind.SURGE))
	var added: bool = loadout.add_skill(weapon)
	var behavior: SkillBehavior = loadout.get_behavior(&"test_weapon")
	_check("add_skill() owns at level 1 and instantiates the behavior as a child",
			added and loadout.get_level(&"test_weapon") == 1 and behavior != null
			and behavior.get_parent() == loadout and behavior.skill == weapon and behavior.taln == taln
			and behavior.params() == {"n": 1}, "added %s, level %d, behavior %s"
			% [added, loadout.get_level(&"test_weapon"), behavior])
	_check("A skill already owned is refused", not loadout.add_skill(weapon), "%d slots" % loadout.slots.size())

	for surge: SkillDef in surges:
		loadout.add_skill(surge)
	_check("Surges bind to the first free binding; a 4th stays unbound", loadout.surge_bindings
			== [surges[0], surges[1], surges[2]] and loadout.has_skill(&"test_surge_3"),
			"bindings %s" % [loadout.surge_bindings.map(func(s: SkillDef) -> StringName: return s.id)])
	var moved: bool = loadout.bind_surge(0, surges[2])
	var weapon_bound: bool = loadout.bind_surge(1, weapon)
	_check("bind_surge() moves a Surge between bindings and refuses non-Surges",
			moved and not weapon_bound and loadout.surge_bindings == [surges[2], surges[1], null],
			"bindings %s" % [loadout.surge_bindings.map(func(s: SkillDef) -> Variant: return s.id if s else null)])

	for i in 10:
		loadout.add_skill(_test_skill(StringName("test_perk_%d" % i), SkillDef.Kind.PERK))
	_check("The Loadout stops at 9 slots", loadout.slots.size() == 9 and loadout.is_full(),
			"%d owned" % loadout.slots.size())
	_check("level_params clamps to the levels authored", weapon.params_for(9) == {"n": 2}
			and weapon.params_for(0) == {"n": 1}, "level 9 → %s" % weapon.params_for(9))


# --- step 3: SwarmServer rooting, slowing and queries ----------------------

const ASH_WALKER := "res://data/swarm/ash_walker.tres"

var swarm: SwarmServer
var ground: StationGround
## One entry per taln_contacted.
var contacts: Array[float] = []


## A new station whose SwarmServer has its ground, with Taln parked at
## taln_at and the spawner paused.
func _fresh_swarm(taln_at: Vector3) -> void:
	await _fresh()
	ground = station.get_node("StationGround")
	swarm = station.get_node("SwarmServer")
	taln.health.set_invulnerable(&"checks", true)
	# Swarm checks run without Taln's weapon unless they turn it back on.
	taln.loadout.process_mode = Node.PROCESS_MODE_DISABLED
	await ground.ground_changed
	taln.global_position = taln_at
	taln.velocity = Vector3.ZERO
	contacts.clear()
	swarm.taln_contacted.connect(func(damage: float, _type: int) -> void: contacts.append(damage))
	await _ticks(2)


## An ash walker variant with a fixed speed, so two of them move alike.
func _fixed_speed_ash() -> SwarmType:
	var ash: SwarmType = (load(ASH_WALKER) as SwarmType).duplicate()
	ash.speed_min = ash.speed_max
	return ash


func _moved(slot: int, from: Vector3) -> float:
	var at: Vector3 = swarm.get_enemy_position(slot)
	return Vector2(at.x - from.x, at.z - from.z).length()


## Custom data w of a drawn instance, read from the buffer (the headless
## renderer doesn't answer get_instance_custom_data()).
func _rooted_amount(mm: MultiMesh, instance: int) -> float:
	return mm.buffer[instance * 16 + 15]


func _check_root() -> void:
	await _fresh_swarm(Vector3(-40.0, 0.0, -20.0))
	var ash: SwarmType = _fixed_speed_ash()
	var origin := Vector3(-40.0, 0.0, 20.0)
	var a_at: Vector3 = origin + Vector3(3.0, 0.0, 0.0)
	var b_at: Vector3 = origin + Vector3(-3.0, 0.0, 0.0)
	var a: int = swarm.spawn(ash, a_at, 1.0, 1.0)
	var b: int = swarm.spawn(ash, b_at, 1.0, 1.0)
	a_at = swarm.get_enemy_position(a)
	b_at = swarm.get_enemy_position(b)
	var hit: int = swarm.apply_root_in_cone(origin, Vector3.RIGHT, 60.0, 5.0, 2.0)
	swarm.apply_impulse_in_radius(a_at + Vector3(-0.5, 0.0, 0.0), 1.0, 6.0)
	await _ticks(60)
	_check("apply_root_in_cone() roots enemies in the cone only", hit == 1 and swarm.get_enemy_root_time(a) > 0.0
			and swarm.get_enemy_root_time(b) == 0.0, "%d rooted; root left a %.2f s, b %.2f s"
			% [hit, swarm.get_enemy_root_time(a), swarm.get_enemy_root_time(b)])
	_check("Rooted enemies don't seek, separate or take impulses", _moved(a, a_at) < 0.001 and _moved(b, b_at) > 1.0,
			"rooted moved %.3f m, free one %.2f m in 1 s" % [_moved(a, a_at), _moved(b, b_at)])

	await process_frame
	await process_frame
	var mm: MultiMesh = (swarm.get_child(0) as MultiMeshInstance3D).multimesh
	var rooted_w: float = _rooted_amount(mm, 0)
	var free_w: float = _rooted_amount(mm, 1)
	_check("Custom data w carries the rooted amount", is_equal_approx(rooted_w, 1.0) and free_w == 0.0,
			"rooted %.2f, free %.2f" % [rooted_w, free_w])

	var held: Vector3 = swarm.get_enemy_position(a)
	# About 0.15 s of root left: w is partway through its root_fade_time ease-out.
	await _ticks(51)
	var fading_w: float = _rooted_amount(mm, 0)
	await _ticks(30)
	_check("The root runs its duration, then the enemy moves again", swarm.get_enemy_root_time(a) == 0.0
			and _moved(a, held) > 0.1 and fading_w > 0.0 and fading_w < 1.0, "root left %.2f s, moved %.2f m after; w %.2f near the end"
			% [swarm.get_enemy_root_time(a), _moved(a, held), fading_w])


func _check_root_contact() -> void:
	var taln_at := Vector3(-40.0, 0.0, 20.0)
	await _fresh_swarm(taln_at)
	var ash: SwarmType = load(ASH_WALKER)
	var slot: int = swarm.spawn(ash, taln_at + Vector3(0.6, 0.0, 0.0), 1.0, 1.0)
	swarm.apply_root_in_cone(taln_at, Vector3.RIGHT, 90.0, 3.0, 5.0)
	await _ticks(60)
	_check("Rooted enemies still deal contact damage", swarm.get_enemy_root_time(slot) > 0.0 and contacts.size() >= 1,
			"%d contacts in 1 s while rooted" % contacts.size())


func _check_slow() -> void:
	await _fresh_swarm(Vector3(-40.0, 0.0, -20.0))
	var ash: SwarmType = _fixed_speed_ash()
	var a_at := Vector3(-43.0, 0.0, 20.0)
	var b_at := Vector3(-37.0, 0.0, 20.0)
	var a: int = swarm.spawn(ash, a_at, 1.0, 1.0)
	var b: int = swarm.spawn(ash, b_at, 1.0, 1.0)
	a_at = swarm.get_enemy_position(a)
	b_at = swarm.get_enemy_position(b)
	var hit: int = swarm.apply_slow_in_radius(a_at, 0.5, 0.5, 2.0)
	var weaker: int = swarm.apply_slow_in_radius(a_at, 0.5, 0.8, 0.5)
	var slow_left: float = swarm.get_enemy_slow_time(a)
	await _ticks(60)
	var ratio: float = _moved(a, a_at) / _moved(b, b_at)
	_check("apply_slow_in_radius() multiplies speed by the factor", hit == 1 and absf(ratio - 0.5) < 0.05,
			"slowed %.2f m vs %.2f m in 1 s (ratio %.2f)" % [_moved(a, a_at), _moved(b, b_at), ratio])
	_check("A weaker slow doesn't replace a stronger one", weaker == 1 and is_equal_approx(slow_left, 2.0),
			"slow left %.2f s after a 0.8 × 0.5 s slow" % slow_left)
	await _ticks(90)
	var from_a: Vector3 = swarm.get_enemy_position(a)
	var from_b: Vector3 = swarm.get_enemy_position(b)
	await _ticks(30)
	_check("The slow wears off after its duration", swarm.get_enemy_slow_time(a) == 0.0
			and absf(_moved(a, from_a) / _moved(b, from_b) - 1.0) < 0.05,
			"ratio %.2f after it ended" % (_moved(a, from_a) / _moved(b, from_b)))


func _check_find_nearest() -> void:
	await _fresh_swarm(Vector3(-40.0, 0.0, -20.0))
	swarm.set_target(null)
	var ash: SwarmType = load(ASH_WALKER)
	var center := Vector3(-40.0, 0.0, 20.0)
	swarm.spawn(ash, center + Vector3(0.0, 0.0, 5.0), 1.0, 1.0)
	var near: int = swarm.spawn(ash, center + Vector3(-3.0, 0.0, 0.0), 1.0, 1.0)
	var found: Vector3 = swarm.find_nearest(center, 10.0)
	var none: Vector3 = swarm.find_nearest(center, 2.0)
	_check("find_nearest() returns the nearest live enemy, or Vector3.INF", found == swarm.get_enemy_position(near)
			and none == Vector3.INF, "found %s, within 2 m: %s" % [found, none])


func _check_densest_direction() -> void:
	await _fresh_swarm(Vector3(-40.0, 0.0, -20.0))
	swarm.set_target(null)
	var ash: SwarmType = load(ASH_WALKER)
	var origin := Vector3(-40.0, 0.0, 20.0)
	var empty: Vector3 = swarm.find_densest_direction(origin, Vector3(2.0, 0.0, 0.0), 30.0, 10.0, 9)
	var at_20 := Vector3(cos(deg_to_rad(20.0)), 0.0, sin(deg_to_rad(20.0)))
	swarm.spawn(ash, origin + Vector3.RIGHT * 6.0, 1.0, 1.0)
	for k in 3:
		swarm.spawn(ash, origin + at_20 * (4.0 + k * 1.5), 1.0, 1.0)
	for k in 5:
		swarm.spawn(ash, origin + Vector3.LEFT * (4.0 + k), 1.0, 1.0)  # Behind.
	for k in 5:
		swarm.spawn(ash, origin + Vector3.RIGHT * (12.0 + k), 1.0, 1.0)  # Past the range.
	await _ticks(1)
	var dense: Vector3 = swarm.find_densest_direction(origin, Vector3.RIGHT, 30.0, 10.0, 9)
	_check("find_densest_direction() returns forward for an empty cone", empty.is_equal_approx(Vector3.RIGHT),
			"%s" % empty)
	_check("find_densest_direction() points at the fullest of 9 sectors", dense.is_equal_approx(at_20),
			"%s, expected %s (20°)" % [dense, at_20])


# --- step 4: Breaking Stroke ----------------------------------------------------

const BREAKING_STROKE := "res://data/skills/breaking_stroke.tres"


## A swarm station with Taln's weapon on; returns the weapon behavior.
func _fresh_weapon(taln_at: Vector3) -> BreakingStroke:
	await _fresh_swarm(taln_at)
	taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT
	return taln.loadout.get_behavior(&"breaking_stroke")


func _check_weapon_data() -> void:
	var skill: SkillDef = load(BREAKING_STROKE)
	var damage: Array = []
	var interval: Array = []
	# P2-05 extended the table to 9 levels; levels 1–3 are this step's.
	var shape_ok: bool = skill.level_params.size() >= 3
	for p: Dictionary in skill.level_params.slice(0, 3):
		damage.append(p.damage)
		interval.append(p.interval)
		shape_ok = shape_ok and p.cone_deg == 110.0 and p.range == 3.2 and p.acquire_margin == 0.5
	_check("Breaking Stroke data: Stoneward Weapon, 24/29/35 Kinetic, 0.8/0.75/0.7 s, 110° × 3.2 m",
			skill.kind == SkillDef.Kind.WEAPON and skill.tree == SkillDef.SkillTree.STONEWARD and shape_ok
			and damage == [24.0, 29.0, 35.0] and interval == [0.8, 0.75, 0.7],
			"damage %s, interval %s" % [damage, interval])

	await _fresh()
	var behavior: SkillBehavior = taln.loadout.get_behavior(&"breaking_stroke")
	_check("Taln starts with Breaking Stroke at level 1", taln.loadout.get_level(&"breaking_stroke") == 1
			and behavior is BreakingStroke and taln.loadout.swarm == station.get_node("SwarmServer"),
			"level %d, behavior %s" % [taln.loadout.get_level(&"breaking_stroke"), behavior])

	var spawn: SpawnTuning = (station.get_node("SpawnDirector") as SpawnDirector).tuning
	var ash: SwarmType = load(ASH_WALKER)
	var w9_hp: float = ash.hp * (1.0 + spawn.hp_slope * (spawn.waves - 1)) * spawn.station_hp_mults[0]
	_check("Tuning: 24 damage one-shots a basic enemy through station 1 wave 9", damage[0] >= w9_hp
			and is_equal_approx(snappedf(w9_hp, 0.01), 23.52), "S1 W9 HP %.2f" % w9_hp)


func _check_weapon_swings() -> void:
	var taln_at := Vector3(-40.0, 0.0, 20.0)
	var weapon: BreakingStroke = await _fresh_weapon(taln_at)
	var swings: Array = []
	weapon.swung.connect(func(dir: Vector3, hits: int) -> void: swings.append([dir, hits]))
	var deaths: Array[Vector3] = []
	swarm.enemy_died.connect(func(_id: StringName, at: Vector3, _rewarded: bool) -> void: deaths.append(at))
	swarm.set_target(null)
	await _ticks(30)
	_check("No swing with nothing in range", swings.is_empty(), "%d swings" % swings.size())

	var ash: SwarmType = load(ASH_WALKER)
	var hp_w9: float = 1.0 + 0.12 * 8.0
	var near: int = swarm.spawn(ash, taln_at + Vector3(0.0, 0.0, -2.0), hp_w9, 1.0)
	var near_at: Vector3 = swarm.get_enemy_position(near)
	var far_at: Vector3 = taln_at + Vector3(0.0, 0.0, 3.3)
	swarm.spawn(ash, far_at, hp_w9, 1.0)
	await _ticks(1)
	var arc: MeshInstance3D = weapon.get_node("Arc")
	var flashed: bool = arc.visible
	await _ticks(4)
	var first: Array = swings[0] if not swings.is_empty() else [Vector3.ZERO, 0]
	_check("Swings at the nearest enemy, one-shotting it at wave 9 HP; the opposite one is untouched",
			swings.size() == 1 and (first[0] as Vector3).is_equal_approx(Vector3.FORWARD) and first[1] == 1
			and deaths.size() == 1 and deaths[0].is_equal_approx(near_at) and swarm.get_alive_count() == 1,
			"%d swings, first %s, %d deaths" % [swings.size(), first, deaths.size()])
	await _ticks(10)
	_check("The ochre arc flashes for 0.12 s", flashed and not arc.visible and weapon.flash_time == 0.12
			and (arc.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color("#D9A55B")),
			"visible after the swing: %s; after 14 ticks: %s" % [flashed, arc.visible])
	await _ticks(50)
	_check("Acquires out to range + 0.5 m and turns the cone toward it", swings.size() == 2
			and (swings[1][0] as Vector3).is_equal_approx(Vector3.BACK) and deaths.size() == 2,
			"%d swings, %d deaths" % [swings.size(), deaths.size()])


func _check_weapon_interval() -> void:
	var taln_at := Vector3(-40.0, 0.0, 20.0)
	var weapon: BreakingStroke = await _fresh_weapon(taln_at)
	swarm.set_target(null)
	var tough: SwarmType = (load(ASH_WALKER) as SwarmType).duplicate()
	tough.hp = 100000.0
	swarm.spawn(tough, taln_at + Vector3(2.0, 0.0, 0.0), 1.0, 1.0)
	var ticks: Array[int] = []
	var tick: Array[int] = [0]
	weapon.swung.connect(func(_dir: Vector3, _hits: int) -> void: ticks.append(tick[0]))
	for k in 180:
		await _ticks(1)
		tick[0] += 1
	var gaps: Array[int] = []
	for k in range(1, ticks.size()):
		gaps.append(ticks[k] - ticks[k - 1])
	_check("Level 1 swings every 0.8 s", gaps.size() >= 2 and gaps.all(func(g: int) -> bool: return g == 48),
			"gaps in ticks %s" % [gaps])
	weapon.set_level(3)
	ticks.clear()
	for k in 120:
		await _ticks(1)
		tick[0] += 1
	gaps.clear()
	for k in range(1, ticks.size()):
		gaps.append(ticks[k] - ticks[k - 1])
	_check("Level 3 swings every 0.7 s", gaps.size() >= 1 and gaps.all(func(g: int) -> bool: return g == 42),
			"gaps in ticks %s" % [gaps])


# --- step 5: Settle ---------------------------------------------------------------

const SETTLE := "res://data/skills/settle.tres"


## A swarm station with Settle live and the weapon off, the swarm not seeking.
func _fresh_settle(taln_at: Vector3) -> Settle:
	await _fresh_swarm(taln_at)
	taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT
	taln.loadout.get_behavior(&"breaking_stroke").process_mode = Node.PROCESS_MODE_DISABLED
	swarm.set_target(null)
	_no_side_effects()
	return taln.loadout.get_behavior(&"settle")


## Side effects off, so a cast does exactly what it says.
func _no_side_effects() -> void:
	var calm: ToaumaTuning = taln.toauma.tuning.duplicate()
	calm.p_base = 0.0
	calm.p_per_strain = 0.0
	calm.p_max = 0.0
	taln.toauma.tuning = calm


## Camera-forward flattened onto the ground, as Surges aim.
func _camera_forward() -> Vector3:
	var look: Vector3 = -station.get_viewport().get_camera_3d().global_basis.z
	return Basis(Vector3.UP, atan2(-look.x, -look.z)) * Vector3.FORWARD


## forward turned by deg on the ground, in find_densest_direction()'s sense.
func _turned(forward: Vector3, deg: float) -> Vector3:
	var v: Vector2 = Vector2(forward.x, forward.z).rotated(deg_to_rad(deg))
	return Vector3(v.x, 0.0, v.y)


func _check_settle_data() -> void:
	var skill: SkillDef = load(SETTLE)
	var damage: Array = []
	var root: Array = []
	var cone: Array = []
	# P2-05 extended the table to 9 levels; levels 1–3 are this step's.
	var range_ok: bool = skill.level_params.size() >= 3
	for p: Dictionary in skill.level_params.slice(0, 3):
		damage.append(p.damage)
		root.append(p.root_duration)
		cone.append(p.cone_deg)
		range_ok = range_ok and p.range == 7.0
	_check("Settle data: Stoneward Surge, Blade-eligible, 25 Investiture, 4 s, 7 m; 18/22/27, 2.0/2.3/2.6 s, 70/80/90°",
			skill.kind == SkillDef.Kind.SURGE and skill.tree == SkillDef.SkillTree.STONEWARD
			and skill.routing == SkillDef.Routing.BLADE_ELIGIBLE and skill.investiture_cost == 25.0
			and skill.cooldown == 4.0 and range_ok and damage == [18.0, 22.0, 27.0] and root == [2.0, 2.3, 2.6]
			and cone == [70.0, 80.0, 90.0], "damage %s, root %s, cone %s" % [damage, root, cone])
	var t: LoadoutTuning = load("res://data/tuning/loadout_tuning.tres")
	_check("Soft-lock is ±15° in 9 sectors", t.surge_soft_lock_half_angle_deg == 15.0
			and t.surge_soft_lock_sectors == 9, "±%.0f°, %d sectors" % [t.surge_soft_lock_half_angle_deg,
			t.surge_soft_lock_sectors])

	await _fresh()
	var surge: SurgeBehavior = taln.loadout.get_surge_behavior(0)
	_check("Taln starts with Settle on Surge binding 1, routed through Toa'uma", surge is Settle
			and taln.loadout.get_level(&"settle") == 1 and surge.routes_through_toa_uma(), "binding 1: %s" % surge)


func _check_settle_cast() -> void:
	var taln_at := Vector3(-40.0, 0.0, 20.0)
	var settle: Settle = await _fresh_settle(taln_at)
	var casts: Array = []
	settle.cast.connect(func(dir: Vector3, hits: int, toa_uma: bool, _effect: Toauma.Effect) -> void:
			casts.append([dir, hits, toa_uma]))
	var deaths: Array[Vector3] = []
	swarm.enemy_died.connect(func(_id: StringName, at: Vector3, _rewarded: bool) -> void: deaths.append(at))
	var reticle: MeshInstance3D = settle.get_node("Reticle")
	var cracks: MeshInstance3D = settle.get_node("Cracks")
	var ash: SwarmType = load(ASH_WALKER)
	var forward: Vector3 = _camera_forward()
	var cluster: Vector3 = _turned(forward, 10.0)
	# Two survive 18 damage (24 HP), one doesn't (16.8 HP).
	var tough: Array[int] = [swarm.spawn(ash, taln_at + cluster * 4.5, 2.0, 1.0),
			swarm.spawn(ash, taln_at + cluster * 5.5, 2.0, 1.0)]
	swarm.spawn(ash, taln_at + cluster * 6.5, 1.4, 1.0)
	var outside: Array[int] = [swarm.spawn(ash, taln_at + _turned(forward, -40.0) * 5.0, 2.0, 1.0),
			swarm.spawn(ash, taln_at + forward * 8.5, 2.0, 1.0)]
	# The aim just jumped 10° onto the cluster: the reticle eases over rather than snapping.
	await _ticks(1)
	var eased_deg: float = rad_to_deg(reticle.global_basis.z.angle_to(forward))
	await _ticks(45)
	var reticle_ready: bool = reticle.visible
	var reticle_dir: Vector3 = reticle.global_basis.z
	var before: float = taln.investiture.current

	await _tap("surge_1")
	await _ticks(3)
	var first: Array = casts[0] if not casts.is_empty() else [Vector3.ZERO, 0, false]
	_check("The reticle shows while ready, soft-locked like the cast", reticle_ready
			and rad_to_deg(reticle_dir.angle_to(cluster)) < 0.5, "visible %s, %.2f° off the cast direction"
			% [reticle_ready, rad_to_deg(reticle_dir.angle_to(cluster))])
	_check("The reticle eases toward a new aim instead of snapping", eased_deg > 0.5 and eased_deg < 9.5,
			"%.2f° of the 10° jump after one frame" % eased_deg)
	_check("Surge 1 casts Settle for 25 Investiture", casts.size() == 1
			and is_equal_approx(before - taln.investiture.current, 25.0), "%d casts, spent %.1f"
			% [casts.size(), before - taln.investiture.current])
	_check("Aim: camera-forward soft-locked 10° onto the cluster", (first[0] as Vector3).is_equal_approx(cluster),
			"cast %s, cluster %s, camera %s" % [first[0], cluster, forward])
	var rooted: bool = tough.all(func(i: int) -> bool: return swarm.get_enemy_root_time(i) > 1.5)
	var spared: bool = outside.all(func(i: int) -> bool: return swarm.get_enemy_root_time(i) == 0.0)
	_check("Damages the cone, then roots the survivors; nothing outside is touched", first[1] == 3
			and deaths.size() == 1 and rooted and spared and swarm.get_alive_count() == 4,
			"%d hit, %d died, survivors rooted %s, outside untouched %s" % [first[1], deaths.size(), rooted, spared])
	var material: ShaderMaterial = cracks.material_override
	_check("Cracked ground in Voidlight (#6B3FA0 core, #7FE3D6 rim, flicker) through Toa'uma", cracks.visible
			and first[2] == true and material.get_shader_parameter(&"flicker") == 1.0
			and (material.get_shader_parameter(&"core_color") as Color).is_equal_approx(Color("#6B3FA0"))
			and (material.get_shader_parameter(&"rim_color") as Color).is_equal_approx(Color("#7FE3D6")),
			"visible %s, core %s, rim %s" % [cracks.visible, material.get_shader_parameter(&"core_color"),
			material.get_shader_parameter(&"rim_color")])

	var spent: float = taln.investiture.current
	await _tap("surge_1")
	_check("On cooldown: no reticle, and a press does nothing", casts.size() == 1 and not reticle.visible
			and taln.investiture.current == spent, "%d casts, reticle %s" % [casts.size(), reticle.visible])
	await _ticks(120)
	_check("The cracks last the root duration (2.0 s)", not cracks.visible, "visible %s at ~2.1 s" % cracks.visible)
	await _ticks(120)
	_check("The reticle returns when the 4 s cooldown ends", reticle.visible and settle.cooldown_left == 0.0,
			"visible %s" % reticle.visible)

	taln.investiture.spend(taln.investiture.current - 10.0)
	await _ticks(2)
	var broke_reticle: bool = reticle.visible
	await _tap("surge_1")
	_check("Unaffordable: no reticle, and a press spends nothing", not broke_reticle and casts.size() == 1
			and is_equal_approx(taln.investiture.current, 10.0), "reticle %s, %d casts, %.1f left"
			% [broke_reticle, casts.size(), taln.investiture.current])


func _check_settle_blade() -> void:
	var settle: Settle = await _fresh_settle(Vector3(-40.0, 0.0, 20.0))
	taln.loadout.honorblade_held = true
	var casts: Array = []
	settle.cast.connect(func(_dir: Vector3, _hits: int, toa_uma: bool, _effect: Toauma.Effect) -> void:
			casts.append(toa_uma))
	await _tap("surge_1")
	var material: ShaderMaterial = (settle.get_node("Cracks") as MeshInstance3D).material_override
	_check("Through the Blade the cracks glow steady ochre", casts == [false]
			and material.get_shader_parameter(&"flicker") == 0.0
			and (material.get_shader_parameter(&"core_color") as Color).is_equal_approx(Color("#D9A55B"))
			and (material.get_shader_parameter(&"rim_color") as Color).is_equal_approx(Color("#D9A55B")),
			"casts %s, core %s" % [casts, material.get_shader_parameter(&"core_color")])


# --- step 6: Toa'uma and Strain ------------------------------------------------------

const NOTICE_HUNTER := "res://data/swarm/notice_hunter.tres"


## Every routed use rolls a side effect, and it's always this one.
func _force_effect(effect: Toauma.Effect) -> void:
	var forced: ToaumaTuning = taln.toauma.tuning.duplicate()
	forced.p_base = 1.0
	forced.p_max = 1.0
	forced.weight_overcharge = 1 if effect == Toauma.Effect.OVERCHARGE else 0
	forced.weight_burn = 1 if effect == Toauma.Effect.BURN else 0
	forced.weight_misfire = 1 if effect == Toauma.Effect.MISFIRE else 0
	forced.weight_lurch = 1 if effect == Toauma.Effect.LURCH else 0
	forced.weight_echo = 1 if effect == Toauma.Effect.ECHO else 0
	forced.weight_speaks = 1 if effect == Toauma.Effect.SPEAKS else 0
	taln.toauma.tuning = forced


## Readies the Surge for another cast right now.
func _recharge(settle: Settle) -> void:
	settle.cooldown_left = 0.0
	taln.investiture.add(100.0, &"checks")


func _check_toauma_data() -> void:
	var hunter: SwarmType = load(NOTICE_HUNTER)
	var ash: SwarmType = load(ASH_WALKER)
	var mesh: CylinderMesh = hunter.mesh
	var ash_mesh: CylinderMesh = ash.mesh
	var band: float = (hunter.material as ShaderMaterial).get_shader_parameter(&"eye_band_top") \
			- (hunter.material as ShaderMaterial).get_shader_parameter(&"eye_band_bottom")
	_check("notice_hunter: 120 HP, 14 contact, 4.2–4.6 m/s, mass 4, radius 0.55, cost 9, 1.3× prism, wider band",
			hunter.id == &"notice_hunter" and hunter.hp == 120.0 and hunter.contact_damage == 14.0
			and hunter.speed_min == 4.2 and hunter.speed_max == 4.6 and hunter.mass == 4.0 and hunter.radius == 0.55
			and hunter.spawn_cost == 9 and is_equal_approx(mesh.height, ash_mesh.height * 1.3)
			and is_equal_approx(mesh.top_radius, ash_mesh.top_radius * 1.3) and band > 0.1 * 1.3,
			"height %.3f, radius %.3f, band %.2f m" % [mesh.height, mesh.top_radius, band])

	await _fresh()
	var toauma: Toauma = taln.toauma
	var t: ToaumaTuning = toauma.tuning
	_check("Toa'uma tuning matches spec §5 and the handoff", t.strain_max == 9.0 and t.surge_strain_per_25 == 0.25
			and t.draw_investiture == 30.0 and t.draw_cooldown == 9.0 and t.draw_strain == 1.0
			and t.misfire_max_deg == 45.0 and t.lurch_radius == 6.0 and t.lurch_factor == 0.6
			and t.lurch_duration == 2.0 and t.echo_delay == 1.0 and t.burn_fraction == 0.06
			and t.overcharge_mult == 2.0 and t.notice_thresholds == [3.0, 6.0, 9.0] and t.notice_hunters == [3, 5, 9]
			and t.notice_hunter_type == load(NOTICE_HUNTER), "strain max %.0f" % t.strain_max)
	var chances: Array[float] = []
	for s: float in [0.0, 4.0, 9.0]:
		toauma.strain = s
		chances.append(toauma.side_effect_chance())
	toauma.strain = 0.0
	_check("p = 0.05 + 0.05 × Strain, capped at 0.5", is_equal_approx(chances[0], 0.05)
			and is_equal_approx(chances[1], 0.25) and is_equal_approx(chances[2], 0.5), "%s at 0 / 4 / 9" % [chances])


func _check_side_effect_table() -> void:
	await _fresh()
	var toauma: Toauma = taln.toauma
	var always: ToaumaTuning = toauma.tuning.duplicate()
	always.p_base = 1.0
	always.p_max = 1.0
	toauma.tuning = always
	toauma.rng.seed = 9
	var rolls: int = 26000
	var surge_counts: Dictionary = {}
	var draw_counts: Dictionary = {}
	var high_counts: Dictionary = {}
	for k in rolls:
		var e: Toauma.Effect = toauma.roll_effect(false)
		surge_counts[e] = surge_counts.get(e, 0) + 1
		e = toauma.roll_effect(true)
		draw_counts[e] = draw_counts.get(e, 0) + 1
	toauma.strain = 9.0
	for k in rolls:
		var e: Toauma.Effect = toauma.roll_effect(false)
		high_counts[e] = high_counts.get(e, 0) + 1
	toauma.strain = 0.0
	var close := func(counts: Dictionary, effect: Toauma.Effect, share: float) -> bool:
		return absf(counts.get(effect, 0) / float(rolls) - share) < 0.012
	var E := Toauma.Effect
	var surge_ok: bool = close.call(surge_counts, E.OVERCHARGE, 3.0 / 13.0) and close.call(surge_counts, E.BURN, 3.0 / 13.0) \
			and close.call(surge_counts, E.MISFIRE, 2.0 / 13.0) and close.call(surge_counts, E.LURCH, 2.0 / 13.0) \
			and close.call(surge_counts, E.ECHO, 1.0 / 13.0) and close.call(surge_counts, E.SPEAKS, 2.0 / 13.0)
	_check("Surge side effects pick by weight 3/3/2/2/1/2", surge_ok, "%s" % [surge_counts])
	var draw_ok: bool = not draw_counts.has(E.MISFIRE) and not draw_counts.has(E.ECHO) \
			and close.call(draw_counts, E.OVERCHARGE, 0.3) and close.call(draw_counts, E.BURN, 0.3) \
			and close.call(draw_counts, E.LURCH, 0.2) and close.call(draw_counts, E.SPEAKS, 0.2)
	_check("A Draw never Misfires or Echoes (rerolled)", draw_ok, "%s" % [draw_counts])
	var high_ok: bool = close.call(high_counts, E.BURN, 6.0 / 18.0) and close.call(high_counts, E.MISFIRE, 4.0 / 18.0) \
			and close.call(high_counts, E.OVERCHARGE, 3.0 / 18.0)
	_check("At Strain 9, Burn and Misfire weights double", high_ok, "%s" % [high_counts])


func _check_strain_and_draw() -> void:
	var settle: Settle = await _fresh_settle(Vector3(-40.0, 0.0, 20.0))
	var toauma: Toauma = taln.toauma
	await _tap("surge_1")
	_check("A Toa'uma-routed Settle adds 0.25 Strain", is_equal_approx(toauma.strain, 0.25), "%.2f" % toauma.strain)

	var before: float = taln.investiture.current
	await _tap("draw")
	var after_draw: float = taln.investiture.current
	await _tap("draw")
	_check("Draw: +30 Investiture, +1 Strain, then a 9 s cooldown", is_equal_approx(after_draw - before, 30.0)
			and is_equal_approx(toauma.strain, 1.25) and taln.investiture.current == after_draw
			and toauma.draw_cooldown_left > 8.5, "+%.0f, Strain %.2f, cooldown %.2f s"
			% [after_draw - before, toauma.strain, toauma.draw_cooldown_left])
	await _ticks(540)
	var drawn_again: bool = toauma.draw()
	_check("Draw is back after 9 s; Strain never decays", drawn_again and is_equal_approx(toauma.strain, 2.25),
			"drew %s, Strain %.2f" % [drawn_again, toauma.strain])
	toauma.add_strain(20.0)
	_check("Strain stops at 9", toauma.strain == 9.0, "%.2f" % toauma.strain)

	await _tap("debug_reset_strain")
	var reset: float = toauma.strain
	await _tap("debug_add_strain")
	_check("Ctrl+7 resets Strain, Ctrl+6 adds 1", reset == 0.0 and toauma.strain == 1.0,
			"after reset %.2f, after add %.2f" % [reset, toauma.strain])


func _check_honorblade() -> void:
	var settle: Settle = await _fresh_settle(Vector3(-40.0, 0.0, 20.0))
	var toauma: Toauma = taln.toauma
	_force_effect(Toauma.Effect.BURN)
	var used: Array = []
	toauma.used.connect(func(is_draw: bool, _e: Toauma.Effect) -> void: used.append(is_draw))
	var health_before: float = taln.health.current
	await _tap("debug_honorblade")
	await _tap("surge_1")
	_check("Ctrl+5 Honorblade: a Blade-eligible Surge adds no Strain and rolls nothing", taln.loadout.honorblade_held
			and toauma.strain == 0.0 and used.is_empty() and taln.health.current == health_before,
			"held %s, Strain %.2f, %d routed uses" % [taln.loadout.honorblade_held, toauma.strain, used.size()])
	var voidlight: SkillDef = settle.skill.duplicate()
	voidlight.routing = SkillDef.Routing.VOIDLIGHT_ONLY
	settle.skill = voidlight
	_recharge(settle)
	await _tap("surge_1")
	_check("A Voidlight-only Surge still routes through Toa'uma", used == [false]
			and is_equal_approx(toauma.strain, 0.25), "%d routed uses, Strain %.2f" % [used.size(), toauma.strain])
	await _tap("debug_honorblade")
	_check("Ctrl+5 again puts the Blade away", not taln.loadout.honorblade_held, "")


func _check_effects() -> void:
	var taln_at := Vector3(-40.0, 0.0, 20.0)
	var settle: Settle = await _fresh_settle(taln_at)
	var toauma: Toauma = taln.toauma
	var ash: SwarmType = load(ASH_WALKER)
	var forward: Vector3 = _camera_forward()

	# Overcharge: 36 damage kills a 30 HP enemy; the root runs 4 s.
	_force_effect(Toauma.Effect.OVERCHARGE)
	var survivor: int = swarm.spawn(ash, taln_at + forward * 4.0, 4.0, 1.0)
	swarm.spawn(ash, taln_at + forward * 5.5, 2.5, 1.0)
	var effects: Array = []
	settle.cast.connect(func(_d: Vector3, _h: int, _t: bool, e: Toauma.Effect) -> void: effects.append(e))
	await _tap("surge_1")
	await _ticks(3)
	_check("Overcharge: the Surge hits at 200% damage and root", effects == [Toauma.Effect.OVERCHARGE]
			and swarm.get_alive_count() == 1 and swarm.get_enemy_root_time(survivor) > 3.8,
			"alive %d, root %.2f s" % [swarm.get_alive_count(), swarm.get_enemy_root_time(survivor)])
	swarm.clear_all()
	var before: float = taln.investiture.current
	toauma.draw()
	_check("Overcharge on a Draw: double Investiture", is_equal_approx(taln.investiture.current - before, 60.0),
			"+%.0f" % (taln.investiture.current - before))

	# Voidlight burn: 6% of max Health as Void, through armor like any hit.
	_force_effect(Toauma.Effect.BURN)
	taln.health.set_invulnerable(&"checks", false)
	var hits: Array = []
	taln.health.damaged.connect(func(amount: float, type: Damage.Type) -> void: hits.append([amount, type]))
	var expected: float = taln.tuning.max_health * 0.06 * 100.0 / (100.0 + taln.health.get_armor())
	_recharge(settle)
	await _tap("surge_1")
	taln.health.set_invulnerable(&"checks", true)
	_check("Voidlight burn: 6% of max Health as Void damage", hits.size() == 1 and is_equal_approx(hits[0][0], expected)
			and hits[0][1] == Damage.Type.VOID, "%s, expected %.2f" % [hits, expected])

	# Misfire: within ±45° of the aim.
	_force_effect(Toauma.Effect.MISFIRE)
	var dirs: Array[Vector3] = []
	settle.cast.connect(func(d: Vector3, _h: int, _t: bool, _e: Toauma.Effect) -> void: dirs.append(d))
	for k in 30:
		_recharge(settle)
		settle.try_cast()
	var widest: float = 0.0
	for d in dirs:
		widest = maxf(widest, rad_to_deg(d.angle_to(forward)))
	_check("Misfire: turns the Surge up to ±45° off its aim", dirs.size() == 30 and widest <= 45.01 and widest > 25.0,
			"widest %.1f° over %d casts" % [widest, dirs.size()])

	# Lurch: enemies within 6 m and Taln slowed to 0.6 for 2 s.
	_force_effect(Toauma.Effect.LURCH)
	var near: int = swarm.spawn(ash, taln_at + Vector3(-5.0, 0.0, 0.0), 1.0, 1.0)
	var far: int = swarm.spawn(ash, taln_at + Vector3(-8.0, 0.0, 0.0), 1.0, 1.0)
	_recharge(settle)
	await _tap("surge_1")
	var slowed: bool = swarm.get_enemy_slow_time(near) > 1.8 and swarm.get_enemy_slow_time(far) == 0.0
	var taln_mult: float = taln.get_speed_multiplier()
	await _ticks(125)
	_check("Lurch: enemies within 6 m and Taln at 0.6 speed for 2 s", slowed and is_equal_approx(taln_mult, 0.6)
			and taln.get_speed_multiplier() == 1.0, "enemies slowed %s, Taln x%.2f then x%.2f"
			% [slowed, taln_mult, taln.get_speed_multiplier()])

	# Echo: fires again 1 s later, free, with no extra Strain.
	_force_effect(Toauma.Effect.ECHO)
	swarm.clear_all()
	var echoes: Array = []
	settle.echoed.connect(func(d: Vector3, h: int) -> void: echoes.append([d, h]))
	# Earlier casts here capped Strain at 9; start below the cap to see the gain.
	toauma.strain = 0.0
	_recharge(settle)
	var spend_from: float = taln.investiture.current
	var strain_from: float = toauma.strain
	await _tap("surge_1")
	await _ticks(50)
	var early: int = echoes.size()
	await _ticks(15)
	_check("Echo: the Surge fires again 1.0 s later at no cost or Strain", early == 0 and echoes.size() == 1
			and is_equal_approx(spend_from - taln.investiture.current, 25.0)
			and is_equal_approx(toauma.strain - strain_from, 0.25), "echoes %d by 0.9 s, %d by 1.1 s; spent %.0f"
			% [early, echoes.size(), spend_from - taln.investiture.current])

	# Speaks: a line, and the gem pulses.
	_force_effect(Toauma.Effect.SPEAKS)
	var lines: Array[String] = []
	toauma.spoke.connect(func(line: String) -> void: lines.append(line))
	_recharge(settle)
	await _tap("surge_1")
	await process_frame
	var gem: ToaumaGem = taln.get_node("Body/Gem")
	_check("Speaks: logs a placeholder line; the gem pulses", lines.size() == 1 and not lines[0].is_empty()
			and gem.speak_left > 0.0, "%s, speak pulse %.2f s" % [lines, gem.speak_left])


func _check_notice() -> void:
	var taln_at := Vector3(-40.0, 0.0, 20.0)
	await _fresh_settle(taln_at)
	var spawner: SpawnDirector = station.get_node("SpawnDirector")
	var packs: Array = []
	spawner.pack_spawned.connect(func(id: StringName, slots: Array[int]) -> void: packs.append([id, slots]))
	var bank: float = spawner.bank
	var toauma: Toauma = taln.toauma
	for k in 3:
		await _tap("debug_add_strain")
	var first: Array[int] = packs[0][1] if packs.size() == 1 else ([] as Array[int])
	var dists: Array[float] = []
	for slot in first:
		dists.append(_flat_dist(swarm.get_enemy_position(slot), taln_at))
	var out_ok: bool = dists.all(func(d: float) -> bool: return absf(d - 26.0) <= 1.3)
	_check("Notice at Strain 3: 3 hunters, 26 m out, outside the budget", packs.size() == 1
			and packs[0][0] == &"notice_hunter" and first.size() == 3 and out_ok and spawner.bank == bank,
			"packs %d, distances %s" % [packs.size(), dists])
	toauma.add_strain(0.5)
	toauma.add_strain(3.0)
	toauma.add_strain(3.0)
	var sizes: Array = packs.map(func(p: Array) -> int: return p[1].size())
	_check("Notice at 6 and 9: 5 and 9 hunters, once each", sizes == [3, 5, 9], "pack sizes %s" % [sizes])
	toauma.reset_strain()
	toauma.add_strain(3.0)
	sizes = packs.map(func(p: Array) -> int: return p[1].size())
	_check("A reset (new cycle) arms Notice again", sizes == [3, 5, 9, 3], "pack sizes %s" % [sizes])


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _check_gem() -> void:
	await _fresh_settle(Vector3(-40.0, 0.0, 20.0))
	var gem: ToaumaGem = taln.get_node("Body/Gem")
	var toauma: Toauma = taln.toauma
	var material: StandardMaterial3D = gem.material_override
	var rest_ok: bool = material.emission.is_equal_approx(Color("#D9A55B")) and gem.flicker_left == 0.0
	var slow: float = gem.pulse_rate()
	toauma.strain = 9.0
	var fast: float = gem.pulse_rate()
	toauma.strain = 0.0
	await _tap("draw")
	var flickering: bool = gem.flicker_left > 0.0
	await process_frame
	var hue: Color = material.emission
	var voidlight: bool = hue.is_equal_approx(Color("#6B3FA0")) or hue.is_equal_approx(Color("#7FE3D6"))
	_check("Gem: ochre at rest, pulse rate rising with Strain, Voidlight flicker on a routed use",
			rest_ok and fast > slow and flickering and voidlight, "rest %s, %.2f → %.2f Hz, flicker hue %s"
			% [rest_ok, slow, fast, hue])


# --- step 7: inputs ------------------------------------------------------------------

## A readable name for each event on an action, e.g. "mouse 1", "key Q", "pad 3", "axis 5+".
func _event_names(action: StringName) -> Array[String]:
	var names: Array[String] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: InputEventKey = event
			names.append(("ctrl+" if key.ctrl_pressed else "") + "key " + OS.get_keycode_string(key.physical_keycode))
		elif event is InputEventMouseButton:
			names.append("mouse %d" % (event as InputEventMouseButton).button_index)
		elif event is InputEventJoypadButton:
			names.append("pad %d" % (event as InputEventJoypadButton).button_index)
		elif event is InputEventJoypadMotion:
			var motion: InputEventJoypadMotion = event
			names.append("axis %d%s" % [motion.axis, "+" if motion.axis_value > 0.0 else "-"])
	return names


func _check_input_table() -> void:
	var expected: Dictionary = {
		&"surge_1": ["mouse %d" % MOUSE_BUTTON_LEFT, "axis %d+" % JOY_AXIS_TRIGGER_RIGHT],
		&"surge_2": ["mouse %d" % MOUSE_BUTTON_RIGHT, "axis %d+" % JOY_AXIS_TRIGGER_LEFT],
		&"surge_3": ["key Q", "pad %d" % JOY_BUTTON_Y],
		&"draw": ["key E", "pad %d" % JOY_BUTTON_X],
	}
	var wrong: Array[String] = []
	for action: StringName in expected:
		var names: Array[String] = _event_names(action) if InputMap.has_action(action) else ([] as Array[String])
		if names != Array(expected[action], TYPE_STRING, &"", null):
			wrong.append("%s = %s" % [action, names])
	# Pad A was held back for Catalyze; since P2-06 it's bound to exactly that
	# (Welcome and committing a catalyst) and nothing else.
	var a_bound: Array[String] = []
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_") and _event_names(action).has("pad %d" % JOY_BUTTON_A) \
				and not [&"welcome", &"catalyze_commit"].has(action):
			a_bound.append(action)
	_check("Inputs: Surge 1 LMB/RT, Surge 2 RMB/LT, Surge 3 Q/Y, Draw E/X; pad A only on Welcome and Catalyze", wrong.is_empty()
			and a_bound.is_empty(), "mismatched %s, other actions on pad A %s" % [wrong, a_bound])


func _check_input_triggers() -> void:
	var settle: Settle = await _fresh_settle(Vector3(-40.0, 0.0, 20.0))
	var casts: Array[int] = [0]
	settle.cast.connect(func(_d: Vector3, _h: int, _t: bool, _e: Toauma.Effect) -> void: casts[0] += 1)
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	Input.parse_input_event(trigger)
	await _ticks(2)
	trigger.axis_value = 0.0
	Input.parse_input_event(trigger)
	await _ticks(1)
	_check("Pulling RT casts Surge 1", casts[0] == 1, "%d casts" % casts[0])

	var before: float = taln.investiture.current
	var strain: float = taln.toauma.strain
	await _tap("surge_2")
	await _tap("surge_3")
	_check("Surge 2 and 3 are bound to inputs but empty: a press does nothing",
			taln.loadout.get_bound_surge(1) == null and taln.loadout.get_bound_surge(2) == null
			and taln.investiture.current == before and taln.toauma.strain == strain, "spent %.0f"
			% (before - taln.investiture.current))


func _check_click_recapture() -> void:
	var settle: Settle = await _fresh_settle(Vector3(-40.0, 0.0, 20.0))
	var casts: Array[int] = [0]
	settle.cast.connect(func(_d: Vector3, _h: int, _t: bool, _e: Toauma.Effect) -> void: casts[0] += 1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for button: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var click := InputEventMouseButton.new()
		click.button_index = button
		click.pressed = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Input.parse_input_event(click)
		await _ticks(2)
		click.pressed = false
		Input.parse_input_event(click)
		await _ticks(1)
	# The headless display server can't capture the mouse, so the recapture itself
	# and a captured click casting are MANUAL checks.
	_check("While the mouse is released, left and right clicks never cast", casts[0] == 0,
			"%d casts" % casts[0])


# --- step 8: overlay, hunter lifetime -------------------------------------------------

func _check_hunter_lifetime() -> void:
	var taln_at := Vector3(-40.0, 0.0, 20.0)
	await _fresh_settle(taln_at)
	# Since P2-05 a lifetime running out is enemy_died with rewarded = false (not a kill).
	var died: Array[StringName] = []
	var expired: Array[StringName] = []
	swarm.enemy_died.connect(func(id: StringName, _at: Vector3, rewarded: bool) -> void:
		(died if rewarded else expired).append(id))
	var ash: SwarmType = load(ASH_WALKER)
	var brief: int = swarm.spawn(ash, taln_at + Vector3(5.0, 0.0, 0.0), 1.0, 1.0)
	swarm.set_enemy_lifetime(brief, 0.5)
	await _ticks(40)
	_check("set_enemy_lifetime(): the enemy expires as enemy_died(rewarded = false), not a kill",
			expired == [&"ash_walker"] and died.is_empty() and swarm.get_alive_count() == 0,
			"expired %s, died %s" % [expired, died])

	expired.clear()
	var toauma: Toauma = taln.toauma
	toauma.add_strain(3.0)
	var first_pack: int = swarm.get_alive_count()
	await _ticks(29 * 60)
	var at_29: int = swarm.get_alive_count()
	await _ticks(90)
	var after_30: int = swarm.get_alive_count()
	toauma.add_strain(6.0)
	var strain_9_packs: int = swarm.get_alive_count() - after_30
	await _ticks(31 * 60)
	_check("Strain 3 and 6 hunters die after 30 s if not killed; Strain 9 hunters stay",
			first_pack == 3 and at_29 == 3 and after_30 == 0 and expired.size() == 3 + 5
			and strain_9_packs == 5 + 9 and swarm.get_alive_count() == 9 and died.is_empty(),
			"Strain 3 pack: %d, %d at 29 s, %d after 30 s; then 6 and 9 packs: %d alive after 31 s, %d expired in all"
			% [first_pack, at_29, after_30, swarm.get_alive_count(), expired.size()])


func _check_overlay() -> void:
	var taln_at := Vector3(-40.0, 0.0, 20.0)
	var settle: Settle = await _fresh_settle(taln_at)
	taln.loadout.get_behavior(&"breaking_stroke").process_mode = Node.PROCESS_MODE_INHERIT
	var overlay: DebugOverlay = station.get_node("DebugOverlay")
	var label: Label = overlay.get_node("Panel/Label")
	overlay.visible = true
	var ash: SwarmType = load(ASH_WALKER)
	var forward: Vector3 = _camera_forward()
	for k in 3:
		swarm.spawn(ash, taln_at + forward * (4.5 + k), 4.0, 1.0)
	_force_effect(Toauma.Effect.LURCH)
	await _tap("surge_1")
	await _tap("draw")
	await process_frame
	var text: String = label.text
	var want: Array[String] = [
		"Investiture 105.0",  # 100 − 25 for Settle + 30 from the Draw.
		"Strain     1.25 / 9, next Notice at 3, side effect 100%",
		"Routing    Toa'uma",
		"Weapon     breaking_stroke L1, next swing",
		"Surges     1 settle ",
		" | 2 - | 3 -",
		"Draw       8.",
		"Side eff.  Lurch on a Draw, 0.0 s ago",
		"Rooted     3",
		"(speed x0.60)",
	]
	var missing: Array[String] = want.filter(func(line: String) -> bool: return not text.contains(line))
	_check("Overlay: Investiture, Strain and next Notice, weapon swing, Surge cooldowns, Draw, last side effect, routing, rooted",
			missing.is_empty(), "missing %s" % [missing] if not missing.is_empty() else "all present")
	await _tap("debug_honorblade")
	await process_frame
	_check("Overlay shows Blade routing while the Honorblade is held", label.text.contains("Routing    Blade"),
			"%s" % Array(label.text.split("\n")).filter(func(l: String) -> bool: return l.begins_with("Routing")))


# --- step 9: before calling it done --------------------------------------------------

func _info(label: String, detail: String) -> void:
	print("INFO  %s  (%s)" % [label, detail])


## Spawns count basic enemies on a ring around Taln, off blocked cells.
func _spawn_ring(count: int, near: float, far: float) -> void:
	var ash: SwarmType = load(ASH_WALKER)
	var spawned: int = 0
	var k: int = 0
	while spawned < count:
		var angle: float = k * 2.39996
		var at: Vector3 = taln.global_position + Vector3(cos(angle), 0.0, sin(angle)) * (near + fmod(k * 0.37, far - near))
		k += 1
		if not ground.is_blocked_at(at.x, at.z):
			swarm.spawn(ash, at, 1.0, 1.0)
			spawned += 1


func _check_done_weapon() -> void:
	var taln_at := Vector3(-40.0, 0.0, 20.0)
	var weapon: BreakingStroke = await _fresh_weapon(taln_at)
	swarm.set_target(null)
	var swings: Array = []
	weapon.swung.connect(func(dir: Vector3, hits: int) -> void: swings.append([dir, hits]))
	var deaths: Array[int] = [0]
	swarm.enemy_died.connect(func(_id: StringName, _at: Vector3, _rewarded: bool) -> void: deaths[0] += 1)
	var out_of_reach: Vector3 = _turned(Vector3.RIGHT, 30.0) * 4.0
	swarm.spawn(load(ASH_WALKER), taln_at + out_of_reach, 1.0, 1.0)
	await _ticks(30)
	var idle_swings: int = swings.size()
	var at := Vector3(2.0, 0.0, 1.5).normalized()
	swarm.spawn(load(ASH_WALKER), taln_at + at * 2.5, 1.0, 1.0)  # Wave 1: HP × 1.0.
	await _ticks(5)
	_check("DONE  Weapon: swings only with an enemy in reach, points at it, one-shots a wave-1 basic enemy",
			idle_swings == 0 and swings.size() == 1 and (swings[0][0] as Vector3).is_equal_approx(at)
			and deaths[0] == 1, "%d swings with one at 4 m; then %d swing(s) at %s, %d death(s)"
			% [idle_swings, swings.size(), swings[0][0] if swings.size() > 0 else "-", deaths[0]])


func _check_done_settle_cone() -> void:
	var taln_at := Vector3(-40.0, 0.0, 20.0)
	var settle: Settle = await _fresh_settle(taln_at)
	var forward: Vector3 = _camera_forward()
	var ash: SwarmType = load(ASH_WALKER)
	taln.rotation.y = atan2(-forward.x, -forward.z)
	# 5.6 m: inside the knockback reach where the 4.5 m charge ends, clear of his body.
	var target: int = swarm.spawn(ash, taln_at + forward * 5.6, 4.0, 1.0)
	var toucher: int = swarm.spawn(ash, taln_at + forward * 0.75, 4.0, 1.0)
	var target_at: Vector3 = swarm.get_enemy_position(target)
	var cast: bool = settle.try_cast()
	var root_at_cast: float = swarm.get_enemy_root_time(target)
	await process_frame
	await process_frame
	var mm: MultiMesh = (swarm.get_child(0) as MultiMeshInstance3D).multimesh
	_check("DONE  Settle cone: damages, roots for 2.0 s, stone tint on", cast and is_equal_approx(root_at_cast, 2.0)
			and swarm.get_enemy_root_time(toucher) > 0.0 and _rooted_amount(mm, 0) == 1.0 and _rooted_amount(mm, 1) == 1.0,
			"root %.2f s at the cast, tint w %.2f / %.2f" % [root_at_cast, _rooted_amount(mm, 0), _rooted_amount(mm, 1)])

	swarm.set_target(taln)  # Contact needs a target; the rooted ones stay put anyway.
	taln.health.set_invulnerable(&"checks", false)
	var hurt: Array[float] = []
	taln.health.damaged.connect(func(amount: float, _type: Damage.Type) -> void: hurt.append(amount))
	await _ticks(30)
	taln.health.set_invulnerable(&"checks", true)
	_check("DONE  A rooted enemy touching Taln still hurts him", swarm.get_enemy_root_time(toucher) > 0.0
			and hurt.size() >= 1, "%d hits in 0.5 s while rooted" % hurt.size())

	# Shoulder straight at the rooted enemy, past a free one that shows the knockback.
	var free: int = swarm.spawn(ash, taln_at + forward * 3.0 + _turned(forward, 90.0) * 0.6, 4.0, 1.0)
	var free_at: Vector3 = swarm.get_enemy_position(free)
	var toucher_at: Vector3 = swarm.get_enemy_position(toucher)
	await _tap("shoulder")
	await _ticks(30)
	var rooted_moved: float = _flat_dist(swarm.get_enemy_position(target), target_at)
	var toucher_moved: float = _flat_dist(swarm.get_enemy_position(toucher), toucher_at)
	var free_moved: float = _flat_dist(swarm.get_enemy_position(free), free_at)
	_check("DONE  Rooted enemies ignore Shoulder knockback", swarm.get_enemy_root_time(target) > 0.0
			and rooted_moved < 0.01 and free_moved > 0.5, ("rooted in the path moved %.3f m (the one at Taln %.2f m, "
			+ "pushed out of his body); a free one beside the path moved %.2f m") % [rooted_moved, toucher_moved, free_moved])
	await _ticks(60)
	_check("DONE  The root ends at 2.0 s", swarm.get_enemy_root_time(target) == 0.0, "root left %.2f s"
			% swarm.get_enemy_root_time(target))


func _check_done_soft_lock() -> void:
	var taln_at := Vector3(-40.0, 0.0, 20.0)
	var settle: Settle = await _fresh_settle(taln_at)
	var forward: Vector3 = _camera_forward()
	var ash: SwarmType = load(ASH_WALKER)
	for k in 2:
		swarm.spawn(ash, taln_at + _turned(forward, -10.0) * (4.0 + k * 1.2), 4.0, 1.0)
	for k in 4:
		swarm.spawn(ash, taln_at + _turned(forward, 10.0) * (3.5 + k * 1.0), 4.0, 1.0)
	swarm.spawn(ash, taln_at + _turned(forward, 40.0) * 4.0, 4.0, 1.0)  # Denser still is outside ±15°...
	swarm.spawn(ash, taln_at + _turned(forward, 42.0) * 5.0, 4.0, 1.0)
	swarm.spawn(ash, taln_at + _turned(forward, 44.0) * 6.0, 4.0, 1.0)
	swarm.spawn(ash, taln_at + _turned(forward, 41.0) * 3.5, 4.0, 1.0)
	swarm.spawn(ash, taln_at + _turned(forward, 43.0) * 4.5, 4.0, 1.0)
	await _ticks(45)  # The reticle eases toward the aim (reticle_follow_rate).
	var reticle: Vector3 = (settle.get_node("Reticle") as MeshInstance3D).global_basis.z
	var dirs: Array[Vector3] = []
	settle.cast.connect(func(d: Vector3, _h: int, _t: bool, _e: Toauma.Effect) -> void: dirs.append(d))
	settle.try_cast()
	var want: Vector3 = _turned(forward, 10.0)
	_check("DONE  Soft-lock pulls the cone and reticle to the denser group within ±15° of the camera",
			dirs.size() == 1 and dirs[0].is_equal_approx(want) and rad_to_deg(reticle.angle_to(want)) < 0.5,
			"cast %.1f°, reticle %.1f° off camera-forward (groups at -10° ×2, +10° ×4, ~42° ×5)"
			% [rad_to_deg(Vector2(forward.x, forward.z).angle_to(Vector2(dirs[0].x, dirs[0].z))) if dirs.size() > 0 else 0.0,
			rad_to_deg(Vector2(forward.x, forward.z).angle_to(Vector2(reticle.x, reticle.z)))])


func _check_done_strain() -> void:
	var settle: Settle = await _fresh_settle(Vector3(-40.0, 0.0, 20.0))
	var toauma: Toauma = taln.toauma
	var steps: Array[float] = []
	for k in 2:
		_recharge(settle)
		await _tap("surge_1")
		steps.append(toauma.strain)
	await _tap("draw")
	steps.append(toauma.strain)
	await _ticks(12 * 60)
	steps.append(toauma.strain)
	_check("DONE  Each routed Settle adds 0.25 Strain, each Draw 1; nothing resets it in the run",
			steps == [0.25, 0.5, 1.5, 1.5], "Strain after Settle, Settle, Draw, then 12 s: %s" % [steps])


func _check_done_rates() -> void:
	await _fresh()
	var toauma: Toauma = taln.toauma
	toauma.rng.seed = 20260926
	var names: PackedStringArray = Toauma.Effect.keys()
	var pooled_counts: Dictionary = {}
	var pooled_expected: Dictionary = {}
	var rates_ok: bool = true
	for strain: float in [0.0, 5.0, 9.0]:
		toauma.strain = strain
		var p: float = toauma.side_effect_chance()
		var counts: Dictionary = {}
		var hits: int = 0
		for k in 200:
			var e: Toauma.Effect = toauma.roll_effect(false)
			if e != Toauma.Effect.NONE:
				hits += 1
				counts[e] = counts.get(e, 0) + 1
				pooled_counts[e] = pooled_counts.get(e, 0) + 1
		var weights: Dictionary = toauma.effect_weights()
		var total: int = 0
		for w: int in weights.values():
			total += w
		for e: Toauma.Effect in weights:
			pooled_expected[e] = pooled_expected.get(e, 0.0) + hits * float(weights[e]) / total
		var rate: float = hits / 200.0
		var allowed: float = 3.0 * sqrt(p * (1.0 - p) / 200.0)
		rates_ok = rates_ok and absf(rate - p) <= allowed
		var logged: Array[String] = []
		for e: Toauma.Effect in weights:
			logged.append("%s %d" % [names[e].capitalize(), counts.get(e, 0)])
		_info("200 rolls at Strain %.0f" % strain, "%d side effects = %.1f%% (expected %.0f%% ± %.1f): %s"
				% [hits, rate * 100.0, p * 100.0, allowed * 100.0, ", ".join(logged)])
	toauma.strain = 0.0
	# Weights: chi-square of the pooled hits against each Strain's own table (5 degrees of freedom).
	var chi2: float = 0.0
	for e: Toauma.Effect in pooled_expected:
		var diff: float = pooled_counts.get(e, 0) - pooled_expected[e]
		chi2 += diff * diff / pooled_expected[e]
	_check("DONE  Side-effect rate about 5% / 30% / 50% at Strain 0 / 5 / 9 over 200 rolls each", rates_ok,
			"each within 3 standard errors; counts logged above")
	_check("DONE  The table weights hold (chi-square of all hits, p > 0.001)", chi2 < 20.52,
			"chi² %.2f with 5 degrees of freedom" % chi2)


func _check_done_notice() -> void:
	await _fresh_settle(Vector3(-40.0, 0.0, 20.0))
	var spawner: SpawnDirector = station.get_node("SpawnDirector")
	var sizes: Array[int] = []
	var at_strain: Array[float] = []
	spawner.pack_spawned.connect(func(_id: StringName, slots: Array[int]) -> void:
		sizes.append(slots.size())
		at_strain.append(taln.toauma.strain))
	for k in 44:  # 0.25 at a time, up to 9 and past it.
		taln.toauma.add_strain(0.25)
	_check("DONE  Notice packs spawn exactly once each: 3, 5 and 9 hunters at Strain 3, 6 and 9", sizes == [3, 5, 9]
			and at_strain == [3.0, 6.0, 9.0], "packs %s at Strain %s" % [sizes, at_strain])


func _check_done_honorblade() -> void:
	var settle: Settle = await _fresh_settle(Vector3(-40.0, 0.0, 20.0))
	_force_effect(Toauma.Effect.BURN)
	var toauma: Toauma = taln.toauma
	var rolls: Array[int] = [0]
	toauma.used.connect(func(_d: bool, _e: Toauma.Effect) -> void: rolls[0] += 1)
	await _tap("debug_honorblade")
	for k in 3:
		_recharge(settle)
		await _tap("surge_1")
	var material: ShaderMaterial = (settle.get_node("Cracks") as MeshInstance3D).material_override
	_check("DONE  Honorblade on (Ctrl+5): Settle adds no Strain, never rolls, renders ochre", toauma.strain == 0.0
			and rolls[0] == 0 and material.get_shader_parameter(&"flicker") == 0.0
			and (material.get_shader_parameter(&"core_color") as Color).is_equal_approx(Color("#D9A55B")),
			"3 casts: Strain %.2f, %d rolls, core %s" % [toauma.strain, rolls[0], material.get_shader_parameter(&"core_color")])


func _check_done_debug_keys() -> void:
	await _fresh_settle(Vector3(-40.0, 0.0, 20.0))
	var spawner: SpawnDirector = station.get_node("SpawnDirector")
	var overlay: DebugOverlay = station.get_node("DebugOverlay")
	var light: DirectionalLight3D = station.get_node("InspectLight")
	var results: Dictionary = {}
	var ash: SwarmType = load(ASH_WALKER)
	swarm.spawn(ash, taln.global_position + Vector3(3.0, 0.0, 0.0), 1.0, 1.0)
	var overlay_was: bool = overlay.visible
	await _tap("debug_overlay")
	results["F3 overlay"] = overlay.visible != overlay_was
	var light_was: bool = light.visible
	await _tap("debug_inspect_light")
	results["F4 light"] = light.visible != light_was
	await _tap("debug_blast")
	await _ticks(4)
	results["Ctrl+1 blast"] = swarm.get_alive_count() == 0
	var stress_was: bool = spawner.stress
	await _tap("debug_stress")
	results["Ctrl+2 stress"] = spawner.stress != stress_was
	var paused_was: bool = spawner.paused
	await _tap("debug_pause_spawner")
	results["Ctrl+3 pause"] = spawner.paused != paused_was
	# The debug tally, not the total: Ctrl+3 just unpaused the spawner, so the
	# Well's ambient income (P2-05) trickles in too.
	var inv: float = taln.investiture.income_by_source.get(&"debug", 0.0)
	await _tap("debug_grant_investiture")
	results["Ctrl+4 Investiture"] = taln.investiture.income_by_source.get(&"debug", 0.0) - inv == 100.0
	await _tap("debug_honorblade")
	results["Ctrl+5 Honorblade"] = taln.loadout.honorblade_held
	await _tap("debug_add_strain")
	results["Ctrl+6 Strain"] = taln.toauma.strain == 1.0
	await _tap("debug_reset_strain")
	results["Ctrl+7 reset"] = taln.toauma.strain == 0.0
	var failed: Array = results.keys().filter(func(k: String) -> bool: return not results[k])
	_check("DONE  Every debug key does its job in a running game (headless)", failed.is_empty(),
			"failed %s" % [failed] if not failed.is_empty() else "%d keys" % results.size())


func _check_done_performance() -> void:
	var taln_at := Vector3(0.0, 0.0, 40.0)
	await _fresh_swarm(taln_at)
	taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT
	var settle: Settle = taln.loadout.get_behavior(&"settle")
	_no_side_effects()
	# Kills drop motes since P2-05; leave them uncollected so the refills run.
	(station.get_node("MoteServer") as MoteServer).set_target(null)
	_spawn_ring(400, 6.0, 26.0)
	var casts: Array[int] = [0]
	settle.cast.connect(func(_d: Vector3, _h: int, _t: bool, _e: Toauma.Effect) -> void: casts[0] += 1)
	var samples: PackedFloat32Array = []
	var alive: PackedInt32Array = []
	var refills: int = 0
	for f in 1200:
		# Top back up to 400 on the spawn ring as Settle and the weapon kill.
		_spawn_ring(400 - swarm.get_alive_count(), 18.0, 26.0)
		alive.append(swarm.get_alive_count())
		if not taln.investiture.can_afford(settle.skill.investiture_cost):
			_send("debug_grant_investiture", true)
			refills += 1
		_send("surge_1", true)
		var before: int = Time.get_ticks_usec()
		await _ticks(1)
		samples.append((Time.get_ticks_usec() - before) / 1000.0)
		_send("surge_1", false)
		_send("debug_grant_investiture", false)
	var total: float = 0.0
	var worst: float = 0.0
	for ms in samples:
		total += ms
		worst = maxf(worst, ms)
	var sorted: PackedFloat32Array = samples.duplicate()
	sorted.sort()
	var p99: float = sorted[int(sorted.size() * 0.99)]
	var over_4ms: int = 0
	for ms in samples:
		if ms > 4.0:
			over_4ms += 1
	var min_alive: int = 100000
	for n in alive:
		min_alive = mini(min_alive, n)
	_check("DONE  400 alive with Settle spammed through Ctrl+4 refills: frame cost fits 60 fps (CPU side)",
			# Judged on avg and p99: a lone frame near Windows' 15.6 ms timer tick shows up in
			# some runs regardless of what the game does (a cast itself costs ~50 us).
			total / samples.size() < 4.0 and p99 < 4.0 and casts[0] >= 5 and refills >= 1 and min_alive == 400,
			"avg %.3f ms, p99 %.3f ms, worst %.3f ms (%d frames over 4 ms) over 20 s; %d casts, %d refills, at least %d alive going into every frame"
			% [total / samples.size(), p99, worst, over_4ms, casts[0], refills, min_alive])
