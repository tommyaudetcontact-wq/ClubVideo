extends SceneTree
func capture(g,name:String,eye:Vector3,target:Vector3) -> void:
	g.head.global_position=eye;g.head.look_at(target)
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../"+name+".png")
func _initialize():
	set_meta("entrepreneur_mode",true)
	await process_frame
	root.size=Vector2i(1440,900)
	var g=load("res://main.tscn").instantiate();root.add_child(g)
	g.set_physics_process(false);g.clerk.set_physics_process(false);g.clerk.customers.set_physics_process(false);g.hud.hide()
	var b=g.entrepreneur
	await capture(g,"entrepreneur0111-empty",Vector3(2,1.7,4),Vector3(0,1.4,-5))
	b.buy_shelf(0);b.tick(11);b.open_parcel(int(b.state.orders[0].id))
	b.ghost.transform=b.snap_placement(Vector3(0,0,1),0,0);b.finish_placement()
	for i in 6:b.take_board(1);b.place_board()
	await capture(g,"entrepreneur0111-assembly",Vector3(.8,1.45,2.8),Vector3(0,.8,1))
	for i in 4:b.fasten_screw(.61)
	for id in b.state.offers.slice(0,8):b.buy_film(int(id))
	b.tick(11);var order:Dictionary=b.state.orders[0];b.open_parcel(int(order.id))
	b.packages[int(order.id)].position=Vector3(.7,.5,1.4)
	await capture(g,"entrepreneur0111-shelf",Vector3(1.2,1.7,3.2),Vector3(.1,.8,1))
	g.clerk.desktop.open_program(5);g.clerk.desktop.business_view.page=0;g.clerk.desktop.business_view.refresh()
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	g.clerk.terminal.get_texture().get_image().save_png("res://../entrepreneur0111-desktop.png")
	b.calendar_canvas.get_viewport().render_target_update_mode=SubViewport.UPDATE_ONCE
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	b.calendar_canvas.get_viewport().get_texture().get_image().save_png("res://../entrepreneur0111-calendar.png")
	await capture(g,"entrepreneur0111-backstore",Vector3(-.5,1.7,-9.8),Vector3(0,1.2,-13.7))
	print("PREVIEW0111_COMPLETE");quit()
