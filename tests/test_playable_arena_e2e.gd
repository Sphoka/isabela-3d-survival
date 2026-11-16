extends SceneTree

const ArenaScene := preload("res://scenes/game/playable_arena.tscn")
const GameManagerRef := preload("res://scripts/game/game_manager.gd")
const ProjectileRef := preload("res://scripts/game/projectile_controller.gd")
const PickupCrateRef := preload("res://scripts/game/pickup_crate.gd")


func _initialize() -> void:
	call_deferred("_run_e2e")


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("E2E ASSERTION FAILED: " + msg)
		quit(1)
		return false
	return true


func _step_frames(n: int) -> void:
	for _i in range(n):
		await physics_frame


func _run_e2e() -> void:
	var arena := ArenaScene.instantiate()
	arena.set("capture_mouse", false)
	arena.call("set_interactive_mouse_capture", false)
	root.add_child(arena)
	current_scene = arena

	var gm = arena.get("game_manager")
	var player = arena.get("player")
	var spawner = arena.get("wave_spawner")
	var hud = arena.get("hud")
	var entities := arena.get_node("Entities") as Node3D

	if not _check(gm != null and player != null and spawner != null and hud != null, "Arena failed to bind core nodes"):
		return

	# Wait for Wave 1 first droid spawn (~0.3s + interval)
	for _tick in range(120):
		await physics_frame
		if get_nodes_in_group("enemies").size() >= 2:
			break
	if not _check(get_nodes_in_group("enemies").size() >= 1, "Wave 1 must spawn droid_small_enemy instances"):
		return

	# Verify player dash + water ripple emission
	if not _check(player.try_start_dash(Vector3.FORWARD), "Player must be able to dash"):
		return
	await _step_frames(6)

	# Place d1 cleanly in front of player and flush PhysicsServer3D transform before raycasting
	var d1 = get_nodes_in_group("enemies")[0] as CharacterBody3D
	d1.global_position = player.global_position + Vector3(0.0, 0.0, -5.0)
	d1.velocity = Vector3.ZERO
	await _step_frames(2)
	d1.global_position = player.global_position + Vector3(0.0, 0.0, -5.0)
	await _step_frames(1)
	var hp1_before: float = d1.current_hp

	# 1. Pistol hitscan shot toward d1
	gm.loadout.select_slot(1)
	var wm = player.get_node("WeaponManager")
	wm.refresh_equipped_mesh()
	var pistol_shot: Dictionary = gm.loadout.try_fire(false)
	wm.execute_shot(pistol_shot, {"origin": player.global_position + Vector3(0, 1.3, 0), "target": d1.global_position + Vector3(0, 0.5, 0), "forward": Vector3.FORWARD})
	if not _check(d1.current_hp < hp1_before, "Pistol hitscan ray must damage droid in front"):
		return

	# 1b. Shotgun pellet blast toward d1 (high close-range burst may kill d1 outright)
	gm.loadout.select_slot(3)
	wm.refresh_equipped_mesh()
	await _step_frames(2)
	var hp1_pre_shotgun: float = d1.current_hp
	var shotgun_shot: Dictionary = gm.loadout.try_fire(false)
	wm.execute_shot(shotgun_shot, {"origin": player.global_position + Vector3(0, 1.3, 0), "target": d1.global_position + Vector3(0, 0.5, 0), "forward": Vector3.FORWARD})
	await _step_frames(1)
	if not _check((not is_instance_valid(d1)) or d1.current_hp < hp1_pre_shotgun, "Shotgun pellets must damage or kill droid in front"):
		return

	# 1c. Katana melee cone cleave at close range (use dedicated target dummy so Wave 1 spawner count stays exact)
	var droid_tall_ps: PackedScene = load("res://scenes/game/droid_tall_enemy.tscn")
	var test_dummy := droid_tall_ps.instantiate() as CharacterBody3D
	test_dummy.position = entities.to_local(player.global_position + Vector3(0.0, 0.0, -1.8))
	entities.add_child(test_dummy)
	test_dummy.global_position = player.global_position + Vector3(0.0, 0.0, -1.8)
	test_dummy.configure_from_balance("droid_tall", gm.balance_db, gm.balance_db.get_wave_spec(2), player)
	test_dummy.max_hp = 500.0
	test_dummy.current_hp = 500.0
	gm.loadout.select_slot(5)
	wm.refresh_equipped_mesh()
	await _step_frames(2)
	var hp_pre_katana: float = test_dummy.current_hp
	var katana_shot: Dictionary = gm.loadout.try_fire(false)
	wm.execute_shot(katana_shot, {"origin": player.global_position + Vector3(0, 1.3, 0), "target": test_dummy.global_position + Vector3(0, 0.5, 0), "forward": Vector3.FORWARD})
	if not _check(test_dummy.current_hp < hp_pre_katana, "Katana melee cleave must damage close droid"):
		return

	# 1d. Health & Ammo world PickupCrate collection check (wait out dash i-frames cleanly first)
	await _step_frames(12)
	player.take_damage(40.0, Vector3.ZERO)
	var hp_damaged: float = player.current_hp
	if not _check(hp_damaged < player.max_hp, "Player take_damage must reduce HP after dash i-frames end"):
		return
	gm.loadout.select_slot(1)
	gm.loadout.start_reload_or_vent()
	gm.loadout.tick(2.0, false)
	var pistol_res_before: int = int(gm.loadout.get_slot_hud_state(1)["reserve"])
	var h_crate := PickupCrateRef.new()
	h_crate.configure("health_crate", gm.balance_db.get_pickup("health_crate"))
	entities.add_child(h_crate)
	h_crate.global_position = player.global_position
	var a_crate := PickupCrateRef.new()
	a_crate.configure("ammo_crate", gm.balance_db.get_pickup("ammo_crate"))
	entities.add_child(a_crate)
	a_crate.global_position = player.global_position
	await _step_frames(3)
	var pistol_res_after: int = int(gm.loadout.get_slot_hud_state(1)["reserve"])
	if not _check(player.current_hp > hp_damaged, "Health crate must heal player (before=%s after=%s)" % [hp_damaged, player.current_hp]):
		return
	if not _check(pistol_res_after > pistol_res_before, "Ammo crate must refill Pistol reserve ammo (before=%s after=%s a_valid=%s a_col=%s cfg=%s same_loadout=%s)" % [pistol_res_before, pistol_res_after, is_instance_valid(a_crate), a_crate._collected if is_instance_valid(a_crate) else true, gm.balance_db.get_pickup("ammo_crate").keys(), player._loadout == gm.loadout]):
		return

	# 2. Sniper Rifle slot 2 equip & fire
	gm.loadout.select_slot(2)
	wm.refresh_equipped_mesh()
	var sniper_shot: Dictionary = gm.loadout.try_fire(true)
	wm.execute_shot(sniper_shot, {"origin": player.global_position + Vector3(0, 1.3, 0), "target": player.global_position + Vector3(0, 1.0, -25.0), "forward": Vector3.FORWARD})
	if not _check(sniper_shot.get("fired", false) and str(sniper_shot.get("id", "")) == "sniper", "Slot 2 Sniper must equip and fire"):
		return

	# 3. LaserGun piercing ray across two lined-up droids
	var tall_dummy := droid_tall_ps.instantiate() as CharacterBody3D
	tall_dummy.position = entities.to_local(player.global_position + Vector3(0.0, 0.0, -9.0))
	entities.add_child(tall_dummy)
	tall_dummy.global_position = player.global_position + Vector3(0.0, 0.0, -9.0)
	tall_dummy.configure_from_balance("droid_tall", gm.balance_db, gm.balance_db.get_wave_spec(2), player)
	test_dummy.global_position = player.global_position + Vector3(0.0, 0.0, -5.0)
	test_dummy.velocity = Vector3.ZERO
	tall_dummy.velocity = Vector3.ZERO
	await _step_frames(2)
	var tall_hp_before: float = tall_dummy.current_hp
	var dummy_hp_before: float = test_dummy.current_hp
	gm.loadout.select_slot(6)
	wm.refresh_equipped_mesh()
	var laser_shot: Dictionary = gm.loadout.try_fire(false)
	var lp: Vector3 = wm._get_muzzle_world_position(laser_shot)
	wm.execute_shot(laser_shot, {"origin": player.global_position + Vector3(0, 1.0, 0), "target": tall_dummy.global_position + Vector3(0, 1.0, 0), "forward": Vector3.FORWARD})
	if not _check(test_dummy.current_hp < dummy_hp_before and tall_dummy.current_hp < tall_hp_before, "LaserGun must pierce both test_dummy and tall_dummy in line (muzzle=%s p=%s td=%s->%s tall=%s->%s fired=%s)" % [lp, player.global_position, dummy_hp_before, test_dummy.current_hp, tall_hp_before, tall_dummy.current_hp, laser_shot.get("fired")]):
		return
	tall_dummy.queue_free()

	# 4. RocketLauncher spawn + splash detonation
	gm.loadout.select_slot(4)
	wm.refresh_equipped_mesh()
	var rocket_shot: Dictionary = gm.loadout.try_fire(false)
	test_dummy.global_position = player.global_position + Vector3(0.0, 0.0, -6.0)
	test_dummy.velocity = Vector3.ZERO
	await _step_frames(2)
	var dummy_pre_rocket: float = test_dummy.current_hp
	wm.execute_shot(rocket_shot, {"origin": player.global_position + Vector3(0, 1.0, 0), "target": test_dummy.global_position + Vector3(0, 0.5, 0), "forward": Vector3.FORWARD})
	await _step_frames(25)
	if not _check((not is_instance_valid(test_dummy)) or test_dummy.current_hp < dummy_pre_rocket, "RocketLauncher projectile must hit/splash droid"):
		return
	if is_instance_valid(test_dummy):
		test_dummy.queue_free()
		await _step_frames(1)

	# 5. Clear remaining Wave 1 enemies cleanly -> verify Level-Up / Wave-Clear 3-Card Upgrade Modal opens
	var saw_modal := false
	var safety := 0
	while gm.current_wave == 1 and not gm._waiting_next_wave and safety < 25:
		safety += 1
		if gm.state == GameManagerRef.State.UPGRADE_MODAL:
			if not _check(hud.is_upgrade_modal_visible() and hud.get_upgrade_card_count() == 3, "Level-up modal must display 3 cards"):
				return
			saw_modal = true
			hud.select_upgrade_card(0)
			await _step_frames(1)
			continue
		var alive := get_nodes_in_group("enemies")
		if not alive.is_empty() and is_instance_valid(alive[0]):
			alive[0].take_damage(9999.0)
		else:
			if not spawner._queue.is_empty():
				spawner._queue.pop_back()
			gm.notify_enemy_killed("droid_small", 18, 100)
		await _step_frames(2)

	if not _check(gm._waiting_next_wave, "Clearing all Wave 1 enemies must enter inter-wave transition"):
		return
	if gm.state == GameManagerRef.State.UPGRADE_MODAL:
		if not _check(hud.is_upgrade_modal_visible() and hud.get_upgrade_card_count() == 3, "Wave-clear modal must display 3 cards"):
			return
		saw_modal = true
		hud.select_upgrade_card(1)
	if not _check(saw_modal, "Clearing Wave 1 / leveling up must open 3-Card Upgrade Modal"):
		return
	while gm.state == GameManagerRef.State.UPGRADE_MODAL:
		hud.select_upgrade_card(0)
	if not _check(not hud.is_upgrade_modal_visible() and gm.state == GameManagerRef.State.PLAYING, "Picking card must close modal and resume"):
		return

	player.heal(player.max_hp)
	for _w2 in range(450):
		await physics_frame
		if gm.current_wave == 2 and get_nodes_in_group("enemies").size() >= 1:
			break
	if not _check(gm.current_wave == 2 and get_nodes_in_group("enemies").size() >= 1, "Wave 2 must start and spawn enemies after countdown (wave=%s state=%s wait=%s timer=%.2f rem=%s enemies=%s)" % [gm.current_wave, gm.state, gm._waiting_next_wave, gm._inter_wave_timer_s, gm.enemies_remaining_in_wave, get_nodes_in_group("enemies").size()]):
		return

	print("E2E_ARENA_PASSED: wave=", gm.current_wave, " level=", gm.level, " score=", gm.score, " kills=", gm.kills)
	quit(0)
