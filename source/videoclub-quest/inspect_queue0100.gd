extends SceneTree
func _initialize():
 await process_frame
 var g=load("res://main.tscn").instantiate()
 root.add_child(g)
 g.set_physics_process(false)
 g.clerk.set_physics_process(false)
 g.clerk.customers.set_physics_process(false)
 g.clerk.customers.prepare_queue_positions()
 print("QUEUE ",g.clerk.customers.queue_positions)
 quit()
