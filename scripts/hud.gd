extends CanvasLayer

const WindSys := preload("res://scripts/wind_system.gd")
const KiteSc := preload("res://scripts/kite.gd")
const PechSc := preload("res://scripts/pech.gd")
const SettingsSc := preload("res://scripts/game_settings.gd")
const PauseSc := preload("res://scripts/pause_menu.gd")
const KiteSkins := preload("res://scripts/kite_skins.gd")
const Brand := preload("res://scripts/brand.gd")
const TitleCardSc := preload("res://scripts/title_card.gd")

signal character_chosen(id: String)
signal mode_chosen(id: String)

var wind: WindSys
var kite: KiteSc
var rival: KiteSc
var pech: PechSc
var player: Node
var rockets: Node
var game_settings: SettingsSc
var graphics_host: Node
var game_mode: String = ""

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
var _zoom: VSlider
var _rocket_label: Label
var _score_label: Label
var _pip_row: HBoxContainer
var _pips: Array[ColorRect] = []
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
var _pip_cap: Label
var _hud_chrome: Control
var _title_card: Control


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

	var rail := ColorRect.new()
	rail.color = Color(0.05, 0.06, 0.08, 0.55)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.anchor_left = 0.0
	rail.anchor_right = 0.0
	rail.anchor_top = 0.0
	rail.anchor_bottom = 1.0
	rail.offset_left = 0.0
	rail.offset_top = 0.0
	rail.offset_right = 58.0
	rail.offset_bottom = 0.0
	hud.add_child(rail)

	_wind_label = _make_label(hud, Vector2(72, 28), 22)
	_status = _make_label(hud, Vector2(72, 60), 18)
	_hint = _make_label(hud, Vector2(72, 0), 16)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 72.0
	_hint.offset_top = -96.0
	_hint.offset_right = 1500.0
	_hint.offset_bottom = -32.0
	_hint.text = "Q dart   ·   E dheel   ·   Wheel line   ·   Space toss   ·   R relaunch   ·   V look back   ·   Left bar zooms   ·   ESC menu"

	_bar(hud, Vector2(72, 92), Color(0.05, 0.08, 0.12, 0.45))
	_meter_fill = _bar(hud, Vector2(72, 92), Color(0.55, 0.82, 1.0, 0.9), 140)

	_pech_label = _make_label(hud, Vector2(72, 112), 20)
	_pech_label.modulate = Color(1.0, 0.82, 0.3, 0.0)
	_pech_label.text = "Pink kite: Q dashes to cut   ·   E sag to slip"

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

	var title := _make_label(hud, Vector2(72, 8), 14)
	title.modulate = Color(1.0, 0.84, 0.38, 0.85)
	title.add_theme_font_override("font", Brand.display_font())
	title.text = Brand.TITLE
	_build_zoom_bar(hud)
	_rocket_label = _make_label(hud, Vector2(72, 136), 16)
	_rocket_label.modulate = Color(1.0, 0.38, 0.22, 0.0)
	_rocket_label.text = "ROCKET  INBOUND"
	_score_label = _make_label(hud, Vector2(72, 158), 18)
	_score_label.modulate = Color(1.0, 0.88, 0.62, 0.9)
	_pip_row = HBoxContainer.new()
	_pip_row.position = Vector2(72, 184)
	_pip_row.add_theme_constant_override("separation", 8)
	hud.add_child(_pip_row)
	_pips.clear()
	for _i in 3:
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(18, 18)
		d.color = Color(0.22, 0.14, 0.12, 0.85)
		_pip_row.add_child(d)
		_pips.append(d)
	var pip_cap := _make_label(hud, Vector2(138, 182), 14)
	pip_cap.text = "CUT CHARGE"
	pip_cap.modulate = Color(1.0, 0.55, 0.78, 0.85)
	_pip_cap = pip_cap
	_build_menu_button(hud)
	_title_card = TitleCardSc.new()
	root.add_child(_title_card)
	_build_intro(root)
	_menu = PauseSc.new()
	add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if game_settings:
		_menu.setup(game_settings)
	_menu.quit_requested.connect(func() -> void: get_tree().quit())
	_menu.settings_changed.connect(_apply_settings)
	_menu.kite_chosen.connect(_pick_kite)
	_apply_settings()


func _build_zoom_bar(root: Control) -> void:
	var track := ColorRect.new()
	track.color = Color(0.07, 0.08, 0.10, 0.62)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.anchor_left = 0.0
	track.anchor_right = 0.0
	track.anchor_top = 0.0
	track.anchor_bottom = 0.0
	track.offset_left = 14.0
	track.offset_top = 168.0
	track.offset_right = 52.0
	track.offset_bottom = 468.0
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
	_zoom.offset_top = 188.0
	_zoom.offset_right = 46.0
	_zoom.offset_bottom = 434.0
	_zoom.value_changed.connect(_on_zoom)
	_style_zoom(_zoom)
	root.add_child(_zoom)

	var plus := _make_label(root, Vector2(18, 168), 14)
	plus.text = "+"
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.size = Vector2(36, 20)
	plus.modulate = Color(1.0, 0.92, 0.72, 0.9)

	var minus := _make_label(root, Vector2(18, 438), 16)
	minus.text = "–"
	minus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minus.size = Vector2(36, 20)
	minus.modulate = Color(1.0, 0.92, 0.72, 0.9)

	var cap := _make_label(root, Vector2(8, 456), 12)
	cap.text = "ZOOM"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size = Vector2(50, 18)
	cap.modulate = Color(1.0, 0.9, 0.7, 0.75)


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
	if _zoom == null:
		return false
	return _zoom.get_global_rect().grow(10.0).has_point(_zoom.get_global_mouse_position())


func over_controls() -> bool:
	if _menu and _menu.is_open():
		return true
	var mouse := get_viewport().get_mouse_position()
	if _gear and _gear.get_global_rect().has_point(mouse):
		return true
	if _intro_on and _char_row and _char_row.visible and _char_row.get_global_rect().has_point(mouse):
		return true
	if _intro_on and _mode_row and _mode_row.visible and _mode_row.get_global_rect().has_point(mouse):
		return true
	return over_zoom()


func _current_kite_id() -> String:
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
	if game_settings:
		game_settings.kite_id = id
		game_settings.save_to_disk()
	if kite:
		kite.set_sail(id)
	if rival and (kite == null or not kite.is_airborne()):
		rival.set_sail(KiteSkins.rival_id(id))
	## Cards are the buttons that fired this pick — free them next frame.
	call_deferred("_rebuild_kite_cards")
	if _menu:
		_menu.call_deferred("refresh_kite_cards", id)


func toggle_menu() -> void:
	if _menu:
		_menu.toggle()


func _apply_settings() -> void:
	if game_settings and graphics_host:
		game_settings.apply(graphics_host)
	if _hint:
		_hint.visible = game_settings == null or game_settings.show_hints


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


func show_character_select() -> void:
	if _intro == null:
		return
	if _title_card and _title_card.has_method("recede"):
		_title_card.recede()
	_show_chrome()
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
	if _intro_prompt:
		_intro_prompt.visible = true
	_apply_mode_chrome()


func hide_intro() -> void:
	if _intro == null or not _intro_on:
		return
	_intro_on = false
	var tw := create_tween()
	tw.tween_property(_intro, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func() -> void: _intro.visible = false)


func _shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)


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
	_kaata_delay = 0.18


func _on_pech(on: bool) -> void:
	_pech_label.modulate.a = 1.0 if on else 0.0


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
	if wind == null or kite == null or _wind_label == null:
		return
	_wind_label.text = "Wind  %s  %.1f m/s" % [wind.compass_letter(), wind.last_speed]
	if wind.is_gusting:
		_wind_label.text += "   GUST"
	var phase := "Space — toss the patang into the wind"
	if kite.phase == KiteSc.Phase.SPIN:
		phase = "SPIN  —  wait for the yellow nose, then Q to dart"
	elif kite.phase == KiteSc.Phase.FLY:
		if kite.is_dashing():
			phase = "CUT DASH — through their string"
		else:
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
	if wind.is_gusting:
		_meter_fill.color = Color(1.0, 0.78, 0.35, 0.95)
	else:
		_meter_fill.color = Color(0.55, 0.82, 1.0, 0.9)
	if pech and pech.active:
		_pech_label.modulate.a = 0.65 + 0.35 * absf(sin(Time.get_ticks_msec() * 0.008))
	_wind_label.modulate = Color(1, 1, 1, 1).lerp(Color(1.0, 0.85, 0.5), _gust_flash)
	_update_rocket_badge()
	_update_charge_ui()


func _apply_mode_chrome() -> void:
	var save := game_mode == "save"
	if _pip_row:
		_pip_row.visible = true
	if _pip_cap:
		_pip_cap.visible = true
		_pip_cap.text = "DODGE CHARGE" if save else "CUT CHARGE"
	if _rocket_label and not save:
		_rocket_label.modulate.a = 0.0


func _update_charge_ui() -> void:
	if kite == null:
		return
	if _score_label and pech:
		if game_mode == "save":
			_score_label.text = "Save the kite    ·    dodge the rockets"
		else:
			_score_label.text = "You  %d    ·    Rival  %d    ·    first to 2" % [pech.player_wins, pech.rival_wins]
	var n := kite.pips if kite else 0
	var ready := kite.is_cut_ready() if kite.has_method("is_cut_ready") else n >= 3
	var dash := kite.is_dashing() if kite.has_method("is_dashing") else false
	for i in _pips.size():
		var lit := i < n or dash
		if ready or dash:
			_pips[i].color = Color(1.0, 0.32, 0.72, 0.95)
		elif lit:
			_pips[i].color = Color(1.0, 0.55, 0.28, 0.92)
		else:
			_pips[i].color = Color(0.22, 0.14, 0.12, 0.85)
	if game_mode == "save":
		if ready:
			_pech_label.text = "CUT READY — aim through their string and Q"
			_pech_label.modulate.a = 0.7 + 0.3 * absf(sin(Time.get_ticks_msec() * 0.01))
		elif dash:
			_pech_label.text = "CUT DASH"
			_pech_label.modulate.a = 1.0
		return
	if dash:
		_pech_label.text = "CUT DASH"
		_pech_label.modulate.a = 1.0
	elif ready:
		_pech_label.text = "CUT READY — through their string, then Q"
		_pech_label.modulate.a = 0.7 + 0.3 * absf(sin(Time.get_ticks_msec() * 0.01))
	elif pech and pech.active:
		_pech_label.text = "PECH — Q to cut, E to slip"
		_pech_label.modulate.a = 0.65 + 0.35 * absf(sin(Time.get_ticks_msec() * 0.008))


func _update_rocket_badge() -> void:
	if _rocket_label == null:
		return
	if game_mode == "battle":
		_rocket_label.modulate.a = 0.0
		return
	var inbound := 0
	if rockets and rockets.has_method("inbound_launches"):
		inbound = rockets.inbound_launches().size()
	if inbound > 0:
		var pulse := 0.62 + 0.38 * absf(sin(Time.get_ticks_msec() * 0.01))
		_rocket_label.modulate = Color(1.0, 0.38, 0.22, pulse)
		_rocket_label.text = "ROCKET  INBOUND" if inbound == 1 else "ROCKETS  INBOUND"
	else:
		_rocket_label.modulate.a = move_toward(_rocket_label.modulate.a, 0.0, 0.08)
