class_name HUDWeaponBar
extends VBoxContainer
## Bottom 1-6 weapon loadout hotbar with active highlight, magazine/battery readout, and reload status.

const WeaponLoadoutRef := preload("res://scripts/game/weapon_loadout.gd")

var _status_lbl: Label
var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _style_selected: StyleBoxFlat
var _style_idle: StyleBoxFlat
var _last_slot_sig: Array[String] = []
var _last_slot_sel: Array[int] = []
var _last_status_txt: String = "__init__"


func build() -> void:
	_ensure_styles()
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
		_last_slot_sig.append("")
		_last_slot_sel.append(-1)


func get_slot_count() -> int:
	return _slot_panels.size()


func refresh(lo: WeaponLoadoutRef) -> void:
	if lo == null or _status_lbl == null:
		return
	_ensure_styles()
	var sel_hud := lo.get_slot_hud_state(lo.get_selected_slot())
	var status_txt := ""
	if bool(sel_hud.get("is_reloading", false)):
		status_txt = "RECARREGANDO... %d%%" % roundi(float(sel_hud.get("reload_progress", 0.0)) * 100.0)
	elif bool(sel_hud.get("is_overheated", false)):
		status_txt = "SUPERAQUECIDO — AGUARDE OU [R] RESFRIAR"
	if status_txt != _last_status_txt:
		_last_status_txt = status_txt
		_status_lbl.text = status_txt

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
		var full_txt := "[%d] %s\n%s" % [i + 1, label_name, ammo_txt]
		if _last_slot_sig[i] != full_txt:
			_last_slot_sig[i] = full_txt
			_slot_labels[i].text = full_txt
		var sel := 1 if bool(st["is_selected"]) else 0
		if _last_slot_sel[i] != sel:
			_last_slot_sel[i] = sel
			_slot_panels[i].add_theme_stylebox_override("panel", _style_selected if sel == 1 else _style_idle)


func _ensure_styles() -> void:
	if _style_selected == null:
		_style_selected = StyleBoxFlat.new()
		_style_selected.bg_color = Color(0.10, 0.22, 0.34, 0.92)
		_style_selected.border_color = Color(0.22, 0.85, 1.0)
		_style_selected.set_border_width_all(2)
		_style_selected.set_corner_radius_all(6)
	if _style_idle == null:
		_style_idle = StyleBoxFlat.new()
		_style_idle.bg_color = Color(0.06, 0.09, 0.14, 0.78)
		_style_idle.border_color = Color(0.30, 0.38, 0.48)
		_style_idle.set_border_width_all(1)
		_style_idle.set_corner_radius_all(6)
