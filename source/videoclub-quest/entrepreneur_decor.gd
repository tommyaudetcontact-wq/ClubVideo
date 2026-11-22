extends RefCounted
const NAMES:=["Plante en pot","Distributrice de comptoir","Distributrice sur pied","Télé cathodique"]
const PRICES:=[1500,6000,15000,12000]
var b
var templates:Array[Node3D]=[]
var nodes:Array[Node3D]=[]
var preview:Node3D
var order_id:=-1
var kind:=-1
var valid:=false
var angle:=0.0
var signature:Array=[]
func setup(owner_business) -> void:
	b=owner_business
	var source:Node3D=load("res://assets/decor.glb").instantiate();b.add_child(source);source.hide()
	var plant:Node3D=b.World.extract_region(source,AABB(Vector3(-5.38,.005,4.87),Vector3(.96,1.4,.96)),Vector3(-4.9,0,5.35))
	var tv:Node3D=b.World.extract_region(source,AABB(Vector3(-1.98,2.15,-3.3),Vector3(.96,1.02,1)),Vector3(-1.5,2.55,-2.8))
	var red:Node3D=b.game.gum.duplicate();red.transform=Transform3D.IDENTITY
	var blue:Node3D=b.game.get_node("SpiralGumballMachine").duplicate();blue.transform=Transform3D.IDENTITY
	for machine in [red,blue]:
		for chute in machine.find_children("PhysicalChute","Node",true,false):chute.get_parent().remove_child(chute);chute.queue_free()
	templates=[plant,red,blue,tv]
	for template in templates:b.add_child(template);template.hide()
	source.queue_free()
	for machine in b.game.candy.machines:machine.node.hide()
	b.game.layout.colliders=b.game.layout.colliders.filter(func(box):return not (absf(float(box.min[0])+5.42)<.01 and absf(float(box.min[2])-3.80)<.01))
	for node in b.game.model.find_children("potted-plant*","Node3D",true,false):node.hide()
	for index in range(1,5):
		var tv_root:Node3D=b.game.model.find_child("ceiling-crt-%d"%index,true,false)
		if tv_root:tv_root.hide()
func buy(index:int) -> bool:
	if index<0 or index>=PRICES.size():return false
	var ok:bool=b.state.buy("decoration",index,PRICES[index])
	if ok:b.flush_orders()
	return ok
func begin(order:Dictionary) -> void:
	if is_instance_valid(preview):return
	order_id=int(order.id);kind=int(order.value);angle=0
	preview=templates[kind].duplicate();b.add_child(preview);preview.show()
	for mesh in preview.find_children("*","GeometryInstance3D",true,false):mesh.transparency=.45
	valid=false
func tick() -> void:
	if not is_instance_valid(preview):return
	var pose:Transform3D=b.freight.safe_pose(b.game.aim_hands[1]);pose.origin.y-=.135
	if kind in [0,2]:pose.origin.y=0
	elif kind==3:pose.origin.y=2.55
	pose.basis=Basis(Vector3.UP,angle)
	preview.transform=pose
	valid=allowed(pose,kind)
	b.ghost_label.position=pose.origin+Vector3(0,.7,0)
	b.ghost_label.text="Gâchette : poser · poignée : tourner de 45°" if valid else "Emplacement occupé · déplace la visée"
func allowed(pose:Transform3D,index:int) -> bool:
	var point:Vector3=pose.origin
	if absf(point.x)>5.3 or point.z< -7.3 or point.z>6.4:return false
	for other in b.state.decorations:
		if other.pose.origin.distance_to(point)<.5:return false
	if index!=3:
		for box in b.game.layout.colliders:
			if box.get("business_decor",false):continue
			if point.x>box.min[0]-.13 and point.x<box.max[0]+.13 and point.z>box.min[2]-.13 and point.z<box.max[2]+.13 and point.y<float(box.max[1])-.02:return false
	return true
func confirm() -> bool:
	if not is_instance_valid(preview) or not valid:return false
	if b.is_remote_guest():return b.remote_command({"op":"place_decor","id":order_id,"point":[preview.position.x,preview.position.y,preview.position.z],"angle":angle})
	return install(order_id,preview.transform)
func install(id:int,pose:Transform3D) -> bool:
	var order:Dictionary=b.freight.order_for(id)
	if order.get("kind","")!="decoration" or not allowed(pose,int(order.value)):return false
	var entry:Dictionary={"kind":int(order.value),"pose":pose}
	b.state.decorations.append(entry);add(entry);signature=b.state.decorations.duplicate(true);b.consume_order(order);cancel();return true
func cancel() -> void:
	if is_instance_valid(preview):preview.queue_free()
	preview=null;order_id=-1;kind=-1;b.ghost_label.text=""
func add(entry:Dictionary) -> void:
	var index:int=entry.kind;var node:Node3D=templates[index].duplicate();b.add_child(node);node.show();node.transform=entry.pose;nodes.append(node)
	if index in [1,2]:b.game.candy._add_machine(node,index==2)
	if index==3:
		for screen in node.find_children("*curved-screen*","MeshInstance3D",true,false):
			screen.material_override=b.game.screens[0].material_override;b.game.screens.append(screen)
	else:
		var height:float=1.45 if index==2 else .68 if index==1 else .9
		var body:Node3D=b.World.solid(node,Vector3(0,height/2,0),Vector3(.32,height,.32),"333a42");body.get_child(0).hide()
		var point:Vector3=entry.pose.origin
		b.game.layout.colliders.append({"min":[point.x-.16,point.y,point.z-.16],"max":[point.x+.16,point.y+height,point.z+.16],"business_decor":true})
func sync() -> void:
	if signature==b.state.decorations:return
	if b.state.decorations.size()>=signature.size() and b.state.decorations.slice(0,signature.size())==signature:
		for entry in b.state.decorations.slice(signature.size()):add(entry)
		signature=b.state.decorations.duplicate(true);return
	for ball in b.game.candy.balls:ball.body.queue_free()
	b.game.candy.balls.clear();b.game.candy.held_balls=[null,null]
	b.game.candy.machines=b.game.candy.machines.filter(func(machine):return not machine.node in nodes)
	for node in nodes:
		if is_instance_valid(node):node.queue_free()
	nodes.clear();b.game.layout.colliders=b.game.layout.colliders.filter(func(box):return not box.get("business_decor",false))
	for entry in b.state.decorations:add(entry)
	signature=b.state.decorations.duplicate(true)
