extends SceneTree
## P2-08 (telemetry and the report tool) checks, run headless against the
## real station scene at a fixed 60 fps. Prints PASS/FAIL per check and exits
## with the number of failures. Runs one short cycle with telemetry on (waves
## and lulls shortened), then checks the file line by line and runs
## tools/telemetry_report.gd over it.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path game --script res://tools/checks/p2_08_checks.gd

const STATION := "res://scenes/graybox_station.tscn"
const ASH_WALKER := "res://data/swarm/ash_walker.tres"
const NOTICE_HUNTER := "res://data/swarm/notice_hunter.tres"
const CHECKS_META := "user://checks_meta.json"
const CHECKS_TELEMETRY := "user://telemetry_checks"
const OPEN := Vector3(40.0, 0.0, 30.0)
const SEED := 424242

var station: GrayboxStation
var taln: Taln
var swarm: SwarmServer
var spawner: SpawnDirector
var catalysis: Catalysis
var sequence: ReturnSequence
var cycle: Cycle
var telemetry: Telemetry
var meta: Meta
var failures: int = 0
var events: Array[Dictionary] = []


func _init() -> void:
	_run()


func _run() -> void:
	await _frames(2)
	meta = Meta.state()
	meta.redirect(CHECKS_META)
	meta.wipe()
	cycle = Cycle.director()
	telemetry = Telemetry.recorder()
	_check("Telemetry stays off inside other check scripts by default", not telemetry.enabled, "")
	telemetry.enabled = true
	telemetry.directory = CHECKS_TELEMETRY
	_clear_dir()
	await _play_short_cycle()
	telemetry.enabled = false
	_read()
	_check_file()
	_check_events()
	_check_snapshots()
	_check_summary()
	_check_numbers()
	await _check_restart_and_abandon()
	_check_report()
	await _check_overhead()
	print("")
	print("MANUAL  The gate readout: run_bot.gd --cycle on 5 seeds, then telemetry_report.gd over the files.")
	print("")
	meta.wipe()
	paused = false
	Engine.time_scale = 1.0
	print("%d check(s) failed." % failures if failures > 0 else "All automated checks passed.")
	quit(failures)


# --- helpers -----------------------------------------------------------------

func _check(label: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _clear_dir() -> void:
	DirAccess.make_dir_recursive_absolute(CHECKS_TELEMETRY)
	for name in DirAccess.get_files_at(CHECKS_TELEMETRY):
		DirAccess.remove_absolute(CHECKS_TELEMETRY.path_join(name))


func _of(kind: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e.ev == kind)


# --- one short cycle -----------------------------------------------------------

## Waves of 3 s and 2 s lulls, so the three stations pass in about a minute;
## along the way: kills (rewarded and not), a level-up, a fill and its
## Cataclysm, a Draw with a side effect, a Notice, a Return.
func _play_short_cycle() -> void:
	meta.unlock_catalysis()
	cycle.next_seed = SEED
	var fast_cycle: CycleTuning = cycle.tuning.duplicate()
	fast_cycle.lull_seconds = 2.0
	var cycle_tuning: CycleTuning = cycle.tuning
	cycle.tuning = fast_cycle
	station = (load(STATION) as PackedScene).instantiate()
	# Short waves before the station enters the tree, so cycle_begin logs them.
	spawner = station.get_node("SpawnDirector")
	var fast: SpawnTuning = spawner.tuning.duplicate()
	fast.wave_length = 3.0
	spawner.tuning = fast
	root.add_child(station)
	taln = station.get_node("Taln")
	swarm = station.get_node("SwarmServer")
	catalysis = station.get_node("Catalysis")
	sequence = station.get_node("ReturnSequence")
	taln.health.set_invulnerable(&"checks", true)
	await (station.get_node("StationGround") as StationGround).ground_changed
	taln.global_position = OPEN
	await _ticks(2)
	var ash: SwarmType = load(ASH_WALKER)
	var hunter: SwarmType = load(NOTICE_HUNTER)
	# A kill, and a hunter that times out (not a kill).
	swarm.spawn(ash, OPEN + Vector3(2.0, 0.0, 0.0), 1.0, 1.0)
	var brief: int = swarm.spawn(hunter, OPEN + Vector3(-12.0, 0.0, 0.0), 1.0, 1.0)
	swarm.set_enemy_lifetime(brief, 0.3)
	# Income from several sources, a level-up and a Draw with a forced side effect.
	taln.investiture.add(80.0, &"debug")
	var forced: ToaumaTuning = taln.toauma.tuning.duplicate()
	forced.p_base = 1.0
	forced.p_max = 1.0
	forced.weight_burn = 0
	taln.toauma.tuning = forced
	taln.toauma.draw()
	taln.leveling.take(taln.leveling.offer()[0])
	taln.toauma.add_strain(3.0)  # A Notice.
	spawner.paused = false
	await _ticks(60 * 5)
	# A fill, Welcomed and fired.
	taln.agony.add(900.0, &"checks")
	await _frames(2)
	catalysis.welcome()
	catalysis.commit(taln.loadout.get_skill(&"settle"))
	await _frames(2)
	# A Return.
	taln.health.damage(10000.0, Damage.Type.KINETIC, true)
	await _frames(2)
	sequence.reform()
	# Play out the rest of the cycle.
	var frames: int = 0
	while cycle.outcome == Cycle.Outcome.NONE and frames < 60 * 90:
		await physics_frame
		frames += 1
	paused = false
	cycle.tuning = cycle_tuning
	station.queue_free()
	await _frames(2)


func _read() -> void:
	events.clear()
	var files: PackedStringArray = DirAccess.get_files_at(CHECKS_TELEMETRY)
	for name in files:
		for line in FileAccess.get_file_as_string(CHECKS_TELEMETRY.path_join(name)).split("\n", false):
			var e: Variant = JSON.parse_string(line)
			if e is Dictionary:
				events.append(e)


# --- the file ---------------------------------------------------------------------

func _check_file() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(CHECKS_TELEMETRY)
	var name: String = files[0] if files.size() > 0 else ""
	var pattern := RegEx.create_from_string("^cycle_\\d{8}_\\d{6}_%d\\.jsonl$" % SEED)
	var lines: int = 0
	var parsed: int = 0
	if name != "":
		for line in FileAccess.get_file_as_string(CHECKS_TELEMETRY.path_join(name)).split("\n", false):
			lines += 1
			var e: Variant = JSON.parse_string(line)
			if e is Dictionary and (e as Dictionary).has("t") and (e as Dictionary).has("ev"):
				parsed += 1
	_check("One JSON Lines file per cycle, cycle_<timestamp>_<seed>.jsonl; every line an object with t and ev",
			files.size() == 1 and pattern.search(name) != null and lines > 20 and parsed == lines,
			"%s: %d lines, %d parsed" % [name, lines, parsed])


func _check_events() -> void:
	var begin: Array[Dictionary] = _of("cycle_begin")
	var kills: Array[Dictionary] = _of("kill")
	var rewarded: bool = kills.any(func(e: Dictionary) -> bool: return e.rewarded == true)
	var unrewarded: bool = kills.any(func(e: Dictionary) -> bool: return e.rewarded == false)
	_check("Cycle start logged with its seed; kills logged with the rewarded flag (both kinds seen)",
			begin.size() == 1 and int(begin[0].seed) == SEED and rewarded and unrewarded,
			"%d kill events" % kills.size())
	var income: Array[Dictionary] = _of("income")
	var sources: Dictionary = {}
	for e in income:
		for source: String in e.by:
			sources[source] = true
	var spends: Array[Dictionary] = _of("spend")
	var reasons: Dictionary = {}
	for e in spends:
		reasons[e.reason] = true
	_check("Investiture income by source (each second) and spends by reason", sources.has("ambient") and sources.has("draw")
			and sources.has("debug") and reasons.has("level") and reasons.has("braize"),
			"sources %s; spend reasons %s" % [sources.keys(), reasons.keys()])
	var levels: Array[Dictionary] = _of("level")
	var fills: Array[Dictionary] = _of("fill")
	var fired: bool = fills.any(func(e: Dictionary) -> bool: return e.choice == "fire" and e.fired == ["settle"] and e.committed == ["settle"])
	_check("Level-ups (time, n, choice) and Agony fills (choice, committed catalysts)", levels.size() == 1
			and int(levels[0].n) == 0 and String(levels[0].choice) != "" and fired, "level %s; fills %s"
			% [levels[0] if levels.size() > 0 else "-", fills.map(func(e: Dictionary) -> String: return e.choice)])
	var returns: Array[Dictionary] = _of("return")
	var reforms: Array[Dictionary] = _of("reform")
	var strain: Array[Dictionary] = _of("strain")
	var notices: Array[Dictionary] = _of("notice")
	var effects: Array[Dictionary] = _of("side_effect")
	_check("Returns (and their reforms), Strain changes, Notices and side effects", returns.size() == 1
			and reforms.size() == 1 and int(returns[0].n) == 1
			and strain.size() >= 2 and notices.size() == 1 and int(notices[0].hunters) == 3 and effects.size() >= 1,
			"%d Returns, %d Strain changes, %d Notices, %d side effects" % [returns.size(), strain.size(), notices.size(),
			effects.size()])
	var waves: Array[Dictionary] = _of("wave")
	var stations: Array = _of("station").map(func(e: Dictionary) -> int: return int(e.index))
	var lulls: Array[Dictionary] = _of("lull")
	_check("Wave and station changes (and lulls)", waves.size() >= 24 and stations == [0, 1, 2] and lulls.size() == 2,
			"%d wave changes, stations %s, %d lulls" % [waves.size(), stations, lulls.size()])


func _check_snapshots() -> void:
	var snaps: Array[Dictionary] = _of("snapshot")
	var keys: Array[String] = ["alive", "kill_rate", "investiture", "health", "agony", "strain"]
	var complete: bool = snaps.all(func(e: Dictionary) -> bool: return keys.all(func(k: String) -> bool: return e.has(k)))
	var spaced: bool = true
	for i in range(1, snaps.size() - 1):
		spaced = spaced and absf(float(snaps[i].t) - float(snaps[i - 1].t) - 10.0) < 0.2
	_check("A snapshot every 10 s: alive count, kill rate, held Investiture, Health, Agony, Strain",
			snaps.size() >= 4 and complete and spaced, "%d snapshots; times %s" % [snaps.size(),
			snaps.map(func(e: Dictionary) -> float: return e.t)])


func _check_summary() -> void:
	var summary: Array[Dictionary] = _of("summary")
	var s: Dictionary = summary[0] if summary.size() == 1 else {}
	_check("A summary line at cycle end (outcome, time, kills, Returns, fills, income, levels, Agony)",
			summary.size() == 1 and events[-1].ev == "summary" and s.get("outcome") == "HELD" and int(s.get("returns", 0)) == 1
			and s.has("income") and s.has("levels") and s.has("agony") and int(s.get("welcomed", 0)) == 1,
			"%s" % [s])


## The numbers themselves, through TelemetryAnalysis (the report's engine).
func _check_numbers() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(CHECKS_TELEMETRY)
	var cycle_data: Dictionary = TelemetryAnalysis.read(CHECKS_TELEMETRY.path_join(files[0]))
	var a: Dictionary = TelemetryAnalysis.analyze(cycle_data)
	var summary: Dictionary = cycle_data.summary
	# Income: the per-second lines add up to the cycle's totals, source by source.
	var summed: Dictionary = {}
	for e in _of("income"):
		for source: String in e.by:
			summed[source] = summed.get(source, 0.0) + float(e.by[source])
	var conserved: bool = true
	for source: String in summary.income:
		conserved = conserved and absf(summed.get(source, 0.0) - float(summary.income[source])) < 0.1
	var gross: float = 0.0
	for st: Dictionary in a.stations:
		gross += st.gross
	var expected_gross: float = 0.0
	for source: String in summary.income:
		if source != "debug":
			expected_gross += float(summary.income[source])
	_check("Income lines add up to the summary by source; per-station gross (debug left out) adds up too",
			conserved and absf(gross - expected_gross) < 0.1, "lines %s vs summary %s; stations %.2f vs %.2f"
			% [summed, summary.income, gross, expected_gross])
	# Waves: each station's wave time is its nine waves, the Return's freeze left out.
	var header: Dictionary = cycle_data.header
	var station_time: float = float(header.wave_length) * int(header.waves)
	var times_ok: bool = a.stations.all(func(st: Dictionary) -> bool: return absf(st.wave_seconds - station_time) < 0.5)
	var wave_kills: int = 0
	for w: Dictionary in a.waves:
		wave_kills += w.kills
	var rewarded: int = _of("kill").filter(func(e: Dictionary) -> bool: return e.rewarded).size()
	_check("Kill rate per wave: wave time excludes the Return freeze and lulls; wave kills + lull kills = rewarded kills",
			times_ok and wave_kills + a.lull_kills == rewarded and a.waves.size() >= 27,
			"station wave seconds %s (expected %.1f); %d + %d lull kills vs %d rewarded; %d wave rows"
			% [a.stations.map(func(st: Dictionary) -> float: return snappedf(st.wave_seconds, 0.01)), station_time,
			wave_kills, a.lull_kills, rewarded, a.waves.size()])
	# C(n): the first level at base ÷ (station 1's net rate).
	var rate: float = TelemetryAnalysis.SPEC_NET[0] / station_time
	var expected0: float = float(header.level_cost_base) / rate
	_check("C(n) prediction reads the logged level costs: C(0) = %.0f at spec §2.4's station 1 net rate" % header.level_cost_base,
			a.predicted.size() > 5 and absf(a.predicted[0] - expected0) < 0.01 and float(header.level_cost_growth) == 1.1,
			"predicted[0] %.3f s vs %.3f s; %d predicted levels" % [a.predicted[0], expected0, a.predicted.size()])
	# Snapshot kill rates, each over its own span, add back up to the kills.
	var snaps: Array[Dictionary] = _of("snapshot")
	var from_snaps: float = 0.0
	var prev: float = 0.0
	for e in snaps:
		from_snaps += float(e.kill_rate) * (float(e.t) - prev) / 60.0
		prev = float(e.t)
	_check("Snapshot kill rates (the last over its own shorter span) add back up to the cycle's kills",
			absf(from_snaps - float(summary.kills)) < 1.5, "%.1f from snapshots vs %d kills" % [from_snaps, int(summary.kills)])


## A cycle Begin-the-next-cycle'd away mid-run, and the one that replaces it
## freed mid-run: each file is one cycle, and each ends with "abandoned".
func _check_restart_and_abandon() -> void:
	telemetry.enabled = true
	cycle.next_seed = SEED + 10
	station = (load(STATION) as PackedScene).instantiate()
	root.add_child(station)
	(station.get_node("SpawnDirector") as SpawnDirector).paused = true
	await (station.get_node("StationGround") as StationGround).ground_changed
	await _ticks(30)
	cycle.begin_next_cycle(SEED + 20)
	await _frames(3)
	await _ticks(30)
	unload_current_scene()
	await _frames(3)
	telemetry.enabled = false
	var names: PackedStringArray = DirAccess.get_files_at(CHECKS_TELEMETRY)
	var by_seed: Dictionary = {}
	for name in names:
		var lines: PackedStringArray = FileAccess.get_file_as_string(CHECKS_TELEMETRY.path_join(name)).split("\n", false)
		var begins: int = 0
		for line in lines:
			if (JSON.parse_string(line) as Dictionary).ev == "cycle_begin":
				begins += 1
		by_seed[name.get_slice("_", 3).get_basename()] = [begins, (JSON.parse_string(lines[-1]) as Dictionary).ev]
	var restarted: Array = by_seed.get(str(SEED + 10), [])
	var freed: Array = by_seed.get(str(SEED + 20), [])
	_check("Begin the next cycle mid-run and a station freed mid-run: one file per cycle, one cycle_begin each, ending \"abandoned\"",
			restarted == [1, "abandoned"] and freed == [1, "abandoned"] and names.size() == 3,
			"%s" % [by_seed])


func _check_report() -> void:
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tools/telemetry_report.gd", "--", "--dir=" + ProjectSettings.globalize_path(CHECKS_TELEMETRY)],
			output, true)
	var text: String = "\n".join(output)
	var first: SkillDef = null
	var sections: Array[String] = ["Kill rate per wave", "S1W1 ", "Station 1 income", "Station 3 income", "predicted ",
			"Agony fills", "Returns", "Strain curve", "Across 3 cycles", "Fill cadence", "unfinished"]
	var missing: Array[String] = sections.filter(func(sec: String) -> bool: return not text.contains(sec))
	_check("tools/telemetry_report.gd over a folder: per-file sections (waves, income per station, level-ups vs C(n), fills, Returns, Strain) and the cross-cycle summary",
			code == 0 and missing.is_empty() and first == null, "exit %d; missing %s" % [code, missing])


## Frame cost at 400 alive with kills every few ticks, telemetry on and off.
func _frame_cost(record: bool) -> float:
	telemetry.enabled = record
	cycle.next_seed = SEED + 1
	station = (load(STATION) as PackedScene).instantiate()
	root.add_child(station)
	taln = station.get_node("Taln")
	swarm = station.get_node("SwarmServer")
	(station.get_node("SpawnDirector") as SpawnDirector).paused = true
	taln.health.set_invulnerable(&"checks", true)
	var ground: StationGround = station.get_node("StationGround")
	await ground.ground_changed
	taln.global_position = OPEN
	var ash: SwarmType = load(ASH_WALKER)
	var total: float = 0.0
	var k: int = 0
	for f in 900:
		while swarm.get_alive_count() < 400:
			var angle: float = k * 2.39996
			var at: Vector3 = OPEN + Vector3(cos(angle), 0.0, sin(angle)) * (3.0 + fmod(k * 0.37, 23.0))
			k += 1
			if not ground.is_blocked_at(at.x, at.z):
				swarm.spawn(ash, at, 1.0, 1.0)
		if f % 3 == 0:
			swarm.apply_damage_in_radius(OPEN, 6.0, 100.0, Damage.Type.KINETIC)
		var before: int = Time.get_ticks_usec()
		await physics_frame
		total += (Time.get_ticks_usec() - before) / 1000.0
	station.queue_free()
	await _frames(2)
	telemetry.enabled = false
	return total / 900.0


func _check_overhead() -> void:
	var off: float = await _frame_cost(false)
	var on: float = await _frame_cost(true)
	_check("400 alive with kills every few ticks: telemetry adds little, and the frame fits 60 fps (CPU side)",
			on < 4.0 and on - off < 0.3, "avg %.3f ms with telemetry, %.3f ms without" % [on, off])
	_clear_dir()
