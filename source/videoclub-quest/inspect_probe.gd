extends SceneTree
func _initialize():
 var probe=ReflectionProbe.new()
 for p in probe.get_property_list():
  if "mask" in p.name:print(p.name)
 probe.free()
 quit()
