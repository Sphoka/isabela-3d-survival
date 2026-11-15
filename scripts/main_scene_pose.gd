extends Node3D

func _ready() -> void:
	var skel: Skeleton3D = get_node_or_null("SK_Isabela/Armature_Isabela/Skeleton3D")
	if skel == null:
		return
	# World/skeleton-space Euler deltas (deg): +X=pitch back, -X=pitch forward, +Y=yaw left, +Z=roll
	var poses: Dictionary = {
		"Hips": Vector3(0.0, 3.0, 0.0),
		"Spine": Vector3(0.0, -2.0, 0.0),
		"Chest": Vector3(0.0, -2.0, 0.0),
		"LeftUpperLeg": Vector3(-14.0, 0.0, -2.0),
		"LeftLowerLeg": Vector3(12.0, 0.0, 0.0),
		"RightUpperLeg": Vector3(12.0, 0.0, 2.0),
		"RightLowerLeg": Vector3(8.0, 0.0, 0.0),
		"LeftUpperArm": Vector3(4.0, 0.0, -24.0),
		"LeftLowerArm": Vector3(-12.0, 0.0, 0.0),
		"RightUpperArm": Vector3(4.0, 0.0, 24.0),
		"RightLowerArm": Vector3(-12.0, 0.0, 0.0),
	}
	for bone_name: String in poses:
		var idx: int = skel.find_bone(bone_name)
		if idx != -1:
			var deg: Vector3 = poses[bone_name]
			var skel_delta: Quaternion = Quaternion.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)))
			var g_rot: Quaternion = skel.get_bone_global_rest(idx).basis.get_rotation_quaternion()
			var local_delta: Quaternion = g_rot.inverse() * skel_delta * g_rot
			var rest_q: Quaternion = skel.get_bone_rest(idx).basis.get_rotation_quaternion()
			skel.set_bone_pose_rotation(idx, rest_q * local_delta)

	call_deferred("_align_helmets_upright")

func _align_helmets_upright() -> void:
	var skel: Skeleton3D = get_node_or_null("SK_Isabela/Armature_Isabela/Skeleton3D")
	if skel == null:
		return
	var helmet_a: Node3D = skel.get_node_or_null("RightHandAttach/SM_Helmet_A")
	if helmet_a:
		var hand_pos_a: Vector3 = helmet_a.get_parent().global_position
		helmet_a.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-18.0)), hand_pos_a + Vector3(0.0, -0.31, 0.0))
	var helmet_b: Node3D = skel.get_node_or_null("LeftHandAttach/SM_Helmet_B")
	if helmet_b:
		var hand_pos_b: Vector3 = helmet_b.get_parent().global_position
		helmet_b.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(16.0)), hand_pos_b + Vector3(0.0, -0.31, 0.0))
