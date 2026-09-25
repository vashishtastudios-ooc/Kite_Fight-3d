extends "res://scripts/map_base.gd"

## Chandni Jaipur: a lantern-lit terrace above a lake and an original stepped
## palace. Open water preserves the kite battle arena; the city wraps behind.
const Kit := preload("res://scripts/build_kit.gd")
const PALACE := preload("res://assets/map_art/moon_palace.glb")
const LANTERN := preload("res://assets/map_art/brass_lantern.glb")
const HAVELI := preload("res://assets/map_art/flight_terrace.glb")
const RIDGE := preload("res://shaders/alto_ridge.gdshader")
var _kit: Kit

func build() -> void:
	_kit = Kit.new(self)
	rooftop_height = 24.0
	spawn_position = Vector3(0, 24.3, 92)
	rooftop_bounds = Rect2(-9, 82, 18, 22)
	player_building_aabb = AABB(Vector3(-11, 0, 80), Vector3(22, 24, 26))
	_roof(Vector3(0, 0, 93), 24.0)
	_roof(Vector3(-35, 0, 94), 22.0)
	_city()
	_waterfront()
	_lakeside_quarters()
	_hills()
	for p in [Vector3(30, 5, 46), Vector3(-50, 5, 40), Vector3(100, 5, 30)]:
		rocket_pads.append(p)

func rival_hand_position() -> Vector3:
	return Vector3(-35, 22.3, 94)

func rival_roof_bounds() -> Rect2:
	return Rect2(-44, 83, 18, 22)

func palace_watch_spot() -> Vector3:
	return Vector3(6, 24, 98)

func nearest_building_chop(pos: Vector3) -> float:
	return clampf((30.0 - pos.y) / 30.0, 0.0, 1.0) if pos.z > 65.0 else 0.0

func _roof(p: Vector3, deck: float) -> void:
	var model := HAVELI.instantiate() as Node3D
	add_child(model)
	model.position = p + Vector3(0, deck - 10.0, 0)
	_kit.box(Vector3(22,deck-10.0,26),p+Vector3(0,(deck-10.0)*.5,0),_kit.mat(Color(.32,.22,.29)))
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(22, 1, 26)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	body.position = p + Vector3(0, deck - 0.5, 0)
	building_aabbs.append(AABB(p + Vector3(-11, 0, -13), Vector3(22, deck, 26)))
	for x in [-9.5, 9.5]:
		for z in [-11.5, 11.5]:
			_lantern(p + Vector3(x, deck + 1.0, z), 0.8)
	var light := OmniLight3D.new()
	light.position = p + Vector3(0, deck + 3, 0)
	light.light_color = Color(1.0, 0.56, 0.27)
	light.light_energy = 2.0
	light.omni_range = 20.0
	add_child(light)

func _lantern(pos: Vector3, size: float = 1.0) -> void:
	var l := LANTERN.instantiate() as Node3D
	add_child(l)
	l.position = pos
	l.scale = Vector3.ONE * size

func _city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 92114
	var stone := _kit.mat(Color(0.21, 0.16, 0.28))
	_kit.box(Vector3(650, 5, 480), Vector3(0, 1.5, 300), stone)
	for ix in range(-11, 12):
		for iz in range(0, 13):
			var x := float(ix) * 24.0 + rng.randf_range(-3, 3)
			var z := 96.0 + float(iz) * 25.0
			if iz < 2 and x > -60.0 and x < 28.0:
				continue
			var h := rng.randf_range(8, 24)
			var w := rng.randf_range(13, 20)
			var d := rng.randf_range(12, 19)
			var col := Color(0.30, 0.17, 0.27).lerp(Color(0.55, 0.29, 0.38), rng.randf())
			_kit.box(Vector3(w, h, d), Vector3(x, 4+h/2, z), _kit.mat(col))
			_kit.box(Vector3(w+1, 0.55, d+1), Vector3(x, h+4, z), stone)
			building_aabbs.append(AABB(Vector3(x-w/2, 4, z-d/2), Vector3(w,h,d)))
			for floor_id in range(1, int(h/4.0)):
				for win in 3:
					if rng.randf() < 0.32:
						continue
					_kit.box(Vector3(0.85, 1.7, 0.12), Vector3(x-4+win*4, 4+floor_id*4, z-d/2-0.08), _kit.mat(Color(1,.43,.13), 2.0))
			if (ix + iz) % 5 == 0:
				_kit.sphere(2.8, 4, Vector3(x,h+5,z), _kit.mat(Color(.16,.28,.32)))
			if iz < 3:
				_lantern(Vector3(x,h+4.3,z), 0.9)
	# Illuminated ghats run across the waterfront, below the flight deck.
	for step in 7:
		_kit.box(Vector3(590, 0.8, 2.7), Vector3(0, 0.4+step*.55, 46+step*2.5), stone)
	for i in range(-18,19):
		_lantern(Vector3(i*15,4.2,64), 1.15)
	# Hanging strings stay to the sides of the player, clear of the launch.
	for side in [-1,1]:
		for i in 15:
			var x: float = side * (23.0 + i*3.2)
			var y := 26.0 - sin(float(i)/14.0*PI)*3.0
			_kit.sphere(.13,.26,Vector3(x,y,113),_kit.mat(Color(1,.52,.18),3.0))

func _waterfront() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1800, 1700)
	var water := MeshInstance3D.new()
	water.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/royal_water.gdshader")
	water.material_override = mat
	water.position = Vector3(0, 0.15, -785)
	add_child(water)
	var palace := PALACE.instantiate() as Node3D
	add_child(palace)
	palace.position = Vector3(-105, 2, -210)
	palace.scale = Vector3.ONE * 1.8
	building_aabbs.append(AABB(Vector3(-174,0,-237),Vector3(138,74,59)))
	# Low islands and a distant secondary pavilion give an asymmetric skyline.
	_kit.cyl(82,75,4,Vector3(-105,0,-210),_kit.mat(Color(.16,.14,.24)),48)
	var pavilion := preload("res://assets/map_art/oasis_pavilion.glb").instantiate() as Node3D
	add_child(pavilion)
	pavilion.position = Vector3(190,2,-320)
	pavilion.scale = Vector3.ONE * 3.0
	_kit.cyl(30,27,3,Vector3(190,.2,-320),_kit.mat(Color(.14,.14,.24)),32)
	for i in 19:
		var a := float(i)/18.0 * PI
		_lantern(Vector3(-105+cos(a)*70,2.1,-210+sin(a)*34),1.4)

func _lakeside_quarters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6026
	var wall := _kit.mat(Color(.28,.19,.30))
	var trim := _kit.mat(Color(.36,.30,.40))
	var glow := _kit.mat(Color(1,.42,.12),1.6)
	for side in [-1.0,1.0]:
		for row in 4:
			var z := 22.0-row*58.0
			var x: float = side*(170.0+row*35.0)
			_kit.cyl(65,61,6,Vector3(x,0,z),wall,24)
			for i in 5:
				var bx: float = x+(i-2)*19
				var bz := z+rng.randf_range(-13,13)
				var h := rng.randf_range(9,23)
				_kit.box(Vector3(15,h,17),Vector3(bx,3+h*.5,bz),wall)
				_kit.box(Vector3(16,.6,18),Vector3(bx,3+h,bz),trim)
				building_aabbs.append(AABB(Vector3(bx-7.5,3,bz-8.5),Vector3(15,h,17)))
				for floor_id in range(1,int(h/4)):
					for w in 3:
						_kit.box(Vector3(.8,1.4,.15),Vector3(bx-4+w*4,3+floor_id*4,bz+8.6),glow)
				if i%2==0:
					_kit.sphere(2.5,3.8,Vector3(bx,h+4,bz),trim)
			for i in 9:
				_lantern(Vector3(x-52+i*13,3.2,z+36),.85)

func _hills() -> void:
	for layer in 4:
		var radius := 720.0 + layer*270.0
		var noise := FastNoiseLite.new()
		noise.seed = 191+layer*31
		noise.frequency = 1.5
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 240:
			var a := float(i)/240.0*TAU
			var b := float(i+1)/240.0*TAU
			var p := Vector3(sin(a)*radius,0,cos(a)*radius)
			var q := Vector3(sin(b)*radius,0,cos(b)*radius)
			var ph := 75.0+layer*38.0+noise.get_noise_2d(sin(a)*3,cos(a)*3)*80.0
			var qh := 75.0+layer*38.0+noise.get_noise_2d(sin(b)*3,cos(b)*3)*80.0
			for v in [p+Vector3(0,-12,0),p+Vector3(0,ph,0),q+Vector3(0,qh,0),p+Vector3(0,-12,0),q+Vector3(0,qh,0),q+Vector3(0,-12,0)]:
				st.add_vertex(v)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := ShaderMaterial.new()
		m.shader = RIDGE
		m.set_shader_parameter("body_col",Color(.115+layer*.036,.11+layer*.026,.20+layer*.038))
		m.set_shader_parameter("peak_col",Color(.16+layer*.030,.13+layer*.027,.25+layer*.029))
		m.set_shader_parameter("haze_col",Color(.28,.20,.32))
		m.set_shader_parameter("top_y",150.0+layer*40.0)
		m.set_shader_parameter("foot_haze",.30)
		m.set_shader_parameter("sun_warm",0.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

func configure_world(env: Environment, sun: DirectionalLight3D) -> void:
	var sky := ShaderMaterial.new()
	sky.shader = preload("res://shaders/jaipur_night_sky.gdshader")
	env.sky.sky_material = sky
	sun.rotation_degrees = Vector3(-25, -28, 0)
	sun.light_color = Color(.66,.75,1.0)
	sun.light_energy = 0.48
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.51,.53,.69)
	env.ambient_light_energy = 0.55
	env.fog_light_color = Color(.21,.15,.29)
	env.fog_depth_begin = 120
	env.fog_depth_end = 1500
	env.fog_aerial_perspective = 0.25
	env.fog_sky_affect = 0.0
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0
	env.adjustment_brightness = 1.02
	env.adjustment_saturation = 1.10
