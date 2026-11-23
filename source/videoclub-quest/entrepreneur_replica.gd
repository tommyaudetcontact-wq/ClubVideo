extends RefCounted
## Geometry/state adapter for a visiting player. It never advances the business clock.
var business
var local_state:Dictionary={}
var shelf_shape:Array=[]
var poster_data:Array=[]
var assembly_data:Dictionary={}
var local_visible:=0

func setup(owner_business) -> void:
	business=owner_business
	local_state=business.snapshot().duplicate(true)
	local_visible=business.game.dvd_records[0].group.multimesh.visible_instance_count
	shelf_shape=shape_of(business.state.shelves)
	poster_data=business.state.posters.duplicate(true)
	assembly_data=business.assembly.duplicate(true)

func shape_of(shelves:Array) -> Array:
	return shelves.map(func(shelf):return {"model":shelf.model,"pose":shelf.pose})

func apply(data:Dictionary) -> void:
	if not data.get("rules") is Dictionary:return
	business.state.restore(data.rules)
	business.ledgers=data.get("ledgers",{}).duplicate(true)
	refresh_views(data.get("assembly",{}))
	var controls:Dictionary=data.get("controls",{})
	business.freight.held_id=int(controls.get("carton",-1))
	business.freight.held_hand=0 if business.freight.held_id>=0 else -1
	business.guest_board=controls.get("board",false)
	business.guest_drill=controls.get("drill",false)
	business.guest_placing=controls.get("placing",false)
	business.drill.global_transform=controls.get("drill_pose",business.drill.global_transform)
	if business.guest_board:
		if not is_instance_valid(business.guest_board_node):business.guest_board_node=business.Props.box(business,Vector3.ZERO,Vector3(.35,.025,.18),"b58b5b")
		business.guest_board_node.global_transform=controls.get("board_pose",Transform3D.IDENTITY)
	elif is_instance_valid(business.guest_board_node):business.guest_board_node.queue_free();business.guest_board_node=null
	if is_instance_valid(business.ghost) and not business.guest_placing:business.ghost.global_transform=controls.get("ghost",business.ghost.global_transform)
	if business.moving_shelf>=0 and is_instance_valid(business.ghost):business.preview_stock()
	var poster_id:int=controls.get("poster",-1)
	if poster_id>=0 and not business.poster_placement.active():
		for order in business.state.orders:
			if int(order.id)==poster_id:business.poster_placement.begin(order);break
	elif poster_id<0 and business.poster_placement.active():business.poster_placement.cancel(false)
	business.decor.sync()
	business.update_prices()
	business.watch.text=business.state.hour()+"\n%.2f $"%(business.state.cash/100.0)
	business.refresh_calendar()
	business.apply_weather()
	business.sign.text="OUVERT" if business.state.phase=="open" else "FERMÉ"
	business.sign.modulate=Color("86e9be") if business.state.phase=="open" else Color("ec8972")
	if business.game.clerk.desktop.business_view:business.game.clerk.desktop.business_view.refresh()

func refresh_views(assembly:Dictionary) -> void:
	var new_shape:=shape_of(business.state.shelves)
	if shelf_shape!=new_shape:
		for node in business.shelf_nodes:
			if is_instance_valid(node):node.get_parent().remove_child(node);node.queue_free()
		business.shelf_nodes.clear()
		business.game.layout.colliders=business.game.layout.colliders.filter(func(box):return not box.get("business_shelf",false))
		for shelf in business.state.shelves:business.add_shelf(shelf)
		shelf_shape=new_shape.duplicate(true)
		business.rebuild_navigation()
	for index in business.state.shelves.size():
		var genre:=str(business.state.shelves[index].get("genre",""))
		business.shelf_nodes[index].get_node("CategoryHeader").text=genre.to_upper() if not genre.is_empty() else "VIDÉO CLUB"
	if poster_data!=business.state.posters:
		for node in business.get_children():
			if node.get_meta("business_poster",false):node.get_parent().remove_child(node);node.queue_free()
		for index in business.state.posters.size():business.place_poster(int(business.state.posters[index].movie),index)
		poster_data=business.state.posters.duplicate(true)
	var delivered:Dictionary={}
	for order in business.state.orders:
		if not order.get("delivered",false):continue
		delivered[int(order.id)]=true
		if not business.packages.has(int(order.id)):business.deliver(order)
	for order in business.state.orders:
		if business.packages.has(int(order.id)):
			if order.has("pose"):business.packages[int(order.id)].transform=order.pose
			business.freight.refresh(order)
	if business.decor.order_id>=0 and business.freight.order_for(business.decor.order_id).is_empty():business.decor.cancel()
	for id in business.packages.keys():
		if delivered.has(id):continue
		var node:Node3D=business.packages[id]
		business.game.clerk.targets=business.game.clerk.targets.filter(func(target):return is_instance_valid(target.node) and target.node!=node)
		if is_instance_valid(node):node.get_parent().remove_child(node);node.queue_free()
		business.packages.erase(id)
	if assembly_data!=assembly:
		business.assembly=assembly.duplicate(true)
		business.moving_shelf=int(assembly.get("moving_index",-1))
		for index in business.shelf_nodes.size():business.shelf_nodes[index].visible=index!=business.moving_shelf
		if is_instance_valid(business.ghost):business.ghost.queue_free();business.ghost=null
		if not assembly.is_empty():
			if assembly.get("stage","") in ["site","move"]:business.begin_placement()
			else:business.build_assembly()
		elif is_instance_valid(business.assembly_node):
			var old:Node3D=business.assembly_node
			business.game.clerk.targets=business.game.clerk.targets.filter(func(target):return is_instance_valid(target.node) and not old.is_ancestor_of(target.node))
			old.queue_free();business.assembly_node=null
		assembly_data=assembly.duplicate(true)

func restore_local() -> void:
	if local_state.is_empty():return
	business.release_guest_tools()
	if business.poster_placement.active():business.poster_placement.cancel(false)
	business.state.restore(local_state.rules)
	business.ledgers=local_state.ledgers.duplicate(true)
	refresh_views(local_state.get("assembly",{}))
	business.decor.sync()
	business.update_prices();business.apply_weather();business.refresh_calendar()
	business.watch.text=business.state.hour()+"\n%.2f $"%(business.state.cash/100.0)
	business.sign.text="OUVERT" if business.state.phase=="open" else "FERMÉ"
	business.sign.modulate=Color("86e9be") if business.state.phase=="open" else Color("ec8972")
	business.ghost_label.text=""
	business.game.dvd_records[0].group.multimesh.visible_instance_count=local_visible

