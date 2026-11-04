extends SceneTree
var failures=0
const Pricing=preload("res://rental_pricing.gd")
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
	c.max_basket=1
	load("res://clerk_inventory.gd").mix_records(g.dvd_records,0)
	var classics=[]
	for movie in g.layout.movies:
		if Pricing.unit(movie)==275:classics.append(movie.id)
	var quote=Pricing.quote(g.layout.movies,classics.slice(0,3))
	check(quote.total==500 and quote.discount==325,"Three distinct classics receive the five-dollar bundle")
	check(Pricing.unit(g.layout.movies[0])==375 and Pricing.unit(g.layout.movies[24])!=375,"Film and game rental categories have distinct stable prices")
	var logical=true
	var saw_exact=false
	for amount in [200,275,375,500,595,825,1125,1785]:
		for i in range(80):
			var parts=Pricing.payment(amount)
			var total=0
			for value in parts:total+=value
			logical=logical and total>=amount
			if parts.all(func(value):return value==200):logical=logical and total-amount<200
			if total==amount:saw_exact=true
	check(logical and saw_exact,"Cash offers cover total and coin-only offers never grossly overpay")
	# Every case's corners remain inside the basket, including the largest game case.
	var contained=true
	for i in range(12):
		var record=c.reserve_stock(i+24)
		var item=c.new_case(record.movie,c.basket.body.to_global(Vector3(0,.2,0)),"shelve")
		item.record=record
		load("res://clerk_inventory.gd").bind(item.node,record)
		c.basket.store(item)
	for item in c.basket.items:
		var h=float(g.layout.movies[item.movie].get("caseHeight",.19))
		for x in [-.0675,.0675]:
			for y in [-h/2,h/2]:
				for z in [-.007,.007]:
					var corner=c.basket.body.to_local(item.node.to_global(Vector3(x,y,z)))
					contained=contained and absf(corner.x)<.19 and absf(corner.z)<.14 and corner.y>.012 and corner.y<.245
	check(contained and c.basket.items.size()==12,"Twelve real-size cases fit in one aligned row entirely within basket walls")
	var a=c.basket.items[0]
	g.hands[0].global_position=a.node.global_position
	c.basket.interact(0,true)
	var b=c.basket.items[-1]
	g.hands[1].global_position=b.node.global_position
	c.basket.interact(1,true)
	check(not c.secondary.is_empty() and g.held_hand==1 and c.secondary_hand==0,"Two hands retrieve two individual cases from resting basket")
	g.held.global_position=Vector3(0,1,-8)
	var secondary_basis=Basis.looking_at(-c.scanner.direction,Vector3.UP)
	a.node.global_transform=Transform3D(secondary_basis,c.scanner.global_position+c.scanner.direction*.23-secondary_basis*Vector3(0,-.045,-.008))
	c.scanner.tick(.02)
	check(g.held==a.node and g.held_hand==0 and c.secondary.node==b.node and a.node.get_meta("barcode_scanned",false),"Either hand can pass its case through the scanner while retaining the other case")
	g.held.global_position=c.basket.body.to_global(Vector3(0,.2,0))
	c.release()
	g.held.global_position=c.basket.body.to_global(Vector3(0,.2,0))
	c.release()
	check(c.basket.items.size()==12 and not g.held,"Both held copies can return to basket without duplication")
	# Scanner must read the rear in its red fan; simple proximity is insufficient.
	var record=c.reserve_stock(0)
	var returned=c.deliver_return({"movie":0,"record":record})
	returned.node.set_meta("dirty",false)
	record.dirty=false
	c.pick_case(returned,0,true)
	var basis=Basis.looking_at(-c.scanner.direction,Vector3.UP)
	g.held.global_transform=Transform3D(basis,c.scanner.global_position+c.scanner.direction*.23-basis*Vector3(0,-.045,-.008))
	check(c.scanner.intersects_case(g.held),"Rear barcode area intersects physical scanner fan")
	g.held.rotate_y(PI)
	check(not c.scanner.intersects_case(g.held),"Scanner rejects front-facing cover")
	g.held.global_transform=Transform3D(basis,c.scanner.global_position+c.scanner.direction*.23-basis*Vector3(0,-.045,-.008))
	c.scanner.tick(.02)
	check(g.held.get_meta("barcode_scanned",false) and not returned.scanned and c.scanner.flash>0,"Beam registers case and beeps before separate disc inspection")
	g.held.set_meta("inspected",true)
	c.inspection.close_case()
	check(returned.scanned,"Previously scanned return validates after disc inspection")
	g.held.global_position=record.world.origin
	c.release()
	check(g.held==returned.node and record.clerk_reserved,"Returned copy cannot restock without yellow bar")
	g.hands[1].global_position=c.lock_bin
	c.lock_input(1)
	g.hands[1].global_position=g.held.to_global(Vector3(.061,-.09,0))
	c.lock_input(1)
	check(g.held.get_meta("antitheft",false),"Clean inspected return accepts a reusable security bar")
	g.held.global_position=record.world.origin
	c.release()
	check(not record.clerk_reserved and not g.held,"Relocked return restores exactly its original stock slot")
	# Reachable aisle targets span the physical store, not just a fixed location.
	var zones={}
	var reachable=0
	for i in range(0,g.dvd_records.size(),65):
		var point=c.customers.aisle_for(g.dvd_records[i].world.origin)
		zones[Vector2i(roundi(point.x),roundi(point.z))]=true
		var start=Vector2i(-16,18)
		var target=Vector2i(roundi(point.x*4),roundi(point.z*4))
		if not c.customers.grid.get_point_path(start,target).is_empty():reachable+=1
	check(zones.size()>12 and reachable>20,"Browsing targets span many reachable shelves throughout the store")
	c.customers.spawn_customer()
	var dropper=c.customers.customers[0]
	dropper.return_job={"movie":2,"record":c.reserve_stock(2)}
	dropper.state="return_drop"
	dropper.return_and_rent=false
	dropper.path=PackedVector2Array()
	dropper.cursor=0
	c.customers._physics_process(.01)
	check(dropper.state=="exit" and c.waiting.is_empty() and c.active.is_empty(),"Return-only visitor uses chute and leaves without joining checkout")
	# Return-and-rent visitor first hands the real old copy to the cashier.
	c.customers.spawn_customer()
	var renter=c.customers.customers[-1]
	renter.return_job={"movie":3,"record":c.reserve_stock(3)}
	renter.state="return_counter"
	renter.return_and_rent=true
	renter.path=PackedVector2Array()
	renter.cursor=0
	c.customers._physics_process(.01)
	check(renter.return_item.node.position.distance_to(Vector3(-.83,1.14,-5.85))<.01,"Return-and-rent visitor places old case at checkout")
	c.customers._physics_process(.01)
	check(c.active==renter and c.active.is_return,"Return is handled before choosing the next rentals")
	c.price=0
	c.paid=true
	renter.return_item.scanned=true
	c.refresh_basket()
	c.action("computer",0)
	check(renter.state=="browse" and not renter.is_return and renter.reservations.size()>0 and c.active.is_empty(),"Same visitor continues shopping after return completion")
	var previous_duration=c.shift.duration
	c.shift.next_day()
	c.shift.next_day()
	check(c.shift.duration==600 and c.shift.day==3,"Difficulty increases without lengthening ten-minute days")
	# A messy customer really drops a nearby physical copy where they browsed.
	renter.node.position=c.customers.aisle_for(g.dvd_records[100].world.origin)
	var before=c.cases.size()
	c.make_mess(renter)
	check(c.cases.size()==before+1,"Messy visitor picks a real nearby shelf copy")
	var dropped=c.cases[-1]
	await create_timer(1.1).timeout
	check(not dropped.node.freeze and dropped.node.collision_layer==8 and dropped.node.position.y<.9,"Abandoned film falls under physics in the visited aisle")
	# A replacement after taking cash must never recreate the original banknote.
	var old_active=c.active
	c.active={"id":renter.id,"node":renter.node,"items":[],"missing":[1],"price_titles":[1],"cash_started":true,"is_return":false}
	c.price=275
	c.tender=500
	c.tender_parts=[]
	c.tender_deposited=0
	c.paid=false
	c.change=0
	c.replace_requested_title(1,c.reserve_stock(0))
	check(c.price==375 and c.tender==500 and c.tender_parts.is_empty(),"Alternative film updates price without duplicating money already taken")
	c.active=old_active
	var state=g.session.snapshot()
	check(state.cases.filter(func(item):return item.meta.in_basket).size()==12,"Aligned basket contents remain represented in save")
	g.hud.visible=false
	g.origin.transform=Transform3D.IDENTITY
	g.head.position=Vector3(.6,2.3,-7.2)
	g.head.look_at(Vector3(-.5,1.3,-6.0))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../checkout-061-preview.png")
	g.head.position=c.basket.body.global_position+Vector3(.5,.7,-.6)
	g.head.look_at(c.basket.body.global_position+Vector3(0,.12,0))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../basket-061-preview.png")
	print("REVIEW061_TESTS failures=",failures)
	quit(1 if failures else 0)
