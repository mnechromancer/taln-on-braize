class_name CatalyzeUi
extends CanvasLayer
## The Welcome the Agony prompt and the Catalyze window (spec §3.4, Art
## Direction: Catalyze UI). Drives a Catalysis:
## - Prompt: Welcome with 1, gamepad A or a click; Bank with 2, gamepad B or a
##   click. A bar shows the real time left.
## - Catalyze: one icon per owned catalyst with its cost in ninths. Hold the
##   left mouse button on an icon, or give it D-pad focus and hold A, and it
##   fills in Agony hue; full, the catalyst is committed and its cost comes
##   off the meter as notches (the HUD's meter shows them). Release with R,
##   gamepad Y or a click. A press of A that Welcomed doesn't also commit:
##   A has to come up first.

## Low and see-through: the game runs underneath, and telegraphs and Taln
## outrank the prompt (Art Direction, VFX priority).
const PANEL := Color("2a2825", 0.6)
## The panels sit this far above the screen's bottom edge, over the HUD.
const PANEL_LIFT := 110.0
const TEXT := Color("a69e8f")
const DIM := Color("5a564f")
const AGONY := Color("e0581f")
const AGONY_LIT := Color("ff8a3d")
const TRACK := Color("0b0b0e", 0.7)
const ICON_SIZE := Vector2(190.0, 64.0)

@export var catalysis: Catalysis

var _dock: VBoxContainer
var _prompt: PanelContainer
var _prompt_timer: ColorRect
var _welcome: Button
var _bank: Button
var _catalyze: PanelContainer
var _catalyze_timer: ColorRect
var _budget: Label
var _icons: HBoxContainer
var _release: Button
## Per icon: the skill and its fill bar.
var _icon_skills: Array[SkillDef] = []
var _icon_fills: Array[ColorRect] = []
var _icon_controls: Array[Control] = []
var _mouse_holding: bool = false
var _pad_armed: bool = false
## Where the pointer last was, from mouse events (screen space).
var _pointer: Vector2 = Vector2.ZERO


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	catalysis.prompt_opened.connect(_show_prompt)
	catalysis.welcomed.connect(_show_catalyze)
	catalysis.committed.connect(func(_skill: SkillDef, _left: int) -> void: _pad_armed = false)
	catalysis.resolved.connect(func(_choice: StringName, _fired: Array[SkillDef], _held: Array[SkillDef]) -> void: _hide())
	_hide()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer = (event as InputEventMouse).global_position
	# Only the D-pad moves focus between icons: the stick is walking.
	if catalysis.state == Catalysis.State.CATALYZE and event is InputEventJoypadMotion \
			and (event.is_action("ui_left") or event.is_action("ui_right") or event.is_action("ui_up")
			or event.is_action("ui_down")):
		get_viewport().set_input_as_handled()
		return
	match catalysis.state:
		Catalysis.State.PROMPT:
			if event.is_action_pressed("welcome"):
				catalysis.welcome()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("bank"):
				catalysis.bank_now()
				get_viewport().set_input_as_handled()
		Catalysis.State.CATALYZE:
			if event.is_action_pressed("catalyze_release"):
				catalysis.release()
				get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if catalysis.state == Catalysis.State.IDLE:
		return
	var t: AgonyTuning = catalysis.tuning
	if catalysis.state == Catalysis.State.PROMPT:
		_prompt_timer.size.x = _prompt_timer.get_parent_control().size.x * clampf(catalysis.window_left / t.prompt_window, 0.0, 1.0)
		return
	_catalyze_timer.size.x = _catalyze_timer.get_parent_control().size.x \
			* clampf(catalysis.window_left / t.catalyze_window, 0.0, 1.0)
	# Gamepad: hold A on the focused icon, once A has come up since Welcome or
	# the last commit. Only icons that can still be committed take a hold.
	var pad_down: bool = Input.is_action_pressed("catalyze_commit")
	if not pad_down:
		_pad_armed = true
	var held: int = _icon_skills.find(catalysis.holding())
	if _mouse_holding and (held < 0 or not _icon_controls[held].get_global_rect().has_point(_pointer)):
		_mouse_holding = false  # Committed, or the pointer left the icon mid-hold.
		catalysis.set_holding(null)
	if not _mouse_holding:
		var focused: int = _icon_controls.find(get_viewport().gui_get_focus_owner())
		var skill: SkillDef = _icon_skills[focused] if focused >= 0 else null
		catalysis.set_holding(skill if pad_down and _pad_armed and _can_take(skill) else null)
	_budget.text = UiText.CATALYZE_BUDGET % [catalysis.budget_left, t.budget_ninths]
	for i in _icon_skills.size():
		var skill: SkillDef = _icon_skills[i]
		var fill: float = 1.0 if catalysis.committed_skills.has(skill) else 0.0
		if catalysis.holding() == skill:
			fill = clampf(catalysis.hold_time / t.commit_hold, 0.0, 1.0)
		_icon_fills[i].size.x = ICON_SIZE.x * fill
		_icon_fills[i].color = AGONY_LIT if catalysis.committed_skills.has(skill) else AGONY
		var fits: bool = catalysis.taln.loadout.catalyst_cost(skill) <= catalysis.budget_left
		_icon_controls[i].modulate = Color.WHITE if fits or catalysis.committed_skills.has(skill) else Color(1, 1, 1, 0.4)
	_release.disabled = catalysis.committed_skills.is_empty()


func _can_take(skill: SkillDef) -> bool:
	return skill != null and not catalysis.committed_skills.has(skill) \
			and catalysis.taln.loadout.catalyst_cost(skill) <= catalysis.budget_left


## Icon labels, in order (for checks and the bot).
func icon_skills() -> Array[SkillDef]:
	return _icon_skills.duplicate()


func icon_control(index: int) -> Control:
	return _icon_controls[index]


func _show_prompt() -> void:
	_prompt.visible = true
	_catalyze.visible = false


func _show_catalyze() -> void:
	_prompt.visible = false
	_catalyze.visible = true
	_pad_armed = not Input.is_action_pressed("catalyze_commit")
	_mouse_holding = false
	for control: Control in _icon_controls:
		control.queue_free()
	_icon_controls.clear()
	_icon_fills.clear()
	_icon_skills.clear()
	for skill: SkillDef in catalysis.taln.loadout.catalysts():
		_add_icon(skill)
	if not _icon_controls.is_empty():
		_icon_controls[0].grab_focus.call_deferred()


func _hide() -> void:
	_prompt.visible = false
	_catalyze.visible = false
	_mouse_holding = false


func _add_icon(skill: SkillDef) -> void:
	var icon := Panel.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.focus_mode = Control.FOCUS_ALL
	var style := StyleBoxFlat.new()
	style.bg_color = TRACK
	icon.add_theme_stylebox_override(&"panel", style)
	var fill := ColorRect.new()
	fill.color = AGONY
	fill.size = Vector2(0.0, ICON_SIZE.y)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(fill)
	var label := Label.new()
	label.text = UiText.CATALYZE_ICON % [skill.display_name, catalysis.taln.loadout.catalyst_cost(skill)]
	label.add_theme_color_override(&"font_color", TEXT)
	label.add_theme_font_size_override(&"font_size", 18)
	label.position = Vector2(12.0, 18.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(label)
	# A focus outline in Agony hue, drawn over the fill.
	var focus := Panel.new()
	var focus_style := StyleBoxFlat.new()
	focus_style.draw_center = false
	focus_style.border_color = AGONY_LIT
	focus_style.set_border_width_all(2)
	focus.add_theme_stylebox_override(&"panel", focus_style)
	focus.size = ICON_SIZE
	focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus.visible = false
	icon.add_child(focus)
	icon.focus_entered.connect(func() -> void: focus.visible = true)
	icon.focus_exited.connect(func() -> void: focus.visible = false)
	icon.gui_input.connect(_on_icon_input.bind(skill))
	_icons.add_child(icon)
	_icon_controls.append(icon)
	_icon_fills.append(fill)
	_icon_skills.append(skill)


func _on_icon_input(event: InputEvent, skill: SkillDef) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	_pointer = button.global_position
	_mouse_holding = button.pressed and _can_take(skill)
	catalysis.set_holding(skill if _mouse_holding else null)
	get_viewport().set_input_as_handled()


# --- layout --------------------------------------------------------------------

## A panel docked low in the middle, and the box its contents go in.
func _panel() -> Array[Control]:
	if _dock == null:
		# Full screen, bottom-aligned, with PANEL_LIFT of space under the panels.
		_dock = VBoxContainer.new()
		_dock.alignment = BoxContainer.ALIGNMENT_END
		_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_dock)
		_dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_dock.offset_bottom = -PANEL_LIFT
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_dock.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	return [panel, box]


func _title(box: Control, text: String) -> void:
	var title := Label.new()
	title.text = text
	title.add_theme_color_override(&"font_color", AGONY_LIT)
	title.add_theme_font_size_override(&"font_size", 26)
	box.add_child(title)


func _timer_bar(box: Control) -> ColorRect:
	var track := ColorRect.new()
	track.color = TRACK
	track.custom_minimum_size = Vector2(0.0, 6.0)
	box.add_child(track)
	var fill := ColorRect.new()
	fill.color = AGONY
	fill.size = Vector2(0.0, 6.0)
	track.add_child(fill)
	return fill


func _button(box: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 40.0)
	button.add_theme_color_override(&"font_color", TEXT)
	button.add_theme_color_override(&"font_hover_color", AGONY_LIT)
	button.add_theme_color_override(&"font_focus_color", AGONY_LIT)
	button.add_theme_color_override(&"font_disabled_color", DIM)
	button.add_theme_font_size_override(&"font_size", 18)
	for state: StringName in [&"normal", &"pressed", &"disabled", &"hover"]:
		var style := StyleBoxFlat.new()
		style.bg_color = TRACK
		style.content_margin_left = 14.0
		style.content_margin_right = 14.0
		button.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = AGONY_LIT
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override(&"focus", focus)
	# No focus: A, B, Y, 1, 2 and R map straight to their choices, and a stray
	# Space (Shoulder) can't press a focused button.
	button.focus_mode = Control.FOCUS_NONE
	box.add_child(button)
	return button


func _build() -> void:
	var prompt: Array[Control] = _panel()
	_prompt = prompt[0]
	var box: VBoxContainer = prompt[1]
	_title(box, UiText.WELCOME_TITLE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	box.add_child(row)
	_welcome = _button(row, UiText.WELCOME_OPTION)
	_bank = _button(row, UiText.BANK_OPTION)
	_welcome.pressed.connect(func() -> void: catalysis.welcome())
	_bank.pressed.connect(func() -> void: catalysis.bank_now())
	_prompt_timer = _timer_bar(box)

	var catalyze: Array[Control] = _panel()
	_catalyze = catalyze[0]
	box = catalyze[1]
	_title(box, UiText.CATALYZE_TITLE)
	_budget = Label.new()
	_budget.add_theme_color_override(&"font_color", TEXT)
	box.add_child(_budget)
	_icons = HBoxContainer.new()
	_icons.add_theme_constant_override(&"separation", 10)
	box.add_child(_icons)
	var hint := Label.new()
	hint.text = UiText.CATALYZE_HINT
	hint.add_theme_color_override(&"font_color", TEXT)
	hint.add_theme_font_size_override(&"font_size", 13)
	box.add_child(hint)
	_release = _button(box, UiText.RELEASE)
	_release.pressed.connect(func() -> void: catalysis.release())
	_catalyze_timer = _timer_bar(box)
