extends SceneTree
func _initialize():
 await process_frame
 var g=load("res://main.tscn").instantiate()
 root.add_child(g)
 for id in [0,1,24]:print("BOUNDS ",id," ",g.dvd_groups[id].multimesh.mesh.get_aabb())
 quit()
