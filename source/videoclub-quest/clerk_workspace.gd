extends RefCounted
static func expand(game):
	move_checkout(game)
	# Extend only the rear edge, including baked floor, walls and ceiling UVs.
	for node in game.model.find_children("*","MeshInstance3D",true,false):
		if not node.visible:continue
		var bounds=node.global_transform*node.get_aabb()
		if bounds.position.z>=-6.90:continue
		var mesh=ArrayMesh.new()
		var changed=false
		for surface in range(node.mesh.get_surface_count()):
			var arrays=node.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for i in range(vertices.size()):
				var world=node.global_transform*vertices[i]
				if world.z< -6.90 and absf(world.x)<6.05 and world.y>-.15 and world.y<3.65:
					world.z-=2.4
					vertices[i]=node.global_transform.affine_inverse()*world
					changed=true
			arrays[Mesh.ARRAY_VERTEX]=vertices
			mesh.add_surface_from_arrays(node.mesh.surface_get_primitive_type(surface),arrays)
			mesh.surface_set_material(surface,node.get_active_material(surface))
		if changed:node.mesh=mesh
	for b in game.layout.colliders:
		if b.min[2]<-6.90:b.min[2]-=2.4
		if b.max[2]<-6.90:b.max[2]-=2.4
	game.layout.colliders.append({"min":[-3.15,0,-9.2],"max":[3.25,.91,-8.4]})
	# Real floor support for loose cases in the added workspace.
	var body=StaticBody3D.new()
	game.add_child(body)
	body.position=Vector3(0,-.045,-8.1)
	var collision=CollisionShape3D.new()
	var box=BoxShape3D.new()
	box.size=Vector3(11.3,.09,3.0)
	collision.shape=box
	body.add_child(collision)

static func move_checkout(game):
	var counter=game.model.find_child("checkout-counter",true,false)
	var region=AABB(Vector3(-2.2,-.02,-5.96),Vector3(4.4,2.42,1.32))
	for node in game.model.find_children("static-*","MeshInstance3D",true,false):
		if counter and counter.is_ancestor_of(node):continue
		var result=ArrayMesh.new()
		var changed=false
		for surface in range(node.mesh.get_surface_count()):
			var arrays=node.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for i in range(vertices.size()):
				var p=node.global_transform*vertices[i]
				if region.has_point(p):
					p.z-=.8
					vertices[i]=node.global_transform.affine_inverse()*p
					changed=true
			arrays[Mesh.ARRAY_VERTEX]=vertices
			result.add_surface_from_arrays(node.mesh.surface_get_primitive_type(surface),arrays)
			result.surface_set_material(surface,node.get_active_material(surface))
		if changed:node.mesh=result
	if counter:counter.position.z-=.8
	for b in game.layout.colliders:
		if absf(b.min[0]+1.9)<.001 and absf(b.max[0]-1.9)<.001:
			b.min[2]-=.8
			b.max[2]-=.8
