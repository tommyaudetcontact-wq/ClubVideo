extends Node3D
const Props=preload("res://clerk_props.gd")
var clerk
var game
var body:RigidBody3D
var hand=-1
var items:Array=[]
var targeted:Array[Dictionary]=[{},{}]
var highlighted:Array[MeshInstance3D]=[]
var highlight:StandardMaterial3D
var home=Vector3(-1.55,1.17,-5.95)
const CAPACITY=12
func setup(c):
	clerk=c
	game=c.game
	highlight=StandardMaterial3D.new()
	highlight.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight.albedo_color=Color(.44,.8,1.0,.45)
	body=RigidBody3D.new()
	add_child(body)
	body.name="RestockingBasket"
	body.mass=.65
	body.freeze=true
	body.position=home
	body.collision_layer=8
	body.collision_mask=1|8
	body.continuous_cd=true
	body.linear_damp=1
	body.angular_damp=2
	var surfaces=[[Vector3(0,0,0),Vector3(.40,.025,.30)],[Vector3(-.20,.12,0),Vector3(.018,.24,.30)],[Vector3(.20,.12,0),Vector3(.018,.24,.30)],[Vector3(0,.12,-.15),Vector3(.40,.24,.018)],[Vector3(0,.12,.15),Vector3(.40,.24,.018)]]
	for surface in surfaces:
		Props.box(body,surface[0],surface[1],"315e73")
		var shape=CollisionShape3D.new()
		var box=BoxShape3D.new()
		box.size=surface[1]
		shape.shape=box
		shape.position=surface[0]
		body.add_child(shape)
	for x in [-.19,.19]:Props.box(body,Vector3(x,.24,0),Vector3(.018,.30,.018),"20272b")
	Props.box(body,Vector3(0,.39,0),Vector3(.40,.025,.025),"20272b")
	Props.label(body,"À RANGER",Vector3(0,.09,.161),.0008,28)
func contains(p:Vector3)->bool:
	var local=body.to_local(p)
	return absf(local.x)<.22 and absf(local.z)<.19 and local.y>-.03 and local.y<.38
func occupied(h:int)->bool:return hand==h
func store(item:Dictionary)->bool:
	if not contains(item.node.global_position):return false
	if items.size()>=CAPACITY:
		game._message("Panier plein : range quelques boîtiers.")
		return true
	if not items.has(item):items.append(item)
	item.node.set_meta("in_basket",true)
	item.node.set_meta("sort_slot",-1)
	item.node.freeze=true
	item.node.collision_layer=0
	item.node.collision_mask=0
	item.node.reparent(body)
	arrange()
	if item==clerk.held_service:clerk.clear_hand()
	return true
func arrange():
	for i in range(items.size()):
		items[i].node.position=Vector3(-.165+i*.030,.120,0)
		items[i].node.rotation=Vector3(0,PI/2,0)
func can_pick(h:int)->bool:
	return h!=hand and h!=game.held_hand and h!=clerk.secondary_hand and h!=clerk.inspection.finger and not clerk.wallet.occupied(h) and h!=clerk.lock_hand and clerk.secondary.is_empty() and not clerk.inspection.opened

func target_case(h:int)->Dictionary:
	if not can_pick(h) or items.is_empty():return {}
	var palm:Vector3=body.to_local(game.hands[h].global_position)
	if hand<0 and palm.distance_to(Vector3(0,.39,0))<.10:return {}
	if absf(palm.x)>.32 or absf(palm.z)>.31 or palm.y<-.04 or palm.y>.52:return {}
	var aim:Node3D=game.aim_hands[h]
	var ray_start:=body.to_local(aim.global_position)
	var ray_direction:=body.global_basis.inverse()*(-aim.global_basis.z)
	var point:=palm
	if ray_direction.y<-.12:
		var distance:float=(.21-ray_start.y)/ray_direction.y
		var hit:=ray_start+ray_direction*distance
		if distance>=0 and distance<.36 and absf(hit.x)<.21 and absf(hit.z)<.12:
			point=hit
	if absf(point.z)>.14:return {}
	var nearest:=.036
	var chosen:Dictionary={}
	for item in items:
		var gap:float=absf(item.node.position.x-point.x)
		if gap<nearest:
			nearest=gap
			chosen=item
	return chosen

func update_targets():
	var next:Array[Dictionary]=[target_case(0),target_case(1)]
	if next==targeted:return
	targeted=next
	for mesh in highlighted:
		if is_instance_valid(mesh):mesh.material_overlay=null
	highlighted.clear()
	for item in targeted:
		if item.is_empty():continue
		var node:Node3D=item.node
		for surface in ["MoldedPlasticOnly","PaperInsert_spine","PaperInsert_front","PaperInsert_back"]:
			var mesh:=node.get_node_or_null(surface) as MeshInstance3D
			if mesh and not highlighted.has(mesh):
				mesh.material_overlay=highlight
				highlighted.append(mesh)

func interact(h:int,grip:bool)->bool:
	if body.get_meta("guest_held",false):return false
	if h==hand:return true
	if not grip or h==game.held_hand or h==clerk.secondary_hand or h==clerk.inspection.finger or clerk.wallet.occupied(h) or h==clerk.lock_hand:return false
	var p:Vector3=game.hands[h].global_position
	# The tall handle is separate from the cases, so either action is intentional.
	if hand<0 and p.distance_to(body.to_global(Vector3(0,.39,0)))<.10:
		hand=h
		body.freeze=true
		body.collision_layer=0
		body.collision_mask=0
		body.reparent(game.hands[h],false)
		body.position=Vector3(0,-.39,-.04)
		body.rotation=Vector3.ZERO
		return true
	var chosen:=targeted[h]
	if can_pick(h) and items.has(chosen):
		items.erase(chosen)
		clerk.pick_case(chosen,h,true)
		arrange()
		update_targets()
		return true
	return false
func release(h:int):
	if hand!=h:return
	body.reparent(self)
	hand=-1
	body.collision_layer=8
	body.collision_mask=1|8
	body.freeze=false
	body.sleeping=false
	body.linear_velocity=game.candy.hand_velocity(h).limit_length(2)
func restore_items():
	items.clear()
	for item in clerk.cases:
		if item.node.get_meta("in_basket",false):
			items.append(item)
			item.node.freeze=true
			item.node.collision_layer=0
			item.node.collision_mask=0
			item.node.reparent(body)
	arrange()
