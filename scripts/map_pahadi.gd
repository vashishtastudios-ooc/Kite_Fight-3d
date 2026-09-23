extends "res://scripts/map_base.gd"

## Pahadi — Himalayan dusk, drawn in the Alto style. You fly from a monastery
## terrace on a hilltop; the rival from a rocky spur across a deep valley.
## Far ranges stack like paper cut-outs, each paler than the last. Low mist
## fills the valley (kites flown down there vanish into it), rock pillars
## stand in it (and cut kites that hit them), and where the wind blows up a
## slope the air lifts — fly near a ridge face to climb.
##
## Everything here is greybox-ready for hero pieces from Blender: the terrace,
## gompa, chorten and the rival's ledge are simple shapes that can be swapped
## for imported models without touching the rules.

const TERRAIN_SHADER := preload("res://shaders/alto_terrain.gdshader")
const RIDGE_SHADER := preload("res://shaders/alto_ridge.gdshader")
const MIST_SHADER := preload("res://shaders/valley_mist.gdshader")
const FLAG_SHADER := preload("res://shaders/prayer_flag.gdshader")
const PropsSc := preload("res://scripts/pahadi_props.gd")

const DECK := 40.0                     ## terrace height above the valley floor
const HOME := Vector2(0.0, 92.0)       ## where the flyer stands (x, z)
const TERRACE_R := 9.0
## The monastery compound: terrace in front, courtyard, gompa behind. The
## hilltop is flat over all of it, and a battered stone base runs down into
## the hill around its edge.
const COMPOUND := Rect2(-13.0, 82.0, 26.0, 42.0)
const GOMPA_FRONT := 110.0             ## z of the gompa's front wall
const BASE_DROP := 16.0
## The rival's outcrop: a neighbouring spur, so both strings run out into the
## same downwind sky (real fights are roof to neighbouring roof).
const RIVAL := Vector2(-46.0, 100.0)
const RIVAL_DECK := 36.0
const RIVAL_R := 6.0
const VALLEY_FLOOR := 3.0
const MIST_Y := 13.0

## Terrain grid.
const GRID_MIN := Vector2(-460.0, -560.0)
const GRID_MAX := Vector2(460.0, 320.0)
const GRID_STEP := 6.0

## Ridge lift.
const LIFT_MAX := 9.0                  ## m/s upward on a steep windward face
const LIFT_REACH := 60.0               ## metres above the slope it still lifts

## Palette (Alto dusk).
const HAZE := Color(0.95, 0.70, 0.60)
const SKY_TOP := Color(0.34, 0.27, 0.40)

var _noise: FastNoiseLite
var _detail: FastNoiseLite
var _wind_dir := Vector3(sin(deg_to_rad(8.0)), 0.0, -cos(deg_to_rad(8.0)))
var _pillars: Array[Dictionary] = []   ## {pos: Vector3 (base), r: float, h: float}
var _flag_mats: Array[ShaderMaterial] = []
var _wind: Node
var _props: PropsSc
var _eagles: Array[Dictionary] = []
var _smoke: GPUParticles3D


func build() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = 4471
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.0045
	_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_noise.fractal_octaves = 4
	_detail = FastNoiseLite.new()
	_detail.seed = 911
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 0.03

	rooftop_height = DECK
	spawn_position = Vector3(HOME.x, DECK + 0.3, HOME.y)
	rooftop_bounds = Rect2(HOME.x - 6.5, HOME.y - 6.0, 13.0, 13.0)
	player_building_aabb = AABB(Vector3(HOME.x - TERRACE_R, 0.0, HOME.y - TERRACE_R), Vector3(TERRACE_R * 2.0, DECK, TERRACE_R * 2.0))

	_plan_pillars()
	_build_terrain()
	_build_far_ranges()
	_build_mist()
	_build_pillars()
	_build_pines()
	_props = PropsSc.new(self)
	_build_monastery()
	_build_rival_ledge()
	_build_flags()
	_build_bridge()
	_build_village()
	_build_eagles()
	_plan_rocket_pads()


func configure_world(env: Environment, sun: DirectionalLight3D) -> void:
	## Low sun ahead-left, as in the reference: long warm light, deep mauve shade.
	sun.rotation_degrees = Vector3(-7.0, 150.0, 0.0)
	sun.light_color = Color(1.0, 0.70, 0.52)
	sun.light_energy = 0.95
	sun.directional_shadow_max_distance = 220.0
	var sky_mat := env.sky.sky_material as ShaderMaterial if env.sky else null
	if sky_mat:
		sky_mat.set_shader_parameter("day_top_color", SKY_TOP)
		sky_mat.set_shader_parameter("day_bottom_color", Color(0.80, 0.54, 0.52))
		sky_mat.set_shader_parameter("horizon_color_day", HAZE)
		sky_mat.set_shader_parameter("sunset_top_color", SKY_TOP)
		sky_mat.set_shader_parameter("sunset_bottom_color", Color(0.88, 0.60, 0.54))
		sky_mat.set_shader_parameter("horizon_color_sunset", Color(1.0, 0.74, 0.56))
		sky_mat.set_shader_parameter("clouds_main_color", Color(0.86, 0.66, 0.64))
		sky_mat.set_shader_parameter("clouds_edge_color", Color(0.72, 0.54, 0.58))
		sky_mat.set_shader_parameter("clouds_opacity", 0.16)
		sky_mat.set_shader_parameter("clouds_cutoff", 0.34)
		sky_mat.set_shader_parameter("sun_col", Color(1.0, 0.86, 0.62))
		sky_mat.set_shader_parameter("sun_size", 0.13)
		sky_mat.set_shader_parameter("sun_blur", 0.42)
		sky_mat.set_shader_parameter("horizon_falloff", 3.2)
	env.ambient_light_energy = 0.62
	env.fog_light_color = HAZE
	## Strong aerial perspective: every step back is paler — the Alto depth.
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 700.0
	env.fog_depth_curve = 1.0
	env.fog_aerial_perspective = 0.9
	env.fog_sky_affect = 0.35
	## Valley fog: the air thickens toward the valley floor.
	env.fog_height = MIST_Y + 4.0
	env.fog_height_density = 0.045
	env.ssao_enabled = false
	env.adjustment_saturation = 1.05


## The game hands us the wind once it exists (for flags and lift direction).
func set_wind(w: Node) -> void:
	_wind = w


func _process(delta: float) -> void:
	_tick_eagles(delta)
	if _wind == null:
		return
	var g: float = _wind.gust01_at(spawn_position)
	for m in _flag_mats:
		m.set_shader_parameter("gust", g)
	if _wind.has_method("wind_dir"):
		_wind_dir = _wind.wind_dir()
	if _smoke:
		var pm := _smoke.process_material as ParticleProcessMaterial
		pm.gravity = Vector3(_wind_dir.x, 0.0, _wind_dir.z) * (1.2 + g * 2.5) + Vector3.UP * 0.35


# ── Map contract ─────────────────────────────────────────────────────────────

func rival_hand_position() -> Vector3:
	return Vector3(RIVAL.x, RIVAL_DECK + 0.3, RIVAL.y)


func rival_roof_bounds() -> Rect2:
	return Rect2(RIVAL.x - 4.0, RIVAL.y - 4.0, 8.0, 8.0)


func palace_watch_spot() -> Vector3:
	return Vector3(HOME.x + 5.5, DECK, HOME.y + 3.0)


## Rough air close to the ground, like roof air in the city.
func nearest_building_chop(pos: Vector3) -> float:
	var above := pos.y - height_at(pos.x, pos.z)
	return clampf(1.0 - above / 16.0, 0.0, 1.0)


## Wind blowing up a slope lifts; strongest right against the face.
func lift_at(pos: Vector3) -> float:
	var ground := height_at(pos.x, pos.z)
	var above := pos.y - ground
	if above < 0.0 or above > LIFT_REACH:
		return 0.0
	var d := _wind_dir
	var ahead := height_at(pos.x + d.x * 12.0, pos.z + d.z * 12.0)
	var behind := height_at(pos.x - d.x * 12.0, pos.z - d.z * 12.0)
	## Look a little further upwind too, so the lift starts before the face.
	var far_ahead := height_at(pos.x + d.x * 30.0, pos.z + d.z * 30.0)
	var rise := maxf((ahead - behind) / 24.0, (far_ahead - ground) / 30.0)
	if rise <= 0.05:
		return 0.0
	return LIFT_MAX * clampf(rise, 0.0, 1.0) * (1.0 - above / LIFT_REACH)


func is_solid(p: Vector3) -> bool:
	if p.y < 1.4:
		return true
	## The compound deck: the parked kite sits on it. The gompa is solid.
	if COMPOUND.has_point(Vector2(p.x, p.z)):
		if p.x > -7.0 and p.x < 7.0 and p.z > GOMPA_FRONT and p.z < GOMPA_FRONT + 9.5 and p.y < DECK + 14.5:
			return true
		return p.y < DECK - 0.2
	if p.y < height_at(p.x, p.z) + 0.4:
		return true
	for pl in _pillars:
		var base: Vector3 = pl["pos"]
		if p.y < base.y + float(pl["h"]) and Vector2(p.x - base.x, p.z - base.z).length() < float(pl["r"]) + 0.3:
			return true
	return false


# ── Terrain ──────────────────────────────────────────────────────────────────

## Ground height. A deep valley runs away from the terrace; walls rise on
## both sides and a big range closes it far off. Two spurs hold the flyers.
func height_at(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	var d := _detail.get_noise_2d(x, z)
	## The valley meanders a little as it runs away.
	var cx := sin(z * 0.004) * 24.0
	## Wide, open valley: low walls near, so the far ranges show layer on layer.
	var side := smoothstep(110.0, 360.0, absf(x - cx)) * (38.0 + n * 58.0)
	var far_wall := smoothstep(-280.0, -540.0, z) * (34.0 + n * 52.0)
	var back := smoothstep(120.0, 280.0, z) * (45.0 + n * 40.0)
	var h := VALLEY_FLOOR + maxf(side, maxf(far_wall, back)) + d * 2.5
	h = maxf(h, _compound_hill(x, z))
	h = maxf(h, _plateau(x, z, RIVAL, RIVAL_DECK, RIVAL_R, 48.0, Vector2(1.0, 0.8)))
	return h


## The monastery hill: flat over the whole compound, falling away steeply
## (the stone base hides the lip) and running back into the hills behind.
func _compound_hill(x: float, z: float) -> float:
	var c := COMPOUND.get_center()
	var half := COMPOUND.size * 0.5
	var dx := maxf(absf(x - c.x) - half.x, 0.0)
	var dz := z - c.y
	## Behind the compound the hill stretches back into the range.
	dz = maxf(absf(dz) - half.y, 0.0) * (0.55 if dz > 0.0 else 1.0)
	var r := sqrt(dx * dx + dz * dz)
	if r <= 0.0:
		return DECK
	var t := clampf(r / 58.0, 0.0, 1.0)
	var fall := 1.0 - pow(1.0 - t, 2.1)
	var rough := _detail.get_noise_2d(x * 1.7, z * 1.7) * 3.0 * t * (1.0 - t) * 4.0
	return lerpf(DECK - 3.0, VALLEY_FLOOR, fall) + rough


## A spur with a flat top: flat inside `flat`, easing down to the valley by
## `reach`. `squash` stretches it (z < 1 makes it run back into the hills).
func _plateau(x: float, z: float, c: Vector2, top: float, flat: float, reach: float, squash: Vector2) -> float:
	var dx := (x - c.x) / squash.x
	var dz := (z - c.y) / squash.y if z > c.y else (z - c.y)
	var r := sqrt(dx * dx + dz * dz)
	if r <= flat:
		return top
	var t := clampf((r - flat) / reach, 0.0, 1.0)
	## Steep near the top, easing out below: a cliffy spur, not a cone.
	var fall := 1.0 - pow(1.0 - t, 2.2)
	var rough := _detail.get_noise_2d(x * 1.7, z * 1.7) * 3.0 * t * (1.0 - t) * 4.0
	return lerpf(top, VALLEY_FLOOR, fall) + rough


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
			## Sink the ground a hair under the stone decks so they never z-fight.
			if COMPOUND.grow(1.0).has_point(Vector2(x, z)) or Vector2(x, z).distance_to(RIVAL) < RIVAL_R + 1.0:
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
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


## Four far ranges as silhouette curtains, each paler than the one in front.
func _build_far_ranges() -> void:
	var layers := [
		{"r": 700.0, "base": 20.0, "top": 170.0, "body": Color(0.58, 0.38, 0.44), "peak": Color(0.72, 0.50, 0.52), "haze": 0.45, "seed": 11},
		{"r": 1000.0, "base": 30.0, "top": 250.0, "body": Color(0.70, 0.48, 0.52), "peak": Color(0.82, 0.60, 0.58), "haze": 0.55, "seed": 23},
		{"r": 1400.0, "base": 40.0, "top": 340.0, "body": Color(0.80, 0.58, 0.58), "peak": Color(0.90, 0.68, 0.62), "haze": 0.62, "seed": 37},
		{"r": 1900.0, "base": 50.0, "top": 470.0, "body": Color(0.88, 0.66, 0.62), "peak": Color(0.95, 0.76, 0.68), "haze": 0.7, "seed": 53},
	]
	for L in layers:
		_range_curtain(L)


func _range_curtain(L: Dictionary) -> void:
	var rn := FastNoiseLite.new()
	rn.seed = int(L["seed"])
	rn.noise_type = FastNoiseLite.TYPE_SIMPLEX
	rn.frequency = 0.9
	rn.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	rn.fractal_octaves = 3
	var r: float = L["r"]
	var base: float = L["base"]
	var top: float = L["top"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 220
	var a0 := deg_to_rad(-130.0)
	var a1 := deg_to_rad(130.0)
	var prev_b := Vector3.ZERO
	var prev_t := Vector3.ZERO
	for i in segs + 1:
		var a := lerpf(a0, a1, float(i) / float(segs))
		## Angle 0 = straight ahead (-Z) from the terrace.
		var dir := Vector3(sin(a), 0.0, -cos(a))
		var peak := rn.get_noise_1d(a * 3.0) * 0.5 + 0.5
		peak = pow(peak, 1.6)
		var y := base + (top - base) * (0.35 + 0.65 * peak)
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
	mi.name = "Range%d" % int(r)
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 200.0
	add_child(mi)


func _build_mist() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(560.0, 620.0)
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var fn := FastNoiseLite.new()
	fn.seed = 77
	fn.frequency = 0.012
	fn.fractal_octaves = 4
	noise.noise = fn
	var mat := ShaderMaterial.new()
	mat.shader = MIST_SHADER
	mat.set_shader_parameter("noise_tex", noise)
	mat.set_shader_parameter("mist_col", Color(0.96, 0.78, 0.72))
	plane.material = mat
	for layer in 2:
		var mi := MeshInstance3D.new()
		mi.name = "ValleyMist%d" % layer
		mi.mesh = plane
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.0, MIST_Y + float(layer) * 6.0, -160.0)
		mi.scale = Vector3.ONE * (1.0 + float(layer) * 0.1)
		add_child(mi)


# ── Rock pillars (obstacles) ─────────────────────────────────────────────────

func _plan_pillars() -> void:
	var spots := [
		Vector3(34.0, 0.0, -38.0), Vector3(-26.0, 0.0, -84.0), Vector3(52.0, 0.0, -132.0),
		Vector3(-58.0, 0.0, -170.0), Vector3(12.0, 0.0, -210.0),
	]
	## Tall enough to rise toward the flyers' level: real obstacles, and the
	## dramatic Alto hoodoos standing out of the mist.
	var hs := [58.0, 78.0, 66.0, 86.0, 72.0]
	for i in spots.size():
		var s: Vector3 = spots[i]
		_pillars.append({"pos": Vector3(s.x, VALLEY_FLOOR, s.z), "r": 8.5 - float(i % 2) * 2.0, "h": float(hs[i])})


func _build_pillars() -> void:
	## Weathered sandstone: the faceted ground look with soft rock strata.
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("floor_col", Color(0.34, 0.22, 0.24))
	mat.set_shader_parameter("grass_col", Color(0.46, 0.30, 0.30))
	mat.set_shader_parameter("rock_col", Color(0.54, 0.36, 0.34))
	mat.set_shader_parameter("crest_col", Color(0.74, 0.52, 0.46))
	mat.set_shader_parameter("crest_h", 90.0)
	mat.set_shader_parameter("strata", 1.0)
	var cap_mat := ShaderMaterial.new()
	cap_mat.shader = TERRAIN_SHADER
	cap_mat.set_shader_parameter("rock_col", Color(0.36, 0.24, 0.26))
	cap_mat.set_shader_parameter("grass_col", Color(0.40, 0.28, 0.28))
	cap_mat.set_shader_parameter("crest_col", Color(0.62, 0.42, 0.40))
	for pl in _pillars:
		var base: Vector3 = pl["pos"]
		var r: float = pl["r"]
		var h: float = pl["h"]
		## Stacked, slightly offset drums: a weathered hoodoo, not a cylinder.
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings := 7
		var sides := 7
		var pts: Array[PackedVector3Array] = []
		for k in rings + 1:
			var t := float(k) / float(rings)
			## Broad foot, narrowing waist, a wider cap: a hoodoo.
			var profile := 1.15 - 0.55 * sin(t * PI * 0.85) + 0.25 * smoothstep(0.8, 1.0, t)
			var rr := r * profile * (0.8 + 0.4 * absf(_detail.get_noise_2d(base.x + t * 40.0, base.z)))
			var off := Vector2(_detail.get_noise_2d(base.x, base.z + t * 60.0), _detail.get_noise_2d(base.x + 90.0, base.z + t * 60.0)) * r * 0.5
			var ring := PackedVector3Array()
			for j in sides:
				var a := TAU * float(j) / float(sides) + t * 0.6
				ring.append(Vector3(off.x + cos(a) * rr, t * h, off.y + sin(a) * rr))
			pts.append(ring)
		for k in rings:
			for j in sides:
				var j2 := (j + 1) % sides
				st.add_vertex(pts[k][j])
				st.add_vertex(pts[k + 1][j])
				st.add_vertex(pts[k][j2])
				st.add_vertex(pts[k][j2])
				st.add_vertex(pts[k + 1][j])
				st.add_vertex(pts[k + 1][j2])
		var top_c := Vector3(0.0, h, 0.0)
		for j in sides:
			st.add_vertex(pts[rings][j])
			st.add_vertex(top_c)
			st.add_vertex(pts[rings][(j + 1) % sides])
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "Pillar"
		mi.mesh = st.commit()
		mi.material_override = mat
		add_child(mi)
		mi.global_position = base - Vector3(0.0, 2.0, 0.0)
		## Harder cap rock sitting proud of the top, like a real hoodoo.
		var cap := CylinderMesh.new()
		cap.top_radius = r * 0.95
		cap.bottom_radius = r * 1.15
		cap.height = 2.4
		cap.radial_segments = 7
		cap.rings = 1
		var ci := MeshInstance3D.new()
		ci.mesh = cap
		ci.material_override = cap_mat
		add_child(ci)
		ci.global_position = base + Vector3(0.0, h - 2.0 + 0.6, 0.0)
		ci.rotation.y = base.x * 0.1


# ── Pines ────────────────────────────────────────────────────────────────────

func _pine_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := [[0.0, 1.0, 1.25], [0.9, 0.78, 1.15], [1.75, 0.55, 1.1]]
	var sides := 6
	for tier in tiers:
		var y0: float = tier[0]
		var rad: float = tier[1]
		var hh: float = tier[2]
		for j in sides:
			var a0 := TAU * float(j) / float(sides)
			var a1 := TAU * float(j + 1) / float(sides)
			st.add_vertex(Vector3(cos(a0) * rad, y0 + 0.4, sin(a0) * rad))
			st.add_vertex(Vector3(0.0, y0 + 0.4 + hh, 0.0))
			st.add_vertex(Vector3(cos(a1) * rad, y0 + 0.4, sin(a1) * rad))
	## Trunk.
	for j in 4:
		var a0 := TAU * float(j) / 4.0
		var a1 := TAU * float(j + 1) / 4.0
		var p0 := Vector3(cos(a0) * 0.12, 0.0, sin(a0) * 0.12)
		var p1 := Vector3(cos(a1) * 0.12, 0.0, sin(a1) * 0.12)
		st.add_vertex(p0)
		st.add_vertex(p0 + Vector3.UP * 0.5)
		st.add_vertex(p1)
	st.generate_normals()
	return st.commit()


func _build_pines() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var xforms: Array[Transform3D] = []
	var tries := 0
	while xforms.size() < 1100 and tries < 30000:
		tries += 1
		var x := rng.randf_range(-400.0, 400.0)
		var z := rng.randf_range(-480.0, 260.0)
		var h := height_at(x, z)
		if h < VALLEY_FLOOR + 3.0 or h > 150.0:
			continue
		## Keep the terraces and the air right in front of them open.
		if COMPOUND.grow(8.0).has_point(Vector2(x, z)) or Vector2(x, z).distance_to(RIVAL) < 12.0:
			continue
		var slope := absf(height_at(x + 2.0, z) - h) + absf(height_at(x, z + 2.0) - h)
		if slope > 2.6:
			continue
		## Clumps: pines gather in stands, not an even carpet.
		if _detail.get_noise_2d(x * 0.4, z * 0.4) < 0.18:
			continue
		## Keep the valley floor ahead open — it is the kites' sky.
		if z < 70.0 and absf(x - sin(z * 0.004) * 24.0) < 90.0 and h < 20.0:
			continue
		var s := rng.randf_range(3.2, 6.5)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 0.8, s, s * 0.8))
		xforms.append(Transform3D(b, Vector3(x, h - 0.3, z)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _pine_mesh()
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.17, 0.22)
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Pines"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ── Monastery, hermitage, flags, bridge, village, eagles ─────────────────────

func _build_monastery() -> void:
	var P := _props
	## Stone base running down into the hill, flaring out as it goes.
	P.compound_base(COMPOUND, DECK, BASE_DROP, 3.5)
	## Flagstone deck (the flyer walks on it).
	var cc := COMPOUND.get_center()
	var deck := P.box(Vector3(COMPOUND.size.x, 1.0, COMPOUND.size.y), Vector3(cc.x, DECK - 0.5, cc.y), P.mat(Color(0.66, 0.58, 0.55)))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(COMPOUND.size.x, 1.0, COMPOUND.size.y)
	cs.shape = shape
	body.add_child(cs)
	deck.add_child(body)
	## Paving: a slightly darker walk from the terrace to the gompa steps.
	var walk_len := GOMPA_FRONT - COMPOUND.position.y - 2.0
	P.box(Vector3(4.6, 0.04, walk_len), Vector3(0.0, DECK + 0.02, COMPOUND.position.y + 1.0 + walk_len * 0.5), P.mat(Color(0.56, 0.48, 0.47)))
	## Low whitewashed parapet round the terrace and courtyard.
	var par := P.wall_mat(DECK + 2.0)
	var x0 := COMPOUND.position.x + 0.3
	var x1 := COMPOUND.end.x - 0.3
	var z0 := COMPOUND.position.y + 0.3
	P.box(Vector3(COMPOUND.size.x - 0.6, 0.95, 0.45), Vector3(0.0, DECK + 0.47, z0), par)
	for x in [x0, x1]:
		P.box(Vector3(0.45, 0.95, GOMPA_FRONT - z0 - 1.0), Vector3(x, DECK + 0.47, (z0 + GOMPA_FRONT) * 0.5 - 0.5), par)
	## The gompa and its gilded shrine.
	P.gompa(Vector3(0.0, DECK, GOMPA_FRONT))
	## A chorten on each side of the courtyard.
	P.chorten(Vector3(-8.5, DECK, 104.0), 0.95)
	P.chorten(Vector3(8.5, DECK, 104.0), 0.95)
	## Incense burner (sang) with juniper smoke drifting downwind.
	## Back in the courtyard beside the gompa steps, out of the flyer's view.
	var sang := Vector3(-4.2, DECK, 107.5)
	P.frustum(Vector2(1.3, 1.3), Vector2(0.9, 0.9), 1.3, sang, P.wall_mat(DECK + 2.0))
	P.cyl(0.35, 0.5, 0.35, sang + Vector3(0, 1.45, 0), P.mat(Color(0.2, 0.15, 0.14)), 8)
	_smoke = GPUParticles3D.new()
	_smoke.name = "IncenseSmoke"
	_smoke.amount = 40
	_smoke.lifetime = 6.0
	_smoke.preprocess = 4.0
	_smoke.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0.0, 0.3, -1.0)
	pm.damping_min = 0.2
	pm.damping_max = 0.5
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.3))
	sc.add_point(Vector2(1.0, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var ramp_g := Gradient.new()
	ramp_g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp_g.colors = PackedColorArray([Color(0.9, 0.86, 0.84, 0.0), Color(0.92, 0.88, 0.86, 0.5), Color(0.95, 0.9, 0.88, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = ramp_g
	pm.color_ramp = ramp
	_smoke.process_material = pm
	var puff := QuadMesh.new()
	puff.size = Vector2(2.2, 2.2)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pmat.vertex_color_use_as_albedo = true
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	var sg := Gradient.new()
	sg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	soft.gradient = sg
	pmat.albedo_texture = soft
	puff.material = pmat
	_smoke.draw_pass_1 = puff
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_smoke)
	_smoke.position = sang + Vector3(0.0, 1.7, 0.0)


func _build_rival_ledge() -> void:
	var top := Vector3(RIVAL.x, RIVAL_DECK, RIVAL.y)
	var deck := _props.box(Vector3(RIVAL_R * 2.0, 0.8, RIVAL_R * 2.0), top - Vector3(0.0, 0.4, 0.0), _props.mat(Color(0.62, 0.55, 0.53)))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(RIVAL_R * 2.0, 0.8, RIVAL_R * 2.0)
	cs.shape = shape
	body.add_child(cs)
	deck.add_child(body)
	_props.hermitage(top, RIVAL_R, 12.0)


# ── Prayer flags ─────────────────────────────────────────────────────────────

const LUNGTA := [Color(0.18, 0.36, 0.78), Color(0.95, 0.94, 0.90), Color(0.80, 0.16, 0.14), Color(0.20, 0.60, 0.28), Color(0.96, 0.78, 0.18)]


func _build_flags() -> void:
	## Flags stay behind the flyer, over the courtyard: from the gompa roof
	## corners down to the chorten spires. Nothing strung across the view of
	## the sky in front of the terrace.
	var roof := DECK + 0.7 + 6.4 + 1.5
	for side in [-1.0, 1.0]:
		var corner := Vector3(side * 6.0, roof, GOMPA_FRONT + 0.8)
		var spire := Vector3(side * 8.5, DECK + 6.2, 104.0)
		_flag_line(spire, corner)
	## From the hermitage mast down to the rival's deck edge.
	var rm := Vector3(RIVAL.x + RIVAL_R - 1.2, RIVAL_DECK + 6.0, RIVAL.y - RIVAL_R + 1.2)
	_flag_line(rm, Vector3(RIVAL.x - RIVAL_R + 0.5, RIVAL_DECK + 0.4, RIVAL.y + RIVAL_R - 0.5))


func _flag_line(a: Vector3, b: Vector3) -> void:
	var n := int(a.distance_to(b) / 0.55)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := b - a
	var len := along.length()
	var dir := along / len
	## Local frame: X along the string, Y down, Z the flap direction.
	var node := Node3D.new()
	add_child(node)
	var side := dir.cross(Vector3.UP).normalized()
	node.global_transform = Transform3D(Basis(dir, Vector3.UP, side), a)
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var x := t * len
		var sag := -sin(t * PI) * len * 0.06
		var w := 0.36
		var h := 0.42
		var col: Color = LUNGTA[i % LUNGTA.size()]
		var p0 := Vector3(x - w * 0.5, sag, 0.0)
		var p1 := Vector3(x + w * 0.5, sag, 0.0)
		var p2 := Vector3(x + w * 0.5, sag - h, 0.0)
		var p3 := Vector3(x - w * 0.5, sag - h, 0.0)
		for v in [[p0, 0.0], [p1, 0.0], [p2, 1.0], [p0, 0.0], [p2, 1.0], [p3, 1.0]]:
			st.set_color(col)
			st.set_uv(Vector2(0.0, v[1]))
			st.add_vertex(v[0])
	var mat := ShaderMaterial.new()
	mat.shader = FLAG_SHADER
	_flag_mats.append(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)


func _build_bridge() -> void:
	## Across the saddle from the compound's west wall to the rival's outcrop.
	var a := Vector3(COMPOUND.position.x - 0.2, DECK + 0.05, 100.0)
	var b := Vector3(RIVAL.x + RIVAL_R + 0.2, RIVAL_DECK + 0.05, RIVAL.y)
	var rails := _props.rope_bridge(a, b, 3.2)
	## Prayer flags along one handrail.
	var rail: Array = rails[1]
	if rail.size() > 2:
		_flag_line(rail[1] + Vector3.UP * 0.4, rail[rail.size() - 2] + Vector3.UP * 0.4)


## Hamlets on the valley sides: a handful of hill houses each, lamps lit.
## Scan for sites above the mist on slopes a footing can take, then grow a
## few hamlets from well-spaced seeds.
func _build_village() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2718
	var sites: Array[Vector3] = []
	var x := -400.0
	while x <= 400.0:
		var z := -420.0
		while z <= 260.0:
			var jx := x + rng.randf_range(-4.0, 4.0)
			var jz := z + rng.randf_range(-4.0, 4.0)
			var cx := sin(jz * 0.004) * 24.0
			var h := height_at(jx, jz)
			var slope := absf(height_at(jx + 3.0, jz) - h) + absf(height_at(jx, jz + 3.0) - h)
			var clear := absf(jx - cx) > 105.0 and not COMPOUND.grow(30.0).has_point(Vector2(jx, jz)) and Vector2(jx, jz).distance_to(RIVAL) > 30.0
			if clear and slope < 3.6 and h > MIST_Y + 12.0 and h < 95.0:
				sites.append(Vector3(jx, h, jz))
			z += 10.0
		x += 10.0
	## Seeds: well apart, some each side of the valley.
	var seeds: Array[Vector3] = []
	sites.shuffle()
	for s0 in sites:
		var ok := true
		for sd in seeds:
			if Vector2(s0.x, s0.z).distance_to(Vector2(sd.x, sd.z)) < 150.0:
				ok = false
				break
		if ok:
			seeds.append(s0)
		if seeds.size() >= 4:
			break
	var placed: Array[Vector3] = []
	for sd in seeds:
		var n := 0
		for s1 in sites:
			if n >= 5:
				break
			if Vector2(s1.x, s1.z).distance_to(Vector2(sd.x, sd.z)) > 55.0:
				continue
			var crowded := false
			for q in placed:
				if Vector2(s1.x, s1.z).distance_to(Vector2(q.x, q.z)) < 11.0:
					crowded = true
					break
			if crowded:
				continue
			## Sit on the lowest corner: the uphill side goes into the slope.
			var fy := s1.y
			for c in [Vector2(-3.5, -3.0), Vector2(3.5, -3.0), Vector2(3.5, 3.0), Vector2(-3.5, 3.0)]:
				fy = minf(fy, height_at(s1.x + c.x, s1.z + c.y))
			## Face down the slope, toward the valley.
			var down := Vector2(height_at(s1.x - 4.0, s1.z) - height_at(s1.x + 4.0, s1.z), height_at(s1.x, s1.z - 4.0) - height_at(s1.x, s1.z + 4.0))
			var yaw := atan2(-down.x, -down.y) if down.length() > 0.2 else rng.randf() * TAU
			_props.village_house(Vector3(s1.x, fy + 0.2, s1.z), yaw, rng)
			placed.append(s1)
			n += 1


## Lammergeiers riding the valley air in slow circles.
func _build_eagles() -> void:
	var mesh := _props.eagle_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 3:
		var mi := MeshInstance3D.new()
		mi.name = "Eagle%d" % i
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_eagles.append({
			"node": mi,
			"c": Vector3(rng.randf_range(-120.0, 120.0), rng.randf_range(70.0, 120.0), rng.randf_range(-260.0, -60.0)),
			"r": rng.randf_range(45.0, 90.0),
			"w": rng.randf_range(0.07, 0.12) * (1.0 if i % 2 == 0 else -1.0),
			"ph": rng.randf() * TAU,
		})


func _tick_eagles(_delta: float) -> void:
	for e in _eagles:
		e["ph"] = float(e["ph"]) + float(e["w"]) * _delta
		var ph: float = e["ph"]
		var c: Vector3 = e["c"]
		var r: float = e["r"]
		var pos := c + Vector3(cos(ph) * r, sin(ph * 2.3) * 4.0, sin(ph) * r)
		var fwd := Vector3(-sin(ph), 0.0, cos(ph)) * signf(float(e["w"]))
		var node: MeshInstance3D = e["node"]
		node.global_position = pos
		node.look_at(pos + fwd, Vector3.UP)
		## Bank into the turn; now and then a few slow wingbeats.
		node.rotate_object_local(Vector3.FORWARD, -0.35 * signf(float(e["w"])))
		var beat := sin(Time.get_ticks_msec() * 0.006 + ph * 7.0)
		var flapping := fmod(absf(ph) * 3.0, TAU) < 0.9
		node.scale = Vector3(1.0, 1.0 + (0.5 * beat if flapping else 0.0), 1.0) * 1.6


func _plan_rocket_pads() -> void:
	for s in [Vector2(28.0, -30.0), Vector2(-36.0, -110.0), Vector2(46.0, -170.0)]:
		rocket_pads.append(Vector3(s.x, height_at(s.x, s.y) + 0.2, s.y))
