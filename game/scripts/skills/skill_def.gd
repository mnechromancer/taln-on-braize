class_name SkillDef
extends Resource
## One skill's data record (spec §2.5, §11.4). Skill .tres files live under
## data/skills/. The Content Pipeline doc owns the full format; these are the
## fields the systems in the spec need, plus display_name and cooldown.

enum Kind { WEAPON, SURGE, PERK }
## Named SkillTree because Tree is a built-in Control class.
enum SkillTree { STONEWARD, HERALD, ASHYNITE }
## Toa'uma: always adds Strain. Blade-eligible: adds none once the Honorblade
## is held. Voidlight-only: always routes through Toa'uma (spec §5.1).
enum Routing { TOA_UMA, BLADE_ELIGIBLE, VOIDLIGHT_ONLY }
## Catalyst cost tier (spec §4.3). NONE means the skill isn't a catalyst.
enum CatalystTier { NONE, LESSER, GREATER, GRAND }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.WEAPON
@export var tree: SkillTree = SkillTree.STONEWARD
@export var tags: Array[StringName] = []
## Investiture per manual use. Surges only; Weapons cost nothing (spec §2.5).
@export_range(0.0, 1000.0, 0.5) var investiture_cost: float = 0.0
@export_range(0.0, 120.0, 0.05, "suffix:s") var cooldown: float = 0.0
@export var routing: Routing = Routing.TOA_UMA
@export var catalyst_tier: CatalystTier = CatalystTier.NONE
## One Dictionary per level; index 0 is level 1. Keys are up to the behavior.
@export var level_params: Array[Dictionary] = []
## The Cataclysm this catalyst fires when committed (placeholder magnitudes
## until the Content List); keys are up to the behavior.
@export var cataclysm_params: Dictionary = {}
## Instantiated as a child of Taln's Loadout. Its root must be a SkillBehavior.
@export var behavior: PackedScene


## The params for level (1-based), clamped to the levels authored.
func params_for(level: int) -> Dictionary:
	if level_params.is_empty():
		return {}
	return level_params[clampi(level, 1, level_params.size()) - 1]
