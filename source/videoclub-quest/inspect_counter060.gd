extends SceneTree
func _initialize():
	await process_frame
	root.size=Vector2i(1600,1000)
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.clerk.set_physics_process(false)
	g.clerk.customers.set_physics_process(false)
	g.hud.visible=false
	g.origin.transform=Transform3D.IDENTITY
	g.head.position=Vector3(1,2.6,-7.5)
	g.head.look_at(Vector3(0,1,-5.9))
	for node in g.model.find_children("*pop*","Node3D",true,false):print(node.name," ",node.global_position)
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../counter-wide060.png")
	quit()
