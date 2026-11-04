extends SceneTree
func _initialize():
 var gi=LightmapGI.new()
 print("BAKE_EXPOSED=",gi.has_method("bake"))
 for method in gi.get_method_list():
  if "bake" in str(method.name):print(method.name)
 gi.free()
 quit()
