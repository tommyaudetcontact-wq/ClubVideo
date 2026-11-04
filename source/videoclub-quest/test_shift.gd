extends SceneTree
var failures=0
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _initialize():
	await process_frame
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	var c=g.clerk
	c.set_physics_process(false)
	c.customers.set_physics_process(false)
	load("res://clerk_inventory.gd").mix_records(g.dvd_records,0)
	var shift=c.shift
	check(not shift.can_spawn() and shift.duration==300,"First shift waits for player input, lasts five minutes")
	shift.started=true
	shift.spawned()
	check(not shift.can_spawn() and shift.break_left==55,"First day includes a restocking break")
	shift.tick(55)
	check(shift.can_spawn(),"Arrivals resume after break")
	shift.tick(245)
	check(shift.closing and not shift.can_spawn(),"Closing prevents new arrivals")
	shift.revenue=375
	c.till[100]+=4
	check(shift.finish() and shift.report.contains("+0.25"),"Till audit detects excess cash without computing checkout change")
	shift.next_day()
	check(shift.duration==600 and shift.capacity()==3,"Day two lasts ten minutes and allows three customers")
	shift.next_day()
	check(shift.duration==900 and shift.capacity()==4,"Day three lasts fifteen minutes")
	shift.next_day()
	shift.next_day()
	check(shift.duration==900 and shift.capacity()==5,"Difficulty caps at five customers and fifteen minutes")
	shift.enabled=false
	var a=c.new_case(0,Vector3(0,1.2,-6.3),"shelve")
	a.record=c.reserve_stock(0)
	load("res://clerk_inventory.gd").bind(a.node,a.record)
	var b=c.new_case(1,Vector3(.3,1.2,-6.3),"shelve")
	b.record=c.reserve_stock(1)
	load("res://clerk_inventory.gd").bind(b.node,b.record)
	c.pick_case(a,0,true)
	c.pick_case(b,1,true)
	check(c.secondary==a and c.held_service==b and c.secondary_hand==0,"One distinct case occupies each hand")
	c.inspection.toggle_case()
	check(not c.inspection.opened,"Opening requires a free hand")
	a.node.global_position=Vector3(2,1.3,-6.1)
	c.release_secondary(0)
	check(c.secondary.is_empty() and g.held==b.node and g.held_hand==1 and not a.node.freeze,"Dropping secondary preserves the other held case")
	c.repairs.tick(0)
	check(c.repairs.marker.visible and c.repairs.marker.global_position.distance_to(b.record.world.origin)<.001,"Green guide marks exact original shelf slot")
	b.node.global_position=Vector3(2.3,1.3,-6.1)
	c.release()
	# Ordinary shelf cases must convert without creating duplicate inventory.
	var shelf_record={}
	for record in g.dvd_records:
		if record.movie==4 and not record.get("clerk_reserved",false):
			shelf_record=record
			break
	g._take(shelf_record,0,true)
	c.pick_case(b,1,true)
	check(c.secondary.record==shelf_record and shelf_record.clerk_reserved,"Shelf pickup converts to two-hand service case with same identity")
	c.secondary.node.global_position=shelf_record.world.origin
	c.release_secondary(0)
	check(not shelf_record.clerk_reserved and g.held==b.node,"Converted shelf copy restores exactly one original slot")
	b.node.global_position=Vector3(2.3,1.3,-6.1)
	c.release()
	var client_node=load("res://clerk_props.gd").customer(c,90)
	client_node.position=Vector3(-.6,0,-5.05)
	c.active={"id":90,"node":client_node,"movie":0,"items":[],"missing":[],"handed":0,"state":"service","patience":0.0}
	c.price=375
	c.tender=600
	c.tender_parts=[200,200,200]
	c.tender_deposited=0
	c.tender_received=false
	c.paid=false
	c.refresh_tender_visual()
	c.refresh_terminal()
	g.hands[0].global_position=c.tender_note.global_position
	c.wallet.interact(0,true)
	check(c.wallet.total(0)==600 and c.tender_parts.is_empty(),"One grip collects all customer tender")
	while c.wallet.occupied(0):c.wallet.remove_one(0,0,true)
	c.drawer_open=true
	c.wallet.take(0,100)
	check(c.wallet.give_customer(0) and c.change==100,"Wrong change is permitted rather than corrected by the game")
	var all_labels=true
	var authentic=0
	for id in range(g.layout.movies.size()):
		var original=ResourceLoader.exists("res://assets/discs/%02d.png"%id) or ResourceLoader.exists("res://assets/discs/%02d.jpg"%id)
		if original:authentic+=1
		if not original and not ResourceLoader.exists("res://assets/covers/%02d-front.jpg"%id):all_labels=false
	check(all_labels and authentic>0,"Every title has original disc art or an authorized cover fallback")
	print("DISC_LABELS original=",authentic," total=",g.layout.movies.size())
	c.active={}
	var return_case=c.deliver_return({"movie":2,"record":c.reserve_stock(2)})
	return_case.node.set_meta("dirty",true)
	var returning={"id":91,"node":client_node,"movie":2,"is_return":true,"return_item":return_case,"state":"service"}
	c.waiting.append(returning)
	c.start_next()
	check(c.price==200 and c.active.items[0]==return_case,"Damaged return charges a two-dollar fee and retains physical copy")
	return_case.scanned=true
	c.paid=true
	c.refresh_basket()
	var before=shift.revenue
	c.action("computer",0)
	check(c.active.is_empty() and shift.revenue==before+200 and is_instance_valid(return_case.node),"Return checkout completes without deleting the case to repair")
	# Patience runs only at service positions, never during navigation.
	var waiting_node=load("res://clerk_props.gd").customer(c,92)
	var queued={"id":92,"node":waiting_node,"movie":3,"state":"service","patience":0.0,"reservations":[]}
	var serving={"id":91,"node":client_node,"movie":2,"state":"service","patience":0.0,"items":[],"reservations":[]}
	c.customers.customers=[serving,queued]
	c.active=serving
	c.waiting=[queued]
	c.paid=false
	shift.enabled=true
	shift.summary=false
	shift.time_left=600
	shift.tick(119)
	check(not c.active.is_empty() and queued.patience==119,"Counter customer has a full two-minute allowance")
	shift.tick(1)
	check(c.active.is_empty() and not c.waiting.has(queued),"Both waiting and serving customers receive two minutes")
	g.origin.transform=Transform3D.IDENTITY
	g.head.position=Vector3(1.8,1.65,-7.2)
	g.head.look_at(Vector3(-.6,1.1,-8.8))
	g.hud.visible=false
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../repairs-057-preview.png")
	print("SHIFT_TESTS failures=",failures)
	quit(1 if failures else 0)
