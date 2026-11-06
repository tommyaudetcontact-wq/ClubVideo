extends Node3D
const Props=preload("res://clerk_props.gd")
var game
var case_node:Node3D
var interior:Node3D
var lid:Node3D
var disc:MeshInstance3D
var finger=-1
var opened=false
var chord_down=false
var hidden_parts:Array=[]
var inspected=false
var clean_progress=0.0
var last_clean_position=Vector3.ZERO
var scratches:Node3D
var pending_flip=-1
var flip_delay=0.0
var opening_direction=1.0
var opening_amount=0.0
var lid_tween:Tween
var lid_hand=-1
var lid_start_angle=0.0
var hand_start_angle=0.0
var lid_moved=false
var label_seen=false
var carried:MeshInstance3D
var carried_data:Dictionary={}
var loose_discs:Array=[]
var source_case:Node3D
func setup(g):game=g
func input_tick(dt:float):
	if opened and opening_amount>=.30:label_seen=true
	if lid_hand>=0:
		if game.hands[lid_hand].get_float("grip")<.6:
			var opened_further:bool=lid.rotation.y<lid_start_angle-.22
			var closed_further:bool=lid.rotation.y>lid_start_angle+.22
			finish_lid(opened_further or (not closed_further and lid_start_angle<-.5))
		else:update_lid(game.hands[lid_hand].global_position)
	if pending_flip>=0:
		flip_delay-=dt
		if flip_delay<=0:
			pending_flip=-1
			if not opened:game._flip_held()
func grab_lid(hand:int)->bool:
	if not game.held or hand==game.held_hand or hand==game.clerk.secondary_hand or hand==game.clerk.basket.hand or hand==finger:return false
	if not opened and game.held.get_meta("antitheft",false):return false
	var p:Vector3=game.hands[hand].global_position
	var edge_owner:Node3D=lid if opened else game.held
	var local_edge:=edge_owner.to_local(p)
	var edge_x:=.125 if opened else .064
	var edge:=Vector3(edge_x,clampf(local_edge.y,-.075,.075),.006)
	if local_edge.distance_to(edge)>(.17 if opened else .13):return false
	if not opened:
		toggle_case()
		if not opened:return true
		if lid_tween and lid_tween.is_valid():lid_tween.kill()
		opening_amount=0
		lid.rotation.y=0
	if lid_tween and lid_tween.is_valid():lid_tween.kill()
	pending_flip=-1
	lid_hand=hand
	lid_start_angle=lid.rotation.y
	var local:Vector3=case_node.to_local(p)-lid.position
	hand_start_angle=atan2(local.z,local.x)
	lid_moved=false
	return true
func update_lid(p:Vector3):
	if not opened or lid_hand<0:return
	var local=case_node.to_local(p)-lid.position
	if Vector2(local.x,local.z).length()<.025:return
	var delta=wrapf(atan2(local.z,local.x)-hand_start_angle,-PI,PI)
	var angle=clampf(lid_start_angle-delta,-2.8,0)
	lid.rotation.y=angle
	opening_amount=-angle/2.8
	if absf(angle-lid_start_angle)>.08:lid_moved=true
	if lid_moved and angle>-.32 and angle>lid_start_angle:finish_lid(false)
	elif lid_moved and angle< -2.35 and angle<lid_start_angle:finish_lid(true)
func finish_lid(open:bool):
	lid_hand=-1
	if lid_tween and lid_tween.is_valid():lid_tween.kill()
	lid_tween=create_tween()
	lid_tween.tween_property(lid,"rotation:y",-2.8 if open else 0.0,.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if open:opening_amount=1.0
	else:lid_tween.tween_callback(close_case)
func defer_flip(hand:int):
	pending_flip=hand
	flip_delay=.20
func toggle_case():
	if opened:
		close_case()
		return
	if not game.held:return
	if not game.clerk.secondary.is_empty():
		game._message("Dépose un des deux boîtiers pour libérer une main avant d'ouvrir.")
		return
	if game.held.get_meta("antitheft",false):
		game._message("Retire d'abord l'antivol sur le détacheur du comptoir.")
		return
	if game.flip_tween and game.flip_tween.is_valid():game.flip_tween.kill()
	open_case(game.held)

func open_case(node:Node3D):
	case_node=node
	interior=Node3D.new()
	case_node.add_child(interior)
	for name in ["MoldedPlasticOnly","PaperInsert_front","PaperInsert_spine"]:
		var part=case_node.get_node_or_null(name)
		if part:
			part.visible=false
			hidden_parts.append(part)
	var shell:=case_node.get_node_or_null("MoldedPlasticOnly") as MeshInstance3D
	var h:float=shell.get_aabb().size.y if shell else .19
	var plastic:Material=shell.material_override if shell else Props.material("202326")
	var tray:=Props.box(interior,Vector3(0,0,-.004),Vector3(.135,h,.005),"202326")
	tray.material_override=plastic
	for x in [-.065,.065]:
		var rim:=Props.box(interior,Vector3(x,0,0),Vector3(.004,h,.008),"292c30")
		rim.material_override=plastic
	lid=Node3D.new()
	interior.add_child(lid)
	lid.position=Vector3(-.0675,0,0)
	var cover_shell:=Props.box(lid,Vector3(.0675,0,.003),Vector3(.135,h,.004),"202326")
	cover_shell.material_override=plastic
	var original=case_node.get_node_or_null("PaperInsert_front")
	if original:
		var cover=original.duplicate()
		lid.add_child(cover)
		cover.position=Vector3(.0675,original.position.y,.00715)
		cover.visible=true
	opening_amount=0
	lid.rotation.y=0
	var disc_id=int(case_node.get_meta("disc_movie",case_node.get_meta("movie",game.movie_id)))
	disc=create_disc(disc_id,case_node.get_meta("dirty",false))
	interior.add_child(disc)
	disc.position=Vector3(0,-.012,.004)
	if disc_id<0:disc.visible=false
	elif game.layout.movies[disc_id].get("console","")=="GameCube":disc.scale=Vector3(.667,.667,1)
	scratches=Node3D.new()
	disc.add_child(scratches)
	opened=true
	label_seen=false
	inspected=false
	clean_progress=0
	if game.touch_profile:
		game._message("Touche le disque pour le sortir. Touche sa face pour le retourner.")
		return
	game._message("Poignée sur le bord : ouvre avec ta main. Relâche après un petit mouvement pour finir le geste. Gâchette près du centre : sortir le disque.")
func finger_transform(hand:int)->Transform3D:
	if game.touch_profile and game.touch_controls:
		var direction:=Basis(Vector3.UP,PI) if game.touch_controls.disc_back else Basis.IDENTITY
		return game.head.global_transform*Transform3D(direction,Vector3(-.19,-.10,-.41))
	var visual=game.hand_visuals[hand]
	var s:Skeleton3D=visual.skeleton
	var tip=s.find_bone("index-finger-tip")
	var distal=s.find_bone("index-finger-phalanx-distal")
	if tip>=0 and distal>=0:
		var p=s.to_global(s.get_bone_global_pose(tip).origin)
		var q=s.to_global(s.get_bone_global_pose(distal).origin)
		var normal=(p-q).normalized()
		var up=Vector3.UP if absf(normal.dot(Vector3.UP))<.95 else Vector3.RIGHT
		return Transform3D(Basis.looking_at(normal,up),p-normal*.012)
	return game.hands[hand].global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-.10))
func try_take_open_disc(hand:int)->bool:
	if hand==game.held_hand or hand==game.clerk.secondary_hand or hand==game.clerk.basket.hand or finger>=0:return false
	if not opened or opening_amount<.30 or not is_instance_valid(disc) or not disc.visible:return false
	if minf(finger_transform(hand).origin.distance_to(disc.global_position),game.hands[hand].global_position.distance_to(disc.global_position))>.18:return false
	if lid_hand>=0:finish_lid(true)
	take_open_disc(hand)
	return true

func interact(hand:int,grip:bool=false)->bool:
	if grip:
		if hand==finger:return true
		return grab_lid(hand)
	var fingertip=finger_transform(hand).origin
	if hand==finger:
		if game.clerk.repairs and game.clerk.repairs.insert_disc(self):return true
		if game.clerk.repairs and game.clerk.repairs.place_disc(self,fingertip):return true
		if opened and opening_amount>.30 and carried.global_position.distance_to(interior.to_global(Vector3(0,-.012,.004)))<.10:
			if put_carried_in_case():game._message("Disque inséré. Tu peux refermer le boîtier à la main.")
			else:game._message("Retire d’abord le disque présent dans ce boîtier.")
		return true
	if finger<0 and hand!=game.held_hand:
		if game.clerk.repairs and game.clerk.repairs.take_disc(self,hand,fingertip):return true
		var chosen={}
		var nearest=.13
		for loose in loose_discs:
			var covered=false
			for other in loose_discs:
				var delta:Vector3=other.node.global_position-loose.node.global_position
				if delta.y>.001 and Vector2(delta.x,delta.z).length()<.08:covered=true
			var gap=fingertip.distance_to(loose.node.global_position)
			if not covered and gap<nearest:
				chosen=loose
				nearest=gap
		if not chosen.is_empty():
			take_loose_disc(chosen,hand)
			return true
	if not opened:return false
	if opening_amount<.30:return false
	if hand==game.held_hand:return true
	return true

func put_carried_in_case()->bool:
	if not opened or not is_instance_valid(carried) or int(case_node.get_meta("disc_movie",-1))>=0:return false
	if is_instance_valid(disc):disc.queue_free()
	disc=carried
	disc.reparent(interior)
	disc.position=Vector3(0,-.012,.004)
	disc.rotation=Vector3.ZERO
	load("res://clerk_inventory.gd").put(case_node,carried_data.movie,carried_data.uid)
	case_node.set_meta("dirty",carried_data.dirty)
	var record:Dictionary=case_node.get_meta("inventory_record",{})
	if not record.is_empty():record.dirty=carried_data.dirty
	case_node.set_meta("inspected",carried_data.inspected)
	carried=null
	finger=-1
	return true

func take_loose_disc(item:Dictionary,hand:int):
	carried=item.node
	if is_instance_valid(item.get("body")):
		carried.reparent(self)
		item.body.queue_free()
	carried_data=item.data
	loose_discs.erase(item)
	finger=hand
	source_case=null

func take_open_disc(hand:int):
	if finger>=0 or not opened or opening_amount<.30 or not is_instance_valid(disc) or not disc.visible:return
	finger=hand
	carried=disc
	carried_data={"movie":int(case_node.get_meta("disc_movie",case_node.get_meta("movie",game.movie_id))),"uid":int(case_node.get_meta("disc_uid",-1)),"dirty":case_node.get_meta("dirty",false),"inspected":false}
	source_case=case_node
	label_seen=true
	load("res://clerk_inventory.gd").put(case_node,-1,-1)
	carried.reparent(self)
	disc=null
	game._message("Inspecte le disque, puis remets-le dans le boîtier ou dépose-le au tri.")
func _physics_process(dt):
	if finger<0 or not is_instance_valid(carried):return
	carried.global_transform=finger_transform(finger)
	if game.layout.movies[carried_data.movie].get("console","")=="GameCube":carried.scale=Vector3(.667,.667,1)
	var eye:Vector3=game.head.global_position-carried.global_position
	if eye.length()<.65 and absf(eye.normalized().dot(carried.global_basis.z.normalized()))>.6:
		inspected=true
		carried_data.inspected=true
		if is_instance_valid(source_case):source_case.set_meta("inspected",true)
	var pad=Vector3(1.18,1.12,-6.18)
	if carried.global_position.distance_to(pad)<.20:
		var travel=carried.global_position.distance_to(last_clean_position)
		if travel<.10:clean_progress+=travel
		if clean_progress>.65:
			game._message("Une rayure nécessite la surfaceuse : pose le disque dans la machine près des retours.")
			clean_progress=0.0
	last_clean_position=carried.global_position
func close_case():
	if lid_tween and lid_tween.is_valid():lid_tween.kill()
	if lid_tween and lid_tween.is_valid():lid_tween.kill()
	for part in hidden_parts:
		if is_instance_valid(part):part.visible=true
	hidden_parts.clear()
	if is_instance_valid(interior):interior.queue_free()
	opened=false
	lid_hand=-1
	var closed_node:=case_node
	case_node=null
	disc=null
	if (label_seen or opening_amount>=.30) and is_instance_valid(closed_node):
		var mismatch:bool=int(closed_node.get_meta("disc_movie",-1))!=int(closed_node.get_meta("movie",game.movie_id))
		closed_node.set_meta("disc_mismatch_seen",mismatch)
		if mismatch:
			game._message("Disque incorrect ou absent. Mets ce boîtier de côté où tu veux, puis cherche un autre exemplaire.")
			return
	if game.clerk and not game.clerk.held_service.is_empty() and game.held and game.held.get_meta("inspected",false):
		game._message("Inspection terminée : passe le dos du boîtier dans le faisceau rouge du scanner.")

func create_disc(disc_id:int,dirty:bool)->MeshInstance3D:
	var result=MeshInstance3D.new()
	var torus=SurfaceTool.new()
	torus.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(96):
		var a=TAU*i/96.0
		var b=TAU*(i+1)/96.0
		for p in [Vector2(cos(a),sin(a))*.008,Vector2(cos(a),sin(a))*.06,Vector2(cos(b),sin(b))*.06,Vector2(cos(a),sin(a))*.008,Vector2(cos(b),sin(b))*.06,Vector2(cos(b),sin(b))*.008]:
			torus.set_normal(Vector3.FORWARD)
			torus.set_uv(p/.12+Vector2(.5,.5))
			torus.add_vertex(Vector3(p.x,p.y,0))
	result.mesh=torus.commit()
	var m=ShaderMaterial.new()
	m.shader=load("res://clerk_disc.gdshader")
	var scan="res://assets/discs/%02d.png"%disc_id
	if not ResourceLoader.exists(scan):scan="res://assets/discs/%02d.jpg"%disc_id
	if disc_id>=0 and not ResourceLoader.exists(scan):scan="res://assets/covers/%02d-front.jpg"%disc_id
	if ResourceLoader.exists(scan):
		m.set_shader_parameter("label_texture",load(scan))
		m.set_shader_parameter("has_label",true)
		if disc_id==0:m.set_shader_parameter("label_rect",Vector4(.065,.06,.90,.87))
	result.material_override=m
	m.set_shader_parameter("scratched",dirty)
	if disc_id>=0 and game.layout.movies[disc_id].get("console","")=="GameCube":result.scale=Vector3(.667,.667,1)
	return result
