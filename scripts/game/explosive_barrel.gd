class_name ExplosiveBarrel
extends StaticBody3D
## Destructible sci-fi plasma fuel barrel: deals AoE damage to enemies and chain-detonates neighboring barrels.

const DestructionVFXRef := preload("res://scripts/game/droid_destruction_vfx.gd")

signal exploded(world_pos: Vector3, radius: float)

const EXPLOSION_RADIUS := 6.0
const CHAIN_RADIUS := 5.5
const MAX_ENEMY_DAMAGE := 180.0
const MAX_PLAYER_DAMAGE := 20.0
const RESPAWN_TIME_S := 28.0

var max_hp: float = 40.0
var current_hp: float = 40.0

var _exploded: bool = false
var _respawn_left: float = 0.0
var _pulse_phase: float = 0.0
var _visual_root: Node3D
var _collider: CollisionShape3D
var _glow_light: OmniLight3D
var _core_mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("damageable_props")
	add_to_group("explosive_barrels")
	_ensure_body_and_visual()


func is_exploded() -> bool:
	return _exploded


func take_damage(amount: float, _impulse: Vector3 = Vector3.ZERO, _is_crit: bool = false, _weapon_id: String = "", _armor_pierce: float = 1.0) -> void:
	if _exploded or amount <= 0.0:
		return
	current_hp = maxf(0.0, current_hp - amount)
	if current_hp <= 0.0:
		detonate()
	elif _core_mat != null:
		_core_mat.emission_energy_multiplier = 4.5


func detonate() -> void:
	if _exploded:
		return
	_exploded = true
	_respawn_left = RESPAWN_TIME_S
	if _collider != null:
		_collider.set_deferred("disabled", true)
	if _visual_root != null:
		_visual_root.visible = false

	var origin := global_position if is_inside_tree() else position
	var scene_root := get_tree().current_scene if is_inside_tree() else get_parent()
	if scene_root == null:
		scene_root = get_parent()
	DestructionVFXRef.spawn_explosion_burst(scene_root, origin + Vector3(0.0, 0.75, 0.0), 4.6, Color(1.0, 0.42, 0.14), 16)

	if is_inside_tree():
		_apply_aoe_damage(origin)
		_trigger_chain_reactions(origin)
	exploded.emit(origin, EXPLOSION_RADIUS)


func _process(delta: float) -> void:
	_pulse_phase += delta * 4.2
	if not _exploded:
		if _core_mat != null:
			_core_mat.emission_energy_multiplier = lerpf(_core_mat.emission_energy_multiplier, 1.8 + 0.55 * sin(_pulse_phase), 8.0 * delta)
		if _glow_light != null:
			_glow_light.light_energy = 0.85 + 0.30 * sin(_pulse_phase)
	elif RESPAWN_TIME_S > 0.0:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			_respawn_barrel()


func _apply_aoe_damage(origin: Vector3) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not (node is Node3D) or not node.has_method("take_damage"):
			continue
		var en := node as Node3D
		var d := origin.distance_to(en.global_position)
		if d <= EXPLOSION_RADIUS:
			var t := clampf(d / EXPLOSION_RADIUS, 0.0, 1.0)
			var dmg := lerpf(MAX_ENEMY_DAMAGE, MAX_ENEMY_DAMAGE * 0.35, t)
			var push := (en.global_position - origin).normalized() * 14.0
			en.call("take_damage", dmg, push, true, "barrel_explode", 1.25)

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null and player.has_method("take_damage"):
		var pd := origin.distance_to(player.global_position)
		if pd <= EXPLOSION_RADIUS * 0.72:
			var pt := clampf(pd / (EXPLOSION_RADIUS * 0.72), 0.0, 1.0)
			player.call("take_damage", lerpf(MAX_PLAYER_DAMAGE, 4.0, pt), (player.global_position - origin).normalized() * 5.0)


func _trigger_chain_reactions(origin: Vector3) -> void:
	for node in get_tree().get_nodes_in_group("explosive_barrels"):
		if node == self or not is_instance_valid(node) or not (node is ExplosiveBarrel):
			continue
		var other := node as ExplosiveBarrel
		if not other.is_exploded() and origin.distance_to(other.global_position) <= CHAIN_RADIUS:
			var tmr := get_tree().create_timer(0.14)
			tmr.timeout.connect(func() -> void:
				if is_instance_valid(other) and not other.is_exploded():
					other.detonate()
			)


func _respawn_barrel() -> void:
	_exploded = false
	current_hp = max_hp
	if _collider != null:
		_collider.set_deferred("disabled", false)
	if _visual_root != null:
		_visual_root.visible = true


func _ensure_body_and_visual() -> void:
	if get_node_or_null("CollisionShape3D") == null:
		_collider = CollisionShape3D.new()
		_collider.name = "CollisionShape3D"
		var cyl_col := CylinderShape3D.new()
		cyl_col.radius = 0.40
		cyl_col.height = 1.20
		_collider.shape = cyl_col
		_collider.position = Vector3(0.0, 0.60, 0.0)
		add_child(_collider)
	else:
		_collider = get_node("CollisionShape3D") as CollisionShape3D

	_visual_root = Node3D.new()
	_visual_root.name = "BarrelVisual"
	add_child(_visual_root)

	var shell := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.36
	sc.bottom_radius = 0.38
	sc.height = 1.16
	shell.mesh = sc
	shell.position = Vector3(0.0, 0.58, 0.0)
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.20, 0.22, 0.26)
	hull_mat.metallic = 0.78
	hull_mat.roughness = 0.38
	shell.material_override = hull_mat
	_visual_root.add_child(shell)

	var core := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.375
	cc.bottom_radius = 0.375
	cc.height = 0.34
	core.mesh = cc
	core.position = Vector3(0.0, 0.62, 0.0)
	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = Color(1.0, 0.38, 0.10)
	_core_mat.emission_enabled = true
	_core_mat.emission = Color(1.0, 0.42, 0.10)
	_core_mat.emission_energy_multiplier = 2.0
	core.material_override = _core_mat
	_visual_root.add_child(core)

	_glow_light = OmniLight3D.new()
	_glow_light.light_color = Color(1.0, 0.45, 0.12)
	_glow_light.light_energy = 1.0
	_glow_light.omni_range = 3.2
	_glow_light.position = Vector3(0.0, 0.75, 0.0)
	_visual_root.add_child(_glow_light)
