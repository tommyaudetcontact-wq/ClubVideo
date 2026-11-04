extends SceneTree
var failures:=0
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func _initialize():
 await process_frame
 var g=load("res://main.tscn").instantiate()
 root.add_child(g)
 await process_frame
 check(g.dvd_records.size()==1629,"Rear wall DVDs removed from interaction index")
 check(g.netflix.cases.size()==4 and not g.netflix.enabled,"Four distinct Netflix fr-CA test cases start disabled")
 g.modes.toggle_pause()
 check(g.modes.labels.size()==7,"Pause menu exposes Netflix mode and official login")
 g.modes._activate(5)
 check(g.netflix.enabled and g.netflix.visible,"Netflix option activates its cases")
 g.modes.toggle_pause()
 var c:Node3D=g.netflix.cases[0]
 var xf:Transform3D=c.global_transform
 g.hands[0].global_position=c.global_position
 check(g.netflix.interact(0,true) and g.netflix.held_case==c,"Netflix case uses existing hand grip anchor")
 check(c.get_parent()==g.dvd_grip_anchors[0],"Netflix grip orientation matches existing DVDs")
 check(g.active_trailer==-1 and g.trailer_banner.text.contains("OFFICIEL"),"Netflix selection stops unrelated Archive trailer")
 g.netflix.interact(0,true)
 check(c.global_transform.is_equal_approx(xf),"Netflix case returns exactly to its place")
 var panes:=0
 for n in g.model.find_children("*","MeshInstance3D",true,false):
  for i in range(n.mesh.get_surface_count()):
   var m=n.get_active_material(i)
   if m is ShaderMaterial and m.shader.resource_path.ends_with("rain_glass.gdshader"):panes+=1
 check(panes>0,"Animated glass shader applied to merged window mesh")
 var asphalt=g.model.find_child("wet-parking-lot",true,false)
 check(asphalt.material_override is ShaderMaterial,"Quest parking has world-mapped PBR shader")
 g.netflix.toggle()
 check(not g.netflix.visible,"Netflix mode can be disabled")
 g.hud.visible=false
 g.head.global_position=Vector3(-.7,1.45,-3.95)
 g.head.look_at(Vector3(-.7,1.20,-4.91))
 g.netflix.toggle()
 await create_timer(.7).timeout
 root.get_texture().get_image().save_png("res://../mode-netflix-031.png")
 print("REFRESH_TESTS failures=",failures)
 quit(1 if failures else 0)
