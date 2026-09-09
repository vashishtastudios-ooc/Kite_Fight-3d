class_name CityGenerator
extends Node3D

## Stylized city: 3D building kits around a dressed patang terrace.

const BUILDING_SHADER := preload("res://shaders/building.gdshader")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const HORIZON_SHADER := preload("res://shaders/horizon_silhouette.gdshader")
const STYLIZED_SHADER := preload("res://shaders/stylized.gdshader")
const TILE_SHADER := preload("res://shaders/roof_tiles.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const CHAIR_SCENE := preload("res://assets/terrace/wooden+chair+3d+model.glb")
const KIT_BLUE := preload("res://assets/buildings/blue building 3d model.glb")
const KIT_TALL := preload("res://assets/buildings/tall modern building 3d model.glb")
const KIT_MASJID := preload("res://assets/buildings/ornate arch gateway masjid 3d model.glb")
const KIT_HOUSE := preload("res://assets/buildings/building 3d model (1).glb")
const KIT_SHOP := preload("res://assets/buildings/old shop building 3d model (1).glb")
const KIT_NEON := preload("res://assets/buildings/neon-lit buildings 3d model.glb")
const KIT_CLOCK := preload("res://assets/buildings/clock+tower+3d+model.glb")
const KIT_STORY2 := preload("res://assets/buildings/two-story+house+3d+model.glb")
const KIT_PALACE := preload("res://assets/buildings/pink palace 3d model.glb")
const KIT_TREE := preload("res://assets/street/pink tree.glb")
const KIT_TREE_BIG := preload("res://assets/street/tree+3d+model.glb")
const KIT_TREE_ORANGE := preload("res://assets/street/orange+flowering+tree+3d+model.glb")
const KIT_TREE_DENSE := preload("res://assets/street/densetree+3d+model (1).glb")
const KIT_TREE_STYL := preload("res://assets/street/stylized+tree+3d+model.glb")
const KIT_CART := preload("res://assets/street/fruit+cart+3d+model.glb")
const KIT_CHAI := preload("res://assets/street/chai+stall+3d+model.glb")

const PLOT := 20.0
## Only the terrace and next-door roofs cast. Mid/far kits stay lit and colorful.
const SHADOW_RADIUS := 42.0

var spawn_position: Vector3 = Vector3(0.0, 20.3, 92.0)
var rooftop_height: float = 20.0
var rooftop_bounds: Rect2 = Rect2(-6.5, 86.0, 13.0, 13.0)
var building_aabbs: Array[AABB] = []
var player_building_aabb: AABB
var rocket_pads: Array[Vector3] = []
var palace_aabb: AABB
var rival_roof_aabb: AABB

var _rng := RandomNumberGenerator.new()
var _kit_houses: Array[PackedScene] = []
var _kit_story2: Array[PackedScene] = []
var _kit_shops: Array[PackedScene] = []
var _kit_mid: Array[PackedScene] = []
var _kit_neon: Array[PackedScene] = []
var _kit_towers: Array[PackedScene] = []
var _kit_landmarks: Array[PackedScene] = []
var _tower_budget: int = 0
var _last_kit_aabb: AABB
var _building_mat: ShaderMaterial
var _styl_mat: ShaderMaterial
var _water_mat: ShaderMaterial
var _box_mesh: BoxMesh
var _cyl_mesh: CylinderMesh
var _sph_mesh: SphereMesh


func build() -> void:
	_rng.seed = 20260827
	_box_mesh = BoxMesh.new()
	_box_mesh.size = Vector3.ONE
	_cyl_mesh = CylinderMesh.new()
	_cyl_mesh.top_radius = 0.5
	_cyl_mesh.bottom_radius = 0.5
	_cyl_mesh.height = 1.0
	_cyl_mesh.radial_segments = 20
	_sph_mesh = SphereMesh.new()
	_sph_mesh.radius = 0.5
	_sph_mesh.height = 1.0
	_sph_mesh.radial_segments = 16
	_sph_mesh.rings = 8
	_building_mat = ShaderMaterial.new()
	_building_mat.shader = BUILDING_SHADER
	_styl_mat = ShaderMaterial.new()
	_styl_mat.shader = STYLIZED_SHADER
	_classify_kits()
	_build_ground()
	_build_player_rooftop()
	_dress_front_street()
	_build_side_neighbors()
	_place_launcher_homes()
	_scatter_city_360()
	_dress_side_trees()
	_add_far_kit_city()
	_scatter_far_greenery()
	_build_water()


func palace_watch_spot() -> Vector3:
	## Flat front-left of the pink palace roof — the 3 o'clock terrace in the
	## title shot, facing the player. Sit below the corner chhatris.
	if palace_aabb.size.length_squared() < 1.0:
		return Vector3(38.0, 24.2, 43.5)
	var x := lerpf(palace_aabb.position.x, palace_aabb.end.x, 0.28)
	var z := palace_aabb.end.z - clampf(palace_aabb.size.z * 0.10, 1.2, 2.8)
	var y := palace_aabb.end.y - clampf(palace_aabb.size.y * 0.08, 1.4, 2.8)
	return Vector3(x, y + 0.05, z)


func _place_launcher_homes() -> void:
	## Three visible roofs in front: left, right, and a third further down the right street.
	rocket_pads.clear()
	var spots: Array[Vector3] = [
		Vector3(-40.0, 0.0, 54.0),
		Vector3(40.0, 0.0, 54.0),
		Vector3(24.0, 0.0, 46.0),
	]
	var heights: Array[float] = [16.8, 16.8, 15.4]
	for i in spots.size():
		var feet: Vector3 = spots[i]
		var yaw := atan2(-feet.x, 92.0 - feet.z)
		if _place_kit_building(KIT_HOUSE, feet, heights[i], yaw, 10.0, 0.4):
			rocket_pads.append(Vector3(feet.x, _last_kit_aabb.end.y + 0.32, feet.z))
			_dress_kit_roof(_last_kit_aabb)
	if rocket_pads.size() < 3:
		_fallback_flank_pads()
	if rocket_pads.size() > 3:
		rocket_pads.resize(3)


func _fallback_flank_pads() -> void:
	for aabb in building_aabbs:
		if aabb.intersects(player_building_aabb):
			continue
		if aabb.size.y < 8.0:
			continue
		var c := aabb.get_center()
		if c.z > 80.0 or c.z < 42.0:
			continue
		if absf(c.x) < 22.0 or absf(c.x) > 58.0:
			continue
		var pad := Vector3(c.x, aabb.end.y + 0.32, c.z)
		var dup := false
		for p in rocket_pads:
			if p.distance_to(pad) < 8.0:
				dup = true
				break
		if not dup:
			rocket_pads.append(pad)


func rival_hand_position() -> Vector3:
	## Right-hand house next to the player terrace (the +X neighbor).
	if rival_roof_aabb.size.length_squared() > 1.0:
		var c := rival_roof_aabb.get_center()
		return Vector3(
			c.x - rival_roof_aabb.size.x * 0.08,
			rival_roof_aabb.end.y + 0.10,
			c.z - rival_roof_aabb.size.z * 0.16
		)
	return Vector3(24.5, 17.4, 90.0)


func nearest_building_chop(pos: Vector3) -> float:
	var chop := 0.0
	for aabb in building_aabbs:
		var closest := _closest_point_aabb(aabb, pos)
		var d := pos.distance_to(closest)
		if d < 14.0:
			chop = maxf(chop, 1.0 - d / 14.0)
	return clampf(chop, 0.0, 1.0)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(3600.0, 3600.0)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	ground.mesh = plane
	var gmat := ShaderMaterial.new()
	gmat.shader = GROUND_SHADER
	## Only micro bump/roughness detail is sampled; colour, lanes and dirt are
	## built procedurally so no baked highway markings show.
	gmat.set_shader_parameter("ground_rough", load("res://assets/ground/Road007_2K-JPG_Roughness.jpg"))
	gmat.set_shader_parameter("ground_normal", load("res://assets/ground/Road007_2K-JPG_NormalGL.jpg"))
	gmat.set_shader_parameter("ground_repeat", Vector2(0.22, 0.22))
	## Road grid aligned to the plot layout (roads run the plot boundaries).
	gmat.set_shader_parameter("grid_spacing", PLOT)
	gmat.set_shader_parameter("grid_origin", Vector2(16.0, 82.0))
	gmat.set_shader_parameter("road_half_width", 3.6)
	gmat.set_shader_parameter("road_color", Color(0.26, 0.22, 0.19))
	gmat.set_shader_parameter("dirt_color", Color(0.47, 0.36, 0.25))
	gmat.set_shader_parameter("dirt_color2", Color(0.36, 0.27, 0.18))
	## Far ground dissolves into the exact horizon-sky tone, on the same distance
	## window as the fog, so distant ground reads as haze/sky — not empty lots.
	gmat.set_shader_parameter("haze_color", Color(0.90, 0.66, 0.56))
	gmat.set_shader_parameter("haze_start", 300.0)
	gmat.set_shader_parameter("haze_end", 640.0)
	ground.material_override = gmat
	ground.position = Vector3(0.0, -0.04, 40.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3600.0, 1.0, 3600.0)
	col.shape = shape
	col.position = Vector3(0.0, -0.54, 40.0)
	body.add_child(col)
	add_child(body)


func _build_water() -> void:
	## A calm dusk sea surrounding the city out to the horizon. Transparent over
	## the land (discarded there), full water past the shore. Cheap, mobile-safe.
	var plane := PlaneMesh.new()
	plane.size = Vector2(8000.0, 8000.0)
	plane.subdivide_width = 16
	plane.subdivide_depth = 16
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	## Just above the street ground so it sorts on top past the shore.
	sea.position = Vector3(0.0, -0.02, 92.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	sea.extra_cull_margin = 4000.0
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = WATER_SHADER
	_water_mat.set_shader_parameter("hub", Vector3(0.0, 0.0, 92.0))
	_water_mat.set_shader_parameter("land_radius", 780.0)
	_water_mat.set_shader_parameter("shore_width", 60.0)
	_water_mat.set_shader_parameter("haze_color", Color(0.90, 0.66, 0.56))
	sea.material_override = _water_mat
	add_child(sea)


func set_water_sun(to_sun: Vector3) -> void:
	if _water_mat and to_sun.length() > 0.01:
		_water_mat.set_shader_parameter("sun_dir", to_sun.normalized())


func _build_player_rooftop() -> void:
	## House kit, decorative parapet toward the masjid (-Z). Props sit on the deck.
	var node := KIT_HOUSE.instantiate() as Node3D
	if node == null:
		return
	node.name = "PlayerHouse"
	add_child(node)
	node.rotation.y = PI
	var aabb := _node_aabb(node)
	if aabb.size.y < 0.2:
		node.queue_free()
		return
	var target_h := 23.0
	var footprint := 18.0
	var s_xz := footprint / maxf(aabb.size.x, aabb.size.z)
	node.scale = Vector3(s_xz, target_h / aabb.size.y, s_xz)
	node.force_update_transform()
	aabb = _node_aabb(node)
	node.global_position = Vector3(0.0, -aabb.position.y, 92.0)
	node.force_update_transform()
	player_building_aabb = _node_aabb(node)
	building_aabbs.append(player_building_aabb)
	_enable_prop_shadows(node, true)
	var deck := _estimate_deck_y(node, player_building_aabb)
	rooftop_height = deck
	var c := player_building_aabb.get_center()
	## Open front terrace toward the masjid (-Z). Stay off the back stair hut.
	var walk_x := player_building_aabb.size.x * 0.22
	var walk_z := player_building_aabb.size.z * 0.22
	rooftop_bounds = Rect2(c.x - walk_x, c.z - walk_z, walk_x * 2.0, walk_z * 1.25)
	spawn_position = Vector3(c.x, deck + 0.38, c.z - walk_z * 0.55)
	_add_box_body(Vector3(c.x, deck - 0.12, c.z - walk_z * 0.15), Vector3(walk_x * 2.0, 0.24, walk_z * 1.4))
	_dress_house_roof()


func _dress_front_street() -> void:
	## Orange in the empty lot. Green tree two blocks out at 10 o'clock.
	_place_prop(KIT_TREE_ORANGE, Vector3(10.0, 0.0, 34.0), 13.4, 0.25)
	_place_prop(KIT_TREE_BIG, Vector3(-36.0, 0.0, 8.0), 21.0, -0.55)
	## Face east toward the palace so the counter reads from the terrace.
	_place_prop(KIT_CHAI, Vector3(-22.0, 0.0, 30.0), 5.3, -PI * 0.5)
	## Dense + stylized pair, left of the big tree and a bit farther out.
	_place_prop(KIT_TREE_DENSE, Vector3(-44.0, 0.0, -4.0), 15.5, 0.42)
	_place_prop(KIT_TREE_STYL, Vector3(-50.5, 0.0, 1.5), 14.2, -0.68)
	var spots: Array[Dictionary] = [
		{"tree": Vector3(10.0, 0.0, 8.0), "yaw": 0.35, "h": 13.0, "cart": Vector3(3.4, 0.0, 8.2)},
		{"tree": Vector3(-11.0, 0.0, -10.0), "yaw": -0.45, "h": 11.9, "cart": Vector3(-3.2, 0.0, 8.0)},
		{"tree": Vector3(8.0, 0.0, -32.0), "yaw": 1.05, "h": 11.6, "cart": Vector3(3.0, 0.0, 7.6)},
		{"tree": Vector3(-7.0, 0.0, -52.0), "yaw": 0.2, "h": 12.3, "cart": Vector3(2.8, 0.0, 7.4)},
	]
	for spec in spots:
		var feet: Vector3 = spec["tree"]
		if not _place_prop(KIT_TREE, feet, spec["h"], spec["yaw"]):
			continue
		var cart_feet: Vector3 = feet + spec["cart"]
		## Face the terrace so the stall reads from the roof.
		var cart_yaw: float = PI + _rng.randf_range(-0.15, 0.15)
		_place_prop(KIT_CART, cart_feet, 3.4, cart_yaw)


func _place_prop(scene: PackedScene, feet: Vector3, target_h: float, yaw: float, _footprint: float = -1.0, shadows: bool = true) -> bool:
	if scene == null:
		return false
	if _on_building_foot(feet):
		return false
	var node := scene.instantiate() as Node3D
	if node == null:
		return false
	add_child(node)
	node.rotation.y = yaw
	var aabb := _node_aabb(node)
	if aabb.size.y < 0.05:
		node.queue_free()
		return false
	var s := target_h / aabb.size.y
	node.scale = Vector3(s, s, s)
	node.force_update_transform()
	aabb = _node_aabb(node)
	node.global_position = Vector3(feet.x, -aabb.position.y, feet.z)
	node.force_update_transform()
	_hide_imported_ground(node)
	_enable_prop_shadows(node, shadows)
	return true


func _hide_imported_ground(node: Node) -> void:
	## Tripo kits often ship a thin square dirt slab under the mesh.
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var aabb := mi.get_aabb()
		if aabb.size.y < 0.22 and maxf(aabb.size.x, aabb.size.z) > 1.6 and aabb.position.y < 0.35:
			mi.visible = false
	for child in node.get_children():
		_hide_imported_ground(child)


func _on_building_foot(feet: Vector3) -> bool:
	for aabb in building_aabbs:
		if feet.x > aabb.position.x + 0.7 and feet.x < aabb.end.x - 0.7 \
				and feet.z > aabb.position.z + 0.7 and feet.z < aabb.end.z - 0.7:
			return true
	return false


func _dress_side_trees() -> void:
	## Random roadside clumps on the left and right — not a stamped row.
	var kits: Array[PackedScene] = [KIT_TREE_DENSE, KIT_TREE_STYL, KIT_TREE, KIT_TREE_ORANGE]
	for ix in range(-10, 12):
		for iz in range(-10, 9):
			var px := 16.0 + (float(ix) + 0.5) * PLOT
			var pz := 82.0 + (float(iz) + 0.5) * PLOT
			var radius := Vector2(px, pz - 92.0).length()
			if radius < 30.0 or radius > 175.0:
				continue
			if _in_kite_window(px, pz, radius):
				continue
			## Keep the open front street clear; dress left and right mohalla.
			if absf(px) < 20.0 and pz < 72.0:
				continue
			var skip := _rng.randf()
			if skip < 0.28:
				continue
			var count := 1
			if skip > 0.70:
				count = 2
			if skip > 0.88:
				count = 3
			for _i in count:
				var kit: PackedScene = kits[_rng.randi_range(0, kits.size() - 1)]
				var off := _roadside_offset(px, pz)
				var feet := Vector3(px + off.x, 0.0, pz + off.z)
				var h := _rng.randf_range(12.0, 16.5)
				if kit == KIT_TREE:
					h = _rng.randf_range(11.5, 13.6)
				elif kit == KIT_TREE_ORANGE:
					h = _rng.randf_range(12.0, 14.2)
				var yaw := _rng.randf_range(0.0, TAU)
				_place_prop(kit, feet, h, yaw, -1.0, radius < 70.0)


func _roadside_offset(px: float, pz: float) -> Vector3:
	var fx := fposmod((px - 16.0) / PLOT, 1.0)
	var fz := fposmod((pz - 82.0) / PLOT, 1.0)
	var to_x := (-fx if fx < 0.5 else 1.0 - fx) * PLOT
	var to_z := (-fz if fz < 0.5 else 1.0 - fz) * PLOT
	if absf(to_x) < absf(to_z):
		return Vector3(to_x * 0.70, 0.0, _rng.randf_range(-5.0, 5.0))
	return Vector3(_rng.randf_range(-5.0, 5.0), 0.0, to_z * 0.70)


func _build_side_neighbors() -> void:
	## Rival roof to the left. Pack the right-hand lots next to the fly-from terrace.
	if _place_kit_building(KIT_HOUSE, Vector3(-34.0, 0.0, 96.0), 18.0, PI * 0.5, 12.0):
		_dress_kit_roof(_last_kit_aabb)
	if _place_kit_building(KIT_HOUSE, Vector3(-52.0, 0.0, 100.0), 17.0, 0.1, 11.5):
		_dress_kit_roof(_last_kit_aabb)
	## Plot centers on the street grid (roads at x=16 and z=82).
	if _place_kit_building(KIT_HOUSE, Vector3(26.0, 0.0, 92.0), 16.5, PI, 11.5):
		_dress_kit_roof(_last_kit_aabb)
		rival_roof_aabb = _last_kit_aabb
	_place_kit_building(KIT_SHOP, Vector3(26.0, 0.0, 74.0), 10.5, 0.1, 10.5)
	if _place_kit_building(KIT_HOUSE, Vector3(26.0, 0.0, 110.0), 17.0, 0.05, 11.5):
		_dress_kit_roof(_last_kit_aabb)
	_place_kit_building(KIT_NEON, Vector3(16.5, 0.0, 80.0), 8.5, PI * 0.08, 6.2)
	_place_kit_building(KIT_NEON, Vector3(44.0, 0.0, 92.0), 11.0, PI * 0.5, 7.2)
	_place_kit_building(KIT_SHOP, Vector3(44.0, 0.0, 74.0), 11.0, -0.12, 10.5)
	if _place_kit_building(KIT_BLUE, Vector3(44.0, 0.0, 110.0), 18.0, 0.2, 11.0):
		_dress_kit_roof(_last_kit_aabb)
	_place_kit_building(KIT_SHOP, Vector3(62.0, 0.0, 92.0), 10.0, PI * 0.95, 10.0)
	_place_kit_building(KIT_NEON, Vector3(62.0, 0.0, 74.0), 10.0, 0.3, 7.0)
	if _place_kit_building(KIT_HOUSE, Vector3(62.0, 0.0, 110.0), 15.5, -0.15, 11.0):
		_dress_kit_roof(_last_kit_aabb)
	if _place_kit_building(KIT_SHOP, Vector3(-28.0, 0.0, 78.0), 11.0, PI * 0.15, 11.0):
		_dress_kit_roof(_last_kit_aabb)
	if _place_kit_building(KIT_BLUE, Vector3(-48.0, 0.0, 118.0), 20.0, 0.4, 12.0):
		_dress_kit_roof(_last_kit_aabb)


func _classify_kits() -> void:
	for sc in _scan_building_kits():
		var path := str(sc.resource_path).to_lower()
		if "masjid" in path or "gateway" in path:
			_kit_landmarks.append(sc)
		elif "clock" in path or "palace" in path:
			pass
		elif "two-story" in path or "two+story" in path:
			_kit_story2.append(sc)
			_kit_houses.append(sc)
		elif "tall" in path or "modern" in path:
			_kit_towers.append(sc)
		elif "neon" in path:
			_kit_neon.append(sc)
		elif "shop" in path:
			_kit_shops.append(sc)
		elif "building 3d model (1)" in path:
			_kit_houses.append(sc)
		else:
			_kit_mid.append(sc)
	if _kit_houses.is_empty():
		_kit_houses = _kit_mid.duplicate()
	if _kit_story2.is_empty():
		_kit_story2 = _kit_houses.duplicate()
	if _kit_mid.is_empty():
		_kit_mid = _kit_houses.duplicate()


func _pick(list: Array[PackedScene]) -> PackedScene:
	if list.is_empty():
		return null
	return list[_rng.randi_range(0, list.size() - 1)]


func _scatter_city_360() -> void:
	## Dense mohalla blocks: kits packed inside each plot, lanes left on the grid.
	## Clock tower on the old masjid lot, dead ahead of the terrace.
	_place_kit_building(KIT_CLOCK, Vector3(0.0, 0.0, -72.0), 46.0, 0.0, 10.0)
	## Second tower stays off to the right skyline.
	_place_kit_building(KIT_CLOCK, Vector3(80.0, 0.0, 14.0), 36.0, -0.18, 8.4)
	## Pink palace on the right lot (not the road), square to the grid.
	_place_kit_building(KIT_PALACE, Vector3(46.0, 0.0, 32.0), 26.4, 0.0, 26.0)
	palace_aabb = _last_kit_aabb
	for ix in range(-10, 12):
		for iz in range(-10, 9):
			var px := 16.0 + (float(ix) + 0.5) * PLOT
			var pz := 82.0 + (float(iz) + 0.5) * PLOT
			var radius := Vector2(px, pz - 92.0).length()
			if radius < 22.0 or radius > 210.0:
				continue
			if absf(px) < 16.0 and absf(pz - 92.0) < 16.0:
				continue
			## Keep the front-left lot open for the shade tree (no leftover neon/shops).
			if px < -6.0 and pz > 64.0 and pz < 88.0:
				continue
			## Keep the tree + chai plaza clear so the stall stays visible from the roof.
			if px < -12.0 and px > -46.0 and pz > 4.0 and pz < 42.0:
				continue
			if absf(px - 46.0) < 10.0 and absf(pz - 32.0) < 10.0:
				continue
			if _in_kite_window(px, pz, radius):
				continue
			if _rng.randf() < 0.07:
				continue
			_fill_plot(px, pz, radius)


func _fill_plot(px: float, pz: float, radius: float) -> void:
	## Rows face the lane, so blocks read as terraced streets instead of scatter.
	var along_x := (_rng.randi() % 2) == 0
	var roll := _rng.randf()
	if roll < 0.34:
		_plot_row(px, pz, along_x, 3, radius)
	elif roll < 0.74:
		_plot_row(px, pz, along_x, 2, radius)
	else:
		_plot_single(px, pz, radius)


func _plot_row(px: float, pz: float, along_x: bool, count: int, radius: float) -> void:
	var span := 13.4
	var step := span / float(count)
	var footprint := step * 0.95
	var yaw := (0.0 if along_x else PI * 0.5) + _rng.randf_range(-0.03, 0.03)
	for i in count:
		var off := (float(i) - (float(count) - 1.0) * 0.5) * step
		var x := px + (off if along_x else 0.0)
		var z := pz + (0.0 if along_x else off)
		var kit := _street_kit(radius, false)
		if kit == null:
			continue
		var h := maxf(7.0, _kit_height(kit) * _rng.randf_range(0.58, 1.32))
		if _rng.randf() < 0.12:
			h *= _rng.randf_range(1.15, 1.45)
		_place_kit_building(kit, Vector3(x, 0.0, z), h, yaw, footprint, 0.25)


func _plot_single(px: float, pz: float, radius: float) -> void:
	var kit := _street_kit(radius, true)
	if kit == null:
		return
	var footprint := _rng.randf_range(11.0, 13.0)
	var yaw := float(_rng.randi() % 4) * PI * 0.5 + _rng.randf_range(-0.04, 0.04)
	var h := _kit_height(kit) * _rng.randf_range(0.85, 1.22)
	if _rng.randf() < 0.14:
		h *= _rng.randf_range(1.2, 1.55)
	_place_kit_building(kit, Vector3(px, 0.0, pz), h, yaw, footprint, 0.3)


func _street_kit(radius: float, allow_tower: bool) -> PackedScene:
	if allow_tower and _tower_budget > 0 and radius > 105.0 and _rng.randf() < 0.18:
		var tower := _pick(_kit_towers)
		if tower != null:
			_tower_budget -= 1
			return tower
	var roll := _rng.randf()
	if roll < 0.14 and not _kit_neon.is_empty():
		return _pick(_kit_neon)
	if roll < 0.40 and not _kit_story2.is_empty():
		return _pick(_kit_story2)
	if roll < 0.58 and not _kit_shops.is_empty():
		return _pick(_kit_shops)
	if roll < 0.70 and not _kit_mid.is_empty():
		return _pick(_kit_mid)
	return _pick(_kit_houses)


func _kit_height(kit: PackedScene) -> float:
	var path := str(kit.resource_path).to_lower()
	if "clock" in path:
		return _rng.randf_range(34.0, 42.0)
	if "palace" in path:
		return _rng.randf_range(18.0, 24.0)
	if "two-story" in path or "two+story" in path:
		return _rng.randf_range(8.5, 14.0)
	if "neon" in path:
		return _rng.randf_range(7.5, 13.0)
	if "shop" in path:
		return _rng.randf_range(7.0, 14.5)
	if "blue" in path:
		return _rng.randf_range(11.0, 26.0)
	return _rng.randf_range(9.0, 24.0)


func _try_place_kit(scene: PackedScene, feet: Vector3, h: float, yaw: float, footprint: float = -1.0, allow_window: bool = false) -> void:
	var radius := Vector2(feet.x, feet.z - 92.0).length()
	if not allow_window and _in_kite_window(feet.x, feet.z, radius):
		return
	_place_kit_building(scene, feet, h, yaw, footprint)


func _in_kite_window(x: float, z: float, radius: float) -> bool:
	## Open fly path ahead. Right-hand lots next to the terrace stay buildable.
	if x > 15.0:
		return false
	var dx := x
	var dz := 92.0 - z
	if dz < 8.0:
		return false
	var ang := absf(atan2(dx, dz))
	return radius < 95.0 and ang < deg_to_rad(36.0)


func _add_far_kit_city() -> void:
	## Mid-rise kits packed in rings so the horizon stays a city, not empty haze.
	var cheap: Array[PackedScene] = []
	cheap.append_array(_kit_houses)
	cheap.append_array(_kit_shops)
	cheap.append_array(_kit_neon)
	cheap.append_array(_kit_mid)
	if cheap.is_empty():
		return
	## Keep the city solid out to the fog line (~640 m) so it reads as one dense
	## metropolis dissolving into haze. Nothing is built past the fog since it
	## would be invisible — that keeps startup fast.
	_fill_far_ring(cheap, 210.0, 380.0, 21.0, 0.02, 14.0, 34.0, 15.0, 21.0)
	_fill_far_ring(cheap, 380.0, 560.0, 26.0, 0.03, 13.0, 32.0, 18.0, 26.0)
	_fill_far_ring(cheap, 560.0, 720.0, 28.0, 0.03, 12.0, 30.0, 18.0, 28.0)
	_plug_forward_horizon(cheap)


func _scatter_far_greenery() -> void:
	## Break up the far ground with clumps of the tree kits so the distant map
	## reads as a lived-in city, not bare lots. Cheap: no collision, far-draw
	## fade, no shadows, and never in the open kite window.
	var kits: Array[PackedScene] = [KIT_TREE_DENSE, KIT_TREE, KIT_TREE_ORANGE, KIT_TREE_BIG, KIT_TREE_STYL]
	var hub := Vector3(0.0, 0.0, 92.0)
	var r := 165.0
	var ring := 0
	while r < 640.0:
		var spacing := 28.0
		var count := maxi(10, int((TAU * r) / spacing))
		var twist := float(ring) * 0.27
		for i in count:
			if _rng.randf() < 0.42:
				continue
			var ang := twist + (float(i) / float(count)) * TAU
			var rad := r + _rng.randf_range(-spacing * 0.32, spacing * 0.32)
			var x := hub.x + sin(ang) * rad
			var z := hub.z - cos(ang) * rad
			var radius := Vector2(x, z - 92.0).length()
			if _in_kite_window(x, z, radius):
				continue
			var kit: PackedScene = kits[_rng.randi_range(0, kits.size() - 1)]
			var h := _rng.randf_range(10.5, 16.0)
			## Occasional tight pair so it clumps like real greenery.
			var reps := 2 if _rng.randf() < 0.28 else 1
			for _k in reps:
				var jx := 0.0 if _k == 0 else _rng.randf_range(-6.0, 6.0)
				var jz := 0.0 if _k == 0 else _rng.randf_range(-6.0, 6.0)
				_place_far_tree(kit, Vector3(x + jx, 0.0, z + jz), h, _rng.randf_range(0.0, TAU))
		r += spacing * 1.35
		ring += 1


func _place_far_tree(scene: PackedScene, feet: Vector3, target_h: float, yaw: float) -> bool:
	if scene == null:
		return false
	if _on_building_foot(feet):
		return false
	var node := scene.instantiate() as Node3D
	if node == null:
		return false
	add_child(node)
	node.rotation.y = yaw
	var aabb := _node_aabb(node)
	if aabb.size.y < 0.05:
		node.queue_free()
		return false
	var s := target_h / aabb.size.y
	node.scale = Vector3(s, s, s)
	node.force_update_transform()
	aabb = _node_aabb(node)
	node.global_position = Vector3(feet.x, -aabb.position.y, feet.z)
	node.force_update_transform()
	_hide_imported_ground(node)
	_mark_far_draw(node)
	return true


func _fill_far_ring(kits: Array[PackedScene], r0: float, r1: float, spacing: float, skip: float, h_lo: float, h_hi: float, fp_lo: float, fp_hi: float) -> void:
	var hub := Vector3(0.0, 0.0, 92.0)
	var r := r0
	var ring := 0
	while r < r1:
		var count := maxi(8, int((TAU * r) / spacing))
		var twist := float(ring) * 0.17
		for i in count:
			if _rng.randf() < skip:
				continue
			var ang := twist + (float(i) / float(count)) * TAU
			var jitter := _rng.randf_range(-spacing * 0.18, spacing * 0.18)
			var rad := r + jitter
			var x := hub.x + sin(ang) * rad
			var z := hub.z - cos(ang) * rad
			var kit := _pick(kits)
			if kit == null:
				continue
			var h := _rng.randf_range(h_lo, h_hi)
			if _rng.randf() < 0.10:
				h *= _rng.randf_range(1.2, 1.55)
			var footprint := _rng.randf_range(fp_lo, fp_hi)
			var yaw := float(_rng.randi() % 4) * PI * 0.5 + _rng.randf_range(-0.06, 0.06)
			_place_kit_building(kit, Vector3(x, 0.0, z), h, yaw, footprint, -1.0, false)
		r += spacing * 0.88
		ring += 1


func _plug_forward_horizon(kits: Array[PackedScene]) -> void:
	## Close the street vanishing point with mid-rise blocks behind the clock
	## tower. Only as deep as the fog reaches — past that it would be invisible.
	var cell := 18.0
	for ix in range(-8, 9):
		for iz in range(0, 17):
			var x := float(ix) * cell + _rng.randf_range(-2.5, 2.5)
			var z := -118.0 - float(iz) * cell + _rng.randf_range(-2.0, 2.0)
			if absf(x) < 11.0 and z > -175.0:
				continue
			if _rng.randf() < 0.08:
				continue
			var kit := _pick(kits)
			if kit == null:
				continue
			var h := _rng.randf_range(14.0, 32.0)
			if _rng.randf() < 0.12:
				h *= _rng.randf_range(1.15, 1.4)
			var footprint := _rng.randf_range(14.0, 19.0)
			var yaw := float(_rng.randi() % 4) * PI * 0.5 + _rng.randf_range(-0.05, 0.05)
			_place_kit_building(kit, Vector3(x, 0.0, z), h, yaw, footprint, -1.0, false)


func _add_horizon_haze() -> void:
	## Soft city teeth at the rim so the V-cam never sees a bare disk edge.
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1180.0
	mesh.bottom_radius = 1180.0
	mesh.height = 70.0
	mesh.radial_segments = 64
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.name = "HorizonHaze"
	mi.mesh = mesh
	mi.position = Vector3(0.0, 35.0, 92.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mat := ShaderMaterial.new()
	mat.shader = HORIZON_SHADER
	## Faint warm filler only — the dense far city is the real horizon now, so
	## this just softens any last sliver where rooftops meet haze.
	mat.set_shader_parameter("tint", Color(0.86, 0.60, 0.48))
	mat.set_shader_parameter("opacity", 0.32)
	mi.material_override = mat
	add_child(mi)


func _add_horizon_treeline() -> void:
	## Distant rolling hills beyond the city — far enough and tall enough to rise
	## above the hazed far-city rooflines, so the rim reads as land receding into
	## haze, not a hard skyline edge. Two soft bands for depth.
	_horizon_hill_ring(1320.0, 165.0, 24.0, 0.62, Color(0.52, 0.44, 0.48), 0.8)
	_horizon_hill_ring(1160.0, 110.0, 46.0, 0.66, Color(0.50, 0.43, 0.42), 0.45)


func _horizon_hill_ring(radius: float, height: float, columns: float, hscale: float, tint: Color, opacity: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 96
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.name = "HorizonHills"
	mi.mesh = mesh
	mi.position = Vector3(0.0, height * 0.5, 92.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mat := ShaderMaterial.new()
	mat.shader = HORIZON_SHADER
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("opacity", opacity)
	mat.set_shader_parameter("columns", columns)
	mat.set_shader_parameter("roundness", 1.0)
	mat.set_shader_parameter("height_scale", hscale)
	mi.material_override = mat
	add_child(mi)


func _scan_building_kits() -> Array[PackedScene]:
	var kits: Array[PackedScene] = [KIT_BLUE, KIT_TALL, KIT_MASJID, KIT_HOUSE, KIT_SHOP, KIT_NEON, KIT_CLOCK, KIT_STORY2, KIT_PALACE]
	var seen: Dictionary = {}
	for sc in kits:
		seen[sc.resource_path] = true
	var dir := DirAccess.open("res://assets/buildings")
	if dir == null:
		return kits
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".glb") or fname.ends_with(".gltf"):
			var path := "res://assets/buildings/%s" % fname
			if not seen.has(path):
				var sc := load(path)
				if sc is PackedScene:
					kits.append(sc)
					seen[path] = true
		fname = dir.get_next()
	dir.list_dir_end()
	return kits


func _place_kit_building(scene: PackedScene, feet: Vector3, target_h: float, yaw: float, footprint: float = -1.0, clearance: float = 1.8, register: bool = true) -> bool:
	if scene == null:
		return false
	var node := scene.instantiate() as Node3D
	if node == null:
		return false
	add_child(node)
	node.rotation.y = yaw
	var aabb := _node_aabb(node)
	if aabb.size.y < 0.2:
		node.queue_free()
		return false
	if footprint < 4.0:
		footprint = clampf(target_h * 0.42, 13.0, 22.0)
	var path := str(scene.resource_path).to_lower()
	if "neon" in path:
		var front := feet.z < 96.0 and absf(feet.x) < 72.0
		target_h *= 0.68 if front else 0.82
		footprint = maxf(5.5, footprint * (0.70 if front else 0.82))
	## Front-view house (pink/warm) and blue kits were stretched too tall.
	if feet.z < 90.0 and (scene == KIT_BLUE or scene == KIT_HOUSE):
		target_h *= 0.6
	var s_y := target_h / aabb.size.y
	var s_xz := footprint / maxf(aabb.size.x, aabb.size.z)
	node.scale = Vector3(s_xz, s_y, s_xz)
	node.force_update_transform()
	aabb = _node_aabb(node)
	node.global_position = Vector3(feet.x, -aabb.position.y, feet.z)
	node.force_update_transform()
	_hide_imported_ground(node)
	var world_aabb := _node_aabb(node)
	if clearance >= 0.0:
		var probe := world_aabb.grow(clearance)
		for other in building_aabbs:
			if probe.intersects(other):
				node.queue_free()
				return false
	var near_hub := register and world_aabb.get_center().distance_to(Vector3(0.0, 12.0, 92.0)) < SHADOW_RADIUS
	_enable_prop_shadows(node, near_hub)
	if not register:
		_mark_far_draw(node)
	if register:
		building_aabbs.append(world_aabb)
	_last_kit_aabb = world_aabb
	if near_hub:
		_add_box_body(world_aabb.get_center(), world_aabb.size)
	if scene != KIT_MASJID and scene != KIT_CLOCK and scene != KIT_PALACE:
		_tint_kit(node, _kit_tint())
	return true


func _kit_tint() -> Color:
	## Most kits: ±10% warmth/value. Some get a faded painted-wall wash.
	if _rng.randf() < 0.18:
		var paints: Array[Color] = [
			Color(0.70, 0.82, 0.94),
			Color(0.76, 0.88, 0.74),
			Color(0.94, 0.88, 0.62),
			Color(0.90, 0.74, 0.64),
		]
		var paint: Color = paints[_rng.randi_range(0, paints.size() - 1)]
		return Color.WHITE.lerp(paint, _rng.randf_range(0.22, 0.38))
	var warm := _rng.randf_range(-0.10, 0.10)
	var value := _rng.randf_range(0.92, 1.10)
	return Color(
		clampf((1.0 + warm) * value, 0.82, 1.18),
		clampf((1.0 + warm * 0.35) * value, 0.82, 1.18),
		clampf((1.0 - warm * 0.45) * value, 0.82, 1.18)
	)


func _tint_kit(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.material_override is BaseMaterial3D:
			mi.material_override = _tinted_base(mi.material_override as BaseMaterial3D, tint)
		elif mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(s)
				if mat is BaseMaterial3D:
					mi.set_surface_override_material(s, _tinted_base(mat as BaseMaterial3D, tint))
	for child in node.get_children():
		_tint_kit(child, tint)


func _tinted_base(mat: BaseMaterial3D, tint: Color) -> BaseMaterial3D:
	var dup := mat.duplicate() as BaseMaterial3D
	var c := dup.albedo_color
	dup.albedo_color = Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)
	return dup


func _node_aabb(node: Node) -> AABB:
	var acc := AABB()
	var first := true
	if node is VisualInstance3D:
		var local: AABB = (node as VisualInstance3D).get_aabb()
		var xf := (node as Node3D).global_transform
		acc = xf * local
		first = false
	for child in node.get_children():
		var sub := _node_aabb(child)
		if sub.size.length_squared() < 0.0001:
			continue
		if first:
			acc = sub
			first = false
		else:
			acc = acc.merge(sub)
	return acc


func _add_mesh_collision(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			mi.create_trimesh_collision()
			mi.extra_cull_margin = 12.0
	for child in node.get_children():
		_add_mesh_collision(child)


func _estimate_deck_y(node: Node, aabb: AABB) -> float:
	## Walkable terrace is below parapet caps / stair-hut roof. Median of inner verts.
	var ys: Array[float] = []
	var cx := aabb.get_center().x
	var cz := aabb.get_center().z
	var inner_x := aabb.size.x * 0.28
	var inner_z := aabb.size.z * 0.28
	var y_lo := aabb.position.y + aabb.size.y * 0.48
	var y_hi := aabb.end.y - aabb.size.y * 0.1
	_collect_deck_ys(node, ys, cx, cz, inner_x, inner_z, y_lo, y_hi)
	if ys.size() < 12:
		return aabb.end.y - 1.45
	ys.sort()
	return ys[int(ys.size() * 0.45)]


func _collect_deck_ys(node: Node, ys: Array[float], cx: float, cz: float, inner_x: float, inner_z: float, y_lo: float, y_hi: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var xf := mi.global_transform
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
					continue
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				for v in verts:
					var w := xf * v
					if absf(w.x - cx) > inner_x or absf(w.z - cz) > inner_z:
						continue
					if w.y < y_lo or w.y > y_hi:
						continue
					ys.append(w.y)
	for child in node.get_children():
		_collect_deck_ys(child, ys, cx, cz, inner_x, inner_z, y_lo, y_hi)


func _dress_house_roof() -> void:
	## Chair and manjha on the walkable deck — keep the front parapet clear to walk.
	var roof_y := rooftop_height
	var cx := player_building_aabb.get_center().x
	var cz := player_building_aabb.get_center().z
	var w := player_building_aabb.size.x
	var d := player_building_aabb.size.z
	_add_chair(Vector3(cx - w * 0.2, roof_y + 0.02, cz - d * 0.14))
	_add_manjha_gear(roof_y, cx, cz, w, d)


func _dress_kit_roof(aabb: AABB) -> void:
	## Tanks and dishes on the roofs you can actually read from the terrace.
	if aabb.size.y < 4.0:
		return
	var c := aabb.get_center()
	var y := aabb.end.y - 1.3
	_add_water_tank(Vector3(c.x + aabb.size.x * 0.24, y, c.z + aabb.size.z * 0.2))
	if _rng.randf() < 0.65:
		_add_dish(Vector3(c.x - aabb.size.x * 0.26, y, c.z - aabb.size.z * 0.2))


func _add_water_tank(base: Vector3) -> void:
	var stand := _styl(Color(0.45, 0.42, 0.38), 0.82)
	var body := _styl(Color(0.12, 0.14, 0.16), 0.42, 0.18)
	var rim := _styl(Color(0.18, 0.20, 0.22), 0.4, 0.22)
	_add_box(base + Vector3(0.0, 0.12, 0.0), Vector3(1.55, 0.24, 1.55), stand, true)
	_add_cyl(base + Vector3(0.0, 1.05, 0.0), 1.18, 1.55, body, true)
	_add_cyl(base + Vector3(0.0, 1.86, 0.0), 1.22, 0.1, rim, false)
	_add_sph(base + Vector3(0.0, 1.98, 0.0), 1.05, 0.42, rim, false)
	var pipe := _styl(Color(0.55, 0.56, 0.52), 0.35, 0.4)
	_add_cyl(base + Vector3(0.62, 0.55, 0.0), 0.08, 0.9, pipe, false)
	_add_cyl(base + Vector3(0.62, 0.18, 0.35), 0.07, 0.7, pipe, false)


func _add_dish(pos: Vector3) -> void:
	var metal := _styl(Color(0.72, 0.74, 0.76), 0.28, 0.55)
	var pole := _styl(Color(0.40, 0.41, 0.42), 0.45, 0.35)
	_add_cyl(pos + Vector3(0.0, 0.58, 0.0), 0.06, 1.15, pole, false)
	var dish := MeshInstance3D.new()
	dish.mesh = _sph_mesh
	dish.material_override = metal
	dish.position = pos + Vector3(0.08, 0.72, -0.12)
	dish.scale = Vector3(0.95, 0.16, 0.95)
	dish.rotation_degrees = Vector3(-28.0, 18.0, 0.0)
	dish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(dish)
	_add_cyl(pos + Vector3(0.02, 0.55, -0.38), 0.03, 0.55, pole, false)


func _add_clothesline(roof_y: float, cx: float, cz: float, w: float, d: float) -> void:
	var wood := _styl(Color(0.42, 0.28, 0.16), 0.8)
	var wire := _styl(Color(0.35, 0.35, 0.36), 0.4, 0.2)
	var a := Vector3(cx - w * 0.38, roof_y + 1.55, cz + d * 0.34)
	var b := Vector3(cx + w * 0.1, roof_y + 1.52, cz + d * 0.36)
	_add_cyl(Vector3(a.x, roof_y + 0.85, a.z), 0.05, 1.5, wood, false)
	_add_cyl(Vector3(b.x, roof_y + 0.85, b.z), 0.05, 1.5, wood, false)
	var mid := (a + b) * 0.5
	var along := b - a
	var line := MeshInstance3D.new()
	line.mesh = _box_mesh
	line.material_override = wire
	line.position = mid
	line.scale = Vector3(0.02, 0.02, along.length())
	add_child(line)
	if along.length_squared() > 0.01:
		line.look_at(b, Vector3.UP)
	var cloths: Array[Color] = [
		Color(0.82, 0.22, 0.18),
		Color(0.92, 0.90, 0.82),
		Color(0.18, 0.42, 0.55),
	]
	for i in cloths.size():
		var t := (float(i) + 1.0) / float(cloths.size() + 1)
		var p := a.lerp(b, t) + Vector3(0.0, -0.42, 0.0)
		_add_box(p, Vector3(0.55, 0.7, 0.04), _styl(cloths[i], 0.92), false)


func _add_manjha_gear(_roof_y: float, _cx: float, _cz: float, _w: float, _d: float) -> void:
	## Wooden firkis on the back parapet — not a row of bricks in the walk path.
	var wood := _styl(Color(0.42, 0.26, 0.14), 0.78)
	var dark := _styl(Color(0.22, 0.14, 0.08), 0.7)
	var roof_y := rooftop_height
	var z := rooftop_bounds.end.y - 0.38
	var x0 := rooftop_bounds.position.x + 0.55
	for i in 3:
		var x := x0 + float(i) * 0.62
		_add_cyl(Vector3(x, roof_y + 0.16, z), 0.16, 0.28, wood, false)
		_add_cyl(Vector3(x, roof_y + 0.32, z), 0.18, 0.05, dark, false)
		_add_cyl(Vector3(x, roof_y + 0.05, z), 0.18, 0.05, dark, false)


func _add_chair(pos: Vector3) -> void:
	var chair := CHAIR_SCENE.instantiate() as Node3D
	chair.name = "TerraceChair"
	chair.position = pos
	chair.rotation_degrees.y = 180.0
	add_child(chair)
	_enable_prop_shadows(chair)
	_add_box_body(pos + Vector3(0.0, 0.45, 0.0), Vector3(0.55, 0.9, 0.58))


func _mark_far_draw(node: Node) -> void:
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		gi.visibility_range_end = 1550.0
		gi.visibility_range_end_margin = 180.0
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for child in node.get_children():
		_mark_far_draw(child)


func _enable_prop_shadows(node: Node, enabled: bool = true) -> void:
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_enable_prop_shadows(child, enabled)


func _styl(color: Color, rough: float = 0.78, metal: float = 0.0) -> ShaderMaterial:
	var mat: ShaderMaterial = _styl_mat.duplicate()
	mat.set_shader_parameter("albedo_color", color)
	mat.set_shader_parameter("roughness", rough)
	mat.set_shader_parameter("metalness", metal)
	return mat


func _add_box(pos: Vector3, size: Vector3, mat: Material, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	if collide:
		_add_box_body(pos, size)


func _add_cyl(pos: Vector3, diameter: float, height: float, mat: Material, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl_mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3(diameter, height, diameter)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	if collide:
		_add_box_body(pos, Vector3(diameter, height, diameter))


func _add_sph(pos: Vector3, diameter: float, height: float, mat: Material, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _sph_mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3(diameter, height, diameter)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	if collide:
		_add_box_body(pos, Vector3(diameter, height, diameter))


func _add_box_body(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _closest_point_aabb(aabb: AABB, p: Vector3) -> Vector3:
	return Vector3(
		clampf(p.x, aabb.position.x, aabb.end.x),
		clampf(p.y, aabb.position.y, aabb.end.y),
		clampf(p.z, aabb.position.z, aabb.end.z)
	)
