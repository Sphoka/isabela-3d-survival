class_name GameOverModalUI
extends ColorRect
## Roguelite Game Over summary modal showing run stats, favorite weapon, upgrade badges, and Restart/Menu actions.

signal restart_requested()
signal menu_requested()

const WEAPON_LABELS := {
	"pistol": "Pistola Tática",
	"sniper": "Rifle Sniper",
	"shotgun": "Escopeta Tática",
	"rocket_launcher": "Lança-Foguetes",
	"rocket_direct": "Lança-Foguetes",
	"rocket_splash": "Lança-Foguetes",
	"katana": "Katana Térmica",
	"laser_gun": "Rifle Laser",
	"smg": "SMG Automática",
	"deflected_plasma": "Deflexão de Plasma",
	"barrel_explode": "Barris de Plasma",
}

var _subtitle_lbl: Label
var _stats_grid: GridContainer
var _upgrades_box: HFlowContainer
var _restart_btn: Button
var _menu_btn: Button
var _built: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	ensure_built()


func ensure_built() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.03, 0.01, 0.02, 0.86)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660.0, 480.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.07, 0.96)
	sb.border_color = Color(0.92, 0.30, 0.24, 0.92)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 14)
	margin.add_child(root_v)

	var title := Label.new()
	title.text = "VOCÊ MORREU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.98, 0.38, 0.32))
	root_v.add_child(title)

	_subtitle_lbl = Label.new()
	_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_lbl.add_theme_font_size_override("font_size", 15)
	_subtitle_lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.50))
	root_v.add_child(_subtitle_lbl)

	var sep := HSeparator.new()
	root_v.add_child(sep)

	_stats_grid = GridContainer.new()
	_stats_grid.columns = 2
	_stats_grid.add_theme_constant_override("h_separation", 24)
	_stats_grid.add_theme_constant_override("v_separation", 8)
	root_v.add_child(_stats_grid)

	var upg_title := Label.new()
	upg_title.text = "UPGRADES ADQUIRIDOS"
	upg_title.add_theme_font_size_override("font_size", 14)
	upg_title.add_theme_color_override("font_color", Color(0.75, 0.85, 0.96))
	root_v.add_child(upg_title)

	_upgrades_box = HFlowContainer.new()
	_upgrades_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_upgrades_box.add_theme_constant_override("h_separation", 8)
	_upgrades_box.add_theme_constant_override("v_separation", 6)
	root_v.add_child(_upgrades_box)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 18)
	root_v.add_child(btn_row)

	_restart_btn = _make_action_button("JOGAR NOVAMENTE", true)
	_restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	btn_row.add_child(_restart_btn)

	_menu_btn = _make_action_button("MENU PRINCIPAL", false)
	_menu_btn.pressed.connect(func() -> void: menu_requested.emit())
	btn_row.add_child(_menu_btn)


func show_summary(summary: Dictionary) -> void:
	ensure_built()
	var wave := int(summary.get("wave", 1))
	var lvl := int(summary.get("level", 1))
	_subtitle_lbl.text = "ONDA ALCANÇADA: %d   •   NÍVEL %d" % [wave, lvl]

	for c in _stats_grid.get_children():
		c.queue_free()

	var sec := int(summary.get("elapsed_s", 0.0))
	var mins := sec / 60
	var rem_s := sec % 60
	var kills := int(summary.get("kills", 0))
	var ks := int(summary.get("kills_small", 0))
	var kt := int(summary.get("kills_tall", 0))
	var fav_id := str(summary.get("favorite_weapon", "—"))
	var fav_name := str(WEAPON_LABELS.get(fav_id, fav_id))
	var fav_dmg := roundi(float(summary.get("favorite_weapon_dmg", 0.0)))

	_add_stat_row("Tempo Sobrevivido", "%02d:%02d" % [mins, rem_s])
	_add_stat_row("Pontuação Final", "%d pts" % int(summary.get("score", 0)))
	_add_stat_row("Abates Totais", "%d (%d Batedores / %d Sentinelas)" % [kills, ks, kt])
	_add_stat_row("Dano Total Causado", "%d" % roundi(float(summary.get("total_damage", 0.0))))
	_add_stat_row("Arma Mais Letal", "%s (%d dmg)" % [fav_name, fav_dmg] if fav_id != "—" else "—")

	for c in _upgrades_box.get_children():
		c.queue_free()
	var upgs: Dictionary = summary.get("upgrades", {})
	if upgs.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "Nenhum upgrade coletado nesta corrida."
		none_lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
		_upgrades_box.add_child(none_lbl)
	else:
		for uid in upgs.keys():
			_upgrades_box.add_child(_make_upgrade_badge(str(uid), int(upgs[uid])))

	visible = true
	if is_inside_tree() and _restart_btn != null:
		_restart_btn.grab_focus()


func hide_modal() -> void:
	visible = false


func get_restart_button() -> Button:
	return _restart_btn


func get_menu_button() -> Button:
	return _menu_btn


func _add_stat_row(k: String, v: String) -> void:
	var kl := Label.new()
	kl.text = k + ":"
	kl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84))
	_stats_grid.add_child(kl)

	var vl := Label.new()
	vl.text = v
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	_stats_grid.add_child(vl)


func _make_upgrade_badge(uid: String, count: int) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.12, 0.18, 0.92)
	sb.border_color = Color(0.90, 0.68, 0.30, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = "%s ×%d" % [uid.replace("_", " ").capitalize(), count]
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.95, 0.86, 0.64))
	p.add_child(l)
	return p


func _make_action_button(txt: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(210, 44)
	b.focus_mode = Control.FOCUS_ALL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.14, 0.12, 0.90) if primary else Color(0.12, 0.12, 0.16, 0.90)
	sb.border_color = Color(0.95, 0.62, 0.30, 0.9) if primary else Color(0.55, 0.60, 0.70, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	var foc := sb.duplicate() as StyleBoxFlat
	foc.border_color = Color(1.0, 0.90, 0.45, 1.0)
	b.add_theme_stylebox_override("focus", foc)
	b.add_theme_stylebox_override("hover", foc)
	return b
