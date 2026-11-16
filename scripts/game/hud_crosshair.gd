class_name HUDCrosshair
extends Control
## Renders dynamic TPS/FPS 4-tick crosshair, crisp hitmarker, and [V] camera mode indicator pill.

var _ticks: Array[ColorRect] = []
var _tick_bgs: Array[ColorRect] = []
var _dot: ColorRect
var _dot_bg: ColorRect
var _hit_rects: Array[ColorRect] = []
var _view_pill: PanelContainer
var _view_lbl: Label

var _hit_left: float = 0.0
var _gap_px: float = 7.0
var _is_fps: bool = false
var _doom_centered: bool = false
var _optic_mode: int = 0  # 0=standard, 1=fps_ads_optic, 2=sniper_scope


func _ready() -> void:
	_sync_full_rect()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_ENTER_TREE:
		_sync_full_rect()


func _sync_full_rect() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	visible = true
	modulate = Color.WHITE


func build() -> void:
	_sync_full_rect()

	_dot_bg = _make_rect(Vector2(-3.5, -3.5), Vector2(3.5, 3.5), Color(0.0, 0.0, 0.0, 0.92))
	_dot = _make_rect(Vector2(-2.0, -2.0), Vector2(2.0, 2.0), Color(0.22, 1.0, 0.78, 1.0))
	for _i in range(4):
		_tick_bgs.append(_make_rect(Vector2.ZERO, Vector2.ZERO, Color(0.0, 0.0, 0.0, 0.88)))
	for _i in range(4):
		_ticks.append(_make_rect(Vector2.ZERO, Vector2.ZERO, Color(0.22, 1.0, 0.78, 0.98)))
	for _j in range(4):
		var hr := _make_rect(Vector2(-7.0, -1.5), Vector2(7.0, 1.5), Color.WHITE)
		hr.pivot_offset = Vector2(7.0, 1.5)
		hr.visible = false
		_hit_rects.append(hr)
	_hit_rects[0].position += Vector2(-9.0, -9.0)
	_hit_rects[0].rotation = PI * 0.25
	_hit_rects[1].position += Vector2(9.0, -9.0)
	_hit_rects[1].rotation = -PI * 0.25
	_hit_rects[2].position += Vector2(-9.0, 9.0)
	_hit_rects[2].rotation = -PI * 0.25
	_hit_rects[3].position += Vector2(9.0, 9.0)
	_hit_rects[3].rotation = PI * 0.25

	_view_pill = PanelContainer.new()
	_view_pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_view_pill.offset_left = -255.0
	_view_pill.offset_right = -18.0
	_view_pill.offset_top = 14.0
	_view_pill.offset_bottom = 44.0
	_view_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.08, 0.13, 0.72)
	box.border_color = Color(0.28, 0.75, 0.95, 0.65)
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	_view_pill.add_theme_stylebox_override("panel", box)
	add_child(_view_pill)

	_view_lbl = Label.new()
	_view_lbl.add_theme_font_size_override("font_size", 13)
	_view_lbl.add_theme_color_override("font_color", Color(0.84, 0.95, 1.0))
	_view_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.9))
	_view_lbl.add_theme_constant_override("outline_size", 3)
	_view_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_view_pill.add_child(_view_lbl)
	set_view_mode(false, false)
	_layout_ticks(7.0)


func set_view_mode(is_fps: bool, doom_centered: bool = false) -> void:
	_is_fps = is_fps
	_doom_centered = doom_centered
	_optic_mode = 0
	queue_redraw()
	_sync_full_rect()
	if _dot_bg != null:
		_dot_bg.visible = true
	if _dot != null:
		_dot.visible = true
	for t in _ticks:
		t.visible = true
	for tb in _tick_bgs:
		tb.visible = true
	if _view_lbl != null:
		if is_fps:
			_view_lbl.text = "[V] Visão: 1ª Pessoa (FPS)%s" % (" • Centro [H]" if doom_centered else "")
		else:
			_view_lbl.text = "[V] Visão: 3ª Pessoa"


func get_view_mode_text() -> String:
	return _view_lbl.text if _view_lbl != null else ""


func trigger_hitmarker(is_crit: bool) -> void:
	_hit_left = 0.11
	var col := Color(1.0, 0.85, 0.2, 0.98) if is_crit else Color(1.0, 1.0, 1.0, 0.90)
	for hr in _hit_rects:
		hr.color = col
		hr.visible = true


func update_crosshair(delta: float, spread_deg: float, is_aiming: bool, move_ratio: float, weapon_id: String = "") -> void:
	if _hit_left > 0.0:
		_hit_left = maxf(0.0, _hit_left - delta)
		if _hit_left <= 0.0:
			for hr in _hit_rects:
				hr.visible = false
	var new_mode := 2 if (is_aiming and weapon_id == "sniper") else (1 if (_is_fps and is_aiming and not (weapon_id in ["katana", "lightsaber"])) else 0)
	if new_mode != _optic_mode:
		_optic_mode = new_mode
		_apply_optic_visibility()
		queue_redraw()
	var target_gap := (4.5 if is_aiming else 7.5) + spread_deg * 1.45 + move_ratio * 4.5
	if _is_fps and is_aiming:
		target_gap *= 0.72
	_gap_px = lerpf(_gap_px, clampf(target_gap, 3.5, 24.0), minf(1.0, delta * 16.0))
	_layout_ticks(_gap_px)


func _apply_optic_visibility() -> void:
	var show_std_ticks := _optic_mode != 2
	for t in _ticks:
		t.visible = show_std_ticks
	for tb in _tick_bgs:
		tb.visible = (_optic_mode == 0)
	if _dot_bg != null:
		_dot_bg.visible = (_optic_mode == 0)


func _draw() -> void:
	if _optic_mode == 0:
		return
	var c := size * 0.5
	if _optic_mode == 1:
		var col := Color(0.22, 1.0, 0.78, 0.45)
		draw_arc(c, 22.0, 0.0, TAU, 48, col, 1.2, true)
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(c + dir * 22.0, c + dir * 28.0, col, 1.2, true)
		return
	var ring_r := clampf(minf(size.x, size.y) * 0.30, 130.0, 260.0)
	draw_arc(c, ring_r + 2.0, 0.0, TAU, 72, Color(0.02, 0.04, 0.06, 0.62), 3.0, true)
	draw_arc(c, ring_r, 0.0, TAU, 72, Color(0.25, 0.96, 0.85, 0.65), 1.3, true)
	var stadia_col := Color(0.25, 0.98, 0.86, 0.80)
	var notch_col := Color(0.25, 0.98, 0.86, 0.52)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var dir: Vector2 = d
		draw_line(c + dir * 12.0, c + dir * (ring_r - 3.0), stadia_col, 1.0, true)
		var perp := Vector2(-dir.y, dir.x)
		for dist in [34.0, 64.0, 94.0, 124.0]:
			if dist < ring_r - 8.0:
				var p: Vector2 = c + dir * dist
				draw_line(p - perp * 3.5, p + perp * 3.5, notch_col, 1.0, true)


func _layout_ticks(g: float) -> void:
	if _ticks.size() < 4:
		return
	var len_px := 7.0 if _optic_mode == 1 else (11.0 if _is_fps else 9.0)
	var th := 1.0 if _optic_mode == 1 else 1.5
	var rects := [
		Rect2(-th, -(g + len_px), th * 2.0, len_px),
		Rect2(-th, g, th * 2.0, len_px),
		Rect2(-(g + len_px), -th, len_px, th * 2.0),
		Rect2(g, -th, len_px, th * 2.0),
	]
	for i in range(4):
		var rc: Rect2 = rects[i]
		_set_center_offsets(_ticks[i], rc.position.x, rc.position.y, rc.end.x, rc.end.y)
		if i < _tick_bgs.size():
			_set_center_offsets(_tick_bgs[i], rc.position.x - 1.0, rc.position.y - 1.0, rc.end.x + 1.0, rc.end.y + 1.0)


func _set_center_offsets(r: ColorRect, l: float, t: float, ri: float, b: float) -> void:
	r.offset_left = l
	r.offset_top = t
	r.offset_right = ri
	r.offset_bottom = b


func _make_rect(lt: Vector2, rb: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_CENTER)
	r.offset_left = lt.x
	r.offset_top = lt.y
	r.offset_right = rb.x
	r.offset_bottom = rb.y
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = col
	add_child(r)
	return r
