extends SceneTree
func _initialize():
	await process_frame
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	print("DVD samples ",g.dvd_records[0].world.origin)
	for node in g.model.find_children("*","MeshInstance3D",true,false):
		if str(node.name).contains("back-wall") or str(node.name).contains("rain-window") or str(node.name).contains("static-"):
			print(node.name," pos=",node.global_position," box=",node.get_aabb()," mat=",node.get_active_material(0).get_class())
	g.hud.visible=false
	g.head.global_position=Vector3(2.9,1.7,-2.6)
	g.head.look_at(Vector3(0,1.4,-7))
	await create_timer(1).timeout
	root.get_texture().get_image().save_png("res://../comptoir-031.png")
	g.head.global_position=Vector3(-2,1.6,4)
	g.head.look_at(Vector3(-1,1.7,9))
	await create_timer(1).timeout
	root.get_texture().get_image().save_png("res://../vitres-pluie-031.png")
	quit()
