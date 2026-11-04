extends SceneTree
var failures=0
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _initialize():
	await process_frame
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	var c=g.clerk
	c.set_physics_process(false)
	c.customers.set_physics_process(false)
	c.shift.enabled=false
	load("res://clerk_inventory.gd").mix_records(g.dvd_records,0)
	check(c.terminal.get_child(0).color==Color.BLACK,"Checkout display uses a black background")
	check(g.teleportation.valid_destination(Vector3(0,0,-7.8)),"New work aisle is reachable by teleportation")
	check(not g._blocked(Vector3(0,0,-8)),"Old rear wall no longer blocks the work aisle")
	check(g._blocked(Vector3(0,0,-9.5)),"Expanded room still has a solid rear boundary")
	var node=load("res://clerk_props.gd").customer(c,10)
	node.position=Vector3(-.6,0,-5.05)
	c.active={"id":10,"node":node,"movie":0,"items":[],"missing":[],"handed":0,"state":"service","reservations":[]}
	for id in [0,1,2]:c.add_basket_case(c.reserve_stock(id))
	c.price=375
	c.tender=1000
	c.tender_parts=[500,500]
	c.paid=false
	c.tender_received=false
	c.tender_deposited=0
	c.refresh_tender_visual()
	c.refresh_terminal()
	check(not c.terminal_text.text.contains("6.25") and not c.register_display.text.contains("6.25"),"Neither display reveals the calculated change")
	g.hands[1].global_position=c.tender_note.global_position
	c.wallet.interact(1,true)
	check(c.wallet.total(1)==1000,"Locked cases do not prevent taking all customer cash")
	while c.wallet.occupied(1):c.wallet.remove_one(1,0,true)
	var old_trailer=g.active_trailer
	c.pick_case(c.active.items[0],0,true)
	check(g.active_trailer==old_trailer,"Picking up a checkout case leaves ambient trailer unchanged")
	g.held.global_position=Vector3(2,1.3,-6.1)
	c.release()
	var abandoned=c.active.items.duplicate()
	c.abandon_customer(c.active)
	await create_timer(1).timeout
	var in_chute=true
	for item in abandoned:
		if item.node.global_position.distance_to(c.return_bin)>.50 or item.node.get_meta("antitheft",true):in_chute=false
	check(in_chute and c.active.is_empty(),"Abandoned basket goes into return chute without yellow locks")
	var returning=c.deliver_return({"movie":4,"record":c.reserve_stock(4)})
	returning.node.set_meta("dirty",true)
	c.waiting=[{"id":11,"node":node,"movie":4,"state":"service","is_return":true,"return_item":returning}]
	c.start_next()
	check(c.damage_alert.visible and c.damage_alert.get_theme_color("font_color").r>.9,"Damaged return displays a red unpaid-fee warning")
	c.paid=true
	c.refresh_terminal()
	check(not c.damage_alert.visible,"Damage-payment warning clears after payment")
	var disc=MeshInstance3D.new()
	disc.mesh=QuadMesh.new()
	c.inspection.add_child(disc)
	c.inspection.carried=disc
	c.inspection.carried_data={"movie":4,"uid":9876,"dirty":false,"inspected":true}
	c.inspection.finger=1
	check(c.repairs.place_disc(c.inspection,Vector3(1.5,1.1,-8.7)),"Loose disc can be placed at chosen tabletop position")
	check(c.inspection.finger==-1 and c.inspection.loose_discs[-1].data.uid==9876,"Sorting preserves the disc identity and frees the hand")
	g.hands[1].global_position+=disc.global_position-c.inspection.finger_transform(1).origin
	c.inspection.interact(1,false)
	check(c.inspection.carried==disc and c.inspection.carried_data.uid==9876,"Individual disc can be picked back up from sorting table")
	g.origin.transform=Transform3D.IDENTITY
	g.head.position=Vector3(.1,1.6,-6.2)
	g.head.look_at(Vector3(.12,1.35,-6.3))
	g.hud.visible=false
	c.paid=false
	c.refresh_terminal()
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../checkout-057-preview.png")
	print("REVIEW057_TESTS failures=",failures)
	quit(1 if failures else 0)
