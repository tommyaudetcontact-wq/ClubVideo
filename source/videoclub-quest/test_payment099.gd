extends SceneTree
func _initialize():
	await process_frame
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	var c=g.clerk
	c.set_physics_process(false)
	c.customers.set_physics_process(false)
	c.customers.spawn_customer()
	var shopper:Dictionary=c.customers.customers[0]
	c.max_basket=2
	c.select_film(shopper)
	if shopper.reservations.size()==1:
		var extra:Dictionary=c.reserve_stock((shopper.movie+1)%g.layout.movies.size())
		shopper.reservations.append(extra)
		shopper.rental_count=2
		shopper.rental_remaining=2
	c.customer_ready(shopper)
	assert(c.tender==0 and c.tender_parts.is_empty() and not c.tender_note.visible)
	var pricing=load("res://rental_pricing.gd")
	var expected:int=pricing.quote(g.layout.movies,shopper.price_titles).total+int(shopper.account_due)
	assert(c.scan_item(shopper.items[0]))
	assert(c.tender>=expected and c.tender_note.visible and not shopper.items[1].scanned)
	var offer:int=c.tender
	var parts:Array=c.tender_parts.duplicate()
	assert(c.scan_item(shopper.items[1]))
	assert(c.tender==offer and c.tender_parts==parts)
	var twenty:=false
	var four_toonies:=false
	var exact:=false
	var combinations:Dictionary={}
	for i in range(2000):
		var payment:Array=pricing.payment(625)
		var sum:int=0
		for piece in payment:
			assert(piece in [2000,1000,500,200,100,25,10,5,1])
			sum+=piece
		assert(sum>=625 and sum<=2000 and payment.size()<=16)
		twenty=twenty or payment==[2000]
		four_toonies=four_toonies or payment==[200,200,200,200]
		exact=exact or sum==625
		combinations[str(payment)]=true
	assert(twenty and four_toonies and exact and combinations.size()>=6)
	for amount in [1,99,275,625,1200,1525,2045,5000]:
		for i in range(100):
			var total:int=pricing.payment(amount).reduce(func(sum,piece):return sum+piece,0)
			assert(total>=amount)
	preload("res://quest_image_quality.gd").apply(root,null)
	assert(root.scaling_3d_scale==1.0 and root.msaa_3d==Viewport.MSAA_4X and not root.use_taa and is_equal_approx(root.texture_mipmap_bias,-.35))
	var covers=load("res://cover_textures.gd")
	for id in g.held_pool:
		for side in ["front","back","spine"]:
			var path:String="res://assets/covers/%02d-%s.jpg"%[id,side]
			var original:Texture2D=load(path)
			var actual:Texture2D=g.held_pool[id].get_node("PaperInsert_"+side).material_override.albedo_texture
			assert(actual.get_size()==original.get_size() and actual.get_image().get_format()==Image.FORMAT_RGBA8)
	print("PAYMENT099_OK: cash appears at first scan for whole basket; stable offer; twenty-dollar, four-toonie and exact varieties; full-resolution held faces; XR quality guard")
	quit()
