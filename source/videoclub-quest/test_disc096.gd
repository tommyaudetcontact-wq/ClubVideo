extends SceneTree

func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	game.touch_profile=true
	root.add_child(game)
	game.set_physics_process(false)
	game.touch_controls.set_physics_process(false)
	var c=game.clerk
	c.set_physics_process(false)
	c.customers.set_physics_process(false)
	var record:Dictionary=c.reserve_stock(0)
	var item:Dictionary=c.new_case(0,Vector3(-4,1.1,3),"shelve")
	item.record=record
	load("res://clerk_inventory.gd").bind(item.node,record)
	c.locks.set_locked(item.node,false)
	c.pick_case(item,1,false)
	var ui=game.touch_controls
	ui.toggle_case()
	await create_timer(.2).timeout
	ui.use_disc()
	var original_uid:int=c.inspection.carried_data.uid
	assert(c.inspection.finger==0 and item.node.get_meta("disc_movie")==-1)
	ui.toggle_case()
	assert(not c.inspection.opened and is_instance_valid(c.inspection.carried))
	game.head.global_position=Vector3(-4.5,1.65,4)
	var aim:Node3D=game.aim_hands[0]
	aim.global_position=game.head.global_position
	aim.look_at(Vector3(-4.5,0,3.5))
	ui.tap_aim=true
	await physics_frame
	assert(ui.drop_on_surface())
	assert(c.inspection.finger==0 and c.inspection.loose_discs.is_empty() and game.held==item.node)
	# The dedicated action reinserts even with the lid closed and a floor behind it.
	ui.case_action()
	assert(c.inspection.opened and c.inspection.carried==null)
	assert(item.node.get_meta("disc_uid")==original_uid)
	ui.use_disc()
	assert(c.inspection.finger==0)
	ui.drop()
	assert(c.inspection.finger==0 and game.held==item.node)
	ui.use_target()
	assert(c.inspection.carried==null and item.node.get_meta("disc_uid")==original_uid)
	# A separate disc is created only by a deliberate target on the sorting table.
	ui.use_disc()
	game.head.global_position=Vector3(2.1,1.65,-8.0)
	aim.global_position=game.head.global_position
	aim.look_at(Vector3(2.1,.905,-8.7))
	assert(ui.disc_sorting_point().is_finite())
	ui.use_disc("table")
	assert(c.inspection.carried==null and c.inspection.loose_discs.size()==1)
	assert(c.inspection.loose_discs[0].data.uid==original_uid)
	c.inspection.take_loose_disc(c.inspection.loose_discs[0],0)
	ui.case_action()
	assert(c.inspection.carried==null and item.node.get_meta("disc_uid")==original_uid)
	print("DISC096_OK: closed-case insertion, no accidental floor drops or case release, intentional sorting deposit, original disc identity preserved")
	quit(0)
