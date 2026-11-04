extends Control

const PROGRAMS := ["Clients", "Tâches", "Retours", "Journée"]
var clerk
var app := 0
var window: Panel
var title: Label
var details: Label
var cursor: Polygon2D
var targets: Array[Button] = []
var hovered: Button

func setup(owner_clerk):
	clerk = owner_clerk
	size = Vector2(1024,768)
	rect(self,Rect2(0,0,1024,768),Color("277fbc"))
	rect(self,Rect2(0,520,1024,208),Color("4e9b48"))
	rect(self,Rect2(0,728,1024,40),Color("1b50bd"))
	for i in range(4):
		var index := i
		button(self,Rect2(18,22+i*94,128,74),PROGRAMS[i],func():open_program(index),Color("214a91"))
	button(self,Rect2(0,728,150,40),"Démarrer",func():open_program(0),Color("3f8e39"))
	button(self,Rect2(155,731,230,34),"Gestion Vidéo Club",func():open_program(maxi(0,app)),Color("3468cc"))
	button(self,Rect2(830,730,190,36),"Coop Wi-Fi",func():open_program(4),Color("347fc1"))
	window=Panel.new()
	window.position=Vector2(164,24)
	window.size=Vector2(834,678)
	add_child(window)
	rect(window,Rect2(0,0,834,678),Color("ece9d8"))
	rect(window,Rect2(0,0,834,50),Color("235dcb"))
	title=label(window,Rect2(18,5,720,43),26,Color.WHITE)
	button(window,Rect2(778,7,46,36),"×",func():window.hide(),Color("b33b27"))
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(18,65)
	scroll.size=Vector2(800,529)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	window.add_child(scroll)
	details=label(scroll,Rect2(0,0,780,0),25,Color("142542"))
	details.custom_minimum_size.x=776
	details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button(window,Rect2(18,614,390,46),"Action du programme",run_action,Color("3561a6"))
	button(window,Rect2(422,614,390,46),"Défiler",func():scroll.scroll_vertical=0 if scroll.scroll_vertical>=scroll.get_v_scroll_bar().max_value-scroll.size.y-4 else scroll.scroll_vertical+310,Color("3561a6"))
	cursor=Polygon2D.new()
	cursor.polygon=PackedVector2Array([Vector2.ZERO,Vector2(0,28),Vector2(7,20),Vector2(14,32),Vector2(19,29),Vector2(12,17),Vector2(23,17)])
	cursor.color=Color("fff3ad")
	cursor.hide()
	add_child(cursor)
	open_program(0)

func rect(parent:Control,bounds:Rect2,color:Color):
	var block:=ColorRect.new()
	block.position=bounds.position
	block.size=bounds.size
	block.color=color
	parent.add_child(block)

func label(parent:Control,bounds:Rect2,font_size:int,color:Color)->Label:
	var item:=Label.new()
	item.position=bounds.position
	item.size=bounds.size
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	parent.add_child(item)
	return item

func button(parent:Control,bounds:Rect2,caption:String,callback:Callable,color:Color):
	var item:=Button.new()
	item.position=bounds.position
	item.size=bounds.size
	item.text=caption
	item.add_theme_font_size_override("font_size",22)
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(6)
	item.add_theme_stylebox_override("normal",style)
	item.pressed.connect(callback)
	parent.add_child(item)
	targets.append(item)

func open_program(index:int):
	app=index
	if index<4:clerk.page=index
	window.show()
	refresh()

func refresh():
	if not details:return
	title.text="Gestion Vidéo Club  /  "+(PROGRAMS[app] if app<4 else "Coop Wi-Fi")
	details.text=clerk.terminal_content(app) if app<4 else clerk.lan.host_status()
	targets[8].text=["Ouvrir le tiroir","Actualiser","Terminer le retour","Clôturer / continuer","Ouvrir / fermer la partie"][app]
	get_viewport().render_target_update_mode=SubViewport.UPDATE_ONCE

func run_action():
	if app==4:
		clerk.lan.toggle_host()
	elif app!=1:
		clerk.page=app
		clerk.action("computer",-1)
	refresh()

func project_ray(ray:Node3D)->Vector2:
	if not clerk.screen:return Vector2(-1,-1)
	var start:Vector3=clerk.screen.to_local(ray.global_position)
	var direction:Vector3=clerk.screen.global_basis.inverse()*(-ray.global_basis.z)
	if absf(direction.z)<.001:return Vector2(-1,-1)
	var distance:float=-start.z/direction.z
	if distance<0 or distance>1.65:return Vector2(-1,-1)
	var point:Vector3=start+direction*distance
	if absf(point.x)>.17 or absf(point.y)>.1225:return Vector2(-1,-1)
	return Vector2(.5+point.x/.34,.5-point.y/.245)*size

func point(pixel:Vector2,click:bool=false)->bool:
	if not cursor:return false
	var inside:=pixel.x>=0
	var next:Button
	if inside:
		for index in range(targets.size()-1,-1,-1):
			var item:=targets[index]
			if item.is_visible_in_tree() and item.get_global_rect().has_point(pixel):
				next=item
				break
	if next!=hovered:
		if hovered:hovered.modulate=Color.WHITE
		hovered=next
		if hovered:hovered.modulate=Color(1.25,1.25,1.25)
	if cursor.visible!=inside or (inside and cursor.position.distance_to(pixel)>1):
		cursor.visible=inside
		cursor.position=pixel
		get_viewport().render_target_update_mode=SubViewport.UPDATE_ONCE
	if click and hovered:hovered.pressed.emit()
	return inside

