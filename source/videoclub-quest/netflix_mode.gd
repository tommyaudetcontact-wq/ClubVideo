extends Node3D
var game
var enabled:=false
var cases:Array=[]
var held_case:Node3D
var held_index:=-1
var held_hand:=-1
var original:Transform3D
var titles=[
 {"title":"Aujourd’hui est un autre jour","id":"80213341","year":"2018"},
 {"title":"La mission","id":"81210670","year":"2021"},
 {"title":"Pour l’amour d’Hollywood","id":"80095365","year":"2016"},
 {"title":"Mes vies de chien","id":"80126335","year":"2017"}]
func setup(g)->void:
	game=g
	name="NetflixExperimentalCases"
	for i in range(titles.size()):
		var c:=Node3D.new()
		c.name="NetflixCase%d"%i
		c.position=Vector3(-1.1+i*.30,1.19,-4.91)
		add_child(c)
		var mesh:=MeshInstance3D.new()
		var box:=BoxMesh.new()
		box.size=Vector3(.135,.19,.014)
		mesh.mesh=box
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=Color("17171c")
		mat.roughness=.42
		mesh.material_override=mat
		c.add_child(mesh)
		var face:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		quad.size=Vector2(.130,.185)
		face.mesh=quad
		face.position.z=.0075
		var cover:=StandardMaterial3D.new()
		cover.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		cover.albedo_texture=load("res://assets/netflix-test/%d.png"%i)
		cover.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		face.material_override=cover
		c.add_child(face)
		for side in [-1]:
			var label:=Label3D.new()
			label.text=("NETFLIX · TEST\n\n"+titles[i].title+"\n"+titles[i].year+"\n\nAudio : français (Canada)") if side==1 else "FICHE EXPÉRIMENTALE\n\nPiste fr-CA indiquée\nsur Netflix.\nDisponibilité à confirmer\ndans votre compte.\n\nGâchette : ouvrir Netflix\nPoignée : reposer"
			label.font_size=30
			label.pixel_size=.00032
			label.width=370
			label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			label.position.z=.008*side
			label.rotation.y=PI if side==-1 else 0.0
			label.modulate=Color("efbebd") if side==1 else Color.WHITE
			c.add_child(label)
		cases.append(c)
	visible=false
func toggle()->void:
	if held_case:put_back()
	enabled=not enabled
	visible=enabled
	if enabled:game._message("Netflix · test : 4 boîtiers au comptoir\nPoignée : prendre · Gâchette : lecteur officiel\nCatalogue du compte non synchronisé")
func put_back()->void:
	held_case.reparent(self,false)
	held_case.global_transform=original
	held_case=null
	held_hand=-1
func interact(hand:int,grip:bool)->bool:
	if not enabled:return false
	if held_case:
		if hand!=held_hand:return true
		if grip:put_back()
		else:OS.shell_open("https://www.netflix.com/ca-fr/title/"+titles[held_index].id)
		return true
	if game.held:return false
	var p:Vector3=game.aim_hands[hand].global_position
	var d:Vector3=-game.aim_hands[hand].global_basis.z
	for i in range(cases.size()):
		var c:Node3D=cases[i]
		var t:float=(c.global_position-p).dot(d)
		var near:bool=game.hands[hand].global_position.distance_to(c.global_position)<.22
		var aimed:bool=t>0 and t<2.5 and (p+d*t).distance_to(c.global_position)<.12
		if (grip and near) or (not grip and aimed):
			original=c.global_transform
			held_case=c
			held_index=i
			held_hand=hand
			c.reparent(game.dvd_grip_anchors[hand],false)
			c.transform=Transform3D.IDENTITY
			game.trailer_player.stop()
			game.active_trailer=-1
			game.screen_picture.visible=true
			game.trailer_banner.text="NETFLIX · LECTEUR OFFICIEL EXTERNE"
			game.screen_title.text=titles[i].title
			game._message(titles[i].title+"\nAudio fr-CA · fiche vérifiée\nGâchette : ouvrir Netflix · Poignée : reposer")
			return true
	return false
