extends "res://scripts/map_base.gd"

## Tukkal Raat — the night of lantern kites, drawn after Alto's moonrise. A
## pink-violet glow rises from the horizon round a big pale moon; a thin
## crescent hangs higher among the stars. A ruined aqueduct crosses the
## valley ahead with a temple on its back, strung with lanterns; dark cliffs
## with wind-bent trees frame the view; hot-air balloons drift far off.
##
## At night every kite string carries tukkals — paper lanterns hung below the
## kite — so both kites glow against the dark. The aqueduct's arches are open:
## a kite can thread them, but its piers and decks are solid stone.

const TERRAIN_SHADER := preload("res://shaders/alto_terrain.gdshader")
const RIDGE_SHADER := preload("res://shaders/alto_ridge.gdshader")
const MIST_SHADER := preload("res://shaders/valley_mist.gdshader")
const SKY_SHADER := preload("res://shaders/tukkal_sky.gdshader")
const PropsSc := preload("res://scripts/tukkal_props.gd")

const DECK := 38.0
const HOME := Vector2(0.0, 92.0)
const TERRACE := Rect2(-12.0, 80.0, 24.0, 28.0)
const RIVAL := Vector2(-46.0, 100.0)
const RIVAL_DECK := 34.0
const RIVAL_R := 6.5
const FLOOR := 2.5
const AQUEDUCT_Z := -160.0
const AQUEDUCT_LEN := 238.0
const MIST_Y := 9.0

const GRID_MIN := Vector2(-560.0, -620.0)
const GRID_MAX := Vector2(560.0, 520.0)
const GRID_STEP := 6.5

const LIFT_MAX := 7.0
const LIFT_REACH := 55.0

const HAZE := Color(0.62, 0.36, 0.60)
const MOON_YAW := 186.0
const MOON_PITCH := 13.0

var _noise: FastNoiseLite
var _detail: FastNoiseLite
var _wind_dir := Vector3(sin(deg_to_rad(8.0)), 0.0, -cos(deg_to_rad(8.0)))
var _wind: Node
var _props: PropsSc
var _balloons: Array[Node3D] = []
var _t: float = 0.0


func build() -> void:
	night = true
	_noise = FastNoiseLite.new()
	_noise.seed = 9091
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.004
	_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_noise.fractal_octaves = 4
	_detail = FastNoiseLite.new()
	_detail.seed = 404
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 0.03

	rooftop_height = DECK
	spawn_position = Vector3(HOME.x, DECK + 0.3, HOME.y)
	rooftop_bounds = Rect2(TERRACE.position.x + 2.0, TERRACE.position.y + 2.0, TERRACE.size.x - 4.0, TERRACE.size.y - 6.0)
	player_building_aabb = AABB(Vector3(TERRACE.position.x, 0.0, TERRACE.position.y), Vector3(TERRACE.size.x, DECK, TERRACE.size.y))

	_props = PropsSc.new(self)
	_build_terrain()
	_build_far_ranges()
	_build_mist()
	_build_terraces()
	building_aabbs.append_array(_props.aqueduct(Vector3(0.0, height_at(0.0, AQUEDUCT_Z) - 0.8, AQUEDUCT_Z), _props.mat(PropsSc.STONE)))
	_build_crags()
	_build_trees()
	var brng := RandomNumberGenerator.new()
	brng.seed = 616
	_balloons = _props.balloons(brng, [
		Vector3(-150.0, 70.0, -300.0), Vector3(95.0, 88.0, -380.0), Vector3(210.0, 64.0, -250.0),
		Vector3(-240.0, 95.0, -420.0), Vector3(30.0, 110.0, -520.0),
	])
	_plan_rocket_pads()


func configure_world(env: Environment, sun: DirectionalLight3D) -> void:
	## Moonlight from low ahead: everything between you and the moon is a
	## silhouette with a pink rim.
	sun.rotation_degrees = Vector3(-MOON_PITCH, MOON_YAW, 0.0)
	sun.light_color = Color(0.96, 0.70, 0.86)
	sun.light_energy = 0.55
	sun.directional_shadow_max_distance = 220.0
	var sky := ShaderMaterial.new()
	sky.shader = SKY_SHADER
	## The moon sits where the moonlight comes from: +Z of the light's basis.
	var md := sun.global_transform.basis.z.normalized()
	sky.set_shader_parameter("moon_dir", md)
	if env.sky:
		env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.40, 0.28, 0.58)
	env.ambient_light_energy = 0.7
	env.fog_light_color = HAZE
	env.fog_depth_begin = 40.0
	env.fog_depth_end = 900.0
	env.fog_depth_curve = 1.2
	env.fog_aerial_perspective = 0.8
	env.fog_sky_affect = 0.25
	env.fog_height = MIST_Y + 4.0
	env.fog_height_density = 0.03
	env.ssao_enabled = false
	## Lanterns bloom; the glow is half the picture at night.
	env.glow_enabled = true
	env.glow_intensity = 0.95
	env.glow_bloom = 0.3
	env.glow_hdr_threshold = 0.7
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12


func set_wind(w: Node) -> void:
	_wind = w


func _process(delta: float) -> void:
	_t += delta
	if _wind and _wind.has_method("wind_dir"):
		_wind_dir = _wind.wind_dir()
	## Balloons drift slowly downwind and bob, wrapping back when too far.
	for i in _balloons.size():
		var b := _balloons[i]
		b.position += _wind_dir * 0.9 * delta
		b.position.y += sin(_t * 0.25 + float(i) * 1.7) * 0.25 * delta
		if b.position.z < -700.0:
			b.position.z += 500.0


## Layered crags standing on the cliffs to either side, framing the valley
## the way the painting's foreground rocks do; each carries a bonsai.
func _build_crags() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var spots := [
		[Vector2(-78.0, 40.0), true, 1.0], [Vector2(84.0, 30.0), false, 1.1],
		[Vector2(-150.0, -40.0), false, 1.3], [Vector2(160.0, -70.0), true, 1.2],
		[Vector2(-170.0, -210.0), true, 1.5], [Vector2(175.0, -230.0), false, 1.4],
	]
	for sp in spots:
		var at: Vector2 = sp[0]
		## Stand on the lowest ground under the footprint, so no edge floats.
		var reach := 12.0 * float(sp[2])
		var g := height_at(at.x, at.y)
		for k in 8:
			var a := TAU * float(k) / 8.0
			g = minf(g, height_at(at.x + cos(a) * reach, at.y + sin(a) * reach))
		building_aabbs.append(_props.crag(Vector3(at.x, g - 2.0, at.y), sp[1], rng, sp[2]))


# ── Map contract ─────────────────────────────────────────────────────────────

func rival_hand_position() -> Vector3:
	return Vector3(RIVAL.x, RIVAL_DECK + 0.3, RIVAL.y)


func rival_roof_bounds() -> Rect2:
	return Rect2(RIVAL.x - 4.0, RIVAL.y - 4.0, 8.0, 8.0)


func palace_watch_spot() -> Vector3:
	return Vector3(HOME.x + 6.0, DECK, HOME.y + 8.0)


func nearest_building_chop(pos: Vector3) -> float:
	var above := pos.y - height_at(pos.x, pos.z)
	return clampf(1.0 - above / 16.0, 0.0, 1.0)


## Wind meeting a cliff face lifts, as in the hills.
func lift_at(pos: Vector3) -> float:
	var ground := height_at(pos.x, pos.z)
	var above := pos.y - ground
	if above < 0.0 or above > LIFT_REACH:
		return 0.0
	var d := _wind_dir
	var ahead := height_at(pos.x + d.x * 12.0, pos.z + d.z * 12.0)
	var behind := height_at(pos.x - d.x * 12.0, pos.z - d.z * 12.0)
	var rise := (ahead - behind) / 24.0
	if rise <= 0.05:
		return 0.0
	return LIFT_MAX * clampf(rise, 0.0, 1.0) * (1.0 - above / LIFT_REACH)


func is_solid(p: Vector3) -> bool:
	if p.y < 1.0:
		return true
	if TERRACE.has_point(Vector2(p.x, p.z)):
		return p.y < DECK - 0.2
	if Vector2(p.x, p.z).distance_to(RIVAL) < RIVAL_R:
		return p.y < RIVAL_DECK - 0.2
	if p.y < height_at(p.x, p.z) + 0.4:
		return true
	for aabb in building_aabbs:
		if aabb.grow(0.3).has_point(p):
			return true
	return false


# ── Land ─────────────────────────────────────────────────────────────────────

## A broad valley running away from the terrace, closed by steep dark cliffs
## on both sides; the flyers stand on two spurs at its head.
func height_at(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	var d := _detail.get_noise_2d(x, z)
	var cx := sin(z * 0.005) * 20.0
	## Cliffs: steep, rising fast once past the valley floor's edge.
	var side := smoothstep(125.0, 190.0, absf(x - cx)) * (46.0 + n * 52.0)
	var back := smoothstep(125.0, 230.0, z) * (40.0 + n * 36.0)
	var far := smoothstep(-330.0, -520.0, z) * (30.0 + n * 40.0)
	var h := FLOOR + maxf(side, maxf(back, far)) + d * 1.8
	h = maxf(h, _spur(x, z, TERRACE.get_center(), DECK, 15.0, 58.0))
	h = maxf(h, _spur(x, z, RIVAL, RIVAL_DECK, RIVAL_R, 46.0))
	return h


## A cliff spur with a flat top, dropping steeply to the valley.
func _spur(x: float, z: float, c: Vector2, top: float, flat: float, reach: float) -> float:
	var dx := x - c.x
	var dz := (z - c.y) * (0.6 if z > c.y else 1.0)
	var r := sqrt(dx * dx + dz * dz)
	if r <= flat:
		return top
	var t := clampf((r - flat) / reach, 0.0, 1.0)
	var fall := 1.0 - pow(1.0 - t, 2.4)
	var rough := _detail.get_noise_2d(x * 1.6, z * 1.6) * 3.0 * t * (1.0 - t) * 4.0
	return lerpf(top, FLOOR, fall) + rough


func _build_terrain() -> void:
	var nx := int((GRID_MAX.x - GRID_MIN.x) / GRID_STEP) + 1
	var nz := int((GRID_MAX.y - GRID_MIN.y) / GRID_STEP) + 1
	var verts := PackedVector3Array()
	verts.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var x := GRID_MIN.x + float(ix) * GRID_STEP
			var z := GRID_MIN.y + float(iz) * GRID_STEP
			var y := height_at(x, z)
			if TERRACE.grow(1.0).has_point(Vector2(x, z)) or Vector2(x, z).distance_to(RIVAL) < RIVAL_R + 1.0:
				y -= 0.45
			verts[iz * nx + ix] = Vector3(x, y, z)
	var idx := PackedInt32Array()
	for iz in nz - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			var b := a + 1
			var c := a + nx
			var e := c + 1
			idx.append_array([a, b, c, b, e, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	## Night rock: violet floor, near-black cliffs, a faint pink catch on the
	## crests where the moonglow reaches.
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("floor_col", Color(0.13, 0.08, 0.19))
	mat.set_shader_parameter("grass_col", Color(0.16, 0.10, 0.22))
	mat.set_shader_parameter("rock_col", Color(0.10, 0.06, 0.15))
	mat.set_shader_parameter("crest_col", Color(0.42, 0.24, 0.42))
	mat.set_shader_parameter("crest_h", 90.0)
	mat.set_shader_parameter("snow_h", 999.0)
	mat.set_shader_parameter("strata", 0.6)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	add_child(mi)


## Four violet ranges ringing the horizon; the nearer two carry the spires
## and domes of a sleeping city, cut out against the glow.
func _build_far_ranges() -> void:
	var layers := [
		{"r": 640.0, "base": 10.0, "top": 120.0, "body": Color(0.16, 0.09, 0.22), "peak": Color(0.24, 0.13, 0.30), "haze": 0.3, "seed": 3, "spires": 16},
		{"r": 900.0, "base": 14.0, "top": 170.0, "body": Color(0.28, 0.15, 0.34), "peak": Color(0.38, 0.20, 0.42), "haze": 0.45, "seed": 13, "spires": 10},
		{"r": 1250.0, "base": 18.0, "top": 240.0, "body": Color(0.44, 0.24, 0.46), "peak": Color(0.54, 0.30, 0.52), "haze": 0.55, "seed": 23, "spires": 0},
		{"r": 1750.0, "base": 22.0, "top": 320.0, "body": Color(0.62, 0.34, 0.56), "peak": Color(0.72, 0.42, 0.62), "haze": 0.65, "seed": 33, "spires": 0},
	]
	for L in layers:
		_range_curtain(L)


func _range_curtain(L: Dictionary) -> void:
	var rn := FastNoiseLite.new()
	rn.seed = int(L["seed"])
	rn.noise_type = FastNoiseLite.TYPE_SIMPLEX
	rn.frequency = 1.1
	rn.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	rn.fractal_octaves = 3
	var r: float = L["r"]
	var base: float = L["base"]
	var top: float = L["top"]
	var spires: int = L["spires"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(L["seed"]) * 7
	var segs := 360
	## Spire slots: a few segment indices that rise into a tower or dome.
	var towers := {}
	for i in spires:
		var at := rng.randi_range(0, segs - 1)
		towers[at] = rng.randf_range(0.25, 0.6) * (top - base)
		towers[(at + 1) % segs] = towers[at] * rng.randf_range(0.6, 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_b := Vector3.ZERO
	var prev_t := Vector3.ZERO
	for i in segs + 1:
		var a := lerpf(-PI, PI, float(i) / float(segs))
		var dir := Vector3(sin(a), 0.0, -cos(a))
		var peak := pow(rn.get_noise_1d(a * 3.0) * 0.5 + 0.5, 1.4)
		var y := base + (top - base) * (0.3 + 0.5 * peak)
		if towers.has(i % segs):
			y += towers[i % segs]
		var p := Vector3(HOME.x, 0.0, HOME.y) + dir * r
		var b := Vector3(p.x, -20.0, p.z)
		var t := Vector3(p.x, y, p.z)
		if i > 0:
			for v in [prev_b, prev_t, t, prev_b, t, b]:
				st.add_vertex(v)
		prev_b = b
		prev_t = t
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = RIDGE_SHADER
	mat.set_shader_parameter("body_col", L["body"])
	mat.set_shader_parameter("peak_col", L["peak"])
	mat.set_shader_parameter("haze_col", HAZE)
	mat.set_shader_parameter("base_y", base)
	mat.set_shader_parameter("top_y", top)
	mat.set_shader_parameter("foot_haze", L["haze"])
	mat.set_shader_parameter("sun_warm", 0.0)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Range%d" % int(r)
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 200.0
	add_child(mi)


func _build_mist() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(520.0, 700.0)
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var fn := FastNoiseLite.new()
	fn.seed = 51
	fn.frequency = 0.012
	fn.fractal_octaves = 4
	noise.noise = fn
	var mat := ShaderMaterial.new()
	mat.shader = MIST_SHADER
	mat.set_shader_parameter("noise_tex", noise)
	mat.set_shader_parameter("mist_col", Color(0.64, 0.40, 0.66))
	mat.set_shader_parameter("opacity", 0.34)
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "ValleyMist"
	mi.mesh = plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, MIST_Y, -160.0)
	add_child(mi)


# ── Terraces, trees, pads ────────────────────────────────────────────────────

func _build_terraces() -> void:
	var P := _props
	var stone := P.mat(PropsSc.STONE_LIT)
	var dark := P.mat(PropsSc.STONE)
	var c := TERRACE.get_center()
	## Stone terrace on a battered base down into the cliff. The base stops
	## under the deck slab, never level with its top (the two would z-fight).
	P.frustum(TERRACE.size + Vector2(7.0, 7.0), TERRACE.size, 14.0, Vector3(c.x, DECK - 14.6, c.y), dark)
	var deck := P.box(Vector3(TERRACE.size.x, 1.0, TERRACE.size.y), Vector3(c.x, DECK - 0.5, c.y), stone)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(TERRACE.size.x, 1.0, TERRACE.size.y)
	cs.shape = shape
	body.add_child(cs)
	deck.add_child(body)
	## Low wall on the flanks and back — the front stays open to the valley.
	P.box(Vector3(0.5, 0.9, TERRACE.size.y), Vector3(TERRACE.position.x + 0.25, DECK + 0.45, c.y), stone)
	P.box(Vector3(0.5, 0.9, TERRACE.size.y), Vector3(TERRACE.end.x - 0.25, DECK + 0.45, c.y), stone)
	P.box(Vector3(TERRACE.size.x, 0.9, 0.5), Vector3(c.x, DECK + 0.45, TERRACE.end.y - 0.25), stone)
	## A small shrine behind, lamp-lit, and lantern posts at the front corners.
	var shrine := Vector3(c.x, DECK, TERRACE.end.y - 5.0)
	P.frustum(Vector2(7.0, 5.0), Vector2(6.4, 4.6), 4.5, shrine, dark)
	var y := 4.5
	var w := 5.0
	for i in 6:
		var hh := lerpf(1.6, 0.8, float(i) / 5.0)
		P.frustum(Vector2(w, w * 0.8), Vector2(w * 0.84, w * 0.8 * 0.84), hh, shrine + Vector3(0.0, y, 0.0), stone if i % 2 == 0 else dark)
		y += hh
		w *= 0.84
	P.box(Vector3(1.4, 2.4, 0.2), shrine + Vector3(0.0, 1.5, -2.55), P.mat(PropsSc.AMBER, 2.4))
	for sx in [-1.0, 1.0]:
		var post := Vector3(c.x + sx * (TERRACE.size.x * 0.5 - 1.0), DECK, TERRACE.position.y + 1.0)
		P.cyl(0.08, 0.1, 3.2, post + Vector3(0.0, 1.6, 0.0), dark, 6)
		P.lantern(self, post + Vector3(0.0, 3.3, 0.0), 0.8)
	## The rival's ledge, with a lantern of its own.
	var rdeck := P.box(Vector3(RIVAL_R * 2.0, 0.8, RIVAL_R * 2.0), Vector3(RIVAL.x, RIVAL_DECK - 0.4, RIVAL.y), stone)
	var rbody := StaticBody3D.new()
	var rcs := CollisionShape3D.new()
	var rshape := BoxShape3D.new()
	rshape.size = Vector3(RIVAL_R * 2.0, 0.8, RIVAL_R * 2.0)
	rcs.shape = rshape
	rbody.add_child(rcs)
	rdeck.add_child(rbody)
	P.cyl(0.08, 0.1, 3.0, Vector3(RIVAL.x + RIVAL_R - 1.0, RIVAL_DECK + 1.5, RIVAL.y - RIVAL_R + 1.0), dark, 6)
	P.lantern(self, Vector3(RIVAL.x + RIVAL_R - 1.0, RIVAL_DECK + 3.1, RIVAL.y - RIVAL_R + 1.0), 1.0)


## Bonsai trees on the cliff tops and spurs, the foreground frame of the
## painting; a few right at the terrace's sides.
func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for sx in [-1.0, 1.0]:
		var x: float = TERRACE.get_center().x + sx * (TERRACE.size.x * 0.5 + 7.0)
		var z := TERRACE.position.y + 4.0
		_props.bonsai(Vector3(x, height_at(x, z) - 0.3, z), rng, 1.4)
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 4000:
		tries += 1
		var x := rng.randf_range(-420.0, 420.0)
		var z := rng.randf_range(-380.0, 320.0)
		var h := height_at(x, z)
		if h < 24.0:
			continue
		if TERRACE.grow(10.0).has_point(Vector2(x, z)) or Vector2(x, z).distance_to(RIVAL) < 12.0:
			continue
		var slope := absf(height_at(x + 3.0, z) - h) + absf(height_at(x, z + 3.0) - h)
		if slope > 3.0:
			continue
		_props.bonsai(Vector3(x, h - 0.3, z), rng, rng.randf_range(1.0, 1.8))
		placed += 1


func _plan_rocket_pads() -> void:
	for s in [Vector2(30.0, -30.0), Vector2(-40.0, -90.0), Vector2(60.0, -120.0)]:
		rocket_pads.append(Vector3(s.x, height_at(s.x, s.y) + 0.2, s.y))
