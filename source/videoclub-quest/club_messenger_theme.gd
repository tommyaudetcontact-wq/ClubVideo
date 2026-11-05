extends RefCounted

static func panel()->StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("e7f2fd")
	style.border_color=Color("387cc4")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_content_margin(side,12)
	return style

static func button(color:String)->StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(color)
	style.border_color=Color("719dc6")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	for side in [SIDE_LEFT,SIDE_RIGHT]:style.set_content_margin(side,10)
	for side in [SIDE_TOP,SIDE_BOTTOM]:style.set_content_margin(side,7)
	return style

static func build()->Theme:
	var theme:=Theme.new()
	theme.default_font_size=20
	for type in ["Label","Button","CheckButton","CheckBox","OptionButton"]:
		theme.set_color("font_color",type,Color("163e68"))
	theme.set_color("font_hover_color","Button",Color("12355b"))
	theme.set_color("font_pressed_color","Button",Color("12355b"))
	theme.set_color("font_disabled_color","Button",Color("8095ac"))
	theme.set_stylebox("panel","PanelContainer",panel())
	theme.set_stylebox("normal","Button",button("f8fcff"))
	theme.set_stylebox("hover","Button",button("d7edff"))
	theme.set_stylebox("pressed","Button",button("bbdaf5"))
	theme.set_stylebox("disabled","Button",button("dce4ec"))
	return theme
