extends SceneTree
var failures=0
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func shelf_copy(g,title:int)->Dictionary:
	for r in g.dvd_records:
		if r.movie==title and not r.get("clerk_reserved",false):return r
	return {}
func swap_disc(a:Dictionary,b:Dictionary):
	var movie=a.disc_movie
	var uid=a.disc_uid
	a.disc_movie=b.disc_movie
	a.disc_uid=b.disc_uid
	b.disc_movie=movie
	b.disc_uid=uid
func _initialize():
	await process_frame
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	var c=g.clerk
	c.set_physics_process(false)
	c.customers.set_physics_process(false)
	c.shift.enabled=false
	c.max_basket=1
	load("res://clerk_inventory.gd").mix_records(g.dvd_records,0)
	c.customers.spawn_customer()
	var client=c.customers.customers[0]
	client.movie=0
	c.select_film(client)
	swap_disc(client.record,shelf_copy(g,1))
	client.node.position=Vector3(-.6,0,-5.05)
	client.state="service"
	c.customer_ready(client)
	var wrong=c.active.items[0]
	c.pick_case(wrong,0,true)
	wrong.node.set_meta("antitheft",false)
	wrong.node.get_node("Antitheft").queue_free()
	wrong.node.set_meta("inspected",true)
	c.action("scan",0)
	check(c.active.missing==[0] and c.active.items.is_empty(),"Wrong original disc creates one replacement request")
	wrong.node.global_position=c.repairs.case_slots[0]
	c.release()
	check(wrong.node.get_meta("sort_slot",-1)==0 and wrong.node.freeze,"Wrong case snaps to a stable sorting-table slot")
	var second=shelf_copy(g,0)
	swap_disc(second,shelf_copy(g,2))
	g._take(second,0,true)
	g.held.set_meta("inspected",true)
	c.action("scan",0)
	check(c.active.missing==[0] and c.active.items.is_empty() and c.held_service.kind=="sorting","Second wrong copy remains sortable without losing original request")
	c.held_service.node.global_position=c.repairs.case_slots[1]
	c.release()
	var good=shelf_copy(g,0)
	g._take(good,0,true)
	g.held.set_meta("inspected",true)
	c.inspection.toggle_case()
	c.inspection.close_case()
	check(c.active.missing.is_empty() and c.active.items.size()==1 and c.held_service.record==good,"Closing inspected good replacement adds exact copy to customer basket")
	c.action("scan",0)
	check(c.held_service.scanned and g.held.get_meta("inspected",false) and g.held.get_meta("antitheft",false),"Inspection is retained while replacement receives yellow lock")
	check(c.price==375 and wrong.node.get_meta("disc_movie")==1 and second.disc_movie==2,"Replacement never alters price or magically fixes wrong discs")
	g.held.global_position=Vector3(.72,1.17,-6.18)
	g.hands[1].global_position=g.held.to_global(Vector3(.061,-.09,0))
	c.lock_input(1)
	g.hands[1].global_position+=c.lock_axis*.16
	c.tick_lock()
	g.hands[1].global_position=c.lock_bin
	c.lock_input(1)
	check(c.unlocked,"Replacement uses working physical lock-removal sequence")
	c.tender=500
	c.tender_parts=[500]
	c.tender_deposited=0
	c.refresh_tender_visual()
	c.action("computer",1)
	c.wallet.take(1,500,true)
	c.wallet.remove_one(1,0,true)
	c.wallet.take(1,100)
	c.wallet.take(1,25)
	c.wallet.give_customer(1)
	c.active.missing.append(3)
	c.action("handoff",0)
	check(c.rentals==0 and g.held!=null,"An incomplete basket cannot dismiss a paid customer before replacements arrive")
	c.active.missing.erase(3)
	c.action("handoff",0)
	check(c.rentals==1 and c.active.is_empty() and c.returns_due[0].record==good,"Replacement completes normal cash checkout and actual-copy return scheduling")
	check(c.cases.size()==2 and wrong.record.clerk_reserved and second.clerk_reserved,"Both unresolved wrong cases remain available for later sorting")
	check(c.tender_note.position.distance_to(Vector3(-.83,1.14,-5.85))>.5,"Customer cash and case staging areas are separated")
	# A disc stack is picked from the top while preserving each disc identity.
	for uid in [9001,9002]:
		var disc=c.inspection.create_disc(0,false)
		c.inspection.add_child(disc)
		c.inspection.carried=disc
		c.inspection.carried_data={"movie":0,"uid":uid,"dirty":false,"inspected":true}
		c.inspection.finger=1
		c.repairs.place_disc(c.inspection,Vector3(1.5,1.1,-8.7))
	var top=c.inspection.loose_discs[-1]
	check(top.node.position.y>c.inspection.loose_discs[0].node.position.y,"Loose discs stack in the separate disc zone")
	g.hands[1].global_position+=top.node.global_position-c.inspection.finger_transform(1).origin
	c.inspection.interact(1,false)
	check(c.inspection.carried_data.uid==9002,"Top disc is retrieved individually without taking the bottom disc")
	var previous=g.session.snapshot()
	previous.version=1
	previous.clients=[]
	previous.active=-1
	previous.waiting=[]
	previous.cases[0].transform.origin=Vector3(0,1.2,-5.6)
	var migrated=g.session.migrate_state(previous)
	check(is_equal_approx(migrated.cases[0].transform.origin.z,-6.4) and migrated.records==previous.records,"Previous saves move counter objects while preserving sorted inventory")
	print("REPLACEMENT_TESTS failures=",failures)
	quit(1 if failures else 0)
