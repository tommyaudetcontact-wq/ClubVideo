extends SceneTree

func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	var c=game.clerk
	var touch=game.touch_controls
	assert(touch!=null and not game.xr_active)
	c.customers.set_physics_process(false)
	c.set_physics_process(false)
	c.shift.enabled=false
	load("res://clerk_inventory.gd").mix_records(game.dvd_records,0)
	c.max_basket=1
	c.customers.spawn_customer()
	var client=c.customers.customers[0]
	client.movie=0
	c.select_film(client)
	client.state="service"
	client.node.position=Vector3(-.6,0,-5.05)
	c.customer_ready(client)
	var item=client.items[0]
	item.node.set_meta("customer_animating",false)
	item.node.global_position=Vector3(1.0,1.12,-6.3)
	game.head.global_position=Vector3(1.0,1.55,-7.0)
	game.head.look_at(item.node.global_position)
	touch.use_target()
	assert(touch.action_busy())
	await touch.action_motion.finished
	assert(game.held==item.node)
	touch.use_lock()
	assert(touch.action_busy())
	await touch.action_motion.finished
	assert(not game.held.get_meta("antitheft"))
	touch.toggle_case()
	await create_timer(.3).timeout
	assert(c.inspection.opened and c.inspection.opening_amount>.9)
	touch.use_disc()
	assert(c.inspection.finger==1)
	await create_timer(.18).timeout
	assert(c.inspection.carried_data.inspected)
	touch.flip_item()
	touch.use_disc()
	assert(c.inspection.finger<0)
	touch.toggle_case()
	touch.scan()
	assert(touch.action_busy())
	await touch.action_motion.finished
	assert(item.scanned and c.price>0)
	c.tender=500
	c.tender_parts=[500]
	c.refresh_tender_visual()
	c.action("computer",1)
	game.head.global_position=c.tender_note.global_position+Vector3(0,.45,.52)
	touch.take_payment()
	touch.deposit_payment()
	assert(c.tender_received)
	for value in [25,25,10,5,1,1,1,1]:c.wallet.take(1,value)
	game.head.global_position=c.customer_hand()+Vector3(0,.4,-.65)
	game.head.look_at(c.customer_hand())
	touch.give_change()
	assert(c.paid)
	touch.drop()
	assert(c.active.is_empty() and c.returns_due.size()==1)
	var state=game.session.snapshot()
	assert(state.has("accounts") and state.shift.day==1)
	var udp:=PacketPeerUDP.new()
	game.lobby.start()
	assert(udp.set_dest_address("127.0.0.1",39166)==OK)
	var peer="abcdef0123456789abcdef01"
	var target=game.lobby.device_id
	udp.put_packet(JSON.stringify({"magic":"VideoClubLobby/1","type":"presence","sender":peer,"name":"Quest TEST"}).to_utf8_buffer())
	await create_timer(.2).timeout
	assert(game.lobby.peers.has(peer))
	udp.put_packet(JSON.stringify({"magic":"VideoClubLobby/1","type":"invite","sender":peer,"to":target,"ticket":"abcdef0123456789"}).to_utf8_buffer())
	await create_timer(.2).timeout
	assert(game.lobby.incoming.from==peer)
	touch.toggle_menu()
	touch.open_lobby()
	assert(touch.lobby_panel.get_parent().visible)

	print("TOUCH069_OK: inventory, unlock, inspection, scan, cash, handoff, save snapshot, lobby discovery and invite")
	quit()

