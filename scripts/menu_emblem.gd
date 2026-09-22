extends Control

## Small animated illustration for a mode card, drawn in code so it matches
## the game's kites: the curved kaman, two-tone paper, a thread for a string.
##   save   — a kite sidestepping a rocket that streaks past.
##   battle — two kites whose strings cross, glass sparks at the crossing.
##   online — two far-apart kites with a signal pulse running between them.
## Hovering the card speeds it up.

var kind: String = "battle"
var cols: Array = [Color(0.38, 0.62, 0.95), Color(0.95, 0.82, 0.28), Color(0.92, 0.28, 0.48)]
var hot: bool = false

const INK := Color(0.14, 0.07, 0.06)
const BAMBOO := Color(0.86, 0.68, 0.40)
const THREAD := Color(1.0, 0.94, 0.84, 0.75)

var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = randf() * 10.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta * (1.8 if hot else 1.0)
	queue_redraw()


func _draw() -> void:
	match kind:
		"save":
			_draw_save()
		"online":
			_draw_online()
		_:
			_draw_battle()


func _draw_battle() -> void:
	var s := size
	var bob_a := sin(_t * 1.7) * 3.0
	var bob_b := sin(_t * 1.5 + 1.3) * 3.0
	var ka := Vector2(s.x * 0.3, s.y * 0.32 + bob_a)
	var kb := Vector2(s.x * 0.7, s.y * 0.30 + bob_b)
	var ha := Vector2(s.x * 0.86, s.y * 1.02)
	var hb := Vector2(s.x * 0.14, s.y * 1.02)
	## Strings first, so the kites sit on top.
	var a0 := ka + Vector2(0.0, 8.0)
	var b0 := kb + Vector2(0.0, 8.0)
	_thread(a0, ha)
	_thread(b0, hb)
	var x := _cross(a0, ha, b0, hb)
	_kite(ka, 17.0, -0.28 + sin(_t * 1.1) * 0.08, cols[0], cols[1])
	_kite(kb, 17.0, 0.3 + sin(_t * 1.3) * 0.08, cols[2], cols[1])
	## Sparks where the strings rub.
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	for i in 7:
		var ang := TAU * float(i) / 7.0 + _t * 2.2
		var r0 := 3.0
		var r1 := 7.0 + 6.0 * pulse * (0.6 + 0.4 * sin(float(i) * 2.3 + _t * 5.0))
		var d := Vector2(cos(ang), sin(ang))
		draw_line(x + d * r0, x + d * r1, Color(1.0, 0.86, 0.45, 0.9), 1.6, true)
	draw_circle(x, 3.2 + pulse * 1.6, Color(1.0, 0.97, 0.85))


func _draw_save() -> void:
	var s := size
	var u := fmod(_t * 0.45, 1.0)
	## Rocket path: up from lower left, curving past the kite's right side.
	var p0 := Vector2(s.x * 0.1, s.y * 1.05)
	var p1 := Vector2(s.x * 0.62, s.y * 0.95)
	var p2 := Vector2(s.x * 0.95, s.y * -0.05)
	var near := 1.0 - clampf(absf(u - 0.55) / 0.25, 0.0, 1.0)
	## The kite sidesteps as the rocket passes.
	var kite_at := Vector2(s.x * 0.5 - near * 16.0, s.y * 0.38 + sin(_t * 1.6) * 3.0)
	_thread(kite_at + Vector2(0.0, 8.0), Vector2(s.x * 0.38, s.y * 1.05))
	_kite(kite_at, 18.0, -near * 0.45 + sin(_t * 1.2) * 0.07, cols[0], cols[1])
	## Smoke trail, fading behind the rocket.
	var prev := _bez(p0, p1, p2, maxf(u - 0.35, 0.0))
	for i in range(1, 12):
		var v := lerpf(maxf(u - 0.35, 0.0), u, float(i) / 11.0)
		var p := _bez(p0, p1, p2, v)
		var a := float(i) / 11.0
		draw_line(prev, p, Color(1.0, 0.9, 0.75, 0.55 * a), 1.0 + 2.5 * a, true)
		prev = p
	var head := _bez(p0, p1, p2, u)
	var dir := (_bez(p0, p1, p2, minf(u + 0.02, 1.0)) - head).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(0.6, -0.8)
	var side := Vector2(-dir.y, dir.x)
	## Flame, then the body.
	var flick := 0.8 + 0.4 * sin(_t * 30.0)
	draw_colored_polygon(PackedVector2Array([head - dir * 4.0 + side * 3.0, head - dir * (12.0 * flick), head - dir * 4.0 - side * 3.0]), Color(1.0, 0.55, 0.15))
	draw_colored_polygon(PackedVector2Array([head + dir * 7.0, head + side * 3.2, head - dir * 5.0 + side * 3.2, head - dir * 5.0 - side * 3.2, head - side * 3.2]), cols[2])
	draw_polyline(PackedVector2Array([head + dir * 7.0, head + side * 3.2, head - dir * 5.0 + side * 3.2, head - dir * 5.0 - side * 3.2, head - side * 3.2, head + dir * 7.0]), INK, 1.2, true)


func _draw_online() -> void:
	var s := size
	var ka := Vector2(s.x * 0.18, s.y * 0.40 + sin(_t * 1.6) * 3.0)
	var kb := Vector2(s.x * 0.82, s.y * 0.36 + sin(_t * 1.4 + 1.0) * 3.0)
	_thread(ka + Vector2(0.0, 8.0), Vector2(s.x * 0.12, s.y * 1.05))
	_thread(kb + Vector2(0.0, 8.0), Vector2(s.x * 0.9, s.y * 1.05))
	## An arc of dots between them with a bright pulse riding it each way.
	var mid := Vector2(s.x * 0.5, s.y * 0.02)
	for i in 17:
		var v := float(i) / 16.0
		var p := _bez(ka, mid, kb, v)
		draw_circle(p, 1.3, Color(1.0, 0.94, 0.84, 0.35))
	for dirn in [0.0, 1.0]:
		var v := fmod(_t * 0.55 + dirn * 0.5, 1.0)
		if dirn > 0.5:
			v = 1.0 - v
		var p := _bez(ka, mid, kb, v)
		draw_circle(p, 5.5, Color(cols[0].r, cols[0].g, cols[0].b, 0.25))
		draw_circle(p, 3.0, Color(1.0, 0.97, 0.88))
	## Signal rings off each kite.
	for k in [ka, kb]:
		for r in 2:
			var ph := fmod(_t * 0.9 + float(r) * 0.5, 1.0)
			draw_arc(k + Vector2(0.0, -4.0), 14.0 + ph * 16.0, -PI * 0.85, -PI * 0.15, 16, Color(1.0, 0.9, 0.7, 0.45 * (1.0 - ph)), 1.5, true)
	_kite(ka, 16.0, -0.2 + sin(_t * 1.1) * 0.08, cols[0], cols[1])
	_kite(kb, 16.0, 0.22 + sin(_t * 1.3) * 0.08, cols[2], cols[1])


## A patang, nose up: two-tone paper, ink edge, spine and arched kaman.
func _kite(c: Vector2, r: float, tilt: float, paper: Color, accent: Color) -> void:
	var rot := Transform2D(tilt, c)
	var nose := rot * Vector2(0.0, -r * 1.1)
	var right := rot * Vector2(r * 0.82, 0.0)
	var tail := rot * Vector2(0.0, r * 0.95)
	var left := rot * Vector2(-r * 0.82, 0.0)
	var mid := rot * Vector2(0.0, 0.0)
	draw_colored_polygon(PackedVector2Array([nose, right, tail, mid]), paper)
	draw_colored_polygon(PackedVector2Array([nose, mid, tail, left]), accent)
	draw_polyline(PackedVector2Array([nose, right, tail, left, nose]), INK, 1.6, true)
	draw_line(nose, tail, BAMBOO.darkened(0.25), 1.4, true)
	var bow := PackedVector2Array()
	for i in 9:
		var t := lerpf(-1.0, 1.0, float(i) / 8.0)
		bow.append(rot * Vector2(t * r * 0.8, -r * 0.42 * (1.0 - t * t)))
	draw_polyline(bow, BAMBOO, 1.8, true)
	## Tail ribbon.
	var tl := tail
	for i in 3:
		var nxt := tail + Vector2(sin(_t * 4.0 + float(i)) * 2.5, float(i + 1) * 5.0)
		draw_line(tl, nxt, accent.lightened(0.2), 1.6, true)
		tl = nxt


func _thread(a: Vector2, b: Vector2) -> void:
	var sag := Vector2(0.0, a.distance_to(b) * 0.06)
	var m := (a + b) * 0.5 + sag
	var prev := a
	for i in range(1, 11):
		var p := _bez(a, m, b, float(i) / 10.0)
		draw_line(prev, p, THREAD, 1.1, true)
		prev = p


func _bez(a: Vector2, m: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(m, t).lerp(m.lerp(b, t), t)


## Where two straight strings cross (falls back to the midpoint).
func _cross(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2) -> Vector2:
	var r := a1 - a0
	var q := b1 - b0
	var den := r.x * q.y - r.y * q.x
	if absf(den) < 0.001:
		return (a0 + b0) * 0.5
	var t := ((b0.x - a0.x) * q.y - (b0.y - a0.y) * q.x) / den
	return a0 + r * clampf(t, 0.0, 1.0) + Vector2(0.0, a0.distance_to(a1) * 0.06 * 2.0 * t * (1.0 - t))
