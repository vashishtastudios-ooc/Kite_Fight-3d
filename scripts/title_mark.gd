extends Control

## Wordmark: diamond kite, then KITE over BATTLE, Patangbaaz under.

const Brand := preload("res://scripts/brand.gd")
const KiteSailSc := preload("res://scripts/kite_sail.gd")

@export var mark_scale: float = 1.0
@export var show_tag: bool = true
@export var lively: bool = true

var _badge: Control
var _sail: KiteSailSc
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_build()
	set_process(lively)


func _build() -> void:
	var s := mark_scale
	var w := 520.0 * s
	var h := (560.0 if show_tag else 500.0) * s
	custom_minimum_size = Vector2(w, h)
	size = custom_minimum_size
	clip_contents = false
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", int(4.0 * s))
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.clip_contents = false
	add_child(col)

	_sail = KiteSailSc.new()
	_sail.mark_scale = s
	_sail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(_sail)
	col.add_child(_kite_word_row(s))
	col.add_child(_battle_row(s))

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


func _kite_word_row(s: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(-6.0 * s))
	var i := 0
	for ch in "KITE":
		row.add_child(_kite_glyph(ch, int(78.0 * s), Brand.CREAM if i % 2 == 0 else Brand.GOLD, s))
		i += 1
	return row


func _kite_glyph(ch: String, px: int, fill: Color, s: float) -> Label:
	var l := Label.new()
	l.text = ch
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Brand.kite_word_font())
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", fill)
	l.add_theme_color_override("font_outline_color", Brand.INK)
	l.add_theme_constant_override("outline_size", maxi(10, int(px * 0.20)))
	l.add_theme_color_override("font_shadow_color", Color(Brand.MAGENTA, 0.78))
	l.add_theme_constant_override("shadow_offset_x", int(4.0 * s))
	l.add_theme_constant_override("shadow_offset_y", int(7.0 * s))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _battle_row(s: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(-18.0 * s))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(96.0 * s, 8.0 * s)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pad)
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
	if not lively:
		return
	_t += delta
	if _sail:
		_sail.rotation = sin(_t * 2.2) * 0.07
	if _badge:
		var pulse := 1.0 + 0.08 * sin(_t * 5.2)
		_badge.scale = Vector2(pulse, pulse)
		_badge.rotation = -0.22 + sin(_t * 3.4) * 0.06
