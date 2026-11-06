extends SceneTree
var failures=0
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func fresh():
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.clerk.set_physics_process(false)
	g.clerk.customers.set_physics_process(false)
	g.session.tools_run=true
	g.session.save_path="user://test-club-save.dat"
	return g
func _initialize():
	await process_frame
	var g=fresh()
	var c=g.clerk
	load("res://clerk_inventory.gd").mix_records(g.dvd_records,0)
	# A correctly sorted disc lies separately on the workbench; its case is empty.
	var r=c.reserve_stock(0)
	var item=c.new_case(0,Vector3(.5,1,-8.7),"shelve")
	item.record=r
	load("res://clerk_inventory.gd").bind(item.node,r)
	var disc=c.inspection.create_disc(0,false)
	c.inspection.add_child(disc)
	disc.position=Vector3(.6,.916,-8.7)
	c.inspection.loose_discs.append({"node":disc,"data":{"movie":0,"uid":r.id,"dirty":false,"inspected":true}})
	load("res://clerk_inventory.gd").put(item.node,-1,-1)
	# A second disc is halfway through resurfacing.
	var repair_record=c.reserve_stock(1)
	var repair_case=c.new_case(1,Vector3(-1.7,1.1,-8.85),"return")
	repair_case.record=repair_record
	load("res://clerk_inventory.gd").bind(repair_case.node,repair_record)
	load("res://clerk_inventory.gd").put(repair_case.node,-1,-1)
	c.repairs.disc=c.inspection.create_disc(1,true)
	c.repairs.add_child(c.repairs.disc)
	c.repairs.disc.position=c.repairs.station
	c.repairs.data={"movie":1,"uid":repair_record.id,"dirty":true,"inspected":true}
	c.repairs.source=repair_case.node
	c.repairs.remaining=17.5
	c.tasks.append("Disques à ranger")
	c.customers.spawn_customer()
	var customer=c.customers.customers[0]
	c.select_film(customer)
	customer.node.position=Vector3(-.6,0,-5.05)
	customer.state="service"
	customer.path=PackedVector2Array()
	customer.cursor=0
	c.customer_ready(customer)
	customer.patience=31.0
	c.wallet.take(1,c.tender,true)
	var cash_held=c.wallet.total(1)
	var rented=c.reserve_stock(7)
	c.returns_due.append({"movie":7,"record":rented,"time":580.0})
	c.shift.day=2
	c.shift.wave=3
	c.shift.target_customers=7
	c.shift.arrived_customers=3
	c.shift.week_losses=123
	c.shift.week_abandoned=1
	c.shift.duration=360.0
	c.shift.time_left=112.0
	c.shift.started=true
	c.till[100]-=3
	check(g.session.save_game(false),"Save writes a complete session atomically")
	var state=g.session.read_state()
	check(not state.is_empty() and state.loose_discs.size()==1,"Save file contains separately sorted disc")
	check(g.session.save_game(false),"Repeated save replaces previous slot and retains recovery copy")
	g.session.start_autosave()
	g.session.flush_worker()
	check(not g.session.read_state().is_empty(),"Background autosave completes without losing session")
	var damaged_file=FileAccess.open(g.session.save_path,FileAccess.WRITE)
	damaged_file.store_var({"version":-1})
	damaged_file.close()
	check(not g.session.read_state().is_empty(),"Invalid primary save falls back to previous valid copy")
	check(g.session.save_game(false),"Valid session can replace damaged primary save")
	var ids=[]
	for record in state.records:ids.append(record.disc_uid)
	root.remove_child(g)
	g.free()
	g=fresh()
	c=g.clerk
	check(g.session.restore_file(),"Fresh scene loads saved game")
	var loaded=g.session.snapshot()
	var same=true
	for i in range(ids.size()):
		if loaded.records[i].disc_uid!=ids[i]:same=false
	check(same,"Reload preserves every disc identity without a new random shuffle")
	var unique={}
	var count=0
	for record in loaded.records:
		if record.disc_uid>=0:
			unique[record.disc_uid]=true
			count+=1
	for loose in loaded.loose_discs:
		unique[loose.data.uid]=true
		count+=1
	unique[loaded.repair.data.uid]=true
	count+=1
	check(count==g.dvd_records.size() and unique.size()==count,"Inventory plus loose and repairing discs conserves every unique disc")
	check(c.inspection.loose_discs.size()==1 and c.inspection.loose_discs[0].data.uid==state.loose_discs[0].data.uid,"Sorted loose disc remains on table with original identity")
	check(c.repairs.remaining==17.5 and c.repairs.data.uid==state.repair.data.uid,"Repair resumes with exact remaining time and disc")
	check(c.shift.week_losses==123 and c.shift.week_abandoned==1,"Weekly counters survive save and restore")
	check(c.shift.day==2 and c.shift.target_customers==7 and c.shift.arrived_customers==3,"Save preserves the finite daily client quota and progression")
	check(c.active.id==customer.get("id",0) and c.active.patience==31,"Active customer, basket and patience persist")
	check(c.returns_due.size()==1 and c.returns_due[0].record.id==state.returns[0].record,"Outstanding rental returns preserve their actual copy")
	var cash_loaded=0
	for money in c.wallet.loose:cash_loaded+=money.value
	check(cash_loaded==cash_held and c.till==state.till,"Held money returns to counter without being duplicated into till")
	check(c.tasks.has("Disques à ranger"),"Outstanding chores persist")
	check(not g.session.restore_file(),"Repeated loading cannot append duplicate cases into live game")
	check(g.session.archive_previous(),"New game archives previous run separately")
	check(g.session.read_state().is_empty(),"New game cannot accidentally reload previous run")
	root.remove_child(g)
	g.free()
	g=fresh()
	var wrong=0
	for record in g.dvd_records:
		if record.disc_movie!=record.movie:wrong+=1
	check(wrong==int(g.dvd_records.size()*.1)/2*2,"New game restores fresh ten-percent disc mix")
	# Reproduce head leaning into furniture: outward motion works, inward is blocked.
	g.layout.colliders=[{"min":[0,0,0],"max":[2,2,2]}]
	g.origin.transform=Transform3D.IDENTITY
	g.head.position=Vector3(-.1,1.65,1)
	var start=g.head.global_position.x
	g._move_player(Vector3(.03,0,0))
	check(is_equal_approx(g.head.global_position.x,start),"Movement farther into a collider stays blocked")
	g._move_player(Vector3(-.05,0,0))
	g._move_player(Vector3(-.05,0,0))
	check(g.head.global_position.x<-.18,"Outward movement escapes an already overlapping shelf")
	g._move_player(Vector3(0,0,.1))
	check(g.head.global_position.z>1,"Movement slides normally along shelf after escaping")
	print("SAVE_TESTS failures=",failures)
	quit(1 if failures else 0)
