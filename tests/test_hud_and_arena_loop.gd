extends SceneTree

const GameManagerScript := preload("res://scripts/game/game_manager.gd")
const PlayerControllerScript := preload("res://scripts/game/player_controller.gd")
const HUDControllerScript := preload("res://scripts/game/hud_controller.gd")
const ArenaCoordinatorScript := preload("res://scripts/game/arena_coordinator.gd")


func _init() -> void:
	var ok := true
	ok = ok and _test_hud_and_modal()
	ok = ok and _test_arena_coordinator_headless()
	if not ok:
		push_error("test_hud_and_arena_loop FAILED")
		quit(1)
		return
	print("ALL_TESTS_PASSED: test_hud_and_arena_loop")
	quit(0)


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("ASSERTION FAILED: " + msg)
		return false
	return true


func _test_hud_and_modal() -> bool:
	var host := Node3D.new()
	root.add_child(host)

	var gm = GameManagerScript.new()
	host.add_child(gm)
	gm.initialize("res://data/game_balance.json", 99)

	var player = PlayerControllerScript.new()
	host.add_child(player)
	player.configure(gm.balance_db, gm.upgrades, gm.loadout)

	var hud = HUDControllerScript.new()
	host.add_child(hud)
	hud.bind(gm, player)
	gm.start_run(false)

	if not _check(hud.get_weapon_slot_count() == 7, "HUD must render 7 weapon hotbar slots"):
		host.queue_free()
		return false
	if not _check(not hud.is_upgrade_modal_visible(), "Upgrade modal starts hidden"):
		host.queue_free()
		return false

	# Clear wave 1 -> modal opens with 3 cards
	for _i in range(6):
		gm.notify_enemy_killed("droid_small", 18, 100)
	if not _check(hud.is_upgrade_modal_visible() and hud.get_upgrade_card_count() == 3, "Wave 1 clear must display 3-card upgrade modal"):
		host.queue_free()
		return false

	# Simulate clicking card 0
	hud.select_upgrade_card(0)
	if not _check(not hud.is_upgrade_modal_visible() and gm.state == GameManagerScript.State.PLAYING, "Selecting card must hide modal and resume PLAYING"):
		host.queue_free()
		return false

	host.queue_free()
	return true


func _test_arena_coordinator_headless() -> bool:
	var arena := Node3D.new()
	arena.set_script(ArenaCoordinatorScript)
	root.add_child(arena)
	arena.call("set_interactive_mouse_capture", false)
	arena.call("bootstrap_headless_arena")

	var gm = arena.get("game_manager")
	var spawner = arena.get("wave_spawner")
	if not _check(gm != null and spawner != null, "ArenaCoordinator must initialize GameManager and WaveSpawner"):
		arena.queue_free()
		return false
	if not _check(gm.current_wave == 1 and spawner.get_pending_spawn_count() == 6, "Wave 1 must queue 6 droids"):
		arena.queue_free()
		return false
	arena.queue_free()
	return true
