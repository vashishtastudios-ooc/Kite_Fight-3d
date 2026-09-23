extends "res://scripts/map_base.gd"

## Registan — Rajasthani desert at a hot gold sundown, in the Alto manner.
## You fly from a haveli rooftop at the edge of a sandstone town; the rival
## from the roof across the lane. Dunes roll away into layered haze, a fort
## stands on the horizon, chhatri pavilions and a ruined stepwell sit out in
## the sand.
##
## Desert air instead of ridge lift: the sand gives off thermals — invisible
## columns of rising air that drift downwind — and dust devils, which lift
## hard and churn the air around them.

const TERRAIN_SHADER := preload("res://shaders/alto_terrain.gdshader")
const SAND_SHADER := preload("res://shaders/dune_sand.gdshader")
const RIDGE_SHADER := preload("res://shaders/alto_ridge.gdshader")
const PropsSc := preload("res://scripts/registan_props.gd")

const SHELF := 14.0                    ## the rock shelf the town stands on
const DECK := 24.0                     ## the haveli roof you fly from
const HOME := Vector2(0.0, 92.0)
const ROOF := Rect2(-11.0, 80.0, 22.0, 26.0)
## The rival's haveli, across the lane.
const RIVAL := Vector2(-34.0, 96.0)
const RIVAL_DECK := 21.0
const RIVAL_ROOF := Rect2(-44.0, 86.0, 20.0, 22.0)
## The town sits behind and beside the rooftops: the sky in front of the
## terrace is the kite's, and nothing is built into it.
const TOWN := Rect2(-80.0, 86.0, 160.0, 130.0)
## The fort on its rock, away to the left over the dunes.
const FORT := Vector2(-230.0, -250.0)
const FORT_TOP := 66.0
const FORT_R := Vector2(78.0, 56.0)

const GRID_MIN := Vector2(-520.0, -620.0)
const GRID_MAX := Vector2(520.0, 340.0)
const GRID_STEP := 7.0

## Thermals.
const THERMAL_LIFT := 8.0              ## m/s in the core of a good thermal
const THERMAL_CEIL := 110.0            ## how high the column still pulls
const DEVIL_LIFT := 13.0

const HAZE := Color(0.98, 0.78, 0.52)
const SKY_TOP := Color(0.42, 0.34, 0.50)

var _warp: FastNoiseLite
var _rough: FastNoiseLite
var _amp: FastNoiseLite
var _wind_dir := Vector3(sin(deg_to_rad(8.0)), 0.0, -cos(deg_to_rad(8.0)))
var _wind: Node
var _props: PropsSc
## {pos: Vector2, r: float, devil: bool, node: Node3D}
var _thermals: Array[Dictionary] = []
var _t: float = 0.0


func build() -> void:
	_warp = FastNoiseLite.new()
	_warp.seed = 3301
	_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp.frequency = 0.0022
	_rough = FastNoiseLite.new()
	_rough.seed = 77
	_rough.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_rough.frequency = 0.02
	_amp = FastNoiseLite.new()
	_amp.seed = 515
	_amp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_amp.frequency = 0.004

	rooftop_height = DECK
	spawn_position = Vector3(HOME.x, DECK + 0.3, HOME.y)
	rooftop_bounds = Rect2(ROOF.position.x + 2.0, ROOF.position.y + 2.0, ROOF.size.x - 4.0, ROOF.size.y - 4.0)
	player_building_aabb = AABB(Vector3(ROOF.position.x, 0.0, ROOF.position.y), Vector3(ROOF.size.x, DECK, ROOF.size.y))

	_build_dunes()
	_build_far_dunes()
	_props = PropsSc.new(self)
	_build_town()
	_build_desert_props()
	_plan_thermals()
	_plan_rocket_pads()


func configure_world(env: Environment, sun: DirectionalLight3D) -> void:
	## A low, huge sun over the dunes: long shadows, hot gold light.
	sun.rotation_degrees = Vector3(-6.0, 128.0, 0.0)
	sun.light_color = Color(1.0, 0.76, 0.44)
	sun.light_energy = 1.15
	sun.directional_shadow_max_distance = 200.0
	var sky_mat := env.sky.sky_material as ShaderMaterial if env.sky else null
	if sky_mat:
		sky_mat.set_shader_parameter("day_top_color", SKY_TOP)
		sky_mat.set_shader_parameter("day_bottom_color", Color(0.92, 0.62, 0.42))
		sky_mat.set_shader_parameter("horizon_color_day", HAZE)
		sky_mat.set_shader_parameter("sunset_top_color", SKY_TOP)
		sky_mat.set_shader_parameter("sunset_bottom_color", Color(0.96, 0.66, 0.40))
		sky_mat.set_shader_parameter("horizon_color_sunset", Color(1.0, 0.80, 0.46))
		sky_mat.set_shader_parameter("clouds_main_color", Color(0.96, 0.74, 0.56))
		sky_mat.set_shader_parameter("clouds_edge_color", Color(0.85, 0.58, 0.46))
		## Desert sky: almost bare, just a few high streaks.
		sky_mat.set_shader_parameter("clouds_opacity", 0.1)
		sky_mat.set_shader_parameter("clouds_cutoff", 0.42)
		sky_mat.set_shader_parameter("sun_col", Color(1.0, 0.88, 0.58))
		sky_mat.set_shader_parameter("sun_size", 0.16)
		sky_mat.set_shader_parameter("sun_blur", 0.5)
		sky_mat.set_shader_parameter("horizon_falloff", 2.8)
	env.ambient_light_energy = 0.7
	env.fog_light_color = HAZE
	env.fog_depth_begin = 60.0
	env.fog_depth_end = 950.0
	env.fog_depth_curve = 1.3
	env.fog_aerial_perspective = 0.72
	env.fog_sky_affect = 0.3
	## Dust haze hanging low over the sand.
	env.fog_height = 24.0
	env.fog_height_density = 0.012
	env.ssao_enabled = false
	env.adjustment_saturation = 1.08


func set_wind(w: Node) -> void:
	_wind = w


func _process(delta: float) -> void:
	_t += delta
	if _wind and _wind.has_method("wind_dir"):
		_wind_dir = _wind.wind_dir()
	_drift_thermals(delta)


# ── Map contract ─────────────────────────────────────────────────────────────

func rival_hand_position() -> Vector3:
	return Vector3(RIVAL.x, RIVAL_DECK + 0.3, RIVAL.y)


func rival_roof_bounds() -> Rect2:
	return Rect2(RIVAL_ROOF.position.x + 2.0, RIVAL_ROOF.position.y + 2.0, RIVAL_ROOF.size.x - 4.0, RIVAL_ROOF.size.y - 4.0)


func palace_watch_spot() -> Vector3:
	return Vector3(HOME.x + 6.5, DECK, HOME.y + 6.0)


## Choppy air low over the roofs and the sand.
func nearest_building_chop(pos: Vector3) -> float:
	var above := pos.y - height_at(pos.x, pos.z)
	var chop := clampf(1.0 - above / 15.0, 0.0, 1.0)
	## A dust devil churns the air all around it.
	for th in _thermals:
		if not th["devil"]:
			continue
		var d := Vector2(pos.x, pos.z).distance_to(th["pos"])
		var r: float = th["r"]
		if d < r * 2.5:
			chop = maxf(chop, 1.0 - d / (r * 2.5))
	return chop


## Hot sand throws up columns of rising air; a dust devil is a fierce one.
func lift_at(pos: Vector3) -> float:
	var above := pos.y - height_at(pos.x, pos.z)
	if above < 0.0 or above > THERMAL_CEIL:
		return 0.0
	var best := 0.0
	var here := Vector2(pos.x, pos.z)
	for th in _thermals:
		var r: float = th["r"]
		var d := here.distance_to(th["pos"])
		if d > r:
			continue
		## Strongest in the core, and it thins out with height.
		var core := 1.0 - pow(d / r, 1.6)
		var top := 1.0 - above / THERMAL_CEIL
		var power: float = DEVIL_LIFT if th["devil"] else THERMAL_LIFT
		best = maxf(best, power * core * top)
	return best


func is_solid(p: Vector3) -> bool:
	if p.y < 1.0:
		return true
	## The two rooftops: a parked kite rests on them.
	if ROOF.has_point(Vector2(p.x, p.z)):
		return p.y < DECK - 0.2
	if RIVAL_ROOF.has_point(Vector2(p.x, p.z)):
		return p.y < RIVAL_DECK - 0.2
	if p.y < height_at(p.x, p.z) + 0.4:
		return true
	for aabb in building_aabbs:
		if aabb.grow(0.3).has_point(p):
			return true
	return false


# ── Land ─────────────────────────────────────────────────────────────────────

## Dune field, with the town's rock shelf and the fort's rock rising out of it.
func height_at(x: float, z: float) -> float:
	var h := _dune_height(x, z)
	h = maxf(h, _shelf(x, z))
	h = maxf(h, _fort_rock(x, z))
	return h


## Crest lines run across the wind, sharp on top and broad in the hollows,
## wandering so they never look like corrugations.
func _dune_height(x: float, z: float) -> float:
	var w := _warp.get_noise_2d(x, z) * 90.0
	var w2 := _warp.get_noise_2d(x * 0.4 + 300.0, z * 0.4) * 60.0
	var amp := 11.0 + 9.0 * (_amp.get_noise_2d(x, z) * 0.5 + 0.5)
	var crest := pow(0.5 + 0.5 * sin((z + w) * 0.017 + x * 0.004), 2.3)
	var big := pow(0.5 + 0.5 * sin((z + w2) * 0.006 - x * 0.002), 2.0) * 10.0
	var grain := _rough.get_noise_2d(x, z) * 1.2
	return 2.5 + amp * crest + big + grain


func _shelf(x: float, z: float) -> float:
	var c := TOWN.get_center()
	var half := TOWN.size * 0.5
	var dx := maxf(absf(x - c.x) - half.x, 0.0)
	var dz := maxf(absf(z - c.y) - half.y, 0.0)
	var r := sqrt(dx * dx + dz * dz)
	if r <= 0.0:
		return SHELF
	var t := clampf(r / 46.0, 0.0, 1.0)
	return lerpf(SHELF, 2.5, 1.0 - pow(1.0 - t, 2.0)) + _rough.get_noise_2d(x * 1.4, z * 1.4) * 2.0 * t


func _fort_rock(x: float, z: float) -> float:
	var dx := maxf(absf(x - FORT.x) - FORT_R.x, 0.0)
	var dz := maxf(absf(z - FORT.y) - FORT_R.y, 0.0)
	var r := sqrt(dx * dx + dz * dz)
	if r <= 0.0:
		return FORT_TOP
	var t := clampf(r / 70.0, 0.0, 1.0)
	return lerpf(FORT_TOP, 3.0, 1.0 - pow(1.0 - t, 1.8)) + _rough.get_noise_2d(x, z) * 3.0 * t


func _build_dunes() -> void:
	var nx := int((GRID_MAX.x - GRID_MIN.x) / GRID_STEP) + 1
	var nz := int((GRID_MAX.y - GRID_MIN.y) / GRID_STEP) + 1
	var verts := PackedVector3Array()
	verts.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var x := GRID_MIN.x + float(ix) * GRID_STEP
			var z := GRID_MIN.y + float(iz) * GRID_STEP
			var y := height_at(x, z)
			## Sink under the rooftops' own slabs so nothing z-fights.
			if TOWN.grow(2.0).has_point(Vector2(x, z)):
				y -= 0.5
			verts[iz * nx + ix] = Vector3(x, y, z)
	var idx := PackedInt32Array()
	for iz in nz - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			var b := a + 1
			var c := a + nx
			var e := c + 1
			idx.append_array([a, b, c, b, e, c])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in idx.size():
		st.add_vertex(verts[idx[i]])
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = SAND_SHADER
	mat.set_shader_parameter("sun_dir", Vector3(sin(deg_to_rad(128.0)), 0.2, -cos(deg_to_rad(128.0))))
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Dunes"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


## Layers of far dunes and rock ridges, each paler than the last.
func _build_far_dunes() -> void:
	var layers := [
		{"r": 680.0, "base": 6.0, "top": 95.0, "body": Color(0.80, 0.50, 0.34), "peak": Color(0.92, 0.66, 0.42), "haze": 0.35, "seed": 5, "smooth": 1.5},
		{"r": 980.0, "base": 8.0, "top": 140.0, "body": Color(0.78, 0.50, 0.44), "peak": Color(0.90, 0.64, 0.50), "haze": 0.45, "seed": 15, "smooth": 1.2},
		{"r": 1350.0, "base": 10.0, "top": 200.0, "body": Color(0.76, 0.54, 0.58), "peak": Color(0.88, 0.68, 0.64), "haze": 0.55, "seed": 25, "smooth": 1.0},
		{"r": 1850.0, "base": 12.0, "top": 275.0, "body": Color(0.80, 0.64, 0.72), "peak": Color(0.90, 0.76, 0.78), "haze": 0.66, "seed": 35, "smooth": 0.8},
	]
	for L in layers:
		_dune_curtain(L)


func _dune_curtain(L: Dictionary) -> void:
	var rn := FastNoiseLite.new()
	rn.seed = int(L["seed"])
	rn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rn.frequency = 0.8
	rn.fractal_octaves = 2
	var r: float = L["r"]
	var base: float = L["base"]
	var top: float = L["top"]
	var smooth: float = L["smooth"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 200
	var a0 := deg_to_rad(-135.0)
	var a1 := deg_to_rad(135.0)
	var prev_b := Vector3.ZERO
	var prev_t := Vector3.ZERO
	for i in segs + 1:
		var a := lerpf(a0, a1, float(i) / float(segs))
		var dir := Vector3(sin(a), 0.0, -cos(a))
		## Dune humps: rounded, not jagged like rock.
		var n := rn.get_noise_1d(a * 2.4) * 0.5 + 0.5
		var hump := pow(n, smooth)
		var y := base + (top - base) * (0.45 + 0.55 * hump)
		var p := Vector3(HOME.x, 0.0, HOME.y) + dir * r
		var b := Vector3(p.x, -20.0, p.z)
		var t := Vector3(p.x, y, p.z)
		if i > 0:
			st.add_vertex(prev_b)
			st.add_vertex(prev_t)
			st.add_vertex(t)
			st.add_vertex(prev_b)
			st.add_vertex(t)
			st.add_vertex(b)
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
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "FarDunes%d" % int(r)
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 200.0
	add_child(mi)


# ── Town and desert props ────────────────────────────────────────────────────

func _build_town() -> void:
	## The two havelis, then the town behind and around them.
	_props.haveli(ROOF, SHELF, DECK, true)
	_props.haveli(RIVAL_ROOF, SHELF, RIVAL_DECK, false)
	_props.town(TOWN, ROOF, RIVAL_ROOF, SHELF, self)


func _build_desert_props() -> void:
	_props.fort(Vector3(FORT.x, FORT_TOP, FORT.y), FORT_R)
	## Chhatri pavilions on dune crests, and a ruined stepwell in the sand.
	for spot in [Vector2(52.0, -60.0), Vector2(-86.0, -140.0), Vector2(120.0, -230.0)]:
		var y := height_at(spot.x, spot.y)
		_props.chhatri(Vector3(spot.x, y - 0.4, spot.y), 1.0 + float(int(spot.x) % 3) * 0.15)
	_props.stepwell(Vector3(-40.0, height_at(-40.0, -40.0), -40.0))
	## A camel train plodding along a hollow.
	_props.caravan(self, Vector2(70.0, 10.0), Vector2(-120.0, -90.0), 6)
	## Khejri trees where the sand is shallow.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 40:
		var x := rng.randf_range(-340.0, 340.0)
		var z := rng.randf_range(-420.0, 240.0)
		var h := height_at(x, z)
		if h > 12.0 or TOWN.grow(12.0).has_point(Vector2(x, z)):
			continue
		_props.khejri(Vector3(x, h - 0.2, z), rng)


# ── Thermals and dust devils ─────────────────────────────────────────────────

func _plan_thermals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	for i in 7:
		var devil := i < 2
		var pos := Vector2(rng.randf_range(-140.0, 140.0), rng.randf_range(-260.0, 55.0))
		var th := {"pos": pos, "r": rng.randf_range(16.0, 30.0) if not devil else rng.randf_range(9.0, 13.0), "devil": devil, "node": null}
		## Both kinds show themselves — a flyer reads the air by the dust.
		th["node"] = _props.dust_devil(Vector3(pos.x, height_at(pos.x, pos.y), pos.y), float(th["r"]), not devil)
		_thermals.append(th)


## Thermals drift downwind and reset upwind when they run out of desert.
func _drift_thermals(delta: float) -> void:
	var d := Vector2(_wind_dir.x, _wind_dir.z).normalized()
	for th in _thermals:
		var speed: float = 3.5 if th["devil"] else 1.6
		var pos: Vector2 = th["pos"] + d * speed * delta
		if pos.distance_to(Vector2(HOME.x, HOME.y)) > 420.0:
			pos = Vector2(HOME.x, HOME.y) - d * 380.0 + Vector2(randf_range(-160.0, 160.0), randf_range(-60.0, 60.0))
		th["pos"] = pos
		var node: Node3D = th["node"]
		if node:
			node.global_position = Vector3(pos.x, height_at(pos.x, pos.y) - 1.0, pos.y)
			node.rotation.y += delta * (2.2 if th["devil"] else 0.4)


func _plan_rocket_pads() -> void:
	for s in [Vector2(30.0, 40.0), Vector2(-52.0, 20.0), Vector2(18.0, -30.0)]:
		rocket_pads.append(Vector3(s.x, height_at(s.x, s.y) + 0.2, s.y))
