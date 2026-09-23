extends Node3D

const WindSys := preload("res://scripts/wind_system.gd")
const MapBase := preload("res://scripts/map_base.gd")
const PahadiSc := preload("res://scripts/map_pahadi.gd")
const MapRegistry := preload("res://scripts/map_registry.gd")
var _map_id: String = "city"
var _flyer_id: String = ""
const PlayerSc := preload("res://scripts/player.gd")
const KiteSc := preload("res://scripts/kite.gd")
const HudSc := preload("res://scripts/hud.gd")
const WindsockSc := preload("res://scripts/windsock.gd")
const PechSc := preload("res://scripts/pech.gd")
const RivalAISc := preload("res://scripts/rival_ai.gd")
const CHARKHI := preload("res://assets/terrace/pink thread spool 3d model.glb")
const SettingsSc := preload("res://scripts/game_settings.gd")
const PersonSc := preload("res://scripts/rooftop_person.gd")
const KiteSkins := preload("res://scripts/kite_skins.gd")
const TitleKiteSc := preload("res://scripts/title_kite.gd")
const ProfileSc := preload("res://scripts/profile.gd")
const NetRoomSc := preload("res://scripts/net_room.gd")

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var wind: WindSys = $WindSystem
@onready var city: MapBase = $City
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
var _cam_chase: bool = false
var _flyer_picked: bool = false
var _character_picked: bool = false
var _game_mode: String = ""
var _rockets: Node
var _char_ui_shown: bool = false
var _preview_boy: PersonSc
var _preview_girl: PersonSc
var _palace_girl: PersonSc
var _terrace_mate: PersonSc
var _title_kite: Node3D
var _profile: ProfileSc
var _match_cuts: int = 0
var _match_paid: bool = false
var _save_dodges: int = 0
var _save_paid: bool = false
var _net: NetRoomSc
var _online: bool = false
var _net_live: bool = false
var _peer_card: Dictionary = {}
var _peer_id: String = ""
var _remote_state: Dictionary = {}
var _send_t: float = 0.0
var _wind_audio: Node
const INTRO_CAM_DUR := 6.0
const BODY_BOY := preload("res://assets/people/stylized+boy+3d+model (1).glb")
const BODY_GIRL := preload("res://assets/people/stylized+female+3d+newmodel.glb")


func _ready() -> void:
	_bind_input()
	_swap_map()
	_configure_world()
	city.build()
	city.configure_world(world_env.environment, sun)
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
	_profile = ProfileSc.new()
	_profile.load_from_disk()
	## Testing: editor/debug runs top coins up to 1000 so any kite can be bought.
	## is_debug_build() is false in release exports, so this never ships.
	if OS.is_debug_build() and _profile.coins < 1000:
		_profile.coins = 1000
	var sync := preload("res://scripts/profile_sync.gd").new()
	sync.name = "ProfileSync"
	add_child(sync)
	_profile.cloud_push = sync.push
	sync.setup(_profile)
	if _profile.owns(_profile.kite_id):
		settings.kite_id = _profile.kite_id
	settings.apply(self)
	player.intro_lock = true
	if player.camera:
		player.camera.far = 2400.0
	kite.setup(wind, city, [], settings.kite_id)
	kite.hand_pos = player.hand_position()
	var rival_colors: Array[Color] = [
		Color(0.18, 0.62, 0.28),
		Color(0.95, 0.86, 0.22),
		Color(0.12, 0.48, 0.22),
		Color(0.98, 0.95, 0.82),
	]
	rival.is_rival = true
	rival.setup(wind, city, rival_colors, KiteSkins.rival_id(settings.kite_id))
	rival.is_ai = true
	var rival_hand := city.rival_hand_position()
	rival.hand_pos = rival_hand
	_rival_ai = RivalAISc.new()
	_rival_ai.name = "RivalAI"
	add_child(_rival_ai)
	_rival_ai.setup(rival, kite, pech, rival_hand)
	hud.game_settings = settings
	hud.profile = _profile
	hud.graphics_host = self
	hud.setup(wind, kite, rival, pech)
	hud.character_chosen.connect(_on_character_chosen)
	hud.mode_chosen.connect(_on_mode_chosen)
	hud.map_chosen.connect(_on_map_chosen)
	hud.current_map_id = _map_id
	## Arrived from the map grid: skip the opening and land on mode select
	## with the same flyer.
	if Engine.has_meta("travel_flyer"):
		var flyer := str(Engine.get_meta("travel_flyer"))
		Engine.remove_meta("travel_flyer")
		call_deferred("_land_after_travel", flyer)
	hud.online_host.connect(_on_online_host)
	hud.online_join.connect(_on_online_join)
	hud.title_requested.connect(_return_to_title)
	_net = NetRoomSc.new()
	_net.name = "NetRoom"
	add_child(_net)
	_net.waiting.connect(_on_net_waiting)
	_net.live.connect(_on_net_live)
	_net.peer_ready.connect(_on_net_peer)
	_net.remote_state.connect(_on_net_state)
	_net.kaata.connect(_on_net_kaata)
	_net.gone.connect(_on_net_gone)
	_net.fail.connect(_on_net_fail)
	wind.origin = city.spawn_position
	if city.has_method("set_wind"):
		city.set_wind(wind)
	if pech:
		pech.wind = wind
		pech.kaata.connect(_on_match_kaata)
		pech.cut_wanted.connect(_on_cut_wanted)
	if kite:
		kite.cut_down.connect(_on_player_cut)
	_rockets = preload("res://scripts/diwali_rockets.gd").new()
	_rockets.name = "DiwaliRockets"
	add_child(_rockets)
	_rockets.setup(kite, city)
	if _rockets.has_signal("player_dodged"):
		_rockets.player_dodged.connect(_on_player_dodged)
	hud.player = player
	hud.rockets = _rockets
	_rockets.enabled = false
	_setup_kite_cams()
	_place_windsock()
	_place_people()
	var air := preload("res://scripts/wind_vfx.gd").new()
	air.name = "WindVfx"
	add_child(air)
	air.setup(wind, city.spawn_position)
	var far_kites := preload("res://scripts/sky_kites.gd").new()
	far_kites.name = "SkyKites"
	add_child(far_kites)
	far_kites.setup(wind, city.spawn_position)
	var wind_audio := preload("res://scripts/wind_audio.gd").new()
	wind_audio.name = "WindAudio"
	add_child(wind_audio)
	wind_audio.setup(wind)
	_wind_audio = wind_audio
	wind.sample(player.global_position + Vector3(0.0, 4.0, -8.0), 0.2, true)
	## Cold open on the sky. The in-hand charkhi and the rooftop flyer read as
	## "ready"; the 1.5m sail is hidden until the toss so it never fills the
	## title frame. The rival waits on its roof until you launch.
	kite.visible = false
	rival.visible = false
	_snap_camera_to_sky()
	_setup_intro_cam()
	_spawn_title_kite()
	if hud:
		hud.set_letterbox(true, "Jaipur dusk. One roof. Two strings.", "SPACE  skip")
	print("Kite Battle 3d rooftop ready. Play-area buildings: %d  Rocket pads: %d" % [city.building_aabbs.size(), city.rocket_pads.size()])
	## Dev: capture a map card image into assets/ui/maps (THUMB_SHOT=<map id>,
	## run windowed with KITE_MAP set to the same id). Re-run when a map changes.
	var thumb := OS.get_environment("THUMB_SHOT")
	if thumb != "":
		hud.visible = false
		if _title_kite:
			_title_kite.visible = false
		var tcam := Camera3D.new()
		tcam.fov = 58.0
		tcam.far = 2600.0
		tcam.environment = player.camera.environment
		add_child(tcam)
		var sp := city.spawn_position
		if thumb == "pahadi":
			tcam.global_position = sp + Vector3(26.0, 26.0, 46.0)
			tcam.look_at(sp + Vector3(-10.0, 12.0, -260.0), Vector3.UP)
		else:
			tcam.global_position = sp + Vector3(18.0, 34.0, 40.0)
			tcam.look_at(sp + Vector3(-6.0, 10.0, -300.0), Vector3.UP)
		tcam.current = true
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			var img := get_viewport().get_texture().get_image()
			img.resize(960, 540, Image.INTERPOLATE_LANCZOS)
			img.save_jpg("res://assets/ui/maps/%s.jpg" % thumb, 0.88)
			print("thumb saved ", thumb)
			get_tree().quit())


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
		if _intro_active and not _char_ui_shown and mb.button_index == MOUSE_BUTTON_LEFT:
			_skip_intro_cam()
			get_viewport().set_input_as_handled()
			return
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

	if Input.is_action_just_pressed("launch") and _flyer_picked:
		if kite.phase == KiteSc.Phase.GROUNDED or kite.phase == KiteSc.Phase.CRASHED or kite.phase == KiteSc.Phase.CUT:
			kite.launch()
			_launch_look = 1.6
	elif Input.is_action_just_pressed("launch") and _intro_active and not _char_ui_shown:
		_skip_intro_cam()
	if Input.is_action_just_pressed("relaunch"):
		kite.relaunch()
		_launch_look = 1.4
		_save_paid = false
		_save_dodges = 0

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
		if _game_mode == "battle":
			rival.visible = true
			if not _online and not rival.is_airborne():
				rival.launch()
		else:
			rival.visible = false
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
	if _online:
		if _net_live:
			if not _remote_state.is_empty():
				rival.apply_net(_remote_state, delta)
			_send_t += delta
			if _send_t >= 0.05:
				_send_t = 0.0
				if _net:
					_net.send_state(kite.pack_net())
	elif _rival_ai and _game_mode == "battle":
		_rival_ai.tick(delta)
	if pech and _game_mode == "battle":
		pech.tick(delta, kite, rival)
		player.set_pech_push(pech.grind())
	else:
		player.set_pech_push(0.0)
	player.tick(delta, kite.tension, kite.pull, kite.slack, bias, kite.payout_rate, hud.zoom if hud else 0.0, kheench, dheel)

	if Input.is_action_just_pressed("kite_back_view"):
		_set_back_view(not _back_view)

	_update_kite_cams()

	if not _back_view:
		_follow_kite_cam(delta)
	if _intro_active and _intro_cam:
		_update_intro_cam(delta)
		if not _char_ui_shown and _intro_cam_t >= 1.0:
			_finish_intro_cam()
	_launch_look = maxf(0.0, _launch_look - delta)


func _follow_kite_cam(delta: float) -> void:
	if kite == null:
		return
	if not kite.is_airborne():
		_cam_chase = false
		var rest := _intro_look_target() if _intro_active else _sky_look_target()
		player.look_towards(rest, delta, 2.6)
		return
	var kite_pt := kite.global_position + kite.velocity * 0.22
	var alt := kite.global_position.y - player.global_position.y
	var off := _kite_leaving_view(kite_pt)
	if off or alt > 12.0:
		_cam_chase = true
	elif _kite_well_in_view(kite_pt) and alt < 8.0:
		_cam_chase = false
	if _cam_chase:
		var w := 10.0 if kite.phase == KiteSc.Phase.FLY else 7.5
		if alt > 25.0:
			w = 12.5
		player.look_towards(kite_pt, delta, w, true)
		return
	var chest := player.global_position + Vector3(0.0, 0.9, 0.0)
	var face := Vector3(-sin(player.look_yaw), 0.0, -cos(player.look_yaw))
	var framed := chest + face * 14.0 + Vector3(0.0, 5.2, 0.0)
	var to_k := kite_pt - player.global_position
	to_k.y = 0.0
	var behind := to_k.dot(face) < 2.0
	var dist := player.global_position.distance_to(kite.global_position)
	var kite_w := 0.0 if behind else lerpf(0.22, 0.48, clampf((dist - 10.0) / 50.0, 0.0, 1.0))
	var aim := framed.lerp(kite_pt, kite_w)
	player.look_towards(aim, delta, 5.0)


func _kite_leaving_view(pt: Vector3) -> bool:
	return _kite_screen_margin(pt) < 0.08


func _kite_well_in_view(pt: Vector3) -> bool:
	return _kite_screen_margin(pt) > 0.18


func _kite_screen_margin(pt: Vector3) -> float:
	if player == null or player.camera == null:
		return 1.0
	var cam := player.camera
	if cam.is_position_behind(pt):
		return -1.0
	var sp: Vector2 = cam.unproject_position(pt)
	var sz: Vector2 = cam.get_viewport().get_visible_rect().size
	if sz.x < 8.0 or sz.y < 8.0:
		return 1.0
	var mx := minf(sp.x / sz.x, 1.0 - sp.x / sz.x)
	var my := minf(sp.y / sz.y, 1.0 - sp.y / sz.y)
	return minf(mx, my)


func _sky_look_target() -> Vector3:
	## Up ~31° and out over the open fly window (-Z), so the frame holds sky
	## and the far skyline — where the patang is about to climb.
	return player.hand_position() + Vector3(0.0, 24.0, -40.0)


func _intro_look_target() -> Vector3:
	## During boy/girl pick, tilt down so both idle flyers read on the terrace.
	if _char_ui_shown and not _character_picked:
		return player.global_position + Vector3(0.0, 2.2, -7.5)
	## Over the flyer's shoulder into the fly window — third-person title.
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


func _spawn_title_kite() -> void:
	_title_kite = TitleKiteSc.new()
	_title_kite.name = "TitleKite"
	add_child(_title_kite)
	_title_kite.setup(Vector3(city.spawn_position.x, city.rooftop_height, city.spawn_position.z))


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


func _skip_intro_cam() -> void:
	if _intro_cam == null or _char_ui_shown:
		return
	_intro_cam_t = 1.0
	_update_intro_cam(0.0)
	_finish_intro_cam()


func _finish_intro_cam() -> void:
	if _char_ui_shown:
		return
	_char_ui_shown = true
	if hud:
		hud.show_character_select()
	if _title_kite and _title_kite.has_method("recede"):
		_title_kite.recede()
		_title_kite = null


func _ensure_preview_people() -> void:
	var cam := city.spawn_position + Vector3(0.0, 1.45, 3.4)
	if _preview_boy == null or not is_instance_valid(_preview_boy):
		_preview_boy = PersonSc.new()
		_preview_boy.name = "PreviewBoy"
		add_child(_preview_boy)
		_preview_boy.setup(city.spawn_position + Vector3(-1.55, 0.0, -2.15), cam, null, BODY_BOY, false, true)
	if _preview_girl == null or not is_instance_valid(_preview_girl):
		_preview_girl = PersonSc.new()
		_preview_girl.name = "PreviewGirl"
		add_child(_preview_girl)
		_preview_girl.setup(city.spawn_position + Vector3(1.55, 0.0, -2.15), cam, null, BODY_GIRL, false, true)


func _return_to_title() -> void:
	_online = false
	_net_live = false
	_peer_card = {}
	_peer_id = ""
	_remote_state = {}
	if _net and _net.has_method("hangup"):
		_net.hangup()
	_flyer_picked = false
	_character_picked = false
	_game_mode = ""
	_intro_active = true
	_char_ui_shown = false
	_cam_chase = false
	_match_cuts = 0
	_match_paid = false
	_save_dodges = 0
	_save_paid = false
	_kheench_held = false
	_dheel_held = false
	_launch_look = 0.0
	if pech:
		pech.net_mode = false
		pech.player_wins = 0
		pech.rival_wins = 0
	if _rockets:
		_rockets.enabled = false
	_set_back_view(false)
	if kite:
		kite.set_kheench(false)
		kite.set_dheel(false)
		kite.park_on_roof()
		kite.visible = false
	if rival:
		rival.is_ai = true
		rival.park_on_roof()
		rival.visible = false
	if player:
		player.intro_lock = true
		player.clear_avatar()
		player.global_position = city.spawn_position
		player.look_yaw = 0.0
		player.look_pitch = -0.06
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _terrace_mate:
		_terrace_mate.queue_free()
		_terrace_mate = null
	_ensure_preview_people()
	if _intro_cam:
		_intro_cam.queue_free()
		_intro_cam = null
	if player and player.camera:
		player.camera.current = false
	_setup_intro_cam()
	_snap_camera_to_sky()
	if _title_kite:
		_title_kite.queue_free()
		_title_kite = null
	_spawn_title_kite()
	if hud:
		hud.reset_to_title()
		hud.set_letterbox(true, "Jaipur dusk. One roof. Two strings.", "SPACE  skip")


func _snap_camera_to_sky() -> void:
	if player == null or player.camera == null:
		return
	var tgt := _intro_look_target() if _intro_active else _sky_look_target()
	var to := tgt - player.camera.global_position
	if to.length() < 0.2:
		return
	player.look_yaw = atan2(-to.x, -to.z)
	player.look_pitch = clampf(atan2(to.y, Vector3(to.x, 0.0, to.z).length()), deg_to_rad(-80.0), deg_to_rad(75.0))


## The City node in the scene is the Jaipur map — the opening always plays
## there. Picking another map in the grid reloads the scene with the choice
## kept on Engine meta, and that map replaces the city before anything is
## built. KITE_MAP overrides (dev).
func _swap_map() -> void:
	var id := OS.get_environment("KITE_MAP")
	if id == "" and Engine.has_meta("travel_map"):
		id = str(Engine.get_meta("travel_map"))
	_map_id = id if MapRegistry.has(id) else "city"
	if _map_id != "pahadi":
		return
	var old := city
	var m := PahadiSc.new()
	add_child(m)
	move_child(m, old.get_index())
	remove_child(old)
	old.queue_free()
	m.name = "City"
	city = m


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
	var old_f := handle.get_node_or_null("Firki")
	if old_f:
		old_f.queue_free()
	var old_l := handle.get_node_or_null("LineOrigin")
	if old_l:
		old_l.queue_free()
	var firki := Node3D.new()
	firki.name = "Firki"
	handle.add_child(firki)
	firki.position = Vector3.ZERO
	var model := CHARKHI.instantiate() as Node3D
	if model == null:
		return
	firki.add_child(model)
	_hide_tripo_ground(model)
	model.rotation_degrees = Vector3.ZERO
	model.scale = Vector3.ONE
	model.force_update_transform()
	var aabb := _mesh_aabb(model)
	## Mesh is a tall cylinder (Y = axle). Scale disc and axle separately so it
	## reads as a handheld charkhi in the boy's palm, not a tiny pill.
	var disc := maxf(aabb.size.x, aabb.size.z)
	var axle := aabb.size.y
	if aabb.size.x >= aabb.size.y and aabb.size.x >= aabb.size.z:
		axle = aabb.size.x
		disc = maxf(aabb.size.y, aabb.size.z)
	elif aabb.size.z >= aabb.size.y and aabb.size.z >= aabb.size.x:
		axle = aabb.size.z
		disc = maxf(aabb.size.x, aabb.size.y)
	if disc < 0.02:
		disc = 0.08
	if axle < 0.02:
		axle = 0.12
	const DISC := 0.18
	const AXLE := 0.132
	var s_disc := DISC / disc
	var s_axle := AXLE / axle
	model.scale = Vector3(s_disc, s_axle, s_disc)
	model.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	model.force_update_transform()
	aabb = _mesh_aabb(model)
	model.global_position += firki.global_position - aabb.get_center()
	_no_shadow(model)
	var line_at := Marker3D.new()
	line_at.name = "LineOrigin"
	handle.add_child(line_at)
	line_at.position = Vector3(0.0, 0.0, -0.04)


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
	if node is VisualInstance3D and node is Node3D and (node as Node3D).visible:
		var local: AABB = (node as VisualInstance3D).get_aabb()
		var xf := (node as Node3D).global_transform
		acc = xf * local
		first = false
	for child in node.get_children():
		if child is Node3D and not (child as Node3D).visible:
			continue
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
	var cam := city.spawn_position + Vector3(0.0, 1.45, 3.4)
	_preview_boy = PersonSc.new()
	_preview_boy.name = "PreviewBoy"
	add_child(_preview_boy)
	_preview_boy.setup(city.spawn_position + Vector3(-1.55, 0.0, -2.15), cam, null, BODY_BOY, false, true)

	_preview_girl = PersonSc.new()
	_preview_girl.name = "PreviewGirl"
	add_child(_preview_girl)
	_preview_girl.setup(city.spawn_position + Vector3(1.55, 0.0, -2.15), cam, null, BODY_GIRL, false, true)

	_palace_girl = PersonSc.new()
	_palace_girl.name = "PalaceGirl"
	add_child(_palace_girl)
	_palace_girl.setup(city.palace_watch_spot(), city.spawn_position, null, BODY_GIRL)

	var sky := city.spawn_position + Vector3(0.0, 6.0, -50.0)
	var rival_flyer := PersonSc.new()
	rival_flyer.name = "RivalFlyer"
	add_child(rival_flyer)
	rival_flyer.setup(city.rival_hand_position(), sky, CHARKHI, BODY_BOY, true)

	if city.rocket_pads.is_empty():
		return
	var other := PersonSc.new()
	other.name = "RoofFlyer"
	add_child(other)
	other.setup(city.rocket_pads[0], city.spawn_position, null, BODY_BOY)


func _on_character_chosen(id: String) -> void:
	if _character_picked:
		return
	_character_picked = true
	_flyer_id = id
	if _profile:
		_profile.flyer_id = id
		_profile.save_to_disk()
	player.intro_lock = false
	player.setup_avatar(id)
	_build_handle()
	if _preview_boy:
		_preview_boy.queue_free()
		_preview_boy = null
	if _preview_girl:
		_preview_girl.queue_free()
		_preview_girl = null
	_spawn_terrace_mate("girl" if id == "boy" else "boy")


## A map card was picked. Same map: straight on to modes. Another map: the
## travel card, then reload onto it keeping the flyer.
func _on_map_chosen(id: String) -> void:
	if not MapRegistry.has(id):
		return
	if id == _map_id:
		hud.show_mode_select()
		return
	hud.show_travel(id)
	var t := get_tree().create_timer(0.9)
	t.timeout.connect(func() -> void:
		Engine.set_meta("travel_map", id)
		Engine.set_meta("travel_flyer", _flyer_id if _flyer_id != "" else "boy")
		get_tree().paused = false
		get_tree().reload_current_scene())


func _land_after_travel(flyer: String) -> void:
	_skip_intro_cam()
	_finish_intro_cam()
	hud.skip_map_step = true
	hud._pick_character(flyer)


func _on_mode_chosen(id: String) -> void:
	if _flyer_picked:
		return
	if id == "online":
		_game_mode = "battle"
		_online = true
		if hud:
			hud.game_mode = "battle"
		if _rockets:
			_rockets.enabled = false
		kite.fight_pips = false
		rival.fight_pips = false
		rival.is_ai = false
		if pech:
			pech.net_mode = true
			pech.player_wins = 0
			pech.rival_wins = 0
		_match_cuts = 0
		_match_paid = false
		return
	_game_mode = "save" if id == "save" else "battle"
	_flyer_picked = true
	if hud:
		hud.game_mode = _game_mode
	if _rockets:
		_rockets.enabled = _game_mode == "save"
	kite.fight_pips = false
	rival.fight_pips = false
	if _game_mode == "save":
		rival.visible = false
	else:
		_match_cuts = 0
		_match_paid = false
		if pech:
			pech.player_wins = 0
			pech.rival_wins = 0
		var fight_hand := _battle_hand()
		rival.hand_pos = fight_hand
		if _rival_ai:
			_rival_ai.hand = fight_hand
		rival.visible = true
		rival.launch()


func _net_play_id() -> String:
	if _profile == null:
		return str(OS.get_process_id())
	return "%s_%d" % [_profile.play_id, OS.get_process_id()]


func _on_online_host() -> void:
	if _net == null or _profile == null:
		return
	if hud:
		hud.set_net_status("Opening a roof…")
	_net.host(_net_play_id(), _profile.you_card())


func _on_online_join(code: String) -> void:
	if _net == null or _profile == null:
		return
	if code.strip_edges().length() < 4:
		if hud:
			hud.set_net_status("Type the 4-letter code first.")
		return
	if hud:
		hud.set_net_status("Joining…")
	_net.join(_net_play_id(), _profile.you_card(), code)


func _on_net_waiting(code: String) -> void:
	if hud:
		hud.set_net_status("Code  %s  —  waiting for them" % code)


func _on_net_peer(card: Dictionary) -> void:
	_peer_card = card
	_peer_id = str(card.get("playId", ""))
	_refresh_online_vs()


func _on_net_live() -> void:
	_net_live = true
	_flyer_picked = true
	rival.visible = true
	_hide_rival_npc()
	if _net and _net.slot == "b":
		_setup_guest_roof()
	if hud:
		hud.hide_net_lobby()
		hud.show_toss_prompt()
	_refresh_online_vs()


func _on_net_state(data: Dictionary) -> void:
	_remote_state = data


func _on_cut_wanted(player_won: bool) -> void:
	if not _online or not _net_live or _net == null:
		return
	if player_won:
		_net.send_cut()


func _on_net_kaata(winner_id: String, a_cuts: int, b_cuts: int) -> void:
	if not _online or pech == null:
		return
	var i_won: bool = winner_id != "" and _net != null and winner_id == _net.play_id
	if i_won:
		rival.apply_cut()
		kite.restore_manjha()
		_match_cuts += 1
	else:
		kite.apply_cut()
		rival.restore_manjha()
	if _net and _net.slot == "a":
		pech.player_wins = a_cuts
		pech.rival_wins = b_cuts
	else:
		pech.player_wins = b_cuts
		pech.rival_wins = a_cuts
	if pech.player_wins < 2 and pech.rival_wins < 2:
		return
	if _net and _net.slot == "a":
		var win_id := ""
		if a_cuts >= 2:
			win_id = _net.play_id
		elif b_cuts >= 2:
			win_id = _peer_id
		_net.finish_match(a_cuts, b_cuts, win_id)
	_payout_battle()


func _on_net_gone() -> void:
	_net_live = false
	if hud:
		hud.set_net_status("They left the roof.")


func _on_net_fail(why: String) -> void:
	if hud:
		hud.set_net_status(why)


func _setup_guest_roof() -> void:
	player.move_to_roof(city.rival_hand_position(), city.rival_roof_bounds())
	kite.hand_pos = player.hand_position()


func _hide_rival_npc() -> void:
	var npc := get_node_or_null("RivalFlyer")
	if npc:
		npc.visible = false


func _refresh_online_vs() -> void:
	if hud == null or _profile == null:
		return
	if _peer_card.is_empty():
		return
	hud.show_vs_cards(_profile.you_card(), _vs_from_peer(_peer_card))


func _vs_from_peer(d: Dictionary) -> Dictionary:
	var n := str(d.get("name", "Rival")).strip_edges()
	if n == "":
		n = "Rival"
	return {
		"name": n,
		"rank": str(d.get("rank", "Rookie")),
		"won": int(d.get("won", 0)),
		"letter": n.substr(0, 1).to_upper(),
		"is_you": false,
	}


func _battle_hand() -> Vector3:
	return city.rival_hand_position()


func _mate_feet() -> Vector3:
	## Front-right railing, the old green-boy spot, close to the fly edge.
	var b := city.rooftop_bounds
	var feet := Vector3(b.end.x - 1.15, city.rooftop_height + 0.02, b.position.y + 1.2)
	feet.x = clampf(feet.x, b.position.x + 0.45, b.end.x - 0.45)
	feet.z = clampf(feet.z, b.position.y + 0.55, b.end.y - 0.45)
	return feet


func _spawn_terrace_mate(id: String) -> void:
	if _terrace_mate:
		_terrace_mate.queue_free()
		_terrace_mate = null
	var pack: PackedScene = BODY_GIRL if id == "girl" else BODY_BOY
	_terrace_mate = PersonSc.new()
	_terrace_mate.name = "TerraceMate"
	add_child(_terrace_mate)
	var sky := city.spawn_position + Vector3(0.0, 6.0, -50.0)
	_terrace_mate.setup(_mate_feet(), sky, CHARKHI, pack, true)


func _on_player_dodged() -> void:
	_save_dodges += 1
	if _palace_girl:
		_palace_girl.play_clap()


func _on_match_kaata(player_won: bool, _at: Vector3) -> void:
	if _online:
		return
	if _game_mode != "battle" or _match_paid:
		return
	if player_won:
		_match_cuts += 1
	if pech and (pech.player_wins >= 2 or pech.rival_wins >= 2):
		_payout_battle()


func _payout_battle() -> void:
	if _profile == null or _match_paid:
		return
	_match_paid = true
	var won := pech != null and pech.player_wins >= 2
	var result := _profile.award_battle(_match_cuts, won)
	if hud:
		hud.show_payout(result)
	var t := get_tree().create_timer(4.0)
	t.timeout.connect(_reset_evening)


func _reset_evening() -> void:
	if pech:
		pech.player_wins = 0
		pech.rival_wins = 0
	_match_cuts = 0
	_match_paid = false


func _on_player_cut() -> void:
	if _game_mode != "save" or _save_paid:
		return
	_save_paid = true
	if _profile == null:
		return
	var result := _profile.award_save(_save_dodges)
	if hud:
		hud.show_payout(result)


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
