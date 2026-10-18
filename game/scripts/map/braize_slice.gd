class_name BraizeSlice
extends GrayboxStation
## The P2-10 Braize slice: a piece of the persistent map (Design Doc v2.0 §4–5,
## spec v1.4 #4) in place of the stand-in's three back-to-back stations. A
## cycle starts in the Tier I region. In a region the spawner's clock runs
## endless; Taln finds the breaker site and walks in to start its siege (the
## breaker stand-in); holding it for siege_seconds fells the breaker: it pays
## breaker income, opens the region's seals and drops the spawner to a lull.
## Walking into a region of the next tier starts its clock at that tier's
## station index. The Tier III breaker falling ends the cycle Held. Gates
## MetaState records open are opened at cycle start. A felled breaker short
## of the last tier offers new kit: up to breaker_offer_size skills from the
## pool that Taln doesn't own, one to take (KitOfferMenu shows it).

enum State { EXPLORING, SIEGE, FALLEN }

signal region_entered(region: Region)
signal siege_began(region: Region)
signal breaker_fell(region: Region)
## A felled breaker's offer of new skills, and the one taken.
signal kit_offered(offer: Array[SkillDef])
signal kit_taken(skill: SkillDef)

@export var region_tuning: RegionTuning

var regions: Array[Region] = []
var gates: Array[Gate] = []
## The region whose tier the clock runs at.
var current: Region
var state: State = State.EXPLORING
## Seconds of siege left (game time, held while the Return freezes the world).
var siege_left: float = 0.0
## Seeded from the cycle (spec §11.5).
var kit_rng := RandomNumberGenerator.new()


func _ready() -> void:
	for node: Node in get_children():
		if node is Region:
			regions.append(node)
		elif node is Gate:
			gates.append(node)
	regions.sort_custom(func(a: Region, b: Region) -> bool: return a.tier < b.tier)
	_spawner.endless = true
	super._ready()


func reset_for_cycle() -> void:
	super.reset_for_cycle()
	_spawner.endless = true
	_spawner.budget_scale = 1.0
	_taln.agony.breaker_active = false
	for gate in gates:
		if gate.is_closed() and Meta.state().is_gate_open(gate.def.id):
			gate.open(_ground)
	for region in regions:
		region.site.set_state(BreakerSite.State.WAITING)
	current = region_at(_taln.global_position)
	if current == null:
		current = regions[0]
	state = State.EXPLORING
	siege_left = 0.0
	kit_rng.seed = Cycle.director().seed_for("kit")
	_follow_taln()
	region_entered.emit(current)


## The region containing at, or null.
func region_at(at: Vector3) -> Region:
	for region in regions:
		if region.contains(at):
			return region
	return null


## The deepest tier on the map; its breaker falling ends the cycle.
func last_tier() -> int:
	return regions[-1].tier if not regions.is_empty() else 1


## XZ distance from Taln to the current region's breaker site.
func distance_to_site() -> float:
	var site: Vector3 = current.site.global_position
	return Vector2(site.x - _taln.global_position.x, site.z - _taln.global_position.z).length()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if current == null or Cycle.director().outcome != Cycle.Outcome.NONE:
		return
	_follow_taln()
	match state:
		State.EXPLORING:
			if current.site.is_inside(_taln.global_position) and not _taln.frozen:
				begin_siege()
		State.SIEGE:
			if not _spawner.frozen:
				siege_left -= delta
				if siege_left <= 0.0:
					fell_breaker()
		State.FALLEN:
			var here: Region = region_at(_taln.global_position)
			if here and here.tier == current.tier + 1:
				enter_region(here)


func begin_siege() -> void:
	state = State.SIEGE
	siege_left = region_tuning.siege_seconds
	_spawner.budget_scale = region_tuning.siege_budget_scale
	_taln.agony.breaker_active = true
	current.site.set_state(BreakerSite.State.SIEGE)
	if region_tuning.siege_pack_type and region_tuning.siege_pack_size > 0:
		var slots: Array[int] = _spawner.spawn_pack(region_tuning.siege_pack_type, region_tuning.siege_pack_size)
		if region_tuning.siege_pack_lifetime > 0.0:
			for slot in slots:
				_swarm.set_enemy_lifetime(slot, region_tuning.siege_pack_lifetime)
	siege_began.emit(current)


func fell_breaker() -> void:
	state = State.FALLEN
	siege_left = 0.0
	_spawner.budget_scale = 1.0
	_taln.agony.breaker_active = false
	current.site.set_state(BreakerSite.State.FALLEN)
	_taln.investiture.add(region_tuning.breaker_income, &"breaker")
	current.open_seals(_ground)
	breaker_fell.emit(current)
	if current.tier >= last_tier():
		Cycle.director().end_cycle(Cycle.Outcome.HELD)
		return
	_spawner.lull = true
	Cycle.director().lull_began.emit(_context.station_index)
	var offer: Array[SkillDef] = draw_offer()
	if not offer.is_empty():
		kit_offered.emit(offer)


## Up to breaker_offer_size pool skills Taln doesn't own, drawn without
## replacement; empty if every slot is taken.
func draw_offer() -> Array[SkillDef]:
	var offer: Array[SkillDef] = []
	var loadout: Loadout = _taln.loadout
	if loadout.is_full():
		return offer
	var left: Array[SkillDef] = region_tuning.breaker_offer_pool.filter(func(s: SkillDef) -> bool:
		return not loadout.has_skill(s.id))
	while offer.size() < region_tuning.breaker_offer_size and not left.is_empty():
		offer.append(left.pop_at(kit_rng.randi_range(0, left.size() - 1)))
	return offer


## Adds skill to Taln's loadout at level 1. False if it can't be added.
func take_kit(skill: SkillDef) -> bool:
	if not _taln.loadout.add_skill(skill):
		return false
	kit_taken.emit(skill)
	return true


func enter_region(region: Region) -> void:
	current = region
	state = State.EXPLORING
	_context.station_index = region.tier - 1
	_spawner.begin_station(_context.station_index)
	_follow_taln()
	_well.relocate_all()
	Cycle.director().station_began.emit(_context.station_index)
	region_entered.emit(region)


## Spawns and new pool spots stay in the region Taln stands in (the current
## one if he's in a seam between regions).
func _follow_taln() -> void:
	var here: Region = region_at(_taln.global_position)
	var area: Rect2 = (here if here else current).bounds
	_spawner.area = area
	_well.area = area
