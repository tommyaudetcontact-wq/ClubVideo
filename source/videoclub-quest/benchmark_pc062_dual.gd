extends SceneTree

const EYE_SIZE := Vector2i(2496, 2592)
var eyes: Array[SubViewport] = []
var cameras: Array[Camera3D] = []

func _initialize():
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	root.disable_3d = true
	game.origin.transform = Transform3D.IDENTITY
	for index in range(2):
		var eye := SubViewport.new()
		eye.size = EYE_SIZE
		eye.world_3d = root.world_3d
		eye.msaa_3d = Viewport.MSAA_4X
		eye.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(eye)
		var camera := Camera3D.new()
		eye.add_child(camera)
		camera.current = true
		eyes.append(eye)
		cameras.append(camera)
	game._play_trailer(0)
	await sample(game, "rayons", Vector3(-3.8,1.7,4.9), Vector3(2,1.7,-3))
	await sample(game, "caisse", Vector3(.12,1.6,-7.1), Vector3(.12,1.38,-6.3))
	await sample(game, "vitrines", Vector3(-3.8,1.7,4.9), Vector3(-5.76,1.7,6.7))
	await sample(game, "stationnement", Vector3(-8.3,1.8,17), Vector3(0,2.1,7))
	quit()

func sample(game, label: String, eye_position: Vector3, target: Vector3):
	game.head.position = eye_position
	game.head.look_at(target)
	game._update_cover_lod(eye_position,true)
	for index in range(2):
		cameras[index].global_transform = game.head.global_transform.translated_local(Vector3((index-.5)*.064,0,0))
	for frame in range(100):
		await process_frame
	var times: Array[float] = []
	for frame in range(240):
		var start := Time.get_ticks_usec()
		await process_frame
		times.append((Time.get_ticks_usec()-start)/1000.0)
	times.sort()
	print("PC_DUAL_VIEW ", label, " ", eyes[0].size, " p50_ms=", times[120], " p95_ms=", times[228])
	await RenderingServer.frame_post_draw
	eyes[0].get_texture().get_image().save_png("res://../pc062-" + label + ".png")
