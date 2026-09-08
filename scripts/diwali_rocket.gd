class_name DiwaliRocket
extends Node3D

const HIT_R := 3.4
const FW_SHADER := preload("res://shaders/firework_burst.gdshader")
const FLARE_SHADER := preload("res://shaders/rocket_flare.gdshader")

signal resolved(hit: bool, dodged: bool)

var launch_pos: Vector3
var _target: Vector3
var _from: Vector3
var _mid: Vector3
var _t: float = 0.0
var _dur: float = 2.0
var _kite: Node
var _live: bool = true
var _body: Node3D
var _burst: MeshInstance3D
var _burst_mat: ShaderMaterial
var _burst_t: float = -1.0
var _glow: OmniLight3D
var _flare: MeshInstance3D
var _trail_mi: MeshInstance3D
var _trail_imm: ImmediateMesh
var _trail_pts: Array[Vector3] = []
var _halo: MeshInstance3D


func is_inbound() -> bool:
	return _live


func fire(from: Vector3, aim: Vector3, kite: Node) -> void:
	_kite = kite
	launch_pos = from
	_from = from
	_target = aim
	var dist := from.distance_to(aim)
	if dist < 4.0:
		_target = from + Vector3(0.0, 12.0, -16.0)
		dist = from.distance_to(_target)
	var side := Vector3(aim.z - from.z, 0.0, from.x - aim.x)
	if side.length() < 0.2:
		side = Vector3.RIGHT
	side = side.normalized() * randf_range(-2.2, 2.2)
	_mid = (_from + _target) * 0.5 + Vector3.UP * clampf(dist * 0.12, 6.0, 16.0) + side
	_dur = clampf(dist / 33.6, 0.95, 2.15)
	global_position = from
	_build_body()
	_trail_pts.append(from)


func _process(delta: float) -> void:
	if _burst_t >= 0.0:
		_burst_t += delta
		if _burst_mat:
			_burst_mat.set_shader_parameter("burst_t", _burst_t)
		if _halo and _halo.material_override is ShaderMaterial:
			(_halo.material_override as ShaderMaterial).set_shader_parameter("burst_t", _burst_t)
		var cam := get_viewport().get_camera_3d()
		if cam:
			if _burst:
				_burst.look_at(cam.global_position, Vector3.UP)
			if _halo:
				_halo.look_at(cam.global_position, Vector3.UP)
		if _glow:
			_glow.light_energy = maxf(0.0, 9.5 * (1.0 - _burst_t / 1.6))
		if _burst_t > 1.85:
			queue_free()
		return
	if not _live:
		return
	_t += delta / _dur
	var u := clampf(_t, 0.0, 1.0)
	var p := _bezier(u)
	var nxt := _bezier(clampf(u + 0.05, 0.0, 1.0))
	global_position = p
	if _body and nxt != p:
		_body.look_at(nxt, Vector3.UP)
	_face_flare()
	_push_trail(p)
	if u >= 1.0:
		_arrive()


func _arrive() -> void:
	var at := _target
	var hit := false
	var dodged := false
	if _kite and is_instance_valid(_kite) and _kite.has_method("is_airborne") and _kite.is_airborne():
		if _kite.global_position.distance_to(at) < HIT_R:
			hit = true
			_kite.kill_by_rocket()
		else:
			var kp: Vector3 = _kite.global_position
			var moved: bool = kp.distance_to(at) > 5.8
			dodged = moved and _kite.has_method("steered_recently") and _kite.steered_recently()
	resolved.emit(hit, dodged)
	_explode(at, _festive_color())


func _bezier(u: float) -> Vector3:
	var o := 1.0 - u
	return _from * o * o + _mid * 2.0 * o * u + _target * u * u


func _festive_color() -> Color:
	var palette: Array[Color] = [
		Color(1.0, 0.22, 0.12),
		Color(1.0, 0.55, 0.08),
		Color(1.0, 0.12, 0.62),
		Color(0.18, 0.95, 0.42),
		Color(0.15, 0.65, 1.0),
		Color(0.85, 0.2, 1.0),
		Color(1.0, 0.85, 0.15),
	]
	return palette[randi() % palette.size()]


func _trail_gradient() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.22, 0.55, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 0.95, 0.55, 1.0),
		Color(1.0, 0.42, 0.08, 1.0),
		Color(1.0, 0.12, 0.55, 0.75),
		Color(0.2, 0.7, 1.0, 0.0),
	])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex


func _spark_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _build_body() -> void:
	_body = Node3D.new()
	add_child(_body)

	var stick := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.12
	cyl.height = 1.15
	cyl.radial_segments = 8
	stick.mesh = cyl
	var paper := StandardMaterial3D.new()
	paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paper.albedo_color = Color(1.0, 0.18, 0.08)
	paper.emission_enabled = true
	paper.emission = Color(1.0, 0.2, 0.05)
	paper.emission_energy_multiplier = 1.8
	stick.material_override = paper
	stick.rotation_degrees.x = 90.0
	_body.add_child(stick)

	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.18
	cone.height = 0.32
	cone.radial_segments = 8
	head.mesh = cone
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.albedo_color = Color(1.0, 0.82, 0.2)
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.55, 0.08)
	gold.emission_energy_multiplier = 4.0
	head.material_override = gold
	head.position = Vector3(0.0, 0.0, -0.68)
	head.rotation_degrees.x = 90.0
	_body.add_child(head)

	_flare = MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(0.95, 0.95)
	_flare.mesh = fq
	var fm := ShaderMaterial.new()
	fm.shader = FLARE_SHADER
	_flare.material_override = fm
	_flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flare.position = Vector3(0.0, 0.0, 0.55)
	_body.add_child(_flare)

	var spark := GPUParticles3D.new()
	spark.amount = 80
	spark.lifetime = 0.75
	spark.local_coords = false
	spark.trail_enabled = true
	spark.trail_lifetime = 0.62
	spark.visibility_aabb = AABB(Vector3(-16, -16, -16), Vector3(32, 32, 32))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 0.0, 1.0)
	pm.spread = 8.0
	pm.initial_velocity_min = 3.2
	pm.initial_velocity_max = 7.5
	pm.gravity = Vector3(0.0, -0.6, 0.0)
	pm.scale_min = 0.035
	pm.scale_max = 0.09
	pm.color = Color(1.0, 0.78, 0.28, 1.0)
	pm.color_ramp = _trail_gradient()
	spark.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.09
	sm.material = _spark_material()
	spark.draw_pass_1 = sm
	spark.position = Vector3(0.0, 0.0, 0.55)
	_body.add_child(spark)

	_trail_imm = ImmediateMesh.new()
	_trail_mi = MeshInstance3D.new()
	_trail_mi.mesh = _trail_imm
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tm.vertex_color_use_as_albedo = true
	tm.no_depth_test = false
	_trail_mi.material_override = tm
	_trail_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail_mi)

	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.5, 0.15)
	_glow.light_energy = 3.6
	_glow.omni_range = 10.0
	_glow.shadow_enabled = false
	_body.add_child(_glow)


func _face_flare() -> void:
	if _flare == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_flare.look_at(cam.global_position, Vector3.UP)


func _push_trail(p: Vector3) -> void:
	if _trail_pts.is_empty() or _trail_pts[_trail_pts.size() - 1].distance_to(p) > 0.18:
		_trail_pts.append(p)
	if _trail_pts.size() > 42:
		_trail_pts.remove_at(0)
	_draw_trail()


func _draw_trail() -> void:
	if _trail_imm == null or _trail_pts.size() < 2:
		return
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam else global_position
	_trail_imm.clear_surfaces()
	_strip(cam_pos, 0.11, Color(1.0, 0.22, 0.48, 0.38), Color(1.0, 0.45, 0.08, 0.55))
	_strip(cam_pos, 0.038, Color(1.0, 0.55, 0.12, 0.55), Color(1.0, 0.96, 0.72, 0.95))


func _strip(cam_pos: Vector3, width: float, tail: Color, head: Color) -> void:
	_trail_imm.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _trail_pts.size()
	for i in n:
		var a: Vector3 = _trail_pts[i]
		var b: Vector3 = _trail_pts[mini(i + 1, n - 1)]
		var along := b - a
		if along.length_squared() < 0.0001:
			along = Vector3.FORWARD
		var side := along.cross(cam_pos - a)
		if side.length_squared() < 0.0001:
			side = Vector3.UP
		var age := float(i) / float(maxi(n - 1, 1))
		var half := width * (0.35 + 0.65 * age) * side.normalized()
		var col := tail.lerp(head, age)
		col.a *= age
		_trail_imm.surface_set_color(col)
		_trail_imm.surface_add_vertex(to_local(a - half))
		_trail_imm.surface_set_color(col)
		_trail_imm.surface_add_vertex(to_local(a + half))
	_trail_imm.surface_end()


func _explode(at: Vector3, col: Color) -> void:
	_live = false
	if _body:
		_body.visible = false
	if _trail_mi:
		_trail_mi.visible = false
	global_position = at
	_burst = _make_burst_quad(Vector2(36.0, 36.0), col, randf() * 40.0 + 1.0)
	add_child(_burst)
	_halo = null
	_spawn_burst_layer(col, 110, 14.0, 1.35, true)
	_spawn_burst_layer(col.lerp(Color(1.0, 0.85, 0.3), 0.4), 55, 6.5, 1.7, false)
	if _glow == null:
		_glow = OmniLight3D.new()
		add_child(_glow)
	else:
		if _glow.get_parent() != self:
			_glow.reparent(self)
	_glow.light_color = col
	_glow.light_energy = 10.0
	_glow.omni_range = 26.0
	_glow.visible = true
	_burst_t = 0.0


func _make_burst_quad(size: Vector2, col: Color, seed: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = FW_SHADER
	mat.set_shader_parameter("burst_t", 0.0)
	mat.set_shader_parameter("burst_col", Vector3(col.r, col.g, col.b))
	mat.set_shader_parameter("seed", seed)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _burst_mat == null:
		_burst_mat = mat
	return mi


func _spawn_burst_layer(col: Color, amount: int, speed: float, life: float, trails: bool) -> void:
	var burst := GPUParticles3D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = amount
	burst.lifetime = life
	burst.local_coords = false
	burst.trail_enabled = trails
	if trails:
		burst.trail_lifetime = 0.45
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 180.0
	pm.initial_velocity_min = speed * 0.45
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0.0, -4.4 if trails else -2.2, 0.0)
	pm.scale_min = 0.04 if trails else 0.03
	pm.scale_max = 0.11 if trails else 0.07
	pm.hue_variation_min = -0.28
	pm.hue_variation_max = 0.4
	pm.color = col
	pm.color_ramp = _trail_gradient()
	burst.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.material = _spark_material()
	burst.draw_pass_1 = sm
	add_child(burst)
