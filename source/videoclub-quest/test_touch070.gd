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
	game.held.set_meta("disc_movie",int(item.movie)+1)
	game.held.set_meta("dirty",true)
	touch.toggle_case()
	await create_timer(.3).timeout
	assert(c.inspection.opened and c.inspection.opening_amount>.9)
	touch.tap_target(game.head.unproject_position(c.inspection.disc.global_position))
	assert(c.inspection.finger==1)
	await create_timer(.18).timeout
	assert(c.inspection.carried_data.inspected)
	touch.tap_target(game.head.unproject_position(c.inspection.carried.global_position))
	assert(touch.disc_back)
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
	game.head.look_at(c.tender_note.global_position)
	touch.tap_target(game.head.unproject_position(c.tender_note.global_position))
	assert(c.wallet.occupied(1))
	touch.deposit_payment()
	assert(c.tender_received)
	for value in [25,25,10,5,1,1,1,1]:c.wallet.take(1,value)
	game.head.global_position=c.customer_hand()+Vector3(0,.4,-.65)
	game.head.look_at(c.customer_hand())
	touch.give_change()
	assert(c.paid)
	touch.drop()
	assert(c.active.is_empty() and c.returns_due.size()==1)
	assert(c.shift.refunds==0 and c.returns_due[0].refund>0)
	var job:Dictionary=c.returns_due.pop_back()
	assert(game.session.pack_job(job).refund==job.refund)
	c.deliver_return(job)
	assert(c.shift.refunds==job.refund)
	touch.open_desktop()
	assert(touch.desktop_overlay.visible and touch.desktop_view.texture!=null)
	touch.desktop_overlay.hide()
	c.customers.spawn_customer()
	var family:Dictionary=c.customers.customers.back()
	family.family=true
	if family.node.has_node("Companion0"):
		var old=family.node.get_node("Companion0")
		family.node.remove_child(old)
		old.queue_free()
	family.companions=[6]
	c.customers.attach_companions(family)
	family.node.position=Vector3(-.6,0,-5.05)
	family.node.rotation.y=0
	family.state="service"
	family.patience=91.0
	var kid:Node3D=family.node.get_node("Companion0")
	var before:int=c.cases.size()
	for step in range(500):
		c.customers.update_children(family,.025)
	assert(family.children_played and c.cases.size()>before and c.cases.size()<=before+2)
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

	print("TOUCH070_OK: inventory, unlock, inspection, scan, cash, handoff, save snapshot, lobby discovery and invite")
	quit()





