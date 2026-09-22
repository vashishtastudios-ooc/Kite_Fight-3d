extends Node3D

## Pech feel, one hit per swipe: a burst of glass sparks where the strings
## pass, a zing of manjha on manjha, and a buzz in the hands. Sparks spray down
## the string that lost the swipe; the zing rings higher when you won it.

const KiteSc := preload("res://scripts/kite.gd")

const MIX_RATE := 22050.0
const GRIND_MAX_DB := -4.0

var _sparks: GPUParticles3D
var _spark_pm: ParticleProcessMaterial
var _grind: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _level: float = 0.0        ## smoothed 0..1 grind loudness
var _pitch: float = 1.0        ## smoothed pitch factor
var _burst_t: float = 0.0

## Resonant noise filter + stick-slip rasp state.
var _lp: float = 0.0
var _bp: float = 0.0
var _slip_ph: float = 0.0
var _slip_hz: float = 55.0


func _ready() -> void:
	_build_sparks()
	_build_grind()


func tick(delta: float, _pech: Node) -> void:
	_burst_t = maxf(0.0, _burst_t - delta)
	_sparks.emitting = _burst_t > 0.0

	## Zing: a quick rasp that dies away after each bite.
	_level = move_toward(_level, 0.0, delta * 3.2)
	if _level > 0.01:
		if not _grind.playing:
			_grind.play()
			_playback = _grind.get_stream_playback()
		_grind.volume_db = linear_to_db(maxf(_level, 0.001)) + GRIND_MAX_DB
		_fill_grind()
	elif _grind.playing:
		_grind.stop()
		_playback = null


## One swipe landed: sparks spray down the loser's string, the rasp rings
## higher when the player won it, and the hands feel it.
func bite(at: Vector3, player: KiteSc, rival: KiteSc, strength: float, edge: float) -> void:
	var s := clampf(strength / 0.4, 0.25, 1.0)
	_burst_t = 0.1 + 0.2 * s
	_sparks.global_position = at
	_sparks.amount_ratio = clampf(0.35 + s * 0.65, 0.0, 1.0)
	_sparks.restart()
	var loser: KiteSc = player if edge < 0.0 else rival
	var down_line: Vector3 = loser.hand_pos - at
	var spray := Vector3.UP
	if down_line.length_squared() > 0.01 and absf(edge) > 0.1:
		spray = (down_line.normalized() * absf(edge) + Vector3.UP * 0.35).normalized()
	_spark_pm.direction = spray
	_spark_pm.spread = lerpf(60.0, 25.0, absf(edge))
	_spark_pm.initial_velocity_min = 4.0 + s * 4.0
	_spark_pm.initial_velocity_max = 8.0 + s * 10.0
	## Sparks keep a readable size on screen however far the crossing is.
	var cam := get_viewport().get_camera_3d()
	var far := 14.0
	if cam:
		far = cam.global_position.distance_to(at)
	var sc := clampf(far / 9.0, 1.0, 10.0)
	_spark_pm.scale_min = 0.5 * sc
	_spark_pm.scale_max = 1.2 * sc
	_level = maxf(_level, 0.45 + 0.55 * s)
	_pitch = 1.0 + 0.5 * edge
	var hurt := clampf(-edge, 0.0, 1.0)
	buzz(0.35 + 0.3 * s + 0.35 * hurt, 0.12 + 0.18 * s)


## Short rumble on pads and phones.
func buzz(strength: float, seconds: float) -> void:
	strength = clampf(strength, 0.0, 1.0)
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, strength * 0.6, strength, seconds)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(int(seconds * 1000.0), strength)


func _fill_grind() -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	## Glass-on-thread: band-passed noise whose centre rides the pitch, chopped
	## by a jittery stick-slip so it rasps rather than hisses.
	var fc := clampf(1300.0 * _pitch, 500.0, 4200.0)
	var f := 2.0 * sin(PI * fc / MIX_RATE)
	var damp := 0.32
	var slip_step := _slip_hz * _pitch / MIX_RATE
	for i in frames:
		var n := randf() * 2.0 - 1.0
		var hp := n - _lp - damp * _bp
		_bp += f * hp
		_lp += f * _bp
		_slip_ph += slip_step
		if _slip_ph >= 1.0:
			_slip_ph -= 1.0
			_slip_hz = randf_range(38.0, 78.0)
		var chop := 0.35 + 0.65 * (1.0 - _slip_ph) * (1.0 - _slip_ph)
		var v := clampf(_bp * 0.9 * chop + n * 0.06, -1.0, 1.0)
		_playback.push_frame(Vector2(v, v))


func _build_sparks() -> void:
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	tex.gradient = g

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.no_depth_test = false
	mat.disable_fog = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	quad.material = mat

	_spark_pm = ParticleProcessMaterial.new()
	_spark_pm.direction = Vector3.UP
	_spark_pm.spread = 40.0
	_spark_pm.initial_velocity_min = 3.0
	_spark_pm.initial_velocity_max = 9.0
	_spark_pm.gravity = Vector3(0.0, -7.0, 0.0)
	_spark_pm.damping_min = 1.5
	_spark_pm.damping_max = 3.5
	_spark_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_spark_pm.emission_sphere_radius = 0.12
	var ramp_g := Gradient.new()
	ramp_g.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	ramp_g.colors = PackedColorArray([
		Color(1.0, 1.0, 0.92, 1.0),
		Color(1.0, 0.86, 0.42, 1.0),
		Color(1.0, 0.45, 0.14, 0.7),
		Color(0.9, 0.2, 0.08, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = ramp_g
	_spark_pm.color_ramp = ramp

	_sparks = GPUParticles3D.new()
	_sparks.name = "GlassSparks"
	_sparks.amount = 96
	_sparks.lifetime = 0.5
	_sparks.explosiveness = 0.75
	_sparks.local_coords = false
	_sparks.emitting = false
	_sparks.process_material = _spark_pm
	_sparks.draw_pass_1 = quad
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	add_child(_sparks)


func _build_grind() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.12
	_grind = AudioStreamPlayer.new()
	_grind.name = "ManjhaGrind"
	_grind.stream = gen
	_grind.volume_db = -60.0
	add_child(_grind)
