extends SceneTree
func _initialize():
 await process_frame
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 game.model.visible=false
 game.get_node("SimulatedLightGlow").visible=false
 game.origin.transform=Transform3D.IDENTITY
 game.head.position=Vector3(0,0.40,0.32)
 game.head.look_at(Vector3(0,0,-0.10))
 game.head.fov=42
 game.hud.visible=false
 game.hands[0].position=Vector3(-0.075,0,0)
 game.hand_visuals[0].visible=true
 game.hand_visuals[1].visible=false
 for record in game.dvd_records:
  if record.movie==11:
   game._take(record,0,true)
   break
 game.hand_visuals[0].update_grip(0.2,0.0,0.65,true)
 await create_timer(1.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../prise-boitier-0.1.9.png")
 quit()
