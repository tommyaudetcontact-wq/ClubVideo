extends SceneTree
func _initialize():
	await process_frame
	var ui=load("res://mobile.tscn").instantiate()
	root.add_child(ui)
	ui.address.text="127.0.0.1"
	ui.pin.text=OS.get_cmdline_user_args()[0]
	ui.join_or_leave()
	var timeout:=create_timer(8)
	while not ui.connected and timeout.time_left>0:await process_frame
	if not ui.connected:
		push_error(ui.status.text)
		quit(1)
		return
	assert(ui.pages.size()==4 and ui.available_actions.client)
	ui.perform_action()
	await create_timer(.7).timeout
	print("ANDROID_CLIENT_OK ",ui.status.text)
	quit(0)
