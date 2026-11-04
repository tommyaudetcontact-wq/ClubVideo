extends RefCounted
static func expand(game) -> void:
	if game.layout.movies.size()<24:return
	for id in range(12):
		var source:MultiMeshInstance3D=game.dvd_groups[id]
		var transforms:Array=[]
		for i in range(source.multimesh.instance_count):transforms.append(source.multimesh.get_instance_transform(i))
		var mesh:Mesh=source.multimesh.mesh
		for half in range(2):
			var out:=MultiMesh.new()
			out.transform_format=MultiMesh.TRANSFORM_3D
			var geometry:=ArrayMesh.new()
			for surface in range(mesh.get_surface_count()):
				var arrays:Array=mesh.surface_get_arrays(surface)
				var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
				for i in range(uv.size()):uv[i].y=uv[i].y*.5+(.5 if half==0 else 0.0)
				arrays[Mesh.ARRAY_TEX_UV]=uv
				geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				geometry.surface_set_material(surface,game.dvd_atlas_material)
			out.mesh=geometry
			var count:int=(transforms.size()+1-half)/2
			out.instance_count=count
			for i in range(count):out.set_instance_transform(i,transforms[i*2+half])
			if half==0:source.multimesh=out
			else:
				var node:=MultiMeshInstance3D.new()
				node.name="ExpandedDVD%d"%(id+12)
				node.multimesh=out
				node.transform=source.transform
				node.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
				node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				source.get_parent().add_child(node)
				game.dvd_groups[id+12]=node
