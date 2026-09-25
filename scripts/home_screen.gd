extends Control

## Home: your flyer on the roof with the sky alive behind them. One big PLAY
## repeats your last fight on this map; Modes, Maps, Kites, Flyer and
## Settings sit beside it, and your card (tap for the profile) top right.
## Everything is sized for a thumb.

const Brand := preload("res://scripts/brand.gd")
const PatangMarkSc := preload("res://scripts/patang_mark.gd")

signal play_pressed
signal modes_pressed
signal maps_pressed
signal flyer_pressed
signal settings_pressed
signal kites_pressed
signal profile_pressed

const MARGIN := 56.0

var _logo: Control
var _chip: PanelContainer
var _chip_name: Label
var _chip_rank: Label
var _chip_coins: Label
var _rank_fill: ColorRect
var _tiles: HBoxContainer
var _play: Button
var _play_sub: Label
var _play_sb: StyleBoxFlat
var _t: float = 0.0
var _shown: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	## Soft dusk shade at the foot and the head, so white type always reads
	## over a bright sky.
	add_child(_shade(true))
	add_child(_shade(false))

	_logo = PatangMarkSc.new()
	_logo.variant = 1
	_logo.mark_scale = 0.5
	_logo.show_tag = false
	_logo.lively = true
	_logo.position = Vector2(MARGIN - 20.0, 4.0)
	add_child(_logo)

	_build_chip()
	_build_tiles()
	_build_play()


func _shade(top: bool) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var ink := Color(0.06, 0.03, 0.06)
	g.colors = PackedColorArray([Color(ink, 0.0), Color(ink, 0.62 if not top else 0.38)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0) if not top else Vector2(0.5, 1.0)
	gt.fill_to = Vector2(0.5, 1.0) if not top else Vector2(0.5, 0.0)
	gt.width = 8
	gt.height = 128
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if top:
		r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		r.offset_bottom = 230.0
	else:
		r.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		r.offset_top = -380.0
	return r


# ── Profile chip ─────────────────────────────────────────────────────────────

func _build_chip() -> void:
	_chip = PanelContainer.new()
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.anchor_left = 1.0
	_chip.anchor_right = 1.0
	_chip.offset_left = -430.0
	_chip.offset_right = -MARGIN
	_chip.offset_top = 40.0
	_chip.offset_bottom = 132.0
	_chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var sb := _glass(22)
	sb.content_margin_left = 14
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_chip.add_theme_stylebox_override("panel", sb)
	add_child(_chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_chip.add_child(row)

	var face := Panel.new()
	face.custom_minimum_size = Vector2(66, 66)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.32, 0.14, 0.12)
	fsb.border_color = Brand.GOLD
	fsb.set_border_width_all(3)
	fsb.set_corner_radius_all(33)
	face.add_theme_stylebox_override("panel", fsb)
	row.add_child(face)
	var letter := Label.new()
	letter.name = "Letter"
	letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.add_theme_font_override("font", Brand.display_font())
	letter.add_theme_font_size_override("font_size", 32)
	letter.add_theme_color_override("font_color", Brand.CREAM)
	face.add_child(letter)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	_chip_name = _label(24, Brand.CREAM, Brand.display_font())
	col.add_child(_chip_name)
	_chip_rank = _label(15, Brand.GOLD)
	col.add_child(_chip_rank)
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.12)
	track.custom_minimum_size = Vector2(170, 6)
	col.add_child(track)
	_rank_fill = ColorRect.new()
	_rank_fill.color = Brand.GOLD
	_rank_fill.size = Vector2(0, 6)
	track.add_child(_rank_fill)

	var coins := HBoxContainer.new()
	coins.add_theme_constant_override("separation", 8)
	coins.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(coins)
	var coin := _Coin.new()
	coin.custom_minimum_size = Vector2(30, 30)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coins.add_child(coin)
	_chip_coins = _label(26, Brand.GOLD, Brand.display_font())
	coins.add_child(_chip_coins)
	## The whole card is a button onto the profile.
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "focus"]:
		hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.pressed.connect(func() -> void: profile_pressed.emit())
	_chip.add_child(hit)


# ── Icon tiles ───────────────────────────────────────────────────────────────

func _build_tiles() -> void:
	_tiles = HBoxContainer.new()
	_tiles.add_theme_constant_override("separation", 18)
	_tiles.anchor_top = 1.0
	_tiles.anchor_bottom = 1.0
	_tiles.offset_left = MARGIN
	_tiles.offset_top = -MARGIN - 136.0
	_tiles.offset_bottom = -MARGIN
	_tiles.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tiles)
	_tiles.add_child(_tile("modes", "Modes", modes_pressed))
	_tiles.add_child(_tile("maps", "Maps", maps_pressed))
	_tiles.add_child(_tile("kites", "Kites", kites_pressed))
	_tiles.add_child(_tile("flyer", "Flyer", flyer_pressed))
	_tiles.add_child(_tile("settings", "Settings", settings_pressed))


func _tile(icon: String, title: String, sig: Signal) -> Button:
	var b := _IconTile.new()
	b.icon_kind = icon
	b.caption = title
	b.custom_minimum_size = Vector2(142, 136)
	b.pressed.connect(func() -> void: sig.emit())
	return b


# ── PLAY ─────────────────────────────────────────────────────────────────────

func _build_play() -> void:
	_play = Button.new()
	_play.focus_mode = Control.FOCUS_NONE
	_play.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_play.anchor_left = 1.0
	_play.anchor_right = 1.0
	_play.anchor_top = 1.0
	_play.anchor_bottom = 1.0
	_play.offset_left = -MARGIN - 470.0
	_play.offset_right = -MARGIN
	_play.offset_top = -MARGIN - 170.0
	_play.offset_bottom = -MARGIN
	_play_sb = StyleBoxFlat.new()
	_play_sb.bg_color = Color(1.0, 0.56, 0.16)
	_play_sb.border_color = Color(1.0, 0.86, 0.46)
	_play_sb.set_border_width_all(4)
	_play_sb.border_width_bottom = 10
	_play_sb.set_corner_radius_all(30)
	_play_sb.skew = Vector2(-0.08, 0.0)
	_play_sb.shadow_color = Color(1.0, 0.42, 0.10, 0.45)
	_play_sb.shadow_size = 26
	var hot := _play_sb.duplicate() as StyleBoxFlat
	hot.bg_color = Color(1.0, 0.64, 0.22)
	hot.border_color = Color(1.0, 0.94, 0.66)
	var down := _play_sb.duplicate() as StyleBoxFlat
	down.bg_color = Color(0.94, 0.48, 0.12)
	down.border_width_bottom = 4
	_play.add_theme_stylebox_override("normal", _play_sb)
	_play.add_theme_stylebox_override("hover", hot)
	_play.add_theme_stylebox_override("pressed", down)
	_play.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_play.pressed.connect(func() -> void: play_pressed.emit())
	add_child(_play)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(col)
	var word := _label(84, Brand.CREAM, Brand.kite_word_font())
	word.text = "PLAY"
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.add_theme_color_override("font_outline_color", Color(0.42, 0.10, 0.04))
	word.add_theme_constant_override("outline_size", 14)
	word.add_theme_color_override("font_shadow_color", Color(0.30, 0.06, 0.02, 0.55))
	word.add_theme_constant_override("shadow_offset_y", 5)
	col.add_child(word)
	_play_sub = _label(19, Color(0.36, 0.08, 0.03))
	_play_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_play_sub)


## Fill in the flyer's card and what PLAY will start.
func fill(profile: Object, mode_title: String, map_title: String) -> void:
	if profile:
		var n := str(profile.display_name)
		_chip_name.text = n
		(_chip.find_child("Letter", true, false) as Label).text = n.substr(0, 1).to_upper() if n != "" else "Y"
		var top := str(profile.rank_name()) == str(profile.next_rank_name())
		_chip_rank.text = ("%s  ·  top rank" % profile.rank_name()) if top else ("%s  ·  next: %s" % [profile.rank_name(), profile.next_rank_name()])
		_rank_fill.size.x = 170.0 * float(profile.rank_progress())
		_chip_coins.text = str(profile.coins)
	_play_sub.text = "%s  ·  %s" % [mode_title, map_title]


func open() -> void:
	if _shown:
		return
	visible = true
	modulate.a = 1.0
	_shown = true
	_t = 0.0
	## Stagger in: logo and chip drop, tiles and PLAY rise.
	var parts: Array[Control] = [_logo, _chip, _tiles, _play]
	for i in parts.size():
		var c := parts[i]
		c.modulate.a = 0.0
		var from_y := -24.0 if i < 2 else 34.0
		var tw := create_tween()
		tw.tween_interval(0.08 * float(i))
		tw.tween_property(c, "modulate:a", 1.0, 0.35)
		c.position.y += from_y
		var tw2 := create_tween()
		tw2.tween_interval(0.08 * float(i))
		tw2.tween_property(c, "position:y", c.position.y - from_y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not _shown:
		return
	_shown = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0)


func _process(delta: float) -> void:
	if not _shown:
		return
	_t += delta
	## PLAY breathes: the glow swells and the button leans in a touch.
	var beat := 0.5 + 0.5 * sin(_t * 2.6)
	_play_sb.shadow_size = int(18.0 + 16.0 * beat)
	_play_sb.shadow_color = Color(1.0, 0.42, 0.10, 0.30 + 0.25 * beat)
	_play.pivot_offset = _play.size * 0.5
	_play.scale = Vector2.ONE * (1.0 + 0.018 * beat)


func _glass(radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.08, 0.66)
	sb.border_color = Color(1.0, 0.84, 0.38, 0.38)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 4)
	return sb


func _label(px: int, col: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font if font else Brand.body_font())
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A gold coin: a disc with a rim and a stamped kite.
class _Coin extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c + Vector2(0, 2), r, Color(0.45, 0.24, 0.02, 0.6))
		draw_circle(c, r, Color(1.0, 0.72, 0.18))
		draw_circle(c, r * 0.78, Color(1.0, 0.84, 0.38))
		var k := r * 0.42
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k), c + Vector2(k * 0.8, 0), c + Vector2(0, k), c + Vector2(-k * 0.8, 0)]), Color(0.86, 0.46, 0.08))


## A square glass tile with a drawn icon and a caption; lifts on hover.
class _IconTile extends Button:
	const Brand := preload("res://scripts/brand.gd")
	var icon_kind: String = ""
	var caption: String = ""
	var _hot: float = 0.0
	var _over: bool = false

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(func() -> void: _over = true)
		mouse_exited.connect(func() -> void: _over = false)
		var cap := Label.new()
		cap.text = caption
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		cap.offset_top = -46.0
		cap.offset_bottom = -14.0
		cap.add_theme_font_override("font", Brand.body_font())
		cap.add_theme_font_size_override("font_size", 20)
		cap.add_theme_color_override("font_color", Brand.CREAM)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.name = "Caption"
		add_child(cap)

	func _process(delta: float) -> void:
		var want := 1.0 if (_over or button_pressed) else 0.0
		if not is_equal_approx(_hot, want):
			_hot = move_toward(_hot, want, delta * 6.0)
			queue_redraw()
			var cap := get_node_or_null("Caption") as Label
			if cap:
				cap.position.y = size.y - 46.0 - 5.0 * _hot

	func _draw() -> void:
		var lift := -5.0 * _hot
		var r := Rect2(Vector2(0, lift), size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.05, 0.08, 0.66 + 0.16 * _hot)
		sb.border_color = Color(1.0, 0.84, 0.38, 0.35 + 0.65 * _hot)
		sb.set_border_width_all(2 + int(_hot))
		sb.set_corner_radius_all(24)
		sb.shadow_color = Color(0, 0, 0, 0.3)
		sb.shadow_size = 12
		sb.shadow_offset = Vector2(0, 4)
		draw_style_box(sb, r)
		var ic := Vector2(size.x * 0.5, 50.0 + lift)
		var col := Brand.GOLD.lerp(Brand.CREAM, _hot)
		_draw_icon(ic, 24.0, col)

	func _draw_icon(c: Vector2, s: float, col: Color) -> void:
		match icon_kind:
			"modes":
				## Two patangs, strings crossing: a fight.
				for sx in [-1.0, 1.0]:
					var k := c + Vector2(sx * s * 0.62, -s * 0.34)
					var h := s * 0.46
					draw_colored_polygon(PackedVector2Array([k + Vector2(0, -h), k + Vector2(h * 0.78, 0), k + Vector2(0, h), k + Vector2(-h * 0.78, 0)]), col)
					draw_line(k + Vector2(0, h), c + Vector2(-sx * s * 0.8, s * 0.95), col, 2.5, true)
			"maps":
				## A folded map with a pin.
				var pts := PackedVector2Array([
					c + Vector2(-s, -s * 0.62), c + Vector2(-s * 0.34, -s * 0.82), c + Vector2(s * 0.34, -s * 0.62), c + Vector2(s, -s * 0.82),
					c + Vector2(s, s * 0.72), c + Vector2(s * 0.34, s * 0.92), c + Vector2(-s * 0.34, s * 0.72), c + Vector2(-s, s * 0.92),
				])
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[6], pts[7], pts[0]]), col, 3.0, true)
				draw_line(pts[1], pts[6], col, 2.0, true)
				draw_line(pts[2], pts[5], col, 2.0, true)
				var pin := c + Vector2(s * 0.05, -s * 0.12)
				draw_circle(pin, s * 0.26, col)
				draw_colored_polygon(PackedVector2Array([pin + Vector2(-s * 0.2, s * 0.14), pin + Vector2(s * 0.2, s * 0.14), pin + Vector2(0, s * 0.56)]), col)
				draw_circle(pin, s * 0.1, Color(0.07, 0.05, 0.08))
			"kites":
				## A patang with its tail.
				var h := s * 0.8
				var k := c + Vector2(0, -s * 0.2)
				draw_colored_polygon(PackedVector2Array([k + Vector2(0, -h), k + Vector2(h * 0.8, 0), k + Vector2(0, h), k + Vector2(-h * 0.8, 0)]), col)
				draw_line(k + Vector2(0, -h), k + Vector2(0, h), Color(0.07, 0.05, 0.08), 2.0, true)
				draw_line(k + Vector2(-h * 0.8, 0), k + Vector2(h * 0.8, 0), Color(0.07, 0.05, 0.08), 2.0, true)
				draw_polyline(PackedVector2Array([k + Vector2(0, h), k + Vector2(-s * 0.2, h + s * 0.2), k + Vector2(s * 0.12, h + s * 0.36)]), col, 2.5, true)
			"flyer":
				## Head and shoulders.
				draw_circle(c + Vector2(0, -s * 0.42), s * 0.4, col)
				var sh := PackedVector2Array()
				for i in 17:
					var a := PI + PI * float(i) / 16.0
					sh.append(c + Vector2(cos(a) * s * 0.86, s * 0.98 + sin(a) * s * 0.9))
				draw_colored_polygon(sh, col)
			"settings":
				## A gear.
				var teeth := 8
				var poly := PackedVector2Array()
				for i in teeth * 4:
					var a := TAU * float(i) / float(teeth * 4)
					var rr := s * (0.95 if (i % 4) < 2 else 0.72)
					poly.append(c + Vector2(cos(a), sin(a)) * rr)
				draw_colored_polygon(poly, col)
				draw_circle(c, s * 0.34, Color(0.07, 0.05, 0.08))
