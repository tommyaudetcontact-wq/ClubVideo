extends Node3D
var game
var manual_mode := true
var rain_enabled := true
var trailers_muted := false
var menu_open := false
var menu_page=0
var invite_mode := true
var confirm_new=false
var confirm_load=false
var panel: Node3D
var panel_material:StandardMaterial3D
var panel_title:Label3D
var labels: Array = []
var last_triggers := [false,false]
var loose_dvds: Array = []
var rain_nodes: Array = []
var mouse_look := false

func setup(g) -> void:
	game=g
	name="PauseAndInteractionModes"
	process_mode=Node.PROCESS_MODE_ALWAYS
	game.origin.process_mode=Node.PROCESS_MODE_ALWAYS
	var settings=ConfigFile.new()
	if settings.load("user://audio-settings.cfg")==OK:
		trailers_muted=bool(settings.get_value("audio","trailers_muted",false))
	_apply_trailer_audio()
	_build_menu()
	_build_rain()

func _build_menu() -> void:
	panel=Node3D.new()
	panel.name="PauseMenu"
	add_child(panel)
	var back:=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(.98,1.52)
	back.mesh=quad
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color("101d30")
	back.material_override=material
	panel_material=material
	panel.add_child(back)
	var title:=Label3D.new()
	title.text="VIDÉO CLUB · PAUSE"
	title.font_size=42
	title.pixel_size=.0008
	title.position=Vector3(0,.57,.012)
	title.modulate=Color("f2c362")
	panel.add_child(title)
	panel_title=title
	for row in range(11):
		var label:=Label3D.new()
		label.font_size=33
		label.pixel_size=.00075
		label.position=Vector3(0,.43-row*.108,.014)
		panel.add_child(label)
		labels.append(label)
	panel.visible=false
	_refresh_labels()

func _refresh_labels() -> void:
	var messenger:bool=menu_page==2
	panel_material.albedo_color=Color("d9edfc") if messenger else Color("101d30")
	panel_title.text="●  VIDÉO CLUB MESSENGER" if messenger else "VIDÉO CLUB · PAUSE"
	panel_title.modulate=Color("174c87") if messenger else Color("f2c362")
	for label in labels:
		label.modulate=Color("123968") if messenger else Color.WHITE
		label.outline_size=0 if messenger else 12
	if messenger:
		for label in labels:label.text=""
		labels[0].text="Retour"
		labels[1].text="LOBBY WI-FI · Joueurs disponibles"
		if not game.lobby:return
		labels[2].text="Sélectionne un joueur pour l’inviter" if game.lobby.available else "Active la coop pour ouvrir ta partie."
		var players:Array=game.lobby.list_players()
		for i in range(mini(players.size(),4)):labels[i+3].text="●  "+players[i].name+(" · héberge" if players[i].hosting else " · disponible")
		if players.is_empty():labels[3].text="Recherche de joueurs sur le Wi-Fi…" if game.lobby.available else ""
		labels[7].text="Lire / accuser réception" if not game.lobby.incoming.is_empty() else ""
		labels[8].text="Refuser la demande" if not game.lobby.incoming.is_empty() else ""
		labels[9].text=game.lobby.status.left(46)
		labels[10].text="Désactiver la coop" if game.lobby.available else "Activer la coop"
		return
	if menu_page==1:
		for label in labels:label.text=""
		labels[0].text="Retour aux options"
		labels[1].text="Sauvegarder la partie"
		labels[2].text="Confirmer le chargement ?" if confirm_load else "Continuer la sauvegarde"
		labels[3].text="Confirmer la nouvelle partie ?" if confirm_new else "Nouvelle partie"
		labels[4].text=game.session.last_status if game.session else "Mode commis indisponible"
		labels[5].text="Nouvelle partie : nouveau mélange de 10 %"
		labels[6].text="Chargement : remplace la partie en cours"
		labels[7].text="Sauvegarde automatique toutes les minutes"
		return
	labels[10].text="Avatar : "+game.clerk_model_name()+" · changer"
	labels[0].text="Reprendre"
	labels[1].text="Téléportation : "+("ACTIVÉE" if game.teleportation.enabled else "DÉSACTIVÉE")
	labels[2].text="Rangement manuel : "+("ACTIVÉ" if manual_mode else "ASSISTÉ")
	labels[3].text="Pluie extérieure : "+("ACTIVÉE" if rain_enabled else "DÉSACTIVÉE")
	labels[4].text="Ranger tous les DVD au sol"
	labels[5].text="Netflix · test : "+("ACTIVÉ" if game.netflix.enabled else "DÉSACTIVÉ")
	labels[6].text="Ouvrir Netflix / connexion"
	labels[7].text="Son des bandes-annonces : "+("COUPÉ" if trailers_muted else "ACTIVÉ")
	labels[8].text="Partie · sauvegarder / continuer / nouvelle"
	labels[9].text="Coop Wi-Fi"

func toggle_pause() -> void:
	confirm_new=false
	confirm_load=false
	menu_open=not menu_open
	panel.visible=menu_open
	game.hud.visible=not menu_open
	if menu_open:
		for i in range(2):last_triggers[i]=game.hands[i].get_float(&"trigger")>.6
		var forward: Vector3=-game.head.global_basis.z
		if forward.length()<.01:forward=Vector3.FORWARD
		forward=forward.normalized()
		panel.global_position=game.head.global_position+forward*1.05
		panel.look_at(game.head.global_position,game.head.global_basis.y,true)
		_refresh_labels()
		game.teleportation.arc.multimesh.visible_instance_count=0
		game.teleportation.marker.visible=false
	get_tree().paused=menu_open
	game.previous_frame_usec=0
	if not menu_open:
		for i in range(2):
			game.previous_trigger[i]=game.hands[i].get_float(&"trigger")>.6
			game.previous_grip[i]=game.hands[i].get_float(&"grip")>.6

func _menu_hit(origin: Vector3,direction: Vector3) -> int:
	var inv:=panel.global_transform.affine_inverse()
	var a:=inv*origin
	var d:=inv.basis*direction
	if absf(d.z)<.00001:return -1
	var t:float=-a.z/d.z
	if t<0 or t>3:return -1
	var p:=a+d*t
	if absf(p.x)>.43:return -1
	for i in range(11):
		if absf(p.y-(.43-i*.108))<.045:return i
	return -1

func _activate(row: int) -> void:
	if menu_page==2:
		match row:
			0:menu_page=0
			2:pass
			3,4,5,6:game.lobby.request(row-3,true)
			7:game.lobby.reply(true)
			8:game.lobby.reply(false)
			10:game.lobby.toggle_available()
		_refresh_labels()
		return
	if menu_page==1:
		match row:
			0:
				menu_page=0
				confirm_new=false
				confirm_load=false
			1:
				if game.session:game.session.save_game()
			2:
				if confirm_load and game.session:game.session.continue_game()
				else:confirm_load=true
				confirm_new=false
			3:
				if confirm_new and game.session:game.session.new_game()
				else:confirm_new=true
				confirm_load=false
		_refresh_labels()
		return
	match row:
		0:toggle_pause()
		1:game.teleportation.toggle()
		2:
			if game.held:game._message("Repose dâ€™abord le DVD tenu avant de changer le mode.")
			else:manual_mode=not manual_mode
		3:
			rain_enabled=not rain_enabled
			for rain in rain_nodes:rain.emitting=rain_enabled
		4:restore_loose_dvds()
		5:game.netflix.toggle()
		6:OS.shell_open("https://www.netflix.com/ca-fr/login")
		8:menu_page=1
		10:game.toggle_clerk_model()
		9:
			if game.lobby:
				menu_page=2
		7:
			trailers_muted=not trailers_muted
			_apply_trailer_audio()
			var settings=ConfigFile.new()
			settings.set_value("audio","trailers_muted",trailers_muted)
			settings.save("user://audio-settings.cfg")
	_refresh_labels()

func _apply_trailer_audio() -> void:
	game.trailer_player.volume=0.0 if trailers_muted else db_to_linear(-12.0)

func _physics_process(delta: float) -> void:
	if menu_open:
		if menu_page==2:_refresh_labels()
		for i in range(2):
			var pressed:bool=game.hands[i].get_float(&"trigger")>.6
			var row:=_menu_hit(game.aim_hands[i].global_position,-game.aim_hands[i].global_basis.z)
			if pressed and not last_triggers[i] and row>=0:_activate(row)
			last_triggers[i]=pressed
			game.hand_visuals[i].update_grip(delta,game.hands[i].get_float(&"trigger"),game.hands[i].get_float(&"grip"),game.held_hand==i)
		return
	if not game.xr_active and not game.touch_profile:
		var v:=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_Z) or Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)))
		if v.length()>1:v=v.normalized()
		var f:Vector3=-game.head.global_basis.z
		f.y=0
		f=f.normalized()
		game._move_player((f*v.y+f.cross(Vector3.UP)*v.x)*delta*1.9)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_TAB]:
		toggle_pause()
		get_viewport().set_input_as_handled()
	if not game.xr_active and event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:mouse_look=event.pressed
		if event.button_index==MOUSE_BUTTON_LEFT and event.pressed and menu_open:
			var p:Vector2=event.position
			var row:=_menu_hit(game.head.project_ray_origin(p),game.head.project_ray_normal(p))
			if row>=0:_activate(row)
	if not game.xr_active and mouse_look and not menu_open and event is InputEventMouseMotion:
		game.origin.rotation.y-=event.relative.x*.003
		game.head.rotation.x=clampf(game.head.rotation.x-event.relative.y*.003,-1.3,1.3)

func _build_rain() -> void:
	for entry in [[Vector3(0,4,20),Vector3(18,1,12),640],[Vector3(-8,4,0),Vector3(1.7,1,7),160]]:
		var rain:=GPUParticles3D.new()
		rain.name="ExteriorRain"
		rain.position=entry[0]
		rain.amount=entry[2]
		rain.lifetime=1.3
		rain.preprocess=.8
		rain.visibility_aabb=AABB(-entry[1]-Vector3(0,7,0),entry[1]*2+Vector3(0,7,0))
		var p:=ParticleProcessMaterial.new()
		p.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
		p.emission_box_extents=entry[1]
		p.direction=Vector3(.08,-1,.04)
		p.spread=3
		p.initial_velocity_min=8
		p.initial_velocity_max=10
		p.gravity=Vector3(0,-1,0)
		p.scale_min=.7
		p.scale_max=1.2
		rain.process_material=p
		var mesh:=QuadMesh.new()
		mesh.size=Vector2(.007,.13)
		var mat:=StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color=Color(.55,.66,.80,.24)
		mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
		mat.no_depth_test=false
		mesh.material=mat
		rain.draw_pass_1=mesh
		rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.add_child(rain)
		rain_nodes.append(rain)

func manual_release() -> bool:
	if not game.held:return false
	var record:Dictionary=game.held_record
	if not manual_mode:
		if record.has("loose_body") and is_instance_valid(record.loose_body):
			game.held.queue_free()
			record.loose_body.queue_free()
			record.erase("loose_body")
			_restore_slot(record)
			game.held=null
			game.held_hand=-1
			return true
		return false
	var target:Transform3D=record.world
	var visual:Node3D=game.held
	var near:bool=visual.global_position.distance_to(target.origin)<.095
	var angle:float=visual.global_basis.orthonormalized().get_rotation_quaternion().angle_to(target.basis.orthonormalized().get_rotation_quaternion())
	if near and minf(angle,absf(PI-angle))<.65:
		if record.has("loose_body") and is_instance_valid(record.loose_body):
			visual.reparent(game,false)
			visual.queue_free()
			record.loose_body.queue_free()
			record.erase("loose_body")
			record.erase("loose")
			game.held=null
			game.held_hand=-1
			_restore_slot(record)
			game._message("DVD rangÃ© dans son emplacement.")
			return true
		return false # standard release performs the final short slot alignment
	if game.flip_tween and game.flip_tween.is_valid():game.flip_tween.kill()
	var body:RigidBody3D
	var clone:Node3D
	if record.has("loose_body") and is_instance_valid(record.loose_body):
		body=record.loose_body
		clone=visual
		var xf:Transform3D=visual.global_transform
		clone.reparent(game,true)
		body.global_transform=xf
		clone.reparent(body,false)
		clone.transform=Transform3D.IDENTITY
	else:
		body=create_case_body(float(game.layout.movies[int(record.movie)].get("caseHeight",.19)))
		game.add_child(body)
		body.global_transform=visual.global_transform
		clone=visual.duplicate()
		body.add_child(clone)
		clone.transform=Transform3D.IDENTITY
		visual.visible=false
		visual.reparent(game,false)
		record.loose_body=body
		if not loose_dvds.has(record):loose_dvds.append(record)
	load("res://held_case.gd").set_detail(clone,false)
	body.collision_mask=1|8
	body.freeze=false
	body.sleeping=false
	body.linear_velocity=game.candy.hand_velocity(game.held_hand).limit_length(4)
	record.loose=true
	game.held=null
	game.held_hand=-1
	game._update_cover_lod(game.head.global_position,true)
	game._message("DVD lÃ¢chÃ©. RÃ©cupÃ¨re-le Ã  la main\npuis rapproche-le de sa place pour le ranger.")
	return true

func _restore_slot(record: Dictionary) -> void:
	record.group.multimesh.set_instance_transform(record.index,record.local)
	if game.shell and record.shell_index>=0:
		game.shell.multimesh.set_instance_transform(record.shell_index,game.shell.global_transform.affine_inverse()*record.world)
	record.erase("loose")

func try_loose_pickup(hand_index: int,by_grip: bool) -> bool:
	if not by_grip or game.held:return false
	for record in loose_dvds:
		if not record.has("loose_body") or not is_instance_valid(record.loose_body):continue
		var body:RigidBody3D=record.loose_body
		if game.hands[hand_index].global_position.distance_to(body.global_position)>.20:continue
		body.freeze=true
		body.collision_mask=0
		var visual:Node3D
		for child in body.get_children():
			if child is Node3D and not child is CollisionShape3D:visual=child
		if not visual:continue
		visual.reparent(game.dvd_grip_anchors[hand_index],false)
		load("res://held_case.gd").set_detail(visual,true)
		visual.transform=Transform3D.IDENTITY
		game.held=visual
		load("res://clerk_inventory.gd").bind(visual,record)
		game.held_record=record
		game.held_hand=hand_index
		game.held_by_grip=true
		game.held_back=false
		game.movie_id=int(record.movie)
		game._message(str(game.layout.movies[game.movie_id].title)+"\nRapproche le DVD de sa place, puis relÃ¢che la poignÃ©e.")
		return true
	return false

func restore_loose_dvds() -> void:
	for record in loose_dvds:
		if record.has("loose_body") and is_instance_valid(record.loose_body):
			if game.held_record==record and game.held:
				game.held.queue_free()
				game.held=null
				game.held_hand=-1
			record.loose_body.queue_free()
			record.erase("loose_body")
		_restore_slot(record)
	loose_dvds.clear()

func can_take_more() -> bool:
	var count:=0
	for record in loose_dvds:
		if record.has("loose_body") and is_instance_valid(record.loose_body):count+=1
	return count<12


# Shared by shelf copies and customer cases: only loose copies simulate physics.
func create_case_body(height:float=.19)->RigidBody3D:
	var body=RigidBody3D.new()
	body.name="LooseDVD"
	body.mass=.12
	body.collision_layer=8
	body.collision_mask=1|8
	body.continuous_cd=true
	body.linear_damp=.15
	body.angular_damp=.35
	var shape=CollisionShape3D.new()
	var box=BoxShape3D.new()
	box.size=Vector3(.135,height,.014)
	shape.shape=box
	body.add_child(shape)
	return body
