extends Control

## Drawn kite sail — diamond, spars, bows. No word on the cloth.

const Brand := preload("res://scripts/brand.gd")

var mark_scale: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	var s := mark_scale
	custom_minimum_size = Vector2(200.0 * s, 300.0 * s)
	size = custom_minimum_size
	pivot_offset = _sail_center()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = _sail_center()
		queue_redraw()


func _sail_center() -> Vector2:
	return Vector2(size.x * 0.50, size.y * 0.30)


func _ink() -> Color:
	return Color(Brand.INK.r, Brand.INK.g, Brand.INK.b, 1.0)


func _draw() -> void:
	var s := mark_scale
	var c := _sail_center()
	var hw := 72.0 * s
	var hh := 80.0 * s
	var ink := _ink()
	draw_colored_polygon(_diamond(c, hw + 6.0 * s, hh + 6.0 * s), ink)
	var gap := 4.0 * s
	var top_i := c + Vector2(0.0, -hh + gap)
	var right_i := c + Vector2(hw - gap, 0.0)
	var bot_i := c + Vector2(0.0, hh - gap)
	var left_i := c + Vector2(-hw + gap, 0.0)
	draw_colored_polygon(PackedVector2Array([top_i, right_i, c]), Brand.GOLD)
	draw_colored_polygon(PackedVector2Array([right_i, bot_i, c]), Brand.SAFFRON)
	draw_colored_polygon(PackedVector2Array([bot_i, left_i, c]), Brand.MAGENTA)
	draw_colored_polygon(PackedVector2Array([left_i, top_i, c]), Brand.CREAM)
	draw_line(top_i, bot_i, ink, 3.2 * s, true)
	draw_line(left_i, right_i, ink, 3.2 * s, true)
	var rim := _diamond(c, hw, hh)
	rim.append(rim[0])
	draw_polyline(rim, ink, 5.2 * s, true)
	_draw_tail(c + Vector2(0.0, hh), s)


func _diamond(c: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(0.0, -hh),
		c + Vector2(hw, 0.0),
		c + Vector2(0.0, hh),
		c + Vector2(-hw, 0.0),
	])


func _draw_tail(from: Vector2, s: float) -> void:
	var ink := _ink()
	var pts := PackedVector2Array()
	var n := 8
	for i in n:
		var t := float(i) / float(n - 1)
		var p := from + Vector2(
			sin(t * 2.6) * 16.0 * s,
			(10.0 + t * 92.0) * s
		)
		pts.append(p)
	draw_polyline(pts, ink, 4.4 * s, true)
	draw_polyline(pts, Brand.GOLD, 2.4 * s, true)
	for i in range(1, pts.size() - 1):
		if i % 2 == 0:
			continue
		_draw_bow(pts[i], s, Brand.GOLD if i % 4 == 1 else Brand.SAFFRON)


func _draw_bow(p: Vector2, s: float, fill: Color) -> void:
	var hw := 11.0 * s
	var hh := 8.0 * s
	var ink := _ink()
	draw_colored_polygon(_diamond(p, hw + 1.6 * s, hh + 1.6 * s), ink)
	draw_colored_polygon(_diamond(p, hw, hh), fill)
