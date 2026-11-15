class_name DuneBackdrop
extends Control
## Dune-inspired desert sci-fi backdrop: loads high-res Wan2GP artwork with procedural fallback.

const BG_IMAGE_PATH := "res://assets/ui/main_menu_bg.png"


static func _load_backdrop_texture() -> Texture2D:
	if ResourceLoader.exists(BG_IMAGE_PATH):
		var res_tex := ResourceLoader.load(BG_IMAGE_PATH) as Texture2D
		if res_tex != null:
			return res_tex
	if FileAccess.file_exists(BG_IMAGE_PATH):
		var img := Image.load_from_file(BG_IMAGE_PATH)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


static func build_into(parent: Control) -> void:
	var root := Control.new()
	root.name = "DuneBackdrop"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)

	var bg_tex := _load_backdrop_texture()
	if bg_tex != null:
		var art := TextureRect.new()
		art.name = "BackdropImage"
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.texture = bg_tex
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(art)
		_add_left_scrim(root)
		_add_spice_dust(root)
		return

	_build_procedural_fallback(root)


static func _add_left_scrim(root: Control) -> void:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.03, 0.02, 0.04, 0.72),
		Color(0.04, 0.03, 0.05, 0.35),
		Color(0.04, 0.03, 0.05, 0.0),
	])
	grad.offsets = PackedFloat32Array([0.0, 0.42, 0.80])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.0, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	var scrim := TextureRect.new()
	scrim.name = "LeftScrim"
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.texture = gtex
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(scrim)


static func _build_procedural_fallback(root: Control) -> void:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.05, 0.06, 0.11, 1.0),
		Color(0.18, 0.12, 0.13, 1.0),
		Color(0.54, 0.31, 0.15, 1.0),
		Color(0.28, 0.14, 0.08, 1.0),
	])
	grad.offsets = PackedFloat32Array([0.0, 0.42, 0.78, 1.0])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = gtex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var sun_grad := Gradient.new()
	sun_grad.colors = PackedColorArray([Color(1.0, 0.80, 0.45, 0.85), Color(0.95, 0.52, 0.18, 0.25), Color(0.95, 0.52, 0.18, 0.0)])
	sun_grad.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	var stex := GradientTexture2D.new()
	stex.gradient = sun_grad
	stex.fill = GradientTexture2D.FILL_RADIAL
	stex.fill_from = Vector2(0.5, 0.5)
	stex.fill_to = Vector2(1.0, 0.5)
	var sun := TextureRect.new()
	sun.texture = stex
	sun.set_anchors_preset(Control.PRESET_CENTER)
	sun.offset_left = 40.0
	sun.offset_top = -280.0
	sun.offset_right = 560.0
	sun.offset_bottom = 240.0
	sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sun)

	var ship := Polygon2D.new()
	ship.color = Color(0.06, 0.05, 0.08, 0.88)
	ship.polygon = PackedVector2Array([
		Vector2(660, 145), Vector2(880, 128), Vector2(1080, 145),
		Vector2(990, 165), Vector2(750, 165)
	])
	root.add_child(ship)

	var dune_far := Polygon2D.new()
	dune_far.color = Color(0.16, 0.09, 0.06, 0.85)
	dune_far.polygon = PackedVector2Array([
		Vector2(0, 540), Vector2(340, 470), Vector2(720, 520),
		Vector2(1140, 445), Vector2(1440, 510), Vector2(1920, 480),
		Vector2(1920, 1080), Vector2(0, 1080)
	])
	root.add_child(dune_far)

	var dune_near := Polygon2D.new()
	dune_near.color = Color(0.07, 0.04, 0.04, 0.96)
	dune_near.polygon = PackedVector2Array([
		Vector2(0, 620), Vector2(460, 565), Vector2(920, 645),
		Vector2(1380, 580), Vector2(1920, 630),
		Vector2(1920, 1080), Vector2(0, 1080)
	])
	root.add_child(dune_near)
	_add_spice_dust(root)


static func _add_spice_dust(root: Control) -> void:
	var dust := CPUParticles2D.new()
	dust.position = Vector2(640, 360)
	dust.amount = 65
	dust.lifetime = 6.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(700, 400)
	dust.direction = Vector2(1.0, -0.15)
	dust.spread = 18.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 16.0
	dust.initial_velocity_max = 46.0
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.5
	dust.color = Color(1.0, 0.78, 0.42, 0.42)
	root.add_child(dust)
