extends SceneTree
var views:Array=[]
func _initialize():
 await process_frame
 root.size=Vector2i(800,600)
 for index in range(2):
  var view=SubViewport.new()
  view.size=Vector2i(800,600)
  view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  view.own_world_3d=true
  root.add_child(view)
  views.append(view)
  var camera=Camera3D.new()
  camera.position=Vector3(0,1.4,2)
  camera.projection=Camera3D.PROJECTION_ORTHOGONAL
  camera.size=3
  view.add_child(camera)
  camera.current=true
  var env=WorldEnvironment.new()
  env.environment=Environment.new()
  env.environment.background_mode=Environment.BG_COLOR
  env.environment.background_color=Color(.12,.16,.22)
  env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
  env.environment.ambient_light_color=Color.WHITE
  env.environment.ambient_light_energy=1
  view.add_child(env)
  var light=DirectionalLight3D.new()
  light.rotation_degrees=Vector3(-25,-20,0)
  view.add_child(light)
  var pane=MeshInstance3D.new()
  pane.mesh=QuadMesh.new()
  pane.mesh.size=Vector2(3,2.6)
  pane.position.y=1.4
  var material=ShaderMaterial.new()
  var shader=Shader.new()
  shader.code=FileAccess.get_file_as_string("C:/Users/recto/Documents/Codex/2026-11-01/va-x20/work/rain-before099.gdshader") if index==0 else FileAccess.get_file_as_string("res://rain_glass.gdshader")
  material.shader=shader
  material.set_shader_parameter("preview_time",41.3)
  material.set_shader_parameter("condensation",load("res://assets/glass-preview/condensation-mixed.png"))
  pane.material_override=material
  view.add_child(pane)
 await create_timer(2).timeout
 await RenderingServer.frame_post_draw
 for i in range(2):views[i].get_texture().get_image().save_png("C:/Users/recto/Documents/Codex/2026-11-01/va-x20/work/rain099-%d.png"%i)
 print("RAIN099_CAPTURED")
 quit()
