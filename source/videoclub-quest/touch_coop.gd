extends PanelContainer

const PeerPose=preload("res://club_peer_pose.gd")
const Port=39165
var game
var guest_case_id:=""
var guest_flipped:=false
var guest_open:=false
var basket_carried:=false
var spare_carried:=false
var guest_disc:=""
var guest_disc_back:=false
var customer_pos:=Vector3.INF
var guest_shelf:=Vector3.INF
var guest_shelf_key:=""
var cash_ids:Array=[]
var world_in_flight:=false
var world_sent_at:=0
var moving_case:=false
var case_animation_pose:=Transform3D.IDENTITY
var pickup_from:=Vector3.INF
const LAN=preload("res://club_lan.gd")
var socket:StreamPeerTCP
var players:VBoxContainer
var grant:=""
var mirror:Node3D
var pages:Array=[]
var info:Label
var feedback:Label
var join_button:Button
var host_button:Button
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
var selected_case:=""
var case_controls:HBoxContainer
var case_info:Label

func setup(owner_game):
	game=owner_game
	theme=preload("res://club_messenger_theme.gd").build()
	process_mode=Node.PROCESS_MODE_ALWAYS
	var frame:=StyleBoxFlat.new()
	frame.bg_color=Color("d9edfc")
	frame.border_color=Color("3679bc")
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(9)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		frame.set_content_margin(side,14)
	add_theme_stylebox_override("panel",frame)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left=-276
	offset_right=276
	offset_top=-263
	offset_bottom=263
	var layout:=VBoxContainer.new()
	layout.add_theme_constant_override("separation",7)
	add_child(layout)
	info=Label.new()
	info.text="●  Vidéo Club Messenger · Wi-Fi"
	info.add_theme_color_override("font_color",Color("123968"))
	info.add_theme_font_size_override("font_size",23)
	layout.add_child(info)
	var discovery:=ScrollContainer.new()
	discovery.custom_minimum_size.y=142
	discovery.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(discovery)
	players=VBoxContainer.new()
	players.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	discovery.add_child(players)
	join_button=button(layout,"Activer la coop",join_or_leave)
	host_button=button(layout,"Héberger ma partie",game.lobby.toggle_mobile_host)
	game.lobby.changed.connect(refresh_players)
	game.lobby.join_granted.connect(connect_host)
	feedback=Label.new()
	feedback.text="Active la coop sur les deux appareils, sur le même Wi-Fi."
	feedback.add_theme_color_override("font_color",Color("123968"))
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
	case_info=Label.new()
	case_info.add_theme_color_override("font_color",Color("123968"))
	layout.add_child(case_info)
	case_controls=HBoxContainer.new()
	layout.add_child(case_controls)
	button(case_controls,"Mettre au panier",func():send("case_basket"))
	button(case_controls,"Ranger en rayon",func():send("case_shelf"))
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

func open_lobby():
	refresh_players()
	show()

func refresh_players():
	for child in players.get_children():
		players.remove_child(child)
		child.queue_free()
	host_button.visible=game.lobby.available and not socket
	if socket:return
	var hosting:bool=game.clerk.lan.server!=null
	host_button.text="Arrêter d’héberger" if hosting else "Héberger ma partie"
	join_button.text="Désactiver la coop" if game.lobby.available else "Activer la coop"
	if not game.lobby.available:
		var intro:=Label.new()
		intro.add_theme_color_override("font_color",Color("123968"))
		intro.text="Active la coop pour rechercher les parties sur le Wi-Fi."
		players.add_child(intro)
		return
	if not game.lobby.incoming.is_empty():
		button(players,"Accepter l’invitation",func():game.lobby.reply(true))
		button(players,"Refuser",func():game.lobby.reply(false))
	var listing:Array=game.lobby.list_players()
	for index in range(listing.size()):
		var player:Dictionary=listing[index]
		var row:=index
		if player.hosting and not hosting:
			button(players,"Rejoindre "+player.name,func():game.lobby.request(row,false))
		elif hosting and not player.hosting:
			button(players,"Inviter "+player.name,func():game.lobby.request(row,true))
		else:
			var peer_label:=Label.new()
			peer_label.add_theme_color_override("font_color",Color("123968"))
			peer_label.text="●  "+player.name+(" · Héberge une partie" if player.hosting else " · Disponible")
			players.add_child(peer_label)
	if players.get_child_count()==0:
		var empty:=Label.new()
		empty.add_theme_color_override("font_color",Color("123968"))
		empty.text="Partie visible sur le Wi-Fi. Tu peux retourner jouer." if hosting else "Recherche de joueurs sur le Wi-Fi…"
		players.add_child(empty)

func join_or_leave():
	if socket:
		reset("Partie quittée.")
		return
	game.lobby.toggle_available()

func connect_host(ip:String,access:String):
	if socket or game.clerk.lan.server:return
	if game.held or game.touch_controls.basket_carried or game.clerk.wallet.occupied(0) or game.clerk.wallet.occupied(1):
		feedback.text="Dépose le boîtier et le panier avant de rejoindre."
		return
	grant=access
	socket=StreamPeerTCP.new()
	if socket.connect_to_host(ip,Port)!=OK:
		reset("Connexion impossible.")
		return
	socket.set_no_delay(true)
	timeout=8
	poll_in=0
	pose_in=0
	feedback.text="Connexion à la partie…"
	refresh_players()
	join_button.text="Annuler"

func reset(message:String):
	if socket:socket.disconnect_from_host()
	socket=null
	if connected:
		game.clerk.set_physics_process(saved_clerk_physics)
		game.clerk.customers.set_physics_process(saved_customer_physics)
		game.clerk.customers.show()
		if is_instance_valid(mirror):mirror.restore_local()
		mirror=null
	if connected:clear_cash_visuals()
	connected=false
	world_in_flight=false
	guest_case_id=""
	guest_flipped=false
	guest_open=false
	basket_carried=false
	spare_carried=false
	guest_disc=""
	customer_pos=Vector3.INF
	guest_shelf=Vector3.INF
	guest_shelf_key=""
	moving_case=false
	game.clerk.repairs.marker.hide()
	game.interaction_glow(0).hide()
	pages.clear()
	selected_case=""
	if is_instance_valid(avatar):avatar.queue_free()
	avatar=null
	buffer.clear()
	checkout.clear()
	selected.clear()
	shown_inventory.clear()
	feedback.text=message
	refresh_players()
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
	if poll_in<=0 and (not world_in_flight or Time.get_ticks_msec()-world_sent_at>1000):
		send("")
		poll_in=.10
	if connected and pose_in<=0:
		send("pose")
		pose_in=.05
	var available:=socket.get_available_bytes()
	if available<=0:return
	if available+buffer.size()>524288:
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
		world_in_flight=false
		if not connected:
			if not reply.get("world") is String:
				reset("Cette partie requiert la mise à jour de la coop.")
				return
			connected=true
			hide()
			join_button.text="Quitter la partie"
			feedback.text="Connecté au magasin de l’hôte."
			saved_clerk_physics=game.clerk.is_physics_processing()
			saved_customer_physics=game.clerk.customers.is_physics_processing()
			game.clerk.set_physics_process(false)
			game.clerk.customers.set_physics_process(false)
			game.clerk.customers.hide()
			mirror=preload("res://club_world_sync.gd").new()
			game.add_child(mirror)
			mirror.setup(game)
		if reply.get("world") is String and is_instance_valid(mirror):mirror.apply(reply.world)
		if reply.get("pages") is Array:
			pages=reply.pages
			game.clerk.desktop.refresh()
		if checkout.get("customer",-2)!=reply.checkout.get("customer",-1) or reply.checkout.get("paid",false):
			selected.clear()
		checkout=reply.checkout
		sync_cash(reply.get("guest_cash",[]))
		var previous_case:=guest_case_id
		guest_case_id=str(reply.get("guest_case",""))
		if previous_case.is_empty() and not guest_case_id.is_empty() and pickup_from.is_finite():
			game.touch_controls.animate_coop_pickup(pickup_from)
			pickup_from=Vector3.INF
		elif reply.get("action","") in ["case_pick","shelf_pick"]:pickup_from=Vector3.INF
		guest_flipped=bool(reply.get("guest_flipped",false))
		guest_open=bool(reply.get("guest_open",false))
		basket_carried=bool(reply.get("guest_basket",false))
		spare_carried=bool(reply.get("guest_spare",false))
		guest_disc=str(reply.get("guest_disc",""))
		guest_disc_back=bool(reply.get("guest_disc_back",false))
		customer_pos=decode_position(reply.get("customer_pos"))
		guest_shelf=decode_position(reply.get("guest_shelf"))
		guest_shelf_key=str(reply.get("guest_shelf_key",""))
		if not str(reply.get("notice","")).is_empty():
			feedback.text=reply.notice
			game._message(reply.notice)
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

func clear_cash_visuals():
	for entry in game.clerk.wallet.palms[0]:entry.node.queue_free()
	game.clerk.wallet.palms[0].clear()
	game.clerk.wallet.arrange(0)
	cash_ids.clear()

func sync_cash(entries:Array):
	var ids:Array=entries.map(func(entry):return str(entry.id))
	if ids==cash_ids:return
	clear_cash_visuals()
	for entry in entries:
		var node:Node3D=game.clerk.make_money(int(entry.value))
		node.set_meta("remote_cash_id",str(entry.id))
		game.clerk.wallet.roots[0].add_child(node)
		game.clerk.wallet.palms[0].append({"node":node,"value":int(entry.value),"tender":bool(entry.tender),"customer_id":int(entry.customer_id)})
	cash_ids=ids
	game.clerk.wallet.arrange(0)

func update_shelf_marker(enabled:bool):
	var marker:MeshInstance3D=game.clerk.repairs.marker
	marker.hide()
	if not enabled or guest_case_id.is_empty() or guest_open or not is_instance_valid(mirror):return
	var row:Array=mirror.state.get("stock",{}).get(guest_shelf_key,[])
	if row.size()<5 or not row[4] is Transform3D:return
	marker.global_transform=row[4]
	marker.show()

func decode_position(position:Variant)->Vector3:
	if not position is Array or position.size()!=3:return Vector3.INF
	return Vector3(float(position[0]),float(position[1]),float(position[2]))

func toggle_guest_case():
	if guest_case_id.is_empty() or not guest_disc.is_empty() or not is_instance_valid(mirror):return
	var node:Node3D=mirror.nodes.get("cases"+guest_case_id)
	if is_instance_valid(node):
		var can_preview:=guest_open or node.get_node_or_null("Antitheft")==null
		if can_preview:mirror.set_case_open(node,not guest_open)
	send("case_open")

func guest_held_pose()->Transform3D:
	return LAN.held_pose(game.head.global_transform,guest_flipped)

func _physics_process(_delta:float):
	if not is_instance_valid(mirror):return
	if basket_carried:game.clerk.basket.body.global_transform=game.head.global_transform*Transform3D(Basis(Vector3.UP,.10),Vector3(-.35,-.43,-.77))
	var node:Node3D=mirror.nodes.get("cases"+guest_case_id)
	if is_instance_valid(node):
		node.global_transform=case_animation_pose if moving_case else guest_held_pose()
		game.hands[game.touch_controls.CASE_HAND].global_transform=node.global_transform
	var disc_node:Node3D=mirror.nodes.get("discs"+guest_disc)
	if is_instance_valid(disc_node):disc_node.global_transform=LAN.disc_pose(game.head.global_transform,guest_disc_back)

func send(action:String,id:String="",target:String=""):
	if not socket or socket.get_status()!=StreamPeerTCP.STATUS_CONNECTED:return
	if action in ["case_pick","shelf_pick"] and is_instance_valid(mirror):
		var key:String=selected_case if id.is_empty() else id
		if action=="case_pick":
			var node:Node3D=mirror.nodes.get("cases"+key)
			if is_instance_valid(node):pickup_from=node.global_position
		else:
			var row:Array=mirror.state.get("stock",{}).get(key,[])
			if row.size()>=5:pickup_from=row[4].origin
	if game.touch_controls and not game.touch_controls.action_busy():game.touch_controls.sync_hands()
	if action.is_empty():
		world_in_flight=true
		world_sent_at=Time.get_ticks_msec()
	var message:={"case":selected_case if id.is_empty() else id,"v":1,"grant":grant,"features":["checkout","world_sync","world_delta"],"action":action,"target":target,"customer":checkout.get("customer",-1),"coins":selected,"pose":PeerPose.pack(game)}
	message.merge(PeerPose.appearance(game))
	socket.put_data((JSON.stringify(message)+"\n").to_utf8_buffer())

func select_case(id:String):
	selected_case=id
	refresh()
	show()

func choose(value:String):
	var count:=int(selected.get(value,0))
	if count<int(checkout.get("till",{}).get(value,0)):
		selected[value]=count+1
	refresh()

func refresh():
	case_controls.hide()
	case_info.hide()
	cash_button.hide()
	denominations.hide()
	payout_button.hide()
	payout_button.get_parent().hide()
	info.text="●  Vidéo Club Messenger · Wi-Fi"
	if connected and is_instance_valid(mirror):
		var shift:Dictionary=mirror.state.get("shift",{})
		var seconds:=int(shift.get("time_left",0))
		info.text+="
Jour %d · %d:%02d"%[int(shift.get("day",1)),seconds/60,seconds%60]
