class_name Hud
extends CanvasLayer
## The play HUD (Art Direction, UI/HUD): flat dark-stone panels at low
## opacity, no gradients or bevels, color only from the world's signal hues
## (Investiture in Honor hue). Separate from the F3 debug overlay. Shows
## Health, the Agony meter (nine segments; during Catalyze the committed
## cost shows as consumed notches), held Investiture with the next level cost
## and a ready mark, the Surge and Draw cooldowns, nine Strain pips and the
## wave (on the Braize slice: the region, its clock and the way to its
## breaker), plus a brief notice when Agony banks. Read-only: it polls the systems
## it shows every frame.

const PANEL := Color("2a2825", 0.55)
const TEXT := Color("a69e8f")
const DIM := Color("5a564f")
const HONOR := Color("cfe8ff")
const STONEWARD := Color("d9a55b")
const VOID_CORE := Color("6b3fa0")
const VOID_RIM := Color("7fe3d6")
const EMPTY := Color("0b0b0e", 0.7)
const AGONY := Color("e0581f")
const AGONY_LIT := Color("ff8a3d")
const AGONY_SPENT := Color("e0581f", 0.3)
const SEGMENT_SIZE := Vector2(26.0, 12.0)
const MARGIN := 20.0
const BAR_SIZE := Vector2(220.0, 10.0)
const PIP_SIZE := Vector2(14.0, 14.0)

@export var taln: Taln
@export var spawner: SpawnDirector
## For the committed notches and the banked notice; optional.
@export var catalysis: Catalysis
@export_range(0.0, 10.0, 0.1, "suffix:s") var notice_time: float = 2.5

var _health_fill: ColorRect
var _health_value: Label
var _investiture_value: Label
var _next_level: Label
var _ready_mark: Label
var _surge_name: Label
var _surge_state: Label
var _surge_fill: ColorRect
var _draw_state: Label
var _draw_fill: ColorRect
var _pips: Array[ColorRect] = []
var _pip_fills: Array[Panel] = []
var _wave: Label
var _returns: Label
var _segments: Array[ColorRect] = []
var _segment_fills: Array[ColorRect] = []
var _notice: Label
var _notice_left: float = 0.0


func _ready() -> void:
	layer = 5
	# Read-only, so it keeps showing through full pauses (the full-pause Catalyze option).
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_status(root)
	_build_abilities(root)
	_build_wave(root)
	if catalysis:
		catalysis.banked.connect(func(first: bool) -> void:
			_notice.text = UiText.NOTICE_UNLOCKED if first else UiText.NOTICE_BANKED
			_notice_left = notice_time)


func _process(delta: float) -> void:
	_show_agony()
	_notice_left = maxf(_notice_left - delta / maxf(Engine.time_scale, 0.001), 0.0)
	_notice.get_parent().get_parent().visible = _notice_left > 0.0
	var health: Health = taln.health
	var ratio: float = health.current / taln.tuning.max_health if taln.tuning.max_health > 0.0 else 0.0
	_health_fill.size.x = BAR_SIZE.x * clampf(ratio, 0.0, 1.0)
	_health_value.text = "%d / %d" % [ceili(health.current), roundi(taln.tuning.max_health)]

	_investiture_value.text = "%d" % floori(taln.investiture.current)
	_next_level.text = UiText.NEXT_LEVEL % roundi(taln.leveling.next_cost())
	_ready_mark.visible = taln.leveling.can_invest()

	var surge: SurgeBehavior = taln.loadout.get_surge_behavior(0)
	if surge:
		_surge_name.text = "%s  %d" % [surge.skill.display_name, roundi(surge.skill.investiture_cost)]
		var affordable: bool = taln.investiture.can_afford(surge.skill.investiture_cost)
		_show_timer(_surge_state, _surge_fill, surge.cooldown_left, surge.skill.cooldown)
		_surge_name.add_theme_color_override(&"font_color", TEXT if affordable else DIM)
	var toauma: Toauma = taln.toauma
	_show_timer(_draw_state, _draw_fill, toauma.draw_cooldown_left, toauma.tuning.draw_cooldown)

	for i in _pips.size():
		var f: float = clampf(toauma.strain - i, 0.0, 1.0)
		_pip_fills[i].size.x = PIP_SIZE.x * f
	var slice := spawner.get_parent() as BraizeSlice
	if slice and slice.current:
		_wave.text = "%s
%s" % [UiText.REGION % [slice.current.display_name, slice.current.tier, spawner.wave + 1],
				_objective(slice)]
		var field: String = _field_line(slice)
		if not field.is_empty():
			_wave.text += "\n" + field
	else:
		var stations: String = UiText.STATION % [spawner.station_index + 1, _cycle_stations()]
		_wave.text = "%s   %s" % [stations, UiText.LULL if spawner.lull else UiText.WAVE % [spawner.wave + 1, spawner.tuning.waves]]
	_returns.text = UiText.RETURNS % Cycle.director().returns


## Nine segments filling in Agony hue; the last full ones brighten. During
## Catalyze the committed cost is shown consumed from the top of the meter.
func _show_agony() -> void:
	var meter: AgonyMeter = taln.agony
	var per: float = meter.tuning.per_ninth
	var spent: int = 0
	if catalysis and catalysis.state == Catalysis.State.CATALYZE:
		spent = meter.tuning.budget_ninths - catalysis.budget_left
	for i in _segments.size():
		var f: float = clampf((meter.value - i * per) / per, 0.0, 1.0)
		_segment_fills[i].size.x = SEGMENT_SIZE.x * f
		var consumed: bool = i >= _segments.size() - spent
		_segment_fills[i].color = AGONY_SPENT if consumed else (AGONY_LIT if meter.is_locked else AGONY)


## The Braize slice's objective line: the way to the breaker site, the
## siege's time left, or the open seals.
func _objective(slice: BraizeSlice) -> String:
	match slice.state:
		BraizeSlice.State.SIEGE:
			return UiText.SIEGE % ceili(slice.siege_left)
		BraizeSlice.State.FALLEN:
			return UiText.SEALS_OPEN % (slice.current.tier + 1)
	var site: Vector3 = slice.current.site.global_position
	return UiText.BREAKER_SITE % [roundi(slice.distance_to_site()), _arrow_to(site)]


## The slice's third line: whether the swarm sees Taln, the nearest
## commander, standing structures and the infected (each only when there is
## something to say).
func _field_line(slice: BraizeSlice) -> String:
	var parts: Array[String] = []
	var awareness: Awareness = taln.loadout.awareness
	if awareness and awareness.enabled:
		parts.append(UiText.AWARENESS[awareness.state])
	var commander: Vector3 = slice.nearest_commander()
	if commander != Vector3.INF:
		var d: float = Vector2(commander.x - taln.global_position.x, commander.z - taln.global_position.z).length()
		parts.append(UiText.COMMANDER % [roundi(d), _arrow_to(commander)])
	var structures: Structures = taln.loadout.structures
	if structures and not structures.standing().is_empty():
		parts.append(UiText.STRUCTURES % structures.standing().size())
	var infected: int = taln.loadout.swarm.get_infected_count() if taln.loadout.swarm else 0
	if infected > 0:
		parts.append(UiText.INFECTED % infected)
	return "   ".join(parts)


## An arrow for the direction from Taln to at, relative to where the camera faces.
func _arrow_to(at: Vector3) -> String:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return ""
	var forward: Vector3 = -camera.global_basis.z
	var to: Vector3 = at - taln.global_position
	var angle: float = atan2(forward.x * to.z - forward.z * to.x, forward.x * to.x + forward.z * to.z)
	var index: int = posmod(roundi(angle / (TAU / UiText.ARROWS.size())), UiText.ARROWS.size())
	return UiText.ARROWS[index]


func _cycle_stations() -> int:
	return Cycle.director().tuning.stations


func _show_timer(state: Label, fill: ColorRect, left: float, total: float) -> void:
	state.text = UiText.READY if left <= 0.0 else UiText.SECONDS % left
	fill.size.x = BAR_SIZE.x * 0.5 * (1.0 - clampf(left / total, 0.0, 1.0) if total > 0.0 else 1.0)


# --- layout ------------------------------------------------------------------

func _panel(parent: Control, preset: Control.LayoutPreset) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override(&"panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	# Grow away from the anchored edge as rows are added, so nothing runs off screen.
	match preset:
		Control.PRESET_BOTTOM_LEFT:
			panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_BOTTOM:
			panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
			panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		Control.PRESET_CENTER_TOP:
			panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 4)
	panel.add_child(box)
	return box


func _label(parent: Control, text: String, color: Color, size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	return row


## A flat bar: a dark track and a fill whose width callers set.
func _bar(parent: Control, color: Color, size: Vector2) -> ColorRect:
	var track := ColorRect.new()
	track.color = EMPTY
	track.custom_minimum_size = size
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(track)
	var fill := ColorRect.new()
	fill.color = color
	fill.size = size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	return fill


func _build_status(root: Control) -> void:
	var box: VBoxContainer = _panel(root, Control.PRESET_BOTTOM_LEFT)
	var health: HBoxContainer = _row(box)
	_label(health, UiText.HEALTH, TEXT)
	_health_fill = _bar(health, STONEWARD, BAR_SIZE)
	_health_value = _label(health, "", TEXT)
	var agony: HBoxContainer = _row(box)
	_label(agony, UiText.AGONY, TEXT)
	var meter := HBoxContainer.new()
	meter.add_theme_constant_override(&"separation", 2)  # The notches between ninths.
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	agony.add_child(meter)
	for i in roundi(taln.agony.tuning.meter_max / taln.agony.tuning.per_ninth):
		var segment := ColorRect.new()
		segment.color = EMPTY
		segment.custom_minimum_size = SEGMENT_SIZE
		segment.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meter.add_child(segment)
		var fill := ColorRect.new()
		fill.color = AGONY
		fill.size = Vector2(0.0, SEGMENT_SIZE.y)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segment.add_child(fill)
		_segments.append(segment)
		_segment_fills.append(fill)
	_returns = _label(box, "", TEXT)
	var inv: HBoxContainer = _row(box)
	_label(inv, UiText.INVESTITURE, TEXT)
	_investiture_value = _label(inv, "", HONOR, 24)
	var level: HBoxContainer = _row(box)
	_next_level = _label(level, "", TEXT)
	_ready_mark = _label(level, UiText.INVEST_READY, HONOR)


func _build_abilities(root: Control) -> void:
	var box: VBoxContainer = _panel(root, Control.PRESET_CENTER_BOTTOM)
	var surge: HBoxContainer = _row(box)
	_surge_name = _label(surge, "", TEXT)
	_surge_fill = _bar(surge, STONEWARD, Vector2(BAR_SIZE.x * 0.5, BAR_SIZE.y))
	_surge_state = _label(surge, "", TEXT)
	var draw: HBoxContainer = _row(box)
	_label(draw, UiText.DRAW, TEXT)
	_draw_fill = _bar(draw, VOID_RIM, Vector2(BAR_SIZE.x * 0.5, BAR_SIZE.y))
	_draw_state = _label(draw, "", TEXT)
	var strain: HBoxContainer = _row(box)
	_label(strain, UiText.STRAIN, TEXT)
	for i in roundi(taln.toauma.tuning.strain_max):
		var pip := ColorRect.new()
		pip.color = EMPTY
		pip.custom_minimum_size = PIP_SIZE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strain.add_child(pip)
		# A filled pip is Taln's Voidlight: dark core, teal rim (Art Direction).
		var fill := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = VOID_CORE
		style.border_color = VOID_RIM
		style.set_border_width_all(2)
		fill.add_theme_stylebox_override(&"panel", style)
		fill.size = Vector2(0.0, PIP_SIZE.y)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_child(fill)
		_pips.append(pip)
		_pip_fills.append(fill)


func _build_wave(root: Control) -> void:
	var box: VBoxContainer = _panel(root, Control.PRESET_CENTER_TOP)
	_wave = _label(box, "", TEXT, 18)
	var notice: VBoxContainer = _panel(root, Control.PRESET_CENTER_TOP)
	(notice.get_parent() as Control).position.y += 56.0
	_notice = _label(notice, "", AGONY_LIT, 18)
