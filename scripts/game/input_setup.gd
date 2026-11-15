class_name GameInputSetup
extends RefCounted
## Registers playable arena InputMap actions idempotently for Keyboard, Mouse, and Gamepad / Controller.


static func ensure_default_actions() -> void:
	# Movement (WASD / Arrows + Left Analog Stick + D-pad)
	_bind_key("move_forward", KEY_W)
	_bind_key("move_forward", KEY_UP)
	_bind_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_bind_joy_button("move_forward", JOY_BUTTON_DPAD_UP)

	_bind_key("move_back", KEY_S)
	_bind_key("move_back", KEY_DOWN)
	_bind_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_bind_joy_button("move_back", JOY_BUTTON_DPAD_DOWN)

	_bind_key("move_left", KEY_A)
	_bind_key("move_left", KEY_LEFT)
	_bind_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_bind_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)

	_bind_key("move_right", KEY_D)
	_bind_key("move_right", KEY_RIGHT)
	_bind_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_bind_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)

	# Camera Look (Right Analog Stick)
	_bind_joy_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_bind_joy_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_bind_joy_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_bind_joy_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)

	# Jump (Space + A / Cross)
	_bind_key("jump", KEY_SPACE)
	_bind_joy_button("jump", JOY_BUTTON_A)

	# Sprint (Shift + Left Stick Click L3)
	_bind_key("sprint", KEY_SHIFT)
	_bind_joy_button("sprint", JOY_BUTTON_LEFT_STICK)

	# Tactical Dash (Q / Ctrl + B / Circle + LB / L1)
	_bind_key("dash", KEY_Q)
	_bind_key("dash", KEY_CTRL)
	_bind_joy_button("dash", JOY_BUTTON_B)
	_bind_joy_button("dash", JOY_BUTTON_LEFT_SHOULDER)

	# Reload / Vent (R + X / Square)
	_bind_key("reload", KEY_R)
	_bind_joy_button("reload", JOY_BUTTON_X)

	# Fire (LMB / F + Right Trigger RT/R2 + RB/R1)
	_bind_mouse_button("fire", MOUSE_BUTTON_LEFT)
	_bind_key("fire", KEY_F)
	_bind_joy_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_bind_joy_button("fire", JOY_BUTTON_RIGHT_SHOULDER)

	# Aim / ADS (RMB + Left Trigger LT/L2)
	_bind_mouse_button("aim", MOUSE_BUTTON_RIGHT)
	_bind_joy_axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0)

	# Weapon Cycle (Mouse Wheel + RB / LB + D-pad Right / Left)
	_bind_mouse_button("weapon_next", MOUSE_BUTTON_WHEEL_UP)
	_bind_joy_button("weapon_next", JOY_BUTTON_RIGHT_SHOULDER)
	_bind_joy_button("weapon_next", JOY_BUTTON_DPAD_RIGHT)

	_bind_mouse_button("weapon_prev", MOUSE_BUTTON_WHEEL_DOWN)
	_bind_joy_button("weapon_prev", JOY_BUTTON_LEFT_SHOULDER)
	_bind_joy_button("weapon_prev", JOY_BUTTON_DPAD_LEFT)

	# View Toggle (V + Y / Triangle + Back/Select)
	_bind_key("toggle_view", KEY_V)
	_bind_joy_button("toggle_view", JOY_BUTTON_Y)
	_bind_joy_button("toggle_view", JOY_BUTTON_BACK)

	# Doom Center View Toggle (H + R3 / Right Stick Click)
	_bind_key("toggle_fps_centered", KEY_H)
	_bind_joy_button("toggle_fps_centered", JOY_BUTTON_RIGHT_STICK)

	# Pause (Esc + Start / Menu)
	_bind_key("pause", KEY_ESCAPE)
	_bind_joy_button("pause", JOY_BUTTON_START)

	# Weapon direct slots 1-7 (Keys 1-7)
	for s in range(1, 8):
		_bind_key("weapon_%d" % s, (KEY_0 + s) as Key)

	# Upgrade picks (1, 2, 3 + Gamepad X, Y, B + D-pad Left, Up, Right)
	_bind_key("upgrade_pick_1", KEY_1)
	_bind_joy_button("upgrade_pick_1", JOY_BUTTON_X)
	_bind_joy_button("upgrade_pick_1", JOY_BUTTON_DPAD_LEFT)

	_bind_key("upgrade_pick_2", KEY_2)
	_bind_joy_button("upgrade_pick_2", JOY_BUTTON_Y)
	_bind_joy_button("upgrade_pick_2", JOY_BUTTON_DPAD_UP)

	_bind_key("upgrade_pick_3", KEY_3)
	_bind_joy_button("upgrade_pick_3", JOY_BUTTON_B)
	_bind_joy_button("upgrade_pick_3", JOY_BUTTON_DPAD_RIGHT)

	# UI Accept / Cancel
	_bind_joy_button("ui_accept", JOY_BUTTON_A)
	_bind_joy_button("ui_cancel", JOY_BUTTON_B)


static func _bind_key(action: String, k: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == k:
			return
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	InputMap.action_add_event(action, ev)


static func _bind_mouse_button(action: String, btn: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == btn:
			return
	var mb := InputEventMouseButton.new()
	mb.button_index = btn
	InputMap.action_add_event(action, mb)


static func _bind_joy_button(action: String, btn: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == btn:
			return
	var jb := InputEventJoypadButton.new()
	jb.button_index = btn
	InputMap.action_add_event(action, jb)


static func _bind_joy_axis(action: String, axis: JoyAxis, val: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion:
			var jm := ev as InputEventJoypadMotion
			if jm.axis == axis and signf(jm.axis_value) == signf(val):
				return
	var jm := InputEventJoypadMotion.new()
	jm.axis = axis
	jm.axis_value = val
	InputMap.action_add_event(action, jm)
