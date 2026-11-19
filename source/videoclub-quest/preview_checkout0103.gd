extends SceneTree
func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.clerk.set_physics_process(false)
	game.clerk.customers.set_physics_process(false)
	var monitor:Node3D
	for node in game.clerk.find_children("*","MeshInstance3D",true,false):
		if node.material_override and node.get_parent().name=="CheckoutTrailerTV" and node.mesh is QuadMesh:
			monitor=node
			break
	assert(monitor)
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.global_position=monitor.global_position+Vector3(-.06,.40,-1.08)
	camera.look_at(monitor.global_position+Vector3(-.13,-.03,0))
	camera.fov=60
	camera.make_current()
	await create_timer(8.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/recto/Documents/Codex/2026-11-01/va-x20/work/checkout-tv-upright.png")
	quit()


