extends SceneTree
func _initialize():
 await process_frame
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 var start=Time.get_ticks_usec()
 for i in range(120):
  game._update_cover_lod(Vector3(-4.0+float(i%12)*0.7,1.6,-5.0+float(i%8)*1.2))
 print("CPU_LOD_BENCH_US=",float(Time.get_ticks_usec()-start)/120.0)
 quit()
