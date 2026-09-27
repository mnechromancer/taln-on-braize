class_name TelemetryAnalysis
extends RefCounted
## Reads and analyzes cycle telemetry (JSON Lines from TelemetryRecorder) for
## tools/telemetry_report.gd and the P2-08 checks. Pure data in, data out.
##
## Time spent frozen by a Return (from its "return" to its "reform") and the
## lulls between stations are taken out of wave time, so kill rates are per
## minute of running waves. The C(n) prediction reads the level-cost numbers
## logged in the file's cycle_begin line.

## Spec §2.4: net Investiture for leveling per station (a full station: waves,
## minibosses, rooms and the breaker; the stand-in has only the waves).
const SPEC_NET := [940.0, 2650.0, 5000.0]
const SPEC_LEVELS_PER_STATION := 9.0
const SPEC_FILLS_PER_STATION := 3.0
## Spec §3.2: one fill per ~3 min of play for a median player.
const SPEC_SECONDS_PER_FILL := 180.0
const SPEC_KILLS_PER_MIN := [100.0, 180.0, 250.0]
const SPEC_FILLS_PER_CYCLE := 9.0
const SPEC_LEVELS_PER_CYCLE := 27.0
## Used only when a file's cycle_begin line predates them.
const FALLBACK := {"wave_length": 45.0, "waves": 9, "stations": 3, "lull_seconds": 15.0,
		"level_cost_base": 54.0, "level_cost_growth": 1.1}


## One file: {"path", "events", "header" (cycle_begin + fallbacks),
## "summary" ({} if unfinished), "finished"}.
static func read(path: String) -> Dictionary:
	var events: Array[Dictionary] = []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var e: Variant = JSON.parse_string(line)
		if e is Dictionary:
			events.append(e)
	var header: Dictionary = FALLBACK.duplicate()
	var summary: Dictionary = {}
	for e in events:
		if e.ev == "cycle_begin":
			header.merge(e, true)
		elif e.ev == "summary":
			summary = e
	return {"path": path, "events": events, "header": header, "summary": summary, "finished": not summary.is_empty()}


## Everything the report shows for one cycle.
static func analyze(cycle: Dictionary) -> Dictionary:
	var header: Dictionary = cycle.header
	var stations: int = int(header.stations)
	var result: Dictionary = {"waves": [], "stations": [], "levels": [], "strain": [], "play_seconds": 0.0,
			"fills": 0, "lull_kills": 0}
	for s in stations:
		result.stations.append({"reached": false, "start": 0.0, "wave_seconds": 0.0, "kills": 0, "income": {},
				"gross": 0.0, "fills": {}, "fill_count": 0, "returns": 0, "levels": 0})
	# Mutable walk state (a Dictionary, so the helper sees every change).
	var w: Dictionary = {"station": 0, "wave": 0, "seg_start": 0.0, "seg_frozen": 0.0, "frozen_since": INF,
			"in_lull": false, "kills": 0}
	var last_t: float = 0.0
	result.stations[0].reached = true
	for e: Dictionary in cycle.events:
		var t: float = float(e.get("t", last_t))
		last_t = t
		match e.ev:
			"kill":
				if e.rewarded:
					if w.in_lull:
						result.lull_kills += 1
					else:
						w.kills += 1
			"wave", "station", "lull", "summary", "abandoned":
				_close_segment(w, result, t)
				w.kills = 0
				w.seg_start = t
				w.seg_frozen = 0.0
				if w.frozen_since != INF:
					w.frozen_since = t
				match e.ev:
					"wave":
						w.station = int(e.get("station", w.station))
						w.wave = int(e.wave)
						w.in_lull = false
					"station":
						w.station = int(e.index)
						w.wave = 0
						w.in_lull = false
						result.stations[w.station].reached = true
						result.stations[w.station].start = t
					"lull":
						w.in_lull = true
			"return":
				result.stations[int(e.get("station", w.station))].returns += 1
				w.frozen_since = t
			"reform":
				if w.frozen_since != INF:
					w.seg_frozen += t - w.frozen_since
					w.frozen_since = INF
			"income":
				var st: Dictionary = result.stations[int(e.get("station", w.station))]
				for source: String in e.by:
					st.income[source] = st.income.get(source, 0.0) + float(e.by[source])
					if source != "debug":
						st.gross += float(e.by[source])
			"fill":
				var st: Dictionary = result.stations[int(e.get("station", w.station))]
				st.fills[e.choice] = st.fills.get(e.choice, 0) + 1
				st.fill_count += 1
				result.fills += 1
			"level":
				result.stations[int(e.get("station", w.station))].levels += 1
				result.levels.append({"t": t, "n": int(e.n), "choice": String(e.choice), "cost": float(e.cost),
						"station": int(e.get("station", w.station))})
			"strain":
				var value: float = float(e.value)
				if result.strain.is_empty() or result.strain[-1].value != value:
					result.strain.append({"t": t, "value": value})
	if not cycle.finished:
		_close_segment(w, result, last_t)
	result.play_seconds = float(cycle.summary.get("time", last_t))
	var starts: Array[float] = []
	for st: Dictionary in result.stations:
		if st.reached:
			starts.append(st.start)
	result.predicted = predicted_times(header, starts)
	return result


## When spec §2.4's pacing would reach each level: each station's net leveling
## income arrives evenly over its waves from the moment the station began
## (station_starts, in play seconds; later stations extrapolated after the
## lull), and is spent on C(0), C(1), ... in turn, carrying any remainder.
## Ends the running wave segment at t: its time less any Return freeze, and
## its kills (lulls aren't waves).
static func _close_segment(w: Dictionary, result: Dictionary, t: float) -> void:
	if w.in_lull:
		return
	var frozen: float = w.seg_frozen + (t - w.frozen_since if w.frozen_since != INF else 0.0)
	var seconds: float = t - w.seg_start - frozen
	if seconds > 0.5:
		result.waves.append({"station": w.station, "wave": w.wave, "kills": w.kills, "seconds": seconds,
				"rate": w.kills / seconds * 60.0})
		result.stations[w.station].wave_seconds += seconds
		result.stations[w.station].kills += w.kills


static func predicted_times(header: Dictionary, station_starts: Array[float]) -> Array[float]:
	var times: Array[float] = []
	var station_seconds: float = float(header.wave_length) * int(header.waves)
	var base: float = float(header.level_cost_base)
	var growth: float = float(header.level_cost_growth)
	var saved: float = 0.0
	var n: int = 0
	for s in mini(int(header.stations), SPEC_NET.size()):
		var start: float = station_starts[s] if s < station_starts.size() \
				else (station_starts[-1] if not station_starts.is_empty() else 0.0) \
				+ (s - station_starts.size() + 1) * (station_seconds + float(header.lull_seconds))
		var rate: float = SPEC_NET[s] / station_seconds
		var t: float = start
		while true:
			var cost: float = roundf(base * pow(growth, n))
			var wait: float = maxf(cost - saved, 0.0) / rate
			if t + wait > start + station_seconds:
				saved += (start + station_seconds - t) * rate
				break
			t += wait
			saved = 0.0
			times.append(t)
			n += 1
	return times


## Means across cycles, each station averaged over the cycles that reached it.
static func aggregate(cycles: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {"cycles": cycles.size(), "outcomes": {}, "held": 0, "stations": [], "play_seconds": 0.0,
			"fills": 0, "levels": 0, "returns": 0, "choices": {}}
	var analyses: Array[Dictionary] = []
	for c in cycles:
		analyses.append(analyze(c))
	var stations: int = int(cycles[0].header.stations) if not cycles.is_empty() else 3
	for s in stations:
		out.stations.append({"reached": 0, "gross": 0.0, "levels": 0.0, "fills": 0.0, "returns": 0.0, "kills": 0.0,
				"wave_seconds": 0.0})
	for i in cycles.size():
		var c: Dictionary = cycles[i]
		var a: Dictionary = analyses[i]
		var outcome: String = String(c.summary.get("outcome", "UNFINISHED"))
		if c.summary.get("debug_end", false):
			outcome += " (debug)"
		out.outcomes[outcome] = out.outcomes.get(outcome, 0) + 1
		if outcome == "HELD":
			out.held += 1
		out.play_seconds += a.play_seconds
		out.fills += a.fills
		out.levels += a.levels.size()
		for s in stations:
			var st: Dictionary = a.stations[s]
			out.returns += st.returns
			for choice: String in st.fills:
				out.choices[choice] = out.choices.get(choice, 0) + st.fills[choice]
			if not st.reached:
				continue
			var agg: Dictionary = out.stations[s]
			agg.reached += 1
			agg.gross += st.gross
			agg.levels += st.levels
			agg.fills += st.fill_count
			agg.returns += st.returns
			agg.kills += st.kills
			agg.wave_seconds += st.wave_seconds
	for agg: Dictionary in out.stations:
		var n: float = maxf(agg.reached, 1.0)
		agg.mean_gross = agg.gross / n
		agg.mean_levels = agg.levels / n
		agg.mean_fills = agg.fills / n
		agg.mean_returns = agg.returns / n
		agg.kills_per_min = agg.kills / (agg.wave_seconds / 60.0) if agg.wave_seconds > 0.0 else 0.0
	out.seconds_per_fill = out.play_seconds / out.fills if out.fills > 0 else INF
	return out


static func pct(value: float, target: float) -> float:
	return 100.0 * (value - target) / target


static func mmss(seconds: float) -> String:
	var s: int = roundi(seconds)
	return "%d:%02d" % [s / 60, s % 60]
