extends Node3D

func build(model: Node3D) -> void:
	name = "ExteriorContinuation"
	var source := model.find_child("wet-parking-lot",true,false) as MeshInstance3D
	var material: StandardMaterial3D
	if source and source.get_active_material(0) is StandardMaterial3D:
		material = source.get_active_material(0).duplicate()
	else:
		material = StandardMaterial3D.new()
		material.albedo_color = Color("171b22")
		material.roughness = 0.6
	# Continue the same asphalt texture and density, slightly below its top face.
	material.uv1_scale = Vector3(800.0/6.9,800.0/6.0,1.0)
	material.uv1_offset = Vector3(5.0-400.0/6.9,8.0-400.0/6.0,0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var plane := PlaneMesh.new()
	plane.size = Vector2(800,800)
	var ground := MeshInstance3D.new()
	ground.name = "ContinuousAsphalt"
	ground.mesh = plane
	ground.material_override = material
	ground.position.y = -0.077
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(ground)
