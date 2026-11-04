extends SceneTree
func _initialize():
 await process_frame
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 game.hud.visible=false
 game.origin.transform=Transform3D.IDENTITY
 var screen=game.screens[0]
 game.head.position=screen.global_position+screen.global_basis.z.normalized()*1.35
 game.head.look_at(screen.global_position)
 game.head.fov=55
 for record in game.dvd_records:
  if record.movie==11:
   game._take(record,1,false)
   break
 game.held.visible=false
 await create_timer(8.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tv-bande-annonce-0.2.0.png")
 print("VIDEO_REVIEW_TIME=",game.trailer_player.stream_position)
 quit()
