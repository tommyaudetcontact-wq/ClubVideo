extends MeshInstance3D

const EDGES := [[0,1],[0,2],[0,4],[1,3],[1,5],[2,3],[2,6],[3,7],[4,5],[4,6],[5,7],[6,7]]

func _ready():
	var lines:=ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var corners:=PackedVector3Array()
	for i in range(8):
		corners.append(Vector3(.5 if i&1 else -.5,.5 if i&2 else -.5,.5 if i&4 else -.5))
	for edge in EDGES:
		var a:=corners[edge[0]]
		var b:=corners[edge[1]]
		lines.surface_add_vertex(a)
		lines.surface_add_vertex(a.lerp(b,.29))
		lines.surface_add_vertex(b)
		lines.surface_add_vertex(b.lerp(a,.29))
	lines.surface_end()
	mesh=lines
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color("ffe268")
	material_override=material
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()

func mark(pose:Transform3D,dimensions:Vector3):
	global_transform=Transform3D(pose.basis.orthonormalized().scaled_local(dimensions),pose.origin)
	show()
