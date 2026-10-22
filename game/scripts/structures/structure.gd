class_name Structure
extends Node3D
## Something Earthshaper raises from the ground (P2-11): a wall, a tower, a
## warden. It stands for its lifetime, or until the swarm breaks it (lures
## take contact damage through the Structures node). Subclasses build their
## look in _ready and act in _physics_process; the Structures node owns them.

signal crumbled(structure: Structure, by_swarm: bool)
## Something it struck: how many enemies, for how much.
signal struck(hits: int, damage: float)

const STONE := Color("8a7f6e")

## Which kind, for counts and telemetry (e.g. &"wall").
var kind: StringName = &""
## Max Health; 0 means the swarm can't break it.
var max_hp: float = 0.0
var hp: float = 0.0
var lifetime_left: float = 0.0
## Enemies within pull_radius (XZ) attack it instead of hunting Taln; 0
## means they ignore it. They're pushed out of body_radius and hit it there.
var pull_radius: float = 0.0
var body_radius: float = 0.0
var taln: Taln
var swarm: SwarmServer
var ground: StationGround
var _gone: bool = false


func _physics_process(delta: float) -> void:
	if swarm and swarm.is_frozen():
		return
	lifetime_left -= delta
	if lifetime_left <= 0.0:
		crumble(false)
		return
	_act(delta)


## Override: one physics frame of what it does.
func _act(_delta: float) -> void:
	pass


func take_damage(amount: float) -> void:
	if max_hp <= 0.0 or _gone:
		return
	hp -= amount
	if hp <= 0.0:
		crumble(true)


func crumble(by_swarm: bool) -> void:
	if _gone:
		return
	_gone = true
	crumbled.emit(self, by_swarm)
	queue_free()


## A flat unlit stone material for placeholder meshes.
static func stone_material(color: Color = STONE) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
