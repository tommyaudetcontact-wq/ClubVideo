extends RefCounted
# Shared low-cost materials; only interactive props get individual nodes.
static var materials:Dictionary={}
static func material(color:String,metal:float=0.0)->StandardMaterial3D:
	var key=color+str(metal)
	if not materials.has(key):
		var m=StandardMaterial3D.new()
		m.albedo_color=Color(color)
		m.metallic=metal
		m.roughness=.32 if metal else .65
		materials[key]=m
	return materials[key]
static func box(parent:Node3D,pos:Vector3,size:Vector3,color:String)->MeshInstance3D:
	var n=MeshInstance3D.new()
	var mesh=BoxMesh.new()
	mesh.size=size
	n.mesh=mesh
	n.material_override=material(color)
	n.position=pos
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n
static func cylinder(parent:Node3D,pos:Vector3,radius:float,height:float,color:String,metal:float=0)->MeshInstance3D:
	var n=MeshInstance3D.new()
	var mesh=CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=24
	n.mesh=mesh
	n.material_override=material(color,metal)
	n.position=pos
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n
static func label(parent:Node3D,text:String,pos:Vector3,size:float=.001,font:int=30)->Label3D:
	var n=Label3D.new()
	n.text=text
	n.position=pos
	n.pixel_size=size
	n.font_size=font
	n.outline_size=3
	parent.add_child(n)
	return n
static func rounded(parent:Node3D,pos:Vector3,scale_shape:Vector3,color:String)->MeshInstance3D:
	var n=MeshInstance3D.new()
	var sphere=SphereMesh.new()
	sphere.radius=1
	sphere.height=2
	sphere.radial_segments=20
	sphere.rings=12
	n.mesh=sphere
	n.position=pos
	n.scale=scale_shape
	n.material_override=material(color)
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n
static func customer(parent:Node3D,index:int)->Node3D:
	var n=Node3D.new()
	parent.add_child(n)
	var skin="c99675" if index%2==0 else "82553e"
	rounded(n,Vector3(0,1.16,0),Vector3(.22,.30,.135),"315a83" if index%2==0 else "803b35")
	cylinder(n,Vector3(0,1.51,0),.064,.12,skin)
	rounded(n,Vector3(0,1.68,0),Vector3(.105,.14,.10),skin)
	rounded(n,Vector3(0,1.765,.012),Vector3(.109,.062,.10),"29241e")
	rounded(n,Vector3(0,1.67,-.103),Vector3(.022,.030,.025),skin)
	box(n,Vector3(0,1.625,-.089),Vector3(.039,.007,.012),"63483e")
	for side in [-1,1]:
		box(n,Vector3(side*.044,1.70,-.099),Vector3(.017,.012,.009),"252321")
		var leg=Node3D.new()
		leg.name="Leg"+str(side)
		n.add_child(leg)
		leg.position=Vector3(side*.105,.94,0)
		rounded(leg,Vector3(0,-.38,0),Vector3(.085,.43,.095),"303b4c")
		rounded(leg,Vector3(0,-.87,-.04),Vector3(.09,.07,.15),"272727")
		var arm=Node3D.new()
		arm.name="Arm"+str(side)
		n.add_child(arm)
		arm.position=Vector3(side*.26,1.37,0)
		rounded(arm,Vector3(0,-.18,0),Vector3(.075,.25,.08),"315a83" if index%2==0 else "803b35")
		rounded(arm,Vector3(0,-.45,0),Vector3(.048,.085,.06),skin)
		merge_parts(leg)
		merge_parts(arm)
	merge_parts(n)
	return n
static func merge_parts(parent:Node3D):
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts=[]
	for child in parent.get_children():
		if not child is MeshInstance3D:continue
		parts.append(child)
		for surface in range(child.mesh.get_surface_count()):
			var arrays=child.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for index in indices:
				st.set_color(child.material_override.albedo_color)
				st.set_normal((child.basis.inverse().transposed()*normals[index]).normalized())
				st.add_vertex(child.transform*vertices[index])
	if parts.is_empty():return
	var merged=MeshInstance3D.new()
	merged.mesh=st.commit()
	var mat=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.vertex_color_is_srgb=true
	mat.roughness=.75
	merged.material_override=mat
	merged.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(merged)
	for part in parts:
		parent.remove_child(part)
		part.queue_free()
