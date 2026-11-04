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
var status:="Recherche sur le Wi-Fi…"
signal changed

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

func _process(delta:float):
	if not socket:return
	announce_in-=delta
	var now:=Time.get_ticks_msec()
	if announce_in<=0:
		announce_in=INTERVAL
		send({"type":"presence","name":display_name},"255.255.255.255")
		for id in peers.keys():
			if now-int(peers[id].seen)>LIFETIME:
				peers.erase(id)
				changed.emit()
		if not incoming.is_empty() and now-int(incoming.time)>20000:
			incoming.clear()
			status="Demande expirée."
			changed.emit()
		if not outgoing.is_empty() and now-int(outgoing.time)>20000:
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
		var added:=not peers.has(sender)
		peers[sender]={"id":sender,"name":str(packet.get("name","Joueur")).strip_edges().left(20),"ip":ip,"seen":now}
		if added:changed.emit()
		return
	if packet.get("to")!=device_id or not peers.has(sender) or peers[sender].ip!=ip:return
	var ticket:=str(packet.get("ticket",""))
	if ticket.length()!=16:return
	match packet.get("type"):
		"invite","join":
			if not incoming.is_empty():return
			incoming={"from":sender,"ticket":ticket,"type":packet.type,"time":now}
			status=("%s t’invite." if packet.type=="invite" else "%s veut rejoindre ta partie.")%peers[sender].name
			game._message(status+" Ouvre le Lobby Wi-Fi.")
			changed.emit()
		"reply":
			if outgoing.get("to")!=sender or outgoing.get("ticket")!=ticket:return
			outgoing.clear()
			status="%s a reçu ta demande."%peers[sender].name if packet.get("accepted",false) else "%s a refusé."%peers[sender].name
			game._message(status)
			changed.emit()

func list_players()->Array:
	var rows:Array=peers.values()
	rows.sort_custom(func(a,b):return a.name.naturalnocasecmp_to(b.name)<0)
	return rows

func request(index:int,invite:bool):
	var players:=list_players()
	if index<0 or index>=players.size() or not outgoing.is_empty():return
	var player:Dictionary=players[index]
	var ticket:=Crypto.new().generate_random_bytes(8).hex_encode()
	outgoing={"to":player.id,"ticket":ticket,"time":Time.get_ticks_msec()}
	send({"type":"invite" if invite else "join","to":player.id,"ticket":ticket},player.ip)
	status="Demande envoyée à "+player.name
	changed.emit()

func reply(acknowledge:bool):
	if incoming.is_empty():return
	var sender:String=incoming.from
	if peers.has(sender):
		send({"type":"reply","to":sender,"ticket":incoming.ticket,"accepted":acknowledge},peers[sender].ip)
	incoming.clear()
	status="Demande reçue. La partie partagée est encore en développement." if acknowledge else "Demande refusée."
	changed.emit()
