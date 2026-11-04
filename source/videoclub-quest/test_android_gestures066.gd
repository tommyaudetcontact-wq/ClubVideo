extends SceneTree

func _initialize():
	await process_frame
	root.size=Vector2i(1152,648)
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	var ui=game.touch_controls
	game.origin.position=Vector3(-4.85,0,6.25)
	game.origin.rotation.y=0
	game.head.position=Vector3(0,1.65,0)
	var before:Vector3=game.origin.position
	touch(2,Vector2(100,490),true)
	await process_frame
	drag(2,Vector2(100,408),Vector2(0,-82))
	await create_timer(.24).timeout
	print("TOUCH_SAMPLE ",ui.move_touch," axis ",ui.motion," travel ",game.origin.position.distance_to(before))
	touch(2,Vector2(100,408),false)
	assert(game.origin.position.distance_to(before)>.15,"Touch move must displace the player")
	var yaw:float=game.origin.rotation.y
	touch(3,Vector2(812,355),true)
	await process_frame
	drag(3,Vector2(850,355),Vector2(38,0))
	await process_frame
	touch(3,Vector2(850,355),false)
	assert(absf(game.origin.rotation.y-yaw)>.05,"Swipe must turn the camera")
	ui.toggle_operations()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../Android-controles-066.png")
	print("ANDROID_TOUCH_GESTURES_OK")
	quit()

func touch(index:int,p:Vector2,pressed:bool):
	var event:=InputEventScreenTouch.new()
	event.index=index
	event.position=p
	event.pressed=pressed
	Input.parse_input_event(event)

func drag(index:int,p:Vector2,relative:Vector2):
	var event:=InputEventScreenDrag.new()
	event.index=index
	event.position=p
	event.relative=relative
	Input.parse_input_event(event)

