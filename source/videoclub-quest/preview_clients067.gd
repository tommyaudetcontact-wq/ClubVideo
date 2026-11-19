extends SceneTree

func _initialize():
	await process_frame
	root.size=Vector2i(1280,800)
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.hud.hide()
	game.clerk.set_physics_process(false)
	game.clerk.customers.set_physics_process(false)
	var props=load("res://clerk_props.gd")
	var actor=load("res://customer_actor.gd")
	var group=Node3D.new()
	game.add_child(group)
	group.position=Vector3(-2.25,0,5.83)
	group.rotation.y=-PI/2
	for i in range(4):
		var node=props.customer(group,[0,4,6,7][i])
		node.position=Vector3((i-1.5)*.49,0,0)
		node.rotation.y=PI
		actor.animate(node,"Idle")
	game.head.global_position=Vector3(-4.75,1.44,5.83)
	game.head.look_at(Vector3(-2.25,.91,5.83))
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../Clients-dans-le-club-067.png")
	quit()

