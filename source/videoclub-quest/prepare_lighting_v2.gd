extends SceneTree

func _initialize() -> void:
	await process_frame
	var scene := Node3D.new()
	scene.name = "BakedClub"
	root.add_child(scene)
	var decor: Node3D = load("res://assets/decor.glb").instantiate()
	scene.add_child(decor)
	decor.scene_file_path = ""
	load("res://scene_refresh.gd").remove_rear_shelves({"dvd_groups":{},"shell":null,"model":decor})
	load("res://material_relief.gd").apply(decor)
	var count := 0
	for node in decor.find_children("*","",true,false):
		if node is Light3D:
			node.visible = false
		if node is MeshInstance3D:
			node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			if node.name.begins_with("static-") and node.get_aabb().end.z<8.0:
				node.mesh = node.mesh.duplicate()
				var result: int = node.mesh.lightmap_unwrap(node.global_transform,0.04)
				if result==OK:
					node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
					count += 1
	print("LIGHTMAP_UV_MESHES=",count)
	for z in [-4.5,0.3,4.5]:
		for x in [-3.9,0.0,3.9]:
			var lamp := SpotLight3D.new()
			lamp.name = "BakedCeilingLamp"
			lamp.position = Vector3(x,3.12,z)
			lamp.rotation_degrees.x = -90
			lamp.light_color = Color("fff2df")
			lamp.light_energy = 4.8
			lamp.spot_range = 5.0
			lamp.spot_angle = 72.0
			lamp.light_size = 0.65
			lamp.light_bake_mode = Light3D.BAKE_STATIC
			lamp.shadow_enabled = true
			scene.add_child(lamp)
	var gi := LightmapGI.new()
	gi.name = "BakedLightmapGI"
	gi.quality = LightmapGI.BAKE_QUALITY_HIGH
	gi.bounces = 4
	gi.directional = true
	gi.denoiser_strength = 0.1
	gi.max_texture_size = 2048
	gi.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_SUBDIV_8
	gi.environment_mode = LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR
	gi.environment_custom_color = Color("758399")
	gi.environment_custom_energy = 0.20
	DirAccess.make_dir_recursive_absolute("res://assets/lighting-v2")
	var data := LightmapGIData.new()
	ResourceSaver.save(data,"res://assets/lighting-v2/club.lmbake")
	data.take_over_path("res://assets/lighting-v2/club.lmbake")
	gi.light_data = data
	scene.add_child(gi)
	for child in scene.find_children("*","",true,false):
		child.scene_file_path = ""
		child.owner = scene
	var packed := PackedScene.new()
	packed.pack(scene)
	var result := ResourceSaver.save(packed,"res://lighting_bake_v2.tscn")
	print("LIGHTMAP_SCENE_SAVED=",result)
	quit(result)
