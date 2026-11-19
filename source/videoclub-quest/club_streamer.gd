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
var pending_specials:Array[Dictionary]=[]
var live_http:HTTPRequest
var live_endpoint:="http://127.0.0.1:18743"
var live_headers:=PackedStringArray()
var live_poll:=0.0
var live_cursor:=0
var live_session:=""
var live_chimes:=0
var chime_delay:=0.0
var wrist_panel:Node3D
var wrist_timer:Label3D
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
var cleanup_until:=0.0
var cleanup_clock:=0.0
var cleanup_workers:Array[Node3D]=[]
var cleanup_claims:Dictionary={}
var blast_elapsed:=0.0
var blast_frame:=0.0
const BLAST_DURATION:=1.35
var arrival_delay:=0.0
var special_busy:=false
var switching:=false
var chord_serial:Dictionary={}
var chord_latched:Dictionary={}

func setup(owner_game) -> void:
	game=owner_game
	live_cursor=int(get_tree().get_meta("streamer_live_cursor",0))
	live_session=str(get_tree().get_meta("streamer_live_session",""))
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
	material.render_priority=-1
	background.material_override=material
	wrist_panel.add_child(background)
	wrist_timer=wrist_label("DÉFI NON DÉMARRÉ",.144,42,Color("174c87"))
	event_label=wrist_label("",.107,29,Color("255c94"))
	wrist=wrist_label("",-.014,32,Color("123968"))
	wrist.width=960
	wrist.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	wrist_footer=wrist_label("",-.145,28,Color("235a85"))
	wrist_panel.hide()
	chat_chime=AudioStreamPlayer.new()
	chat_chime.stream=make_chat_chime()
	chat_chime.volume_db=-6
	add_child(chat_chime)
	var config:=ConfigFile.new()
	if config.load("user://streamer-relay.cfg")==OK:
		live_endpoint=str(config.get_value("relay","endpoint",live_endpoint))
		var token:=str(config.get_value("relay","token",""))
		if not token.is_empty():live_headers.append("Authorization: Bearer "+token)
	live_http=HTTPRequest.new()
	live_http.timeout=2.5
	live_http.body_size_limit=750000
	live_http.use_threads=true
	add_child(live_http)
	live_http.request_completed.connect(receive_live_events)

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
	const FRAMES:=5760
	var samples:=PackedByteArray()
	samples.resize(FRAMES*2)
	for i in FRAMES:
		var t:=float(i)/RATE
		var envelope:=minf(1,t*160)*pow(1-float(i)/FRAMES,1.25)
		samples.encode_s16(i*2,roundi((sin(TAU*880*t)*.78+sin(TAU*1320*t)*.22)*envelope*22000))
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
	labels[3].text="10 Étoiles · Le client lit ton message"
	labels[5].text="20 Étoiles · Famille de cinq enfants"
	labels[6].text="30 Étoiles · Rush de cinq clients"
	labels[7].text="40 Étoiles · 5 commis m'aident à ramasser pendant 5 min"
	labels[8].text="Sauvegarder le mode Streamer"
	labels[9].text="300 Étoiles · Tous les films tombent"
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
	if not game.streamer_mode or row<2 or row==4 or row>9:return
	if row==8:
		game.session.save_game()
		return
	toggle_menu()
	match row:
		2:
			next_comment=0
			comment_timer=0.0
		3,5:
			run_special(row-2)
		6:
			notify_event("30 Étoiles · Rush de cinq clients")
			queue_clients(5)
		7:call_cleanup_crew()
		9:explode_shelves()

func switch_mode() -> void:
	get_tree().set_meta("entrepreneur_mode",false)
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
	cleanup_clock+=dt
	live_poll-=dt
	if live_poll<=0:
		live_poll=1.2
		if live_http.get_http_client_status()==HTTPClient.STATUS_DISCONNECTED:
			live_http.request(live_endpoint+"/events?after=%d&session=%s"%[live_cursor,live_session.uri_encode()],live_headers)
	chime_delay-=dt
	if live_chimes>0 and chime_delay<=0:
		live_chimes-=1
		chime_delay=chat_chime.stream.get_length()+.04
		chat_chime.play()
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
		var event:Dictionary=pending_specials.pop_front()
		run_special(event.tier,event.get("phrase",""),event.get("voice",""))
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
	var offset:Vector3=wrist_panel.global_position-game.head.global_position
	var looking:bool=offset.length()>.22 and offset.length()<1.05 and (-game.head.global_basis.z).dot(offset.normalized())>.82
	wrist_panel.visible=looking and game.hands[0].get_float(&"trigger")>.6
	if wrist_panel.visible:wrist_panel.look_at(game.head.global_position,game.head.global_basis.y,true)

func add_comment(message:String) -> void:
	if comment_offset>0:comment_offset+=1
	comments.append(message)
	if comments.size()>60:comments.pop_front()
	comment_offset=mini(comment_offset,maxi(0,comments.size()-CHAT_PAGE_SIZE))
	refresh_wrist()
	live_chimes+=1

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
	wrist.text="\n".join(lines)
	if challenge_remaining>0:
		var remaining:=ceili(challenge_remaining)
		wrist_timer.text="TEMPS RESTANT  %d:%02d"%[remaining/60,remaining%60]
	else:
		wrist_timer.text="TEMPS ÉCOULÉ  0:00" if challenge_remaining==0 else "DÉFI NON DÉMARRÉ"
	event_label.text=event_text
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

func run_special(tier:int,spoken_phrase:String="",voice_data:String="") -> void:
	if special_busy:
		pending_specials.append({"tier":tier,"phrase":spoken_phrase,"voice":voice_data})
		game._message("Événement ajouté à la file.")
		return
	special_busy=true
	notify_event(["10 Étoiles · Le client lit ton message","2 $ · Pochette dans la chute","20 Étoiles · Famille de cinq enfants"][tier-1])
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
		var phrase:="Salut ! Ton club vidéo me rappelle mes vendredis soir." if spoken_phrase.is_empty() else spoken_phrase
		game._message("Client du live : "+phrase)
		var voice:=AudioStreamPlayer3D.new()
		if spoken_phrase.is_empty():
			voice.stream=load("res://assets/streamer-client-fr.mp3")
		elif not voice_data.is_empty():
			voice.stream=AudioStreamMP3.load_from_buffer(Marshalls.base64_to_raw(voice_data))
		voice.position.y=1.55
		voice.unit_size=3.0
		visitor.add_child(voice)
		if voice.stream:
			voice.play()
			await voice.finished
		else:
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
	notify_event("300 Étoiles · Tous les films tombent · %d boîtiers"%added)
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
		if entry.flying or entry.get("carried",false):continue
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


func receive_live_events(result:int,code:int,_headers:PackedStringArray,body:PackedByteArray) -> void:
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200 or not game.streamer_mode:return
	var packet:Variant=JSON.parse_string(body.get_string_from_utf8())
	if not packet is Dictionary or not packet.get("events") is Array:return
	var session_id:=str(packet.get("session",""))
	if live_session!=session_id:
		live_session=session_id
		live_cursor=0
	for entry in packet.events:
		if not entry is Dictionary:continue
		var sequence:=int(entry.get("seq",0))
		if sequence<=live_cursor:continue
		live_cursor=sequence
		get_tree().set_meta("streamer_live_cursor",live_cursor)
		get_tree().set_meta("streamer_live_session",live_session)
		match entry.get("kind",""):
			"comment":add_comment(str(entry.get("name","Spectateur")).left(32)+": "+str(entry.get("text","")).left(110))
			"tip":
				var tier:=int(entry.get("tier",0))
				match tier:
					1:
						var phrase:=str(entry.get("text","")).left(220)
						if not phrase.is_empty():run_special(1,phrase,str(entry.get("audio","")))
					3:run_special(tier)
					5:
						notify_event("30 Étoiles · Rush de cinq clients")
						queue_clients(5,false)
					10:call_cleanup_crew()
					20:explode_shelves()


func call_cleanup_crew() -> void:
	if not game.streamer_mode:return
	cleanup_until=maxf(cleanup_clock,cleanup_until)+300.0
	notify_event("40 Étoiles · 5 commis m'aident à ramasser pendant 5 min")
	if not cleanup_workers.is_empty():return
	for index in range(5):
		var worker:=Props.customer(self,index)
		worker.position=Vector3(-4.0+float(index%2)*.32,0,8.8+float(index/2)*.45)
		worker.add_to_group("streamer_door_visitor")
		var tag:=Label3D.new()
		tag.text="COMMIS"
		tag.font_size=30
		tag.pixel_size=.0012
		tag.position.y=1.9
		tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		worker.add_child(tag)
		cleanup_workers.append(worker)
		cleanup_shift(worker,index)

func cleanup_shift(worker:Node3D,index:int) -> void:
	const SPEED:=1.32
	await get_tree().create_timer(index*.32,false).timeout
	await walk(worker,Vector3(-4,0,4.5),SPEED)
	while cleanup_clock<cleanup_until:
		var job:=nearest_cleanup_job(worker.global_position)
		if job.is_empty():
			await get_tree().create_timer(.8,false).timeout
			continue
		var id:int=job.record.id
		cleanup_claims[id]=worker
		await walk(worker,game.clerk.customers.aisle_for(job.position),SPEED)
		if cleanup_clock>=cleanup_until or not cleanup_job_ready(job) or worker.global_position.distance_to(job.position)>.75:
			cleanup_claims.erase(id)
			await get_tree().create_timer(.45,false).timeout
			continue
		Actor.animate(worker,"Pick")
		await get_tree().create_timer(.55,false).timeout
		if not cleanup_job_ready(job):
			cleanup_claims.erase(id)
			continue
		set_cleanup_carry(job,true)
		var carry:=Node3D.new()
		Actor.equip(worker,carry)
		load("res://held_case.gd").build(carry,game.layout.movies[job.record.movie])
		var shelf:Vector3=game.clerk.customers.aisle_for(job.record.world.origin)
		await walk(worker,shelf,SPEED)
		await get_tree().create_timer(.35,false).timeout
		if cleanup_job_ready(job) and worker.global_position.distance_to(shelf)<.6:
			finish_cleanup_job(job)
		else:set_cleanup_carry(job,false)
		carry.queue_free()
		cleanup_claims.erase(id)
	await walk(worker,Vector3(-4,0,9),SPEED)
	cleanup_workers.erase(worker)
	worker.queue_free()

func nearest_cleanup_job(from:Vector3) -> Dictionary:
	var best:Dictionary={}
	var nearest:=INF
	for id in fallen_cases:
		if cleanup_claims.has(id):continue
		var entry:Dictionary=fallen_cases[id]
		if entry.flying or not is_cleanup_aisle(entry.pose.origin):continue
		var distance:=from.distance_squared_to(entry.pose.origin)
		if distance>=nearest:continue
		nearest=distance
		best={"record":game.dvd_records[id],"position":entry.pose.origin,"blast":true}
	for item in game.clerk.cases:
		var record:Dictionary=item.get("record",{})
		if record.is_empty() or cleanup_claims.has(record.id) or not is_instance_valid(item.get("node")):continue
		if item.kind not in ["shelve","return","sorting"]:continue
		var job:Dictionary={"record":record,"item":item,"position":item.node.global_position}
		if not cleanup_job_ready(job):continue
		var distance:=from.distance_squared_to(job.position)
		if distance>=nearest:continue
		nearest=distance
		best=job
	for record in game.modes.loose_dvds:
		if cleanup_claims.has(record.id) or not is_instance_valid(record.get("loose_body")):continue
		var job:Dictionary={"record":record,"position":record.loose_body.global_position,"loose":true}
		if not cleanup_job_ready(job):continue
		var distance:=from.distance_squared_to(job.position)
		if distance>=nearest:continue
		nearest=distance
		best=job
	return best

func cleanup_job_ready(job:Dictionary) -> bool:
	var record:Dictionary=job.record
	if game.held_record==record:return false
	if job.get("blast",false):
		return fallen_cases.has(record.id) and not fallen_cases[record.id].flying
	var position:Vector3
	if job.get("loose",false):
		if record not in game.modes.loose_dvds or not is_instance_valid(record.get("loose_body")):return false
		position=record.loose_body.global_position
	else:
		var item:Dictionary=job.item
		if item not in game.clerk.cases or not is_instance_valid(item.get("node")):return false
		if item==game.clerk.held_service or item==game.clerk.secondary or item in game.clerk.active.get("items",[]):return false
		if item.node.get_meta("in_basket",false) or item.node.get_meta("in_sort_tray",false) or item.node.get_meta("guest_held",false) or (item.node.get_meta("customer_animating",false) and not job.get("carrying",false)):return false
		position=item.node.global_position
	if position.y<-.12 or position.y>.24 or position.distance_to(job.position)>.28:return false
	# The counter, chute, entrance and exterior are outside the shelving aisles.
	if not is_cleanup_aisle(position):return false
	var aisle:Vector3=game.clerk.customers.aisle_for(position)
	return Vector2(position.x-aisle.x,position.z-aisle.z).length()<.55

func is_cleanup_aisle(position:Vector3) -> bool:
	return absf(position.x)<=5.25 and position.z>=-4.45 and position.z<=4.4

func set_cleanup_carry(job:Dictionary,carrying:bool) -> void:
	job.carrying=carrying
	var record:Dictionary=job.record
	if job.get("blast",false):
		if not fallen_cases.has(record.id):return
		var entry:Dictionary=fallen_cases[record.id]
		entry.carried=carrying
		draw_fallen(record,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO) if carrying else entry.pose)
		return
	var body:Node3D=record.get("loose_body") if job.get("loose",false) else job.item.get("node")
	if not is_instance_valid(body):return
	body.visible=not carrying
	body.set_meta("customer_animating",carrying)

func finish_cleanup_job(job:Dictionary) -> void:
	var record:Dictionary=job.record
	if job.get("blast",false):
		fallen_cases.erase(record.id)
		game.modes._restore_slot(record)
		game.clerk.locks.update_slot(record)
	elif job.get("loose",false):
		record.loose_body.queue_free()
		record.erase("loose_body")
		game.modes.loose_dvds.erase(record)
		game.modes._restore_slot(record)
		game.clerk.locks.update_slot(record)
	else:
		var item:Dictionary=job.item
		record.dirty=item.node.get_meta("dirty",false)
		record.locked=item.node.get_meta("antitheft",true)
		game.clerk.tasks.erase(item.get("task",""))
		game.clerk.cases.erase(item)
		item.node.queue_free()
		game.clerk.restore_stock(record)
