extends SceneTree
func _initialize():
 await process_frame
 var g=load("res://main.tscn").instantiate()
 root.add_child(g)
 await process_frame
 var shader:=ShaderMaterial.new()
 shader.shader=load("res://rain_glass_preview.gdshader")
 shader.set_shader_parameter("condensation",load("res://assets/glass-preview/condensation-packed.png"))
 shader.set_shader_parameter("preview_time",12.0)
 var count:=0
 for node in g.model.find_children("*","MeshInstance3D",true,false):
  for i in range(node.mesh.get_surface_count()):
   var m=node.get_active_material(i)
   if m is ShaderMaterial and m.shader.resource_path.ends_with("rain_glass.gdshader"):
    node.set_surface_override_material(i,shader)
    count+=1
 g.hud.visible=false
 g.head.global_position=Vector3(-2,1.6,4)
 g.head.look_at(Vector3(-1,1.7,9))
 await create_timer(1.0).timeout
 root.get_texture().get_image().save_png("res://../vitres-proposition-buee.png")
 g.head.global_position=Vector3(-1.8,1.65,6.35)
 g.head.look_at(Vector3(-1.55,1.65,7.3))
 await create_timer(.4).timeout
 root.get_texture().get_image().save_png("res://../vitres-proposition-detail.png")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../../work/glass-frames"))
 for i in range(48):
  shader.set_shader_parameter("preview_time",12.0+i/12.0)
  await process_frame
  await process_frame
  root.get_texture().get_image().save_png("res://../../work/glass-frames/%03d.png"%i)
 print("GLASS_PREVIEW surfaces=",count)
 quit()
