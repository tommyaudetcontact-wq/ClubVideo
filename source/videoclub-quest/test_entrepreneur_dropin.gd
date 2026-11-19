extends SceneTree
var failures:=0
func check(value:bool,label:String) -> void:
	if not value:failures+=1;push_error("MODE_DROPIN: "+label)
func wait_for(condition:Callable,seconds:float=12) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while not condition.call() and Time.get_ticks_msec()<end:await process_frame
	return condition.call()
func make_game(touch:bool):
	var game=load("res://main.tscn").instantiate()
	game.touch_profile=touch
	root.add_child(game)
	game.set_physics_process(false);game.clerk.set_physics_process(false);game.clerk.customers.set_physics_process(false)
	return game
func _initialize():
	await process_frame
	set_meta("entrepreneur_mode",true)
	var host=make_game(false)
	host.entrepreneur.state.cash=45678
	host.clerk.lan.toggle_host()
	set_meta("entrepreneur_mode",false)
	var guest=make_game(true)
	current_scene=guest
	guest.clerk.shift.day=7
	guest.clerk.till[25]=23
	var personal_path:String=guest.session.save_path
	guest.lobby.peers={"test-host":{"ip":"127.0.0.1","mode":"entrepreneur"}}
	var old_id:int=guest.get_instance_id()
	var grant:String=host.clerk.lan.permit("127.0.0.1")
	guest.touch_controls.coop_panel.connect_host("127.0.0.1",grant)
	check(await wait_for(func():return is_instance_valid(current_scene) and current_scene.get_instance_id()!=old_id and current_scene.touch_controls and current_scene.touch_controls.coop_panel.connected),"normal player joins business after automatic scene change")
	if not is_instance_valid(current_scene) or not current_scene.touch_controls or not current_scene.touch_controls.coop_panel.connected:quit(1);return
	var visitor=current_scene
	check(visitor.entrepreneur_mode and visitor.entrepreneur.state.cash==45678,"correct host mode and finances loaded")
	check(has_meta("coop_return_mode") and not visitor.session.save_game(false),"borrowed mode cannot overwrite private business save")
	visitor.touch_controls.coop_panel.reset("Retour au solo")
	var visitor_id:int=visitor.get_instance_id()
	check(await wait_for(func():return is_instance_valid(current_scene) and current_scene.get_instance_id()!=visitor_id and current_scene.session!=null),"disconnect returns to original mode")
	var returned=current_scene
	returned.set_physics_process(false);returned.clerk.set_physics_process(false);returned.clerk.customers.set_physics_process(false)
	check(not returned.entrepreneur_mode and not has_meta("coop_return_mode"),"borrowed mode cleared")
	returned.session.save_path=personal_path
	check(returned.session.restore_file(),"normal private save readable after visit")
	check(returned.clerk.shift.day==7 and returned.clerk.till[25]==23,"private day and till preserved")
	host.clerk.lan.toggle_host()
	print("ENTREPRENEUR_DROPIN_COMPLETE failures=",failures)
	quit(1 if failures else 0)
