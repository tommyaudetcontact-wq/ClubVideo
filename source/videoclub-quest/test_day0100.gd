extends SceneTree
var g
var c
func rental()->Dictionary:
	c.customer_delay=0
	c.customers.spawn_customer()
	var shopper:Dictionary=c.customers.customers.back()
	c.max_basket=1
	c.select_film(shopper)
	shopper.node.position=Vector3(-.6,0,-5.05)
	c.customer_ready(shopper)
	return shopper
func paid_tender():
	c.tender=1000
	c.tender_parts=[1000]
	c.refresh_tender_visual()
	c.wallet.take(0,1000,true)
	c.drawer_open=true
	while c.wallet.occupied(0):c.wallet.remove_one(0,0,true)
func give_amount(amount:int):
	for value in [2000,1000,500,200,100,25,10,5,1]:
		while amount>=value:
			c.wallet.take(0,value)
			amount-=value
	assert(c.wallet.give_customer(0))
func remove_shopper(shopper:Dictionary):
	c.customers.customers.erase(shopper)
	shopper.node.queue_free()
func _initialize():
	await process_frame
	g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	c=g.clerk
	c.set_physics_process(false)
	c.customers.set_physics_process(false)
	load("res://clerk_inventory.gd").mix_records(g.dvd_records,0)
	assert(c.shift.target_customers==4)
	c.shift.started=true
	for i in range(4):
		c.customers.spawn_customer()
		var visitor:Dictionary=c.customers.customers.back()
		assert(visitor.selection_left>=30 and visitor.selection_left<=180)
		assert(visitor.patience_limit>=120 and visitor.patience_limit<=180)
	assert(not c.shift.can_spawn() and c.shift.arrived_customers==4)
	c.shift.tick(9999)
	assert(not c.shift.closing)
	for visitor in c.customers.customers:visitor.node.queue_free()
	c.customers.customers.clear()
	var record:Dictionary=c.reserve_stock(0)
	c.returns_due=[{"movie":0,"record":record,"time":180}]
	c.shift.tick(1)
	assert(not c.shift.closing)
	c.elapsed=180
	c.customers.spawn_timer=999
	c.customers._physics_process(.01)
	assert(c.customers.customers.size()==1 and not c.customers.customers[0].return_job.is_empty() and c.shift.arrived_customers==4)
	c.customers.customers[0].node.queue_free()
	c.customers.customers.clear()
	c.returns_due.clear()
	c.restore_stock(record)
	c.shift.tick(1)
	assert(c.shift.closing and c.shift.finish())
	c.shift.next_day()
	assert(c.shift.day==2 and c.shift.target_customers in [5,6] and c.shift.arrived_customers==0)
	# Handing over the film cannot erase a customer's outstanding change.
	var shopper:Dictionary=rental()
	var item:Dictionary=shopper.items[0]
	assert(c.scan_item(item))
	paid_tender()
	var due:int=c.tender-c.price
	assert(due>0 and not c.paid)
	assert(c.handoff_item(item) and c.active==shopper and shopper.await_cash and shopper.state!="exit")
	assert(c.returns_due.back().time>c.elapsed+240)
	give_amount(due)
	assert(c.active.is_empty() and shopper.state=="exit")
	assert(c.returns_due.back().time>=c.elapsed+120 and c.returns_due.back().time<=c.elapsed+240)
	remove_shopper(shopper)
	# An uncollected offer is reclaimed by its owner, never left orphaned.
	shopper=rental()
	item=shopper.items[0]
	c.scan_item(item)
	c.handoff_item(item)
	assert(c.active.is_empty() and c.tender_parts.is_empty())
	remove_shopper(shopper)
	# A customer abandoning a paid basket waits for all original money back.
	shopper=rental()
	item=shopper.items[0]
	c.scan_item(item)
	paid_tender()
	c.pick_case(item,1,false)
	c.abandon_customer(shopper)
	assert(c.active==shopper and shopper.await_cash and item.node.get_meta("antitheft",false))
	give_amount(1000)
	assert(c.active.is_empty() and shopper.state=="exit")
	remove_shopper(shopper)
	# Returning the customer's original note directly is also supported.
	shopper=rental()
	item=shopper.items[0]
	c.scan_item(item)
	c.tender=1000
	c.tender_parts=[1000]
	c.refresh_tender_visual()
	c.wallet.take(0,1000,true)
	c.handoff_item(item)
	assert(c.active==shopper and c.wallet.can_return_tender(0))
	assert(c.wallet.give_customer(0) and c.active.is_empty())
	remove_shopper(shopper)
	# Whole-shape safety and recovery preserve a dropped note's identity/value.
	c.drawer_open=true
	c.tender_received=true
	c.wallet.take(0,500)
	var note:Dictionary=c.wallet.palms[0][0]
	load("res://club_surface_drop.gd").drop_cash(c.wallet,c.wallet.palms[0],Vector3(.12,1.375,-6.085))
	assert(note in c.wallet.loose and c.wallet.palms[0].is_empty())
	await physics_frame
	assert(load("res://club_drop_safety.gd").clear_at(note.body,note.body.global_transform))
	note.body.freeze=true
	note.body.global_position.y=-2
	c.wallet.recover_cash()
	assert(note.body.global_position.y>0 and note.value==500)
	assert(c.wallet.pick_loose(0,note) and c.wallet.total(0)==500)
	load("res://club_surface_drop.gd").drop_cash(c.wallet,c.wallet.palms[0],Vector3.INF)
	assert(c.wallet.occupied(0) and note not in c.wallet.loose)
	c.wallet.remove_one(0,0,true)
	# The same refund contract is enforced by the authoritative guest handler.
	shopper=rental()
	item=shopper.items[0]
	c.scan_item(item)
	c.tender=1000
	c.tender_parts=[]
	c.lan.add_guest_money(1000,true,shopper.id)
	c.handoff_item(item)
	assert(c.active==shopper and shopper.await_cash)
	c.lan.remote_avatar=load("res://club_peer_pose.gd").new()
	g.add_child(c.lan.remote_avatar)
	c.lan.remote_avatar.valid_pose=true
	c.lan.remote_avatar.targets[0]=Transform3D(Basis.IDENTITY,c.customer_hand()+Vector3(0,.25,.3))
	assert(c.lan.guest_money("cash_give",{"customer":shopper.id})=="")
	assert(c.active.is_empty() and c.lan.guest_cash.is_empty())
	remove_shopper(shopper)
	c.lan.add_guest_money(25,false,-1)
	var selected:Dictionary=c.lan.guest_cash[0]
	assert(c.lan.drop_guest_on_surface({"target":JSON.stringify([.12,1.375,-6.085]),"case":str(selected.node.get_instance_id())}).begins_with("Objet"))
	assert(c.lan.guest_cash.is_empty() and selected in c.wallet.loose and selected.value==25)
	print("DAY0100_OK: finite daily quotas + growth, browsing/patience ranges, close waits for returns, departure waits for change/refund, direct tender return, solid cash drops and recovery")
	quit()
