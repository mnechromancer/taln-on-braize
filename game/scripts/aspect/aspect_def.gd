class_name AspectDef
extends Resource
## One Aspect's data record (Design Doc v2.0 §10, spec v1.4 #1, #11). Chosen
## between cycles, an Aspect sets Taln's starting skills and switches on the
## stance systems that belong to its loop, and carries its passive: how
## easily the swarm detects him and any flat Armor. Aspect .tres files live
## under data/aspects/.

@export var id: StringName = &""
@export var display_name: String = ""
## Owned at level 1 when a cycle starts, in this order.
@export var starting_skills: Array[SkillDef] = []
## Anchored (spec §6.3): the stance, its Armor bonus, knockback immunity and
## the Anchored Well-pool rate. Off, Taln never Anchors (spec v1.4 #2).
@export var anchored: bool = false
## Fracture (spec §6.4): Braize punishes stillness. Off, it never builds.
@export var fracture: bool = false
@export var tags: Array[StringName] = []

@export_group("Passive")
## Spotters' sight and the swarm's close sight reach Taln at this share of
## their range (Awareness, spec v1.4 #6): below 1 is the stealth approach.
@export_range(0.0, 2.0, 0.05) var detection_mult: float = 1.0
## Flat Armor for the whole cycle: the tank approach.
@export_range(0.0, 1000.0, 1.0) var armor_bonus: float = 0.0
