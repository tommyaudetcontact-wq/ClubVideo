extends SceneTree
var rows=[]
func sample(g,label):
 for i in range(60):await process_frame
 var gpu=[]
 var elapsed=[]
 var last=Time.get_ticks_usec()
 for i in range(120):
  await process_frame
  var now=Time.get_ticks_usec()
  elapsed.append((now-last)/1000.0)
  last=now
  gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
 gpu.sort();elapsed.sort()
 var row={"name":label,"gpuMs":gpu[60],"gpuP95":gpu[114],"frameMs":elapsed[60],"frameP95":elapsed[114],"processMs":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physicsMs":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"viewport":str(root.size)}
 rows.append(row)
 print("PC_AB ",JSON.stringify(row))
func _initialize():
 await process_frame
 root.size=Vector2i(4096,3780)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var g=load("res://main.tscn").instantiate()
 root.add_child(g)
 g.origin.transform=Transform3D.IDENTITY
 g.head.position=Vector3(2.9,1.7,4.6)
 g.head.look_at(Vector3(-2,1.7,-3))
 var p=g.get_node("PCPresentation")
 await sample(g,"HQ2_no_video")
 g._play_trailer(57)
 await sample(g,"HQ2_video57")
 p.set_process(false)
 var shadows=[]
 for light in g.find_children("*","Light3D",true,false):
  if light.shadow_enabled:
   shadows.append(light)
   light.shadow_enabled=false
 await sample(g,"no_shadows")
 for light in shadows:light.shadow_enabled=true
 p.scene_environment.glow_enabled=false
 await sample(g,"no_glow")
 p.scene_environment.glow_enabled=true
 for light in p.lamps:light.spot_range=4.0
 await sample(g,"range4")
 var file=FileAccess.open("res://../../work/pc-ab.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(rows,"  "))
 quit()
