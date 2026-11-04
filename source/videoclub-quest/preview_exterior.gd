extends SceneTree
func _initialize():
 await process_frame
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 game.hud.visible=false
 game.origin.transform=Transform3D.IDENTITY
 game.head.position=Vector3(0,1.65,16)
 game.head.look_at(Vector3(0,5,60))
 game.head.fov=80
 await create_timer(2.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../exterieur-corrige-0.2.1.png")
 quit()
