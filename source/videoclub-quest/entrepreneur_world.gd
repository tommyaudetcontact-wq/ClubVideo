extends RefCounted
const Props=preload("res://clerk_props.gd")

static func empty_shop(game) -> void:
	var bays:Array[AABB]=[]
	for box in game.layout.colliders:
		var a:=Vector3(box.min[0],box.min[1],box.min[2])
		var b:=Vector3(box.max[0],box.max[1],box.max[2])
		if a.y==0 and b.y<2 and a.z<4 and b.z>0 and absf(a.x)<4:
			bays.append(AABB(a-Vector3(.15,0,.25),b-a+Vector3(.3,.5,.5)))
	bays.append(AABB(Vector3(-5.64,.05,-6.5),Vector3(.55,2.5,13)))
	bays.append(AABB(Vector3(5.09,.05,-6.5),Vector3(.55,2.5,13)))
	for node in game.model.find_children("*","MeshInstance3D",true,false):
		if not node.mesh:continue
		var result:=ArrayMesh.new()
		var changed:=false
		for surface in node.mesh.get_surface_count():
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			if arrays.is_empty():continue
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():
				for index in vertices.size():indices.append(index)
			var kept:=PackedInt32Array()
			for triangle in range(0,indices.size(),3):
				var center:Vector3=node.global_transform*((vertices[indices[triangle]]+vertices[indices[triangle+1]]+vertices[indices[triangle+2]])/3)
				var old_rear:=absf(center.x)<5.9 and center.z< -9.3 and center.z> -9.8 and center.y>.05
				# Keep the carpet at y=0, but remove low feet and plinth triangles too.
				var shelf:=old_rear or (center.y>.001 and bays.any(func(bounds):return bounds.has_point(center)))
				if shelf:changed=true
				else:kept.append_array(indices.slice(triangle,triangle+3))
			if kept.is_empty():continue
			arrays[Mesh.ARRAY_INDEX]=kept
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			result.surface_set_material(result.get_surface_count()-1,node.get_active_material(surface))
		if changed:
			if result.get_surface_count():node.mesh=result
			else:node.hide()
	game.layout.colliders=game.layout.colliders.filter(func(box):return not (box.max[1]<2 and box.min[2]<4 and box.max[2]>0 and absf(box.min[0])<4))

static func solid(parent:Node3D,position:Vector3,size:Vector3,color:String) -> Node3D:
	var body:=StaticBody3D.new()
	parent.add_child(body)
	body.position=position
	Props.box(body,Vector3.ZERO,size,color)
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collider.shape=shape
	body.add_child(collider)
	return body

static func shelf(parent:Node3D,columns:int) -> Node3D:
	var node:=Node3D.new()
	parent.add_child(node)
	var width:=columns*.145+.06
	# Laminate cabinet, wood edges, steel foot levellers, and recessed screws.
	Props.box(node,Vector3(0,.92,-.155),Vector3(width,1.82,.018),"333a42")
	for side in [-1,1]:
		Props.box(node,Vector3(side*(width/2-.013),.92,0),Vector3(.026,1.84,.34),"b58b5b")
		for z in [-.10,.10]:
			Props.cylinder(node,Vector3(side*(width/2-.04),.035,z),.025,.06,"252a30",.7)
	for row in range(5):
		var height:=.20+row*.35
		Props.box(node,Vector3(0,height,0),Vector3(width,.024,.34),"ac8155")
		Props.box(node,Vector3(0,height+.012,.17),Vector3(width,.033,.012),"262d37")
		for side in [-1,1]:
			var screw:=Props.cylinder(node,Vector3(side*(width/2+.002),height,0),.007,.003,"91989c",.8)
			screw.rotation.z=PI/2
	Props.box(node,Vector3(0,1.73,.18),Vector3(width,.16,.02),"182d55")
	# Batch the static cabinet while preserving the different metal/laminate response.
	batch_props(node)
	Props.label(node,"VIDÉO CLUB",Vector3(0,1.73,.194),.0006,28).name="CategoryHeader"
	return node

static func batch_props(parent:Node3D) -> void:
	var batches:Dictionary={}
	var parts:Array=[]
	for child in parent.get_children():
		if not child is MeshInstance3D or not child.material_override is StandardMaterial3D:continue
		var material:StandardMaterial3D=child.material_override
		var key:="%s|%s"%[material.metallic,material.roughness]
		if not batches.has(key):
			var tool:=SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var merged_material:=material.duplicate()
			merged_material.albedo_color=Color.WHITE
			merged_material.vertex_color_use_as_albedo=true
			merged_material.vertex_color_is_srgb=true
			batches[key]={"tool":tool,"material":merged_material}
		var tool:SurfaceTool=batches[key].tool
		for surface in child.mesh.get_surface_count():
			var arrays:Array=child.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():
				for index in vertices.size():indices.append(index)
			for index in indices:
				tool.set_color(material.albedo_color)
				tool.set_normal((child.basis.inverse().transposed()*normals[index]).normalized())
				tool.add_vertex(child.transform*vertices[index])
		parts.append(child)
	for batch in batches.values():
		var mesh:=MeshInstance3D.new()
		mesh.mesh=batch.tool.commit()
		mesh.material_override=batch.material
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mesh)
	for part in parts:parent.remove_child(part);part.queue_free()

static func parcel(parent:Node3D,position:Vector3,caption:String,long_box:bool=false) -> Node3D:
	var node:=Node3D.new()
	parent.add_child(node)
	node.position=position
	var size:=Vector3(.65,.22,.36) if long_box else Vector3(.36,.26,.28)
	Props.box(node,Vector3.ZERO,size,"ad8558")
	Props.box(node,Vector3(0,size.y*.5+.001,0),Vector3(.046,.002,size.z),"d4bd8d")
	Props.box(node,Vector3(0,0,size.z*.5+.001),Vector3(.046,size.y,.002),"d4bd8d")
	Props.box(node,Vector3(size.x*.2,size.y*.5+.003,0),Vector3(.13,.002,.10),"ede7d7")
	for stripe in range(8):
		Props.box(node,Vector3(size.x*.2-.04+stripe*.012,size.y*.5+.005,0),Vector3(.003,.002,.06),"393832")
	Props.label(node,caption,Vector3(0,.025,size.z*.5+.004),.0005,24)
	return node

static func drill(parent:Node3D) -> Node3D:
	var node:=Node3D.new()
	parent.add_child(node)
	Props.box(node,Vector3(0,.015,0),Vector3(.075,.09,.14),"d1a02b")
	Props.cylinder(node,Vector3(0,.015,-.075),.035,.06,"313942",.6).rotation.x=PI/2
	Props.cylinder(node,Vector3(0,.015,-.13),.003,.06,"afb6b9",.8).rotation.x=PI/2
	Props.box(node,Vector3(0,-.065,.035),Vector3(.05,.12,.06),"242c31")
	Props.box(node,Vector3(0,-.13,.025),Vector3(.09,.035,.08),"303940")
	for index in range(4):Props.box(node,Vector3(.039,.025,-.035+index*.017),Vector3(.002,.025,.005),"22282d")
	return node

static func office_monitor(parent:Node3D) -> Node3D:
	var node:=Node3D.new();parent.add_child(node)
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:Array=[]
	for section in [Vector3(.278,.235,.225),Vector3(.270,.228,.10),Vector3(.145,.147,-.22)]:
		var ring:PackedVector3Array=[]
		for corner in 4:
			var center:=Vector2((1 if corner in [0,3] else -1)*(section.x-.025),(1 if corner<2 else -1)*(section.y-.025))
			for step in 5:
				var angle:=corner*PI/2+step*PI/8
				ring.append(Vector3(center.x+cos(angle)*.025,center.y+sin(angle)*.025,section.z))
		rings.append(ring)
	for section in range(rings.size()-1):
		for index in rings[section].size():
			var next: int=(index+1)%rings[section].size()
			triangle(tool,rings[section][index],rings[section+1][index],rings[section][next])
			triangle(tool,rings[section][next],rings[section+1][index],rings[section+1][next])
	for index in rings.back().size():triangle(tool,Vector3(0,0,-.22),rings.back()[(index+1)%rings.back().size()],rings.back()[index])
	var shell:=MeshInstance3D.new();shell.mesh=tool.commit()
	var plastic:=StandardMaterial3D.new();plastic.albedo_color=Color("bdbba7");plastic.roughness=.48
	shell.material_override=plastic;node.add_child(shell)
	# Recessed dark gasket, a wide lower bezel, power control and indicator.
	for side in [-1,1]:Props.box(node,Vector3(side*.237,.025,.228),Vector3(.025,.343,.014),"676961")
	Props.box(node,Vector3(0,.201,.228),Vector3(.45,.022,.014),"676961")
	Props.box(node,Vector3(0,-.152,.228),Vector3(.45,.022,.014),"676961")
	Props.box(node,Vector3(0,-.192,.23),Vector3(.50,.05,.018),"b7b49e")
	var power:=Props.cylinder(node,Vector3(.204,-.191,.244),.013,.007,"898e84");power.rotation.x=PI/2
	Props.box(node,Vector3(.171,-.19,.246),Vector3(.008,.005,.004),"7cbb7a")
	for index in range(4):Props.box(node,Vector3(.045+index*.026,-.19,.243),Vector3(.014,.008,.007),"8e9389")
	# Ventilation follows the taper on the rear shell. All slots share a material draw.
	for index in range(14):
		var z:float=.06-index*.017
		var half_width:float=lerpf(.270,.145,(.10-z)/.32)
		for side in [-1,1]:
			var slot:=Props.box(node,Vector3(side*(half_width+.001),.055,z),Vector3(.002,.105,.006),"4a4f48")
			slot.rotation.y=side*.37
	Props.box(node,Vector3(0,-.075,-.224),Vector3(.16,.095,.008),"53594f")
	Props.box(node,Vector3(-.025,-.08,-.23),Vector3(.048,.017,.01),"54749b")
	Props.box(node,Vector3(.046,-.08,-.23),Vector3(.026,.027,.01),"272d2c")
	Props.cylinder(node,Vector3(0,-.29,-.025),.066,.12,"aaa995")
	Props.box(node,Vector3(0,-.355,.015),Vector3(.35,.025,.26),"aead98")
	batch_props(node)
	return node

static func triangle(tool:SurfaceTool,a:Vector3,b:Vector3,c:Vector3) -> void:
	tool.set_normal((b-a).cross(c-a).normalized())
	tool.add_vertex(a);tool.add_vertex(b);tool.add_vertex(c)

static func office_keyboard(parent:Node3D) -> Node3D:
	var node:=Node3D.new();parent.add_child(node)
	Props.box(node,Vector3.ZERO,Vector3(.57,.025,.19),"b9b7a7")
	for row in 4:
		for column in 12:
			Props.box(node,Vector3(-.24+column*.039,.019,-.062+row*.033),Vector3(.033,.013,.027),"d8d4c4")
	Props.box(node,Vector3(-.05,.019,.072),Vector3(.25,.013,.024),"d8d4c4")
	batch_props(node)
	return node

static func desk_base(parent:Node3D,center:Vector3,width:float,depth:float,drawers:bool=false) -> void:
	var node:=Node3D.new();parent.add_child(node)
	node.position=Vector3(center.x,0,center.z)
	for side in [-1,1]:
		for end in [-1,1]:Props.box(node,Vector3(side*(width/2-.1),.35,end*(depth/2-.1)),Vector3(.055,.70,.055),"555f62")
	Props.box(node,Vector3(0,.58,-depth/2+.08),Vector3(width-.2,.13,.035),"555f62")
	if drawers:
		Props.box(node,Vector3(width/2-.37,.35,0),Vector3(.55,.69,depth-.15),"b5a68c")
		for row in 3:
			Props.box(node,Vector3(width/2-.37,.13+row*.22,depth/2-.067),Vector3(.51,.20,.018),"c6b79d")
			Props.box(node,Vector3(width/2-.37,.15+row*.22,depth/2-.052),Vector3(.13,.018,.024),"697374")
	batch_props(node)
