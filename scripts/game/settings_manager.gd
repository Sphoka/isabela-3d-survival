class_name SettingsManager
extends RefCounted
## Persistent user settings (Audio, Video, Controls) stored in user://settings.cfg.

const DEFAULT_CFG_PATH := "user://settings.cfg"

const DEFAULTS := {
	"master_volume": 0.85,
	"music_volume": 0.70,
	"sfx_volume": 0.85,
	"fullscreen": false,
	"vsync": true,
	"fov": 66.0,
	"mouse_sensitivity": 0.0022,
	"controller_sensitivity": 3.4,
	"default_fps_mode": false,
}

static var _cache: Dictionary = {}
static var _loaded: bool = false
static var _custom_path: String = ""


static func set_config_path_for_test(path: String) -> void:
	_custom_path = path
	_loaded = false
	_cache.clear()


static func get_config_path() -> String:
	return _custom_path if not _custom_path.is_empty() else DEFAULT_CFG_PATH


static func ensure_loaded() -> void:
	if _loaded:
		return
	_cache = DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(get_config_path()) == OK:
		for k in DEFAULTS.keys():
			var sec := _section_for(k)
			if cfg.has_section_key(sec, k):
				_cache[k] = cfg.get_value(sec, k, DEFAULTS[k])
	_loaded = true


static func get_all() -> Dictionary:
	ensure_loaded()
	return _cache.duplicate(true)


static func get_val(key: String) -> Variant:
	ensure_loaded()
	return _cache.get(key, DEFAULTS.get(key))


static func set_val(key: String, value: Variant, save_now: bool = false) -> void:
	ensure_loaded()
	_cache[key] = value
	if save_now:
		save()


static func reset_to_defaults(save_now: bool = true) -> void:
	_cache = DEFAULTS.duplicate(true)
	_loaded = true
	if save_now:
		save()


static func save() -> int:
	ensure_loaded()
	var cfg := ConfigFile.new()
	for k in DEFAULTS.keys():
		cfg.set_value(_section_for(k), k, _cache.get(k, DEFAULTS[k]))
	return cfg.save(get_config_path())


static func apply_all(tree: SceneTree = null) -> void:
	ensure_loaded()
	apply_audio(tree)
	apply_video()
	if tree != null:
		apply_runtime_player(tree)


static func apply_audio(tree: SceneTree = null) -> void:
	ensure_loaded()
	_set_bus_linear("Master", float(get_val("master_volume")), 0.0)
	_set_bus_linear("SFX", float(get_val("sfx_volume")), -1.5)
	_set_bus_linear("Music", float(get_val("music_volume")), -7.5)
	if tree != null:
		for am in tree.get_nodes_in_group("audio_manager"):
			if am.has_method("apply_user_volumes"):
				am.call("apply_user_volumes", float(get_val("music_volume")), float(get_val("sfx_volume")))


static func apply_video() -> void:
	ensure_loaded()
	if DisplayServer.get_name() == "headless":
		return
	var fs := bool(get_val("fullscreen"))
	var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != target_mode:
		DisplayServer.window_set_mode(target_mode)
	var vsync_mode := DisplayServer.VSYNC_ENABLED if bool(get_val("vsync")) else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)


static func apply_runtime_player(tree: SceneTree) -> void:
	ensure_loaded()
	var ms := float(get_val("mouse_sensitivity"))
	var cs := float(get_val("controller_sensitivity"))
	var fov := float(get_val("fov"))
	for p in tree.get_nodes_in_group("player"):
		var rig := p.get_node_or_null("CameraPivot")
		if rig != null and rig.has_method("apply_user_settings"):
			rig.call("apply_user_settings", ms, cs, fov)


static func _set_bus_linear(bus_name: String, ratio: float, base_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped <= 0.005:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, base_db + linear_to_db(clamped))


static func _section_for(key: String) -> String:
	match key:
		"master_volume", "music_volume", "sfx_volume":
			return "audio"
		"fullscreen", "vsync", "fov":
			return "video"
		_:
			return "controls"
