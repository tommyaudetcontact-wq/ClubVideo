extends Node3D

const Props=preload("res://clerk_props.gd")
const Actor=preload("res://customer_actor.gd")
const COMMENTS:Array[String]=[
	"VHSfan : Le club est beau ce soir !",
	"Camille : Salut du Québec !",
	"RetroMax : Je louais ça tout le temps.",
	"Julie : Qui a choisi le film ?",
	"Alex : Un jeu de course !",
	"Sam : J’aime les néons.",
	"Mia : Le rayon horreur !",
	"Jo : Salut la gang !",
	"Max : Beau retour en 2002 !",
	"Léa : Je prends deux films.",
]
var game
const CHAT_PAGE_SIZE:=7
const DURATIONS:=[10,15,20,30]
var duration_index:=2
var challenge_remaining:=-1.0
var challenge_report:=""
var challenge_stats:Dictionary={}
var challenge_menu:=false
var confirm_restart:=false
var event_label:Label3D
var event_text:=""
var pending_specials:Array[int]=[]
var wrist_panel:Node3D
var wrist:Label3D
var wrist_footer:Label3D
var chat_chime:AudioStreamPlayer
var comment_offset:=0
var comment_timer:=0.0
var next_comment:=-1
var scroll_repeat:=0.0
var comments:Array[String]=[]
var queued_clients:=0
var fallen_cases:Dictionary={}
var blast_elapsed:=0.0
var blast_frame:=0.0
const BLAST_DURATION:=1.35
var arrival_delay:=0.0
var guest:Node3D
var guest_seconds:=0.0
var special_busy:=false
var switching:=false
var chord_serial:Dictionary={}
var chord_latched:Dictionary={}

func setup(owner_game) -> void:
	game=owner_game
	wrist_panel=Node3D.new()
	wrist_panel.name="ChatStreamer"
	game.hands[0].add_child(wrist_panel)
	wrist_panel.position=Vector3(0,.11,.12)
	var background:=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(.46,.35)
	background.mesh=quad
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color("d9edfc")
	material.no_depth_test=true
	background.material_override=material
	wrist_panel.add_child(background)
	wrist_label("● VIDÉO CLUB MESSENGER",.144,36,Color("174c87"))
	event_label=wrist_label("",.107,29,Color("255c94"))
	wrist=wrist_label("",-.014,32,Color("123968"))
	wrist.width=960
	wrist.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	wrist_footer=wrist_label("",-.145,28,Color("235a85"))
	wrist_panel.hide()
	chat_chime=AudioStreamPlayer.new()
	chat_chime.stream=make_chat_chime()
	chat_chime.volume_db=-20
	add_child(chat_chime)

func wrist_label(value:String,y:float,size:int,color:Color) -> Label3D:
	var label:=Label3D.new()
	label.text=value
	label.font_size=size
	label.pixel_size=.00044
	label.outline_size=0
	label.no_depth_test=true
	label.modulate=color
	label.position=Vector3(0,y,.002)
	wrist_panel.add_child(label)
	return label

func make_chat_chime() -> AudioStreamWAV:
	const RATE:=16000
	const FRAMES:=1600
	var samples:=PackedByteArray()
	samples.resize(FRAMES*2)
	for i in FRAMES:
		var t:=float(i)/RATE
		var envelope:=minf(1,t*220)*pow(1-float(i)/FRAMES,2)
		samples.encode_s16(i*2,roundi(sin(TAU*880*t)*envelope*15000))
	var clip:=AudioStreamWAV.new()
	clip.format=AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate=RATE
	clip.data=samples
	return clip

func controller_button(action:StringName,hand:int) -> bool:
	if action==&"ax_button" and not game.streamer_mode:return false
	if action not in [&"by_button",&"primary_click",&"ax_button"]:return false
	if chord_latched.get(action,false):return true
	var serial:int=int(chord_serial.get(action,0))+1
	chord_serial[action]=serial
	if game.hands[1-hand].is_button_pressed(action):
		chord_latched[action]=true
		if action==&"by_button":
			toggle_menu()
		elif game.streamer_mode and not game.modes.menu_open:
			queue_clients(1,action!=&"ax_button")
		unlatch_when_released(action)
	elif hand==0:
		single_after_chord_window(action,serial)
	return true

func single_after_chord_window(action:StringName,serial:int) -> void:
	await get_tree().create_timer(.18,true).timeout
	if not is_inside_tree() or chord_serial.get(action)!=serial:return
	if action==&"by_button":
		game.modes.menu_page=0
		game.modes.toggle_pause()
	elif not game.modes.menu_open:
		if action==&"ax_button":game._recenter_entry(true)
		else:game.teleportation.toggle()

func unlatch_when_released(action:StringName) -> void:
	while is_inside_tree() and (game.hands[0].is_button_pressed(action) or game.hands[1].is_button_pressed(action)):
		await get_tree().process_frame
	chord_latched.erase(action)

func toggle_menu() -> void:
	var modes=game.modes
	if modes.menu_open and modes.menu_page==3:
		modes.toggle_pause()
		modes.menu_page=0
	else:
		modes.menu_page=3
		if not modes.menu_open:modes.toggle_pause()
		else:modes._refresh_labels()

func menu_labels(labels:Array) -> void:
	for label in labels:label.text=""
	if challenge_menu and game.streamer_mode:
		labels[0].text="Retour aux événements"
		labels[1].text="Durée · %d minutes"%DURATIONS[duration_index]
		labels[2].text="Démarrer le défi" if challenge_remaining<0 else "Défi en cours" if challenge_remaining>0 else "Temps écoulé"
		labels[3].text=challenge_report
		if not challenge_stats.is_empty():
			labels[4].text="Boîtiers à ranger : %d"%challenge_stats.cases
			labels[6].text="Caisse : %.2f $ / %.2f $"%[challenge_stats.cash/100.0,challenge_stats.expected/100.0]
			var difference:int=challenge_stats.cash-challenge_stats.expected
			labels[7].text="Écart de caisse : %+.2f $"%(difference/100.0)
			labels[8].text="Clients servis : %d · restants : %d"%[challenge_stats.served,challenge_stats.remaining]
			labels[9].text="Pertes : %.2f $"%(challenge_stats.losses/100.0)
			labels[10].text="Caisse à fermer ou argent à ranger" if not challenge_stats.tidy_cash else ""
		labels[5].text="Confirmer le redémarrage Streamer" if confirm_restart else "Nouvelle partie Streamer"
		return
	labels[0].text="Reprendre"
	labels[1].text="Retour au mode commis" if game.streamer_mode else "Entrer en mode Streamer"
	if not game.streamer_mode:
		labels[3].text="Sauvegarde séparée · Quest"
		return
	labels[2].text="Commentaires fictifs au poignet"
	labels[3].text="1 $ · Client et phrase"
	labels[4].text="2 $ · Pochette dans la chute"
	labels[5].text="3 $ · Famille de cinq enfants"
	labels[6].text="5 $ · Rush de cinq clients"
	labels[7].text="10 $ · Visiteur web simulé"
	labels[8].text="Sauvegarder le mode Streamer"
	labels[9].text="20 $ · Explosion dans le club"
	labels[10].text="Défi du live · durée et nouvelle partie"

func menu_action(row:int) -> void:
	if challenge_menu and game.streamer_mode:
		match row:
			0:
				challenge_menu=false
				confirm_restart=false
			1:duration_index=(duration_index+1)%DURATIONS.size()
			2:
				if challenge_remaining<0:
					challenge_remaining=DURATIONS[duration_index]*60.0
					notify_event("Défi du live commencé")
					challenge_menu=false
					toggle_menu()
					return
			5:
				if confirm_restart and game.session.save_path=="user://club-streamer.dat":
					game.session.new_game()
					return
				confirm_restart=true
		game.modes._refresh_labels()
		return
	if row==10 and game.streamer_mode:
		challenge_menu=true
		game.modes._refresh_labels()
		return
	if row==1:
		switch_mode()
		return
	if row==0:
		toggle_menu()
		return
	if not game.streamer_mode or row<2 or row>9:return
	if row==8:
		game.session.save_game()
		return
	toggle_menu()
	match row:
		2:
			next_comment=0
			comment_timer=0.0
		3,4,5:
			run_special(row-2)
		6:
			notify_event("5 $ · Rush de cinq clients")
			queue_clients(5)
		7:spawn_guest()
		9:explode_shelves()

func switch_mode() -> void:
	if switching:return
	if game.lobby.available or game.clerk.lan.server or game.session.guest_coop():
		game._message("Désactive la coop avant de changer de mode.")
		return
	if not game.session.load_failed and (game.streamer_mode or game.clerk.shift.started):
		if not game.session.save_game(false):return
	switching=true
	get_tree().set_meta("streamer_mode",not game.streamer_mode)
	game.session.load_failed=true
	get_tree().paused=false
	get_tree().reload_current_scene()

func queue_clients(count:int,announce:bool=true) -> void:
	if not game.streamer_mode:return
	queued_clients=mini(queued_clients+count,20)
	if announce:game._message("%d client(s) en attente."%queued_clients)

func _process(dt:float) -> void:
	if not game.streamer_mode:return
	advance_blast(dt)
	if challenge_remaining>0:
		var previous:=ceili(challenge_remaining)
		challenge_remaining=maxf(0,challenge_remaining-dt)
		if challenge_remaining==0:
			challenge_report=check_challenge()
			notify_event(challenge_report)
			challenge_menu=true
			toggle_menu()
		elif ceili(challenge_remaining)!=previous:refresh_wrist()
	if not special_busy and not pending_specials.is_empty():
		run_special(pending_specials.pop_front())
	if next_comment>=0:
		comment_timer-=dt
		if comment_timer<=0:
			add_comment(COMMENTS[next_comment])
			next_comment+=1
			comment_timer=1.3
			if next_comment>=COMMENTS.size():next_comment=-1
	if queued_clients>0:
		arrival_delay=maxf(0,arrival_delay-dt)
		if arrival_delay<=0 and game.clerk.customers.spawn_customer():
			queued_clients-=1
			arrival_delay=1.65
	if is_instance_valid(guest):
		guest_seconds=maxf(0,guest_seconds-dt)
		if guest_seconds<=0:
			guest.queue_free()
			guest=null
			refresh_wrist()
		else:
			var seconds:=ceili(guest_seconds)
			if not wrist.text.ends_with("%d:%02d"%[seconds/60,seconds%60]):refresh_wrist()
	var offset:Vector3=wrist_panel.global_position-game.head.global_position
	wrist_panel.visible=(not wrist.text.is_empty() or not event_text.is_empty() or challenge_remaining>=0) and offset.length()>.22 and offset.length()<1.05 and (-game.head.global_basis.z).dot(offset.normalized())>.82
	if wrist_panel.visible:wrist_panel.look_at(game.head.global_position,game.head.global_basis.y,true)

func add_comment(message:String) -> void:
	if comment_offset>0:comment_offset+=1
	comments.append(message)
	if comments.size()>60:comments.pop_front()
	comment_offset=mini(comment_offset,maxi(0,comments.size()-CHAT_PAGE_SIZE))
	refresh_wrist()
	chat_chime.play()

func scroll_chat(stick:Vector2,dt:float) -> bool:
	if not game.streamer_mode or not wrist_panel.visible:return false
	if absf(stick.y)<.35:scroll_repeat=0.0
	if absf(stick.y)<.55 or absf(stick.x)>absf(stick.y):return true
	scroll_repeat-=dt
	if scroll_repeat<=0:
		scroll_repeat=.22
		comment_offset=clampi(comment_offset+(1 if stick.y>0 else -1),0,maxi(0,comments.size()-CHAT_PAGE_SIZE))
		refresh_wrist()
	return true

func refresh_wrist() -> void:
	var end:=comments.size()-comment_offset
	var lines:Array[String]=comments.slice(maxi(0,end-CHAT_PAGE_SIZE),end)
	if is_instance_valid(guest):
		var seconds:=ceili(guest_seconds)
		lines.append("Visiteur test · %d:%02d"%[seconds/60,seconds%60])
	wrist.text="\n".join(lines)
	var timer:=""
	if challenge_remaining>=0:
		var remaining:=ceili(challenge_remaining)
		timer="  ·  %d:%02d"%[remaining/60,remaining%60]
	event_label.text=event_text+timer
	wrist_footer.text="↑ ↓  Joystick droit    ·    "+("%d plus récent(s)"%comment_offset if comment_offset>0 else "En direct")

func notify_event(message:String) -> void:
	event_text=message
	refresh_wrist()
	chat_chime.play()
	game._message(message)

func check_challenge() -> String:
	var clerk=game.clerk
	var cases_to_shelve:int=fallen_cases.size()+game.modes.loose_dvds.size()
	for item in clerk.cases:
		if item.kind!="streamer_gift":cases_to_shelve+=1
	if game.held and clerk.held_service.is_empty() and game.held_record not in game.modes.loose_dvds:
		cases_to_shelve+=1
	var cash:int=clerk.shift.cash_in_till()
	var expected:int=clerk.shift.initial_cash+clerk.shift.revenue-clerk.shift.refunds
	var tidy_cash:bool=clerk.wallet.loose.is_empty() and not clerk.wallet.occupied(0) and not clerk.wallet.occupied(1) and not clerk.drawer_open
	var remaining:int=queued_clients
	for customer in clerk.customers.customers:
		if customer.state!="exit":remaining+=1
	challenge_stats={
		"cases":cases_to_shelve,"cash":cash,"expected":expected,
		"served":clerk.shift.served,"remaining":remaining,"losses":clerk.shift.loss_total(),
		"tidy_cash":tidy_cash
	}
	if cases_to_shelve==0 and cash==expected and tidy_cash and remaining==0:return "Défi réussi · club en ordre"
	return "Temps écoulé · bilan du défi"

func spawn_guest() -> void:
	if is_instance_valid(guest):return
	guest=Props.customer(self,randi_range(0,5))
	guest.position=Vector3(.25,0,-4.9)
	guest.look_at(Vector3(.25,0,-6.3))
	var label:=Label3D.new()
	label.text="VISITEUR WEB · TEST LOCAL"
	label.position.y=1.9
	label.font_size=32
	label.pixel_size=.0014
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	guest.add_child(label)
	guest_seconds=300.0
	refresh_wrist()
	notify_event("10 $ · Visiteur simulé")

func walk(person:Node3D,target:Vector3,speed:float=2.1) -> void:
	var route:Dictionary={"node":person}
	if not game.clerk.customers.route(route,target):return
	Actor.animate(person,"Walk")
	var motion:=create_tween()
	var previous:=person.global_position
	var heading:=person.global_rotation.y
	for cell:Vector2 in route.path:
		var point:=Vector3(cell.x,0,cell.y)
		var step:=point-previous
		if step.length()<.03:continue
		var next_heading:=heading+angle_difference(heading,atan2(-step.x,-step.z))
		if absf(next_heading-heading)>.8:
			motion.tween_property(person,"global_rotation:y",next_heading,.15)
			motion.tween_property(person,"global_position",point,step.length()/speed)
		else:
			motion.tween_property(person,"global_position",point,step.length()/speed)
			motion.parallel().tween_property(person,"global_rotation:y",next_heading,.09)
		heading=next_heading
		previous=point
	if motion.is_running():await motion.finished
	if is_instance_valid(person):Actor.animate(person,"Idle")

func run_special(tier:int) -> void:
	if special_busy:
		pending_specials.append(tier)
		game._message("Événement ajouté à la file.")
		return
	special_busy=true
	notify_event(["1 $ · Client et phrase","2 $ · Pochette dans la chute","3 $ · Famille de cinq enfants"][tier-1])
	var visitor:=Props.customer(self,randi_range(0,5))
	visitor.position=Vector3(-4,0,9)
	visitor.add_to_group("streamer_door_visitor")
	if tier==3:
		var children:Array[Node3D]=[]
		for index in range(5):
			var child:=Props.customer(visitor,6+index%2)
			child.position=Vector3((index%2-.5)*.68,0,.50+float(index/2)*.43)
			children.append(child)
			Actor.animate(child,"Walk")
		await walk(visitor,Vector3(-4,0,4.5))
		for index in range(5):
			var child:=children[index]
			child.reparent(self)
			child_chaos(child,index)
		await walk(visitor,Vector3(-4,0,9))
	elif tier==2:
		await walk(visitor,Vector3(-2.5,0,-4.8))
		drop_demo_case()
		await walk(visitor,Vector3(-4,0,9))
	else:
		await walk(visitor,Vector3(-.6,0,-5.05))
		while not player_at_counter():
			await get_tree().create_timer(.20,false).timeout
		visitor.look_at(Vector3(game.head.global_position.x,0,game.head.global_position.z))
		var phrase:="Salut ! Ton club vidéo me rappelle mes vendredis soir."
		game._message("Client du live : "+phrase)
		var voice:=AudioStreamPlayer3D.new()
		voice.stream=load("res://assets/streamer-client-fr.mp3")
		voice.position.y=1.55
		voice.unit_size=3.0
		visitor.add_child(voice)
		voice.play()
		await get_tree().create_timer(4.5,false).timeout
		await walk(visitor,Vector3(-4,0,9))
	visitor.queue_free()
	special_busy=false

func player_at_counter() -> bool:
	var position:Vector3=game.head.global_position
	return position.x>=-2.25 and position.x<=1.85 and position.z<=-6.48 and position.z>=-7.85

func child_chaos(child:Node3D,index:int) -> void:
	await get_tree().create_timer(float(index)*.35,false).timeout
	child.add_to_group("streamer_door_visitor")
	var anchor:=Vector3(-3.7+float(index%2)*2.3,0,-2.4+float(index)*1.32)
	var nearest:Vector3=anchor
	var distance:=INF
	for record in game.dvd_records:
		var shelf:Vector3=record.world.origin
		var gap:=anchor.distance_squared_to(shelf)
		if gap<distance:
			distance=gap
			nearest=shelf
	await walk(child,game.clerk.customers.aisle_for(nearest))
	for drop in range(randi_range(1,4)):
		game.clerk.make_mess({"node":child},28)
		await get_tree().create_timer(.28,false).timeout
	await walk(child,Vector3(-4,0,9))
	child.queue_free()

func drop_demo_case() -> void:
	var item:Dictionary=game.clerk.new_case(0,Vector3(-2.55,1.16,-5.72),"streamer_gift")
	var image:=Image.new()
	image.load_svg_from_string("""<svg xmlns='http://www.w3.org/2000/svg' width='256' height='360'>
	<rect width='256' height='360' fill='#1b4059'/><circle cx='135' cy='145' r='62' fill='#f5c46e'/>
	<path d='M0 235 L70 126 L111 226 L166 174 L256 244 V360 H0Z' fill='#6ca895'/>
	<path d='M0 270 Q90 224 154 276 T256 267 V360 H0Z' fill='#24304e'/>
	</svg>""")
	var sleeve:MeshInstance3D=item.node.get_node("PaperInsert_front")
	var material:StandardMaterial3D=sleeve.material_override.duplicate()
	material.albedo_texture=ImageTexture.create_from_image(image)
	sleeve.material_override=material
	var cover:=Label3D.new()
	cover.text="★\nLE FILM DU LIVE\nDessin test"
	cover.position=Vector3(0,.043,.010)
	cover.font_size=30
	cover.pixel_size=.00057
	cover.modulate=Color("ffe5a3")
	item.node.add_child(cover)
	item.node.set_meta("customer_animating",true)
	var motion:=create_tween()
	motion.tween_property(item.node,"position",game.clerk.return_bin+Vector3.UP*.09,.6)
	motion.tween_callback(func():item.node.set_meta("customer_animating",false))


func explode_shelves() -> void:
	if not game.streamer_mode:return
	var added:=0
	for record in game.dvd_records:
		if record.get("loose",false) or record.get("clerk_reserved",false) or record==game.held_record:continue
		var shelf:Vector3=record.world.origin
		var aisle:Vector3=game.clerk.customers.aisle_for(shelf)
		var floor_point:=aisle+Vector3(randf_range(-.09,.09),randf_range(.012,.045),randf_range(-.09,.09))
		var floor_basis:=Basis(Vector3.UP,randf_range(-PI,PI))*Basis(Vector3.RIGHT,-PI/2)
		fallen_cases[record.id]={"pose":Transform3D(floor_basis,floor_point),"flying":true}
		record.loose=true
		game.clerk.locks.update_slot(record)
		added+=1
	if added==0:return
	blast_elapsed=0.0
	blast_frame=0.0
	game._update_cover_lod(game.head.global_position,true)
	notify_event("20 $ · Explosion · %d boîtiers"%added)
	play_blast()

func advance_blast(dt:float) -> void:
	if fallen_cases.is_empty() or blast_elapsed>=BLAST_DURATION:return
	blast_elapsed=minf(BLAST_DURATION,blast_elapsed+dt)
	blast_frame+=dt
	if blast_frame<.033 and blast_elapsed<BLAST_DURATION:return
	blast_frame=0.0
	for id in fallen_cases:
		var entry:Dictionary=fallen_cases[id]
		if not entry.flying:continue
		var record:Dictionary=game.dvd_records[id]
		var target:Transform3D=entry.pose
		var t:=clampf((blast_elapsed-float(int(id)%13)*.013)/1.18,0,1)
		var pose:Transform3D=record.world.interpolate_with(target,t)
		pose.origin.y=lerpf(record.world.origin.y,target.origin.y,t*t)+sin(t*PI)*.29
		draw_fallen(record,pose)
		entry.flying=t<1.0

func draw_fallen(record:Dictionary,pose:Transform3D) -> void:
	record.group.multimesh.set_instance_transform(record.index,record.group.global_transform.affine_inverse()*pose)
	if game.shell and record.shell_index>=0:
		game.shell.multimesh.set_instance_transform(record.shell_index,game.shell.global_transform.affine_inverse()*pose)

func try_pickup_fallen(hand:int,grip:bool) -> bool:
	if not grip or game.held or fallen_cases.is_empty():return false
	var position:Vector3=game.hands[hand].global_position
	var closest:=-1
	var distance:=.21
	for id in fallen_cases:
		var entry:Dictionary=fallen_cases[id]
		if entry.flying:continue
		var gap:=position.distance_to(entry.pose.origin)
		if gap<distance:
			distance=gap
			closest=id
	if closest<0:return false
	var record:Dictionary=game.dvd_records[closest]
	fallen_cases.erase(closest)
	record.erase("loose")
	game._take(record,hand,true)
	return true

func restore_fallen_to_shelves() -> void:
	for id in fallen_cases:
		var record:Dictionary=game.dvd_records[id]
		game.modes._restore_slot(record)
		game.clerk.locks.update_slot(record)
	fallen_cases.clear()
	game._update_cover_lod(game.head.global_position,true)

func pack_fallen() -> Dictionary:
	var result:Dictionary={}
	for id in fallen_cases:result[id]=fallen_cases[id].pose
	return result

func load_fallen(poses:Dictionary) -> void:
	for id in poses:
		if not id is int or id<0 or id>=game.dvd_records.size() or not poses[id] is Transform3D:continue
		var record:Dictionary=game.dvd_records[id]
		fallen_cases[id]={"pose":poses[id],"flying":false}
		record.loose=true
		draw_fallen(record,poses[id])
		game.clerk.locks.update_slot(record)
	blast_elapsed=BLAST_DURATION

func play_blast() -> void:
	const RATE:=16000
	var samples:=PackedByteArray()
	samples.resize(RATE*2)
	for i in RATE:
		var t:=float(i)/RATE
		var decay:=exp(-t*7.0)*minf(t*180.0,1.0)
		var rumble:=sin(TAU*(66.0*t-21.0*t*t))*.63
		samples.encode_s16(i*2,roundi((rumble+randf_range(-.28,.28))*decay*27000.0))
	var clip:=AudioStreamWAV.new()
	clip.format=AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate=RATE
	clip.data=samples
	var speaker:=AudioStreamPlayer.new()
	add_child(speaker)
	speaker.stream=clip
	speaker.volume_db=-9
	speaker.finished.connect(speaker.queue_free)
	speaker.play()
