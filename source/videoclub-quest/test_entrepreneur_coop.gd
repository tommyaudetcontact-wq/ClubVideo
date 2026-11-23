extends SceneTree
var failures:=0
func check(value:bool,description:String) -> void:
	if not value:failures+=1;push_error("BUSINESS_COOP: "+description)
func wait_for(condition:Callable,seconds:float=5) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while not condition.call() and Time.get_ticks_msec()<deadline:await process_frame
	return condition.call()
func make_game(touch:bool):
	var game=load("res://main.tscn").instantiate()
	game.touch_profile=touch
	root.add_child(game)
	game.set_physics_process(false);game.clerk.set_physics_process(false);game.clerk.customers.set_physics_process(false)
	return game
func fixture(game,movies:Array,position:Vector3):
	var business=game.entrepreneur
	var shelf={"model":0,"pose":Transform3D(Basis.IDENTITY,position),"genre":"action"}
	business.state.shelves.append(shelf);business.add_shelf(shelf)
	for movie in movies:
		check(business.receive_film(movie),"fixture delivery")
		var item:Dictionary=game.clerk.cases.back()
		game.clerk.restore_stock(item.record)
		game.clerk.cases.erase(item);item.node.queue_free()
	business.rebuild_navigation()
func _initialize():
	set_meta("entrepreneur_mode",true)
	await process_frame
	var host=make_game(false)
	host.session.save_path="user://business-host-test.dat"
	fixture(host,[0,1,2,3],Vector3(0,0,1))
	host.entrepreneur.state.cash=100000
	var guest=make_game(true)
	guest.session.save_path="user://business-guest-test.dat"
	fixture(guest,[30],Vector3(2,0,2))
	guest.entrepreneur.state.cash=77777
	var local_copy:Dictionary=guest.dvd_records[30]
	var local_pose:Transform3D=local_copy.world
	var local_visible:int=local_copy.group.multimesh.visible_instance_count
	host.clerk.lan.toggle_host()
	check(host.clerk.lan.server!=null,"business host starts")
	var grant:String=host.clerk.lan.permit("127.0.0.1")
	var coop=guest.touch_controls.coop_panel
	guest.head.global_position=host.clerk.screen.global_position+Vector3(0,.25,.6)
	paused=true
	coop.connect_host("127.0.0.1",grant)
	check(await wait_for(func():return coop.connected and coop.mirror and not coop.mirror.state.is_empty()),"guest joins entrepreneur")
	if not coop.connected:quit(1);return
	check(guest.entrepreneur.state.cash==100000 and guest.entrepreneur.state.stock.size()==4,"shared cash and inventory")
	check(guest.entrepreneur.shelf_nodes.size()==1 and guest.entrepreneur.shelf_nodes[0].transform==host.entrepreneur.shelf_nodes[0].transform,"shared shelf geometry")
	check(coop.mirror.state.stock.size()==4 and coop.mirror.state.stock.has("E|0"),"owned stock only and stable copy keys")
	check(guest.dvd_records[0].world==host.dvd_records[0].world and not guest.dvd_records[0].clerk_reserved,"copy positions synchronized")
	check(local_copy.clerk_reserved,"private inventory hidden while visiting")
	var id:int=host.entrepreneur.state.offers[0]
	var price:int=host.entrepreneur.state.purchase_price(host.layout.movies[id])
	var view=guest.clerk.desktop.business_view
	view.page=0;view.refresh()
	for index in view.row_ids.size():
		if view.row_ids[index].kind=="film" and int(view.row_ids[index].id)==id:view.selected=index;break
	view.act()
	check(await wait_for(func():return host.entrepreneur.state.orders.size()==1 and guest.entrepreneur.state.cash==100000-price),"guest buys through shared computer")
	host.entrepreneur.tick(11)
	var order:Dictionary=host.entrepreneur.state.orders[0]
	check(await wait_for(func():return guest.entrepreneur.packages.has(int(order.id))),"delivered parcel visible to guest")
	guest.head.global_position=Vector3(-.5,1.5,-10)
	check(await wait_for(func():return host.clerk.lan.remote_avatar.targets[0].origin.distance_to(guest.head.global_position)<.1),"guest approaches carton")
	host.entrepreneur.open_parcel(int(order.id))
	check(host.entrepreneur.freight.extract(order,1,true),"guest extracts paid copy")
	host.clerk.lan.drop_guest_case()
	var delivered:Dictionary=host.clerk.cases.back()
	host.clerk.restore_stock(delivered.record);host.clerk.cases.erase(delivered);delivered.node.queue_free()
	check(await wait_for(func():return guest.entrepreneur.state.stock.size()==5 and guest.entrepreneur.packages.is_empty()),"opened parcel and new copy replicated")
	guest.head.global_position=host.clerk.screen.global_position+Vector3(0,.25,.6)
	coop.send("enterprise","",JSON.stringify({"op":"buy","kind":"shelf","id":0,"day":host.entrepreneur.state.day}))
	check(await wait_for(func():return host.entrepreneur.state.orders.size()==1),"guest orders shelf")
	host.entrepreneur.tick(11)
	var shelf_order:Dictionary=host.entrepreneur.state.orders[0]
	check(await wait_for(func():return guest.entrepreneur.packages.has(int(shelf_order.id))),"guest receives shelf parcel")
	guest.head.global_position=Vector3(-.5,1.5,-10)
	coop.send("enterprise","",JSON.stringify({"op":"parcel","id":int(shelf_order.id)}))
	check(await wait_for(func():return guest.entrepreneur.freight.held_id==int(shelf_order.id)),"guest carries flatpack carton")
	guest.head.global_position=Vector3(-3.8,1.5,-11.9)
	guest.touch_controls.sync_hands()
	check(await wait_for(func():return host.clerk.lan.remote_avatar.targets[0].origin.distance_to(guest.head.global_position)<.1),"guest reaches workshop")
	guest.entrepreneur.mobile_use()
	check(await wait_for(func():return guest.entrepreneur.assembly.get("stage","")=="site"),"guest opens carton before selecting construction site")
	coop.send("enterprise","",JSON.stringify({"op":"place_shelf","point":[-3.8,0,-11.0],"angle":0}))
	check(await wait_for(func():return guest.entrepreneur.assembly.get("stage","")=="boards"),"guest confirms floor site")
	print("COOP_BUILD_POSE ",host.entrepreneur.assembly.get("pose")," HEAD ",host.clerk.lan.remote_avatar.targets[0].origin)
	for step in 6:
		coop.send("enterprise","",JSON.stringify({"op":"take_board"}))
		check(await wait_for(func():return guest.entrepreneur.guest_board),"guest takes board")
		guest.entrepreneur.mobile_use()
		var expected:=step+1
		check(await wait_for(func():return int(guest.entrepreneur.assembly.get("boards",0))==expected and not guest.entrepreneur.guest_board),"guest places shared board")
	guest.head.global_position=Vector3(-3.1,1.5,-12)
	coop.send("enterprise","",JSON.stringify({"op":"drill"}))
	check(await wait_for(func():return guest.entrepreneur.guest_drill),"guest takes shared drill")
	guest.head.global_position=Vector3(-3.8,1.5,-11.9)
	for step in 20:
		coop.send("enterprise","",JSON.stringify({"op":"screw","index":19-step}))
		var expected:=step+1
		if step<19:check(await wait_for(func():return int(guest.entrepreneur.assembly.get("screws",0))==expected),"guest fixes screw")
		else:check(await wait_for(func():return guest.entrepreneur.state.shelves.size()==2),"guest final screw completes shelf")
	check(await wait_for(func():return host.entrepreneur.state.shelves.size()==2 and guest.entrepreneur.shelf_nodes.size()==2),"final guest screw completes shared shelf at selected site")
	guest.head.global_position=host.clerk.screen.global_position+Vector3(0,.25,.6)
	coop.send("enterprise","",JSON.stringify({"op":"poster","id":id}))
	check(await wait_for(func():return host.entrepreneur.state.orders.size()==1),"guest buys poster")
	host.entrepreneur.tick(11)
	var poster_order:Dictionary=host.entrepreneur.state.orders[0]
	check(await wait_for(func():return guest.entrepreneur.packages.has(int(poster_order.id))),"poster parcel replicated")
	guest.head.global_position=Vector3(-.5,1.5,-10)
	coop.send("enterprise","",JSON.stringify({"op":"parcel","id":int(poster_order.id)}))
	check(await wait_for(func():return guest.entrepreneur.poster_placement.active()),"guest opens poster preview")
	guest.head.global_position=Vector3(-2,2.2,-5.5)
	var poster_hit:Dictionary=guest.entrepreneur.poster_placement.wall_pose(guest.head.global_position,Vector3.FORWARD)
	guest.entrepreneur.poster_placement.preview.global_transform=poster_hit.pose
	guest.entrepreneur.poster_placement.valid=true
	check(guest.entrepreneur.poster_placement.confirm(),"guest submits poster placement")
	check(await wait_for(func():return host.entrepreneur.state.posters.size()==1 and guest.entrepreneur.state.posters.size()==1 and not guest.entrepreneur.poster_placement.active()),"poster appears at same wall position")
	check(host.entrepreneur.poster_pose(0)==guest.entrepreneur.poster_pose(0),"shared poster pose exact")
	coop.send("enterprise","",JSON.stringify({"op":"place_poster","id":int(poster_order.id),"point":[-2,2.2,-7.812]}))
	await create_timer(.2).timeout
	check(host.entrepreneur.state.posters.size()==1,"duplicate poster confirmation rejected")
	guest.head.global_position=host.dvd_records[0].world.origin+Vector3(0,.35,.7)
	coop.send("shelf_pick","E|0")
	check(await wait_for(func():return not coop.guest_case_id.is_empty()),"guest can take entrepreneur shelf copy")
	check(host.dvd_records[0].clerk_reserved and not host.entrepreneur.state.stock[0].shelved,"shared pickup reserves exact copy")
	guest.entrepreneur.locate_id=0
	coop.mirror._process(.02)
	check(guest.entrepreneur.highlighted.visible,"guest can locate physical shared case")
	coop.send("case_drop")
	check(await wait_for(func():return coop.guest_case_id.is_empty()),"guest drops shared case")
	paused=false
	coop.reset("Fin du test")
	await process_frame
	check(guest.entrepreneur.state.cash==77777 and guest.entrepreneur.state.stock.size()==1,"private business finances restored")
	check(local_copy.world==local_pose and not local_copy.clerk_reserved,"private shelf copy restored")
	check(local_copy.group.multimesh.visible_instance_count==local_visible,"private rendering budget restored")
	check(host.entrepreneur.state.stock.size()==5,"host progression persists after guest leaves")
	host.clerk.lan.toggle_host()
	print("ENTREPRENEUR_COOP_COMPLETE failures=",failures)
	quit(1 if failures else 0)
