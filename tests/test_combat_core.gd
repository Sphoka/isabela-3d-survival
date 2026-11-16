extends SceneTree

const BalanceDBScript := preload("res://scripts/game/balance_db.gd")
const UpgradeSystemScript := preload("res://scripts/game/upgrade_system.gd")
const InputSetupScript := preload("res://scripts/game/input_setup.gd")
const WeaponLoadoutScript := preload("res://scripts/game/weapon_loadout.gd")
const GameManagerScript := preload("res://scripts/game/game_manager.gd")


func _init() -> void:
	var ok := true
	ok = ok and _test_input_setup()
	ok = ok and _test_weapon_loadout()
	ok = ok and _test_game_manager()
	if not ok:
		push_error("test_combat_core FAILED")
		quit(1)
		return
	print("ALL_TESTS_PASSED: test_combat_core")
	quit(0)


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("ASSERTION FAILED: " + msg)
		return false
	return true


func _test_input_setup() -> bool:
	InputSetupScript.ensure_default_actions()
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "dash", "fire", "aim", "reload", "weapon_1", "weapon_6", "weapon_next", "pause"]:
		if not _check(InputMap.has_action(action), "Missing InputMap action: " + action):
			return false
	return true


func _test_weapon_loadout() -> bool:
	var db = BalanceDBScript.new()
	db.load_from_file("res://data/game_balance.json")
	var upg = UpgradeSystemScript.new(db)
	var loadout = WeaponLoadoutScript.new(db, upg)

	# Slot 1 Pistol fire + reload
	if not _check(loadout.get_selected_slot() == 1, "Initial slot must be 1"):
		return false
	var shot1: Dictionary = loadout.try_fire()
	if not _check(shot1.get("fired", false) and str(shot1.get("id", "")) == "pistol", "Pistol must fire"):
		return false
	var hud1: Dictionary = loadout.get_slot_hud_state(1)
	if not _check(int(hud1["mag"]) == 14, "Pistol mag should decrement to 14"):
		return false

	loadout.start_reload_or_vent()
	if not _check(bool(loadout.get_slot_hud_state(1)["is_reloading"]), "Pistol should be reloading"):
		return false
	loadout.tick(1.25, false)
	if not _check(not bool(loadout.get_slot_hud_state(1)["is_reloading"]) and int(loadout.get_slot_hud_state(1)["mag"]) == 15, "Pistol reload should refill mag to 15"):
		return false

	# Slot 2 Sniper Rifle high headshot multiplier & tight ADS spread
	loadout.select_slot(2)
	var sniper: Dictionary = loadout.try_fire(true)
	if not _check(sniper.get("fired", false) and str(sniper.get("id", "")) == "sniper" and float(sniper.get("headshot_multiplier", 1.0)) >= 3.0 and float(sniper.get("spread_deg", 1.0)) <= 0.05, "Sniper must fire with high headshot multiplier and tight ADS spread"):
		return false

	# Slot 5 Katana 3-hit combo progression
	loadout.select_slot(5)
	var k1: Dictionary = loadout.try_fire()
	loadout.tick(0.4, false)
	var k2: Dictionary = loadout.try_fire()
	loadout.tick(0.4, false)
	var k3: Dictionary = loadout.try_fire()
	if not _check(k1.get("combo_step", 0) == 1 and k2.get("combo_step", 0) == 2 and k3.get("combo_step", 0) == 3, "Katana 3-hit combo mismatch"):
		return false
	if not _check(float(k3.get("base_damage", 0.0)) > float(k1.get("base_damage", 0.0)), "Katana 3rd hit must deal more damage"):
		return false

	# Slot 6 LaserGun battery drain, overheat, manual vent & ammo crate restore
	loadout.select_slot(6)
	for _i in range(23):
		loadout.tick(0.11, true)
		loadout.try_fire()
	var hud6: Dictionary = loadout.get_slot_hud_state(6)
	if not _check(bool(hud6["is_overheated"]), "LaserGun must overheat after continuous drain"):
		return false
	loadout.refill_ammo_percent(0.4, 1.0)
	hud6 = loadout.get_slot_hud_state(6)
	if not _check(not bool(hud6["is_overheated"]) and float(hud6["battery"]) >= 99.9, "Ammo crate must clear overheat and restore 100% laser battery"):
		return false
	return true


func _test_game_manager() -> bool:
	var gm = GameManagerScript.new()
	gm.initialize("res://data/game_balance.json", 777)
	gm.start_run(false) # do not mutate SceneTree pause inside headless SceneTree script test
	if not _check(gm.current_wave == 1 and gm.enemies_remaining_in_wave == 6, "Wave 1 must start with 6 enemies"):
		gm.free()
		return false

	# Kill 6 small droids -> wave clear triggers modal
	for _i in range(6):
		gm.notify_enemy_killed("droid_small", 18, 100)
	if not _check(gm.state == GameManagerScript.State.UPGRADE_MODAL, "Wave 1 clear must open Upgrade Modal"):
		gm.free()
		return false
	if not _check(gm.current_choices.size() == 3, "Upgrade modal must have 3 choices"):
		gm.free()
		return false
	if not _check(gm.level >= 2, "Wave 1 XP + clear bonus (133 XP) must reach >= Level 2"):
		gm.free()
		return false

	gm.choose_upgrade(0)
	if not _check(gm.state == GameManagerScript.State.PLAYING, "Selecting last pending upgrade must return to PLAYING"):
		gm.free()
		return false
	# Advance inter-wave countdown -> Wave 2 starts
	gm.tick(3.0)
	if not _check(gm.current_wave == 2 and gm.enemies_remaining_in_wave == 9, "Wave 2 must start with 9 enemies"):
		gm.free()
		return false
	gm.free()
	return true
