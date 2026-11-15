class_name PauseModalUI
extends ColorRect
## Complete In-Game Pause modal with Resume, Settings, Restart, Main Menu, and active upgrade summary.

signal resume_requested()
signal settings_requested()
signal restart_requested()
signal menu_requested()

var _stats_lbl: Label
var _upgrades_lbl: Label
var _resume_btn: Button
var _settings_btn: Button
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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Color(0.02, 0.02, 0.04, 0.78)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -220.0
	panel.offset_top = -185.0
	panel.offset_right = 220.0
	panel.offset_bottom = 185.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09, 0.96)
	sb.border_color = Color(0.88, 0.66, 0.30, 0.90)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var title := Label.new()
	title.text = "PAUSADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.96, 0.80, 0.44))
	v.add_child(title)

	_stats_lbl = Label.new()
	_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_lbl.add_theme_font_size_override("font_size", 14)
	_stats_lbl.add_theme_color_override("font_color", Color(0.82, 0.90, 0.98))
	v.add_child(_stats_lbl)

	_upgrades_lbl = Label.new()
	_upgrades_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrades_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrades_lbl.add_theme_font_size_override("font_size", 12)
	_upgrades_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	v.add_child(_upgrades_lbl)

	var sep := HSeparator.new()
	v.add_child(sep)

	_resume_btn = _make_btn("CONTINUAR")
	_resume_btn.pressed.connect(func() -> void: resume_requested.emit())
	v.add_child(_resume_btn)

	_settings_btn = _make_btn("CONFIGURAÇÕES")
	_settings_btn.pressed.connect(func() -> void: settings_requested.emit())
	v.add_child(_settings_btn)

	_restart_btn = _make_btn("REINICIAR PARTIDA")
	_restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	v.add_child(_restart_btn)

	_menu_btn = _make_btn("MENU PRINCIPAL")
	_menu_btn.pressed.connect(func() -> void: menu_requested.emit())
	v.add_child(_menu_btn)


func show_pause(wave: int, kills: int, score: int, upgrades: Dictionary = {}) -> void:
	ensure_built()
	_stats_lbl.text = "Onda %d  •  Abates: %d  •  Pontos: %d" % [wave, kills, score]
	if upgrades.is_empty():
		_upgrades_lbl.text = "Upgrades ativos: Nenhum"
	else:
		var parts: Array[String] = []
		for k in upgrades.keys():
			parts.append("%s ×%d" % [str(k).replace("_", " ").capitalize(), int(upgrades[k])])
		_upgrades_lbl.text = "Upgrades: " + ", ".join(parts)
	visible = true
	if is_inside_tree() and _resume_btn != null:
		_resume_btn.grab_focus()


func hide_modal() -> void:
	visible = false


func focus_default() -> void:
	if is_inside_tree() and _resume_btn != null:
		_resume_btn.grab_focus()


func get_buttons() -> Array[Button]:
	return [_resume_btn, _settings_btn, _restart_btn, _menu_btn]


func _make_btn(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 38)
	b.focus_mode = Control.FOCUS_ALL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.11, 0.16, 0.88)
	sb.border_color = Color(0.65, 0.52, 0.32, 0.72)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	var foc := sb.duplicate() as StyleBoxFlat
	foc.bg_color = Color(0.24, 0.17, 0.12, 0.96)
	foc.border_color = Color(1.0, 0.86, 0.45, 1.0)
	foc.set_border_width_all(2)
	b.add_theme_stylebox_override("focus", foc)
	b.add_theme_stylebox_override("hover", foc)
	return b
