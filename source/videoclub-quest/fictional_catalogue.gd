extends RefCounted
## One shelf batch; readable paper is loaded only for close or handled copies.
const COPIES_PER_TITLE:=16
static func install(game) -> void:
	var entries:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/fictional/catalogue.json"))
	assert(entries.size()==200)
	game.layout.movies=[]
	game.cover_info=[]
	for entry in entries:
		entry.id=game.layout.movies.size()
		game.layout.movies.append(entry)
		game.cover_info.append({"verified":false,"edition":"Jaquette originale fictive"})
	var poster_index:=0
	for node in game.model.find_children("*","MeshInstance3D",true,false):
		if "poster" not in str(node.name).to_lower():continue
		var mat:=StandardMaterial3D.new()
		mat.albedo_texture=load(entries[poster_index%entries.size()].frontCover)
		mat.roughness=.7
		node.material_override=mat
		poster_index+=1

static func attach_records(game) -> void:
	var placements:Array=game.dvd_records.map(func(record):return record.world)
	game.dvd_records.clear()
	game.dvd_grid.clear()
	for old in game.dvd_groups.values():old.hide();old.queue_free()
	game.dvd_groups.clear()
	if game.shell:
		game.shell.hide()
		game.shell.queue_free()
		game.shell=null
	var group:=MultiMeshInstance3D.new()
	group.name="FictionalShelfBatch"
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_custom_data=true
	var mat:=ShaderMaterial.new()
	mat.shader=load("res://fictional_cases.gdshader")
	mat.set_shader_parameter("paper_atlas",load("res://assets/fictional/shelf-atlas.jpg"))
	var box:=BoxMesh.new()
	box.size=Vector3(.135,.19,.014)
	var arrays:Array=box.surface_get_arrays(0)
	var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	for i in uv.size():
		var v:Vector3=vertices[i]
		var local:=Vector2(v.x/.135+.5,.5-v.y/.19)
		var pixel:=Vector2(240,240)
		if normals[i].z>.5:pixel=Vector2(4+local.x*96,4+local.y*136)
		elif normals[i].z<-.5:pixel=Vector2(104+(1-local.x)*96,4+local.y*136)
		elif normals[i].x<-.5:pixel=Vector2(204+(v.z/.014+.5)*16,4+local.y*136)
		uv[i]=pixel/256.0
	arrays[Mesh.ARRAY_TEX_UV]=uv
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,mat)
	mm.mesh=mesh
	var titles:Array=game.layout.movies.filter(func(movie):return movie.get("fictional",false))
	mm.instance_count=titles.size()*COPIES_PER_TITLE if game.entrepreneur_mode else placements.size()
	mm.visible_instance_count=0 if game.entrepreneur_mode else mm.instance_count
	mm.custom_aabb=AABB(Vector3(-6,0,-14.5),Vector3(12,4,24))
	group.multimesh=mm
	group.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(group)
	var zero:=Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)
	for index in mm.instance_count:
		var tile:int=index%titles.size()
		var pose:Transform3D=Transform3D(Basis.IDENTITY,Vector3(0,-20,0)) if game.entrepreneur_mode else placements[index]
		mm.set_instance_transform(index,zero if game.entrepreneur_mode else pose)
		mm.set_instance_custom_data(index,Color((tile%16)/16.0,int(tile/16)/16.0,0,1))
		game.dvd_records.append({"group":group,"index":index,"local":pose,"world":pose,"movie":tile,"shell_index":-1,"id":index,"inverse":pose.affine_inverse(),"clerk_reserved":game.entrepreneur_mode})
		if not game.entrepreneur_mode:
			var cell:=Vector2i(floori(pose.origin.x/2),floori(pose.origin.z/2))
			if not game.dvd_grid.has(cell):game.dvd_grid[cell]=[]
			game.dvd_grid[cell].append(index)
	print("FICTIONAL_CATALOGUE titles=",titles.size()," batched_copies=",mm.instance_count)
