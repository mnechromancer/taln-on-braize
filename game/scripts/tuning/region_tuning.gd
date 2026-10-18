class_name RegionTuning
extends Resource
## Regions on the persistent map and the breaker stand-in (spec v1.4 #4,
## P2-10). Values live in data/tuning/region_tuning.tres; the defaults here are
## deliberately zero.

@export_group("Breaker site")
## Taln within this distance of a site (XZ) starts its siege.
@export_range(0.0, 30.0, 0.1, "suffix:m") var site_radius: float = 0.0
## Height of the site's beacon, seen from across the region.
@export_range(0.0, 200.0, 1.0, "suffix:m") var beacon_height: float = 0.0

@export_group("Siege (breaker stand-in)")
## Seconds Taln must hold for the breaker to fall.
@export_range(0.0, 600.0, 1.0, "suffix:s") var siege_seconds: float = 0.0
## The spawn budget is multiplied by this during a siege.
@export_range(1.0, 10.0, 0.1) var siege_budget_scale: float = 1.0
## A pack of this type and size spawns when a siege begins.
@export var siege_pack_type: SwarmType
@export_range(0, 50, 1) var siege_pack_size: int = 0
## The pack expires this long after the siege begins if not killed (0: never).
@export_range(0.0, 600.0, 1.0, "suffix:s") var siege_pack_lifetime: float = 0.0
## Base Investiture paid when the breaker falls, auto-collected, times v (spec §2.3).
@export_range(0.0, 2000.0, 1.0) var breaker_income: float = 0.0

@export_group("Breaker drop (P2-10)")
## A felled breaker (not the last tier's) offers up to this many skills from
## the pool that Taln doesn't own; he takes one (spec §2.4: new kit comes from
## Special Rooms and encounter drops).
@export_range(0, 9, 1) var breaker_offer_size: int = 0
@export var breaker_offer_pool: Array[SkillDef] = []
