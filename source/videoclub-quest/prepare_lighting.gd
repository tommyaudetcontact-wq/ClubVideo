extends SceneTree

func _initialize() -> void:
	await process_frame
	var scene := Node3D.new()
	scene.name = "BakedClub"
	root.add_child(scene)
	var decor: Node3D = load("res://assets/decor.glb").instantiate()
	scene.add_child(decor)
	decor.scene_file_path = ""
	var count := 0
	for node in decor.find_children("*","",true,false):
		if node is Light3D:
			node.visible = false
		if node is MeshInstance3D:
			node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			if node.name.begins_with("static-") and node.get_aabb().end.z<8.0:
				node.mesh = node.mesh.duplicate()
				var result: int = node.mesh.lightmap_unwrap(node.global_transform,0.12)
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
			lamp.light_color = Color("ffe9cb")
			lamp.light_energy = 12.0
			lamp.spot_range = 5.0
			lamp.spot_angle = 76.0
			lamp.light_size = 0.45
			lamp.light_bake_mode = Light3D.BAKE_STATIC
			lamp.shadow_enabled = true
			scene.add_child(lamp)
	var gi := LightmapGI.new()
	gi.name = "BakedLightmapGI"
	gi.quality = LightmapGI.BAKE_QUALITY_MEDIUM
	gi.bounces = 3
	gi.max_texture_size = 2048
	gi.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_SUBDIV_8
	gi.environment_mode = LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR
	gi.environment_custom_color = Color("758399")
	gi.environment_custom_energy = 0.30
	DirAccess.make_dir_recursive_absolute("res://assets/lighting")
	var data := LightmapGIData.new()
	ResourceSaver.save(data,"res://assets/lighting/club.lmbake")
	data.take_over_path("res://assets/lighting/club.lmbake")
	gi.light_data = data
	scene.add_child(gi)
	for child in scene.find_children("*","",true,false):
		child.scene_file_path = ""
		child.owner = scene
	var packed := PackedScene.new()
	packed.pack(scene)
	var result := ResourceSaver.save(packed,"res://lighting_bake.tscn")
	print("LIGHTMAP_SCENE_SAVED=",result)
	quit(result)
