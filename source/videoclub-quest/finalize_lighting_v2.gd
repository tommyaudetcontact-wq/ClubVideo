extends SceneTree
func _initialize():
 await process_frame
 var scene=load("res://lighting_bake_v2.tscn").instantiate()
 root.add_child(scene)
 var gi=scene.get_node("BakedLightmapGI")
 print("BAKED_USERS=",gi.light_data.get_user_count())
 for node in scene.find_children("*","",true,false):
  if node is Light3D:
   node.visible=false
  if node is MeshInstance3D and node.mesh.resource_path.begins_with("res://lighting_bake_v2.tscn"):
   node.mesh=node.mesh.duplicate()
  node.owner=scene
 var packed=PackedScene.new()
 packed.pack(scene)
 var result=ResourceSaver.save(packed,"res://assets/lighting-v2/decor-lit.scn")
 print("LIT_SCENE_SAVED=",result)
 print(ResourceLoader.get_dependencies("res://assets/lighting-v2/decor-lit.scn"))
 quit(result)
