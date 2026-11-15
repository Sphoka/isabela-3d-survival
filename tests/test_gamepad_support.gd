extends SceneTree

const BalanceDBScript := preload("res://scripts/game/balance_db.gd")
const InputSetupScript := preload("res://scripts/game/input_setup.gd")
const PlayerCameraRigScript := preload("res://scripts/game/player_camera_rig.gd")
const UpgradeModalScript := preload("res://scripts/game/upgrade_modal_ui.gd")

func _init() -> void:
	call_deferred("_run_all")


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("GAMEPAD ASSERTION FAILED: " + msg)
		return false
	return true


func _run_all() -> void:
	var ok := true
	ok = ok and _test_input_map_gamepad_bindings()
	ok = ok and _test_camera_controller_look()
	ok = ok and await _test_upgrade_modal_gamepad_navigation()
	if not ok:
		push_error("test_gamepad_support FAILED")
		quit(1)
		return
	print("ALL_TESTS_PASSED: test_gamepad_support")
	quit(0)


func _test_input_map_gamepad_bindings() -> bool:
	InputSetupScript.ensure_default_actions()

	# Check movement left stick and D-pad
	var required_axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0],
		"move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
		"move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"look_left": [JOY_AXIS_RIGHT_X, -1.0],
		"look_right": [JOY_AXIS_RIGHT_X, 1.0],
		"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
		"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
		"fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
		"aim": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	}
	for act in required_axes:
		if not _check(InputMap.has_action(act), "InputMap must have action: " + act):
			return false
		var found_axis := false
		for ev in InputMap.action_get_events(act):
			if ev is InputEventJoypadMotion:
				var jm := ev as InputEventJoypadMotion
				if jm.axis == required_axes[act][0] and signf(jm.axis_value) == signf(required_axes[act][1]):
					found_axis = true
					break
		if not _check(found_axis, "Action " + act + " must have JoypadMotion axis " + str(required_axes[act][0])):
			return false

	# Check buttons
	var required_buttons := {
		"jump": JOY_BUTTON_A,
		"dash": JOY_BUTTON_B,
		"reload": JOY_BUTTON_X,
		"toggle_view": JOY_BUTTON_Y,
		"sprint": JOY_BUTTON_LEFT_STICK,
		"toggle_fps_centered": JOY_BUTTON_RIGHT_STICK,
		"weapon_next": JOY_BUTTON_RIGHT_SHOULDER,
		"weapon_prev": JOY_BUTTON_LEFT_SHOULDER,
		"pause": JOY_BUTTON_START,
		"upgrade_pick_1": JOY_BUTTON_X,
		"upgrade_pick_2": JOY_BUTTON_Y,
		"upgrade_pick_3": JOY_BUTTON_B,
	}
	for act in required_buttons:
		if not _check(InputMap.has_action(act), "InputMap must have action: " + act):
			return false
		var found_btn := false
		for ev in InputMap.action_get_events(act):
			if ev is InputEventJoypadButton:
				var jb := ev as InputEventJoypadButton
				if jb.button_index == required_buttons[act]:
					found_btn = true
					break
		if not _check(found_btn, "Action " + act + " must have JoypadButton " + str(required_buttons[act])):
			return false

	return true


func _test_camera_controller_look() -> bool:
	var rig = PlayerCameraRigScript.new()
	rig.configure({
		"controller_sensitivity": 3.4,
		"controller_aim_sensitivity_multiplier": 0.65,
		"pitch_min_deg": -58.0,
		"pitch_max_deg": 50.0
	})
	var initial_yaw: float = rig.yaw
	var initial_pitch: float = rig.pitch

	# Verify rig has method or logic to apply look from stick
	if not _check(rig.has_method("apply_controller_look"), "PlayerCameraRig must have apply_controller_look(look_vec, delta, is_aiming)"):
		rig.free()
		return false

	# Tilt stick right (look.x = 1.0, look.y = 0.0) -> yaw should decrease
	rig.apply_controller_look(Vector2(1.0, 0.0), 0.1, false)
	if not _check(rig.yaw < initial_yaw, "Right stick tilt right must turn camera yaw right (yaw decreases)"):
		rig.free()
		return false

	# Tilt stick down (look.x = 0.0, look.y = 1.0) -> pitch should decrease (pitch down)
	rig.apply_controller_look(Vector2(0.0, 1.0), 0.1, false)
	if not _check(rig.pitch < initial_pitch, "Right stick tilt down must pitch camera down"):
		rig.free()
		return false

	rig.free()
	return true


func _test_upgrade_modal_gamepad_navigation() -> bool:
	var modal = UpgradeModalScript.new()
	root.add_child(modal)
	await process_frame
	modal.show_choices([
		{"id": "c1", "title": "Upgrade 1", "rarity_label": "Comum", "color_hex": "#ffffff"},
		{"id": "c2", "title": "Upgrade 2", "rarity_label": "Raro", "color_hex": "#38bdf8"},
		{"id": "c3", "title": "Upgrade 3", "rarity_label": "Épico", "color_hex": "#c084fc"}
	])
	if not _check(modal.get_card_count() == 3, "Modal must display 3 cards"):
		modal.queue_free()
		return false

	var selected_idx := [-1]
	modal.card_selected.connect(func(idx: int): selected_idx[0] = idx)

	# Trigger upgrade_pick_1 via controller X button
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_X
	ev.pressed = true
	modal._unhandled_input(ev)
	if not _check(selected_idx[0] == 0, "Gamepad X button (upgrade_pick_1) must select card 0"):
		modal.queue_free()
		return false

	# Trigger upgrade_pick_2 via controller Y button
	var ev2 := InputEventJoypadButton.new()
	ev2.button_index = JOY_BUTTON_Y
	ev2.pressed = true
	modal._unhandled_input(ev2)
	if not _check(selected_idx[0] == 1, "Gamepad Y button (upgrade_pick_2) must select card 1"):
		modal.queue_free()
		return false

	# Trigger upgrade_pick_3 via controller B button
	var ev3 := InputEventJoypadButton.new()
	ev3.button_index = JOY_BUTTON_B
	ev3.pressed = true
	modal._unhandled_input(ev3)
	if not _check(selected_idx[0] == 2, "Gamepad B button (upgrade_pick_3) must select card 2"):
		modal.queue_free()
		return false

	modal.queue_free()
	return true
