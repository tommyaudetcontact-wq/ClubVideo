extends Node3D
# Shared physical candy simulation. Layers: 1 scenery, 2 internal chute, 4 candy, 8 DVD.
var game
var machines: Array = []
var balls: Array = []
var held_balls := [null,null]
var hand_history := [[],[]]
var clock := 0.0
var static_world: StaticBody3D
var candy_mesh: SphereMesh
var candy_materials: Array = []
const MAX_BALLS := 12
const LIFE_SECONDS := 60.0

func setup(g) -> void:
	game = g
	name = "PhysicalGumballs"
	candy_mesh = SphereMesh.new()
	candy_mesh.radius = 0.014
	candy_mesh.height = 0.028
	candy_mesh.radial_segments = 20
	candy_mesh.rings = 10
	for color in ["e97886","70bf9a","75b6d4","e3c16a","cc92c4","e8a56a","dce5ce"]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color)
		mat.roughness = 0.32
		mat.emission_enabled=true
		mat.emission=Color(color)*.08
		candy_materials.append(mat)
	_build_world_collision()
	if game.gum:
		if game.gum_ball: game.gum_ball.visible = false
		_add_machine(game.gum,false)
	if ResourceLoader.exists("res://assets/spiral-machine.glb"):
		var blue: Node3D = load("res://assets/spiral-machine.glb").instantiate()
		blue.name = "SpiralGumballMachine"
		blue.position = Vector3(-5.12,0,4.10)
		blue.rotation.y = 0.28
		game.add_child(blue)
		var stock:MeshInstance3D=blue.find_child("gum-fill",true,false)
		if stock:
			var stock_material:StandardMaterial3D=stock.get_active_material(0).duplicate()
			stock_material.vertex_color_use_as_albedo=true
			stock.material_override=stock_material
		for part_name in ["coin-plate","outlet"]:
			var part:MeshInstance3D=blue.find_child(part_name,true,false)
			if part:
				var mat:StandardMaterial3D=part.get_active_material(0).duplicate()
				mat.metallic=.22
				mat.roughness=.40
				mat.albedo_color=Color(.66,.71,.76)
				part.material_override=mat
		for part_name in ["spiral-ramp","column"]:
			var part=blue.find_child(part_name,true,false)
			if part is MeshInstance3D:
				var mat:StandardMaterial3D=part.get_active_material(0).duplicate()
				mat.albedo_color.a=.24 if part_name=="spiral-ramp" else .07
				mat.roughness=.30
				part.material_override=mat
		_add_machine(blue,true)
		game.layout.colliders.append({"min":[-5.42,0,3.80],"max":[-4.82,1.5,4.40]})

func _build_world_collision() -> void:
	static_world = StaticBody3D.new()
	static_world.name = "ObjectSceneryCollision"
	static_world.collision_layer = 1
	static_world.collision_mask = 4|8
	add_child(static_world)
	_box(static_world,Vector3(80,0.12,80),Vector3(0,-0.14,12))
	_box(static_world,Vector3(11.6,0.08,14.4),Vector3(0,-0.04,0))
	for b in game.layout.colliders:
		var a := Vector3(b.min[0],b.min[1],b.min[2])
		var z := Vector3(b.max[0],b.max[1],b.max[2])
		if absf(a.x+1.9)<.001 and absf(z.x-1.9)<.001 and a.z<-5:z.y=1.09
		if z.y-a.y>0.01:
			_box(static_world,z-a,(a+z)*0.5)

func _box(parent: Node3D,size: Vector3,position: Vector3,rotation := Vector3.ZERO) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = position
	shape.rotation = rotation
	parent.add_child(shape)
	return shape

func _add_machine(node: Node3D,spiral: bool) -> void:
	var chute := StaticBody3D.new()
	chute.name = "PhysicalChute"
	chute.collision_layer = 2
	chute.collision_mask = 4
	node.add_child(chute)
	if spiral:
		# Closed visible U-track, double-sided static collision; real rolling under gravity.
		var ramp:MeshInstance3D=node.find_child("spiral-ramp",true,false)
		var collision:=CollisionShape3D.new()
		var track:=ConcavePolygonShape3D.new()
		track.set_faces(ramp.mesh.get_faces())
		track.backface_collision=true
		collision.shape=track
		collision.transform=node.global_transform.affine_inverse()*ramp.global_transform
		chute.add_child(collision)
		# Actual clear column encloses the track: robust convex cylinder proxy.
		for segment in range(40):
			var angle:float=TAU*segment/40.0
			var radial:=Vector3(cos(angle),0,sin(angle))
			var tangent:=Vector3(-sin(angle),0,cos(angle))
			var wall:=_box(chute,Vector3(.014,.61,.022),radial*.123+Vector3(0,.63,0))
			wall.basis=Basis(radial,Vector3.UP,tangent)
		# Hidden gravity-fed collector beneath the final turn; leads to the real outlet.
		_box(chute,Vector3(.22,.008,.25),Vector3(0,.283,.025),Vector3(.32,0,0))
		_box(chute,Vector3(.008,.11,.25),Vector3(-.112,.30,.02))
		_box(chute,Vector3(.008,.11,.25),Vector3(.112,.30,.02))
		_box(chute,Vector3(.22,.10,.008),Vector3(0,.32,-.103))
		_box(chute,Vector3(.008,.10,.30),Vector3(-.08,.29,.04),Vector3(0,.23,0))
		_box(chute,Vector3(.008,.10,.30),Vector3(.08,.29,.04),Vector3(0,-.23,0))
		_box(chute,Vector3(.11,.009,.09),Vector3(0,.224,.155))
		_box(chute,Vector3(.009,.05,.10),Vector3(-.055,.25,.155))
		_box(chute,Vector3(.009,.05,.10),Vector3(.055,.25,.155))
		_box(chute,Vector3(.11,.04,.009),Vector3(0,.247,.199))
	else:
		_box(chute,Vector3(.075,.008,.19),Vector3(0,.116,.13),Vector3(.68,0,0))
		_box(chute,Vector3(.095,.01,.09),Vector3(0,.031,.218))
		_box(chute,Vector3(.009,.055,.20),Vector3(-.045,.11,.14),Vector3(.68,0,0))
		_box(chute,Vector3(.009,.055,.20),Vector3(.045,.11,.14),Vector3(.68,0,0))
		_box(chute,Vector3(.10,.05,.01),Vector3(0,.052,.262))
	machines.append({"node":node,"spiral":spiral,"credit":0,"stock":223 if spiral else 450,"busy":false,"knob":node.find_child("crank" if spiral else "gumball-crank",true,false)})

func use_machine(index: int) -> bool:
	var m: Dictionary = machines[index]
	if m.busy: return false
	if m.stock<=0:
		game._message("La distributrice est vide.")
		return false
	if m.credit==0:
		m.credit = 1
		game._message("25 ¢ virtuels insérés\nGâchette : tourner la poignée")
		return true
	if balls.size()>=MAX_BALLS:
		game._message("Douze gommes sont déjà actives.\nAttends leur disparition pour en sortir une autre.")
		return false
	m.credit = 0
	m.stock -= 1
	m.busy = true
	var knob: Node3D = m.knob
	if knob:
		var turn := create_tween()
		turn.tween_property(knob,"rotation:z",knob.rotation.z-TAU,.7)
	_spawn(index)
	get_tree().create_timer(1.0,false).timeout.connect(func():m.busy=false)
	game._message("La gomme descend avec la gravité.\nPoignée près de la gomme : prendre · Relâcher : lancer")
	return true

func _spawn(index: int) -> RigidBody3D:
	var m: Dictionary = machines[index]
	var body := RigidBody3D.new()
	body.name = "PhysicalCandy"
	body.mass = .005
	body.gravity_scale = 1.0
	body.collision_layer = 4
	body.collision_mask = 1|2|4
	body.continuous_cd = true
	body.can_sleep = false
	body.linear_damp = .008
	body.angular_damp = .002
	var physics := PhysicsMaterial.new()
	physics.friction = .075
	physics.bounce = .06
	body.physics_material_override = physics
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .014
	shape.shape = sphere
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = candy_mesh
	mesh.material_override = candy_materials[balls.size()%candy_materials.size()]
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	add_child(body)
	body.global_position = m.node.to_global(Vector3(0,.945,.082) if m.spiral else Vector3(0,.235,.072))
	body.linear_velocity = m.node.global_basis*(Vector3(-.24,0,0) if m.spiral else Vector3(0,0,.06))
	if m.spiral:body.angular_velocity=m.node.global_basis*Vector3(0,0,-17.14)
	balls.append({"body":body,"born":clock,"machine":index,"held":-1})
	return body

func _physics_process(delta: float) -> void:
	clock += delta
	for i in range(2):
		var h: Array = hand_history[i]
		h.append({"time":clock,"position":game.hands[i].global_position})
		while h.size()>2 and clock-float(h[0].time)>.12: h.pop_front()
		if is_instance_valid(held_balls[i]):
			held_balls[i].global_transform = game.hands[i].global_transform
			held_balls[i].global_position = game.hands[i].to_global(Vector3(0,-.01,-.035))
			if game.xr_active and game.hands[i].get_float(&"grip")<.35:
				release_ball(i)
	for n in range(balls.size()-1,-1,-1):
		var ball: Dictionary = balls[n]
		if not ball.body.can_sleep and int(ball.held)<0:
			var machine:Dictionary=machines[int(ball.machine)]
			if not machine.spiral or machine.node.to_local(ball.body.global_position).y<.32:
				ball.body.can_sleep=true
				ball.body.gravity_scale=1.0
		if clock-float(ball.born)>=LIFE_SECONDS:
			if int(ball.held)>=0: held_balls[int(ball.held)]=null
			ball.body.queue_free()
			balls.remove_at(n)

func hand_velocity(index: int) -> Vector3:
	var h: Array = hand_history[index]
	if h.size()<2: return Vector3.ZERO
	var dt := float(h[-1].time)-float(h[0].time)
	if dt<.001: return Vector3.ZERO
	return ((h[-1].position-h[0].position)/dt).limit_length(9)

func grab_ball(index: int,body: RigidBody3D) -> void:
	body.linear_damp = .06
	body.gravity_scale = 1.0
	body.freeze = true
	body.collision_mask = 0
	body.linear_velocity = Vector3.ZERO
	held_balls[index]=body
	for ball in balls:
		if ball.body==body: ball.held=index

func release_ball(index: int) -> void:
	var body = held_balls[index]
	if not is_instance_valid(body): return
	body.collision_mask = 1|2|4
	body.freeze = false
	body.sleeping = false
	body.linear_velocity = hand_velocity(index)
	body.angular_velocity = Vector3(2,4,1)
	held_balls[index]=null
	for ball in balls:
		if ball.body==body: ball.held=-1

func try_interact(index: int,by_grip: bool) -> bool:
	if is_instance_valid(held_balls[index]):
		return true
	if by_grip and not game.held:
		var closest = null
		var distance := .15
		for ball in balls:
			if int(ball.held)>=0: continue
			var d: float = ball.body.global_position.distance_to(game.hands[index].global_position)
			if d<distance:
				distance=d
				closest=ball.body
		if closest:
			grab_ball(index,closest)
			return true
	if by_grip or game.held: return false
	var p: Vector3 = game.aim_hands[index].global_position
	var direction: Vector3 = -game.aim_hands[index].global_basis.z
	for j in range(machines.size()):
		var m: Dictionary = machines[j]
		var center: Vector3 = m.node.to_global(Vector3(0,1.0,.12) if m.spiral else Vector3(0,.30,0))
		var t: float = (center-p).dot(direction)
		if t>0 and t<2.5 and (p+direction*t).distance_to(center)<.24:
			var clear := true
			for b in game.cover_occluders:
				if not b.has_point(center) and b.intersects_segment(p,center)!=null: clear=false
			if clear:
				use_machine(j)
				return true
	return false




