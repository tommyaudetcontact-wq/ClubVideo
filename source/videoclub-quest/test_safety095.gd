extends SceneTree

func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	game.touch_profile=true
	root.add_child(game)
	game.set_physics_process(false)
	game.touch_controls.set_physics_process(false)
	var clerk=game.clerk
	clerk.set_physics_process(false)
	clerk.customers.set_physics_process(false)
	await physics_frame
	var item:Dictionary=clerk.new_case(0,Vector3(-4,1,4),"shelve")
	var body:RigidBody3D=item.node
	var safety=load("res://club_drop_safety.gd")
	var dropper=load("res://club_surface_drop.gd")
	var flat:=Basis(Vector3.RIGHT,-PI/2)
	var targets:Array[Vector3]=[Vector3(-.78,1.25,-6.44),Vector3(.12,1.375,-6.085),clerk.repairs.station-Vector3(0,.12,0),clerk.repairs.station+Vector3(.16,.075,0)]
	for target in targets:
		assert(not safety.clear_at(body,Transform3D(flat,target)))
		assert(dropper.release_body(body,clerk,target,Vector3(-.8,1.7,-7.1)))
		assert(safety.clear_at(body,body.global_transform))
		assert(body.global_position.distance_to(target)>.03)
		body.freeze=true
		body.collision_layer=0
		await physics_frame
	# Recover previously lost cases from the actual housing, not only new drops.
	body.global_transform=Transform3D(flat,targets[1])
	body.freeze=false
	body.collision_layer=8
	await physics_frame
	clerk.recover_blocked_cases()
	assert(safety.clear_at(body,body.global_transform))
	assert(body.global_position.y>targets[1].y)
	# A centre beside the register is insufficient if half the case overlaps it.
	var edge:=Vector3(-1.12,1.25,-6.44)
	assert(not safety.clear_at(body,Transform3D(flat,edge)))
	var safe:Vector3=safety.position_for(body,edge,flat)
	assert(safe.is_finite() and safety.clear_at(body,Transform3D(flat,safe)))
	assert(clerk.shift.capacity()==8)
	seed(9501)
	var quick:=0
	var slow:=0
	var ordinary:=0
	for index in range(200):
		var delay:float=clerk.customers.next_arrival_delay()
		if delay<6:quick+=1
		elif delay>=30:slow+=1
		else:ordinary+=1
	assert(quick>20 and slow>10 and ordinary>20)
	for index in range(12):clerk.customers.spawn_customer()
	assert(clerk.customers.population()==8)
	var slots:Array=[]
	for customer in clerk.customers.customers:
		clerk.customers.join_queue(customer)
		assert(not slots.has(customer.queue_slot) and not customer.path.is_empty())
		slots.append(customer.queue_slot)
	print("SAFETY095_OK: full case volumes, device solids, recovery, eight-client capacity, varied arrivals ",quick,"/",ordinary,"/",slow)
	quit(0)
