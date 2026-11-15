extends SceneTree

const BalanceDBRef := preload("res://scripts/game/balance_db.gd")
const UpgradeSystemRef := preload("res://scripts/game/upgrade_system.gd")
const WeaponLoadoutRef := preload("res://scripts/game/weapon_loadout.gd")
const WeaponManagerRef := preload("res://scripts/game/weapon_manager.gd")
const FPSViewmodelRef := preload("res://scripts/game/fps_viewmodel.gd")

var _failures: int = 0


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		push_error("GRIP_JACKET_ASSERTION_FAILED: %s" % msg)


func _init() -> void:
	var db := BalanceDBRef.new()
	db.load_from_file()

	# 1. Schema & SMG auto weapon check: all 7 weapons must have tps/fps grip config
	for wid in ["pistol", "lightsaber", "shotgun", "rocket_launcher", "katana", "laser_gun", "smg"]:
		var w: Dictionary = db.get_weapon_by_id(wid)
		_assert(not w.is_empty(), "Weapon %s must exist in game_balance.json" % wid)
		_assert(w.has("tps_grip_pos"), "Weapon %s must define tps_grip_pos" % wid)
		_assert(w.has("tps_grip_rot_deg"), "Weapon %s must define tps_grip_rot_deg" % wid)
		_assert(w.has("fps_grip_pos"), "Weapon %s must define fps_grip_pos" % wid)
		_assert(w.has("fps_grip_rot_deg"), "Weapon %s must define fps_grip_rot_deg" % wid)
	var smg_def: Dictionary = db.get_weapon_by_id("smg")
	_assert(int(smg_def.get("slot", 0)) == 7 and str(smg_def.get("fire_mode", "")) == "auto", "SMG must be slot 7 auto fire_mode")
	_assert(ResourceLoader.exists(str(smg_def.get("asset_path", ""))), "SMG GLB asset must exist")
	preload("res://scripts/game/input_setup.gd").ensure_default_actions()
	_assert(InputMap.has_action("weapon_7"), "InputMap must bind weapon_7")

	# 2. Instantiate player and check Jacket anti-poke-through
	var ps := load("res://scenes/game/player_isabela.tscn") as PackedScene
	var player := ps.instantiate()
	root.add_child(player)
	await process_frame
	await process_frame

	var top_mesh := player.find_child("SK_Isabela_Top", true, false) as MeshInstance3D
	_assert(top_mesh != null, "SK_Isabela_Top mesh must exist")
	if top_mesh != null:
		_assert(top_mesh.lod_bias >= 4.0, "SK_Isabela_Top lod_bias must be >= 4.0 to prevent back LOD poke-through")
		var mat := top_mesh.get_surface_override_material(0) as StandardMaterial3D
		_assert(mat != null, "SK_Isabela_Top must have StandardMaterial3D surface override")
		if mat != null:
			_assert(mat.grow, "SK_Isabela_Top material must have grow = true")
			_assert(mat.grow_amount >= 0.005, "SK_Isabela_Top grow_amount must be >= 0.005m")

	# 3. Check TPS Weapon Grip alignment across all 6 weapons
	var anim: Node = player.get_node("PlayerAnimator")
	var sk: Skeleton3D = anim.call("get_skeleton")
	var wm: WeaponManagerRef = player.get_node("WeaponManager") as WeaponManagerRef
	var upgrades := UpgradeSystemRef.new()
	upgrades.reset()
	var loadout := WeaponLoadoutRef.new()
	loadout.setup(db, upgrades)
	wm.setup(loadout, player)

	for slot_idx in range(1, 8):
		loadout.select_slot(slot_idx)
		var def := loadout.get_selected_def()
		var wid := str(def.get("id", ""))
		wm.refresh_equipped_mesh()
		for _i in range(25):
			anim.call("apply_pose", 0.05, Vector3.ZERO, true, false, 0.0, 0.0, 1, wid)
		await process_frame

		var active_w: Node3D = wm.get("_active_visual") as Node3D
		_assert(active_w != null, "TPS active weapon visual must exist for %s" % wid)
		if active_w != null:
			var palm_center := _compute_skinned_right_grip_center(sk)
			var dist := active_w.global_position.distance_to(palm_center)
			_assert(dist <= 0.025, "TPS %s grip origin too far from skinned palm center: %.4fm (expected <= 0.025m)" % [wid, dist])

	loadout.select_slot(7)
	_assert(loadout.get_selected_slot() == 7 and loadout.cycle_slot(1) and loadout.get_selected_slot() == 1, "cycle_slot(1) from slot 7 must wrap to slot 1")
	var atree: AnimationTree = anim.get("_anim_tree") as AnimationTree
	_assert(atree != null and str(atree.get("parameters/UpperIdle/current_state")) == "rifle", "SMG must use rifle UpperIdle")
	_assert(atree != null and str(atree.get("parameters/GripChoice/current_state")) == "both", "SMG must use both-hands GripChoice")

	# 4. Check FPS Viewmodel grip alignment for pistol, katana, lightsaber, and smg
	var fps_vm := FPSViewmodelRef.new()
	root.add_child(fps_vm)
	fps_vm.set_active(true)
	await process_frame
	for wid in ["pistol", "katana", "lightsaber", "smg"]:
		var def: Dictionary = db.get_weapon_by_id(wid)
		fps_vm.set_weapon(def)
		fps_vm.update_viewmodel(0.05, 0.0, 5.8, true, false, false)
		await process_frame
		var fps_w: Node3D = fps_vm.get("_active_weapon") as Node3D
		var fps_sk := fps_vm.find_child("Skeleton3D", true, false) as Skeleton3D
		_assert(fps_w != null and fps_sk != null, "FPS weapon & skeleton must exist for %s" % wid)
		if fps_w != null and fps_sk != null:
			var frm := (fps_sk.global_transform * fps_sk.get_bone_global_pose(fps_sk.find_bone("RightMiddleProximal"))).origin
			var frmd := (fps_sk.global_transform * fps_sk.get_bone_global_pose(fps_sk.find_bone("RightMiddleDistal"))).origin
			var fpalm := (frm + frmd) * 0.5
			var fdist := fps_w.global_position.distance_to(fpalm)
			_assert(fdist <= 0.045, "FPS %s grip origin too far from palm center: %.4fm (expected <= 0.045m)" % [wid, fdist])

	if _failures == 0:
		print("ALL_TESTS_PASSED: test_jacket_and_weapon_grip")
		quit(0)
	else:
		printerr("TESTS_FAILED: ", _failures)
		quit(1)


func _compute_skinned_right_grip_center(sk: Skeleton3D) -> Vector3:
	var body := sk.get_node_or_null("SK_Isabela_Body") as MeshInstance3D
	if body == null or body.mesh == null or body.skin == null:
		var rm := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightMiddleProximal"))).origin
		var rmd := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightMiddleDistal"))).origin
		return (rm + rmd) * 0.5
	var mesh := body.mesh
	var skin := body.skin
	var bind_to_bone := {}
	for bi in range(skin.get_bind_count()):
		var sb := sk.find_bone(skin.get_bind_name(bi))
		if sb >= 0:
			bind_to_bone[bi] = sb
	var target_names := ["RightHand", "RightThumbDistal", "RightIndexDistal", "RightMiddleDistal"]
	var watch := {}
	for b in target_names:
		var idx := sk.find_bone(b)
		if idx >= 0:
			watch[idx] = true
	var sums := {}
	var counts := {}
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var stride := bones.size() / verts.size()
		for vi in range(verts.size()):
			var sb: int = bind_to_bone.get(bones[vi * stride], bones[vi * stride])
			if watch.has(sb):
				var p_skel := Vector3.ZERO
				for k in range(stride):
					var bk := bones[vi * stride + k]
					var wk := weights[vi * stride + k]
					if wk <= 0.0001:
						continue
					p_skel += ((sk.get_bone_global_pose(bind_to_bone.get(bk, bk)) * skin.get_bind_pose(bk)) * verts[vi]) * wk
				sums[sb] = sums.get(sb, Vector3.ZERO) + (body.global_transform * p_skel)
				counts[sb] = counts.get(sb, 0) + 1
	var total := Vector3.ZERO
	var n_groups := 0
	for sb in sums.keys():
		total += (sums[sb] as Vector3) / float(counts[sb])
		n_groups += 1
	return total / float(maxi(1, n_groups))
