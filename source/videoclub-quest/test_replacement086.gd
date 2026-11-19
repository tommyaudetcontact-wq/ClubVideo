extends SceneTree

func _initialize():
	await process_frame
	for mobile in [false,true]:
		var game=load("res://main.tscn").instantiate()
		game.touch_profile=mobile
		root.add_child(game)
		game.set_physics_process(false)
		var clerk=game.clerk
		clerk.set_physics_process(false)
		clerk.customers.set_physics_process(false)
		load("res://clerk_inventory.gd").mix_records(game.dvd_records,0)
		var original=clerk.new_case(0,Vector3.ZERO,"rental")
		original.record=clerk.reserve_stock(0)
		load("res://clerk_inventory.gd").bind(original.node,original.record)
		load("res://clerk_inventory.gd").put(original.node,1,9001)
		original.node.set_meta("antitheft",false)
		clerk.active={"id":1,"items":[original],"missing":[],"is_return":false}
		clerk.pick_case(original,0,true)
		var inspection=clerk.inspection
		inspection.toggle_case()
		inspection.finish_lid(true)
		assert(clerk.active.missing.is_empty())
		if not mobile:
			inspection.lid_hand=1
			game.hands[1].global_position+=inspection.disc.global_position-inspection.finger_transform(1).origin
			assert(clerk.interact(1,false) and inspection.finger==1 and inspection.lid_hand==-1)
			assert(clerk.repairs.place_disc(inspection,Vector3(1.5,1.1,-8.7)))
		original.node.global_position=Vector3(1.75,1.19,-5.92)
		assert(clerk.release())
		assert(original.kind=="sorting" and original.node.get_meta("in_sort_tray"))
		assert(clerk.active.missing==[0] and clerk.active.items.is_empty())
		var spare:Dictionary={}
		for record in game.dvd_records:
			if record.movie==0 and not record.get("clerk_reserved",false):
				spare=record
				break
		game._take(spare,0,true)
		assert(clerk.active.missing==[0] and clerk.scan_held())
		assert(clerk.active.missing.is_empty() and clerk.active.items.size()==1)
		assert(clerk.active.items[0].record==spare and clerk.active.items[0].scanned)
		assert(original.node.get_meta("in_sort_tray") and original.record.clerk_reserved)
		game.free()
	print("REPLACEMENT086_OK")
	quit()

