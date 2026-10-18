class_name GateDef
extends Resource
## One gate on the persistent map (spec v1.4 #4, #11): a route between
## regions that stays shut until it's opened through meta-progression, then
## stays open every cycle after. Gate .tres files live under data/map/.

@export var id: StringName = &""
@export var display_name: String = ""
## Banked Agony to open it for good (stub meta condition; it competes with cap raises).
@export_range(0, 99, 1) var cost: int = 0
