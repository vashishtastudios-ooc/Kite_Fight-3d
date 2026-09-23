extends Node3D

## Distant kites over the city — the festival sky. Each hangs on a long line
## from a far roof, swaying on its own. When a gust front rolls out over the
## city they lurch downwind and up one after another, nearest first, so you
## can watch the gust travel away from your roof.

const WindSys := preload("res://scripts/wind_system.gd")
const KiteSkins := preload("res://scripts/kite_skins.gd")

const COUNT := 9
const SIZE := 4.2                ## drawn larger than life so they read at 200 m
const GUST_PUSH := 7.0           ## m a full gust shoves a far kite downwind
const GUST_LIFT := 4.0

var wind: WindSys
var _kites: Array[MeshInstance3D] = []
var _home: Array[Vector3] = []
var _anchor: Array[Vector3] = []
var _phase: Array[float] = []
var _lurch: Array[float] = []
var _lines: ImmediateMesh
var _line_mat: StandardMaterial3D


func setup(wind_in: WindSys, origin: Vector3) -> void:
	wind = wind_in
	var d := wind.wind_dir()
	var right := Vector3.UP.cross(d).normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var ids := KiteSkins.PATANGS.keys()
	for i in COUNT:
		var far := rng.randf_range(150.0, 330.0)
		var side := lerpf(-1.0, 1.0, (float(i) + rng.randf_range(-0.3, 0.3)) / float(COUNT - 1))
		var home := origin + d * far + right * side * far * 0.62 + Vector3.UP * rng.randf_range(48.0, 105.0)
		var anchor := origin + d * (far - rng.randf_range(60.0, 110.0)) + right * side * far * 0.55
		anchor.y = origin.y + rng.randf_range(-6.0, 4.0)
		var pal := KiteSkins.palette_for(ids[rng.randi() % ids.size()])
		var mi := MeshInstance3D.new()
		mi.mesh = _diamond(pal[0], pal[1])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = home
		_kites.append(mi)
		_home.append(home)
		_anchor.append(anchor)
		_phase.append(rng.randf() * TAU)
		_lurch.append(0.0)
	_lines = ImmediateMesh.new()
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_mat.albedo_color = Color(1.0, 0.94, 0.86, 0.09)
	var lines := MeshInstance3D.new()
	lines.name = "FarLines"
	lines.mesh = _lines
	lines.material_override = _line_mat
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lines.extra_cull_margin = 400.0
	add_child(lines)


## Dim every far kite and its line — on a map flown into the sun they read
## as paper silhouettes, not bright colour.
func tint(c: Color) -> void:
	for k in _kites:
		var mesh := k.mesh as ArrayMesh
		if mesh == null:
			continue
		var m := mesh.surface_get_material(0) as StandardMaterial3D
		if m:
			m.albedo_color = c
	if _line_mat:
		_line_mat.albedo_color = Color(c.r, c.g, c.b, 0.16)


func _process(delta: float) -> void:
	if wind == null or _kites.is_empty():
		return
	var d := wind.wind_dir()
	var right := Vector3.UP.cross(d).normalized()
	var t := wind.time
	var cam := get_viewport().get_camera_3d()
	_lines.clear_surfaces()
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in _kites.size():
		var g := wind.gust01_at(_home[i])
		## Snap into the gust, ease out of it.
		_lurch[i] = move_toward(_lurch[i], g, delta * (3.0 if g > _lurch[i] else 0.8))
		var l := _lurch[i]
		var ph := _phase[i]
		var sway := right * sin(t * 0.7 + ph) * 3.0 + Vector3.UP * sin(t * 1.1 + ph * 1.7) * 1.4
		var pos := _home[i] + sway + d * l * GUST_PUSH + Vector3.UP * l * GUST_LIFT
		pos += right * sin(t * 9.0 + ph) * 0.5 * l
		var k := _kites[i]
		k.global_position = pos
		## Face the camera like a flown kite faces its flyer, nose up, rolling
		## with the sway and kicking over in the gust.
		if cam:
			var face := cam.global_position - pos
			face.y = 0.0
			if face.length_squared() > 1.0:
				k.look_at(pos - face, Vector3.UP)
		k.rotate_object_local(Vector3.FORWARD, sin(t * 0.9 + ph) * 0.35 + l * 0.6 * sin(t * 7.0 + ph))
		## Line from the far roof, sagging a little.
		var a := _anchor[i]
		var mid := (a + pos) * 0.5 + Vector3.DOWN * a.distance_to(pos) * 0.05
		var prev := a
		for s in range(1, 9):
			var u := float(s) / 8.0
			var p := a.lerp(mid, u).lerp(mid.lerp(pos, u), u)
			_lines.surface_add_vertex(prev)
			_lines.surface_add_vertex(p)
			prev = p
	_lines.surface_end()


func _diamond(paper: Color, ink: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3(0.0, SIZE * 0.55, 0.0)
	var r := Vector3(SIZE * 0.42, 0.0, 0.0)
	var b := Vector3(0.0, -SIZE * 0.45, 0.0)
	var l := Vector3(-SIZE * 0.42, 0.0, 0.0)
	var c := Vector3.ZERO
	for tri in [[n, r, c, paper], [r, b, c, ink], [b, l, c, paper], [l, n, c, ink]]:
		st.set_color(tri[3])
		st.add_vertex(tri[0])
		st.set_color(tri[3])
		st.add_vertex(tri[1])
		st.set_color(tri[3])
		st.add_vertex(tri[2])
	## Little tail.
	var tail_col := ink.lerp(Color.WHITE, 0.3)
	var t0 := b
	var t1 := b + Vector3(0.12, -SIZE * 0.5, 0.0)
	var t2 := b + Vector3(-0.12, -SIZE * 0.5, 0.0)
	for v in [t0, t1, t2]:
		st.set_color(tail_col)
		st.add_vertex(v)
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.92, 0.9, 0.95)
	mesh.surface_set_material(0, mat)
	return mesh
