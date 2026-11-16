class_name ArenaElectricPerimeter
extends Node3D
## Electric perimeter hazard around the playable arena rim: visual barrier pylons, animated arcs, and 10 dmg/s shock.

const GameManagerRef := preload("res://scripts/game/game_manager.gd")
const PlayerControllerRef := preload("res://scripts/game/player_controller.gd")
const AudioManagerRef := preload("res://scripts/game/audio_manager.gd")

const PYLON_COUNT := 16
const TICK_INTERVAL_S := 0.5
const ARC_SEGMENTS_PER_SPAN := 5
const DEFAULT_DAMAGE_PER_SEC := 10.0
const DEFAULT_WIDTH_M := 1.8
const DEFAULT_RADIUS_M := 32.0

var _game_manager: GameManagerRef
var _player: PlayerControllerRef
var _audio: AudioManagerRef

var _radius_m: float = DEFAULT_RADIUS_M
var _width_m: float = DEFAULT_WIDTH_M
var _damage_per_sec: float = DEFAULT_DAMAGE_PER_SEC
var _hazard_radius: float = DEFAULT_RADIUS_M - DEFAULT_WIDTH_M

var _shock_timer: float = 0.0
var _shock_flash_left: float = 0.0
var _pulse_time: float = 0.0
var _arc_redraw_accum: float = 0.0

var _barrier_mat: StandardMaterial3D
var _coil_mat: StandardMaterial3D
var _arc_mat: StandardMaterial3D
var _post_mesh: CylinderMesh
var _coil_mesh: SphereMesh
var _arc_mesh: ImmediateMesh
var _arc_instance: MeshInstance3D
var _shock_light: OmniLight3D
var _pylon_tops: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "ArenaElectricPerimeter"


func setup(gm: GameManagerRef, player: PlayerControllerRef, audio: AudioManagerRef) -> void:
	_game_manager = gm
	_player = player
	_audio = audio
	_rng.randomize()
	if _game_manager != null and _game_manager.balance_db != null:
		var cfg := _game_manager.balance_db.get_arena_cfg()
		_radius_m = float(cfg.get("playable_radius_m", DEFAULT_RADIUS_M))
		_width_m = float(cfg.get("perimeter_electric_width_m", DEFAULT_WIDTH_M))
		_damage_per_sec = float(cfg.get("perimeter_electric_damage_per_sec", DEFAULT_DAMAGE_PER_SEC))
	_hazard_radius = maxf(2.0, _radius_m - _width_m)
	_build_visuals()


func _physics_process(delta: float) -> void:
	tick_hazard(delta)


func tick_hazard(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _player.is_dead:
		return
	if _game_manager != null and _game_manager.state != GameManagerRef.State.PLAYING:
		return

	var flat := Vector2(_player.global_position.x, _player.global_position.z)
	var dist := flat.length()
	if dist >= _hazard_radius:
		_shock_timer -= delta
		if _shock_timer <= 0.0 and float(_player.get("_iframes_left")) <= 0.0:
			var tick_dmg := _damage_per_sec * TICK_INTERVAL_S
			var inward := Vector3(-flat.x, 0.0, -flat.y).normalized() * 3.0 if dist > 0.01 else Vector3.ZERO
			_player.take_damage(tick_dmg, inward)
			_shock_timer = TICK_INTERVAL_S
			_shock_flash_left = 0.28
			if _audio != null:
				_audio.play_sfx("electric_shock", 0.12, -2.0)
	else:
		_shock_timer = maxf(0.0, _shock_timer - delta)


func _process(delta: float) -> void:
	_pulse_time += delta
	_shock_flash_left = maxf(0.0, _shock_flash_left - delta)
	if _barrier_mat != null:
		var pulse := 0.5 + 0.5 * sin(_pulse_time * 5.2)
		_barrier_mat.albedo_color = Color(0.12, 0.78, 1.0, lerpf(0.16, 0.34, pulse))
		_barrier_mat.emission_energy_multiplier = lerpf(1.6, 3.0, pulse)
	if _coil_mat != null:
		var c_pulse := 0.5 + 0.5 * sin(_pulse_time * 7.5)
		_coil_mat.emission_energy_multiplier = lerpf(2.2, 4.2, c_pulse)
	if _shock_light != null:
		if _shock_flash_left > 0.0 and _player != null and is_instance_valid(_player):
			_shock_light.visible = true
			_shock_light.global_position = _player.global_position + Vector3(0.0, 1.0, 0.0)
			_shock_light.light_energy = 4.5 * (_shock_flash_left / 0.28)
		else:
			_shock_light.visible = false

	_arc_redraw_accum += delta
	if _arc_redraw_accum >= 0.06:
		_arc_redraw_accum = 0.0
		_redraw_electric_arcs()


func _build_visuals() -> void:
	if _arc_instance != null:
		return
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.10, 0.13, 0.18)
	post_mat.metallic = 0.85
	post_mat.roughness = 0.30

	_coil_mat = StandardMaterial3D.new()
	_coil_mat.albedo_color = Color(0.20, 0.90, 1.0)
	_coil_mat.emission_enabled = true
	_coil_mat.emission = Color(0.15, 0.86, 1.0)
	_coil_mat.emission_energy_multiplier = 3.0

	_barrier_mat = StandardMaterial3D.new()
	_barrier_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_barrier_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_barrier_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_barrier_mat.albedo_color = Color(0.12, 0.78, 1.0, 0.22)
	_barrier_mat.emission_enabled = true
	_barrier_mat.emission = Color(0.15, 0.85, 1.0)
	_barrier_mat.emission_energy_multiplier = 2.2

	_arc_mat = StandardMaterial3D.new()
	_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_mat.albedo_color = Color(0.55, 0.96, 1.0)
	_arc_mat.emission_enabled = true
	_arc_mat.emission = Color(0.35, 0.92, 1.0)
	_arc_mat.emission_energy_multiplier = 4.0

	_pylon_tops.clear()
	for i in range(PYLON_COUNT):
		var angle := (TAU / float(PYLON_COUNT)) * float(i)
		var pos := Vector3(cos(angle) * _radius_m, 0.0, sin(angle) * _radius_m)
		_pylon_tops.append(pos + Vector3(0.0, 2.05, 0.0))
		_spawn_pylon(pos, post_mat)
		var next_angle := (TAU / float(PYLON_COUNT)) * float(i + 1)
		var next_pos := Vector3(cos(next_angle) * _radius_m, 0.0, sin(next_angle) * _radius_m)
		_spawn_barrier_span(pos, next_pos)

	_arc_mesh = ImmediateMesh.new()
	_arc_instance = MeshInstance3D.new()
	_arc_instance.name = "PerimeterElectricArcs"
	_arc_instance.mesh = _arc_mesh
	_arc_instance.material_override = _arc_mat
	_arc_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arc_instance)

	_shock_light = OmniLight3D.new()
	_shock_light.light_color = Color(0.25, 0.88, 1.0)
	_shock_light.omni_range = 8.0
	_shock_light.visible = false
	add_child(_shock_light)


func _spawn_pylon(pos: Vector3, post_mat: StandardMaterial3D) -> void:
	if _post_mesh == null:
		_post_mesh = CylinderMesh.new()
		_post_mesh.top_radius = 0.18
		_post_mesh.bottom_radius = 0.26
		_post_mesh.height = 2.3
		_post_mesh.radial_segments = 12
		_post_mesh.rings = 2
	if _coil_mesh == null:
		_coil_mesh = SphereMesh.new()
		_coil_mesh.radius = 0.24
		_coil_mesh.height = 0.48
		_coil_mesh.radial_segments = 12
		_coil_mesh.rings = 6

	var post := MeshInstance3D.new()
	post.mesh = _post_mesh
	post.position = pos + Vector3(0.0, 1.15, 0.0)
	post.material_override = post_mat
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(post)

	var coil := MeshInstance3D.new()
	coil.mesh = _coil_mesh
	coil.position = pos + Vector3(0.0, 2.25, 0.0)
	coil.material_override = _coil_mat
	coil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coil)


func _spawn_barrier_span(a: Vector3, b: Vector3) -> void:
	var span := b - a
	var length := span.length()
	var mid := (a + b) * 0.5
	var yaw := atan2(span.x, span.z)
	for h in [0.95, 1.85]:
		var rail := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.14, length)
		rail.mesh = bm
		rail.position = mid + Vector3(0.0, h, 0.0)
		rail.rotation.y = yaw
		rail.material_override = _barrier_mat
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rail)


func _redraw_electric_arcs() -> void:
	if _arc_mesh == null or _pylon_tops.size() < 2:
		return
	_arc_mesh.clear_surfaces()
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(_pylon_tops.size()):
		var a := _pylon_tops[i]
		var b := _pylon_tops[(i + 1) % _pylon_tops.size()]
		_emit_jagged_line(a, b, ARC_SEGMENTS_PER_SPAN, 0.24)
		_emit_jagged_line(a - Vector3(0.0, 1.0, 0.0), b - Vector3(0.0, 1.0, 0.0), ARC_SEGMENTS_PER_SPAN, 0.18)

	if _shock_flash_left > 0.0 and _player != null and is_instance_valid(_player):
		var p_pos := _player.global_position + Vector3(0.0, 1.0, 0.0)
		var rim_dir := Vector3(p_pos.x, 0.0, p_pos.z).normalized()
		if rim_dir.length_squared() > 0.01:
			var rim_pt := rim_dir * _radius_m + Vector3(0.0, 1.5, 0.0)
			_emit_jagged_line(rim_pt, p_pos, 6, 0.35)
			_emit_jagged_line(rim_pt + Vector3(0.0, -0.7, 0.0), p_pos, 5, 0.30)
	_arc_mesh.surface_end()


func _emit_jagged_line(a: Vector3, b: Vector3, segments: int, jitter: float) -> void:
	var prev := a
	for s in range(1, segments + 1):
		var t := float(s) / float(segments)
		var pt := a.lerp(b, t)
		if s < segments:
			pt += Vector3(_rng.randf_range(-jitter, jitter), _rng.randf_range(-jitter, jitter), _rng.randf_range(-jitter, jitter))
		_arc_mesh.surface_add_vertex(prev)
		_arc_mesh.surface_add_vertex(pt)
		prev = pt
