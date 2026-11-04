extends Node3D
const Props=preload("res://clerk_props.gd")
var clerk
var game
var bars:Array=[]
var shelves:Array=[]
var inserting:Node3D
var entry_depth := 0.0
var side_case:Node3D
const DETACHER := Vector3(.72,1.17,-6.18)
var last_bar_count=0
const LOOSE_RENDER_SLOTS=256
static func visual(node:Node3D)->Node3D:
	var existing=node.get_node_or_null("Antitheft")
	if existing:return existing
	var bar=Props.box(node,Vector3(.061,0,0),Vector3(.009,.17,.009),"e7bd28")
	bar.name="Antitheft"
	Props.box(bar,Vector3(0,-.09,0),Vector3(.018,.012,.014),"e7bd28")
	return bar
static func bind_visual(node:Node3D,record:Dictionary):
	var locked=bool(record.get("locked",true))
	node.set_meta("antitheft",locked)
	if locked:visual(node)
	else:
		var old=node.get_node_or_null("Antitheft")
		if old:
			node.remove_child(old)
			old.queue_free()
func setup(c):
	clerk=c
	game=c.game
	for size in [Vector3(.009,.17,.009),Vector3(.018,.012,.014)]:
		var node=MultiMeshInstance3D.new()
		var mesh=BoxMesh.new()
		mesh.size=size
		var mm=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=mesh
		mm.instance_count=game.dvd_records.size()+LOOSE_RENDER_SLOTS
		for index in range(mm.instance_count):mm.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
		node.multimesh=mm
		node.material_override=Props.material("e7bd28")
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		shelves.append(node)
	for record in game.dvd_records:
		if not record.has("locked"):record.locked=true
		update_slot(record)
	for i in range(8):put_in_bin(create_bar())
	update_bar_instances()
func update_slot(record:Dictionary):
	if record.is_empty() or shelves.is_empty():return
	var visible=record.get("locked",true) and not record.get("clerk_reserved",false) and not record.get("loose",false) and record!=game.held_record
	for i in range(2):
		var transform:Transform3D=record.world*Transform3D(Basis.IDENTITY,Vector3(.061,-.09 if i else 0,0))
		if not visible:transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)
		shelves[i].multimesh.set_instance_transform(record.id,transform)
func set_locked(node:Node3D,locked:bool):
	node.set_meta("antitheft",locked)
	var record:Dictionary=node.get_meta("inventory_record",{})
	if not record.is_empty():
		record.locked=locked
		update_slot(record)
	if locked:visual(node)
	else:
		var bar=node.get_node_or_null("Antitheft")
		if bar:
			node.remove_child(bar)
			bar.queue_free()
func create_bar()->RigidBody3D:
	var body=RigidBody3D.new()
	add_child(body)
	body.mass=.025
	body.freeze=true
	body.continuous_cd=true
	body.linear_damp=.7
	body.angular_damp=2
	var collision=CollisionShape3D.new()
	var shape=BoxShape3D.new()
	shape.size=Vector3(.014,.18,.014)
	collision.shape=shape
	body.add_child(collision)
	Props.box(body,Vector3.ZERO,Vector3(.009,.17,.009),"e7bd28")
	Props.box(body,Vector3(0,-.09,0),Vector3(.018,.012,.014),"e7bd28")
	for child in body.get_children():
		if child is MeshInstance3D:child.visible=false
	bars.append(body)
	return body
func hold(body:RigidBody3D,hand:int):
	body.set_meta("in_bin",false)
	body.freeze=true
	body.collision_layer=0
	body.collision_mask=0
	body.reparent(self)
	clerk.loose_lock=body
	clerk.lock_hand=hand
	update_hand()
func hand_transform(hand:int)->Transform3D:
	# Hold the rear end between fingers; the long bar extends in front of the palm.
	return game.hands[hand].global_transform*Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3(.025,-.015,-.10))
func update_hand():
	if clerk.lock_hand>=0 and is_instance_valid(clerk.loose_lock) and not is_instance_valid(clerk.lock_source):clerk.loose_lock.global_transform=hand_transform(clerk.lock_hand)
func put_in_bin(body:RigidBody3D):
	body.reparent(self)
	body.freeze=true
	body.collision_layer=0
	body.collision_mask=0
	var count=0
	for other in bars:
		if other!=body and other.get_meta("in_bin",false):count+=1
	body.global_position=clerk.lock_bin+Vector3((count%7-3)*.029,-.013+(count/7)*.014,0)
	body.rotation=Vector3(PI/2,0,0)
	body.set_meta("in_bin",true)
func interact(hand:int)->bool:
	if hand==clerk.lock_hand:
		if not is_instance_valid(clerk.lock_source):try_insert()
		return true
	if clerk.lock_hand>=0 or hand==game.held_hand or hand==clerk.secondary_hand or clerk.wallet.occupied(hand) or hand==clerk.phone_hand or hand==clerk.basket.hand or hand==clerk.inspection.finger:return false
	var p:Vector3=game.hands[hand].global_position
	if game.held and game.held.get_meta("antitheft",false) and not clerk.inspection.opened:
		var bottom=game.held.to_global(Vector3(.061,-.09,0))
		if p.distance_to(bottom)<.09 and game.held.global_position.distance_to(DETACHER)<.18:
			clerk.lock_source=game.held
			clerk.loose_lock=game.held.get_node("Antitheft")
			clerk.lock_hand=hand
			clerk.lock_start=p
			clerk.lock_axis=-game.held.global_basis.y.normalized()
			game._message("Maintiens au détacheur et tire la languette jaune vers le bas.")
			return true
	var chosen:RigidBody3D
	var distance=.12
	for body in bars:
		var gap=p.distance_to(body.global_position)
		if gap<distance:
			distance=gap
			chosen=body
	if chosen:
		hold(chosen,hand)
		return true
	return false
func try_insert()->bool:
	if not is_instance_valid(clerk.loose_lock) or is_instance_valid(clerk.lock_source) or not game.held or clerk.inspection.opened:return false
	if game.held.get_meta("antitheft",false):return false
	var body:Node3D=clerk.loose_lock
	var slot:Vector3=game.held.to_global(Vector3(.061,-.09,0))
	var axis:Vector3=game.held.global_basis.y.normalized()
	var raw := hand_transform(clerk.lock_hand)
	var tip := raw * Vector3(0,.085,0)
	var offset := tip-slot
	var depth := offset.dot(axis)
	var lateral := (offset-axis*depth).length()
	var alignment := raw.basis.y.normalized().dot(axis)
	if inserting!=game.held:
		inserting=null
		if offset.length()>.078 or alignment<.48:return false
		inserting=game.held
		entry_depth=depth
	elif lateral>.11 or depth<entry_depth-.07 or alignment<.20:
		inserting=null
		return false
	# Guide the visible bar into the slot while measuring the real hand push.
	var guided_basis:Basis=game.held.global_basis.orthonormalized()
	body.global_transform=Transform3D(guided_basis,slot+axis*(clampf(depth-entry_depth,0,.10)-.085))
	if depth-entry_depth<.075:return false
	set_locked(game.held,true)
	bars.erase(body)
	body.queue_free()
	clerk.loose_lock=null
	clerk.lock_hand=-1
	inserting=null
	clerk.refresh_terminal()
	game._message("Barre insérée. Boîtier verrouillé ; seul le détacheur permet de la retirer.")
	return true
func at_detacher() -> bool:
	return is_instance_valid(side_case) and side_case==game.held and game.held.global_position.distance_to(DETACHER)<.34

func update_case_pose(delta:float):
	var held:Node3D=game.held
	if side_case!=held:side_case=null
	if not held or clerk.inspection.opened:return
	var distance:=held.global_position.distance_to(DETACHER)
	var turn_sideways:bool=held.get_meta("antitheft",false) and distance<(.34 if side_case==held else .26)
	if turn_sideways:
		side_case=held
		if game.flip_tween and game.flip_tween.is_valid():game.flip_tween.kill()
	if side_case!=held:return
	var target:=PI/2 if turn_sideways else (PI if game.held_back else 0.0)
	held.rotation.y=rotate_toward(held.rotation.y,target,delta*10.0)
	if not turn_sideways and absf(angle_difference(held.rotation.y,target))<.002:side_case=null

func ensure_spare():
	for bar in bars:
		if bar.get_meta("in_bin",false):return
	put_in_bin(create_bar())

func tick(delta:float=1.0/72.0):
	ensure_spare()
	update_case_pose(delta)
	for body in bars:
		if not body.freeze and body.sleeping:
			body.freeze=true
			body.collision_layer=0
			body.collision_mask=0
	if is_instance_valid(clerk.lock_source):
		if game.held!=clerk.lock_source or clerk.lock_source.global_position.distance_to(DETACHER)>.26:
			release(clerk.lock_hand)
			return
		var travel=clampf((game.hands[clerk.lock_hand].global_position-clerk.lock_start).dot(clerk.lock_axis),0,.18)
		clerk.loose_lock.position.y=-travel
		if travel>=.15:
			var h=clerk.lock_hand
			set_locked(clerk.lock_source,false)
			clerk.lock_source=null
			hold(create_bar(),h)
			clerk.refresh_terminal()
		update_bar_instances()
		return
	update_hand()
	try_insert()
	update_bar_instances()
func release(hand:int):
	if hand!=clerk.lock_hand:return
	if is_instance_valid(clerk.lock_source):
		clerk.loose_lock.position=Vector3(.061,0,0)
		clerk.lock_source=null
	else:
		var body:RigidBody3D=clerk.loose_lock
		if body.global_position.distance_to(clerk.lock_bin)<.24:put_in_bin(body)
		else:
			body.freeze=false
			body.collision_layer=8
			body.collision_mask=1|8
			body.sleeping=false
			body.linear_velocity=game.candy.hand_velocity(hand).limit_length(3)
	clerk.lock_hand=-1
	clerk.loose_lock=null
	inserting=null
func snapshot()->Array:
	var result=[]
	for body in bars:
		var in_bin=body.get_meta("in_bin",false) or body==clerk.loose_lock
		result.append({"transform":body.global_transform,"in_bin":in_bin})
	return result
func restore(entries:Array):
	for body in bars:body.queue_free()
	bars.clear()
	for entry in entries:
		var body=create_bar()
		if entry.in_bin:put_in_bin(body)
		else:
			body.global_transform=entry.transform
			body.freeze=false
			body.collision_layer=8
			body.collision_mask=1|8

func update_bar_instances():
	for index in range(bars.size()):
		var body:RigidBody3D=bars[index]
		if index>=LOOSE_RENDER_SLOTS:
			for child in body.get_children():
				if child is MeshInstance3D:child.visible=true
			continue
		if body.get_meta("draw_index",-1)==index and body.get_meta("draw_transform",Transform3D.IDENTITY)==body.global_transform:continue
		body.set_meta("draw_index",index)
		body.set_meta("draw_transform",body.global_transform)
		for i in range(2):
			var transform=body.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,-.09 if i else 0,0))
			shelves[i].multimesh.set_instance_transform(game.dvd_records.size()+index,transform)
	for index in range(bars.size(),mini(last_bar_count,LOOSE_RENDER_SLOTS)):
		for node in shelves:node.multimesh.set_instance_transform(game.dvd_records.size()+index,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
	last_bar_count=bars.size()
