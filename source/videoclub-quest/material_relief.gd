extends RefCounted
static func apply(model: Node3D) -> void:
	var cache:Dictionary={}
	var normal:Dictionary={}
	var rough:Dictionary={}
	for kind in ["carpet","paint","brushed-metal"]:
		normal[kind]=load("res://assets/material-lab/%s-normal.png"%kind)
		rough[kind]=load("res://assets/material-lab/%s-roughness.png"%kind)
	for node in model.find_children("*","MeshInstance3D",true,false):
		if str(node.name).begins_with("dvd-") or str(node.name).contains("screen"):continue
		for i in range(node.mesh.get_surface_count()):
			var original=node.get_active_material(i)
			if not original is StandardMaterial3D:continue
			var mat:StandardMaterial3D=original
			mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED:
				mat.roughness=maxf(mat.roughness,.40)
				mat.metallic_specular=minf(mat.metallic_specular,.38)
			if mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
			var kind:=""
			if str(node.name).contains("carpet"):kind="carpet"
			elif mat.metallic>.6:kind="brushed-metal"
			elif not mat.albedo_texture and mat.albedo_color.b>mat.albedo_color.r*1.3:kind="paint"
			if kind.is_empty():continue
			if not cache.has(original):
				var enhanced:StandardMaterial3D=original.duplicate()
				enhanced.normal_enabled=true
				enhanced.normal_texture=normal[kind]
				enhanced.normal_scale=.23 if kind=="carpet" else .09
				enhanced.roughness_texture=rough[kind]
				enhanced.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				cache[original]=enhanced
			node.set_surface_override_material(i,cache[original])
