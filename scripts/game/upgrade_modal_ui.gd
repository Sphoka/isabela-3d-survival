class_name UpgradeModalUI
extends PanelContainer
## Renders the 3-card Level-Up / Wave-Clear Upgrade Selection UI with golden aura, confirm buttons, and 1/2/3/gamepad shortcuts.

signal card_selected(index: int)

var _cards_row: HBoxContainer
var _cards_data: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _confirm_buttons: Array[Button] = []
var _aura_styles: Array[StyleBoxFlat] = []
var _selected_idx: int = 0
var _aura_time: float = 0.0
var _just_selected: bool = false
var _built: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_ensure_layout()


func _process(delta: float) -> void:
	if not visible or _aura_styles.is_empty():
		return
	_aura_time += delta
	for i in range(_aura_styles.size()):
		var aura := _aura_styles[i]
		var is_sel := (i == _selected_idx)
		var speed := 4.4 if is_sel else 2.2
		var pulse := 0.5 + 0.5 * sin(_aura_time * speed + float(i) * 0.85)
		if is_sel:
			aura.bg_color = Color(1.0, 0.84, 0.20, lerpf(0.16, 0.30, pulse))
			aura.border_color = Color(1.0, 0.90, 0.28, lerpf(0.80, 1.0, pulse))
			aura.shadow_size = int(lerpf(14.0, 22.0, pulse))
			aura.shadow_color = Color(1.0, 0.80, 0.14, lerpf(0.45, 0.72, pulse))
		else:
			aura.bg_color = Color(1.0, 0.80, 0.24, lerpf(0.03, 0.08, pulse))
			aura.border_color = Color(1.0, 0.82, 0.28, lerpf(0.24, 0.44, pulse))
			aura.shadow_size = int(lerpf(4.0, 8.0, pulse))
			aura.shadow_color = Color(1.0, 0.76, 0.18, lerpf(0.12, 0.26, pulse))


func show_choices(choices: Array) -> void:
	_ensure_layout()
	_cards_data.clear()
	for child in _cards_row.get_children():
		child.queue_free()
	_buttons.clear()
	_confirm_buttons.clear()
	_aura_styles.clear()
	_selected_idx = 0
	_aura_time = 0.0
	_just_selected = false

	for i in range(choices.size()):
		if not (choices[i] is Dictionary):
			continue
		var card: Dictionary = choices[i]
		_cards_data.append(card)
		var slot_data := _create_card_widget(i, card)
		_cards_row.add_child(slot_data["wrapper"])
		_buttons.append(slot_data["button"])
		_confirm_buttons.append(slot_data["confirm"])
		_aura_styles.append(slot_data["aura"])
	visible = not _cards_data.is_empty()
	if visible:
		_set_selected_index(0)
		if not _buttons.is_empty() and is_inside_tree():
			_buttons[0].grab_focus()
		_play_ui_sfx("upgrade_appear", 0.02, -3.5)


func hide_modal() -> void:
	if visible and not _just_selected:
		_play_ui_sfx("metal_click", 0.04, -2.5)
	visible = false


func get_card_count() -> int:
	return _buttons.size()


func select_card(index: int) -> void:
	if index >= 0 and index < _cards_data.size():
		_set_selected_index(index)
		_just_selected = true
		_play_ui_sfx("metal_click", 0.04, -2.5)
		card_selected.emit(index)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	for i in range(3):
		if event.is_action_pressed("upgrade_pick_%d" % (i + 1)) and i < _cards_data.size():
			select_card(i)
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()
			return


func _set_selected_index(idx: int) -> void:
	if idx < 0 or idx >= _buttons.size():
		return
	_selected_idx = idx
	for i in range(_confirm_buttons.size()):
		var cbtn := _confirm_buttons[i]
		var is_sel := (i == _selected_idx)
		cbtn.text = "★ CONFIRMAR ★" if is_sel else "CONFIRMAR"
		cbtn.modulate = Color(1.0, 0.96, 0.72, 1.0) if is_sel else Color(0.82, 0.88, 0.96, 0.92)


func _play_ui_sfx(sfx_id: String, pitch_jitter: float = 0.03, volume_db: float = -3.0) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var audio_mgr := tree.get_first_node_in_group("audio_manager")
	if audio_mgr != null and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_id, pitch_jitter, volume_db)


func _ensure_layout() -> void:
	if _built:
		return
	_built = true
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -485.0
	offset_top = -215.0
	offset_right = 485.0
	offset_bottom = 215.0

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.07, 0.11, 0.94)
	bg.border_color = Color(0.98, 0.82, 0.28, 0.88)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(14)
	bg.set_content_margin_all(20)
	add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	add_child(vbox)

	var title := Label.new()
	title.text = "ESCOLHA UMA MELHORIA TÁTICA [1 / 2 / 3 OU CONTROLE: X / Y / B / D-PAD]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.94, 0.76))
	vbox.add_child(title)

	_cards_row = HBoxContainer.new()
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_row.add_theme_constant_override("separation", 16)
	_cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_cards_row)


func _create_card_widget(idx: int, card: Dictionary) -> Dictionary:
	var aura := StyleBoxFlat.new()
	aura.bg_color = Color(1.0, 0.80, 0.24, 0.06)
	aura.border_color = Color(1.0, 0.84, 0.28, 0.35)
	aura.set_border_width_all(2)
	aura.set_corner_radius_all(13)
	aura.set_content_margin_all(5)
	aura.shadow_size = 6
	aura.shadow_color = Color(1.0, 0.78, 0.18, 0.2)

	var wrapper := PanelContainer.new()
	wrapper.add_theme_stylebox_override("panel", aura)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(272.0, 292.0)
	btn.focus_mode = Control.FOCUS_ALL
	var accent := Color.from_string(str(card.get("color_hex", "#CBD5E1")), Color(0.8, 0.85, 0.9))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.12, 0.18, 0.96)
	style.border_color = accent
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.19, 0.28, 1.0)
	hover.border_color = Color(1.0, 0.88, 0.35, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

	var focus_box := style.duplicate() as StyleBoxFlat
	focus_box.bg_color = Color(0.16, 0.22, 0.32, 1.0)
	focus_box.border_color = Color(1.0, 0.90, 0.28, 1.0)
	focus_box.set_border_width_all(4)
	btn.add_theme_stylebox_override("focus", focus_box)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	btn.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var badge := Label.new()
	var shortcut_hint := "[1/X]" if idx == 0 else ("[2/Y]" if idx == 1 else "[3/B]")
	badge.text = "%s %s  •  NV %d/%d" % [shortcut_hint, str(card.get("rarity_label", "Comum")).to_upper(), int(card.get("next_stack", 1)), int(card.get("max_stacks", 10))]
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", accent)
	vbox.add_child(badge)

	var name_lbl := Label.new()
	name_lbl.text = str(card.get("title", "Melhoria"))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_lbl)

	var desc := Label.new()
	desc.text = str(card.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.82, 0.87, 0.94))
	vbox.add_child(desc)

	var confirm_btn := _create_confirm_button()
	confirm_btn.pressed.connect(func() -> void: select_card(idx))
	vbox.add_child(confirm_btn)

	btn.focus_entered.connect(func() -> void: _set_selected_index(idx))
	btn.mouse_entered.connect(func() -> void: _set_selected_index(idx))
	btn.pressed.connect(func() -> void: _set_selected_index(idx))
	wrapper.add_child(btn)
	return {"wrapper": wrapper, "button": btn, "confirm": confirm_btn, "aura": aura}


func _create_confirm_button() -> Button:
	var cbtn := Button.new()
	cbtn.text = "CONFIRMAR"
	cbtn.custom_minimum_size = Vector2(0.0, 34.0)
	cbtn.focus_mode = Control.FOCUS_NONE
	cbtn.add_theme_font_size_override("font_size", 14)

	var c_norm := StyleBoxFlat.new()
	c_norm.bg_color = Color(0.78, 0.58, 0.14, 0.92)
	c_norm.border_color = Color(1.0, 0.88, 0.35, 1.0)
	c_norm.set_border_width_all(2)
	c_norm.set_corner_radius_all(7)
	cbtn.add_theme_stylebox_override("normal", c_norm)

	var c_hover := c_norm.duplicate() as StyleBoxFlat
	c_hover.bg_color = Color(0.95, 0.74, 0.20, 1.0)
	cbtn.add_theme_stylebox_override("hover", c_hover)
	cbtn.add_theme_color_override("font_color", Color(0.08, 0.06, 0.02, 1.0))
	cbtn.add_theme_color_override("font_hover_color", Color(0.05, 0.04, 0.01, 1.0))
	return cbtn
