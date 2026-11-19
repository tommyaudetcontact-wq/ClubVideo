extends SceneTree
func _initialize():
	await process_frame
	root.size=Vector2i(1604,720)
	var game=load("res://main.tscn").instantiate()
	game.touch_profile=true
	root.add_child(game)
	await create_timer(1.2).timeout
	game.origin.transform=Transform3D.IDENTITY
	game.head.position=Vector3(-.6,1.65,-6.8)
	game.head.look_at(Vector3(-.6,1.2,-5))
	game.clerk.customers.set_physics_process(false)
	game.clerk.customers.spawn_customer()
	var customer:Dictionary=game.clerk.customers.customers[0]
	game.clerk.select_film(customer)
	game.clerk.customer_ready(customer)
	game.touch_controls.open_checkout()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame=root.get_texture().get_image()
	frame.save_png("C:/Users/recto/Documents/Codex/2026-11-01/va-x20/work/checkout094.png")
	print("PREVIEW094_OK")
	quit()
