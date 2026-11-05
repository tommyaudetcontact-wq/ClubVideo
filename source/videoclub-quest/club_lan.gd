extends Node

const PORT := 39165
const VERSION := 1
const MAX_PACKET := 32768
var clerk
var server:TCPServer
var client:StreamPeerTCP
var pin := ""
var receive_buffer := ""
var authenticated := false
var last_request := 0
var accept_time := 0
var remote_avatar:Node3D
const PeerPose=preload("res://club_peer_pose.gd")

func host_status()->String:
	if not server:return "Héberge une partie pour relier un téléphone Android sur le même Wi-Fi."
	var addresses:=Array(IP.get_local_addresses()).filter(func(ip):return ip.begins_with("192.168.") or ip.begins_with("10.") or (ip.begins_with("172.") and int(ip.split(".")[1]) in range(16,32)))
	return "Partie locale ouverte\nAdresse du Quest : %s\nCode : %s\n\n%s"%[", ".join(addresses),pin,"Coéquipier connecté." if authenticated else "En attente du téléphone."]

func toggle_host():
	if server:
		disconnect_client()
		server.stop()
		server=null
		return
	var listener:=TCPServer.new()
	if listener.listen(PORT)!=OK:
		clerk.game._message("Impossible d’ouvrir la partie Wi-Fi.")
		return
	server=listener
	pin="%06d"%randi_range(0,999999)

func disconnect_client():
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
		if request.get("pin")!=pin:
			client.put_data((JSON.stringify({"error":"Code incorrect."})+"\n").to_utf8_buffer())
			disconnect_client()
			return
		authenticated=true
		last_request=0
	if request.has("pose"):
		if not is_instance_valid(remote_avatar):
			remote_avatar=PeerPose.new()
			clerk.game.add_child(remote_avatar)
		remote_avatar.receive(request.pose,request)
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
		response["pose"]=PeerPose.pack(clerk.game)
		response["avatar"]=PeerPose.appearance(clerk.game)
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
			return "Le paiement doit être disponible sur le comptoir du Quest."
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
	if total!=clerk.tender-clerk.price:
		return "La monnaie sélectionnée ne correspond pas au montant à rendre."
	for denomination in coins:clerk.till[int(denomination)]-=int(coins[denomination])
	clerk.change=total
	clerk.paid=true
	clerk.refresh_terminal()
	clerk.game._message("Monnaie rendue sur Android. Remets les boîtiers au client.")
	return "Monnaie rendue au client."
