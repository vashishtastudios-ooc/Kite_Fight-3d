extends "res://scripts/build_kit.gd"

## Built pieces for Pahadi Sham, drawn in code in the map's flat-shaded style:
## the monastery (battered stone base, gompa, gilded shrine, chorten, prayer
## wheels, incense), the rival's hermitage, a rope bridge between the two
## hills, a hillside village with lamp-lit windows, and eagles over the valley.

const LUNGTA := [Color(0.18, 0.36, 0.78), Color(0.95, 0.94, 0.90), Color(0.80, 0.16, 0.14), Color(0.20, 0.60, 0.28), Color(0.96, 0.78, 0.18)]

## A Tibetan window on a wall facing `normal`: black trapezoid frame wider at
## the foot, a red lintel, and a lamp-lit pane.
func window(center: Vector3, normal: Vector3, w: float, h: float, lit: bool, parent: Node3D = null) -> void:
	var yaw := atan2(normal.x, normal.z)
	var holder := Node3D.new()
	(parent if parent else root).add_child(holder)
	holder.position = center
	holder.rotation.y = yaw
	## Frame: a flat black trapezoid standing proud of the wall.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fb := w * 0.78
	var ft := w * 0.58
	var hh := h * 0.62
	for tri in [[Vector3(-fb, -hh, 0), Vector3(fb, -hh, 0), Vector3(ft, hh, 0)], [Vector3(-fb, -hh, 0), Vector3(ft, hh, 0), Vector3(-ft, hh, 0)]]:
		for vv in tri:
			st.add_vertex(vv)
	st.generate_normals()
	var tr := MeshInstance3D.new()
	tr.mesh = st.commit()
	var ink := mat(INK).duplicate() as StandardMaterial3D
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	tr.material_override = ink
	holder.add_child(tr)
	tr.position = Vector3(0.0, 0.0, 0.03)
	box(Vector3(w, h, 0.05), Vector3(0.0, -0.02, 0.06), mat(LAMP, 2.2) if lit else mat(Color(0.12, 0.09, 0.1)), 0.0, holder)
	box(Vector3(w * 1.4, 0.16, 0.14), Vector3(0.0, h * 0.62 + 0.1, 0.08), mat(RED), 0.0, holder)
	## Mullion.
	box(Vector3(0.05, h, 0.07), Vector3(0.0, 0.0, 0.08), mat(RED), 0.0, holder)


# ── Monastery ────────────────────────────────────────────────────────────────

## Battered stone base under a flat compound (rect in x/z), running `drop`
## metres down into the hill and flaring out as it goes.
func compound_base(rect: Rect2, top_y: float, drop: float, flare: float) -> void:
	var m := wall_mat(top_y)
	var c := rect.get_center()
	var size := rect.size
	var base := frustum(size + Vector2(flare, flare) * 2.0, size, drop, Vector3(c.x, top_y - drop, c.y), m)
	base.name = "CompoundBase"
	## Whitewashed coping stone around the rim.
	var cap := wall_mat(top_y + 2.0)
	box(Vector3(size.x + 0.3, 0.35, 0.5), Vector3(c.x, top_y + 0.17, rect.position.y), cap)
	box(Vector3(size.x + 0.3, 0.35, 0.5), Vector3(c.x, top_y + 0.17, rect.end.y), cap)
	box(Vector3(0.5, 0.35, size.y + 0.3), Vector3(rect.position.x, top_y + 0.17, c.y), cap)
	box(Vector3(0.5, 0.35, size.y + 0.3), Vector3(rect.end.x, top_y + 0.17, c.y), cap)


## The gompa: faces -Z (toward the terrace and the valley).
func gompa(front_center: Vector3) -> Node3D:
	var g := Node3D.new()
	g.name = "Gompa"
	root.add_child(g)
	g.position = front_center
	var W := 13.0
	var D := 9.0
	var H := 6.4
	var white := wall_mat(front_center.y + H + 3.0)
	## Plinth and battered hall.
	frustum(Vector2(W + 1.0, D + 1.0), Vector2(W + 0.6, D + 0.6), 0.7, Vector3(0.0, 0.0, D * 0.5), mat(SLATE), g)
	frustum(Vector2(W, D), Vector2(W - 0.9, D - 0.7), H, Vector3(0.0, 0.7, D * 0.5), white, g)
	## Maroon penbey frieze, white cornice, flat roof with parapet.
	var top := 0.7 + H
	box(Vector3(W - 0.8, 1.15, D - 0.6), Vector3(0.0, top + 0.57, D * 0.5), mat(MAROON), 0.0, g)
	for i in 14:
		var x := lerpf(-W * 0.44, W * 0.44, float(i) / 13.0)
		sphere(0.14, 0.2, Vector3(x, top + 0.6, 0.3 + 0.02), mat(GOLD, 0.2), g)
	box(Vector3(W - 0.4, 0.28, D - 0.2), Vector3(0.0, top + 1.29, D * 0.5), mat(WHITE), 0.0, g)
	box(Vector3(W - 0.6, 0.12, D - 0.4), Vector3(0.0, top + 1.49, D * 0.5), mat(SLATE), 0.0, g)
	## Front windows (two storeys) and side windows, some lamp-lit.
	var fz := -0.02
	for row in 2:
		var y := 0.7 + 1.9 + float(row) * 2.35
		for col in 4:
			var x := lerpf(-4.6, 4.6, float(col) / 3.0)
			if row == 0 and absf(x) < 2.0:
				continue
			window(Vector3(x * (1.0 - float(row) * 0.03), y, fz + 0.12 + float(row) * 0.08), Vector3(0, 0, -1), 0.8, 1.1, (col + row) % 2 == 0, g)
	for side in [-1.0, 1.0]:
		for k in 2:
			window(Vector3(side * (W * 0.5 - 0.3 - 0.2), 3.6, 2.5 + float(k) * 4.0), Vector3(side, 0, 0), 0.7, 1.0, k == 0, g)
	## Main door: red, gold studs, deep black trapezoid surround, striped canopy.
	box(Vector3(3.0, 3.6, 0.1), Vector3(0.0, 0.7 + 1.8, 0.02), mat(INK), 0.0, g)
	box(Vector3(2.2, 3.0, 0.14), Vector3(0.0, 0.7 + 1.5, -0.02), mat(RED), 0.0, g)
	for sx in [-0.5, 0.5]:
		for sy in 4:
			sphere(0.06, 0.08, Vector3(sx, 0.7 + 0.7 + float(sy) * 0.6, -0.1), mat(GOLD, 0.3), g)
	var stripes := [Color(0.95, 0.78, 0.18), Color(0.18, 0.36, 0.78), Color(0.80, 0.16, 0.14), Color(0.20, 0.60, 0.28), Color(0.95, 0.94, 0.9)]
	for i in 5:
		box(Vector3(3.6, 0.14, 0.9), Vector3(0.0, 0.7 + 3.9 + float(i) * 0.02 - float(i) * 0.16, -0.5 - float(i) * 0.02), mat(stripes[i]), 0.0, g)
	## Steps down to the courtyard.
	for s in 3:
		box(Vector3(4.4 - float(s) * 0.4, 0.23, 0.6), Vector3(0.0, 0.7 - 0.23 * float(s) - 0.12, -0.3 - 0.6 * float(s)), mat(SLATE), 0.0, g)
	## Prayer wheels under a little roof along the front, either side of the door.
	for side in [-1.0, 1.0]:
		box(Vector3(3.6, 0.12, 0.9), Vector3(side * 4.4, 0.7 + 2.35, -0.45), mat(MAROON), 0.0, g)
		for k in 5:
			var wx: float = side * (2.9 + float(k) * 0.72)
			cyl(0.22, 0.22, 0.6, Vector3(wx, 0.7 + 1.1, -0.45), mat(RED), 10, g)
			cyl(0.23, 0.23, 0.1, Vector3(wx, 0.7 + 1.35, -0.45), mat(GOLD, 0.2), 10, g)
	## Gilded shrine on the roof: small white room, maroon band, golden hip roof.
	var sy0 := top + 1.55
	frustum(Vector2(5.2, 4.4), Vector2(4.9, 4.1), 2.3, Vector3(0.0, sy0, D * 0.5 + 0.8), white, g)
	box(Vector3(4.9, 0.6, 4.1), Vector3(0.0, sy0 + 2.6, D * 0.5 + 0.8), mat(MAROON), 0.0, g)
	window(Vector3(0.0, sy0 + 1.2, D * 0.5 + 0.8 - 2.1), Vector3(0, 0, -1), 0.7, 0.9, true, g)
	hip_roof(6.6, 5.8, 2.1, 2.4, Vector3(0.0, sy0 + 2.9, D * 0.5 + 0.8), mat(GOLD, 0.35), g)
	## Upturned eave tips at the four corners, and a gilt ridge.
	for ex in [-1.0, 1.0]:
		for ez in [-1.0, 1.0]:
			var tip := frustum(Vector2(0.5, 0.5), Vector2(0.08, 0.08), 0.75, Vector3(ex * 3.25, sy0 + 2.85, D * 0.5 + 0.8 + ez * 2.85), mat(GOLD, 0.4), g)
			tip.rotation = Vector3(ez * 0.5, 0.0, -ex * 0.5)
	box(Vector3(2.6, 0.18, 0.18), Vector3(0.0, sy0 + 5.05, D * 0.5 + 0.8), mat(GOLD, 0.5), 0.0, g)
	cyl(0.08, 0.2, 0.7, Vector3(0.0, sy0 + 5.35, D * 0.5 + 0.8), mat(GOLD, 0.5), 8, g)
	sphere(0.22, 0.3, Vector3(0.0, sy0 + 5.8, D * 0.5 + 0.8), mat(GOLD, 0.6), g)
	## Victory banners (gyaltsen) at the roof corners.
	for cx in [-1.0, 1.0]:
		for cz in [0.0, 1.0]:
			var p := Vector3(cx * (W * 0.5 - 1.0), top + 1.55, lerpf(0.8, D - 0.8, cz))
			cyl(0.34, 0.26, 1.3, p + Vector3(0, 0.65, 0), mat(GOLD, 0.3), 10, g)
			cyl(0.36, 0.36, 0.14, p + Vector3(0, 0.9, 0), mat(INK), 10, g)
			sphere(0.14, 0.24, p + Vector3(0, 1.42, 0), mat(GOLD, 0.5), g)
	## Dharma wheel with two deer above the door, facing the valley.
	var wheel_at := Vector3(0.0, top + 2.25, 0.9)
	var wheel := cyl(0.62, 0.62, 0.12, wheel_at, mat(GOLD, 0.45), 16, g)
	wheel.rotation.x = PI * 0.5
	for dx in [-1.0, 1.0]:
		box(Vector3(0.55, 0.42, 0.3), wheel_at + Vector3(dx * 1.05, -0.5, 0.0), mat(GOLD, 0.35), 0.0, g)
		box(Vector3(0.14, 0.34, 0.14), wheel_at + Vector3(dx * 0.85, -0.1, 0.0), mat(GOLD, 0.35), 0.0, g)
	return g


## Chorten (stupa): stepped throne, dome, harmika, 13 rings, sun and moon.
func chorten(base: Vector3, s: float = 1.0) -> Node3D:
	var c := Node3D.new()
	c.name = "Chorten"
	root.add_child(c)
	c.position = base
	var white := mat(WHITE)
	var y := 0.0
	for tier in [[3.0, 0.55], [2.6, 0.45], [2.2, 0.4], [1.85, 0.35]]:
		box(Vector3(tier[0], tier[1], tier[0]) * s, Vector3(0.0, (y + tier[1] * 0.5) * s, 0.0), white, 0.0, c)
		y += tier[1]
	cyl(0.95, 1.05, 0.25, Vector3(0.0, (y + 0.12) * s, 0.0), white, 16, c)
	y += 0.25
	sphere(0.95 * s, 1.55 * s, Vector3(0.0, (y + 0.55) * s, 0.0), white, c)
	y += 1.2
	box(Vector3(0.75, 0.45, 0.75) * s, Vector3(0.0, (y + 0.22) * s, 0.0), white, 0.0, c)
	box(Vector3(0.78, 0.12, 0.78) * s, Vector3(0.0, (y + 0.1) * s, 0.0), mat(MAROON), 0.0, c)
	y += 0.45
	for r in 13:
		var rr := lerpf(0.34, 0.12, float(r) / 12.0)
		cyl(rr * s, rr * 0.92 * s, 0.14 * s, Vector3(0.0, (y + 0.07 + float(r) * 0.14) * s, 0.0), mat(GOLD, 0.25), 10, c)
	y += 13.0 * 0.14
	cyl(0.34 * s, 0.34 * s, 0.05 * s, Vector3(0.0, (y + 0.05) * s, 0.0), mat(GOLD, 0.4), 12, c)
	sphere(0.16 * s, 0.22 * s, Vector3(0.0, (y + 0.24) * s, 0.0), mat(GOLD, 0.6), c)
	return c


## The rival's hermitage: a small whitewashed hut on a battered stone base.
func hermitage(center: Vector3, radius: float, drop: float) -> void:
	var m := wall_mat(center.y)
	frustum(Vector2(radius * 2.0 + 3.0, radius * 2.0 + 3.0), Vector2(radius * 2.0, radius * 2.0), drop, Vector3(center.x, center.y - drop, center.z), m)
	var hut := Node3D.new()
	hut.name = "Hermitage"
	root.add_child(hut)
	hut.position = center + Vector3(-1.2, 0.0, 2.6)
	frustum(Vector2(4.2, 3.4), Vector2(3.8, 3.1), 2.8, Vector3.ZERO, wall_mat(center.y + 4.0), hut)
	box(Vector3(3.9, 0.45, 3.2), Vector3(0.0, 3.0, 0.0), mat(MAROON), 0.0, hut)
	box(Vector3(4.2, 0.18, 3.5), Vector3(0.0, 3.3, 0.0), mat(SLATE), 0.0, hut)
	## Stacked firewood on the roof edge, a lit window, a door.
	box(Vector3(3.2, 0.35, 0.5), Vector3(0.0, 3.55, 1.3), mat(WOOD), 0.0, hut)
	window(Vector3(0.9, 1.6, -1.62), Vector3(0, 0, -1), 0.55, 0.75, true, hut)
	box(Vector3(0.9, 1.8, 0.1), Vector3(-0.8, 0.9, -1.6), mat(RED), 0.0, hut)
	## Prayer-flag mast.
	cyl(0.06, 0.08, 6.0, center + Vector3(radius - 1.2, 3.0, -radius + 1.2), mat(WOOD), 6)


# ── Rope bridge ──────────────────────────────────────────────────────────────

func rope_bridge(a: Vector3, b: Vector3, sag: float) -> Array:
	var bridge := Node3D.new()
	bridge.name = "RopeBridge"
	root.add_child(bridge)
	var n := int(a.distance_to(b) / 0.55)
	var along := (b - a)
	var flat := Vector3(along.x, 0.0, along.z).normalized()
	var side := flat.cross(Vector3.UP).normalized()
	var yaw := atan2(flat.x, flat.z)
	var plank := mat(WOOD)
	var rope := mat(Color(0.30, 0.22, 0.16))
	var rails := [[], []]
	for i in n + 1:
		var t := float(i) / float(n)
		var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		if i < n:
			var tilt := (i * 7) % 3
			var pl := box(Vector3(1.4, 0.07, 0.4), p, plank, yaw + PI * 0.5 + float(tilt - 1) * 0.04, bridge)
			pl.rotation.z = float(tilt - 1) * 0.03
		for k in 2:
			var sgn := -1.0 if k == 0 else 1.0
			(rails[k] as Array).append(p + side * sgn * 0.75 + Vector3.UP * (1.0 - 0.5 * 4.0 * t * (1.0 - t) * 0.3))
	## Handrail ropes, and the vertical hangers down to the deck.
	for rail in rails:
		for i in (rail as Array).size() - 1:
			_rope(rail[i], rail[i + 1], 0.03, rope, bridge)
			if i % 3 == 0:
				_rope(rail[i], rail[i] + Vector3.DOWN * 0.95, 0.015, rope, bridge)
	## End posts.
	for end in [a, b]:
		for k in 2:
			var sgn := -1.0 if k == 0 else 1.0
			cyl(0.1, 0.12, 1.8, end + side * sgn * 0.8 + Vector3.UP * 0.6, plank, 6, bridge)
	return rails


func _rope(p0: Vector3, p1: Vector3, r: float, m: Material, parent: Node3D) -> void:
	var d := p1 - p0
	var l := d.length()
	if l < 0.01:
		return
	var mi := cyl(r, r, l, (p0 + p1) * 0.5, m, 4, parent)
	var up := d / l
	var x := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(up).normalized()
	mi.basis = Basis(x, up, z)


# ── Village ──────────────────────────────────────────────────────────────────

## A flat-roofed hill house, facing `yaw`, with firewood on the roof edge and
## a lamp-lit window or two.
func village_house(feet: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var h := Node3D.new()
	h.name = "House"
	h.add_to_group("village_house")
	root.add_child(h)
	h.position = feet
	h.rotation.y = yaw
	var w := rng.randf_range(4.2, 6.5)
	var d := rng.randf_range(3.6, 5.0)
	var tall := rng.randf_range(2.8, 4.6)
	## Stone footing into the slope, whitewashed walls, maroon band, flat roof.
	## Deep enough to reach the ground on the downhill side of a steep slope.
	frustum(Vector2(w + 2.4, d + 2.4), Vector2(w, d), 8.0, Vector3(0.0, -8.0, 0.0), wall_mat(feet.y), h)
	frustum(Vector2(w, d), Vector2(w - 0.3, d - 0.25), tall, Vector3.ZERO, wall_mat(feet.y + tall + 2.0), h)
	box(Vector3(w - 0.2, 0.4, d - 0.15), Vector3(0.0, tall + 0.2, 0.0), mat(MAROON), 0.0, h)
	box(Vector3(w + 0.1, 0.15, d + 0.2), Vector3(0.0, tall + 0.47, 0.0), mat(SLATE), 0.0, h)
	box(Vector3(w * 0.8, 0.35, 0.5), Vector3(0.0, tall + 0.7, d * 0.4), mat(WOOD), 0.0, h)
	var lit := rng.randf() < 0.65
	window(Vector3(-w * 0.2, tall * 0.55, -d * 0.5 - 0.02), Vector3(0, 0, -1), 0.6, 0.8, lit, h)
	if w > 5.0:
		window(Vector3(w * 0.25, tall * 0.55, -d * 0.5 - 0.02), Vector3(0, 0, -1), 0.6, 0.8, rng.randf() < 0.4, h)
	box(Vector3(0.9, 1.9, 0.08), Vector3(w * 0.3 if w <= 5.0 else -w * 0.38, 0.95, -d * 0.5 - 0.04), mat(RED), 0.0, h)
	## A little flag on a stick on some roofs.
	if rng.randf() < 0.5:
		cyl(0.03, 0.03, 2.2, Vector3(w * 0.4, tall + 1.5, d * 0.35), mat(WOOD), 5, h)
		box(Vector3(0.6, 0.4, 0.02), Vector3(w * 0.4 + 0.3, tall + 2.3, d * 0.35), mat(LUNGTA[rng.randi() % LUNGTA.size()]), 0.0, h)


# ── Eagles ───────────────────────────────────────────────────────────────────

func eagle_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	## Body along -Z (forward), wings spread on X with a slight dihedral.
	var tris := [
		[Vector3(0, 0, -0.9), Vector3(0.25, 0, 0.2), Vector3(-0.25, 0, 0.2)],
		[Vector3(-0.25, 0, 0.2), Vector3(0.25, 0, 0.2), Vector3(0, 0, 0.9)],
		[Vector3(0.1, 0, -0.35), Vector3(2.1, 0.25, 0.05), Vector3(0.15, 0, 0.3)],
		[Vector3(2.1, 0.25, 0.05), Vector3(2.4, 0.3, 0.35), Vector3(0.15, 0, 0.3)],
		[Vector3(-0.1, 0, -0.35), Vector3(-0.15, 0, 0.3), Vector3(-2.1, 0.25, 0.05)],
		[Vector3(-2.1, 0.25, 0.05), Vector3(-0.15, 0, 0.3), Vector3(-2.4, 0.3, 0.35)],
	]
	for t in tris:
		for v in t:
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.11, 0.12)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mesh.surface_set_material(0, m)
	return mesh
