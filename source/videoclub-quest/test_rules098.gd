extends SceneTree
var failures=0
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _initialize():
	await process_frame
	var g=load("res://main.tscn").instantiate()
	g.touch_profile=true
	root.add_child(g)
	g.set_physics_process(false)
	var c=g.clerk
	c.set_physics_process(false)
	c.customers.set_physics_process(false)
	load("res://clerk_inventory.gd").mix_records(g.dvd_records,0)
	c.max_basket=1
	var icons=load("res://club_visit_icons.gd")
	check(icons.reason_mask({"visit_mask":3,"return_job":{"refund":0},"return_and_rent":true,"rental_remaining":2})==3,"Return plus rental intentions are visible")
	check(icons.reason_mask({"visit_mask":3,"return_job":{},"rental_remaining":1})==2,"Completed return intention disappears")
	check(icons.reason_mask({"visit_mask":6,"rental_remaining":0,"state":"exit"})==0,"All intentions disappear on departure")
	for mode in range(3):
		c.customer_delay=0
		c.customers.spawn_customer()
		var customer:Dictionary=c.customers.customers.back()
		c.select_film(customer)
		c.customer_ready(customer)
		var item:Dictionary=customer.items[0]
		var amount:int=load("res://rental_pricing.gd").unit(g.layout.movies[item.movie])
		item.node.set_meta("antitheft",mode==2)
		item.node.set_meta("dirty",false)
		item.node.set_meta("disc_movie",item.movie)
		var before:int=c.shift.lost_sales
		if mode>0:
			c.pick_case(item,0,false)
			check(c.scan_held(),"Scan remains optional but functional")
		if mode==2:c.tender_deposited=c.price
		var expected_loss:int=amount if mode==0 else (c.price if mode==1 else 0)
		var batch:int=customer.id
		check(c.handoff_item(item),"Handoff allowed without required scan/payment/inspection/unlock, mode %d"%mode)
		check(c.active.is_empty() and customer.state=="exit","Customer leaves after handoff")
		check(customer.rental_remaining==0,"Remaining quantity reaches zero")
		check(c.shift.lost_sales-before==expected_loss,"Actual unpaid or unscanned loss is counted once")
		var job:Dictionary=c.returns_due.filter(func(j):return j.batch==batch)[0]
		check(job.time>=c.elapsed+120 and job.time<=c.elapsed+240,"Return scheduled two to four minutes later")
		check(job.refund==(amount if mode==2 else 0),"Refund follows actual payment and faulty lock")
		customer.node.queue_free()
		c.customers.customers.erase(customer)
	c.clear_hand()
	c.shift.started=true
	c.shift.time_left=360
	c.shift.tick(359.9)
	check(not c.shift.closing and c.shift.can_spawn(),"Day remains open before six minutes")
	c.shift.tick(.2)
	check(c.shift.closing and not c.shift.can_spawn(),"Six minutes stops new arrivals")
	var leftover=c.new_case(4,Vector3(1.75,1.2,-5.92),"sorting")
	leftover.node.set_meta("in_sort_tray",true)
	check(c.shift.finish(),"Separate sorting bin may stay until tomorrow")
	c.shift.next_day()
	check(c.shift.time_left==360 and not c.shift.closing and not c.shift.summary,"Next day resets to six minutes")
	c.shift.tick(360)
	leftover.node.set_meta("in_sort_tray",false)
	leftover.kind="return"
	check(not c.shift.finish(),"Uncleared return blocks complete closure")
	leftover.node.set_meta("in_sort_tray",true)
	c.drawer_open=true
	check(not c.shift.finish(),"Open till blocks closure")
	c.drawer_open=false
	check(c.shift.finish(),"Closure succeeds after remaining work")
	print("RULES098 failures=",failures)
	quit(1 if failures else 0)

