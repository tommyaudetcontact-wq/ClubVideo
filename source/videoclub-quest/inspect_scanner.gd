extends SceneTree
func _initialize():
 await process_frame
 var scene=load("res://assets/lighting-v3/decor-lit.scn").instantiate()
 root.add_child(scene)
 for n in scene.find_children("*","",true,false):
  if n is MeshInstance3D:
   var box=n.global_transform*n.get_aabb()
   if box.get_center().distance_to(Vector3(-.5,1.25,-5.07))<.4:print(n.get_path()," ",box)
  elif n is MultiMeshInstance3D:
   for i in range(n.multimesh.instance_count):
    var box=n.global_transform*n.multimesh.get_instance_transform(i)*n.multimesh.mesh.get_aabb()
    if box.get_center().distance_to(Vector3(-.5,1.25,-5.07))<.3:print(n.get_path()," INSTANCE ",i," ",box)
 quit()

