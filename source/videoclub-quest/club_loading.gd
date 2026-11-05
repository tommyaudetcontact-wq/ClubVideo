extends Node3D

const GAME := "res://main.tscn"
const ART := ["res://assets/loading/checkout.png", "res://assets/loading/games.png"]
const TIPS := [
	"Les clients sont patients sans limite. Profite des temps morts entre les rushs pour traiter les retours.",
	"Sur mobile, glisse le pouce dans la partie gauche : le joystick apparaît sous ton doigt.",
	"Les retours arrivent dans la chute. À toi de décider quand vérifier et réparer les disques.",
	"Scanne le dos du boîtier, puis retire la barre jaune avant de le remettre au client.",
	"Vérifie l’état du disque. Si le client revient demander un remboursement, il sera compté dans tes pertes.",
	"Après un retour, remets une barre jaune avant de replacer le boîtier en rayon.",
	"Le panier garde les boîtiers à ranger ensemble. Tu peux en reprendre un à la fois.",
	"Le total et le montant donné sont affichés à la caisse. Utilise les pièces et billets du tiroir pour rendre la monnaie."
]
var ui:Control
var backdrop:TextureRect
var progress:ProgressBar
var status:Label
var tip:Label
var artwork:Array[Texture2D]=[]
var art_index:=0
var tip_index:=0
var rotation_time:=0.0
var xr_quad:MeshInstance3D
var xr_view:SubViewport
var prepared_decor:Resource

func _ready():
	build_ui()
	var xr:=XRServer.find_interface("OpenXR")
	var touch:=OS.has_feature("touchgame") or "--touch-profile" in OS.get_cmdline_user_args()
	if not touch and xr and xr.is_initialized():
		build_xr_surface()
	else:
		var layer:=CanvasLayer.new()
		layer.layer=50
		add_child(layer)
		layer.add_child(ui)
	for path in ART:
		if ResourceLoader.exists(path):
			var texture:=load(path) as Texture2D
			if texture:artwork.append(texture)
	art_index=randi_range(0,maxi(0,artwork.size()-1))
	tip_index=randi_range(0,TIPS.size()-1)
	refresh_art()
	await get_tree().process_frame
	await load_game()

func build_ui():
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_STOP
	var base:=ColorRect.new()
	base.color=Color("0b1526")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(base)
	backdrop=TextureRect.new()
	backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(backdrop)
	var shade:=ColorRect.new()
	shade.color=Color(.025,.047,.082,.93)
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top=-183
	ui.add_child(shade)
	var copy:=VBoxContainer.new()
	copy.add_theme_constant_override("separation",8)
	copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	copy.offset_left=34
	copy.offset_right=-34
	copy.offset_top=12
	copy.offset_bottom=-13
	shade.add_child(copy)
	var title:=Label.new()
	title.text="VIDÉO CLUB"
	title.add_theme_font_size_override("font_size",33)
	title.add_theme_color_override("font_color",Color("ffcf83"))
	copy.add_child(title)
	status=Label.new()
	status.text="Ouverture du vidéoclub…"
	status.add_theme_font_size_override("font_size",22)
	copy.add_child(status)
	progress=ProgressBar.new()
	progress.custom_minimum_size.y=14
	progress.show_percentage=false
	var background:=StyleBoxFlat.new()
	background.bg_color=Color("273a51")
	background.set_corner_radius_all(6)
	progress.add_theme_stylebox_override("background",background)
	var fill:=StyleBoxFlat.new()
	fill.bg_color=Color("ffc37b")
	fill.set_corner_radius_all(6)
	progress.add_theme_stylebox_override("fill",fill)
	copy.add_child(progress)
	tip=Label.new()
	tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size",19)
	copy.add_child(tip)

func build_xr_surface():
	get_viewport().use_xr=true
	var origin:=XROrigin3D.new()
	add_child(origin)
	var camera:=XRCamera3D.new()
	origin.add_child(camera)
	camera.current=true
	xr_view=SubViewport.new()
	xr_view.size=Vector2i(1280,720)
	xr_view.disable_3d=true
	xr_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(xr_view)
	xr_view.add_child(ui)
	xr_quad=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(2.30,1.29375)
	xr_quad.mesh=quad
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test=true
	material.albedo_texture=xr_view.get_texture()
	xr_quad.material_override=material
	xr_quad.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(xr_quad)
	xr_quad.position=Vector3(0,0,-1.50)

func follow_camera(camera:Camera3D):
	if is_instance_valid(xr_quad):xr_quad.reparent(camera,false)

func refresh_art():
	if not artwork.is_empty():backdrop.texture=artwork[art_index]
	tip.text="ASTUCE  ·  "+TIPS[tip_index]

func _process(delta:float):
	rotation_time+=delta
	if rotation_time<5.0:return
	rotation_time=0
	if not artwork.is_empty():art_index=(art_index+1)%artwork.size()
	tip_index=(tip_index+1)%TIPS.size()
	refresh_art()

func stage(value:float,message:String):
	progress.value=maxf(progress.value,value)
	status.text=message
	await get_tree().process_frame
	await get_tree().process_frame

func load_game():
	var scene:=await load_resource(GAME,0.0,12.0) as PackedScene
	if not scene:
		status.text="Impossible de charger le niveau."
		return
	var pc:=OS.has_feature("pcvr") or "--pcvr-profile" in OS.get_cmdline_user_args()
	var baked_path:="res://assets/lighting-v3/decor-lit.scn"
	var decor_path:=baked_path if not pc and ResourceLoader.exists(baked_path) else "res://assets/decor.glb"
	status.text="Chargement du décor et de l’éclairage…"
	prepared_decor=await load_resource(decor_path,12.0,40.0)
	if not prepared_decor:
		status.text="Impossible de charger le décor."
		return
	var game:=scene.instantiate()
	game.set_meta("startup_loader",self)
	game.process_mode=Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(game)
	get_tree().current_scene=game

func load_resource(path:String,start:float,end:float)->Resource:
	if ResourceLoader.load_threaded_request(path)!=OK:return null
	var state:=ResourceLoader.THREAD_LOAD_IN_PROGRESS
	while state==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var steps:Array=[]
		state=ResourceLoader.load_threaded_get_status(path,steps)
		if not steps.is_empty():progress.value=maxf(progress.value,lerpf(start,end,float(steps[0])))
		await get_tree().process_frame
	if state!=ResourceLoader.THREAD_LOAD_LOADED:return null
	return ResourceLoader.load_threaded_get(path)

func finish(game:Node):
	await stage(100.0,"Le vidéoclub est prêt.")
	if is_instance_valid(xr_quad):xr_quad.queue_free()
	game.remove_meta("startup_loader")
	game.process_mode=Node.PROCESS_MODE_INHERIT
	queue_free()
