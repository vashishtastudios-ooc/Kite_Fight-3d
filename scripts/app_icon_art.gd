extends Control

## The app icon: one saffron patang with its tail and string, high in a dusk
## gradient with the sun low behind the hills. Nothing else, so it reads at
## 48 px beside busy neighbours. Draws to its own size; mood 0 is the pink
## Pahadi dusk, 1 the violet Tukkal night.

@export var mood: int = 0
## Off for the boot splash, where the wordmark carries its own kite.
@export var show_kite: bool = true

const SAFFRON := Color(1.0, 0.56, 0.22)
const CREAM := Color(1.0, 0.95, 0.86)


func _ready() -> void:
	clip_contents = true


func _draw() -> void:
	var w := size.x
	var h := size.y
	var top := Color(0.36, 0.22, 0.40) if mood == 0 else Color(0.10, 0.06, 0.22)
	var mid := Color(0.86, 0.52, 0.52) if mood == 0 else Color(0.44, 0.20, 0.50)
	var low := Color(1.0, 0.80, 0.62) if mood == 0 else Color(0.96, 0.56, 0.66)
	## Sky: a smooth three-stop vertical gradient.
	var ys := [0.0, h * 0.6, h]
	var cs := [top, mid, low]
	for i in 2:
		draw_polygon(PackedVector2Array([Vector2(0, ys[i]), Vector2(w, ys[i]), Vector2(w, ys[i + 1]), Vector2(0, ys[i + 1])]),
			PackedColorArray([cs[i], cs[i], cs[i + 1], cs[i + 1]]))
	## Sun (or moon) low on the horizon, with a soft halo.
	var sun := Vector2(w * 0.34, h * 0.80)
	for r in range(40, 0, -1):
		draw_circle(sun, w * 0.0075 * float(r), Color(low.lightened(0.3), 0.012))
	draw_circle(sun, w * 0.075, Color(1.0, 0.94, 0.84) if mood == 0 else Color(1.0, 0.92, 0.95))
	## Two layers of hills.
	_hills(h * 0.80, h * 0.06, 3.0, 0.4, Color(mid.darkened(0.25), 1.0), w, h)
	_hills(h * 0.88, h * 0.05, 2.2, 1.7, Color(top.darkened(0.35), 1.0), w, h)
	if not show_kite:
		return
	## The string from off the bottom edge up to the kite.
	var k := Vector2(w * 0.62, h * 0.34)
	var hand := Vector2(w * 0.18, h * 1.02)
	var ctrl := Vector2(w * 0.58, h * 0.86)
	var pts := PackedVector2Array()
	for i in 33:
		var u := float(i) / 32.0
		pts.append(hand.lerp(ctrl, u).lerp(ctrl.lerp(k + Vector2(0, w * 0.13), u), u))
	draw_polyline(pts, Color(CREAM, 0.8), maxf(1.5, w * 0.006), true)
	_kite(k, w * 0.15, 0.18)


func _hills(base: float, amp: float, freq: float, phase: float, col: Color, w: float, h: float) -> void:
	var pts := PackedVector2Array([Vector2(0.0, h)])
	for i in 41:
		var x := w * float(i) / 40.0
		var u := float(i) / 40.0
		## Long soft swells with a gentle second harmonic: hills, not teeth.
		pts.append(Vector2(x, base - amp * (0.55 + 0.45 * sin(u * TAU * freq * 0.5 + phase)) - amp * 0.25 * sin(u * TAU * freq * 1.3 + phase * 2.0)))
	pts.append(Vector2(w, h))
	draw_colored_polygon(pts, col)


func _kite(c: Vector2, hh: float, tilt: float) -> void:
	var rot := Transform2D(tilt, c)
	var kw := hh * 0.82
	var poly := PackedVector2Array()
	for p in [Vector2(0, -hh), Vector2(kw, -hh * 0.12), Vector2(0, hh), Vector2(-kw, -hh * 0.12)]:
		poly.append(rot * p)
	draw_circle(c, hh * 1.6, Color(SAFFRON, 0.10))
	draw_colored_polygon(poly, SAFFRON)
	## A deeper half so the paper reads as folded.
	draw_colored_polygon(PackedVector2Array([rot * Vector2(0, -hh), rot * Vector2(kw, -hh * 0.12), rot * Vector2(0, hh)]), SAFFRON.darkened(0.14))
	var ink := Color(0.25, 0.08, 0.06, 0.6)
	var bow := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0
		bow.append(rot * Vector2(lerpf(-kw, kw, u), -hh * 0.12 - sin(u * PI) * hh * 0.28))
	draw_polyline(bow, ink, maxf(1.0, hh * 0.03), true)
	draw_line(rot * Vector2(0, -hh), rot * Vector2(0, hh), ink, maxf(1.0, hh * 0.03), true)
	for i in 3:
		var ty := hh * (1.2 + 0.36 * float(i))
		var sway := sin(float(i) * 1.3) * hh * 0.1
		draw_colored_polygon(PackedVector2Array([rot * Vector2(sway, ty - hh * 0.12), rot * Vector2(sway + hh * 0.17, ty + hh * 0.13), rot * Vector2(sway - hh * 0.17, ty + hh * 0.13)]), SAFFRON if i % 2 == 0 else CREAM)
