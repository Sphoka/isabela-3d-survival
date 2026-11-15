extends SceneTree

const BalanceDBScript := preload("res://scripts/game/balance_db.gd")
const UpgradeSystemScript := preload("res://scripts/game/upgrade_system.gd")


func _init() -> void:
	var failed := false
	failed = failed or not _test_balance_db()
	failed = failed or not _test_upgrade_system()
	if failed:
		push_error("test_balance_and_upgrades FAILED")
		quit(1)
		return
	print("ALL_TESTS_PASSED: test_balance_and_upgrades")
	quit(0)


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("ASSERTION FAILED: " + msg)
		return false
	return true


func _test_balance_db() -> bool:
	var db = BalanceDBScript.new()
	if not _check(db.load_from_file("res://data/game_balance.json"), "BalanceDB failed to load json"):
		return false
	if not _check(db.get_all_weapons().size() == 7, "Expected 7 weapons"):
		return false
	if not _check(db.get_weapon_by_slot(1).get("asset_name", "") == "SM_Weapon_Pistol", "Slot 1 mismatch"):
		return false
	if not _check(db.get_weapon_by_slot(6).get("asset_name", "") == "SM_Weapon_LaserGun", "Slot 6 mismatch"):
		return false
	if not _check(db.get_weapon_by_slot(7).get("asset_name", "") == "SM_Weapon_SMG", "Slot 7 SMG mismatch"):
		return false
	if not _check(db.get_pickup("health_crate").get("asset_name", "") == "SM_Crate_Health", "Health crate mismatch"):
		return false
	if not _check(db.get_pickup("ammo_crate").get("asset_name", "") == "SM_Crate_Ammo", "Ammo crate mismatch"):
		return false

	var w1: Dictionary = db.get_wave_spec(1)
	if not _check(int(w1["total_enemies"]) == 6 and int(w1["tall_count"]) == 0 and int(w1["small_count"]) == 6, "Wave 1 counts mismatch"):
		return false
	var w2: Dictionary = db.get_wave_spec(2)
	if not _check(int(w2["total_enemies"]) == 9 and int(w2["tall_count"]) >= 1, "Wave 2 must introduce Tall droids"):
		return false
	var w5: Dictionary = db.get_wave_spec(5)
	if not _check(int(w5["total_enemies"]) == 20 and float(w5["hp_multiplier"]) > 1.7, "Wave 5 scaling mismatch"):
		return false
	if not _check(db.get_xp_for_next_level(1) == 80, "Level 1->2 XP should be 80"):
		return false
	if not _check(db.get_xp_for_next_level(2) > 80, "Level 2->3 XP should exceed 80"):
		return false
	return true


func _test_upgrade_system() -> bool:
	var db = BalanceDBScript.new()
	if not _check(db.load_from_file("res://data/game_balance.json"), "BalanceDB load failed"):
		return false
	var upg = UpgradeSystemScript.new(db)
	if not _check(is_equal_approx(upg.get_stat("damage_multiplier"), 1.0), "Initial damage_multiplier should be 1.0"):
		return false

	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var choices: Array[Dictionary] = upg.roll_choices(3, rng)
	if not _check(choices.size() == 3, "Expected 3 upgrade choices"):
		return false
	var seen_ids := {}
	for c in choices:
		var uid := str(c["id"])
		if not _check(not seen_ids.has(uid), "Duplicate upgrade card in single draft: " + uid):
			return false
		seen_ids[uid] = true

	var hp_card := {
		"id": "max_hp_heal",
		"rarity": "rare",
		"rarity_label": "Raro",
		"color_hex": "#38BDF8",
		"multiplier": 1.5,
		"resolved_value": 37.5,
	}
	var res: Dictionary = upg.apply_upgrade(hp_card)
	if not _check(is_equal_approx(upg.get_stat("max_hp_bonus"), 37.5), "max_hp_bonus should be 37.5"):
		return false
	if not _check(is_equal_approx(float(res.get("heal_amount", 0.0)), 37.5), "heal_amount should be 37.5"):
		return false

	var dash_epic := {
		"id": "dash_recharge",
		"rarity": "epic",
		"rarity_label": "Épico",
		"color_hex": "#C084FC",
		"multiplier": 2.1,
		"resolved_value": 0.378,
	}
	upg.apply_upgrade(dash_epic)
	if not _check(int(upg.get_stat("dash_extra_charges")) == 1, "Epic dash_recharge must grant +1 extra dash charge"):
		return false
	if not _check(upg.get_effective_dash_cooldown(1.60, 0.45) < 1.60, "Dash cooldown must decrease"):
		return false

	# Verify max_stacks saturation never breaks roll_choices
	for _i in range(20):
		var batch: Array[Dictionary] = upg.roll_choices(6, rng)
		if batch.is_empty():
			break
		upg.apply_upgrade(batch[0])
	return true
