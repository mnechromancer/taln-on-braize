extends SceneTree
## Headless runs with KiteBot playing. Meta state goes to
## user://bot_meta.json, never the player's file. Reports only; tunes nothing.
##
## Station mode (default, P2-05/P2-06): one full station (nine waves) at
## station_index 0 per seed; prints income by source, spending, level-ups and
## their times, kills and kill rate, Agony fills, and the spec §2.4 station 1
## targets beside them.
## Cycle mode (--cycle, P2-08): full stand-in cycles until Held or Closed;
## TelemetryRecorder writes each cycle's file for tools/telemetry_report.gd.
## Each seed is the cycle's seed (the CycleDirector seeds every stream from it).
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/bots/run_bot.gd -- --seeds=1,2,3 [--cycle] [--level-first] [--telemetry-dir=user://telemetry_gate]

const STATION := "res://scenes/graybox_station.tscn"
## Spec §2.4, station 1: gross income, net for leveling, levels; kill rate (§2.4 note).
const TARGET_GROSS := 1450.0
const TARGET_NET := 940.0
const TARGET_LEVELS := 10.0
const TARGET_KILLS_PER_MIN := 100.0
## Spec §3.2: one fill per ~3 min for a median player; ~3 per full station
## (waves, rooms, breaker) and ~9 per cycle. A waves-only run is shorter.
const FILL_SECONDS := 180.0
const TARGET_FILLS_PER_STATION := 3.0
## Cycle mode gives up on a cycle after this much play (it should end well before).
const CYCLE_LIMIT_SECONDS := 3600.0

var seeds: Array[int] = [1, 2, 3]
## --level-first: the bot variant that won't cast Settle below the next level cost.
var level_first: bool = false
## --cycle: full cycles instead of one station.
var cycle_mode: bool = false
## --telemetry-dir: where cycle files go (default user://telemetry_bot).
var telemetry_dir: String = ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds.clear()
			for part in arg.trim_prefix("--seeds=").split(","):
				seeds.append(int(part))
		elif arg == "--level-first":
			level_first = true
		elif arg == "--cycle":
			cycle_mode = true
		elif arg.begins_with("--telemetry-dir="):
			telemetry_dir = arg.trim_prefix("--telemetry-dir=")
	_run()


func _run() -> void:
	await physics_frame
	Meta.state().redirect("user://bot_meta.json")
	# Bot files stay out of the playtest folder (the report's default).
	Telemetry.recorder().directory = telemetry_dir if telemetry_dir != "" else "user://telemetry_bot"
	var runs: Array[Dictionary] = []
	for seed in seeds:
		# Every seed starts from a first-ever meta state, so seeds compare.
		Meta.state().wipe()
		runs.append(await _run_one(seed))
	if cycle_mode:
		_report_cycles(runs)
	else:
		_report(runs)
	quit()


func _run_one(seed: int) -> Dictionary:
	var cycle: Cycle = Cycle.director()
	cycle.next_seed = seed
	var station: GrayboxStation = (load(STATION) as PackedScene).instantiate()
	root.add_child(station)
	var taln: Taln = station.get_node("Taln")
	var spawner: SpawnDirector = station.get_node("SpawnDirector")
	var swarm: SwarmServer = station.get_node("SwarmServer")
	spawner.paused = true
	var bot := KiteBot.new()
	bot.taln = taln
	bot.swarm = swarm
	bot.ground = station.get_node("StationGround")
	bot.camera_rig = station.get_node("CameraRig")
	bot.menu = station.get_node("LevelUpMenu")
	bot.well = station.get_node("Well")
	bot.catalysis = station.get_node("Catalysis")
	bot.sequence = station.get_node("ReturnSequence")
	bot.level_first = level_first
	station.add_child(bot)
	await (station.get_node("StationGround") as StationGround).ground_changed

	var levels: Array = []
	var clock: Array[float] = [0.0]
	taln.leveling.leveled.connect(func(n: int, skill: SkillDef, cost: float) -> void:
		levels.append([clock[0], n, skill.id if skill else &"consolidate", cost]))
	var done: Array[bool] = [false]
	var outcome: Array[String] = ["unfinished"]
	cycle.cycle_ended.connect(func(o: Cycle.Outcome, _s: Dictionary) -> void:
		done[0] = true
		outcome[0] = Cycle.Outcome.keys()[o], CONNECT_ONE_SHOT)
	if not cycle_mode:
		spawner.waves_done.connect(func() -> void: done[0] = true, CONNECT_ONE_SHOT)
	spawner.paused = false
	while not done[0] and cycle.play_time < CYCLE_LIMIT_SECONDS:
		await physics_frame
		clock[0] = cycle.play_time
	spawner.paused = true
	var run: Dictionary = {
		"seed": seed,
		"seconds": spawner.tuning.wave_length * spawner.tuning.waves if not cycle_mode else cycle.play_time,
		"play_seconds": cycle.play_time,
		"outcome": outcome[0],
		"kills": station.kills,
		"income": taln.investiture.income_by_source.duplicate(),
		"spent": taln.investiture.spent_by_reason.duplicate(),
		"held": taln.investiture.current,
		"levels": levels,
		"returns": cycle.returns,
		"motes_lost": station.motes_lost,
		"strain": taln.toauma.strain,
		"fills": (station.get_node("Catalysis") as Catalysis).history.map(func(h: Dictionary) -> String: return h.choice),
		"agony": taln.agony.gained_by_source.duplicate(),
		"station_reached": station.station_index() + 1,
		"bot": {"casts": bot.casts, "draws": bot.draws, "invests": bot.invests, "pool_s": bot.pool_seconds},
	}
	paused = false
	station.queue_free()
	await physics_frame
	return run


func _report_cycles(runs: Array[Dictionary]) -> void:
	print("")
	print("Economy bot%s: full stand-in cycles, %d seed(s)" % [" (level-first variant)" if level_first else "", runs.size()])
	for run in runs:
		var gross: float = 0.0
		for source: StringName in run.income:
			gross += run.income[source]
		print("seed %d: %s at station %d after %d:%02d; %d Returns, %d level-ups, %d fills (%s), %d kills, income %.0f"
				% [run.seed, run.outcome, run.station_reached, int(run.play_seconds) / 60, int(run.play_seconds) % 60,
				run.returns, run.levels.size(), run.fills.size(), ", ".join(run.fills), run.kills, gross])
	print("Telemetry files are in %s; tools/telemetry_report.gd reads them." % ProjectSettings.globalize_path(
			Telemetry.recorder().directory))


func _report(runs: Array[Dictionary]) -> void:
	print("")
	print("Economy bot%s: station 1 (v = 1), nine waves, %d seed(s)" % [" (level-first variant)" if level_first else "",
			runs.size()])
	var sources: Array[StringName] = [&"kill", &"elite", &"ambient", &"pool", &"draw"]
	var totals: Dictionary = {"gross": 0.0, "levels": 0.0, "kills_pm": 0.0, "level_spend": 0.0, "surge": 0.0, "fills": 0.0}
	for run in runs:
		var income: Dictionary = run.income
		var gross: float = 0.0
		for s in sources:
			gross += income.get(s, 0.0)
		var minutes: float = run.seconds / 60.0
		var spent: Dictionary = run.spent
		print("")
		print("seed %d: %d kills (%.0f/min), %d level-ups, %d Returns, Strain %.2f at the end" % [run.seed,
				run.kills, run.kills / minutes, run.levels.size(), run.returns, run.strain])
		var parts: Array[String] = []
		for s in sources:
			parts.append("%s %.0f" % [s, income.get(s, 0.0)])
		print("  income %.0f gross: %s" % [gross, ", ".join(parts)])
		print("  spent: levels %.0f, Surges %.0f; held at the end %.0f; motes lost %.0f" % [spent.get(&"level", 0.0),
				spent.get(&"surge", 0.0), run.held, run.motes_lost])
		var times: Array[String] = []
		for level: Array in run.levels:
			times.append("%.0fs:%s" % [level[0], String(level[2]).left(6)])
		print("  level-ups at %s" % ", ".join(times))
		print("  bot: %d Settles, %d Draws, %.0f s standing in pools" % [run.bot.casts, run.bot.draws, run.bot.pool_s])
		var agony_parts: Array[String] = []
		for source: StringName in run.agony:
			agony_parts.append("%s %.0f" % [source, run.agony[source]])
		print("  Agony fills %d: %s; Agony gained by source: %s" % [run.fills.size(), ", ".join(run.fills),
				", ".join(agony_parts)])
		totals.fills += run.fills.size()
		totals.gross += gross
		totals.levels += run.levels.size()
		totals.kills_pm += run.kills / minutes
		totals.level_spend += spent.get(&"level", 0.0)
		totals.surge += spent.get(&"surge", 0.0)
	var n: float = runs.size()
	print("")
	print("Mean over %d seed(s) vs spec §2.4 station 1:" % runs.size())
	print("  gross income  %.0f vs ~%.0f  (%+.0f%%)" % [totals.gross / n, TARGET_GROSS, _pct(totals.gross / n, TARGET_GROSS)])
	print("  spent on levels %.0f vs ~%.0f net for leveling  (%+.0f%%)" % [totals.level_spend / n, TARGET_NET,
			_pct(totals.level_spend / n, TARGET_NET)])
	print("  level-ups     %.1f vs ~%.0f  (%+.0f%%)" % [totals.levels / n, TARGET_LEVELS, _pct(totals.levels / n, TARGET_LEVELS)])
	print("  kill rate     %.0f/min vs ~%.0f/min  (%+.0f%%)" % [totals.kills_pm / n, TARGET_KILLS_PER_MIN,
			_pct(totals.kills_pm / n, TARGET_KILLS_PER_MIN)])
	var paced: float = runs[0].seconds / FILL_SECONDS
	print("  Agony fills   %.1f vs ~%.0f per full station (%+.0f%%), or %.2f at one per ~3 min over these %.0f s of waves (%+.0f%%)"
			% [totals.fills / n, TARGET_FILLS_PER_STATION, _pct(totals.fills / n, TARGET_FILLS_PER_STATION), paced,
			runs[0].seconds, _pct(totals.fills / n, paced)])
	print("  Surge share of spending %.0f%% (spec assumes ~35%% of income on Surges)" % (100.0 * totals.surge
			/ maxf(totals.surge + totals.level_spend, 1.0)))
	var file := FileAccess.open("user://bot_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(runs, "\t"))
	print("  runs saved to %s" % ProjectSettings.globalize_path("user://bot_report.json"))


func _pct(value: float, target: float) -> float:
	return 100.0 * (value - target) / target
