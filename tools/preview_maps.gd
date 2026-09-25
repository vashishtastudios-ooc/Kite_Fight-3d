extends SceneTree

## Render the actual map and shared game lighting without starting a profile
## session or contacting the multiplayer server. Also checks the map contract.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var id := OS.get_environment("KITE_MAP")
	if id.is_empty():
		id = "jaipur_night"
	var stage := Node3D.new()
	root.add_child(stage)
	var main := preload("res://scripts/main.gd").new()
	var world := WorldEnvironment.new()
	var sun := DirectionalLight3D.new()
	main.world_env = world
	main.sun = sun
	main._configure_world()
	stage.add_child(world)
	stage.add_child(sun)
	var fill := main.get_node("FillLight")
	main.remove_child(fill)
	stage.add_child(fill)
	main.free()
	var map: Node3D = load("res://scripts/map_%s.gd" % id).new()
	stage.add_child(map)
	map.build()
	map.configure_world(world.environment, sun)
	assert(not map.is_solid(map.spawn_position + Vector3(0,1.5,0)), "Blocked player spawn")
	assert(not map.is_solid(map.rival_hand_position() + Vector3(0,1.5,0)), "Blocked rival spawn")
	assert(map.is_solid(map.spawn_position - Vector3(0,2,0)), "No player roof collision")
	assert(map.rooftop_bounds.has_point(Vector2(map.spawn_position.x,map.spawn_position.z)), "Spawn outside bounds")
	if id == "registan":
		for x in range(-11,12,2):
			for z in range(80,107,2):
				assert(map.height_at(x,z) < map.rooftop_height - 1.0, "Terrain intersects flight terrace")
	print("MAP CONTRACT PASS ",id," nodes=",stage.get_child_count())
	if DisplayServer.get_name() == "headless":
		quit()
		return
	root.size = Vector2i(1280,720)
	root.msaa_3d = Viewport.MSAA_2X
	root.use_taa = true
	var camera := Camera3D.new()
	camera.fov = 66
	camera.far = 2600
	stage.add_child(camera)
	camera.current = true
	var sp: Vector3 = map.spawn_position
	DirAccess.make_dir_recursive_absolute("res://art_previews")
	var views := [
		["vista",sp+Vector3(22,20,38),sp+Vector3(-20,27,-300)],
		["terrace",sp+Vector3(0,1.6,0),sp+Vector3(0,15,-220)],
		["landmark",Vector3(-70,68,-110),Vector3(-225,85,-250)] if id=="registan" else ["landmark",Vector3(-15,30,-90),Vector3(-105,24,-210)],
	]
	for view in views:
		camera.position = view[1]
		camera.look_at(view[2])
		await create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png("res://art_previews/%s_%s.png" % [id,view[0]])
		if view[0] == "vista":
			img.resize(960,540,Image.INTERPOLATE_LANCZOS)
			img.save_jpg("res://assets/ui/maps/%s.jpg" % id,0.94)
	print("MAP CAPTURES COMPLETE ",id)
	quit()
