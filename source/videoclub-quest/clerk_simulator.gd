extends Node3D
const Props=preload("res://clerk_props.gd")
const Pricing=preload("res://rental_pricing.gd")
var scanner
var locks
var accounts=preload("res://clerk_accounts.gd").new()
var game
var max_basket=3
var sorting_bin=Vector3(2.7,1.04,-8.85)
var wallet
var basket
var repairs
var shift
var shift_ui_clock=0.0
var scanner_position=Vector3(.40,1.17,-6.18)
var phone_enabled=false
var return_bin=Vector3(-2.55,.83,-6.5)
var inspection
var customers
var waiting:Array=[]
var active:Dictionary={}
var cases:Array=[]
var held_service:Dictionary={}
var secondary:Dictionary={}
var secondary_hand=-1
var targets:Array=[]
var terminal:SubViewport
var desktop:Control
var lan:Node
var damage_alert:Label
var chute_serial=0
var screen:MeshInstance3D
var door:Node3D
var drawer:Node3D
var drawer_motion:Tween
var drawer_open=false
var phone:Node3D
var phone_hand=-1
var phone_timer=32.0
var ringing=false
var ring_serial:=0
var scan_serial:=0
var phone_audio:AudioStreamPlayer3D
var page=0
var scanned=false
var unlocked=false
var paid=false
var tender_received=false
var tender_note:Node3D
var tender=1000
var tender_parts:Array=[]
var tender_deposited=0
var register_display:Label3D
var price=375
var change=0
var change_contents:Array=[]
var change_meshes:Array=[]
var rentals=0
var returns_due:Array=[]
var tasks:Array[String]=[]
var reminders:Array[String]=[]
var money_hand=-1
var money_node:Node3D
var money_value=0
var stock={1:50,5:30,10:30,25:40,100:20,200:15,500:10,1000:10,2000:5}
var till={}
var elapsed=0.0
var ring_tick=0.0
var customer_delay=0.0
var last_station=""
var lock_hand=-1
var loose_lock:Node3D
var lock_source:Node3D
var lock_start=Vector3.ZERO
var lock_axis=Vector3.DOWN
var lock_bin=Vector3(.99,1.14,-6.18)
func add_lock(n:Node3D)->Node3D:return load("res://clerk_locks.gd").visual(n)
func lock_input(hand:int)->bool:return locks.interact(hand)
func tick_lock(dt:float=1.0/72.0):locks.tick(dt)
func setup(g):
	game=g
	name="ClerkSimulator"
	load("res://clerk_inventory.gd").mix_records(game.dvd_records,.10)
	inspection=load("res://clerk_inspection.gd").new()
	add_child(inspection)
	inspection.setup(game)
	build_counter()
	wallet=load("res://clerk_wallet.gd").new()
	add_child(wallet)
	wallet.setup(self)
	build_return_chute()
	repairs=load("res://clerk_repairs.gd").new()
	add_child(repairs)
	repairs.setup(self)
	basket=load("res://clerk_basket.gd").new()
	add_child(basket)
	basket.setup(self)
	locks=load("res://clerk_locks.gd").new()
	add_child(locks)
	locks.setup(self)
	scanner=load("res://clerk_scanner.gd").new()
	add_child(scanner)
	scanner.setup(self)
	shift=load("res://clerk_shift.gd").new()
	shift.setup(self)
	build_door()
	customers=load("res://clerk_customers.gd").new()
	add_child(customers)
	customers.setup(game,self)
	refresh_terminal()
func target(node:Node3D,action:String,radius:float=.09,value:int=0):
	targets.append({"node":node,"action":action,"radius":radius,"value":value})
func build_counter():
	# Reuse the existing CRT and preserve its housing and location.
	screen=game.model.find_child("pc-screen",true,false)
	terminal=SubViewport.new()
	terminal.size=Vector2i(1536,1152)
	terminal.size_2d_override=Vector2i(1024,768)
	terminal.size_2d_override_stretch=true
	terminal.disable_3d=true
	terminal.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(terminal)
	lan=preload("res://club_lan.gd").new()
	add_child(lan)
	lan.clerk=self
	desktop=preload("res://club_desktop.gd").new()
	terminal.add_child(desktop)
	desktop.setup(self)
	if screen:
		# Imported screen UVs occupy an atlas tile; replace only the display surface.
		var display=QuadMesh.new()
		display.size=Vector2(.402,.3015)
		screen.position+=Vector3(0,.021,.020)
		var frame:=Props.box(screen,Vector3(0,0,-.014),Vector3(.441,.338,.022),"bbb6a8")
		frame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		screen.mesh=display
		var m=StandardMaterial3D.new()
		m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture=terminal.get_texture()
		m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
		screen.material_override=m
	var keys=["CLIENTS","TÂCHES","RETOURS","JOURNÉE"]
	for i in range(4):
		var key=Props.box(self,Vector3(-.1+i*.19,1.14,-6.41),Vector3(.17,.022,.08),"3b5955")
		var text=Props.label(key,keys[i],Vector3(0,.014,0),.00055,24)
		text.rotation=Vector3(-PI/2,0,PI)
		target(key,"page",.09,i)
	load("res://scene_refresh.gd").move_checkout_scanner(game)
	var scanner=game.model.find_child("scanner-red-window",true,false)
	if not scanner:scanner=Props.cylinder(self,scanner_position-Vector3(0,.06,0),.055,.035,"9c3030")
	target(scanner,"scan",.15)
	var magnet=Props.box(self,Vector3(.72,1.12,-6.18),Vector3(.0953,.027,.0953),"54585b")
	for x in [-.034,.034]:Props.box(magnet,Vector3(x,.025,0),Vector3(.022,.024,.095),"34383b")
	Props.box(self,lock_bin-Vector3(0,.035,0),Vector3(.24,.015,.20),"37464a")
	for x in [-.12,.12]:Props.box(self,lock_bin+Vector3(x,0,0),Vector3(.012,.075,.20),"37464a")
	for z in [-.10,.10]:Props.box(self,lock_bin+Vector3(0,0,z),Vector3(.24,.075,.012),"37464a")
	target(magnet,"unlock",.12)
	var pad=Props.box(self,Vector3(1.45,1.10,-6.18),Vector3(.32,.016,.28),"326e96")
	target(pad,"clean",.20)
	var receipt=Props.box(self,Vector3(.75,1.11,-5.72),Vector3(.32,.018,.22),"344533")
	target(receipt,"handoff",.19)
	var return_tray:=Marker3D.new()
	add_child(return_tray)
	return_tray.position=Vector3(-.27,1.11,-6.22)
	target(return_tray,"return",.20)
	drawer=Node3D.new()
	add_child(drawer)
	drawer.position=Vector3(-.78,1.13,-6.6)
	var register=StaticBody3D.new()
	add_child(register)
	register.position=Vector3(-.78,1.17,-6.44)
	var register_shape=CollisionShape3D.new()
	var register_box=BoxShape3D.new()
	register_box.size=Vector3(.64,.30,.43)
	register_shape.shape=register_box
	register_shape.position.y=.08
	register.add_child(register_shape)
	Props.box(register,Vector3.ZERO,Vector3(.63,.14,.42),"c3bca8")
	var keypad=Props.box(register,Vector3(0,.12,-.06),Vector3(.53,.10,.29),"c3bca8")
	keypad.rotation.x=.20
	for row in range(4):
		for col in range(5):
			var key=Props.box(register,Vector3(-.18+col*.075,.19,-.16+row*.045),Vector3(.055,.018,.033),"36413e" if col<3 else "647b70")
			target(key,"drawer",.035)
			var caption=Props.label(key,str(row*3+col+1) if col<3 and row<3 else ("0" if col==1 else "="),Vector3(0,.011,0),.00032,24)
			caption.rotation=Vector3(-PI/2,0,PI)
	Props.box(register,Vector3(.04,.25,.12),Vector3(.34,.11,.07),"343a37")
	register_display=Props.label(register,"TOTAL  0.00",Vector3(.04,.26,.077),.0005,28)
	register_display.rotation.y=PI
	Props.box(register,Vector3(-.22,.20,.10),Vector3(.10,.01,.14),"ede8d6")
	Props.box(drawer,Vector3.ZERO,Vector3(.74,.07,.44),"353a3a")
	var pull=Props.box(drawer,Vector3(0,.02,-.17),Vector3(.22,.035,.025),"b1b5b3")
	target(pull,"drawer",.16)
	for divider in range(7):Props.box(drawer,Vector3(-.36+divider*.12,.055,-.11),Vector3(.004,.03,.20),"535957")
	for divider in range(4):Props.box(drawer,Vector3(-.33+divider*.22,.055,.11),Vector3(.004,.03,.20),"535957")
	Props.box(drawer,Vector3(0,.055,-.01),Vector3(.72,.03,.004),"535957")
	var denominations=[1,5,10,25,100,200,500,1000,2000]
	for i in range(denominations.size()):
		var value=denominations[i]
		var p=Vector3(-.30+i*.12,.045,-.12)
		if value>=500:p=Vector3(-.22+(i-6)*.22,.045,.11)
		var piece=make_money(value)
		drawer.add_child(piece)
		piece.position=p
		if value>=500:piece.rotation.y=PI/2
		target(piece,"money",.052,value)
	till=stock.duplicate()
	var change_tray=Props.box(self,Vector3(.3,1.11,-5.73),Vector3(.23,.02,.16),"b8aaa0")
	# Change tray is physical staging only; it never resets a paid transaction.
	tender_note=make_money(1000)
	add_child(tender_note)
	tender_note.position=Vector3(-.27,1.135,-6.22)
	tender_note.visible=false
	target(tender_note,"tender",.10)
	phone=Node3D.new()
	add_child(phone)
	phone.position=Vector3(-1.45,1.15,-6.2)
	Props.box(phone,Vector3.ZERO,Vector3(.08,.07,.24),"22282a")
	for z in [-.10,.10]:Props.box(phone,Vector3(0,-.02,z),Vector3(.10,.06,.07),"22282a")
	target(phone,"phone",.15)
	phone_audio=AudioStreamPlayer3D.new()
	phone.add_child(phone_audio)
	phone_audio.max_distance=12
	phone_audio.volume_db=-18
	var wav=AudioStreamWAV.new()
	wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate=22050
	var bytes=PackedByteArray()
	bytes.resize(11025*2)
	for i in range(11025):bytes.encode_s16(i*2,int((sin(i*TAU*440/22050.0)+sin(i*TAU*480/22050.0))*5000))
	wav.data=bytes
	phone_audio.stream=wav
	for item in [["SCANNER",Vector3(.40,1.09,-6.42)],["ANTIVOL",Vector3(.72,1.09,-6.42)],["NETTOYAGE",Vector3(1.45,1.09,-6.42)]]:
		var text=Props.label(self,item[0],item[1],.00065,27)
		text.rotation=Vector3(-PI/2,0,PI)
func make_money(value:int)->Node3D:
	var n=Node3D.new()
	if value<500:
		var radius=.012 if value<100 else .014
		Props.cylinder(n,Vector3.ZERO,radius,.002,"b58052" if value==1 else ("c0a447" if value==100 else "b9bfc1"),.7)
		if value==200:Props.cylinder(n,Vector3(0,.0011,0),.008,.0003,"bba34c",.7)
	else:
		Props.box(n,Vector3.ZERO,Vector3(.145,.0008,.065),"698dbe" if value==500 else ("9b7eb4" if value==1000 else "79a585"))
		for side in ["recto","verso"]:
			var path="res://assets/currency/%d-%s.jpg"%[value/100,side]
			if ResourceLoader.exists(path):
				var face=MeshInstance3D.new()
				var quad=QuadMesh.new()
				quad.size=Vector2(.145,.065)
				face.mesh=quad
				var mat=StandardMaterial3D.new()
				mat.albedo_texture=load(path)
				mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				mat.roughness=.85
				face.material_override=mat
				face.position.y=.0005 if side=="recto" else -.0005
				face.rotation.x=-PI/2 if side=="recto" else PI/2
				n.add_child(face)
	var text=Props.label(n,("%d ¢"%value) if value<100 else ("%d $"%(value/100)),Vector3(0,.0018,0),.00038 if value<500 else .0007,24)
	text.rotation.x=-PI/2
	if value>=500:
		var legend=Props.label(n,"CANADA · ACCESSOIRE",Vector3(0,.0019,.021),.00025,22)
		legend.rotation.x=-PI/2
	return n
func build_door():
	door=Node3D.new()
	add_child(door)
	door.position=Vector3(-4.74,0,7.12)
	for x in [0,1.34]:Props.box(door,Vector3(x,1.38,0),Vector3(.045,2.76,.065),"b3bbc0")
	for y in [.035,2.74]:Props.box(door,Vector3(.67,y,0),Vector3(1.34,.06,.065),"b3bbc0")
	var glass=Props.box(door,Vector3(.67,1.38,0),Vector3(1.28,2.65,.012),"b8d0d0")
	var m=StandardMaterial3D.new()
	m.albedo_color=Color(.65,.8,.85,.10)
	m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness=.13
	glass.material_override=m
	var handle=Props.box(door,Vector3(1.18,1.15,-.07),Vector3(.025,.35,.035),"babfc2")
	target(handle,"door",.18)
	var old=game.model.find_child("door-handle",true,false)
	if old:old.visible=false
	var sign=game.model.find_child("open-sign",true,false)
	if sign:sign.reparent(door,true)
	# The original rain pane crossed the doorway; retain its left fixed sidelight only.
	var pane=game.model.find_child("rain-window-front-0",true,false)
	if pane:
		pane.scale.x*=.40
		pane.position.x=-5.29
	var body=AnimatableBody3D.new()
	door.add_child(body)
	body.collision_layer=1
	body.collision_mask=8
	var shape=CollisionShape3D.new()
	var box=BoxShape3D.new()
	box.size=Vector3(1.34,2.76,.07)
	shape.shape=box
	shape.position=Vector3(.67,1.38,0)
	body.add_child(shape)
func reserve_stock(id:int)->Dictionary:
	var pool=game.dvd_records.filter(func(r):return r.movie==id)
	pool.shuffle()
	for record in pool:
		if record.movie!=id or record.get("loose",false) or record.get("clerk_reserved",false) or record==game.held_record:continue
		reserve_exact(record)
		return record
	return {}
func reserve_exact(record:Dictionary):
	record.clerk_reserved=true
	if locks:locks.update_slot(record)
	var zero=Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)
	record.group.multimesh.set_instance_transform(record.index,zero)
	if game.shell and record.shell_index>=0:game.shell.multimesh.set_instance_transform(record.shell_index,zero)
	game._update_cover_lod(game.head.global_position,true)
func restore_stock(record:Dictionary):
	if record.is_empty():return
	record.clerk_reserved=false
	if locks:locks.update_slot(record)
	record.group.multimesh.set_instance_transform(record.index,record.local)
	if game.shell and record.shell_index>=0:
		game.shell.multimesh.set_instance_transform(record.shell_index,game.shell.global_transform.affine_inverse()*record.world)
	game._update_cover_lod(game.head.global_position,true)
func select_film(c:Dictionary)->bool:
	c.record=reserve_stock(c.movie)
	if c.record.is_empty():
		var candidates=range(game.layout.movies.size())
		candidates.shuffle()
		for title in candidates:
			c.record=reserve_stock(title)
			if not c.record.is_empty():
				c.movie=c.record.movie
				break
	if c.record.is_empty():return false
	if c.has("carry") and is_instance_valid(c.carry):c.carry.queue_free()
	var carry=Node3D.new()
	load("res://customer_actor.gd").equip(c.node,carry)
	load("res://held_case.gd").build(carry,game.layout.movies[c.movie])
	add_lock(carry)
	c.carry=carry
	c.reservations=[c.record]
	var roll=randf()
	var difficulty=clampf((shift.day-1)/8.0,0.0,1.0)
	var wanted=mini(max_basket,3 if roll<.15+.20*difficulty else (2 if roll<.45+.30*difficulty else 1))
	var candidates=range(game.layout.movies.size())
	candidates.shuffle()
	for id in candidates:
		if c.reservations.size()>=wanted:break
		if id==c.movie:continue
		var record=reserve_stock(id)
		if not record.is_empty():c.reservations.append(record)
	return true
func new_case(id:int,position:Vector3,kind:String)->Dictionary:
	var n=game.modes.create_case_body(float(game.layout.movies[id].get("caseHeight",.19)))
	n.freeze=true
	n.collision_layer=0
	n.collision_mask=0
	add_child(n)
	load("res://held_case.gd").build(n,game.layout.movies[id])
	n.position=position
	n.rotation.x=-PI/2
	var data={"node":n,"movie":id,"kind":kind,"home":position,"scanned":false,"record":{}}
	n.set_meta("movie",id)
	n.set_meta("disc_movie",id)
	n.set_meta("disc_uid",-1)
	n.set_meta("antitheft",kind=="rental")
	n.set_meta("dirty",kind=="return")
	if kind=="rental":
		add_lock(n)
	cases.append(data)
	return data
func customer_ready(c:Dictionary):
	c.patience=0.0
	waiting.append(c)
	start_next()
func start_next():
	if not active.is_empty() or waiting.is_empty() or customer_delay>0:return
	active=waiting.pop_front()
	active.patience=0.0
	if active.node.position.distance_to(Vector3(-.6,0,-5.05))>.15:
		active.state="approach_counter"
		customers.route(active,Vector3(-.6,0,-5.05))
	scanned=false
	unlocked=false
	paid=false
	tender_received=false
	tender_deposited=0
	tender_note.visible=true
	change=0
	active.items=[]
	active.missing=[]
	active.handed=0
	active.billed_titles=[]
	active.cash_started=false
	active.offer_ready=false
	if not active.has("account_id"):active.account_id=accounts.create_account()
	if not active.has("visit_balance"):active.visit_balance=int(accounts.ensure(active.account_id).balance)
	active.account_due=0 if active.get("is_return",false) or active.get("is_refund",false) else int(active.visit_balance)
	if active.get("is_refund",false):
		price=0
		page=2
	elif active.get("is_return",false):
		active.items=[active.return_item]
		price=0
		page=2
	else:
		for record in active.get("reservations",[active.record]):add_basket_case(record)
		active.price_titles=active.items.map(func(item):return item.movie)
	price=int(active.account_due)
	tender_parts=[]
	tender=0
	tender_received=active.get("is_return",false) or active.get("is_refund",false)
	paid=active.get("is_return",false)
	offer_rental_payment()
	refresh_tender_visual()
	if active.has("carry") and is_instance_valid(active.carry):active.carry.visible=false
	refresh_terminal()
func refresh_tender_visual():
	for child in tender_note.get_children():
		tender_note.remove_child(child)
		child.queue_free()
	for i in range(tender_parts.size()):
		var piece=make_money(tender_parts[i])
		tender_note.add_child(piece)
		piece.position=Vector3((i%3)*.025,(i/3)*.004,0)
	tender_note.visible=not tender_parts.is_empty() and active.get("missing",[]).is_empty()
func make_mess(c:Dictionary):
	if cases.filter(func(item):return str(item.get("task","")).begins_with("Ramasser")).size()>=8:return
	var nearby=game.dvd_records.filter(func(r):return not r.get("clerk_reserved",false) and not r.get("loose",false) and r!=game.held_record and r.world.origin.distance_to(c.node.global_position+Vector3(0,1,0))<2.0)
	if nearby.is_empty():return
	var record:Dictionary=nearby.pick_random()
	record.clerk_reserved=true
	var zero=Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)
	record.group.multimesh.set_instance_transform(record.index,zero)
	if game.shell and record.shell_index>=0:game.shell.multimesh.set_instance_transform(record.shell_index,zero)
	game._update_cover_lod(game.head.global_position,true)
	var hand_position:Vector3=c.node.to_global(Vector3(.22,.95,-.18))
	var mess=new_case(record.movie,record.world.origin,"shelve")
	locks.update_slot(record)
	mess.record=record
	mess.node.set_meta("customer_animating",true)
	load("res://clerk_inventory.gd").bind(mess.node,record)
	mess.task="Ramasser : "+str(game.layout.movies[mess.movie].title)
	tasks.append(mess.task)
	var motion=create_tween()
	motion.tween_property(mess.node,"global_position",hand_position,.45)
	motion.tween_interval(.35)
	motion.tween_callback(func():
		mess.node.set_meta("customer_animating",false)
		if mess==held_service or mess==secondary:return
		mess.node.collision_layer=8
		mess.node.collision_mask=1|8
		mess.node.freeze=false
		mess.node.sleeping=false
		mess.node.linear_velocity=Vector3(randf_range(-.15,.15),-.12,randf_range(-.15,.15)))
	refresh_terminal()
func refresh_terminal():
	refresh_basket()
	if tender_note:tender_note.visible=not tender_parts.is_empty() and active.get("missing",[]).is_empty()
	if register_display:register_display.text="TOTAL %.2f $\nDONNÉ %.2f $"%[price/100.0,tender/100.0] if not active.is_empty() else "TOTAL 0.00 $"
	if desktop:
		if shift and shift.summary and desktop.app!=3:desktop.open_program(3)
		else:desktop.refresh()

func terminal_content(tab:int)->String:
	var title="VIDÉO CLUB — POSTE COMMIS\n"
	if shift and shift.summary:title=shift.report
	elif tab==3 and shift:title=shift.text()
	elif tab==0 or (tab==2 and not active.is_empty() and active.get("is_return",false)):
		if active.is_empty():title+="Aucun client à la caisse.\nLocations terminées : %d\n"%rentals
		else:
			title="CLIENT %03d · %s\n"%[int(active.get("account_id",active.id+1)),"REMBOURSEMENT" if active.get("is_refund",false) else "RETOUR" if active.get("is_return",false) else "LOCATION"]
			title+="TOTAL %.2f $ · DONNÉ %.2f $\n"%[price/100.0,tender/100.0]
			if active.get("is_refund",false):title+="Réclamation : %.2f $\nChoisis et remets les pièces et billets au client.\n"%(int(active.get("refund_due",0))/100.0)
			if not active.get("is_return",false) and not active.get("is_refund",false):
				title+="HT %.2f · TPS %.2f · TVQ %.2f\n"%[active.get("subtotal",0)/100.0,active.get("gst",0)/100.0,active.get("qst",0)/100.0]
				if int(active.get("account_due",0))>0:title+="ANCIEN SOLDE : %.2f $\n"%(active.account_due/100.0)
			for item in active.items:
				title+="[%s] %s\n"%["OK" if item.scanned else "À VOIR",str(game.layout.movies[item.movie].title).left(23)]
			for missing in active.missing:
				title+="REMPLACER : %s\n"%str(game.layout.movies[missing].title).left(24)
			if int(active.get("discount",0))>0:title+="FORFAIT 3 CLASSIQUES : 5.00 $\n"
			title+="Antivols : %s\nPaiement : %s\n"%["RETIRÉS" if unlocked else "À RETIRER","REÇU" if paid else "À ENCAISSER"]
			title+="Attente sans limite\n"
			if not active.missing.is_empty():title+="Vérifie un autre exemplaire."
			elif active.get("is_return",false):title+="Utilise le bouton Terminer le retour."
			else:title+="Utilise le bouton Ouvrir le tiroir."

	elif tab==1:
		title+="TÂCHES DU QUART\n"+"\n".join(tasks)
		title+="\nRetours : choisis quand vérifier, réparer et ranger."
	else:
		title+="RETOURS\nLes films arrivent dans la chute.\nAucuns frais pour les rayures.\nVérification et surfaceuse au choix.\nRemets l’antivol avant le rangement."
	return title
func interact(hand:int,grip:bool)->bool:
	if shift:shift.started=true
	if not grip and not wallet.occupied(hand) and inspection.try_take_open_disc(hand):return true
	if not grip and inspection.lid_hand>=0:return true
	if not grip and hand!=game.held_hand and hand!=secondary_hand and not wallet.occupied(hand) and desktop.point(desktop.project_ray(game.aim_hands[hand]),true):return true
	if hand==secondary_hand:
		if not grip:secondary.node.rotate_y(PI)
		return true
	if basket.hand==hand:return true
	if wallet.interact(hand,grip):return true
	if grip and not basket.targeted[hand].is_empty() and basket.interact(hand,true):return true
	if lock_input(hand):return true
	if basket.interact(hand,grip):return true
	if grip and inspection.grab_lid(hand):return true
	var p:Vector3=game.hands[hand].global_position
	if grip and hand!=game.held_hand and not inspection.opened:
		var closest={}
		var distance=.23
		for c in cases:
			if c==held_service or c==secondary or c.node.get_meta("in_basket",false) or c.node.get_meta("customer_animating",false):continue
			var gap=c.node.global_position.distance_to(p)
			if gap<distance:
				closest=c
				distance=gap
		if not closest.is_empty():
			pick_case(closest,hand,grip)
			return true
		if game.held and secondary.is_empty():
			for record in game.modes.loose_dvds.duplicate():
				if not is_instance_valid(record.get("loose_body")):continue
				if record.loose_body.global_position.distance_to(p)>.22:continue
				var item=new_case(record.movie,record.loose_body.global_position,"shelve")
				item.record=record
				record.clerk_reserved=true
				load("res://clerk_inventory.gd").bind(item.node,record)
				record.loose_body.queue_free()
				record.erase("loose_body")
				record.erase("loose")
				game.modes.loose_dvds.erase(record)
				pick_case(item,hand,true)
				return true
			for index in game._nearby_dvd_indices(p,.25):
				var record:Dictionary=game.dvd_records[index]
				if record==game.held_record or record.get("clerk_reserved",false) or record.get("loose",false):continue
				if record.world.origin.distance_to(p)>.22:continue
				var item=new_case(record.movie,record.world.origin,"shelve")
				item.record=record
				record.clerk_reserved=true
				var zero=Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)
				record.group.multimesh.set_instance_transform(record.index,zero)
				if game.shell and record.shell_index>=0:game.shell.multimesh.set_instance_transform(record.shell_index,zero)
				load("res://clerk_inventory.gd").bind(item.node,record)
				pick_case(item,hand,true)
				return true
	if (not grip or hand==inspection.finger) and inspection.interact(hand,grip):return true
	if phone_hand==hand:
		phone.reparent(self)
		phone.position=Vector3(-1.45,1.15,-6.2)
		phone.rotation=Vector3.ZERO
		phone_hand=-1
		return true
	var ray=game.aim_hands[hand]
	var direction:Vector3=-ray.global_basis.z
	var chosen:Dictionary={}
	var nearest=1.25
	for t in targets:
		if t.action in ["money","tender","handoff","scan"]:continue
		if t.action=="phone" and not phone_enabled:continue
		if t.action=="tender" and not tender_note.visible:continue
		if grip and t.action not in ["money","tender","phone","drawer"]:continue
		var offset:Vector3=t.node.global_position-ray.global_position
		var depth=offset.dot(direction)
		if p.distance_to(t.node.global_position)<t.radius or (depth>0 and depth<nearest and (offset-direction*depth).length()<t.radius):
			chosen=t
			nearest=maxf(0,depth)
	if not chosen.is_empty():
		action(chosen.action,hand,chosen.value)
		return true
	if game.held:return false
	for c in cases:
		if c.node.get_meta("customer_animating",false) or c.node.get_meta("in_basket",false):continue
		if c.node.global_position.distance_to(p)<.25:
			pick_case(c,hand,grip)
			return true
	return false
func pick_case(c:Dictionary,hand:int,grip:bool):
	if c.node.get_meta("guest_held",false):return
	if locks:locks.update_slot(c.get("record",{}))
	basket.items.erase(c)
	if lan and is_instance_valid(lan.guest_basket_node):lan.guest_basket_node.items.erase(c)
	c.node.set_meta("sort_slot",-1)
	c.node.set_meta("in_basket",false)
	c.node.set_meta("in_sort_tray",false)
	if game.held and game.held!=c.node and hand!=game.held_hand:
		if not secondary.is_empty() or inspection.opened:return
		if held_service.is_empty():
			var original=game.held
			var transform=original.global_transform
			var record:Dictionary=game.held_record
			var converted=new_case(int(record.movie),transform.origin,"shelve")
			converted.record=record
			record.clerk_reserved=true
			if record.has("loose_body") and is_instance_valid(record.loose_body):
				record.loose_body.queue_free()
				record.erase("loose_body")
				record.erase("loose")
				game.modes.loose_dvds.erase(record)
			load("res://clerk_inventory.gd").bind(converted.node,record)
			converted.node.reparent(game.dvd_grip_anchors[game.held_hand],false)
			converted.node.global_transform=transform
			original.visible=false
			original.reparent(game,false)
			game.held=converted.node
			held_service=converted
		secondary=held_service
		secondary_hand=game.held_hand
	held_service=c
	game.held=c.node
	game.held_hand=hand
	game.held_by_grip=grip
	game.held_back=false
	game.held_record={}
	game.movie_id=c.movie
	c.node.freeze=true
	c.node.collision_layer=0
	c.node.collision_mask=0
	c.node.reparent(game.dvd_grip_anchors[hand],false)
	c.node.transform=Transform3D.IDENTITY
	game._message("Boîtier de service. Scanner et détacheur au comptoir.\nMain libre + poignée sur le bord : ouvrir après retrait de l'antivol.")
func set_drawer_open(open:bool):
	if drawer_open==open:return
	drawer_open=open
	if drawer_motion and drawer_motion.is_valid():drawer_motion.kill()
	drawer_motion=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	drawer_motion.tween_property(drawer,"position:z",-6.82 if open else -6.6,.25)

func action(which:String,hand:int,value:int=0):
	match which:
		"page":desktop.open_program(value)
		"door":door.rotation.y=-PI/2
		"drawer":
			set_drawer_open(not drawer_open)
		"money":wallet.take(hand,value)
		"tender":wallet.take(hand,tender,true)
		"change":
			if change>0:
				# Cancel an incorrect change selection without losing money from the till.
				for denom in change_contents:till[denom]+=1
				change=0
				clear_change()
				paid=false
		"computer":
			if shift and shift.summary:shift.next_day()
			elif page==3 and shift:shift.finish()
			elif active.get("is_return",false) and paid and scanned:
				complete_return()
			elif not active.is_empty():
				set_drawer_open(true)
				game._message("Le total et le montant donné sont affichés. Calcule la monnaie de tête.")
		"scan":scan_held()
		"unlock":
			if game.held and game.held.get_meta("antitheft",false):
				game._message("Boîtier au détacheur : prends la languette jaune avec la main libre, puis tire vers le bas.")
		"clean":game._message("Ouvre le boîtier, prends le disque avec l'index et pose-le dans la surfaceuse près des retours : 30 secondes.")
		"handoff":handoff_rental()
		"phone":
			if game.held_hand==hand:return
			phone_hand=hand
			phone.reparent(game.hands[hand],false)
			phone.position=Vector3(0,0,-.06)
			ringing=false
			phone_audio.stop()
			reminders.append("Rappeler Julie : disponibilité de Shrek.")
			game._message("Julie : « Avez-vous Shrek ce soir ? Pouvez-vous me rappeler ? »\nLa demande est inscrite sur l'ordinateur, onglet Rappels.")
	refresh_terminal()
func handoff_rental():
	if inspection.opened or held_service.is_empty():return
	handoff_item(held_service)

func handoff_item(item:Dictionary)->bool:
	if active.is_empty() or item.is_empty() or item.kind!="rental" or item not in active.items:return false
	var node:Node3D=item.node
	if not active.missing.is_empty():
		game._message("Trouve les films manquants avant de remettre ce boîtier.")
		return false
	var was_scanned:bool=item.scanned
	if was_scanned and not paid:
		game._message("Règle le panier avant de remettre les films facturés.")
		return false
	var id:int=item.movie
	var record:Dictionary=item.record
	if was_scanned:
		if not active.has("billed_titles"):active.billed_titles=[]
		active.billed_titles.append(id)
	else:
		shift.missed_scans+=1
		shift.lost_sales+=Pricing.unit(game.layout.movies[id])
	var locked:bool=node.get_meta("antitheft",false)
	var defective:bool=node.get_meta("dirty",false) or node.get_meta("disc_movie",-1)!=id
	var refund:int=Pricing.unit(game.layout.movies[id]) if was_scanned and (locked or defective) else 0
	active.items.erase(item)
	cases.erase(item)
	node.queue_free()
	if item==held_service:clear_hand()
	active.handed+=1
	var account=int(active.get("account_id",active.id))
	var cycle=accounts.rental(account,id,record.id)
	returns_due.append({"movie":id,"time":elapsed+60,"record":record,"account_id":account,"rental_id":cycle,"refund":refund,"locked":locked})
	if not active.items.is_empty():
		refresh_invoice()
		game._message("Film remis sans scan. Perte enregistrée." if not was_scanned else "Remets les autres boîtiers au client.")
		return true
	shift.record_sale(price if paid else 0)
	if paid:accounts.settle(account,int(active.get("account_due",0)))
	clear_change()
	customers.dismiss(active)
	active={}
	rentals+=1
	customer_delay=8
	game._message("Film remis sans scan. Perte enregistrée au bilan." if not was_scanned else "Panier payé et remis. Le client repart.")
	return true

func release()->bool:
	if inspection.opened:
		if game.held and (in_sort_tray(game.held.global_position) or repairs.is_case_surface(game.held.global_position)):
			inspection.close_case()
		else:
			game._message("Referme le boîtier avant de le déposer.")
			return true
	if held_service.is_empty() and game.held and (repairs.is_case_surface(game.held.global_position) or basket.contains(game.held.global_position) or in_sort_tray(game.held.global_position)):adopt_held_case()
	if held_service.is_empty():return false
	if basket.store(held_service):return true
	if in_sort_tray(game.held.global_position):
		if has_identified_mismatch(game.held,held_service.movie):
			flag_wrong_case(held_service)
		store_sort_tray(held_service)
		return true
	if repairs.drop_into_bin(held_service):return true
	var p:Vector3=game.held.global_position
	if not game.touch_profile and held_service.kind=="rental" and not active.is_empty() and in_customer_zone(p):
		action("handoff",game.held_hand)
		return true
	if held_service.kind in ["return","shelve","sorting"]:
		for record in game.dvd_records:
			if record==held_service.record and p.distance_to(record.world.origin)<.25:
				if active.get("is_return",false) and held_service in active.get("items",[]):
					game._message("Termine le retour à l'ordinateur avant de ranger ce boîtier.")
					return true
				if not game.held.get_meta("antitheft",false):
					game._message("Réinsère une barre jaune dans le boîtier avant de le ranger.")
					return true
				held_service.record.dirty=game.held.get_meta("dirty",false)
				restore_stock(held_service.record)
				if shift and held_service.kind=="return":shift.restocked+=1
				if held_service.has("task"):tasks.erase(held_service.task)
				consume_case()
				refresh_terminal()
				game._message("Boîtier rangé dans le bon rayon.")
				return true
	game.held.reparent(self)
	# Keep releases out of the register body, then let ordinary physics take over.
	var released=game.held.global_position
	if released.x>-1.18 and released.x<-.38 and released.z>-6.76 and released.z< -6.15 and released.y<1.55:
		game.held.global_position.y=1.56
	game.held.collision_layer=8
	game.held.collision_mask=1|8
	game.held.freeze=false
	game.held.sleeping=false
	game.held.linear_velocity=game.candy.hand_velocity(game.held_hand).limit_length(4)
	clear_hand()
	return true
func clear_hand():
	if game.flip_tween and game.flip_tween.is_valid():game.flip_tween.kill()
	inspection.pending_flip=-1
	game.held=null
	game.held_hand=-1
	game.held_record={}
	held_service={}
	if not secondary.is_empty():
		held_service=secondary
		game.held=secondary.node
		game.held_hand=secondary_hand
		game.held_by_grip=true
		game.movie_id=secondary.movie
		secondary={}
		secondary_hand=-1
func release_secondary(hand:int):
	if hand!=secondary_hand:return
	var current=held_service
	var current_hand=game.held_hand
	held_service=secondary
	game.held=secondary.node
	game.held_hand=secondary_hand
	game.held_record={}
	secondary=current
	secondary_hand=current_hand
	game._release()
func clear_change():
	for piece in change_meshes:piece.queue_free()
	change_meshes.clear()
	change_contents.clear()
func consume_case():
	cases.erase(held_service)
	game.held.queue_free()
	clear_hand()
func _physics_process(dt):
	if not game:return
	elapsed+=dt
	shift.tick(dt)
	shift_ui_clock+=dt
	if shift_ui_clock>=1:
		shift_ui_clock=0
		refresh_terminal()
	tick_lock(dt)
	scanner.tick(dt)
	if game.held and not inspection.opened:
		var station=""
		if game.held.global_position.distance_to(Vector3(.72,1.17,-6.18))<.13:station="unlock"
		if station!="" and station!=last_station:action(station,game.held_hand)
		last_station=station
	else:last_station=""
	var near=game.head.global_position.distance_to(Vector3(-4.07,1.5,7.1))<2
	for c in customers.customers:
		if c.node.position.distance_to(Vector3(-4.07,0,7.1))<2:near=true
	if is_instance_valid(lan.remote_avatar) and lan.remote_avatar.valid_pose:
		var guest:Vector3=lan.remote_avatar.targets[0].origin
		near=near or Vector2(guest.x+4.1,guest.z-7.12).length()<1.8
	door.rotation.y=move_toward(door.rotation.y,-PI/2 if near else 0,dt*1.6)
	phone_timer-=dt
	if phone_enabled and phone_timer<=0:
		ringing=true
		phone_timer=95
	ring_tick-=dt
	if ringing and ring_tick<=0:
		ring_serial+=1
		phone_audio.play()
		ring_tick=3
	if customer_delay>0:
		customer_delay-=dt
		if customer_delay<=0:start_next()
	# Returning customers deliver the actual rented copy through the chute.
func customer_hand()->Vector3:
	if active.is_empty():return Vector3.INF
	var mount:Node3D=load("res://customer_actor.gd").mount(active.node)
	if mount!=active.node:return mount.global_position
	return active.node.get_node("Arm1").to_global(Vector3(0,-.45,0))
func build_return_chute():
	Props.box(self,Vector3(-2.55,1.03,-5.9),Vector3(.52,.35,.32),"555c60")
	Props.box(self,Vector3(-2.55,1.10,-5.73),Vector3(.40,.075,.012),"121719")
	var label=Props.label(self,"RETOUR DES FILMS",Vector3(-2.55,1.23,-5.72),.0006,25)
	Props.box(self,return_bin,Vector3(.56,.025,.54),"394750")
	for x in [-.28,.28]:Props.box(self,return_bin+Vector3(x,.07,0),Vector3(.018,.15,.54),"394750")
	build_sort_tray()
	# Bin floor uses the same world collision layer as the existing counters.
	var floor=StaticBody3D.new()
	add_child(floor)
	floor.position=return_bin
	var collider=CollisionShape3D.new()
	var shape=BoxShape3D.new()
	shape.size=Vector3(.56,.025,.54)
	collider.shape=shape
	floor.add_child(collider)
func take_due_return()->Dictionary:
	for job in returns_due:
		var already_here=false
		for customer in customers.customers:
			if int(job.get("account_id",-1))>=0 and customer.get("account_id",-2)==job.get("account_id",-1):already_here=true
		if elapsed>=job.time and not already_here:
			returns_due.erase(job)
			return job
	return {}
func deliver_return(job:Dictionary,customer:Dictionary={},at_counter:bool=false):
	if shift:shift.returned+=1
	var destination=return_bin+Vector3(0,.15,0)
	at_counter=false
	var returned=new_case(job.movie,destination,"return")
	returned.record=job.record
	load("res://clerk_inventory.gd").bind(returned.node,job.record)
	locks.set_locked(returned.node,bool(job.get("locked",false)))
	returned.node.set_meta("needs_relock",not bool(job.get("locked",false)))
	var account=int(job.get("account_id",customer.get("account_id",-1)))
	if account<0:account=accounts.create_account()
	returned.node.set_meta("return_account",account)
	returned.node.set_meta("return_cycle",int(job.get("rental_id",-1)))
	returned.node.set_meta("return_checked",false)
	var refund:=int(job.get("refund",0))
	var dirty=bool(job.record.get("dirty",false)) if refund>0 else randf()<minf(.45,.30+.015*(shift.day-1))
	returned.node.set_meta("dirty",dirty)
	returned.node.set_meta("returned_damage",dirty and refund==0)
	job.record.dirty=dirty
	returned.node.rotation=Vector3(-PI/2,0,0)
	if not customer.is_empty() and customer.has("carry") and is_instance_valid(customer.carry):customer.carry.visible=false
	if not at_counter:
		returned.node.collision_layer=8
		returned.node.collision_mask=1|8
		if customer.is_empty():returned.node.freeze=false
		else:
			returned.node.position=Vector3(-2.55,1.10,-5.72)
			var slide=create_tween()
			slide.tween_property(returned.node,"position",destination,.6)
			slide.tween_callback(func():returned.node.freeze=false)
	returned.scanned=true
	accounts.scan_return(returned.node)
	returned.task="Retour à traiter : "+str(game.layout.movies[job.movie].title)+" — vérifier ou réparer au choix, remettre en rayon."
	tasks.append(returned.task)
	refresh_terminal()
	return returned

func complete_return():
	shift.record_sale(price)
	var customer=active
	active={}
	tender_parts=[]
	refresh_tender_visual()
	customer_delay=8
	if customer.get("return_and_rent",false):
		customer.return_and_rent=false
		customer.is_return=false
		customer.erase("return_item")
		customer.items=[]
		customer.missing=[]
		customer.movie=randi_range(0,game.layout.movies.size()-1)
		customers.begin_browse(customer)
		game._message("Retour enregistré. Le client va choisir ses prochaines locations.")
	else:
		customers.dismiss(customer)
		game._message("Retour enregistré : inspecte, remets l'antivol puis range le boîtier.")

func replace_requested_title(old_title:int,record:Dictionary):
	active.missing.erase(old_title)
	var ids:Array=active.get("price_titles",active.items.map(func(item):return item.movie))
	var index=ids.find(old_title)
	if index>=0:ids[index]=record.movie
	else:ids.append(record.movie)
	active.price_titles=ids
	add_basket_case(record)
	refresh_invoice()
	refresh_terminal()

func abandon_customer(c:Dictionary):
	shift.abandoned+=1
	shift.lost_sales+=Pricing.quote(game.layout.movies,c.get("reservations",[]).map(func(r):return r.movie)).total
	waiting.erase(c)
	if c==active:
		for item in active.items:
			item.kind="shelve"
			if item!=held_service and item!=secondary and not item.node.get_meta("guest_held",false):send_to_chute(item)
			item.task="Ranger après abandon : "+str(game.layout.movies[item.movie].title)
			if not tasks.has(item.task):tasks.append(item.task)
		active={}
		tender_parts=[]
		refresh_tender_visual()
		customer_delay=8
	else:
		for record in c.get("reservations",[]):
			var item=new_case(record.movie,c.node.global_position+Vector3(0,1,0),"shelve")
			item.record=record
			load("res://clerk_inventory.gd").bind(item.node,record)
			item.task="Ranger après abandon : "+str(game.layout.movies[item.movie].title)
			tasks.append(item.task)
			send_to_chute(item)
	if c.has("carry") and is_instance_valid(c.carry):c.carry.visible=false
	customers.dismiss(c)
	game._message("Un client est parti après son délai d'attente.")

func send_to_chute(item:Dictionary):
	var n:RigidBody3D=item.node
	locks.set_locked(n,true)
	basket.items.erase(item)
	basket.arrange()
	n.set_meta("in_basket",false)
	n.set_meta("in_sort_tray",false)
	n.set_meta("sort_slot",-1)
	n.set_meta("customer_animating",true)
	n.freeze=true
	n.collision_layer=0
	n.collision_mask=0
	if n.get_parent()!=self:n.reparent(self)
	var slot=chute_serial
	chute_serial+=1
	var destination=return_bin+Vector3(-.11+.22*(slot%2),.04+.022*(slot/4),-.12+.24*((slot/2)%2))
	var tween=create_tween()
	tween.tween_property(n,"global_position",Vector3(-2.55,1.10,-5.72),.35)
	tween.tween_property(n,"global_position",destination,.35)
	tween.tween_callback(func():
		if not is_instance_valid(n):return
		n.remove_meta("customer_animating")
		n.rotation=Vector3(-PI/2,0,0)
		n.collision_layer=8
		n.collision_mask=1|8
		n.freeze=false)

func in_customer_zone(p:Vector3)->bool:
	if active.is_empty():return false
	return absf(p.x-active.node.global_position.x)<.7 and p.y>.95 and p.y<1.65 and p.z> -6.42 and p.z< -5.15

func add_basket_case(record:Dictionary):
	var item=new_case(int(record.movie),Vector3(-.83,1.14+active.items.size()*.022,-5.85),"rental")
	item.record=record
	load("res://clerk_inventory.gd").bind(item.node,record)
	active.items.append(item)
func refresh_basket():
	if active.is_empty() or not active.has("items"):return
	scanned=active.missing.is_empty()
	unlocked=true
	for item in active.items:
		scanned=scanned and item.scanned
		unlocked=unlocked and not item.node.get_meta("antitheft",false)
func flag_wrong_case(item:Dictionary):
	if item.kind=="sorting":return
	if active.get("is_return",false) and item in active.items:
		item.scanned=true
	var needs_replacement:bool=item.movie in active.get("missing",[])
	if item.kind=="rental" and item in active.get("items",[]):
		active.items.erase(item)
		if not needs_replacement:active.missing.append(item.movie)
		needs_replacement=true
	if needs_replacement:
		active.patience_bonus=float(active.get("patience_bonus",0))+30.0
		var available:bool=game.dvd_records.any(func(record):return record.movie==item.movie and not record.get("clerk_reserved",false) and not record.get("loose",false))
		if not available and not (active.get("state","") in ["replacement_browse","replacement_return"] and active.get("replace_title",-1)==item.movie):
			customers.choose_alternative(active,item.movie)
	item.kind="sorting"
	if item.has("task"):tasks.erase(item.task)
	item.task="À démêler : "+str(game.layout.movies[item.movie].title)
	if not tasks.has(item.task):tasks.append(item.task)
	refresh_invoice()
	refresh_terminal()
	game._message("Boîtier mis de côté. Cherche un autre exemplaire pour le client." if needs_replacement else "Boîtier mis de côté pour le tri.")
func adopt_held_case()->Dictionary:
	if not held_service.is_empty():return held_service
	if not game.held or game.held_record.is_empty():return {}
	var original=game.held
	var record:Dictionary=game.held_record
	var hand=game.held_hand
	var grip=game.held_by_grip
	var meta={}
	for key in ["disc_movie","disc_uid","dirty","inspected","antitheft","barcode_scanned","disc_mismatch_seen"]:meta[key]=original.get_meta(key,false)
	var item=new_case(record.movie,original.global_position,"shelve")
	item.record=record
	record.clerk_reserved=true
	load("res://clerk_inventory.gd").bind(item.node,record)
	for key in meta:item.node.set_meta(key,meta[key])
	original.visible=false
	original.reparent(game,false)
	if record.has("loose_body") and is_instance_valid(record.loose_body):
		record.loose_body.queue_free()
		record.erase("loose_body")
		record.erase("loose")
		game.modes.loose_dvds.erase(record)
		original.queue_free()
	pick_case(item,hand,grip)
	return item

func has_identified_mismatch(node:Node3D,title:int)->bool:
	return int(node.get_meta("disc_movie",-1))!=title and (node.get_meta("disc_mismatch_seen",false) or node.get_meta("inspected",false))

func accept_replacement(item:Dictionary)->bool:
	if active.is_empty() or active.get("is_return",false):return false
	if item.record.is_empty() or item.movie not in active.missing or item.kind=="return":return false
	active.missing.erase(item.movie)
	item.kind="rental"
	if item.has("task"):
		tasks.erase(item.task)
		item.erase("task")
	item.scanned=true
	if not active.items.has(item):active.items.append(item)
	refresh_terminal()
	game._message("Exemplaire de remplacement scanné et ajouté au panier.")
	return true

func in_sort_tray(p:Vector3)->bool:
	return absf(p.x-1.75)<.25 and absf(p.z+5.92)<.23 and p.y>1.08 and p.y<1.6
func build_sort_tray():
	var center=Vector3(1.75,1.12,-5.92)
	Props.box(self,center,Vector3(.46,.025,.40),"53604d")
	for x in [-.23,.23]:Props.box(self,center+Vector3(x,.07,0),Vector3(.015,.14,.40),"53604d")
	Props.box(self,center+Vector3(0,.07,.20),Vector3(.46,.14,.015),"53604d")
	Props.label(self,"À DÉMÊLER",center+Vector3(0,.10,-.21),.0008,27).rotation.y=PI
func store_sort_tray(item:Dictionary,clear_local_hand:bool=true):
	var count=0
	for other in cases:
		if other!=item and other.node.get_meta("in_sort_tray",false):count+=1
	item.node.reparent(self)
	item.node.global_position=Vector3(1.75,1.145+.022*count,-5.92)
	item.node.rotation=Vector3(-PI/2,0,0)
	item.node.freeze=true
	item.node.collision_layer=0
	item.node.collision_mask=0
	item.node.set_meta("in_sort_tray",true)
	if clear_local_hand:clear_hand()

func scan_held()->bool:
	if not game.held:
		game._message("Présente un boîtier au scanner.")
		return false
	if inspection.opened:
		game._message("Referme le boîtier, puis passe son dos au scanner.")
		return false
	if held_service.is_empty() and adopt_held_case().is_empty():return false
	return scan_item(held_service)

func scan_item(item:Dictionary)->bool:
	var node:Node3D=item.node
	if active.get("missing",[]).has(item.movie) and has_identified_mismatch(node,item.movie):
		game._message("Dépose cet exemplaire dans À DÉMÊLER et essaie un autre boîtier.")
		return false
	if node.get_meta("needs_relock",false) and not node.get_meta("return_checked",false):
		var fee=accounts.scan_return(node)
		game._message("Retour enregistré au dossier client. Frais de 2.00 $ à sa prochaine visite." if fee>0 else "Retour enregistré au bon dossier client.")
	if item.kind=="rental" and not item.scanned and paid:
		game._message("Le paiement est terminé. Ce boîtier n’a pas été facturé.")
		return false
	node.set_meta("barcode_scanned",true)
	scan_serial+=1
	item.scanned=true
	accept_replacement(item)
	refresh_basket()
	refresh_invoice()
	refresh_terminal()
	return true
func offer_rental_payment():
	if active.is_empty() or active.get("is_refund",false) or active.get("is_return",false) or active.get("offer_ready",false) or active.get("cash_started",false):return
	var titles:Array=active.get("price_titles",active.items.map(func(item):return item.movie))
	var expected:int=Pricing.quote(game.layout.movies,titles).total+int(active.get("account_due",0))
	if expected<=0:return
	active.offer_ready=true
	tender_parts=Pricing.payment(expected)
	tender=0
	for value in tender_parts:tender+=value

func refresh_invoice():
	if active.is_empty() or active.get("is_refund",false) or active.get("is_return",false):return
	var ids:Array=active.get("billed_titles",[]).duplicate()
	for item in active.items:
		if item.scanned:ids.append(item.movie)
	var quote=Pricing.quote(game.layout.movies,ids)
	active.subtotal=quote.subtotal
	active.discount=quote.discount
	active.gst=quote.gst
	active.qst=quote.qst
	price=quote.total+int(active.get("account_due",0))
	refresh_basket()
	offer_rental_payment()
	refresh_tender_visual()


func complete_refund(amount:int):
	if active.is_empty() or not active.get("is_refund",false):return
	shift.refunds+=amount
	var customer=active
	active={}
	tender_parts=[]
	refresh_tender_visual()
	customer_delay=2
	if customer.get("return_and_rent",false):
		customer.return_and_rent=false
		customer.is_refund=false
		customer.is_return=false
		customer.visit_mask=2
		customers.begin_browse(customer)
	else:customers.dismiss(customer)
	refresh_terminal()
	game._message("Remboursement remis au client.")
