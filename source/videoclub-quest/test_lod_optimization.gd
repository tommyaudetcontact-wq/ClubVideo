extends SceneTree
func select_reference(g, eye:Vector3, forward:Vector3, optimized:bool)->Array:
 var candidates=[]
 for i in g._nearby_dvd_indices(eye,2.8):
  var r=g.dvd_records[i]
  if r.get("loose",false):continue
  var d=eye.distance_squared_to(r.world.origin)
  var limit=2.8 if g.lod_selected.has(i) else 2.2
  if d>=limit*limit:continue
  if optimized:
   if d>=.0625 and forward.dot((r.world.origin-eye).normalized())<.20:continue
  elif not g._cover_in_view(eye,r.world.origin,forward):continue
  candidates.append({"index":i,"distance":d})
 candidates.sort_custom(func(a,b):return a.distance<b.distance)
 var result=[]
 for c in candidates:
  if result.size()>=24:break
  if optimized and not g._cover_in_view(eye,g.dvd_records[c.index].world.origin,forward):continue
  result.append(c.index)
 return result
func _initialize():
 await process_frame
 var g=load("res://main.tscn").instantiate()
 root.add_child(g)
 await process_frame
 g.set_physics_process(false)
 var mismatch=0
 var times=[0,0]
 for x in [-4.3,-1.5,1.5,4.5]:
  for z in [-3.0,.5,4.5]:
   var eye=Vector3(x,1.6,z)
   for forward in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
    var old=select_reference(g,eye,forward,false)
    var newer=select_reference(g,eye,forward,true)
    if old!=newer:mismatch+=1
    for mode in range(2):
     var start=Time.get_ticks_usec()
     for repeat in range(10):select_reference(g,eye,forward,mode==1)
     times[mode]+=Time.get_ticks_usec()-start
 print("LOD_BENCHMARK poses=48 mismatches=",mismatch," reference_us=",times[0]," optimized_us=",times[1])
 quit(1 if mismatch else 0)
