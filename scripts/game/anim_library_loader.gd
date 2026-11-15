class_name AnimLibraryLoader
extends RefCounted
## Loads animation clips from an external GLB into AnimationPlayer, strips Hair_ tracks for SpringBoneSimulator3D, and builds an upper/lower AnimationNodeBlendTree.

const UPPER_BASE_BONES := [
	"Spine", "Chest", "UpperChest", "Neck", "Head", "Jaw",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
]

const FINGER_BONES := [
	"LeftIndexProximal", "LeftIndexIntermediate", "LeftIndexDistal",
	"LeftMiddleProximal", "LeftMiddleIntermediate", "LeftMiddleDistal",
	"LeftRingProximal", "LeftRingIntermediate", "LeftRingDistal",
	"LeftLittleProximal", "LeftLittleIntermediate", "LeftLittleDistal",
	"LeftThumbMetacarpal", "LeftThumbProximal", "LeftThumbDistal",
	"RightIndexProximal", "RightIndexIntermediate", "RightIndexDistal",
	"RightMiddleProximal", "RightMiddleIntermediate", "RightMiddleDistal",
	"RightRingProximal", "RightRingIntermediate", "RightRingDistal",
	"RightLittleProximal", "RightLittleIntermediate", "RightLittleDistal",
	"RightThumbMetacarpal", "RightThumbProximal", "RightThumbDistal",
]

const LOOP_CLIPS := [
	"Idle", "Idle_Loop", "Walk", "Walk_Loop", "Jog_Fwd", "Jog_Fwd_Loop",
	"Sprint", "Sprint_Loop", "Crouch_Idle", "Crouch_Idle_Loop", "Jump", "Jump_Loop",
	"Pistol_Idle", "Pistol_Idle_Loop", "Rifle_Idle", "Rifle_Idle_Loop",
	"Rocket_Idle", "Rocket_Idle_Loop", "Sword_Idle",
]


static func load_clips_into_player(ap: AnimationPlayer, glb_path: String) -> Dictionary:
	var loaded := {}
	if ap == null or glb_path.is_empty() or not ResourceLoader.exists(glb_path):
		return loaded
	var ps := load(glb_path) as PackedScene
	if ps == null:
		return loaded
	var inst := ps.instantiate()
	var src_ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src_ap == null:
		inst.free()
		return loaded

	var dst_lib := AnimationLibrary.new()
	for lib_name in src_ap.get_animation_library_list():
		var src_lib := src_ap.get_animation_library(lib_name)
		for anim_name in src_lib.get_animation_list():
			var anim := src_lib.get_animation(anim_name).duplicate(true) as Animation
			_normalize_tracks(anim)
			anim.loop_mode = Animation.LOOP_LINEAR if String(anim_name) in LOOP_CLIPS else Animation.LOOP_NONE
			if not dst_lib.has_animation(anim_name):
				dst_lib.add_animation(anim_name, anim)
				loaded[String(anim_name)] = true

	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", dst_lib)
	inst.free()
	return loaded


static func setup_isabela_anim_tree(isabela_root: Node3D, glb_path: String) -> Dictionary:
	var out := {"player": null, "tree": null, "clips": {}}
	if isabela_root == null or not ResourceLoader.exists(glb_path):
		return out
	var ap := isabela_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "AnimationPlayer"
		isabela_root.add_child(ap)
	ap.root_node = ap.get_path_to(isabela_root)
	var clips := load_clips_into_player(ap, glb_path)
	if clips.is_empty():
		return out
	var tree := isabela_root.get_node_or_null("AnimationTree") as AnimationTree
	if tree == null:
		tree = AnimationTree.new()
		tree.name = "AnimationTree"
		isabela_root.add_child(tree)
	tree.root_node = tree.get_path_to(isabela_root)
	tree.anim_player = tree.get_path_to(ap)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.tree_root = build_combat_blend_tree(clips)
	tree.active = true
	tree.set("parameters/UpperBlend/blend_amount", 1.0)
	tree.set("parameters/GripBlend/blend_amount", 0.85)
	out["player"] = ap
	out["tree"] = tree
	out["clips"] = clips
	return out


static func build_combat_blend_tree(clips: Dictionary) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	var loco_specs := [
		["idle", ["Idle", "Idle_Loop"]],
		["walk", ["Walk", "Walk_Loop", "Idle", "Idle_Loop"]],
		["jog", ["Jog_Fwd", "Jog_Fwd_Loop", "Walk", "Walk_Loop"]],
		["sprint", ["Sprint", "Sprint_Loop", "Jog_Fwd", "Jog_Fwd_Loop"]],
		["jump_start", ["Jump_Start", "Jump", "Jump_Loop"]],
		["jump_loop", ["Jump", "Jump_Loop", "Idle", "Idle_Loop"]],
		["jump_land", ["Jump_Land", "Idle", "Idle_Loop"]],
		["roll", ["Roll", "Sprint", "Sprint_Loop"]],
		["hit", ["Hit_Chest", "Idle", "Idle_Loop"]],
		["death", ["Death01", "Idle", "Idle_Loop"]],
	]
	_make_transition(bt, "Loco", 0.12, loco_specs, clips)

	var uidle_specs := [
		["pistol", ["Pistol_Idle", "Pistol_Idle_Loop", "Idle", "Idle_Loop"]],
		["rifle", ["Rifle_Idle", "Rifle_Idle_Loop", "Pistol_Idle", "Pistol_Idle_Loop"]],
		["rocket", ["Rocket_Idle", "Rocket_Idle_Loop", "Pistol_Idle", "Pistol_Idle_Loop"]],
		["sword", ["Sword_Idle", "Idle", "Idle_Loop"]],
	]
	_make_transition(bt, "UpperIdle", 0.10, uidle_specs, clips)

	var uact_specs := [
		["pistol_shoot", ["Pistol_Shoot", "Pistol_Idle", "Pistol_Idle_Loop"]],
		["pistol_reload", ["Pistol_Reload", "Pistol_Idle", "Pistol_Idle_Loop"]],
		["rifle_shoot", ["Rifle_Shoot", "Pistol_Shoot", "Rifle_Idle"]],
		["rifle_reload", ["Rifle_Reload", "Pistol_Reload", "Rifle_Idle"]],
		["rocket_shoot", ["Rocket_Shoot", "Pistol_Shoot", "Rocket_Idle"]],
		["rocket_reload", ["Rocket_Reload", "Pistol_Reload", "Rocket_Idle"]],
		["sword_1", ["Katana_Combo_1", "Sword_Attack", "Sword_Idle"]],
		["sword_2", ["Katana_Combo_2", "Sword_Attack", "Sword_Idle"]],
		["sword_3", ["Katana_Combo_3", "Sword_Attack", "Sword_Idle"]],
		["saber_1", ["Saber_Combo_1", "Sword_Attack", "Sword_Idle"]],
		["saber_2", ["Saber_Combo_2", "Sword_Attack", "Sword_Idle"]],
		["saber_3", ["Saber_Combo_3", "Sword_Attack", "Sword_Idle"]],
		["hit", ["Hit_Chest", "Idle", "Idle_Loop"]],
	]
	_make_transition(bt, "UpperAction", 0.04, uact_specs, clips)

	var oneshot := AnimationNodeOneShot.new()
	oneshot.fadein_time = 0.04
	oneshot.fadeout_time = 0.09
	oneshot.mix_mode = AnimationNodeOneShot.MIX_MODE_BLEND
	bt.add_node("UpperOneShot", oneshot)
	bt.connect_node("UpperOneShot", 0, "UpperIdle")
	bt.connect_node("UpperOneShot", 1, "UpperAction")

	var upper_blend := AnimationNodeBlend2.new()
	upper_blend.filter_enabled = true
	for bname in UPPER_BASE_BONES + FINGER_BONES:
		upper_blend.set_filter_path(NodePath("Armature_Isabela/Skeleton3D:" + bname), true)
	bt.add_node("UpperBlend", upper_blend)
	bt.connect_node("UpperBlend", 0, "Loco")
	bt.connect_node("UpperBlend", 1, "UpperOneShot")

	var grip_specs := [
		["right", ["Grip_RightHand", "Pistol_Idle", "Idle"]],
		["left", ["Grip_LeftHand", "Rifle_Idle", "Idle"]],
		["both", ["Grip_BothHands", "Rifle_Idle", "Idle"]],
	]
	_make_transition(bt, "GripChoice", 0.08, grip_specs, clips)
	var grip_blend := AnimationNodeBlend2.new()
	grip_blend.filter_enabled = true
	for fname in FINGER_BONES:
		grip_blend.set_filter_path(NodePath("Armature_Isabela/Skeleton3D:" + fname), true)
	bt.add_node("GripBlend", grip_blend)
	bt.connect_node("GripBlend", 0, "UpperBlend")
	bt.connect_node("GripBlend", 1, "GripChoice")
	bt.connect_node("output", 0, "GripBlend")
	return bt


static func _make_transition(bt: AnimationNodeBlendTree, node_name: String, xfade: float, specs: Array, clips: Dictionary) -> AnimationNodeTransition:
	var tr := AnimationNodeTransition.new()
	tr.xfade_time = xfade
	tr.input_count = specs.size()
	bt.add_node(node_name, tr)
	for i in range(specs.size()):
		var state_name: String = specs[i][0]
		var clip_name: String = _pick_clip(specs[i][1], clips)
		tr.set_input_name(i, state_name)
		var an := AnimationNodeAnimation.new()
		an.animation = clip_name
		var an_name := "%s_%s" % [node_name, state_name]
		bt.add_node(an_name, an)
		bt.connect_node(node_name, i, an_name)
	return tr


static func _pick_clip(candidates: Array, clips: Dictionary) -> String:
	for c in candidates:
		var s := str(c)
		if clips.has(s):
			return s
	if clips.has("Idle"):
		return "Idle"
	if clips.has("Idle_Loop"):
		return "Idle_Loop"
	return String(clips.keys()[0]) if not clips.is_empty() else ""


static func _normalize_tracks(anim: Animation) -> void:
	for i in range(anim.get_track_count() - 1, -1, -1):
		var p := String(anim.track_get_path(i))
		var colon_idx := p.find(":")
		if colon_idx == -1:
			continue
		var bone := p.substr(colon_idx + 1)
		if bone.begins_with("Hair_") or bone == "LeftEye" or bone == "RightEye":
			anim.remove_track(i)
			continue
		anim.track_set_path(i, NodePath("Armature_Isabela/Skeleton3D:" + bone))
