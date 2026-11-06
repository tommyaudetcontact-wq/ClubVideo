extends RefCounted

static func solid(parent:Node3D,position:Vector3,size:Vector3,name:String)->StaticBody3D:
	var body:=StaticBody3D.new()
	body.name=name
	body.collision_layer=1
	body.collision_mask=8
	parent.add_child(body)
	body.position=position
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=size
	shape.shape=box
	body.add_child(shape)
	return body

static func setup(clerk):
	# The computer housing is baked into visual batches, not into solid geometry.
	solid(clerk,Vector3(.12,1.375,-6.085),Vector3(.44,.36,.42),"ComputerHousingSolid")
	solid(clerk,Vector3(.12,1.14,-6.15),Vector3(.35,.08,.25),"ComputerFootSolid")
	solid(clerk,Vector3(.12,1.11,-6.49),Vector3(.39,.04,.15),"KeyboardSolid")
	solid(clerk,Vector3(-.74,1.42,-6.32),Vector3(.34,.12,.08),"RegisterDisplaySolid")
	var station:Vector3=clerk.repairs.station
	solid(clerk.repairs,station-Vector3(0,.12,0),Vector3(.47,.23,.42),"ResurfacerBaseSolid")
	solid(clerk.repairs,station+Vector3(.16,.075,0),Vector3(.07,.18,.11),"ResurfacerPostSolid")
	solid(clerk.repairs,station+Vector3(.06,.15,0),Vector3(.24,.035,.09),"ResurfacerArmSolid")
	solid(clerk.drawer,Vector3.ZERO,Vector3(.74,.07,.44),"DrawerFloorSolid")

static func clear_at(body:RigidBody3D,pose:Transform3D)->bool:
	for child in body.get_children():
		if not child is CollisionShape3D or child.disabled or not child.shape:continue
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=child.shape
		query.transform=pose*child.transform
		query.collision_mask=1|8
		query.margin=.003
		query.exclude=[body.get_rid()]
		if not body.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
	return true

static func position_for(body:RigidBody3D,desired:Vector3,basis:Basis,eye:Vector3=Vector3.INF)->Vector3:
	if not desired.is_finite():return Vector3.INF
	var point:=desired
	if eye.is_finite() and eye.distance_to(point)>.02:
		var ray:=PhysicsRayQueryParameters3D.create(eye,point,1)
		ray.exclude=[body.get_rid()]
		ray.hit_from_inside=true
		var obstruction:Dictionary=body.get_world_3d().direct_space_state.intersect_ray(ray)
		if not obstruction.is_empty():
			var normal:Vector3=obstruction.normal
			if normal.length_squared()<.1:normal=Vector3.UP
			point=obstruction.position+normal*.16+Vector3.UP*.04
	# Test the full case, not just its centre. A blocked release rises out of the
	# appliance; if there is no room the player keeps the case in hand.
	for step in range(41):
		var candidate:=point+Vector3.UP*(step*.025)
		if clear_at(body,Transform3D(basis,candidate)):return candidate
	return Vector3.INF
