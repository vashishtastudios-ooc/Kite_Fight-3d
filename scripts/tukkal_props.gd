extends "res://scripts/build_kit.gd"

## Pieces for Tukkal Raat, modelled in Blender (assets/tukkal/*.glb) and dressed
## here: the ruined aqueduct with its temple, layered crags with bonsai trees,
## paper lanterns hung along the arcade and hot-air balloons drifting far off.
## Everything reads as a violet silhouette against the moonglow; only the
## lanterns and the temple doorways give off light.

const STONE := Color(0.20, 0.12, 0.25)
const STONE_LIT := Color(0.32, 0.20, 0.35)
const NEAR_DARK := Color(0.07, 0.05, 0.11)
const AMBER := Color(1.0, 0.66, 0.30)

const AQUEDUCT_SCENE := preload("res://assets/tukkal/aqueduct.glb")
const BONSAI_SCENE := preload("res://assets/tukkal/bonsai.glb")
const CRAG_TALL_SCENE := preload("res://assets/tukkal/cragtall.glb")
const CRAG_WIDE_SCENE := preload("res://assets/tukkal/cragwide.glb")
const SKY_LANTERN_SCENE := preload("res://assets/tukkal/sky_lantern.glb")
const BALLOON_SCENE := preload("res://assets/tukkal/balloon.glb")


## Give every mesh under a node the same material.
func _paint(n: Node, m: Material) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m


## The aqueduct model: a two-tier arcade with carved arch rings and dentilled
## cornices, broken at both ends, carrying a Nagara temple (mandapa, shikhara,
## amalaka, kalash, pennant) and two chhatris. Its doorways glow, and a paper
## lantern hangs at each LanternSlot the model carries. Returns collision
## boxes for the piers, the solid bands over the arches, and the temple — the
## arch openings themselves stay open, so a kite can thread them.
func aqueduct(center: Vector3, stone: Material) -> Array[AABB]:
	var a := AQUEDUCT_SCENE.instantiate() as Node3D
	a.name = "Aqueduct"
	root.add_child(a)
	a.position = center
	## Double-sided: the arcade is built of open panels, so draw both faces.
	var both := stone.duplicate() as StandardMaterial3D
	both.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi in a.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if String(m.name).begins_with("Glow"):
			m.material_override = mat(AMBER, 3.0)
		else:
			m.material_override = both
	for slot in a.find_children("LanternSlot*", "Node3D", true, false):
		lantern(a, (slot as Node3D).position, 0.9)
	var boxes: Array[AABB] = []
	## Lower tier: 15 piers 17 m apart, solid band above the arch crowns.
	for i in 15:
		var px := -119.0 + 17.0 * float(i)
		boxes.append(AABB(center + Vector3(px - 3.3, 0.0, -3.6), Vector3(6.6, 26.0, 7.2)))
	boxes.append(AABB(center + Vector3(-102.0, 20.0, -4.0), Vector3(204.0, 6.5, 8.0)))
	## Upper tier: piers 11 m apart round x = -25, band over its arches.
	for i in 14:
		var px := -25.0 - 71.5 + 11.0 * float(i)
		boxes.append(AABB(center + Vector3(px - 2.0, 25.7, -3.1), Vector3(4.0, 16.8, 6.2)))
	boxes.append(AABB(center + Vector3(-85.5, 38.8, -3.4), Vector3(121.0, 4.8, 6.8)))
	## Temple and its two chhatris.
	boxes.append(AABB(center + Vector3(-35.0, 43.0, -9.0), Vector3(20.0, 37.0, 17.0)))
	for sx in [-1.0, 1.0]:
		boxes.append(AABB(center + Vector3(-25.0 + sx * 30.0 - 2.6, 43.0, -2.6), Vector3(5.2, 8.5, 5.2)))
	return boxes


## A glowing paper lantern hung from a slot: the sky-lantern shape, lit.
func lantern(parent: Node3D, pos: Vector3, s: float = 1.0) -> Node3D:
	var l := SKY_LANTERN_SCENE.instantiate() as Node3D
	l.name = "Lantern"
	parent.add_child(l)
	l.position = pos - Vector3(0.0, 0.6 * s, 0.0)
	l.scale = Vector3.ONE * s
	_paint(l, mat(AMBER, 4.0))
	for mi in l.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return l


## A wind-bent cliff tree: kinked trunk, flat cloud-pads stepping out.
func bonsai(feet: Vector3, rng: RandomNumberGenerator, s: float = 1.0) -> Node3D:
	var t := BONSAI_SCENE.instantiate() as Node3D
	t.name = "Bonsai"
	root.add_child(t)
	t.position = feet
	t.rotation.y = rng.randf() * TAU
	t.scale = Vector3.ONE * s * rng.randf_range(0.85, 1.15)
	_paint(t, mat(NEAR_DARK))
	return t


## A layered crag of stacked rock slabs, with a bonsai on its cap stone.
## Returns its collision box (a slightly slimmed column).
func crag(foot: Vector3, tall: bool, rng: RandomNumberGenerator, s: float = 1.0) -> AABB:
	var c := (CRAG_TALL_SCENE if tall else CRAG_WIDE_SCENE).instantiate() as Node3D
	c.name = "Crag"
	root.add_child(c)
	c.position = foot
	c.rotation.y = rng.randf() * TAU
	c.scale = Vector3.ONE * s
	_paint(c, mat(NEAR_DARK.lerp(STONE, 0.35)))
	for slot in c.find_children("*TreeSlot*", "Node3D", true, false):
		var top := c.global_transform * (slot as Node3D).position
		bonsai(top, rng, s * rng.randf_range(0.9, 1.3))
	var w := (26.0 if tall else 34.0) * 0.6 * s
	var h := (43.0 if tall else 28.0) * s
	return AABB(foot - Vector3(w * 0.5, 0.0, w * 0.5), Vector3(w, h, w))


## Hot-air balloons far out over the valley, dark against the glow with a lit
## burner at the mouth. Returns them for the map to drift.
func balloons(rng: RandomNumberGenerator, spots: Array) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var skin := mat(Color(0.26, 0.12, 0.22))
	for sp in spots:
		var b := BALLOON_SCENE.instantiate() as Node3D
		b.name = "Balloon"
		root.add_child(b)
		b.position = sp
		var s := rng.randf_range(0.8, 1.3)
		b.scale = Vector3.ONE * s
		b.rotation.y = rng.randf() * TAU
		_paint(b, skin)
		## Burner glow just inside the mouth of the envelope.
		var burner := sphere(0.7, 1.0, Vector3(0.0, 3.2, 0.0), mat(AMBER, 5.0), b)
		burner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.append(b)
	return out
