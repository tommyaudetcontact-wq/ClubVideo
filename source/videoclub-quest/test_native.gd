extends SceneTree

var failures := 0
func check(value: bool, label: String) -> void:
	if value:
		print("PASS ",label)
	else:
		failures += 1
		push_error(label)

func _initialize() -> void:
	await process_frame
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.dvd_records.size()==1629,"DVD population")
	check(game.screens.size()==5,"Shared CRT screens")
	check(not game.baked_lighting_active if game.pc_vr else game.baked_lighting_active and game.model.get_node("BakedLightmapGI").light_data.get_user_count()==39,"Lighting matches platform profile")
	check(game.trailer_streams.size()==60,"Sixty matching video streams available")
	var same_texture := true
	for screen in game.screens:
		if screen.material_override.albedo_texture!=game.screens[0].material_override.albedo_texture:
			same_texture = false
	check(same_texture and game.find_children("*","VideoStreamPlayer",true,false).size()==1,"Five CRTs share one video player and texture")
	check(game.gum!=null and game.gum_knob!=null,"Gumball machine")
	check(game.screens[0].material_override.uv1_scale.y == -1,"CRT vertical UV correction")
	check(game.hands[0].pose==&"grip" and game.aim_hands[0].pose==&"aim","Grip pose separated from aiming pose")
	check(game.hand_visuals.size()==2 and game.hand_visuals[0].skeleton.get_bone_count()>=25,"Two skinned hands replace capsule placeholders")
	game.hand_visuals[0].update_grip(0.2,1.0,1.0,true)
	check(game.hand_visuals[0].skeleton.get_bone_pose_rotation(game.hand_visuals[0].joints[0]).get_angle()>0.1,"Hand fingers curl for pickup")
	check(not game._cover_in_view(Vector3(0,2,0),Vector3(0,2,1),Vector3.FORWARD),"Detailed cover LOD excludes rear view")
	var old_occluders = game.cover_occluders.duplicate()
	game.cover_occluders.clear()
	game.cover_occluders.append(AABB(Vector3(-1,0,-1.5),Vector3(2,3,0.2)))
	check(not game._cover_in_view(Vector3(0,2,0),Vector3(0,2,-2),Vector3.FORWARD),"Detailed cover LOD excludes blocked shelves")
	game.cover_occluders.clear()
	game.cover_occluders.append_array(old_occluders)
	check(game.held_pool.size()==60 and game.poster_cache.size()==60,"DVD and poster resources prepared before interaction")
	var spatial_complete := true
	for eye in [Vector3(-5,1.6,-6),Vector3(0,1.6,0),Vector3(5,1.6,5)]:
		var nearby = game._nearby_dvd_indices(eye,2.8)
		for i in range(game.dvd_records.size()):
			if eye.distance_squared_to(game.dvd_records[i].world.origin)<2.8*2.8 and not nearby.has(i):
				spatial_complete = false
	check(spatial_complete,"Spatial query includes every DVD within requested radius")
	if not game.dvd_records.is_empty():
		game._update_cover_lod(game.dvd_records[0].world.origin)
		check(game.lod_selected.size()>0 and game.lod_selected.size()<=game.COVER_DETAIL_BUDGET,"Nearby cover LOD budget")
		game._update_cover_lod(Vector3(100,100,100))
		check(game.lod_selected.is_empty(),"Distant covers use atlas")
		game._take(game.dvd_records[0],1,false)
		check(game.held!=null and game.held.get_parent()==game.dvd_grip_anchors[1],"DVD pickup uses edge-pinch hand anchor")
		var pooled_id: int = game.held.get_instance_id()
		game._interact(1,false)
		await create_timer(0.35).timeout
		check(game.held!=null and game.held_back and abs(game.held.rotation.y-PI)<0.01,"Trigger shows DVD back")
		game._interact(1,false)
		await create_timer(0.35).timeout
		check(not game.held_back and abs(game.held.rotation.y)<0.01,"Trigger restores DVD front")
		check(game.active_trailer==int(game.dvd_records[0].movie) and game.trailer_player.is_playing() and game.trailer_player.stream_position>0.1,"Picking DVD starts corresponding moving video")
		game._interact(1,true)
		check(game.held==null,"DVD return")
		game._take(game.dvd_records[0],1,false)
		check(game.held.get_instance_id()==pooled_id,"DVD node reused without allocation on second pickup")
		game._release()
	game.candy.use_machine(0)
	check(game.candy.machines[0].credit==1,"Virtual coin")
	game.candy.use_machine(0)
	check(game.candy.balls.size()==1 and game.candy.balls[0].body is RigidBody3D,"Physical gumball spawned")
	var teleport = game.teleportation
	game._on_controller_button(&"primary_click",1)
	check(not teleport.enabled,"Right joystick click does not change locomotion")
	game._on_controller_button(&"primary_click",0)
	check(teleport.enabled,"Left joystick click enables teleport mode")
	var blocked = teleport.trace(Vector3(-3.05,1.4,5.0),Vector3.FORWARD)
	check(not blocked.valid,"Teleport arc cannot cross shelf collider")
	check(not teleport.valid_destination(Vector3(40,0,50)),"Teleport rejects out-of-bounds destination")
	game.head.position += Vector3(0.25,0,-0.1)
	game.aim_hands[0].global_position = Vector3(-4.3,1.4,5.8)
	game.aim_hands[0].look_at(Vector3(-4.3,0.8,4.7))
	teleport.update(Vector2(0,1),0.04)
	check(teleport.aiming and teleport.target_valid and teleport.arc.visible,"Stick forward previews a valid floor destination")
	var landing: Vector3 = teleport.target
	teleport.update(Vector2.ZERO,0.01)
	await create_timer(0.3).timeout
	var actual: Vector3 = game.head.global_position
	check(Vector2(actual.x,actual.z).distance_to(Vector2(landing.x,landing.z))<0.001,"Release teleports tracked head to target with room-scale offset")
	check(not teleport.busy and not teleport.fade.visible and not teleport.arc.visible,"Teleport comfort fade and targeting finish cleanly")
	game._on_controller_button(&"primary_click",0)
	check(not teleport.enabled,"Second left joystick click restores walking")
	print("NATIVE_TESTS failures=",failures)
	quit(1 if failures else 0)
