extends SceneTree
## P2-14 (Doomhunter: Rend's elite priority, Lunge's hunt, the Shade and
## Bastion passives) checks, run headless against the Braize slice at a
## fixed 60 fps. Prints PASS/FAIL per check and exits with the number of
## failures. Meta state goes to user://checks_meta.json.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_14_checks.gd

const SLICE := "res://scenes/braize_slice.tscn"
const ASH_WALKER := "res://data/swarm/ash_walker.tres"
const COMMANDER := "res://data/swarm/ash_commander.tres"
const CHECKS_META := "user://checks_meta.json"
## Open, level ground in The Shelf, clear of features, pads and pools.
const OPEN := Vector3(20.0, 0.0, 115.0)

var station: BraizeSlice
var taln: Taln
var swarm: SwarmServer
var spawner: SpawnDirector
var ground: StationGround
var awareness: Awareness
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
	meta.set_aspect(&"doomhunter_shade")
	cycle = Cycle.director()
	_check_data()
	print("")
	await _check_kit()
	await _check_rend_elite()
	await _check_rend_fallback()
	await _check_lunge_hunt()
	await _check_lunge_short()
	await _check_bastion()
	print("")
	print("MANUAL  Hunting a commander through its buffed escort, stealthy vs head-on, and the landing of a Lunge need a rendered recording.")
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


func _fresh(at: Vector3 = OPEN) -> void:
	paused = false
	if is_instance_valid(station):
		station.queue_free()
		await _frames(1)
	station = (load(SLICE) as PackedScene).instantiate()
	root.add_child(station)
	taln = station.get_node("Taln")
	swarm = station.get_node("SwarmServer")
	spawner = station.get_node("SpawnDirector")
	ground = station.get_node("StationGround")
	awareness = station.get_node("Awareness")
	spawner.paused = true
	await ground.ground_changed
	_place(at)
	taln.investiture.add(500.0, &"debug")
	await _ticks(3)


func _place(at: Vector3) -> void:
	taln.global_position = Vector3(at.x, ground.get_surface_height_at(at.x, at.z), at.z)
	taln.velocity = Vector3.ZERO


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _rooted(type: SwarmType, at: Vector3, hp_mult: float = 1.0) -> int:
	var slot: int = swarm.spawn(type, at, hp_mult, 1.0)
	swarm.apply_root_in_cone(at, Vector3.FORWARD, 360.0, 1.0, 60.0)
	return slot


## Ticks until Taln lands (or max_ticks pass). Returns [landed, where].
func _fly(max_ticks: int = 300) -> Array:
	var result: Array = [false, Vector3.ZERO]
	var on_landed := func(_speed: float, at: Vector3) -> void:
		if not result[0]:
			result[0] = true
			result[1] = at
	taln.landed.connect(on_landed)
	for i in max_ticks:
		await physics_frame
		if result[0]:
			break
	taln.landed.disconnect(on_landed)
	return result


# --- data --------------------------------------------------------------------

func _check_data() -> void:
	var shade: AspectDef = load("res://data/aspects/doomhunter_shade.tres")
	var bastion: AspectDef = load("res://data/aspects/doomhunter_bastion.tres")
	var kit := func(a: AspectDef) -> Array: return a.starting_skills.map(func(s: SkillDef) -> StringName: return s.id)
	_check("Doomhunter (Shade) and (Bastion) both start with Rend and Lunge, no Anchored or Fracture; Shade halves detection, Bastion wears +30 Armor",
			kit.call(shade) == [&"rend", &"lunge"] and kit.call(bastion) == [&"rend", &"lunge"] and not shade.anchored
			and not bastion.fracture and shade.detection_mult == 0.5 and shade.armor_bonus == 0.0 and bastion.detection_mult == 1.0
			and bastion.armor_bonus == 30.0, "%s / %s; %.2f, %.0f" % [kit.call(shade), kit.call(bastion), shade.detection_mult,
			bastion.armor_bonus])
	var r: SkillDef = load("res://data/skills/rend.tres")
	var l: SkillDef = load("res://data/skills/lunge.tres")
	var r1: Dictionary = r.params_for(1)
	var l1: Dictionary = l.params_for(1)
	_check("Rend: a Weapon, 40 damage every 1 s on the nearest elite within 5 m, else the nearest enemy within 3 m (+1 acquire); levels 1–9",
			r.kind == SkillDef.Kind.WEAPON and r1.damage == 40.0 and r1.interval == 1.0 and r1.elite_range == 5.0 and r1.range == 3.0
			and r1.acquire_margin == 1.0 and r.level_params.size() == 9, "%s" % [r1])
	_check("Lunge: a Blade-eligible Surge, 20 Investiture, 4 s; an 8 m, 1.2 m-high leap at the nearest commander within 30 m, 30 damage within 2 m on landing",
			l.kind == SkillDef.Kind.SURGE and l.routing == SkillDef.Routing.BLADE_ELIGIBLE and l.investiture_cost == 20.0
			and l.cooldown == 4.0 and l1.distance == 8.0 and l1.apex == 1.2 and l1.hunt_range == 30.0 and l1.damage == 30.0
			and l1.radius == 2.0 and l.level_params.size() == 9, "%s" % [l1])


# --- Doomhunter --------------------------------------------------------------

func _check_kit() -> void:
	await _fresh()
	var ids: Array = taln.loadout.slots.map(func(s: SkillDef) -> StringName: return s.id)
	_check("Doomhunter (Shade) loads with Rend and Lunge (Lunge on Surge 1), detection halved, no Armor",
			ids == [&"rend", &"lunge"] and taln.loadout.get_bound_surge(0).id == &"lunge" and taln.aspect.detection_mult == 0.5
			and taln.health.get_armor() == 0.0, "%s, armor %.0f" % [ids, taln.health.get_armor()])


func _check_rend_elite() -> void:
	await _fresh()
	var rend: Rend = taln.loadout.get_behavior(&"rend")
	rend.cooldown_left = 0.0
	# A walker closer than the commander: Rend still goes for the commander.
	var walker: int = _rooted(load(ASH_WALKER), taln.global_position + Vector3(1.5, 0.0, 0.0), 100.0)
	var commander: int = _rooted(load(COMMANDER), taln.global_position + Vector3(0.0, 0.0, 4.0))
	var struck: Array = []
	rend.struck.connect(func(at: Vector3, hits: int, elite: bool) -> void: struck.append([hits, elite]))
	await _ticks(3)
	var commander_hp: float = swarm.get_enemy_hp(commander)
	var walker_hp: float = swarm.get_enemy_hp(walker)
	_check("Rend strikes the commander 4 m away before the walker at 1.5 m: 40 damage, the walker untouched",
			struck.size() == 1 and struck[0] == [1, true] and is_equal_approx(commander_hp, 320.0) and is_equal_approx(walker_hp, 1200.0),
			"struck %s, commander %.0f, walker %.0f" % [struck, commander_hp, walker_hp])


func _check_rend_fallback() -> void:
	await _fresh()
	var rend: Rend = taln.loadout.get_behavior(&"rend")
	rend.cooldown_left = 0.0
	var walker: int = _rooted(load(ASH_WALKER), taln.global_position + Vector3(2.5, 0.0, 0.0), 100.0)
	var struck: Array = []
	rend.struck.connect(func(at: Vector3, hits: int, elite: bool) -> void: struck.append([hits, elite]))
	await _ticks(3)
	_check("With no elite near, Rend strikes the nearest enemy within 3 m (+1)", struck.size() == 1 and struck[0] == [1, false]
			and is_equal_approx(swarm.get_enemy_hp(walker), 1160.0), "struck %s, Health %.0f" % [struck, swarm.get_enemy_hp(walker)])


func _check_lunge_hunt() -> void:
	await _fresh()
	var lunge: Lunge = taln.loadout.get_behavior(&"lunge")
	# A commander 12 m off to the side, well away from the camera's aim.
	var c_at: Vector3 = taln.global_position + Vector3(12.0, 0.0, 0.0)
	var commander: int = _rooted(load(COMMANDER), c_at)
	await _ticks(1)
	var aim: Vector3 = lunge.aim_direction()
	var aimed: bool = aim.is_equal_approx(Vector3.RIGHT)
	var struck: Array = []
	lunge.struck.connect(func(_at: Vector3, hits: int) -> void: struck.append(hits))
	var start: Vector3 = taln.global_position
	var cast: bool = lunge.try_cast()
	var flight: Array = await _fly()
	var travelled: float = _flat(flight[1], start)
	await _ticks(2)
	_check("Lunge aims itself at the nearest commander and throws Taln 8 m toward it, striking on landing (30 damage within 2 m)",
			aimed and cast and flight[0] and absf(travelled - 8.0) < 0.6 and struck.size() == 1 and not taln.airborne,
			"aimed %s, cast %s, %.1f m, struck %s" % [aimed, cast, travelled, struck])


func _check_lunge_short() -> void:
	await _fresh()
	var lunge: Lunge = taln.loadout.get_behavior(&"lunge")
	var c_at: Vector3 = taln.global_position + Vector3(0.0, 0.0, 5.0)
	var commander: int = _rooted(load(COMMANDER), c_at)
	await _ticks(1)
	var struck: Array = []
	lunge.struck.connect(func(_at: Vector3, hits: int) -> void: struck.append(hits))
	var hp_before: float = swarm.get_enemy_hp(commander)
	lunge.try_cast()
	var in_air: bool = not lunge.try_cast()
	var flight: Array = await _fly()
	await _ticks(2)
	var landed_on: float = _flat(flight[1], c_at)
	_check("A commander nearer than a full lunge is landed on: the leap shortens to it; a Lunge is refused mid-air",
			flight[0] and landed_on < 1.5 and struck == [1] and swarm.get_enemy_hp(commander) < hp_before and in_air,
			"landed %.1f m from it, struck %s, Health %.0f → %.0f, refused in air %s" % [landed_on, struck, hp_before,
			swarm.get_enemy_hp(commander), in_air])


func _check_bastion() -> void:
	meta.set_aspect(&"doomhunter_bastion")
	await _fresh()
	var armor: float = taln.health.get_armor()
	var taken: float = taln.health.damage(13.0, Damage.Type.KINETIC)
	_check("Doomhunter (Bastion) wears +30 Armor all cycle: 13 raw lands as 10", armor == 30.0 and is_equal_approx(taken, 10.0)
			and taln.aspect.detection_mult == 1.0, "armor %.0f, took %.1f" % [armor, taken])
	meta.set_aspect(&"doomhunter_shade")
