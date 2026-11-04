extends CanvasLayer

var game
var clerk
var buttons:Control
var menu:VBoxContainer
var operations:VBoxContainer
var lobby_panel:VBoxContainer
var lobby_invite := false
var status:Label
var action_hint:Label
var primary_button:Button
var case_button:Button
var drop_button:Button
var stick_base:Panel
var stick_thumb:Panel
var prompt_clock := 0.0
var tap_aim := false
var move_touch := -1
var look_touch := -1
var look_start := Vector2.ZERO
var look_moved := false
var move_start := Vector2.ZERO
var motion := Vector2.ZERO
var notice_time := 0.0
var last_notice := ""
var original_camera_height := 1.65
var crouching := false
var spare_carried := false
var disc_back := false
const DETACHER := Vector3(.72,1.17,-6.18)

func setup(g):
	game=g
	clerk=g.clerk
	name="TouchControls"
	process_mode=Node.PROCESS_MODE_ALWAYS
	game.hud.hide()
	game.head.fov=72
	game.get_viewport().msaa_3d=Viewport.MSAA_2X
	game.get_viewport().scaling_3d_scale=.87
	for i in range(2):
		game.dvd_grip_anchors[i].transform=Transform3D.IDENTITY
		game.hand_visuals[i].hide()
	buttons=Control.new()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buttons.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(buttons)
	var reticle:=Label.new()
	reticle.text="+"
	reticle.add_theme_font_size_override("font_size",22)
	reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.offset_left=-7
	reticle.offset_top=-15
	buttons.add_child(reticle)
	status=Label.new()
	status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	status.offset_left=-365
	status.offset_right=365
	status.offset_top=10
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color",Color("ffe0a1"))
	status.add_theme_color_override("font_outline_color",Color.BLACK)
	status.add_theme_constant_override("outline_size",6)
	status.add_theme_font_size_override("font_size",21)
	status.text="Gauche : avancer · Droite : regarder · Vise puis touche Utiliser"
	buttons.add_child(status)
	stick_base=make_stick(Vector2(130,130),Color(.10,.17,.27,.50))
	stick_thumb=make_stick(Vector2(54,54),Color(.71,.83,1.0,.66))
	var bar:=HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bar.offset_left=-595
	bar.offset_right=-18
	bar.offset_top=-86
	bar.offset_bottom=-16
	bar.add_theme_constant_override("separation",8)
	buttons.add_child(bar)
	primary_button=add_button(bar,"Utiliser",use_target)
	primary_button.custom_minimum_size.x=178
	primary_button.add_theme_stylebox_override("normal",button_skin(Color("245892")))
	case_button=add_button(bar,"Boîtier",case_action)
	drop_button=add_button(bar,"Déposer",drop)
	add_button(bar,"Outils",toggle_operations)
	var pause:=Button.new()
	pause.text="☰  Menu"
	pause.custom_minimum_size=Vector2(105,51)
	pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause.offset_left=-126
	pause.offset_right=-18
	pause.offset_top=16
	pause.pressed.connect(toggle_menu)
	buttons.add_child(pause)
	action_hint=Label.new()
	action_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action_hint.offset_left=-350
	action_hint.offset_right=350
	action_hint.offset_top=-113
	action_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	action_hint.add_theme_color_override("font_color",Color("f6deab"))
	action_hint.add_theme_color_override("font_outline_color",Color.BLACK)
	action_hint.add_theme_constant_override("outline_size",6)
	action_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	buttons.add_child(action_hint)
	menu=make_panel()
	add_button(menu,"Reprendre",toggle_menu)
	add_button(menu,"Sauvegarder",func():game.session.save_game())
	add_button(menu,"Continuer la sauvegarde",func():game.session.continue_game())
	add_button(menu,"Nouvelle partie",confirm_new_game)
	add_button(menu,"Son des bandes-annonces",func():game.modes._activate(7))
	add_button(menu,"Lobby Wi-Fi",open_lobby)
	operations=make_panel()
	var grid:=GridContainer.new()
	grid.columns=2
	operations.add_child(grid)
	add_button(grid,"Retourner boîtier / disque",flip_item)
	add_button(grid,"Sortir / remettre le disque",use_disc)
	add_button(grid,"Scanner",scan)
	add_button(grid,"Retirer / remettre l’antivol",use_lock)
	add_button(grid,"Prendre une barre jaune",take_spare)
	add_button(grid,"Prendre le paiement",take_payment)
	add_button(grid,"Déposer les billets en caisse",deposit_payment)
	add_button(grid,"Préparer la monnaie",open_change)
	add_button(grid,"Remettre la monnaie",give_change)
	add_button(grid,"S’accroupir / se relever",func():crouching=not crouching)
	add_button(operations,"Fermer",toggle_operations)
	sync_hands()

func add_button(parent:Container,title:String,call:Callable)->Button:
	var button:=Button.new()
	button.text=title
	button.custom_minimum_size=Vector2(105,48)
	button.add_theme_font_size_override("font_size",20)
	button.pressed.connect(call)
	parent.add_child(button)
	return button

func button_skin(color:Color)->StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(12)
	return style

func make_stick(dimensions:Vector2,color:Color)->Panel:
	var panel:=Panel.new()
	panel.size=dimensions
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var skin:=button_skin(color)
	skin.set_corner_radius_all(int(dimensions.x/2))
	skin.set_border_width_all(2)
	skin.border_color=Color(.74,.83,.96,.52)
	panel.add_theme_stylebox_override("panel",skin)
	buttons.add_child(panel)
	return panel

func update_stick():
	var height:=get_viewport().get_visible_rect().size.y
	var center:=move_start if move_touch>=0 else Vector2(105,height-106)
	stick_base.position=center-stick_base.size*.5
	stick_thumb.position=center+motion*47-stick_thumb.size*.5
	stick_base.visible=not get_tree().paused
	stick_thumb.visible=stick_base.visible

func make_panel()->VBoxContainer:
	var panel:=PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left=-154
	panel.offset_right=154
	panel.offset_top=-220
	panel.offset_bottom=220
	buttons.add_child(panel)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",4)
	panel.add_child(box)
	panel.hide()
	return box

func sync_hands():
	for i in range(2):
		game.aim_hands[i].global_transform=game.head.global_transform
		game.hands[i].global_transform=game.head.global_transform*Transform3D(Basis.IDENTITY,Vector3(-.20 if i==0 else .20,-.21,-.48))

func _physics_process(delta:float):
	update_stick()
	if get_tree().paused:
		if game.modes.menu_open and not menu.get_parent().visible and (not lobby_panel or not lobby_panel.get_parent().visible):menu.get_parent().show()
		return
	var f:Vector3=-game.head.global_basis.z
	f.y=0
	f=f.normalized()
	game._move_player((f*-motion.y+f.cross(Vector3.UP)*motion.x)*delta*1.90)
	game.head.position.y=move_toward(game.head.position.y,.98 if crouching else original_camera_height,delta*3.0)
	sync_hands()
	var point:Vector2=clerk.desktop.project_ray(game.aim_hands[0])
	clerk.desktop.point(point)
	prompt_clock-=delta
	if prompt_clock<=0:
		prompt_clock=.10
		refresh_action(point.x>=0)
	if not game.hud.text.is_empty() and game.hud.text!=last_notice:
		last_notice=game.hud.text
		status.text=last_notice
		notice_time=5.0
	elif notice_time>0:
		notice_time-=delta
		if notice_time<=0:status.text=""

func _unhandled_input(event:InputEvent):
	if get_tree().paused:return
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x<get_viewport().get_visible_rect().size.x*.44 and move_touch<0:
				move_touch=event.index
				move_start=event.position
			elif look_touch<0:
				look_touch=event.index
				look_start=event.position
				look_moved=false
		else:
			if event.index==move_touch:
				move_touch=-1
				motion=Vector2.ZERO
			if event.index==look_touch:
				look_touch=-1
				if not look_moved:
					tap_target(event.position)
	elif event is InputEventScreenDrag:
		if event.index==move_touch:motion=((event.position-move_start)/75.0).limit_length(1.0)
		elif event.index==look_touch:
			if event.position.distance_to(look_start)>6:look_moved=true
			game.origin.rotation.y-=event.relative.x*.004
			game.head.rotation.x=clampf(game.head.rotation.x-event.relative.y*.004,-1.24,1.24)

func tap_target(pixel:Vector2):
	var direction:Vector3=game.head.project_ray_normal(pixel)
	var up:=Vector3.UP if absf(direction.dot(Vector3.UP))<.99 else Vector3.RIGHT
	var aim:Node3D=game.aim_hands[0]
	aim.global_transform=Transform3D(Basis.looking_at(direction,up),game.head.project_ray_origin(pixel))
	tap_aim=true
	use_target()
	tap_aim=false
	sync_hands()

func toggle_menu():
	operations.get_parent().hide()
	game.modes.toggle_pause()
	game.modes.panel.hide()
	menu.get_parent().visible=game.modes.menu_open
	game.hud.hide()
	motion=Vector2.ZERO
	move_touch=-1
	look_touch=-1

func toggle_operations():
	operations.get_parent().visible=not operations.get_parent().visible
	motion=Vector2.ZERO

func confirm_new_game():
	var dialog:=ConfirmationDialog.new()
	dialog.dialog_text="Démarrer une nouvelle partie sur cet appareil ?"
	add_child(dialog)
	dialog.confirmed.connect(func():game.session.new_game();dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func near(p:Vector3,range_m:float=1.55)->bool:
	return game.head.global_position.distance_to(p)<range_m

func aimed(p:Vector3,radius:float=.15)->float:
	var ray:Vector3=-game.aim_hands[0].global_basis.z if tap_aim else -game.head.global_basis.z
	var offset:Vector3=p-game.head.global_position
	var distance:=offset.dot(ray)
	if distance<=0 or distance>2.15 or (offset-ray*distance).length()>radius:return INF
	return distance

func pointed_item()->Dictionary:
	var best:Dictionary={}
	var nearest:=INF
	for item in clerk.cases:
		if item==clerk.held_service or item.node.get_meta("customer_animating",false):continue
		var distance:=aimed(item.node.global_position,.095)
		if distance<nearest:
			best=item
			nearest=distance
	return best

func use_target():
	if get_tree().paused:return
	clerk.shift.started=true
	if not tap_aim:sync_hands()
	if clerk.desktop.point(clerk.desktop.project_ray(game.aim_hands[0]),true):return
	if clerk.inspection.finger>=0:
		use_disc()
		return
	if game.held:
		if near(clerk.customer_hand(),1.25) and aimed(clerk.customer_hand(),.34)<INF:
			drop()
		elif near(clerk.scanner.global_position) and aimed(clerk.scanner.global_position,.24)<INF:scan()
		elif near(DETACHER) and aimed(DETACHER,.20)<INF:use_lock()
		else:toggle_case()
		return
	if is_instance_valid(game.candy.held_balls[0]):
		game.candy.release_ball(0)
		return
	for ball in game.candy.balls:
		if int(ball.held)<0 and aimed(ball.body.global_position,.12)<INF:
			game.candy.grab_ball(0,ball.body)
			return
	var item:=pointed_item()
	if not item.is_empty():
		if item in clerk.basket.items:
			clerk.basket.items.erase(item)
			clerk.basket.arrange()
		clerk.pick_case(item,0,false)
		game._play_trailer(item.movie)
		return
	for target in clerk.targets:
		if target.action in ["tender","money","page","phone","door","drawer"] and aimed(target.node.global_position,target.radius)<INF:
			if target.action=="tender":take_payment()
			elif target.action=="money":clerk.wallet.take(1,target.value)
			else:clerk.action(target.action,1,target.value)
			return
	var original:bool=game.modes.manual_mode
	game.modes.manual_mode=false
	game._interact(0,false)
	game.modes.manual_mode=original

func refresh_action(over_desktop:bool):
	var inspection=clerk.inspection
	var label:="Viser un objet"
	var hint:=""
	var item:Dictionary=pointed_item() if not game.held else {}
	if over_desktop:label="Cliquer"
	elif inspection.finger>=0:
		label="Déposer le disque" if not inspection.opened else "Remettre le disque"
	elif game.held:
		if not clerk.active.is_empty() and aimed(clerk.customer_hand(),.34)<INF:label="Remettre au client"
		elif aimed(clerk.scanner.global_position,.24)<INF:label="Scanner"
		elif aimed(DETACHER,.20)<INF:label="Antivol"
		else:label="Fermer" if inspection.opened else "Ouvrir"
		hint=str(game.layout.movies[game.movie_id].title) if game.movie_id>=0 else ""
	elif not item.is_empty():
		label="Prendre"
		hint=str(game.layout.movies[item.movie].title)
	else:
		label="Utiliser"
	primary_button.text=label
	case_button.text="Disque" if inspection.opened else "Boîtier"
	case_button.disabled=not game.held and inspection.finger<0
	drop_button.disabled=not game.held and not is_instance_valid(game.candy.held_balls[0])
	action_hint.text=hint

func case_action():
	if clerk.inspection.opened or clerk.inspection.finger>=0:use_disc()
	else:toggle_case()

func toggle_case():
	if not game.held:
		game._message("Prends un boîtier.")
		return
	if clerk.inspection.finger>=0 and clerk.inspection.opened:
		game._message("Remets le disque avant de fermer.")
		return
	clerk.inspection.toggle_case()
	if clerk.inspection.opened:clerk.inspection.finish_lid(true)

func flip_item():
	if clerk.inspection.finger>=0:disc_back=not disc_back
	elif not clerk.inspection.opened:game._flip_held()

func use_disc():
	var inspection=clerk.inspection
	if inspection.finger>=0:
		var station:Vector3=clerk.repairs.station
		if near(station) and aimed(station,.23)<INF:
			inspection.carried.global_position=station
			inspection.interact(inspection.finger,false)
		elif inspection.opened:
			inspection.carried.global_position=inspection.interior.to_global(Vector3(0,-.012,.004))
			inspection.interact(inspection.finger,false)
		else:
			var p:=table_point(.93)
			clerk.repairs.place_disc(inspection,p)
		return
	if inspection.opened and is_instance_valid(inspection.disc):
		inspection.take_open_disc(1)
	elif near(clerk.repairs.station) and aimed(clerk.repairs.station,.25)<INF:
		clerk.repairs.take_disc(inspection,1,clerk.repairs.station)
	else:
		for loose in inspection.loose_discs:
			if aimed(loose.node.global_position,.13)<INF:
				inspection.take_loose_disc(loose,1)
				return

func scan():
	if not near(clerk.scanner.global_position):
		game._message("Approche-toi du scanner du comptoir.")
		return
	if clerk.scan_held():
		clerk.scanner.flash=.16
		clerk.scanner.sound.play()

func use_lock():
	if not game.held or clerk.inspection.opened:return
	if game.held.get_meta("antitheft",false):
		if not near(DETACHER):
			game._message("Approche-toi du détacheur pour retirer la barre.")
			return
		clerk.locks.set_locked(game.held,false)
		clerk.locks.put_in_bin(clerk.locks.create_bar())
		clerk.refresh_terminal()
		return
	if not spare_carried:
		game._message("Prends une barre de réserve dans le bac ou via Outils.")
		return
	spare_carried=false
	clerk.locks.set_locked(game.held,true)
	clerk.refresh_terminal()

func take_spare():
	if not near(clerk.lock_bin) or spare_carried:return
	clerk.locks.ensure_spare()
	for body in clerk.locks.bars:
		if not body.get_meta("in_bin",false):continue
		clerk.locks.bars.erase(body)
		body.queue_free()
		spare_carried=true
		game._message("Barre prête. Tu peux l’insérer où tu veux.")
		return

func drop():
	if is_instance_valid(game.candy.held_balls[0]):
		var body:RigidBody3D=game.candy.held_balls[0]
		game.candy.release_ball(0)
		body.linear_velocity=-game.head.global_basis.z*3.0+Vector3.UP
		return
	if not game.held:return
	if not clerk.active.is_empty() and clerk.held_service.get("kind","")=="rental" and near(clerk.customer_hand(),1.3) and aimed(clerk.customer_hand(),.34)<INF:
		if game.held.get_meta("disc_movie",-1)!=clerk.held_service.movie:
			clerk.flag_wrong_case(clerk.held_service)
		else:
			clerk.action("handoff",game.held_hand)
		return
	if not clerk.held_service.is_empty():
		var record:Dictionary=clerk.held_service.get("record",{})
		if not record.is_empty() and aimed(record.world.origin,.24)<INF:
			game.held.global_position=record.world.origin
		elif aimed(Vector3(1.75,1.19,-5.92),.26)<INF:
			game.held.global_position=Vector3(1.75,1.19,-5.92)
		elif aimed(clerk.basket.body.global_position,.25)<INF:
			game.held.global_position=clerk.basket.body.to_global(Vector3(0,.16,0))
		else:
			var table:=table_point(.93)
			if clerk.repairs.is_case_surface(table):
				game.held.global_position=table
				if clerk.repairs.place_case(clerk.held_service):return
			game.held.global_position=game.head.global_position-game.head.global_basis.z*.68
	game._release()
	sync_hands()

func table_point(height:float)->Vector3:
	var start:Vector3=game.head.global_position
	var direction:Vector3=-game.head.global_basis.z
	if direction.y>=-.08:return Vector3.INF
	var distance:float=(height-start.y)/direction.y
	return start+direction*distance if distance>0 and distance<1.7 else Vector3.INF

func take_payment():
	if not near(clerk.tender_note.global_position):return
	while clerk.tender_note.visible and clerk.wallet.palms[1].size()<32:
		var count:int=clerk.wallet.palms[1].size()
		clerk.wallet.take(1,clerk.tender,true)
		if clerk.wallet.palms[1].size()==count:break

func deposit_payment():
	if not near(clerk.tender_note.global_position) or not clerk.drawer_open:return
	for index in range(clerk.wallet.palms[1].size()-1,-1,-1):
		if clerk.wallet.palms[1][index].tender:clerk.wallet.remove_one(1,index,true)

func open_change():
	if not near(clerk.tender_note.global_position) or not clerk.drawer_open:return
	operations.get_parent().hide()
	var change:=make_panel()
	for value in [1,5,10,25,100,200,500,1000,2000,5000]:
		var cents:int=value
		add_button(change,"%.2f $"%(cents/100.0),func():clerk.wallet.take(1,cents))
	add_button(change,"Fermer",change.get_parent().queue_free)
	change.get_parent().show()

func give_change():
	if near(clerk.customer_hand(),1.5):clerk.wallet.give_customer(1)

func open_lobby():
	game.lobby.start()
	menu.get_parent().hide()
	if not lobby_panel:
		lobby_panel=make_panel()
		game.lobby.changed.connect(refresh_lobby)
	lobby_panel.get_parent().show()
	refresh_lobby()

func refresh_lobby():
	if not lobby_panel or not lobby_panel.get_parent().visible:return
	for child in lobby_panel.get_children():
		lobby_panel.remove_child(child)
		child.queue_free()
	var heading:=Label.new()
	heading.text="Lobby Wi-Fi · Test de présence"
	lobby_panel.add_child(heading)
	var notice:=Label.new()
	notice.text=game.lobby.status
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.x=370
	lobby_panel.add_child(notice)
	add_button(lobby_panel,"Mode : inviter" if lobby_invite else "Mode : rejoindre",func():lobby_invite=not lobby_invite;refresh_lobby())
	var players:Array=game.lobby.list_players()
	for i in range(mini(players.size(),5)):
		var index:=i
		add_button(lobby_panel,players[i].name,func():game.lobby.request(index,lobby_invite))
	if not game.lobby.incoming.is_empty():
		add_button(lobby_panel,"Accuser réception",func():game.lobby.reply(true))
		add_button(lobby_panel,"Refuser",func():game.lobby.reply(false))
	add_button(lobby_panel,"Retour",func():lobby_panel.get_parent().hide();menu.get_parent().show())
