extends SceneTree
## Headless economy runs with KiteBot playing (P2-05): one full station (nine
## waves) at station_index 0 per seed. Prints income by source, spending,
## level-ups and their times, kills and kill rate, and the spec §2.4 station 1
## targets beside them. Meta state goes to user://bot_meta.json, never the
## player's file. Reports only; tunes nothing.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/bots/run_bot.gd -- --seeds=1,2,3

const STATION := "res://scenes/graybox_station.tscn"
## Spec §2.4, station 1: gross income, net for leveling, levels; kill rate (§2.4 note).
const TARGET_GROSS := 1450.0
const TARGET_NET := 940.0
const TARGET_LEVELS := 10.0
const TARGET_KILLS_PER_MIN := 100.0

var seeds: Array[int] = [1, 2, 3]
## --level-first: the bot variant that won't cast Settle below the next level cost.
var level_first: bool = false


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds.clear()
			for part in arg.trim_prefix("--seeds=").split(","):
				seeds.append(int(part))
		elif arg == "--level-first":
			level_first = true
	_run()


func _run() -> void:
	await physics_frame
	Meta.state().redirect("user://bot_meta.json")
	Meta.state().wipe()
	var runs: Array[Dictionary] = []
	for seed in seeds:
		runs.append(await _run_station(seed))
	_report(runs)
	quit()


func _run_station(seed: int) -> Dictionary:
	var station: GrayboxStation = (load(STATION) as PackedScene).instantiate()
	root.add_child(station)
	var taln: Taln = station.get_node("Taln")
	var spawner: SpawnDirector = station.get_node("SpawnDirector")
	var swarm: SwarmServer = station.get_node("SwarmServer")
	var well: Well = station.get_node("Well")
	spawner.paused = true
	_seed(station, seed)
	var bot := KiteBot.new()
	bot.taln = taln
	bot.swarm = swarm
	bot.ground = station.get_node("StationGround")
	bot.camera_rig = station.get_node("CameraRig")
	bot.menu = station.get_node("LevelUpMenu")
	bot.well = well
	bot.level_first = level_first
	station.add_child(bot)
	await (station.get_node("StationGround") as StationGround).ground_changed

	var levels: Array = []
	var depletions: Array[int] = [0]
	var clock: Array[float] = [0.0]
	taln.leveling.leveled.connect(func(n: int, skill: SkillDef, cost: float) -> void:
		levels.append([clock[0], n, skill.id if skill else &"consolidate", cost]))
	taln.health.depleted.connect(func() -> void: depletions[0] += 1)
	spawner.paused = false
	var length: float = spawner.tuning.wave_length * spawner.tuning.waves
	var ticks: int = roundi(length * Engine.physics_ticks_per_second)
	var step: float = 1.0 / Engine.physics_ticks_per_second
	var t := 0
	while t < ticks:
		await physics_frame
		if not paused:
			t += 1
			clock[0] = t * step
	spawner.paused = true
	var run: Dictionary = {
		"seed": seed,
		"seconds": length,
		"kills": station.kills,
		"income": taln.investiture.income_by_source.duplicate(),
		"spent": taln.investiture.spent_by_reason.duplicate(),
		"held": taln.investiture.current,
		"levels": levels,
		"depletions": depletions[0],
		"motes_lost": station.motes_lost,
		"strain": taln.toauma.strain,
		"bot": {"casts": bot.casts, "draws": bot.draws, "invests": bot.invests, "pool_s": bot.pool_seconds},
	}
	station.queue_free()
	await physics_frame
	return run


func _seed(station: GrayboxStation, seed: int) -> void:
	var taln: Taln = station.get_node("Taln")
	(station.get_node("SpawnDirector") as SpawnDirector)._rng.seed = hash([seed, "spawner"])
	(station.get_node("SwarmServer") as SwarmServer).set_seed(hash([seed, "swarm"]))
	(station.get_node("MoteServer") as MoteServer).set_seed(hash([seed, "motes"]))
	(station.get_node("Well") as Well).rng.seed = hash([seed, "well"])
	taln.toauma.rng.seed = hash([seed, "toauma"])
	taln.leveling.rng.seed = hash([seed, "leveling"])


func _report(runs: Array[Dictionary]) -> void:
	print("")
	print("Economy bot%s: station 1 (v = 1), nine waves, %d seed(s)" % [" (level-first variant)" if level_first else "",
			runs.size()])
	var sources: Array[StringName] = [&"kill", &"elite", &"ambient", &"pool", &"draw"]
	var totals: Dictionary = {"gross": 0.0, "levels": 0.0, "kills_pm": 0.0, "level_spend": 0.0, "surge": 0.0}
	for run in runs:
		var income: Dictionary = run.income
		var gross: float = 0.0
		for s in sources:
			gross += income.get(s, 0.0)
		var minutes: float = run.seconds / 60.0
		var spent: Dictionary = run.spent
		print("")
		print("seed %d: %d kills (%.0f/min), %d level-ups, %d Health depletions, Strain %.2f at the end" % [run.seed,
				run.kills, run.kills / minutes, run.levels.size(), run.depletions, run.strain])
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
	print("  Surge share of spending %.0f%% (spec assumes ~35%% of income on Surges)" % (100.0 * totals.surge
			/ maxf(totals.surge + totals.level_spend, 1.0)))
	var file := FileAccess.open("user://bot_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(runs, "\t"))
	print("  runs saved to %s" % ProjectSettings.globalize_path("user://bot_report.json"))


func _pct(value: float, target: float) -> float:
	return 100.0 * (value - target) / target
