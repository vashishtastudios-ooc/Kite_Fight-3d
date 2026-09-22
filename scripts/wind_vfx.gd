extends Node3D

## Ambient air: tumbling scraps blown downwind. When a gust front comes up
## behind the flyer, streaks and leaves race past the camera ahead of it, and
## street trees lean one after another as the front rolls out over the city.

const WindSys := preload("res://scripts/wind_system.gd")
const LEAF_PROCESS := preload("res://shaders/wind_particles.gdshader")
const LEAF_DRAW := preload("res://shaders/leaf_draw.gdshader")

var wind: WindSys
var _leaf_process: ShaderMaterial
var _dust: GPUParticles3D
var _leaves: GPUParticles3D
var _streaks: GPUParticles3D
var _streak_pm: ParticleProcessMaterial
var _gust_leaves: GPUParticles3D
var _gust_leaf_process: ShaderMaterial
var _trees: Array[Node3D] = []
var _tree_basis: Array[Basis] = []
var _tree_phase: Array[float] = []
var _tree_lean: Array[float] = []

const TREE_SWAY := 0.012         ## rad of idle sway
const TREE_GUST_LEAN := 0.07     ## rad a tree leans in a full gust


func setup(wind_in: WindSys, rooftop: Vector3) -> void:
	wind = wind_in
	_build_leaves(rooftop)
	_build_dust(rooftop)
	_build_streaks()
	_build_gust_leaves()
	## Trees are placed by the city before we are set up.
	for n in get_tree().get_nodes_in_group("sway_tree"):
		var t := n as Node3D
		if t == null:
			continue
		_trees.append(t)
		_tree_basis.append(t.basis)
		_tree_phase.append(randf() * TAU)
		_tree_lean.append(0.0)


func _process(delta: float) -> void:
	if wind == null:
		return
	var v: Vector3 = wind.last_sample
	if v.length() < 0.15:
		v = Vector3(0.15, 0.0, -8.0)
	if _leaf_process:
		_leaf_process.set_shader_parameter("wind_velocity", v)
	_update_gust_air(v)
	_update_trees(delta)
	if _dust:
		var pm := _dust.process_material as ParticleProcessMaterial
		if pm:
			pm.direction = v.normalized()
			pm.initial_velocity_min = wind.last_speed * 0.35
			pm.initial_velocity_max = wind.last_speed * 0.85


func _build_leaves(rooftop: Vector3) -> void:
	var p := GPUParticles3D.new()
	_leaves = p
	p.name = "WindLeaves"
	p.amount = 80
	p.amount_ratio = 0.4
	p.lifetime = 11.0
	p.preprocess = 6.0
	p.visibility_aabb = AABB(Vector3(-90, -10, -140), Vector3(180, 90, 240))
	p.local_coords = false
	_leaf_process = ShaderMaterial.new()
	_leaf_process.shader = LEAF_PROCESS
	_leaf_process.set_shader_parameter("box_emit_size", Vector3(58.0, 34.0, 90.0))
	p.process_material = _leaf_process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.28)
	var draw := ShaderMaterial.new()
	draw.shader = LEAF_DRAW
	quad.material = draw
	p.draw_pass_1 = quad
	p.position = Vector3(rooftop.x + 4.0, rooftop.y + 14.0, rooftop.z - 38.0)
	add_child(p)


func _build_dust(rooftop: Vector3) -> void:
	_dust = GPUParticles3D.new()
	_dust.name = "WindDust"
	_dust.amount = 40
	_dust.lifetime = 4.5
	_dust.preprocess = 2.5
	_dust.visibility_aabb = AABB(Vector3(-70, -8, -100), Vector3(140, 70, 180))
	_dust.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22.0, 12.0, 28.0)
	pm.direction = Vector3(0.0, 0.0, -1.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 8.0
	pm.gravity = Vector3(0.0, -0.4, 0.0)
	pm.scale_min = 0.02
	pm.scale_max = 0.045
	pm.color = Color(0.85, 0.90, 0.98, 0.12)
	_dust.process_material = pm
	var sph := SphereMesh.new()
	sph.radius = 0.04
	sph.height = 0.08
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.88, 0.92, 0.98, 0.14)
	mat.disable_receive_shadows = true
	sph.material = mat
	_dust.draw_pass_1 = sph
	_dust.position = Vector3(rooftop.x, rooftop.y + 8.0, rooftop.z - 18.0)
	add_child(_dust)


## Streaks and leaves that race past the camera from behind, thin while the
## front is on its way and thick once it arrives.
func _update_gust_air(v: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d: Vector3 = wind.wind_dir()
	var here := cam.global_position
	var g: float = wind.gust01_at(here)
	var warn: float = wind.gust_incoming
	var level := maxf(pow(warn, 1.6) * 0.55, g)
	var speed := maxf(v.length(), 6.0) * (1.4 + g * 0.6)
	var upwind := here - d * 14.0 + Vector3.UP * 3.0
	_streaks.global_position = upwind
	_streaks.emitting = level > 0.03
	_streaks.amount_ratio = clampf(level, 0.0, 1.0)
	_streak_pm.direction = (d + Vector3.UP * 0.04).normalized()
	_streak_pm.initial_velocity_min = speed * 0.85
	_streak_pm.initial_velocity_max = speed * 1.15
	_gust_leaves.global_position = upwind
	_gust_leaves.emitting = level > 0.08
	_gust_leaves.amount_ratio = clampf(level, 0.0, 1.0)
	_gust_leaf_process.set_shader_parameter("wind_velocity", d * speed * 1.2)
	if _leaves:
		_leaves.amount_ratio = clampf(0.4 + g * 0.6, 0.0, 1.0)


## Each tree leans downwind when the front reaches it, and springs back.
func _update_trees(delta: float) -> void:
	if _trees.is_empty():
		return
	var d: Vector3 = wind.wind_dir()
	var axis := Vector3.UP.cross(d).normalized()
	var t: float = wind.time
	for i in _trees.size():
		var tree := _trees[i]
		if not is_instance_valid(tree):
			continue
		var g: float = wind.gust01_at(tree.global_position)
		_tree_lean[i] = move_toward(_tree_lean[i], g, delta * (2.2 if g > _tree_lean[i] else 0.9))
		var lean := _tree_lean[i]
		var sway := sin(t * 1.3 + _tree_phase[i]) * TREE_SWAY * (1.0 + lean * 1.5)
		sway += sin(t * 5.1 + _tree_phase[i] * 2.0) * 0.01 * lean
		## Lean away from the wind: rotate so the crown moves downwind.
		var ang := -(lean * TREE_GUST_LEAN + sway)
		tree.basis = Basis(axis, ang) * _tree_basis[i]


func _build_streaks() -> void:
	_streaks = GPUParticles3D.new()
	_streaks.name = "GustStreaks"
	_streaks.amount = 48
	_streaks.lifetime = 1.8
	_streaks.local_coords = false
	_streaks.emitting = false
	_streaks.visibility_aabb = AABB(Vector3(-60, -30, -80), Vector3(120, 60, 160))
	_streak_pm = ParticleProcessMaterial.new()
	_streak_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_streak_pm.emission_box_extents = Vector3(14.0, 7.0, 6.0)
	_streak_pm.direction = Vector3(0.0, 0.0, -1.0)
	_streak_pm.spread = 3.0
	_streak_pm.gravity = Vector3.ZERO
	_streak_pm.particle_flag_align_y = true
	_streak_pm.scale_min = 0.7
	_streak_pm.scale_max = 1.3
	var ramp_g := Gradient.new()
	ramp_g.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	ramp_g.colors = PackedColorArray([
		Color(1.0, 0.97, 0.9, 0.0),
		Color(1.0, 0.97, 0.9, 0.22),
		Color(1.0, 0.95, 0.86, 0.13),
		Color(1.0, 0.95, 0.86, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = ramp_g
	_streak_pm.color_ramp = ramp
	_streaks.process_material = _streak_pm
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.012
	mesh.height = 1.1
	mesh.radial_segments = 4
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.disable_fog = true
	mesh.material = mat
	_streaks.draw_pass_1 = mesh
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_streaks)


func _build_gust_leaves() -> void:
	_gust_leaves = GPUParticles3D.new()
	_gust_leaves.name = "GustLeaves"
	_gust_leaves.amount = 34
	_gust_leaves.lifetime = 2.6
	_gust_leaves.local_coords = false
	_gust_leaves.emitting = false
	_gust_leaves.visibility_aabb = AABB(Vector3(-60, -30, -80), Vector3(120, 60, 160))
	_gust_leaf_process = ShaderMaterial.new()
	_gust_leaf_process.shader = LEAF_PROCESS
	_gust_leaf_process.set_shader_parameter("box_emit_size", Vector3(18.0, 8.0, 8.0))
	_gust_leaf_process.set_shader_parameter("forward_speed_min", 4.0)
	_gust_leaf_process.set_shader_parameter("forward_speed_max", 9.0)
	_gust_leaves.process_material = _gust_leaf_process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.18)
	var draw := ShaderMaterial.new()
	draw.shader = LEAF_DRAW
	quad.material = draw
	_gust_leaves.draw_pass_1 = quad
	_gust_leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gust_leaves)
