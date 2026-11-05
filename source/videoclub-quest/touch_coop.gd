extends PanelContainer

const PeerPose=preload("res://club_peer_pose.gd")
const Port=39165
var game
var socket:StreamPeerTCP
var address:LineEdit
var pin:LineEdit
var info:Label
var feedback:Label
var join_button:Button
var cash_button:Button
var payout_button:Button
var denominations:GridContainer
var selected:Dictionary={}
var checkout:Dictionary={}
var buffer:=PackedByteArray()
var connected:=false
var timeout:=0.0
var poll_in:=0.0
var pose_in:=0.0
var avatar:Node3D
var saved_customer_physics:=true
var saved_clerk_physics:=true
var shown_inventory:Dictionary={}

func setup(owner_game):
	game=owner_game
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left=-276
	offset_right=276
	offset_top=-263
	offset_bottom=263
	var layout:=VBoxContainer.new()
	layout.add_theme_constant_override("separation",7)
	add_child(layout)
	info=Label.new()
	info.text="Coop Wi-Fi · Poste de caisse"
	info.add_theme_font_size_override("font_size",23)
	layout.add_child(info)
	address=LineEdit.new()
	address.placeholder_text="Adresse IP de l’hôte"
	address.custom_minimum_size.y=44
	layout.add_child(address)
	pin=LineEdit.new()
	pin.placeholder_text="Code à six chiffres"
	pin.max_length=6
	pin.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_NUMBER
	pin.custom_minimum_size.y=44
	layout.add_child(pin)
	join_button=button(layout,"Rejoindre",join_or_leave)
	feedback=Label.new()
	feedback.text="L’hôte ouvre Coop Wi-Fi sur l’ordinateur du magasin."
	feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(feedback)
	cash_button=button(layout,"Encaisser le paiement du client",func():send("cash_deposit"))
	denominations=GridContainer.new()
	denominations.columns=5
	layout.add_child(denominations)
	var actions:=HBoxContainer.new()
	layout.add_child(actions)
	payout_button=button(actions,"Rendre la monnaie",func():send("cash_change"))
	button(actions,"Effacer la sélection",func():selected.clear();refresh())
	button(layout,"Retour au magasin",hide)
	refresh()
	hide()

func button(parent:Container,caption:String,callback:Callable)->Button:
	var control:=Button.new()
	control.text=caption
	control.custom_minimum_size.y=44
	control.add_theme_font_size_override("font_size",18)
	control.pressed.connect(callback)
	parent.add_child(control)
	return control

func join_or_leave():
	if socket:
		reset("Partie quittée.")
		return
	var ip:=address.text.strip_edges()
	if not ip.is_valid_ip_address() or not pin.text.is_valid_int() or pin.text.length()!=6:
		feedback.text="Entre l’adresse et le code affichés par l’hôte."
		return
	socket=StreamPeerTCP.new()
	if socket.connect_to_host(ip,Port)!=OK:
		reset("Connexion impossible.")
		return
	socket.set_no_delay(true)
	timeout=8
	poll_in=0
	pose_in=0
	feedback.text="Connexion à la partie…"
	join_button.text="Annuler"

func reset(message:String):
	if socket:socket.disconnect_from_host()
	socket=null
	if connected:
		game.clerk.set_physics_process(saved_clerk_physics)
		game.clerk.customers.set_physics_process(saved_customer_physics)
		game.clerk.customers.show()
	connected=false
	if is_instance_valid(avatar):avatar.queue_free()
	avatar=null
	buffer.clear()
	checkout.clear()
	selected.clear()
	shown_inventory.clear()
	feedback.text=message
	join_button.text="Rejoindre"
	refresh()

func _process(delta:float):
	if not socket:return
	socket.poll()
	timeout-=delta
	if socket.get_status() in [StreamPeerTCP.STATUS_NONE,StreamPeerTCP.STATUS_ERROR] or timeout<=0:
		reset("Partie inaccessible. Vérifie le Wi-Fi et la version du jeu chez l’hôte.")
		return
	if socket.get_status()!=StreamPeerTCP.STATUS_CONNECTED:return
	poll_in-=delta
	pose_in-=delta
	if poll_in<=0:
		send("")
		poll_in=.45
	if connected and pose_in<=0:
		send("pose")
		pose_in=.075
	var available:=socket.get_available_bytes()
	if available<=0:return
	if available+buffer.size()>65536:
		reset("Réponse de la partie trop volumineuse.")
		return
	var packet:=socket.get_partial_data(available)
	if packet[0]!=OK:return
	buffer.append_array(packet[1])
	var end:=buffer.find(10)
	while end>=0 and socket:
		var reply:Variant=JSON.parse_string(buffer.slice(0,end).get_string_from_utf8())
		buffer=buffer.slice(end+1)
		if reply is Dictionary:receive(reply)
		end=buffer.find(10)

func receive(reply:Dictionary):
	if reply.has("error"):
		reset(str(reply.error))
		return
	if reply.get("v")!=1:return
	if reply.get("checkout") is Dictionary:
		if not connected:
			connected=true
			join_button.text="Quitter la partie"
			feedback.text="Connecté au magasin de l’hôte."
			saved_clerk_physics=game.clerk.is_physics_processing()
			saved_customer_physics=game.clerk.customers.is_physics_processing()
			game.clerk.set_physics_process(false)
			game.clerk.customers.set_physics_process(false)
			game.clerk.customers.hide()
		if checkout.get("customer",-2)!=reply.checkout.get("customer",-1) or reply.checkout.get("paid",false):
			selected.clear()
		checkout=reply.checkout
		if not str(reply.get("notice","")).is_empty():feedback.text=reply.notice
		refresh()
	elif not connected and reply.has("pages"):
		reset("L’hôte doit recevoir la mise à jour coop pour le poste Android.")
		return
	if not connected:return
	timeout=6
	if reply.has("pose"):
		if not is_instance_valid(avatar):
			avatar=PeerPose.new()
			game.add_child(avatar)
		avatar.receive(reply.pose,reply.get("avatar",{}))

func send(action:String):
	if not socket or socket.get_status()!=StreamPeerTCP.STATUS_CONNECTED:return
	var message:={"v":1,"pin":pin.text,"features":["checkout"],"action":action,"customer":checkout.get("customer",-1),"coins":selected,"pose":PeerPose.pack(game)}
	message.merge(PeerPose.appearance(game))
	socket.put_data((JSON.stringify(message)+"\n").to_utf8_buffer())

func choose(value:String):
	var count:=int(selected.get(value,0))
	if count<int(checkout.get("till",{}).get(value,0)):
		selected[value]=count+1
	refresh()

func refresh():
	var has_customer:bool=int(checkout.get("customer",-1))>=0
	var paid:bool=checkout.get("paid",false)
	cash_button.visible=connected and has_customer
	cash_button.disabled=not checkout.get("cash_visible",false) or checkout.get("received",false)
	denominations.visible=connected and has_customer and checkout.get("received",false) and not paid
	payout_button.visible=denominations.visible
	var inventory:Dictionary=checkout.get("till",{})
	if inventory!=shown_inventory:
		shown_inventory=inventory.duplicate()
		for child in denominations.get_children():
			denominations.remove_child(child)
			child.queue_free()
		var values:=inventory.keys()
		values.sort_custom(func(a,b):return int(a)<int(b))
		for value in values:button(denominations,"",choose.bind(str(value)))
	var values:=inventory.keys()
	values.sort_custom(func(a,b):return int(a)<int(b))
	var total:=0
	for index in range(values.size()):
		var key:String=values[index]
		var count:=int(selected.get(key,0))
		total+=int(key)*count
		var coin:Button=denominations.get_child(index)
		coin.text="%.2f $ ×%d"%[int(key)/100.0,count]
		coin.disabled=count>=int(inventory[key])
	if not connected:
		info.text="Coop Wi-Fi · Poste de caisse"
	elif not has_customer:
		info.text="Caisse partagée · En attente d’un client"
	elif paid:
		info.text="Paiement réglé · L’hôte peut remettre les boîtiers"
	else:
		info.text="Total %.2f $ · Donné %.2f $ · Main %.2f $"%[int(checkout.price)/100.0,int(checkout.tender)/100.0,total/100.0]
	payout_button.disabled=total!=int(checkout.get("tender",0))-int(checkout.get("price",0))
