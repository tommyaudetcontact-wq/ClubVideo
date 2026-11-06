extends SceneTree
const Inventory=preload("res://clerk_inventory.gd")
var game
var clerk
func customer()->Dictionary:
	clerk.customer_delay=0
	clerk.customers.spawn_customer()
	var result:Dictionary=clerk.customers.customers.back()
	result.movie=0
	clerk.max_basket=1
	assert(clerk.select_film(result))
	result.node.position=Vector3(-.6,0,-5.05)
	clerk.customer_ready(result)
	return result
func remove_customer(entry:Dictionary):
	clerk.customers.customers.erase(entry)
	entry.node.queue_free()
func settle():
	clerk.tender=clerk.price
	clerk.tender_parts=[]
	clerk.tender_deposited=clerk.price
	clerk.tender_received=true
	clerk.paid=true
func _initialize():
	await process_frame
	for mode in ["vr","android","guest"]:
		game=load("res://main.tscn").instantiate()
		game.touch_profile=mode=="android"
		root.add_child(game)
		game.set_physics_process(false)
		clerk=game.clerk
		clerk.set_physics_process(false)
		clerk.customers.set_physics_process(false)
		Inventory.mix_records(game.dvd_records,0)
		if mode=="guest":
			clerk.lan.remote_avatar=load("res://club_peer_pose.gd").new()
			game.add_child(clerk.lan.remote_avatar)
			clerk.lan.remote_avatar.valid_pose=true
			clerk.lan.ensure_guest_inspection()
		for destination in ["arbitrary","counter","front_counter","table","tray","basket"]:
			var client:Dictionary=customer()
			var wrong:Dictionary=client.items[0]
			var uid:int=700000+int(client.id)
			Inventory.put(wrong.node,1,uid)
			wrong.node.set_meta("disc_mismatch_seen",true)
			Inventory.bind(wrong.node,wrong.record)
			clerk.locks.set_locked(wrong.node,false)
			assert(client.missing.is_empty() and not wrong.node.get_meta("inspected",false) and not clerk.has_identified_mismatch(wrong.node,0))
			var point:=Vector3(3.2,1.3,-5.8)
			if destination=="counter":point=Vector3(.15,1.18,-6.3)
			if destination=="front_counter":point=Vector3(-.6,1.18,-5.7)
			if destination=="table":point=Vector3(1.5,1.1,-8.7)
			if destination=="tray":point=Vector3(1.75,1.19,-5.92)
			if destination=="basket":point=clerk.basket.body.to_global(Vector3(0,.16,0))
			if mode=="guest":
				clerk.lan.guest_case=wrong
				wrong.node.set_meta("guest_held",true)
				clerk.lan.guest_inspection.open_case(wrong.node)
				clerk.lan.guest_inspection.finish_lid(true)
				if destination=="basket":clerk.lan.guest_inspection.opening_amount=.35
				if destination=="basket":
					point=clerk.lan.personal_basket().body.global_position+Vector3(0,.3,0)
					clerk.lan.remote_avatar.targets[0]=Transform3D(Basis.IDENTITY,point)
					assert(clerk.lan.store_guest_case().begins_with("Boîtier"))
				else:
					clerk.lan.remote_avatar.targets[0]=Transform3D(Basis.IDENTITY,point+Vector3(0,.5,.4))
					assert(clerk.lan.drop_guest_on_surface({"target":JSON.stringify([point.x,point.y,point.z])}).begins_with("Objet"))
			else:
				clerk.pick_case(wrong,1,false)
				clerk.inspection.open_case(wrong.node)
				clerk.inspection.finish_lid(true)
				if destination=="front_counter":clerk.inspection.opening_amount=.35
				game.head.global_position=point+Vector3(0,.5,.4)
				if mode=="android":
					if destination=="basket":
						game.touch_controls.open_basket()
						game.touch_controls.put_in_basket()
					else:game.touch_controls.place_held_case(point)
				else:
					wrong.node.global_position=point
					assert(clerk.release())
			assert(wrong.kind=="sorting" and client.missing==[0] and client.items.is_empty())
			assert(wrong.node.get_meta("disc_movie")==1 and wrong.node.get_meta("disc_uid")==uid and wrong.record.disc_uid==uid)
			assert(not is_instance_valid(clerk.inspection.carried))
			if mode=="vr" and destination=="arbitrary":
				# Old saves may still link a known wrong case already lying aside.
				wrong.kind="rental"
				client.items=[wrong]
				client.missing=[]
				client.state="replacement_browse"
				client.replace_title=0
				client.replacement_movie=3
			var spare:Dictionary=game.dvd_records.filter(func(r):return r.movie==0 and not r.get("clerk_reserved",false))[0]
			var replacement:Dictionary
			if mode=="guest":
				clerk.lan.remote_avatar.targets[0]=Transform3D(Basis.IDENTITY,spare.world.origin+Vector3.UP*.3)
				assert(clerk.lan.pick_guest_case("stock_pick",load("res://club_world_sync.gd").shelf_key(game,spare))=="")
				replacement=clerk.lan.guest_case
				clerk.locks.set_locked(replacement.node,false)
				clerk.lan.guest_inspection.open_case(replacement.node)
				clerk.lan.guest_inspection.finish_lid(true)
				clerk.lan.guest_inspection.close_case()
				clerk.lan.remote_avatar.targets[0]=Transform3D(Basis.IDENTITY,clerk.scanner.global_position+Vector3.UP*.3)
				assert(clerk.lan.guest_action("case_scan",{}).begins_with("Boîtier"))
			else:
				game._take(spare,1,true)
				clerk.locks.set_locked(game.held,false)
				clerk.inspection.open_case(game.held)
				clerk.inspection.finish_lid(true)
				clerk.inspection.close_case()
				assert(clerk.scan_held())
				replacement=clerk.held_service
			assert(client.missing.is_empty() and client.items.size()==1 and client.items[0]==replacement and replacement.record==spare and replacement.scanned)
			assert(wrong not in client.items and wrong.record.clerk_reserved and spare.clerk_reserved)
			if mode=="vr" and destination=="arbitrary":assert(client.state=="approach_counter" and not client.has("replacement_movie"))
			settle()
			assert(clerk.handoff_item(replacement) and clerk.active.is_empty())
			if mode=="guest":clerk.lan.guest_case={}
			assert(clerk.returns_due.back().record==spare and not clerk.returns_due.back().complaint)
			remove_customer(client)
		print("REPLACEMENT0101_MODE_OK ",mode)
		game.free()
	# Uninspected wrong disc: scanning/handoff remain free; only that title is refunded.
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	clerk=game.clerk
	clerk.set_physics_process(false)
	clerk.customers.set_physics_process(false)
	Inventory.mix_records(game.dvd_records,0)
	var client:Dictionary=customer()
	var second_record:Dictionary=clerk.reserve_stock(2)
	clerk.add_basket_case(second_record)
	client.price_titles.append(2)
	client.rental_count=2
	client.rental_remaining=2
	var wrong:Dictionary=client.items[0]
	Inventory.put(wrong.node,1,800001)
	for item in client.items:
		clerk.locks.set_locked(item.node,false)
		assert(not item.node.get_meta("inspected",false) and clerk.scan_item(item))
	var invoice:int=clerk.price
	settle()
	for item in client.items.duplicate():assert(clerk.handoff_item(item))
	assert(clerk.active.is_empty() and clerk.returns_due.size()==2)
	var bad_job:Dictionary=clerk.returns_due.filter(func(job):return job.movie==0)[0]
	var good_job:Dictionary=clerk.returns_due.filter(func(job):return job.movie==2)[0]
	assert(bad_job.refund==bad_job.charge and bad_job.refund>0 and good_job.refund==0 and bad_job.charge+good_job.charge==invoice)
	var restored:Dictionary=game.session.unpack_job(game.session.pack_job(bad_job))
	assert(restored.billed and restored.refund==bad_job.refund)
	remove_customer(client)
	clerk.elapsed=maxf(bad_job.time,good_job.time)+1
	clerk.customers.spawn_customer(true)
	var returning:Dictionary=clerk.customers.customers[0]
	returning.node.position=Vector3(-2.5,0,-4.8)
	returning.state="return_drop"
	returning.path=PackedVector2Array()
	returning.cursor=0
	returning.nav_goal=returning.node.position
	clerk.customers._physics_process(.01)
	assert(returning.is_refund and returning.refund_due==bad_job.refund and clerk.shift.returned==2)
	clerk.customer_delay=0
	clerk.customer_ready(returning)
	clerk.complete_refund(int(returning.refund_due))
	assert(clerk.shift.refunds==bad_job.refund and clerk.shift.loss_total()==bad_job.refund)
	print("REPLACEMENT0101_OK: open wrong case deposited anywhere with disc inside; same-title copy replaces original on scan in VR, Android and guest; no mandatory inspection; per-title refund includes billed tax and loss ledger")
	quit()
