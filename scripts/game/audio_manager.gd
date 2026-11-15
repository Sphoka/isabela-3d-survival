class_name AudioManager
extends Node
## Hybrid music and combat SFX manager (prefers external .ogg/.wav in assets/audio/, falls back to ProceduralSFX).

const ProceduralSFXRef := preload("res://scripts/game/procedural_sfx.gd")

const MUSIC_CANDIDATES := [
	"res://assets/audio/music/punk_rock_loop.ogg",
	"res://assets/audio/music/punk_rock_loop.wav",
]
const SFX_POOL_SIZE := 16
const MUSIC_LIVE_DB := -7.5
const MUSIC_PAUSED_DB := -17.5

var played_events_count: int = 0

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _streams: Dictionary = {}
var _music_stream: AudioStream
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("audio_manager")
	_rng.randomize()
	_ensure_buses()
	_build_players()
	_preload_default_streams()


func has_music_stream() -> bool:
	return _music_stream != null


func start_music() -> void:
	if _music_stream == null or _music_player == null:
		return
	if DisplayServer.get_name() == "headless":
		return
	if _music_player.stream != _music_stream:
		_music_player.stream = _music_stream
	if not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()


func set_paused_ducking(paused: bool) -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, MUSIC_PAUSED_DB if paused else MUSIC_LIVE_DB)


func play_weapon_shot(weapon_id: String) -> void:
	var vol := -3.5
	var jitter := 0.07
	match weapon_id:
		"smg":
			vol = -5.5
			jitter = 0.09
		"shotgun", "rocket_launcher":
			vol = -2.0
			jitter = 0.05
	play_sfx(weapon_id, jitter, vol)


func play_sfx(sfx_id: String, pitch_jitter: float = 0.08, volume_db: float = -3.0) -> void:
	played_events_count += 1
	if DisplayServer.get_name() == "headless":
		return
	var stream := _resolve_sfx_stream(sfx_id)
	if stream == null or _sfx_pool.is_empty():
		return
	var player := _sfx_pool[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_pool.size()
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func _ensure_buses() -> void:
	_ensure_bus("Music", MUSIC_LIVE_DB)
	_ensure_bus("SFX", -1.5)


func _ensure_bus(bus_name: String, default_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, &"Master")
	AudioServer.set_bus_volume_db(idx, default_db)


func _build_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = &"Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)

	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFX_%d" % i
		p.bus = &"SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_pool.append(p)


func _preload_default_streams() -> void:
	for cand in MUSIC_CANDIDATES:
		if ResourceLoader.exists(cand):
			var loaded := load(cand) as AudioStream
			if loaded != null:
				if loaded is AudioStreamOggVorbis:
					(loaded as AudioStreamOggVorbis).loop = true
				elif loaded is AudioStreamWAV:
					(loaded as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
				_music_stream = loaded
				break
	if _music_stream == null:
		_music_stream = ProceduralSFXRef.make_punk_loop()

	for sfx_id in [
		"pistol", "smg", "shotgun", "laser_gun", "rocket_launcher",
		"katana", "lightsaber", "droid_hit", "droid_explode",
		"barrel_explode", "pickup", "level_up", "player_hurt",
		"wave_start", "reload",
	]:
		_resolve_sfx_stream(sfx_id)


func _resolve_sfx_stream(sfx_id: String) -> AudioStream:
	if _streams.has(sfx_id):
		return _streams[sfx_id] as AudioStream
	for ext in [".ogg", ".wav"]:
		var path := "res://assets/audio/sfx/%s%s" % [sfx_id, ext]
		if ResourceLoader.exists(path):
			var s := load(path) as AudioStream
			if s != null:
				_streams[sfx_id] = s
				return s
	var synth := ProceduralSFXRef.make_sfx(sfx_id)
	_streams[sfx_id] = synth
	return synth
