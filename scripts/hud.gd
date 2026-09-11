extends CanvasLayer

const WindSys := preload("res://scripts/wind_system.gd")
const KiteSc := preload("res://scripts/kite.gd")
const PechSc := preload("res://scripts/pech.gd")
const SettingsSc := preload("res://scripts/game_settings.gd")
const PauseSc := preload("res://scripts/pause_menu.gd")
const KiteSkins := preload("res://scripts/kite_skins.gd")
const Brand := preload("res://scripts/brand.gd")
const TitleCardSc := preload("res://scripts/title_card.gd")
const ProfileSc := preload("res://scripts/profile.gd")
const ProfileCardSc := preload("res://scripts/profile_card.gd")

signal character_chosen(id: String)
signal mode_chosen(id: String)
signal online_host
signal online_join(code: String)

var wind: WindSys
var kite: KiteSc
var rival: KiteSc
var pech: PechSc
var player: Node
var rockets: Node
var game_settings: SettingsSc
var profile: ProfileSc
var graphics_host: Node
var game_mode: String = ""

var _kaata: Label
var _gust_flash: float = 0.0
var _kaata_t: float = 0.0
var _kaata_delay: float = -1.0
var _kaata_won: bool = true
var _zoom: VSlider
var _line_now: Label
var _line_max: Label
var _line_fill: ColorRect
var _line_track_w: float = 236.0
var _menu: PauseSc
var _gear: Button
var zoom: float = 0.0
var _intro: Control
var _intro_prompt: Label
var _intro_t: float = 0.0
var _intro_on: bool = false
var _kite_row: HBoxContainer
var _kite_cards: Array[Button] = []
var _char_row: HBoxContainer
var _char_label: Label
var _mode_row: HBoxContainer
var _mode_label: Label
var _net_row: HBoxContainer
var _net_status: Label
var _code_edit: LineEdit
var _hud_chrome: Control
var _title_card: Control
var _vs: Control
var _vs_you: ProfileCardSc
var _vs_them: ProfileCardSc
var _payout: Label


func setup(wind_in: WindSys, kite_in: KiteSc, rival_in: KiteSc = null, pech_in: PechSc = null) -> void:
	wind = wind_in
	kite = kite_in
	rival = rival_in
	pech = pech_in
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	if wind:
		wind.gust_began.connect(func() -> void: _gust_flash = 1.0)
	if pech:
		pech.kaata.connect(_on_kaata)
		pech.pech_changed.connect(_on_pech)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_hud_chrome = Control.new()
	_hud_chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_chrome.visible = false
	_hud_chrome.modulate.a = 0.0
	root.add_child(_hud_chrome)
	var hud := _hud_chrome

	_build_line_card(hud)
	_build_zoom_bar(hud)
	_kaata = _make_label(hud, Vector2(0, 0), 72)
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
	_build_menu_button(root)
	_title_card = TitleCardSc.new()
	root.add_child(_title_card)
	_build_intro(root)
	_build_vs(root)
	_build_payout(root)
	_menu = PauseSc.new()
	add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if game_settings:
		_menu.setup(game_settings, profile)
	_menu.quit_requested.connect(func() -> void: get_tree().quit())
	_menu.settings_changed.connect(_apply_settings)
	_menu.kite_chosen.connect(_pick_kite)
	_apply_settings()


func _build_line_card(parent: Control) -> void:
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2(22, 20)
	card.size = Vector2(268, 96)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.06, 0.58)
	sb.border_color = Color(1.0, 0.84, 0.38, 0.42)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.38)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 3)
	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)

	var cap := Label.new()
	cap.text = "LINE"
	cap.position = Vector2(18, 10)
	cap.size = Vector2(120, 18)
	cap.add_theme_font_override("font", Brand.body_font())
	cap.add_theme_font_size_override("font_size", 12)
	cap.add_theme_color_override("font_color", Brand.GOLD)
	cap.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	cap.add_theme_constant_override("shadow_offset_x", 1)
	cap.add_theme_constant_override("shadow_offset_y", 1)
	card.add_child(cap)

	_line_now = Label.new()
	_line_now.text = "18 m"
	_line_now.position = Vector2(16, 26)
	_line_now.size = Vector2(150, 46)
	_line_now.add_theme_font_override("font", Brand.display_font())
	_line_now.add_theme_font_size_override("font_size", 36)
	_line_now.add_theme_color_override("font_color", Brand.CREAM)
	_line_now.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_line_now.add_theme_constant_override("shadow_offset_x", 2)
	_line_now.add_theme_constant_override("shadow_offset_y", 2)
	card.add_child(_line_now)

	_line_max = Label.new()
	_line_max.text = "/  500 m"
	_line_max.position = Vector2(148, 40)
	_line_max.size = Vector2(110, 28)
	_line_max.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_line_max.add_theme_font_override("font", Brand.body_font())
	_line_max.add_theme_font_size_override("font_size", 16)
	_line_max.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82, 0.62))
	card.add_child(_line_max)

	var track := ColorRect.new()
	track.color = Color(1.0, 0.84, 0.38, 0.14)
	track.position = Vector2(18, 76)
	track.size = Vector2(_line_track_w, 7)
	card.add_child(track)
	_line_fill = ColorRect.new()
	_line_fill.color = Color(1.0, 0.78, 0.32, 0.95)
	_line_fill.position = Vector2(18, 76)
	_line_fill.size = Vector2(40, 7)
	card.add_child(_line_fill)


func _build_zoom_bar(root: Control) -> void:
	var track := ColorRect.new()
	track.color = Color(0.05, 0.04, 0.06, 0.58)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.anchor_left = 0.0
	track.anchor_right = 0.0
	track.anchor_top = 0.0
	track.anchor_bottom = 0.0
	track.offset_left = 16.0
	track.offset_top = 140.0
	track.offset_right = 50.0
	track.offset_bottom = 430.0
	root.add_child(track)

	_zoom = VSlider.new()
	_zoom.min_value = 0.0
	_zoom.max_value = 1.0
	_zoom.step = 0.01
	_zoom.value = 0.0
	_zoom.scrollable = true
	_zoom.mouse_filter = Control.MOUSE_FILTER_STOP
	_zoom.anchor_left = 0.0
	_zoom.anchor_right = 0.0
	_zoom.anchor_top = 0.0
	_zoom.anchor_bottom = 0.0
	_zoom.offset_left = 20.0
	_zoom.offset_top = 158.0
	_zoom.offset_right = 46.0
	_zoom.offset_bottom = 400.0
	_zoom.value_changed.connect(_on_zoom)
	_style_zoom(_zoom)
	root.add_child(_zoom)

	var plus := _make_label(root, Vector2(16, 140), 14)
	plus.text = "+"
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.size = Vector2(34, 18)
	plus.modulate = Color(1.0, 0.84, 0.38, 0.9)

	var minus := _make_label(root, Vector2(16, 404), 16)
	minus.text = "–"
	minus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minus.size = Vector2(34, 18)
	minus.modulate = Color(1.0, 0.84, 0.38, 0.9)

	var cap := _make_label(root, Vector2(6, 422), 11)
	cap.text = "ZOOM"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size = Vector2(54, 16)
	cap.modulate = Color(1.0, 0.84, 0.38, 0.7)


func _style_zoom(s: VSlider) -> void:
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0.18, 0.16, 0.12, 0.95)
	groove.set_corner_radius_all(5)
	groove.content_margin_left = 5.0
	groove.content_margin_right = 5.0
	s.add_theme_stylebox_override("slider", groove)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1.0, 0.78, 0.28, 1.0)
	grab.set_corner_radius_all(4)
	grab.content_margin_left = 8.0
	grab.content_margin_right = 8.0
	grab.content_margin_top = 6.0
	grab.content_margin_bottom = 6.0
	s.add_theme_stylebox_override("grabber_area", grab)
	s.add_theme_stylebox_override("grabber_area_highlight", grab)
	s.add_theme_constant_override("center_grabber", 1)
	var icon := _gold_knob()
	s.add_theme_icon_override("grabber", icon)
	s.add_theme_icon_override("grabber_highlight", icon)


func _gold_knob() -> Texture2D:
	var img := Image.create(22, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(2, 12):
		for x in range(2, 20):
			img.set_pixel(x, y, Color(1.0, 0.82, 0.32, 1.0))
	return ImageTexture.create_from_image(img)


func _on_zoom(value: float) -> void:
	zoom = clampf(value, 0.0, 1.0)


func over_zoom() -> bool:
	if _zoom == null or _hud_chrome == null or not _hud_chrome.visible:
		return false
	return _zoom.get_global_rect().grow(10.0).has_point(_zoom.get_global_mouse_position())


func over_controls() -> bool:
	if _menu and _menu.is_open():
		return true
	var mouse := get_viewport().get_mouse_position()
	if _gear and _gear.visible and _gear.get_global_rect().has_point(mouse):
		return true
	if _intro_on and _char_row and _char_row.visible and _char_row.get_global_rect().has_point(mouse):
		return true
	if _intro_on and _mode_row and _mode_row.visible and _mode_row.get_global_rect().has_point(mouse):
		return true
	if _intro_on and _net_row and _net_row.visible and _net_row.get_global_rect().has_point(mouse):
		return true
	return over_zoom()


func _current_kite_id() -> String:
	if profile:
		return KiteSkins.clamp_id(profile.kite_id)
	if game_settings:
		return KiteSkins.clamp_id(game_settings.kite_id)
	if kite:
		return kite.sail_id
	return KiteSkins.SAFFRON


func _rebuild_kite_cards() -> void:
	if _kite_row == null:
		return
	for c in _kite_row.get_children():
		_kite_row.remove_child(c)
		c.queue_free()
	_kite_cards.clear()
	var selected := _current_kite_id()
	for id in KiteSkins.ids():
		var card := KiteSkins.make_card(id, id == selected, _pick_kite)
		_kite_row.add_child(card)
		_kite_cards.append(card)


func _pick_kite(id: String) -> void:
	id = KiteSkins.clamp_id(id)
	if profile:
		if not profile.owns(id):
			return
		profile.set_kite(id)
	if game_settings:
		game_settings.kite_id = id
		game_settings.save_to_disk()
	if kite:
		kite.set_sail(id)
	if rival and (kite == null or not kite.is_airborne()):
		rival.set_sail(KiteSkins.rival_id(id))
	call_deferred("_rebuild_kite_cards")
	if _menu:
		_menu.call_deferred("refresh_kite_cards", id)
		_menu.call_deferred("refresh_profile")


func toggle_menu() -> void:
	if _menu:
		_menu.toggle()


func _apply_settings() -> void:
	if game_settings and graphics_host:
		game_settings.apply(graphics_host)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			toggle_menu()
			get_viewport().set_input_as_handled()


func _build_menu_button(root: Control) -> void:
	_gear = Button.new()
	_gear.text = "MENU"
	_gear.mouse_filter = Control.MOUSE_FILTER_STOP
	_gear.anchor_left = 1.0
	_gear.anchor_right = 1.0
	_gear.anchor_top = 0.0
	_gear.anchor_bottom = 0.0
	_gear.offset_left = -132.0
	_gear.offset_top = 18.0
	_gear.offset_right = -24.0
	_gear.offset_bottom = 56.0
	_gear.pressed.connect(func() -> void:
		if _menu:
			_menu.open_pause()
	)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.07, 0.09, 0.78)
	normal.border_color = Color(0.95, 0.72, 0.32, 0.85)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.16, 0.08, 0.92)
	_gear.add_theme_stylebox_override("normal", normal)
	_gear.add_theme_stylebox_override("hover", hover)
	_gear.add_theme_stylebox_override("pressed", hover)
	_gear.add_theme_font_size_override("font_size", 16)
	_gear.add_theme_color_override("font_color", Color(1.0, 0.92, 0.74))
	_gear.visible = false
	root.add_child(_gear)


func _build_intro(root: Control) -> void:
	_intro = Control.new()
	_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.visible = false
	root.add_child(_intro)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.offset_left = -520.0
	box.offset_right = 520.0
	## Sit the block in the lower third so the sky and the kite read above it.
	box.offset_top = 40.0
	box.offset_bottom = 340.0
	_intro.add_child(box)

	var title := Label.new()
	title.text = Brand.TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Brand.display_font())
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Brand.GOLD)
	title.add_theme_color_override("font_outline_color", Brand.INK)
	title.add_theme_constant_override("outline_size", 10)
	_shadow(title)
	box.add_child(title)

	var tag := Label.new()
	tag.text = Brand.TAGLINE
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_override("font", Brand.body_font())
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", Brand.CREAM)
	_shadow(tag)
	box.add_child(tag)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer)

	var pick := Label.new()
	pick.text = "Choose who flies"
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick.add_theme_font_override("font", Brand.body_font())
	pick.add_theme_font_size_override("font_size", 22)
	pick.add_theme_color_override("font_color", Brand.GOLD)
	_shadow(pick)
	box.add_child(pick)
	_char_label = pick

	_char_row = HBoxContainer.new()
	_char_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_char_row.add_theme_constant_override("separation", 18)
	_char_row.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(_char_row)
	_char_row.add_child(_make_flyer_card("boy", "Boy", [
		Color(0.42, 0.72, 0.42),
		Color(0.82, 0.72, 0.42),
		Color(0.95, 0.88, 0.70),
	]))
	_char_row.add_child(_make_flyer_card("girl", "Girl", [
		Color(0.92, 0.42, 0.62),
		Color(0.95, 0.90, 0.88),
		Color(0.82, 0.18, 0.22),
	]))

	_mode_label = Label.new()
	_mode_label.text = "Choose a mode"
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.add_theme_font_override("font", Brand.body_font())
	_mode_label.add_theme_font_size_override("font_size", 22)
	_mode_label.add_theme_color_override("font_color", Brand.GOLD)
	_shadow(_mode_label)
	_mode_label.visible = false
	box.add_child(_mode_label)

	_mode_row = HBoxContainer.new()
	_mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_mode_row.add_theme_constant_override("separation", 22)
	_mode_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_mode_row.visible = false
	box.add_child(_mode_row)
	_mode_row.add_child(_make_mode_card(
		"save",
		"Save the kite",
		"Rockets hunt your sail — dodge them. No rival.",
		[Color(1.0, 0.42, 0.16), Color(1.0, 0.78, 0.28), Color(0.95, 0.90, 0.72)]
	))
	_mode_row.add_child(_make_mode_card(
		"battle",
		"Classic Kite Battle",
		"Cut their manjha. First to 2 kaata. No rockets.",
		[Color(0.38, 0.62, 0.95), Color(0.95, 0.82, 0.28), Color(0.92, 0.28, 0.48)]
	))
	_mode_row.add_child(_make_mode_card(
		"online",
		"Online Battle",
		"Host or join. Same dusk, two kites. First to 2.",
		[Color(0.45, 0.82, 0.72), Color(0.95, 0.82, 0.28), Color(0.92, 0.28, 0.48)]
	))

	_net_status = Label.new()
	_net_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_net_status.add_theme_font_override("font", Brand.body_font())
	_net_status.add_theme_font_size_override("font_size", 20)
	_net_status.add_theme_color_override("font_color", Brand.GOLD)
	_shadow(_net_status)
	_net_status.visible = false
	box.add_child(_net_status)

	_net_row = HBoxContainer.new()
	_net_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_net_row.add_theme_constant_override("separation", 14)
	_net_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_net_row.visible = false
	box.add_child(_net_row)
	_net_row.add_child(_make_net_btn("Host", func() -> void: online_host.emit()))
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "CODE"
	_code_edit.max_length = 6
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.custom_minimum_size = Vector2(110, 48)
	_code_edit.add_theme_font_size_override("font_size", 22)
	_net_row.add_child(_code_edit)
	_net_row.add_child(_make_net_btn("Join", func() -> void: online_join.emit(_code_edit.text)))

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer2)

	_intro_prompt = Label.new()
	_intro_prompt.text = "Press  SPACE  to fly"
	_intro_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_prompt.add_theme_font_override("font", Brand.display_font())
	_intro_prompt.add_theme_font_size_override("font_size", 30)
	_intro_prompt.add_theme_color_override("font_color", Brand.GOLD)
	_shadow(_intro_prompt)
	_intro_prompt.visible = false
	box.add_child(_intro_prompt)


func _build_vs(root: Control) -> void:
	_vs = Control.new()
	_vs.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vs.visible = false
	_vs.modulate.a = 0.0
	root.add_child(_vs)
	_vs_you = ProfileCardSc.new()
	_vs_you.anchor_left = 0.0
	_vs_you.anchor_right = 0.0
	_vs_you.anchor_top = 0.5
	_vs_you.anchor_bottom = 0.5
	_vs_you.offset_left = 70.0
	_vs_you.offset_top = -146.0
	_vs_you.offset_right = 318.0
	_vs_you.offset_bottom = 146.0
	_vs.add_child(_vs_you)
	_vs_them = ProfileCardSc.new()
	_vs_them.anchor_left = 1.0
	_vs_them.anchor_right = 1.0
	_vs_them.anchor_top = 0.5
	_vs_them.anchor_bottom = 0.5
	_vs_them.offset_left = -318.0
	_vs_them.offset_top = -146.0
	_vs_them.offset_right = -70.0
	_vs_them.offset_bottom = 146.0
	_vs.add_child(_vs_them)
	var vs_lab := Label.new()
	vs_lab.text = "VS"
	vs_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs_lab.set_anchors_preset(Control.PRESET_CENTER)
	vs_lab.offset_left = -60.0
	vs_lab.offset_right = 60.0
	vs_lab.offset_top = -40.0
	vs_lab.offset_bottom = 40.0
	vs_lab.add_theme_font_override("font", Brand.display_font())
	vs_lab.add_theme_font_size_override("font_size", 56)
	vs_lab.add_theme_color_override("font_color", Brand.GOLD)
	vs_lab.add_theme_color_override("font_outline_color", Brand.INK)
	vs_lab.add_theme_constant_override("outline_size", 8)
	_vs.add_child(vs_lab)


func _build_payout(root: Control) -> void:
	_payout = Label.new()
	_payout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_payout.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_payout.offset_left = -280.0
	_payout.offset_right = 280.0
	_payout.offset_top = 28.0
	_payout.offset_bottom = 80.0
	_payout.add_theme_font_override("font", Brand.display_font())
	_payout.add_theme_font_size_override("font_size", 28)
	_payout.add_theme_color_override("font_color", Brand.GOLD)
	_payout.add_theme_color_override("font_outline_color", Brand.INK)
	_payout.add_theme_constant_override("outline_size", 6)
	_payout.modulate.a = 0.0
	_payout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_payout)


func show_vs() -> void:
	if _vs == null or profile == null:
		return
	var kid := profile.kite_id
	if kite:
		kid = kite.sail_id
	_vs_you.fill(profile.you_card())
	_vs_them.fill(profile.rival_card(kid))
	_vs.visible = true
	_vs.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_vs, "modulate:a", 1.0, 0.4)


func hide_vs() -> void:
	if _vs == null or not _vs.visible:
		return
	var tw := create_tween()
	tw.tween_property(_vs, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		if _vs:
			_vs.visible = false
	)


func show_payout(result: Dictionary) -> void:
	if _payout == null:
		return
	var line := "+%d XP   ·   +%d coins   ·   %s" % [int(result.get("xp", 0)), int(result.get("coins", 0)), str(result.get("rank", ""))]
	if bool(result.get("ranked_up", false)):
		line += "  ↑"
	_payout.text = line
	_payout.modulate.a = 1.0
	if _menu:
		_menu.refresh_profile()
	var tw := create_tween()
	tw.tween_interval(2.8)
	tw.tween_property(_payout, "modulate:a", 0.0, 0.6)


func show_character_select() -> void:
	if _intro == null:
		return
	if _title_card and _title_card.has_method("recede"):
		_title_card.recede()
	_intro_on = true
	_intro_t = 0.0
	_intro.visible = true
	_intro.modulate.a = 0.0
	if _char_row:
		_char_row.visible = true
	if _char_label:
		_char_label.visible = true
	if _mode_row:
		_mode_row.visible = false
	if _mode_label:
		_mode_label.visible = false
	if _intro_prompt:
		_intro_prompt.visible = false


func _show_chrome() -> void:
	if _hud_chrome == null:
		return
	_hud_chrome.visible = true
	if _gear:
		_gear.visible = true
	var tw := create_tween()
	tw.tween_property(_hud_chrome, "modulate:a", 1.0, 0.55)


func _make_flyer_card(id: String, title: String, swatches: Array) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(180, 148)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: _pick_character(id))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.07, 0.08, 0.92)
	normal.border_color = Color(swatches[0].r, swatches[0].g, swatches[0].b, 0.55)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	var hot := normal.duplicate() as StyleBoxFlat
	hot.bg_color = Color(0.16, 0.12, 0.10, 0.96)
	hot.border_color = Color(1.0, 0.84, 0.38, 1.0)
	hot.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", hot)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(col)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	for c in swatches:
		var chip := ColorRect.new()
		chip.custom_minimum_size = Vector2(28, 52)
		chip.color = c
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chip)
	var name := Label.new()
	name.text = title
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_override("font", Brand.body_font())
	name.add_theme_font_size_override("font_size", 22)
	name.add_theme_color_override("font_color", Brand.CREAM)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name)
	return b


func _make_mode_card(id: String, title: String, blurb: String, swatches: Array) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("separation", 8)
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	var b := Button.new()
	b.custom_minimum_size = Vector2(280, 132)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: _pick_mode(id))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.07, 0.08, 0.92)
	normal.border_color = Color(swatches[0].r, swatches[0].g, swatches[0].b, 0.7)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 14
	normal.content_margin_bottom = 14
	var hot := normal.duplicate() as StyleBoxFlat
	hot.bg_color = Color(0.16, 0.12, 0.10, 0.96)
	hot.border_color = Color(1.0, 0.84, 0.38, 1.0)
	hot.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", hot)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(col)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	for c in swatches:
		var chip := ColorRect.new()
		chip.custom_minimum_size = Vector2(22, 40)
		chip.color = c
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chip)
	var name := Label.new()
	name.text = title
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.add_theme_font_override("font", Brand.display_font())
	name.add_theme_font_size_override("font_size", 22)
	name.add_theme_color_override("font_color", Brand.GOLD)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name)
	wrap.add_child(b)
	var desc := Label.new()
	desc.text = blurb
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(280, 0)
	desc.add_theme_font_override("font", Brand.body_font())
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Brand.CREAM)
	_shadow(desc)
	wrap.add_child(desc)
	return wrap


func _pick_character(id: String) -> void:
	character_chosen.emit(id)
	if _char_row:
		_char_row.visible = false
	if _char_label:
		_char_label.visible = false
	if _mode_row:
		_mode_row.visible = true
	if _mode_label:
		_mode_label.visible = true
	if _intro_prompt:
		_intro_prompt.visible = false


func _pick_mode(id: String) -> void:
	game_mode = id
	mode_chosen.emit(id)
	if _mode_row:
		_mode_row.visible = false
	if _mode_label:
		_mode_label.visible = false
	if id == "online":
		if _net_row:
			_net_row.visible = true
		if _net_status:
			_net_status.visible = true
			_net_status.text = "Host a roof, or type a code to join."
		if _intro_prompt:
			_intro_prompt.visible = false
		return
	if _net_row:
		_net_row.visible = false
	if _intro_prompt:
		_intro_prompt.visible = true
	if id == "battle":
		show_vs()


func show_vs_cards(you: Dictionary, them: Dictionary) -> void:
	if _vs_you:
		_vs_you.fill(you)
	if _vs_them:
		_vs_them.fill(them)
	if _vs == null:
		return
	_vs.visible = true
	_vs.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_vs, "modulate:a", 1.0, 0.4)


func set_net_status(text: String) -> void:
	if _net_status:
		_net_status.visible = true
		_net_status.text = text


func hide_net_lobby() -> void:
	if _net_row:
		_net_row.visible = false
	if _net_status:
		_net_status.visible = false


func show_toss_prompt() -> void:
	if _intro_prompt:
		_intro_prompt.visible = true


func _make_net_btn(title: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = title
	b.custom_minimum_size = Vector2(120, 48)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Brand.CREAM)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.07, 0.08, 0.92)
	normal.border_color = Brand.GOLD
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	var hot := normal.duplicate() as StyleBoxFlat
	hot.bg_color = Color(0.16, 0.12, 0.10, 0.96)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", hot)
	return b


func hide_intro() -> void:
	if _intro == null or not _intro_on:
		return
	_intro_on = false
	var tw := create_tween()
	tw.tween_property(_intro, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func() -> void: _intro.visible = false)
	_show_chrome()
	hide_vs()


func _shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)


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
	_kaata_delay = 0.18


func _on_pech(_on: bool) -> void:
	pass


func _process(delta: float) -> void:
	if _intro_on and _intro:
		_intro.modulate.a = move_toward(_intro.modulate.a, 1.0, delta * 2.4)
		_intro_t += delta
		if _intro_prompt:
			_intro_prompt.modulate.a = 0.55 + 0.45 * absf(sin(_intro_t * 3.0))
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
	_update_line_card()


func _update_line_card() -> void:
	if kite == null or _line_now == null:
		return
	var shown := kite.line_length
	if kite.phase != KiteSc.Phase.GROUNDED and kite.phase != KiteSc.Phase.CUT:
		shown = maxf(kite.line_length, kite.hand_pos.distance_to(kite.global_position))
	var total := KiteSc.LINE_MAX
	_line_now.text = "%d m" % int(round(shown))
	_line_max.text = "/  %d m" % int(round(total))
	var t := clampf(shown / maxf(total, 1.0), 0.0, 1.0)
	_line_fill.size.x = _line_track_w * t
	_line_fill.color = Color(1.0, 0.78, 0.32, 0.95).lerp(Color(1.0, 0.48, 0.22, 0.95), t)
