extends CanvasLayer

const WindSys := preload("res://scripts/wind_system.gd")
const KiteSc := preload("res://scripts/kite.gd")
const PechSc := preload("res://scripts/pech.gd")

var wind: WindSys
var kite: KiteSc
var rival: KiteSc
var pech: PechSc
var player: Node
var rockets: Node

var _wind_label: Label
var _status: Label
var _hint: Label
var _meter_fill: ColorRect
var _pech_label: Label
var _kaata: Label
var _gust_flash: float = 0.0
var _kaata_t: float = 0.0
var _kaata_delay: float = -1.0
var _kaata_won: bool = true
var kite_close_cam: Camera3D
var _ring_mat: ShaderMaterial
var _pip_cap: Label


func setup(wind_in: WindSys, kite_in: KiteSc, rival_in: KiteSc = null, pech_in: PechSc = null) -> void:
	wind = wind_in
	kite = kite_in
	rival = rival_in
	pech = pech_in
	_build()
	if wind:
		wind.gust_began.connect(func() -> void: _gust_flash = 1.0)
		wind.lull_began.connect(func() -> void: _gust_flash = 0.35)
	if pech:
		pech.kaata.connect(_on_kaata)
		pech.pech_changed.connect(_on_pech)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_wind_label = _make_label(root, Vector2(32, 28), 22)
	_status = _make_label(root, Vector2(32, 60), 18)
	_hint = _make_label(root, Vector2(32, 0), 16)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 32.0
	_hint.offset_top = -96.0
	_hint.offset_right = 1500.0
	_hint.offset_bottom = -32.0
	_hint.text = "Q dart   ·   E dheel (sag / fake)   ·   Wheel line   ·   Space toss   ·   R relaunch   ·   V look back"

	_bar(root, Vector2(32, 92), Color(0.05, 0.08, 0.12, 0.45))
	_meter_fill = _bar(root, Vector2(32, 92), Color(0.55, 0.82, 1.0, 0.9), 140)

	_pech_label = _make_label(root, Vector2(32, 112), 20)
	_pech_label.modulate = Color(1.0, 0.82, 0.3, 0.0)
	_pech_label.text = "PECH — E sag to slip   ·   Q taut to cut"

	_kaata = _make_label(root, Vector2(0, 0), 72)
	_kaata.set_anchors_preset(Control.PRESET_CENTER)
	_kaata.offset_left = -280.0
	_kaata.offset_right = 280.0
	_kaata.offset_top = -80.0
	_kaata.offset_bottom = 40.0
	_kaata.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kaata.text = "WO KAATA!"
	_kaata.modulate = Color(1, 1, 1, 0)
	_kaata.add_theme_color_override("font_shadow_color", Color(0.4, 0.05, 0.0, 0.8))
	_kaata.add_theme_constant_override("shadow_offset_x", 3)
	_kaata.add_theme_constant_override("shadow_offset_y", 3)

	var title := _make_label(root, Vector2(32, 8), 14)
	title.modulate = Color(1, 1, 1, 0.7)
	title.text = "PATANG  ·  ROOFTOP"
	_build_kite_pip(root)


func _build_kite_pip(root: Control) -> void:
	## Further in from the corner so the threat ring reads clearly.
	var inset_r := 56.0
	var inset_t := 48.0
	var outer := 268.0
	var inner := 188.0

	var ring := ColorRect.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.anchor_left = 1.0
	ring.anchor_right = 1.0
	ring.anchor_top = 0.0
	ring.anchor_bottom = 0.0
	ring.offset_left = -(inset_r + outer)
	ring.offset_top = inset_t
	ring.offset_right = -inset_r
	ring.offset_bottom = inset_t + outer
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = preload("res://shaders/rocket_threat_ring.gdshader")
	ring.material = _ring_mat
	root.add_child(ring)

	var box := SubViewportContainer.new()
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.anchor_top = 0.0
	box.anchor_bottom = 0.0
	var pad := (outer - inner) * 0.5
	box.offset_left = -(inset_r + outer - pad)
	box.offset_top = inset_t + pad
	box.offset_right = -(inset_r + pad)
	box.offset_bottom = inset_t + outer - pad
	var clip := ShaderMaterial.new()
	clip.shader = preload("res://shaders/circle_pip.gdshader")
	box.material = clip
	root.add_child(box)

	var sv := SubViewport.new()
	sv.size = Vector2i(224, 224)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = true
	sv.handle_input_locally = false
	sv.msaa_3d = Viewport.MSAA_DISABLED
	box.add_child(sv)

	kite_close_cam = Camera3D.new()
	kite_close_cam.name = "KiteCloseCam"
	kite_close_cam.fov = 46.0
	kite_close_cam.near = 0.08
	kite_close_cam.far = 80.0
	kite_close_cam.current = true
	sv.add_child(kite_close_cam)

	_pip_cap = _make_label(root, Vector2(0, 0), 13)
	_pip_cap.text = "KITE"
	_pip_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pip_cap.anchor_left = 1.0
	_pip_cap.anchor_right = 1.0
	_pip_cap.anchor_top = 0.0
	_pip_cap.anchor_bottom = 0.0
	_pip_cap.offset_left = -(inset_r + outer)
	_pip_cap.offset_top = inset_t + outer + 4.0
	_pip_cap.offset_right = -inset_r
	_pip_cap.offset_bottom = inset_t + outer + 24.0
	_pip_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pip_cap.modulate = Color(1.0, 0.92, 0.7, 0.8)


func _bar(parent: Control, pos: Vector2, color: Color, width: float = 280.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = Vector2(width, 12)
	r.position = pos
	parent.add_child(r)
	return r


func _make_label(parent: Control, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	return l


func _on_kaata(player_won: bool, _at: Vector3) -> void:
	## Banner waits so a sagging fake is not called as a cut.
	_kaata_won = player_won
	_kaata_delay = 2.8


func _on_pech(on: bool) -> void:
	_pech_label.modulate.a = 1.0 if on else 0.0


func _process(delta: float) -> void:
	_gust_flash = move_toward(_gust_flash, 0.0, delta * 0.8)
	if _kaata_delay > 0.0:
		_kaata_delay -= delta
		if _kaata_delay <= 0.0:
			_kaata_t = 2.6
			_kaata.text = "WO KAATA!" if _kaata_won else "KATA GAYA!"
			_kaata.modulate = Color(1.0, 0.92, 0.35, 1.0) if _kaata_won else Color(1.0, 0.45, 0.35, 1.0)
	if _kaata_t > 0.0:
		_kaata_t -= delta
		var a := clampf(_kaata_t / 0.4, 0.0, 1.0) if _kaata_t < 0.4 else 1.0
		_kaata.modulate.a = a
		_kaata.scale = Vector2.ONE * (1.0 + (1.0 - a) * 0.08)
	if wind == null or kite == null or _wind_label == null:
		return
	_wind_label.text = "Wind  %s  %.1f m/s   %s" % [wind.compass_letter(), wind.last_speed, wind.debug_label()]
	var phase := "Space — toss the patang into the wind"
	if kite.phase == KiteSc.Phase.SPIN:
		phase = "SPIN  —  wait for the yellow nose, then Q to dart"
	elif kite.phase == KiteSc.Phase.FLY:
		phase = "KHEENCH  —  taut, shooting the nose"
	elif kite.phase == KiteSc.Phase.DHEEL:
		phase = "DHEEL  —  sagging. Q to yank back before the ground"
	elif kite.phase == KiteSc.Phase.CLIMB:
		phase = "Tossing up — it will spin when it catches"
	elif kite.phase == KiteSc.Phase.CUT:
		if kite.killed_by_rocket:
			phase = "A Diwali rocket hit your patang — R to toss again"
		else:
			phase = "Your manjha is cut — the kite is gone"
	elif kite.phase == KiteSc.Phase.CRASHED:
		phase = "Down — R to toss again"
	var shown_line := kite.line_length
	if kite.phase != KiteSc.Phase.GROUNDED and kite.phase != KiteSc.Phase.CUT:
		shown_line = maxf(kite.line_length, kite.hand_pos.distance_to(kite.global_position))
	_status.text = "%s    ·    line %.0fm    ·    %.0f°" % [phase, shown_line, rad_to_deg(kite.elevation)]

	var t := clampf(wind.last_speed / 16.0, 0.0, 1.0)
	_meter_fill.size.x = 280.0 * t
	if wind.is_lull:
		_meter_fill.color = Color(0.55, 0.62, 0.75, 0.85)
	elif wind.is_gusting:
		_meter_fill.color = Color(1.0, 0.78, 0.35, 0.95)
	else:
		_meter_fill.color = Color(0.55, 0.82, 1.0, 0.9)
	if pech and pech.active:
		_pech_label.modulate.a = 0.65 + 0.35 * absf(sin(Time.get_ticks_msec() * 0.008))
	_wind_label.modulate = Color(1, 1, 1, 1).lerp(Color(1.0, 0.85, 0.5), _gust_flash)
	_update_threat_ring()


func _update_threat_ring() -> void:
	if _ring_mat == null:
		return
	var launches: Array[Vector3] = []
	if rockets and rockets.has_method("inbound_launches"):
		launches = rockets.inbound_launches()
	var origin := Vector3.ZERO
	var fwd := Vector3(0.0, 0.0, -1.0)
	var right := Vector3.RIGHT
	if player and player.get("camera"):
		var cam: Camera3D = player.camera
		origin = cam.global_position
		fwd = -cam.global_transform.basis.z
		right = cam.global_transform.basis.x
	elif kite:
		origin = kite.hand_pos
	fwd.y = 0.0
	right.y = 0.0
	if fwd.length_squared() < 0.04:
		fwd = Vector3(0.0, 0.0, -1.0)
	if right.length_squared() < 0.04:
		right = Vector3.RIGHT
	fwd = fwd.normalized()
	right = right.normalized()
	var angs: Array[float] = []
	for pad in launches:
		var to := pad - origin
		to.y = 0.0
		if to.length_squared() < 0.2:
			continue
		angs.append(atan2(to.dot(right), to.dot(fwd)))
	var pulse := 0.72 + 0.28 * absf(sin(Time.get_ticks_msec() * 0.009))
	_ring_mat.set_shader_parameter("threat_a", angs[0] if angs.size() > 0 else 0.0)
	_ring_mat.set_shader_parameter("threat_b", angs[1] if angs.size() > 1 else 0.0)
	_ring_mat.set_shader_parameter("threat_c", angs[2] if angs.size() > 2 else 0.0)
	_ring_mat.set_shader_parameter("strength_a", 1.0 if angs.size() > 0 else 0.0)
	_ring_mat.set_shader_parameter("strength_b", 1.0 if angs.size() > 1 else 0.0)
	_ring_mat.set_shader_parameter("strength_c", 1.0 if angs.size() > 2 else 0.0)
	_ring_mat.set_shader_parameter("pulse", pulse if angs.size() > 0 else 0.35)
	if _pip_cap:
		if angs.size() > 0:
			_pip_cap.text = "ROCKET  INBOUND"
			_pip_cap.modulate = Color(1.0, 0.35, 0.22, 0.95)
		else:
			_pip_cap.text = "KITE"
			_pip_cap.modulate = Color(1.0, 0.92, 0.7, 0.8)
