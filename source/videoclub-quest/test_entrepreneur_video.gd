extends SceneTree
var failures:=0
func check(ok:bool,message:String):
	if not ok:failures+=1;push_error("VIDEO_FEEDBACK: "+message)
func _initialize():
	set_meta("entrepreneur_mode",true)
	await process_frame
	var g=load("res://main.tscn").instantiate();root.add_child(g)
	g.set_physics_process(false);g.clerk.set_physics_process(false);g.clerk.customers.set_physics_process(false)
	var b=g.entrepreneur;var c=g.clerk
	b.buy_shelf(0);b.tick(11);var order:Dictionary=b.state.orders[0]
	b.open_parcel(int(order.id))
	check(b.assembly.stage=="boards" and b.packages.has(int(order.id)),"carton starts assembly where deposited")
	for i in 6:b.take_board(1);b.place_board()
	for i in 10:b.fasten_screw(.61)
	check(b.state.shelves.size()==1 and b.packages.is_empty(),"parcel consumed once after all six boards and ten screws")
	b.state.cash=100000
	var movie:int=b.state.offers[0]
	for i in 21:check(b.buy_film(movie),"order copy")
	# Budget is finite: the initial cash permits 15 copies at the starter price.
	# Test packing limit independently without bypassing in-game affordability.
	var rules=load("res://entrepreneur_state.gd").new();rules.cash=100000
	for i in 21:rules.buy("films",movie,100,[movie])
	check(rules.orders.size()==2 and rules.orders[0].contents.size()==20 and rules.orders[1].contents.size()==1,"twenty films maximum per carton")
	b.tick(11)
	var box:Dictionary=b.state.orders[0]
	var box_id:int=box.id
	var position:Vector3=b.packages[box_id].position
	g.hands[0].global_position=position+Vector3(.23,0,0)
	check(b.freight.interact(0,true) and b.freight.held_id==box_id,"grip side of carton to carry")
	b.freight.tick();check(b.packages[box_id].position.distance_to(position)>.05,"carton follows hand")
	b.freight.use(box_id,1)
	check(box.opened and box.contents.size()>0 and b.state.stock.is_empty(),"opening does not spawn all purchased films")
	var count:int=box.contents.size()
	check(b.freight.extract(box,1) and box.contents.size()==count-1,"one film extracted")
	check(g.held!=null and c.held_service.record.movie==movie,"extracted film actually in hand")
	var item:Dictionary=c.held_service
	c.clear_hand();c.restore_stock(item.record);c.cases.erase(item);item.node.queue_free()
	var record:Dictionary=g.dvd_records[int(b.state.stock.keys()[0])]
	b.freight.drop();check(b.freight.held_id<0 and b.packages[box_id].position.y>=.135,"carton safely placed above floor")
	var pose:Transform3D=b.packages[box_id].transform
	var snapshot:Dictionary=b.snapshot()
	check(snapshot.rules.orders[0].pose==pose and snapshot.rules.orders[0].opened and snapshot.rules.orders[0].contents.size()==count-1,"opened contents and dropped position saved")
	var old:Transform3D=record.world
	b.start_move_shelf(0)
	b.ghost.transform=b.snap_placement(Vector3(2,0,2),PI/4,0)
	b.finish_placement()
	check(b.state.shelves.size()==1 and b.state.shelves[0].pose.origin==Vector3(2,0,2),"move existing shelf without duplicating it")
	check(record.world!=old and b.shelf_nodes[0].transform==b.state.shelves[0].pose,"shelf stock and geometry move together")
	check(g.shelf_ray(record.world.origin+record.world.basis.z, -record.world.basis.z,2).get("id",-1)==record.id,"moved stock still selectable")
	var view=c.desktop.business_view;c.desktop.open_program(5);view.page=0;view.refresh()
	view.scroll_rows(1);check(view.offset==1,"continuous scroll advances one row")
	check(view.film_cards.size()==3,"catalogue displays larger film cards")
	check(b.calendar_canvas.previews.size()==3,"calendar displays three forthcoming covers")
	print("ENTREPRENEUR_VIDEO_COMPLETE failures=",failures)
	quit(1 if failures else 0)
