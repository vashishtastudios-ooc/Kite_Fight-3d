extends Control

## The Patang wordmark, drawn in the game's own quiet palette: one kite on a
## thin string over PATANG in wide cream capitals with a soft glow, so it sits
## in the sky of any map instead of on top of it.
##   variant 0  clean: a saffron kite, its string sweeping under the word
##   variant 1  bilingual: as 0, with पतंग in Devanagari under the word
##   variant 2  pech: two kites whose strings cross beneath the word

const INTER := preload("res://assets/fonts/Inter.woff2")
const DEVANAGARI := preload("res://assets/fonts/NotoSansDevanagari-Regular.woff2")

const CREAM := Color(1.0, 0.95, 0.86)
const SAFFRON := Color(1.0, 0.56, 0.22)
const GLOW := Color(1.0, 0.80, 0.56)
const TAG := "A  ROOFTOP  KITE  FIGHT"

@export var mark_scale: float = 1.0
@export var variant: int = 0
@export var show_tag: bool = true
@export var lively: bool = true

var _word: Label
var _deva: Label
var _tag: Label
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_build()
	set_process(lively)


static func font(weight: int, tracking: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = INTER
	f.variation_opentype = {"wght": weight}
	f.spacing_glyph = tracking
	return f


func _build() -> void:
	var s := mark_scale
	custom_minimum_size = Vector2(640.0, 350.0 if variant == 1 else 300.0) * s
	size = custom_minimum_size
	_word = _label("PATANG", font(300, int(30.0 * s)), int(120.0 * s), CREAM)
	_word.position = Vector2(0.0, 88.0 * s)
	## Tracking adds space after the last letter too; nudge right to recentre.
	_word.size = Vector2(size.x + 30.0 * s, 150.0 * s)
	add_child(_word)
	var y := 250.0 * s
	if variant == 1:
		var d := FontVariation.new()
		d.base_font = DEVANAGARI
		_deva = _label("पतंग", d, int(40.0 * s), SAFFRON)
		_deva.position = Vector2(0.0, y - 6.0 * s)
		_deva.size = Vector2(size.x, 60.0 * s)
		add_child(_deva)
		y += 52.0 * s
	if show_tag:
		_tag = _label(TAG, font(500, int(3.0 * s)), int(18.0 * s), Color(CREAM, 0.78), false)
		_tag.position = Vector2(0.0, y)
		_tag.size = Vector2(size.x, 30.0 * s)
		add_child(_tag)


func _label(text: String, f: Font, px: int, col: Color, glow: bool = true) -> Label:
	var l := _plain(text, f, px, col)
	if glow:
		## A soft halo: the same word drawn behind in faint, ever wider
		## outlines, so the letters glow in the dusk rather than sit in a box.
		for i in 4:
			var g := _plain(text, f, px, Color(0, 0, 0, 0))
			g.add_theme_color_override("font_outline_color", Color(GLOW, 0.05))
			g.add_theme_constant_override("outline_size", int(float(6 + i * 9) * mark_scale))
			l.add_child(g)
			g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			g.show_behind_parent = true
	return l


func _plain(text: String, f: Font, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := mark_scale
	var bob := Vector2(sin(_t * 1.3) * 3.0, sin(_t * 1.9) * 4.0) * s
	if variant == 2:
		## Pech: two kites high on either side, strings crossing under the word.
		var k1 := Vector2(size.x * 0.20, 34.0 * s) + bob
		var k2 := Vector2(size.x * 0.80, 30.0 * s) - bob * 0.8
		var cross := Vector2(size.x * 0.5, 236.0 * s)
		_string(k1, cross + Vector2(size.x * 0.34, 22.0 * s), Color(CREAM, 0.55), s)
		_string(k2, cross + Vector2(-size.x * 0.34, 22.0 * s), Color(SAFFRON, 0.75), s)
		draw_circle(cross + Vector2(0.0, 6.0 * s), 3.2 * s, Color(1.0, 0.9, 0.6, 0.9))
		_kite(k1, 26.0 * s, CREAM, -0.18)
		_kite(k2, 26.0 * s, SAFFRON, 0.2)
		return
	## One kite high right; its string drops past the G and sweeps back under
	## the word like an underline, never through the letters.
	var k := Vector2(size.x * 0.93, 22.0 * s) + bob
	var foot := k + Vector2(0.0, 30.0 * s)
	var pts := PackedVector2Array()
	var c1 := Vector2(size.x * 1.03, 150.0 * s)
	var c2 := Vector2(size.x * 0.90, 250.0 * s)
	var end := Vector2(size.x * 0.10, 236.0 * s)
	for i in 41:
		var u := float(i) / 40.0
		var v := 1.0 - u
		pts.append(foot * v * v * v + c1 * 3.0 * v * v * u + c2 * 3.0 * v * u * u + end * u * u * u)
	draw_polyline(pts, Color(CREAM, 0.6), 1.6 * s, true)
	_kite(k, 26.0 * s, SAFFRON, 0.16)


## A thin curved string from the kite's foot to the flyer's hand.
func _string(from: Vector2, to: Vector2, col: Color, s: float) -> void:
	var mid := (from + to) * 0.5 + Vector2(0.0, 70.0 * s)
	var pts := PackedVector2Array()
	for i in 33:
		var u := float(i) / 32.0
		pts.append(from.lerp(mid, u).lerp(mid.lerp(to, u), u))
	draw_polyline(pts, col, 1.6 * s, true)


## A patang: a diamond with a bowed top spar, spine and a short tail.
func _kite(c: Vector2, h: float, col: Color, tilt: float) -> void:
	var rot := Transform2D(tilt, c)
	var w := h * 0.82
	var body := PackedVector2Array([Vector2(0, -h), Vector2(w, -h * 0.12), Vector2(0, h), Vector2(-w, -h * 0.12)])
	var poly := PackedVector2Array()
	for p in body:
		poly.append(rot * p)
	## Glow first, then the paper.
	for r in range(8, 0, -1):
		draw_circle(c, h * 0.25 * float(r), Color(col, 0.018))
	draw_colored_polygon(poly, col)
	var ink := Color(0.22, 0.10, 0.10, 0.55)
	draw_line(rot * Vector2(0, -h), rot * Vector2(0, h), ink, 1.2, true)
	var bow := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0
		var x := lerpf(-w, w, u)
		bow.append(rot * Vector2(x, -h * 0.12 - sin(u * PI) * h * 0.28))
	draw_polyline(bow, ink, 1.2, true)
	## Tail: two small triangles under the foot.
	var foot := rot * Vector2(0, h)
	for i in 2:
		var ty := h * (0.28 + 0.34 * float(i))
		var tri := PackedVector2Array([rot * Vector2(0, h + ty - h * 0.1), rot * Vector2(h * 0.16, h + ty + h * 0.12), rot * Vector2(-h * 0.16, h + ty + h * 0.12)])
		draw_colored_polygon(tri, col)
	draw_line(foot, rot * Vector2(0, h * 1.9), Color(col, 0.7), 1.0, true)
