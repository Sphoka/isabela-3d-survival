extends SceneTree

const BalanceDBScript := preload("res://scripts/game/balance_db.gd")
const WaveSpawnerScript := preload("res://scripts/game/wave_spawner.gd")
const PickupCrateScript := preload("res://scripts/game/pickup_crate.gd")
const ProjectileScript := preload("res://scripts/game/projectile_controller.gd")


func _init() -> void:
	var ok := true
	ok = ok and _test_wave_spawner()
	ok = ok and _test_pickup_crate()
	ok = ok and _test_projectile_controller()
	if not ok:
		push_error("test_spawner_projectiles_pickups FAILED")
		quit(1)
		return
	print("ALL_TESTS_PASSED: test_spawner_projectiles_pickups")
	quit(0)


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("ASSERTION FAILED: " + msg)
		return false
	return true


func _test_wave_spawner() -> bool:
	var db = BalanceDBScript.new()
	db.load_from_file("res://data/game_balance.json")
	var spawner = WaveSpawnerScript.new()
	spawner.setup(db, null, null)
	spawner.set_rng_seed(12345)

	# Wave 2 queue must have 7 small and 2 tall
	var spec2: Dictionary = db.get_wave_spec(2)
	spawner.queue_wave(spec2)
	if not _check(spawner.get_pending_spawn_count() == 9, "Wave 2 pending queue should be 9"):
		spawner.free()
		return false

	var player_pos := Vector3(5.0, 0.0, 5.0)
	for _i in range(25):
		var p: Vector3 = spawner.pick_ring_spawn_position(player_pos)
		var r := Vector2(p.x, p.z).length()
		var d := p.distance_to(player_pos)
		if not _check(r >= 19.9 and r <= 28.1, "Spawn radius out of bounds: " + str(r)):
			spawner.free()
			return false
		if not _check(d >= 9.9, "Spawn too close to player: " + str(d)):
			spawner.free()
			return false

	# Low HP should strongly weight health_crate over ammo_crate
	var health_picks := 0
	for _k in range(100):
		if spawner.choose_crate_type(0.20, 0.90) == "health_crate":
			health_picks += 1
	if not _check(health_picks > 65, "Low HP should favor health_crate drops, got " + str(health_picks)):
		spawner.free()
		return false
	spawner.free()
	return true


func _test_pickup_crate() -> bool:
	var db = BalanceDBScript.new()
	db.load_from_file("res://data/game_balance.json")
	var crate = PickupCrateScript.new()
	crate.configure("health_crate", db.get_pickup("health_crate"))
	if not _check(crate.pickup_id == "health_crate", "Crate ID mismatch"):
		crate.free()
		return false
	var heal: float = crate.compute_heal_amount(120.0)
	if not _check(is_equal_approx(heal, 47.0), "Expected 35 + 10% of 120 = 47 heal, got " + str(heal)):
		crate.free()
		return false
	crate.free()
	return true


func _test_projectile_controller() -> bool:
	var rocket = ProjectileScript.new()
	rocket.configure_rocket(Vector3.ZERO, Vector3.FORWARD, {
		"damage": 30.0,
		"splash_damage": 135.0,
		"splash_radius_m": 4.8,
		"splash_edge_falloff_multiplier": 0.4,
		"self_damage_multiplier": 0.15,
		"projectile_speed_mps": 28.0,
		"knockback_mps": 15.0,
	})
	var center_dmg: float = rocket.compute_splash_damage_at_distance(0.0)
	var edge_dmg: float = rocket.compute_splash_damage_at_distance(4.8)
	var mid_dmg: float = rocket.compute_splash_damage_at_distance(2.4)
	if not _check(is_equal_approx(center_dmg, 135.0), "Center splash should be 135"):
		rocket.free()
		return false
	if not _check(is_equal_approx(edge_dmg, 54.0), "Edge splash should be 40% of 135 = 54"):
		rocket.free()
		return false
	if not _check(mid_dmg > edge_dmg and mid_dmg < center_dmg, "Mid splash must fall off linearly"):
		rocket.free()
		return false
	rocket.free()

	var plasma = ProjectileScript.new()
	plasma.configure_enemy_plasma(Vector3.ZERO, Vector3.BACK, 18.0, 16.0)
	if not _check(not plasma.is_friendly_to_player(), "Enemy plasma starts hostile"):
		plasma.free()
		return false
	plasma.deflect(Vector3.FORWARD, 1.75)
	if not _check(plasma.is_friendly_to_player() and is_equal_approx(plasma.damage, 31.5), "Deflected plasma must flip friendly and boost damage 1.75x"):
		plasma.free()
		return false
	plasma.free()
	return true
