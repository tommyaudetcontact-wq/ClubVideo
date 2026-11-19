extends SceneTree
func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	var peer=load("res://club_peer_pose.gd")
	var a=peer.new()
	var b=peer.new()
	game.add_child(a)
	game.add_child(b)
	a.receive([[-1.8,1.64,5.0,0.0,0.0,0.0],[-2.04,1.16,4.69,0.0,0.0,0.0],[-1.57,1.25,4.61,-.3,.2,0.0]],{"clerk_model":0})
	b.receive([[-.9,1.58,5.0,0.0,0.0,0.0]],{"clerk_model":1})
	game.head.global_position=Vector3(-1.35,1.12,2.45)
	game.head.look_at(Vector3(-1.35,.92,5.0))
	game.touch_controls.buttons.hide()
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../../work/commis-coop-080.png")
	quit()

