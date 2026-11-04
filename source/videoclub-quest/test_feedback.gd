extends SceneTree
var failures=0
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _initialize():
	await process_frame
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	var verified=0
	for r in g.cover_info.slice(24):
		if r.get("backVerified",false):verified+=1
	check(verified==36,"All 36 game backs use sourced retail artwork")
	var ps3=g.held_pool[54].get_node("MoldedPlasticOnly")
	var xbox=g.held_pool[48].get_node("MoldedPlasticOnly")
	var dvd=g.held_pool[0].get_node("MoldedPlasticOnly")
	check(ps3.mesh.get_aabb().size.y<xbox.mesh.get_aabb().size.y,"PS3 held case shorter than Xbox 360 case")
	check(ps3.material_override.albedo_color.a<.5 and xbox.material_override.albedo_color.a<1,"PS3 clear and Xbox 360 translucent green plastic")
	check(dvd.material_override.normal_enabled and dvd.material_override.roughness_texture!=null,"Held plastic has normal and roughness detail")
	check(not dvd.get_parent().visible and g.held_pool.size()==60,"Detailed case pool hidden until interaction")
	check(g.get_node("CornerWindowPane").material_override.shader.resource_path=="res://rain_glass.gdshader","Corner pane uses unchanged rain and condensation shader")
	check(g.get_node("PhotographicLeafCards").multimesh.instance_count==384,"Leaves batched into one instanced draw")
	check(not g.model.find_child("tree-crown",true,false).visible,"Old polygon tree crowns hidden")
	var chute=g.candy.machines[1].node.get_node("PhysicalChute")
	var track=false
	for child in chute.get_children():
		if child is CollisionShape3D and child.shape is ConcavePolygonShape3D:track=child.shape.backface_collision
	check(track,"Spiral collision follows double-sided visible track")
	print("FEEDBACK_TESTS failures=",failures)
	quit(1 if failures else 0)
