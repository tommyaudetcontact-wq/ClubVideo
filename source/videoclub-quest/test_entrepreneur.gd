extends SceneTree
func _initialize():
	set_meta("entrepreneur_mode",true)
	await process_frame
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.entrepreneur!=null)
	print("ENTREPRENEUR_STARTUP_OK")
	quit()
