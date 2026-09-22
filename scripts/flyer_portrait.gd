extends SubViewportContainer

## Live bust of a flyer for the character cards: the real rooftop model in its
## idle, lit like the dusk roof (warm key, orange rim from behind), on a soft
## glow disc in the card's colour. Renders only while the card is on screen.

const PersonSc := preload("res://scripts/rooftop_person.gd")

var _vp: SubViewport
var _person: Node3D
var _body: PackedScene
var _glow: Color


## Cards are built before the menu joins the scene, so the 3D set is only
## assembled once this control is actually in the tree.
func setup(body: PackedScene, glow: Color) -> void:
	_body = body
	_glow = glow
	if is_inside_tree():
		_build()


func _ready() -> void:
	if _body and _vp == null:
		_build()


func _build() -> void:
	var body := _body
	var glow := _glow
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.52, 0.58)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.7)
	key.light_energy = 1.35
	key.rotation_degrees = Vector3(-22.0, 28.0, 0.0)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(1.0, 0.52, 0.28)
	rim.light_energy = 2.2
	rim.rotation_degrees = Vector3(-12.0, 160.0, 0.0)
	_vp.add_child(rim)

	var cam := Camera3D.new()
	## Head and shoulders, eye line a little above centre.
	cam.fov = 17.0
	cam.position = Vector3(0.0, 1.44, 2.3)
	_vp.add_child(cam)
	cam.look_at(Vector3(0.0, 1.34, 0.0), Vector3.UP)
	cam.current = true

	_person = PersonSc.new()
	_vp.add_child(_person)
	_person.setup(Vector3.ZERO, cam.global_position, null, body, false, true)

	## Glow disc behind the bust, in the card's colour.
	var disc := ColorRect.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.show_behind_parent = true
	disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec4 glow : source_color;
void fragment() {
	float d = length(UV - vec2(0.5, 0.52)) * 2.0;
	float a = smoothstep(1.0, 0.15, d) * 0.55;
	COLOR = vec4(glow.rgb, a * glow.a);
}
"""
	mat.shader = sh
	mat.set_shader_parameter("glow", glow)
	disc.material = mat
	add_child(disc)
	move_child(disc, 0)
