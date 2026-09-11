extends Control

## Punchy mobile wordmark: KITE over BATTLE, kite-diamond 3D badge, Patangbaaz under.

const Brand := preload("res://scripts/brand.gd")

@export var mark_scale: float = 1.0
@export var show_tag: bool = true
@export var lively: bool = true

var _badge: Control
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_build()
	set_process(lively)


func _build() -> void:
	var s := mark_scale
	var w := 560.0 * s
	var h := (196.0 if show_tag else 150.0) * s
	custom_minimum_size = Vector2(w, h)
	size = custom_minimum_size

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", int(-6.0 * s))
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(col)

	col.add_child(_kite_row(s))
	col.add_child(_battle_row(s))

	var slash := ColorRect.new()
	slash.color = Brand.MAGENTA
	slash.custom_minimum_size = Vector2(300.0 * s, maxf(5.0, 7.0 * s))
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.rotation = -0.08
	slash.pivot_offset = Vector2(150.0 * s, 4.0 * s)
	var slash_wrap := CenterContainer.new()
	slash_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash_wrap.add_child(slash)
	col.add_child(slash_wrap)

	if show_tag:
		var tag := Label.new()
		tag.text = Brand.TAGLINE.to_upper()
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_override("font", Brand.body_font())
		tag.add_theme_font_size_override("font_size", int(20.0 * s))
		tag.add_theme_color_override("font_color", Brand.GOLD)
		tag.add_theme_color_override("font_outline_color", Brand.INK)
		tag.add_theme_constant_override("outline_size", int(8.0 * s))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(tag)


func _kite_row(s: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(10.0 * s))
	for ch in "KITE":
		row.add_child(_glyph(ch, int(34.0 * s), Brand.CREAM, s))
	return row


func _battle_row(s: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(-22.0 * s))
	var battle := HBoxContainer.new()
	battle.alignment = BoxContainer.ALIGNMENT_CENTER
	battle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle.add_theme_constant_override("separation", int(-4.0 * s))
	var i := 0
	for ch in "BATTLE":
		battle.add_child(_glyph(ch, int(78.0 * s), Brand.SAFFRON if i % 2 == 0 else Brand.GOLD, s))
		i += 1
	row.add_child(battle)
	_badge = _kite_badge(s)
	row.add_child(_badge)
	return row


func _glyph(ch: String, px: int, fill: Color, s: float) -> Label:
	var l := Label.new()
	l.text = ch
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Brand.mark_font())
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", fill)
	l.add_theme_color_override("font_outline_color", Brand.INK)
	l.add_theme_constant_override("outline_size", maxi(8, int(px * 0.18)))
	l.add_theme_color_override("font_shadow_color", Color(Brand.MAGENTA, 0.72))
	l.add_theme_constant_override("shadow_offset_x", int(3.0 * s))
	l.add_theme_constant_override("shadow_offset_y", int(6.0 * s))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _kite_badge(s: float) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(96.0 * s, 96.0 * s)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.clip_contents = false
	wrap.pivot_offset = wrap.custom_minimum_size * 0.5
	wrap.rotation = -0.22

	var ink := ColorRect.new()
	ink.color = Brand.INK
	ink.size = Vector2(62.0 * s, 62.0 * s)
	ink.position = Vector2(20.0 * s, 22.0 * s)
	ink.pivot_offset = ink.size * 0.5
	ink.rotation = PI * 0.25
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(ink)

	var gold := ColorRect.new()
	gold.color = Brand.GOLD
	gold.size = Vector2(54.0 * s, 54.0 * s)
	gold.position = Vector2(22.0 * s, 18.0 * s)
	gold.pivot_offset = gold.size * 0.5
	gold.rotation = PI * 0.25
	gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(gold)

	var num := Label.new()
	num.text = "3D"
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.size = wrap.custom_minimum_size
	num.add_theme_font_override("font", Brand.mark_font())
	num.add_theme_font_size_override("font_size", int(28.0 * s))
	num.add_theme_color_override("font_color", Brand.INK)
	num.add_theme_color_override("font_outline_color", Brand.CREAM)
	num.add_theme_constant_override("outline_size", int(6.0 * s))
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(num)
	return wrap


func _process(delta: float) -> void:
	if not lively or _badge == null:
		return
	_t += delta
	var pulse := 1.0 + 0.08 * sin(_t * 5.2)
	_badge.scale = Vector2(pulse, pulse)
	_badge.rotation = -0.22 + sin(_t * 3.4) * 0.06
