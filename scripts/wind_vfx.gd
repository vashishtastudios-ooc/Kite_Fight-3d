extends Node3D

## Ambient air: tumbling scraps blown downwind.

const WindSys := preload("res://scripts/wind_system.gd")
const LEAF_PROCESS := preload("res://shaders/wind_particles.gdshader")
const LEAF_DRAW := preload("res://shaders/leaf_draw.gdshader")

var wind: WindSys
var _leaf_process: ShaderMaterial
var _dust: GPUParticles3D


func setup(wind_in: WindSys, rooftop: Vector3) -> void:
	wind = wind_in
	_build_leaves(rooftop)
	_build_dust(rooftop)


func _process(_delta: float) -> void:
	if wind == null:
		return
	var v: Vector3 = wind.last_sample
	if v.length() < 0.15:
		v = Vector3(0.15, 0.0, -8.0)
	if _leaf_process:
		_leaf_process.set_shader_parameter("wind_velocity", v)
	if _dust:
		var pm := _dust.process_material as ParticleProcessMaterial
		if pm:
			pm.direction = v.normalized()
			pm.initial_velocity_min = wind.last_speed * 0.35
			pm.initial_velocity_max = wind.last_speed * 0.85


func _build_leaves(rooftop: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.name = "WindLeaves"
	p.amount = 36
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
