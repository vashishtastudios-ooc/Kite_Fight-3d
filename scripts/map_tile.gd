extends Button

## One card in the map bento grid: the map's picture edge to edge on a rounded
## card, a dark fade at the foot carrying its name and mood. Hover slowly
## pushes the picture in and warms the border; the chosen map gets a gold
## border and a check. Coming-soon cards draw a dim silhouette instead and
## cannot be picked.

const Brand := preload("res://scripts/brand.gd")

const RADIUS := 16
const GOLD := Color(1.0, 0.84, 0.38)

var map_id: String = ""
var coming: bool = false
var art: String = ""

var _img: TextureRect
var _frame: Panel
var _frame_sb: StyleBoxFlat
var _check: Label
var _hover: bool = false
var _selected: bool = false
var _zoom: float = 1.0


func setup(data: Dictionary, tile_size: Vector2, is_coming: bool = false) -> void:
	coming = is_coming
	map_id = str(data.get("id", ""))
	art = str(data.get("art", ""))
	custom_minimum_size = tile_size
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE if coming else Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW if coming else Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, empty)

	## Rounded card that clips everything inside it.
	var card := Panel.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.08, 0.06, 0.08)
	card_sb.set_corner_radius_all(RADIUS)
	card.add_theme_stylebox_override("panel", card_sb)
	add_child(card)

	if coming:
		var sil := Control.new()
		sil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sil.draw.connect(_draw_silhouette.bind(sil))
		card.add_child(sil)
	else:
		_img = TextureRect.new()
		_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var path := str(data.get("image", ""))
		if path != "" and ResourceLoader.exists(path):
			_img.texture = load(path)
		card.add_child(_img)

	## Dark fade at the foot so the name always reads.
	var scrim := TextureRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0.04, 0.02, 0.04, 0.15), Color(0.04, 0.02, 0.04, 0.88)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 64
	scrim.texture = gt
	card.add_child(scrim)

	var text := VBoxContainer.new()
	text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	text.offset_left = 16.0
	text.offset_right = -16.0
	text.offset_top = -64.0 if not coming else -58.0
	text.offset_bottom = -12.0
	text.alignment = BoxContainer.ALIGNMENT_END
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(text)
	var name_l := Label.new()
	name_l.text = str(data.get("title", ""))
	name_l.add_theme_font_override("font", Brand.display_font())
	name_l.add_theme_font_size_override("font_size", 24 if not coming else 17)
	name_l.add_theme_color_override("font_color", Brand.CREAM if not coming else Color(1.0, 0.94, 0.82, 0.7))
	name_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	name_l.add_theme_constant_override("shadow_offset_y", 2)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(name_l)
	var mood_l := Label.new()
	mood_l.text = str(data.get("mood", ""))
	mood_l.add_theme_font_override("font", Brand.body_font())
	mood_l.add_theme_font_size_override("font_size", 13 if not coming else 11)
	mood_l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.82, 0.82 if not coming else 0.5))
	mood_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mood_l.clip_text = true
	text.add_child(mood_l)

	if coming:
		var chip := Label.new()
		chip.text = "COMING SOON"
		chip.add_theme_font_override("font", Brand.body_font())
		chip.add_theme_font_size_override("font_size", 10)
		chip.add_theme_color_override("font_color", GOLD)
		chip.position = Vector2(14, 10)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(chip)

	## Border drawn over everything; warms on hover, gold when chosen.
	_frame = Panel.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_sb = StyleBoxFlat.new()
	_frame_sb.draw_center = false
	_frame_sb.set_corner_radius_all(RADIUS)
	_frame_sb.set_border_width_all(1)
	_frame_sb.border_color = Color(1.0, 0.9, 0.75, 0.22)
	_frame.add_theme_stylebox_override("panel", _frame_sb)
	add_child(_frame)

	_check = Label.new()
	_check.text = "✓"
	_check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_check.size = Vector2(28, 28)
	_check.add_theme_font_size_override("font_size", 18)
	_check.add_theme_color_override("font_color", Color(0.12, 0.07, 0.04))
	var chk_sb := StyleBoxFlat.new()
	chk_sb.bg_color = GOLD
	chk_sb.set_corner_radius_all(14)
	_check.add_theme_stylebox_override("normal", chk_sb)
	_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_check.visible = false
	add_child(_check)

	if not coming:
		mouse_entered.connect(func() -> void: _hover = true)
		mouse_exited.connect(func() -> void: _hover = false)
	resized.connect(_layout)


func set_selected(on: bool) -> void:
	_selected = on


func _layout() -> void:
	if _check:
		_check.position = Vector2(size.x - 40.0, 12.0)
	if _img:
		_img.pivot_offset = size * 0.5


func _process(delta: float) -> void:
	if not is_visible_in_tree() or coming:
		return
	_zoom = move_toward(_zoom, 1.07 if _hover else 1.0, delta * 0.35)
	if _img:
		_img.scale = Vector2.ONE * _zoom
	var want := Color(1.0, 0.9, 0.75, 0.22)
	var width := 1
	if _selected:
		want = GOLD
		width = 3
	elif _hover:
		want = Color(1.0, 0.78, 0.46, 0.85)
		width = 2
	_frame_sb.border_color = _frame_sb.border_color.lerp(want, clampf(delta * 10.0, 0.0, 1.0))
	_frame_sb.set_border_width_all(width)
	_check.visible = _selected


## Coming-soon art: a dim dusk gradient and a silhouette of what is coming.
func _draw_silhouette(c: Control) -> void:
	var s := c.size
	var top := Color(0.22, 0.14, 0.24)
	var bot := Color(0.46, 0.26, 0.24)
	if art == "lanterns":
		top = Color(0.05, 0.06, 0.14)
		bot = Color(0.14, 0.12, 0.24)
	for i in 12:
		var t0 := float(i) / 12.0
		var t1 := float(i + 1) / 12.0
		c.draw_rect(Rect2(0.0, s.y * t0, s.x, s.y * (t1 - t0) + 1.0), top.lerp(bot, t0))
	if art == "dunes":
		c.draw_circle(Vector2(s.x * 0.72, s.y * 0.42), s.y * 0.16, Color(1.0, 0.72, 0.42, 0.55))
		for layer in 3:
			var pts := PackedVector2Array()
			var base := s.y * (0.58 + 0.12 * float(layer))
			var col := Color(0.30, 0.16, 0.16).lerp(Color(0.12, 0.06, 0.08), float(layer) / 2.0)
			pts.append(Vector2(0.0, s.y))
			for k in 21:
				var x := s.x * float(k) / 20.0
				pts.append(Vector2(x, base - sin(x * 0.03 + float(layer) * 1.7) * s.y * 0.07))
			pts.append(Vector2(s.x, s.y))
			c.draw_colored_polygon(pts, col)
	else:
		## Lantern kites rising into a night sky.
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for k in 22:
			var p := Vector2(rng.randf() * s.x, rng.randf() * s.y * 0.8)
			var r := rng.randf_range(1.2, 3.2)
			c.draw_circle(p, r * 2.6, Color(1.0, 0.6, 0.2, 0.12))
			c.draw_circle(p, r, Color(1.0, 0.78, 0.36, 0.85))
		var hill := PackedVector2Array([Vector2(0.0, s.y), Vector2(0.0, s.y * 0.8), Vector2(s.x * 0.3, s.y * 0.72), Vector2(s.x * 0.6, s.y * 0.82), Vector2(s.x, s.y * 0.74), Vector2(s.x, s.y)])
		c.draw_colored_polygon(hill, Color(0.04, 0.03, 0.08))
