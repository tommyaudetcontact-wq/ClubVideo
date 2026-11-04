extends SceneTree
func _initialize():
	await process_frame
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	var sign_node=g.model.find_child("open-sign",true,false)
	print("SIGN ",sign_node," basis=",sign_node.global_basis if sign_node else "missing")
	var polish=g.get_node("InteriorPolish")
	print("REFLECTION ",polish.get_node("InteriorCeilingReflection").update_mode," lights=",polish.lamps.size())
	print("MIP_BIAS ",ProjectSettings.get_setting("rendering/textures/default_filters/texture_mipmap_bias"))
	quit(0 if sign_node and polish.lamps.size()==2 else 1)
