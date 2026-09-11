class_name PauseMenu
extends Control

const SettingsSc := preload("res://scripts/game_settings.gd")
const KiteSkins := preload("res://scripts/kite_skins.gd")
const Brand := preload("res://scripts/brand.gd")
const ProfileSc := preload("res://scripts/profile.gd")
const TitleMarkSc := preload("res://scripts/title_mark.gd")

signal quit_requested
signal settings_changed
signal kite_chosen(id: String)

var settings: SettingsSc
var profile: ProfileSc

var _dim: ColorRect
var _pause_box: PanelContainer
var _settings_box: PanelContainer
var _quality: OptionButton
var _full: CheckButton
var _hints: CheckButton
var _how_box: PanelContainer
var _kite_box: PanelContainer
var _kite_row: HBoxContainer
var _shop_coins: Label
var _shop_note: Label
var _profile_box: PanelContainer
var _name_edit: LineEdit
var _rank_lab: Label
var _xp_fill: ColorRect
var _xp_track_w: float = 320.0
var _rec_lab: Label
var _pause_rank: Label
var _pause_coins: Label
var _open: bool = false
var _in_settings: bool = false
var _in_how: bool = false
var _in_kites: bool = false
var _in_profile: bool = false


func is_open() -> bool:
	return _open


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = true
	_set_page(false, false)


func setup(settings_in: SettingsSc, profile_in: ProfileSc = null) -> void:
	settings = settings_in
	profile = profile_in
	_sync_widgets()
	refresh_profile()
	refresh_kite_cards("")


func toggle() -> void:
	if _open and _in_how:
		_in_how = false
		open_pause()
		return
	if _open and _in_kites:
		_in_kites = false
		open_pause()
		return
	if _open and _in_profile:
		_save_name()
		_in_profile = false
		open_pause()
		return
	if _open and _in_settings:
		_set_page(true, false)
		_in_settings = false
		return
	if _open:
		close()
	else:
		open_pause()


func open_pause() -> void:
	_open = true
	_in_settings = false
	_in_how = false
	_in_kites = false
	_in_profile = false
	get_tree().paused = true
	refresh_profile()
	_set_page(true, false)


func open_settings() -> void:
	_open = true
	_in_settings = true
	_in_how = false
	_in_kites = false
	_in_profile = false
	get_tree().paused = true
	_sync_widgets()
	_set_page(true, true)


func open_how() -> void:
	_open = true
	_in_settings = false
	_in_how = true
	_in_kites = false
	_in_profile = false
	get_tree().paused = true
	_dim.visible = true
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_box.visible = false
	_settings_box.visible = false
	if _kite_box:
		_kite_box.visible = false
	if _profile_box:
		_profile_box.visible = false
	_how_box.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func open_kites() -> void:
	_open = true
	_in_settings = false
	_in_how = false
	_in_kites = true
	_in_profile = false
	get_tree().paused = true
	refresh_kite_cards("")
	_dim.visible = true
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_box.visible = false
	_settings_box.visible = false
	_how_box.visible = false
	if _profile_box:
		_profile_box.visible = false
	if _kite_box:
		_kite_box.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func close() -> void:
	_save_name()
	_open = false
	_in_settings = false
	_in_how = false
	_in_kites = false
	_in_profile = false
	get_tree().paused = false
	_set_page(false, false)


func open_profile() -> void:
	_open = true
	_in_settings = false
	_in_how = false
	_in_kites = false
	_in_profile = true
	get_tree().paused = true
	refresh_profile()
	_dim.visible = true
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_box.visible = false
	_settings_box.visible = false
	_how_box.visible = false
	if _kite_box:
		_kite_box.visible = false
	if _profile_box:
		_profile_box.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _set_page(show_dim: bool, settings_page: bool) -> void:
	_dim.visible = show_dim
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP if show_dim else Control.MOUSE_FILTER_IGNORE
	_pause_box.visible = show_dim and not settings_page and not _in_how and not _in_kites and not _in_profile
	_settings_box.visible = show_dim and settings_page
	if _how_box:
		_how_box.visible = show_dim and _in_how
	if _kite_box:
		_kite_box.visible = show_dim and _in_kites
	if _profile_box:
		_profile_box.visible = show_dim and _in_profile
	mouse_filter = Control.MOUSE_FILTER_STOP if show_dim else Control.MOUSE_FILTER_IGNORE


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.05, 0.62)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_pause_box = _make_card()
	_pause_box.custom_minimum_size = Vector2(520, 0)
	center.add_child(_pause_box)
	var pause_col := _vbox(_pause_box)
	var mark := TitleMarkSc.new()
	mark.mark_scale = 0.52
	mark.show_tag = true
	mark.lively = true
	pause_col.add_child(mark)
	_pause_rank = _caption("Rookie")
	_pause_rank.add_theme_color_override("font_color", Brand.GOLD)
	pause_col.add_child(_pause_rank)
	_pause_coins = _caption("0 coins")
	pause_col.add_child(_pause_coins)
	pause_col.add_child(_gap(8))
	pause_col.add_child(_btn("Resume", close))
	pause_col.add_child(_btn("Profile", open_profile))
	pause_col.add_child(_btn("Shop", open_kites))
	pause_col.add_child(_btn("How to play", open_how))
	pause_col.add_child(_btn("Settings", open_settings))
	pause_col.add_child(_btn("Quit", func() -> void: quit_requested.emit()))

	_settings_box = _make_card()
	center.add_child(_settings_box)
	var set_col := _vbox(_settings_box)
	set_col.add_child(_title("SETTINGS"))
	set_col.add_child(_caption("Graphics quality is the main cost. Zoom is free."))
	set_col.add_child(_gap(8))

	var q_row := HBoxContainer.new()
	q_row.add_theme_constant_override("separation", 16)
	var q_lab := Label.new()
	q_lab.text = "Quality"
	q_lab.custom_minimum_size = Vector2(140, 0)
	q_lab.add_theme_font_size_override("font_size", 18)
	q_row.add_child(q_lab)
	_quality = OptionButton.new()
	_quality.add_item("Low", 0)
	_quality.add_item("Medium", 1)
	_quality.add_item("High", 2)
	_quality.custom_minimum_size = Vector2(180, 36)
	_quality.item_selected.connect(_on_quality)
	q_row.add_child(_quality)
	set_col.add_child(q_row)

	_full = CheckButton.new()
	_full.text = "Fullscreen"
	_full.toggled.connect(_on_full)
	_style_check(_full)
	set_col.add_child(_full)

	_hints = CheckButton.new()
	_hints.text = "Show control hints"
	_hints.toggled.connect(_on_hints)
	_style_check(_hints)
	set_col.add_child(_hints)

	set_col.add_child(_gap(10))
	set_col.add_child(_btn("How to play", open_how))
	set_col.add_child(_btn("Back", _back_from_settings))

	_how_box = _make_card()
	_how_box.custom_minimum_size = Vector2(560, 520)
	center.add_child(_how_box)
	_fill_how(_how_box)

	_kite_box = _make_card()
	_kite_box.custom_minimum_size = Vector2(640, 360)
	center.add_child(_kite_box)
	_fill_kites(_kite_box)

	_profile_box = _make_card()
	_profile_box.custom_minimum_size = Vector2(480, 420)
	center.add_child(_profile_box)
	_fill_profile(_profile_box)


func _back_from_settings() -> void:
	_in_settings = false
	_in_how = false
	_in_kites = false
	_in_profile = false
	open_pause()


func _fill_kites(card: PanelContainer) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(_title("SHOP"))
	_shop_coins = _caption("0 coins")
	_shop_coins.add_theme_color_override("font_color", Brand.GOLD)
	v.add_child(_shop_coins)
	v.add_child(_caption("Buy a sail with coins. Saffron is free."))
	_kite_row = HBoxContainer.new()
	_kite_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_kite_row.add_theme_constant_override("separation", 14)
	v.add_child(_kite_row)
	_shop_note = _caption("")
	v.add_child(_shop_note)
	v.add_child(_btn("Back", open_pause))
	refresh_kite_cards("")


func _fill_profile(card: PanelContainer) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	v.add_child(_title("PROFILE"))
	v.add_child(_caption("Your card for later online VS. Photo comes from Play later."))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your name"
	_name_edit.max_length = 16
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(0, 40)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _save_name())
	_name_edit.focus_exited.connect(_save_name)
	v.add_child(_name_edit)
	_rank_lab = _caption("Rookie")
	_rank_lab.add_theme_color_override("font_color", Brand.GOLD)
	v.add_child(_rank_lab)
	var track := ColorRect.new()
	track.color = Color(1.0, 0.84, 0.38, 0.16)
	track.custom_minimum_size = Vector2(_xp_track_w, 8)
	v.add_child(track)
	_xp_fill = ColorRect.new()
	_xp_fill.color = Color(1.0, 0.78, 0.32, 0.95)
	_xp_fill.custom_minimum_size = Vector2(40, 8)
	_xp_fill.position = Vector2.ZERO
	track.add_child(_xp_fill)
	_rec_lab = _caption("0–0  ·  0 cuts")
	v.add_child(_rec_lab)
	v.add_child(_btn("Back", open_pause))


func refresh_profile() -> void:
	if profile == null:
		return
	if _pause_rank:
		_pause_rank.text = "%s  ·  %s" % [profile.display_name, profile.rank_name()]
	if _pause_coins:
		_pause_coins.text = "%d coins" % profile.coins
	if _shop_coins:
		_shop_coins.text = "%d coins" % profile.coins
	if _name_edit and not _name_edit.has_focus():
		_name_edit.text = profile.display_name
	if _rank_lab:
		if profile.rank_index() >= 6:
			_rank_lab.text = "Master"
		else:
			_rank_lab.text = "%s  →  %s" % [profile.rank_name(), profile.next_rank_name()]
	if _xp_fill:
		_xp_fill.custom_minimum_size.x = _xp_track_w * profile.rank_progress()
		_xp_fill.size.x = _xp_track_w * profile.rank_progress()
	if _rec_lab:
		_rec_lab.text = "%d–%d battles  ·  %d cuts" % [profile.battles_won, profile.battles_lost, profile.cuts]


func _save_name() -> void:
	if profile == null or _name_edit == null:
		return
	var n := _name_edit.text.strip_edges()
	if n == "":
		n = "You"
	if n == profile.display_name:
		return
	profile.display_name = n
	profile.save_to_disk()
	refresh_profile()


func refresh_kite_cards(selected: String) -> void:
	if _kite_row == null:
		return
	if selected == "" and profile:
		selected = KiteSkins.clamp_id(profile.kite_id)
	elif selected == "" and settings:
		selected = KiteSkins.clamp_id(settings.kite_id)
	elif selected == "":
		selected = KiteSkins.SAFFRON
	for c in _kite_row.get_children():
		_kite_row.remove_child(c)
		c.queue_free()
	for id in KiteSkins.ids():
		var owned := profile.owns(id) if profile else id == KiteSkins.SAFFRON
		_kite_row.add_child(KiteSkins.make_shop_card(id, id == selected, owned, _on_kite_pick))
	if _shop_coins and profile:
		_shop_coins.text = "%d coins" % profile.coins


func _on_kite_pick(id: String) -> void:
	id = KiteSkins.clamp_id(id)
	if profile:
		if profile.owns(id):
			profile.set_kite(id)
			if _shop_note:
				_shop_note.text = ""
		elif profile.buy(id):
			if _shop_note:
				_shop_note.text = "Bought %s." % KiteSkins.title_for(id)
		else:
			if _shop_note:
				_shop_note.text = "Need %d coins." % KiteSkins.price_for(id)
			call_deferred("refresh_kite_cards", profile.kite_id)
			return
		if settings:
			settings.kite_id = profile.kite_id
			settings.save_to_disk()
		kite_chosen.emit(profile.kite_id)
		refresh_profile()
		call_deferred("refresh_kite_cards", profile.kite_id)
		return
	if settings:
		settings.kite_id = id
		settings.save_to_disk()
	kite_chosen.emit(id)
	call_deferred("refresh_kite_cards", id)


func _fill_how(card: PanelContainer) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	v.add_child(_title("HOW TO PLAY"))
	v.add_child(_caption("A dusk rooftop. Charge pink. Cut their string."))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 340)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_child(_how_block("FLY", Color(0.55, 0.82, 1.0), "Q darts the nose. E sags the line (dheel). Wheel pays line in or out. Space tosses. R relaunches. Dart with the wind to go faster — into the wind is slower."))
	body.add_child(_how_block("DODGE", Color(1.0, 0.45, 0.28), "Diwali rockets lock where you were. Q or E off the path before they burst. Three real dodges fill the CUT CHARGE pips. A hit knocks you down and empties the pips."))
	body.add_child(_how_block("CUT", Color(1.0, 0.38, 0.72), "Three pips — kite glows pink. The next Q is a fast dash. Steer that dash through their manjha (the string). Hit = wo kaata. Miss = bar empty, fly on. First to 2 cuts wins the evening."))
	body.add_child(_how_block("SLIP", Color(0.95, 0.78, 0.35), "If they glow pink, tap E so your kite drops off their line. Sag off the cross and their dash misses. Stay slack while still crossed and their dash cuts you."))
	v.add_child(_btn("Back", open_pause))


func _how_block(heading: String, accent: Color, copy: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r * 0.18, accent.g * 0.14, accent.b * 0.12, 0.92)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	p.add_child(col)
	var h := Label.new()
	h.text = heading
	h.add_theme_font_size_override("font_size", 18)
	h.add_theme_color_override("font_color", accent)
	col.add_child(h)
	var t := Label.new()
	t.text = copy
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", Color(1.0, 0.93, 0.82, 0.95))
	col.add_child(t)
	return p


func _sync_widgets() -> void:
	if settings == null:
		return
	if _quality:
		_quality.select(settings.quality)
	if _full:
		_full.set_pressed_no_signal(settings.fullscreen)
	if _hints:
		_hints.set_pressed_no_signal(settings.show_hints)


func _on_quality(index: int) -> void:
	if settings == null:
		return
	settings.quality = index
	settings.save_to_disk()
	settings_changed.emit()


func _on_full(on: bool) -> void:
	if settings == null:
		return
	settings.fullscreen = on
	settings.save_to_disk()
	settings_changed.emit()


func _on_hints(on: bool) -> void:
	if settings == null:
		return
	settings.show_hints = on
	settings.save_to_disk()
	settings_changed.emit()


func _make_card() -> PanelContainer:
	var p := PanelContainer.new()
	p.visible = false
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.custom_minimum_size = Vector2(440, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.96)
	sb.border_color = Color(0.95, 0.72, 0.32, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	p.add_theme_stylebox_override("panel", sb)
	return p


func _vbox(parent: PanelContainer) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	parent.add_child(v)
	return v


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Brand.display_font())
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", Brand.GOLD)
	l.add_theme_color_override("font_outline_color", Brand.INK)
	l.add_theme_constant_override("outline_size", 6)
	return l


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.82, 0.78, 0.7, 0.85))
	return l


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(cb)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.12, 0.10, 0.95)
	normal.border_color = Color(0.85, 0.62, 0.28, 0.7)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.28, 0.20, 0.10, 0.98)
	hover.border_color = Color(1.0, 0.82, 0.4, 1.0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
	return b


func _style_check(b: CheckButton) -> void:
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
