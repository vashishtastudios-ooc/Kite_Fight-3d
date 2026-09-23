extends "res://scripts/build_kit.gd"

## Built pieces for Registan: golden-sandstone havelis with carved balconies,
## the town around them, chhatri pavilions, a ruined stepwell, a fort on its
## rock, a camel train, khejri trees and dust devils.

const SAND := Color(0.88, 0.66, 0.38)
const SAND_LIT := Color(0.95, 0.76, 0.46)
const SAND_DEEP := Color(0.72, 0.50, 0.30)
const CARVE := Color(0.97, 0.84, 0.58)
const SHADE := Color(0.52, 0.34, 0.26)
const DOOR := Color(0.36, 0.20, 0.14)
const TEAL := Color(0.20, 0.52, 0.52)


# ── Haveli ───────────────────────────────────────────────────────────────────

## A merchant's house: sandstone walls from the shelf up to a flat roof, with
## arched windows, carved brackets and jutting jharokha balconies. `hero` adds
## the corner pavilions and a stair block — that is the roof you fly from.
func haveli(roof: Rect2, ground_y: float, deck_y: float, hero: bool) -> Node3D:
	var h := Node3D.new()
	h.name = "Haveli"
	root.add_child(h)
	var c := roof.get_center()
	h.position = Vector3(c.x, ground_y, c.y)
	var w := roof.size.x
	var d := roof.size.y
	var tall := deck_y - ground_y
	## Walls, a plinth, and a string course under the roof.
	frustum(Vector2(w + 1.2, d + 1.2), Vector2(w + 0.6, d + 0.6), 1.0, Vector3.ZERO, mat(SAND_DEEP), h)
	frustum(Vector2(w, d), Vector2(w - 0.5, d - 0.5), tall, Vector3(0.0, 1.0, 0.0), mat(SAND), h)
	box(Vector3(w + 0.5, 0.35, d + 0.5), Vector3(0.0, tall - 0.4, 0.0), mat(CARVE), 0.0, h)
	## Roof slab you stand on, with collision.
	var deck := box(Vector3(w + 0.8, 0.7, d + 0.8), Vector3(0.0, tall + 0.35, 0.0), mat(SAND_LIT), 0.0, h)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w + 0.8, 0.7, d + 0.8)
	cs.shape = shape
	body.add_child(cs)
	deck.add_child(body)
	## Parapet with stepped merlons round the roof.
	_parapet(h, w + 0.8, d + 0.8, tall + 0.7)
	## Arched windows on all four walls, a few lamp-lit.
	var rows := int((tall - 2.0) / 3.2)
	for row in maxi(rows, 1):
		var y := 2.2 + float(row) * 3.2
		for side in 4:
			var along := w if side % 2 == 0 else d
			var n := maxi(int(along / 4.0), 1)
			for i in n:
				var t := (float(i) + 0.5) / float(n)
				var p := Vector3.ZERO
				var nrm := Vector3.ZERO
				match side:
					0:
						p = Vector3(lerpf(-w * 0.42, w * 0.42, t), y, -d * 0.5)
						nrm = Vector3(0, 0, -1)
					1:
						p = Vector3(w * 0.5, y, lerpf(-d * 0.42, d * 0.42, t))
						nrm = Vector3(1, 0, 0)
					2:
						p = Vector3(lerpf(-w * 0.42, w * 0.42, t), y, d * 0.5)
						nrm = Vector3(0, 0, 1)
					_:
						p = Vector3(-w * 0.5, y, lerpf(-d * 0.42, d * 0.42, t))
						nrm = Vector3(-1, 0, 0)
				arch_window(p, nrm, 1.0, 1.7, (i + row + side) % 3 == 0, h)
	## Jharokha balconies on the front, one per upper window.
	if tall > 5.0:
		for i in 2:
			var x := lerpf(-w * 0.26, w * 0.26, float(i))
			jharokha(Vector3(x, tall - 3.4, -d * 0.5), Vector3(0, 0, -1), h)
	if hero:
		## Corner pavilions and the stair house up to the roof.
		for sx in [-1.0, 1.0]:
			chhatri(Vector3(c.x + sx * (w * 0.5 - 1.6), deck_y + 0.7, c.y + d * 0.5 - 1.6), 0.62)
		box(Vector3(4.0, 2.6, 3.4), Vector3(w * 0.5 - 3.0, tall + 2.0, d * 0.5 - 2.4), mat(SAND_LIT), 0.0, h)
		box(Vector3(4.4, 0.3, 3.8), Vector3(w * 0.5 - 3.0, tall + 3.4, d * 0.5 - 2.4), mat(CARVE), 0.0, h)
		arch_window(Vector3(w * 0.5 - 3.0, tall + 2.0, d * 0.5 - 4.32), Vector3(0, 0, -1), 1.0, 1.6, false, h)
	return h


func _parapet(h: Node3D, w: float, d: float, y: float) -> void:
	var m := mat(SAND_LIT)
	var cap := mat(CARVE)
	for side in 4:
		var horiz := side % 2 == 0
		var along := w if horiz else d
		var pos := Vector3.ZERO
		match side:
			0:
				pos = Vector3(0.0, y + 0.45, -d * 0.5 + 0.2)
			1:
				pos = Vector3(w * 0.5 - 0.2, y + 0.45, 0.0)
			2:
				pos = Vector3(0.0, y + 0.45, d * 0.5 - 0.2)
			_:
				pos = Vector3(-w * 0.5 + 0.2, y + 0.45, 0.0)
		var size := Vector3(along, 0.9, 0.4) if horiz else Vector3(0.4, 0.9, along)
		box(size, pos, m, 0.0, h)
		## Merlons: little stepped teeth along the top.
		var n := int(along / 1.6)
		for i in n:
			var t := (float(i) + 0.5) / float(n)
			var off := lerpf(-along * 0.46, along * 0.46, t)
			var mp := pos + (Vector3(off, 0.62, 0.0) if horiz else Vector3(0.0, 0.62, off))
			box(Vector3(0.7, 0.34, 0.42) if horiz else Vector3(0.42, 0.34, 0.7), mp, cap, 0.0, h)
			box(Vector3(0.34, 0.26, 0.42) if horiz else Vector3(0.42, 0.26, 0.34), mp + Vector3(0.0, 0.3, 0.0), cap, 0.0, h)


## A pointed Rajasthani arch window: a recessed arch, a carved surround and a
## sill, lamp-lit or dark.
func arch_window(center: Vector3, normal: Vector3, w: float, h: float, lit: bool, parent: Node3D = null) -> void:
	var holder := Node3D.new()
	(parent if parent else root).add_child(holder)
	holder.position = center
	holder.rotation.y = atan2(normal.x, normal.z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	## Arch outline: straight sides, then a cusped point.
	var pts := PackedVector2Array()
	var hw := w * 0.5
	pts.append(Vector2(-hw, -h * 0.5))
	pts.append(Vector2(hw, -h * 0.5))
	for i in 9:
		var t := float(i) / 8.0
		var a := lerpf(0.0, PI, t)
		## A pointed head rather than a half circle.
		var x := cos(a) * hw
		var y := h * 0.12 + sin(a) * h * 0.34 + (1.0 - absf(cos(a))) * h * 0.1
		pts.append(Vector2(x, y))
	var center2 := Vector2(0.0, 0.0)
	for i in pts.size():
		var p0 := pts[i]
		var p1 := pts[(i + 1) % pts.size()]
		st.add_vertex(Vector3(center2.x, center2.y, 0.0))
		st.add_vertex(Vector3(p0.x, p0.y, 0.0))
		st.add_vertex(Vector3(p1.x, p1.y, 0.0))
	st.generate_normals()
	var pane := MeshInstance3D.new()
	pane.mesh = st.commit()
	var pm := (mat(LAMP, 2.0) if lit else mat(Color(0.16, 0.10, 0.09))).duplicate() as StandardMaterial3D
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	pane.material_override = pm
	holder.add_child(pane)
	pane.position = Vector3(0.0, 0.0, -0.06)
	## Carved surround and sill.
	box(Vector3(w + 0.42, h + 0.5, 0.12), Vector3(0.0, 0.1, 0.02), mat(CARVE), 0.0, holder)
	box(Vector3(w + 0.7, 0.16, 0.3), Vector3(0.0, -h * 0.5 - 0.12, -0.08), mat(CARVE), 0.0, holder)


## Jharokha: a covered balcony jutting from the wall on carved brackets.
func jharokha(center: Vector3, normal: Vector3, parent: Node3D) -> void:
	var j := Node3D.new()
	parent.add_child(j)
	j.position = center
	j.rotation.y = atan2(normal.x, normal.z)
	## Brackets, floor, screen sides, eave and a little dome.
	for sx in [-0.8, 0.8]:
		var br := frustum(Vector2(0.3, 0.9), Vector2(0.3, 0.3), 0.8, Vector3(sx, -1.0, -0.45), mat(CARVE), j)
		br.rotation.x = 0.35
	box(Vector3(2.4, 0.22, 1.1), Vector3(0.0, -0.15, -0.52), mat(CARVE), 0.0, j)
	box(Vector3(2.2, 1.0, 0.1), Vector3(0.0, 0.4, -1.02), mat(SAND_LIT), 0.0, j)
	for sx in [-1.05, 1.05]:
		box(Vector3(0.12, 1.5, 1.0), Vector3(sx, 0.6, -0.55), mat(SAND_LIT), 0.0, j)
	box(Vector3(2.7, 0.18, 1.3), Vector3(0.0, 1.45, -0.6), mat(CARVE), 0.0, j)
	var dome := sphere(0.85, 0.7, Vector3(0.0, 1.6, -0.6), mat(SAND_LIT), j)
	dome.scale = Vector3(1.3, 1.0, 0.85)
	cyl(0.05, 0.1, 0.4, Vector3(0.0, 2.0, -0.6), mat(CARVE), 6, j)


# ── Chhatri ──────────────────────────────────────────────────────────────────

## A domed pavilion on pillars — the desert's silhouette.
func chhatri(base: Vector3, s: float = 1.0) -> Node3D:
	var c := Node3D.new()
	c.name = "Chhatri"
	root.add_child(c)
	c.position = base
	var r := 2.4 * s
	box(Vector3(r * 2.6, 0.5 * s, r * 2.6), Vector3(0.0, 0.25 * s, 0.0), mat(SAND_DEEP), 0.0, c)
	box(Vector3(r * 2.2, 0.35 * s, r * 2.2), Vector3(0.0, 0.65 * s, 0.0), mat(SAND_LIT), 0.0, c)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var p := Vector3(cos(a) * r, 0.8 * s, sin(a) * r)
		cyl(0.16 * s, 0.14 * s, 3.0 * s, p + Vector3(0.0, 1.5 * s, 0.0), mat(SAND_LIT), 8, c)
		## Bracket under the eave.
		box(Vector3(0.5 * s, 0.4 * s, 0.22 * s), p + Vector3(0.0, 2.9 * s, 0.0), mat(CARVE), a, c)
	## Eave slab (chajja), drum and dome.
	cyl(r * 1.35, r * 1.25, 0.3 * s, Vector3(0.0, 3.4 * s, 0.0), mat(CARVE), 16, c)
	cyl(r * 0.95, r * 0.95, 0.5 * s, Vector3(0.0, 3.8 * s, 0.0), mat(SAND_LIT), 16, c)
	var dome := sphere(r * 0.98, r * 1.5, Vector3(0.0, 4.4 * s, 0.0), mat(SAND_LIT), c)
	dome.scale = Vector3(1.0, 0.85, 1.0)
	cyl(0.1 * s, 0.22 * s, 0.9 * s, Vector3(0.0, 5.3 * s, 0.0), mat(CARVE), 8, c)
	sphere(0.22 * s, 0.32 * s, Vector3(0.0, 5.9 * s, 0.0), mat(CARVE), c)
	return c


# ── Town ─────────────────────────────────────────────────────────────────────

## Sandstone blocks packed around the two havelis, taller near the lane and
## lower at the edges, with flat roofs, parapets and the odd dome.
func town(area: Rect2, keep_a: Rect2, keep_b: Rect2, ground_y: float, map: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	var step := 13.0
	var x := area.position.x + 6.0
	while x < area.end.x - 6.0:
		var z := area.position.y + 6.0
		while z < area.end.y - 6.0:
			var jx := x + rng.randf_range(-2.0, 2.0)
			var jz := z + rng.randf_range(-2.0, 2.0)
			var here := Rect2(jx - 5.0, jz - 5.0, 10.0, 10.0)
			if here.intersects(keep_a.grow(6.0)) or here.intersects(keep_b.grow(6.0)):
				z += step
				continue
			## Never in front of the roofs — that sky belongs to the kites.
			if jz < keep_a.end.y + 4.0 and absf(jx - keep_a.get_center().x) < keep_a.size.x * 1.6:
				z += step
				continue
			var g: float = map.height_at(jx, jz)
			if g < ground_y - 3.0:
				z += step
				continue
			## Detail only where it can be seen: the far streets are plain.
			var plain := jz > keep_a.end.y + 70.0
			var w := rng.randf_range(6.0, 12.5)
			var d := rng.randf_range(6.0, 12.5)
			## A mix of low courtyard houses and tall merchant blocks.
			var tall := rng.randf_range(3.5, 7.0) if rng.randf() < 0.55 else rng.randf_range(8.0, 15.0)
			var b := Node3D.new()
			b.name = "TownBlock"
			root.add_child(b)
			b.position = Vector3(jx, g - 1.0, jz)
			b.rotation.y = rng.randf_range(-0.35, 0.35)
			frustum(Vector2(w, d), Vector2(w - 0.4, d - 0.4), tall, Vector3.ZERO, mat(SAND if rng.randf() < 0.6 else SAND_DEEP), b)
			box(Vector3(w + 0.4, 0.5, d + 0.4), Vector3(0.0, tall + 0.2, 0.0), mat(SAND_LIT), 0.0, b)
			## Only some roofs are parapeted; the rest are plain terraces.
			if plain:
				pass
			elif rng.randf() < 0.45:
				_parapet(b, w + 0.4, d + 0.4, tall + 0.45)
			else:
				box(Vector3(w + 0.4, 0.5, 0.4), Vector3(0.0, tall + 0.65, -d * 0.5), mat(SAND_LIT), 0.0, b)
			if not plain:
				for i in 2:
					arch_window(Vector3(rng.randf_range(-w * 0.3, w * 0.3), 1.6 + float(i) * 2.8, -d * 0.5), Vector3(0, 0, -1), 0.8, 1.3, rng.randf() < 0.4, b)
			if rng.randf() < 0.22:
				var dome := sphere(w * 0.3, w * 0.42, Vector3(0.0, tall + 1.0, 0.0), mat(SAND_LIT), b)
				dome.scale = Vector3(1.0, 0.8, 1.0)
			## Kites can crash into the town.
			map.building_aabbs.append(AABB(Vector3(jx - w * 0.5, g - 1.0, jz - d * 0.5), Vector3(w, tall + 1.0, d)))
			z += step
		x += step


# ── Town landmarks and wall ──────────────────────────────────────────────────

## The pieces that give the skyline its shape behind the flyer: a palace with
## pavilions, a temple spire, and a stepped water tank.
func landmarks(area: Rect2, ground_y: float, map: Node) -> void:
	var c := area.get_center()
	var lit := mat(SAND_LIT)
	## Palace: a broad block with a taller wing, balconies and roof chhatris.
	var p := Vector3(c.x - 26.0, ground_y, c.y + 18.0)
	var pal := Node3D.new()
	pal.name = "Palace"
	root.add_child(pal)
	pal.position = p
	frustum(Vector2(34.0, 22.0), Vector2(32.0, 20.0), 14.0, Vector3.ZERO, mat(SAND), pal)
	box(Vector3(35.0, 0.8, 23.0), Vector3(0.0, 14.4, 0.0), lit, 0.0, pal)
	_parapet(pal, 35.0, 23.0, 14.8)
	frustum(Vector2(16.0, 14.0), Vector2(15.0, 13.0), 9.0, Vector3(9.0, 14.8, 1.0), mat(SAND), pal)
	box(Vector3(17.0, 0.7, 15.0), Vector3(9.0, 24.1, 1.0), lit, 0.0, pal)
	for i in 4:
		var x := lerpf(-13.0, 13.0, float(i) / 3.0)
		arch_window(Vector3(x, 6.0, -11.02), Vector3(0, 0, -1), 1.4, 2.4, i % 2 == 0, pal)
		jharokha(Vector3(x * 0.8, 10.5, -11.0), Vector3(0, 0, -1), pal)
	for sx in [-1.0, 1.0]:
		chhatri(p + Vector3(sx * 15.0, 15.0, -8.0), 0.85)
	chhatri(p + Vector3(9.0, 24.5, 1.0), 0.95)
	map.building_aabbs.append(AABB(p + Vector3(-17.5, 0.0, -11.5), Vector3(35.0, 24.0, 23.0)))
	## Temple: a square hall under a tapering shikhara with a gold finial.
	var t := Vector3(c.x + 30.0, ground_y, c.y - 6.0)
	var tem := Node3D.new()
	tem.name = "Temple"
	root.add_child(tem)
	tem.position = t
	frustum(Vector2(16.0, 16.0), Vector2(15.0, 15.0), 7.0, Vector3.ZERO, mat(SAND), tem)
	box(Vector3(17.0, 0.7, 17.0), Vector3(0.0, 7.4, 0.0), lit, 0.0, tem)
	## Shikhara: stacked, shrinking storeys curving to a point.
	var y := 7.8
	var w := 11.0
	for i in 9:
		var f := float(i) / 8.0
		var h := lerpf(1.9, 0.9, f)
		frustum(Vector2(w, w), Vector2(w * 0.86, w * 0.86), h, Vector3(0.0, y, 0.0), mat(SAND if i % 2 == 0 else SAND_LIT), tem)
		y += h
		w *= 0.86
	cyl(w * 0.6, w * 0.3, 1.2, Vector3(0.0, y + 0.6, 0.0), lit, 10, tem)
	sphere(0.9, 1.2, Vector3(0.0, y + 1.8, 0.0), mat(CARVE), tem)
	cyl(0.12, 0.2, 1.6, Vector3(0.0, y + 3.0, 0.0), mat(CARVE), 6, tem)
	arch_window(Vector3(0.0, 3.4, -8.02), Vector3(0, 0, -1), 2.6, 4.4, true, tem)
	map.building_aabbs.append(AABB(t + Vector3(-8.5, 0.0, -8.5), Vector3(17.0, y + 4.0, 17.0)))
	## Water tank: a square of steps down to still water, with a pavilion.
	var k := Vector3(c.x - 4.0, ground_y, c.y + 60.0)
	var tank := Node3D.new()
	tank.name = "Tank"
	root.add_child(tank)
	tank.position = k
	var side := 34.0
	for i in 6:
		var s := side - float(i) * 3.4
		box(Vector3(s, 1.2, s), Vector3(0.0, -0.6 - float(i) * 1.2, 0.0), mat(SAND_DEEP if i % 2 == 0 else SAND_LIT), 0.0, tank)
	box(Vector3(12.0, 0.3, 12.0), Vector3(0.0, -7.4, 0.0), mat(TEAL), 0.0, tank)
	chhatri(k + Vector3(side * 0.5 + 3.0, 0.0, 0.0), 0.8)


## A battered wall with round bastions closing the town in — open on the side
## the kites fly, so it never fences the sky.
func town_wall(area: Rect2, ground_y: float, map: Node) -> void:
	var m := mat(SAND)
	var lit := mat(SAND_LIT)
	var corners := [
		[Vector2(area.position.x + 4.0, area.position.y + 30.0), Vector2(area.position.x + 4.0, area.end.y - 4.0)],
		[Vector2(area.position.x + 4.0, area.end.y - 4.0), Vector2(area.end.x - 4.0, area.end.y - 4.0)],
		[Vector2(area.end.x - 4.0, area.end.y - 4.0), Vector2(area.end.x - 4.0, area.position.y + 30.0)],
	]
	for run in corners:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var len := a.distance_to(b)
		var dir := (b - a) / len
		var yaw := atan2(dir.x, dir.y)
		var n := int(len / 34.0) + 1
		for i in n + 1:
			var t := float(i) / float(n)
			var p := a.lerp(b, t)
			var g: float = map.height_at(p.x, p.y)
			cyl(4.6, 3.9, 13.0, Vector3(p.x, g + 5.5, p.y), m, 10)
			cyl(4.2, 4.2, 1.0, Vector3(p.x, g + 12.4, p.y), lit, 10)
			for k in 8:
				var aa := TAU * float(k) / 8.0
				box(Vector3(1.0, 1.1, 1.0), Vector3(p.x + cos(aa) * 3.7, g + 13.3, p.y + sin(aa) * 3.7), lit, aa)
			if i == n:
				continue
			var q := a.lerp(b, float(i + 1) / float(n))
			var mid := (p + q) * 0.5
			var gm: float = map.height_at(mid.x, mid.y)
			var seg := p.distance_to(q)
			var wall := frustum(Vector2(seg, 4.2), Vector2(seg, 3.0), 10.0, Vector3(mid.x, gm, mid.y), m)
			wall.rotation.y = yaw + PI * 0.5
			var cap := box(Vector3(seg, 0.7, 3.4), Vector3(mid.x, gm + 10.3, mid.y), lit, yaw + PI * 0.5)
			cap.name = "WallCap"
			map.building_aabbs.append(AABB(Vector3(mid.x - seg * 0.5, gm, mid.y - 2.5), Vector3(seg, 11.0, 5.0)))


# ── Fort ─────────────────────────────────────────────────────────────────────

## Jaisalmer-style: a ring of round bastions joined by battered curtain wall,
## with a gate tower and a huddle of buildings inside.
func fort(top_center: Vector3, half: Vector2) -> Node3D:
	var f := Node3D.new()
	f.name = "Fort"
	root.add_child(f)
	f.position = top_center
	var m := mat(SAND)
	var lit := mat(SAND_LIT)
	var n := 16
	for i in n:
		var a := TAU * float(i) / float(n)
		var p := Vector3(cos(a) * half.x, 0.0, sin(a) * half.y)
		## Bastion: a fat tapering drum with a battlemented top.
		var r := 6.5 if i % 2 == 0 else 5.0
		cyl(r, r * 0.8, 24.0, p + Vector3(0.0, 12.0, 0.0), m, 12, f)
		cyl(r * 0.95, r * 0.95, 1.4, p + Vector3(0.0, 24.7, 0.0), lit, 12, f)
		for k in 9:
			var aa := TAU * float(k) / 9.0
			box(Vector3(1.2, 1.4, 1.2), p + Vector3(cos(aa) * r * 0.86, 26.0, sin(aa) * r * 0.86), lit, aa, f)
		## Curtain wall to the next bastion.
		var a2 := TAU * float(i + 1) / float(n)
		var q := Vector3(cos(a2) * half.x, 0.0, sin(a2) * half.y)
		var mid := (p + q) * 0.5
		var seg := q - p
		var wall := frustum(Vector2(seg.length(), 5.5), Vector2(seg.length(), 4.0), 19.0, mid, m, f)
		wall.rotation.y = atan2(seg.x, seg.z) + PI * 0.5
		var cap := box(Vector3(seg.length(), 0.9, 4.6), mid + Vector3(0.0, 19.4, 0.0), lit, atan2(seg.x, seg.z) + PI * 0.5, f)
		cap.name = "WallCap"
	## Inside: a cluster of flat-roofed blocks and two chhatris.
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in 12:
		var p := Vector3(rng.randf_range(-half.x * 0.7, half.x * 0.7), 0.0, rng.randf_range(-half.y * 0.7, half.y * 0.7))
		var w := rng.randf_range(8.0, 16.0)
		var d := rng.randf_range(8.0, 14.0)
		var tall := rng.randf_range(14.0, 30.0)
		frustum(Vector2(w, d), Vector2(w - 0.6, d - 0.6), tall, p, mat(SAND if i % 2 == 0 else SAND_DEEP), f)
		box(Vector3(w + 0.5, 0.6, d + 0.5), p + Vector3(0.0, tall + 0.3, 0.0), lit, 0.0, f)
		if i % 4 == 0:
			var dm := sphere(w * 0.32, w * 0.42, p + Vector3(0.0, tall + 1.0, 0.0), lit, f)
			dm.scale = Vector3(1.0, 0.85, 1.0)
	## Gate tower facing the town.
	var gate := Vector3(half.x * 0.2, 0.0, -half.y - 1.0)
	frustum(Vector2(14.0, 8.0), Vector2(12.0, 7.0), 20.0, gate, m, f)
	box(Vector3(15.0, 1.0, 9.0), gate + Vector3(0.0, 20.2, 0.0), lit, 0.0, f)
	arch_window(gate + Vector3(0.0, 5.0, -4.1), Vector3(0, 0, -1), 4.0, 7.0, false, f)
	## Palace chhatris breaking the skyline.
	for sx in [-0.45, 0.0, 0.45]:
		chhatri(top_center + Vector3(sx * half.x, 26.0, -half.y * 0.25), 1.15)
	return f


# ── Stepwell, caravan, trees, dust devils ────────────────────────────────────

## A ruined baori: square terraces of steps descending into the sand.
func stepwell(top_center: Vector3) -> void:
	var s := Node3D.new()
	s.name = "Stepwell"
	root.add_child(s)
	s.position = top_center
	var m := mat(SAND_DEEP)
	var lit := mat(SAND_LIT)
	var side := 22.0
	for i in 7:
		var w := side - float(i) * 2.6
		var y := -float(i) * 1.5
		box(Vector3(w, 1.5, w), Vector3(0.0, y - 0.75, 0.0), m if i % 2 == 0 else lit, 0.0, s)
	## Water at the bottom, and a broken pavilion on the rim.
	box(Vector3(5.0, 0.2, 5.0), Vector3(0.0, -10.4, 0.0), mat(TEAL), 0.0, s)
	chhatri(top_center + Vector3(side * 0.5 + 2.0, 0.0, 0.0), 0.7)
	for i in 3:
		box(Vector3(1.2, rand_from(i) * 3.0 + 1.0, 1.2), Vector3(-side * 0.5 - 1.5, 0.5, -3.0 + float(i) * 3.0), lit, 0.0, s)


func rand_from(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)


## Silhouette material: flat black-brown whatever the light does, so a camel
## on a crest reads as a cut-out against the sun.
func shadow_mat() -> StandardMaterial3D:
	var m := mat(Color(0.10, 0.05, 0.05))
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## A camel, built so its legs can swing: returns the node with the four legs
## kept as children for the walk.
func camel(pos: Vector3, yaw: float, parent: Node3D) -> Node3D:
	var c := Node3D.new()
	c.name = "Camel"
	parent.add_child(c)
	c.position = pos
	c.rotation.y = yaw
	var hide := shadow_mat()
	var body := sphere(0.95, 1.5, Vector3(0.0, 1.9, 0.0), hide, c)
	body.scale = Vector3(0.85, 0.75, 1.7)
	var hump := sphere(0.58, 0.95, Vector3(0.0, 2.55, 0.1), hide, c)
	hump.scale = Vector3(0.9, 1.05, 1.0)
	var neck := cyl(0.2, 0.24, 1.9, Vector3(0.0, 2.75, -1.3), hide, 6, c)
	neck.rotation.x = 0.5
	var head := sphere(0.3, 0.5, Vector3(0.0, 3.5, -1.85), hide, c)
	head.scale = Vector3(0.8, 0.8, 1.5)
	var tail := cyl(0.07, 0.04, 0.9, Vector3(0.0, 2.1, 1.35), hide, 4, c)
	tail.rotation.x = -0.5
	## Legs hang from hips so they can swing from the top.
	for sx in [-0.45, 0.45]:
		for sz in [-0.85, 0.8]:
			var hip := Node3D.new()
			hip.name = "Leg"
			c.add_child(hip)
			hip.position = Vector3(sx, 1.9, sz)
			cyl(0.13, 0.1, 1.9, Vector3(0.0, -0.95, 0.0), hide, 5, hip)
	return c


## A camel train plodding nose to tail around a closed route over the dunes.
## A loop means the line never breaks at a seam. The map ticks it each frame.
func caravan(map: Node, route: PackedVector2Array, n: int) -> Dictionary:
	var c := Node3D.new()
	c.name = "Caravan"
	root.add_child(c)
	var camels: Array[Node3D] = []
	for i in n:
		camels.append(camel(Vector3.ZERO, 0.0, c))
	## Cumulative length round the loop, so a camel can be placed by distance.
	var marks := PackedFloat32Array()
	var total := 0.0
	for i in route.size():
		marks.append(total)
		total += route[i].distance_to(route[(i + 1) % route.size()])
	return {"node": c, "camels": camels, "route": route, "marks": marks, "len": total, "dist": 0.0}


## Where the route is at `along` metres round the loop.
func _route_at(train: Dictionary, along: float) -> Vector2:
	var route: PackedVector2Array = train["route"]
	var marks: PackedFloat32Array = train["marks"]
	var total: float = train["len"]
	var d := fposmod(along, total)
	for i in range(route.size() - 1, -1, -1):
		if d >= marks[i]:
			var a := route[i]
			var b := route[(i + 1) % route.size()]
			var seg := a.distance_to(b)
			return a.lerp(b, clampf((d - marks[i]) / maxf(seg, 0.001), 0.0, 1.0))
	return route[0]


## Walk the train: each camel trails the one ahead by a fixed gap, rises and
## falls over the dunes, leans with the slope and swings its legs.
func walk_caravan(train: Dictionary, map: Node, delta: float, speed: float = 1.6) -> void:
	var dist: float = float(train["dist"]) + speed * delta
	train["dist"] = dist
	var camels: Array = train["camels"]
	for i in camels.size():
		var along := dist - float(i) * 6.5
		var p := _route_at(train, along)
		var ahead := _route_at(train, along + 2.0)
		var y: float = map.height_at(p.x, p.y)
		var y2: float = map.height_at(ahead.x, ahead.y)
		var step := ahead - p
		var cam: Node3D = camels[i]
		cam.position = Vector3(p.x, y - 0.25 + sin(along * 0.9 + float(i)) * 0.05, p.y)
		cam.rotation = Vector3(-atan2(y2 - y, maxf(step.length(), 0.01)), atan2(step.x, step.y) + PI, 0.0)
		## Legs swing in diagonal pairs, and the body rocks with the stride.
		var phase := along * 1.1 + float(i) * 0.7
		var k := 0
		for leg in cam.get_children():
			if leg is Node3D and leg.name.begins_with("Leg"):
				var swing := sin(phase + (0.0 if k % 3 == 0 else PI))
				(leg as Node3D).rotation.x = swing * 0.35
				k += 1


## Khejri: thin trunk, flat spreading crown — the tree of the Thar.
func khejri(feet: Vector3, rng: RandomNumberGenerator) -> void:
	var t := Node3D.new()
	t.name = "Khejri"
	root.add_child(t)
	t.position = feet
	t.rotation.y = rng.randf() * TAU
	var bark := mat(Color(0.36, 0.26, 0.18))
	var leaf := mat(Color(0.30, 0.34, 0.20))
	var tall := rng.randf_range(2.6, 4.4)
	cyl(0.22, 0.14, tall, Vector3(0.0, tall * 0.5, 0.0), bark, 6, t)
	for i in 3:
		var a := TAU * float(i) / 3.0 + rng.randf()
		var r := rng.randf_range(1.2, 2.2)
		var crown := sphere(r, r * 0.7, Vector3(cos(a) * r * 0.5, tall + rng.randf_range(0.0, 0.5), sin(a) * r * 0.5), leaf, t)
		crown.scale = Vector3(1.2, 0.5, 1.2)


## A dust devil: a twisting column of sand, thin at the foot and flaring out
## as it rises, with grit whipping round it. `gentle` makes it a plain
## thermal instead: a slow drift of dust and chaff marking the rising air.
func dust_devil(base: Vector3, r: float, gentle: bool = false) -> Node3D:
	var d := Node3D.new()
	d.name = "DustDevil"
	root.add_child(d)
	d.position = base
	var p := GPUParticles3D.new()
	p.amount = 45 if gentle else 240
	p.lifetime = 6.5 if gentle else 4.5
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 80, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = r * 0.7
	pm.emission_ring_inner_radius = r * 0.3
	pm.emission_ring_height = 2.0
	pm.emission_ring_axis = Vector3.UP
	pm.direction = Vector3.UP
	pm.spread = 7.0
	pm.initial_velocity_min = 1.6 if gentle else 6.0
	pm.initial_velocity_max = 3.4 if gentle else 11.0
	pm.tangential_accel_min = 1.0 if gentle else 9.0
	pm.tangential_accel_max = 3.0 if gentle else 18.0
	pm.radial_accel_min = -2.0
	pm.radial_accel_max = -0.5
	pm.gravity = Vector3(0.0, 1.2 if gentle else 2.5, 0.0)
	pm.scale_min = 0.8 if gentle else 1.2
	pm.scale_max = 1.8 if gentle else 3.2
	## Grit widens as it climbs, like a real devil.
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(1.0, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	var strong := 0.42 if gentle else 0.7
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.7, 1.0])
	## Dust, not steam: warm and dim, so it never flashes white against the
	## dark backlit sand.
	g.colors = PackedColorArray([
		Color(0.62, 0.36, 0.22, 0.0),
		Color(0.58, 0.32, 0.20, 0.34 * strong),
		Color(0.52, 0.28, 0.18, 0.20 * strong),
		Color(0.48, 0.26, 0.18, 0.0),
	])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.5) if gentle else Vector2(3.2, 3.2)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	var sg := Gradient.new()
	sg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	soft.gradient = sg
	qm.albedo_texture = soft
	quad.material = qm
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.add_child(p)
	return d


## A date palm: a leaning, ringed trunk and a crown of long drooping fronds.
## Against a low sun these read as pure silhouette, which is the whole point.
func palm(feet: Vector3, rng: RandomNumberGenerator, scale: float = 1.0) -> Node3D:
	var t := Node3D.new()
	t.name = "Palm"
	root.add_child(t)
	t.position = feet
	t.rotation.y = rng.randf() * TAU
	var dark := mat(Color(0.14, 0.07, 0.07))
	var tall := rng.randf_range(7.0, 12.0) * scale
	var lean := rng.randf_range(-0.16, 0.16)
	var segs := 9
	var pos := Vector3.ZERO
	var r0 := 0.34 * scale
	for i in segs:
		var f := float(i) / float(segs)
		var seg_h := tall / float(segs)
		var r := lerpf(r0, r0 * 0.55, f)
		## Each drum steps a little sideways, so the trunk curves.
		pos += Vector3(sin(f * 3.0) * lean * seg_h, seg_h, cos(f * 2.0) * lean * seg_h * 0.5)
		var drum := cyl(r, r * 0.95, seg_h * 1.06, pos - Vector3(0.0, seg_h * 0.5, 0.0), dark, 7, t)
		drum.rotation.y = f * 1.4
	## Crown: fronds springing from the top, arching over and drooping.
	var crown := pos
	var n := rng.randi_range(8, 11)
	for i in n:
		var a := TAU * float(i) / float(n) + rng.randf_range(-0.12, 0.12)
		var droop := rng.randf_range(0.5, 1.0)
		var len := rng.randf_range(2.6, 4.2) * scale
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var steps := 6
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for k in steps + 1:
			var f := float(k) / float(steps)
			## Arch up, then fall away.
			var y := sin(f * PI * 0.55) * len * 0.42 - pow(f, 2.2) * len * droop * 0.55
			var out := f * len
			var wide := sin(f * PI) * 0.34 * scale + 0.04
			var mid := Vector3(cos(a) * out, y, sin(a) * out)
			var side := Vector3(-sin(a), 0.0, cos(a)) * wide
			var l := mid + side
			var r := mid - side
			if k > 0:
				for v in [prev_l, prev_r, r, prev_l, r, l]:
					st.add_vertex(v)
			prev_l = l
			prev_r = r
		st.generate_normals()
		var frond := MeshInstance3D.new()
		frond.mesh = st.commit()
		var fm := dark.duplicate() as StandardMaterial3D
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		frond.material_override = fm
		t.add_child(frond)
		frond.position = crown
	## A cluster of dates under the crown.
	for i in 3:
		var a := TAU * float(i) / 3.0
		sphere(0.3 * scale, 0.5 * scale, crown + Vector3(cos(a) * 0.5, -0.5, sin(a) * 0.5) * scale, dark, t)
	return t


## Motes of light drifting over the sand at sundown — dust catching the sun.
func motes(center: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Motes"
	p.amount = 90
	p.lifetime = 11.0
	p.preprocess = 6.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-160, -40, -200), Vector3(320, 120, 400))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(130.0, 22.0, 150.0)
	pm.direction = Vector3(0.0, 0.3, -1.0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0.0, 0.25, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.75, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 0.82, 0.45, 0.0),
		Color(1.0, 0.86, 0.52, 0.85),
		Color(1.0, 0.78, 0.40, 0.55),
		Color(1.0, 0.72, 0.36, 0.0),
	])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.disable_fog = true
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	var sg := Gradient.new()
	sg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	soft.gradient = sg
	qm.albedo_texture = soft
	quad.material = qm
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	p.position = center
	return p
