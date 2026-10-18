class_name BetweenRunScreen
extends CanvasLayer
## The between-run screen (spec §1.3, §9; Art Direction: framed as Taln's
## memory; a placeholder dark panel for now). Shown when the cycle ends: the
## game pauses and the mouse is freed. It states the outcome plainly (Held or
## Closed, never framed as winning or losing), the cycle's time, kills,
## Returns, fills Welcomed and Banked, and Agony banked this cycle and in
## total. Banked Agony raises skill caps here at c − 1 points per step (§9).
## The next cycle's Aspect is chosen here, and banked Agony opens gates on
## the persistent map for good (P2-10, spec v1.4 #1, #4). "Begin the next
## cycle" loads the station again with a new seed.

signal next_cycle_requested

## Debug (they run through the screen's pause, so they work here): Ctrl+8
## grants this many spendable points; Ctrl+9 held this long wipes MetaState.
const DEBUG_AGONY_GRANT := 9
const DEBUG_WIPE_HOLD := 1.0

const PANEL := Color("0b0b0e", 0.92)
const TEXT := Color("a69e8f")
const DIM := Color("5a564f")
const HONOR := Color("cfe8ff")
const AGONY := Color("ff8a3d")
## The panel never grows past this share of the screen's height; past it, it scrolls.
const MAX_HEIGHT_FRACTION := 0.85

## Skills whose caps can be raised here.
@export var cap_skills: Array[SkillDef] = []
## Gates that can be opened here.
@export var gates: Array[GateDef] = []

var is_open: bool = false
var stats: Dictionary = {}
var _panel: PanelContainer
var _scroll: ScrollContainer
var _box: VBoxContainer
var _title: Label
var _lines: Label
var _banked: Label
var _cap_rows: Array[Button] = []
var _aspect_rows: Array[Button] = []
var _gate_rows: Array[Button] = []
var _begin: Button
var _wipe_held: float = 0.0
var _wiped: bool = false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false
	Cycle.director().cycle_ended.connect(show_summary)
	Meta.state().changed.connect(_refresh_caps)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_grant_agony"):
		Meta.state().grant(DEBUG_AGONY_GRANT)
		print("Banked Agony now %d" % Meta.state().banked_agony)


func _process(delta: float) -> void:
	# Ctrl+9 must be held a full second to wipe.
	if Input.is_action_pressed("debug_wipe_meta"):
		_wipe_held += delta
		if _wipe_held >= DEBUG_WIPE_HOLD and not _wiped:
			_wiped = true
			Meta.state().wipe()
			print("MetaState wiped")
	else:
		_wipe_held = 0.0
		_wiped = false


func show_summary(outcome: Cycle.Outcome, summary: Dictionary) -> void:
	stats = summary
	is_open = true
	get_tree().paused = true
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_title.text = UiText.OUTCOME_HELD if outcome == Cycle.Outcome.HELD else UiText.OUTCOME_CLOSED
	var seconds: int = roundi(summary.time)
	_lines.text = "\n".join([
		UiText.SUMMARY_TIME % [seconds / 60, seconds % 60],
		UiText.SUMMARY_KILLS % summary.kills,
		UiText.SUMMARY_RETURNS % summary.returns,
		UiText.SUMMARY_FILLS % [summary.welcomed, summary.banked],
	])
	_refresh_caps()
	_panel.visible = true
	_fit_scroll()
	_scroll.scroll_vertical = 0
	_begin.grab_focus.call_deferred()


func _refresh_caps() -> void:
	if not is_open:
		return
	var meta: Meta = Meta.state()
	_banked.text = UiText.SUMMARY_AGONY % [stats.get("banked", 0), meta.banked_total, meta.banked_agony]
	for i in _cap_rows.size():
		var skill: SkillDef = cap_skills[i]
		var cap: int = meta.get_cap(skill.id)
		var cost: int = meta.cap_raise_cost(skill.id)
		var button: Button = _cap_rows[i]
		if cost < 0:
			button.text = UiText.CAP_MAX % [skill.display_name, cap]
			button.disabled = true
		else:
			button.text = UiText.CAP_RAISE % [skill.display_name, cap, cap + 1, cost]
			button.disabled = meta.banked_agony < cost
	var chosen: AspectDef = Cycle.director().aspect()
	var aspects: Array[AspectDef] = Cycle.director().tuning.aspects
	for i in _aspect_rows.size():
		var aspect: AspectDef = aspects[i]
		_aspect_rows[i].text = (UiText.ASPECT_CHOSEN if aspect == chosen else UiText.ASPECT_OPTION) % aspect.display_name
	for i in _gate_rows.size():
		var gate: GateDef = gates[i]
		var open: bool = meta.is_gate_open(gate.id)
		_gate_rows[i].text = UiText.GATE_OPENED % gate.display_name if open 				else UiText.GATE_OPEN % [gate.display_name, gate.cost]
		_gate_rows[i].disabled = open or meta.banked_agony < gate.cost


func raise(index: int) -> bool:
	var raised: bool = Meta.state().raise_cap(cap_skills[index].id)
	_refresh_caps()
	return raised


func choose_aspect(index: int) -> void:
	Meta.state().set_aspect(Cycle.director().tuning.aspects[index].id)
	_refresh_caps()


func open_gate(index: int) -> bool:
	var opened: bool = Meta.state().open_gate(gates[index].id, gates[index].cost)
	_refresh_caps()
	return opened


func begin_next() -> void:
	is_open = false
	_panel.visible = false
	next_cycle_requested.emit()
	Cycle.director().begin_next_cycle()


func _build() -> void:
	# A full-screen center container keeps the panel centered as its text changes.
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_content_margin_all(28.0)
	_panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(_panel)
	# The panel scrolls once its rows outgrow the screen (focus follows for the pad).
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_panel.add_child(_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	_scroll.add_child(box)
	_box = box
	_title = Label.new()
	_title.add_theme_color_override(&"font_color", HONOR)
	_title.add_theme_font_size_override(&"font_size", 34)
	box.add_child(_title)
	_lines = Label.new()
	_lines.add_theme_color_override(&"font_color", TEXT)
	_lines.add_theme_font_size_override(&"font_size", 18)
	box.add_child(_lines)
	_banked = Label.new()
	_banked.add_theme_color_override(&"font_color", AGONY)
	_banked.add_theme_font_size_override(&"font_size", 18)
	box.add_child(_banked)
	var caps_title := Label.new()
	caps_title.text = UiText.CAPS_TITLE
	caps_title.add_theme_color_override(&"font_color", TEXT)
	box.add_child(caps_title)
	for i in cap_skills.size():
		var button: Button = _button(box)
		button.pressed.connect(raise.bind(i))
		_cap_rows.append(button)
	var aspects: Array[AspectDef] = Cycle.director().tuning.aspects
	if aspects.size() > 1:
		_title_label(box, UiText.ASPECT_TITLE)
		for i in aspects.size():
			var button: Button = _button(box)
			button.pressed.connect(choose_aspect.bind(i))
			_aspect_rows.append(button)
	if not gates.is_empty():
		_title_label(box, UiText.GATES_TITLE)
		for i in gates.size():
			var button: Button = _button(box)
			button.pressed.connect(open_gate.bind(i))
			_gate_rows.append(button)
	_begin = _button(box)
	_begin.text = UiText.BEGIN_NEXT
	_begin.pressed.connect(begin_next)


## Sizes the scroll area to the rows, capped at MAX_HEIGHT_FRACTION of the screen.
func _fit_scroll() -> void:
	var rows: Vector2 = _box.get_combined_minimum_size()
	var cap: float = get_viewport().get_visible_rect().size.y * MAX_HEIGHT_FRACTION
	_scroll.custom_minimum_size = Vector2(rows.x, minf(rows.y, cap))


func _title_label(box: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", TEXT)
	box.add_child(label)


func _button(box: Control) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(460.0, 38.0)
	button.add_theme_color_override(&"font_color", TEXT)
	button.add_theme_color_override(&"font_hover_color", HONOR)
	button.add_theme_color_override(&"font_focus_color", HONOR)
	button.add_theme_color_override(&"font_disabled_color", DIM)
	for state: StringName in [&"normal", &"pressed", &"disabled"]:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("2a2825", 0.6)
		flat.content_margin_left = 14.0
		button.add_theme_stylebox_override(state, flat)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("5a564f", 0.6)
	hover.content_margin_left = 14.0
	button.add_theme_stylebox_override(&"hover", hover)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = HONOR
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override(&"focus", focus)
	box.add_child(button)
	return button
