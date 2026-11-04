extends SceneTree
func _initialize():
	var packed=load("res://assets/decor.glb") as PackedScene
	if not packed:
		quit(1)
		return
	var model=packed.instantiate()
	root.add_child(model)
	var counts={}
	for node in model.find_children("*", "", true, false):
		var type=node.get_class()
		counts[type]=counts.get(type,0)+1
		if node is MultiMeshInstance3D or str(node.name).begins_with("dvd-") or str(node.name).contains("curved-screen"):
			print("PART ",node.name," ",type," ",node.multimesh.instance_count if node is MultiMeshInstance3D else "")
	print("COUNTS ",counts)
	quit()

