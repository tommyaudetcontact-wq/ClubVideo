extends RefCounted
static func move_checkout_scanner(game)->void:
	# The black scanner housing is baked into static batches; preserve its UVs.
	var region=AABB(Vector3(-.68,1.02,-6.05),Vector3(.38,.425,.38))
	var offset=Vector3(.90,0,-.31)
	var moved=0
	for node in game.model.find_children("static-*","MeshInstance3D",true,false):
		var result=ArrayMesh.new()
		var changed=false
		for surface in range(node.mesh.get_surface_count()):
			var arrays=node.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for i in range(vertices.size()):
				var world=node.global_transform*vertices[i]
				if region.has_point(world):
					vertices[i]=node.global_transform.affine_inverse()*(world+offset)
					changed=true
					moved+=1
			arrays[Mesh.ARRAY_VERTEX]=vertices
			result.add_surface_from_arrays(node.mesh.surface_get_primitive_type(surface),arrays)
			result.surface_set_material(surface,node.get_active_material(surface))
		if changed:node.mesh=result
	var window=game.model.find_child("scanner-red-window",true,false)
	if window:window.get_parent().global_position+=offset
	print("VIDEOCLUB_SCANNER_MOVED vertices=",moved)
static func rear(p:Vector3)->bool:
	return p.z< -6.60 and p.z> -7.125 and p.y<2.35
static func remove_rear_shelves(game)->void:
	var zero:=Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)
	for group in game.dvd_groups.values()+[game.shell]:
		if not group:continue
		for i in range(group.multimesh.instance_count):
			if rear((group.global_transform*group.multimesh.get_instance_transform(i)).origin):group.multimesh.set_instance_transform(i,zero)
	for node in game.model.find_children("*","MeshInstance3D",true,false):
		if str(node.name).begins_with("back-wall-bay-") or rear(node.global_transform*node.get_aabb().get_center()):node.visible=false
		if not str(node.name).begins_with("static-"):continue
		var result:=ArrayMesh.new()
		var changed:=false
		for surface in range(node.mesh.get_surface_count()):
			var a:Array=node.mesh.surface_get_arrays(surface)
			var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
			var idx:PackedInt32Array=a[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				for i in range(v.size()):idx.append(i)
			var kept:=PackedInt32Array()
			for t in range(0,idx.size(),3):
				var center:Vector3=node.global_transform*((v[idx[t]]+v[idx[t+1]]+v[idx[t+2]])/3)
				if not rear(center):kept.append_array(idx.slice(t,t+3))
			if kept.size()!=idx.size():changed=true
			if kept.is_empty():continue
			a[Mesh.ARRAY_INDEX]=kept
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
			result.surface_set_material(result.get_surface_count()-1,node.get_active_material(surface))
		if changed and result.get_surface_count():node.mesh=result
static func apply_surfaces(game)->void:
	var glass:=ShaderMaterial.new()
	glass.shader=load("res://rain_glass.gdshader")
	glass.set_shader_parameter("condensation",load("res://assets/glass-preview/condensation-mixed.png"))
	for node in game.model.find_children("*","MeshInstance3D",true,false):
		for i in range(node.mesh.get_surface_count()):
			var mat=node.get_active_material(i)
			if mat is StandardMaterial3D and mat.resource_name=="material_101":
				node.set_surface_override_material(i,glass)
				var arrays:Array=node.mesh.surface_get_arrays(i)
				var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				if indices.is_empty():
					for k in range(vertices.size()):indices.append(k)
				var kept:=PackedInt32Array()
				for k in range(0,indices.size(),3):
					var center:Vector3=node.global_transform*((vertices[indices[k]]+vertices[indices[k+1]]+vertices[indices[k+2]])/3)
					if absf(center.x+5.76)>.02:kept.append_array(indices.slice(k,k+3))
				if kept.size()<indices.size() and node.mesh.get_surface_count()==1:
					if kept.is_empty():node.visible=false
					else:
						arrays[Mesh.ARRAY_INDEX]=kept
						var mesh:=ArrayMesh.new()
						mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
						node.mesh=mesh
						node.material_override=glass
	# One continuous side pane replaces the four separated side panes, including the corner.
	for node in game.model.find_children("*","MeshInstance3D",true,false):
		if str(node.name).begins_with("rain-window-side"):node.visible=false
	var pane:=MeshInstance3D.new()
	pane.name="CornerWindowPane"
	var quad:=QuadMesh.new()
	quad.size=Vector2(8.76,2.6)
	pane.mesh=quad
	pane.material_override=glass
	pane.position=Vector3(-5.755,1.68,2.80)
	pane.rotation.y=PI/2
	pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(pane)
	var asphalt:=ShaderMaterial.new()
	asphalt.shader=load("res://wet_asphalt.gdshader")
	asphalt.set_shader_parameter("grain_normal",load("res://assets/material-lab/asphalt-normal.png"))
	asphalt.set_shader_parameter("grain_roughness",load("res://assets/material-lab/asphalt-roughness.png"))
	var source=game.model.find_child("wet-parking-lot",true,false)
	if source:
		var original=source.get_active_material(0)
		if original is StandardMaterial3D:asphalt.set_shader_parameter("base_texture",original.albedo_texture)
		source.material_override=asphalt
	var continuation=game.find_child("ContinuousAsphalt",true,false)
	if continuation:continuation.material_override=asphalt


