class_name Structures
extends Node3D
## The station's standing structures (P2-11): every Structure a skill raises
## is a child here. Each physics frame it hands the swarm the lures among
## them (set_lures) and routes the swarm's hits back (lure_contacted). A
## kind's count is capped: raising one past its max crumbles the oldest.

signal raised(structure: Structure)
signal lost(structure: Structure, by_swarm: bool)
## A structure struck enemies.
signal struck(kind: StringName, hits: int, damage: float)

@export var taln: Taln
@export var swarm: SwarmServer
@export var ground: StationGround

## The lures handed to the swarm last frame, by index.
var _lured: Array[Structure] = []


func _ready() -> void:
	swarm.lure_contacted.connect(_on_lure_contacted)


func _physics_process(_delta: float) -> void:
	var positions := PackedVector3Array()
	var pulls := PackedFloat32Array()
	var bodies := PackedFloat32Array()
	_lured.clear()
	for structure: Structure in standing():
		if structure.pull_radius <= 0.0 and structure.body_radius <= 0.0:
			continue
		positions.append(structure.global_position)
		pulls.append(structure.pull_radius)
		bodies.append(structure.body_radius)
		_lured.append(structure)
	swarm.set_lures(positions, pulls, bodies)


## Adds structure at at; the oldest of its kind crumbles if max_count are
## already standing. Returns it.
func add(structure: Structure, at: Vector3, max_count: int) -> Structure:
	var same: Array[Structure] = of_kind(structure.kind)
	while max_count > 0 and same.size() >= max_count:
		same.pop_front().crumble(false)
	structure.taln = taln
	structure.swarm = swarm
	structure.ground = ground
	structure.hp = structure.max_hp
	structure.position = at
	structure.crumbled.connect(_on_crumbled)
	structure.struck.connect(func(hits: int, damage: float) -> void: struck.emit(structure.kind, hits, damage))
	add_child(structure)
	raised.emit(structure)
	return structure


## Every structure still standing, oldest first.
func standing() -> Array[Structure]:
	var out: Array[Structure] = []
	for node: Node in get_children():
		if node is Structure and not (node as Structure)._gone:
			out.append(node)
	return out


func of_kind(kind: StringName) -> Array[Structure]:
	return standing().filter(func(s: Structure) -> bool: return s.kind == kind)


func count(kind: StringName) -> int:
	return of_kind(kind).size()


## Everything down at once (a new cycle).
func clear_all() -> void:
	for structure in standing():
		structure.crumble(false)
	swarm.set_lures(PackedVector3Array(), PackedFloat32Array(), PackedFloat32Array())
	_lured.clear()


func _on_lure_contacted(index: int, damage: float) -> void:
	if index >= 0 and index < _lured.size() and is_instance_valid(_lured[index]):
		_lured[index].take_damage(damage)


func _on_crumbled(structure: Structure, by_swarm: bool) -> void:
	lost.emit(structure, by_swarm)
