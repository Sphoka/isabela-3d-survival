class_name SettingsModalUI
extends ColorRect
## Reusable tabbed Settings modal (Audio, Video, Controls) with Gamepad & Keyboard navigation.

const SettingsManagerRef := preload("res://scripts/game/settings_manager.gd")

signal closed()

var _tabs: TabContainer
var _close_btn: Button
var _reset_btn: Button
var _controls_by_key: Dictionary = {}
var _labels_by_key: Dictionary = {}
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
	color = Color(0.02, 0.02, 0.04, 0.84)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -310.0
	panel.offset_top = -225.0
	panel.offset_right = 310.0
	panel.offset_bottom = 225.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.08, 0.96)
	sb.border_color = Color(0.88, 0.62, 0.25, 0.90)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	margin.add_child(root_v)

	var title := Label.new()
	title.text = "CONFIGURAÇÕES  [LB / RB: Abas]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
	root_v.add_child(title)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(_tabs)

	_build_audio_tab()
	_build_video_tab()
	_build_controls_tab()

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	root_v.add_child(btn_row)

	_reset_btn = Button.new()
	_reset_btn.text = "RESTAURAR PADRÕES"
	_reset_btn.pressed.connect(_on_reset_pressed)
	btn_row.add_child(_reset_btn)

	_close_btn = Button.new()
	_close_btn.text = "SALVAR E VOLTAR [ESC / B]"
	_close_btn.pressed.connect(_on_close_pressed)
	btn_row.add_child(_close_btn)


func open() -> void:
	ensure_built()
	SettingsManagerRef.ensure_loaded()
	_sync_ui_from_settings()
	visible = true
	if is_inside_tree() and _close_btn != null:
		_focus_first_in_current_tab()


func close() -> void:
	SettingsManagerRef.save()
	visible = false
	closed.emit()


func switch_tab(delta: int) -> void:
	if _tabs == null or _tabs.get_tab_count() == 0:
		return
	var next := (_tabs.current_tab + delta + _tabs.get_tab_count()) % _tabs.get_tab_count()
	_tabs.current_tab = next
	_focus_first_in_current_tab()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game") or event.is_action_pressed("pause"):
		close()
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		var jb := event as InputEventJoypadButton
		if jb.button_index == JOY_BUTTON_B:
			close()
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
		elif jb.button_index == JOY_BUTTON_LEFT_SHOULDER:
			switch_tab(-1)
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
		elif jb.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			switch_tab(1)
			if get_viewport() != null:
				get_viewport().set_input_as_handled()


func _build_audio_tab() -> void:
	var box := _make_tab_page("ÁUDIO")
	_add_slider(box, "master_volume", "Volume Geral", 0.0, 1.0, 0.05, true)
	_add_slider(box, "music_volume", "Volume da Música", 0.0, 1.0, 0.05, true)
	_add_slider(box, "sfx_volume", "Efeitos Sonoros (SFX)", 0.0, 1.0, 0.05, true)


func _build_video_tab() -> void:
	var box := _make_tab_page("VÍDEO")
	_add_checkbox(box, "fullscreen", "Tela Cheia (Fullscreen)")
	_add_checkbox(box, "vsync", "Sincronização Vertical (V-Sync)")
	_add_slider(box, "fov", "Campo de Visão (FOV)", 60.0, 95.0, 1.0, false, "°")


func _build_controls_tab() -> void:
	var box := _make_tab_page("CONTROLES")
	_add_slider(box, "mouse_sensitivity", "Sensibilidade do Mouse", 0.0008, 0.0060, 0.0002, false, "", 4)
	_add_slider(box, "controller_sensitivity", "Sensibilidade do Controle", 1.2, 6.5, 0.2, false, "x", 1)
	_add_checkbox(box, "default_fps_mode", "Iniciar em 1ª Pessoa (FPS)")


func _make_tab_page(tab_title: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = tab_title
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	_tabs.add_child(margin)
	return v


func _add_slider(parent: VBoxContainer, key: String, label_txt: String, min_v: float, max_v: float, step_v: float, as_percent: bool, suffix: String = "", decimals: int = 0) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_txt
	lbl.custom_minimum_size = Vector2(230, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(72, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	_controls_by_key[key] = slider
	_labels_by_key[key] = {"label": val_lbl, "percent": as_percent, "suffix": suffix, "decimals": decimals}

	slider.value_changed.connect(func(v: float) -> void:
		SettingsManagerRef.set_val(key, v, false)
		_update_slider_label(key, v)
		SettingsManagerRef.apply_all(get_tree() if is_inside_tree() else null)
	)


func _add_checkbox(parent: VBoxContainer, key: String, label_txt: String) -> void:
	var cb := CheckBox.new()
	cb.text = label_txt
	cb.focus_mode = Control.FOCUS_ALL
	parent.add_child(cb)
	_controls_by_key[key] = cb
	cb.toggled.connect(func(on: bool) -> void:
		SettingsManagerRef.set_val(key, on, false)
		SettingsManagerRef.apply_all(get_tree() if is_inside_tree() else null)
	)


func _sync_ui_from_settings() -> void:
	var data := SettingsManagerRef.get_all()
	for k in _controls_by_key.keys():
		var ctrl: Control = _controls_by_key[k]
		if ctrl is HSlider:
			var val := float(data.get(k, 0.0))
			(ctrl as HSlider).set_value_no_signal(val)
			_update_slider_label(k, val)
		elif ctrl is CheckBox:
			(ctrl as CheckBox).set_pressed_no_signal(bool(data.get(k, false)))


func _update_slider_label(key: String, val: float) -> void:
	if not _labels_by_key.has(key):
		return
	var meta: Dictionary = _labels_by_key[key]
	var lbl: Label = meta["label"]
	if bool(meta["percent"]):
		lbl.text = "%d%%" % roundi(val * 100.0)
	else:
		var dec := int(meta["decimals"])
		var fmt := "%." + str(dec) + "f%s"
		lbl.text = fmt % [val, str(meta["suffix"])]


func _focus_first_in_current_tab() -> void:
	if _tabs == null or not is_inside_tree():
		return
	var page := _tabs.get_current_tab_control()
	if page != null:
		var found := _find_first_focusable(page)
		if found != null:
			found.grab_focus()
			return
	if _close_btn != null:
		_close_btn.grab_focus()


func _find_first_focusable(node: Node) -> Control:
	for c in node.get_children():
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL and (c as Control).visible:
			return c as Control
		var deeper := _find_first_focusable(c)
		if deeper != null:
			return deeper
	return null


func _on_reset_pressed() -> void:
	SettingsManagerRef.reset_to_defaults(true)
	_sync_ui_from_settings()
	SettingsManagerRef.apply_all(get_tree() if is_inside_tree() else null)


func _on_close_pressed() -> void:
	close()
