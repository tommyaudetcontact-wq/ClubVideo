extends RefCounted

static func hit(game,origin:Vector3,direction:Vector3)->Vector3:
	var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction.normalized()*3.0,1)
	var result:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():return Vector3.INF
	return result.position+result.normal*.035+Vector3.UP*.09

static func release_body(body:RigidBody3D,parent:Node,position:Vector3):
	body.reparent(parent)
	body.global_transform=Transform3D(Basis(Vector3.RIGHT,-PI/2),position)
	body.freeze=false
	body.collision_layer=8
	body.collision_mask=1|8
	body.continuous_cd=true
	body.sleeping=false
	body.linear_velocity=Vector3.ZERO
	body.angular_velocity=Vector3.ZERO

static func disc_body(inspection,node:MeshInstance3D,position:Vector3)->RigidBody3D:
	var body:=RigidBody3D.new()
	body.mass=.016
	body.collision_layer=8
	body.collision_mask=1|8
	body.continuous_cd=true
	var collider:=CollisionShape3D.new()
	var shape:=CylinderShape3D.new()
	shape.radius=.06*minf(node.scale.x,node.scale.y)
	shape.height=.004
	collider.shape=shape
	body.add_child(collider)
	inspection.add_child(body)
	body.global_position=position
	node.reparent(body)
	node.transform=Transform3D(Basis(Vector3.RIGHT,-PI/2).scaled(node.scale),Vector3.ZERO)
	return body

static func drop_disc(inspection,position:Vector3):
	var node:MeshInstance3D=inspection.carried
	var data:Dictionary=inspection.carried_data.duplicate()
	var body:=disc_body(inspection,node,position)
	inspection.loose_discs.append({"node":node,"data":data,"body":body})
	inspection.carried=null
	inspection.finger=-1

static func drop_cash(wallet,entries:Array,position:Vector3):
	for index in range(entries.size()):
		var entry:Dictionary=entries[index]
		var body:=RigidBody3D.new()
		body.mass=.004 if entry.value>=500 else .007
		body.collision_layer=8
		body.collision_mask=1|8
		body.continuous_cd=true
		var collider:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=Vector3(.145,.004,.065) if entry.value>=500 else Vector3(.027,.004,.027)
		collider.shape=shape
		body.add_child(collider)
		wallet.add_child(body)
		body.global_position=position+Vector3((index%3-1)*.035,index*.008,0)
		entry.node.reparent(body)
		entry.node.transform=Transform3D.IDENTITY
		entry.body=body
		wallet.loose.append(entry)
	entries.clear()
