extends SceneTree

func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	game.touch_profile=true
	root.add_child(game)
	game.set_physics_process(false)
	var clerk=game.clerk
	clerk.set_physics_process(false)
	clerk.customers.set_physics_process(false)
	var a:Dictionary=clerk.reserve_stock(0)
	var b:Dictionary=clerk.reserve_stock(1)
	var unrelated:Dictionary=game.dvd_records[100]
	var ua:int=a.disc_uid
	var ub:int=b.disc_uid
	var original:int=unrelated.disc_uid
	clerk.elapsed=100
	var account:int=clerk.accounts.create_account()
	clerk.returns_due=[{"movie":a.movie,"record":a,"batch":42,"account_id":account,"time":160.0,"refund":0},{"movie":b.movie,"record":b,"batch":42,"account_id":account,"time":160.0,"refund":0}]
	# Force the uncommon branch, while preserving every real disc identity.
	clerk.finalize_return_batch(42,1.0)
	assert(a.disc_uid==ub and b.disc_uid==ua and unrelated.disc_uid==original)
	var due:float=clerk.returns_due[0].time
	assert(due>=400 and due<=700 and clerk.returns_due[1].time==due)
	assert(clerk.take_due_return().is_empty())
	clerk.elapsed=due-.01
	assert(clerk.take_due_return().is_empty())
	clerk.elapsed=due
	var job:Dictionary=clerk.take_due_return()
	assert(job.others.size()==1 and clerk.returns_due.is_empty())
	var packed:Dictionary=game.session.pack_job(job)
	var restored:Dictionary=game.session.unpack_job(packed)
	assert(restored.others.size()==1 and restored.others[0].record==b)
	clerk.customers.spawn_customer()
	var customer:Dictionary=clerk.customers.customers[0]
	customer.return_job=job
	customer.return_and_rent=false
	customer.state="return_drop"
	customer.path=PackedVector2Array()
	customer.cursor=0
	clerk.customers._physics_process(.01)
	assert(clerk.shift.returned==2 and clerk.cases.size()==2 and customer.state=="exit")
	assert(clerk.accounts.ensure(account).balance==0)
	clerk.returns_due=[{"movie":a.movie,"record":a,"batch":43,"account_id":account,"time":0.0,"refund":0}]
	var single_uid:int=a.disc_uid
	clerk.finalize_return_batch(43,1.0)
	assert(a.disc_uid==single_uid)
	var icon:Node3D=Node3D.new()
	root.add_child(icon)
	load("res://club_visit_icons.gd").update(icon,2,2)
	assert(icon.get_meta("visit_icon_count")==2)
	var found:=false
	for child in icon.get_node("VisitIcons").get_children():
		if child is Label3D and child.text=="×2":found=true
	assert(found)
	assert(game.touch_controls.cash_total.get_theme_color("font_color")==Color.WHITE)
	assert(game.touch_controls.cash_total.get_theme_font_size("font_size")>=30)
	print("RETURNS095_OK: 5–10 minute delay, same-rental-only mixing, grouped chute returns, saved bundles, single-disc protection, count icon, readable cash")
	quit(0)
