extends SceneTree
func _initialize():
 await process_frame
 var g=load("res://main.tscn").instantiate()
 root.add_child(g)
 for n in g.find_children("*","Light3D",true,false):print("LIGHT ",n.name," bake=",n.light_bake_mode," energy=",n.light_energy," mask=",n.light_cull_mask," visible=",n.visible)
 print("VIEW ",root.scaling_3d_scale," mip ",root.texture_mipmap_bias)
 quit()
