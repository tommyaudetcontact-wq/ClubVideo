extends Node3D

var anchors:Array[Node3D]=[]
var targets:Array[Transform3D]=[]
var valid_pose:=false

func _ready():
	for index in range(3):
		var anchor:=Node3D.new()
		add_child(anchor)
		anchors.append(anchor)
		targets.append(Transform3D.IDENTITY)
		if index==0:
			var head:=MeshInstance3D.new()
			var mesh:=SphereMesh.new()
			mesh.radius=.11
			mesh.height=.23
			mesh.radial_segments=12
			mesh.rings=6
			head.mesh=mesh
			head.material_override=material(Color("5d80ad"))
			anchor.add_child(head)
			var visor:=MeshInstance3D.new()
			var front:=BoxMesh.new()
			front.size=Vector3(.18,.075,.065)
			visor.mesh=front
			visor.material_override=material(Color("192636"))
			visor.position=Vector3(0,0,-.088)
			anchor.add_child(visor)
		else:
			var glove:=Node3D.new()
			glove.set_script(load("res://vr_hand.gd"))
			glove.left=index==1
			anchor.add_child(glove)
	hide()

func material(color:Color)->StandardMaterial3D:
	var result:=StandardMaterial3D.new()
	result.albedo_color=color
	return result

static func pack(game)->Array:
	var points:Array=[game.head]
	if game.xr_active:points.append_array(game.hands)
	var result:Array=[]
	for point in points:
		var position:Vector3=point.global_position
		var rotation:Vector3=point.global_basis.get_euler()
		result.append([position.x,position.y,position.z,rotation.x,rotation.y,rotation.z])
	return result

func receive(data:Variant):
	if not data is Array or data.size() not in [1,3]:return
	var decoded:Array[Transform3D]=[]
	for values in data:
		if not values is Array or values.size()!=6:return
		for value in values:
			if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value))>50.0:return
		var position:=Vector3(values[0],values[1],values[2])
		var rotation:=Vector3(values[3],values[4],values[5])
		decoded.append(Transform3D(Basis.from_euler(rotation),position))
	for index in range(anchors.size()):
		anchors[index].visible=index<decoded.size()
		if index>=decoded.size():continue
		targets[index]=decoded[index]
		if not valid_pose:anchors[index].global_transform=targets[index]
	valid_pose=true
	show()

func _process(delta:float):
	if not visible:return
	for index in range(anchors.size()):
		if anchors[index].visible:
			anchors[index].global_transform=anchors[index].global_transform.interpolate_with(targets[index],1.0-exp(-delta*19.0))
