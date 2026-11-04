extends SceneTree
func _initialize()->void:
	await process_frame
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.hud.visible=false
	game.head.global_position=Vector3(-4.1,1.35,5.4)
	game.head.look_at(Vector3(-5.12,.78,4.10))
	await create_timer(1.4).timeout
	get_root().get_texture().get_image().save_png("res://../machine-gommes-dans-club.png")
	game.modes.toggle_pause()
	await create_timer(.3,true).timeout
	get_root().get_texture().get_image().save_png("res://../menu-pause-vr.png")
	game.modes.toggle_pause()
	var record:Dictionary
	for r in game.dvd_records:
		if int(r.movie)==12:
			record=r
			break
	game._take(record,1,false)
	game.held.reparent(game.head,false)
	game.held.position=Vector3(.13,-.09,-.48)
	game.held.rotation=Vector3.ZERO
	await create_timer(.5).timeout
	get_root().get_texture().get_image().save_png("res://../dvd-gremlins-recto.png")
	game._flip_held()
	await create_timer(.5).timeout
	get_root().get_texture().get_image().save_png("res://../dvd-gremlins-verso.png")
	quit()

