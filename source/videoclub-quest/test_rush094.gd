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
	var shift=clerk.shift
	shift.started=true
	shift.tick(180)
	assert(shift.wave==1 and shift.break_left==60 and not shift.can_spawn())
	shift.tick(60)
	assert(shift.wave==2 and shift.time_left==210 and shift.can_spawn())
	shift.tick(280)
	assert(shift.wave==3 and shift.time_left==240 and shift.break_left==0)
	shift.tick(17)
	var saved:Dictionary=game.session.snapshot()
	assert(saved.shift.wave==3 and saved.shift.time_left==223)
	var record:Dictionary=game.dvd_records[0]
	var account:int=clerk.accounts.create_account()
	var cycle:int=clerk.accounts.rental(account,record.movie,record.id)
	var job={"movie":record.movie,"record":record,"account_id":account,"rental_id":cycle,"refund":0}
	var returned:Dictionary=clerk.deliver_return(job)
	assert(clerk.accounts.ensure(account).balance==0 and clerk.accounts.ensure(account).rentals[cycle].returned)
	assert(returned.scanned and returned.node.get_meta("return_checked"))
	assert(returned.node.global_position.distance_to(clerk.return_bin+Vector3(0,.15,0))<.01)
	assert(shift.refunds==0)
	returned.node.freeze=true
	returned.node.set_meta("dirty",true)
	clerk.pick_case(returned,game.touch_controls.CASE_HAND,false)
	game.touch_controls.toggle_case()
	await create_timer(.2).timeout
	var inspection=clerk.inspection
	var expected_disc:int=returned.node.get_meta("disc_movie")
	var aim:Node3D=game.aim_hands[0]
	var lid_center:Vector3=inspection.lid.to_global(Vector3(.0675,0,.003))
	aim.global_position=inspection.lid.to_global(Vector3(.0675,0,.4))
	aim.look_at(lid_center)
	game.touch_controls.tap_aim=true
	assert(game.touch_controls.tapped_empty_lid())
	game.touch_controls.tap_aim=false
	inspection.take_open_disc(0)
	assert(is_instance_valid(inspection.carried) and inspection.carried_data.dirty)
	# Closing the empty lid must not delete the disc carried in the other hand.
	game.touch_controls.toggle_case()
	assert(not inspection.opened and is_instance_valid(inspection.carried))
	inspection.carried.global_position=clerk.repairs.station
	assert(clerk.repairs.insert_disc(inspection))
	clerk.repairs.remaining=.05
	await create_timer(.2).timeout
	assert(clerk.repairs.remaining==0 and not clerk.repairs.data.dirty)
	assert(clerk.repairs.take_disc(inspection,0,clerk.repairs.station))
	inspection.open_case(returned.node)
	inspection.finish_lid(true)
	assert(inspection.put_carried_in_case())
	assert(not returned.node.get_meta("dirty",true) and returned.node.get_meta("disc_movie")==expected_disc)
	inspection.close_case()
	clerk.clear_hand()
	var host_basket=clerk.basket
	var guest_basket=clerk.lan.personal_basket()
	returned.node.global_position=guest_basket.body.to_global(Vector3(0,.16,0))
	assert(guest_basket.store(returned))
	assert(returned in guest_basket.items and returned not in host_basket.items)
	assert(returned.node.get_meta("basket_owner")=="guest")
	var packed:Dictionary=game.session.snapshot()
	assert(packed.cases[0].meta.basket_owner=="guest")
	# Complaint customers return through the chute, then get cash from either player.
	clerk.customers.spawn_customer()
	var customer:Dictionary=clerk.customers.customers[0]
	customer.is_refund=true
	customer.refund_due=500
	customer.return_and_rent=false
	customer.visit_mask=5
	clerk.customer_ready(customer)
	assert(clerk.tender_received and clerk.tender_parts.is_empty() and clerk.price==0)
	clerk.wallet.record_change(500)
	assert(clerk.active.is_empty() and shift.refunds==500 and customer.state=="exit")
	print("RUSH094_OK: progressive rushes, free automatic returns, host disc repair, close with disc in hand, personal baskets, cash refund")
	quit(0)
