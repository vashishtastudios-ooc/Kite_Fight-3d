extends RefCounted

## Shared building blocks for the hand-built maps: cached flat-shaded
## materials and the few primitives every prop is made of (boxes, cylinders,
## spheres, battered frustums, hip roofs). Map prop files extend this.

const WALL_SHADER := preload("res://shaders/stone_wall.gdshader")

## Shared palette.
const WHITE := Color(0.95, 0.92, 0.86)
const MAROON := Color(0.46, 0.10, 0.10)
const RED := Color(0.72, 0.16, 0.12)
const GOLD := Color(0.95, 0.72, 0.28)
const INK := Color(0.10, 0.07, 0.07)
const WOOD := Color(0.40, 0.26, 0.16)
const SLATE := Color(0.34, 0.30, 0.32)
const LAMP := Color(1.0, 0.70, 0.36)

var root: Node3D
var _mats: Dictionary = {}


func _init(parent: Node3D) -> void:
	root = parent


# ── Materials & primitives ───────────────────────────────────────────────────

func mat(col: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s" % [col.to_html(), glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


func wall_mat(top_y: float) -> ShaderMaterial:
	var key := "wall|%s" % top_y
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = WALL_SHADER
	m.set_shader_parameter("wash_top", top_y)
	_mats[key] = m
	return m


func box(size: Vector3, pos: Vector3, m: Material, yaw: float = 0.0, parent: Node3D = null) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = m
	(parent if parent else root).add_child(mi)
	mi.position = pos
	mi.rotation.y = yaw
	return mi


func cyl(r_bottom: float, r_top: float, h: float, pos: Vector3, m: Material, sides: int = 12, parent: Node3D = null) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_bottom
	cm.top_radius = r_top
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = m
	(parent if parent else root).add_child(mi)
	mi.position = pos
	return mi


func sphere(r: float, h: float, pos: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = h
	sm.radial_segments = 14
	sm.rings = 7
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = m
	(parent if parent else root).add_child(mi)
	mi.position = pos
	return mi


## A block whose top is smaller than its foot (battered walls, plinths).
func frustum(bottom: Vector2, top: Vector2, h: float, pos: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var b := bottom * 0.5
	var t := top * 0.5
	var v := [
		Vector3(-b.x, 0, -b.y), Vector3(b.x, 0, -b.y), Vector3(b.x, 0, b.y), Vector3(-b.x, 0, b.y),
		Vector3(-t.x, h, -t.y), Vector3(t.x, h, -t.y), Vector3(t.x, h, t.y), Vector3(-t.x, h, t.y),
	]
	var faces := [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [4, 5, 6, 7], [3, 2, 1, 0]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		st.add_vertex(v[f[0]])
		st.add_vertex(v[f[1]])
		st.add_vertex(v[f[2]])
		st.add_vertex(v[f[0]])
		st.add_vertex(v[f[2]])
		st.add_vertex(v[f[3]])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	(parent if parent else root).add_child(mi)
	mi.position = pos
	return mi


## A four-sided roof rising to a ridge (hip roof).
func hip_roof(w: float, d: float, h: float, ridge: float, pos: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var hw := w * 0.5
	var hd := d * 0.5
	var r := ridge * 0.5
	var a := Vector3(-hw, 0, -hd)
	var b := Vector3(hw, 0, -hd)
	var c := Vector3(hw, 0, hd)
	var e := Vector3(-hw, 0, hd)
	var p := Vector3(-r, h, 0)
	var q := Vector3(r, h, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[a, b, q], [a, q, p], [c, e, p], [c, p, q], [b, c, q], [e, a, p]]:
		for vv in tri:
			st.add_vertex(vv)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mm
	(parent if parent else root).add_child(mi)
	mi.position = pos
	return mi
