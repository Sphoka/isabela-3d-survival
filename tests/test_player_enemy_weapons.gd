extends SceneTree

const BalanceDBScript := preload("res://scripts/game/balance_db.gd")
const UpgradeSystemScript := preload("res://scripts/game/upgrade_system.gd")
const WeaponLoadoutScript := preload("res://scripts/game/weapon_loadout.gd")
const PlayerControllerScript := preload("res://scripts/game/player_controller.gd")
const PlayerAnimatorScript := preload("res://scripts/game/player_animator.gd")
const WeaponManagerScript := preload("res://scripts/game/weapon_manager.gd")
const EnemyDroidScript := preload("res://scripts/game/enemy_droid.gd")
const ProjectileScript := preload("res://scripts/game/projectile_controller.gd")


func _init() -> void:
	var ok := true
	ok = ok and _test_player_controller()
	ok = ok and _test_player_animator_on_isabela()
	ok = ok and _test_weapon_manager_melee_and_spread()
	ok = ok and _test_enemy_droid()
	if not ok:
		push_error("test_player_enemy_weapons FAILED")
		quit(1)
		return
	print("ALL_TESTS_PASSED: test_player_enemy_weapons")
	quit(0)


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("ASSERTION FAILED: " + msg)
		return false
	return true


func _test_player_controller() -> bool:
	var db = BalanceDBScript.new()
	db.load_from_file("res://data/game_balance.json")
	var upg = UpgradeSystemScript.new(db)
	var loadout = WeaponLoadoutScript.new(db, upg)

	var p = PlayerControllerScript.new()
	p.configure(db, upg, loadout)
	if not _check(is_equal_approx(p.max_hp, 120.0) and is_equal_approx(p.current_hp, 120.0), "Player initial HP must be 120"):
		p.free()
		return false

	# Shallow water drag speed check
	var water_speed: float = p.compute_move_speed(false, false, 0.0)
	var air_speed: float = p.compute_move_speed(false, false, 0.5)
	if not _check(water_speed < air_speed and is_equal_approx(water_speed, 5.8 * 0.94), "Shallow water drag mismatch"):
		p.free()
		return false

	# Dash triggers iframes blocking incoming damage
	if not _check(p.try_start_dash(Vector3.FORWARD), "Dash should succeed with 1 base charge"):
		p.free()
		return false
	p.take_damage(30.0, Vector3.BACK)
	if not _check(is_equal_approx(p.current_hp, 120.0), "Dash iframes must block damage"):
		p.free()
		return false

	# Expire iframes and verify damage + health crate heal
	p.step_timers(0.5)
	p.take_damage(50.0, Vector3.BACK)
	if not _check(is_equal_approx(p.current_hp, 70.0), "Damage after iframes should leave 70 HP"):
		p.free()
		return false
	p.apply_pickup("health_crate", db.get_pickup("health_crate"))
	if not _check(is_equal_approx(p.current_hp, 117.0), "Health crate should heal 70 + 47 = 117 HP"):
		p.free()
		return false

	p.free()
	return true


func _test_player_animator_on_isabela() -> bool:
	var ps: PackedScene = load("res://assets/SK_Isabela/SK_Isabela.glb")
	var isabela := ps.instantiate() as Node3D
	var anim = PlayerAnimatorScript.new()
	anim.bind_isabela(isabela)
	if not _check(anim.get_skeleton() != null and anim.get_weapon_socket() != null, "Animator must locate Skeleton3D and create WeaponSocket"):
		anim.free()
		isabela.free()
		return false

	anim.apply_pose(0.1, Vector3(0.0, 0.0, -5.0), true, false, 0.0, 0.0, 0, "pistol")
	var sk: Skeleton3D = anim.get_skeleton()
	var idx := sk.find_bone("RightUpperArm")
	if not _check(idx != -1, "Missing RightUpperArm"):
		anim.free()
		isabela.free()
		return false
	anim.free()
	isabela.free()
	return true


func _test_weapon_manager_melee_and_spread() -> bool:
	var wm = WeaponManagerScript.new()
	var dir: Vector3 = wm.apply_spread(Vector3.FORWARD, 0.0)
	if not _check(dir.is_equal_approx(Vector3.FORWARD), "Zero spread must preserve exact direction"):
		wm.free()
		return false

	# Test cone geometry check
	if not _check(wm.is_point_in_melee_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0.5, 0.5, -2.0), 2.75, 135.0), "Target in front within 2.75m must be inside melee cone"):
		wm.free()
		return false
	if not _check(not wm.is_point_in_melee_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 0.5, 2.0), 2.75, 135.0), "Target behind player must NOT be inside melee cone"):
		wm.free()
		return false

	# Test Lightsaber projectile deflection on standalone projectile
	var plasma = ProjectileScript.new()
	plasma.configure_enemy_plasma(Vector3(0.0, 1.0, -1.5), Vector3.BACK, 18.0, 16.0)
	var deflected: int = wm.deflect_projectiles_in_cone([plasma], Vector3(0.0, 1.0, 0.0), Vector3.FORWARD, 2.75, 135.0, 1.75)
	if not _check(deflected == 1 and plasma.is_friendly_to_player(), "Lightsaber cone must deflect hostile plasma bolt"):
		plasma.free()
		wm.free()
		return false
	plasma.free()
	wm.free()
	return true


func _test_enemy_droid() -> bool:
	var db = BalanceDBScript.new()
	db.load_from_file("res://data/game_balance.json")
	var tall = EnemyDroidScript.new()
	tall.configure_from_balance("droid_tall", db, db.get_wave_spec(2), null)
	# Wave 2 HP mult is 1.18 * 180 = 212.4
	if not _check(is_equal_approx(tall.max_hp, 180.0 * 1.18), "Tall droid Wave 2 HP mismatch: " + str(tall.max_hp)):
		tall.free()
		return false
	var hp_before: float = tall.current_hp
	tall.take_damage(40.0, Vector3(10.0, 0.0, 0.0), false, "katana", 1.25)
	if not _check(is_equal_approx(tall.current_hp, hp_before - 50.0), "Katana 1.25x armor pierce must deal 50 damage to Tall droid"):
		tall.free()
		return false
	tall.free()
	return true
