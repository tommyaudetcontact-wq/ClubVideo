extends SceneTree
const Actor=preload("res://customer_actor.gd")
const Props=preload("res://clerk_props.gd")

func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	var c=game.clerk
	c.customers.set_physics_process(false)
	c.set_physics_process(false)
	for i in range(8):
		var node=Props.customer(c.customers,i)
		var visual:Node3D=node.get_node("ActorVisual")
		assert(visual!=null)
		var player:AnimationPlayer=visual.get_meta("player")
		assert(Actor.mount(node)!=node)
		for name in ["Idle","Walk","CarryWalk","CarryIdle","Pick","HandOff"]:
			assert(player.has_animation(name))
			assert(player.get_animation(name).get_track_count()>10)
		var skeleton:Skeleton3D=visual.find_children("*","Skeleton3D",true,false)[0]
		var wrist:=skeleton.find_bone("CaseHand")
		player.play("Pick")
		player.advance(0)
		var before:=skeleton.get_bone_global_pose(wrist).origin
		player.seek(1.4,true)
		skeleton.force_update_all_bone_transforms()
		assert(before.distance_to(skeleton.get_bone_global_pose(wrist).origin)>.08)
		node.queue_free()
	var couple={"node":Props.customer(c.customers,0),"companions":[1]}
	var family={"node":Props.customer(c.customers,2),"companions":[6,7]}
	for group in [couple,family]:c.customers.attach_companions(group)
	assert(couple.node.has_node("Companion0/ActorVisual"))
	assert(family.node.has_node("Companion1/ActorVisual"))
	assert(c.customers.traffic_interval(.25,1).y<c.customers.traffic_interval(.45,1).x)
	assert(c.customers.traffic_interval(.75,3).y<c.customers.traffic_interval(.90,3).x)
	couple.node.queue_free()
	family.node.queue_free()
	c.customers.spawn_customer()
	var client:Dictionary=c.customers.customers[0]
	client.companions=[6,7]
	var saved:Dictionary=game.session.snapshot()
	assert(saved.clients[0].companions==[6,7])
	var fresh=load("res://main.tscn").instantiate()
	root.add_child(fresh)
	assert(fresh.session.restore(saved))
	assert(fresh.clerk.customers.customers[0].node.has_node("Companion1/ActorVisual"))
	print("ACTORS067_OK eight avatars, six clips each, animated wrist, family save migration, peak and quiet windows")
	quit()
