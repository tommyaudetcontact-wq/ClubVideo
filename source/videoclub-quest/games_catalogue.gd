extends RefCounted
static func right_aisle(p:Vector3)->bool:
	return p.x>2.45 and p.x<3.65 and p.z> -2.95 and p.z<3.75
static func install(game)->void:
	if not FileAccess.file_exists("res://assets/games.json"):return
	var games:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/games.json"))
	if games.size()!=36:return
	game.layout.movies.append_array(games)
	game.cover_info.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://assets/game-covers.json")))
	var slots:Array=[]
	var zero:=Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)
	for group in game.dvd_groups.values():
		for i in range(group.multimesh.instance_count):
			var xf:Transform3D=group.global_transform*group.multimesh.get_instance_transform(i)
			if xf.basis.determinant()!=0 and right_aisle(xf.origin):
				slots.append(xf)
				group.multimesh.set_instance_transform(i,zero)
	if game.shell:
		for i in range(game.shell.multimesh.instance_count):
			if right_aisle((game.shell.global_transform*game.shell.multimesh.get_instance_transform(i)).origin):game.shell.multimesh.set_instance_transform(i,zero)
	slots.sort_custom(func(a,b):
		if not is_equal_approx(a.origin.z,b.origin.z):return a.origin.z<b.origin.z
		return a.origin.y<b.origin.y)
	var placements:Dictionary={}
	for id in range(24,60):placements[id]=[]
	var counts:=[0,0,0,0,0,0]
	for xf in slots:
		var platform:int
		if xf.origin.z>3.2:platform=(counts.reduce(func(a,b):return a+b,0))%6
		else:platform=clampi(int(floor((xf.origin.z+2.95)/2.1)),0,2)+(0 if xf.origin.x>3.05 else 3)
		var id:int=24+platform*6+(counts[platform]%6)
		counts[platform]+=1
		if platform==5:xf.origin.y-=.01
		placements[id].append(xf)
	var material:=StandardMaterial3D.new()
	material.albedo_texture=load("res://assets/game-atlas.png")
	material.roughness=.65
	material.metallic_specular=.12
	material.shading_mode=BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for r in games:
		var id:int=r.id
		var node:=MultiMeshInstance3D.new()
		node.name="GameCases%d"%id
		var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=_case_mesh(id-24,float(r.caseHeight),material)
		mm.instance_count=placements[id].size()
		for i in range(mm.instance_count):mm.set_instance_transform(i,placements[id][i])
		node.multimesh=mm
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
		game.add_child(node)
		game.dvd_groups[id]=node
	_signs(game)
	print("VIDEOCLUB_GAME_AISLE rightmost=true games=36 cases=",slots.size()," platforms=",counts)
static func _case_mesh(tile:int,height:float,material:Material)->ArrayMesh:
	var box:=BoxMesh.new()
	box.size=Vector3(.135,height,.014)
	var a:Array=box.surface_get_arrays(0)
	var uv:PackedVector2Array=a[Mesh.ARRAY_TEX_UV]
	var normals:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
	var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
	var tile_pos:=Vector2((tile%4)*512,floori(tile/4.0)*512)
	for i in range(uv.size()):
		var v:Vector3=vertices[i]
		var local:=Vector2(v.x/.135+.5,.5-v.y/height)
		var px:=Vector2(482,470)
		if normals[i].z>.5:px=Vector2(4+local.x*212,4+local.y*304)
		elif normals[i].z<-.5:px=Vector2(220+(1.0-local.x)*212,4+local.y*304)
		elif absf(normals[i].x)>.5:px=Vector2(438+(v.z/.014+.5)*28,4+local.y*304)
		uv[i]=(tile_pos+px)/Vector2(2048,4608)
	a[Mesh.ARRAY_TEX_UV]=uv
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	mesh.surface_set_material(0,material)
	return mesh
static func _signs(game)->void:
	var material:=StandardMaterial3D.new()
	material.albedo_texture=load("res://assets/game-endcap-sign.png")
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for node in game.model.find_children("endcap-category*","MeshInstance3D",true,false):
		if absf((node.global_transform*node.get_aabb().get_center()).x-3.05)<.2:node.material_override=material
	for back in [false,true]:
		var panel:=MeshInstance3D.new()
		panel.name="GameEndcapSign"
		var quad:=QuadMesh.new()
		quad.size=Vector2(.84,.19)
		panel.mesh=quad
		panel.material_override=material
		panel.position=Vector3(3.05,1.78,-2.843 if back else 3.431)
		panel.rotation.y=PI if back else 0.0
		panel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.add_child(panel)
	var a:Array=[]
	a.resize(Mesh.ARRAY_MAX)
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	var indices:=PackedInt32Array()
	for platform in range(6):
		var quad:=QuadMesh.new()
		quad.size=Vector2(1.65,.17)
		var source:Array=quad.surface_get_arrays(0)
		var basis:=Basis(Vector3.UP,PI/2 if platform<3 else -PI/2)
		var pos:=Vector3(3.43 if platform<3 else 2.67,1.85,-1.8+(platform%3)*2.1)
		var base:=vertices.size()
		for i in range(4):
			vertices.append(basis*source[Mesh.ARRAY_VERTEX][i]+pos)
			normals.append(basis*source[Mesh.ARRAY_NORMAL][i])
			uvs.append(Vector2(source[Mesh.ARRAY_TEX_UV][i].x,(source[Mesh.ARRAY_TEX_UV][i].y+platform)/6.0))
		for index in source[Mesh.ARRAY_INDEX]:indices.append(base+index)
	a[Mesh.ARRAY_VERTEX]=vertices
	a[Mesh.ARRAY_NORMAL]=normals
	a[Mesh.ARRAY_TEX_UV]=uvs
	a[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	var mat:=material.duplicate()
	mat.albedo_texture=load("res://assets/game-section-signs.png")
	mesh.surface_set_material(0,mat)
	var signs:=MeshInstance3D.new()
	signs.name="SixConsoleSections"
	signs.mesh=mesh
	signs.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(signs)
