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
var checkout_popup:PanelContainer
var checkout_scroll:ScrollContainer
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
var move_dragged := false
var look_touch := -1
var look_start := Vector2.ZERO
var look_moved := false
var move_start := Vector2.ZERO
var motion := Vector2.ZERO
var notice_time := 0.0
var last_notice := ""
var original_camera_height := 1.65
var crouching := false
var crouch_button:Button
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
	buttons.theme=preload("res://club_messenger_theme.gd").build()
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
	cash_total.add_theme_font_size_override("font_size",32)
	cash_total.add_theme_color_override("font_color",Color.WHITE)
	var cash_background:=StyleBoxFlat.new()
	cash_background.bg_color=Color(.025,.04,.07,.9)
	cash_background.set_corner_radius_all(8)
	cash_background.content_margin_left=12
	cash_background.content_margin_right=12
	cash_background.content_margin_top=8
	cash_background.content_margin_bottom=8
	cash_total.add_theme_stylebox_override("normal",cash_background)
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
	bar.offset_left=-790
	bar.offset_right=-18
	bar.offset_top=-86
	bar.offset_bottom=-16
	bar.add_theme_constant_override("separation",8)
	buttons.add_child(bar)
	primary_button=add_button(bar,"Utiliser",use_target)
	primary_button.custom_minimum_size.x=178
	primary_button.add_theme_stylebox_override("normal",preload("res://club_messenger_theme.gd").button("d1e9ff"))
	case_button=add_button(bar,"Boîtier",case_action)
	drop_button=add_button(bar,"Déposer",drop)
	add_button(bar,"Outils",toggle_operations)
	crouch_button=add_button(bar,"S’accroupir",toggle_crouch)
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
	setup_checkout_scroll()
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
	coop_button.text="Contacts"
	coop_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	coop_button.offset_left=-410
	coop_button.offset_right=-275
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
	add_button(menu,"Sauvegarder",func():
		if coop_panel.connected:coop_panel.send("save")
		else:game.session.save_game()
	)
	var continue_button:=add_button(menu,"Continuer la sauvegarde",continue_solo)
	continue_button.disabled=not FileAccess.file_exists(game.session.save_path) and not FileAccess.file_exists(game.session.save_path+".bak")
	add_button(menu,"Nouvelle partie",confirm_new_game)
	add_button(menu,"Son des bandes-annonces",func():game.modes._activate(7))
	var avatar_button:=add_button(menu,"Avatar : "+game.clerk_model_name(),func():
		game.toggle_clerk_model()
	)
	avatar_button.pressed.connect(func():avatar_button.text="Avatar : "+game.clerk_model_name())
	add_button(menu,"Coop",open_coop)
	
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
	add_button(grid,"S’accroupir / se relever",toggle_crouch)
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
	return move_start if move_touch>=0 else Vector2(145,get_viewport().get_visible_rect().size.y-145)

func update_stick():
	var center:=stick_center()
	stick_base.position=center-stick_base.size*.5
	stick_thumb.position=center+motion*54-stick_thumb.size*.5
	stick_base.visible=move_touch>=0 and move_dragged and not get_tree().paused and not action_busy() and not coop_panel.visible and not basket_panel.get_parent().visible and not checkout_popup.visible and not (desktop_overlay and desktop_overlay.visible)
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
	var title:=PanelContainer.new()
	title.name="MessengerTitle"
	var title_skin:=preload("res://club_messenger_theme.gd").button("397dc5")
	title.add_theme_stylebox_override("panel",title_skin)
	box.add_child(title)
	var header:=HBoxContainer.new()
	title.add_child(header)
	var caption:=Label.new()
	caption.text="●  Vidéo Club Messenger"
	caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	caption.add_theme_font_size_override("font_size",18)
	caption.add_theme_color_override("font_color",Color.WHITE)
	header.add_child(caption)
	var close:=Button.new()
	close.text="×"
	close.custom_minimum_size=Vector2(32,30)
	close.pressed.connect(func():
		panel.hide()
		if game.modes.menu_open:
			if menu and panel==menu.get_parent():toggle_menu()
			elif menu:menu.get_parent().show()
	)
	header.add_child(close)
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
		if not action_busy():
			game.hands[i].global_transform=coop_panel.guest_held_pose() if coop_panel.connected and i==CASE_HAND and not coop_panel.guest_case_id.is_empty() else hand_rest(i)

func show_grip(delta:float):
	for i in range(2):
		var visual:Node3D=game.hand_visuals[i]
		var holding:bool=(is_instance_valid(game.held) and game.held_hand==i) or (coop_panel.connected and i==CASE_HAND and not coop_panel.guest_case_id.is_empty())
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
	checkout_popup.hide()
	action_motion=create_tween()

func animate_pick(origin:Vector3):
	if not game.held or action_busy():return
	var hand:int=game.held_hand
	var rest:=hand_rest(hand)
	if origin.distance_to(rest.origin)<.05:return
	game.hands[hand].global_transform=Transform3D(rest.basis,origin)
	begin_motion()
	tween_hand(action_motion,hand,rest,.26)

func animate_coop_pickup(origin:Vector3):
	if action_busy():return
	var rest:Transform3D=coop_panel.guest_held_pose()
	begin_motion()
	coop_panel.moving_case=true
	coop_panel.case_animation_pose=Transform3D(rest.basis,origin)
	action_motion.tween_property(coop_panel,"case_animation_pose",rest,.26).set_trans(Tween.TRANS_SINE)
	action_motion.tween_callback(func():coop_panel.moving_case=false)

func animate_coop_counter_action(target:Dictionary):
	var rest:Transform3D=coop_panel.guest_held_pose()
	var working:Transform3D=target.pose
	if target.action=="case_scan":
		var direction:Vector3=clerk.scanner.direction
		working=Transform3D(Basis.looking_at(-direction,Vector3.UP),clerk.scanner.global_position+direction*.23)
	begin_motion()
	coop_panel.moving_case=true
	coop_panel.case_animation_pose=rest
	action_motion.tween_property(coop_panel,"case_animation_pose",working,.27).set_trans(Tween.TRANS_SINE)
	action_motion.tween_callback(func():coop_panel.send(target.action,"",target.get("target","")))
	action_motion.tween_interval(.20)
	action_motion.tween_property(coop_panel,"case_animation_pose",rest,.26).set_trans(Tween.TRANS_SINE)
	action_motion.tween_callback(func():coop_panel.moving_case=false)

func toggle_crouch():
	crouching=not crouching
	crouch_button.text="Se relever" if crouching else "S’accroupir"

func open_coop():
	if game.modes.menu_open:toggle_menu()
	operations.get_parent().hide()
	basket_panel.get_parent().hide()
	checkout_popup.hide()
	motion=Vector2.ZERO
	move_touch=-1
	look_touch=-1
	coop_panel.open_lobby()

func _physics_process(delta:float):
	update_stick()
	coop_button.visible=coop_panel.connected and not coop_panel.visible and not get_tree().paused
	if get_tree().paused:
		hide_coop_guides()
		counter_actions.hide()
		checkout_button.hide()
		basket_button.hide()
		flip_button.hide()
		lock_button.hide()
		if game.modes.menu_open and not menu.get_parent().visible and (not lobby_panel or not lobby_panel.get_parent().visible):menu.get_parent().show()
		return
	show_grip(delta)
	refresh_cash_panel()
	primary_button.get_parent().show()
	if (not coop_panel.connected and clerk.active.is_empty()) or (coop_panel.connected and int(coop_panel.checkout.get("customer",-1))<0):checkout_popup.hide()
	refresh_supply_buttons()
	counter_actions.visible=can_serve_customer() and not (desktop_overlay and desktop_overlay.visible)
	change_button.disabled=action_busy()
	handoff_button.disabled=action_busy()
	if action_busy() or coop_panel.visible or basket_panel.get_parent().visible or checkout_popup.visible or (desktop_overlay and desktop_overlay.visible):
		hide_coop_guides()
		return
	var f:Vector3=-game.head.global_basis.z
	f.y=0
	f=f.normalized()
	game._move_player((f*-motion.y+f.cross(Vector3.UP)*motion.x)*delta*2.40)
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

func hide_coop_guides():
	if not coop_panel.connected:return
	coop_panel.update_shelf_marker(false)
	game.interaction_glow(0).hide()

func _unhandled_input(event:InputEvent):
	if get_tree().paused or action_busy() or coop_panel.visible or basket_panel.get_parent().visible or checkout_popup.visible or (desktop_overlay and desktop_overlay.visible):return
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x<get_viewport().get_visible_rect().size.x*.45 and move_touch<0:
				move_touch=event.index
				move_start=event.position
				move_dragged=false
			elif look_touch<0:
				look_touch=event.index
				look_start=event.position
				look_moved=false
		else:
			if event.index==move_touch:
				var was_dragged:=move_dragged
				move_touch=-1
				move_dragged=false
				motion=Vector2.ZERO
				update_stick()
				if not was_dragged:tap_target(event.position)
			if event.index==look_touch:
				look_touch=-1
				if not look_moved:
					tap_target(event.position)
	elif event is InputEventScreenDrag:
		if event.index==move_touch:
			var offset:Vector2=event.position-move_start
			if offset.length()>8:move_dragged=true
			motion=offset.limit_length(75.0)/75.0 if move_dragged else Vector2.ZERO
			update_stick()
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
	checkout_popup.hide()
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
	checkout_popup.hide()
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
	if get_tree().paused or action_busy() or coop_panel.visible or basket_panel.get_parent().visible or checkout_popup.visible:return
	if tapped_empty_lid():
		toggle_case()
		return
	if has_inspection_disc():
		if not tap_aim:sync_hands()
		var intent:=inspection_disc_action()
		if intent.action=="disc_flip":flip_item()
		else:use_disc(str(intent.get("target","")))
		return
	if coop_panel.connected:
		if not tap_aim:sync_hands()
		var target:=coop_interaction()
		if target.action=="computer":open_desktop()
		elif target.action=="basket_menu":open_basket()
		elif target.action=="cash_take":
			if target.target=="tender":take_payment()
			else:
				var value:=int(target.target)
				for cash_target in clerk.targets:
					if cash_target.action=="money" and cash_target.value==value:
						take_denomination(value,cash_target.node.global_position)
						break
		elif target.action=="cash_pick":
			coop_panel.send("cash_pick","",target.target)
			animate_cash_pick(target.pose.origin)
		elif target.action=="cash_put":deposit_payment()
		elif target.action=="cash_give":give_change()
		elif target.action=="select_cash":select_cash(target.node)
		elif target.action=="case_scan" or target.action=="case_handoff" or (target.action=="case_lock" and target.target=="unlock"):
			animate_coop_counter_action(target)
		elif target.action=="surface_drop":drop_on_surface()
		elif not target.action.is_empty():coop_panel.send(target.action,target.get("id",""),target.get("target",""))
		return
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
			var record:Dictionary=clerk.held_service.get("record",{})
			if destination.is_finite() and (clerk.in_sort_tray(destination) or (not record.is_empty() and destination.distance_to(record.world.origin)<.01)):
				place_held_case(destination)
			elif not drop_on_surface() and destination.is_finite():place_held_case(destination)
		return
	if tap_aim and drop_on_surface():return
	for loose_disc in clerk.inspection.loose_discs:
		if not clerk.wallet.occupied(CASH_HAND) and near(loose_disc.node.global_position,2.0) and aimed(loose_disc.node.global_position,.08)<INF:
			clerk.inspection.take_loose_disc(loose_disc,CASH_HAND)
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
	if coop_panel.connected and coop_panel.basket_carried:return true
	return basket_carried or near(clerk.basket.body.global_position,BASKET_REACH)

func basket_aimed()->bool:
	var center:Vector3=clerk.basket.body.to_global(Vector3(0,.18,0))
	return near(center,BASKET_REACH) and aimed(center,.29)<INF

func refresh_supply_buttons():
	var in_play:bool=not coop_panel.connected and not coop_panel.visible and not (desktop_overlay and desktop_overlay.visible) and not basket_panel.get_parent().visible and not checkout_popup.visible
	basket_button.visible=not coop_panel.visible and not (desktop_overlay and desktop_overlay.visible) and basket_accessible()
	checkout_button.visible=not coop_panel.visible and not (desktop_overlay and desktop_overlay.visible) and can_serve_customer()
	var basket_count:int=clerk.basket.items.size()
	var carrying:bool=basket_carried
	if coop_panel.connected and is_instance_valid(coop_panel.mirror):
		basket_count=coop_panel.mirror.state.get("cases",[]).filter(func(item):return item.in_basket and item.get("basket_owner","host")=="guest").size()
		carrying=coop_panel.basket_carried
	basket_button.text=("Panier en main (%d)" if carrying else "Panier (%d)")%basket_count
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
	if coop_panel.connected:
		open_coop_basket()
		return
	if action_busy() or not basket_accessible():return
	if clerk.inspection.opened:
		game._message("Referme le boîtier avant d’utiliser le panier.")
		return
	motion=Vector2.ZERO
	move_touch=-1
	look_touch=-1
	operations.get_parent().hide()
	checkout_popup.hide()
	for child in basket_panel.get_children():
		if child.name=="MessengerTitle":continue
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
	if not coop_panel.connected and clerk.basket.body.get_meta("guest_held",false):return
	if coop_panel.connected:
		coop_panel.send("basket_carry")
		basket_panel.get_parent().hide()
		return
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
	if coop_panel.connected:
		coop_panel.send("held_basket")
		basket_panel.get_parent().hide()
		return
	if action_busy() or not game.held or not basket_accessible():return
	basket_panel.get_parent().hide()
	var held_case:Node3D=game.held
	place_held_case(clerk.basket.body.to_global(Vector3(0,.16,0)))
	if game.held!=held_case:game._message("Boîtier mis dans le panier.")

func coop_marked(target:Dictionary,pose:Transform3D,bounds:Vector3)->Dictionary:
	target.pose=pose
	target.bounds=bounds
	return target

func coop_interaction()->Dictionary:
	if not coop_panel.guest_disc.is_empty():return inspection_disc_action()
	if clerk.desktop.project_ray(game.aim_hands[0]).x>=0:
		var screen_size:Vector2=clerk.screen.mesh.size
		return coop_marked({"action":"computer","label":"Ouvrir l’ordi"},clerk.screen.global_transform,Vector3(screen_size.x+.012,screen_size.y+.012,.018))
	var money:=coop_cash_target()
	if not money.is_empty():return money
	for target in clerk.targets:
		if target.action!="drawer" or not near(target.node.global_position) or aimed(target.node.global_position,target.radius+.022)==INF:continue
		var label:="Fermer le tiroir" if coop_panel.checkout.get("drawer_open",false) else "Ouvrir le tiroir"
		return coop_marked({"action":"drawer_toggle","label":label},target.node.global_transform,Vector3(.26,.09,.12))
	var holding:bool=not coop_panel.guest_case_id.is_empty()
	if near(clerk.repairs.station) and aimed(clerk.repairs.station,.23)<INF:
		return coop_marked({"action":"disc_use","target":"repair","label":"Surfaceuse"},Transform3D(Basis.IDENTITY,clerk.repairs.station),Vector3(.20,.16,.20))
	if holding:
		if coop_panel.guest_open:
			if tap_aim and aimed(coop_panel.guest_held_pose().origin,.17)==INF and surface_drop_point().is_finite():return {"action":"surface_drop","label":"Déposer ici"}
			var case_node:Node3D=coop_panel.mirror.nodes.get("cases"+coop_panel.guest_case_id) if is_instance_valid(coop_panel.mirror) else null
			if is_instance_valid(case_node):
				var center:Vector3=case_node.to_global(Vector3(0,-.012,.004))
				return coop_marked({"action":"disc_use","label":"Sortir le disque"},Transform3D(case_node.global_basis,center),Vector3(.13,.13,.015))
			return {"action":"disc_use","label":"Sortir le disque"}
		if near(clerk.scanner.global_position) and aimed(clerk.scanner.global_position,.24)<INF:return coop_marked({"action":"case_scan","label":"Scanner"},clerk.scanner.global_transform,Vector3(.22,.17,.18))
		if near(DETACHER) and aimed(DETACHER,.20)<INF:return coop_marked({"action":"case_lock","target":"unlock","label":"Retirer l’antivol"},Transform3D(Basis.IDENTITY,DETACHER),Vector3(.22,.18,.17))
		if near(clerk.lock_bin) and aimed(clerk.lock_bin,.20)<INF:return coop_marked({"action":"case_lock","target":"relock","label":"Poser l’antivol"},Transform3D(Basis.IDENTITY,clerk.lock_bin),Vector3(.23,.16,.22))
		if coop_panel.customer_pos.is_finite() and near(coop_panel.customer_pos) and aimed(coop_panel.customer_pos,.42)<INF:
			return coop_marked({"action":"case_handoff","label":"Remettre le film"},Transform3D(Basis.IDENTITY,coop_panel.customer_pos),Vector3(.24,.19,.20))
		if basket_aimed():return coop_marked({"action":"held_basket","label":"Mettre au panier"},clerk.basket.body.global_transform,Vector3(.46,.27,.39))
		var tray:=Vector3(1.75,1.19,-5.92)
		if near(tray,1.8) and aimed(tray,.32)<INF:
			return coop_marked({"action":"case_sort","label":"Mettre au tri"},Transform3D(Basis.IDENTITY,tray),Vector3(.46,.14,.40))
		if coop_panel.guest_shelf.is_finite() and near(coop_panel.guest_shelf,1.45) and aimed(coop_panel.guest_shelf,.23)<INF:
			var row:Array=coop_panel.mirror.state.get("stock",{}).get(coop_panel.guest_shelf_key,[])
			if row.size()>=5:return coop_marked({"action":"case_rack","label":"Ranger en rayon"},row[4],Vector3(.15,.21,.033))
		if tap_aim and aimed(coop_panel.guest_held_pose().origin,.13)==INF and surface_drop_point().is_finite():return {"action":"surface_drop","label":"Déposer ici"}
		return {"action":"case_flip","label":"Retourner"}
	if is_instance_valid(coop_panel.mirror):
		for entry in coop_panel.mirror.state.get("discs",[]):
			if (entry.get("loose",false) or clerk.repairs.is_sorting_surface(entry.transform.origin)) and near(entry.transform.origin,2.0) and aimed(entry.transform.origin,.10)<INF:
				return coop_marked({"action":"disc_use","target":entry.id,"label":"Prendre le disque"},entry.transform,Vector3(.13,.13,.015))
	for target in clerk.targets:
		if target.action in ["phone","door"] and aimed(target.node.global_position,target.radius)<INF:
			return coop_marked({"action":target.action,"label":"Répondre" if target.action=="phone" else "Porte"},target.node.global_transform,Vector3.ONE*target.radius*1.5)
	if basket_aimed():return coop_marked({"action":"basket_menu","label":"Ouvrir le panier"},clerk.basket.body.global_transform,Vector3(.46,.27,.39))
	var chosen:=coop_case_target()
	if not chosen.is_empty():
		chosen.label="Prendre"
		return chosen
	if tap_aim and (clerk.wallet.occupied(CASH_HAND) or basket_carried) and surface_drop_point().is_finite():return {"action":"surface_drop","label":"Déposer ici"}
	return {"action":"","label":"Viser un objet"}

func coop_cash_target()->Dictionary:
	var entries:Array=clerk.wallet.palms[CASH_HAND]
	if tap_aim:
		for entry in entries:
			if aimed(entry.node.global_position,.04)<INF:
				return coop_marked({"action":"select_cash","node":entry.node,"label":"Choisir cette pièce"},entry.node.global_transform,Vector3(.08,.025,.065))
	if not entries.is_empty():
		if coop_panel.customer_pos.is_finite() and not has_tender_in_hand() and near(coop_panel.customer_pos) and aimed(coop_panel.customer_pos,.42)<INF:
			return coop_marked({"action":"cash_give","label":"Rendre la monnaie"},Transform3D(Basis.IDENTITY,coop_panel.customer_pos),Vector3(.24,.19,.20))
		if coop_panel.checkout.get("drawer_open",false) and near(clerk.drawer.global_position) and aimed(clerk.drawer.global_position,.28)<INF and (is_instance_valid(selected_cash) or has_tender_in_hand()):
			return coop_marked({"action":"cash_put","label":"Déposer en caisse"},clerk.drawer.global_transform,Vector3(.56,.10,.36))
	if is_instance_valid(coop_panel.mirror):
		for entry in coop_panel.mirror.state.get("cash",[]):
			if entry.get("owner","")=="guest" or not near(entry.transform.origin) or aimed(entry.transform.origin,.07)==INF:continue
			var tender:bool=str(entry.id).begins_with("tender")
			return coop_marked({"action":"cash_take" if tender else "cash_pick","target":"tender" if tender else entry.id,"label":"Prendre le paiement" if tender else "Ramasser l’argent"},entry.transform,Vector3(.14,.025,.08))
	if coop_panel.checkout.get("drawer_open",false) and coop_panel.checkout.get("received",false):
		var nearest:=INF
		var result:Dictionary={}
		for target in clerk.targets:
			if target.action!="money" or not near(target.node.global_position):continue
			if int(coop_panel.checkout.get("till",{}).get(str(target.value),0))<=0:continue
			var depth:=aimed(target.node.global_position,minf(target.radius+.022,.14))
			if depth>=nearest:continue
			nearest=depth
			result=coop_marked({"action":"cash_take","target":str(target.value),"label":"Prendre %.2f $"%(int(target.value)/100.0)},target.node.global_transform,Vector3(.14,.025,.08))
		return result
	return {}

func coop_case_target()->Dictionary:
	if not is_instance_valid(coop_panel.mirror):return {}
	var best:=INF
	var result:Dictionary={}
	for item in coop_panel.mirror.state.get("cases",[]):
		if item.held or item.get("busy",false):continue
		var gap:=aimed(item.transform.origin,.115)
		if gap>=best:continue
		best=gap
		result=coop_marked({"id":item.id,"action":"case_pick"},item.transform,Vector3(.15,.21,.033))
	var ray:Node3D=game.aim_hands[CASE_HAND]
	var record:Dictionary=game.shelf_ray(ray.global_position,-ray.global_basis.z,2.2)
	if not record.is_empty() and ray.global_position.distance_to(record.world.origin)<best:
		return coop_marked({"id":coop_panel.mirror.shelf_key(game,record),"action":"shelf_pick"},record.world,Vector3(.15,.21,.033))
	return result

func refresh_action(over_desktop:bool):
	if coop_panel.connected:
		var holding:bool=not coop_panel.guest_case_id.is_empty()
		var target:=coop_interaction()
		primary_button.text=target.label
		var glow:MeshInstance3D=game.interaction_glow(0)
		if target.has("pose"):glow.mark(target.pose,target.bounds)
		else:glow.hide()
		coop_panel.update_shelf_marker(true)
		case_button.text="Ranger le disque" if not coop_panel.guest_disc.is_empty() else ("Fermer" if coop_panel.guest_open else "Ouvrir")
		flip_button.visible=not coop_panel.guest_disc.is_empty() or (holding and not coop_panel.guest_open)
		flip_button.text="Retourner le disque" if not coop_panel.guest_disc.is_empty() else ("Voir la couverture" if coop_panel.guest_flipped else "Voir le dos")
		case_button.disabled=not holding and coop_panel.guest_disc.is_empty()
		drop_button.disabled=not holding and coop_panel.guest_disc.is_empty() and not clerk.wallet.occupied(CASH_HAND)
		action_hint.text=""
		return
	var inspection=clerk.inspection
	var label:="Viser un objet"
	var hint:=""
	var item:Dictionary=pointed_item() if not game.held else {}
	var cash:=cash_target()
	mark_touch_target(cash,item,over_desktop)
	if inspection.finger>=0:label=inspection_disc_action().label
	elif target_customer() and clerk.tender_received and clerk.wallet.occupied(CASH_HAND):label="Rendre la monnaie"
	elif target_customer() and can_handoff():label="Remettre le film"
	elif basket_aimed():label="Mettre au panier" if game.held else "Ouvrir le panier"
	elif over_desktop:label="Ouvrir l’ordi"
	elif not cash.is_empty():
		label={"tender":"Prendre l’argent","money":"Prendre","drawer":"Tiroir","give_change":"Rendre la monnaie","deposit":"Déposer en caisse","loose_money":"Ramasser","select_cash":"Choisir"}.get(cash.action,"Utiliser")
	elif inspection.finger>=0:
		label="Retourner" if aimed(inspection.carried.global_position,.083)<INF else ("Déposer au tri" if disc_sorting_point().is_finite() else "Remettre le disque")
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
	if coop_panel.connected:
		if not coop_panel.guest_disc.is_empty():use_disc()
		else:coop_panel.toggle_guest_case()
		return
	if clerk.inspection.finger>=0:use_disc()
	else:toggle_case()

func toggle_case():
	if action_busy():return
	if coop_panel.connected:
		coop_panel.toggle_guest_case()
		return
	if not game.held:
		game._message("Prends un boîtier.")
		return
	clerk.inspection.toggle_case()
	if clerk.inspection.opened:clerk.inspection.finish_lid(true)

func flip_item():
	if action_busy():return
	if coop_panel.connected:
		coop_panel.send("disc_flip" if not coop_panel.guest_disc.is_empty() else "case_flip")
		return
	if clerk.inspection.finger>=0:disc_back=not disc_back
	elif not clerk.inspection.opened:game._flip_held()

func use_disc(target:String=""):
	if action_busy():return
	if coop_panel.connected:
		coop_panel.send("disc_use","",target)
		return
	var inspection=clerk.inspection
	if inspection.finger>=0:
		if target=="repair":
			if near(clerk.repairs.station):
				inspection.carried.global_position=clerk.repairs.station
				clerk.repairs.insert_disc(inspection)
		elif target=="table":
			var point:=disc_sorting_point()
			if point.is_finite():clerk.repairs.place_disc(inspection,point)
		else:
			if not game.held and is_instance_valid(inspection.source_case):
				for item in clerk.cases:
					if item.node==inspection.source_case and near(item.node.global_position,2.0):
						clerk.pick_case(item,CASE_HAND,false)
						break
			if not game.held:
				game._message("Prends un boîtier vide pour y remettre le disque.")
				return
			if not inspection.opened:
				if game.held.get_meta("antitheft",false):
					game._message("Retire l’antivol avant de remettre le disque.")
					return
				inspection.open_case(game.held)
				inspection.finish_lid(true)
			if inspection.put_carried_in_case():
				disc_back=false
				game._message("Disque remis dans le boîtier. Tu peux le refermer.")
			else:game._message("Ce boîtier contient déjà un disque. Choisis un boîtier vide.")
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
	if coop_panel.connected:
		if not action_busy() and not coop_panel.guest_case_id.is_empty() and near(clerk.scanner.global_position):
			animate_coop_counter_action({"action":"case_scan","pose":clerk.scanner.global_transform})
		return
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
	if coop_panel.connected:
		if action_busy() or coop_panel.guest_case_id.is_empty() or not is_instance_valid(coop_panel.mirror):return
		var node:Node3D=coop_panel.mirror.nodes.get("cases"+coop_panel.guest_case_id)
		if not is_instance_valid(node):return
		if node.get_node_or_null("Antitheft"):
			if near(DETACHER):animate_coop_counter_action({"action":"case_lock","target":"unlock","pose":Transform3D(Basis.IDENTITY,DETACHER)})
		else:coop_panel.send("case_lock","","relock")
		return
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
	if coop_panel.connected:
		coop_panel.send("spare_take")
		return
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
	if coop_panel.connected:
		return coop_panel.customer_pos.is_finite() and (near(coop_panel.customer_pos,1.65) or near(clerk.drawer.global_position,2.0))
	if clerk.active.is_empty():return false
	var offset:Vector3=game.head.global_position-clerk.drawer.global_position
	return near(clerk.customer_hand(),1.65) or Vector2(offset.x,offset.z).length()<2.0

func can_handoff()->bool:
	if coop_panel.connected:
		if coop_panel.guest_case_id.is_empty() or not is_instance_valid(coop_panel.mirror):return false
		return coop_panel.mirror.state.get("cases",[]).any(func(item):return item.id==coop_panel.guest_case_id and item.kind=="rental")
	return game.held!=null and not clerk.active.is_empty() and clerk.held_service.get("kind","")=="rental"

func target_customer()->bool:
	if not can_serve_customer():return false
	var customer:Vector3=clerk.active.node.global_position
	return aimed(clerk.customer_hand(),.32)<INF or aimed(customer+Vector3.UP*1.23,.34)<INF or aimed(customer+Vector3.UP*1.53,.29)<INF

func handoff():
	if coop_panel.connected:
		if action_busy() or not can_serve_customer() or not can_handoff():return
		if coop_panel.guest_open:
			game._message("Referme le boîtier avant de le donner.")
			return
		checkout_popup.hide()
		animate_coop_counter_action({"action":"case_handoff","pose":Transform3D(coop_panel.guest_held_pose().basis,coop_panel.customer_pos)})
		return
	if action_busy() or not can_serve_customer():return
	if clerk.inspection.opened:
		game._message("Remets le disque et referme le boîtier avant de le donner.")
		return
	if not can_handoff():
		game._message("Prends en main un film ou un jeu de ce client.")
		return
	checkout_popup.hide()
	clerk.action("handoff",game.held_hand)

func drop():
	if (coop_panel.connected and not coop_panel.guest_disc.is_empty()) or (not coop_panel.connected and is_instance_valid(clerk.inspection.carried)):
		if disc_sorting_point().is_finite():use_disc("table")
		else:game._message("Vise la table à démêler pour déposer le disque, ou touche Ranger le disque.")
		return
	if coop_panel.connected:
		if clerk.wallet.occupied(CASH_HAND) and coop_panel.guest_case_id.is_empty():
			if coop_panel.checkout.get("drawer_open",false):deposit_payment()
			return
		var tray:=Vector3(1.75,1.19,-5.92)
		if not coop_panel.guest_disc.is_empty() and clerk.repairs.is_sorting_surface(table_point(.93)):
			coop_panel.send("disc_use","","table")
		elif near(tray,1.8) and aimed(tray,.32)<INF:coop_panel.send("case_sort")
		elif coop_panel.guest_shelf.is_finite() and near(coop_panel.guest_shelf,1.45) and aimed(coop_panel.guest_shelf,.23)<INF:
			coop_panel.send("case_rack")
		else:coop_panel.send("case_drop")
		return
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
	if clerk.inspection.opened and not (clerk.in_sort_tray(destination) or clerk.repairs.is_case_surface(destination)):
		game._message("Referme le boîtier avant de le déposer.")
		return
	if on_checkout_surface(destination) and not clerk.held_service.is_empty():
		var item:RigidBody3D=game.held
		if not load("res://club_surface_drop.gd").release_body(item,clerk,destination,game.head.global_position):
			game._message("Ce dépôt est bloqué.")
			return
		clerk.clear_hand()
		game._message("Boîtier posé sur le comptoir.")
		sync_hands()
		return
	game.held.global_position=destination
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
		if child.name=="MessengerTitle":continue
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
		button.custom_minimum_size=Vector2(76,48)
		button.add_theme_font_size_override("font_size",24)
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
	if coop_panel.connected:
		coop_panel.send("cash_take","",str(value))
		animate_cash_pick(source)
		return
	var count:int=clerk.wallet.palms[CASH_HAND].size()
	clerk.wallet.take(CASH_HAND,value)
	if clerk.wallet.palms[CASH_HAND].size()>count:animate_cash_pick(source)

func take_payment():
	if coop_panel.connected:
		if action_busy():return
		coop_panel.send("cash_take","","tender")
		var source:Vector3=clerk.tender_note.global_position
		if is_instance_valid(coop_panel.mirror):
			for entry in coop_panel.mirror.state.get("cash",[]):
				if str(entry.id).begins_with("tender"):
					source=entry.transform.origin
					break
		animate_cash_pick(source)
		return
	if action_busy() or not (near(clerk.tender_note.global_position) or can_serve_customer()):return
	var start:int=clerk.wallet.palms[CASH_HAND].size()
	while clerk.tender_note.visible and clerk.wallet.palms[CASH_HAND].size()<32:
		var count:int=clerk.wallet.palms[CASH_HAND].size()
		clerk.wallet.take(CASH_HAND,clerk.tender,true)
		if clerk.wallet.palms[CASH_HAND].size()==count:break
	if clerk.wallet.palms[CASH_HAND].size()>start:animate_cash_pick(clerk.tender_note.global_position)

func deposit_payment(all_tender:bool=false,all_cash:bool=false):
	if coop_panel.connected:
		if action_busy() or not coop_panel.checkout.get("drawer_open",false):return
		var target:="all" if all_cash else "tender"
		if not all_cash and not all_tender and is_instance_valid(selected_cash):target=str(selected_cash.get_meta("remote_cash_id",""))
		animate_coop_cash("cash_put",target,clerk.drawer.global_position+Vector3.UP*.12)
		return
	if action_busy() or not clerk.drawer_open:return
	if not near(clerk.drawer.global_position) and not (all_tender and can_serve_customer()):return
	if all_tender:selected_cash=null
	var entries:Array=clerk.wallet.palms[CASH_HAND]
	var pieces:Array[Node3D]=[]
	for entry in entries:
		if all_cash or (is_instance_valid(selected_cash) and entry.node==selected_cash) or (not is_instance_valid(selected_cash) and entry.tender):
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
	if coop_panel.connected:
		open_coop_change()
		return
	if not can_serve_customer() or not clerk.tender_received:return
	if not clerk.drawer_open:clerk.action("drawer",CASH_HAND)
	checkout_popup.hide()
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
	resize_checkout()
	if coop_panel.connected:
		open_coop_checkout()
		return
	if action_busy() or not can_serve_customer():return
	basket_panel.get_parent().hide()
	operations.get_parent().hide()
	motion=Vector2.ZERO
	move_touch=-1
	look_touch=-1
	for child in checkout_panel.get_children():
		if child.name=="MessengerTitle":continue
		checkout_panel.remove_child(child)
		child.queue_free()
	var status_label:=Label.new()
	status_label.text="Caisse  ·  Total %.2f $  ·  Donné %.2f $"%[clerk.price/100.0,clerk.tender/100.0]
	status_label.add_theme_font_size_override("font_size",27)
	checkout_panel.add_child(status_label)
	add_cash_help(checkout_panel)
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
				checkout_popup.hide()
				pick_touch_case(item)
			)
			button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	add_button(checkout_panel,"Fermer",checkout_popup.hide)
	checkout_popup.show()

func give_change():
	if coop_panel.connected:
		if not action_busy() and coop_panel.customer_pos.is_finite():animate_coop_cash("cash_give","",coop_panel.customer_pos+Vector3.UP*.06)
		return
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

func animate_coop_cash(action:String,target:String,destination:Vector3):
	if action_busy():return
	var rest:=hand_rest(CASH_HAND)
	begin_motion()
	action_support_hand=CASH_HAND
	tween_hand(action_motion,CASH_HAND,Transform3D(rest.basis,destination),.30)
	action_motion.tween_callback(func():coop_panel.send(action,"",target))
	tween_hand(action_motion,CASH_HAND,rest,.24)

func open_coop_basket():
	if action_busy() or not basket_accessible():return
	if coop_panel.guest_open:
		game._message("Referme le boîtier avant d’utiliser le panier.")
		return
	operations.get_parent().hide()
	checkout_popup.hide()
	motion=Vector2.ZERO
	move_touch=-1
	look_touch=-1
	for child in basket_panel.get_children():
		if child.name=="MessengerTitle":continue
		basket_panel.remove_child(child)
		child.queue_free()
	var heading:=Label.new()
	heading.text="Panier à ranger"
	basket_panel.add_child(heading)
	if not coop_panel.guest_case_id.is_empty():
		add_button(basket_panel,"Mettre le boîtier dans le panier",func():
			coop_panel.send("held_basket")
			basket_panel.get_parent().hide()
		)
	if is_instance_valid(coop_panel.mirror):
		for entry in coop_panel.mirror.state.get("cases",[]):
			if not entry.in_basket or entry.held or entry.get("basket_owner","host")!="guest":continue
			var id:String=entry.id
			var button:=add_button(basket_panel,str(game.layout.movies[entry.movie].title),func():
				coop_panel.send("case_pick",id)
				basket_panel.get_parent().hide()
			)
			button.disabled=not coop_panel.guest_case_id.is_empty()
	add_button(basket_panel,"Poser le panier" if coop_panel.basket_carried else "Prendre le panier",toggle_basket_carry)
	add_button(basket_panel,"Fermer",basket_panel.get_parent().hide)
	basket_panel.get_parent().show()

func open_coop_change():
	if not can_serve_customer() or not coop_panel.checkout.get("received",false):return
	coop_panel.send("drawer")
	checkout_popup.hide()
	var change:=make_panel()
	var heading:=Label.new()
	heading.text="Pièces et billets"
	change.add_child(heading)
	var grid:=GridContainer.new()
	grid.columns=3
	change.add_child(grid)
	for value in [1,5,10,25,100,200,500,1000,2000,5000]:
		var cents:int=value
		var button:=add_button(grid,"%.2f $"%(cents/100.0),func():
			change.get_parent().queue_free()
			take_denomination(cents,clerk.drawer.global_position)
		)
		button.disabled=int(coop_panel.checkout.get("till",{}).get(str(cents),0))<=0
	add_button(change,"Fermer",change.get_parent().queue_free)
	change.get_parent().show()

func open_coop_checkout():
	resize_checkout()
	if action_busy() or not can_serve_customer():return
	basket_panel.get_parent().hide()
	operations.get_parent().hide()
	motion=Vector2.ZERO
	move_touch=-1
	look_touch=-1
	for child in checkout_panel.get_children():
		if child.name=="MessengerTitle":continue
		checkout_panel.remove_child(child)
		child.queue_free()
	var heading:=Label.new()
	heading.text="Caisse · Total %.2f $ · Donné %.2f $"%[int(coop_panel.checkout.get("price",0))/100.0,int(coop_panel.checkout.get("tender",0))/100.0]
	heading.add_theme_font_size_override("font_size",27)
	checkout_panel.add_child(heading)
	add_cash_help(checkout_panel)
	add_button(checkout_panel,"Ouvrir le tiroir",func():coop_panel.send("drawer"))
	if coop_panel.checkout.get("cash_visible",false):add_button(checkout_panel,"Prendre le paiement",take_payment)
	if has_tender_in_hand():
		add_button(checkout_panel,"Déposer le paiement",func():
			animate_coop_cash("cash_put","open_tender",clerk.drawer.global_position+Vector3.UP*.12)
		)
	if coop_panel.checkout.get("received",false):
		add_button(checkout_panel,"Choisir les pièces et billets",open_change)
		if clerk.wallet.occupied(CASH_HAND) and not has_tender_in_hand():add_button(checkout_panel,"Rendre la monnaie",give_change)
	if not coop_panel.guest_case_id.is_empty():
		add_button(checkout_panel,"Remettre le boîtier",func():
			checkout_popup.hide()
			handoff()
		)
	add_button(checkout_panel,"Fermer",checkout_popup.hide)
	checkout_popup.show()

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
		if child.name=="MessengerTitle":continue
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

func tapped_empty_lid()->bool:
	if not tap_aim:return false
	var hinge:Node3D
	if coop_panel.connected:
		if not coop_panel.guest_open or not is_instance_valid(coop_panel.mirror):return false
		var node:Node3D=coop_panel.mirror.nodes.get("cases"+coop_panel.guest_case_id)
		if node:hinge=node.get_node_or_null("MirrorInterior/Hinge")
	else:
		if clerk.inspection.opened:hinge=clerk.inspection.lid
	if not is_instance_valid(hinge):return false
	var aim:Node3D=game.aim_hands[0]
	var origin:Vector3=hinge.to_local(aim.global_position)
	var direction:Vector3=hinge.global_basis.inverse()*(-aim.global_basis.z)
	if absf(direction.z)<.001:return false
	var distance:float=(.003-origin.z)/direction.z
	var hit:Vector3=origin+direction*distance
	return distance>=0 and distance<2 and hit.x>=0 and hit.x<=.135 and absf(hit.y)<=.105

func add_cash_help(panel:Control):
	var label:=Label.new()
	label.text="Paiement → tiroir → choisir la monnaie → client.\nTouche une pièce en main pour la sélectionner, puis le tiroir pour la remettre.\nLe montant à rendre se calcule de tête."
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x=350
	panel.add_child(label)
	if clerk.wallet.occupied(CASH_HAND) and not has_tender_in_hand():
		add_button(panel,"Remettre l’argent en main dans le tiroir",func():
			checkout_popup.hide()
			if coop_panel.connected:animate_coop_cash("cash_put","open_all",clerk.drawer.global_position+Vector3.UP*.12)
			else:
				if not clerk.drawer_open:clerk.action("drawer",CASH_HAND)
				deposit_payment(false,true)
		)

func surface_drop_point()->Vector3:
	var aim:Node3D=game.aim_hands[0]
	return load("res://club_surface_drop.gd").hit(game,aim.global_position,-aim.global_basis.z)

func drop_on_surface()->bool:
	if not tap_aim:return false
	var point:=surface_drop_point()
	if not point.is_finite():return false
	if coop_panel.connected:
		coop_panel.send("surface_drop",str(selected_cash.get_meta("remote_cash_id","")) if is_instance_valid(selected_cash) else "",JSON.stringify([point.x,point.y,point.z]))
		return true
	var dropper=load("res://club_surface_drop.gd")
	if is_instance_valid(clerk.inspection.carried):
		if disc_sorting_point().is_finite():use_disc("table")
		else:game._message("Le disque reste en main : remets-le dans son boîtier ou vise la table à démêler.")
		return true
	elif game.held:
		if clerk.inspection.opened:clerk.inspection.close_case()
		var item:Dictionary=clerk.adopt_held_case() if clerk.held_service.is_empty() else clerk.held_service
		if item.is_empty():return false
		if not dropper.release_body(item.node,clerk,point,game.head.global_position):
			game._message("Pas assez de place pour déposer le boîtier ici.")
			return true
		clerk.clear_hand()
	elif clerk.wallet.occupied(CASH_HAND):
		var entries:Array=clerk.wallet.palms[CASH_HAND]
		if is_instance_valid(selected_cash):
			var selected:Array=entries.filter(func(entry):return entry.node==selected_cash)
			for entry in selected:entries.erase(entry)
			dropper.drop_cash(clerk.wallet,selected,point)
		else:dropper.drop_cash(clerk.wallet,entries,point)
		selected_cash=null
		clerk.wallet.arrange(CASH_HAND)
	elif basket_carried:
		toggle_basket_carry()
		clerk.basket.body.global_position=point
	elif is_instance_valid(game.candy.held_balls[0]):
		var body:RigidBody3D=game.candy.held_balls[0]
		game.candy.release_ball(0)
		body.global_position=point
		body.linear_velocity=Vector3.ZERO
	else:return false
	game._message("Objet déposé à l’endroit touché.")
	return true

func setup_checkout_scroll():
	checkout_popup=checkout_panel.get_parent()
	checkout_popup.remove_child(checkout_panel)
	var shell:=VBoxContainer.new()
	checkout_popup.add_child(shell)
	var title:Node=checkout_panel.get_node("MessengerTitle")
	title.reparent(shell)
	checkout_scroll=ScrollContainer.new()
	checkout_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	checkout_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	shell.add_child(checkout_scroll)
	checkout_scroll.add_child(checkout_panel)
	checkout_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	resize_checkout()

func resize_checkout():
	if not checkout_popup:return
	var size:Vector2=get_viewport().get_visible_rect().size
	var width:float=minf(540,size.x-40)
	var height:float=minf(620,size.y-40)
	checkout_popup.offset_left=-width*.5
	checkout_popup.offset_right=width*.5
	checkout_popup.offset_top=-height*.5
	checkout_popup.offset_bottom=height*.5
	checkout_scroll.scroll_vertical=0

func disc_sorting_point()->Vector3:
	var point:=surface_drop_point()
	if not point.is_finite() or not clerk.repairs.is_sorting_surface(point) or point.y>1.08:return Vector3.INF
	return Vector3(point.x,.916,point.z)

func has_inspection_disc()->bool:
	return not coop_panel.guest_disc.is_empty() if coop_panel.connected else is_instance_valid(clerk.inspection.carried)

func inspection_disc_action()->Dictionary:
	var disc:Node3D=clerk.inspection.carried
	var case_position:Vector3=game.held.global_position if game.held else Vector3.INF
	if coop_panel.connected:
		disc=coop_panel.mirror.nodes.get("discs"+coop_panel.guest_disc) if is_instance_valid(coop_panel.mirror) else null
		case_position=coop_panel.guest_held_pose().origin if not coop_panel.guest_case_id.is_empty() else Vector3.INF
	if tap_aim and disc and aimed(disc.global_position,.09)<INF:return {"action":"disc_flip","label":"Retourner le disque"}
	if tap_aim and case_position.is_finite() and aimed(case_position,.18)<INF:return {"action":"disc_use","label":"Remettre le disque"}
	if near(clerk.repairs.station) and aimed(clerk.repairs.station,.23)<INF:return {"action":"disc_use","target":"repair","label":"Surfaceuse"}
	if disc_sorting_point().is_finite():return {"action":"disc_use","target":"table","label":"Déposer au tri"}
	return {"action":"disc_use","label":"Remettre le disque"}
