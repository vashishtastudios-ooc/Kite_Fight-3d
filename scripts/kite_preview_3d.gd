extends SubViewportContainer

## Shop / picker preview for the sculpted (GLB) sails: the real model, nose up,
## swaying gently as if hanging in a breeze, lit like the dusk roof. Paper
## kites use the flat painted preview instead (KiteSkins.make_preview).

var _scene: PackedScene
var _vp: SubViewport
var _pivot: Node3D
var _t: float = 0.0


func setup(scene: PackedScene) -> void:
	_scene = scene
	if is_inside_tree():
		_build()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = randf() * TAU
	if _scene and _vp == null:
		_build()


func _process(delta: float) -> void:
	if _pivot == null or not is_visible_in_tree():
		return
	_t += delta
	## A kite on a short line in light air: a slow yaw, a lean, a small bob.
	_pivot.rotation = Vector3(sin(_t * 0.9) * 0.08, sin(_t * 0.55) * 0.42, sin(_t * 0.7) * 0.12)
	_pivot.position.y = sin(_t * 1.3) * 0.03


func _build() -> void:
	stretch = true
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.62, 0.66)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.88, 0.74)
	key.light_energy = 1.3
	key.rotation_degrees = Vector3(-24.0, 24.0, 0.0)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(1.0, 0.55, 0.3)
	rim.light_energy = 1.6
	rim.rotation_degrees = Vector3(-10.0, 165.0, 0.0)
	_vp.add_child(rim)

	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	var model := _scene.instantiate() as Node3D
	if model == null:
		return
	_pivot.add_child(model)
	## The GLB stands in XY with its nose up (+Y): fit it to a 1 m box, centred.
	model.force_update_transform()
	var aabb := _aabb(model)
	var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if longest < 0.01:
		longest = 1.0
	model.scale *= 1.0 / longest
	model.force_update_transform()
	aabb = _aabb(model)
	model.position -= aabb.get_center()

	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.position = Vector3(0.0, 0.0, 1.95)
	_vp.add_child(cam)
	cam.current = true


func _aabb(n: Node) -> AABB:
	var acc := AABB()
	var first := true
	if n is VisualInstance3D:
		acc = (n as Node3D).global_transform * (n as VisualInstance3D).get_aabb()
		first = false
	for c in n.get_children():
		var sub := _aabb(c)
		if sub.size.length_squared() < 0.0001:
			continue
		if first:
			acc = sub
			first = false
		else:
			acc = acc.merge(sub)
	return acc
