extends SceneTree
## Writes the game's input map (P2-01 step 10) into project.godot. This table
## is the single source for game actions: actions not listed here are removed
## (Godot's built-in ui_* actions are left alone). Mouse orbit and click-to-
## recapture read mouse events directly in CameraRig, so they have no action.
## Gamepad A is bound only to what the spec reserved it for, Welcome the
## Agony and Catalyze; paused menus also confirm with it through Godot's
## built-in ui_accept (P2-05 handoff).
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tools/setup_input_map.gd


func _init() -> void:
	var actions := {
		"move_forward": [_key(KEY_W), _stick(JOY_AXIS_LEFT_Y, -1.0)],
		"move_back": [_key(KEY_S), _stick(JOY_AXIS_LEFT_Y, 1.0)],
		"move_left": [_key(KEY_A), _stick(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [_key(KEY_D), _stick(JOY_AXIS_LEFT_X, 1.0)],
		"cam_orbit_left": [_stick(JOY_AXIS_RIGHT_X, -1.0)],
		"cam_orbit_right": [_stick(JOY_AXIS_RIGHT_X, 1.0)],
		"cam_orbit_up": [_stick(JOY_AXIS_RIGHT_Y, -1.0)],
		"cam_orbit_down": [_stick(JOY_AXIS_RIGHT_Y, 1.0)],
		"cam_zoom_in": [_pad(JOY_BUTTON_RIGHT_SHOULDER)],
		"cam_zoom_out": [_pad(JOY_BUTTON_LEFT_SHOULDER)],
		"cam_zoom_in_step": [_mouse(MOUSE_BUTTON_WHEEL_UP)],
		"cam_zoom_out_step": [_mouse(MOUSE_BUTTON_WHEEL_DOWN)],
		"shoulder": [_key(KEY_SPACE), _pad(JOY_BUTTON_B)],
		"surge_1": [_mouse(MOUSE_BUTTON_LEFT), _stick(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"surge_2": [_mouse(MOUSE_BUTTON_RIGHT), _stick(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		"surge_3": [_key(KEY_Q), _pad(JOY_BUTTON_Y)],
		"draw": [_key(KEY_E), _pad(JOY_BUTTON_X)],
		"mouse_release": [_key(KEY_ESCAPE)],
		"invest": [_key(KEY_TAB), _pad(JOY_BUTTON_BACK)],
		"pick_1": [_key(KEY_1)],
		"pick_2": [_key(KEY_2)],
		"pick_3": [_key(KEY_3)],
		"welcome": [_key(KEY_1), _pad(JOY_BUTTON_A)],
		"bank": [_key(KEY_2), _pad(JOY_BUTTON_B)],
		"catalyze_commit": [_pad(JOY_BUTTON_A)],
		"catalyze_release": [_key(KEY_R), _pad(JOY_BUTTON_Y)],
		"debug_overlay": [_key(KEY_F3)],
		"debug_inspect_light": [_key(KEY_F4)],
		"debug_blast": [_key(KEY_1, true)],
		"debug_stress": [_key(KEY_2, true)],
		"debug_pause_spawner": [_key(KEY_3, true)],
		"debug_grant_investiture": [_key(KEY_4, true)],
		"debug_honorblade": [_key(KEY_5, true)],
		"debug_add_strain": [_key(KEY_6, true)],
		"debug_reset_strain": [_key(KEY_7, true)],
	}

	for property: Dictionary in ProjectSettings.get_property_list():
		var setting: String = property.name
		if setting.begins_with("input/") and not setting.begins_with("input/ui_") \
				and not actions.has(setting.trim_prefix("input/")):
			print("removing stale action ", setting)
			ProjectSettings.set_setting(setting, null)
	for action: String in actions:
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": actions[action]})
	print("save settings: ", ProjectSettings.save())
	quit()


func _key(code: Key, ctrl: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.device = -1
	event.physical_keycode = code
	event.ctrl_pressed = ctrl
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.device = -1
	event.button_index = button
	return event


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	return event


func _stick(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = value
	return event
