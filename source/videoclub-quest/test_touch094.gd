extends SceneTree

func _initialize():
	await process_frame
	root.size=Vector2i(1604,720)
	var game=load("res://main.tscn").instantiate()
	game.touch_profile=true
	root.add_child(game)
	var ui=game.touch_controls
	ui.update_stick()
	assert(not ui.stick_base.visible)
	var touch:=InputEventScreenTouch.new()
	touch.index=3
	touch.position=Vector2(530,320)
	touch.pressed=true
	ui._unhandled_input(touch)
	assert(ui.move_touch==3 and ui.move_start==touch.position)
	var drag:=InputEventScreenDrag.new()
	drag.index=3
	drag.position=Vector2(530,245)
	drag.relative=Vector2(0,-75)
	ui._unhandled_input(drag)
	assert(ui.motion==Vector2(0,-1) and ui.stick_base.visible)
	assert(ui.stick_center()==Vector2(530,320))
	var right:=InputEventScreenTouch.new()
	right.index=7
	right.position=Vector2(1100,300)
	right.pressed=true
	ui._unhandled_input(right)
	assert(ui.look_touch==7 and ui.move_touch==3)
	drag.index=7
	drag.position=Vector2(1150,300)
	drag.relative=Vector2(50,0)
	var yaw:float=game.origin.rotation.y
	ui._unhandled_input(drag)
	assert(game.origin.rotation.y<yaw)
	touch.pressed=false
	ui._unhandled_input(touch)
	assert(ui.motion==Vector2.ZERO and not ui.stick_base.visible and ui.look_touch==7)
	right.pressed=false
	ui._unhandled_input(right)
	assert(ui.look_touch==-1)
	print("TOUCH094_OK: floating joystick across left 45%, origin under thumb, independent look finger, release hides joystick")
	quit(0)
