extends Node3D

var touch_profile := OS.has_feature("touchgame") or "--touch-profile" in OS.get_cmdline_user_args()
var touch_controls:CanvasLayer
var lobby:Node
var pc_vr := OS.has_feature("pcvr") or "--pcvr-profile" in OS.get_cmdline_user_args()
var COVER_DETAIL_BUDGET := 96 if pc_vr else 48
var COVER_DETAIL_ENTER := 5.0 if pc_vr else 4.0
var COVER_DETAIL_EXIT := 5.8 if pc_vr else 4.6

var layout: Dictionary
var model: Node3D
var baked_lighting_active := false
var teleportation
var candy
var modes
var netflix
var clerk
var origin: XROrigin3D
var head: Camera3D
var hands: Array[XRController3D] = []
var aim_hands: Array[XRController3D] = []
var dvd_grip_anchors: Array[Node3D] = []
var hand_visuals: Array[Node3D] = []
var pointer_beams: Array[MeshInstance3D] = []
var lod_last_forward := Vector3.ZERO
var cover_occluders: Array[AABB] = []
var previous_trigger := [false, false]
var previous_grip := [false, false]
var crouch_offset := 0.0
var dvd_groups: Dictionary = {}
var dvd_records: Array = []
var shell: MultiMeshInstance3D
var held: Node3D
var held_record: Dictionary = {}
var held_hand := -1
var session
var held_by_grip := false
var held_back := false
var flip_tween: Tween
var xr_active := false
var snap_armed := true
var hud: Label3D
var gum: Node3D
var gum_knob: Node3D
var gum_ball: MeshInstance3D
var gum_credit := 0
var gum_busy := false
var gum_ready := false
var gum_served := 0
var gum_stock := 450
var movie_id := -1
var screens: Array[MeshInstance3D] = []
var screen_view: SubViewport
var screen_picture: TextureRect
var screen_title: Label
var trailer_banner: Label
var trailer_player: VideoStreamPlayer
var trailer_streams: Dictionary = {}
var active_trailer := -1
var trailer_timer := 0.0
var screen_timer := 0.0
var elapsed := 0.0
var metrics_timer := 0.0
var cover_info: Array = []
var dvd_atlas_material: StandardMaterial3D
var spawn_centered := false
var recenter_running := false
var frame_times: Array[float] = []
var previous_frame_usec := 0
var frame_ring_cursor := 0
var dvd_grid: Dictionary = {}
var held_pool: Dictionary = {}
var poster_cache: Dictionary = {}
var lod_last_eye := Vector3.INF
var lod_last_examined := 0
var lod_groups: Dictionary = {}
var lod_timer := 0.0
var lod_selected: Dictionary = {}
var xr_interface: XRInterface
var lod_update_usec := 0
var lod_occlusion_tests := 0

func _ready() -> void:
	if pc_vr:
		get_viewport().msaa_3d=Viewport.MSAA_4X
		print("VIDEOCLUB_PC_PROFILE msaa=4x resolution=runtime_recommended covers=96")
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/layout.json"))
	if FileAccess.file_exists("res://assets/covers.json"):
		cover_info = JSON.parse_string(FileAccess.get_file_as_string("res://assets/covers.json"))
	baked_lighting_active = not pc_vr and ResourceLoader.exists("res://assets/lighting-v3/decor-lit.scn")
	model = load("res://assets/lighting-v3/decor-lit.scn" if baked_lighting_active else "res://assets/decor.glb").instantiate()
	add_child(model)
	_restore_instances()
	load("res://catalogue_expansion.gd").expand(self)
	load("res://scene_refresh.gd").remove_rear_shelves(self)
	load("res://clerk_workspace.gd").expand(self)
	load("res://games_catalogue.gd").install(self)
	_prepare_world()
	var exterior := Node3D.new()
	exterior.set_script(load("res://exterior_continuation.gd"))
	add_child(exterior)
	exterior.build(model)
	var fake_glow := Node3D.new()
	fake_glow.set_script(load("res://fake_lighting.gd"))
	add_child(fake_glow)
	_prepare_player()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	teleportation = load("res://teleport_locomotion.gd").new()
	add_child(teleportation)
	teleportation.setup(self)
	_prepare_screens()
	_index_dvds()
	_prepare_cover_lod()
	_prepare_held_pool()
	candy = load("res://gumball_physics.gd").new()
	add_child(candy)
	candy.setup(self)
	modes = load("res://gameplay_modes.gd").new()
	add_child(modes)
	netflix=load("res://netflix_mode.gd").new()
	add_child(netflix)
	netflix.setup(self)
	modes.setup(self)
	load("res://material_relief.gd").apply(model)
	load("res://scene_refresh.gd").apply_surfaces(self)
	load("res://exterior_polish.gd").apply(self)
	var polish=load("res://interior_polish.gd").new()
	add_child(polish)
	polish.setup(self)
	clerk=load("res://clerk_simulator.gd").new()
	add_child(clerk)
	clerk.setup(self)
	lobby=preload("res://club_lobby.gd").new()
	add_child(lobby)
	lobby.setup(self)
	session=load("res://club_save.gd").new()
	add_child(session)
	if touch_profile and not OS.has_feature("android"):session.save_path="user://touch-playtest.dat"
	session.setup(self)
	if touch_profile:
		touch_controls=load("res://touch_game.gd").new()
		add_child(touch_controls)
		touch_controls.setup(self)
	var updater=preload("res://club_update.gd").new()
	add_child(updater)
	updater.setup(self)
	if pc_vr:
		var presentation=load("res://pc_presentation.gd").new()
		add_child(presentation)
		presentation.setup(self)
	print("VIDEOCLUB_READY xr=", xr_active, " dvds=", dvd_records.size(), " screens=", screens.size())
	call_deferred("_play_ambient_trailer")
	if xr_active:
		call_deferred("_recenter_entry")
		call_deferred("_diagnostic_capture")

func _request_refresh_rate() -> void:
	if not pc_vr and xr_interface and xr_interface.has_method("set_display_refresh_rate"):
		xr_interface.call_deferred("set_display_refresh_rate",72.0)

func _restore_instances() -> void:
	dvd_atlas_material = StandardMaterial3D.new()
	dvd_atlas_material.albedo_texture = load("res://assets/dvd-atlas.png")
	dvd_atlas_material.roughness = 0.65
	dvd_atlas_material.metallic_specular = 0.12
	dvd_atlas_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	dvd_atlas_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var groups: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/instances.json"))
	for entry in groups:
		var old = model.find_child(entry.name, true, false)
		if not old and entry.name.begins_with("dvd-"):
			var matches := model.find_children("dvd-"+entry.name.split("-")[1]+"-*", "MeshInstance3D", true, false)
			if not matches.is_empty():
				old = matches[0]
		if not old is MeshInstance3D:
			push_error("Missing instanced mesh: " + entry.name)
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = old.mesh
		if entry.name.begins_with("dvd-"):
			mm.mesh = old.mesh.duplicate()
			for surface in range(mm.mesh.get_surface_count()):
				mm.mesh.surface_set_material(surface,dvd_atlas_material)
		mm.instance_count = entry.translations.size()
		for i in range(mm.instance_count):
			var p: Array = entry.translations[i]
			var q: Array = entry.rotations[i]
			var s: Array = entry.scales[i]
			var basis := Basis(Quaternion(q[0], q[1], q[2], q[3])).scaled(Vector3(s[0], s[1], s[2]))
			mm.set_instance_transform(i, Transform3D(basis, Vector3(p[0], p[1], p[2])))
		var node := MultiMeshInstance3D.new()
		node.name = old.name
		node.multimesh = mm
		node.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		node.transform = old.transform
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var parent := old.get_parent()
		parent.remove_child(old)
		parent.add_child(node)
		old.queue_free()
		if entry.name.begins_with("dvd-"):
			dvd_groups[int(entry.name.split("-")[1])] = node
		elif entry.name == "all-dvd-keep-case-shells":
			shell = node

func _prepare_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = load("res://assets/night-sky-subtle-8k.jpg")
	sky_material.filter = true
	sky_material.energy_multiplier = 0.35
	sky.sky_material = sky_material
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.background_color = Color("24374f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9eabc0")
	env.ambient_light_energy = 0.72 if baked_lighting_active else 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("253044")
	env.fog_depth_begin = 18.0
	env.fog_depth_end = 36.0
	env.fog_depth_curve = 1.2
	env.fog_sky_affect = 0.08
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-60, -25, 0)
	fill.light_color = Color("f3d6ac")
	fill.light_energy = 0.62 if baked_lighting_active else 0.65
	fill.shadow_enabled = false
	add_child(fill)
	for node in model.find_children("*", "", true, false):
		if node is OmniLight3D:
			node.light_energy = clampf(node.light_energy, 0.3, 2.2)
			node.shadow_enabled = false
		if node is MeshInstance3D:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if str(node.name).ends_with("-curved-screen"):
				screens.append(node)
			if str(node.name).contains("gumball-interaction-target"):
				node.visible = false
		if str(node.name) == "functional-gumball-machine":
			gum = node
		if str(node.name) == "gumball-crank":
			gum_knob = node
		if str(node.name) == "dispensed-gumball":
			gum_ball = node
	if gum and not gum_ball:
		gum_ball = MeshInstance3D.new()
		var ball_mesh := SphereMesh.new()
		ball_mesh.radius = 0.015
		ball_mesh.height = 0.03
		ball_mesh.radial_segments = 12
		ball_mesh.rings = 6
		gum_ball.mesh = ball_mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("d48baf")
		material.roughness = 0.3
		gum_ball.material_override = material
		gum.add_child(gum_ball)
		gum_ball.visible = false

func _prepare_player() -> void:
	origin = XROrigin3D.new()
	origin.name = "Player"
	origin.position = Vector3(-4.85, 0, 6.25)
	origin.rotation.y = -0.46
	add_child(origin)
	var xr = XRServer.find_interface("OpenXR")
	xr_interface = xr
	if not touch_profile and xr and xr.is_initialized():
		xr_active = true
		get_viewport().use_xr = true
		xr.render_target_size_multiplier = 1.0 if pc_vr else 1.4
		if not pc_vr and xr.has_method("set_foveation_level"):
			xr.call("set_foveation_level", 0)
		if not pc_vr and xr.has_method("set_foveation_dynamic"):
			xr.call("set_foveation_dynamic", false)
		if not pc_vr:xr.call_deferred("set_display_refresh_rate", 72.0)
		xr.session_begun.connect(_request_refresh_rate)
		xr.session_focussed.connect(func():
			_request_refresh_rate()
			_recenter_entry())
		head = XRCamera3D.new()
	else:
		head = Camera3D.new()
		head.position.y = 1.65
	origin.add_child(head)
	head.current = true
	head.near = 0.035
	head.far = 240
	hud = Label3D.new()
	hud.font_size = 30
	hud.pixel_size = 0.00065
	hud.position = Vector3(0, -0.27, -0.95)
	hud.no_depth_test = true
	hud.modulate = Color("f3d79d")
	head.add_child(hud)
	_message("VID\u00c9O CLUB VR\nJoystick gauche : marcher \u00b7 Clic : t\u00e9l\u00e9portation\nDroit : tourner / bas : accroupir \u00b7 G\u00e2chette : DVD \u00b7 X : recentrer")
	for i in range(2):
		var hand := XRController3D.new()
		hand.name = "LeftHand" if i == 0 else "RightHand"
		hand.tracker = &"left_hand" if i == 0 else &"right_hand"
		hand.pose = &"grip"
		origin.add_child(hand)
		hands.append(hand)
		hand.button_pressed.connect(_on_controller_button.bind(i))
		var visual := Node3D.new()
		visual.set_script(load("res://vr_hand.gd"))
		visual.left = i==0
		hand.add_child(visual)
		visual.visible = xr_active
		hand_visuals.append(visual)
		var dvd_anchor := Node3D.new()
		dvd_anchor.name = "DVDPinchAnchor"
		dvd_anchor.position = Vector3(0.075 if i==0 else -0.075,-0.020,-0.120)
		dvd_anchor.rotation.x = -PI/2
		hand.add_child(dvd_anchor)
		dvd_grip_anchors.append(dvd_anchor)
		var aim := XRController3D.new()
		aim.tracker = hand.tracker
		aim.pose = &"aim"
		origin.add_child(aim)
		aim_hands.append(aim)
		var beam := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.0012
		cylinder.bottom_radius = 0.0012
		cylinder.height = 1.5
		cylinder.radial_segments = 5
		beam.mesh = cylinder
		beam.rotation.x = PI / 2
		beam.position.z = -0.75
		var beam_mat := StandardMaterial3D.new()
		beam_mat.albedo_color = Color("dfb967")
		beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam.material_override = beam_mat
		aim.add_child(beam)
		pointer_beams.append(beam)
		beam.visible = xr_active

func _on_controller_button(action: StringName, hand_index: int) -> void:
	if hand_index!=0:
		return
	if action==&"by_button":
		modes.toggle_pause()
		return
	if modes and modes.menu_open:
		return
	if action==&"primary_click":
		teleportation.toggle()
	elif action==&"ax_button":
		_recenter_entry(true)

func _prepare_screens() -> void:
	screen_view = SubViewport.new()
	screen_view.size = Vector2i(1024, 768)
	screen_view.disable_3d = true
	screen_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(screen_view)
	var background := ColorRect.new()
	background.color = Color("081523")
	background.size = Vector2(1024, 768)
	screen_view.add_child(background)
	screen_picture = TextureRect.new()
	screen_picture.position = Vector2(0, 96)
	screen_picture.size = Vector2(1024, 576)
	screen_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	screen_view.add_child(screen_picture)
	trailer_player = VideoStreamPlayer.new()
	trailer_player.name = "SharedTrailerPlayer"
	trailer_player.expand = true
	trailer_player.position = Vector2(0,96)
	trailer_player.size = Vector2(1024,576)
	trailer_player.volume_db = -12.0
	trailer_player.loop = false
	trailer_player.finished.connect(_play_ambient_trailer)
	screen_view.add_child(trailer_player)
	trailer_player.visible = false
	if FileAccess.file_exists("res://assets/trailers.json"):
		var entries: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/trailers.json"))
		for entry in entries:
			var path := "res://assets/"+str(entry.file)
			if ResourceLoader.exists(path):
				trailer_streams[int(entry.id)] = load(path)
	var banner := Label.new()
	trailer_banner = banner
	banner.text = "VIDÉO CLUB · APERÇU DE DÉMONSTRATION"
	banner.add_theme_font_size_override("font_size", 27)
	banner.position = Vector2(35, 32)
	screen_view.add_child(banner)
	screen_title = Label.new()
	screen_title.position = Vector2(40, 680)
	screen_title.size = Vector2(944, 70)
	screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_title.add_theme_font_size_override("font_size", 34)
	screen_title.add_theme_color_override("font_color", Color("f0c77a"))
	screen_title.text = "CE SOIR, ON CHOISIT QUOI ?"
	screen_view.add_child(screen_title)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = screen_view.get_texture()
	mat.uv1_scale = Vector3(1,-1,1)
	mat.uv1_offset = Vector3(0,1,0)
	for screen in screens:
		screen.material_override = mat

func _play_ambient_trailer()->void:
	var available=trailer_streams.keys()
	if available.is_empty():return
	if available.size()>1:available.erase(active_trailer)
	_play_trailer(available.pick_random())

func _play_trailer(id: int) -> void:
	if id==active_trailer and trailer_player.is_playing():
		return
	trailer_player.stop()
	if not trailer_streams.has(id):
		active_trailer = -1
		trailer_player.visible = false
		screen_picture.visible = true
		trailer_banner.text = "BANDE-ANNONCE NON DISPONIBLE"
		call_deferred("_play_ambient_trailer")
		return
	active_trailer = id
	trailer_player.stream = trailer_streams[id]
	trailer_player.visible = true
	screen_picture.visible = false
	trailer_banner.text = ("JEUX VIDÉO · "+str(layout.movies[id].get("console",""))) if layout.movies[id].get("kind","")=="game" else "VIDÉO CLUB · BANDE-ANNONCE"
	trailer_player.play()
	screen_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	print("VIDEOCLUB_TRAILER_STARTED id=",id)

func _index_dvds() -> void:
	var shell_map := {}
	if shell:
		for i in range(shell.multimesh.instance_count):
			var xf := shell.global_transform * shell.multimesh.get_instance_transform(i)
			shell_map[_position_key(xf.origin)] = i
	for id in dvd_groups:
		var group: MultiMeshInstance3D = dvd_groups[id]
		for i in range(group.multimesh.instance_count):
			var local_xf := group.multimesh.get_instance_transform(i)
			var xf := group.global_transform * local_xf
			if local_xf.basis.determinant()==0 or load("res://scene_refresh.gd").rear(xf.origin):continue
			dvd_records.append({"group":group,"index":i,"local":local_xf,"world":xf,"movie":id,"shell_index":shell_map.get(_position_key(xf.origin),-1),"id":dvd_records.size(),"inverse":xf.affine_inverse()})

	for box in layout.colliders:
		var minimum := Vector3(box.min[0],box.min[1],box.min[2])
		var maximum := Vector3(box.max[0],box.max[1],box.max[2])
		cover_occluders.append(AABB(minimum,maximum-minimum))
	for i in range(dvd_records.size()):
		var p: Vector3 = dvd_records[i].world.origin
		var cell := Vector2i(floori(p.x/2.0),floori(p.z/2.0))
		if not dvd_grid.has(cell):
			dvd_grid[cell] = []
		dvd_grid[cell].append(i)

func _nearby_dvd_indices(p: Vector3, radius: float) -> Array:
	var result: Array = []
	for x in range(floori((p.x-radius)/2.0),floori((p.x+radius)/2.0)+1):
		for z in range(floori((p.z-radius)/2.0),floori((p.z+radius)/2.0)+1):
			var cell := Vector2i(x,z)
			if dvd_grid.has(cell):
				result.append_array(dvd_grid[cell])
	return result

func _prepare_held_pool() -> void:
	for id in dvd_groups:
		var item := Node3D.new()
		item.name = "DVDPool%d" % id
		load("res://held_case.gd").build(item,layout.movies[id])
		add_child(item)
		item.visible = false
		held_pool[id] = item
		poster_cache[id] = load(("res://assets/covers/%02d-front.jpg" if id>=24 else "res://assets/posters/%02d.png") % id)

func _prepare_cover_lod() -> void:
	for id in dvd_groups:
		var pair: Array = []
		for side in ["front","back"]:
			var quad := QuadMesh.new()
			quad.size = Vector2(0.131,float(layout.movies[id].get("caseHeight",.19))-.004)
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = load("res://cover_textures.gd").get_cover("res://assets/covers/%02d-%s.jpg" % [id,side])
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mat.roughness = 0.65
			quad.material = mat
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = quad
			mm.instance_count = COVER_DETAIL_BUDGET
			mm.visible_instance_count = 0
			var node := MultiMeshInstance3D.new()
			node.multimesh = mm
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			pair.append(node)
		lod_groups[id] = pair

func _update_cover_lod(eye: Vector3, force := false) -> void:
	var forward := -head.global_basis.z.normalized()
	if not force and eye.distance_squared_to(lod_last_eye)<0.0064 and forward.dot(lod_last_forward)>0.992:
		return
	lod_last_eye = eye
	lod_last_forward = forward
	var candidates: Array = []
	var nearby := _nearby_dvd_indices(eye,COVER_DETAIL_EXIT)
	lod_last_examined = nearby.size()
	lod_occlusion_tests = 0
	for i in nearby:
		var record: Dictionary = dvd_records[i]
		if record.get("loose",false) or record.get("clerk_reserved",false):continue
		if held and record.id == held_record.get("id",-1):
			continue
		var distance := eye.distance_squared_to(record.world.origin)
		var limit := COVER_DETAIL_EXIT if lod_selected.has(i) else COVER_DETAIL_ENTER
		if distance < limit*limit and (not xr_active or distance < 0.0625 or forward.dot((record.world.origin-eye).normalized()) >= 0.20):
			var alignment := maxf(0.0,forward.dot((record.world.origin-eye).normalized()))
			candidates.append({"index":i,"distance":distance,"priority":distance/(.35+.65*alignment*alignment)})
	candidates.sort_custom(func(a,b): return a.priority < b.priority)
	lod_selected.clear()
	var counts := {}
	for id in lod_groups:
		counts[id] = [0,0]
	for candidate in candidates:
		if lod_selected.size() >= COVER_DETAIL_BUDGET:
			break
		var record: Dictionary = dvd_records[candidate.index]
		# Test shelf occlusion only until the highest-priority visible covers are found.
		if xr_active:
			lod_occlusion_tests += 1
		if xr_active and not _cover_in_view(eye,record.world.origin,forward):
			continue
		var id: int = record.movie
		var front:Vector3=record.world.basis.z.normalized()
		for side in range(2):
			var facing:float=front.dot(eye-record.world.origin)*(1.0 if side==0 else -1.0)
			if facing < -.035:continue
			var slot:int=counts[id][side]
			var offset := Transform3D(Basis(Vector3.UP,PI if side==1 else 0.0),Vector3(0,0,-0.0082 if side==1 else 0.0082))
			lod_groups[id][side].multimesh.set_instance_transform(slot,record.world*offset)
			counts[id][side] += 1
		lod_selected[candidate.index] = true
	for id in lod_groups:
		for side in range(2):
			var node=lod_groups[id][side]
			node.multimesh.visible_instance_count = counts[id][side]
			node.visible=counts[id][side]>0

func _cover_in_view(eye: Vector3, center: Vector3, forward: Vector3) -> bool:
	var ray := center-eye
	var distance := ray.length()
	if distance<0.25:
		return true
	# Wide stereo margin; never wait for an object to reach the central view.
	if forward.dot(ray/distance)<0.20:
		return false
	var endpoint := center-ray/distance*0.16
	for box in cover_occluders:
		if not box.has_point(eye) and not box.has_point(center) and box.intersects_segment(eye,endpoint)!=null:
			return false
	return true

func _position_key(p: Vector3) -> String:
	return "%.4f,%.4f,%.4f" % [p.x,p.y,p.z]

func _message(text: String) -> void:
	hud.text = text

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	# Paused/invisible OpenXR sessions are not gameplay samples.
	if pc_vr and xr_active and Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)==0:
		previous_frame_usec=0
		frame_times.clear()
		frame_ring_cursor=0
		return
	if previous_frame_usec > 0 and elapsed > 5.0:
		var frame_ms := float(now-previous_frame_usec)/1000.0
		if frame_times.size()<4320:
			frame_times.append(frame_ms)
		else:
			frame_times[frame_ring_cursor] = frame_ms
			frame_ring_cursor = (frame_ring_cursor+1)%4320
	previous_frame_usec = now

var interaction_glows:Array[MeshInstance3D]=[]
var interaction_timer:=0.0

func interaction_glow(hand:int)->MeshInstance3D:
	while interaction_glows.size()<=hand:
		var glow:=preload("res://interaction_glow.gd").new()
		add_child(glow)
		interaction_glows.append(glow)
	return interaction_glows[hand]

func update_vr_glows(delta:float):
	if not xr_active or not clerk:return
	interaction_timer+=delta
	if interaction_timer<.055:return
	interaction_timer=0
	for i in range(2):
		var glow:=interaction_glow(i)
		glow.hide()
		if i==held_hand or i==clerk.secondary_hand or i==clerk.basket.hand:continue
		var p:=hands[i].global_position
		var best:=.23
		var pose:=Transform3D.IDENTITY
		var bounds:=Vector3(.151,.212,.034)
		for item in clerk.cases:
			if item==clerk.held_service or item==clerk.secondary or item.node.get_meta("customer_animating",false):continue
			var distance:float=p.distance_to(item.node.global_position)
			if distance<best:
				best=distance
				pose=item.node.global_transform
		for target in clerk.targets:
			if target.action=="tender" and not clerk.tender_note.visible:continue
			if target.action=="money" and not clerk.drawer_open:continue
			var distance:float=p.distance_to(target.node.global_position)
			if distance<minf(best,target.radius+.025):
				best=distance
				pose=target.node.global_transform
				bounds=Vector3.ONE*clampf(target.radius*1.6,.065,.26)
		if best==.23 and not held and modes.manual_mode:
			for index in _nearby_dvd_indices(p,.3):
				var record:Dictionary=dvd_records[index]
				if record.get("loose",false) or record.get("clerk_reserved",false):continue
				var distance:float=p.distance_to(record.world.origin)
				if distance<best:
					best=distance
					pose=record.world
		elif best==.23 and not held:
			var record:=shelf_ray(aim_hands[i].global_position,-aim_hands[i].global_basis.z)
			if not record.is_empty():
				best=0
				pose=record.world
		if best<.23:glow.mark(pose,bounds)

func _physics_process(delta: float) -> void:
	update_vr_glows(delta)
	elapsed += delta
	if trailer_player and trailer_player.is_playing():
		trailer_timer += delta
		if trailer_timer>=1.0/24.0-0.00001:
			trailer_timer = fmod(trailer_timer,1.0/24.0)
			screen_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	lod_timer += delta
	if lod_timer > 0.3:
		lod_timer = 0.0
		var lod_start:=Time.get_ticks_usec()
		_update_cover_lod(head.global_position)
		lod_update_usec=Time.get_ticks_usec()-lod_start
	metrics_timer += delta
	if metrics_timer > (2.0 if pc_vr else 10.0):
		metrics_timer = 0
		print("VIDEOCLUB_METRICS fps=",Engine.get_frames_per_second()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," held=",held!=null)
		_write_diagnostics()
	if not xr_active:
		return
	var move := hands[0].get_vector2(&"primary")
	if move.length() < 0.2:
		move = Vector2.ZERO
	else:
		move = move.normalized() * minf(1,(move.length()-0.2)/0.8)
	var forward := -head.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	if teleportation.enabled:
		teleportation.update(hands[0].get_vector2(&"primary"),delta)
	else:
		_move_player((right*move.x+forward*move.y)*delta*2.22)
	var right_stick := hands[1].get_vector2(&"primary")
	_update_crouch(right_stick,delta)
	var turn := right_stick.x if absf(right_stick.x)>absf(right_stick.y) else 0.0
	if absf(turn) < 0.3:
		snap_armed = true
	if absf(turn) > 0.7 and snap_armed:
		var before := head.global_position
		origin.rotate_y(-signf(turn)*PI/6)
		origin.position += before-head.global_position
		snap_armed = false
	if clerk:
		clerk.basket.update_targets()
		var pixel:=Vector2(-1,-1)
		for hand in [1,0]:
			if hand==held_hand or hand==clerk.secondary_hand:continue
			pixel=clerk.desktop.project_ray(aim_hands[hand])
			if pixel.x>=0:break
		clerk.desktop.point(pixel)
	var clerk_chord:bool=clerk.inspection.input_tick(delta) if clerk else false
	for i in range(2):
		var trigger := hands[i].get_float(&"trigger") > 0.6
		var grip := hands[i].get_float(&"grip") > 0.6
		hand_visuals[i].update_grip(delta,hands[i].get_float(&"trigger"),hands[i].get_float(&"grip"),held_hand==i or (clerk and (clerk.inspection.finger==i or clerk.secondary_hand==i or clerk.basket.hand==i or clerk.lock_hand==i)))
		pointer_beams[i].visible = held_hand!=i and not (clerk and clerk.secondary_hand==i) and not (i==0 and teleportation.enabled and teleportation.aiming)
		if trigger and not previous_trigger[i] and not clerk_chord:
			_interact(i,false)
		if grip and not previous_grip[i]:
			_interact(i,true)
		if not grip and previous_grip[i] and clerk:
			clerk.wallet.release_grip(i)
			clerk.basket.release(i)
			clerk.locks.release(i)
			if clerk.secondary_hand==i:
				clerk.release_secondary(i)
				previous_grip[i]=grip
				previous_trigger[i]=trigger
				continue
		if not grip and previous_grip[i] and held_hand == i and held_by_grip:
			_release()
		previous_trigger[i] = trigger
		previous_grip[i] = grip

func _update_crouch(stick:Vector2,delta:float)->void:
	var crouch_pressed=stick.y<-.55 and absf(stick.x)<.55
	var target=-maxf(0.0,head.position.y-.60) if crouch_pressed else 0.0
	var next=move_toward(crouch_offset,target,delta*1.8)
	origin.position.y+=next-crouch_offset
	crouch_offset=next

func _blocked(p: Vector3) -> bool:
	if clerk and clerk.door and absf(clerk.door.rotation.y)<.65 and p.x> -4.74 and p.x< -3.40 and absf(p.z-7.12)<.22:return true
	for b in layout.colliders:
		if p.x>b.min[0]-0.18 and p.x<b.max[0]+0.18 and p.z>b.min[2]-0.18 and p.z<b.max[2]+0.18:
			return true
	return false

func _recenter_entry(force := false) -> void:
	if not xr_active or recenter_running or (spawn_centered and not force):
		return
	recenter_running = true
	for frame in range(180):
		await get_tree().process_frame
		if head.position.y > 0.3 and xr_interface.get_tracking_status() == XRInterface.XR_NORMAL_TRACKING:
			break
	if head.position.y > 0.3:
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT,true)
		origin.position = Vector3(-4.85,0,6.25)
		crouch_offset=0.0
		origin.rotation = Vector3(0,-0.46,0)
		spawn_centered = true
		print("VIDEOCLUB_CENTERED local_head=",head.position," world_head=",head.global_position)
		_message("VID\u00c9O CLUB VR\nJoystick gauche : marcher \u00b7 Clic : t\u00e9l\u00e9portation\nDroit : tourner / bas : accroupir \u00b7 G\u00e2chette : DVD \u00b7 X : recentrer")
	else:
		print("VIDEOCLUB_WAITING_FOR_TRACKING head=",head.position)
	recenter_running = false
	_write_diagnostics()

func _write_diagnostics() -> void:
	var state := {"xr_active":xr_active,"tracking":xr_interface.get_tracking_status() if xr_interface else -1,"spawn_centered":spawn_centered,"head_local":[head.position.x,head.position.y,head.position.z],"head_world":[head.global_position.x,head.global_position.y,head.global_position.z],"origin":[origin.position.x,origin.position.y,origin.position.z],"viewport_xr":get_viewport().use_xr,"viewport_size":str(get_viewport().get_visible_rect().size),"xr_target_size":str(xr_interface.get_render_target_size()) if xr_interface else "none","msaa":get_viewport().msaa_3d,"camera_current":head.current,"fps":Engine.get_frames_per_second(),"dvd_count":dvd_records.size(),"near_covers":lod_selected.size(),"lod_candidates":lod_last_examined,"build":"PC-0.6.5" if pc_vr else ("0.7.6" if touch_profile else "0.7.4"),"teleport_mode":teleportation.enabled,"baked_lighting":baked_lighting_active,"active_trailer":active_trailer,"trailer_playing":trailer_player.is_playing(),"video_position":trailer_player.stream_position,"screens":screens.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	state["texture_mip_bias"]=ProjectSettings.get_setting("rendering/textures/default_filters/texture_mipmap_bias",0.0)
	state["foveation_level"]=xr_interface.call("get_foveation_level") if xr_interface and xr_interface.has_method("get_foveation_level") else -1
	if Engine.has_singleton("OpenXRFbCompositionLayerSettingsExtension"):
		var layer_settings=Engine.get_singleton("OpenXRFbCompositionLayerSettingsExtension")
		if layer_settings.has_method("get_projection_layer_sharpening_mode"):
			state["meta_sharpening"]=layer_settings.call("get_projection_layer_sharpening_mode")
			state["meta_filter_supported"]=layer_settings.call("is_enabled")
	state["render_cpu_ms"]=RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
	state["render_gpu_ms"]=RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	state["process_ms"]=Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
	state["physics_ms"]=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
	state["lod_update_ms"]=lod_update_usec/1000.0
	state["lod_occlusion_tests"]=lod_occlusion_tests
	state["display_hz"]=xr_interface.call("get_display_refresh_rate") if xr_interface and xr_interface.has_method("get_display_refresh_rate") else 0
	state["catalogue_entries"]=layout.movies.size()
	state["unique_games"]=layout.movies.filter(func(item):return item.get("kind","")=="game").size()
	state["active_candy"]=candy.balls.size() if candy else 0
	if not frame_times.is_empty():
		var sorted := frame_times.duplicate()
		sorted.sort()
		state["frame_sample_count"] = sorted.size()
		state["frame_ms_p99"] = sorted[mini(sorted.size()-1,int(sorted.size()*0.99))]
		state["frame_ms_worst"] = sorted.back()
		state["frame_ms_median"] = sorted[int(sorted.size()*.5)]
		state["frame_ms_p95"] = sorted[mini(sorted.size()-1,int(sorted.size()*.95))]
		state["target_frame_ms"] = 1000.0/72.0
	var file := FileAccess.open("user://diagnostics.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state))
	if pc_vr:
		var history=FileAccess.open("user://performance-history.jsonl",FileAccess.READ_WRITE if FileAccess.file_exists("user://performance-history.jsonl") else FileAccess.WRITE)
		if history:
			history.seek_end()
			state["unix_time"]=Time.get_unix_time_from_system()
			history.store_line(JSON.stringify(state))
		frame_times.clear()
		frame_ring_cursor=0

func _diagnostic_capture() -> void:
	if pc_vr:return # Avoid a stereo GPU readback and PNG encode during gameplay.
	await get_tree().create_timer(8).timeout
	await RenderingServer.frame_post_draw
	_write_diagnostics()
	var image := get_viewport().get_texture().get_image()
	if image and not image.is_empty():
		var result := image.save_png("user://native-frame.png")
		print("VIDEOCLUB_CAPTURE result=",result," size=",image.get_size())

func _move_player(delta: Vector3) -> void:
	for axis in [0,2]:
		var p := head.global_position
		var before := p
		p[axis] += delta[axis]
		if p.x>-30 and p.x<30 and p.z>-9.0 and p.z<40 and (not _blocked(p) or _escaping_collision(before,p)):
			origin.position[axis] += delta[axis]

func _escaping_collision(before:Vector3,after:Vector3)->bool:
	# Real-world head movement may enter a collider. Permit only reduced overlap.
	var improving=false
	for b in layout.colliders:
		var low=Vector2(b.min[0]-.18,b.min[2]-.18)
		var high=Vector2(b.max[0]+.18,b.max[2]+.18)
		var a=Vector2(before.x,before.z)
		var z=Vector2(after.x,after.z)
		var old_depth=maxf(0,minf(minf(a.x-low.x,high.x-a.x),minf(a.y-low.y,high.y-a.y)))
		var new_depth=maxf(0,minf(minf(z.x-low.x,high.x-z.x),minf(z.y-low.y,high.y-z.y)))
		if new_depth>old_depth+.000001:return false
		if new_depth<old_depth-.000001:improving=true
	return improving

func _interact(hand_index: int, by_grip: bool) -> void:
	if clerk and clerk.interact(hand_index,by_grip):return
	if netflix and netflix.interact(hand_index,by_grip):return
	if candy and candy.try_interact(hand_index,by_grip): return
	if modes and modes.try_loose_pickup(hand_index,by_grip): return
	if held:
		if hand_index == held_hand:
			if by_grip:
				_release()
			else:
				if clerk:clerk.inspection.defer_flip(hand_index)
				else:_flip_held()
		return
	var hand := aim_hands[hand_index]
	var p := hand.global_position
	var direction := -hand.global_basis.z.normalized()
	if modes and modes.manual_mode:
		if not by_grip:
			_message("Mode manuel : approche la main du DVD\npuis maintiens la poignée pour le prendre.")
			return
		if not modes.can_take_more():
			_message("Douze DVD sont au sol.\nRange-les ou utilise Y → Ranger tous les DVD.")
			return
		var near_record: Dictionary = {}
		var near_distance := 0.23
		for index in _nearby_dvd_indices(hands[hand_index].global_position,0.3):
			var record: Dictionary = dvd_records[index]
			if record.get("loose",false) or record.get("clerk_reserved",false):continue
			var d: float = record.world.origin.distance_to(hands[hand_index].global_position)
			if d<near_distance:
				near_distance=d
				near_record=record
		if not near_record.is_empty():_take(near_record,hand_index,true)
		return
	var closest:=shelf_ray(p,direction)
	if closest.is_empty():
		_message("Vise un boîtier\nGâchette : prendre · Joystick gauche : marcher")
		return
	_take(closest,hand_index,by_grip)

func shelf_ray(p:Vector3,direction:Vector3,max_distance:float=3.5)->Dictionary:
	var closest: Dictionary = {}
	var distance := max_distance
	for index in _nearby_dvd_indices(p,max_distance+.15):
		var record: Dictionary = dvd_records[index]
		if record.get("loose",false) or record.get("clerk_reserved",false):continue
		var center: Vector3 = record.world.origin
		var t := (center-p).dot(direction)
		if t<0 or t>distance or (p+direction*t).distance_to(center)>0.13:
			continue
		var inverse: Transform3D = record.inverse
		var hit = AABB(Vector3(-0.068,-0.096,-0.008),Vector3(0.136,0.192,0.016)).intersects_ray(inverse*p,inverse.basis*direction)
		if hit != null:
			distance = t
			closest = record
	return closest

func _take(record: Dictionary, hand_index: int, by_grip: bool) -> void:
	held_record = record
	held_hand = hand_index
	held_by_grip = by_grip
	held_back = false
	var zero := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)
	record.group.multimesh.set_instance_transform(record.index,zero)
	if shell and record.shell_index>=0:
		shell.multimesh.set_instance_transform(record.shell_index,zero)
	movie_id = int(record.movie)
	held = held_pool[movie_id]
	held.reparent(dvd_grip_anchors[hand_index],false)
	held.position = Vector3.ZERO
	held.rotation = Vector3.ZERO
	held.visible = true
	load("res://clerk_inventory.gd").bind(held,record)
	_update_cover_lod(head.global_position,true)
	screen_title.text = layout.movies[movie_id].title
	screen_picture.texture = poster_cache[movie_id]
	_play_trailer(movie_id)
	screen_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var authenticity := "Dos reconstitué pour la démonstration"
	if movie_id<cover_info.size() and cover_info[movie_id].get("verified",false):
		authenticity = "Vraie jaquette : " + str(cover_info[movie_id].get("edition","DVD"))
	_message(str(layout.movies[movie_id].title)+"\nG\u00e2chette : retourner \u00b7 Poign\u00e9e : reposer")
	print("VIDEOCLUB_DVD_TAKEN id=",movie_id)
	if clerk:
		clerk.adopt_held_case()
		clerk.locks.update_slot(record)

func _add_true_covers(parent: Node3D, id: int) -> void:
	if id>=cover_info.size():
		return
	for side in ["front","back"]:
		var path := "res://assets/covers/%02d-%s.jpg" % [id,side]
		if not ResourceLoader.exists(path):
			continue
		var plane := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.131,float(layout.movies[id].get("caseHeight",.19))-.004)
		plane.mesh = quad
		plane.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		plane.position.z = 0.0075 if side=="front" else -0.0075
		if side=="back":
			plane.rotation.y = PI
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(path)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.roughness = 0.45
		plane.material_override = mat
		parent.add_child(plane)

func _flip_held() -> void:
	if clerk and clerk.locks.at_detacher():return
	if not held:
		return
	held_back = not held_back
	if flip_tween and flip_tween.is_valid():
		flip_tween.kill()
	flip_tween = create_tween()
	flip_tween.tween_property(held,"rotation:y",PI if held_back else 0.0,0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _release() -> void:
	if not held:
		return
	if clerk and clerk.release():return
	if modes and modes.manual_release():return
	held_record.group.multimesh.set_instance_transform(held_record.index,held_record.local)
	if shell and held_record.shell_index>=0:
		var local_transform: Transform3D = shell.global_transform.affine_inverse()*held_record.world
		shell.multimesh.set_instance_transform(held_record.shell_index,local_transform)
	if flip_tween and flip_tween.is_valid():
		flip_tween.kill()
	held.visible = false
	held.reparent(self,false)
	held = null
	held_hand = -1
	_message("Boîtier reposé\nChoisis un autre film dans les rayons.")

func _use_gum() -> void:
	if candy:candy.use_machine(0)




