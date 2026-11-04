extends SceneTree
func _initialize():
 await process_frame
 root.size=Vector2i(1600,1000)
 var g=load("res://main.tscn").instantiate()
 root.add_child(g)
 await process_frame
 g.hud.visible=false
 g.head.global_position=Vector3(-3.9,1.65,5.6)
 g.head.look_at(Vector3(0,1.5,-3.5))
 await create_timer(3).timeout
 root.get_texture().get_image().save_png("res://../eclairage-interieur-v2.png")
 quit()
