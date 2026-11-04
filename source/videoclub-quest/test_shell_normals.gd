extends SceneTree
func _initialize():
 var mesh=load("res://held_case.gd").rounded_shell(.135,.19,.014)
 var a=mesh.surface_get_arrays(0)
 var bad=0
 for i in range(a[Mesh.ARRAY_VERTEX].size()):
  if a[Mesh.ARRAY_VERTEX][i].dot(a[Mesh.ARRAY_NORMAL][i])<0:bad+=1
 print("SHELL_INWARD_NORMALS=",bad)
 quit(1 if bad else 0)
