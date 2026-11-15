class_name PickupCrate
extends Area3D
## Floating, rotating health or ammo supply crate with magnetic pull and collection FX.

signal collected(pickup_id: String, collector: Node3D)

var pickup_id: String = "health_crate"
var _cfg: Dictionary = {}
var _visual_root: Node3D
var _light: OmniLight3D
var _age_s: float = 0.0
var _collected: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitorable = true
	monitoring = true
	if get_node_or_null("CollisionShape3D") == null:
		var cs := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = float(_cfg.get("trigger_radius_m", 1.35))
		cs.shape = sphere
		cs.position = Vector3(0.0, 0.25, 0.0)
		add_child(cs)
	body_entered.connect(_on_body_entered)


func configure(id: String, cfg: Dictionary) -> void:
	pickup_id = id
	_cfg = cfg
	_ensure_visual()


func compute_heal_amount(max_hp: float) -> float:
	return float(_cfg.get("heal_flat", 35.0)) + max_hp * float(_cfg.get("heal_max_hp_percent", 0.10))


func _process(delta: float) -> void:
	if _collected:
		return
	_age_s += delta
	var ttl := float(_cfg.get("lifetime_s", 45.0))
	if _age_s >= ttl:
		queue_free()
		return

	if _visual_root != null:
		var bob_h := float(_cfg.get("bob_height_m", 0.14))
		var bob_a := float(_cfg.get("bob_amplitude_m", 0.08))
		var bob_f := float(_cfg.get("bob_frequency_hz", 1.8))
		_visual_root.position.y = bob_h + sin(_age_s * TAU * bob_f) * bob_a
		_visual_root.rotate_y(deg_to_rad(float(_cfg.get("spin_deg_per_sec", 75.0))) * delta)
		if ttl - _age_s < 3.0:
			_visual_root.visible = int(_age_s * 10.0) % 2 == 0

	var player := get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
	if player != null:
		var flat_delta := Vector3(player.global_position.x - global_position.x, 0.0, player.global_position.z - global_position.z)
		var dist := flat_delta.length()
		var trigger_r := float(_cfg.get("trigger_radius_m", 1.35))
		var magnet_r := float(_cfg.get("magnet_radius_m", 2.60))
		if dist <= trigger_r:
			_collect(player)
		elif dist <= magnet_r and dist > 0.001:
			global_position += (flat_delta / dist) * 7.5 * delta


func _on_body_entered(body: Node3D) -> void:
	if not _collected and body != null and body.is_in_group("player"):
		_collect(body)


func _collect(player: Node3D) -> void:
	_collected = true
	if player.has_method("apply_pickup"):
		player.call("apply_pickup", pickup_id, _cfg)
	collected.emit(pickup_id, player)
	queue_free()


func _ensure_visual() -> void:
	if _visual_root != null:
		_visual_root.queue_free()
	_visual_root = Node3D.new()
	_visual_root.name = "CrateVisual"
	add_child(_visual_root)

	var asset_path := str(_cfg.get("asset_path", ""))
	if not asset_path.is_empty() and ResourceLoader.exists(asset_path):
		var ps := load(asset_path) as PackedScene
		if ps != null:
			_visual_root.add_child(ps.instantiate())
	elif not asset_path.is_empty():
		push_warning("PickupCrate: asset not found yet at '%s'" % asset_path)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.15, 1.0, 0.45) if pickup_id == "health_crate" else Color(1.0, 0.72, 0.18)
	_light.light_energy = 1.6
	_light.omni_range = 3.2
	_light.position = Vector3(0.0, 0.35, 0.0)
	_visual_root.add_child(_light)
