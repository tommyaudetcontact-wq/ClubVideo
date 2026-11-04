extends SceneTree
func sample(g,label):
	for i in range(30):await process_frame
	var gpu=[]
	for i in range(60):
		await process_frame
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	gpu.sort()
	print("PROFILE ",label," gpu_median=",gpu[30]," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
func _initialize():
	await process_frame
	root.size=Vector2i(2184,2288)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.origin.transform=Transform3D.IDENTITY
	g.head.position=Vector3(-3.8,1.7,4.9)
	g.head.look_at(Vector3(2,1.7,-3))
	await sample(g,"baseline")
	g.get_node("InteriorPolish").visible=false
	await sample(g,"no_local_lights_or_probe")
	g.get_node("InteriorPolish").visible=true
	g.get_node("SimulatedLightGlow").visible=false
	await sample(g,"no_glow")
	g.get_node("SimulatedLightGlow").visible=true
	for n in g.modes.rain_nodes:n.visible=false
	await sample(g,"no_rain_particles")
	for n in g.modes.rain_nodes:n.visible=true
	g.head.look_at(Vector3(-5.76,1.7,6.7))
	await sample(g,"windows_baseline")
	quit()
