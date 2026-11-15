class_name DroidDestructionVFX
extends RefCounted
## Spawns robot explosion bursts, spark showers, scorch marks, and pooled RigidBody3D disassembled parts.

const MAX_DEBRIS_PIECES := 36

static var _rng := RandomNumberGenerator.new()
static var _seeded := false


static func spawn_droid_explosion(scene_root: Node, world_pos: Vector3, enemy_id: String, impulse_hint: Vector3 = Vector3.ZERO) -> void:
	if scene_root == null or not scene_root.is_inside_tree():
		return
	if not _seeded:
		_rng.randomize()
		_seeded = true
	var is_tall := enemy_id == "droid_tall"
	var center := world_pos + Vector3(0.0, 1.05 if is_tall else 0.58, 0.0)
	var flash_col := Color(0.35, 0.85, 1.0) if is_tall else Color(1.0, 0.55, 0.16)
	spawn_explosion_burst(scene_root, center, 2.8 if is_tall else 2.0, flash_col, 14 if is_tall else 10)
	_spawn_debris_chunks(scene_root, center, is_tall, impulse_hint)


static func spawn_explosion_burst(scene_root: Node, center: Vector3, radius: float, col: Color, spark_count: int = 12) -> void:
	if scene_root == null or not scene_root.is_inside_tree():
		return
	if not _seeded:
		_rng.randomize()
		_seeded = true

	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 7.5
	light.omni_range = radius * 3.4
	scene_root.add_child(light)
	light.global_position = center
	var ltw := light.create_tween()
	ltw.tween_property(light, "light_energy", 0.0, 0.26)
	ltw.tween_callback(light.queue_free)

	var orb := MeshInstance3D.new()
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sph := SphereMesh.new()
	sph.radius = 0.35
	sph.height = 0.70
	orb.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(col.r, col.g, col.b, 0.45)
	orb.material_override = mat
	scene_root.add_child(orb)
	orb.global_position = center
	var tw := orb.create_tween()
	tw.set_parallel(true)
	tw.tween_property(orb, "scale", Vector3.ONE * radius, 0.16)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tw.chain().tween_callback(orb.queue_free)

	_spawn_spark_shower(scene_root, center, col, spark_count, radius)
	_spawn_scorch_ring(scene_root, Vector3(center.x, 0.03, center.z), radius * 0.65)


static func _spawn_debris_chunks(scene_root: Node, center: Vector3, is_tall: bool, impulse_hint: Vector3) -> void:
	var count := 8 if is_tall else 6
	var tree := scene_root.get_tree()
	_enforce_debris_cap(tree, MAX_DEBRIS_PIECES - count)

	var hull_col := Color(0.24, 0.27, 0.32) if is_tall else Color(0.18, 0.20, 0.24)
	var accent_col := Color(0.18, 0.82, 0.96) if is_tall else Color(0.95, 0.42, 0.12)
	var hull_mat := _make_metal_mat(hull_col, false)
	var core_mat := _make_metal_mat(accent_col, true)

	for i in range(count):
		var rb := RigidBody3D.new()
		rb.add_to_group("droid_debris")
		rb.collision_layer = 0
		rb.collision_mask = 1
		rb.mass = 1.4
		rb.continuous_cd = false

		var mi := MeshInstance3D.new()
		var cs := CollisionShape3D.new()
		var sc := 1.25 if is_tall else 0.95
		if i == 0:
			var head := BoxMesh.new()
			head.size = Vector3(0.24, 0.20, 0.26) * sc
			mi.mesh = head
			mi.material_override = core_mat
			var b := BoxShape3D.new()
			b.size = head.size
			cs.shape = b
		elif i <= 3:
			var limb := CylinderMesh.new()
			limb.top_radius = 0.055 * sc
			limb.bottom_radius = 0.045 * sc
			limb.height = 0.38 * sc
			mi.mesh = limb
			mi.material_override = hull_mat
			var c := CylinderShape3D.new()
			c.radius = 0.055 * sc
			c.height = limb.height
			cs.shape = c
		else:
			var plate := BoxMesh.new()
			plate.size = Vector3(0.28, 0.09, 0.22) * sc
			mi.mesh = plate
			mi.material_override = hull_mat if i % 2 == 0 else core_mat
			var b2 := BoxShape3D.new()
			b2.size = plate.size
			cs.shape = b2

		rb.add_child(mi)
		rb.add_child(cs)
		scene_root.add_child(rb)
		var off := Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.15, 0.35), _rng.randf_range(-0.25, 0.25))
		rb.global_position = center + off
		var out_dir := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized()
		if out_dir.length_squared() < 0.01:
			out_dir = Vector3.RIGHT
		var h_spd := _rng.randf_range(3.0, 7.2)
		var v_spd := _rng.randf_range(3.8, 7.8)
		var flat_hint := Vector3(impulse_hint.x, 0.0, impulse_hint.z) * 0.35
		rb.linear_velocity = out_dir * h_spd + Vector3(0.0, v_spd, 0.0) + flat_hint
		rb.angular_velocity = Vector3(_rng.randf_range(-11.0, 11.0), _rng.randf_range(-11.0, 11.0), _rng.randf_range(-11.0, 11.0))

		var dtw := rb.create_tween()
		dtw.tween_interval(_rng.randf_range(2.2, 3.1))
		dtw.tween_property(mi, "scale", Vector3.ZERO, 0.35)
		dtw.tween_callback(rb.queue_free)


static func _enforce_debris_cap(tree: SceneTree, target_max: int) -> void:
	if tree == null:
		return
	var existing := tree.get_nodes_in_group("droid_debris")
	var over := existing.size() - maxi(0, target_max)
	for i in range(mini(over, existing.size())):
		var node := existing[i]
		if is_instance_valid(node):
			node.remove_from_group("droid_debris")
			node.queue_free()


static func _spawn_spark_shower(scene_root: Node, center: Vector3, col: Color, count: int, radius: float) -> void:
	for _i in range(count):
		var sp := MeshInstance3D.new()
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bm := BoxMesh.new()
		bm.size = Vector3(0.035, 0.035, 0.22)
		sp.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(minf(1.0, col.r + 0.3), minf(1.0, col.g + 0.3), minf(1.0, col.b + 0.2), 1.0)
		sp.material_override = mat
		scene_root.add_child(sp)
		sp.global_position = center
		var dir := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(0.15, 0.95), _rng.randf_range(-1.0, 1.0)).normalized()
		sp.look_at(center + dir, Vector3.UP)
		var end_p := center + dir * _rng.randf_range(radius * 0.7, radius * 1.6)
		var stw := sp.create_tween()
		stw.set_parallel(true)
		stw.tween_property(sp, "global_position", end_p, 0.24)
		stw.tween_property(mat, "albedo_color:a", 0.0, 0.24)
		stw.chain().tween_callback(sp.queue_free)


static func _spawn_scorch_ring(scene_root: Node, floor_pos: Vector3, radius: float) -> void:
	var disc := MeshInstance3D.new()
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.05, 0.05, 0.07, 0.62)
	disc.material_override = mat
	scene_root.add_child(disc)
	disc.global_position = floor_pos
	var tw := disc.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.2)
	tw.tween_callback(disc.queue_free)


static func _make_metal_mat(col: Color, emissive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.82
	m.roughness = 0.34
	if emissive:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 2.0
	return m
