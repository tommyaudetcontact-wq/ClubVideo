extends SceneTree
func _initialize():
	await process_frame
	root.size=Vector2i(1604,720)
	var game=load("res://main.tscn").instantiate()
	game.touch_profile=true
	root.add_child(game)
	await create_timer(1.2).timeout
	game.touch_controls.toggle_menu()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame=root.get_texture().get_image()
	frame.save_png("C:/Users/recto/Documents/Codex/2026-11-01/va-x20/work/messenger091-menu.png")
	var title:Node=game.touch_controls.menu.get_node("MessengerTitle")
	title.get_child(0).get_child(1).pressed.emit()
	assert(not paused and not game.modes.menu_open)
	print("MSN_MENU_CLOSE_OK")
	quit()
