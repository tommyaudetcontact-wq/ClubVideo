extends RefCounted
const SCREW_COUNT:=20
const Props=preload("res://clerk_props.gd")
static func part_pose(width:float,index:int) -> Transform3D:
	return Transform3D(Basis.IDENTITY,Vector3((-1 if index==0 else 1)*(width/2-.013),.92,0) if index<2 else Vector3(0,.55+(index-2)*.35,0))
static func part_size(width:float,index:int) -> Vector3:
	return Vector3(.026,1.84,.34) if index<2 else Vector3(width-.052,.024,.34)
static func screw_pose(width:float,index:int) -> Transform3D:
	var side:float=-1 if index%2==0 else 1
	return Transform3D(Basis(Vector3.UP,side*PI/2),Vector3(side*(width/2+.003),.20+int((index%10)/2)*.35,-.10 if index<10 else .10))
static func done(assembly:Dictionary,index:int) -> bool:
	if assembly.has("screw_mask"):return (int(assembly.screw_mask)&(1<<index))!=0
	return index<int(assembly.get("screws",0))
static func backstore(parent:Node3D,world) -> void:
	var node:=Node3D.new();node.name="BackstoreDressing";parent.add_child(node)
	# Fixed staff equipment: steel storage rack, labelled cartons and practical workbench.
	for x in [-1.9,.25]:
		for z in [-14.12,-13.60]:Props.box(node,Vector3(x,1.10,z),Vector3(.035,2.20,.035),"737d83").material_override=Props.material("737d83",.5)
	for row in 5:
		var y:float=.12+row*.46
		Props.box(node,Vector3(-.825,y,-13.86),Vector3(2.18,.035,.56),"a8adb0")
		if row<4:
			for col in 3:
				var x:float=-1.60+col*.69
				Props.box(node,Vector3(x,y+.19,-13.88),Vector3(.53,.34,.43),"a68a60")
				Props.box(node,Vector3(x,y+.19,-13.659),Vector3(.35,.11,.002),"e7e0cb")
	for y in [.35,2.4]:Props.box(node,Vector3(-5.65,y,-11.3),Vector3(.012,.055,4.7),"7b6551")
	Props.box(node,Vector3(-3.75,1.70,-14.24),Vector3(2.4,.85,.025),"927354")
	for i in 5:
		var slip:=Props.box(node,Vector3(-4.6+i*.40,1.75,-14.21),Vector3(.30,.40,.004),"e7dfc5")
		Props.box(node,Vector3(-4.6+i*.40,1.96,-14.20),Vector3(.012,.012,.005),"c24c3d")
	for x in [-4.25,-3.7,-3.15]:
		Props.box(node,Vector3(x,.69,-12.95),Vector3(.15,.025,.36),"384752")
	Props.box(node,Vector3(2.85,.81,-13.45),Vector3(.23,.05,.19),"e6e1cb")
	Props.cylinder(node,Vector3(4.55,.83,-13.4),.055,.13,"b6c0bf")
	Props.cylinder(node,Vector3(4.55,.897,-13.4),.047,.002,"33231d")
	world.batch_props(node)
	Props.label(node,"VIDÉO CLUB · SERVICE TECHNIQUE",Vector3(-3.75,2.45,-14.20),.0011,42)
	Props.label(node,"NETTOYAGE  ·  RÉPARATIONS  ·  FOURNITURES",Vector3(-.82,2.44,-13.55),.0008,28)
	for col in 3:
		var label:=Props.label(node,["RETOURS","PIÈCES","ARCHIVES"][col],Vector3(-1.60+col*.69,1.70,-13.65),.0009,29)
		label.modulate=Color("263442");label.outline_size=0

static func staff_posters(parent:Node3D,movies:Array) -> void:
	for index in 2:
		var poster:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.56,.80)
		poster.mesh=quad;poster.position=Vector3(5.65,1.85,-10.6-index*.85);poster.rotation.y=-PI/2
		var material:=StandardMaterial3D.new();material.albedo_texture=load(str(movies[index].frontCover));material.roughness=.9
		poster.material_override=material;parent.add_child(poster)
