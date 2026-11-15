class_name WeaponVFX
extends RefCounted
## Spawns transient muzzle flashes, laser/bullet tracer beams, and 3-hit directional melee slash arcs.


static func spawn_muzzle_flash(scene_root: Node, pos: Vector3, col: Color) -> void:
	if scene_root == null:
		return
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 3.2
	l.omni_range = 4.2
	scene_root.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.07)
	tw.tween_callback(l.queue_free)


static func spawn_beam_fx(scene_root: Node, from_p: Vector3, to_p: Vector3, col: Color, radius: float, duration: float) -> void:
	var dist := from_p.distance_to(to_p)
	if dist < 0.05 or scene_root == null:
		return
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = dist
	mi.mesh = cyl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col.r, col.g, col.b, 0.92)
	mi.material_override = mat
	scene_root.add_child(mi)
	mi.global_position = (from_p + to_p) * 0.5
	mi.look_at(to_p, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.tween_callback(mi.queue_free)


static func spawn_blade_trail(scene_root: Node, origin: Vector3, forward: Vector3, combo_step: int, weapon_id: String, is_fps: bool) -> void:
	if scene_root == null:
		return
	var col := Color(0.28, 0.92, 1.0, 0.95) if weapon_id == "lightsaber" else Color(1.0, 0.28, 0.14, 0.92)
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = _build_arc_mesh(0.90 if is_fps else 0.98, 0.26 if is_fps else 0.28, 14)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(col.r, col.g, col.b, 1.0)
	mat.emission_energy_multiplier = 2.6
	mat.albedo_color = col
	mi.material_override = mat
	scene_root.add_child(mi)

	var flat_fwd := Vector3(forward.x, forward.y * 0.55, forward.z).normalized()
	if flat_fwd.length_squared() < 0.01:
		flat_fwd = Vector3.FORWARD
	var eye_off := (Vector3(0.0, 0.18, 0.0) if is_fps else Vector3(0.0, 0.24, 0.0)) + flat_fwd * (0.68 if is_fps else 0.58)
	mi.global_position = origin + eye_off
	mi.look_at(mi.global_position + flat_fwd, Vector3.UP)

	var roll_deg := -34.0
	if combo_step == 2:
		roll_deg = 34.0
	elif combo_step >= 3:
		roll_deg = -86.0
	mi.rotate_object_local(Vector3.FORWARD, deg_to_rad(roll_deg))
	mi.rotate_object_local(Vector3.RIGHT, deg_to_rad(28.0 if is_fps else 34.0))
	mi.scale = Vector3(0.75, 0.75, 0.75)

	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.18, 1.18, 1.18), 0.16)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tw.chain().tween_callback(mi.queue_free)


static func _build_arc_mesh(radius: float, width: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a0 := deg_to_rad(-65.0)
	var a1 := deg_to_rad(65.0)
	var inner_r := radius - width
	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var th0 := lerpf(a0, a1, t0)
		var th1 := lerpf(a0, a1, t1)
		var w0 := sin(t0 * PI)
		var w1 := sin(t1 * PI)
		var r_in0 := lerpf(radius, inner_r, w0)
		var r_in1 := lerpf(radius, inner_r, w1)
		var o0 := Vector3(sin(th0) * radius, 0.0, -cos(th0) * radius)
		var i0 := Vector3(sin(th0) * r_in0, 0.0, -cos(th0) * r_in0)
		var o1 := Vector3(sin(th1) * radius, 0.0, -cos(th1) * radius)
		var i1 := Vector3(sin(th1) * r_in1, 0.0, -cos(th1) * r_in1)
		st.add_vertex(o0)
		st.add_vertex(o1)
		st.add_vertex(i1)
		st.add_vertex(o0)
		st.add_vertex(i1)
		st.add_vertex(i0)
	return st.commit()
