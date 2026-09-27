extends SceneTree
## Reads cycle telemetry (JSON Lines from TelemetryRecorder) and prints, per
## file and across all of them: kill rate per wave; income by source per
## station; the level-up timeline beside the spec §2.4 C(n) prediction; Agony
## fills per station and the choice split; Returns; the Strain curve. The
## numbers come from TelemetryAnalysis. Report only.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tools/telemetry_report.gd -- [--file=<path>] [--dir=<dir>]
## With neither, it reads every file in user://telemetry.

const A := preload("res://tools/telemetry_analysis.gd")


func _init() -> void:
	var files: Array[String] = []
	var dir: String = "user://telemetry"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--file="):
			files.append(arg.trim_prefix("--file="))
		elif arg.begins_with("--dir="):
			dir = arg.trim_prefix("--dir=")
	if files.is_empty():
		for name in DirAccess.get_files_at(dir):
			if name.ends_with(".jsonl"):
				files.append(dir.path_join(name))
	files.sort()
	if files.is_empty():
		print("No telemetry files in %s." % dir)
		quit(1)
		return
	var cycles: Array[Dictionary] = []
	for file in files:
		cycles.append(A.read(file))
	for c in cycles:
		_report(c)
	if cycles.size() > 1:
		_aggregate(cycles)
	quit(0)


func _report(c: Dictionary) -> void:
	var a: Dictionary = A.analyze(c)
	var s: Dictionary = c.summary
	var outcome: String = "%s%s" % [s.get("outcome", ""), " (debug end)" if s.get("debug_end", false) else ""]
	print("")
	print("=== %s (seed %d): %s ===" % [String(c.path).get_file(), int(c.header.get("seed", 0)),
			"%s after %s, %d Returns" % [outcome, A.mmss(a.play_seconds), int(s.get("returns", 0))] if c.finished
			else "unfinished (%s logged)" % A.mmss(a.play_seconds)])
	var rates: Array[String] = []
	for w: Dictionary in a.waves:
		rates.append("S%dW%d %.0f" % [w.station + 1, w.wave + 1, w.rate])
	print("Kill rate per wave (kills per minute of running waves; Return freezes and lulls left out): " + ", ".join(rates))
	for i in a.stations.size():
		var st: Dictionary = a.stations[i]
		if not st.reached:
			continue
		var parts: Array[String] = []
		for source: String in st.income:
			parts.append("%s %.0f" % [source, st.income[source]])
		print("Station %d income %.0f (debug grants left out): %s" % [i + 1, st.gross, ", ".join(parts)])
	print("Level-ups (n, choice, actual vs the spec §2.4 prediction, which assumes a full station's income):")
	for level: Dictionary in a.levels:
		var n: int = level.n
		print("  n %2d  C %4.0f  %-18s  %s   predicted %s" % [n, level.cost, level.choice, A.mmss(level.t),
				A.mmss(a.predicted[n]) if n < a.predicted.size() else "beyond station 3"])
	for i in a.stations.size():
		var st: Dictionary = a.stations[i]
		if st.reached:
			print("Station %d: %d Agony fills %s; %d Returns" % [i + 1, st.fill_count, JSON.stringify(st.fills), st.returns])
	var curve: Array[String] = []
	for point: Dictionary in a.strain:
		curve.append("%s %.2f" % [A.mmss(point.t), point.value])
	print("Strain curve: " + (", ".join(curve) if not curve.is_empty() else "flat at 0"))


func _aggregate(cycles: Array[Dictionary]) -> void:
	var g: Dictionary = A.aggregate(cycles)
	print("")
	print("=== Across %d cycles ===" % g.cycles)
	print("Outcomes %s; mean %s of play, %.1f Returns per cycle" % [JSON.stringify(g.outcomes),
			A.mmss(g.play_seconds / g.cycles), float(g.returns) / g.cycles])
	for i in g.stations.size():
		var st: Dictionary = g.stations[i]
		if st.reached == 0:
			print("Station %d: no cycle reached it" % (i + 1))
			continue
		print("Station %d (%d of %d cycles reached it; means over those): income %.0f; level-ups %.1f vs ~%.0f (%+.0f%%); fills %.1f vs ~%.0f (%+.0f%%); Returns %.1f; kills %.0f/min vs ~%.0f (%+.0f%%)"
				% [i + 1, st.reached, g.cycles, st.mean_gross, st.mean_levels, A.SPEC_LEVELS_PER_STATION,
				A.pct(st.mean_levels, A.SPEC_LEVELS_PER_STATION), st.mean_fills, A.SPEC_FILLS_PER_STATION,
				A.pct(st.mean_fills, A.SPEC_FILLS_PER_STATION), st.mean_returns, st.kills_per_min,
				A.SPEC_KILLS_PER_MIN[i], A.pct(st.kills_per_min, A.SPEC_KILLS_PER_MIN[i])])
	print("Fill cadence: one per %s of play vs ~%s (spec §3.2); choices %s" % [A.mmss(g.seconds_per_fill),
			A.mmss(A.SPEC_SECONDS_PER_FILL), JSON.stringify(g.choices)])
	if g.held > 0:
		print("Per cycle (Held cycles only): see the per-file lines above.")
	else:
		print("No cycle ended Held, so per-cycle totals (~%.0f fills, ~%.0f level-ups) can't be compared; totals over these cycles: %d fills, %d level-ups"
				% [A.SPEC_FILLS_PER_CYCLE, A.SPEC_LEVELS_PER_CYCLE, g.fills, g.levels])
