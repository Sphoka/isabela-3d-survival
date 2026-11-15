class_name UpgradeModalUI
extends PanelContainer
## Renders the 3-card Level-Up / Wave-Clear Upgrade Selection UI with rarity styling and 1/2/3 shortcuts.

signal card_selected(index: int)

var _cards_row: HBoxContainer
var _cards_data: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _built: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_ensure_layout()


func show_choices(choices: Array) -> void:
	_ensure_layout()
	_cards_data.clear()
	for child in _cards_row.get_children():
		child.queue_free()
	_buttons.clear()

	for i in range(choices.size()):
		if not (choices[i] is Dictionary):
			continue
		var card: Dictionary = choices[i]
		_cards_data.append(card)
		var btn := _create_card_widget(i, card)
		_cards_row.add_child(btn)
		_buttons.append(btn)
	visible = not _cards_data.is_empty()
	if visible and not _buttons.is_empty() and is_inside_tree():
		_buttons[0].grab_focus()


func hide_modal() -> void:
	visible = false


func get_card_count() -> int:
	return _buttons.size()


func select_card(index: int) -> void:
	if index >= 0 and index < _cards_data.size():
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


func _ensure_layout() -> void:
	if _built:
		return
	_built = true
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -460.0
	offset_top = -190.0
	offset_right = 460.0
	offset_bottom = 190.0

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.07, 0.11, 0.92)
	bg.border_color = Color(0.22, 0.74, 0.97, 0.85)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(12)
	bg.set_content_margin_all(20)
	add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	add_child(vbox)

	var title := Label.new()
	title.text = "ESCOLHA UMA MELHORIA TÁTICA [1 / 2 / 3 OU CONTROLE: X / Y / B / D-PAD]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	vbox.add_child(title)

	_cards_row = HBoxContainer.new()
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_row.add_theme_constant_override("separation", 18)
	_cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_cards_row)


func _create_card_widget(idx: int, card: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(270.0, 260.0)
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
	btn.add_theme_stylebox_override("hover", hover)

	var focus_box := style.duplicate() as StyleBoxFlat
	focus_box.bg_color = Color(0.16, 0.22, 0.32, 1.0)
	focus_box.border_color = Color(1.0, 0.9, 0.3, 1.0)
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
	vbox.add_theme_constant_override("separation", 10)
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

	btn.pressed.connect(func() -> void: select_card(idx))
	return btn
