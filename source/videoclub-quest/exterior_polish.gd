extends RefCounted

static func apply(game)->void:
	var shader=load("res://exterior_haze.gdshader")
	var cache={}
	var backface_shader:=Shader.new()
	backface_shader.code=shader.code.replace("cull_disabled","cull_back")
	for node in game.model.find_children("*","MeshInstance3D",true,false):
		var bounds:AABB=node.global_transform*node.get_aabb()
		var center=bounds.get_center()
		if str(node.name).begins_with("tree-crown"):
			node.visible=false
			continue
		if center.z<7.21 and absf(center.x)<5.81:continue
		if str(node.name).contains("wet-parking"):continue
		for i in range(node.mesh.get_surface_count()):
			var original=node.get_active_material(i)
			if not original is StandardMaterial3D:continue
			if original.resource_name=="material_82":
				var puddle:StandardMaterial3D=original.duplicate()
				puddle.albedo_color.a=.10
				puddle.roughness=.42
				node.set_surface_override_material(i,puddle)
				continue
			if original.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
			if not cache.has(original):
				var m=ShaderMaterial.new()
				m.shader=backface_shader if original.cull_mode==BaseMaterial3D.CULL_BACK else shader
				m.set_shader_parameter("tint",original.albedo_color)
				m.set_shader_parameter("textured",original.albedo_texture!=null)
				if original.albedo_texture:m.set_shader_parameter("base_texture",original.albedo_texture)
				m.set_shader_parameter("vertex_color",original.vertex_color_use_as_albedo)
				m.set_shader_parameter("uv_scale",original.uv1_scale)
				m.set_shader_parameter("uv_offset",original.uv1_offset)
				m.set_shader_parameter("surface_roughness",original.roughness)
				m.set_shader_parameter("surface_metallic",original.metallic)
				m.set_shader_parameter("glow",Vector3(original.emission.r,original.emission.g,original.emission.b)*original.emission_energy_multiplier if original.emission_enabled else Vector3.ZERO)
				if original.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED:
					m.set_shader_parameter("glow",Vector3(original.albedo_color.r,original.albedo_color.g,original.albedo_color.b)*2.0)
				cache[original]=m
			node.set_surface_override_material(i,cache[original])
	_trees(game)

static func _trees(game)->void:
	var mat=ShaderMaterial.new()
	mat.shader=load("res://exterior_foliage.gdshader")
	mat.set_shader_parameter("leaves",load("res://assets/exterior/branch-leaves.png"))
	var leaf=QuadMesh.new()
	leaf.size=Vector2(1.45,.52)
	leaf.material=mat
	var mm=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=leaf
	mm.instance_count=384
	var rng=RandomNumberGenerator.new()
	rng.seed=82005
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cursor=0
	for x in [-26.0,26.0]:
		for b in range(24):
			var tier=b/8
			var a=b*TAU/8+float(tier)*.35
			var radial=Vector3(cos(a),0,sin(a))
			var start=Vector3(x,2.65+tier*.6,14)
			var end=start+radial*(1.45-tier*.25)+Vector3.UP*.9
			var branch=CylinderMesh.new()
			branch.top_radius=.018
			branch.bottom_radius=.075
			branch.height=start.distance_to(end)
			branch.radial_segments=6
			branch.rings=1
			var y=(end-start).normalized()
			var side=y.cross(Vector3.FORWARD).normalized()
			st.append_from(branch,0,Transform3D(Basis(side,y,side.cross(y)),(start+end)*.5))
			for i in range(8):
				var pos=start.lerp(end,.45+float(i%4)*.17)
				pos+=Vector3(rng.randf_range(-.2,.2),rng.randf_range(-.15,.25),rng.randf_range(-.2,.2))
				var card_basis=Basis(-radial,Vector3.UP,(-radial).cross(Vector3.UP))
				card_basis=card_basis*Basis.from_euler(Vector3(.3 if i<4 else -.5,0,rng.randf_range(-.45,.45)))
				mm.set_instance_transform(cursor,Transform3D(card_basis,pos))
				cursor+=1
	var leaves=MultiMeshInstance3D.new()
	leaves.name="PhotographicLeafCards"
	leaves.multimesh=mm
	leaves.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(leaves)
	var branches=MeshInstance3D.new()
	branches.name="TreeBranches3D"
	branches.mesh=st.commit()
	var bark=StandardMaterial3D.new()
	bark.albedo_color=Color("303b36")
	bark.roughness=.95
	branches.material_override=bark
	branches.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(branches)
