extends Control

const PORT := 39165
const TABS := ["Clients","Tâches","Retours","Journée"]
var socket:StreamPeerTCP
var address:LineEdit
var pin:LineEdit
var status:Label
var info:Label
var action_button:Button
var join_button:Button
var pages:Array = []
var selected := 0
var buffer := PackedByteArray()
var connected := false
var request_clock := 0.0
var time_left := 0.0
var available_actions:Dictionary = {}

func _ready():
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,22)
	add_child(margin)
	var stack:=VBoxContainer.new()
	stack.add_theme_constant_override("separation",12)
	margin.add_child(stack)
	var title:=Label.new()
	title.text="VIDÉO CLUB"
	title.add_theme_font_size_override("font_size",36)
	stack.add_child(title)
	var subtitle:=Label.new()
	subtitle.text="Poste coop · Réseau local"
	stack.add_child(subtitle)
	address=LineEdit.new()
	address.placeholder_text="Adresse du Quest, ex. 192.168.1.20"
	address.custom_minimum_size.y=48
	stack.add_child(address)
	pin=LineEdit.new()
	pin.placeholder_text="Code de la partie"
	pin.max_length=6
	pin.custom_minimum_size.y=48
	stack.add_child(pin)
	join_button=add_button(stack,"Rejoindre",join_or_leave)
	status=Label.new()
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.text="Sur le Quest : ordinateur → Coop Wi-Fi."
	stack.add_child(status)
	var row:=HBoxContainer.new()
	stack.add_child(row)
	for index in range(TABS.size()):
		var tab:=index
		var button:=add_button(row,TABS[index],func():selected=tab; update_view())
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	info=Label.new()
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size",19)
	scroll.add_child(info)
	action_button=add_button(stack,"Action",perform_action)
	update_view()

func add_button(parent:Container,caption:String,callback:Callable)->Button:
	var item:=Button.new()
	item.text=caption
	item.custom_minimum_size.y=48
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func join_or_leave():
	if socket:
		reset("Partie quittée.")
		return
	var ip:=address.text.strip_edges()
	if not ip.is_valid_ip_address() or not pin.text.is_valid_int() or pin.text.length()!=6:
		status.text="Entre l’adresse IP et le code à six chiffres affichés sur le Quest."
		return
	socket=StreamPeerTCP.new()
	if socket.connect_to_host(ip,PORT)!=OK:
		reset("Connexion impossible.")
		return
	time_left=8.0
	request_clock=0.0
	status.text="Connexion au Quest…"
	join_button.text="Annuler"

func reset(message:String):
	if socket:socket.disconnect_from_host()
	socket=null
	connected=false
	pages.clear()
	buffer.clear()
	status.text=message
	join_button.text="Rejoindre"
	update_view()

func _process(delta:float):
	if not socket:return
	socket.poll()
	time_left-=delta
	if socket.get_status() in [StreamPeerTCP.STATUS_ERROR,StreamPeerTCP.STATUS_NONE] or time_left<=0:
		reset("Partie inaccessible. Vérifie l’adresse, le code et le Wi-Fi.")
		return
	if socket.get_status()!=StreamPeerTCP.STATUS_CONNECTED:return
	request_clock-=delta
	if request_clock<=0.0:
		send("")
		request_clock=.55
	var available:=socket.get_available_bytes()
	if available<=0:return
	if available+buffer.size()>65536:
		reset("Réponse de la partie invalide.")
		return
	var data:=socket.get_partial_data(available)
	if data[0]!=OK:return
	buffer.append_array(data[1])
	var end:=buffer.find(10)
	while end>=0:
		var response:Variant=JSON.parse_string(buffer.slice(0,end).get_string_from_utf8())
		buffer=buffer.slice(end+1)
		if response is Dictionary and response.has("error"):
			reset(str(response.error))
			return
		if response is Dictionary and response.get("v")==1 and response.get("pages") is Array:
			connected=true
			time_left=6.0
			pages=response.pages
			available_actions=response
			status.text="Connecté · Journée %d"%int(response.get("day",1))
			join_button.text="Quitter la partie"
			update_view()
		end=buffer.find(10)

func send(action:String):
	if socket and socket.get_status()==StreamPeerTCP.STATUS_CONNECTED:
		socket.put_data((JSON.stringify({"v":1,"pin":pin.text,"action":action})+"\n").to_utf8_buffer())

func update_view():
	info.text=str(pages[selected]) if connected and selected<pages.size() else "Les dossiers et les tâches apparaissent ici après la connexion."
	action_button.visible=connected and (selected==0 or selected==2)
	action_button.text="Ouvrir le tiroir de caisse" if selected==0 else "Valider le retour inspecté"
	action_button.disabled=not available_actions.get("client",false) if selected==0 else not available_actions.get("can_return",false)

func perform_action():
	send("drawer" if selected==0 else "return")
	request_clock=.55
