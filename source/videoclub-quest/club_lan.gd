extends Node

const PORT := 39165
const VERSION := 1
const MAX_PACKET := 32768
var clerk
var server:TCPServer
var client:StreamPeerTCP
var pin := ""
var permits:Dictionary={}
const WorldSync=preload("res://club_world_sync.gd")
var receive_buffer := ""
var authenticated := false
var last_request := 0
var accept_time := 0
var remote_avatar:Node3D
var guest_case:Dictionary={}
var guest_flipped:=false
var guest_inspection:Node3D
var guest_disc_back:=false
const PeerPose=preload("res://club_peer_pose.gd")

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS

func host_status()->String:
	if not server:return "Active la coop pour apparaître dans la liste des joueurs."
	return "Partie visible sur le Wi-Fi. Tu peux fermer cet écran et jouer.\n\n%s"%("Coéquipier connecté." if authenticated else "En attente d’un joueur.")

func toggle_host():
	if server:
		disconnect_client()
		server.stop()
		server=null
		permits.clear()
		return
	var listener:=TCPServer.new()
	if listener.listen(PORT)!=OK:
		clerk.game._message("Impossible d’ouvrir la partie Wi-Fi.")
		return
	server=listener
	pin="%06d"%randi_range(0,999999)

func permit(ip:String)->String:
	if not server or authenticated:return ""
	for token in permits.keys():
		if int(permits[token].expires)<Time.get_ticks_msec():permits.erase(token)
	var token:=Crypto.new().generate_random_bytes(12).hex_encode()
	permits[token]={"ip":ip,"expires":Time.get_ticks_msec()+15000}
	return token

func disconnect_client():
	if is_instance_valid(guest_inspection) and is_instance_valid(guest_inspection.carried):
		var drop:=Vector3(1.6,.93,-8.7)
		clerk.repairs.place_disc(guest_inspection,drop)
	drop_guest_case()
	if client:client.disconnect_from_host()
	client=null
	authenticated=false
	receive_buffer=""
	if is_instance_valid(remote_avatar):remote_avatar.queue_free()
	remote_avatar=null

func _process(_delta:float):
	if not server:return
	if not client and server.is_connection_available():
		client=server.take_connection()
		accept_time=Time.get_ticks_msec()
		client.set_no_delay(true)
	if not client:return
	client.poll()
	if client.get_status()!=StreamPeerTCP.STATUS_CONNECTED or (not authenticated and Time.get_ticks_msec()-accept_time>5000):
		disconnect_client()
		return
	var available:=client.get_available_bytes()
	if available<=0:return
	if available+receive_buffer.length()>MAX_PACKET:
		disconnect_client()
		return
	var packet:=client.get_partial_data(available)
	if packet[0]!=OK:
		disconnect_client()
		return
	receive_buffer+=packet[1].get_string_from_utf8()
	while "\n" in receive_buffer and client:
		var end:=receive_buffer.find("\n")
		var line:=receive_buffer.left(end)
		receive_buffer=receive_buffer.substr(end+1)
		handle_request(JSON.parse_string(line))

func handle_request(request:Variant):
	if not request is Dictionary or request.get("v")!=VERSION:
		disconnect_client()
		return
	if not authenticated:
		var token:=str(request.get("grant",""))
		var access:Dictionary=permits.get(token,{})
		var valid:bool=not access.is_empty() and access.ip==client.get_connected_host() and int(access.expires)>=Time.get_ticks_msec()
		if not valid and request.get("pin")!=pin:
			send_response({"error":"La demande de connexion a expiré."})
			disconnect_client()
			return
		permits.erase(token)
		ensure_guest_inspection()
		authenticated=true
		last_request=0
	if request.has("pose"):
		if not is_instance_valid(remote_avatar):
			remote_avatar=PeerPose.new()
			clerk.game.add_child(remote_avatar)
		remote_avatar.receive(request.pose,request)
		update_guest_case_pose()
		if request.get("action")=="pose":
			send_response({"v":VERSION,"pose":PeerPose.pack(clerk.game),"avatar":PeerPose.appearance(clerk.game)})
			return
	var now:=Time.get_ticks_msec()
	if now-last_request<90 and request.get("action","").is_empty():return
	last_request=now
	var old_page:int=clerk.page
	var receipt:=""
	var action:=str(request.get("action",""))
	match action:
		"case_pick","shelf_pick":
			receipt=pick_guest_case(action,str(request.get("case","")))
		"case_drop":
			drop_guest_case()
		"held_basket":
			receipt=store_guest_case()
		"case_flip":
			if not guest_case.is_empty() and not guest_inspection.opened:
				guest_flipped=not guest_flipped
				update_guest_case_pose()
		"case_open","disc_use","disc_flip","case_scan","case_lock","case_handoff","case_sort","case_rack","phone","door","day":
			receipt=guest_action(action,request)
		"case_basket","case_shelf":
			receipt=assist_case(action,str(request.get("case","")))
		"cash_deposit","cash_change":
			if clerk.active.is_empty() or int(request.get("customer",-2))!=int(clerk.active.get("id",-1)):
				receipt="Le client a changé. Vérifie la caisse."
			else:
				receipt=remote_cash(action,request.get("coins",{}))
		"drawer":
			if not clerk.active.is_empty() and not clerk.active.get("is_return",false):
				clerk.page=0
				clerk.action("computer",-1)
		"return":
			if clerk.active.get("is_return",false) and clerk.paid and clerk.scanned:
				clerk.page=2
				clerk.action("computer",-1)
	clerk.page=old_page
	var content:Array[String]=[]
	for tab in range(4):
		content.append(clerk.terminal_content(tab))
	var response={"v":VERSION,"pages":content,"client":not clerk.active.is_empty(),"can_return":clerk.active.get("is_return",false) and clerk.paid and clerk.scanned,"day":clerk.shift.day}
	var features:Variant=request.get("features",[])
	if features is Array and "checkout" in features:
		var inventory:Dictionary={}
		for denomination in clerk.till:
			inventory[str(denomination)]=clerk.till[denomination]
		response["checkout"]={"customer":clerk.active.get("id",-1),"price":clerk.price,"tender":clerk.tender,"received":clerk.tender_received,"paid":clerk.paid,"cash_visible":clerk.tender_note.visible,"till":inventory}
		response["notice"]=receipt
		response["guest_case"]=str(guest_case.node.get_instance_id()) if not guest_case.is_empty() else ""
		if not guest_case.is_empty() and not guest_case.record.is_empty():
			var slot:Vector3=guest_case.record.world.origin
			response["guest_shelf"]=[slot.x,slot.y,slot.z]
		response["guest_flipped"]=guest_flipped
		response["guest_open"]=is_instance_valid(guest_inspection) and guest_inspection.opened
		response["guest_disc"]=str(guest_inspection.carried.get_instance_id()) if is_instance_valid(guest_inspection) and is_instance_valid(guest_inspection.carried) else ""
		response["guest_disc_back"]=guest_disc_back
		if not clerk.active.is_empty():
			var p:Vector3=clerk.customer_hand()
			response["customer_pos"]=[p.x,p.y,p.z]
		response["pose"]=PeerPose.pack(clerk.game)
		response["avatar"]=PeerPose.appearance(clerk.game)
	if features is Array and "world_sync" in features:
		response["world"]=WorldSync.capture(clerk.game)
	send_response(response)

func send_response(response:Dictionary):
	client.put_data((JSON.stringify(response)+"\n").to_utf8_buffer())

func remote_cash(action:String,coins:Variant)->String:
	if action=="cash_deposit":
		if clerk.tender_received:return "Paiement déjà encaissé."
		var remaining:int=clerk.tender-clerk.tender_deposited
		var visible_total:=0
		for value in clerk.tender_parts:visible_total+=int(value)
		if remaining<=0 or visible_total!=remaining or not clerk.tender_note.visible:
			return "Le paiement doit être disponible sur le comptoir de l’hôte."
		for value in clerk.tender_parts:clerk.till[value]+=1
		clerk.tender_parts.clear()
		clerk.active.cash_started=true
		clerk.tender_deposited=clerk.tender
		clerk.tender_received=true
		clerk.paid=clerk.tender==clerk.price
		clerk.refresh_tender_visual()
		clerk.refresh_terminal()
		clerk.game._message("Paiement encaissé sur Android.")
		return "Paiement encaissé."
	if not clerk.tender_received or clerk.paid or not coins is Dictionary:
		return "Encaisse d’abord le paiement du client."
	var total:=0
	for denomination in coins:
		var requested:Variant=coins[denomination]
		if not str(denomination).is_valid_int() or not (requested is int or requested is float):
			return "Sélection de monnaie invalide."
		if not is_finite(float(requested)) or requested<0 or requested>1000 or floorf(requested)!=requested:
			return "Sélection de monnaie invalide."
		var value:=int(denomination)
		var count:=int(requested)
		if count<0 or count>int(clerk.till.get(value,0)) or not clerk.till.has(value):
			return "Une pièce n’est plus disponible dans le tiroir."
		total+=value*count
	for denomination in coins:clerk.till[int(denomination)]-=int(coins[denomination])
	clerk.change+=total
	clerk.paid=true
	clerk.refresh_terminal()
	clerk.game._message("Monnaie rendue sur Android. Remets les boîtiers au client.")
	return "Monnaie rendue au client."


func assist_case(action:String,id:String)->String:
	if not is_instance_valid(remote_avatar) or not remote_avatar.valid_pose:return "Attends la synchronisation de ta position."
	var guest:Vector3=remote_avatar.targets[0].origin
	for item in clerk.cases.duplicate():
		var node:Node3D=item.node
		if str(node.get_instance_id())!=id:continue
		if node==clerk.game.held or item==clerk.secondary or node.get_meta("customer_animating",false) or node.get_meta("guest_held",false):
			return "Ce boîtier est déjà manipulé par l’hôte."
		if node.global_position.distance_to(guest)>2.0:return "Approche-toi du boîtier."
		if action=="case_basket":
			var basket:RigidBody3D=clerk.basket.body
			if item in clerk.basket.items:return "Ce boîtier est déjà dans le panier."
			if basket.global_position.distance_to(guest)>2.0:return "Approche-toi du panier."
			if clerk.basket.items.size()>=clerk.basket.CAPACITY:return "Le panier est plein."
			node.global_position=basket.to_global(Vector3(0,.16,0))
			if clerk.basket.store(item):
				clerk.refresh_terminal()
				return "Boîtier ajouté au panier."
		else:
			var record:Dictionary=item.get("record",{})
			if record.is_empty() or item.kind not in ["return","shelve","sorting"]:return "Ce boîtier n’est pas à ranger."
			if record.world.origin.distance_to(guest)>1.7:return "Approche-toi de son emplacement en rayon."
			if clerk.active.get("is_return",false) and item in clerk.active.items:return "Termine le retour au comptoir."
			if node.get_meta("disc_movie",-1)!=item.movie or node.get_meta("dirty",false):return "Le disque doit être vérifié ou réparé."
			if not node.get_meta("antitheft",false):return "Pose l’antivol avant le rangement."
			if item.kind=="return" and not item.scanned:return "Scanne le retour avant de le ranger."
			clerk.basket.items.erase(item)
			clerk.basket.arrange()
			clerk.restore_stock(record)
			if item.kind=="return":clerk.shift.restocked+=1
			clerk.tasks.erase(item.get("task",""))
			clerk.cases.erase(item)
			node.queue_free()
			clerk.refresh_terminal()
			return "Boîtier remis en rayon."
	return "Ce boîtier n’est plus disponible."

func ensure_guest_inspection():
	if not is_instance_valid(guest_inspection):
		guest_inspection=load("res://clerk_inspection.gd").new()
		add_child(guest_inspection)
		guest_inspection.setup(clerk.game)
		guest_inspection.loose_discs=clerk.inspection.loose_discs
		guest_inspection.set_physics_process(false)

func pick_guest_case(action:String,id:String)->String:
	if not guest_case.is_empty():return "Dépose d’abord le boîtier que tu tiens."
	if not is_instance_valid(remote_avatar) or not remote_avatar.valid_pose:return "Attends la synchronisation de ta position."
	var guest:Vector3=remote_avatar.targets[0].origin
	if action=="case_pick":
		for item in clerk.cases:
			var node:Node3D=item.node
			if str(node.get_instance_id())!=id:continue
			if node==clerk.game.held or item==clerk.secondary or node.get_meta("customer_animating",false):break
			if guest.distance_to(node.global_position)>2.2:return "Approche-toi du boîtier."
			guest_case=item
			break
	else:
		for record in clerk.game.dvd_records:
			if WorldSync.shelf_key(clerk.game,record)!=id:continue
			if record.get("clerk_reserved",false) or record.get("loose",false) or record==clerk.game.held_record:break
			if guest.distance_to(record.world.origin)>2.2:return "Approche-toi du rayon."
			clerk.reserve_exact(record)
			guest_case=clerk.new_case(record.movie,record.world.origin,"shelve")
			guest_case.record=record
			load("res://clerk_inventory.gd").bind(guest_case.node,record)
			break
	if guest_case.is_empty():return "Ce boîtier est déjà pris ou indisponible."
	var node:RigidBody3D=guest_case.node
	clerk.basket.items.erase(guest_case)
	clerk.basket.arrange()
	if node.get_parent()!=clerk:node.reparent(clerk)
	for key in ["in_basket","in_sort_tray"]:node.set_meta(key,false)
	node.set_meta("sort_slot",-1)
	node.set_meta("guest_held",true)
	node.freeze=true
	node.collision_layer=0
	node.collision_mask=0
	guest_flipped=false
	clerk.shift.started=true
	update_guest_case_pose()
	return ""

static func held_pose(head_pose:Transform3D,flipped:bool)->Transform3D:
	return head_pose*Transform3D(Basis(Vector3.UP,PI if flipped else 0.0),Vector3(.105,-.105,-.50))

func update_guest_case_pose():
	if not is_instance_valid(remote_avatar) or not remote_avatar.valid_pose:return
	var head_pose:Transform3D=remote_avatar.targets[0]
	if not guest_case.is_empty() and is_instance_valid(guest_case.node):
		guest_case.node.global_transform=held_pose(head_pose,guest_flipped)
	if is_instance_valid(guest_inspection) and is_instance_valid(guest_inspection.carried):
		var disc:MeshInstance3D=guest_inspection.carried
		disc.global_transform=disc_pose(head_pose,guest_disc_back)
		if clerk.game.layout.movies[guest_inspection.carried_data.movie].get("console","")=="GameCube":disc.scale=Vector3(.667,.667,1)

static func disc_pose(head_pose:Transform3D,back:bool)->Transform3D:
	return head_pose*Transform3D(Basis(Vector3.UP,PI if back else 0.0),Vector3(-.19,-.10,-.41))

func drop_guest_case():
	if guest_case.is_empty():return
	var item:=guest_case
	if guest_inspection.opened:guest_inspection.close_case()
	guest_case={}
	guest_flipped=false
	var node:RigidBody3D=item.node
	if not is_instance_valid(node):return
	node.remove_meta("guest_held")
	var record:Dictionary=item.record
	if item.kind=="shelve" and not record.is_empty() and node.global_position.distance_to(record.world.origin)<.75:
		clerk.restore_stock(record)
		clerk.cases.erase(item)
		node.queue_free()
		return
	node.freeze=false
	node.collision_layer=8
	node.collision_mask=1|8
	node.linear_velocity=Vector3.ZERO
	node.sleeping=false

func store_guest_case()->String:
	if guest_case.is_empty() or guest_inspection.opened:return ""
	var basket:RigidBody3D=clerk.basket.body
	if basket.global_position.distance_to(remote_avatar.targets[0].origin)>2.0:return "Approche-toi du panier."
	if clerk.basket.items.size()>=clerk.basket.CAPACITY:return "Le panier est plein."
	var item:=guest_case
	item.node.global_position=basket.to_global(Vector3(0,.16,0))
	if not clerk.basket.store(item):return "Approche le boîtier du panier."
	item.node.remove_meta("guest_held")
	guest_case={}
	guest_flipped=false
	clerk.refresh_terminal()
	return "Boîtier ajouté au panier."

func guest_action(action:String,request:Dictionary)->String:
	if not is_instance_valid(remote_avatar) or not remote_avatar.valid_pose:return ""
	var p:Vector3=remote_avatar.targets[0].origin
	if action=="day":
		if p.distance_to(clerk.screen.global_position)>2.0:return "Approche-toi de l’ordinateur."
		if clerk.shift.summary:clerk.shift.next_day()
		else:clerk.shift.finish()
		clerk.refresh_terminal()
		return ""
	if action in ["phone","door"]:
		for target in clerk.targets:
			if target.action!=action or p.distance_to(target.node.global_position)>1.8:continue
			if action=="phone":
				if not clerk.ringing:return ""
				clerk.ringing=false
				clerk.phone_audio.stop()
				clerk.reminders.append("Rappeler Julie : disponibilité de Shrek.")
				clerk.refresh_terminal()
			else:clerk.action("door",-1)
			break
		return ""
	if not is_instance_valid(guest_inspection):return ""
	if action=="disc_flip" and is_instance_valid(guest_inspection.carried):
		guest_disc_back=not guest_disc_back
		guest_inspection.carried_data.inspected=true
		update_guest_case_pose()
		return ""
	if action=="disc_use":return use_guest_disc(p,str(request.get("target","")))
	if guest_case.is_empty():return ""
	var node:Node3D=guest_case.node
	if action=="case_open":
		if guest_inspection.opened:
			if is_instance_valid(guest_inspection.carried):return "Remets le disque ou pose-le avant de fermer."
			guest_inspection.close_case()
		elif node.get_meta("antitheft",false):
			return "Retire d’abord l’antivol."
		else:
			guest_flipped=false
			guest_inspection.open_case(node)
			guest_inspection.finish_lid(true)
		return ""
	if guest_inspection.opened and action!="case_sort":return "Referme d’abord le boîtier."
	match action:
		"case_scan":
			if p.distance_to(clerk.scanner.global_position)>1.8:return "Approche-toi du scanner."
			if clerk.scan_item(guest_case):
				clerk.scanner.sound.play()
				return "Boîtier scanné."
		"case_lock":
			var target:=str(request.get("target",""))
			if target=="unlock" and not node.get_meta("antitheft",false):return "L’antivol est déjà retiré."
			if target=="relock" and node.get_meta("antitheft",false):return "L’antivol est déjà posé."
			if node.get_meta("antitheft",false):
				if p.distance_to(Vector3(.72,1.17,-6.18))>1.8:return "Approche-toi du détacheur."
				clerk.locks.set_locked(node,false)
				clerk.locks.put_in_bin(clerk.locks.create_bar())
			else:
				if p.distance_to(clerk.lock_bin)>1.8:return "Approche-toi des barres jaunes."
				clerk.locks.ensure_spare()
				for bar in clerk.locks.bars:
					if not bar.get_meta("in_bin",false):continue
					clerk.locks.bars.erase(bar)
					bar.queue_free()
					clerk.locks.set_locked(node,true)
					break
			clerk.refresh_terminal()
		"case_handoff":
			if clerk.active.is_empty() or int(request.get("customer",-2))!=int(clerk.active.get("id",-1)):return ""
			if p.distance_to(clerk.customer_hand())>1.8:return "Approche-toi du client."
			if clerk.handoff_item(guest_case):
				guest_case={}
				guest_flipped=false
				return "Boîtier remis au client."
		"case_sort":
			var tray:=Vector3(1.75,1.19,-5.92)
			if p.distance_to(tray)>1.8:return "Approche-toi du bac À démêler."
			if guest_inspection.opened:guest_inspection.close_case()
			if clerk.has_identified_mismatch(node,guest_case.movie):clerk.flag_wrong_case(guest_case)
			node.remove_meta("guest_held")
			clerk.store_sort_tray(guest_case,false)
			guest_case={}
		"case_rack":
			node.remove_meta("guest_held")
			var result:String=assist_case("case_shelf",str(node.get_instance_id()))
			if node.is_queued_for_deletion():guest_case={}
			else:node.set_meta("guest_held",true)
			return result
	return ""

func use_guest_disc(p:Vector3,target:String)->String:
	var repairs=clerk.repairs
	if target=="repair" and p.distance_to(repairs.station)<1.8:
		if is_instance_valid(guest_inspection.carried):
			if is_instance_valid(repairs.disc):return "La surfaceuse est occupée."
			guest_inspection.carried.global_position=repairs.station
			repairs.insert_disc(guest_inspection)
		else:repairs.take_disc(guest_inspection,0,repairs.station)
	elif is_instance_valid(guest_inspection.carried):
		if target=="table" and p.distance_to(Vector3(2.1,.93,-8.7))<1.9:
			repairs.place_disc(guest_inspection,Vector3(clampf(p.x,1.25,3.0),.93,-8.7))
		elif target.is_empty() and not guest_inspection.put_carried_in_case():return "Ouvre un boîtier vide pour y remettre le disque."
	elif target.is_empty():
		guest_inspection.take_open_disc(0)
	else:
		for loose in clerk.inspection.loose_discs:
			if str(loose.node.get_instance_id())!=target or p.distance_to(loose.node.global_position)>1.8:continue
			guest_inspection.take_loose_disc(loose,0)
			break
	guest_disc_back=false
	update_guest_case_pose()
	return ""
