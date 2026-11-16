extends SceneTree

const SettingsManagerRef := preload("res://scripts/game/settings_manager.gd")
const SettingsModalRef := preload("res://scripts/game/settings_modal_ui.gd")
const MainMenuScene := preload("res://scenes/game/main_menu.tscn")
const GameManagerRef := preload("res://scripts/game/game_manager.gd")
const GameOverModalRef := preload("res://scripts/game/game_over_modal_ui.gd")
const PauseModalRef := preload("res://scripts/game/pause_modal_ui.gd")
const UpgradeModalRef := preload("res://scripts/game/upgrade_modal_ui.gd")
const FPSViewmodelRef := preload("res://scripts/game/fps_viewmodel.gd")
const ArenaScene := preload("res://scenes/game/playable_arena.tscn")

var _failed: int = 0


func _init() -> void:
	var ok := true
	ok = ok and _test_settings_manager_persistence()
	ok = ok and await _test_main_menu_and_modals()
	ok = ok and await _test_run_summary_and_game_over_ui()
	ok = ok and await _test_upgrade_confirm_only_and_fps_laser_anims()
	ok = ok and await _test_hud_pause_and_game_over_integration()
	if ok and _failed == 0:
		print("ALL_TESTS_PASSED: test_menus_and_settings")
		quit(0)
	else:
		printerr("TESTS_FAILED: test_menus_and_settings count=%d" % _failed)
		quit(1)


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		_failed += 1
		printerr("FAIL: %s" % msg)
	return cond


func _test_settings_manager_persistence() -> bool:
	var ok := true
	var test_path := "user://test_settings_menus.cfg"
	SettingsManagerRef.set_config_path_for_test(test_path)
	SettingsManagerRef.reset_to_defaults(true)

	SettingsManagerRef.set_val("master_volume", 0.45, false)
	SettingsManagerRef.set_val("music_volume", 0.30, false)
	SettingsManagerRef.set_val("fov", 82.0, false)
	SettingsManagerRef.set_val("mouse_sensitivity", 0.0044, false)
	SettingsManagerRef.set_val("default_fps_mode", true, true)

	# Force reload from disk
	SettingsManagerRef.set_config_path_for_test(test_path)
	SettingsManagerRef.ensure_loaded()
	ok = ok and _check(is_equal_approx(float(SettingsManagerRef.get_val("master_volume")), 0.45), "master_volume persisted")
	ok = ok and _check(is_equal_approx(float(SettingsManagerRef.get_val("music_volume")), 0.30), "music_volume persisted")
	ok = ok and _check(is_equal_approx(float(SettingsManagerRef.get_val("fov")), 82.0), "fov persisted")
	ok = ok and _check(is_equal_approx(float(SettingsManagerRef.get_val("mouse_sensitivity")), 0.0044), "mouse_sensitivity persisted")
	ok = ok and _check(bool(SettingsManagerRef.get_val("default_fps_mode")) == true, "default_fps_mode persisted")

	SettingsManagerRef.apply_audio(self)
	var master_idx := AudioServer.get_bus_index("Master")
	ok = ok and _check(master_idx >= 0 and not AudioServer.is_bus_mute(master_idx), "Master audio bus unmuted at 0.45")

	SettingsManagerRef.set_val("master_volume", 0.0, false)
	SettingsManagerRef.apply_audio(self)
	ok = ok and _check(AudioServer.is_bus_mute(master_idx), "Master audio bus muted at 0.0")

	SettingsManagerRef.reset_to_defaults(true)
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	SettingsManagerRef.set_config_path_for_test("")
	return ok


func _test_main_menu_and_modals() -> bool:
	var ok := true
	var menu := MainMenuScene.instantiate()
	root.add_child(menu)
	await process_frame

	ok = ok and _check(menu.get_node_or_null("DuneBackdrop") != null, "MainMenu builds DuneBackdrop")
	var btns: Array = menu.call("get_menu_buttons")
	ok = ok and _check(btns.size() == 4, "MainMenu has 4 action buttons")
	ok = ok and _check(not bool(menu.call("is_settings_open")), "Settings modal starts closed")
	ok = ok and _check(not bool(menu.call("is_howto_open")), "How-To modal starts closed")

	# Open settings via button
	(btns[1] as Button).pressed.emit()
	await process_frame
	ok = ok and _check(bool(menu.call("is_settings_open")), "Clicking Settings opens SettingsModalUI")

	var smodal := menu.get_node_or_null("SettingsModal") as SettingsModalRef
	ok = ok and _check(smodal != null, "SettingsModal node exists")
	if smodal != null:
		var spanel := smodal.find_children("*", "PanelContainer", true, false)
		var scenter := smodal.find_children("*", "CenterContainer", true, false)
		ok = ok and _check(is_equal_approx(smodal.anchor_right, 1.0) and is_equal_approx(smodal.anchor_bottom, 1.0) and is_equal_approx(smodal.offset_right, 0.0), "SettingsModal fills full viewport rect")
		ok = ok and _check(not scenter.is_empty() and not spanel.is_empty() and (spanel[0] as Node).get_parent() == scenter[0], "SettingsModal panel is centered inside CenterContainer")
		smodal.switch_tab(1)
		smodal.close()
		await process_frame
		ok = ok and _check(not bool(menu.call("is_settings_open")), "Closing Settings hides modal")

	# Open How-to
	(btns[2] as Button).pressed.emit()
	await process_frame
	ok = ok and _check(bool(menu.call("is_howto_open")), "Clicking How-To opens overlay")

	menu.queue_free()
	await process_frame
	return ok


func _test_run_summary_and_game_over_ui() -> bool:
	var ok := true
	var gm := GameManagerRef.new()
	gm.initialize("res://data/game_balance.json", 42)
	gm.start_run(false)
	gm.tick(12.5)
	gm.record_damage("katana", 150.0)
	gm.record_damage("smg", 85.0)
	gm.notify_enemy_killed("droid_small", 18, 100)
	gm.notify_enemy_killed("droid_tall", 55, 250)

	var sum: Dictionary = gm.get_run_summary()
	ok = ok and _check(int(sum["kills"]) == 2, "Summary total kills == 2")
	ok = ok and _check(int(sum["kills_small"]) == 1, "Summary kills_small == 1")
	ok = ok and _check(int(sum["kills_tall"]) == 1, "Summary kills_tall == 1")
	ok = ok and _check(is_equal_approx(float(sum["total_damage"]), 235.0), "Summary total_damage == 235.0")
	ok = ok and _check(str(sum["favorite_weapon"]) == "katana", "Summary favorite_weapon == katana")

	var go := GameOverModalRef.new()
	root.add_child(go)
	go.show_summary(sum)
	await process_frame
	ok = ok and _check(go.visible, "GameOverModalUI visible after show_summary")
	ok = ok and _check(go.get_restart_button() != null and go.get_menu_button() != null, "GameOverModalUI exposes Restart and Menu buttons")
	var found_death_title := false
	for lbl in go.find_children("*", "Label", true, false):
		if (lbl as Label).text == "VOCÊ MORREU":
			found_death_title = true
			break
	ok = ok and _check(found_death_title, "GameOverModalUI displays VOCÊ MORREU title")

	go.queue_free()
	await process_frame
	return ok


func _test_hud_pause_and_game_over_integration() -> bool:
	var ok := true
	var arena := ArenaScene.instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame

	var gm := arena.get("game_manager") as GameManagerRef
	var hud: Variant = arena.get("hud")
	ok = ok and _check(gm != null and hud != null, "PlayableArena provides GameManager and HUD")
	if gm != null and hud != null:
		gm.toggle_pause()
		await process_frame
		ok = ok and _check(bool(hud.call("is_pause_modal_visible")), "Pausing shows PauseModalUI")
		ok = ok and _check(not bool(hud.call("is_game_over_modal_visible")), "Pausing hides GameOverModalUI")

		gm.toggle_pause()
		await process_frame
		ok = ok and _check(not bool(hud.call("is_pause_modal_visible")), "Unpausing hides PauseModalUI")

		gm.trigger_game_over()
		await process_frame
		ok = ok and _check(bool(hud.call("is_game_over_modal_visible")), "Game Over shows GameOverModalUI")
		ok = ok and _check(not bool(hud.call("is_pause_modal_visible")), "Game Over hides PauseModalUI")

	paused = false
	arena.queue_free()
	await process_frame
	return ok


func _test_upgrade_confirm_only_and_fps_laser_anims() -> bool:
	var ok := true
	var modal := UpgradeModalRef.new()
	root.add_child(modal)
	await process_frame
	modal.show_choices([
		{"id": "u1", "title": "Up 1", "rarity_label": "Comum", "color_hex": "#ffffff"},
		{"id": "u2", "title": "Up 2", "rarity_label": "Raro", "color_hex": "#38bdf8"},
		{"id": "u3", "title": "Up 3", "rarity_label": "Épico", "color_hex": "#c084fc"}
	])
	var picked := [-1]
	modal.card_selected.connect(func(idx: int) -> void: picked[0] = idx)
	var card_btns: Array = modal.get("_buttons")
	var confirm_btns: Array = modal.get("_confirm_buttons")
	ok = ok and _check(card_btns.size() == 3 and confirm_btns.size() == 3, "UpgradeModalUI created 3 card entries")
	if card_btns.size() == 3 and confirm_btns.size() == 3:
		(card_btns[1] as Button).pressed.emit()
		await process_frame
		ok = ok and _check(picked[0] == -1, "Clicking card body does not confirm upgrade")
		ok = ok and _check(int(modal.get("_selected_idx")) == 1, "Clicking card body focuses card 1")
		(confirm_btns[1] as Button).pressed.emit()
		await process_frame
		ok = ok and _check(picked[0] == 1, "Clicking CONFIRMAR button confirms upgrade 1")
	modal.queue_free()

	var vm := FPSViewmodelRef.new()
	root.add_child(vm)
	vm.set_active(true)
	vm.trigger_reload(1.2)
	ok = ok and _check(float(vm.get("_reload_left")) > 0.0, "FPSViewmodel trigger_reload sets reload timer")
	vm.trigger_laser_overheat(1.8)
	ok = ok and _check(bool(vm.get("_overheat_active")), "FPSViewmodel trigger_laser_overheat activates overheat anim")
	vm.update_viewmodel(0.05, 0.0, 7.0, true, false, false)
	vm.trigger_laser_ready()
	ok = ok and _check(not bool(vm.get("_overheat_active")) and float(vm.get("_cool_ready_left")) > 0.0, "FPSViewmodel trigger_laser_ready triggers cooldown-ready anim")
	vm.queue_free()
	await process_frame
	return ok
