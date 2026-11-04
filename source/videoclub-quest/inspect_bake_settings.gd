extends SceneTree
func _initialize():
 var gi=LightmapGI.new()
 for p in gi.get_property_list():
  if "denois" in p.name or "direction" in p.name or "quality" in p.name:print(p.name," = ",gi.get(p.name))
 gi.free()
 quit()
