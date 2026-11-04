extends SceneTree
func _initialize():
	await process_frame
	root.size=Vector2i(1920,1200)
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.origin.transform=Transform3D.IDENTITY
	g.hud.visible=false
	if "--no-cover-lod" in OS.get_cmdline_user_args():g.COVER_DETAIL_BUDGET=0
	g.head.position=Vector3(-4.6,1.72,5.8)
	g.head.look_at(Vector3(1.2,1.65,-1.5))
	g.head.fov=75
	g._play_trailer(0)
	await create_timer(4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../pc-no-lod-interieur.png")
	g.head.position=Vector3(-3.8,1.72,4.5)
	g.head.look_at(Vector3(-5.76,1.6,6.7))
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../pc-no-lod-vitrines.png")
	quit()
