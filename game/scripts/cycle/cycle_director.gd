class_name Cycle
extends Node
## The cycle (spec §1.1–1.3, §11.5), autoloaded as CycleDirector. Owns the
## cycle's seed (logged) and seeds every random stream in the station from it,
## counts Returns (0–9) and keeps the cycle's stats. Phase 2 stand-in
## (ruled): a cycle is three consecutive nine-wave stations on the gray-box
## map, station_index 0 → 1 → 2, with a lull between stations; after station
## 3's ninth wave the cycle ends Held; the ninth Return ends it Closed.
##
## The station registers itself with begin_cycle() when it loads; everything
## in-run starts fresh there. Scripts reach this through Cycle.director(): a
## --script run compiles scripts before autoloads exist.

enum Outcome { NONE, HELD, CLOSED }

signal cycle_began(seed: int)
signal station_began(index: int)
signal lull_began(index: int)
## Held or Closed; stats is summary().
signal cycle_ended(outcome: Outcome, stats: Dictionary)

const TUNING := "res://data/tuning/cycle_tuning.tres"

var tuning: CycleTuning = load(TUNING)
var cycle_seed: int = 0
var returns: int = 0
var outcome: Outcome = Outcome.NONE
## Seconds of game time this cycle: pauses (Invest, the between-run screen)
## don't count; the Welcome/Catalyze slow-down counts at its time scale.
var play_time: float = 0.0
var station: GrayboxStation
## A seed for the next cycle, or 0 for a random one.
var next_seed: int = 0


## The CycleDirector autoload.
static func director() -> Cycle:
	return (Engine.get_main_loop() as SceneTree).root.get_node(^"CycleDirector") as Cycle


func _process(delta: float) -> void:
	if station and outcome == Outcome.NONE and not get_tree().paused:
		play_time += delta


## A fresh cycle in this (freshly loaded) station: new seed, everything in-run
## back to its start.
func begin_cycle(new_station: GrayboxStation) -> void:
	station = new_station
	cycle_seed = next_seed if next_seed != 0 else randi_range(1, 2147483646)
	next_seed = 0
	returns = 0
	outcome = Outcome.NONE
	play_time = 0.0
	Engine.time_scale = 1.0
	print("Cycle seed: %d" % cycle_seed)
	station.reset_for_cycle()
	cycle_began.emit(cycle_seed)
	station_began.emit(0)


## A stream's seed, derived from the cycle's.
func seed_for(stream: String) -> int:
	return hash([cycle_seed, stream])


func add_return() -> int:
	returns += 1
	return returns


## True once this Return is the one that closes the cycle.
func is_closing_return() -> bool:
	return returns >= tuning.returns_to_close


func end_cycle(how: Outcome) -> void:
	if outcome != Outcome.NONE or station == null:
		return
	# A fill still being decided banks first, so the summary counts it and no
	# window runs on under the between-run screen.
	(station.get_node(^"Catalysis") as Catalysis).force_bank()
	outcome = how
	cycle_ended.emit(how, summary())


## What the between-run screen shows (and telemetry records). "welcomed"
## counts fills Welcomed and fired; a Welcomed fill that ended up banked
## (Catalyze ran out empty, or Taln died deciding) counts as banked.
func summary() -> Dictionary:
	var catalysis: Catalysis = station.get_node("Catalysis")
	var welcomed: int = 0
	var banked: int = 0
	for entry: Dictionary in catalysis.history:
		if entry.choice == &"fire":
			welcomed += 1
		else:
			banked += 1
	return {
		"outcome": outcome,
		"seed": cycle_seed,
		"time": play_time,
		"kills": station.kills,
		"returns": returns,
		"welcomed": welcomed,
		"banked": banked,
		"banked_total": Meta.state().banked_total,
		"station": station.station_index(),
	}


## Loads a fresh station for the next cycle.
func begin_next_cycle(seed_override: int = 0) -> void:
	next_seed = seed_override
	get_tree().paused = false
	Engine.time_scale = 1.0
	var old: GrayboxStation = station
	var current: Node = get_tree().current_scene
	station = null
	get_tree().change_scene_to_file(tuning.station_scene)
	# A station added by hand (checks, bots) isn't the current scene, so the
	# change doesn't free it.
	if old and is_instance_valid(old) and old != current:
		old.queue_free()
