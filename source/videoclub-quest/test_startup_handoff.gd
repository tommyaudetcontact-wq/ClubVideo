extends SceneTree
var failures:=0
func check(ok:bool,message:String) -> void:
	if not ok:failures+=1;push_error("STARTUP_HANDOFF: "+message)
func _initialize():
	set_meta("entrepreneur_mode",true)
	await process_frame
	var g=load("res://main.tscn").instantiate();root.add_child(g)
	g.set_physics_process(false);g.clerk.set_physics_process(false);g.clerk.customers.set_physics_process(false)
	var loader:=Node.new();root.add_child(loader);g.set_meta("startup_loader",loader)
	g.session.resume_prompt()
	await process_frame;await process_frame
	check(not paused,"resume cannot pause while loading")
	check(not g.clerk.is_physics_processing(),"clerk stays suspended before handoff")
	g.remove_meta("startup_loader")
	await process_frame;await process_frame
	check(not paused and g.clerk.is_physics_processing(),"entrepreneur resumes running after loading")
	g.queue_free();loader.queue_free();await process_frame
	var loading=load("res://club_loading.tscn").instantiate();root.add_child(loading);current_scene=loading
	var deadline:=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline and (current_scene==loading or current_scene.has_meta("startup_loader")):
		await process_frame
	check(is_instance_valid(current_scene) and current_scene!=loading and not current_scene.has_meta("startup_loader"),"complete real loading scene hands off to playable game")
	check(current_scene.process_mode==Node.PROCESS_MODE_INHERIT and not paused,"loaded root is active")
	print("STARTUP_HANDOFF_COMPLETE failures=",failures)
	quit(1 if failures else 0)
