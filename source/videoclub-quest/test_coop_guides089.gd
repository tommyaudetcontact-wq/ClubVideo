extends SceneTree

func _initialize():
	await process_frame
	var scene=load("res://main.tscn")
	var host=scene.instantiate()
	host.touch_profile=false
	root.add_child(host)
	host.set_physics_process(false)
	host.clerk.set_physics_process(false)
	host.clerk.customers.set_physics_process(false)
	host.clerk.shift.day=4
	host.clerk.shift.time_left=182.0
	host.clerk.customers.spawn_customer()
	var shopper:Dictionary=host.clerk.customers.customers[0]
	host.clerk.max_basket=1
	host.clerk.select_film(shopper)
	host.clerk.customer_ready(shopper)
	var item:Dictionary=shopper.items[0]
	assert(host.clerk.tender>0 and host.clerk.tender_note.visible and not item.scanned and host.clerk.price==0)
	var offered:int=host.clerk.tender
	host.clerk.pick_case(item,0,false)
	assert(host.clerk.scan_held() and host.clerk.tender==offered and host.clerk.price>0)
	var origin:Vector3=Vector3(-1.4,1.36,-5.95)
	host.clerk.clear_hand()
	item.node.reparent(host.clerk)
	item.node.global_position=origin
	host.clerk.tender_received=false
	host.lobby.socket=PacketPeerUDP.new()
	assert(host.lobby.socket.bind(39166,"127.0.0.2")==OK)
	host.lobby.set_available(true)
	assert(host.clerk.lan.server!=null)
	var guest=scene.instantiate()
	guest.touch_profile=true
	root.add_child(guest)
	guest.clerk.customers.set_physics_process(false)
	var first:Dictionary=host.dvd_records[0]
	var local:Dictionary=guest.dvd_records[0]
	local.disc_uid=999999
	guest.lobby.socket=PacketPeerUDP.new()
	assert(guest.lobby.socket.bind(39166,"127.0.0.1")==OK)
	guest.lobby.set_available(true)
	host.lobby.broadcast_targets.clear()
	guest.lobby.broadcast_targets.clear()
	guest.lobby.probe_hosts=PackedStringArray(["127.0.0.2"])
	var coop=guest.touch_controls.coop_panel
	guest.head.global_position=Vector3(-1.4,1.55,-6.5)
	paused=true
	for attempt in range(240):
		await process_frame
		if not guest.lobby.list_players().is_empty():break
	assert(not guest.lobby.list_players().is_empty() and guest.lobby.list_players()[0].hosting)
	guest.lobby.request(0,false)
	for attempt in range(250):
		await process_frame
		if coop.connected and not coop.mirror.state.is_empty():break
	assert(coop.connected and not coop.mirror.state.is_empty())
	assert(coop.mirror.state.shift.day==4 and coop.mirror.state.shift.time_left==182.0)
	assert(local.disc_uid==first.disc_uid and coop.mirror.state.cases[0].transform.origin.is_equal_approx(origin))
	assert(coop.mirror.state.clients.size()==1 and not coop.mirror.state.cash.is_empty())
	assert(not host.clerk.lan.permits.has(coop.grant))
	coop.selected_case=str(item.node.get_instance_id())
	coop.send("case_basket")
	await create_timer(.65).timeout
	assert(item in host.clerk.basket.items and coop.mirror.state.cases[0].in_basket)
	coop.send("cash_deposit")
	await create_timer(.65).timeout
	assert(host.clerk.tender_received and coop.checkout.received)
	coop.send("case_pick",str(item.node.get_instance_id()))
	await create_timer(.65).timeout
	assert(coop.guest_case_id==str(item.node.get_instance_id()) and item.node.get_meta("guest_held",false))
	assert(not item in host.clerk.basket.items)
	host.clerk.pick_case(item,0,false)
	assert(host.held!=item.node)
	coop.send("case_flip")
	await create_timer(.65).timeout
	assert(coop.guest_flipped)
	coop.send("held_basket")
	await create_timer(.65).timeout
	assert(coop.guest_case_id.is_empty() and item in host.clerk.basket.items)
	var stock:Dictionary=host.dvd_records.filter(func(record):return not record.get("clerk_reserved",false))[0]
	guest.head.global_position=stock.world.origin+Vector3(0,0,.5)
	var world=load("res://club_world_sync.gd")
	coop.send("shelf_pick",world.shelf_key(host,stock))
	await create_timer(.65).timeout
	assert(stock.clerk_reserved and not coop.guest_case_id.is_empty())
	coop.update_shelf_marker(true)
	assert(guest.clerk.repairs.marker.visible)
	assert(guest.clerk.repairs.marker.global_transform.is_equal_approx(stock.world))
	coop.update_shelf_marker(false)
	assert(not guest.clerk.repairs.marker.visible)
	coop.update_shelf_marker(true)
	coop.send("case_drop")
	await create_timer(.65).timeout
	assert(not stock.clerk_reserved and coop.guest_case_id.is_empty())
	coop.update_shelf_marker(true)
	assert(not guest.clerk.repairs.marker.visible)
	var aim:Node3D=guest.aim_hands[guest.touch_controls.CASE_HAND]
	aim.global_position=stock.world.origin+stock.world.basis.z.normalized()*.45
	aim.look_at(stock.world.origin)
	var picked:Dictionary=guest.touch_controls.coop_case_target()
	assert(not picked.is_empty() and picked.has("pose") and picked.has("bounds"))
	guest.head.global_position=item.node.global_position+Vector3(0,.30,.35)
	coop.send("case_pick",str(item.node.get_instance_id()))
	await create_timer(.55).timeout
	assert(not coop.guest_case_id.is_empty())
	guest.head.global_position=Vector3(.72,1.45,-6.15)
	if item.node.get_meta("antitheft",false):
		coop.send("case_lock")
		await create_timer(.55).timeout
	assert(not item.node.get_meta("antitheft",false))
	coop.send("case_open")
	await create_timer(.55).timeout
	assert(coop.guest_open and host.clerk.lan.guest_inspection.opened)
	coop.send("disc_use")
	await create_timer(.55).timeout
	assert(not coop.guest_disc.is_empty() and item.node.get_meta("disc_movie")==-1)
	coop.send("disc_flip")
	await create_timer(.55).timeout
	assert(coop.guest_disc_back)
	coop.send("disc_use")
	await create_timer(.55).timeout
	assert(coop.guest_disc.is_empty() and item.node.get_meta("inspected",false))
	coop.send("case_open")
	await create_timer(.55).timeout
	assert(not coop.guest_open)
	guest.head.global_position=host.clerk.scanner.global_position+Vector3(0,.30,.35)
	coop.send("case_scan")
	await create_timer(.55).timeout
	assert(item.scanned)
	host.clerk.paid=true
	guest.head.global_position=host.clerk.customer_hand()+Vector3(0,.25,.3)
	coop.send("case_handoff")
	await create_timer(.65).timeout
	assert(coop.guest_case_id.is_empty() and host.clerk.active.is_empty())
	paused=false
	coop.reset("Test terminé")
	assert(local.disc_uid==999999 and not coop.connected)
	print("COOP_GUIDES089_OK: early cash, no-code grant, mirrored inventory and day, shared basket, shared cash, local restore")
	quit()


