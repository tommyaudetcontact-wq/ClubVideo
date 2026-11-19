extends SceneTree

func _initialize():
	await process_frame
	var scene=load("res://main.tscn")
	var host=scene.instantiate()
	host.touch_profile=true
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
	assert(host.clerk.lan.server==null)
	host.lobby.toggle_mobile_host()
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
	paused=false
	coop.reset("Test terminé")
	assert(local.disc_uid==999999 and not coop.connected)
	print("ANDROID_COOP084_OK: early cash, no-code grant, mirrored inventory and day, shared basket, shared cash, local restore")
	quit()


