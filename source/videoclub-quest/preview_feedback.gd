extends SceneTree
func _initialize():
	await process_frame
	root.size=Vector2i(1600,1000)
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.hud.visible=false
	g.origin.transform=Transform3D.IDENTITY
	g.head.position=Vector3(0,1.6,5.5)
	g.head.look_at(Vector3(0,1.6,4.65))
	g.head.fov=40
	var items=[]
	for i in range(3):
		var item=g.held_pool[[48,54,0][i]]
		item.visible=true
		item.global_transform=Transform3D(Basis(Vector3.UP,.15 if i==0 else -.15 if i==2 else 0),Vector3((i-1)*.19,1.6,4.65))
		items.append(item)
	await create_timer(2).timeout
	root.get_texture().get_image().save_png("res://../boitiers-detailles-044.png")
	for item in items:item.rotate_y(PI)
	await create_timer(.5).timeout
	root.get_texture().get_image().save_png("res://../dos-boitiers-044.png")
	for item in items:item.visible=false
	g.head.position=Vector3(-3.8,1.65,5.2)
	g.head.look_at(Vector3(-5.76,1.7,7.0))
	g.head.fov=75
	await create_timer(.5).timeout
	root.get_texture().get_image().save_png("res://../vitre-coin-044.png")
	g.head.position=Vector3(1,1.65,6.5)
	g.head.look_at(Vector3(-2,2,24))
	await create_timer(.5).timeout
	root.get_texture().get_image().save_png("res://../brume-exterieure-044.png")
	g.head.position=Vector3(-22.5,2.5,19)
	g.head.look_at(Vector3(-26,3.5,14))
	await create_timer(.5).timeout
	root.get_texture().get_image().save_png("res://../arbre-044.png")
	quit()
