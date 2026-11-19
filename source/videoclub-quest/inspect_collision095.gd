extends SceneTree
func _initialize():
 await process_frame
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 for node in game.model.find_children("*","MeshInstance3D",true,false):
  if node.global_position.distance_to(Vector3(.12,1.4,-6.5))>1.3:continue
  print("PC_MESH ",node.name," ",node.global_transform*node.get_aabb())
 var body=game.clerk.new_case(0,Vector3.ZERO,"shelve").node
 for node in body.get_children():
  if node is CollisionShape3D:print("CASE_SHAPE ",node.shape," ",node.transform)
 quit()
