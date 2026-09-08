extends Node3D

const WindSys := preload("res://scripts/wind_system.gd")
const CityGen := preload("res://scripts/city_generator.gd")
const PlayerSc := preload("res://scripts/player.gd")
const KiteSc := preload("res://scripts/kite.gd")
const HudSc := preload("res://scripts/hud.gd")
const WindsockSc := preload("res://scripts/windsock.gd")
const PechSc := preload("res://scripts/pech.gd")
const RivalAISc := preload("res://scripts/rival_ai.gd")
const CHARKHI := preload("res://assets/terrace/pink thread spool 3d model.glb")
const SettingsSc := preload("res://scripts/game_settings.gd")
const PersonSc := preload("res://scripts/rooftop_person.gd")

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var wind: WindSys = $WindSystem
@onready var city: CityGen = $City
@onready var player: PlayerSc = $Player
@onready var kite: KiteSc = $Kite
@onready var hud: HudSc = $HUD
@onready var rival: KiteSc = $RivalKite
@onready var pech: PechSc = $Pech

var _reel: float = 0.0
var _launch_look: float = 0.0
var _rival_ai: RivalAISc
var _kheench_held: bool = false
var _dheel_held: bool = false
var _kite_back_cam: Camera3D
var _back_view: bool = false
var _intro_active: bool = true
var _intro_cam: Camera3D
var _intro_cam_start: Transform3D = Transform3D.IDENTITY
var _intro_cam_start_fov: float = 74.0
var _intro_cam_t: float = 0.0
const INTRO_CAM_DUR := 6.0


func _ready() -> void:
	_bind_input()
	_configure_world()
	city.build()
	## Point the sea's sun-glint at the actual sun so the golden path lines up.
	city.set_water_sun(-sun.global_transform.basis.z)
	wind.rooftop_height = city.rooftop_height
	player.global_position = city.spawn_position
	player.rooftop_bounds = city.rooftop_bounds
	player.rooftop_y = city.spawn_position.y
	player.look_yaw = 0.0
	player.look_pitch = -0.06
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var settings := SettingsSc.new()
	settings.load_from_disk()
	settings.apply(self)
	player.setup_avatar()
	_build_handle()
	kite.setup(wind, city)
	kite.hand_pos = player.hand_position()
	var rival_colors: Array[Color] = [
		Color(0.18, 0.62, 0.28),
		Color(0.95, 0.86, 0.22),
		Color(0.12, 0.48, 0.22),
		Color(0.98, 0.95, 0.82),
	]
	rival.setup(wind, city, rival_colors)
	rival.is_ai = true
	var rival_hand := city.rival_hand_position()
	rival.hand_pos = rival_hand
	_rival_ai = RivalAISc.new()
	_rival_ai.name = "RivalAI"
	add_child(_rival_ai)
	_rival_ai.setup(rival, kite, pech, rival_hand)
	hud.game_settings = settings
	hud.graphics_host = self
	hud.setup(wind, kite, rival, pech)
	var rockets := preload("res://scripts/diwali_rockets.gd").new()
	rockets.name = "DiwaliRockets"
	add_child(rockets)
	rockets.setup(kite, city)
	hud.player = player
	hud.rockets = rockets
	_setup_kite_cams()
	_place_windsock()
	_place_people()
	var air := preload("res://scripts/wind_vfx.gd").new()
	air.name = "WindVfx"
	add_child(air)
	air.setup(wind, city.spawn_position)
	wind.sample(player.global_position + Vector3(0.0, 4.0, -8.0), 0.2, true)
	## Cold open on the sky. The in-hand charkhi and the rooftop flyer read as
	## "ready"; the 1.5m sail is hidden until the toss so it never fills the
	## title frame. The rival waits on its roof until you launch.
	kite.visible = false
	rival.visible = false
	_snap_camera_to_sky()
	_setup_intro_cam()
	if hud:
		hud.show_intro()
	print("Patang rooftop ready. Buildings: %d  Rocket pads: %d" % [city.building_aabbs.size(), city.rocket_pads.size()])


func _setup_kite_cams() -> void:
	_kite_back_cam = Camera3D.new()
	_kite_back_cam.name = "KiteBackCam"
	_kite_back_cam.fov = 58.0
	_kite_back_cam.near = 0.12
	_kite_back_cam.far = 2200.0
	_kite_back_cam.current = false
	add_child(_kite_back_cam)
	if player and player.camera and player.camera.environment:
		_kite_back_cam.environment = player.camera.environment


func _set_back_view(on: bool) -> void:
	_back_view = on
	if player and player.camera:
		player.camera.current = not on
	if _kite_back_cam:
		_kite_back_cam.current = on


func _update_kite_cams() -> void:
	if kite == null or player == null or player.camera == null:
		return
	var kp := kite.global_position
	var pp := player.camera.global_position
	var to_kite := kp - pp
	if to_kite.length_squared() < 0.2:
		to_kite = -player.camera.global_transform.basis.z
	var view := to_kite.normalized()
	if _kite_back_cam:
		_kite_back_cam.global_position = kp + view * 5.4 + Vector3.UP * 1.15
		_cam_look(_kite_back_cam, player.global_position + Vector3(0.0, 1.35, 0.0))


func _cam_look(cam: Camera3D, target: Vector3, up: Vector3 = Vector3.UP) -> void:
	var d := target - cam.global_position
	if d.length_squared() < 0.04:
		return
	if up.length_squared() < 0.01:
		up = Vector3.UP
	if absf(d.normalized().dot(up.normalized())) > 0.94:
		up = Vector3.RIGHT
	cam.look_at(target, up)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if hud and hud.over_controls():
			pass
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_reel = 1.6
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_reel = -1.6
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	var bias := Input.get_action_strength("bias_right") - Input.get_action_strength("bias_left")
	var reel := _reel
	reel += Input.get_action_strength("reel_out") - Input.get_action_strength("reel_in")
	_reel = move_toward(_reel, 0.0, delta * 4.0)
	var kheench := Input.is_action_pressed("kheench")
	var dheel := Input.is_action_pressed("dheel")
	if kheench:
		dheel = false
	var hand := player.hand_position()
	var viewer := player.camera.global_position

	if Input.is_action_just_pressed("launch"):
		if kite.phase == KiteSc.Phase.GROUNDED or kite.phase == KiteSc.Phase.CRASHED or kite.phase == KiteSc.Phase.CUT:
			kite.launch()
			_launch_look = 1.6
	if Input.is_action_just_pressed("relaunch"):
		kite.relaunch()
		_launch_look = 1.4

	## First toss clears the title, hands the view to first person, and sends
	## the rival up to meet you.
	if _intro_active and kite.is_airborne():
		_intro_active = false
		kite.visible = true
		if _intro_cam:
			_intro_cam.current = false
			_intro_cam.queue_free()
			_intro_cam = null
		if player.camera:
			player.camera.current = true
		rival.visible = true
		rival.launch()
		_launch_look = 2.0
		if hud:
			hud.hide_intro()

	if kheench != _kheench_held:
		kite.set_kheench(kheench)
		if kheench:
			player.kick_speed_fov()
			player.yank_spool()
		_kheench_held = kheench
	if dheel != _dheel_held:
		kite.set_dheel(dheel)
		if dheel:
			player.sag_spool()
		_dheel_held = dheel

	kite.tick(delta, hand, viewer, reel, bias)
	## Hold the rival on its roof during the title — its AI would otherwise
	## relaunch and dive the parked patang straight into the frame.
	if _rival_ai and not _intro_active:
		_rival_ai.tick(delta)
	if pech:
		pech.tick(delta, kite, rival)
	player.tick(delta, kite.tension, kite.pull, kite.slack, bias, kite.payout_rate, hud.zoom if hud else 0.0, kheench, dheel)

	if Input.is_action_just_pressed("kite_back_view"):
		_set_back_view(not _back_view)

	_update_kite_cams()

	if not _back_view:
		_follow_kite_cam(delta)
	if _intro_active and _intro_cam:
		_update_intro_cam(delta)
	_launch_look = maxf(0.0, _launch_look - delta)


func _follow_kite_cam(delta: float) -> void:
	if kite == null:
		return
	if not kite.is_airborne():
		var rest := _intro_look_target() if _intro_active else _sky_look_target()
		player.look_towards(rest, delta, 2.6)
		return
	## Keep the boy in the lower frame. Aim between a shoulder shot and the kite
	## so a high dart does not become only sky, and a close kite does not spin off him.
	var kite_pt := kite.global_position + kite.velocity * 0.16
	var chest := player.global_position + Vector3(0.0, 0.9, 0.0)
	var face := Vector3(-sin(player.look_yaw), 0.0, -cos(player.look_yaw))
	var framed := chest + face * 14.0 + Vector3(0.0, 5.2, 0.0)
	var to_k := kite_pt - player.global_position
	to_k.y = 0.0
	var behind := to_k.dot(face) < 2.0
	var dist := player.global_position.distance_to(kite.global_position)
	var kite_w := 0.0 if behind else lerpf(0.22, 0.48, clampf((dist - 10.0) / 50.0, 0.0, 1.0))
	var aim := framed.lerp(kite_pt, kite_w)
	var w := 4.6
	if kite.phase == KiteSc.Phase.FLY:
		w = 7.5
	elif kite.phase == KiteSc.Phase.DHEEL or kite.phase == KiteSc.Phase.CUT:
		w = 6.0
	elif kite.phase == KiteSc.Phase.SPIN:
		w = 5.2
	elif _launch_look > 0.0:
		w = 6.5
	player.look_towards(aim, delta, w)


func _sky_look_target() -> Vector3:
	## Up ~31° and out over the open fly window (-Z), so the frame holds sky
	## and the far skyline — where the patang is about to climb.
	return player.hand_position() + Vector3(0.0, 24.0, -40.0)


func _intro_look_target() -> Vector3:
	## Over the boy's shoulder into the fly window — third-person title.
	return player.global_position + Vector3(0.0, 12.0, -26.0)


func _setup_intro_cam() -> void:
	## A cinematic that opens on a wide, hazy city vista and glides down into
	## the over-shoulder rooftop shot, then hands off on the toss.
	_intro_cam = Camera3D.new()
	_intro_cam.name = "IntroCam"
	_intro_cam.fov = _intro_cam_start_fov
	_intro_cam.near = 0.2
	_intro_cam.far = 2400.0
	if player and player.camera and player.camera.environment:
		_intro_cam.environment = player.camera.environment
	add_child(_intro_cam)
	var sp := city.spawn_position
	_intro_cam.global_position = Vector3(sp.x, city.rooftop_height + 95.0, sp.z + 70.0)
	_intro_cam.look_at(Vector3(sp.x, city.rooftop_height + 45.0, sp.z - 480.0), Vector3.UP)
	_intro_cam_start = _intro_cam.global_transform
	_intro_cam_t = 0.0
	_intro_cam.current = true


func _update_intro_cam(delta: float) -> void:
	if _intro_cam == null or player == null or player.camera == null:
		return
	_intro_cam_t = minf(1.0, _intro_cam_t + delta / INTRO_CAM_DUR)
	## Ease in-out for a settled, filmic move.
	var e := smoothstep(0.0, 1.0, _intro_cam_t)
	var end_xf := player.camera.global_transform
	var pos := _intro_cam_start.origin.lerp(end_xf.origin, e)
	var q0 := _intro_cam_start.basis.get_rotation_quaternion()
	var q1 := end_xf.basis.get_rotation_quaternion()
	_intro_cam.global_transform = Transform3D(Basis(q0.slerp(q1, e)), pos)
	_intro_cam.fov = lerpf(_intro_cam_start_fov, player.camera.fov, e)


func _snap_camera_to_sky() -> void:
	if player == null or player.camera == null:
		return
	var tgt := _intro_look_target() if _intro_active else _sky_look_target()
	var to := tgt - player.camera.global_position
	if to.length() < 0.2:
		return
	player.look_yaw = atan2(-to.x, -to.z)
	player.look_pitch = clampf(atan2(to.y, Vector3(to.x, 0.0, to.z).length()), deg_to_rad(-80.0), deg_to_rad(75.0))


func _configure_world() -> void:
	## Dusk, not night: sun ~10° up, warmer and dimmer than late afternoon.
	sun.rotation_degrees = Vector3(-10.0, 122.0, 0.0)
	sun.light_color = Color(1.0, 0.72, 0.50)
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.shadow_blur = 2.1
	sun.light_angular_distance = 0.95
	## Only the hub block casts shadows, so keep the cascade tight.
	sun.directional_shadow_max_distance = 150.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/stylized_sky.gdshader")
	sky_mat.set_shader_parameter("clouds_texture", _cloud_noise(11, 0.010, 5))
	sky_mat.set_shader_parameter("clouds_distort_texture", _cloud_noise(29, 0.018, 4))
	sky_mat.set_shader_parameter("clouds_noise_texture", _cloud_noise(47, 0.040, 3))
	sky_mat.set_shader_parameter("day_top_color", Color(0.14, 0.20, 0.40))
	sky_mat.set_shader_parameter("day_bottom_color", Color(0.38, 0.32, 0.40))
	sky_mat.set_shader_parameter("horizon_color_day", Color(0.78, 0.50, 0.30))
	sky_mat.set_shader_parameter("sunset_bottom_color", Color(0.58, 0.34, 0.26))
	sky_mat.set_shader_parameter("sunset_top_color", Color(0.16, 0.18, 0.36))
	sky_mat.set_shader_parameter("horizon_color_sunset", Color(0.82, 0.46, 0.22))
	sky_mat.set_shader_parameter("clouds_main_color", Color(0.62, 0.56, 0.58))
	sky_mat.set_shader_parameter("clouds_edge_color", Color(0.48, 0.42, 0.50))
	sky_mat.set_shader_parameter("clouds_speed", 0.048)
	sky_mat.set_shader_parameter("clouds_scale", 0.09)
	sky_mat.set_shader_parameter("clouds_cutoff", 0.26)
	sky_mat.set_shader_parameter("clouds_fuzziness", 0.28)
	sky_mat.set_shader_parameter("clouds_opacity", 0.78)
	sky_mat.set_shader_parameter("sun_col", Color(1.0, 0.58, 0.22))
	sky_mat.set_shader_parameter("sun_size", 0.085)
	sky_mat.set_shader_parameter("sun_blur", 0.12)
	## Lower falloff spreads the warm horizon glow higher, so there is always a
	## sliver of atmosphere at the rim, even looking down from high up.
	sky_mat.set_shader_parameter("horizon_falloff", 4.5)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.46
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 5.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	## Warm dusk haze that matches the horizon sky, so the far city dissolves
	## into the same colour it is seen against instead of a grey seam.
	env.fog_light_color = Color(0.90, 0.66, 0.56)
	env.fog_density = 0.0013
	## Aerial perspective at full: distant geometry AND ground take the exact sky
	## colour behind them, so the far ground is indistinguishable from the
	## horizon haze — no empty band at the edges, just seamless atmosphere.
	env.fog_aerial_perspective = 1.0
	## Haze the horizon band of the sky too, so the line where city meets sky is
	## soft rather than a hard edge.
	env.fog_sky_affect = 0.55
	env.fog_depth_begin = 300.0
	## Opened back up now that the sea fills the distance — the city fades into
	## haze over the water, and the water has its own horizon dissolve.
	env.fog_depth_end = 1200.0
	env.fog_depth_curve = 0.9
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.35
	env.ssil_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.30
	env.glow_bloom = 0.09
	env.glow_hdr_threshold = 0.78
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.94
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	world_env.environment = env
	if player and player.camera:
		player.camera.environment = env
		player.camera.far = 2200.0

	var fill := get_node_or_null("FillLight") as DirectionalLight3D
	if fill == null:
		fill = DirectionalLight3D.new()
		fill.name = "FillLight"
		add_child(fill)
	fill.rotation_degrees = Vector3(-14.0, -48.0, 0.0)
	fill.light_color = Color(0.38, 0.40, 0.58)
	fill.light_energy = 0.10
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY


func _cloud_noise(noise_seed: int, freq: float, octaves: int) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = noise_seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	var img := n.get_seamless_image(512, 512)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _build_handle() -> void:
	var handle := player.handle
	if handle == null:
		return
	var firki := Node3D.new()
	firki.name = "Firki"
	handle.add_child(firki)
	firki.position = Vector3.ZERO
	var model := CHARKHI.instantiate() as Node3D
	if model == null:
		return
	firki.add_child(model)
	_hide_tripo_ground(model)
	model.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	model.force_update_transform()
	var aabb := _mesh_aabb(model)
	var disc := maxf(aabb.size.x, aabb.size.z)
	if disc < 0.02:
		disc = maxf(aabb.size.y * 0.22, 0.08)
	var s := 0.13 / disc
	model.scale = Vector3(s, s, s)
	model.force_update_transform()
	aabb = _mesh_aabb(model)
	model.global_position += firki.global_position - aabb.get_center()
	_no_shadow(model)
	var line_at := Marker3D.new()
	line_at.name = "LineOrigin"
	handle.add_child(line_at)
	line_at.position = firki.position + Vector3(0.0, 0.02, -0.06)


func _hide_tripo_ground(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var aabb := mi.get_aabb()
		if aabb.size.y < 0.22 and maxf(aabb.size.x, aabb.size.z) > 1.6 and aabb.position.y < 0.35:
			mi.visible = false
	for child in node.get_children():
		_hide_tripo_ground(child)


func _no_shadow(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_no_shadow(child)


func _mesh_aabb(node: Node) -> AABB:
	var acc := AABB()
	var first := true
	if node is VisualInstance3D:
		var local: AABB = (node as VisualInstance3D).get_aabb()
		var xf := (node as Node3D).global_transform
		acc = xf * local
		first = false
	for child in node.get_children():
		var sub := _mesh_aabb(child)
		if sub.size.length_squared() < 0.0001:
			continue
		if first:
			acc = sub
			first = false
		else:
			acc = acc.merge(sub)
	return acc


func _place_people() -> void:
	var sky := city.spawn_position + Vector3(0.0, 6.0, -50.0)
	var mate := PersonSc.new()
	mate.name = "TerraceMate"
	add_child(mate)
	var b := city.rooftop_bounds
	var feet := Vector3(b.end.x - 0.9, city.rooftop_height + 0.02, city.spawn_position.z - 0.35)
	feet.x = clampf(feet.x, b.position.x + 0.45, b.end.x - 0.45)
	feet.z = clampf(feet.z, b.position.y + 0.45, b.end.y - 0.45)
	mate.setup(feet, sky)

	if city.rocket_pads.is_empty():
		return
	var other := PersonSc.new()
	other.name = "RoofFlyer"
	add_child(other)
	other.setup(city.rocket_pads[0], city.spawn_position)


func _place_windsock() -> void:
	var sock := WindsockSc.new()
	sock.name = "Windsock"
	city.add_child(sock)
	sock.global_position = Vector3(city.rooftop_bounds.end.x - 0.55, city.rooftop_height + 0.05, city.rooftop_bounds.end.y - 0.9)
	sock.setup(wind)


func _bind_input() -> void:
	_add_key("walk_forward", KEY_W)
	_add_key("walk_back", KEY_S)
	_add_key("walk_left", KEY_A)
	_add_key("walk_right", KEY_D)
	_add_key("sprint", KEY_SHIFT)
	_add_key("kheench", KEY_Q)
	_strip_mouse("kheench")
	_add_key("dheel", KEY_E)
	_strip_mouse("dheel")
	_add_key("bias_left", KEY_LEFT)
	_add_key("bias_right", KEY_RIGHT)
	_add_key("reel_in", KEY_UP)
	_add_key("reel_out", KEY_DOWN)
	_add_key("launch", KEY_SPACE)
	_add_key("relaunch", KEY_R)
	_add_key("look_kite", KEY_F)
	_add_key("kite_back_view", KEY_V)


func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	if not _has_event(action, ev):
		InputMap.action_add_event(action, ev)


func _strip_mouse(action: String) -> void:
	if not InputMap.has_action(action):
		return
	var drop: Array[InputEvent] = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventMouseButton:
			drop.append(ev)
	for ev in drop:
		InputMap.action_erase_event(action, ev)


func _add_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	if not _has_event(action, ev):
		InputMap.action_add_event(action, ev)


func _has_event(action: String, ev: InputEvent) -> bool:
	for existing in InputMap.action_get_events(action):
		if existing.as_text() == ev.as_text():
			return true
	return false
