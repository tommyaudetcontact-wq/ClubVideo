extends SceneTree
func _initialize():
 await process_frame
 var scene=Node3D.new()
 root.add_child(scene)
 var environment=WorldEnvironment.new()
 environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color("24374f")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color.WHITE
 environment.environment.ambient_light_energy=0.7
 scene.add_child(environment)
 var light=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-55,-30,0)
 light.light_energy=1.0
 scene.add_child(light)
 var camera=Camera3D.new()
 scene.add_child(camera)
 camera.position=Vector3(0,0.35,0.24)
 camera.look_at(Vector3(0,0,-0.015))
 camera.fov=43
 camera.near=0.01
 for left in [true,false]:
  var hand=Node3D.new()
  hand.set_script(load("res://vr_hand.gd"))
  hand.left=left
  scene.add_child(hand)
  hand.position.x=-0.075 if left else 0.075
  if not left:
   hand.update_grip(0.2,1.0,1.0,true)
 await create_timer(1.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../../work/hands-review.png")
 quit()
