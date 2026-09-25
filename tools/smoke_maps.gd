extends SceneTree

## Run with APPDATA redirected to a disposable test directory.
## Exercises the real scene, map menu, character selection and kite launch.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	assert(main._map_id == OS.get_environment("KITE_MAP"))
	main._skip_intro_cam()
	main.hud._pick_character("boy")
	assert(main.hud._map_tiles.size() >= 4)
	if DisplayServer.get_name() != "headless":
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art_previews/%s_menu.png" % main._map_id)
	main.hud._pick_map(main._map_id)
	main.hud._pick_mode("battle")
	main.kite.launch()
	for i in 240:
		await physics_frame
	assert(main.kite.is_airborne(), "Player kite failed to stay airborne")
	assert(main.rival.is_airborne(), "Rival failed to stay airborne")
	print("ROOF CHECK feet=",main.player.global_position.y," deck=",main.city.rooftop_height," on_floor=",main.player.is_on_floor())
	assert(main.player.global_position.y >= main.city.rooftop_height - 0.1, "Player fell through roof")
	assert(main.kite.global_position.is_finite())
	print("GAMEPLAY SMOKE PASS ",main._map_id," player=",main.kite.global_position," rival=",main.rival.global_position)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art_previews/%s_gameplay.png" % main._map_id)
	main.queue_free()
	await process_frame
	await process_frame
	quit()
