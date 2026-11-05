extends Node

const PORT := 39166
const MAGIC := "VideoClubLobby/1"
const INTERVAL := 1.35
const LIFETIME := 6500

var game
var socket:PacketPeerUDP
var peers:Dictionary={}
var incoming:Dictionary={}
var outgoing:Dictionary={}
var device_id:=""
var display_name:=""
var announce_in:=0.0
var available:=false
var last_playing:=false
var status:="Recherche sur le Wi-Fi…"
signal changed
signal join_granted(ip:String,grant:String)

func setup(g):
	game=g
	name="LobbyWiFi"
	process_mode=Node.PROCESS_MODE_ALWAYS
	device_id=Crypto.new().generate_random_bytes(12).hex_encode()
	display_name=("Android" if game.touch_profile else "Quest")+" "+device_id.left(4).to_upper()
	if OS.has_feature("android") or "--lan-lobby" in OS.get_cmdline_user_args():start()

func start():
	if socket:return
	var listener:=PacketPeerUDP.new()
	if listener.bind(PORT,"0.0.0.0")!=OK:
		status="Lobby indisponible : le port Wi-Fi est occupé."
		changed.emit()
		return
	listener.set_broadcast_enabled(true)
	socket=listener
	announce_in=0.0

func send(packet:Dictionary,ip:String):
	if not socket or socket.set_dest_address(ip,PORT)!=OK:return
	var body=packet.duplicate()
	body["magic"]=MAGIC
	body["sender"]=device_id
	socket.put_packet(JSON.stringify(body).to_utf8_buffer())

func is_playing()->bool:
	if not game.clerk or not game.clerk.shift:return false
	return game.clerk.shift.started and not game.clerk.shift.summary

func announce(ip:String,replying:bool=false):
	send({"type":"presence","name":display_name,"playing":is_playing(),"available":available,"hosting":game.clerk.lan.server!=null,"reply":replying},ip)

func set_available(value:bool):
	start()
	available=value
	if not game.touch_profile and game.clerk and (game.clerk.lan.server!=null)!=value:
		game.clerk.lan.toggle_host()
	status="Visible sur le Wi-Fi." if available else "Invisible sur le Wi-Fi."
	if socket:announce("255.255.255.255")
	changed.emit()

func toggle_available():
	set_available(not available)

func _process(delta:float):
	if not socket:return
	announce_in-=delta
	var now:=Time.get_ticks_msec()
	var playing:=is_playing()
	if announce_in<=0 or playing!=last_playing:
		last_playing=playing
		announce_in=INTERVAL
		announce("255.255.255.255")
		for id in peers.keys():
			if now-int(peers[id].seen)>LIFETIME:
				peers.erase(id)
				changed.emit()
		if not incoming.is_empty() and now-int(incoming.time)>14000:
			incoming.clear()
			status="Demande expirée."
			changed.emit()
		if not outgoing.is_empty() and now-int(outgoing.time)>14000:
			outgoing.clear()
			status="Aucune réponse à la demande."
			changed.emit()
	for ignored in range(mini(24,socket.get_available_packet_count())):
		var data:=socket.get_packet()
		if data.size()>512:continue
		receive(JSON.parse_string(data.get_string_from_utf8()),socket.get_packet_ip(),now)

func receive(packet:Variant,ip:String,now:int):
	if not packet is Dictionary or packet.get("magic")!=MAGIC:return
	var sender:=str(packet.get("sender",""))
	if sender==device_id or sender.length()!=24 or not ip.is_valid_ip_address():return
	if packet.get("type")=="presence":
		var old:Dictionary=peers.get(sender,{})
		var ready:bool=packet.get("available",false)==true
		var hosting:bool=packet.get("hosting",false)==true
		var peer_name:=str(packet.get("name","Joueur")).strip_edges().left(20)
		peers[sender]={"id":sender,"name":peer_name,"ip":ip,"seen":now,"ready":ready,"hosting":hosting}
		if old.is_empty() or old.get("ready")!=ready or old.get("name")!=peer_name or old.get("hosting")!=hosting:
			changed.emit()
		if old.is_empty() and not packet.get("reply",false):announce(ip,true)
		return
	if packet.get("to")!=device_id or not peers.has(sender) or peers[sender].ip!=ip:return
	var ticket:=str(packet.get("ticket",""))
	if ticket.length()!=16:return
	match packet.get("type"):
		"join":
			if not available or not game.clerk.lan.server:return
			var grant:String=game.clerk.lan.permit(ip)
			send({"type":"reply","to":sender,"ticket":ticket,"accepted":not grant.is_empty(),"grant":grant},ip)
		"invite":
			if not available or not game.touch_profile or not incoming.is_empty():return
			var grant:=str(packet.get("grant",""))
			if grant.length()!=24:return
			incoming={"from":sender,"ticket":ticket,"grant":grant,"time":now}
			status="%s t’invite à jouer."%peers[sender].name
			game._message(status)
			changed.emit()
		"reply":
			if outgoing.get("to")!=sender or outgoing.get("ticket")!=ticket:return
			outgoing.clear()
			var grant:=str(packet.get("grant",""))
			if packet.get("accepted",false) and grant.length()==24:join_granted.emit(ip,grant)
			status="Connexion à "+peers[sender].name if not grant.is_empty() else "Demande terminée."
			changed.emit()

func list_players()->Array:
	var rows:Array=peers.values().filter(func(peer):return peer.get("ready",false))
	rows.sort_custom(func(a,b):return a.name.naturalnocasecmp_to(b.name)<0)
	return rows

func request(index:int,invite:bool):
	var players:=list_players()
	if not available or index<0 or index>=players.size() or not outgoing.is_empty():return
	var player:Dictionary=players[index]
	var ticket:=Crypto.new().generate_random_bytes(8).hex_encode()
	if invite:
		if not game.clerk.lan.server or player.hosting:return
		var grant:String=game.clerk.lan.permit(player.ip)
		if grant.is_empty():return
		send({"type":"invite","to":player.id,"ticket":ticket,"grant":grant},player.ip)
	else:
		if not game.touch_profile or not player.hosting:return
		outgoing={"to":player.id,"ticket":ticket,"time":Time.get_ticks_msec()}
		send({"type":"join","to":player.id,"ticket":ticket},player.ip)
	status="Demande envoyée à "+player.name
	changed.emit()

func reply(acknowledge:bool):
	if incoming.is_empty():return
	var sender:String=incoming.from
	if acknowledge and peers.has(sender):join_granted.emit(peers[sender].ip,incoming.grant)
	incoming.clear()
	status="Connexion à la partie…" if acknowledge else "Invitation refusée."
	changed.emit()
