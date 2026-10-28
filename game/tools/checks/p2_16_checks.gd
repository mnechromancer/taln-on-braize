extends SceneTree
## P2-16 (boons as Sja-Anat's residue: the pool, offers on commander kills,
## the offer menu, every effect hook, the reset) checks, run headless
## against the Braize slice at a fixed 60 fps. Prints PASS/FAIL per check
## and exits with the number of failures. Meta state goes to
## user://checks_meta.json; telemetry for the one check that records goes to
## user://checks_telemetry_p2_16.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_16_checks.gd

const SLICE := "res://scenes/braize_slice.tscn"
const ASH_WALKER := "res://data/swarm/ash_walker.tres"
const COMMANDER := "res://data/swarm/ash_commander.tres"
const CHECKS_META := "user://checks_meta.json"
const CHECKS_TELEMETRY := "user://checks_telemetry_p2_16"
## Open, level ground in The Shelf, clear of features, pads and pools.
const OPEN := Vector3(20.0, 0.0, 115.0)

var station: BraizeSlice
var taln: Taln
var swarm: SwarmServer
var spawner: SpawnDirector
var ground: StationGround
var awareness: Awareness
var structures: Structures
var boons: Boons
var menu: BoonOfferMenu
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
	meta.set_aspect(&"unaspected")
	cycle = Cycle.director()
	_check_data()
	print("")
	await _check_offer()
	await _check_menu()
	await _check_toauma_bargains()
	await _check_culture_bargains()
	await _check_landing_bargains()
	await _check_reset()
	await _check_telemetry()
	print("")
	print("MANUAL  The offer's read (source, line, bane), and whether a run drifts in play (a Meteor seeding the culture, an Earthshaper's rotting walls), need a rendered recording and playtests.")
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
	structures = station.get_node("Structures")
	boons = station.get_node("Boons")
	menu = station.get_node("BoonOfferMenu")
	spawner.paused = true
	taln.loadout.process_mode = Node.PROCESS_MODE_DISABLED
	await ground.ground_changed
	_place(at)
	taln.investiture.add(500.0, &"debug")
	await _ticks(3)


func _place(at: Vector3) -> void:
	taln.global_position = Vector3(at.x, ground.get_surface_height_at(at.x, at.z), at.z)
	taln.velocity = Vector3.ZERO


func _boon(id: String) -> BoonDef:
	return load("res://data/boons/%s.tres" % id)


func _rooted(type: SwarmType, at: Vector3, hp_mult: float = 1.0) -> int:
	var slot: int = swarm.spawn(type, at, hp_mult, 1.0)
	swarm.apply_root_in_cone(at, Vector3.FORWARD, 360.0, 1.0, 60.0)
	return slot


# --- data --------------------------------------------------------------------

func _check_data() -> void:
	var bt: BoonTuning = load("res://data/tuning/boon_tuning.tres")
	var ids: Array = bt.pool.map(func(b: BoonDef) -> StringName: return b.id)
	var toauma: Array[BoonDef] = bt.pool.filter(func(b: BoonDef) -> bool: return b.source == BoonDef.Source.TOAUMA)
	var culture: Array[BoonDef] = bt.pool.filter(func(b: BoonDef) -> bool: return b.source == BoonDef.Source.CULTURE)
	var toauma_no_bane: bool = toauma.all(func(b: BoonDef) -> bool: return b.bane.is_empty())
	var culture_banes: bool = culture.all(func(b: BoonDef) -> bool: return not b.bane.is_empty() and not b.effects.is_empty())
	var lines: bool = bt.pool.all(func(b: BoonDef) -> bool: return not b.line.is_empty() and not b.display_name.is_empty())
	_check("Eight bargains: four of Toa'uma's (no bane) and four of the culture's (each with a bane); 3 per offer, on commander kills, landings from 6 m/s",
			ids.size() == 8 and toauma.size() == 4 and culture.size() == 4 and toauma_no_bane and culture_banes and lines
			and bt.offer_size == 3 and bt.offer_on_commander_kill and bt.landing_min_speed == 6.0, "%s" % [ids])


# --- offers ------------------------------------------------------------------

func _check_offer() -> void:
	await _fresh()
	var offers: Array = []
	boons.offered.connect(func(offer: Array[BoonDef]) -> void: offers.append(offer.duplicate()))
	var slot: int = station.spawn_commander()
	await _ticks(1)
	swarm.apply_damage_in_radius(swarm.get_enemy_position(slot), 0.5, 9999.0, Damage.Type.KINETIC)
	await _ticks(2)
	var first: Array = offers[0] if not offers.is_empty() else []
	var distinct: bool = first.size() == 3 and first.all(func(b: BoonDef) -> bool: return first.count(b) == 1)
	_check("A commander's death offers three distinct bargains from the pool", offers.size() == 1 and distinct,
			"%d offers, first %s" % [offers.size(), first.map(func(b: BoonDef) -> StringName: return b.id)])
	# Seeded: the same cycle seed draws the same offer.
	var seed_now: int = cycle.cycle_seed
	var again: Array[BoonDef] = []
	boons.rng.seed = cycle.seed_for("boons")
	again = boons.draw_offer()
	boons.rng.seed = cycle.seed_for("boons")
	var same: bool = boons.draw_offer() == again and again.size() == 3
	# Owned ones are never offered again; the pool empties.
	for b: BoonDef in boons.tuning.pool.slice(0, 6):
		boons.take(b)
	var last: Array[BoonDef] = boons.draw_offer()
	var last_unowned: bool = not last.any(func(b: BoonDef) -> bool: return boons.has(b.id))
	for b: BoonDef in boons.tuning.pool.slice(6):
		boons.take(b)
	var none: Array[BoonDef] = boons.offer()
	_check("Offers are drawn from the cycle's seed, skip owned bargains, and dry up when all eight are taken",
			same and last.size() == 2 and last_unowned and none.is_empty()
			and boons.owned.size() == 8, "same %s, with 6 owned %d offered, then %d; owned %d" % [same, last.size(), none.size(), boons.owned.size()])


func _check_menu() -> void:
	await _fresh()
	var kit_menu: KitOfferMenu = station.get_node("KitOfferMenu")
	boons.offer()
	await _frames(2)
	var opened: bool = menu.is_open and paused and menu.option_texts().size() == 3 \
			and menu.option_texts()[0].begins_with("1   ") and menu.option_texts()[0].contains("\n")
	var early: bool = not menu.pick(0)  # Inside the input delay.
	await _frames(int(taln.leveling.tuning.menu_input_delay * 60.0) + 5)
	var first: BoonDef = menu._offer[1]
	var picked: bool = menu.pick(1)
	_check("The offer menu opens paused with three labelled rows (source, name, a line), ignores early picks, and a pick takes the bargain",
			opened and early and picked and boons.owned == [first] and not menu.is_open and not paused and not kit_menu.is_open,
			"opened %s, early refused %s, picked %s, owned %s" % [opened, early, picked,
			boons.owned.map(func(b: BoonDef) -> StringName: return b.id)])
	paused = false


# --- effects -------------------------------------------------------------------

func _check_toauma_bargains() -> void:
	await _fresh()
	# Overcharged Stone: Settle's damage ×1.3, and +0.25 Strain on top of routing's 0.25.
	boons.take(_boon("overcharged_stone"))
	taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT
	(taln.loadout.get_behavior(&"breaking_stroke") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var settle: Settle = taln.loadout.get_behavior(&"settle")
	var walker: int = _rooted(load(ASH_WALKER), taln.global_position + settle.aim_direction() * 3.0, 100.0)
	taln.toauma.rng.seed = 7  # No side effect on this roll (checked below).
	var strain_before: float = taln.toauma.strain
	var cast: bool = settle.try_cast()
	await _ticks(1)
	var dealt: float = 1200.0 - swarm.get_enemy_hp(walker)
	var no_effect: bool = taln.toauma.last_effect == Toauma.Effect.NONE
	_check("Overcharged Stone: Surges hit ×1.3 (Settle 18 → 23.4) and each cast adds a quarter Strain more (0.5 in all)",
			cast and no_effect and is_equal_approx(dealt, 23.4) and is_equal_approx(taln.toauma.strain - strain_before, 0.5),
			"cast %s, effect-free %s, dealt %.1f, Strain +%.2f" % [cast, no_effect, dealt, taln.toauma.strain - strain_before])
	# Deeper Draw: ×1.5 Investiture; noise ×1.5 (a Draw heard at 18 m).
	boons.take(_boon("deeper_draw"))
	var heard: Array = []
	awareness.heard.connect(func(_at: Vector3, radius: float) -> void: heard.append(radius))
	_rooted(load(ASH_WALKER), taln.global_position + Vector3(16.0, 0.0, 0.0))
	await _ticks(60 * 7)
	var before: float = taln.investiture.current
	taln.toauma.rng.seed = 7
	taln.toauma.draw_cooldown_left = 0.0
	taln.toauma.draw()
	await _ticks(1)
	var drew: float = taln.investiture.current - before
	_check("Deeper Draw: the Draw gives ×1.5 (%.0f) and is heard ×1.5 as far (a walker at 16 m)" % (taln.toauma.tuning.draw_investiture * 1.5),
			is_equal_approx(drew, taln.toauma.tuning.draw_investiture * 1.5) and heard == [18.0],
			"drew %.0f, heard %s" % [drew, heard])
	# Hunter's Mark: ×1.5 on elites, not on the swarm; seen ×1.3 further.
	boons.take(_boon("hunters_mark"))
	var c: int = _rooted(load(COMMANDER), taln.global_position + Vector3(0.0, 0.0, 6.0))
	var w: int = _rooted(load(ASH_WALKER), taln.global_position + Vector3(0.0, 0.0, -6.0), 100.0)
	swarm.apply_damage_in_radius(swarm.get_enemy_position(c), 0.5, 10.0, Damage.Type.KINETIC)
	swarm.apply_damage_in_radius(swarm.get_enemy_position(w), 0.5, 10.0, Damage.Type.KINETIC)
	_check("Hunter's Mark: elites take ×1.5 (10 → 15), the swarm ×1; the commander and walkers see ×1.3 further",
			is_equal_approx(swarm.get_enemy_hp(c), 345.0) and is_equal_approx(swarm.get_enemy_hp(w), 1190.0)
			and is_equal_approx(awareness.detection_mult(), 1.3), "commander %.0f, walker %.0f, detection ×%.2f"
			% [swarm.get_enemy_hp(c), swarm.get_enemy_hp(w), awareness.detection_mult()])


func _check_culture_bargains() -> void:
	await _fresh()
	# Carrier: 10% of hits infect; seen ×1.25 further.
	boons.take(_boon("carrier"))
	var ash: SwarmType = load(ASH_WALKER)
	var slots: Array[int] = []
	for k in 40:
		slots.append(swarm.spawn(ash, taln.global_position + Vector3(6.0 + k * 0.5, 0.0, 0.0), 1000.0, 1.0))
	swarm.apply_root_in_cone(taln.global_position, Vector3.RIGHT, 20.0, 40.0, 60.0)
	for k in 5:
		swarm.apply_damage_in_radius(taln.global_position + Vector3(16.0, 0.0, 0.0), 12.0, 1.0, Damage.Type.KINETIC)
	var infected: int = swarm.get_infected_count()
	_check("Carrier: a tenth of blows seed the culture (200 hits → ~20 infected); the bane: seen ×1.25 further",
			infected >= 8 and infected <= 36 and is_equal_approx(awareness.detection_mult(), 1.25),
			"%d of 40 infected, detection ×%.2f" % [infected, awareness.detection_mult()])
	# Rot in the Stone: a tower's touch infects; towers stand with 75% Health.
	await _fresh()
	boons.take(_boon("rot_in_the_stone"))
	taln.loadout.add_skill(load("res://data/skills/sentinel.tres"))
	taln.loadout.process_mode = Node.PROCESS_MODE_INHERIT
	(taln.loadout.get_behavior(&"breaking_stroke") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var sentinel: Sentinel = taln.loadout.get_behavior(&"sentinel")
	sentinel.try_cast()
	await _ticks(2)
	var tower: SentinelTower = structures.of_kind(&"tower")[0]
	tower.damage = 0.0
	var toucher: int = swarm.spawn(ash, tower.global_position + Vector3(3.0, 0.0, 0.0), 100.0, 1.0)
	await _ticks(90)
	_check("Rot in the Stone: what touches a structure sickens; the bane: structures have 75% Health (tower 165)",
			swarm.is_enemy_infected(toucher) and is_equal_approx(tower.max_hp, 165.0) and swarm.get_lure_infects(),
			"touching walker infected %s, tower Health %.0f" % [swarm.is_enemy_infected(toucher), tower.max_hp])
	# Patient Culture: ×1.5 disease damage and spread; every hit on Taln ×1.25.
	await _fresh()
	boons.take(_boon("patient_culture"))
	var taken: float = taln.health.damage(8.0, Damage.Type.KINETIC)
	var sick: int = swarm.spawn(ash, taln.global_position + Vector3(10.0, 0.0, 0.0), 1.0, 1.0)
	swarm.apply_root_in_cone(swarm.get_enemy_position(sick), Vector3.FORWARD, 360.0, 1.0, 60.0)
	swarm.infect_in_radius(swarm.get_enemy_position(sick), 0.5)
	await _ticks(60 * 8)  # 4 s incubation, then 4.5/s: 12 Health in under 3 s.
	_check("Patient Culture: the disease takes ×1.5 as fast (a walker dies ~2.7 s after incubation); the bane: hits on Taln land ×1.25 (8 → 10)",
			is_equal_approx(taken, 10.0) and not swarm.is_enemy_alive(sick), "took %.1f, walker dead %s" % [taken, not swarm.is_enemy_alive(sick)])


func _check_landing_bargains() -> void:
	await _fresh()
	boons.take(_boon("loud_landing"))
	boons.take(_boon("spore_step"))
	var ash: SwarmType = load(ASH_WALKER)
	var near: int = _rooted(ash, taln.global_position + Vector3(2.0, 0.0, 0.0), 100.0)
	var mid: int = _rooted(ash, taln.global_position + Vector3(3.5, 0.0, 0.0), 100.0)
	var far: int = _rooted(ash, taln.global_position + Vector3(6.0, 0.0, 0.0), 100.0)
	var heard: Array = []
	awareness.heard.connect(func(_at: Vector3, radius: float) -> void: heard.append(radius))
	var armor: float = taln.health.get_armor()
	taln.launch(Vector3(0.0, 9.0, 0.0))  # Lands at 9 m/s.
	await _ticks(80)
	var landed: bool = not taln.airborne
	_check("Loud Landing + Spore Step: a 9 m/s landing bursts 20 Void within 4 m (the walker at 6 m untouched) and seeds the culture within 3 m; landings are heard ×2 as far; the bane: −15 Armor",
			landed and is_equal_approx(swarm.get_enemy_hp(near), 1180.0) and is_equal_approx(swarm.get_enemy_hp(mid), 1180.0)
			and is_equal_approx(swarm.get_enemy_hp(far), 1200.0) and swarm.is_enemy_infected(near) and not swarm.is_enemy_infected(mid)
			and heard == [20.0] and armor == -15.0,
			"landed %s; Health %.0f / %.0f / %.0f; infected %s / %s; heard %s; armor %.0f" % [landed, swarm.get_enemy_hp(near),
			swarm.get_enemy_hp(mid), swarm.get_enemy_hp(far), swarm.is_enemy_infected(near), swarm.is_enemy_infected(mid), heard, armor])


func _check_reset() -> void:
	await _fresh()
	for id in ["overcharged_stone", "hunters_mark", "carrier", "spore_step", "patient_culture"]:
		boons.take(_boon(id))
	var on: bool = boons.owned.size() == 5 and taln.loadout.surge_magnitude_mult == 1.3 and swarm.get_tier_damage_mult(1) == 1.5 \
			and swarm.get_hit_infect_chance() == 0.1 and taln.health.get_armor() == -15.0 and taln.health.get_damage_mult() == 1.25
	station.reset_for_cycle()
	await _ticks(1)
	var off: bool = boons.owned.is_empty() and taln.loadout.surge_magnitude_mult == 1.0 and taln.loadout.surge_strain_add == 0.0 \
			and swarm.get_tier_damage_mult(1) == 1.0 and swarm.get_hit_infect_chance() == 0.0 and taln.health.get_armor() == 0.0 \
			and taln.health.get_damage_mult() == 1.0 and is_equal_approx(awareness.detection_mult(), 1.0)
	_check("Bargains end with the cycle: every effect and bane comes off at a new cycle's start", on and off, "on %s, off %s" % [on, off])


func _check_telemetry() -> void:
	var telemetry: Telemetry = Telemetry.recorder()
	telemetry.enabled = true
	telemetry.directory = CHECKS_TELEMETRY
	await _fresh()
	var offer: Array[BoonDef] = boons.offer()
	await _frames(2)
	menu.pick(0)  # Inside the delay: refused.
	await _frames(int(taln.leveling.tuning.menu_input_delay * 60.0) + 5)
	menu.pick(0)
	await _ticks(2)
	cycle.end_cycle(Cycle.Outcome.CLOSED)
	await _frames(2)
	telemetry.enabled = false
	var file: Dictionary = TelemetryAnalysis.read(telemetry.path)
	var a: Dictionary = TelemetryAnalysis.analyze(file)
	var s: Dictionary = file.summary
	_check("Telemetry logs offers and takes (with the source) and the summary lists the bargains held",
			a.boon_offers == 1 and a.boons.size() == 1 and a.boons[0].boon == String(offer[0].id) and s.get("boons", []) == [String(offer[0].id)],
			"offers %d, taken %s, summary %s" % [a.boon_offers, a.boons, s.get("boons")])
	for f in DirAccess.get_files_at(CHECKS_TELEMETRY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKS_TELEMETRY.path_join(f)))
	paused = false
