extends SceneTree
func _initialize():
	await process_frame
	root.size=Vector2i(1400,1000)
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.clerk.customers.set_physics_process(false)
	g.clerk.set_physics_process(false)
	g.origin.transform=Transform3D.IDENTITY
	g.head.position=Vector3(0,1.65,-6.1)
	g.head.look_at(Vector3(0,1.3,-5.65))
	g.hud.visible=false
	for i in range(2):
		g.hand_visuals[i].visible=true
		g.hands[i].position=Vector3(-.13 if i==0 else .13,1.3,-5.75)
		g.hands[i].rotation=Vector3(0,0,PI)
	g.clerk.scanned=true
	g.clerk.drawer_open=true
	g.clerk.tender_received=true
	for value in [500,100,25,25]:g.clerk.wallet.take(0,value)
	g.clerk.wallet.supported[0]=true
	await create_timer(.5).timeout
	print("PALM basis=",g.clerk.wallet.roots[0].global_basis," pos=",g.clerk.wallet.roots[0].global_position," hand=",g.hands[0].global_position)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../cash-palm-preview.png")
	quit()
