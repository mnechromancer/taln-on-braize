class_name StartScreen
extends CanvasLayer
## The launch pick (P2-12): when the slice is the session's first scene, its
## cycle waits here for an Aspect. One row per Aspect in the cycle tuning; the
## last-chosen one has focus. Picking one begins the cycle as it (the slice
## reloads if Taln needs a different kit). Later cycles skip this screen; the
## between-run screen still changes the Aspect. Same placeholder dark panel
## as the between-run screen.

signal picked(aspect: AspectDef)

const PANEL := Color("0b0b0e", 0.92)
const TEXT := Color("a69e8f")
const DIM := Color("5a564f")
const HONOR := Color("cfe8ff")

@export var slice: BraizeSlice

var is_open: bool = false
var _rows: Array[Button] = []
var _panel: PanelContainer


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false
	# The slice decides whether to wait in its own _ready, after this one.
	_open_if_waiting.call_deferred()


## Begins the cycle as the Aspect at index.
func pick(index: int) -> void:
	if not is_open:
		return
	var aspect: AspectDef = Cycle.director().tuning.aspects[index]
	is_open = false
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	picked.emit(aspect)
	slice.begin_as(aspect)


## Row labels, in order (for checks).
func option_texts() -> Array[String]:
	var texts: Array[String] = []
	for row in _rows:
		texts.append(row.text)
	return texts


func _open_if_waiting() -> void:
	if not slice.waiting_for_start:
		return
	is_open = true
	_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var chosen: int = Cycle.director().tuning.aspects.find(Cycle.director().aspect())
	_rows[maxi(chosen, 0)].grab_focus.call_deferred()


func _build() -> void:
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
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	_panel.add_child(box)
	var title := Label.new()
	title.text = UiText.START_TITLE
	title.add_theme_color_override(&"font_color", HONOR)
	title.add_theme_font_size_override(&"font_size", 30)
	box.add_child(title)
	var aspects: Array[AspectDef] = Cycle.director().tuning.aspects
	for i in aspects.size():
		var button := Button.new()
		button.text = UiText.ASPECT_OPTION % aspects[i].display_name
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(360.0, 42.0)
		button.add_theme_color_override(&"font_color", TEXT)
		button.add_theme_color_override(&"font_hover_color", HONOR)
		button.add_theme_color_override(&"font_focus_color", HONOR)
		button.add_theme_font_size_override(&"font_size", 20)
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
		button.pressed.connect(pick.bind(i))
		box.add_child(button)
		_rows.append(button)
