extends RefCounted
## Cartons remain physical containers until their individual copies are unpacked.
var b
var held_id:=-1
var held_hand:=-1
var guest_id:=-1
var signatures:Dictionary={}
func setup(business) -> void:b=business
func order_for(id:int) -> Dictionary:
	for order in b.state.orders:
		if int(order.id)==id:return order
	return {}
func free_item_hand() -> bool:
	if b.game.held:return false
	if b.is_remote_guest() and not b.game.touch_controls.coop_panel.guest_case_id.is_empty():return false
	return true
func hint() -> String:
	var order:=order_for(held_id)
	if order.get("kind","")=="shelf":return "Ouvrir le carton ici pour assembler"
	return "Sortir un film · déposer : bouton Déposer" if order.get("opened",false) else "Ouvrir le carton · déposer : bouton Déposer"
func use(id:int,hand:int) -> bool:
	var order:=order_for(id)
	if order.is_empty() or order.get("kind","") not in ["films","shelf","decoration"]:return false
	if b.is_remote_guest():
		return b.remote_command({"op":"carton_use","id":id})
	if order.kind!="films":
		b.open_parcel(id);return true
	if not order.get("opened",false):open_box(order)
	else:extract(order,hand)
	return true
func open_box(order:Dictionary) -> void:
	order.opened=true
	refresh(order)
	b.game._message("Carton ouvert : poignée près des boîtiers pour en sortir un. Poignée sur le côté pour transporter le carton.")
func refresh(order:Dictionary) -> void:
	var id:int=order.id
	if not b.packages.has(id) or order.kind!="films":return
	var signature:=[order.get("opened",false),order.contents.hash()]
	if signatures.get(id,[])==signature:return
	signatures[id]=signature
	var node:Node3D=b.packages[id]
	for child in node.get_children():node.remove_child(child);child.queue_free()
	var props=b.Props
	# Twenty DVD cases fit in two rows. The box is closed by two hinged flaps.
	props.box(node,Vector3(0,-.115,0),Vector3(.42,.02,.34),"a58155")
	for side in [-1,1]:
		props.box(node,Vector3(side*.205,0,0),Vector3(.01,.24,.34),"b18b5f")
		props.box(node,Vector3(0,0,side*.165),Vector3(.42,.24,.01),"b89265")
		var flap:MeshInstance3D=props.box(node,Vector3(0,.125,side*(.25 if order.get("opened",false) else .082)),Vector3(.42,.008,.164),"bd986c")
		if order.get("opened",false):flap.rotation.x=side*.48
	b.World.batch_props(node)
	if order.get("opened",false):
		for index in mini(20,order.contents.size()):
			var movie:int=order.contents[index]
			var dvd:=Node3D.new();node.add_child(dvd)
			dvd.position=Vector3(-.17+(index%10)*.037,0,-.075+int(index/10)*.15)
			dvd.rotation.y=PI/2
			# Reuse the exact held-case plastic shell, with economical printed faces.
			var body:=MeshInstance3D.new();body.mesh=load("res://held_case.gd").rounded_shell(.135,.19,.014)
			body.material_override=props.material("17191b");dvd.add_child(body)
			for side in [1,-1]:
				var cover:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.127,.181)
				cover.mesh=quad;cover.position=Vector3(0,0,side*.0072)
				if side<0:cover.rotation.y=PI
				var mat:=StandardMaterial3D.new()
				mat.albedo_texture=load(load("res://cover_textures.gd").path_for(b.game.layout.movies[movie],"front" if side>0 else "back"))
				mat.roughness=.45;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				cover.material_override=mat;dvd.add_child(cover)

	props.label(node,"%d / 20 FILMS"%order.contents.size(),Vector3(0,.035,.176),.0005,24)
func extract(order:Dictionary,hand:int,guest:bool=false) -> bool:
	if order.contents.is_empty():return false
	if (guest and not b.game.clerk.lan.guest_case.is_empty()) or (not guest and (b.game.held or b.game.clerk.secondary_hand==hand or b.game.clerk.wallet.occupied(hand))):
		b.game._message("Libère une main pour sortir un film.");return false
	var position:Vector3=b.packages[int(order.id)].global_position+Vector3(0,.3,.1)
	if guest and b.game.clerk.lan.remote_avatar.targets[0].origin.distance_to(position)>2.15:
		b.game._message("Approche-toi du carton pour prendre le film.");return false
	if not b.receive_film(int(order.contents[0]),position):
		b.game._message("Il manque une place en rayon. Le film reste dans le carton.");return false
	var item:Dictionary=b.game.clerk.cases.back()
	order.contents.pop_front()
	if guest:b.game.clerk.lan.pick_guest_case("case_pick",str(item.node.get_instance_id()))
	else:b.game.clerk.pick_case(item,hand,true)
	if order.contents.is_empty():
		if held_id==int(order.id):held_id=-1;held_hand=-1
		if guest_id==int(order.id):guest_id=-1
		b.consume_order(order)
	else:refresh(order)
	return true
func take(id:int,hand:int) -> bool:
	if held_id>=0 or guest_id==id or b.game.held_hand==hand or b.game.clerk.wallet.occupied(hand):return false
	if order_for(id).is_empty():return false
	held_id=id;held_hand=hand
	b.game._message("Carton en main : gâchette pour ouvrir. Poignée pour déposer.")
	return true
func interact(hand:int,grip:bool) -> bool:
	if b.is_remote_guest():return false
	if held_id>=0 and hand==held_hand:
		if grip:pass # A carton is released when the grip opens.
		else:use(held_id,1-hand)
		return true
	if not grip:return false
	var point:Vector3=b.game.hands[hand].global_position
	for id in b.packages:
		var order:=order_for(int(id))
		if order.is_empty() or order.kind not in ["films","shelf","decoration"] or guest_id==int(id):continue
		var local:Vector3=b.packages[id].to_local(point)
		if absf(local.x)<(.99 if order.kind=="shelf" else .31) and absf(local.z)<.29 and absf(local.y)<.30:
			if order.kind=="films" and order.get("opened",false) and absf(local.x)<.16 and absf(local.z)<.13 and local.y>.07:return extract(order,hand)
			return take(int(id),hand)
	return false
func safe_pose(ray:Node3D) -> Transform3D:
	var start:Vector3=ray.global_position;var direction:Vector3=-ray.global_basis.z
	var point:=Vector3(start.x,0,start.z)+direction*1.0
	point.y=0
	var best:=INF
	if direction.y<-.05:
		var distance:float=-start.y/direction.y
		if distance>0 and distance<3:point=start+direction*distance;best=distance
	for box in b.game.layout.colliders:
		var low:=Vector3(box.min[0],box.min[1],box.min[2]);var high:=Vector3(box.max[0],box.max[1],box.max[2])
		var bounds:=AABB(low,high-low)
		var hit:Variant=bounds.intersects_segment(start,start+direction*3)
		if hit!=null and start.distance_to(hit)<best:
			point=Vector3(hit.x,high.y,hit.z);best=start.distance_to(hit)
	point.x=clampf(point.x,-5.25,5.25);point.z=clampf(point.z,-13.9,6.2)
	# Lift above intersecting furniture instead of ever burying a parcel in it.
	for box in b.game.layout.colliders:
		if point.x+.24>box.min[0] and point.x-.24<box.max[0] and point.z+.20>box.min[2] and point.z-.20<box.max[2] and point.y<box.max[1]:point.y=box.max[1]
	point.y+=.135
	return Transform3D(Basis.IDENTITY,point)
func drop_from_hand() -> void:
	if held_id<0 or b.is_remote_guest():return
	var point:Vector3=b.packages[held_id].global_position
	var support:=0.0
	for box in b.game.layout.colliders:
		if point.x>box.min[0] and point.x<box.max[0] and point.z>box.min[2] and point.z<box.max[2] and box.max[1]<point.y+.1:support=maxf(support,float(box.max[1]))
	point.y=support+.135
	point.x=clampf(point.x,-5.3,5.3);point.z=clampf(point.z,-13.9,6.2)
	b.packages[held_id].global_transform=Transform3D(Basis(Vector3.UP,snappedf(b.packages[held_id].rotation.y,PI/4)),point)
	held_id=-1;held_hand=-1

func drop() -> void:
	if held_id<0:return
	if b.is_remote_guest():
		var pose:=safe_pose(b.game.aim_hands[1]);b.remote_command({"op":"carton_drop","id":held_id,"point":[pose.origin.x,pose.origin.y,pose.origin.z]})
	else:
		b.packages[held_id].global_transform=safe_pose(b.game.aim_hands[held_hand])
		held_id=-1;held_hand=-1
func store_poses() -> void:
	for order in b.state.orders:
		if b.packages.has(int(order.id)):
			order.pose=b.packages[int(order.id)].transform
			if int(order.id) in [held_id,guest_id]:
				var point:Vector3=order.pose.origin;var height:=0.0
				for box in b.game.layout.colliders:
					if point.x>box.min[0] and point.x<box.max[0] and point.z>box.min[2] and point.z<box.max[2] and box.max[1]<point.y+.1:height=maxf(height,float(box.max[1]))
				order.pose.origin.y=height+.135
func tick() -> void:
	for order in b.state.orders:
		if order.get("delivered",false):refresh(order)
	if held_id>=0 and b.packages.has(held_id):
		b.packages[held_id].global_transform=b.game.hands[held_hand].global_transform*Transform3D(Basis.IDENTITY,Vector3(0,-.10,-.28))
	if guest_id>=0 and b.packages.has(guest_id) and not b.is_remote_guest():
		var avatar=b.game.clerk.lan.remote_avatar
		if is_instance_valid(avatar) and avatar.valid_pose:
			var hand:Transform3D=avatar.targets[1] if avatar.tracked_hands else avatar.targets[0]*Transform3D(Basis.IDENTITY,Vector3(-.30,-.45,-.45))
			b.packages[guest_id].global_transform=hand*Transform3D(Basis.IDENTITY,Vector3(0,-.10,-.28))
