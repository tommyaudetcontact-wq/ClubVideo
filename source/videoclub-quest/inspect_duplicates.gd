extends SceneTree
func _initialize():
 await process_frame
 var g=load("res://main.tscn").instantiate()
 root.add_child(g)
 var seen={}
 var dup=0
 for r in g.dvd_records:
  var key=str(r.world.origin)
  if seen.has(key):dup+=1
  seen[key]=true
 print("DUPLICATES ",dup," BASIS ",g.dvd_records[0].world)
 quit()
