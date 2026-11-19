extends Control
var kind:=""
var texture:Texture2D
var columns:=5
func show_item(item:Dictionary,business) -> void:
	kind=str(item.get("kind",""));texture=null
	var id:=int(item.get("id",-1))
	if kind in ["film","stock"]:
		var movie:int=id if kind=="film" else int(business.state.stock[id].movie)
		texture=load(str(business.game.layout.movies[movie].frontCover).replace("./","res://"))
	elif kind=="shelf":columns=business.state.SHELF_COLUMNS[id] if business.state.SHELF_COLUMNS.size()>id else 5
	queue_redraw()
func _draw() -> void:
	if texture:
		draw_texture_rect(texture,Rect2(13,2,34,49),false)
		return
	if kind=="shelf":
		var width:float=28+minf(28,columns*1.7)
		draw_rect(Rect2(32-width/2,2,width,50),Color("27394f"))
		for row in 5:draw_rect(Rect2(32-width/2,9+row*9,width,2),Color("c1a474"))
	elif kind=="bundle":
		draw_rect(Rect2(7,17,50,32),Color("b59364"))
		for i in 6:draw_rect(Rect2(12+i*6,6,4,24),Color("314860") if i%2 else Color("a34639"))
	else:
		draw_circle(Vector2(32,17),10,Color("e0b68a"))
		draw_style_box(_style(),Rect2(13,30,38,21))
func _style() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color("4488b9");style.set_corner_radius_all(8);return style
