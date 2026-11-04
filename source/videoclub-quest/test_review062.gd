extends SceneTree
const Pricing=preload("res://rental_pricing.gd")
var failures=0
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func fresh():
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.clerk.set_physics_process(false)
	g.clerk.customers.set_physics_process(false)
	g.clerk.shift.enabled=false
	return g
func pull_lock(g):
	var c=g.clerk
	g.held.global_position=Vector3(.72,1.17,-6.18)
	g.hands[1].global_position=g.held.to_global(Vector3(.061,-.09,0))
	c.lock_input(1)
	g.hands[1].global_position+=c.lock_axis*.16
	c.tick_lock()
func place_bar(g,transform:Transform3D):
	var offset=Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3(.025,-.015,-.10))
	g.hands[1].global_transform=transform*offset.affine_inverse()
	g.clerk.tick_lock()
func _initialize():
	await process_frame
	root.size=Vector2i(1600,1000)
	var g=fresh()
	var c=g.clerk
	load("res://clerk_inventory.gd").mix_records(g.dvd_records,0)
	check(c.locks.shelves.size()==2 and c.locks.shelves[0].multimesh.instance_count>=g.dvd_records.size(),"All shelf bars use only two instanced render batches")
	check(c.locks.bars.all(func(body):return body.freeze and body.collision_layer==0),"All spare bars have simulation and collision disabled in bin")
	var count=0
	for record in g.dvd_records:
		if record.get("locked",false):count+=1
	check(count==g.dvd_records.size(),"Every shelf film and game starts with a real lock state")
	c.max_basket=1
	c.customers.spawn_customer()
	var client=c.customers.customers[0]
	client.movie=0
	c.select_film(client)
	client.state="service"
	client.node.position=Vector3(-.6,0,-5.05)
	c.customer_ready(client)
	var account=client.account_id
	var item=client.items[0]
	c.pick_case(item,0,true)
	check(c.price==0 and c.tender_parts.is_empty(),"Rental total is empty until an inspected film is scanned")
	check(not c.scan_held() and not item.scanned and c.price==0,"Scanner refuses an uninspected disc without adding it to invoice")
	pull_lock(g)
	check(not g.held.get_meta("antitheft",true) and not item.record.locked and c.loose_lock is RigidBody3D,"Detacher pull releases the actual lock as a reusable object")
	var bar=c.loose_lock
	check(bar.global_position.distance_to(g.hands[1].global_position)>.09 and bar.freeze,"Held bar extends in front of palm with simulation disabled")
	g.hands[1].global_position=Vector3(-1,1.4,-7)
	c.tick_lock()
	c.locks.release(1)
	check(not bar.freeze and bar.collision_layer==8,"Only releasing a bar activates its physical fall")
	bar.sleeping=true
	c.tick_lock()
	check(bar.freeze and bar.collision_layer==0,"Settled bar disables simulation and collision again")
	g.hands[1].global_position=bar.global_position
	check(c.lock_input(1) and c.loose_lock==bar,"A dropped bar can be picked back up")
	g.held.global_transform=Transform3D(Basis.IDENTITY,Vector3(1,1.4,-7.2))
	var slot=g.held.to_global(Vector3(.061,-.09,0))
	place_bar(g,Transform3D(Basis(Vector3.RIGHT,PI/2),slot))
	check(not g.held.get_meta("antitheft",false),"Wrong bar orientation does not magically lock a case")
	place_bar(g,Transform3D(Basis.IDENTITY,slot-Vector3.UP*.085))
	check(not g.held.get_meta("antitheft",false),"Aligning bar with slot starts insertion but does not skip the push")
	place_bar(g,Transform3D(Basis.IDENTITY,slot+Vector3.UP*.065))
	check(g.held.get_meta("antitheft",false) and item.record.locked and c.lock_hand==-1,"Pushing bar into slot locks the case away from detacher")
	pull_lock(g)
	g.hands[1].global_position=c.lock_bin
	c.tick_lock()
	c.locks.release(1)
	g.held.set_meta("inspected",true)
	c.inspection.close_case()
	check(c.price==0 and not item.scanned,"Closing inspected case is not mistaken for a scanner pass")
	check(c.scan_held(),"Inspected matching disc is accepted by scanner")
	check(c.price==431 and item.scanned and c.tender>=431,"Scan adds correct rental subtotal plus period GST and QST")
	var total=c.price
	c.scan_held()
	check(c.price==total and client.items.size()==1,"Repeated scan does not duplicate invoice item")
	# Complete one real rental; return tracks account identity rather than NPC visit ID.
	c.tender=500
	c.tender_parts=[500]
	c.tender_deposited=0
	c.refresh_tender_visual()
	c.action("computer",1)
	c.wallet.take(1,500,true)
	c.wallet.remove_one(1,0,true)
	for coin in [25,25,10,5,1,1,1,1]:c.wallet.take(1,coin)
	c.wallet.give_customer(1)
	c.action("handoff",0)
	check(c.returns_due.size()==1 and c.returns_due[0].account_id==account,"Rental return record retains original customer account")
	var job=c.returns_due.pop_back()
	var returned=c.deliver_return(job)
	returned.node.set_meta("dirty",true)
	returned.node.set_meta("returned_damage",true)
	returned.node.set_meta("inspected",true)
	c.pick_case(returned,0,true)
	c.scan_held()
	check(c.accounts.ensure(account).balance==200 and returned.node.get_meta("return_checked",false),"Damaged chute return records fee on the original customer's account")
	c.scan_held()
	check(c.accounts.ensure(account).balance==200,"Repeated return scan never duplicates damage fee")
	returned.node.global_position=c.repairs.case_slots[0]
	c.release()
	# A different visitor never inherits that balance.
	var other=c.accounts.create_account()
	check(c.accounts.ensure(other).balance==0,"Another customer's balance is untouched")
	c.customer_delay=0
	c.active={}
	c.waiting.clear()
	var revisit={"id":101,"account_id":account,"visit_balance":200,"node":client.node,"movie":1,"state":"service"}
	c.select_film(revisit)
	c.customer_ready(revisit)
	var rental=revisit.items[0]
	c.pick_case(rental,0,true)
	c.locks.set_locked(rental.node,false)
	rental.node.set_meta("inspected",true)
	c.scan_held()
	check(c.price==Pricing.quote(g.layout.movies,[1]).total+200 and revisit.account_due==200,"Next visit includes outstanding fee with newly scanned rentals")
	# Settlement removes only the debt invoiced at arrival, preserving later charges.
	c.accounts.ensure(account).balance+=200
	c.accounts.settle(account,revisit.account_due)
	check(c.accounts.ensure(account).balance==200,"New damage charges from same visit remain deferred after old balance settlement")
	var offers={}
	for i in range(120):
		var payment=Pricing.payment(275)
		if payment.size()==1:offers[payment[0]]=true
	check(offers.has(500) and offers.has(1000),"Small purchases can be paid with either five- or ten-dollar notes")
	var state=g.session.snapshot()
	var account_state=c.accounts.snapshot()
	check(state.has("accounts") and state.has("loose_locks") and state.records.all(func(r):return r.has("locked")),"Save includes accounts, loose bars and exact lock states")
	# Drop this synthetic visit from saved NPC indices to isolate inventory/account restoration.
	state.active=-1
	state.waiting=[]
	var loaded=fresh()
	check(loaded.session.restore(state),"Extended save restores into a fresh scene")
	check(loaded.clerk.accounts.snapshot()==account_state and loaded.clerk.locks.bars.size()==state.loose_locks.size(),"Client charges and reusable bar count survive restart")
	check(loaded.clerk.locks.bars.all(func(body):return body.freeze),"Stored bars resume without unnecessary physics")
	g.hud.visible=false
	g.origin.transform=Transform3D.IDENTITY
	g.head.position=Vector3(.4,1.8,-7.15)
	g.head.look_at(Vector3(.3,1.2,-6.2))
	c.locks.update_bar_instances()
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../checkout-062-preview.png")
	print("REVIEW062_TESTS failures=",failures)
	quit(1 if failures else 0)
