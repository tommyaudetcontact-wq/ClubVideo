extends SceneTree
var failures:=0
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error("FEEDBACK113: "+message)
func _initialize():
 set_meta("entrepreneur_mode",true)
 await process_frame
 var g=load("res://main.tscn").instantiate();root.add_child(g)
 g.set_physics_process(false);g.clerk.set_physics_process(false);g.clerk.customers.set_physics_process(false)
 var b=g.entrepreneur
 b.buy_shelf(0)
 var id:int=b.state.orders[0].id
 b.freight.take(id,0);g.hands[0].position=Vector3(0,1,2);b.freight.tick();b.open_parcel(id)
 check(b.freight.held_hand==0,"opening shelf carton leaves it in the first hand")
 b.ghost.transform=b.snap_placement(Vector3(0,0,2),0,0);b.finish_placement()
 b.update_tools(0)
 g.hands[1].global_position=b.packages[id].global_position+Vector3(0,.12,0)
 check(b.freight.interact(1,true) and b.board_hand==1,"other hand extracts a real board from held carton")
 for i in 6:
  if b.board_hand<0:b.take_board(1)
  b.place_board()
 check(not b.packages.has(id) and b.freight.held_id<0,"empty carton disposed after final board")
 check(b.assembly_node.get_node("Screws").get_child_count()==20,"two screws at every side joint")
 var point:Vector3=b.assembly_node.to_global(b.screw_position(0))
 b.drill.global_transform=Transform3D(Basis.IDENTITY,point-Vector3(0,.015,-.16))
 check(b.contact_screw()==0,"real bit at screw is accepted")
 b.drill.position.z+=.4
 check(b.contact_screw()==-1,"aiming from a distance does not fasten a screw")
 for i in 20:b.fasten_screw(.61,i)
 check(b.state.shelves.size()==1,"all twenty screws finish assembly")
 b.start_move_shelf(0);b.ghost.position=Vector3(0,0,2);b.finish_placement()
 b.receive_film(0)
 var item:Dictionary=g.clerk.cases.back();var record:Dictionary=item.record
 check(b.slots.choose(record,b.slots.pose(0,0).origin),"choose shelf slot")
 g.clerk.restore_stock(record);g.clerk.cases.erase(item);item.node.queue_free()
 var old:Vector3=record.world.origin
 b.placement_hand=0;b.start_move_shelf(0)
 g.xr_active=true
 g.hands[0].global_position+=Vector3(.4,.2,0)
 b.interact(0,true)
 check(is_equal_approx(b.placement_angle,PI/4),"grip rotates placement by 45 degrees")
 b.ghost.transform=b.snap_placement(Vector3(.4,0,2),0,0);b.preview_stock()
 check(absf(b.ghost.position.y)<.001,"shelf placement remains on the floor")
 check(record.world.origin.distance_to(old+Vector3(.4,0,0))<.001,"stock follows placement before confirmation")
 b.finish_placement()
 check(b.moving_shelf==-1 and absf(b.state.shelves[0].pose.origin.y)<.001,"confirmation sets shelf on floor")
 g.xr_active=false
 g.hands[1].global_position=record.world.origin
 check(not b.interact(1,true) and b.moving_shelf<0,"case pickup takes priority over shelf frame")
 g.modes.manual_mode=false
 g._interact(1,true)
 check(g.held!=null and g.clerk.held_service.get("record",{}).get("id",-1)==record.id,"physical grip picks the nearby film without aiming")
 var card=load("res://entrepreneur_card.gd").new();root.add_child(card);card.configure(g.layout.movies[0],"STANDARD","")
 check(card.cover!=null and card.cover.get_width()>=256,"catalogue has actual clear cover texture")
 print("FEEDBACK113_COMPLETE failures=",failures)
 quit(1 if failures else 0)



