extends SceneTree
## Headless verification for ArenaElevators, ranged elevator spawning, and enemy platform stability.

const ArenaElevatorsRef := preload("res://scripts/game/arena_elevators.gd")
const BalanceDBRef := preload("res://scripts/game/balance_db.gd")
const WaveSpawnerRef := preload("res://scripts/game/wave_spawner.gd")

var _failed := 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("ASSERTION FAILED: " + msg)
		_failed += 1


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var root := Node3D.new()
	get_root().add_child(root)

	var elev := ArenaElevatorsRef.new()
	root.add_child(elev)

	_check(elev.get_platform_count() == 4, "Expected 4 elevator platforms")

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var spawn_p := elev.get_ranged_spawn_position(rng)
	_check(spawn_p != Vector3.ZERO, "get_ranged_spawn_position must return non-zero")
	_check(elev.is_on_elevator(spawn_p), "get_ranged_spawn_position must be on an elevator")
	_check(not elev.is_on_elevator(Vector3.ZERO), "Origin (0,0,0) must not be on an elevator")

	# Verify platform radii are within 12m-20m and sync_to_physics is enabled
	var bodies := get_nodes_in_group("elevator_platforms")
	_check(bodies.size() == 4, "Expected 4 bodies in elevator_platforms group")
	var initial_ys: Array[float] = []
	for b in bodies:
		var ab := b as AnimatableBody3D
		_check(ab != null and ab.sync_to_physics, "Platform must be AnimatableBody3D with sync_to_physics=true")
		var r := Vector2(ab.global_position.x, ab.global_position.z).length()
		_check(r >= 12.0 and r <= 20.0, "Platform radius %.2f must be in [12, 20]" % r)
		initial_ys.append(ab.position.y)

	# Advance physics frames and verify vertical movement within [0.35, 4.2]
	for _i in range(30):
		await physics_frame
	var moved := false
	for i in range(bodies.size()):
		var ab := bodies[i] as AnimatableBody3D
		_check(ab.position.y >= 0.34 and ab.position.y <= 4.21, "Platform Y %.2f out of bounds" % ab.position.y)
		if absf(ab.position.y - initial_ys[i]) > 0.01:
			moved = true
	_check(moved, "Platforms must move vertically over physics ticks")

	# Verify WaveSpawner spawns some droid_tall on elevators and never droid_small
	var db := BalanceDBRef.new()
	db.load_from_file("res://data/game_balance.json")
	var entities := Node3D.new()
	root.add_child(entities)
	var player := Node3D.new()
	player.position = Vector3.ZERO
	root.add_child(player)

	var spawner := WaveSpawnerRef.new()
	spawner.droid_small_scene = load("res://scenes/game/droid_small_enemy.tscn")
	spawner.droid_tall_scene = load("res://scenes/game/droid_tall_enemy.tscn")
	root.add_child(spawner)
	spawner.setup(db, entities, player)
	spawner.set_rng_seed(1337)

	var tall_on_elev := 0
	for _k in range(24):
		spawner.call("_spawn_enemy", "droid_tall")
	for child in entities.get_children():
		if child is Node3D and elev.is_on_elevator((child as Node3D).global_position):
			tall_on_elev += 1
	_check(tall_on_elev >= 1, "Expected at least 1 of 24 droid_tall spawns on an elevator, got %d" % tall_on_elev)

	# Verify a droid_tall placed on a platform stays on it over physics frames
	var test_droid := spawner.droid_tall_scene.instantiate() as CharacterBody3D
	entities.add_child(test_droid)
	var plat_pos := elev.get_ranged_spawn_position(rng)
	test_droid.global_position = plat_pos
	test_droid.call("configure_from_balance", "droid_tall", db, {"wave": 1}, player)
	for _f in range(30):
		await physics_frame
	_check(elev.is_on_elevator(test_droid.global_position, 0.5), "Enemy on elevator must stay on elevator without falling off")

	if _failed == 0:
		print("ALL_TESTS_PASSED: test_arena_elevators")
		quit(0)
	else:
		print("FAILED_TESTS: %d" % _failed)
		quit(1)
