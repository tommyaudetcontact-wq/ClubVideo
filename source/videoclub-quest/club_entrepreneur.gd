extends Node3D
const Rules=preload("res://entrepreneur_state.gd")
const World=preload("res://entrepreneur_world.gd")
const Props=preload("res://clerk_props.gd")
var game
const Build=preload("res://entrepreneur_build.gd")
var slots=preload("res://entrepreneur_slots.gd").new()
var active_screw:=-1
var decor=preload("res://entrepreneur_decor.gd").new()
var state:Rules=Rules.new()
var office_screen:MeshInstance3D
var calendar_label:Label3D
var calendar_key:Array=[]
var calendar_canvas:Control
var watch:Label3D
var sign:Label3D
var sun:DirectionalLight3D
var sky_material:ProceduralSkyMaterial
var packages:Dictionary={}
var shelf_nodes:Array[Node3D]=[]
var assembly:Dictionary={}
var assembly_node:Node3D
var ghost:Node3D
var ghost_label:Label3D
var placement_hand:=1
var placement_angle:=0.0
var placement_valid:=false
var drill:Node3D
var drill_hand:=-1
var board:Node3D
var board_hand:=-1
var loose_board:RigidBody3D
var screw_progress:=0.0
var second_clock:=0.0
var phone_remaining:=75.0
var highlighted:Node3D
var locate_id:=-1
var release_today:=-1
var sound:AudioStreamPlayer3D
var ledgers:Dictionary={}
var poster_placement=preload("res://entrepreneur_poster_placement.gd").new()
var guest_board:=false
var guest_drill:=false
var guest_placing:=false
var guest_poster_order:=-1
var guest_board_node:Node3D
var freight=preload("res://entrepreneur_freight.gd").new()
var moving_shelf:=-1
var carry_offset:=Transform3D.IDENTITY
var order_serial:=100

func setup(g) -> void:
	game=g
	preload("res://boot_trace.gd").mark("setup-enter",get_tree())
	poster_placement.setup(self)
	freight.setup(self)
	slots.setup(self)
	preload("res://boot_trace.gd").mark("state-init",get_tree())
	state.initialize(game.layout.movies,randi())
	game.clerk.max_basket=4
	game.clerk.shift.started=false
	game.clerk.shift.target_customers=6
	game.clerk.phone_enabled=true
	game.clerk.phone_timer=1.0e20
	# The fixed float belongs to the business, separate from purchasing cash.
	game.clerk.till={2000:0,1000:1,500:3,200:8,100:5,25:12,10:5,5:8,1:10}
	# Exactly $50, including coins, allows practical early-day change.
	game.clerk.till[1000]=1
	game.clerk.shift.initial_cash=game.clerk.shift.cash_in_till()
	preload("res://boot_trace.gd").mark("records-start",get_tree())
	for record in game.dvd_records:
		record.clerk_reserved=true
		record.disc_movie=record.movie
		record.disc_uid=record.id
		record.dirty=false
		var zero:=Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)
		record.group.multimesh.set_instance_transform(record.index,zero)
		if game.shell and record.shell_index>=0:game.shell.multimesh.set_instance_transform(record.shell_index,zero)
		game.clerk.locks.update_slot(record)
	preload("res://boot_trace.gd").mark("backstore-start",get_tree())
	build_backstore()
	preload("res://boot_trace.gd").mark("backstore-done",get_tree())
	var display:MeshInstance3D=game.clerk.screen
	var center:Transform3D=display.global_transform
	center.origin.y+=.13;center.origin+=center.basis.z*.06
	var monitor:=World.office_monitor(self)
	monitor.global_transform=center*Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*1.35),Vector3(0,-.025,-.238*1.35))
	var face:=QuadMesh.new();face.size=Vector2(.594,.432)
	display.mesh=face;display.global_transform=center
	build_watch()
	preload("res://boot_trace.gd").mark("decor-start",get_tree())
	decor.setup(self)
	preload("res://boot_trace.gd").mark("decor-done",get_tree())
	update_prices()
	apply_weather()
	preload("res://boot_trace.gd").mark("calendar-start",get_tree())
	refresh_calendar()

func status() -> String:
	var date:Dictionary=state.calendar()
	return "ENTREPRENEUR · %02d/%02d/%04d\n%s · %s · %s\nAchats disponibles : %.2f $\nFond de caisse : %.2f $\nExemplaires : %d · réservations : %d\n%s"%[date.day,date.month,date.year,state.hour(),state.weather,state.phase,state.cash/100.0,game.clerk.shift.cash_in_till()/100.0,state.stock.size(),state.reservations.size(),state.report]

func switch_mode() -> void:
	if game.session and not game.session.load_failed:game.session.save_game(false)
	get_tree().set_meta("entrepreneur_mode",not game.entrepreneur_mode)
	get_tree().set_meta("streamer_mode",false)
	get_tree().paused=false
	get_tree().reload_current_scene()

func build_backstore() -> void:
	var rear:Array=game.layout.colliders.filter(func(box):return box.min[2]<-9 and box.max[1]>3 and box.max[2]<-9)
	for box in rear:game.layout.colliders.erase(box)
	# Remove the old rear wall so the new room is physically accessible.
	for node in game.model.find_children("*","MeshInstance3D",true,false):
		if not node.mesh:continue
		var bounds: AABB=node.global_transform*node.get_aabb()
		if bounds.position.z<-9.35 and bounds.end.z<-9.2 and bounds.size.y>2:node.hide()
	var floor_body:=World.solid(self,Vector3(0,-.05,-11.7),Vector3(11.5,.1,5.4),"70746e")
	floor_body.get_child(0).material_override=World.staff_surface("vinyl","70746e")
	add_wall(Vector3(0,1.65,-14.35),Vector3(11.5,3.3,.12))
	add_wall(Vector3(-5.72,1.65,-11.7),Vector3(.12,3.3,5.4))
	add_wall(Vector3(5.72,1.65,-11.7),Vector3(.12,3.3,5.4))
	add_wall(Vector3(-.95,1.65,-7.9),Vector3(9.5,3.3,.10))
	add_wall(Vector3(5.35,1.65,-7.9),Vector3(.7,3.3,.10))
	World.solid(self,Vector3(4.35,2.95,-7.9),Vector3(1.8,.7,.12),"c5bb9e")
	Props.label(self,"RÉSERVÉ AU PERSONNEL",Vector3(4.35,2.5,-7.82),.0008,32)
	World.solid(self,Vector3(0,3.3,-11.1),Vector3(11.5,.08,6.4),"bbb8aa")
	for z in [-9.6,-12.6]:
		Props.box(self,Vector3(0,3.22,z),Vector3(1.25,.035,.22),"e8e6ca")
		var light:=OmniLight3D.new()
		light.position=Vector3(0,2.8,z)
		light.light_energy=.7
		light.omni_range=5
		light.shadow_enabled=false
		add_child(light)
	var bench_top:=World.solid(self,Vector3(-3.8,.65,-12.9),Vector3(2.5,.06,1.0),"a88963")
	bench_top.get_child(0).material_override=World.staff_surface("wood","a88963")
	World.desk_base(self,Vector3(-3.8,-.1,-12.9),2.5,1.0)
	game.layout.colliders.append({"min":[-5.05,0,-13.4],"max":[-2.55,.7,-12.4]})
	Props.label(self,"ASSEMBLAGE · PLANCHES ET VIS",Vector3(-3.8,1.65,-13.45),.0009,28)
	drill=World.drill(self)
	drill.position=Vector3(-3.1,.78,-12.8)
	game.clerk.target(drill,"enterprise",.13,2)
	var screw_box:=Props.box(self,Vector3(-2.8,.725,-12.75),Vector3(.15,.09,.12),"bbaa87")
	for i in 7:
		var pin:=Props.cylinder(screw_box,Vector3((i%4-.5)*.025,.065,(i/4)*.025),.004,.055,"b5bdc1",.7)
		pin.rotation.x=.4
	World.solid(self,Vector3(3.7,.72,-13.6),Vector3(2.8,.06,1.0),"b59a73")
	World.desk_base(self,Vector3(3.7,0,-13.6),2.8,1.0,true)
	Build.backstore(self,World)
	var rack_body:=World.solid(self,Vector3(-.825,1.0,-13.86),Vector3(2.2,2.0,.56),"737d83")
	rack_body.get_child(0).hide()
	game.layout.colliders.append({"min":[-1.925,0,-14.14],"max":[.275,2,-13.58]})
	Build.staff_posters(self,game.layout.movies)
	game.layout.colliders.append({"min":[2.3,0,-14.1],"max":[5.1,.8,-13.1]})
	var monitor:=World.office_monitor(self)
	monitor.scale=Vector3.ONE*1.40
	monitor.position=Vector3(3.6,1.12,-13.7)
	office_screen=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(.616,.448)
	office_screen.mesh=quad
	office_screen.position=Vector3(3.6,1.155,-13.367)
	add_child(office_screen)
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture=game.clerk.terminal.get_texture()
	office_screen.material_override=mat
	var keyboard:=World.office_keyboard(self)
	keyboard.position=Vector3(3.6,.78,-13.15)
	game.clerk.target(office_screen,"enterprise",.40,3)
	calendar_label=Props.label(self,"",Vector3(1.4,1.7,-14.26),.00085,29)
	var calendar_back:=Props.box(self,Vector3(1.4,1.7,-14.29),Vector3(1.35,1.20,.018),"eee8d2")
	calendar_back.material_override=Props.material("eee8d2")
	calendar_label.modulate=Color("202c3b")
	calendar_label.outline_size=0
	calendar_label.hide()
	var calendar_view:=SubViewport.new()
	calendar_view.size=Vector2i(768,672)
	calendar_view.disable_3d=true
	calendar_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(calendar_view)
	calendar_canvas=preload("res://entrepreneur_calendar.gd").new()
	calendar_canvas.size=Vector2(768,672)
	calendar_canvas.movies=game.layout.movies
	calendar_view.add_child(calendar_canvas)
	var paper:=MeshInstance3D.new()
	var paper_quad:=QuadMesh.new();paper_quad.size=Vector2(1.55,1.36)
	paper.mesh=paper_quad;paper.position=Vector3(1.4,1.7,-14.255)
	var paper_material:=StandardMaterial3D.new()
	paper_material.albedo_texture=calendar_view.get_texture()
	paper_material.roughness=.9
	paper_material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	paper.material_override=paper_material
	paper.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(paper)
	Props.cylinder(self,Vector3(1.4,2.28,-14.25),.014,.005,"979d9e",.7).rotation.x=PI/2
	Props.box(self,Vector3(.2,.015,-11.2),Vector3(2,.01,1.5),"7c8c91")
	Props.label(self,"RÉCEPTION DES COLIS",Vector3(.2,1.6,-11.7),.001,34)
	sign=Props.label(self,"FERMÉ",Vector3(-4.72,1.9,6.94),.0014,44)
	sign.rotation.y=PI
	sign.modulate=Color("ec8972")
	game.clerk.target(sign,"enterprise",.24,0)
	# Dedicated rack for telephone reservations, behind the register.
	World.solid(self,Vector3(2.7,1.01,-7.2),Vector3(.65,.04,.36),"5b6973")
	for x in range(5):Props.box(self,Vector3(2.4+x*.15,1.13,-7.2),Vector3(.01,.22,.36),"71808b")
	Props.label(self,"RÉSERVATIONS",Vector3(2.7,1.34,-7.1),.00065,26)
	ghost_label=Props.label(self,"",Vector3.ZERO,.001,32)
	ghost_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	highlighted=MeshInstance3D.new()
	var highlight_mesh:=BoxMesh.new()
	highlight_mesh.size=Vector3(.155,.215,.032)
	highlighted.mesh=highlight_mesh
	var highlight_mat:=StandardMaterial3D.new()
	highlight_mat.albedo_color=Color(1,.85,.05,.3)
	highlight_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight_mat.no_depth_test=true
	highlighted.material_override=highlight_mat
	add_child(highlighted)
	highlighted.hide()
	sound=AudioStreamPlayer3D.new()
	add_child(sound)
	sun=DirectionalLight3D.new()
	sun.shadow_enabled=false
	add_child(sun)
	for environment in game.find_children("*","WorldEnvironment",true,false):
		sky_material=ProceduralSkyMaterial.new()
		sky_material.sky_horizon_color=Color("c3c8cf")
		sky_material.ground_horizon_color=Color("c3c8cf")
		environment.environment.sky=Sky.new()
		environment.environment.sky.sky_material=sky_material

func add_wall(position:Vector3,size:Vector3) -> void:
	var wall:=World.solid(self,position,size,"b6b2a2")
	wall.get_child(0).material_override=World.staff_surface("plaster","b6b2a2")
	game.layout.colliders.append({"min":[position.x-size.x/2,0,position.z-size.z/2],"max":[position.x+size.x/2,size.y,position.z+size.z/2]})

func build_watch() -> void:
	var base:=Node3D.new()
	game.hands[0].add_child(base)
	base.position=Vector3(0,.025,.075)
	Props.box(base,Vector3.ZERO,Vector3(.073,.014,.044),"323c43")
	Props.box(base,Vector3(0,-.009,0),Vector3(.025,.022,.06),"272e32")
	watch=Props.label(base,"08:00\n250.00 $",Vector3(0,.009,0),.00046,24)
	watch.rotation.x=-PI/2
	watch.modulate=Color("b2e69c")
	watch.no_depth_test=true

func update_prices() -> void:
	for movie in game.layout.movies:movie.business_rent=state.rental(movie)

func apply_weather() -> void:
	game.modes.rain_enabled=state.weather=="pluie"
	for rain in game.modes.rain_nodes:rain.emitting=game.modes.rain_enabled
	var fraction:=clampf(state.played/480.0,0,1)
	var night:=clampf((fraction-.55)/.25,0,1)
	if sky_material:
		sky_material.sky_top_color=Color("567fba").lerp(Color("081025"),night)
		sky_material.sky_horizon_color=Color("e7cda9").lerp(Color("24304c"),night)
		sky_material.ground_horizon_color=sky_material.sky_horizon_color
		if state.weather=="pluie":sky_material.sky_top_color=sky_material.sky_top_color.lerp(Color("515f70"),.65)
	sun.rotation_degrees=Vector3(-maxf(4,sin(fraction*PI)*60),-70+fraction*140,0)
	sun.light_color=Color("ffe0af").lerp(Color("95a9d0"),night)
	sun.light_energy=(1.0-night)*(.4 if state.weather=="pluie" else .75)

func refresh_calendar() -> void:
	var key:Array=[state.day,state.next_release,state.next_bundle,state.upcoming.hash(),state.release_days.hash()]
	if key==calendar_key:return
	calendar_key=key
	var date:Dictionary=state.calendar()
	var first:=Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict({"year":date.year,"month":date.month,"day":1,"hour":0,"minute":0,"second":0}))
	var text:="%04d · %02d\nL   M   M   J   V   S   D\n"%[date.year,date.month]
	var offset:=(int(first.weekday)+6)%7
	text+="    ".repeat(offset)
	for number in range(1,state.calendar_days()+1):
		text+=(" X  " if number<int(date.day) else "(%02d)"%number if number==int(date.day) else "%02d  "%number)
		if (offset+number)%7==0:text+="\n"
	calendar_label.text=text
	if calendar_canvas:calendar_canvas.configure(state)

func tick(dt:float) -> void:
	for order in state.orders:
		if order.delivered:continue
		order.remaining=maxf(0,float(order.remaining)-dt)
		if order.remaining==0:deliver(order)
	if state.phase=="open":
		state.played=minf(480,state.played+dt)
		game.clerk.shift.time_left=480-state.played
		phone_remaining-=dt
		if phone_remaining<=0:
			phone_remaining=state.rng.randf_range(70,130)
			if not game.clerk.ringing:
				game.clerk.ringing=true
				game.clerk.ring_serial+=1
				game.clerk.phone_audio.play()
		if state.played>=480:
			game.clerk.ringing=false
			game.clerk.phone_audio.stop()
			state.phase="closing"
			game.clerk.shift.closing=true
			sign.text="FERMÉ"
			sign.modulate=Color("ec8972")
			game._message("Minuit. Termine les clients, puis fais le close.")
	second_clock+=dt
	if second_clock>=1:
		second_clock=0
		watch.text=state.hour()+"\n%.2f $"%(state.cash/100.0)
		apply_weather()
		update_locator()
	update_tools(dt)

func open_day() -> bool:
	if not state.start_day():
		game._message("Avant d’ouvrir : assemble une étagère et range au moins un film.")
		return false
	var shift=game.clerk.shift
	shift.started=true
	shift.closing=false
	shift.summary=false
	shift.day=state.day
	shift.target_customers=state.arrival_limit()
	shift.arrived_customers=0
	shift.duration=480
	shift.initial_cash=shift.cash_in_till()
	game.clerk.customers.spawn_timer=8
	for job in game.clerk.returns_due:
		if int(job.get("business_due_day",999999))<=state.day:job.time=game.clerk.elapsed+state.rng.randf_range(15,240)
	sign.text="OUVERT"
	sign.modulate=Color("86e9be")
	game._message("Ouvert · 08:00 · Premier jour : jusqu’à 6 clients." if state.day==1 else "La boutique est ouverte jusqu’à minuit.")
	return true

func close_day() -> bool:
	var c=game.clerk
	if state.phase!="closing":return false
	if not c.active.is_empty() or not c.customers.customers.is_empty():
		game._message("Termine le service et attends la sortie des clients.")
		return false
	for item in c.cases:
		if item.node.get_meta("in_sort_tray",false):continue
		game._message("Range les retours et les boîtiers. Le bac À démêler peut attendre.")
		return false
	if c.shift.game_has_loose_stock() or c.wallet.occupied(0) or c.wallet.occupied(1) or not c.wallet.loose.is_empty() or c.drawer_open:
		game._message("Ramasse les objets et l’argent, puis ferme le tiroir.")
		return false
	if is_instance_valid(c.repairs.disc) or is_instance_valid(c.inspection.carried):
		game._message("Termine la réparation et dépose le disque.")
		return false
	var delta:int=c.shift.cash_in_till()-int(c.shift.initial_cash)
	state.cash+=delta
	for value in c.till:c.till[value]=0
	c.till={2000:0,1000:1,500:3,200:8,100:5,25:12,10:5,5:8,1:10}
	var error:int=delta-(state.daily_receipts-state.daily_refunds)
	state.report="Recettes %.2f $ · remboursements %.2f $\nÉcart de caisse %+.2f $ · trésorerie %.2f $"%[state.daily_receipts/100.0,state.daily_refunds/100.0,error/100.0,state.cash/100.0]
	state.phase="closed"
	c.shift.summary=true
	c.shift.report=state.report
	game.session.save_game(false)
	return true

func next_day() -> void:
	if state.phase!="closed":return
	state.next_day(game.layout.movies)
	var shift=game.clerk.shift
	shift.day=state.day
	shift.started=false
	shift.summary=false
	shift.closing=false
	shift.served=0
	shift.revenue=0
	shift.refunds=0
	shift.arrived_customers=0
	shift.lost_sales=0
	for entry in state.stock.values():
		if not entry.get("returned_scanned",true) and int(entry.get("due_day",999999))<state.day:
			var account:int=entry.get("account",-1)
			var ledger:Dictionary=ledgers.get(account,{})
			ledger.late=int(ledger.get("late",0))+1
			ledger.balance=int(ledger.get("balance",0))+100
			ledgers[account]=ledger
	update_prices()
	apply_weather()
	refresh_calendar()
	game.session.save_game(false)
	game._message("Nouvelle journée. Prépare les commandes et ouvre le néon quand tu es prêt.")

func record_sale(amount:int,account:int) -> void:
	state.daily_receipts+=amount
	var ledger:Dictionary=ledgers.get(account,{})
	ledger.visits=int(ledger.get("visits",0))+1
	ledgers[account]=ledger

func record_refund(amount:int) -> void:state.daily_refunds+=amount

func available_stock() -> bool:
	return game.dvd_records.any(func(record):return state.stock.has(int(record.id)) and state.stock[int(record.id)].get("shelved",false) and not record.get("clerk_reserved",true))

func arrival_delay() -> float:
	var remaining:=maxi(1,int(game.clerk.shift.target_customers)-int(game.clerk.shift.arrived_customers))
	var interval:=(480-state.played)/remaining
	return state.rng.randf_range(maxf(6,interval*.35),maxf(10,interval*1.15))

func prepare_customer(customer:Dictionary) -> void:
	var returning:bool=not customer.return_job.is_empty()
	if not returning:
		if ledgers.get(int(customer.account_id),{}).get("banned",false):customer.account_id=game.clerk.accounts.create_account()
		var regulars:Array=ledgers.keys().filter(func(id):return not ledgers[id].get("banned",false) and not game.clerk.customers.customers.any(func(other):return other!=customer and int(other.get("account_id",-1))==int(id)))
		if not regulars.is_empty() and state.rng.randf()<.65:customer.account_id=regulars[state.rng.randi_range(0,regulars.size()-1)]
		customer.selection_left=state.rng.randf_range(15,60) if state.day==1 else state.rng.randf_range(20,120)
		var ledger:Dictionary=ledgers.get(int(customer.account_id),{})
		if not ledger.has("genre"):ledger.genre=str(game.layout.movies[state.offers[state.rng.randi_range(0,state.offers.size()-1)]].get("genre","Comédie"))
		ledgers[int(customer.account_id)]=ledger
		var candidates:Array=game.dvd_records.filter(func(record):return not record.get("clerk_reserved",true) and state.stock.has(int(record.id)) and not record.get("loose",false))
		if not candidates.is_empty():
			var preferred:Array=candidates.filter(func(record):return str(game.layout.movies[record.movie].get("genre",""))==ledger.genre)
			if preferred.is_empty():preferred=candidates
			var ranked:=rank_titles(preferred.map(func(record):return int(record.movie)))
			customer.movie=ranked[0]
		for reservation in state.reservations:
			if int(reservation.account)==int(customer.account_id) and reservation.get("ready",false):
				customer.movie=int(reservation.movie)
				customer.business_reservation=int(reservation.record)
		if state.rng.randf()<.15:customer.recommendation=true
		var appointments:Array=state.reservations.filter(func(reservation):return int(reservation.day)<=state.day and not game.clerk.customers.customers.any(func(other):return other!=customer and int(other.get("account_id",-1))==int(reservation.account)))
		if not appointments.is_empty():
			customer.account_id=int(appointments[0].account)
			customer.movie=int(appointments[0].movie)
			customer.business_reservation=int(appointments[0].record)
			customer.recommendation=false
		customer.visit_balance=int(game.clerk.accounts.ensure(int(customer.account_id)).balance)
	apply_regular_appearance(customer)

func apply_regular_appearance(customer:Dictionary) -> void:
	var account:int=customer.account_id
	var ledger:Dictionary=ledgers.get(account,{})
	if not ledger.has("appearance"):ledger.appearance=int(customer.get("appearance",0))
	var appearance:int=clampi(int(ledger.appearance),0,5)
	if appearance!=int(customer.get("appearance",0)):
		if load("res://customer_actor.gd").replace(customer.node,appearance):customer.appearance=appearance
	ledgers[account]=ledger

func assess_return_damage(data:Dictionary,source:Node3D=null) -> void:
	var damaged:bool=data.get("returned_damage",false)
	var account:int=data.get("return_account",-1)
	var cycle:int=data.get("return_cycle",-1)
	if is_instance_valid(source):
		damaged=bool(source.get_meta("returned_damage",false))
		account=int(source.get_meta("return_account",-1))
		cycle=int(source.get_meta("return_cycle",-1))
	if not damaged or not data.get("dirty",false) or account<0 or cycle<0:return
	var ledger:Dictionary=ledgers.get(account,{})
	var assessed:Dictionary=ledger.get("damage_cycles",{})
	var key:=str(cycle)
	if assessed.has(key):return
	assessed[key]=true
	ledger.damage_cycles=assessed
	ledger.damage=int(ledger.get("damage",0))+1
	ledger.balance=int(ledger.get("balance",0))+300
	ledgers[account]=ledger
	game._message("Rayures constatées : 3 $ de frais ajoutés au dossier du client. À réclamer à sa prochaine visite.")

func take_reservation(customer:Dictionary) -> Dictionary:
	var id:int=customer.get("business_reservation",-1)
	if id<0:
		var pending:Array=state.reservations.filter(func(reservation):return int(reservation.account)==int(customer.account_id) and not reservation.get("ready",false))
		if not pending.is_empty():state.reservations.erase(pending[0])
		return {}
	var matches:Array=state.reservations.filter(func(reservation):return int(reservation.record)==id and int(reservation.account)==int(customer.account_id))
	if matches.is_empty():return {}
	for node in get_children():
		if node.get_meta("reservation_record",-1)==id:node.queue_free()
	state.reservations.erase(matches[0])
	customer.erase("business_reservation")
	return game.dvd_records[id]

func title_weight(movie:int,labeled:bool=false) -> float:
	var weight:=clampf(1.0+(float(state.ratings.get(movie,3)) - 3.0)*.2,.5,1.5)
	if state.is_new(movie):
		weight*=1.5
		if state.posters.any(func(poster):return int(poster.movie)==movie):weight*=2.5
	if labeled:weight*=1.2
	return weight

func rank_titles(titles:Array) -> Array:
	var ranked:Array=[]
	var seen:Dictionary={}
	var labeled:Dictionary={}
	for copy in state.stock.values():
		if not copy.get("shelved",false) or copy.get("sold",false):continue
		var index:int=copy.get("shelf",-1)
		var id:int=copy.movie
		if index>=0 and index<state.shelves.size() and str(state.shelves[index].get("genre","")).to_lower()==str(game.layout.movies[id].get("genre","")).to_lower():labeled[id]=true
	for title in titles:
		var id:=int(title)
		if seen.has(id):continue
		seen[id]=true
		ranked.append({"id":id,"score":-log(maxf(.000001,state.rng.randf()))/title_weight(id,labeled.has(id))})
	ranked.sort_custom(func(a,b):return a.score<b.score)
	return ranked.map(func(entry):return int(entry.id))

func basket_size(customer:Dictionary) -> int:
	var quality:=0.0
	var count:=0
	for entry in state.stock.values():
		if entry.get("sold",false):continue
		quality+=float(state.ratings.get(int(entry.movie),3))
		count+=1
	var active_posters:int=state.posters.filter(func(poster):return state.is_new(int(poster.movie))).size()
	var bonus:=(quality/maxi(count,1)-2.5)*.12+minf(.25,active_posters*.04)
	if customer.get("recommendation",false):return 1
	var roll:=state.rng.randf()
	return 4 if roll<bonus*.35 else 3 if roll<bonus else 2 if roll<.35+bonus else 1

func schedule_return(job:Dictionary) -> void:
	var due:=state.day+state.rng.randi_range(1,3)
	job.business_due_day=due
	job.time=1.0e20
	var entry:Dictionary=state.stock.get(int(job.record.id),{})
	entry.returned_scanned=false
	entry.due_day=due
	entry.account=int(job.account_id)
	entry.shelved=false

func scan_return(item:Dictionary) -> void:
	var record:Dictionary=item.get("record",{})
	if record.is_empty() or not state.stock.has(int(record.id)):return
	var entry:Dictionary=state.stock[int(record.id)]
	if not entry.get("returned_physical",false) or entry.get("returned_scanned",true):return
	entry.returned_scanned=true
	entry.returned_physical=false
	record.pending_return=false
	game.clerk.accounts.scan_return(item.node)
	game._message("Retour scanné : exemplaire retrouvé dans l’inventaire.")

func physical_return(item:Dictionary,job:Dictionary) -> void:
	var record:Dictionary=job.record
	if not state.stock.has(int(record.id)):return
	var entry:Dictionary=state.stock[int(record.id)]
	entry.returned_physical=true
	entry.returned_scanned=false
	entry.return_cycle=int(job.get("rental_id",-1))
	entry.account=int(item.node.get_meta("return_account",-1))
	record.pending_return=true
	record.return_account=entry.account
	record.return_cycle=entry.return_cycle

func can_shelve(record:Dictionary) -> bool:
	if not state.stock.has(int(record.id)) or state.stock[int(record.id)].get("sold",false):return false
	var entry:Dictionary=state.stock[int(record.id)]
	if int(entry.shelf)<0:
		var room:=free_slots()
		if room.is_empty():return false
		entry.shelf=room[0].shelf;entry.slot=room[0].slot
		move_record(record)
	entry.shelved=true
	return true

func buy_film(movie:int) -> bool:
	if not state.offers.has(movie):return false
	var ok:=state.buy("films",movie,state.purchase_price(game.layout.movies[movie]),[movie])
	if ok:flush_orders()
	return ok

func buy_shelf(model:int) -> bool:
	var ok:bool=model in range(3) and state.buy("shelf",model,Rules.SHELF_PRICES[model])
	if ok:flush_orders()
	return ok

func flush_orders() -> void:
	for order in state.orders:
		if not order.delivered:deliver(order)
	freight.tick()


func deliver(order:Dictionary) -> void:
	order.delivered=true
	var caption:String="ÉTAGÈRE · À ASSEMBLER" if order.kind=="shelf" else "FILMS · OUVRIR" if order.kind=="films" else decor.NAMES[int(order.value)].to_upper()+" · OUVRIR" if order.kind=="decoration" else "AFFICHE · OUVRIR"
	var parcel:=World.parcel(self,Vector3(-1.9+(packages.size()%3)*1.9,.135,-10.4-floorf(packages.size()/3.0)*.85),caption,order.kind=="shelf")
	packages[int(order.id)]=parcel
	if order.has("pose"):parcel.transform=order.pose
	freight.refresh(order)
	game.clerk.target(parcel,"enterprise",.28,100+int(order.id))
	game._message("Colis livré au backstore.")

func action(value:int,hand:int) -> void:
	if value>=100 and game.touch_profile:
		var order:Dictionary=freight.order_for(value-100)
		if order.get("kind","")=="films" and freight.held_id<0:
			freight.take(value-100,0);return
	if value>=100 and freight.use(value-100,hand):return
	if value==0:
		if state.phase=="preparation":open_day()
		elif state.phase=="closing":close_day()
		elif state.phase=="closed":next_day()
		else:game._message("Fermeture automatique à minuit.")
	elif value==2:
		if guest_drill:game._message("Ton collègue utilise la perceuse.");return
		drill_hand=-1 if drill_hand==hand else hand
	elif value==3:game.clerk.desktop.open_program(5)
	elif value==4:take_board(hand)
	elif value>=100:open_parcel(value-100)

func open_parcel(id:int) -> void:
	if guest_poster_order==id:
		game._message("Ton collègue place cette affiche.")
		return
	if poster_placement.active():
		game._message("Pose l’affiche en cours ou annule avec la poignée.")
		return
	var orders:Array=state.orders.filter(func(order):return int(order.id)==id)
	if orders.is_empty():return
	var order:Dictionary=orders[0]
	if order.kind=="shelf":
		if not assembly.is_empty():
			game._message("Termine l’étagère en cours avant d’ouvrir celle-ci.")
			return
		if freight.guest_id==id:
			var point:Vector3=packages[id].position
			var height:=0.0
			for box in game.layout.colliders:
				if point.x>box.min[0] and point.x<box.max[0] and point.z>box.min[2] and point.z<box.max[2] and box.max[1]<point.y+.1:height=maxf(height,float(box.max[1]))
			packages[id].position.y=height+.135
		var box_pose:Transform3D=packages[id].global_transform
		var base:Vector3=box_pose.origin-Vector3(0,.135,0)
		if freight.held_id==id:base.y=0
		assembly={"model":order.value,"boards":0,"screws":0,"screw_mask":0,"stage":"site","order":id,"pose":Transform3D(Basis(Vector3.UP,snappedf(box_pose.basis.get_euler().y,PI/4)),base)}
		order.opened=true
		freight.refresh(order)
		placement_hand=1-freight.held_hand if freight.held_hand>=0 else 1
		guest_placing=freight.guest_id==id
		begin_placement()
		ghost.transform=snap_placement(base,box_pose.basis.get_euler().y,int(order.value))
		game._message("Carton ouvert. Vise le sol pour choisir le lieu du montage, puis confirme avec la gâchette.")
		return
	elif order.kind=="decoration":
		freight.held_id=-1;freight.held_hand=-1;freight.guest_id=-1
		decor.begin(order);return
	elif order.kind=="films":
		freight.open_box(order)
		return
	elif order.kind=="sign":
		var shelf:int=order.contents[0]
		if shelf<state.shelves.size():
			state.shelves[shelf].genre=Rules.CATEGORIES[int(order.value)]
			var header:Label3D=shelf_nodes[shelf].get_node("CategoryHeader")
			header.text=str(state.shelves[shelf].genre).to_upper()
	else:
		if is_instance_valid(ghost):
			game._message("Pose d’abord l’étagère en cours.")
			return
		poster_placement.begin(order)
		return
	consume_order(order)

func consume_order(order:Dictionary) -> void:
	var id:int=order.id
	if freight.held_id==id:freight.held_id=-1;freight.held_hand=-1
	if freight.guest_id==id:freight.guest_id=-1
	state.orders.erase(order)
	if packages.has(id):
		var parcel:Node3D=packages[id]
		game.clerk.targets=game.clerk.targets.filter(func(target):return target.node!=parcel)
		parcel.queue_free()
		packages.erase(id)

func free_slots() -> Array:
	var result:Array=[]
	for index in state.shelves.size():
		var shelf:Dictionary=state.shelves[index]
		var capacity:int=Rules.SHELF_COLUMNS[int(shelf.model)]*4
		for slot in capacity:
			if slots.is_free(index,slot):
				result.append({"shelf":index,"slot":slot})
	return result

func receive_film(movie:int,spawn_at:Vector3=Vector3(.1,.8,-11)) -> bool:
	var copies:Array=game.dvd_records.filter(func(record):return int(record.movie)==movie and not state.stock.has(int(record.id)))
	if copies.is_empty():
		game._message("Limite d’exemplaires pour ce titre. Colis conservé.")
		return false
	var record:Dictionary=copies[0]
	state.stock[int(record.id)]={"movie":movie,"shelf":-1,"slot":-1,"shelved":false,"sold":false,"returned_scanned":true}
	record.world=Transform3D(Basis.IDENTITY,spawn_at)
	record.local=record.group.global_transform.affine_inverse()*record.world
	record.inverse=record.world.affine_inverse()
	index_record(record)
	var item:Dictionary=game.clerk.new_case(movie,spawn_at,"shelve")
	item.record=record
	load("res://clerk_inventory.gd").bind(item.node,record)
	game.clerk.add_lock(item.node)
	return true

func move_record(record:Dictionary) -> void:
	var entry:Dictionary=state.stock[int(record.id)]
	if int(entry.shelf)<0 or int(entry.shelf)>=state.shelves.size():return
	var shelf:Dictionary=state.shelves[int(entry.shelf)]
	var columns:int=Rules.SHELF_COLUMNS[int(shelf.model)]
	var width:=columns*.145
	var pose:Transform3D=shelf.pose
	record.world=pose*Transform3D(Basis.IDENTITY,Vector3(-width/2+.0725+(int(entry.slot)%columns)*.145,.32+int(int(entry.slot)/columns)*.35,.14))
	record.local=record.group.global_transform.affine_inverse()*record.world
	record.inverse=record.world.affine_inverse()
	record.pending_return=entry.get("returned_physical",false) and not entry.get("returned_scanned",true)
	if record.pending_return:
		record.return_account=entry.get("account",-1)
		record.return_cycle=entry.get("return_cycle",-1)
	index_record(record)
	if game.layout.movies[record.movie].get("fictional",false):
		record.group.multimesh.visible_instance_count=maxi(record.group.multimesh.visible_instance_count,int(record.index)+1)

func build_assembly() -> void:
	if is_instance_valid(assembly_node):
		game.clerk.targets=game.clerk.targets.filter(func(target):return is_instance_valid(target.node) and not assembly_node.is_ancestor_of(target.node))
		remove_child(assembly_node);assembly_node.queue_free()
	assembly_node=Node3D.new();add_child(assembly_node)
	assembly_node.transform=assembly.get("pose",Transform3D(Basis.IDENTITY,Vector3(-3.8,.69,-12.9)))
	var width:float=Rules.SHELF_COLUMNS[int(assembly.model)]*.145+.06
	var count:int=assembly.boards
	for index in 6:
		var transform:Transform3D=Build.part_pose(width,index)
		var part:=Props.box(assembly_node,transform.origin,Build.part_size(width,index),"d8bd60" if index==count else "b4bfcc")
		if index<count:part.material_override=World.laminate()
		else:part.transparency=.50 if index==count else .91
	Props.box(assembly_node,Vector3(0,.20,0),Vector3(width-.052,.024,.34),"333a42")
	if count<6:
		var spare:=Props.box(assembly_node,Vector3(width/2+.35,.18,.55),Build.part_size(width,count),"b58b5b")
		spare.name="SpareBoard";spare.rotation.z=PI/2 if count<2 else 0
		if is_instance_valid(loose_board):spare.hide()
		if assembly.has("loose_pose"):spare.global_transform=assembly.loose_pose
		game.clerk.target(spare,"enterprise",.25,4)
	Props.label(assembly_node,"Planche %d / 6 · relâche la poignée sur le contour jaune"%mini(6,count+1) if count<6 else "Visse chaque jonction · ordre libre",Vector3(0,1.99,0),.0009,29).billboard=BaseMaterial3D.BILLBOARD_ENABLED
	if count==6:refresh_screws()

func refresh_screws() -> void:
	var old:=assembly_node.get_node_or_null("Screws")
	if old:assembly_node.remove_child(old);old.queue_free()
	var screws:=Node3D.new();screws.name="Screws";assembly_node.add_child(screws)
	var width:float=Rules.SHELF_COLUMNS[int(assembly.model)]*.145+.06
	for index in Build.SCREW_COUNT:
		var screw:=World.assembly_screw(screws);screw.name="Screw%d"%index
		screw.transform=Build.screw_pose(width,index)
		if not Build.done(assembly,index):screw.position+=screw.basis.z*.028

func screw_position(index:int) -> Vector3:
	return Build.screw_pose(Rules.SHELF_COLUMNS[int(assembly.model)]*.145+.06,index).origin

func targeted_screw() -> int:
	if assembly.is_empty() or not is_instance_valid(assembly_node):return -1
	var ray:Node3D=game.aim_hands[1 if drill_hand<0 else drill_hand]
	var best:=.10;var result:=-1
	for i in Build.SCREW_COUNT:
		if Build.done(assembly,i):continue
		var offset:Vector3=assembly_node.to_global(screw_position(i))-ray.global_position
		var distance:float=offset.dot(-ray.global_basis.z)
		var gap:float=(offset+ray.global_basis.z*distance).length()
		if distance>0 and distance<2.5 and gap<best:best=gap;result=i
	return result

func screw_point_local() -> Vector3:
	var index:=active_screw
	if index<0:
		for i in Build.SCREW_COUNT:
			if not Build.done(assembly,i):index=i;break
	return screw_position(maxi(0,index))

func place_board() -> void:
	if assembly.is_empty() or int(assembly.boards)>=6:return
	assembly.erase("loose_pose")
	assembly.boards+=1
	if int(assembly.boards)==6:
		var carton:=freight.order_for(int(assembly.get("order",-1)))
		if not carton.is_empty():consume_order(carton)
	if is_instance_valid(board):board.queue_free()
	board_hand=-1
	build_assembly()

func fasten_screw(dt:float,index:int=-1) -> void:
	if assembly.is_empty() or int(assembly.boards)!=6:return
	if not assembly.has("screw_mask"):assembly.screw_mask=(1<<int(assembly.get("screws",0)))-1
	if index<0:
		for i in Build.SCREW_COUNT:
			if not Build.done(assembly,i):index=i;break
	if index<0 or index>=Build.SCREW_COUNT or Build.done(assembly,index):return
	if active_screw!=index:active_screw=index;screw_progress=0
	screw_progress+=dt
	var pose:Transform3D=Build.screw_pose(Rules.SHELF_COLUMNS[int(assembly.model)]*.145+.06,index)
	var screw:Node3D=assembly_node.get_node("Screws/Screw%d"%index)
	screw.transform=pose;screw.position+=pose.basis.z*.028*(1-minf(1,screw_progress/.6));screw.rotate_object_local(Vector3.FORWARD,screw_progress*TAU*3)
	ghost_label.position=assembly_node.to_global(pose.origin)+Vector3(0,.14,0)
	ghost_label.text="Vis %d/20 · %d %%"%[int(assembly.screws)+1,mini(100,roundi(screw_progress/.6*100))]
	if screw_progress>=.6:
		assembly.screw_mask=int(assembly.screw_mask)|(1<<index);assembly.screws=int(assembly.screws)+1
		screw_progress=0;active_screw=-1
		if int(assembly.screws)>=Build.SCREW_COUNT:complete_assembly()
		else:refresh_screws()

func begin_placement() -> void:
	if is_instance_valid(ghost):return
	drill_hand=-1
	drill.position=Vector3(-3.1,.78,-12.8)
	drill.rotation=Vector3.ZERO
	ghost=World.shelf(self,Rules.SHELF_COLUMNS[int(assembly.model)])
	World.placement_grid(ghost)
	placement_angle=0
	placement_valid=false
	for mesh in ghost.find_children("*","GeometryInstance3D",true,false):mesh.transparency=.5
	if is_instance_valid(assembly_node):assembly_node.hide()

func mobile_hint() -> String:
	if is_instance_valid(decor.preview):return "Poser la décoration"
	if slots.ray_target(game.head.global_position,-game.aim_hands[1].global_basis.z).is_finite() and (game.held or (is_remote_guest() and not game.touch_controls.coop_panel.guest_case_id.is_empty())):return "Ranger à cette place"
	if freight.held_id>=0 and freight.free_item_hand():return freight.hint()
	if is_remote_guest():
		if guest_board:return "Placer la planche"
		if guest_drill and not assembly.is_empty() and int(assembly.boards)==6:return "Visser %d / 20"%(int(assembly.get("screws",0))+1)
		if is_instance_valid(ghost) and not guest_placing:return "Ton collègue place l’étagère"
	if poster_placement.active():return "Poser l’affiche" if poster_placement.valid else "Vise un mur plein"
	if is_instance_valid(ghost):return "Poser l’étagère" if placement_valid else "Déplace la visée au sol"
	if board_hand>=0:return "Placer la planche"
	if drill_hand>=0 and not assembly.is_empty() and int(assembly.boards)==6:return "Visser %d / 20"%(int(assembly.get("screws",0))+1)
	return ""

func mobile_use() -> bool:
	if is_instance_valid(decor.preview):decor.confirm();return true
	if game.held or (is_remote_guest() and not game.touch_controls.coop_panel.guest_case_id.is_empty()):
		var point:Vector3=slots.ray_target(game.head.global_position,-game.aim_hands[1].global_basis.z,int(game.held_record.get("id",-1)))
		if point.is_finite():
			if is_remote_guest():remote_command({"op":"shelve_at","point":[point.x,point.y,point.z]})
			else:game.held.global_position=point;game._release()
			return true
	if freight.held_id>=0 and freight.free_item_hand() and board_hand<0 and not guest_board and not is_instance_valid(ghost):return freight.use(freight.held_id,1)
	if is_remote_guest():
		if guest_board:remote_command({"op":"place_board"});return true
		if guest_drill and not assembly.is_empty() and int(assembly.boards)==6:
			var index:=targeted_screw()
			if index>=0:remote_command({"op":"screw","index":index})
			return true
	if poster_placement.active():
		poster_placement.confirm()
		return true
	if is_instance_valid(ghost):
		if is_remote_guest() and not guest_placing:return true
		if placement_valid:finish_placement()
		return true
	if board_hand>=0:
		if game.head.global_position.distance_to(assembly_node.global_position)<2.8:place_board()
		else:game._message("Approche-toi de l’établi pour poser la planche.")
		return true
	if drill_hand>=0 and not assembly.is_empty() and int(assembly.boards)==6:
		if game.head.global_position.distance_to(assembly_node.global_position)<2.8 and targeted_screw()>=0:fasten_screw(.61,targeted_screw())
		else:game._message("Approche-toi de l’établi pour visser.")
		return true
	return false

func take_board(hand:int) -> void:
	if guest_board or assembly.is_empty() or assembly.get("stage","")!="boards" or int(assembly.boards)>=6 or board_hand>=0:return
	if game.held_hand==hand or game.clerk.wallet.occupied(hand):return
	board=Props.box(self,Vector3.ZERO,Build.part_size(Rules.SHELF_COLUMNS[int(assembly.model)]*.145+.06,int(assembly.boards)),"b58b5b")
	board.material_override=World.laminate();board_hand=hand
	if is_instance_valid(loose_board):
		game.clerk.targets=game.clerk.targets.filter(func(target):return target.node!=loose_board)
		loose_board.queue_free();loose_board=null
	var spare:=assembly_node.get_node_or_null("SpareBoard")
	if spare:spare.hide()

func release_grip(hand:int) -> void:
	if freight.held_hand==hand:freight.drop_from_hand()
	if board_hand!=hand:return
	var target:Vector3=assembly_node.to_global(Build.part_pose(Rules.SHELF_COLUMNS[int(assembly.model)]*.145+.06,int(assembly.boards)).origin)
	if board.global_position.distance_to(target)<.38:
		assembly.erase("loose_pose");place_board()
	else:
		var pose:Transform3D=board.global_transform;pose.origin.y=maxf(.10,pose.origin.y)
		loose_board=RigidBody3D.new();loose_board.name="LooseAssemblyBoard";loose_board.mass=.55;loose_board.continuous_cd=true
		loose_board.collision_layer=8;loose_board.collision_mask=1|8
		add_child(loose_board);loose_board.global_transform=pose
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Build.part_size(Rules.SHELF_COLUMNS[int(assembly.model)]*.145+.06,int(assembly.boards));shape.shape=box;loose_board.add_child(shape)
		board.reparent(loose_board);board.transform=Transform3D.IDENTITY
		assembly.loose_pose=pose;board=null;board_hand=-1;build_assembly()
		game.clerk.target(loose_board,"enterprise",.30,4)
		game._message("Planche déposée. Reprends-la et relâche près du contour jaune.")

func interact(hand:int,grip:bool) -> bool:
	if is_instance_valid(decor.preview):
		if grip:decor.angle+=PI/4
		else:decor.confirm()
		return true
	if is_instance_valid(ghost) and hand==placement_hand:
		if grip:placement_angle=snappedf(placement_angle+PI/4,PI/4);return true
		if placement_valid:finish_placement();return true
	if freight.interact(hand,grip):return true
	if grip and not game.held:
		var hand_point:Vector3=game.hands[hand].global_position
		for item in game.clerk.cases:
			if is_instance_valid(item.node) and item.node.global_position.distance_to(hand_point)<.25:return false
		for id in state.stock:
			if not state.stock[id].get("shelved",false):continue
			if game.dvd_records[int(id)].world.origin.distance_to(hand_point)<.23:return false
	if not is_instance_valid(ghost) and grip and not game.held and not is_remote_guest():
		for index in shelf_nodes.size():
			var local:Vector3=shelf_nodes[index].to_local(game.hands[hand].global_position)
			var width:float=Rules.SHELF_COLUMNS[int(state.shelves[index].model)]*.145+.06
			var frame:bool=absf(absf(local.x)-width/2)<.10 or absf(local.y-(.20+roundf((local.y-.20)/.35)*.35))<.045
			if frame and absf(local.x)<width/2+.10 and local.y>.05 and local.y<1.95 and absf(local.z)<.28:
				placement_hand=hand;start_move_shelf(index);return true
	if poster_placement.active():
		if grip:poster_placement.cancel()
		else:poster_placement.confirm()
		return true
	if game.held and not game.clerk.held_service.is_empty() and game.held_hand==hand:
		if game.held.global_position.distance_to(Vector3(2.7,1.2,-7.2))<.55:
			if reserve_held():return true
	if is_instance_valid(ghost):
		if not grip and placement_valid:finish_placement()
		elif grip:
			placement_angle+=PI/4
			ghost.rotation.y=placement_angle
		return true
	if board_hand==hand:return true
	if drill_hand==hand:
		if grip:
			drill_hand=-1
			drill.position=Vector3(-3.1,.78,-12.8)
			drill.rotation=Vector3.ZERO
		return true
	return false

func update_tools(dt:float) -> void:
	slots.tick(dt)
	if is_instance_valid(loose_board) and not assembly.is_empty():assembly.loose_pose=loose_board.global_transform
	freight.tick()
	if not assembly.is_empty() and int(assembly.boards)<6 and board_hand<0 and is_instance_valid(assembly_node):
		var carton_id:int=int(assembly.get("order",-1))
		if packages.has(carton_id):
			var spare:=assembly_node.get_node_or_null("SpareBoard")
			if spare:spare.global_position=packages[carton_id].global_position+Vector3(0,.15,0)
	poster_placement.tick()
	decor.tick()
	if is_remote_guest():
		if guest_board and is_instance_valid(guest_board_node):guest_board_node.global_transform=game.hands[1].global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-.12))
		if guest_drill:drill.global_transform=game.hands[1].global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-.08))
	if not is_remote_guest() and (guest_board or guest_drill):
		var avatar=game.clerk.lan.remote_avatar
		if is_instance_valid(avatar) and avatar.valid_pose:
			if guest_board and is_instance_valid(guest_board_node):guest_board_node.global_transform=(avatar.targets[2] if avatar.tracked_hands else avatar.targets[0]*Transform3D(Basis.IDENTITY,Vector3(.22,-.25,-.55)))*Transform3D(Basis.IDENTITY,Vector3(0,0,-.12))
			if guest_drill:drill.global_transform=(avatar.targets[2] if avatar.tracked_hands else avatar.targets[0]*Transform3D(Basis.IDENTITY,Vector3(.22,-.25,-.55)))*Transform3D(Basis.IDENTITY,Vector3(0,0,-.08))
	if drill_hand>=0:drill.global_transform=game.hands[drill_hand].global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-.08))
	if board_hand>=0 and is_instance_valid(board):board.global_transform=game.hands[board_hand].global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-.12))
	if not assembly.is_empty() and int(assembly.boards)==6 and drill_hand>=0:
		var selected:=contact_screw()
		if selected>=0 and game.hands[drill_hand].get_float(&"trigger")>.6:fasten_screw(dt,selected)
		elif active_screw>=0:screw_progress=0;active_screw=-1

	if is_instance_valid(ghost):
		if not is_remote_guest() and guest_placing:return
		if is_remote_guest() and not guest_placing:return
		var ray:Node3D=game.aim_hands[placement_hand]
		var direction:Vector3=-ray.global_basis.z
		placement_valid=false
		if direction.y<-.06:
			var p:Vector3=ray.global_position+direction*(-ray.global_position.y/direction.y)
			ghost.transform=snap_placement(p,placement_angle,int(assembly.model))
			p=ghost.position
			placement_valid=valid_placement(ghost.transform,int(assembly.model))
			if moving_shelf>=0:preview_stock()
			ghost_label.position=p+Vector3(0,2.05,0)
			ghost_label.text="Gâchette : choisir l’emplacement · poignée : 45°" if placement_valid and assembly.get("stage","")=="site" else "Gâchette : poser · poignée : 45°" if placement_valid else "Passage bloqué · déplace l’étagère"
			ghost_label.modulate=Color("8ce6b2") if placement_valid else Color("ee9c78")

func valid_placement(pose:Transform3D,model:int) -> bool:
	var width:float=Rules.SHELF_COLUMNS[model]*.145+.06
	var bounds:=pose*AABB(Vector3(-width/2,0,-.18),Vector3(width,1.85,.36))
	if bounds.position.x< -5.63 or bounds.end.x>5.63 or bounds.position.z< -14.15 or bounds.end.z>5.8:return false
	for box in game.layout.colliders:
		if box.get("business_shelf",false):continue
		var low:=Vector3(box.min[0],box.min[1],box.min[2]);var high:=Vector3(box.max[0],box.max[1],box.max[2])
		if high.y<.1:continue
		if bounds.grow(.003).intersects(AABB(low,high-low)):return false
	var front:=pose*AABB(Vector3(-width/2,0,.18),Vector3(width,1.85,.7))
	var access:=pose.origin+pose.basis.z*.65
	if absf(access.x)>5.65 or access.z< -14.15 or access.z>6.1:return false
	for shelf in state.shelves:
		if moving_shelf>=0 and shelf==state.shelves[moving_shelf]:continue
		var other_width:float=Rules.SHELF_COLUMNS[int(shelf.model)]*.145+.06
		var other:AABB=shelf.pose*AABB(Vector3(-other_width/2,0,-.18),Vector3(other_width,1.85,.36))
		var other_front:AABB=shelf.pose*AABB(Vector3(-other_width/2,0,.18),Vector3(other_width,1.85,.7))
		if bounds.grow(.008).intersects(other) or front.intersects(other) or other_front.intersects(bounds):return false
	return true

func snap_placement(position:Vector3,angle:float,model:int) -> Transform3D:
	var basis:=Basis(Vector3.UP,snappedf(angle,PI/4))
	var p:=Vector3(snappedf(position.x,.1),0,snappedf(position.z,.1))
	var width:float=Rules.SHELF_COLUMNS[model]*.145+.06
	var half:=Vector3(width/2,0,.18)
	var extent:=Vector3(absf(basis.x.x)*half.x+absf(basis.z.x)*half.z,0,absf(basis.x.z)*half.x+absf(basis.z.z)*half.z)
	for wall in [-1,1]:
		var wall_x:float=wall*(5.61-extent.x)
		if absf(p.x-wall_x)<.24:p.x=wall_x
	for wall_box in game.layout.colliders:
		var low:=Vector3(wall_box.min[0],wall_box.min[1],wall_box.min[2])
		var high:=Vector3(wall_box.max[0],wall_box.max[1],wall_box.max[2])
		if high.y-low.y<2.2:continue
		if high.x-low.x<.3 and p.z>=low.z-extent.z and p.z<=high.z+extent.z:
			var face:float=low.x-extent.x-.012 if p.x<(low.x+high.x)/2 else high.x+extent.x+.012
			if absf(p.x-face)<.20:p.x=face
		if high.z-low.z<.3 and p.x>=low.x-extent.x and p.x<=high.x+extent.x:
			var face:float=low.z-extent.z-.012 if p.z<(low.z+high.z)/2 else high.z+extent.z+.012
			if absf(p.z-face)<.20:p.z=face
	for shelf in state.shelves:
		if moving_shelf>=0 and shelf==state.shelves[moving_shelf]:continue
		var other:Transform3D=shelf.pose
		var alignment:=basis.z.dot(other.basis.z)
		var other_width:float=Rules.SHELF_COLUMNS[int(shelf.model)]*.145+.06
		if absf(alignment)>.98:
			for side in [-1,1]:
				var candidate:Vector3=other.origin+other.basis.x*side*((width+other_width)/2+.02)
				if p.distance_to(candidate)<.28:p=candidate
			if alignment<-.98:
				var candidate:Vector3=other.origin-other.basis.z*.38
				if p.distance_to(candidate)<.28:p=candidate
	return Transform3D(basis,p)

func start_move_shelf(index:int) -> void:
	if not assembly.is_empty() or index<0 or index>=state.shelves.size():return
	moving_shelf=index
	assembly={"model":state.shelves[index].model,"stage":"move","boards":0,"screws":0,"moving_index":index}
	begin_placement()
	ghost.transform=state.shelves[index].pose
	placement_angle=ghost.rotation.y
	carry_offset=game.hands[placement_hand].global_transform.affine_inverse()*ghost.global_transform
	shelf_nodes[index].hide()
	game._message("Vise le sol · gâchette : poser · poignée : tourner de 45°.")

func complete_assembly() -> void:
	if assembly.is_empty():return
	var entry:Dictionary={"model":assembly.model,"pose":assembly.get("pose",assembly_node.transform),"genre":""}
	state.shelves.append(entry);add_shelf(entry)
	var id:int=int(assembly.get("order",-1))
	for order in state.orders.duplicate():
		if int(order.id)==id:consume_order(order)
	if is_instance_valid(assembly_node):assembly_node.queue_free();assembly_node=null
	assembly={};active_screw=-1;screw_progress=0;guest_drill=false;drill_hand=-1
	drill.position=Vector3(-3.1,.78,-12.8);drill.rotation=Vector3.ZERO
	ghost_label.text="";rebuild_navigation()
	game._message("Étagère assemblée. Prends son cadre pour la placer : rotation de 45°.")

func finish_placement() -> void:
	if not is_instance_valid(ghost):return
	if not valid_placement(ghost.transform,int(assembly.model)):
		game._message("Cet emplacement bloque un meuble ou un passage. Déplace la visée.");return
	if is_remote_guest():
		if guest_placing:remote_command({"op":"place_shelf","point":[ghost.position.x,ghost.position.y,ghost.position.z],"angle":placement_angle})
		return
	guest_placing=false
	if str(assembly.get("stage",""))=="site":
		assembly.pose=ghost.transform
		assembly.stage="boards"
		ghost.queue_free();ghost=null
		ghost_label.text=""
		if packages.has(int(assembly.order)) and freight.held_id!=int(assembly.order):
			packages[int(assembly.order)].position=assembly.pose.origin+assembly.pose.basis.x*(Rules.SHELF_COLUMNS[int(assembly.model)]*.145/2+.35)+Vector3(0,.15,0)
		build_assembly()
		game._message("Emplacement choisi. Prends les six planches à côté, puis visse les vingt vis.")
		return
	if moving_shelf>=0:
		var index:=moving_shelf
		state.shelves[index].pose=ghost.transform
		shelf_nodes[index].transform=ghost.transform
		shelf_nodes[index].show()
		ghost.queue_free();ghost=null;assembly={};moving_shelf=-1
		ghost_label.text=""
		rebuild_shelf_colliders()
		for id in state.stock:
			if int(state.stock[id].shelf)!=index:continue
			var record:Dictionary=game.dvd_records[int(id)]
			move_record(record)
			if state.stock[id].get("shelved",false):game.clerk.restore_stock(record)
		rebuild_navigation()
		return
	guest_drill=false;drill_hand=-1
	drill.position=Vector3(-3.1,.78,-12.8);drill.rotation=Vector3.ZERO
	var finished_order:int=int(assembly.get("order",-1))
	var entry:Dictionary={"model":assembly.model,"pose":ghost.transform,"genre":""}
	state.shelves.append(entry)
	ghost.queue_free()
	ghost=null
	assembly={}
	screw_progress=0
	if is_instance_valid(assembly_node):assembly_node.queue_free()
	if finished_order>=0:
		for order in state.orders.duplicate():
			if int(order.id)==finished_order:consume_order(order)
	ghost_label.text=""
	add_shelf(entry)
	rebuild_navigation()
	game._message("Étagère assemblée et placée. Ouvre les colis de films, puis range-les.")

func is_remote_guest() -> bool:
	return game.touch_controls!=null and game.touch_controls.coop_panel.connected

func remote_command(command:Dictionary) -> bool:
	if not is_remote_guest():return false
	game.touch_controls.coop_panel.send("enterprise","",JSON.stringify(command))
	return true

func release_guest_tools() -> void:
	guest_board=false;guest_drill=false;guest_placing=false;guest_poster_order=-1
	freight.guest_id=-1
	if is_instance_valid(guest_board_node):guest_board_node.queue_free();guest_board_node=null
	if drill_hand<0:drill.position=Vector3(-3.1,.78,-12.8);drill.rotation=Vector3.ZERO

func add_shelf(entry:Dictionary) -> void:
	var node:=World.shelf(self,Rules.SHELF_COLUMNS[int(entry.model)])
	node.transform=entry.pose
	shelf_nodes.append(node)
	var width:float=Rules.SHELF_COLUMNS[int(entry.model)]*.145+.06
	var body:=World.solid(node,Vector3(0,.9,0),Vector3(width,1.8,.34),"333a42")
	body.get_child(0).hide()
	var bounds: AABB=entry.pose*AABB(Vector3(-width/2,0,-.17),Vector3(width,1.8,.34))
	game.layout.colliders.append({"min":[bounds.position.x,0,bounds.position.z],"max":[bounds.end.x,1.8,bounds.end.z],"business_shelf":true})
	if not str(entry.get("genre","")).is_empty():
		node.get_node("CategoryHeader").text=str(entry.genre).to_upper()

func rebuild_shelf_colliders() -> void:
	game.layout.colliders=game.layout.colliders.filter(func(box):return not box.get("business_shelf",false))
	for index in state.shelves.size():
		var entry:Dictionary=state.shelves[index]
		var width:float=Rules.SHELF_COLUMNS[int(entry.model)]*.145+.06
		var bounds:AABB=entry.pose*AABB(Vector3(-width/2,0,-.17),Vector3(width,1.8,.34))
		game.layout.colliders.append({"min":[bounds.position.x,0,bounds.position.z],"max":[bounds.end.x,1.8,bounds.end.z],"business_shelf":true})

func rebuild_navigation() -> void:
	var c=game.clerk.customers
	c.walk_cache.clear()
	c.setup(game,game.clerk)
	game.dvd_grid.clear()
	for record in game.dvd_records:
		if not state.stock.has(int(record.id)):continue
		var cell:=Vector2i(floori(record.world.origin.x/2),floori(record.world.origin.z/2))
		if not game.dvd_grid.has(cell):game.dvd_grid[cell]=[]
		game.dvd_grid[cell].append(record.id)
	game.lod_last_eye=Vector3.INF

func poster_pose(index:int) -> Transform3D:
	return state.posters[index].get("pose",Transform3D(Basis.IDENTITY,Vector3(-3.3+(index%8)*.83,1.9+(int(index/8)%2)*.85,-7.82)))

func place_poster(movie:int,poster_index:int=-1) -> void:
	var index:=poster_index if poster_index>=0 else state.posters.size()-1
	var poster:=MeshInstance3D.new()
	poster.set_meta("business_poster",true)
	var quad:=QuadMesh.new()
	quad.size=Vector2(.55,.78)
	poster.mesh=quad
	poster.transform=poster_pose(index)
	add_child(poster)
	var mat:=StandardMaterial3D.new()
	var path:String=str(game.layout.movies[movie].get("frontCover","")).replace("./","res://")
	if ResourceLoader.exists(path):mat.albedo_texture=load(path)
	mat.roughness=.65
	poster.material_override=mat

func answer_phone() -> void:
	if state.phase!="open" or state.stock.is_empty():return
	var copies:Array=state.stock.values().filter(func(entry):return not entry.get("sold",false))
	if copies.is_empty():return
	var available:Array=copies.filter(func(entry):return entry.get("shelved",false) and entry.get("returned_scanned",true))
	if not available.is_empty():copies=available
	var title:int=copies[state.rng.randi_range(0,copies.size()-1)].movie
	var account:int=game.clerk.accounts.create_account()
	state.reservations.append({"account":account,"movie":title,"day":state.day+state.rng.randi_range(0,1),"ready":false,"record":-1})
	ledgers[account]={"visits":0,"genre":game.layout.movies[title].get("genre",""),"balance":0}
	game._message("Client %03d : pouvez-vous me réserver « %s » ? Prépare le boîtier dans le présentoir derrière la caisse."%[account,game.layout.movies[title].title])

func sell_copy(id:int) -> bool:
	if not state.stock.has(id):return false
	var entry:Dictionary=state.stock[id]
	var record:Dictionary=game.dvd_records[id]
	if entry.get("sold",false) or record.get("clerk_reserved",true) or not entry.get("returned_scanned",true):
		game._message("L’exemplaire doit être rangé et son retour enregistré avant la revente.")
		return false
	if state.reservations.any(func(reservation):return int(reservation.record)==id):return false
	game.clerk.reserve_exact(record)
	entry.sold=true
	entry.shelved=false
	state.cash+=200
	game._message("Exemplaire revendu : 2.00 $.")
	return true

func reserve_held() -> bool:
	var item:Dictionary=game.clerk.held_service
	return reserve_item(item)

func reserve_item(item:Dictionary) -> bool:
	var record:Dictionary=item.get("record",{})
	if record.is_empty() or not state.stock.has(int(record.id)):return false
	for reservation in state.reservations:
		if reservation.ready or int(reservation.movie)!=int(item.movie):continue
		if not state.stock[int(record.id)].get("returned_scanned",true):
			game._message("Scanne le retour de cet exemplaire avant de le réserver.")
			return true
		reservation.record=int(record.id)
		reservation.ready=true
		record.clerk_reserved=true
		state.stock[int(record.id)].shelved=false
		var node:Node3D=item.node
		node.reparent(self)
		node.global_position=Vector3(2.45+state.reservations.find(reservation)%4*.15,1.14,-7.2)
		node.rotation=Vector3.ZERO
		node.freeze=true
		node.collision_layer=0
		node.collision_mask=0
		game.clerk.cases.erase(item)
		if item==game.clerk.held_service:game.clerk.clear_hand()
		if node.has_meta("guest_held"):node.remove_meta("guest_held")
		node.set_meta("reservation_record",record.id)
		game._message("Réservation prête pour le client %03d."%reservation.account)
		return true
	return false

func cancel_reservation(index:int) -> void:
	if index<0 or index>=state.reservations.size():return
	var reservation:Dictionary=state.reservations[index]
	if reservation.get("ready",false):
		for node in get_children():
			if int(node.get_meta("reservation_record",-1))==int(reservation.record):node.queue_free()
		var record:Dictionary=game.dvd_records[int(reservation.record)]
		var item:Dictionary=game.clerk.new_case(record.movie,Vector3(2.7,1.2,-7.2),"shelve")
		item.record=record
		load("res://clerk_inventory.gd").bind(item.node,record)
		game.clerk.add_lock(item.node)
	state.reservations.remove_at(index)

func update_locator() -> void:
	highlighted.hide()
	if locate_id<0 or locate_id>=game.dvd_records.size():return
	if is_remote_guest():
		var mirror=game.touch_controls.coop_panel.mirror
		if is_instance_valid(mirror):
			for item in mirror.state.get("cases",[]):
				if int(item.get("record",-1))!=locate_id:continue
				var node:Node3D=mirror.nodes.get("cases"+str(item.id))
				if is_instance_valid(node):highlighted.global_transform=node.global_transform;highlighted.show();return
	var record:Dictionary=game.dvd_records[locate_id]
	for item in game.clerk.cases:
		if not item.get("record",{}).is_empty() and int(item.record.id)==locate_id:
			highlighted.global_transform=item.node.global_transform
			highlighted.show()
			return
	if record.get("loose",false) and is_instance_valid(record.get("loose_body")):
		highlighted.global_transform=record.loose_body.global_transform
		highlighted.show()
		return
	for node in get_children():
		if int(node.get_meta("reservation_record",-1))==locate_id:
			highlighted.global_transform=node.global_transform
			highlighted.show()
			return
	if not record.get("clerk_reserved",false):
		highlighted.global_transform=record.world
		highlighted.show()

func snapshot() -> Dictionary:
	freight.store_poses()
	return {"rules":state.snapshot(),"ledgers":ledgers.duplicate(true),"assembly":assembly.duplicate(true)}

func restore(saved:Dictionary) -> void:
	if saved.is_empty():return
	state.restore(saved.get("rules",{}))
	ledgers=saved.get("ledgers",{})
	assembly=saved.get("assembly",{})
	for shelf in state.shelves:add_shelf(shelf)
	for record in game.dvd_records:
		if state.stock.has(int(record.id)):move_record(record)
	for order in state.orders:
		if order.delivered:
			order.delivered=false
			deliver(order)
	decor.sync()
	for index in state.posters.size():place_poster(int(state.posters[index].movie),index)
	if not assembly.is_empty():
		if assembly.get("stage","")=="move":
			var index:int=int(assembly.get("moving_index",-1));assembly={};start_move_shelf(index)
		elif assembly.get("stage","")=="site":
			var id:int=int(assembly.get("order",-1));assembly={}
			if packages.has(id):open_parcel(id)
		else:build_assembly()
	for reservation in state.reservations:
		if reservation.get("ready",false):restore_reservation_visual(reservation)
	update_prices()
	refresh_calendar()
	apply_weather()
	rebuild_navigation()

func restore_reservation_visual(reservation:Dictionary) -> void:
	var id:int=reservation.record
	if id<0 or id>=game.dvd_records.size():return
	var node:=Node3D.new()
	add_child(node)
	load("res://held_case.gd").build(node,game.layout.movies[reservation.movie])
	node.set_meta("antitheft",true)
	game.clerk.add_lock(node)
	node.position=Vector3(2.45+state.reservations.find(reservation)%4*.15,1.14,-7.2)
	node.set_meta("reservation_record",id)

func prepare_recommendation(customer:Dictionary) -> void:
	var pool:Array=[]
	for id in state.stock:
		var entry:Dictionary=state.stock[id]
		var record:Dictionary=game.dvd_records[int(id)]
		if entry.get("shelved",false) and not entry.get("sold",false) and not record.get("clerk_reserved",true) and not record.get("loose",false):pool.append(entry)
	if pool.is_empty():customer.recommendation=false;return
	var entry:Dictionary=pool[state.rng.randi_range(0,pool.size()-1)]
	var id:int=entry.movie
	var movie:Dictionary=game.layout.movies[id]
	customer.request_genre=str(movie.genre)
	customer.request_age="nouveau" if state.is_new(id) else "vieux" if state.rental(movie)==375 else "standard"
	customer.request_review=review_tag(id)
	customer.recommendation_pending=true
	customer.recommendation_text="Un conseil ?\n%s · %s · %s"%[customer.request_genre,customer.request_age,customer.request_review]
	customer.record={}
	customer.reservations=[]
	customer.rental_count=1
	customer.rental_remaining=1
	show_recommendation(customer)

func show_recommendation(customer:Dictionary) -> void:
	if customer.node.has_node("Recommendation"):return
	var label:=Props.label(customer.node,str(customer.get("recommendation_text","")),Vector3(0,2.13,0),.001,25)
	label.name="Recommendation"
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate=Color("ffe0a0")

func review_tag(id:int) -> String:
	var rating:float=state.ratings.get(id,3)
	return "mal noté" if rating<=2 else "acclamé" if rating>=4 else "critique moyenne"

func offer_recommendation(item:Dictionary) -> bool:
	var customer:Dictionary=game.clerk.active
	if not customer.get("recommendation_pending",false) or item.get("record",{}).is_empty():return false
	if not state.stock.has(int(item.record.id)):return false
	var movie:Dictionary=game.layout.movies[item.movie]
	var age:="nouveau" if state.is_new(item.movie) else "vieux" if state.rental(movie)==375 else "standard"
	var matches:=str(movie.genre)==str(customer.request_genre) and age==str(customer.request_age) and review_tag(item.movie)==str(customer.request_review)
	customer.recommendation_met=matches
	customer.recommendation_pending=false
	customer.movie=item.movie
	customer.items.append(item)
	customer.price_titles=[item.movie]
	customer.reservations=[item.record]
	item.kind="rental"
	if customer.node.has_node("Recommendation"):customer.node.get_node("Recommendation").queue_free()
	var ledger:Dictionary=ledgers.get(int(customer.account_id),{})
	ledger.recommendations=int(ledger.get("recommendations",0))+int(matches)
	ledgers[int(customer.account_id)]=ledger
	game._message("Ce conseil correspond à sa demande." if matches else "Il accepte ton choix, mais ce n’est pas ce qu’il cherchait.")
	return true

func index_record(record:Dictionary) -> void:
	var cell:=Vector2i(floori(record.world.origin.x/2),floori(record.world.origin.z/2))
	if not game.dvd_grid.has(cell):game.dvd_grid[cell]=[]
	if not game.dvd_grid[cell].has(record.id):game.dvd_grid[cell].append(record.id)

func take_stock(record:Dictionary) -> void:
	if state.stock.has(int(record.id)):state.stock[int(record.id)].shelved=false

func preview_stock() -> void:
	var old:Transform3D=state.shelves[moving_shelf].pose
	state.shelves[moving_shelf].pose=ghost.transform
	for id in state.stock:
		var entry:Dictionary=state.stock[id]
		if int(entry.shelf)!=moving_shelf or not entry.get("shelved",false):continue
		var record:Dictionary=game.dvd_records[int(id)]
		move_record(record)
		record.group.multimesh.set_instance_transform(record.index,record.local)
		if game.shell and record.shell_index>=0:game.shell.multimesh.set_instance_transform(record.shell_index,game.shell.global_transform.affine_inverse()*record.world)
		game.clerk.locks.update_slot(record)
	state.shelves[moving_shelf].pose=old
	game.refresh_cover_poses()

func contact_screw() -> int:
	if assembly.is_empty() or not is_instance_valid(assembly_node):return -1
	var tip:Vector3=drill.to_global(Vector3(0,.015,-.16))
	var best:=.065;var selected:=-1
	for i in Build.SCREW_COUNT:
		if Build.done(assembly,i):continue
		var gap:float=tip.distance_to(assembly_node.to_global(screw_position(i)))
		if gap<best:best=gap;selected=i
	return selected

