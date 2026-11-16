extends SceneTree

const BalanceDBScript := preload("res://scripts/game/balance_db.gd")
const InputSetupScript := preload("res://scripts/game/input_setup.gd")
const UpgradeSystemScript := preload("res://scripts/game/upgrade_system.gd")
const WeaponLoadoutScript := preload("res://scripts/game/weapon_loadout.gd")
const PlayerScene := preload("res://scenes/game/player_isabela.tscn")
const HUDControllerScript := preload("res://scripts/game/hud_controller.gd")
const GameManagerScript := preload("res://scripts/game/game_manager.gd")


func _init() -> void:
	call_deferred("_run_all")


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("V2 ASSERTION FAILED: " + msg)
		return false
	return true


func _run_all() -> void:
	var ok := true
	ok = ok and _test_balance_camera_v2()
	ok = ok and _test_input_toggle_view()
	ok = ok and await _test_player_tps_fps_toggle()
	ok = ok and await _test_fps_shooting_and_melee_vfx()
	ok = ok and _test_hud_view_indicator()
	ok = ok and await _test_retargeted_anims_and_combat()
	ok = ok and await _test_fps_optic_transparency_and_sniper_reticle()
	if not ok:
		push_error("test_v2_camera_anims_fps FAILED")
		quit(1)
		return
	print("ALL_TESTS_PASSED: test_v2_camera_anims_fps")
	quit(0)


func _test_balance_camera_v2() -> bool:
	var db = BalanceDBScript.new()
	if not _check(db.load_from_file("res://data/game_balance.json"), "Load game_balance.json"):
		return false
	var cam: Dictionary = db.get_player_cfg().get("camera", {})
	if not _check(float(cam.get("pivot_height_m", 9.0)) <= 1.35, "TPS pivot_height_m must be <= 1.35m (closer/lower)"):
		return false
	if not _check(float(cam.get("spring_length_normal_m", 9.0)) <= 1.90, "TPS spring_length_normal_m must be <= 1.90m"):
		return false
	if not _check(float(cam.get("spring_length_aim_m", 9.0)) <= 1.25, "TPS spring_length_aim_m must be <= 1.25m"):
		return false
	if not _check(float(cam.get("fov_normal_deg", 0.0)) >= 64.0 and float(cam.get("fov_normal_deg", 0.0)) <= 70.0, "TPS fov_normal_deg should be ~66"):
		return false
	if not _check(float(cam.get("fps_eye_height_m", 0.0)) >= 1.50 and float(cam.get("fps_fov_normal_deg", 0.0)) >= 80.0, "FPS camera config (fps_eye_height_m, fps_fov_normal_deg) required"):
		return false
	var off: Array = cam.get("shoulder_offset_m", [1.0, 1.0, 0.0])
	if not _check(float(off[0]) <= 0.45 and float(off[1]) <= 0.12, "Tighter shoulder offset required"):
		return false
	return true


func _test_input_toggle_view() -> bool:
	InputSetupScript.ensure_default_actions()
	if not _check(InputMap.has_action("toggle_view"), "InputMap must register toggle_view ([V])"):
		return false
	if not _check(InputMap.has_action("toggle_fps_centered"), "InputMap must register toggle_fps_centered ([H])"):
		return false
	return true


func _test_player_tps_fps_toggle() -> bool:
	var db = BalanceDBScript.new()
	db.load_from_file("res://data/game_balance.json")
	var upg = UpgradeSystemScript.new(db)
	var lo = WeaponLoadoutScript.new(db, upg)

	var p := PlayerScene.instantiate()
	root.add_child(p)
	p.configure(db, upg, lo)
	await physics_frame

	var rig = p.get_node_or_null("CameraPivot")
	var spring = p.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
	var cam = p.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if not _check(rig != null and spring != null and cam != null, "Player must have CameraPivot/SpringArm3D/Camera3D"):
		p.queue_free()
		return false
	if not _check(p.has_method("toggle_view_mode") and p.has_method("is_fps_mode"), "PlayerController must expose toggle_view_mode() and is_fps_mode()"):
		p.queue_free()
		return false
	if not _check(not p.is_fps_mode(), "Player starts in TPS mode"):
		p.queue_free()
		return false
	if not _check(rig.position.y <= 1.35 and spring.spring_length <= 1.90, "Initial TPS rig pivot/spring must be closer & lower"):
		p.queue_free()
		return false

	# Toggle to FPS
	p.toggle_view_mode()
	for _i in range(4):
		p.get_node("CameraPivot").update_rig(0.05, false, false)
	if not _check(p.is_fps_mode(), "toggle_view_mode() must enter FPS mode"):
		p.queue_free()
		return false
	if not _check(is_equal_approx(spring.spring_length, 0.0) and spring.position.is_equal_approx(Vector3.ZERO), "FPS mode requires spring_length=0 and zero shoulder offset"):
		p.queue_free()
		return false
	if not _check(rig.position.y >= 1.50 and cam.fov >= 80.0, "FPS mode requires eye-level pivot and ~86 deg FOV"):
		p.queue_free()
		return false

	# Check SK_Isabela meshes cast SHADOWS_ONLY in FPS mode
	var body_mesh := p.get_node_or_null("VisualRoot/SK_Isabela/Armature_Isabela/Skeleton3D/SK_Isabela_Body") as MeshInstance3D
	if not _check(body_mesh != null and body_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "SK_Isabela meshes must be SHADOWS_ONLY in FPS mode"):
		p.queue_free()
		return false

	# Check FPSViewmodel mounted under Camera3D with active weapon & muzzle
	if not _check(ResourceLoader.exists("res://scripts/game/fps_viewmodel.gd"), "scripts/game/fps_viewmodel.gd must exist"):
		p.queue_free()
		return false
	var vm = cam.get_node_or_null("FPSViewmodel")
	if not _check(vm != null and vm.visible and vm.has_method("get_muzzle_world_position"), "FPSViewmodel must be visible child of Camera3D in FPS mode"):
		p.queue_free()
		return false

	# Toggle back to TPS -> restores SHADOW_CASTING_SETTING_ON and hides FPSViewmodel
	p.toggle_view_mode()
	if not _check(not p.is_fps_mode() and not vm.visible, "Second toggle must return to TPS and hide FPSViewmodel"):
		p.queue_free()
		return false
	if not _check(body_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "TPS mode must restore SHADOW_CASTING_SETTING_ON"):
		p.queue_free()
		return false

	p.queue_free()
	return true


func _test_fps_shooting_and_melee_vfx() -> bool:
	var arena := (load("res://scenes/game/playable_arena.tscn") as PackedScene).instantiate()
	arena.call("set_interactive_mouse_capture", false)
	root.add_child(arena)
	current_scene = arena
	await physics_frame

	var gm = arena.get("game_manager")
	var p = arena.get("player")
	var wm = p.get_node("WeaponManager")
	var rig = p.get_node("CameraPivot")
	var vm = rig.get_fps_viewmodel()

	p.toggle_view_mode()
	rig.update_rig(0.05, false, false)
	var vm_muzzle: Vector3 = vm.get_muzzle_world_position(gm.loadout.get_selected_def())
	var wm_muzzle: Vector3 = wm._get_muzzle_world_position({})
	if not _check(vm_muzzle.distance_to(wm_muzzle) < 0.02, "In FPS mode, WeaponManager muzzle must match FPSViewmodel muzzle"):
		arena.queue_free()
		return false

	# Doom centered toggle [H]
	var before_centered: bool = vm.doom_centered
	p.toggle_fps_centered()
	if not _check(vm.doom_centered != before_centered, "toggle_fps_centered() must flip doom_centered"):
		arena.queue_free()
		return false

	# Test FPS melee blade trail + combo step progression
	gm.loadout.select_slot(2)
	wm.refresh_equipped_mesh()
	var s1: Dictionary = gm.loadout.try_fire(false)
	wm.execute_shot(s1, rig.get_aim_ray(p))
	await physics_frame

	arena.queue_free()
	current_scene = null
	await physics_frame
	return true


func _test_retargeted_anims_and_combat() -> bool:
	if not _check(ResourceLoader.exists("res://assets/SK_Isabela/SK_Isabela_Anims.glb"), "SK_Isabela_Anims.glb must exist"):
		return false
	if not _check(ResourceLoader.exists("res://assets/SK_Isabela/FPS_Arms.glb"), "FPS_Arms.glb must exist"):
		return false

	var db = BalanceDBScript.new()
	db.load_from_file("res://data/game_balance.json")
	var upg = UpgradeSystemScript.new(db)
	var lo = WeaponLoadoutScript.new(db, upg)

	var p := PlayerScene.instantiate()
	root.add_child(p)
	p.configure(db, upg, lo)
	await physics_frame

	var anim = p.get_node_or_null("PlayerAnimator")
	if not _check(anim != null and anim.has_method("has_animation_clip"), "PlayerAnimator must expose has_animation_clip()"):
		p.queue_free()
		return false
	var req_clips := [
		"Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Jump_Start", "Jump", "Jump_Land", "Roll", "Hit_Chest", "Death01",
		"Pistol_Idle", "Pistol_Shoot", "Pistol_Reload", "Rifle_Idle", "Rifle_Shoot", "Rifle_Reload",
		"Rocket_Idle", "Rocket_Shoot", "Rocket_Reload", "Sword_Idle", "Sword_Attack",
		"Katana_Combo_1", "Katana_Combo_2", "Katana_Combo_3", "Saber_Combo_1", "Saber_Combo_2", "Saber_Combo_3",
		"Grip_RightHand", "Grip_LeftHand", "Grip_BothHands",
	]
	for clip in req_clips:
		if not _check(anim.has_animation_clip(clip), "Missing retargeted/combat clip: " + clip):
			p.queue_free()
			return false

	var ap: AnimationPlayer = anim.get("_anim_player")
	for loop_clip in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Pistol_Idle", "Rifle_Idle", "Rocket_Idle", "Sword_Idle"]:
		var a := ap.get_animation(loop_clip)
		if not _check(a != null and a.loop_mode == Animation.LOOP_LINEAR, "Cyclic clip must loop: " + loop_clip):
			p.queue_free()
			return false
	var idle_anim := ap.get_animation("Idle")
	for i in range(idle_anim.get_track_count()):
		var tp := String(idle_anim.track_get_path(i))
		if not _check(not (":Hair_" in tp or ":LeftEye" in tp or ":RightEye" in tp), "Hair/Eye track must be stripped: " + tp):
			p.queue_free()
			return false

	# Drive dynamic locomotion & weapon blend states + Finger GripChoice
	var tree: AnimationTree = anim.get("_anim_tree")
	anim.apply_pose(0.05, Vector3(0, 0, -8.0), true, false, 0.0, 0.0, 1, "shotgun", 0.0, Vector2(0, -1))
	if not _check(str(tree.get("parameters/Loco/current_state")) == "sprint", "Loco must switch to sprint"):
		p.queue_free()
		return false
	if not _check(str(tree.get("parameters/UpperIdle/current_state")) == "rifle", "UpperIdle must switch to rifle for shotgun"):
		p.queue_free()
		return false
	if not _check(str(tree.get("parameters/GripChoice/current_state")) == "both", "GripChoice must switch to both for shotgun"):
		p.queue_free()
		return false

	# FPS_Arms viewmodel clip verification
	var vm = p.get_node("CameraPivot").get_fps_viewmodel()
	var vm_ap: AnimationPlayer = vm.get("_anim_player")
	if not _check(vm_ap != null, "FPSViewmodel must load FPS_Arms.glb AnimationPlayer"):
		p.queue_free()
		return false
	for fps_clip in ["FPS_Idle", "FPS_Walk", "FPS_Fire_Pistol", "FPS_Fire_Heavy", "FPS_Reload", "FPS_Melee_1", "FPS_Melee_2", "FPS_Melee_3", "FPS_Draw"]:
		if not _check(vm_ap.has_animation(fps_clip), "Missing FPS_Arms clip: " + fps_clip):
			p.queue_free()
			return false
	if not _check(vm_ap.get_animation("FPS_Idle").loop_mode == Animation.LOOP_LINEAR and vm_ap.get_animation("FPS_Walk").loop_mode == Animation.LOOP_LINEAR, "FPS_Idle/FPS_Walk must loop"):
		p.queue_free()
		return false

	var spring_sim := p.get_node_or_null("VisualRoot/SK_Isabela/Armature_Isabela/Skeleton3D/SpringBoneSimulator3D")
	if not _check(spring_sim != null, "SpringBoneSimulator3D hair physics must remain intact"):
		p.queue_free()
		return false
	p.queue_free()
	await physics_frame
	return true


func _test_hud_view_indicator() -> bool:
	var host := Node3D.new()
	root.add_child(host)
	var gm = GameManagerScript.new()
	host.add_child(gm)
	gm.initialize("res://data/game_balance.json", 7)
	var p := PlayerScene.instantiate()
	host.add_child(p)
	p.configure(gm.balance_db, gm.upgrades, gm.loadout)
	var hud = HUDControllerScript.new()
	host.add_child(hud)
	hud.bind(gm, p)
	if not _check(hud.has_method("get_view_mode_text"), "HUDController must expose get_view_mode_text()"):
		host.queue_free()
		return false
	var tps_txt: String = hud.get_view_mode_text()
	if not _check("3ª" in tps_txt or "3a" in tps_txt, "TPS HUD indicator text mismatch: " + tps_txt):
		host.queue_free()
		return false
	p.toggle_view_mode()
	var fps_txt: String = hud.get_view_mode_text()
	if not _check("1ª" in fps_txt or "FPS" in fps_txt, "FPS HUD indicator text mismatch: " + fps_txt):
		host.queue_free()
		return false
	host.queue_free()
	return true


func _test_fps_optic_transparency_and_sniper_reticle() -> bool:
	var host := Node3D.new()
	root.add_child(host)
	var gm = GameManagerScript.new()
	host.add_child(gm)
	gm.initialize("res://data/game_balance.json", 11)
	var p := PlayerScene.instantiate()
	host.add_child(p)
	p.configure(gm.balance_db, gm.upgrades, gm.loadout)
	var hud = HUDControllerScript.new()
	host.add_child(hud)
	hud.bind(gm, p)
	await physics_frame

	gm.loadout.select_slot(2)
	var wm = p.get_node("WeaponManager")
	wm.refresh_equipped_mesh()
	p.toggle_view_mode()
	var vm = p.get_node("CameraPivot").get_fps_viewmodel()
	if not _check("sniper" in vm.WEAPON_TWEAKS, "FPSViewmodel.WEAPON_TWEAKS must contain sniper"):
		host.queue_free()
		return false
	vm.update_viewmodel(0.05, 0.0, 5.8, true, true, false)
	var active_w: Node3D = vm.get("_active_weapon")
	var scope_mesh := active_w.find_child("Scope", true, false) as MeshInstance3D
	var lens_mesh := active_w.find_child("ScopeLens", true, false) as MeshInstance3D
	if not _check(scope_mesh != null and lens_mesh != null, "Sniper GLB must expose Scope and ScopeLens meshes"):
		host.queue_free()
		return false
	var lens_mat := lens_mesh.material_override as StandardMaterial3D
	var scope_mat := scope_mesh.material_override as StandardMaterial3D
	if not _check(lens_mat != null and lens_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and lens_mat.albedo_color.a < 0.15, "ScopeLens must be transparent glass in ADS"):
		host.queue_free()
		return false
	if not _check(scope_mat != null and scope_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and scope_mat.albedo_color.a < 0.25, "Scope housing must be semi-transparent in ADS"):
		host.queue_free()
		return false

	# Restore opaque materials when exiting ADS
	vm.update_viewmodel(0.05, 0.0, 5.8, true, false, false)
	if not _check(lens_mesh.material_override == null and scope_mesh.material_override == null, "Exiting ADS must restore opaque scope materials"):
		host.queue_free()
		return false

	# Crosshair optic modes
	var ch = hud.get("_crosshair")
	ch.update_crosshair(0.05, 0.02, true, 0.0, "sniper")
	if not _check(int(ch.get("_optic_mode")) == 2, "HUDCrosshair must use sniper scope mode (2) when aiming sniper"):
		host.queue_free()
		return false
	ch.update_crosshair(0.05, 0.2, true, 0.0, "pistol")
	if not _check(int(ch.get("_optic_mode")) == 1, "HUDCrosshair must use precision optic mode (1) in FPS ADS for pistol"):
		host.queue_free()
		return false
	ch.update_crosshair(0.05, 0.2, false, 0.0, "pistol")
	if not _check(int(ch.get("_optic_mode")) == 0, "HUDCrosshair must return to standard mode (0) when not aiming"):
		host.queue_free()
		return false

	host.queue_free()
	await physics_frame
	return true
