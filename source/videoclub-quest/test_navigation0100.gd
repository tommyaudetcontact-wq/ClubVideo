extends SceneTree
func person(nav,id:int,position:Vector3)->Dictionary:
	var node=load("res://clerk_props.gd").customer(nav,id%6)
	node.position=position
	var entry:Dictionary={"node":node,"id":id,"state":"inspect","path":PackedVector2Array(),"cursor":0,"wait":1000.0,"movie":0,"companions":[],"return_job":{},"rental_count":1,"patience_started":false}
	nav.customers.append(entry)
	return entry
func _initialize():
	await process_frame
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	var c=g.clerk
	c.set_physics_process(false)
	var nav=c.customers
	nav.set_physics_process(false)
	g.head.global_position=Vector3(4,1.65,-7)
	var blocker:Dictionary=person(nav,0,Vector3(-4,0,3))
	var walker:Dictionary=person(nav,1,Vector3(-4,0,1))
	var goal:=Vector3(-4,0,5.5)
	assert(nav.route(walker,goal))
	for i in range(2400):
		nav._physics_process(1.0/72)
		if walker.node.position.distance_to(goal)<.2:break
	assert(walker.node.position.distance_to(goal)<.2)
	blocker.node.position=Vector3(-4,0,7.25)
	for key in ["yield_target","yield_origin","yield_until","yield_path","yield_cursor","yield_return"]:blocker.erase(key)
	walker.node.position=Vector3(-4,0,6)
	goal=Vector3(-4,0,9)
	assert(nav.route(walker,goal))
	var yielded:=false
	for i in range(4320):
		nav._physics_process(1.0/72)
		yielded=yielded or blocker.has("yield_target")
		if walker.node.position.distance_to(goal)<.2:break
	if walker.node.position.distance_to(goal)>=.2:print("NAV_BLOCKED ",walker.node.position," blocker=",blocker.node.position," yield=",blocker.get("yield_target"))
	assert(yielded and walker.node.position.distance_to(goal)<.2)
	for i in range(1200):nav._physics_process(1.0/72)
	assert(not blocker.has("yield_target") and blocker.node.position.distance_to(Vector3(-4,0,7.25))<.2 and blocker.state=="inspect")
	for entry in nav.customers:entry.node.queue_free()
	nav.customers.clear()
	nav.prepare_queue_positions()
	c.max_basket=1
	for i in range(4):
		var shopper:Dictionary=person(nav,100+i,nav.queue_positions[i])
		if i==0:
			shopper.companions=[6]
			nav.attach_companions(shopper)
		assert(c.select_film(shopper))
		nav.join_queue(shopper)
	assert(nav.customers.map(func(shopper):return shopper.queue_slot)==[0,2,3,4])
	for i in range(72):nav._physics_process(1.0/72)
	assert(not c.active.is_empty() and c.active.id==100 and not c.active.items.is_empty())
	for item in c.active.items.duplicate():assert(c.handoff_item(item))
	for i in range(360):
		c.customer_delay=maxf(0,c.customer_delay-1.0/72)
		nav._physics_process(1.0/72)
		if not c.active.is_empty():break
	assert(not c.active.is_empty() and c.active.id==101)
	for a in nav.customers:
		for b in nav.customers:
			if a==b:continue
			assert(a.node.position.distance_to(b.node.position)>.48)
	print("NAV0100_OK: aisle detour, narrow doorway yielding, resumed route, ordered single-file queue, first handoff under one second, prompt next client, no overlaps")
	quit()
