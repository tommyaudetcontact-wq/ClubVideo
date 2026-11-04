extends SceneTree
func _initialize()->void:
	var model=load("res://assets/spiral-machine.glb").instantiate()
	root.add_child(model)
	var stock:MeshInstance3D=model.find_child("gum-fill",true,false)
	var mat:StandardMaterial3D=stock.get_active_material(0)
	var arrays:Array=stock.mesh.surface_get_arrays(0)
	print("VERTEX_COLORS count=",arrays[Mesh.ARRAY_COLOR].size()," first=",arrays[Mesh.ARRAY_COLOR][0]," enabled=",mat.vertex_color_use_as_albedo)
	quit()
