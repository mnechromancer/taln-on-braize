class_name Boons
extends Node
## Taln's bargains this cycle (Design Doc v2.0 §11, P2-16): the drift
## between Aspects. A commander's death draws offer_size bargains from the
## pool (without replacement, none owned); BoonOfferMenu shows them and
## take() applies the one chosen. Each effect key below is pushed into the
## system that owns it, keyed by the bargain's id, so it comes off again
## cleanly. A new cycle clears them all.
##
## Effect keys (multipliers default 1, amounts 0):
##   surge_magnitude, surge_strain_add        every manual Surge cast
##   draw_mult, noise_mult, detection_mult    Toa'uma's Draw; Awareness
##   elite_damage_mult, hit_infect_chance     the swarm (C++)
##   lure_infects (1), blight_dps_mult, blight_spread_mult
##   structure_hp_mult, armor_delta, damage_taken_mult
##   landing_void_damage, landing_void_radius, landing_infect_radius

signal offered(offer: Array[BoonDef])
signal taken(boon: BoonDef)

@export var tuning: BoonTuning
@export var taln: Taln
@export var swarm: SwarmServer
@export var awareness: Awareness
@export var structures: Structures
@export var slice: BraizeSlice

var owned: Array[BoonDef] = []
## Seeded from the cycle (spec §11.5).
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	if slice and tuning.offer_on_commander_kill:
		slice.commander_killed.connect(func(_at: Vector3) -> void: offer())
	taln.landed.connect(_on_landed)


## Draws and announces an offer; empty (and silent) if nothing is left.
func offer() -> Array[BoonDef]:
	var draw: Array[BoonDef] = draw_offer()
	if not draw.is_empty():
		offered.emit(draw)
	return draw


## Up to offer_size pool bargains Taln doesn't own, without replacement.
func draw_offer() -> Array[BoonDef]:
	var left: Array[BoonDef] = tuning.pool.filter(func(b: BoonDef) -> bool: return not has(b.id))
	var draw: Array[BoonDef] = []
	while draw.size() < tuning.offer_size and not left.is_empty():
		draw.append(left.pop_at(rng.randi_range(0, left.size() - 1)))
	return draw


func has(id: StringName) -> bool:
	return owned.any(func(b: BoonDef) -> bool: return b.id == id)


## Takes a bargain: its effects (and bane) apply at once. False if owned.
func take(boon: BoonDef) -> bool:
	if has(boon.id):
		return false
	owned.append(boon)
	_apply_all()
	taken.emit(boon)
	return true


## Everything off: a new cycle.
func reset() -> void:
	owned.clear()
	rng.seed = Cycle.director().seed_for("boons")
	_apply_all()


## The product of every owned bargain's multiplier for key.
func mult(key: StringName) -> float:
	var out: float = 1.0
	for boon in owned:
		out *= float(boon.all_effects().get(key, 1.0))
	return out


## The sum of every owned bargain's amount for key.
func amount(key: StringName) -> float:
	var out: float = 0.0
	for boon in owned:
		out += float(boon.all_effects().get(key, 0.0))
	return out


## Pushes the totals into their systems (idempotent).
func _apply_all() -> void:
	taln.loadout.surge_magnitude_mult = mult(&"surge_magnitude")
	taln.loadout.surge_strain_add = amount(&"surge_strain_add")
	taln.toauma.draw_mults[&"boons"] = mult(&"draw_mult")
	if awareness:
		awareness.detection_mults[&"boons"] = mult(&"detection_mult")
		awareness.noise_mults[&"boons"] = mult(&"noise_mult")
	if swarm:
		swarm.set_tier_damage_mult(SwarmType.TIER_ELITE, mult(&"elite_damage_mult"))
		swarm.set_hit_infect_chance(amount(&"hit_infect_chance"))
		swarm.set_lure_infects(amount(&"lure_infects") > 0.0)
		swarm.set_blight_mults(mult(&"blight_dps_mult"), mult(&"blight_spread_mult"))
	if structures:
		structures.hp_mult = mult(&"structure_hp_mult")
	var armor: float = amount(&"armor_delta")
	if armor != 0.0:
		taln.health.set_armor_bonus(&"boons", armor)
	else:
		taln.health.clear_armor_bonus(&"boons")
	taln.health.set_damage_mult(&"boons", mult(&"damage_taken_mult"))


## Landing bargains: a Voidlight burst, the culture seeded where he lands.
func _on_landed(fall_speed: float, at: Vector3) -> void:
	if swarm == null or fall_speed < tuning.landing_min_speed:
		return
	var void_damage: float = amount(&"landing_void_damage")
	if void_damage > 0.0:
		swarm.apply_damage_in_radius(at, amount(&"landing_void_radius"), void_damage, Damage.Type.VOID)
	var infect: float = amount(&"landing_infect_radius")
	if infect > 0.0:
		swarm.infect_in_radius(at, infect)
