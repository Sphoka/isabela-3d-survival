class_name WeaponVFX
extends RefCounted
## Spawns transient muzzle flashes, laser/bullet tracer beams, and 3-hit directional melee slash arcs.


static var _rng := RandomNumberGenerator.new()
static var _seeded := false


static func spawn_muzzle_flash(scene_root: Node, pos: Vector3, col: Color) -> void:
	if scene_root == null or not scene_root.is_inside_tree():
		return
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 4.2
	l.omni_range = 4.8
	scene_root.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.08)
	tw.tween_callback(l.queue_free)

	var orb := MeshInstance3D.new()
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sph := SphereMesh.new()
	sph.radius = 0.095
	sph.height = 0.19
	orb.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(minf(1.0, col.r + 0.25), minf(1.0, col.g + 0.25), minf(1.0, col.b + 0.25), 0.95)
	orb.material_override = mat
	scene_root.add_child(orb)
	orb.global_position = pos
	var otw := orb.create_tween()
	otw.set_parallel(true)
	otw.tween_property(orb, "scale", Vector3(2.2, 2.2, 2.2), 0.07)
	otw.tween_property(mat, "albedo_color:a", 0.0, 0.075)
	otw.chain().tween_callback(orb.queue_free)


static func spawn_hit_sparks(scene_root: Node, hit_pos: Vector3, hit_normal: Vector3, is_crit: bool = false, is_metal: bool = true) -> void:
	if scene_root == null or not scene_root.is_inside_tree():
		return
	if not _seeded:
		_rng.randomize()
		_seeded = true
	var nrm := hit_normal.normalized() if hit_normal.length_squared() > 0.01 else Vector3.UP
	var count := 11 if is_crit else (6 if is_metal else 4)
	var base_col := Color(0.28, 0.95, 1.0, 1.0) if is_crit else (Color(1.0, 0.72, 0.22, 1.0) if is_metal else Color(0.85, 0.80, 0.65, 0.9))

	for _i in range(count):
		var sp := MeshInstance3D.new()
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bm := BoxMesh.new()
		bm.size = Vector3(0.024, 0.024, 0.15 if is_crit else 0.11)
		sp.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = base_col
		sp.material_override = mat
		scene_root.add_child(sp)
		sp.global_position = hit_pos
		var jitter := Vector3(_rng.randf_range(-0.85, 0.85), _rng.randf_range(-0.35, 0.95), _rng.randf_range(-0.85, 0.85))
		var dir := (nrm + jitter).normalized()
		if dir.length_squared() < 0.01:
			dir = Vector3.UP
		sp.look_at(hit_pos + dir, Vector3.UP)
		var dist := _rng.randf_range(0.45, 1.15 if is_crit else 0.75)
		var tw := sp.create_tween()
		tw.set_parallel(true)
		tw.tween_property(sp, "global_position", hit_pos + dir * dist, 0.16)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
		tw.chain().tween_callback(sp.queue_free)


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
	tw.tween_property(mi, "scale", Vector3(1.24, 1.24, 1.24), 0.17)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.19)
	tw.chain().tween_callback(mi.queue_free)

	var core := MeshInstance3D.new()
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.mesh = _build_arc_mesh(0.92 if is_fps else 1.0, 0.085, 14)
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cmat.albedo_color = Color(1.0, 1.0, 1.0, 0.92)
	core.material_override = cmat
	mi.add_child(core)
	var ctw := core.create_tween()
	ctw.tween_property(cmat, "albedo_color:a", 0.0, 0.12)
	spawn_hit_sparks(scene_root, origin + flat_fwd * 0.95, Vector3.UP, weapon_id == "lightsaber", true)


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
