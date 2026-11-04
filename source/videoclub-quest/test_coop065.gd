extends SceneTree

func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	var c=game.clerk
	c.customers.set_physics_process(false)
	c.set_physics_process(false)
	var ui=c.desktop
	var ray:=Node3D.new()
	root.add_child(ray)
	ray.global_position=c.screen.to_global(Vector3(-.154,.082,.55))
	ray.look_at(c.screen.to_global(Vector3(-.154,.082,0)),c.screen.global_basis.y)
	var projected:Vector2=ui.project_ray(ray)
	assert(projected.distance_to(Vector2(48.19,126.95))<2)
	ui.point(Vector2(80,145),true)
	assert(ui.app==1)
	ui.point(Vector2(917,750),true)
	assert(ui.app==4)
	ui.point(Vector2(350,660),true)
	assert(c.lan.server!=null)
	c.customers.spawn_customer()
	var customer=c.customers.customers[0]
	customer.movie=0
	c.select_film(customer)
	customer.state="service"
	c.customer_ready(customer)
	print("COOP_READY ",c.lan.pin)
	await create_timer(16).timeout
	print("COOP_DRAWER ",c.drawer_open)
	quit(0 if c.drawer_open else 1)
