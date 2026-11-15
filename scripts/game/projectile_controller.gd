class_name ProjectileController
extends Area3D
## Handles player RocketLauncher AoE rockets and enemy Tall Droid deflectable plasma bolts.

enum Mode { PLAYER_ROCKET, ENEMY_PLASMA }

signal detonated(world_pos: Vector3, radius: float)

var mode: Mode = Mode.PLAYER_ROCKET
var direction: Vector3 = Vector3.FORWARD
var speed_mps: float = 28.0
var damage: float = 30.0
var splash_damage: float = 135.0
var splash_radius_m: float = 4.8
var splash_edge_falloff: float = 0.40
var self_damage_mult: float = 0.15
var knockback_mps: float = 15.0
var max_lifetime_s: float = 4.5

var _age_s: float = 0.0
var _friendly_to_player: bool = true
var _exploded: bool = false
var _mesh: MeshInstance3D
var _light: OmniLight3D


func _ready() -> void:
	monitoring = true
	monitorable = true
	if get_node_or_null("CollisionShape3D") == null:
		var cs := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.22
		cs.shape = s
		add_child(cs)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_rebuild_vfx()


func configure_rocket(origin: Vector3, dir: Vector3, shot: Dictionary) -> void:
	mode = Mode.PLAYER_ROCKET
	_friendly_to_player = true
	direction = dir.normalized()
	speed_mps = float(shot.get("projectile_speed_mps", 28.0))
	damage = float(shot.get("final_damage", shot.get("damage", 30.0)))
	splash_damage = float(shot.get("splash_damage", 135.0))
	splash_radius_m = float(shot.get("splash_radius_m", 4.8))
	splash_edge_falloff = float(shot.get("splash_edge_falloff_multiplier", 0.40))
	self_damage_mult = float(shot.get("self_damage_multiplier", 0.15))
	knockback_mps = float(shot.get("knockback_mps", 15.0))
	collision_layer = 16
	collision_mask = 1 | 4
	if is_inside_tree():
		global_position = origin
		look_at(origin + direction, Vector3.UP)
	else:
		position = origin


func configure_enemy_plasma(origin: Vector3, dir: Vector3, dmg: float, speed: float = 16.0) -> void:
	mode = Mode.ENEMY_PLASMA
	_friendly_to_player = false
	direction = dir.normalized()
	damage = dmg
	speed_mps = speed
	knockback_mps = 3.5
	collision_layer = 32
	collision_mask = 1 | 2
	if is_inside_tree():
		global_position = origin
	else:
		position = origin


func is_friendly_to_player() -> bool:
	return _friendly_to_player


func deflect(new_dir: Vector3, dmg_multiplier: float = 1.75) -> void:
	if mode != Mode.ENEMY_PLASMA or _friendly_to_player:
		return
	_friendly_to_player = true
	direction = new_dir.normalized()
	speed_mps *= 1.6
	damage *= dmg_multiplier
	_age_s = 0.0
	collision_layer = 16
	collision_mask = 1 | 4
	_rebuild_vfx()


func compute_splash_damage_at_distance(dist: float) -> float:
	if dist > splash_radius_m:
		return 0.0
	var t := clampf(dist / maxf(0.01, splash_radius_m), 0.0, 1.0)
	return splash_damage * lerpf(1.0, splash_edge_falloff, t)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_age_s += delta
	if _age_s >= max_lifetime_s:
		queue_free()
		return
	var step := direction * speed_mps * delta
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space != null:
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step, collision_mask)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			global_position = hit["position"]
			_handle_hit(hit.get("collider", null))
			return
	global_position += step


func _on_body_entered(body: Node3D) -> void:
	_handle_hit(body)


func _on_area_entered(area: Area3D) -> void:
	if area != null and area.get_parent() != null and area.get_parent().is_in_group("player") and not _friendly_to_player:
		_handle_hit(area.get_parent())


func _handle_hit(target: Variant) -> void:
	if _exploded:
		return
	if mode == Mode.PLAYER_ROCKET:
		if target is Node and (target as Node).is_in_group("player"):
			return
		_detonate_rocket(target)
	else:
		if _friendly_to_player:
			if target is Node and (target as Node).is_in_group("enemies") and target.has_method("take_damage"):
				target.call("take_damage", damage, direction * knockback_mps, true, "deflected_plasma")
			elif target is Node and (target as Node).is_in_group("player"):
				return
		else:
			if target is Node and (target as Node).is_in_group("player") and target.has_method("take_damage"):
				target.call("take_damage", damage, direction * knockback_mps)
		_exploded = true
		queue_free()


func _detonate_rocket(direct_target: Variant) -> void:
	_exploded = true
	if direct_target is Node and ((direct_target as Node).is_in_group("enemies") or (direct_target as Node).is_in_group("damageable_props")) and direct_target.has_method("take_damage"):
		direct_target.call("take_damage", damage, direction * knockback_mps * 0.5, false, "rocket_direct")

	if is_inside_tree():
		for node in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("damageable_props"):
			if not (node is Node3D) or not is_instance_valid(node):
				continue
			var n3 := node as Node3D
			var d := global_position.distance_to(n3.global_position + Vector3(0.0, 0.7, 0.0))
			if d <= splash_radius_m and n3.has_method("take_damage"):
				var sd := compute_splash_damage_at_distance(d)
				var push := (n3.global_position - global_position).normalized() * knockback_mps
				n3.call("take_damage", sd, push, false, "rocket_splash")

		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player != null and player.has_method("take_damage"):
			var pd := global_position.distance_to(player.global_position + Vector3(0.0, 0.85, 0.0))
			if pd <= splash_radius_m:
				var self_dmg := compute_splash_damage_at_distance(pd) * self_damage_mult
				player.call("take_damage", self_dmg, (player.global_position - global_position).normalized() * 6.0)

		_spawn_explosion_fx()
	detonated.emit(global_position, splash_radius_m)
	queue_free()


func _spawn_explosion_fx() -> void:
	var fx := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	fx.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.85)
	fx.material_override = mat
	get_parent().add_child(fx)
	fx.global_position = global_position
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector3.ONE * (splash_radius_m * 1.9), 0.28)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(fx.queue_free)


func _rebuild_vfx() -> void:
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh)
	if _light == null:
		_light = OmniLight3D.new()
		_light.omni_range = 3.0
		add_child(_light)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if mode == Mode.PLAYER_ROCKET:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.065
		cyl.height = 0.42
		_mesh.mesh = cyl
		_mesh.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		mat.albedo_color = Color(1.0, 0.65, 0.15)
		_light.light_color = Color(1.0, 0.55, 0.15)
	else:
		var sph := SphereMesh.new()
		sph.radius = 0.14
		sph.height = 0.28
		_mesh.mesh = sph
		var col := Color(0.15, 0.95, 1.0) if _friendly_to_player else Color(1.0, 0.22, 0.12)
		mat.albedo_color = col
		_light.light_color = col
	_mesh.material_override = mat
