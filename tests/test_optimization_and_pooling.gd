extends SceneTree

const PlayableArenaScene := preload("res://scenes/game/playable_arena.tscn")
const WeaponVFXRef := preload("res://scripts/game/weapon_vfx.gd")
const DestructionVFXRef := preload("res://scripts/game/droid_destruction_vfx.gd")
const HUDWeaponBarRef := preload("res://scripts/game/hud_weapon_bar.gd")
const SettingsManagerRef := preload("res://scripts/game/settings_manager.gd")
const BalanceDBScript := preload("res://scripts/game/balance_db.gd")
const WeaponLoadoutScript := preload("res://scripts/game/weapon_loadout.gd")


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var ok := true
	ok = ok and await _test_weapon_pool_and_o1_swap()
	ok = ok and await _test_hud_weapon_bar_style_reuse()
	ok = ok and await _test_vfx_shared_resources_and_warmup()
	ok = ok and await _test_graphics_quality_settings()
	if not ok:
		push_error("test_optimization_and_pooling FAILED")
		quit(1)
		return
	print("ALL_TESTS_PASSED: test_optimization_and_pooling")
	quit(0)


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("ASSERTION FAILED: " + msg)
		return false
	return true


func _test_weapon_pool_and_o1_swap() -> bool:
	var arena := PlayableArenaScene.instantiate()
	arena.set_interactive_mouse_capture(false)
	root.add_child(arena)
	await process_frame
	await process_frame

	var ok := true
	var player := get_first_node_in_group("player")
	var gm := arena.get_node("GameManager")
	var wm := player.get_node("WeaponManager")
	var rig := player.get_node("CameraPivot")
	var vm = rig.get_fps_viewmodel()

	ok = ok and _check(wm.has_method("get_pooled_weapon_count") and wm.get_pooled_weapon_count() >= 7, "WeaponManager pre-instantiates >= 7 pooled TPS weapons")
	ok = ok and _check(vm != null and vm.has_method("get_pooled_weapon_count") and vm.get_pooled_weapon_count() >= 7, "FPSViewmodel pre-instantiates >= 7 pooled FPS weapons")

	var nodes_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for slot in [2, 3, 4, 5, 6, 7, 1]:
		if gm.loadout.select_slot(slot):
			wm.refresh_equipped_mesh()
	if player.has_method("toggle_view_mode"):
		player.toggle_view_mode()
		await process_frame
		for slot in [2, 3, 4, 5, 6, 7, 1]:
			if gm.loadout.select_slot(slot):
				wm.refresh_equipped_mesh()
		player.toggle_view_mode()
	var nodes_after: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	ok = ok and _check(nodes_after <= nodes_before + 4, "O(1) weapon swaps must not allocate/destroy weapon nodes (before=%d after=%d)" % [nodes_before, nodes_after])

	# Verify FPS_Arms animations were sanitized (no zero-scale tracks)
	if vm != null and vm.get("_anim_player") != null:
		var ap := vm.get("_anim_player") as AnimationPlayer
		var has_zero_scale := false
		for anim_name in ap.get_animation_list():
			var anim := ap.get_animation(anim_name)
			for t in range(anim.get_track_count()):
				if anim.track_get_type(t) == Animation.TYPE_SCALE_3D:
					for k in range(anim.track_get_key_count(t)):
						var v: Vector3 = anim.track_get_key_value(t, k)
						if absf(v.x) < 0.001 or absf(v.y) < 0.001 or absf(v.z) < 0.001:
							has_zero_scale = true
		ok = ok and _check(not has_zero_scale, "FPS_Arms animations have zero degenerate scale tracks")

	arena.queue_free()
	await process_frame
	return ok


func _test_hud_weapon_bar_style_reuse() -> bool:
	var db := BalanceDBScript.new()
	db.load_from_file("res://data/game_balance.json")
	var loadout := WeaponLoadoutScript.new(db, null)
	var bar := HUDWeaponBarRef.new()
	root.add_child(bar)
	bar.build()
	await process_frame

	bar.refresh(loadout)
	var p0 := bar._slot_panels[0]
	var sb_first := p0.get_theme_stylebox("panel")
	bar.refresh(loadout)
	var sb_second := p0.get_theme_stylebox("panel")

	var ok := true
	ok = ok and _check(sb_first != null and sb_first == sb_second, "HUDWeaponBar reuses cached StyleBoxFlat instances across identical refreshes")

	bar.queue_free()
	await process_frame
	return ok


func _test_vfx_shared_resources_and_warmup() -> bool:
	var host := Node3D.new()
	root.add_child(host)
	WeaponVFXRef.warmup(host)
	DestructionVFXRef.warmup(host)
	await process_frame

	var ok := true
	ok = ok and _check(WeaponVFXRef.has_shared_cache(), "WeaponVFX maintains shared Mesh/Material cache after warmup")
	ok = ok and _check(DestructionVFXRef.has_shared_cache(), "DroidDestructionVFX maintains shared Mesh/Shape/Material cache after warmup")

	host.queue_free()
	await process_frame
	return ok


func _test_graphics_quality_settings() -> bool:
	var tmp := "user://test_opt_settings.cfg"
	SettingsManagerRef.set_config_path_for_test(tmp)
	SettingsManagerRef.reset_to_defaults(true)

	var ok := true
	ok = ok and _check(int(SettingsManagerRef.get_val("graphics_quality")) == 2, "Default graphics_quality is 2 (Alto)")

	var arena := PlayableArenaScene.instantiate()
	arena.set_interactive_mouse_capture(false)
	root.add_child(arena)
	await process_frame

	SettingsManagerRef.set_val("graphics_quality", 0, true)
	SettingsManagerRef.apply_all(self)
	var we := arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var dl := arena.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	ok = ok and _check(we != null and not we.environment.ssr_enabled, "graphics_quality=0 disables SSR")
	ok = ok and _check(dl != null and not dl.shadow_enabled, "graphics_quality=0 disables directional shadows")

	SettingsManagerRef.set_val("graphics_quality", 2, true)
	SettingsManagerRef.apply_all(self)
	ok = ok and _check(we != null and we.environment.ssr_enabled, "graphics_quality=2 re-enables SSR")
	ok = ok and _check(dl != null and dl.shadow_enabled, "graphics_quality=2 re-enables directional shadows")

	arena.queue_free()
	await process_frame
	SettingsManagerRef.set_config_path_for_test("")
	return ok
