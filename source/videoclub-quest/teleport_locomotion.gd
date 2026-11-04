extends Node3D

var game
var enabled := false
var aiming := false
var busy := false
var target_valid := false
var target := Vector3.ZERO
var refresh := 0.0
var arc: MultiMeshInstance3D
var marker: MeshInstance3D
var indicator_material: StandardMaterial3D
var fade: MeshInstance3D
var fade_material: StandardMaterial3D

func setup(owner_game) -> void:
	game = owner_game
	name = "TeleportLocomotion"
	indicator_material = StandardMaterial3D.new()
	indicator_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var segment := CylinderMesh.new()
	segment.top_radius = 0.003
	segment.bottom_radius = 0.003
	segment.height = 1.0
	segment.radial_segments = 5
	segment.rings = 1
	segment.material = indicator_material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = segment
	instances.instance_count = 32
	instances.visible_instance_count = 0
	arc = MultiMeshInstance3D.new()
	arc.multimesh = instances
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arc)
	marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.17
	ring.outer_radius = 0.22
	ring.rings = 24
	ring.ring_segments = 6
	marker.mesh = ring
	marker.material_override = indicator_material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	fade = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.32,0.32)
	fade.mesh = quad
	fade.position.z = -0.055
	fade_material = StandardMaterial3D.new()
	fade_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fade_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fade_material.no_depth_test = true
	fade_material.render_priority = 127
	fade_material.albedo_color = Color(0,0,0,0)
	fade.material_override = fade_material
	fade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.head.add_child(fade)
	fade.visible = false
	_hide_target()

func toggle() -> void:
	if busy:
		return
	enabled = not enabled
	aiming = false
	_hide_target()
	game._message("T\u00e9l\u00e9portation\nPousse le joystick gauche, vise avec la main gauche, puis rel\u00e2che.\nClic joystick gauche : revenir \u00e0 la marche" if enabled else "Mode marche\nClic joystick gauche : activer la t\u00e9l\u00e9portation")

func update(stick: Vector2, delta: float) -> void:
	if not enabled or busy:
		return
	if stick.y>0.6:
		aiming = true
		refresh += delta
		if refresh>=1.0/36.0:
			refresh = 0.0
			_refresh_target()
	elif aiming and stick.length()<0.25:
		_refresh_target()
		var destination := target
		var can_land := target_valid
		aiming = false
		_hide_target()
		if can_land:
			_jump(destination)
	elif stick.y< -0.4:
		aiming = false
		_hide_target()

func _floor_y(p: Vector3) -> float:
	return 0.0 if absf(p.x)<5.8 and p.z> -9.6 and p.z<7.2 else -0.075

func valid_destination(p: Vector3) -> bool:
	return p.x> -30 and p.x<30 and p.z> -9.0 and p.z<40 and not game._blocked(p)

func trace(start: Vector3, direction: Vector3) -> Dictionary:
	var points: Array[Vector3] = [start]
	var velocity := direction.normalized()*6.0
	var last := start
	for i in range(1,33):
		var t := float(i)*0.045
		var point := start+velocity*t+Vector3.DOWN*4.9*t*t
		var nearest = null
		var nearest_distance := INF
		for obstacle in game.cover_occluders:
			var hit = obstacle.intersects_segment(last,point)
			if hit!=null and last.distance_squared_to(hit)<nearest_distance:
				nearest = hit
				nearest_distance = last.distance_squared_to(hit)
		if nearest!=null:
			points.append(nearest)
			return {"points":points,"position":nearest,"valid":false}
		if absf(point.x)<5.8 and point.z> -9.6 and point.z<7.2 and point.y>3.16:
			points.append(point)
			return {"points":points,"position":point,"valid":false}
		var floor_y := _floor_y(point)
		if point.y<=floor_y:
			var weight := clampf((last.y-floor_y)/maxf(last.y-point.y,0.0001),0,1)
			var landing := last.lerp(point,weight)
			landing.y = _floor_y(landing)
			points.append(landing)
			var distance := Vector2(landing.x-start.x,landing.z-start.z).length()
			return {"points":points,"position":landing,"valid":distance<=7.5 and valid_destination(landing)}
		points.append(point)
		last = point
	return {"points":points,"position":last,"valid":false}

func _refresh_target() -> void:
	var hand = game.aim_hands[0]
	var result := trace(hand.global_position,-hand.global_basis.z)
	target = result.position
	target_valid = result.valid
	indicator_material.albedo_color = Color("55edb0") if target_valid else Color("f26a62")
	var points: Array = result.points
	for i in range(points.size()-1):
		var vector: Vector3 = points[i+1]-points[i]
		var basis := Basis.IDENTITY
		if vector.length()>0.0001:
			basis = Basis(Quaternion(Vector3.UP,vector.normalized())).scaled(Vector3(1,vector.length(),1))
		arc.multimesh.set_instance_transform(i,Transform3D(basis,(points[i]+points[i+1])*0.5))
	arc.multimesh.visible_instance_count = points.size()-1
	arc.visible = true
	marker.position = target+Vector3.UP*0.015
	marker.visible = true

func _hide_target() -> void:
	arc.visible = false
	marker.visible = false

func relocate(destination: Vector3) -> void:
	# Land the actual head position, accounting for room-scale tracking offset.
	var offset: Vector3 = game.head.global_position-game.origin.global_position
	offset.y = 0
	game.origin.global_position = destination-offset
	game.origin.global_position.y+=game.crouch_offset
	game._update_cover_lod(game.head.global_position,true)

func _jump(destination: Vector3) -> void:
	if busy or not valid_destination(destination):
		return
	busy = true
	fade.visible = true
	var out := create_tween()
	out.tween_property(fade_material,"albedo_color:a",1.0,0.07)
	await out.finished
	relocate(destination)
	var into := create_tween()
	into.tween_property(fade_material,"albedo_color:a",0.0,0.12)
	await into.finished
	fade.visible = false
	busy = false
