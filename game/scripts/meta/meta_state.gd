class_name Meta
extends Node
## Meta state that outlives a cycle (spec §9, §11.5), autoloaded as MetaState:
## per-skill caps, banked Agony, whether Catalysis is unlocked and whether the
## Return sequence has been seen. Saved to user://meta.json as versioned JSON
## on every change, so quitting mid-cycle loses nothing already banked.
##
## Checks and bots call redirect() first so they never touch the player's file.
##
## Scripts reach it through Meta.state() rather than the autoload's global
## name: a --script run compiles its scripts before autoloads exist.

signal changed

const SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://meta.json"
const TUNING := "res://data/tuning/meta_tuning.tres"

var tuning: MetaTuning = load(TUNING)
var path: String = DEFAULT_PATH
## Raised caps by skill id; skills not listed are at their starting cap.
var caps: Dictionary[StringName, int] = {}
## Unspent banked Agony points.
var banked_agony: int = 0
## Every point ever banked, spent or not.
var banked_total: int = 0
var catalysis_unlocked: bool = false
var return_seen: bool = false


## The MetaState autoload.
static func state() -> Meta:
	return (Engine.get_main_loop() as SceneTree).root.get_node(^"MetaState") as Meta


func _ready() -> void:
	load_state()


## Switches to another save file and loads it (empty state if it's missing).
func redirect(new_path: String) -> void:
	path = new_path
	load_state()


func get_cap(id: StringName) -> int:
	return caps.get(id, starting_cap(id))


func starting_cap(id: StringName) -> int:
	return tuning.starting_cap_overrides.get(id, tuning.starting_cap)


## Banked points to raise id's cap by one; -1 once it's at the maximum.
func cap_raise_cost(id: StringName) -> int:
	var cap: int = get_cap(id)
	return -1 if cap >= tuning.max_cap else maxi(cap + tuning.cap_raise_cost_offset, 0)


## Spends banked Agony to raise id's cap by one (spec §9). False if it's at
## the maximum or there aren't enough points.
func raise_cap(id: StringName) -> bool:
	var cost: int = cap_raise_cost(id)
	if cost < 0 or banked_agony < cost:
		return false
	banked_agony -= cost
	caps[id] = get_cap(id) + 1
	_changed()
	return true


func bank_agony(points: int) -> void:
	if points <= 0:
		return
	banked_agony += points
	banked_total += points
	_changed()


func unlock_catalysis() -> void:
	if not catalysis_unlocked:
		catalysis_unlocked = true
		_changed()


func mark_return_seen() -> void:
	if not return_seen:
		return_seen = true
		_changed()


## Debug: back to a first-ever cycle.
func wipe() -> void:
	caps.clear()
	banked_agony = 0
	banked_total = 0
	catalysis_unlocked = false
	return_seen = false
	_changed()


func load_state() -> void:
	caps.clear()
	banked_agony = 0
	banked_total = 0
	catalysis_unlocked = false
	return_seen = false
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and int((data as Dictionary).get("schema_version", 0)) == SCHEMA_VERSION:
			var d: Dictionary = data
			var saved_caps: Dictionary = d.get("caps", {})
			for id: String in saved_caps:
				caps[StringName(id)] = int(saved_caps[id])
			banked_agony = int(d.get("banked_agony", 0))
			banked_total = int(d.get("banked_total", banked_agony))
			catalysis_unlocked = bool(d.get("catalysis_unlocked", false))
			return_seen = bool(d.get("return_seen", false))
		else:
			push_warning("%s isn't meta state schema %d; starting fresh." % [path, SCHEMA_VERSION])
	changed.emit()


func save() -> void:
	var saved_caps: Dictionary = {}
	for id: StringName in caps:
		saved_caps[String(id)] = caps[id]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Can't write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"caps": saved_caps,
		"banked_agony": banked_agony,
		"banked_total": banked_total,
		"catalysis_unlocked": catalysis_unlocked,
		"return_seen": return_seen,
	}, "\t"))


func _changed() -> void:
	save()
	changed.emit()
