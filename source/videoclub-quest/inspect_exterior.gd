extends SceneTree
func _initialize():
 await process_frame
 var m=load("res://assets/lighting-v2/decor-lit.scn").instantiate()
 root.add_child(m)
 for n in m.find_children("*","MeshInstance3D",true,false):
  var b=n.get_aabb()
  if b.size.length()>25 or str(n.name).contains("tree"):
   print("OUT ",n.name," box=",b," origin=",n.global_position," surfaces=",n.mesh.get_surface_count())
   for i in range(n.mesh.get_surface_count()):
    var mat=n.get_active_material(i)
    if mat is StandardMaterial3D:print("MAT ",i," ",mat.resource_name," ",mat.albedo_color)
 quit()
