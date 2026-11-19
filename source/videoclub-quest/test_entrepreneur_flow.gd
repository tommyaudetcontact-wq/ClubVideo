extends SceneTree
var g
var c
var b
var failures:=0
func check(value:bool,description:String) -> void:
	if not value:failures+=1;push_error("ENTREPRENEUR_TEST: "+description)
func make_game():
	var result=load("res://main.tscn").instantiate()
	root.add_child(result)
	result.set_physics_process(false)
	result.clerk.set_physics_process(false)
	result.clerk.customers.set_physics_process(false)
	result.session.save_path="user://entrepreneur-workflow-test.dat"
	return result
func shelve(item:Dictionary):
	c.restore_stock(item.record)
	c.cases.erase(item)
	item.node.queue_free()
func _initialize():
	set_meta("entrepreneur_mode",true)
	await process_frame
	g=make_game();c=g.clerk;b=g.entrepreneur
	check(g.layout.movies.size()==200,"200 titles")
	check(g.layout.movies.all(func(movie):return movie.get("fictional",false) and movie.get("kind","")!="game"),"no real movies or games")
	check(b.state.cash==25000 and c.shift.cash_in_till()==5000,"starting money and float")
	check(not b.open_day(),"empty shop cannot open")
	check(b.buy_shelf(0),"purchase shelf")
	b.tick(10.1)
	check(b.packages.size()==1,"parcel delivery")
	b.open_parcel(int(b.state.orders[0].id))
	for index in 6:b.take_board(1);b.place_board()
	for index in 4:b.fasten_screw(.61)
	check(is_instance_valid(b.ghost),"assembly yields placement preview")
	b.ghost.transform=b.snap_placement(Vector3(0,0,1),0,0)
	b.placement_valid=b.valid_placement(b.ghost.transform,0)
	check(b.placement_valid,"starter placement")
	b.finish_placement()
	check(b.free_slots().size()==16,"16 starter slots")
	check(b.shelf_nodes[0].find_children("*","MeshInstance3D",false,false).size()==3,"shelf batched into three material draws")
	check(b.state.buy("sign",0,300,[0]),"order category sign")
	b.tick(10.1)
	for order in b.state.orders.duplicate():b.open_parcel(int(order.id))
	check(b.shelf_nodes[0].get_node("CategoryHeader").text=="ACTION","category parcel installs matching label")
	for id in b.state.offers.slice(0,8):check(b.buy_film(int(id)),"buy film %d"%id)
	b.tick(10.1)
	for order in b.state.orders.duplicate():b.open_parcel(int(order.id))
	check(b.state.stock.size()==8 and c.cases.size()==8,"eight deliveries")
	for item in c.cases.duplicate():shelve(item)
	var first:Dictionary=g.dvd_records[int(b.state.stock.keys()[0])]
	var weight:float=b.title_weight(first.movie)
	b.state.releases[first.movie]=b.state.day
	check(b.title_weight(first.movie)>weight,"novelty raises interest")
	b.state.posters.append({"movie":first.movie,"day":b.state.day})
	check(b.title_weight(first.movie)>weight*3,"matching novelty poster raises interest")
	check(b.title_weight(first.movie,true)>b.title_weight(first.movie),"matching category label raises interest")
	check(b.rank_titles([first.movie,first.movie]).size()==1,"weighted choices stay distinct")
	b.state.releases.erase(first.movie);b.state.posters.clear()
	check(not first.clerk_reserved and first.group.multimesh.get_instance_transform(first.index).basis.determinant()!=0,"visible shelf copy")
	check(not g.shelf_ray(first.world.origin+Vector3(0,0,1),Vector3.FORWARD,2).is_empty(),"new copy can be selected")
	c.desktop.open_program(5)
	for page in 6:c.desktop.business_view.page=page;c.desktop.business_view.refresh()
	var snapshot:Dictionary=g.session.snapshot()
	check(g.session.valid_state(snapshot),"save validation")
	g.queue_free()
	await process_frame
	g=make_game();c=g.clerk;b=g.entrepreneur
	check(g.session.restore(snapshot),"restore")
	check(b.state.stock.size()==8 and b.state.shelves.size()==1,"persistent inventory")
	first=g.dvd_records[int(b.state.stock.keys()[0])]
	check(first.group.multimesh.get_instance_transform(first.index).basis.determinant()!=0,"restored shelf remains visible")
	check(b.open_day() and b.state.hour()=="08:00","business opens at eight")
	c.customers.spawn_customer()
	var shopper:Dictionary=c.customers.customers.back()
	shopper.recommendation=false
	check(c.select_film(shopper),"customer selects owned copy")
	for other in shopper.reservations.slice(1):c.restore_stock(other)
	shopper.reservations=[shopper.record];shopper.rental_count=1;shopper.rental_remaining=1
	shopper.node.position=Vector3(-.6,0,-5.05)
	c.customer_ready(shopper)
	var item:Dictionary=shopper.items[0]
	check(c.scan_item(item),"rental scan")
	c.locks.set_locked(item.node,false)
	var total:int=c.price
	c.tender=2000;c.tender_parts=[2000];shopper.original_tender=[2000]
	c.refresh_tender_visual();c.wallet.take(0,2000,true)
	c.drawer_open=true
	while c.wallet.occupied(0):c.wallet.remove_one(0,0,true)
	var change:int=2000-total
	for value in [1000,500,200,100,25,10,5,1]:
		while change>=value:c.wallet.take(0,value);change-=value
	g.hands[0].global_position=c.customer_hand();c.wallet.release_grip(0)
	check(c.handoff_item(item) and c.active.is_empty(),"paid checkout completes")
	var job:Dictionary=c.returns_due.back()
	check(job.get("business_due_day",0)>=2 and job.get("business_due_day",0)<=4,"business-day return schedule")
	check(not b.state.stock[int(job.record.id)].returned_scanned,"outstanding loan")
	c.customers.customers.erase(shopper);shopper.node.queue_free();c.drawer_open=false
	b.tick(480)
	check(b.close_day(),"clean close")
	check(b.state.daily_receipts==total and c.shift.cash_in_till()==5000,"balanced closing float")
	b.next_day()
	check(b.state.day==2 and b.state.phase=="preparation","next day")
	var returned:Dictionary=c.deliver_return(job)
	var record:Dictionary=returned.record
	check(not b.state.stock[int(record.id)].returned_scanned,"physical return not auto-scanned")
	c.restore_stock(record)
	b.locate_id=int(record.id);b.update_locator()
	check(b.highlighted.visible,"lost shelf copy locates")
	var return_id:int=record.id
	var pending_snapshot:Dictionary=g.session.snapshot()
	check(g.session.valid_state(pending_snapshot),"unscanned return save validation")
	g.queue_free()
	await process_frame
	g=make_game();c=g.clerk;b=g.entrepreneur
	check(g.session.restore(pending_snapshot),"unscanned return restores")
	record=g.dvd_records[return_id]
	check(record.get("pending_return",false) and not b.state.stock[return_id].returned_scanned,"pending return survives reload")
	returned={}
	for candidate in c.cases:
		if int(candidate.record.get("id",-1))==return_id:returned=candidate;break
	check(not returned.is_empty(),"returned physical case survives reload")
	if returned.is_empty():quit(1);return
	load("res://clerk_inventory.gd").bind(returned.node,record)
	check(c.scan_item(returned) and b.state.stock[int(record.id)].returned_scanned,"scan recovers return")
	check(not record.get("pending_return",true),"pending return cleared")
	b.state.phase="open"
	b.answer_phone()
	check(b.state.reservations.size()==1,"phone creates reservation")
	var reservation:Dictionary=b.state.reservations[0]
	var reserved_record:Dictionary=c.reserve_stock(int(reservation.movie))
	check(not reserved_record.is_empty(),"reserved title available")
	if reserved_record.is_empty():quit(1);return
	var reserved_case:Dictionary=c.new_case(reserved_record.movie,Vector3(1,1.2,-6),"shelve")
	reserved_case.record=reserved_record
	load("res://clerk_inventory.gd").bind(reserved_case.node,reserved_record)
	c.pick_case(reserved_case,0,false)
	check(b.reserve_held() and reservation.ready,"hand-held reservation placed in rack")
	check(c.held_service.is_empty() and not reserved_case in c.cases,"rack clears hand and service item")
	b.cancel_reservation(0)
	check(b.state.reservations.is_empty(),"reservation cancelled")
	var cancelled:Dictionary=c.cases.back()
	check(int(cancelled.record.id)==int(reserved_record.id),"cancel restores exact copy")
	shelve(cancelled)
	c.customer_delay=0
	check(c.customers.spawn_customer(),"recommendation customer arrives")
	var advice_customer:Dictionary=c.customers.customers.back()
	b.prepare_recommendation(advice_customer)
	advice_customer.node.position=Vector3(-.6,0,-5.05)
	c.customer_ready(advice_customer)
	check(c.active==advice_customer and advice_customer.items.is_empty(),"recommendation starts without invented case")
	var matches:Array=g.dvd_records.filter(func(copy):return b.state.stock.has(int(copy.id)) and not copy.get("clerk_reserved",true) and str(g.layout.movies[copy.movie].genre)==advice_customer.request_genre and b.review_tag(copy.movie)==advice_customer.request_review and ("nouveau" if b.state.is_new(copy.movie) else "vieux" if b.state.rental(g.layout.movies[copy.movie])==375 else "standard")==advice_customer.request_age)
	check(not matches.is_empty(),"requested recommendation exists")
	if matches.is_empty():quit(1);return
	var advised:Dictionary=matches[0]
	c.reserve_exact(advised)
	var advised_case:Dictionary=c.new_case(advised.movie,Vector3(1,1.2,-6),"shelve")
	advised_case.record=advised
	load("res://clerk_inventory.gd").bind(advised_case.node,advised)
	check(c.scan_item(advised_case) and advice_customer.recommendation_met,"matching recommendation becomes scannable rental")
	check(advice_customer.items.size()==1 and advice_customer.price_titles==[advised.movie],"recommendation billed once")
	print("ENTREPRENEUR_WORKFLOW_COMPLETE failures=",failures)
	quit(1 if failures else 0)
