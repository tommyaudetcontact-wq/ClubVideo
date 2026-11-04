extends SceneTree
var failures:=0
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func _initialize():
 await process_frame
 var g=load("res://main.tscn").instantiate()
 root.add_child(g)
 await process_frame
 var machine:Dictionary=g.candy.machines[1]
 var center:Vector3=machine.node.to_global(Vector3(0,1.0,.12))
 g.aim_hands[0].global_position=center+Vector3(0,0,1)
 g.aim_hands[0].global_basis=Basis.IDENTITY
 check(not g.candy.try_interact(0,true) and machine.credit==0,"Grip cannot insert coins or vend candy")
 check(g.candy.try_interact(0,false) and machine.credit==1,"Trigger inserts coin in standing dispenser")
 check(g.candy.try_interact(0,false) and g.candy.balls.size()==1,"Second trigger dispenses one candy")
 var ball:RigidBody3D=g.candy.balls[0].body
 g.hands[0].global_position=ball.global_position
 check(g.candy.try_interact(0,true) and ball.freeze,"Grip still picks up physical candy")
 check(machine.credit==0,"Candy pickup cannot reinsert a coin")
 g.candy.release_ball(0)
 var target:Transform3D=g.dvd_records[0].world
 g.head.global_position=target.origin+target.basis.z*.65
 g.head.look_at(target.origin)
 g._update_cover_lod(g.head.global_position,true)
 var faces:=0
 for pair in g.lod_groups.values():
  for n in pair:faces+=n.multimesh.visible_instance_count
 print("SHARP_COVERS selected=",g.lod_selected.size()," faces=",faces," previous_two_sided=",g.lod_selected.size()*2)
 check(faces>=g.lod_selected.size() and faces<g.lod_selected.size()*2,"Hidden cover faces culled, all selected covers stay detailed")
 check(g.xr_interface.render_target_size_multiplier==1.0 or not g.xr_active,"Desktop test does not alter XR render quality")
 check(g.model.find_child("BakedLightmapGI",true,false)!=null,"Baked lights retained")
 var column=machine.node.find_child("column",true,false)
 check(column.get_active_material(0).albedo_color.a<.1,"Standing dispenser column reveals real candy trajectory")
 g.hud.visible=false
 g.head.global_position=Vector3(-2,1.6,4)
 g.head.look_at(Vector3(-1,1.7,9))
 await create_timer(1).timeout
 root.get_texture().get_image().save_png("res://../vitres-corrigees-033.png")
 g.head.global_position=Vector3(2.9,1.7,-2.6)
 g.head.look_at(Vector3(0,1.4,-7))
 await create_timer(.4).timeout
 root.get_texture().get_image().save_png("res://../eclairage-corrige-033.png")
 print("CORRECTION_TESTS failures=",failures)
 quit(1 if failures else 0)
