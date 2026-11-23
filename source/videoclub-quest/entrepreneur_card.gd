extends Control
const COLORS={"action":"b93432","horreur":"592c73","suspense policier":"17625f","science-fiction":"285cb0","comédie":"efc758","cinéma familial":"91d5aa","fantastique":"7052a4","aventure":"cd7132","drame":"8aa5b2","comédie romantique":"e7a6bf","NOUVEAU":"28764a","STANDARD":"cbd9e7","CLASSIQUE":"e8c672"}
var title:=""
var subtitle:=""
var genre:=""
var kind:=""
var cover:Texture2D
static func ink(background:Color) -> Color:
	var linear:=background.srgb_to_linear();var luminance:float=.2126*linear.r+.7152*linear.g+.0722*linear.b
	return Color("101820") if (luminance+.05)/.058>1.05/(luminance+.05) else Color.WHITE
static func pill_color(text:String) -> Color:
	if COLORS.has(text):return Color(COLORS[text])
	return Color.from_hsv(fposmod(float(text.hash())*.61803398875,1.0),.44,.85)
func configure(movie:Dictionary,classification:String,detail:String) -> void:
	title=str(movie.title);genre=str(movie.genre).to_lower();kind=classification;subtitle=detail
	cover=preload("res://cover_textures.gd").get_cover(preload("res://cover_textures.gd").path_for(movie,"front"));queue_redraw()
func _draw() -> void:
	var font:=ThemeDB.fallback_font
	if cover:draw_texture_rect(cover,Rect2(8,4,66,94),false)
	draw_string(font,Vector2(90,33),title,HORIZONTAL_ALIGNMENT_LEFT,605,28,Color("153455"))
	draw_string(font,Vector2(90,59),subtitle,HORIZONTAL_ALIGNMENT_LEFT,605,21,Color("3d5268"))
	var x:=90.0
	for text in [genre,kind]:
		if text.is_empty():continue
		var caption:String=text
		while font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x>360:caption=caption.left(caption.length()-2)+"…"
		var width:float=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x+24
		var style:=StyleBoxFlat.new();var background:=pill_color(text)
		style.bg_color=background;style.set_corner_radius_all(13)
		draw_style_box(style,Rect2(x,69,width,28))
		draw_string(font,Vector2(x+12,90),caption,HORIZONTAL_ALIGNMENT_LEFT,width-24,19,ink(background))
		x+=width+9
