extends SceneTree
var failures=0
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _initialize():
	await process_frame
	root.size=Vector2i(1600,1000)
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	var c=g.clerk
	c.max_basket=1
	c.shift.enabled=false
	load("res://clerk_inventory.gd").mix_records(g.dvd_records,0.0)
	check(c!=null,"Clerk module initialized")
	check(c.screen!=null,"Existing checkout CRT found")
	c.customers.set_physics_process(false)
	c.set_physics_process(false)
	c.customers.spawn_customer()
	c.customers.spawn_customer()
	c.customers.spawn_customer()
	check(c.customers.customers.size()==2,"At most two customers")
	var client=c.customers.customers[0]
	check(c.customers.route(client,Vector3(-.5,0,-4)),"Customer path from entrance to counter exists")
	for p in client.path:
		check(not c.customers.grid.is_point_solid(Vector2i(roundi(p.x/.25),roundi(p.y/.25))),"Path avoids shelves")
	for shopper in c.customers.customers:shopper.movie=0
	for tick in range(72*140):c.customers._physics_process(1.0/72)
	for debug_customer in c.customers.customers:print("CUSTOMER_STATE ",debug_customer.state," position=",debug_customer.node.position," cursor=",debug_customer.cursor,"/",debug_customer.path.size())
	check(c.waiting.size()==1 and not c.active.is_empty(),"Both customers browse and reach service queue")
	client=c.active
	c.tender=1000
	c.tender_parts=[1000]
	c.tender_deposited=0
	c.refresh_tender_visual()
	check(c.cases.size()==1,"Customer presents rental case")
	var item=c.cases[0]
	g.held=item.node
	g.held_hand=0
	c.held_service=item
	c.inspection.toggle_case()
	check(not c.inspection.opened,"Antitheft prevents opening")
	c.action("scan",1)
	c.action("unlock",1)
	check(g.held.get_meta("antitheft",false),"Proximity alone does not remove the bar")
	g.held.global_position=Vector3(.72,1.17,-6.18)
	g.hands[1].global_position=g.held.to_global(Vector3(.061,-.09,0))
	check(c.lock_input(1),"Free hand grips bar at the detacher")
	g.hands[1].global_position+=c.lock_axis*.16
	c.tick_lock()
	check(not g.held.get_meta("antitheft",true),"Pulling bar out unlocks case")
	g.hands[1].global_position=c.lock_bin
	c.lock_input(1)
	check(c.lock_hand==-1,"Removed bar stored in bin")
	c.inspection.toggle_case()
	check(c.inspection.opened,"Unlocked case opens")
	c.inspection.close_case()
	g.hands[1].global_position=g.held.to_global(Vector3(.06,0,0))
	check(c.inspection.grab_lid(1),"Free hand grips lid edge")
	var hinge=Vector3(-.0675,0,0)
	c.inspection.update_lid(g.held.to_global(hinge+Vector3(cos(1.2)*.1275,0,sin(1.2)*.1275)))
	check(absf(c.inspection.lid.rotation.y+1.2)<.05,"Lid follows physical hand arc")
	c.inspection.lid_hand=-1
	check(c.inspection.opening_amount>.3,"Lid remains open one-handed")
	g.hands[1].global_position=c.inspection.lid.to_global(Vector3(.125,0,0))
	c.inspection.grab_lid(1)
	c.inspection.update_lid(g.held.to_global(Vector3(.06,0,0)))
	await create_timer(.25).timeout
	check(not c.inspection.opened,"Physical return motion closes lid")
	g.hands[1].global_position=g.held.to_global(Vector3(.06,0,0))
	c.inspection.grab_lid(1)
	c.inspection.update_lid(g.held.to_global(hinge+Vector3(cos(2.76)*.1275,0,sin(2.76)*.1275)))
	await create_timer(.25).timeout
	check(c.inspection.lid_hand==-1 and absf(c.inspection.lid.rotation.y+2.8)<.02,"Full opening requires the complete physical arc")
	c.inspection.close_case()
	c.inspection.toggle_case()
	check(c.inspection.disc.mesh.get_surface_count()==1,"Disc mesh constructed")
	check(g.hand_visuals[1].skeleton.find_bone("index-finger-tip")>=0,"Disc attachment uses actual index fingertip")
	g._update_cover_lod(g.head.global_position,true)
	check(item.record.get("clerk_reserved",false),"Customer holds a real reserved shelf copy")
	c.inspection.close_case()
	g.held.set_meta("inspected",true)
	c.action("scan",1)
	c.action("computer",1)
	check(c.drawer_open,"Checkout opens drawer")
	c.action("handoff",1)
	check(c.rentals==0,"Unpaid rental cannot leave")
	c.action("tender",1)
	g.hands[1].global_position=Vector3(1,1.4,-6.5)
	c.wallet.release_grip(1)
	check(not c.wallet.occupied(1) and c.wallet.loose.size()==1,"Released tender becomes physical cash")
	var loose_note=c.wallet.loose[0]
	g.hands[1].global_position=loose_note.node.global_position
	c.wallet.interact(1,true)
	check(c.wallet.occupied(1) and c.wallet.loose.is_empty(),"Dropped bill can be picked up again")
	g.hands[1].global_position=c.drawer.global_position+Vector3(0,.10,0)
	c.interact(1,false)
	check(c.tender_received and c.till[1000]==11,"Customer cash deposited exactly once")
	c.action("money",1,200)
	check(c.wallet.give_customer(1) and c.change==200,"Incorrect change accepted for end-of-day audit")
	c.paid=false
	c.change=0
	c.till[200]+=1 # restore this isolated payment scenario
	g.hands[1].global_position=c.drawer.global_position+Vector3(0,.10,0)
	c.interact(1,false)
	check(c.wallet.total(1)==0 and c.till[200]==15,"One coin returned without losing stock")
	for denom in [500,100,25]:c.action("money",1,denom)
	check(c.wallet.total(1)==625 and c.wallet.palms[1].size()==3,"Multiple denominations coexist in one palm")
	g.hands[1].global_position=Vector3(c.active.node.position.x,1.2,-6.2)
	c.interact(1,false)
	check(c.paid and c.change==625 and not c.wallet.occupied(1),"Exact change handed directly to customer")
	c.action("handoff",1)
	check(c.rentals==1 and c.active.is_empty(),"Completed checkout releases customer")
	check(c.returns_due.size()==1,"Rental schedules a return")
	check(item.record.clerk_reserved,"Rented copy stays absent until return and restocking")
	var drop=c.new_case(1,Vector3(0,1.4,-6.1),"shelve")
	c.pick_case(drop,0,true)
	g.held.global_position=Vector3(0,1.3,-6.1)
	c.release()
	check(not drop.node.freeze and drop.node.collision_layer==8,"Customer cases reuse manual rigid-body physics")
	for frame in range(90):await physics_frame
	check(drop.node.global_position.y>1.08 and drop.node.global_position.y<1.14,"Released case settles on counter instead of returning home")
	c.elapsed=c.returns_due[0].time+1
	var job=c.take_due_return()
	check(not job.is_empty() and c.returns_due.is_empty(),"Due rental is claimed once by return delivery")
	c.deliver_return(job)
	check(c.cases[-1].record==item.record and c.cases[-1].kind=="return","Chute preserves exact rented copy identity")
	check(not c.phone_enabled,"Phone ringing disabled for testing")
	var returned=c.cases[-1]
	g.held=returned.node
	g.held_hand=0
	c.held_service=returned
	c.action("scan",1)
	check(not returned.scanned,"Uninspected return rejected")
	c.inspection.toggle_case()
	c.inspection.opening_amount=1
	c.inspection.lid.rotation.y=-2.8
	g.hands[1].global_position+=c.inspection.disc.global_position-c.inspection.finger_transform(1).origin
	c.inspection.interact(1)
	check(c.inspection.finger==1,"Free index lifts disc from central hub")
	c.inspection._physics_process(1.0/72)
	g.head.global_position=c.inspection.carried.global_position+c.inspection.carried.global_basis.z*.35
	c.inspection._physics_process(1.0/72)
	check(g.held.get_meta("inspected",false),"Viewing disc near eye records inspection")
	c.action("scan",1)
	check(not returned.scanned,"Open return cannot be scanned")
	c.inspection.carried_data.dirty=true
	c.inspection.carried.global_position=c.repairs.station
	check(c.repairs.insert_disc(c.inspection),"Disc enters resurfacing machine")
	c.repairs.tick(29)
	check(c.repairs.remaining>0 and c.repairs.data.dirty,"Repair requires full thirty seconds")
	c.repairs.tick(1)
	check(c.repairs.remaining==0 and not c.repairs.data.dirty,"Thirty-second repair clears underside damage")
	check(c.repairs.take_disc(c.inspection,1,c.repairs.station),"Repaired disc retrieved on index")
	g.hands[1].global_position+=c.inspection.interior.to_global(Vector3(0,-.012,.004))-c.inspection.finger_transform(1).origin
	c.inspection._physics_process(1.0/72)
	c.inspection.interact(1)
	check(c.inspection.finger==-1,"Disc snaps back into original hub")
	c.inspection.close_case()
	c.action("scan",1)
	check(returned.scanned,"Inspected clean return accepted")
	g.held.global_position=returned.record.world.origin
	c.release()
	check(g.held!=null and returned.record.clerk_reserved,"Return cannot restock before replacing yellow lock")
	g.hands[1].global_position=c.lock_bin
	c.lock_input(1)
	g.hands[1].global_position=g.held.to_global(Vector3(.061,-.09,0))
	c.lock_input(1)
	check(g.held.get_meta("antitheft",false),"Returned copy accepts reusable yellow lock")
	g.held.global_position=returned.record.world.origin
	c.release()
	check(not item.record.clerk_reserved,"Only manual restocking makes rented copy available again")
	check(c.customers.route(client,Vector3(-2.5,0,-4)),"Customer return chute is reachable")

	var sample=[]
	for i in range(100):sample.append({"id":i,"movie":i%10})
	var mixed=load("res://clerk_inventory.gd").mix_records(sample,.10)
	var wrong=0
	var identities={}
	for r in sample:
		if r.movie!=r.disc_movie:wrong+=1
		identities[r.disc_uid]=true
	check(mixed==10 and wrong==10 and identities.size()==100,"Startup mixes exactly 10 percent while conserving every disc")
	c.active={"id":99,"node":client.node,"movie":0,"items":[],"missing":[],"handed":0}
	for id in range(3):c.add_basket_case(c.reserve_stock(id))
	c.price=1125
	c.tender=2000
	c.tender_parts=[2000]
	c.tender_deposited=0
	c.tender_note.visible=true
	c.paid=false
	c.tender_received=false
	c.refresh_terminal()
	c.wallet.take(1,2000,true)
	check(c.wallet.occupied(1),"Customer tender is accessible before unlocking basket")
	c.wallet.remove_one(1,0,false)
	c.tender_parts=[2000]
	c.refresh_tender_visual()
	for entry in c.active.items:
		entry.scanned=true
		entry.node.set_meta("antitheft",false)
	c.refresh_terminal()
	c.wallet.take(1,2000,true)
	g.hands[1].global_position=c.drawer.global_position+Vector3(0,.1,0)
	c.wallet.release_grip(1)
	for value in [500,200,100,25,25,25]:c.wallet.take(1,value)
	check(c.wallet.total(1)==875,"One payment computes change for three films")
	check(c.wallet.give_customer(1),"Exact basket change accepted")
	var pending_returns=c.returns_due.size()
	for entry in c.active.items.duplicate():
		c.held_service=entry
		g.held=entry.node
		g.held_hand=0
		c.action("handoff",0)
	check(c.active.is_empty() and c.returns_due.size()==pending_returns+3,"Three films handed over after one payment")
	# Sampling many generated baskets catches duplicate-title regressions.
	c.max_basket=3
	var distinct=true
	var multi_count=0
	for basket_index in range(100):
		var shopper={"movie":basket_index%24,"node":Node3D.new()}
		c.add_child(shopper.node)
		if c.select_film(shopper):
			var titles={}
			for record in shopper.reservations:
				if titles.has(record.movie):distinct=false
				titles[record.movie]=true
				record.clerk_reserved=false
			if titles.size()>1:multi_count+=1
		shopper.node.queue_free()
	check(distinct and multi_count>0,"Generated multi-title baskets never repeat a title")
	c.active={"id":100,"movie":0,"node":client.node,"items":[],"missing":[],"handed":0}
	c.add_basket_case(c.reserve_stock(0))
	for entry in c.active.items:
		entry.scanned=true
		entry.node.set_meta("antitheft",false)
	c.price=375
	c.tender=400
	c.tender_parts=[200,200]
	c.tender_deposited=0
	c.tender_received=false
	c.paid=false
	c.refresh_tender_visual()
	c.refresh_terminal()
	c.wallet.take(1,400,true)
	c.wallet.remove_one(1,0,true)
	check(not c.tender_received and c.tender_deposited==200,"First coin does not complete mixed tender")
	c.wallet.take(1,400,true)
	c.wallet.remove_one(1,0,true)
	check(c.tender_received and c.tender_deposited==400,"Two separate toonies complete customer tender")
	c.wallet.take(1,25)
	check(c.wallet.give_customer(1),"Mixed tender uses exact 25 cent change")
	g.held_hand=-1
	g.hands[0].global_position=c.drawer.global_position+Vector3(0,.12,0)
	g.hands[1].global_position=g.hands[0].global_position+Vector3(.06,.03,0)
	c.wallet._physics_process(.016)
	var coin_stock=c.till[100]
	c.wallet.take(1,100)
	c.wallet.release_grip(1)
	check(c.wallet.total(0)==100 and c.wallet.total(1)==0 and c.till[100]==coin_stock-1,"Other palm receives coin before drawer underneath")
	c.wallet.take(1,25)
	c.wallet.release_grip(1)
	check(c.wallet.total(0)==125 and c.wallet.totals[0].text=="1.25 $","Sequential transfers accumulate and display exact palm total")
	for tick in range(90):c.wallet._physics_process(1.0/72)
	check(c.wallet.total(0)==125,"Receiving palm retains cash without held grip")
	var quarter=c.wallet.palms[0][1]
	g.hands[1].global_position+=quarter.node.global_position-c.inspection.finger_transform(1).origin
	c.wallet.interact(1,true)
	check(c.wallet.total(1)==25 and c.wallet.total(0)==100,"Index selects one individual coin from receiving palm")
	g.hands[1].global_position=g.hands[0].global_position+Vector3(.06,.03,0)
	c.wallet._physics_process(.016)
	c.wallet.release_grip(1)
	g.hands[1].global_position=g.hands[0].global_position+Vector3(2,0,0)
	c.wallet._physics_process(.016)
	c.wallet.release_grip(0)
	check(c.wallet.total(0)==0 and c.till[100]==coin_stock,"Handful deposited into drawer without loss")
	g.hands[1].global_position=Vector3(3,.3,-3)
	c.wallet.take(1,100)
	c.wallet.drop_all(1)
	var ground_cash=c.wallet.loose[-1]
	ground_cash.body.global_position=Vector3(3,.025,-3)
	g.hands[1].global_position=Vector3(3,.12,-3)
	c.wallet._physics_process(.016)
	c.wallet.interact(1,true)
	check(c.wallet.total(1)==100 and not c.wallet.loose.has(ground_cash),"Ground coin is recoverable within generous hand reach")
	c.wallet.remove_one(1,0,true)
	var old_head=g.head.position
	var old_origin=g.origin.position
	g.head.position.y=1.7
	for tick in range(90):g._update_crouch(Vector2(0,-1),1.0/72)
	check(absf(g.crouch_offset+1.1)<.01,"Right stick down lowers standing view to reachable floor height")
	var crouched=g.crouch_offset
	g.teleportation.relocate(Vector3(-4,0,4))
	check(absf(g.origin.position.y-crouched)<.01,"Teleport preserves crouch offset")
	for tick in range(90):g._update_crouch(Vector2.ZERO,1.0/72)
	check(absf(g.crouch_offset)<.01 and absf(g.origin.position.y)<.01,"Releasing crouch restores standing height without drift")
	g.head.position=old_head
	g.origin.position=old_origin
	g.origin.transform=Transform3D.IDENTITY
	g.head.position=Vector3(1.8,1.8,-6.7)
	g.head.look_at(Vector3(0,1.2,-5.2))
	g.hud.visible=false
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../clerk-counter-preview.png")
	# Close visual inspection of the real ring mesh and hinged cover.
	var open_case=c.new_case(0,Vector3(.02,1.45,-6.65),"return")
	g.held=open_case.node
	g.held_hand=0
	c.held_service=open_case
	open_case.node.rotation=Vector3(0,PI,0)
	c.inspection.toggle_case()
	g.head.position=Vector3(.05,1.48,-6.25)
	g.head.look_at(Vector3(.02,1.45,-6.65))
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../clerk-disc-preview.png")
	print("CLERK_TESTS failures=",failures)
	quit(1 if failures else 0)
