extends SceneTree
func _initialize():
	await process_frame
	root.size=Vector2i(1440,900)
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.hud.hide()
	var c=game.clerk
	c.set_physics_process(false)
	c.customers.set_physics_process(false)
	game.head.global_position=c.screen.to_global(Vector3(.09,.07,.49))
	game.head.look_at(c.screen.global_position,c.screen.global_basis.y)
	c.desktop.point(Vector2(704,652))
	await create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	c.terminal.get_texture().get_image().save_png("res://../bureau-065-interface.png")
	root.get_texture().get_image().save_png("res://../bureau-065-comptoir.png")
	quit()
