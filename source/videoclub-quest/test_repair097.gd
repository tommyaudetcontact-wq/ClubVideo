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
	var item:Dictionary=c.new_case(0,Vector3.ZERO,"shelve")
	item.record=record
	load("res://clerk_inventory.gd").bind(item.node,record)
	c.locks.set_locked(item.node,false)
	item.node.set_meta("dirty",true)
	c.pick_case(item,1,false)
	var ui=game.touch_controls
	ui.toggle_case()
	await create_timer(.2).timeout
	ui.use_disc()
	var uid:int=c.inspection.carried_data.uid
	game.head.global_position=c.repairs.station+Vector3(0,.3,.35)
	var aim:Node3D=game.aim_hands[0]
	aim.global_position=game.head.global_position
	aim.look_at(c.repairs.station)
	ui.tap_aim=true
	ui.use_disc("repair")
	assert(is_instance_valid(c.repairs.disc) and c.inspection.carried==null)
	# Reopening an empty case creates the invisible disc-slot placeholder that
	# used to swallow the tap intended for the repaired disc on the machine.
	ui.toggle_case()
	ui.toggle_case()
	await create_timer(.2).timeout
	assert(c.inspection.opened and not c.inspection.disc.visible)
	c.repairs.remaining=.05
	await create_timer(.2).timeout
	assert(ui.repair_action_label()=="Reprendre le disque")
	ui.use_target()
	assert(c.inspection.finger==0 and c.repairs.disc==null)
	assert(not c.inspection.carried_data.dirty and c.inspection.carried_data.uid==uid)
	assert(c.inspection.carried_data.just_repaired)
	await physics_frame
	# Looking at the machine again must not restart a repair: return to the case.
	ui.tap_aim=false
	ui.sync_hands()
	game.aim_hands[0].look_at(c.repairs.station)
	assert(ui.inspection_disc_action().get("target","")!="repair")
	ui.case_action()
	assert(c.inspection.carried==null and item.node.get_meta("disc_uid")==uid)
	assert(not item.node.get_meta("dirty",true) and c.repairs.disc==null)
	print("REPAIR097_OK: actual Android tap retrieves repaired disc despite open empty case; same clean disc reinserts; no accidental repeat repair")
	quit(0)
