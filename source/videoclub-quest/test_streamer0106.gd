extends SceneTree
func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.streamer_mode=true
	game.streamer=load("res://club_streamer.gd").new()
	game.add_child(game.streamer)
	game.streamer.setup(game)
	game.streamer.set_process(false)
	game.session.save_path="user://club-streamer.dat"
	var clerk=game.clerk
	clerk.shift.started=true
	clerk.customers._physics_process(60.0)
	assert(clerk.customers.customers.is_empty())
	assert(not clerk.shift.finish())
	game.streamer.queue_clients(5)
	for i in 5:
		game.streamer._process(2.0)
		var client:Dictionary=clerk.customers.customers.back()
		clerk.customers.activate_patience(client)
		assert(not client.patience_started)
		clerk.customers.customers.erase(client)
		client.node.queue_free()
	assert(game.streamer.queued_clients==0 and clerk.customers.next_id==5)
	game.streamer.drop_demo_case()
	assert(clerk.cases.back().kind=="streamer_gift")
	assert(game.session.snapshot().cases.is_empty())
	var case_item:Dictionary=clerk.new_case(0,Vector3(0,1,-6),"shelve")
	assert(game.session.snapshot().cases.size()==1)
	game.streamer.spawn_guest()
	assert(game.streamer.guest_seconds==300.0)
	assert(game.streamer.wrist.text.contains("5:00"))
	game.streamer._process(300.0)
	assert(game.streamer.guest==null)
	print("STREAMER0106_OK")
	quit()
