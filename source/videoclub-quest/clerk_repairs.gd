extends Node3D
const Props=preload("res://clerk_props.gd")
var clerk
var game
var station=Vector3(-2.55,1.12,-8.8)
var repair_bin=Vector3(-1.70,1.03,-8.85)
var ready_bin=Vector3(-.85,1.03,-8.85)
var disc:MeshInstance3D
var data={}
var source:Node3D
var remaining=0.0
var label:Label3D
var marker:MeshInstance3D
var processed=0
var case_slots:Array[Vector3]=[]
func setup(c):
	clerk=c
	game=c.game
	Props.box(self,Vector3(.05,.88,-8.8),Vector3(6.4,.05,.8),"565c60")
	var table_body=StaticBody3D.new()
	add_child(table_body)
	table_body.position=Vector3(.05,.88,-8.8)
	var table_collision=CollisionShape3D.new()
	var table_shape=BoxShape3D.new()
	table_shape.size=Vector3(6.4,.05,.8)
	table_collision.shape=table_shape
	table_body.add_child(table_collision)
	Props.label(self,"BOÎTIERS",Vector3(.35,.87,-8.39),.0012,30)
	Props.label(self,"DISQUES",Vector3(2.15,.87,-8.39),.0012,30)
	for row in range(2):
		for col in range(7):
			var slot=Vector3(-.23+col*.19,.918,-8.65-row*.32)
			case_slots.append(slot)
			Props.box(self,slot-Vector3(0,.012,0),Vector3(.15,.003,.23),"384b53")
	for x in [-2.9,3.0]:
		for z in [-9.12,-8.48]:Props.box(self,Vector3(x,.43,z),Vector3(.045,.86,.045),"858c91")
	for entry in [[repair_bin,"À RÉPARER","b56a28"],[ready_bin,"À RANGER","3b8b65"]]:
		Props.box(self,entry[0]-Vector3(0,.12,0),Vector3(.70,.025,.46),entry[2])
		for x in [-.34,.34]:Props.box(self,entry[0]+Vector3(x,-.02,0),Vector3(.02,.22,.46),entry[2])
		for z in [-.22,.22]:Props.box(self,entry[0]+Vector3(0,-.02,z),Vector3(.70,.22,.02),entry[2])
		Props.label(self,entry[1],entry[0]+Vector3(0,-.02,.232),.0012,30)
		var body=StaticBody3D.new()
		add_child(body)
		body.position=entry[0]-Vector3(0,.12,0)
		var shape=CollisionShape3D.new()
		var box=BoxShape3D.new()
		box.size=Vector3(.70,.035,.46)
		shape.shape=box
		body.add_child(shape)
		for wall in [[Vector3(-.34,.10,0),Vector3(.02,.22,.46)],[Vector3(.34,.10,0),Vector3(.02,.22,.46)],[Vector3(0,.10,-.22),Vector3(.70,.22,.02)],[Vector3(0,.10,.22),Vector3(.70,.22,.02)]]:
			var collider=CollisionShape3D.new()
			var wall_shape=BoxShape3D.new()
			wall_shape.size=wall[1]
			collider.shape=wall_shape
			collider.position=wall[0]
			body.add_child(collider)
	Props.box(self,station-Vector3(0,.12,0),Vector3(.47,.23,.42),"aab3ba")
	Props.cylinder(self,station,.085,.02,"252d33")
	Props.cylinder(self,station+Vector3(0,.025,0),.006,.04,"a9b5bb")
	Props.box(self,station+Vector3(.16,.075,0),Vector3(.07,.18,.11),"5e6972")
	Props.box(self,station+Vector3(.06,.15,0),Vector3(.24,.035,.09),"c7ced2")
	Props.cylinder(self,station+Vector3(-.015,.115,0),.035,.05,"4a8d93")
	label=Props.label(self,"SURFACEUSE · 30 s\nPose le disque sur le plateau",station+Vector3(0,.23,0),.0007,26)
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	marker=MeshInstance3D.new()
	var mesh=BoxMesh.new()
	mesh.size=Vector3(.15,.21,.025)
	marker.mesh=mesh
	var mat=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color(.1,1,.3,.45)
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test=false
	marker.material_override=mat
	add_child(marker)
	marker.visible=false
func is_sorting_surface(p:Vector3)->bool:
	return p.x>1.15 and p.x<3.15 and p.z>-9.16 and p.z<-8.4 and p.y>.82 and p.y<1.45
func is_case_surface(p:Vector3)->bool:
	return p.x>-.35 and p.x<1.15 and p.z>-9.18 and p.z<-8.35 and p.y>.82 and p.y<1.50
func place_case(item:Dictionary)->bool:
	if not is_case_surface(item.node.global_position):return false
	var chosen=-1
	var nearest=INF
	for i in range(case_slots.size()):
		var occupied=false
		for other in clerk.cases:
			if other!=item and other.node.get_meta("sort_slot",-1)==i:occupied=true
		var distance=case_slots[i].distance_to(item.node.global_position)
		if not occupied and distance<nearest:
			chosen=i
			nearest=distance
	if chosen<0:
		game._message("Les emplacements de boîtiers sont pleins.")
		return true
	if clerk.has_identified_mismatch(item.node,item.movie):clerk.flag_wrong_case(item)
	item.node.reparent(clerk)
	item.node.global_position=case_slots[chosen]
	item.node.rotation=Vector3(-PI/2,0,0)
	item.node.set_meta("sort_slot",chosen)
	item.node.freeze=true
	item.node.collision_layer=0
	item.node.collision_mask=0
	clerk.clear_hand()
	return true
func place_disc(inspection,p:Vector3)->bool:
	if not is_sorting_surface(p):return false
	var destination=Vector3(p.x,.916,p.z)
	for loose in inspection.loose_discs:
		if loose.node.global_position.distance_to(destination)<.125:
			destination.x=loose.node.global_position.x
			destination.z=loose.node.global_position.z
			destination.y=maxf(destination.y,loose.node.global_position.y+.004)
	inspection.carried.reparent(inspection)
	inspection.carried.global_position=destination
	inspection.carried.rotation=Vector3(-PI/2,0,0)
	inspection.loose_discs.append({"node":inspection.carried,"data":inspection.carried_data.duplicate()})
	inspection.carried=null
	inspection.finger=-1
	return true
func insert_disc(inspection)->bool:
	if inspection.carried.global_position.distance_to(station)>.23:return false
	if is_instance_valid(disc):
		game._message("La surfaceuse est occupée.")
		return true
	disc=inspection.carried
	data=inspection.carried_data.duplicate()
	source=inspection.source_case
	disc.reparent(self)
	disc.global_position=station+Vector3(0,.035,0)
	disc.rotation=Vector3(PI/2,0,0)
	inspection.carried=null
	inspection.finger=-1
	remaining=30.0
	game._message("Réparation démarrée : 30 secondes. Tu peux servir un autre client.")
	return true
func take_disc(inspection,hand:int,p:Vector3)->bool:
	if not is_instance_valid(disc) or p.distance_to(station)>.23:return false
	if remaining>0:
		game._message("Réparation en cours : %d secondes."%ceili(remaining))
		return true
	inspection.carried=disc
	inspection.carried_data=data.duplicate()
	inspection.source_case=source
	inspection.finger=hand
	disc.reparent(inspection)
	disc=null
	label.text="SURFACEUSE · 30 s\nPose le disque sur le plateau"
	return true
func tick(dt:float):
	if remaining>0:
		remaining=maxf(0,remaining-dt)
		disc.rotate_object_local(Vector3.FORWARD,dt*8)
		label.text="RÉPARATION · %d s"%ceili(remaining)
		if remaining<=0:
			data.dirty=false
			disc.material_override.set_shader_parameter("scratched",false)
			if is_instance_valid(source):source.set_meta("dirty",false)
			processed+=1
			label.text="DISQUE RÉPARÉ\nGâchette pour reprendre"
	marker.visible=false
	var record:Dictionary=game.held_record
	if not clerk.held_service.is_empty():record=clerk.held_service.record
	if game.held and not record.is_empty():
		marker.global_transform=record.world
		marker.visible=true
func drop_into_bin(item:Dictionary)->bool:
	if place_case(item):return true
	var p:Vector3=item.node.global_position
	for location in [repair_bin,ready_bin]:
		if p.distance_to(location)<.38:
			if location==ready_bin and item.node.get_meta("dirty",false):
				game._message("Ce disque est encore rayé : utilise le bac À RÉPARER.")
				return true
			item.node.reparent(clerk)
			item.node.global_position=location+Vector3(randf_range(-.15,.15),.08,randf_range(-.08,.08))
			item.node.rotation=Vector3(-PI/2,0,0)
			item.node.freeze=false
			item.node.collision_layer=8
			item.node.collision_mask=1|8
			item.node.linear_velocity=Vector3.ZERO
			clerk.clear_hand()
			return true
	return false
