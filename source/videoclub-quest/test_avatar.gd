extends SceneTree

func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.clerk.customers.set_physics_process(false)
	var clerk=game.clerk
	clerk.set_physics_process(false)
	clerk.customers.spawn_customer()
	clerk.active=clerk.customers.customers[0]
	clerk.active.id=42
	clerk.active.items=[]
	clerk.active.missing=[]
	clerk.price=450
	clerk.tender=500
	clerk.tender_parts=[500]
	clerk.refresh_tender_visual()
	clerk.lan.toggle_host()
	assert(clerk.lan.server!=null)
	var stream:=StreamPeerTCP.new()
	assert(stream.connect_to_host("127.0.0.1",39165)==OK)
	for i in range(60):
		await process_frame
		stream.poll()
		if stream.get_status()==StreamPeerTCP.STATUS_CONNECTED:break
	assert(stream.get_status()==StreamPeerTCP.STATUS_CONNECTED)
	var base={"v":1,"pin":clerk.lan.pin}
	var legacy:=await exchange(stream,base)
	assert(legacy.has("pages") and not legacy.has("checkout"))
	await create_timer(.12).timeout
	base.features=["checkout"]
	base.customer=42
	base.clerk_model=1
	base.pose=[[2.0,1.6,-3.0,.3,.4,.5]]
	var view:=await exchange(stream,base)
	assert(view.checkout.customer==42 and view.pose.size()==1)
	assert(clerk.lan.remote_avatar.model_choice==1 and clerk.lan.remote_avatar.skeleton.get_bone_count()>=15)
	assert(clerk.lan.remote_avatar.anchors[0].global_position.is_equal_approx(Vector3(2,1.6,-3)))
	base.action="cash_deposit"
	var payment:=await exchange(stream,base)
	assert(payment.checkout.received and not payment.checkout.paid)
	base.action="cash_change"
	base.coins={"25":2}
	var before:int=clerk.till[25]
	var payout:=await exchange(stream,base)
	assert(payout.checkout.paid and clerk.paid and clerk.till[25]==before-2)
	var phone=game.touch_controls.coop_panel
	phone.receive({"v":1,"checkout":payout.checkout,"pose":[[0,1.7,0,.2,.3,.4],[1,1.2,0,.3,.4,.5],[-1,1.4,0,.4,.5,.6]]})
	assert(phone.connected and phone.avatar.anchors[2].visible)
	assert(phone.avatar.anchors[1].global_position.is_equal_approx(Vector3(1,1.2,0)))
	assert(phone.avatar.anchors[1].global_basis.is_equal_approx(Basis.from_euler(Vector3(.3,.4,.5))))
	await create_timer(.25).timeout
	assert(phone.avatar.body.visible and phone.avatar.skeleton!=null)
	assert(phone.avatar.skeleton.get_bone_global_pose_override(phone.avatar.skeleton.find_bone("CaseHand")).origin.length()>.1)
	print("AVATAR_OK: legacy protocol, live pose, cash deposit, change, and three VR transforms")
	quit()

func exchange(stream:StreamPeerTCP,message:Dictionary)->Dictionary:
	stream.put_data((JSON.stringify(message)+"\n").to_utf8_buffer())
	var bytes:=PackedByteArray()
	for i in range(250):
		await process_frame
		stream.poll()
		var available:=stream.get_available_bytes()
		if available==0:continue
		var packet:=stream.get_partial_data(available)
		if packet[0]!=OK:break
		bytes.append_array(packet[1])
		var end:=bytes.find(10)
		if end>=0:
			return JSON.parse_string(bytes.slice(0,end).get_string_from_utf8())
	return {}


