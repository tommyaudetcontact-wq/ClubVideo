extends SceneTree
const Covers=preload("res://cover_textures.gd")
var failures:=0
func check(value:bool,description:String) -> void:
	if not value:failures+=1;push_error("CATALOGUE_STRESS: "+description)
func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false);game.clerk.set_physics_process(false);game.clerk.customers.set_physics_process(false)
	var maximum_cache:=0
	var maximum_lod:=0
	for index in 200:
		var movie:Dictionary=game.layout.movies[index]
		var held:=Node3D.new()
		game.add_child(held)
		load("res://held_case.gd").build(held,movie)
		for side in ["front","back","spine"]:
			var paper:MeshInstance3D=held.get_node("PaperInsert_"+side)
			var texture:Texture2D=paper.material_override.albedo_texture
			check(texture!=null and texture.get_height()>=724,"native paper resolution %d %s"%[index,side])
			check(texture.resource_path.begins_with("res://assets/fictional/"),"fictional paper identity")
		var disc:MeshInstance3D=game.clerk.inspection.create_disc(index,false)
		held.add_child(disc)
		var label:Texture2D=disc.material_override.get_shader_parameter("label_texture")
		check(label!=null and label.resource_path==movie.disc_label and label.get_width()>=768,"matching original fictional disc %d"%index)
		held.queue_free()
		var record:Dictionary=game.dvd_records[index%game.dvd_records.size()]
		game.head.global_position=record.world.origin+Vector3(0,.2,.7)
		game.head.look_at(record.world.origin)
		game._update_cover_lod(game.head.global_position,true)
		maximum_cache=maxi(maximum_cache,Covers.fictional_recent.size())
		maximum_lod=maxi(maximum_lod,game.lod_groups.size())
		check(Covers.fictional_recent.size()<=32,"paper LRU bounded")
		check(game.lod_groups.size()<=maxi(24,game.lod_selected.size()+8),"LOD cache bounded")
		await process_frame
	check(game.held_pool.is_empty(),"no 200-title hidden held pool")
	print("CATALOGUE_STRESS_COMPLETE failures=",failures," titles=200 paper_checks=600 disc_checks=200 maximum_cache=",maximum_cache," maximum_lod=",maximum_lod)
	quit(1 if failures else 0)
