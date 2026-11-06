extends SceneTree

func customer(nav,id:int,p:Vector3)->Dictionary:
	var node=load("res://clerk_props.gd").customer(nav,id%6)
	node.position=p
	var c:Dictionary={"node":node,"id":id,"state":"service","path":PackedVector2Array(),"cursor":0,"wait":0.0,"movie":0,"companions":[],"family":false,"return_job":{},"rental_count":1}
	nav.customers.append(c)
	return c

func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.clerk.set_physics_process(false)
	var nav=game.clerk.customers
	nav.set_physics_process(false)
	game.head.global_position=Vector3(4,1.65,5)
	var old=customer(nav,0,Vector3(-4,0,5.5))
	var leaving=customer(nav,5,Vector3(-4,0,4.5))
	nav.dismiss(leaving)
	var snapshot:Array=[]
	for x in range(-24,24):
		for z in range(-30,42):snapshot.append(nav.grid.is_point_solid(Vector2i(x,z)))
	var reached:=false
	for tick in range(2400):
		var before:Vector3=leaving.node.position
		nav._physics_process(1.0/60)
		if not nav.customers.has(leaving):
			assert(before.distance_to(Vector3(-4,0,9))<.30)
			reached=true
			break
		assert(leaving.node.position.distance_to(before)<=.017)
	assert(reached)
	var index:=0
	for x in range(-24,24):
		for z in range(-30,42):
			assert(snapshot[index]==nav.grid.is_point_solid(Vector2i(x,z)))
			index+=1
	# Block the narrow doorway itself; the waiting customer must make space.
	old.node.position=Vector3(-4,0,7.25)
	old.erase("yield_target")
	leaving=customer(nav,6,Vector3(-4,0,6.0))
	nav.dismiss(leaving)
	reached=false
	var yielded:=false
	for tick in range(3600):
		nav._physics_process(1.0/60)
		if old.has("yield_target"):yielded=true
		if not nav.customers.has(leaving):
			reached=true
			break
	if not reached:print("EXIT_BLOCKED ",leaving.node.position," cursor=",leaving.cursor," path=",leaving.path," old=",old.node.position," yield=",old.get("yield_target")," origin=",old.get("yield_origin"))
	assert(reached)
	print("EXIT098_OK: served customer detours around stationary older client, exits without teleporting; dynamic grid restored; blocked doorway cleared, yield=",yielded)
	quit(0)
