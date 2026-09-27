class_name LevelUpMenu
extends CanvasLayer
## The Invest menu (spec §2.4). Invest (Tab / gamepad Back) does nothing
## unless Taln holds C(n); otherwise the game pauses fully and this shows the
## offer: up to three skills, or Consolidate when every owned skill is capped.
## Pick with 1–3, a click, or the D-pad and A (A is allowed in paused menus).
## Invest again closes it without spending. The mouse is freed while it's
## open and captured again after. Picks in the first menu_input_delay are
## ignored, so a key still held from play can't pick. That delay counts real
## frame time (unscaled, and running while paused), not the wall clock, so
## headless runs behave the same as played ones.

signal opened(offer: Array[SkillDef])
signal closed(picked: bool)

const PANEL := Color("2a2825", 0.85)
const TEXT := Color("a69e8f")
const HONOR := Color("cfe8ff")
const BUTTON := Color("0b0b0e", 0.6)
const BUTTON_HOVER := Color("5a564f", 0.6)

@export var taln: Taln

var is_open: bool = false
## Other systems that must hold the menu shut (a Welcome prompt, the Return).
var blocked: bool = false
var _offer: Array[SkillDef] = []
var _buttons: Array[Button] = []
## Unscaled seconds since the menu opened.
var _open_for: float = 0.0
var _panel: PanelContainer
var _list: VBoxContainer
var _cost: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func _process(delta: float) -> void:
	if is_open:
		_open_for += delta / Engine.time_scale if Engine.time_scale > 0.0 else delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("invest"):
		if is_open:
			close(false)
		else:
			try_open()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	for i in 3:
		if event.is_action_pressed("pick_%d" % (i + 1)):
			pick(i)
			get_viewport().set_input_as_handled()
			return


## Opens the menu if Taln can afford a level and nothing blocks it.
func try_open() -> bool:
	if is_open or blocked or get_tree().paused or not taln.leveling.can_invest():
		return false
	_offer = taln.leveling.offer()
	_fill()
	is_open = true
	_open_for = 0.0
	_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	opened.emit(_offer)
	return true


## Takes option index (0-based): a skill from the offer, or Consolidate when
## the offer is empty. Ignored during the input delay or past the options.
func pick(index: int) -> bool:
	if not is_open or _open_for < taln.leveling.tuning.menu_input_delay:
		return false
	var done: bool = false
	if _offer.is_empty():
		done = index == 0 and taln.leveling.consolidate()
	elif index < _offer.size():
		done = taln.leveling.take(_offer[index])
	if done:
		close(true)
	return done


func close(picked: bool) -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit(picked)


## Button labels, in pick order (for checks and the bot).
func option_texts() -> Array[String]:
	var texts: Array[String] = []
	for button in _buttons:
		texts.append(button.text)
	return texts


func _fill() -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
	_cost.text = UiText.INVEST_COST % roundi(taln.leveling.next_cost())
	var loadout: Loadout = taln.loadout
	if _offer.is_empty():
		var heal: int = roundi(taln.leveling.tuning.consolidate_heal_fraction * 100.0)
		_add_button(UiText.INVEST_CONSOLIDATE % [1, heal], 0)
	else:
		for i in _offer.size():
			var skill: SkillDef = _offer[i]
			var level: int = loadout.get_level(skill.id)
			_add_button(UiText.INVEST_OPTION % [i + 1, skill.display_name, level, level + 1], i)
	_buttons[0].grab_focus.call_deferred()


func _add_button(text: String, index: int) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(420.0, 40.0)
	button.add_theme_color_override(&"font_color", TEXT)
	button.add_theme_color_override(&"font_hover_color", HONOR)
	button.add_theme_color_override(&"font_focus_color", HONOR)
	button.add_theme_font_size_override(&"font_size", 18)
	for state: StringName in [&"normal", &"pressed", &"disabled"]:
		button.add_theme_stylebox_override(state, _flat(BUTTON, Color.TRANSPARENT))
	button.add_theme_stylebox_override(&"hover", _flat(BUTTON_HOVER, Color.TRANSPARENT))
	button.add_theme_stylebox_override(&"focus", _flat(BUTTON, HONOR))
	button.pressed.connect(pick.bind(index))
	_list.add_child(button)
	_buttons.append(button)


func _flat(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	if border.a > 0.0:
		style.draw_center = false
		style.border_color = border
		style.set_border_width_all(2)
	return style


func _build() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_content_margin_all(20.0)
	_panel.add_theme_stylebox_override(&"panel", style)
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	_panel.add_child(box)
	var title := Label.new()
	title.text = UiText.INVEST_TITLE
	title.add_theme_color_override(&"font_color", HONOR)
	title.add_theme_font_size_override(&"font_size", 26)
	box.add_child(title)
	_cost = Label.new()
	_cost.add_theme_color_override(&"font_color", TEXT)
	box.add_child(_cost)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 6)
	box.add_child(_list)
	var heal := Label.new()
	heal.text = UiText.INVEST_HEAL % roundi(taln.leveling.tuning.level_heal_fraction * 100.0)
	heal.add_theme_color_override(&"font_color", TEXT)
	box.add_child(heal)
	var hint := Label.new()
	hint.text = UiText.INVEST_HINT
	hint.add_theme_color_override(&"font_color", TEXT)
	hint.add_theme_font_size_override(&"font_size", 13)
	box.add_child(hint)
