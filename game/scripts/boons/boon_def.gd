class_name BoonDef
extends Resource
## One bargain's data record (Design Doc v2.0 §11, spec v1.4 #10–11,
## P2-16): what Sja-Anat left in Taln, offered through the two things she
## Enlightened. Run-scoped, no slot. Toa'uma's bargains carry their cost in
## what they do (Strain, noise, attention); the culture's carry a separate
## bane. Boon .tres files live under data/boons/.
##
## effects and bane map effect keys to numbers; the Boons node applies them
## (see its EFFECTS list). Multipliers default to 1, amounts to 0.

enum Source { TOAUMA, CULTURE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var source: Source = Source.TOAUMA
## One line under the name on the offer.
@export var line: String = ""
@export var tags: Array[StringName] = []
@export var effects: Dictionary = {}
## The culture's price (same keys); empty for Toa'uma's bargains.
@export var bane: Dictionary = {}


## Both halves of the bargain together.
func all_effects() -> Dictionary:
	var out: Dictionary = effects.duplicate()
	out.merge(bane, true)
	return out
