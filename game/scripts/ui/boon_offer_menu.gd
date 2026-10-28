class_name BoonOfferMenu
extends CanvasLayer
## A bargain offer (P2-16): one of three, each named with its source and a
## line on what it does (and asks). Opens as soon as play allows (not under
## another pause, the Return, a Welcome or Catalyze window, the Invest menu
## or a breaker drop), pauses the game fully and frees the mouse. Pick with
## 1–3, a click, or the D-pad and A. No backing out. Picks in the first
## menu_input_delay (real frame time) are ignored. Same placeholder panel
## as the breaker drop.

signal opened(offer: Array[BoonDef])
signal closed(boon: BoonDef)

const PANEL := Color("2a2825", 0.85)
const TEXT := Color("a69e8f")
const DIM := Color("7a7268")
const HONOR := Color("cfe8ff")
const BUTTON := Color("0b0b0e", 0.6)
const BUTTON_HOVER := Color("5a564f", 0.6)

@export var boons: Boons
@export var taln: Taln
@export var catalysis: Catalysis
@export var level_menu: LevelUpMenu
@export var kit_menu: KitOfferMenu

var is_open: bool = false
## Offers waiting for play to allow the menu, oldest first.
var pending: Array[Array] = []
var _offer: Array[BoonDef] = []
var _buttons: Array[Button] = []
var _open_for: float = 0.0
var _panel: PanelContainer
var _list: VBoxContainer


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false
	boons.offered.connect(func(offer: Array[BoonDef]) -> void: pending.append(offer.duplicate()))


func _process(delta: float) -> void:
	if is_open:
		_open_for += delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	elif not pending.is_empty() and _can_open():
		_open(pending.pop_front())


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	for i in 3:
		if event.is_action_pressed("pick_%d" % (i + 1)):
			pick(i)
			get_viewport().set_input_as_handled()
			return


## Takes the bargain at index (0-based). Ignored during the input delay or past the options.
func pick(index: int) -> bool:
	if not is_open or _open_for < taln.leveling.tuning.menu_input_delay or index >= _offer.size():
		return false
	var boon: BoonDef = _offer[index]
	if not boons.take(boon):
		return false
	is_open = false
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit(boon)
	return true


## Button labels, in pick order (for checks).
func option_texts() -> Array[String]:
	var texts: Array[String] = []
	for button in _buttons:
		texts.append(button.text)
	return texts


func _can_open() -> bool:
	return not get_tree().paused and not taln.frozen and catalysis.state == Catalysis.State.IDLE \
			and not level_menu.is_open and (kit_menu == null or not kit_menu.is_open) \
			and Cycle.director().outcome == Cycle.Outcome.NONE


func _open(offer: Array) -> void:
	_offer.assign(offer)
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
	for i in _offer.size():
		var boon: BoonDef = _offer[i]
		_add_button("%s\n%s" % [UiText.BOON_OPTION % [i + 1, UiText.BOON_SOURCES[boon.source], boon.display_name],
				UiText.BOON_LINE % boon.line], i)
	_buttons[0].grab_focus.call_deferred()
	is_open = true
	_open_for = 0.0
	_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	opened.emit(_offer)


func _add_button(text: String, index: int) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(520.0, 56.0)
	button.add_theme_color_override(&"font_color", TEXT)
	button.add_theme_color_override(&"font_hover_color", HONOR)
	button.add_theme_color_override(&"font_focus_color", HONOR)
	button.add_theme_font_size_override(&"font_size", 17)
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
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
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
	title.text = UiText.BOON_TITLE
	title.add_theme_color_override(&"font_color", HONOR)
	title.add_theme_font_size_override(&"font_size", 26)
	box.add_child(title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 6)
	box.add_child(_list)
	var hint := Label.new()
	hint.text = UiText.INVEST_HINT
	hint.add_theme_color_override(&"font_color", TEXT)
	hint.add_theme_font_size_override(&"font_size", 13)
	box.add_child(hint)
