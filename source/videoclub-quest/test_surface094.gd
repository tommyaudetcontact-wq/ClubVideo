extends SceneTree

func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	game.touch_profile=true
	root.add_child(game)
	game.set_physics_process(false)
	var clerk=game.clerk
	clerk.set_physics_process(false)
	clerk.customers.set_physics_process(false)
	var ui=game.touch_controls
	ui.set_physics_process(false)
	await physics_frame
	game.head.global_position=Vector3(-4.5,1.65,4)
	var aim:Node3D=game.aim_hands[0]
	aim.global_position=game.head.global_position
	aim.look_at(Vector3(-4.5,0,3.5))
	ui.tap_aim=true
	var point:Vector3=ui.surface_drop_point()
	assert(point.is_finite() and point.y>.05 and point.y<.3)
	var item:Dictionary=clerk.new_case(0,point,"shelve")
	clerk.pick_case(item,1,false)
	assert(ui.drop_on_surface())
	assert(game.held==null and not item.node.freeze and item.node.global_position.is_equal_approx(point))
	await create_timer(.6).timeout
	assert(item.node.global_position.y<point.y and item.node.global_position.y>-.1)
	# Loose discs use a body only after they are released, and can be picked up again.
	var inspection=clerk.inspection
	inspection.carried=inspection.create_disc(0,true)
	inspection.add_child(inspection.carried)
	inspection.carried_data={"movie":0,"uid":42,"dirty":true,"inspected":true}
	inspection.finger=0
	assert(ui.drop_on_surface())
	assert(is_instance_valid(inspection.carried) and inspection.loose_discs.is_empty())
	# Existing saved loose discs still retain working physical pickup.
	load("res://club_surface_drop.gd").drop_disc(inspection,point)
	assert(inspection.loose_discs.size()==1)
	var loose:Dictionary=inspection.loose_discs[0]
	assert(is_instance_valid(loose.body) and not loose.body.freeze)
	await create_timer(.5).timeout
	assert(loose.node.global_position.y>-.1 and loose.node.global_position.y<point.y)
	inspection.take_loose_disc(loose,0)
	assert(inspection.loose_discs.is_empty() and inspection.carried_data.uid==42)
	load("res://club_surface_drop.gd").drop_disc(inspection,point)
	# Money conserves denomination and identity when dropped rather than deposited.
	clerk.set_drawer_open(true)
	clerk.tender_received=true
	var before:int=clerk.till[25]
	clerk.wallet.take(0,25)
	assert(clerk.wallet.total(0)==25)
	assert(ui.drop_on_surface())
	assert(clerk.wallet.total(0)==0 and clerk.wallet.loose.size()==1 and clerk.till[25]==before-1)
	assert(clerk.wallet.loose[0].value==25)
	print("SURFACE094_OK: floor raycast, physical case release, physical disc drop and pickup, conserved dropped money")
	quit(0)
