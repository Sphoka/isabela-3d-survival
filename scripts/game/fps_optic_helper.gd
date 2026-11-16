class_name FPSOpticHelper
extends RefCounted
## Manages FPS ADS optic/scope transparency and weapon overlay tints, restoring opaque materials on exit.

const LENS_KEYWORDS := ["lens", "glass", "reticle", "prism"]
const OPTIC_KEYWORDS := ["scope", "optic", "sight", "rail", "mount", "hood", "ring", "shroud"]
const MELEE_IDS := ["katana", "lightsaber"]

var _tracked: Array[Dictionary] = []
var _has_dedicated_optics: bool = false
var _is_aiming: bool = false
var _tint_overlay: StandardMaterial3D
var _lens_mat: StandardMaterial3D
var _optic_mat: StandardMaterial3D
var _body_ghost_mat: StandardMaterial3D


func disable_shadows_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		disable_shadows_recursive(c)


func set_weapon_overlay(weapon_root: Node3D, col: Color) -> void:
	if weapon_root == null:
		return
	var mat: StandardMaterial3D = null
	if col.a > 0.001:
		if _tint_overlay == null:
			_tint_overlay = StandardMaterial3D.new()
			_tint_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_tint_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tint_overlay.albedo_color = col
		mat = _tint_overlay
	for m in weapon_root.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = mat


func bind_weapon(weapon_root: Node3D) -> void:
	_tracked.clear()
	_has_dedicated_optics = false
	_is_aiming = false
	if weapon_root == null:
		return
	for node in weapon_root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		var role := _classify_mesh(mi.name)
		if role == "lens" or role == "optic":
			_has_dedicated_optics = true
		var surf_count := mi.get_surface_override_material_count()
		var orig_surfs: Array[Material] = []
		for i in range(surf_count):
			orig_surfs.append(mi.get_surface_override_material(i))
		_tracked.append({
			"mesh": mi,
			"role": role,
			"orig_override": mi.material_override,
			"orig_surfs": orig_surfs,
		})


func set_aiming(aiming: bool, weapon_id: String = "") -> void:
	var want_ghost := aiming and not (weapon_id in MELEE_IDS)
	if _is_aiming == want_ghost:
		return
	_is_aiming = want_ghost
	if not want_ghost:
		_restore_materials()
		return
	_ensure_optic_materials()
	for entry in _tracked:
		var mi := entry.get("mesh") as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var role := str(entry.get("role", "body"))
		if role == "lens":
			_apply_ghost_material(mi, _lens_mat)
		elif role == "optic":
			_apply_ghost_material(mi, _optic_mat)
		elif not _has_dedicated_optics:
			_apply_ghost_material(mi, _body_ghost_mat)


func _restore_materials() -> void:
	for entry in _tracked:
		var mi := entry.get("mesh") as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		mi.material_override = entry.get("orig_override") as Material
		var orig_surfs: Array = entry.get("orig_surfs", [])
		for i in range(mini(orig_surfs.size(), mi.get_surface_override_material_count())):
			mi.set_surface_override_material(i, orig_surfs[i] as Material)


func _apply_ghost_material(mi: MeshInstance3D, mat: StandardMaterial3D) -> void:
	mi.material_override = mat
	for i in range(mi.get_surface_override_material_count()):
		mi.set_surface_override_material(i, null)


func _classify_mesh(mesh_name: String) -> String:
	var low := mesh_name.to_lower()
	for kw in LENS_KEYWORDS:
		if kw in low:
			return "lens"
	for kw in OPTIC_KEYWORDS:
		if kw in low:
			return "optic"
	return "body"


func _ensure_optic_materials() -> void:
	if _lens_mat == null:
		_lens_mat = StandardMaterial3D.new()
		_lens_mat.albedo_color = Color(0.55, 0.92, 1.0, 0.08)
		_lens_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_lens_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_lens_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_lens_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if _optic_mat == null:
		_optic_mat = StandardMaterial3D.new()
		_optic_mat.albedo_color = Color(0.18, 0.24, 0.30, 0.16)
		_optic_mat.metallic = 0.4
		_optic_mat.roughness = 0.35
		_optic_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_optic_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if _body_ghost_mat == null:
		_body_ghost_mat = StandardMaterial3D.new()
		_body_ghost_mat.albedo_color = Color(0.24, 0.28, 0.34, 0.32)
		_body_ghost_mat.metallic = 0.35
		_body_ghost_mat.roughness = 0.4
		_body_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_body_ghost_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
