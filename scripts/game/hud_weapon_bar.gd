class_name HUDWeaponBar
extends VBoxContainer
## Bottom 1-6 weapon loadout hotbar with active highlight, magazine/battery readout, and reload status.

const WeaponLoadoutRef := preload("res://scripts/game/weapon_loadout.gd")

var _status_lbl: Label
var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []


func build() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 300.0
	offset_right = -40.0
	offset_top = -105.0
	offset_bottom = -14.0

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 14)
	_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25))
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status_lbl)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	for i in range(7):
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(114.0, 56.0)
		var l := Label.new()
		l.text = "[%d]" % (i + 1)
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(l)
		bar.add_child(p)
		_slot_panels.append(p)
		_slot_labels.append(l)


func get_slot_count() -> int:
	return _slot_panels.size()


func refresh(lo: WeaponLoadoutRef) -> void:
	if lo == null or _status_lbl == null:
		return
	var sel_hud := lo.get_slot_hud_state(lo.get_selected_slot())
	if bool(sel_hud.get("is_reloading", false)):
		_status_lbl.text = "RECARREGANDO... %d%%" % roundi(float(sel_hud.get("reload_progress", 0.0)) * 100.0)
	elif bool(sel_hud.get("is_overheated", false)):
		_status_lbl.text = "SUPERAQUECIDO — AGUARDE OU [R] RESFRIAR"
	else:
		_status_lbl.text = ""

	for i in range(_slot_panels.size()):
		var st := lo.get_slot_hud_state(i + 1)
		if st.is_empty():
			continue
		var ammo_txt := "∞"
		var at := str(st["ammo_type"])
		if at == "magazine":
			ammo_txt = "%d / %d" % [int(st["mag"]), int(st["reserve"])]
		elif at == "battery":
			ammo_txt = "%d%%" % roundi((float(st["battery"]) / maxf(1.0, float(st["battery_max"]))) * 100.0)
		var label_name := "SNIPER" if str(st.get("id", "")) == "sniper" else str(st["display_name"])
		_slot_labels[i].text = "[%d] %s\n%s" % [i + 1, label_name, ammo_txt]
		var box := StyleBoxFlat.new()
		var sel := bool(st["is_selected"])
		box.bg_color = Color(0.10, 0.22, 0.34, 0.92) if sel else Color(0.06, 0.09, 0.14, 0.78)
		box.border_color = Color(0.22, 0.85, 1.0) if sel else Color(0.30, 0.38, 0.48)
		box.set_border_width_all(2 if sel else 1)
		box.set_corner_radius_all(6)
		_slot_panels[i].add_theme_stylebox_override("panel", box)
