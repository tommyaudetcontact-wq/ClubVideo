extends SceneTree
var failures:=0
func check(ok:bool,message:String) -> void:
	if not ok:failures+=1;push_error("FEEDBACK112: "+message)
func _initialize():
	set_meta("entrepreneur_mode",true)
	await process_frame
	var g=load("res://main.tscn").instantiate();root.add_child(g)
	g.set_physics_process(false);g.clerk.set_physics_process(false);g.clerk.customers.set_physics_process(false)
	var b=g.entrepreneur;var c=g.clerk
	check(b.state.decorations.is_empty() and not g.gum.is_visible_in_tree(),"entrepreneur starts without vending decorations")
	check(b.buy_shelf(0) and b.packages.size()==1,"shelf delivered immediately")
	var order:Dictionary=b.state.orders[0];var id:int=order.id
	check(b.freight.take(id,0),"shelf carton can be carried")
	g.hands[0].global_position=Vector3(-3.9,1,-12.6);b.freight.tick();b.freight.drop_from_hand()
	check(b.packages[id].position.y>.70,"carton rests above workbench")
	b.open_parcel(id)
	check(b.assembly.stage=="site" and is_instance_valid(b.ghost),"opening carton precedes site confirmation")
	b.ghost.transform=b.snap_placement(Vector3(0,0,2),0,0);b.finish_placement()
	check(b.assembly.stage=="boards" and not is_instance_valid(b.ghost),"construction starts at deposited box without a retail placement step")
	check(b.assembly.pose.origin==Vector3(0,0,2),"assembly uses explicitly chosen floor site")
	b.take_board(1);b.board.global_position=b.assembly_node.global_position+Vector3(0,1,1.5);b.release_grip(1)
	check(is_instance_valid(b.loose_board) and b.board_hand<0,"misplaced board becomes physical and can be recovered")
	for i in 6:
		b.take_board(1)
		var target:Transform3D=b.assembly_node.global_transform*b.Build.part_pose(.785,i)
		b.board.global_transform=target
		b.release_grip(1)
		check(int(b.assembly.boards)==i+1 and b.board_hand<0,"release snaps board into highlighted joint")
	check(b.assembly_node.get_node("Screws").get_child_count()==20,"one side screw at each shelf joint")
	b.fasten_screw(.61,9);check(b.Build.done(b.assembly,9) and not b.Build.done(b.assembly,0),"last screw can be driven first")
	b.fasten_screw(.61,9);check(int(b.assembly.screws)==1,"same screw cannot be charged twice")
	for index in [4,0,7,2,8,1,6,3,5,10,11,12,13,14,15,16,17,18,19]:b.fasten_screw(.61,index)
	check(b.state.shelves.size()==1 and b.assembly.is_empty(),"completed shelf stays where built")
	b.start_move_shelf(0);b.ghost.transform=b.snap_placement(Vector3(0,0,1),0,0);b.finish_placement()
	check(b.state.shelves[0].pose.origin==Vector3(0,0,1),"finished shelf moved from workshop to retail")
	check(b.receive_film(0),"receive case")
	var item:Dictionary=c.cases.back();var record:Dictionary=item.record
	check(int(b.state.stock[int(record.id)].shelf)==-1,"new film has no forced slot")
	var target:Transform3D=b.slots.pose(0,17)
	check(b.slots.choose(record,target.origin),"choose arbitrary first slot")
	c.restore_stock(record);check(b.state.stock[int(record.id)].slot==17,"chosen slot persists")
	check(not b.slots.is_free(0,17),"occupied slot cannot be double booked")
	var chips=load("res://entrepreneur_card.gd")
	var chip_names:Array=chips.COLORS.keys()
	for movie in g.layout.movies:
		if not chip_names.has(str(movie.genre).to_lower()):chip_names.append(str(movie.genre).to_lower())
	for key in chip_names:
		var background:Color=chips.pill_color(key);var foreground:Color=chips.ink(background)
		var a:=background.srgb_to_linear();var z:=foreground.srgb_to_linear()
		var l1:float=.2126*a.r+.7152*a.g+.0722*a.b;var l2:float=.2126*z.r+.7152*z.g+.0722*z.b
		check((maxf(l1,l2)+.05)/(minf(l1,l2)+.05)>=4.5,"readable chip contrast: "+str(key))
	check(b.calendar_canvas.events.size()>0,"release titles appear on calendar dates")
	var copy=b.state.snapshot();var other=b.Rules.new();other.restore(copy)
	check(other.release_days==b.state.release_days,"announced dates survive save")
	c.desktop.open_program(5);var view=c.desktop.business_view;view.page=0;view.refresh();view.scroll_rows(1)
	check(view.offset==1 and view.rows.size()==3,"larger UI with line scrolling")
	b.state.cash=100000;check(b.decor.buy(0),"plant can be purchased")
	var decoration:Dictionary=b.state.orders.back()
	check(b.decor.install(int(decoration.id),Transform3D(Basis.IDENTITY,Vector3(2,0,4))),"purchased plant can be placed")
	check(b.state.decorations.size()==1 and b.decor.nodes[0].is_visible_in_tree(),"purchased decoration visible")
	for index in [1,2,3]:
		check(b.decor.buy(index),"purchase other decoration")
		var delivered:Dictionary=b.state.orders.back()
		var point:=Vector3(-.5,1.2,-5.3) if index==1 else Vector3(-2,0,4) if index==2 else Vector3(2,2.55,2)
		check(b.decor.install(int(delivered.id),Transform3D(Basis.IDENTITY,point)),"install original model decoration")
	check(g.candy.machines.size()==4,"two purchased machines have physical candy chutes")
	check(g.candy.use_machine(2) and g.candy.use_machine(2),"purchased countertop machine dispenses")
	check(g.candy.use_machine(3) and g.candy.use_machine(3),"purchased spiral machine dispenses")
	check(g.candy.balls.size()==2,"two real physical candies created")
	print("FEEDBACK112_COMPLETE failures=",failures)
	quit(1 if failures else 0)
