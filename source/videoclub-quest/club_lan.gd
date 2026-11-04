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
	var now:=Time.get_ticks_msec()
	if now-last_request<90 and request.get("action","").is_empty():return
	last_request=now
	var old_page:int=clerk.page
	match request.get("action",""):
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
	client.put_data((JSON.stringify(response)+"\n").to_utf8_buffer())



