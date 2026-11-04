extends SceneTree
func _initialize():
 var m=load("res://assets/lighting/decor-lit.scn").instantiate()
 root.add_child(m)
 for n in m.find_children("*","MeshInstance3D",true,false):
  for i in range(n.mesh.get_surface_count()):
   var mat=n.get_active_material(i)
   if mat is StandardMaterial3D and (mat.transparency!=0 or str(n.name).contains("parking")):
    print(n.name," surface",i," material=",mat.resource_name," alpha=",mat.albedo_color.a," texture=",mat.albedo_texture.resource_path if mat.albedo_texture else "none"," aabb=",n.get_aabb())
 quit()
