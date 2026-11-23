extends SceneTree
func _initialize():call_deferred("build")
func build():
 var source=load("res://assets/decor.glb").instantiate()
 root.add_child(source)
 var world=load("res://entrepreneur_world.gd")
 var specs=[ ["plant",AABB(Vector3(-5.38,.005,4.87),Vector3(.96,1.4,.96)),Vector3(-4.9,0,5.35)], ["tv",AABB(Vector3(-1.98,2.15,-3.3),Vector3(.96,1.02,1)),Vector3(-1.5,2.55,-2.8)] ]
 for spec in specs:
  var node=world.extract_region(source,spec[1],spec[2])
  for mesh in node.get_children():
   mesh.owner=node
   if mesh.material_override:mesh.material_override=mesh.material_override.duplicate()
  var scene=PackedScene.new()
  assert(scene.pack(node)==OK)
  assert(ResourceSaver.save(scene,"res://assets/entrepreneur-"+spec[0]+".scn")==OK)
  print("DECOR_BAKED ",spec[0]," parts=",node.get_child_count())
  node.free()
 source.free()
 quit()
