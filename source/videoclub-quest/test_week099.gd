extends SceneTree
func _initialize():
	await process_frame
	var g=load("res://main.tscn").instantiate()
	g.touch_profile=true
	root.add_child(g)
	g.set_physics_process(false)
	var c=g.clerk
	c.set_physics_process(false)
	c.customers.set_physics_process(false)
	c.shift.started=true
	c.customers.spawn_customer()
	var shopper:Dictionary=c.customers.customers[0]
	assert(shopper.patience_limit in [60.0,120.0,180.0])
	c.max_basket=1
	c.select_film(shopper)
	c.customers.join_queue(shopper)
	shopper.patience=.1
	c.customer_ready(shopper)
	assert(shopper.patience==.1)
	var item:Dictionary=shopper.items[0]
	c.pick_case(item,0,false)
	c.locks.set_locked(item.node,false)
	c.customers._physics_process(.2)
	assert(shopper.state=="exit" and c.active.is_empty() and c.shift.abandoned==1 and c.shift.lost_sales>0)
	assert(item.node.get_meta("antitheft",false) and g.held==null)
	await create_timer(.8).timeout
	assert(item.node.global_position.distance_to(c.return_bin)<.5)
	var packed:Dictionary=g.session.snapshot()
	assert(packed.clients[0].patience_limit==shopper.patience_limit and packed.shift.has("week_losses"))
	c.customers.customers.clear()
	shopper.node.queue_free()
	c.cases.clear()
	item.node.queue_free()
	c.tasks.clear()
	c.shift.lost_sales=0
	c.shift.abandoned=0
	c.shift.day=1
	for day in range(1,6):
		assert(c.shift.day==day and c.shift.weekday()==c.shift.WEEKDAYS[day-1])
		c.shift.time_left=360
		c.shift.tick(360)
		assert(c.shift.closing and c.shift.finish())
		if day<5:c.shift.next_day()
	assert(c.shift.week_perfect and c.shift.report.contains("PARFAITE"))
	c.shift.next_day()
	assert(c.shift.weekday()=="LUNDI" and c.shift.week_number()==2 and c.shift.week_losses==0)
	c.shift.day=10
	c.shift.closing=true
	c.shift.lost_sales=100
	assert(c.shift.finish() and not c.shift.week_perfect)
	c.shift.next_day()
	c.shift.day=15
	c.shift.closing=true
	var work=c.new_case(1,Vector3(1.75,1.2,-5.92),"sorting")
	work.node.set_meta("in_sort_tray",true)
	work.node.set_meta("dirty",true)
	assert(c.shift.finish() and not c.shift.week_perfect and c.shift.remaining_scratches()>0)
	print("WEEK099_OK: no timer reset, locked abandoned held case reaches chute, loss counted, saved patience/week fields, Monday-Friday progression, perfect-week reward and failed-week checks")
	quit()
