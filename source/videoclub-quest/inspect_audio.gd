extends SceneTree
func _initialize():
 await process_frame
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 var modes=game.modes
 var original=modes.trailers_muted
 modes._activate(7)
 var changed=game.trailer_player.volume==0 if modes.trailers_muted else game.trailer_player.volume>0
 var config=ConfigFile.new()
 config.load("user://audio-settings.cfg")
 var saved=config.get_value("audio","trailers_muted")==modes.trailers_muted
 modes._activate(7)
 var restored=modes.trailers_muted==original
 modes.toggle_pause()
 var label=modes.labels[7]
 var hit=modes._menu_hit(label.global_position+ modes.panel.global_basis.z, -modes.panel.global_basis.z)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../options-058-preview.png")
 modes._activate(8)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../save-058-preview.png")
 print("AUDIO_OPTION changed=",changed," saved=",saved," restored=",restored," hit=",hit)
 quit(0 if changed and saved and restored and hit==7 else 1)
