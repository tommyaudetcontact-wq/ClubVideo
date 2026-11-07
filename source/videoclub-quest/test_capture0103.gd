extends SceneTree
func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var clerk=game.clerk
	clerk.set_physics_process(false)
	clerk.customers.set_physics_process(false)
	await process_frame
	assert(game.model.find_child("popcorn-bucket",true,false)==null)
	for target in clerk.targets:assert(target.action!="page")
	var a=clerk.locks.create_bar()
	var b=clerk.locks.create_bar()
	clerk.locks.put_in_bin(a)
	clerk.locks.put_in_bin(b)
	game.hands[0].global_position=a.global_position
	assert(clerk.locks.interact(0))
	game.hands[1].global_position=b.global_position
	assert(clerk.locks.interact(1))
	assert(clerk.locks.occupies(0) and clerk.locks.occupies(1))
	for hand in [0,1]:
		game.hands[hand].global_position=clerk.lock_bin
		clerk.locks.update_hand()
		clerk.locks.release(hand)
	assert(a.get_meta("in_bin") and b.get_meta("in_bin"))
	assert(not clerk.locks.occupies(0) and not clerk.locks.occupies(1))
	clerk.customers.spawn_customer()
	var customer=clerk.customers.customers.back()
	clerk.select_film(customer)
	customer.node.position=Vector3(-.6,0,-5.05)
	customer.state="service"
	clerk.customer_ready(customer)
	clerk.customers.update_service_visual(customer,.016)
	load("res://customer_actor.gd").animate(customer.node,"Receive")
	await process_frame
	var palm:Vector3=clerk.customer_hand()
	print("PALM ",palm)
	assert(clerk.at_customer_palm(palm))
	assert(palm.y>1.19 and palm.z<-5.49)
	assert(not clerk.at_customer_palm(Vector3(-.83,1.14,-5.85)))
	var item=clerk.active.items[0]
	clerk.pick_case(item,0,true)
	game.held.global_position=Vector3(-.83,1.22,-5.85)
	clerk.release()
	assert(item in clerk.active.items)
	clerk.pick_case(item,0,true)
	game.held.global_position=palm
	clerk.release()
	assert(item not in clerk.cases)
	print("CAPTURE0103_OK")
	quit()
