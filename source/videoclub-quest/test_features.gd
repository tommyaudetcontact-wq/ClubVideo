extends SceneTree
var failures:=0
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _initialize()->void:
	await process_frame
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.layout.movies.size()==60 and game.dvd_groups.size()==60,"24 films and 36 console games")
	check(game.dvd_records.size()==1629,"No duplicated shelf geometry")
	check(game.candy.machines.size()==2,"Both physical dispensers loaded")
	check(game.candy.machines[1].node.find_child("spiral-ramp",true,false)!=null,"Continuous spiral mesh imported")
	check(game.modes.rain_nodes.size()==2,"Rain emitted only in exterior zones")
	check(game.held_pool.size()==60 and game.poster_cache.size()==60,"All covers preloaded")
	check(game.trailer_streams.size()==60,"60 matching local videos")
	check(game.screens.size()==5,"Five CRT screens")
	game._on_controller_button(&"by_button",0)
	check(paused and game.modes.menu_open,"Y opens pause menu")
	game.modes._activate(1)
	check(game.teleportation.enabled,"Pause menu enables teleportation")
	game.modes._activate(2)
	check(game.modes.manual_mode,"Pause menu enables manual DVD handling")
	game.modes._activate(3)
	check(not game.modes.rain_enabled,"Pause menu disables rain")
	game.modes._activate(0)
	check(not paused,"Resume unpauses world")
	# Close manual pickup and dropped-case recovery.
	var record:Dictionary=game.dvd_records[0]
	game.hands[0].global_position=record.world.origin+Vector3(0,.6,0)
	game._take(record,0,true)
	game._release()
	check(record.get("loose",false) and is_instance_valid(record.get("loose_body")),"Manual release drops physical DVD instead of snapping remotely")
	var body:RigidBody3D=record.loose_body
	check(not body.find_child("MoldedPlasticOnly",true,false).material_override.normal_enabled,"Dropped plastic switches off handheld surface detail")
	await physics_frame
	game.hands[0].global_position=body.global_position
	check(game.modes.try_loose_pickup(0,true) and game.held!=null,"Dropped DVD can be picked up")
	check(game.held.get_node("MoldedPlasticOnly").material_override.normal_enabled,"Plastic detail returns when DVD is picked up")
	game.held.global_transform=record.world
	game._release()
	check(not record.get("loose",false) and game.held==null,"DVD restored only at original slot")
	check(record.group.multimesh.get_instance_transform(record.index).is_equal_approx(record.local),"Manual slot transforms restored exactly")
	game.modes.manual_mode=false
	# Run the same 1/72 second physics step faster in wall time for trajectory QA.
	Engine.physics_ticks_per_second=288
	Engine.time_scale=4.0
	game.candy.use_machine(0)
	check(game.candy.machines[0].credit==1 and game.candy.balls.is_empty(),"Coin alone does not dispense")
	game.candy.use_machine(0)
	game.candy.use_machine(1)
	game.candy.use_machine(1)
	check(game.candy.balls.size()==2,"Each paid crank spawns one real rigid body")
	var red:RigidBody3D=game.candy.balls[0].body
	var blue:RigidBody3D=game.candy.balls[1].body
	var machine:Node3D=game.candy.machines[1].node
	var red_start:Vector3=red.global_position
	var angle:=PI/2
	var angular_distance:=0.0
	var min_y:=2.0
	var positions:Array=[]
	for frame in range(2000):
		await physics_frame
		var local:Vector3=machine.to_local(blue.global_position)
		if local.y>.36:
			var a:=atan2(local.z,local.x)
			angular_distance+=wrapf(a-angle,-PI,PI)
			angle=a
		min_y=minf(min_y,local.y)
		if frame%72==0:positions.append([local.x,local.y,local.z])
	var red_end:Vector3=game.candy.machines[0].node.to_local(red.global_position)
	var blue_end:Vector3=machine.to_local(blue.global_position)
	print("TRAJECTORY red=",red_end," blue=",blue_end," turns=",angular_distance/TAU," min_y=",min_y)
	print("SPIRAL_SAMPLES ",JSON.stringify(positions))
	check(red.global_position.distance_to(red_start)>.08 and red_end.y<.15,"Counter dispenser falls under gravity")
	check(angular_distance/TAU>3.5 and blue_end.y<.36,"Spiral ball physically traverses at least 3.5 turns to outlet")
	game.candy.grab_ball(0,red)
	check(red.freeze and game.candy.held_balls[0]==red,"Candy pickup freezes rigid body")
	game.candy.hand_history[0]=[{"time":game.candy.clock-.1,"position":Vector3.ZERO},{"time":game.candy.clock,"position":Vector3(.3,.1,0)}]
	game.candy.release_ball(0)
	check(not red.freeze and red.linear_velocity.length()>2,"Throw inherits measured hand velocity")
	var life_record:Dictionary=game.candy.balls[0]
	life_record.born=game.candy.clock-59.98
	await physics_frame
	await physics_frame
	await process_frame
	check(not is_instance_valid(red),"Candy disappears after 60 simulation seconds")
	print("FEATURE_TESTS failures=",failures)
	quit(1 if failures else 0)

