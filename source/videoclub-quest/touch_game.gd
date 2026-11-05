extends CanvasLayer

var game
var clerk
var buttons:Control
var menu:VBoxContainer
var operations:VBoxContainer
var basket_button:Button
var flip_button:Button
var lock_button:Button
var basket_panel:VBoxContainer
var basket_carried:=false
var basket_resting_pose:Transform3D
var checkout_panel:VBoxContainer
var checkout_button:Button
var coop_panel:PanelContainer
var coop_button:Button
const BASKET_REACH := 1.8
var lobby_panel:VBoxContainer
var lobby_invite := false
var status:Label
var action_hint:Label
var primary_button:Button
var case_button:Button
var drop_button:Button
var counter_actions:HBoxContainer
var change_button:Button
var handoff_button:Button
var stick_base:Panel
var stick_thumb:Panel
var prompt_clock := 0.0
var tap_aim := false
var action_motion:Tween
var action_support_hand:=-1
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
var desktop_overlay:ColorRect
var desktop_view:TextureRect
const CASH_HAND := 0
const CASE_HAND := 1
var cash_panel:VBoxContainer
var cash_total:Label
var cash_pieces:GridContainer
var selected_cash:Node3D
var cash_signature:Array=[]
const DETACHER := Vector3(.72,1.17,-6.18)

func setup(g):
	game=g
	clerk=g.clerk
	name="TouchControls"
	process_mode=Node.PROCESS_MODE_ALWAYS
	game.hud.hide()
	game.head.fov=58
	game.get_viewport().msaa_3d=Viewport.MSAA_DISABLED if OS.has_feature("android") else Viewport.MSAA_2X
	game.get_viewport().scaling_3d_scale=.87
	for i in range(2):
		game.dvd_grip_anchors[i].transform=Transform3D.IDENTITY
		game.hand_visuals[i].hide()
	buttons=Control.new()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buttons.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(buttons)
	var reticle:=Control.new()
	reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	buttons.add_child(reticle)
	for bounds in [Rect2(-19,-2,38,4),Rect2(-2,-19,4,38)]:
		var outline:=ColorRect.new()
		outline.position=bounds.position-Vector2.ONE*2
		outline.size=bounds.size+Vector2.ONE*4
		outline.color=Color(.03,.04,.06,.92)
		outline.mouse_filter=Control.MOUSE_FILTER_IGNORE
		reticle.add_child(outline)
	for bounds in [Rect2(-18,-1.5,36,3),Rect2(-1.5,-18,3,36)]:
		var stroke:=ColorRect.new()
		stroke.position=bounds.position
		stroke.size=bounds.size
		stroke.color=Color("fff1d0")
		stroke.mouse_filter=Control.MOUSE_FILTER_IGNORE
		reticle.add_child(stroke)
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
	cash_panel=VBoxContainer.new()
	cash_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	cash_panel.offset_left=202
	cash_panel.offset_top=-200
	cash_panel.alignment=BoxContainer.ALIGNMENT_END
	cash_panel.offset_bottom=-93
	cash_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	buttons.add_child(cash_panel)
	cash_total=Label.new()
	cash_total.add_theme_font_size_override("font_size",22)
	cash_total.add_theme_color_override("font_outline_color",Color.BLACK)
	cash_total.add_theme_constant_override("outline_size",8)
	cash_panel.add_child(cash_total)
	cash_pieces=GridContainer.new()
	cash_pieces.columns=5
	cash_panel.add_child(cash_pieces)
	cash_panel.hide()
	stick_base=make_stick(Vector2(154,154),Color(.10,.17,.27,.50))
	stick_thumb=make_stick(Vector2(62,62),Color(.71,.83,1.0,.66))
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
	counter_actions=HBoxContainer.new()
	counter_actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	counter_actions.offset_left=-475
	counter_actions.offset_right=-18
	counter_actions.offset_top=-149
	counter_actions.offset_bottom=-94
	counter_actions.add_theme_constant_override("separation",8)
	buttons.add_child(counter_actions)
	change_button=add_button(counter_actions,"Rendre la monnaie",give_change)
	handoff_button=add_button(counter_actions,"Remettre le film / jeu",handoff)
	counter_actions.hide()
	var supplies:=HBoxContainer.new()
	supplies.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	supplies.offset_left=-475
	supplies.offset_right=-18
	supplies.offset_top=-211
	supplies.offset_bottom=-154
	buttons.add_child(supplies)
	basket_button=add_button(supplies,"Panier",open_basket)
	lock_button=add_button(supplies,"Antivol",use_lock)
	flip_button=add_button(supplies,"Voir le dos",flip_item)
	flip_button.hide()
	basket_button.hide()
	lock_button.hide()
	basket_panel=make_panel()
	checkout_panel=make_panel()
	checkout_button=Button.new()
	checkout_button.text="Caisse"
	checkout_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	checkout_button.offset_left=-250
	checkout_button.offset_right=-135
	checkout_button.offset_top=16
	checkout_button.offset_bottom=67
	checkout_button.add_theme_font_size_override("font_size",22)
	checkout_button.pressed.connect(open_checkout)
	buttons.add_child(checkout_button)
	checkout_button.hide()
	var pause:=Button.new()
	pause.text="☰  Menu"
	pause.custom_minimum_size=Vector2(105,51)
	pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause.offset_left=-126
	pause.offset_right=-18
	pause.offset_top=16
	pause.pressed.connect(toggle_menu)
	buttons.add_child(pause)
	coop_panel=preload("res://touch_coop.gd").new()
	buttons.add_child(coop_panel)
	coop_panel.setup(game)
	coop_button=Button.new()
	coop_button.text="Caisse coop"
	coop_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	coop_button.offset_left=-272
	coop_button.offset_right=-136
	coop_button.offset_top=16
	coop_button.offset_bottom=67
	coop_button.pressed.connect(open_coop)
	buttons.add_child(coop_button)
	coop_button.hide()
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
	add_button(menu,"Jouer en solo",play_solo)
	add_button(menu,"Sauvegarder",func():game.session.save_game())
	var continue_button:=add_button(menu,"Continuer la sauvegarde",continue_solo)
	continue_button.disabled=not FileAccess.file_exists(game.session.save_path) and not FileAccess.file_exists(game.session.save_path+".bak")
	add_button(menu,"Nouvelle partie",confirm_new_game)
	add_button(menu,"Son des bandes-annonces",func():game.modes._activate(7))
	var avatar_button:=add_button(menu,"Avatar : "+game.clerk_model_name(),func():
		game.toggle_clerk_model()
	)
	avatar_button.pressed.connect(func():avatar_button.text="Avatar : "+game.clerk_model_name())
	add_button(menu,"Coop",open_coop)
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
	if OS.has_feature("android") and not game.session.tools_run:call_deferred("show_start_menu")

func show_start_menu():
	if not game.modes.menu_open:toggle_menu()
	else:
		game.modes.panel.hide()
		menu.get_parent().show()

func play_solo():
	if game.modes.menu_open:toggle_menu()
	game.clerk.shift.started=true
	if not game.trailer_player.is_playing():game._play_ambient_trailer()
	game._message("Partie solo démarrée. Le club est ouvert.")

func continue_solo():
	if not game.session.continue_game():
		game._message(game.session.last_status)

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

func stick_center()->Vector2:
	return Vector2(111,get_viewport().get_visible_rect().size.y-145)

func update_stick():
	var center:=stick_center()
	stick_base.position=center-stick_base.size*.5
	stick_thumb.position=center+motion*54-stick_thumb.size*.5
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

func action_busy()->bool:
	return action_motion!=null and action_motion.is_running()

func hand_rest(index:int)->Transform3D:
	if index==CASH_HAND and (clerk.wallet.occupied(index) or action_support_hand==index):
		return game.head.global_transform*Transform3D(Basis(Vector3.RIGHT,.32),Vector3(-.16,-.135,-.43))
	var offset:=Vector3(-.20 if index==0 else .20,-.21,-.48)
	if game.held and game.held_hand==index:
		offset=Vector3(-.105 if index==0 else .105,-.105,-.40)
	return game.head.global_transform*Transform3D(Basis.IDENTITY,offset)

func sync_hands():
	for i in range(2):
		game.aim_hands[i].global_transform=game.head.global_transform
		if not action_busy():game.hands[i].global_transform=hand_rest(i)

func show_grip(delta:float):
	for i in range(2):
		var visual:Node3D=game.hand_visuals[i]
		var holding:bool=is_instance_valid(game.held) and game.held_hand==i
		visual.visible=holding or clerk.wallet.occupied(i) or (action_busy() and i==action_support_hand)
		if not visual.visible:continue
		visual.position=Vector3(-.070 if i==0 else .070,-.068,.028)
		visual.rotation.z=-.28 if i==0 else .28
		var cash:bool=clerk.wallet.occupied(i)
		visual.update_grip(delta,.04 if cash else .22,.08 if cash else .70,holding)

func tween_hand(tween:Tween,index:int,target:Transform3D,seconds:float):
	tween.tween_property(game.hands[index],"global_transform",target,seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func begin_motion():
	if desktop_overlay:desktop_overlay.hide()
	motion=Vector2.ZERO
	action_support_hand=-1
	move_touch=-1
	look_touch=-1
	operations.get_parent().hide()
	checkout_panel.get_parent().hide()
	action_motion=create_tween()

func animate_pick(origin:Vector3):
	if not game.held or action_busy():return
	var hand:int=game.held_hand
	var rest:=hand_rest(hand)
	if origin.distance_to(rest.origin)<.05:return
	game.hands[hand].global_transform=Transform3D(rest.basis,origin)
	begin_motion()
	tween_hand(action_motion,hand,rest,.26)

func open_coop():
	if game.modes.menu_open:toggle_menu()
	operations.get_parent().hide()
	basket_panel.get_parent().hide()
	checkout_panel.get_parent().hide()
	motion=Vector2.ZERO
	move_touch=-1
	look_touch=-1
	coop_panel.show()

func _physics_process(delta:float):
	update_stick()
	coop_button.visible=coop_panel.connected and not coop_panel.visible and not get_tree().paused
	if get_tree().paused:
		counter_actions.hide()
		checkout_button.hide()
		basket_button.hide()
		flip_button.hide()
		lock_button.hide()
		if game.modes.menu_open and not menu.get_parent().visible and (not lobby_panel or not lobby_panel.get_parent().visible):menu.get_parent().show()
		return
	show_grip(delta)
	refresh_cash_panel()
	if coop_panel.connected:
		cash_panel.hide()
		primary_button.get_parent().hide()
	else:primary_button.get_parent().show()
	if clerk.active.is_empty():checkout_panel.get_parent().hide()
	refresh_supply_buttons()
	counter_actions.visible=can_serve_customer() and not (desktop_overlay and desktop_overlay.visible)
	change_button.disabled=action_busy()
	handoff_button.disabled=action_busy()
	if action_busy() or coop_panel.visible or basket_panel.get_parent().visible or checkout_panel.get_parent().visible or (desktop_overlay and desktop_overlay.visible):return
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
	if get_tree().paused or action_busy() or coop_panel.visible or basket_panel.get_parent().visible or checkout_panel.get_parent().visible or (desktop_overlay and desktop_overlay.visible):return
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.distance_to(stick_center())<=77.0 and move_touch<0:
				move_touch=event.index
				move_start=stick_center()
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
	game.aim_hands[CASE_HAND].global_transform=aim.global_transform
	use_target()
	tap_aim=false
	sync_hands()

func toggle_menu():
	coop_panel.hide()
	checkout_panel.get_parent().hide()
	basket_panel.get_parent().hide()
	if desktop_overlay:desktop_overlay.hide()
	operations.get_parent().hide()
	game.modes.toggle_pause()
	game.modes.panel.hide()
	menu.get_parent().visible=game.modes.menu_open
	game.hud.hide()
	motion=Vector2.ZERO
	move_touch=-1
	look_touch=-1

func toggle_operations():
	checkout_panel.get_parent().hide()
	basket_panel.get_parent().hide()
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
	if get_tree().paused or action_busy() or coop_panel.connected or coop_panel.visible or basket_panel.get_parent().visible or checkout_panel.get_parent().visible:return
	clerk.shift.started=true
	if not tap_aim:sync_hands()
	if basket_aimed() and not clerk.inspection.opened:
		if game.held:put_in_basket()
		else:open_basket()
		return
	if target_customer() and clerk.tender_received and clerk.wallet.occupied(CASH_HAND):
		give_change()
		return
	if target_customer() and can_handoff():
		handoff()
		return
	if clerk.desktop.project_ray(game.aim_hands[0]).x>=0:
		open_desktop()
		return
	var cash:=cash_target()
	if not cash.is_empty():
		use_cash(cash)
		return
	if clerk.inspection.finger>=0:
		if aimed(clerk.inspection.carried.global_position,.083)<INF:flip_item()
		else:use_disc()
		return
	if clerk.inspection.opened and is_instance_valid(clerk.inspection.disc) and aimed(clerk.inspection.disc.global_position,.085)<INF:
		use_disc()
		return
	if game.held:
		if near(clerk.scanner.global_position) and aimed(clerk.scanner.global_position,.24)<INF:scan()
		elif near(DETACHER) and aimed(DETACHER,.20)<INF:use_lock()
		elif not game.held.get_meta("antitheft",false) and near(clerk.lock_bin) and aimed(clerk.lock_bin,.20)<INF:use_lock()
		elif tap_aim and aimed(game.held.global_position,.105)<INF:toggle_case()
		elif tap_aim:
			var destination:=case_drop_target()
			if destination.is_finite():place_held_case(destination)
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
		pick_touch_case(item)
		return
	for target in clerk.targets:
		if target.action in ["page","phone","door"] and aimed(target.node.global_position,target.radius)<INF:
			clerk.action(target.action,1,target.value)
			return
	var original:bool=game.modes.manual_mode
	game.modes.manual_mode=false
	game._interact(CASE_HAND,false)
	game.modes.manual_mode=original
	if game.held:
		var record:Dictionary=clerk.held_service.get("record",game.held_record)
		if not record.is_empty():animate_pick(record.world.origin)

func mark_touch_target(cash:Dictionary,item:Dictionary,over_desktop:bool):
	var glow:MeshInstance3D=game.interaction_glow(0)
	glow.hide()
	if over_desktop:
		var display_size:Vector2=clerk.screen.mesh.size
		glow.mark(clerk.screen.global_transform,Vector3(display_size.x+.012,display_size.y+.012,.018))
	elif not cash.is_empty():
		var node:Node3D=cash.get("node")
		var pose:=node.global_transform if node else Transform3D(Basis.IDENTITY,cash.position)
		var width:=.32 if cash.action=="deposit" else .14
		glow.mark(pose,Vector3(width,.09,.12))
	elif clerk.inspection.finger>=0:
		var disc:Node3D=clerk.inspection.carried
		if aimed(disc.global_position,.083)<INF:glow.mark(disc.global_transform,Vector3(.13,.13,.015))
	elif clerk.inspection.opened:
		var disc:Node3D=clerk.inspection.disc
		if is_instance_valid(disc) and aimed(disc.global_position,.085)<INF:glow.mark(disc.global_transform,Vector3(.13,.13,.015))
	elif not item.is_empty():
		glow.mark(item.node.global_transform,Vector3(.15,.21,.033))
	elif not game.held:
		var record:Dictionary=game.shelf_ray(game.head.global_position,-game.head.global_basis.z)
		if not record.is_empty():glow.mark(record.world,Vector3(.15,.21,.033))
	elif aimed(clerk.scanner.global_position,.24)<INF and near(clerk.scanner.global_position):
		glow.mark(clerk.scanner.global_transform,Vector3(.22,.17,.18))
	elif aimed(DETACHER,.20)<INF and near(DETACHER):
		glow.mark(Transform3D(Basis.IDENTITY,DETACHER),Vector3(.22,.18,.17))

func basket_accessible()->bool:
	return basket_carried or near(clerk.basket.body.global_position,BASKET_REACH)

func basket_aimed()->bool:
	var center:Vector3=clerk.basket.body.to_global(Vector3(0,.18,0))
	return near(center,BASKET_REACH) and aimed(center,.29)<INF

func refresh_supply_buttons():
	var in_play:bool=not coop_panel.connected and not coop_panel.visible and not (desktop_overlay and desktop_overlay.visible) and not basket_panel.get_parent().visible and not checkout_panel.get_parent().visible
	basket_button.visible=in_play and basket_accessible()
	checkout_button.visible=in_play and can_serve_customer()
	basket_button.text=("Panier en main (%d)" if basket_carried else "Panier (%d)")%clerk.basket.items.size()
	basket_button.disabled=action_busy()
	lock_button.hide()
	flip_button.visible=in_play and game.held!=null and not clerk.inspection.opened and clerk.inspection.finger<0
	flip_button.disabled=action_busy()
	flip_button.text="Voir la couverture" if game.held_back else "Voir le dos"
	if not in_play or not game.held or clerk.inspection.opened:return
	var locked:bool=game.held.get_meta("antitheft",false)
	lock_button.visible=near(DETACHER) if locked else spare_carried or near(clerk.lock_bin)
	lock_button.disabled=action_busy()
	lock_button.text="Retirer l’antivol" if locked else "Poser l’antivol"

func open_basket():
	if action_busy() or not basket_accessible():return
	if clerk.inspection.opened:
		game._message("Referme le boîtier avant d’utiliser le panier.")
		return
	motion=Vector2.ZERO
	move_touch=-1
	look_touch=-1
	operations.get_parent().hide()
	checkout_panel.get_parent().hide()
	for child in basket_panel.get_children():
		basket_panel.remove_child(child)
		child.queue_free()
	var heading:=Label.new()
	heading.text="Panier à ranger · %d / %d"%[clerk.basket.items.size(),clerk.basket.CAPACITY]
	heading.add_theme_font_size_override("font_size",24)
	basket_panel.add_child(heading)
	if game.held:
		add_button(basket_panel,"Mettre le boîtier dans le panier",put_in_basket)
	if clerk.basket.items.is_empty():
		var empty:=Label.new()
		empty.text="Le panier est vide."
		basket_panel.add_child(empty)
	else:
		var scroll:=ScrollContainer.new()
		scroll.custom_minimum_size=Vector2(380,290)
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		basket_panel.add_child(scroll)
		var list:=VBoxContainer.new()
		list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		for item in clerk.basket.items:
			var entry:Dictionary=item
			var title_text:String=game.layout.movies[entry.movie].title
			var button:=add_button(list,title_text,pick_from_basket.bind(entry))
			button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			button.disabled=game.held!=null
	var controls:=HBoxContainer.new()
	basket_panel.add_child(controls)
	add_button(controls,"Poser le panier" if basket_carried else "Prendre le panier",toggle_basket_carry)
	add_button(controls,"Fermer",basket_panel.get_parent().hide)
	basket_panel.get_parent().show()

func toggle_basket_carry():
	if action_busy() or not basket_accessible():return
	var body:RigidBody3D=clerk.basket.body
	if basket_carried:
		var forward:Vector3=-game.head.global_basis.z
		forward.y=0
		var position:Vector3=game.head.global_position+forward.normalized()*.62
		var query:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*.22,position-Vector3.UP*2.3,1)
		var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.normal.y<.7:
			game._message("Place-toi devant une surface libre pour poser le panier.")
			return
		body.reparent(clerk.basket)
		body.global_transform=Transform3D(Basis(Vector3.UP,game.origin.rotation.y),hit.position+Vector3.UP*.023)
		body.collision_layer=8
		body.collision_mask=1|8
		basket_carried=false
		game._message("Panier posé.")
	else:
		basket_resting_pose=body.global_transform
		body.freeze=true
		body.collision_layer=0
		body.collision_mask=0
		body.reparent(game.head,false)
		body.transform=Transform3D(Basis(Vector3.UP,.10),Vector3(-.35,-.43,-.77))
		basket_carried=true
		game._message("Panier en main. Ouvre-le pour choisir un boîtier ou le poser.")
	basket_panel.get_parent().hide()

func pick_from_basket(item:Dictionary):
	if action_busy() or game.held or clerk.inspection.finger>=0 or not basket_accessible():return
	if item not in clerk.basket.items:return
	basket_panel.get_parent().hide()
	pick_touch_case(item)
	var name_text:String=game.layout.movies[item.movie].title
	var next:="Vérifie et scanne le retour." if item.kind=="return" and not item.scanned else "Range-le dans son rayon."
	if not item.node.get_meta("antitheft",false):next+=" Pose une barre jaune au comptoir avant de le ranger."
	game._message(name_text+" · "+next)

func pick_touch_case(item:Dictionary):
	var origin:Vector3=item.node.global_position
	clerk.pick_case(item,CASE_HAND,false)
	if game.held!=item.node:return
	if item in clerk.basket.items:
		clerk.basket.items.erase(item)
		clerk.basket.arrange()
	animate_pick(origin)
	game._play_trailer(item.movie)

func put_in_basket():
	if action_busy() or not game.held or not basket_accessible():return
	basket_panel.get_parent().hide()
	var held_case:Node3D=game.held
	place_held_case(clerk.basket.body.to_global(Vector3(0,.16,0)))
	if game.held!=held_case:game._message("Boîtier mis dans le panier.")

func refresh_action(over_desktop:bool):
	var inspection=clerk.inspection
	var label:="Viser un objet"
	var hint:=""
	var item:Dictionary=pointed_item() if not game.held else {}
	var cash:=cash_target()
	mark_touch_target(cash,item,over_desktop)
	if target_customer() and clerk.tender_received and clerk.wallet.occupied(CASH_HAND):label="Rendre la monnaie"
	elif target_customer() and can_handoff():label="Remettre le film"
	elif basket_aimed():label="Mettre au panier" if game.held else "Ouvrir le panier"
	elif over_desktop:label="Ouvrir l’ordi"
	elif not cash.is_empty():
		label={"tender":"Prendre l’argent","money":"Prendre","drawer":"Tiroir","give_change":"Rendre la monnaie","deposit":"Déposer en caisse","loose_money":"Ramasser","select_cash":"Choisir"}.get(cash.action,"Utiliser")
	elif inspection.finger>=0:
		label="Retourner" if aimed(inspection.carried.global_position,.083)<INF else ("Déposer le disque" if not inspection.opened else "Remettre le disque")
	elif game.held:
		if aimed(clerk.scanner.global_position,.24)<INF:label="Scanner"
		elif aimed(DETACHER,.20)<INF:label="Antivol"
		elif inspection.opened and is_instance_valid(inspection.disc) and aimed(inspection.disc.global_position,.085)<INF:label="Sortir le disque"
		else:label="Utiliser"
		hint=str(game.layout.movies[game.movie_id].title) if game.movie_id>=0 else ""
	elif not item.is_empty():
		label="Prendre"
		hint=str(game.layout.movies[item.movie].title)
	else:
		label="Utiliser"
	primary_button.text=label
	case_button.text="Ranger le disque" if inspection.finger>=0 else ("Fermer" if inspection.opened else "Ouvrir")
	case_button.disabled=not game.held and inspection.finger<0
	drop_button.text="Déposer"
	drop_button.disabled=not game.held and not clerk.wallet.occupied(CASH_HAND) and not is_instance_valid(game.candy.held_balls[0])
	action_hint.text=hint

func case_action():
	if clerk.inspection.finger>=0:use_disc()
	else:toggle_case()

func toggle_case():
	if action_busy():return
	if not game.held:
		game._message("Prends un boîtier.")
		return
	if clerk.inspection.finger>=0 and clerk.inspection.opened:
		game._message("Remets le disque avant de fermer.")
		return
	clerk.inspection.toggle_case()
	if clerk.inspection.opened:clerk.inspection.finish_lid(true)

func flip_item():
	if action_busy():return
	if clerk.inspection.finger>=0:disc_back=not disc_back
	elif not clerk.inspection.opened:game._flip_held()

func use_disc():
	if action_busy():return
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
	if clerk.wallet.occupied(CASH_HAND):
		game._message("Libère ta main gauche pour prendre le disque.")
		return
	if inspection.opened and is_instance_valid(inspection.disc):
		inspection.take_open_disc(CASH_HAND)
	elif near(clerk.repairs.station) and aimed(clerk.repairs.station,.25)<INF:
		clerk.repairs.take_disc(inspection,CASH_HAND,clerk.repairs.station)
	else:
		for loose in inspection.loose_discs:
			if aimed(loose.node.global_position,.13)<INF:
				inspection.take_loose_disc(loose,CASH_HAND)
				return

func scan():
	if action_busy() or not game.held or clerk.inspection.opened:return
	if not near(clerk.scanner.global_position):
		game._message("Approche-toi du scanner du comptoir.")
		return
	var item:Node3D=game.held
	var hand:int=game.held_hand
	var rest:=hand_rest(hand)
	var scanner_direction:Vector3=clerk.scanner.direction
	var facing:=Basis.looking_at(-scanner_direction,Vector3.UP)
	var center:Vector3=clerk.scanner.global_position+scanner_direction*.23-facing*Vector3(0,-.045,-.008)
	var hand_basis:=facing*item.basis.inverse()
	begin_motion()
	tween_hand(action_motion,hand,Transform3D(hand_basis,center+Vector3(.095,0,0)),.26)
	tween_hand(action_motion,hand,Transform3D(hand_basis,center),.16)
	action_motion.tween_callback(func():
		if is_instance_valid(item) and game.held==item and clerk.scan_held():
			clerk.scanner.flash=.16
			clerk.scanner.sound.play()
	)
	tween_hand(action_motion,hand,Transform3D(hand_basis,center-Vector3(.09,0,0)),.15)
	tween_hand(action_motion,hand,rest,.25)

func use_lock():
	if action_busy() or not game.held or clerk.inspection.opened:return
	if game.held.get_meta("antitheft",false):
		if not near(DETACHER):
			game._message("Approche-toi du détacheur pour retirer la barre.")
			return
		animate_unlock(game.held)
		return
	if not spare_carried and near(clerk.lock_bin):take_spare()
	if not spare_carried:
		game._message("Approche-toi du bac des barres jaunes pour poser un antivol.")
		return
	spare_carried=false
	clerk.locks.set_locked(game.held,true)
	clerk.refresh_terminal()
	game._message("Antivol posé. Tu peux aller ranger le boîtier.")

func animate_unlock(item:Node3D):
	var hand:int=game.held_hand
	var other:=1-hand
	var rest:=hand_rest(hand)
	var free_rest:=hand_rest(other)
	var facing:Basis=game.head.global_basis.orthonormalized()
	var object_basis:=Basis(Vector3.UP,facing.get_euler().y+PI*.27)
	var aligned:=Transform3D(object_basis*item.basis.inverse(),DETACHER+Vector3(0,.08,0))
	var latch:=aligned.origin+object_basis*Vector3(.061,-.087,.018)
	var pull:=Vector3.DOWN*.145
	begin_motion()
	action_support_hand=other
	tween_hand(action_motion,hand,aligned,.28)
	tween_hand(action_motion,other,Transform3D(facing,latch),.18)
	tween_hand(action_motion,other,Transform3D(facing,latch+pull),.21)
	var bar:=item.get_node_or_null("Antitheft") as Node3D
	if bar:action_motion.parallel().tween_property(bar,"position:y",-.145,.21)
	action_motion.tween_callback(func():
		if is_instance_valid(item) and game.held==item:
			clerk.locks.set_locked(item,false)
			clerk.locks.put_in_bin(clerk.locks.create_bar())
			clerk.refresh_terminal()
	)
	tween_hand(action_motion,hand,rest,.27)
	action_motion.parallel().tween_property(game.hands[other],"global_transform",free_rest,.27).set_trans(Tween.TRANS_SINE)

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

func can_serve_customer()->bool:
	if coop_panel.connected or clerk.active.is_empty():return false
	var offset:Vector3=game.head.global_position-clerk.drawer.global_position
	return near(clerk.customer_hand(),1.65) or Vector2(offset.x,offset.z).length()<2.0

func can_handoff()->bool:
	return game.held!=null and not clerk.active.is_empty() and clerk.held_service.get("kind","")=="rental"

func target_customer()->bool:
	if not can_serve_customer():return false
	var customer:Vector3=clerk.active.node.global_position
	return aimed(clerk.customer_hand(),.32)<INF or aimed(customer+Vector3.UP*1.23,.34)<INF or aimed(customer+Vector3.UP*1.53,.29)<INF

func handoff():
	if action_busy() or not can_serve_customer():return
	if clerk.inspection.opened:
		game._message("Remets le disque et referme le boîtier avant de le donner.")
		return
	if not can_handoff():
		game._message("Prends en main un film ou un jeu de ce client.")
		return
	checkout_panel.get_parent().hide()
	clerk.action("handoff",game.held_hand)

func drop():
	if action_busy():return
	if is_instance_valid(game.candy.held_balls[0]):
		var body:RigidBody3D=game.candy.held_balls[0]
		game.candy.release_ball(0)
		body.linear_velocity=-game.head.global_basis.z*3.0+Vector3.UP
		return
	if not game.held:
		if clerk.wallet.occupied(CASH_HAND):give_change()
		return
	var destination:=case_drop_target()
	if not destination.is_finite():
		var counter:=Vector3(-.11,1.20,-6.20)
		if near(counter):
			destination=counter
		else:
			var forward:Vector3=-game.head.global_basis.z
			forward.y=0
			destination=game.head.global_position+forward.normalized()*.64
			destination.y=maxf(.23,destination.y-.40)
	place_held_case(destination)

func case_drop_target()->Vector3:
	var tray:=Vector3(1.75,1.19,-5.92)
	if near(tray,1.8) and aimed(tray,.32)<INF:return tray
	var basket_point:Vector3=clerk.basket.body.to_global(Vector3(0,.16,0))
	if near(basket_point,1.8) and aimed(basket_point,.30)<INF:return basket_point
	var record:Dictionary=clerk.held_service.get("record",{})
	if not record.is_empty() and near(record.world.origin,1.45) and aimed(record.world.origin,.23)<INF:
		return record.world.origin
	var table:=table_point(.93)
	if clerk.repairs.is_case_surface(table):return table
	var counter:=table_point(1.18)
	if on_checkout_surface(counter):
		return counter
	return Vector3.INF

func on_checkout_surface(point:Vector3)->bool:
	return point.x>-.36 and point.x<.52 and point.z>-6.53 and point.z<-6.06 and point.y>=1.17 and point.y<=1.21

func place_held_case(destination:Vector3):
	if clerk.inspection.opened:
		game._message("Referme le boîtier avant de le déposer.")
		return
	if on_checkout_surface(destination) and not clerk.held_service.is_empty():
		var item:RigidBody3D=game.held
		item.reparent(clerk)
		item.global_transform=Transform3D(Basis(Vector3.RIGHT,-PI/2),destination)
		item.freeze=true
		clerk.clear_hand()
		game._message("Boîtier posé sur le comptoir.")
		sync_hands()
		return
	game.held.global_position=destination
	if clerk.repairs.is_case_surface(destination) and not clerk.held_service.is_empty():
		if clerk.repairs.place_case(clerk.held_service):return
	game._release()
	sync_hands()

func table_point(height:float)->Vector3:
	var start:Vector3=game.head.global_position
	var direction:Vector3=-game.aim_hands[0].global_basis.z if tap_aim else -game.head.global_basis.z
	if direction.y>=-.08:return Vector3.INF
	var distance:float=(height-start.y)/direction.y
	return start+direction*distance if distance>0 and distance<1.7 else Vector3.INF

func open_desktop():
	motion=Vector2.ZERO
	move_touch=-1
	look_touch=-1
	if not desktop_overlay:
		desktop_overlay=ColorRect.new()
		desktop_overlay.color=Color(.025,.035,.055,.96)
		desktop_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		buttons.add_child(desktop_overlay)
		desktop_view=TextureRect.new()
		desktop_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		desktop_view.texture=clerk.desktop.get_viewport().get_texture()
		desktop_overlay.add_child(desktop_view)
		desktop_view.gui_input.connect(desktop_input)
		var close:=Button.new()
		close.text="Fermer"
		close.custom_minimum_size=Vector2(100,52)
		close.position=Vector2(12,12)
		close.pressed.connect(func():desktop_overlay.hide();clerk.desktop.point(Vector2(-1,-1)))
		desktop_overlay.add_child(close)
	var bounds:=get_viewport().get_visible_rect().size
	var height:=minf(bounds.y-18,(bounds.x-118)*.75)
	desktop_view.size=Vector2(height/.75,height)
	desktop_view.position=(bounds-desktop_view.size)*.5+Vector2(48,0)
	desktop_overlay.show()

func desktop_input(event:InputEvent):
	if event is InputEventScreenTouch:
		desktop_view.accept_event()
		if event.pressed:
			var point:Vector2=event.position/desktop_view.size*clerk.desktop.size
			clerk.desktop.point(point,true)

func cash_target()->Dictionary:
	var candidate:Dictionary={}
	var best:=INF
	for target in clerk.targets:
		if target.action not in ["tender","money","drawer"]:continue
		if target.action=="tender" and not clerk.tender_note.visible:continue
		if target.action=="money" and (not clerk.drawer_open or not clerk.tender_received or int(clerk.till.get(target.value,0))<=0):continue
		var position:Vector3=target.node.global_position
		if not near(position):continue
		var depth:=aimed(position,minf(target.radius+.022,.14))
		if depth==INF:continue
		var ray:Vector3=-game.aim_hands[0].global_basis.z
		var distance:float=(position-game.head.global_position-ray*depth).length()+depth*.02
		if distance<best:
			candidate=target
			best=distance
	for entry in clerk.wallet.loose:
		var depth:=aimed(entry.node.global_position,.055)
		if depth==INF:continue
		var ray:Vector3=-game.aim_hands[0].global_basis.z
		var distance:float=(entry.node.global_position-game.head.global_position-ray*depth).length()+depth*.02
		if distance<best and near(entry.node.global_position):
			candidate={"action":"loose_money","node":entry.node,"entry":entry}
			best=distance
	if clerk.wallet.occupied(CASH_HAND) and clerk.drawer_open and near(clerk.drawer.global_position):
		if aimed(clerk.drawer.global_position,.29)<INF and (selected_cash or has_tender_in_hand()):
			candidate={"action":"deposit","node":clerk.drawer}
	if tap_aim:
		var picked:Node3D
		var gap:=INF
		var ray:Vector3=-game.aim_hands[0].global_basis.z
		for entry in clerk.wallet.palms[CASH_HAND]:
			var piece:Node3D=entry.node
			var depth:=aimed(piece.global_position,.028 if entry.value<500 else .055)
			if depth==INF:continue
			var distance:float=(piece.global_position-game.head.global_position-ray*depth).length()
			if distance<gap:
				picked=piece
				gap=distance
		if picked:return {"action":"select_cash","node":picked}

	return candidate

func refresh_cash_panel():
	var entries:Array=clerk.wallet.palms[CASH_HAND]
	var signature:Array=entries.map(func(entry):return entry.node)
	if selected_cash not in signature:selected_cash=null
	cash_panel.visible=not entries.is_empty() and not get_tree().paused and not (desktop_overlay and desktop_overlay.visible)
	cash_total.text="Main gauche   %.2f $"%(clerk.wallet.total(CASH_HAND)/100.0)
	if selected_cash:
		for entry in entries:
			if entry.node==selected_cash:
				cash_total.text+="   ·   Remettre %.2f $"%(entry.value/100.0)
				break
	if signature==cash_signature:return
	cash_signature=signature
	for child in cash_pieces.get_children():
		cash_pieces.remove_child(child)
		child.queue_free()
	var grouped:Dictionary={}
	var counts:Dictionary={}
	for entry in entries:
		grouped[entry.value]=entry.node
		counts[entry.value]=int(counts.get(entry.value,0))+1
	var values:=grouped.keys()
	values.sort()
	for value in values:
		var piece:Node3D=grouped[value]
		var count:int=counts[value]
		var button:=Button.new()
		button.text=("%.2f $"%(value/100.0))+(" ×%d"%count if count>1 else "")
		button.custom_minimum_size=Vector2(56,42)
		button.pressed.connect(func():select_cash(piece))
		cash_pieces.add_child(button)

func select_cash(piece:Node3D):
	if action_busy():return
	if selected_cash==piece:
		selected_cash=null
		return
	selected_cash=piece
	for entry in clerk.wallet.palms[CASH_HAND]:
		if entry.node==piece:
			game._message("%.2f $ sélectionné. Touche le tiroir pour remettre cette pièce ou ce billet."%(entry.value/100.0))
			break

func has_tender_in_hand()->bool:
	for entry in clerk.wallet.palms[CASH_HAND]:
		if entry.tender:return true
	return false

func use_cash(target:Dictionary):
	match target.action:
		"tender":take_payment()
		"money":take_denomination(target.value,target.node.global_position)
		"drawer":clerk.action("drawer",CASH_HAND)
		"deposit":deposit_payment()
		"select_cash":select_cash(target.node)
		"loose_money":
			var source:Vector3=target.node.global_position
			if clerk.wallet.pick_loose(CASH_HAND,target.entry):animate_cash_pick(source)

func animate_cash_pick(source:Vector3):
	var rest:=hand_rest(CASH_HAND)
	begin_motion()
	action_support_hand=CASH_HAND
	game.hands[CASH_HAND].global_transform=Transform3D(rest.basis,source+Vector3.UP*.045)
	tween_hand(action_motion,CASH_HAND,rest,.30)

func take_denomination(value:int,source:Vector3):
	if action_busy():return
	var count:int=clerk.wallet.palms[CASH_HAND].size()
	clerk.wallet.take(CASH_HAND,value)
	if clerk.wallet.palms[CASH_HAND].size()>count:animate_cash_pick(source)

func take_payment():
	if action_busy() or not (near(clerk.tender_note.global_position) or can_serve_customer()):return
	var start:int=clerk.wallet.palms[CASH_HAND].size()
	while clerk.tender_note.visible and clerk.wallet.palms[CASH_HAND].size()<32:
		var count:int=clerk.wallet.palms[CASH_HAND].size()
		clerk.wallet.take(CASH_HAND,clerk.tender,true)
		if clerk.wallet.palms[CASH_HAND].size()==count:break
	if clerk.wallet.palms[CASH_HAND].size()>start:animate_cash_pick(clerk.tender_note.global_position)

func deposit_payment(all_tender:bool=false):
	if action_busy() or not clerk.drawer_open:return
	if not near(clerk.drawer.global_position) and not (all_tender and can_serve_customer()):return
	if all_tender:selected_cash=null
	var entries:Array=clerk.wallet.palms[CASH_HAND]
	var pieces:Array[Node3D]=[]
	for entry in entries:
		if (is_instance_valid(selected_cash) and entry.node==selected_cash) or (not is_instance_valid(selected_cash) and entry.tender):
			pieces.append(entry.node)
	if pieces.is_empty():
		game._message("Choisis une pièce ou un billet dans ta main gauche.")
		return
	var destination:Vector3=clerk.drawer.global_position+Vector3.UP*.12
	if pieces.size()==1:
		for entry in entries:
			if entry.node!=pieces[0]:continue
			for target in clerk.targets:
				if target.action=="money" and target.value==entry.value:
					destination=target.node.global_position+Vector3.UP*.08
					break
	var rest:=hand_rest(CASH_HAND)
	begin_motion()
	action_support_hand=CASH_HAND
	tween_hand(action_motion,CASH_HAND,Transform3D(rest.basis,destination),.32)
	action_motion.tween_callback(func():
		for index in range(entries.size()-1,-1,-1):
			if entries[index].node in pieces:clerk.wallet.remove_one(CASH_HAND,index,true)
		selected_cash=null
	)
	tween_hand(action_motion,CASH_HAND,rest,.24)

func open_change():
	if not can_serve_customer() or not clerk.tender_received:return
	if not clerk.drawer_open:clerk.action("drawer",CASH_HAND)
	checkout_panel.get_parent().hide()
	operations.get_parent().hide()
	var change:=make_panel()
	var denominations:=GridContainer.new()
	denominations.columns=3
	change.add_child(denominations)
	for value in [1,5,10,25,100,200,500,1000,2000,5000]:
		var cents:int=value
		add_button(denominations,"%.2f $"%(cents/100.0),func():
			change.get_parent().queue_free()
			for target in clerk.targets:
				if target.action=="money" and target.value==cents:
					take_denomination(cents,target.node.global_position)
					break)
	add_button(change,"Fermer",change.get_parent().queue_free)
	change.get_parent().show()

func open_checkout():
	if action_busy() or not can_serve_customer():return
	basket_panel.get_parent().hide()
	operations.get_parent().hide()
	motion=Vector2.ZERO
	move_touch=-1
	look_touch=-1
	for child in checkout_panel.get_children():
		checkout_panel.remove_child(child)
		child.queue_free()
	var status_label:=Label.new()
	status_label.text="Caisse  ·  Total %.2f $  ·  Donné %.2f $"%[clerk.price/100.0,clerk.tender/100.0]
	checkout_panel.add_child(status_label)
	if clerk.tender_note.visible:
		add_button(checkout_panel,"Prendre le paiement",take_payment)
	if has_tender_in_hand():
		add_button(checkout_panel,"Déposer le paiement dans le tiroir",func():
			if not clerk.drawer_open:clerk.action("drawer",CASH_HAND)
			deposit_payment(true)
		)
	if clerk.tender_received:
		add_button(checkout_panel,"Choisir les pièces et billets",open_change)
		if clerk.wallet.occupied(CASH_HAND) and not has_tender_in_hand():
			add_button(checkout_panel,"Rendre la monnaie au client",give_change)
	if can_handoff():
		add_button(checkout_panel,"Remettre le boîtier en main",handoff)
	elif not game.held:
		for item in clerk.active.get("items",[]):
			if item.kind!="rental" or item.node.get_meta("customer_animating",false) or not near(item.node.global_position,2.0):continue
			var title_text:String=game.layout.movies[item.movie].title
			var button:=add_button(checkout_panel,"Prendre "+title_text,func():
				checkout_panel.get_parent().hide()
				pick_touch_case(item)
			)
			button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	add_button(checkout_panel,"Fermer",checkout_panel.get_parent().hide)
	checkout_panel.get_parent().show()

func give_change():
	if action_busy() or not can_serve_customer():return
	if not clerk.tender_received:
		open_checkout()
		game._message("Encaisse le paiement avant de rendre la monnaie.")
		return
	if not clerk.wallet.occupied(CASH_HAND):
		if clerk.tender>clerk.price and not clerk.paid:open_change()
		return
	if has_tender_in_hand():
		open_checkout()
		game._message("Dépose le paiement dans le tiroir avant de rendre la monnaie.")
		return
	var customer_id:int=clerk.active.id
	var rest:=hand_rest(CASH_HAND)
	begin_motion()
	action_support_hand=CASH_HAND
	tween_hand(action_motion,CASH_HAND,Transform3D(rest.basis,clerk.customer_hand()+Vector3.UP*.06),.30)
	action_motion.tween_callback(func():
		if clerk.active.get("id",-1)==customer_id:clerk.wallet.give_customer(CASH_HAND)
	)
	tween_hand(action_motion,CASH_HAND,rest,.23)

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
	heading.text="Lobby Wi-Fi · Joueurs disponibles"
	lobby_panel.add_child(heading)
	var notice:=Label.new()
	notice.text=game.lobby.status
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.x=370
	lobby_panel.add_child(notice)
	add_button(lobby_panel,"Mode : inviter" if lobby_invite else "Mode : rejoindre",func():lobby_invite=not lobby_invite;refresh_lobby())
	add_button(lobby_panel,"Disponible sur le Wi-Fi" if game.lobby.available else "Invisible sur le Wi-Fi",game.lobby.toggle_available)
	var players:Array=game.lobby.list_players()
	if players.is_empty():
		var empty:=Label.new()
		empty.text="Aucune partie disponible sur ce Wi-Fi."
		lobby_panel.add_child(empty)
	for i in range(mini(players.size(),5)):
		var index:=i
		add_button(lobby_panel,players[i].name,func():game.lobby.request(index,lobby_invite))
	if not game.lobby.incoming.is_empty():
		add_button(lobby_panel,"Accuser réception",func():game.lobby.reply(true))
		add_button(lobby_panel,"Refuser",func():game.lobby.reply(false))
	add_button(lobby_panel,"Retour",func():lobby_panel.get_parent().hide();menu.get_parent().show())
