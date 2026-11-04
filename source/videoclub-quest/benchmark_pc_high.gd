extends SceneTree
var results=[]
func sample(g,label,eye,target):
	g.head.position=eye
	g.head.look_at(target)
	g._update_cover_lod(eye,true)
	for i in range(120):await process_frame
	var gpu=[]
	var cpu=[]
	for i in range(180):
		await process_frame
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
	gpu.sort()
	cpu.sort()
	var row={"view":label,"gpuMedianMs":gpu[90],"gpuP95Ms":gpu[171],"cpuMedianMs":cpu[90],"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	results.append(row)
	print("PC_HIGH_PROFILE ",JSON.stringify(row))
func _initialize():
	await process_frame
	root.size=Vector2i(2448,2448)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.origin.transform=Transform3D.IDENTITY
	g._play_trailer(0)
	await sample(g,"aisles_video",Vector3(-3.8,1.7,4.9),Vector3(2,1.7,-3))
	await sample(g,"counter",Vector3(0,1.7,-3),Vector3(3,1.4,-5.5))
	await sample(g,"wet_windows",Vector3(-3.8,1.7,4.9),Vector3(-5.76,1.7,6.7))
	await sample(g,"parking",Vector3(-8.3,1.8,17),Vector3(0,2.1,7))
	var file=FileAccess.open("res://../../work/pc-high-profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"resolution":[2448,2448],"stereo":false,"results":results},"  "))
	quit()
