extends SceneTree

func _initialize():
	await process_frame
	var scene=load("res://main.tscn")
	var host=scene.instantiate()
	host.touch_profile=false
	root.add_child(host)
	host.session.save_path="user://coop-test-host.dat"
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
	guest.session.save_path="user://coop-test-guest.dat"
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
	guest.head.global_position=host.clerk.tender_note.global_position+Vector3(0,.3,.3)
	guest.touch_controls.take_payment()
	await create_timer(.6).timeout
	assert(not host.clerk.tender_received and host.clerk.tender_parts.is_empty())
	assert(not host.clerk.lan.guest_cash.is_empty() and guest.clerk.wallet.total(0)==host.clerk.tender)
	assert(not guest.clerk.wallet.palms[0].is_empty())
	coop.send("drawer")
	await create_timer(.3).timeout
	guest.touch_controls.deposit_payment(true)
	await create_timer(.8).timeout
	assert(host.clerk.tender_received and coop.checkout.received and host.clerk.lan.guest_cash.is_empty())
	# Two players reserve the same drawer denomination without duplicating cash.
	var before:int=host.clerk.till[25]
	coop.send("cash_take","","25")
	await create_timer(.3).timeout
	assert(host.clerk.till[25]==before-1 and guest.clerk.wallet.total(0)==25)
	var coin=guest.clerk.wallet.palms[0][0].node
	guest.touch_controls.select_cash(coin)
	guest.touch_controls.deposit_payment()
	await create_timer(.8).timeout
	assert(host.clerk.till[25]==before and guest.clerk.wallet.total(0)==0)
	guest.head.global_position=host.clerk.basket.body.global_position+Vector3(0,.4,.4)
	coop.send("basket_carry")
	await create_timer(.3).timeout
	assert(coop.basket_carried and host.clerk.lan.guest_basket)
	coop.send("basket_carry")
	await create_timer(.3).timeout
	assert(not coop.basket_carried and not host.clerk.lan.guest_basket)
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
		guest.touch_controls.use_lock()
		await create_timer(.85).timeout
	assert(not item.node.get_meta("antitheft",false))
	coop.toggle_guest_case()
	assert(coop.mirror.nodes["cases"+coop.guest_case_id].get_meta("mirror_open"))
	await create_timer(.55).timeout
	assert(coop.guest_open and host.clerk.lan.guest_inspection.opened)
	var visual:Node3D=coop.mirror.nodes["cases"+coop.guest_case_id]
	var interior:Node3D=visual.get_node("MirrorInterior")
	assert(interior.visible and not visual.get_node("MoldedPlasticOnly").visible)
	assert(interior.get_node("Hinge").rotation.y < -.5)
	guest.touch_controls.use_disc()
	await create_timer(.55).timeout
	assert(not coop.guest_disc.is_empty() and item.node.get_meta("disc_movie")==-1)
	coop.send("disc_flip")
	await create_timer(.55).timeout
	assert(coop.guest_disc_back)
	guest.touch_controls.use_disc()
	await create_timer(.55).timeout
	assert(coop.guest_disc.is_empty() and item.node.get_meta("inspected",false))
	coop.send("case_open")
	await create_timer(.55).timeout
	assert(not coop.guest_open)
	guest.head.global_position=host.clerk.scanner.global_position+Vector3(0,.30,.35)
	guest.touch_controls.scan()
	await create_timer(.85).timeout
	assert(item.scanned and coop.mirror.state.audio.scan==host.clerk.scan_serial)
	guest.head.global_position=host.clerk.drawer.global_position+Vector3(0,.3,.3)
	var change_due:int=host.clerk.tender-host.clerk.price
	for denomination in [5000,2000,1000,500,200,100,25,10,5,1]:
		while change_due>=denomination:
			coop.send("cash_take","",str(denomination))
			change_due-=denomination
			await create_timer(.15).timeout
	await create_timer(.3).timeout
	assert(guest.clerk.wallet.total(0)==host.clerk.tender-host.clerk.price)
	guest.head.global_position=host.clerk.customer_hand()+Vector3(0,.25,.3)
	guest.touch_controls.give_change()
	await create_timer(.8).timeout
	assert(host.clerk.paid and guest.clerk.wallet.total(0)==0)
	guest.touch_controls.handoff()
	await create_timer(.85).timeout
	assert(coop.guest_case_id.is_empty() and host.clerk.active.is_empty())
	guest.head.global_position=host.clerk.drawer.global_position+Vector3(0,.35,.3)
	host.clerk.set_drawer_open(false)
	await create_timer(.3).timeout
	coop.send("drawer")
	await create_timer(.8).timeout
	assert(host.clerk.drawer_open and coop.checkout.drawer_open)
	assert(guest.clerk.drawer.global_position.distance_to(host.clerk.drawer.global_position)<.003)
	coop.send("drawer_toggle")
	await create_timer(.8).timeout
	assert(not host.clerk.drawer_open and not coop.checkout.drawer_open)
	# A snapshot changes the destination, while rendered customers move between snapshots.
	var npc_visual:Node3D=coop.mirror.nodes.get("clients"+str(shopper.id))
	assert(is_instance_valid(npc_visual))
	var start:Vector3=npc_visual.global_position
	shopper.node.global_position=start+Vector3(.4,0,0)
	coop.mirror.apply(world.capture(host,false))
	assert(npc_visual.global_position.is_equal_approx(start))
	coop.mirror._process(.02)
	assert(npc_visual.global_position.x>start.x and npc_visual.global_position.x<shopper.node.global_position.x)
	# A disconnect returns reserved drawer money exactly once.
	coop.send("drawer")
	await create_timer(.25).timeout
	var cash_before:int=host.clerk.till[25]
	coop.send("cash_take","","25")
	await create_timer(.3).timeout
	assert(host.clerk.till[25]==cash_before-1)
	var saved:Dictionary=host.session.snapshot()
	assert(saved.cash.any(func(entry):return int(entry.value)==25))
	paused=false
	coop.reset("Test terminé")
	await create_timer(.3).timeout
	assert(host.clerk.till[25]==cash_before and host.clerk.lan.guest_cash.is_empty())
	assert(local.disc_uid==999999 and not coop.connected)
	var compressed_full:String=world.capture(host,true)
	var compressed_delta:String=world.capture(host,false)
	assert(compressed_delta.length()<compressed_full.length()/2)
	print("WORLD_PAYLOAD full=",compressed_full.length()," delta=",compressed_delta.length())
	print("COOP_FULL_SIMULATION_OK: early cash, no-code grant, mirrored inventory and day, shared basket, shared cash, local restore")
	quit()
