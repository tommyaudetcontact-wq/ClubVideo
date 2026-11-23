extends SceneTree
var failures:=0
func check(ok:bool,text:String):
 if not ok:failures+=1;push_error("FEEDBACK115: "+text)
func _initialize():
 set_meta("entrepreneur_mode",true)
 await process_frame
 var g=load("res://main.tscn").instantiate();root.add_child(g)
 g.set_physics_process(false);g.clerk.set_physics_process(false);g.clerk.customers.set_physics_process(false)
 var b=g.entrepreneur
 b.buy_shelf(0);var id:int=b.state.orders[0].id
 b.freight.take(id,0);b.open_parcel(id)
 check(b.assembly.stage=="site" and not is_instance_valid(b.assembly_node),"opening does not commit a construction location or create boards")
 check(b.freight.held_id==id,"opened carton stays in hand")
 b.ghost.transform=b.snap_placement(Vector3(0,0,2),0,0);b.finish_placement()
 check(b.assembly.stage=="boards" and b.assembly_node.position==Vector3(0,0,2),"construction only appears at confirmed floor location")
 for i in 6:b.take_board(1);b.place_board()
 var screw_poses:Array=[]
 for i in 20:screw_poses.append(b.assembly_node.get_node("Screws/Screw%d"%i).global_transform)
 for i in 20:b.fasten_screw(.61,i)
 for i in 20:
  var screw:Node3D=b.shelf_nodes[0].get_node("Screws/Screw%d"%i)
  # During assembly unfinished heads protrude by28mm; after fitting they sit flush at the exact same joint.
  var expected:Transform3D=b.shelf_nodes[0].global_transform*b.Build.screw_pose(.785,i)
  check(screw.global_position.distance_to(expected.origin)<.0001,"finished screw remains at joint %d"%i)
 b.receive_film(0)
 var item:Dictionary=g.clerk.cases.back();var record:Dictionary=item.record
 b.slots.choose(record,b.slots.pose(0,0).origin);g.clerk.restore_stock(record);g.clerk.cases.erase(item);item.node.queue_free()
 g.head.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,.7,3))
 g._update_cover_lod(g.head.global_position,true)
 check(g.lod_slots.has(0) and g.lod_slots[0][0].size()>0,"actual high resolution front cover is visible")
 b.start_move_shelf(0);b.ghost.transform=b.snap_placement(Vector3(.4,7,2),PI/4,0);b.preview_stock()
 var slot:int=g.lod_slots[0][0].find(int(record.id))
 var paper:Transform3D=g.lod_groups[0][0].multimesh.get_instance_transform(slot)
 check(paper.origin.distance_to((record.world*Transform3D(Basis.IDENTITY,Vector3(0,0,.0082))).origin)<.0001,"actual detailed cover follows record during placement")
 check(is_zero_approx(b.ghost.position.y),"input height cannot lift the shelf")
 b.release_grip(b.placement_hand)
 check(b.moving_shelf==0,"releasing grip does not commit an unintended location")
 b.placement_valid=true;b.interact(b.placement_hand,false)
 check(b.moving_shelf==-1,"trigger confirms floor placement")
 var aligned:Transform3D=b.snap_placement(b.state.shelves[0].pose.origin+b.state.shelves[0].pose.basis.x*.80,PI/4,0)
 check(aligned.basis.is_equal_approx(b.state.shelves[0].pose.basis),"adjacent shelf preserves matching45degree orientation")
 check(aligned.origin.distance_to(b.state.shelves[0].pose.origin+b.state.shelves[0].pose.basis.x*.805)<.001,"adjacent edges snap together")
 var wall:Transform3D=b.snap_placement(Vector3(5.2,0,1),0,0)
 check(is_equal_approx(wall.origin.x,5.61-.785/2),"wall edge snap")
 g.head.position.y=1.6
 g._update_crouch(Vector2(0,-1),.016)
 check(is_equal_approx(g.crouch_offset,-.65),"crouch height changes without vertical elevator motion")
 g._update_crouch(Vector2.ZERO,.016)
 check(is_zero_approx(g.crouch_offset),"standing height restored immediately")
 print("FEEDBACK115_COMPLETE failures=",failures)
 quit(1 if failures else 0)
