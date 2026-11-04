extends SceneTree
var failures=0
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _initialize():
	await process_frame
	root.size=Vector2i(1600,1000)
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	var c=g.clerk
	c.set_physics_process(false)
	c.customers.set_physics_process(false)
	c.shift.enabled=false
	# Ten percent of the whole stock, uniformly selected, identity conserved.
	var sample=[]
	for i in range(1000):sample.append({"id":i,"movie":i/100})
	var counts=PackedInt32Array()
	counts.resize(10)
	var valid=true
	for seed_value in range(30):
		seed(seed_value)
		var mixed=load("res://clerk_inventory.gd").mix_records(sample,.10)
		var ids={}
		var actual=0
		for r in sample:
			ids[r.disc_uid]=true
			if r.disc_movie!=r.movie:
				actual+=1
				counts[r.movie]+=1
		valid=valid and mixed==100 and actual==100 and ids.size()==1000
	check(valid,"Exactly ten percent mismatched, with all unique discs conserved across 30 seeds")
	check(counts[0]<400 and counts[9]>200,"Random mismatch selection has no first-title catalogue bias")
	load("res://clerk_inventory.gd").mix_records(g.dvd_records,0)
	c.max_basket=3
	c.customers.spawn_customer()
	var client=c.customers.customers[0]
	client.movie=0
	c.select_film(client)
	client.node.position=Vector3(-.6,0,-5.05)
	client.state="service"
	c.customer_ready(client)
	while c.active.items.size()<3:c.add_basket_case(c.reserve_stock(c.active.items.size()))
	var first=c.active.items[0]
	var second=c.active.items[1]
	check(absf(first.node.position.x-second.node.position.x)<.001 and second.node.position.y>first.node.position.y,"Customer places a vertical stack clear of the register")
	check(c.tender_note.position.distance_to(first.node.position)>.5,"Cash is separate, within reach beside the monitor")
	c.pick_case(first,0,true)
	g.hands[1].global_position=second.node.global_position
	c.interact(1,true)
	check(g.held==second.node and c.secondary.node==first.node,"Physical interaction takes a second customer case into the free hand")
	second.node.global_position=Vector3(1.75,1.2,-5.92)
	c.release()
	check(g.held==first.node and second.node.get_meta("in_sort_tray",false),"One case can be put aside without dropping the other")
	first.node.set_meta("antitheft",false)
	first.node.get_node("Antitheft").queue_free()
	c.inspection.toggle_case()
	check(c.inspection.opened and c.inspection.opening_amount==0 and c.inspection.lid.rotation.y==0,"Opening initializes a closed hinge without automatic travel")
	c.inspection.lid_hand=1
	c.inspection.hand_start_angle=0
	c.inspection.lid_start_angle=0
	c.inspection.update_lid(c.inspection.case_node.to_global(c.inspection.lid.position+Vector3(cos(1.8)*.13,0,sin(1.8)*.13)))
	check(c.inspection.lid_hand==1 and absf(c.inspection.lid.rotation.y+1.8)<.01,"Midway gesture retains physical hinge angle rather than snapping fully open")
	# Detect wrong label and create a replacement request without scanner or forced extraction.
	first.node.set_meta("disc_movie",5)
	first.record.disc_movie=5
	c.inspection.label_seen=true
	c.inspection.close_case()
	check(first.kind=="sorting" and c.active.missing.has(first.movie) and c.active.patience_bonus==30,"Visible wrong disc can be set aside with a single 30-second patience bonus")
	c.flag_wrong_case(first)
	check(c.active.patience_bonus==30,"Repeated handling cannot farm patience bonuses")
	first.node.global_position=Vector3(1.75,1.2,-5.92)
	c.release()
	check(g.held==null and first.node.freeze,"Wrong case deposits in nearby sorting tray without scanner")
	# Basket mechanics preserve the same instance and inventory copy.
	c.pick_case(second,0,true)
	second.node.global_position=c.basket.body.to_global(Vector3(0,.22,0))
	c.release()
	check(g.held==null and c.basket.items.has(second) and second.node.get_meta("in_basket",false),"Released case enters basket with its original inventory identity")
	g.hands[0].global_position=c.basket.body.to_global(Vector3(0,.39,0))
	c.basket.interact(0,true)
	check(c.basket.hand==0 and c.basket.body.get_parent()==g.hands[0],"Basket handle is physically held by one hand")
	var saved=g.session.snapshot()
	check(saved.cases.filter(func(i):return i.meta.in_basket).size()==1 and saved.has("basket_transform"),"Basket contents and safe held-basket placement are checkpointed")
	g.hands[1].global_position=second.node.global_position
	c.basket.interact(1,true)
	check(g.held==second.node and g.held_hand==1 and c.basket.hand==0 and c.basket.items.is_empty(),"Other hand retrieves one case while the first keeps holding the basket")
	c.basket.release(0)
	check(c.basket.hand==-1 and not c.basket.body.freeze,"Releasing basket resumes its physics")
	check(not c.repairs.marker.material_override.no_depth_test,"Green shelf marker respects opaque shelf and wall depth")
	g.head.global_position=Vector3(-.6,1.6,-7.0)
	c.customers.update_service_visual(client,1)
	var direction:Vector3=(g.head.global_position-client.node.global_position).normalized()
	check((-client.node.global_basis.z).dot(Vector3(direction.x,0,direction.z).normalized())>.99,"Served customer faces cashier")
	check(client.node.get_node("Patience").visible,"Customer patience bar is visible above their head")
	# Closing requires real cleanup, but unresolved mixed cases can remain for tomorrow.
	c.active={}
	c.waiting.clear()
	client.state="exit"
	c.shift.closing=true
	second.kind="return"
	check(not c.shift.finish(),"Closing refuses unfinished returns")
	for item in c.cases:item.kind="sorting"
	check(c.shift.finish(),"Closing permits unresolved sorting after returns are cleared")
	c.shift.summary=false
	c.active=client
	c.refresh_terminal()
	g.hud.visible=false
	g.origin.transform=Transform3D.IDENTITY
	g.head.position=Vector3(.12,1.65,-7.05)
	g.head.look_at(Vector3(.0,1.30,-6.10))
	c.basket.body.freeze=true
	c.basket.body.global_transform=Transform3D(Basis.IDENTITY,c.basket.home)
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../checkout-060-preview.png")
	var restored_game=load("res://main.tscn").instantiate()
	root.add_child(restored_game)
	restored_game.clerk.set_physics_process(false)
	restored_game.clerk.customers.set_physics_process(false)
	var restored=restored_game.session.restore(saved)
	check(restored and restored_game.clerk.basket.items.size()==1,"Saved basket restores its actual case without duplication")
	check(restored_game.clerk.basket.items[0].record.id==second.record.id and restored_game.clerk.active.patience_bonus==30,"Basket inventory identity and replacement patience persist across fresh scene")
	print("REVIEW060_TESTS failures=",failures)
	quit(1 if failures else 0)
