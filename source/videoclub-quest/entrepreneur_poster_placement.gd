extends RefCounted
## A delivered poster stays in its parcel until placement has been confirmed.
var business
var preview:MeshInstance3D
var order_id:=-1
var movie:=-1
var valid:=false

func setup(owner_business) -> void:business=owner_business
func active() -> bool:return is_instance_valid(preview)

func begin(order:Dictionary) -> void:
	if active():return
	order_id=int(order.id);movie=int(order.value)
	preview=MeshInstance3D.new()
	preview.name="PosterPlacementPreview"
	var quad:=QuadMesh.new();quad.size=Vector2(.55,.78)
	preview.mesh=quad
	var material:=StandardMaterial3D.new()
	material.albedo_texture=load(business.game.layout.movies[movie].frontCover)
	material.roughness=.65
	preview.material_override=material
	preview.transparency=.4
	preview.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	business.add_child(preview)
	preview.hide()
	valid=false
	business.game._message("Vise un mur : gâchette pour poser l’affiche. Poignée pour annuler.")

func wall_pose(origin:Vector3,direction:Vector3) -> Dictionary:
	var hits:Array=[]
	# Solid wall sections only: no posters floating over glass or the staff doorway.
	if absf(direction.z)>.0001:
		var distance:=(-7.82-origin.z)/direction.z
		var point:=origin+direction*distance
		if distance>0 and distance<=5 and point.x>=-5.35 and point.x<=3.65 and point.y>=.55 and point.y<=2.65:
			hits.append({"pose":Transform3D(Basis.IDENTITY,point+Vector3(0,0,.008)),"distance":distance})
	for side in [-1,1]:
		if absf(direction.x)<.0001:continue
		var distance:float=(side*5.69-origin.x)/direction.x
		var point:=origin+direction*distance
		if distance>0 and distance<=5 and point.z>=-7.4 and point.z<=-1.9 and point.y>=.55 and point.y<=2.65:
			hits.append({"pose":Transform3D(Basis(Vector3.UP,-side*PI/2),point+Vector3(-side*.008,0,0)),"distance":distance})
	if hits.is_empty():return {}
	hits.sort_custom(func(a,b):return a.distance<b.distance)
	return hits[0]

func allowed(pose:Transform3D,origin:Vector3) -> bool:
	for index in business.state.posters.size():
		var other:Transform3D=business.poster_pose(index)
		if pose.basis.z.dot(other.basis.z)<.95:continue
		var offset:=other.affine_inverse()*pose.origin
		if absf(offset.x)<.59 and absf(offset.y)<.82:return false
	for box in business.game.layout.colliders:
		var low:=Vector3(box.min[0],box.min[1],box.min[2])
		var high:=Vector3(box.max[0],box.max[1],box.max[2])
		var bounds:=AABB(low,high-low)
		if bounds.grow(.05).has_point(pose.origin):
			if bounds.size.y>2.5 and minf(bounds.size.x,bounds.size.z)<.25:continue
			return false
		var hit:Variant=bounds.intersects_segment(origin,pose.origin)
		if hit!=null and origin.distance_to(hit)<origin.distance_to(pose.origin)-.12:return false
	return true

func tick() -> void:
	if not active():return
	var ray:Node3D=business.game.aim_hands[1]
	var hit:=wall_pose(ray.global_position,-ray.global_basis.z)
	valid=not hit.is_empty()
	preview.visible=valid
	if valid:
		preview.global_transform=hit.pose
		valid=allowed(hit.pose,ray.global_position)
		preview.material_override.albedo_color=Color.WHITE if valid else Color("e77767")
		business.ghost_label.global_position=preview.global_position+Vector3(0,.55,0)
		business.ghost_label.text="Poser l’affiche" if valid else "Emplacement occupé ou masqué"
	else:
		business.ghost_label.global_position=ray.global_position-ray.global_basis.z*.8+Vector3(0,.2,0)
		business.ghost_label.text="Vise un mur plein à proximité"

func confirm() -> bool:
	if not active() or not valid:return false
	if business.is_remote_guest():
		var p:=preview.global_position
		return business.remote_command({"op":"place_poster","id":order_id,"point":[p.x,p.y,p.z]})
	# Revalidate at the moment of input, not just at the previous rendered frame.
	if not allowed(preview.global_transform,business.game.aim_hands[1].global_position):return false
	var matches:Array=business.state.orders.filter(func(order):return int(order.id)==order_id)
	if matches.is_empty():cancel();return false
	business.state.posters.append({"movie":movie,"day":business.state.day,"pose":preview.global_transform})
	business.place_poster(movie)
	business.consume_order(matches[0])
	cancel()
	business.game._message("Affiche posée. Elle attire l’attention sur ce film pendant sa nouveauté.")
	return true

func cancel(notify:bool=true) -> void:
	if notify and active() and business.is_remote_guest():business.remote_command({"op":"cancel_poster","id":order_id})
	if active():preview.queue_free()
	preview=null;order_id=-1;movie=-1;valid=false
	business.ghost_label.text=""
