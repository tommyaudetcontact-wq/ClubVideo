extends Node3D
# PC-only presentation. The standalone Quest profile never instantiates this.
var game
var lamps:Array[SpotLight3D]=[]
var shadow_lamp:SpotLight3D
var positions:Array[Vector3]=[]
var timer:=0.0
var scene_environment:Environment
func setup(g)->void:
	game=g
	name="PCPresentation"
	var environment:Environment
	for n in g.get_children():
		if n is WorldEnvironment:environment=n.environment
	if environment:
		scene_environment=environment
		environment.ssr_max_steps=48
		environment.ssr_depth_tolerance=.3
		environment.ssao_enabled=false
		environment.ssao_radius=.22
		environment.ssao_intensity=1.15
		environment.ssao_power=1.3
		environment.ssao_detail=.35
		environment.glow_enabled=false
		environment.glow_intensity=.35
		environment.glow_strength=.7
		environment.glow_bloom=0.0
		environment.glow_hdr_threshold=1.4
		environment.ambient_light_color=Color("bdc2ce")
		environment.ambient_light_energy=.56
		environment.tonemap_exposure=1.08
		environment.fog_depth_begin=30.0
		environment.fog_depth_end=95.0
		environment.fog_depth_curve=1.5
		environment.fog_sky_affect=.20
	for old in g.model.find_children("*","Light3D",true,false):old.visible=false
	for old in g.get_children():
		if old is DirectionalLight3D:
			old.light_energy=.30
			old.light_color=Color("8faacb")
	var polish=g.get_node("InteriorPolish")
	polish.set_process(false)
	for light in polish.lamps:light.visible=false
	var material_variants:Dictionary={}
	for node in g.model.find_children("*","MeshInstance3D",true,false):
		if not node.visible:continue
		for surface in range(node.mesh.get_surface_count()):
			var original=node.get_active_material(surface)
			if not original is StandardMaterial3D:continue
			if original.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
			var metallic_surface:bool=original.metallic>.6
			var blue_enamel:bool=not original.albedo_texture and original.albedo_color.b>original.albedo_color.r*1.3
			if not metallic_surface and not blue_enamel and not original.normal_enabled:continue
			if not material_variants.has(original):
				var detailed:StandardMaterial3D=original.duplicate()
				if metallic_surface:
					detailed.roughness=.28
					detailed.anisotropy_enabled=true
					detailed.anisotropy=.30
				elif blue_enamel:
					detailed.roughness=.36
					detailed.clearcoat_enabled=true
					detailed.clearcoat=.28
					detailed.clearcoat_roughness=.32
				if detailed.normal_enabled:
					detailed.normal_scale*=1.4
				material_variants[original]=detailed
			node.set_surface_override_material(surface,material_variants[original])
		var bounds:AABB=node.global_transform*node.get_aabb()
		if bounds.end.z<7.2 and bounds.position.z> -8.5:
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Detailed handheld objects cast a real shadow; repeated shelf cases keep
	# their contact shading rather than thousands of extra shadow draws.
	for item in g.held_pool.values():
		var body=item.get_node_or_null("MoldedPlasticOnly")
		if body:body.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for x in [-3.9,0.0,3.9]:
		for z in [-4.5,.3,4.5]:positions.append(Vector3(x,3.10,z))
	for i in range(9):
		var light:=SpotLight3D.new()
		light.name="PCSoftCeiling%d"%i
		light.position=positions[i]
		light.rotation_degrees.x=-90
		light.light_color=Color("fff2de")
		light.light_energy=3.6
		light.light_size=.25
		light.spot_range=4.0
		light.spot_angle=65.0
		light.spot_attenuation=1.3
		light.shadow_enabled=false
		light.shadow_opacity=.6
		light.shadow_blur=1.3
		light.shadow_bias=.03
		light.shadow_normal_bias=.3
		add_child(light)
		lamps.append(light)
	
	_checkout_lighting()
	_exterior()
	_detail_materials()
	_neighborhood()
	# Dedicated exterior capture gives wet asphalt the actual storefront/sky.
	var probe:=ReflectionProbe.new()
	probe.name="PCWetParkingReflection"
	probe.position=Vector3(0,2.4,17)
	probe.size=Vector3(56,9,28)
	probe.box_projection=true
	probe.intensity=.65
	probe.enable_shadows=false
	probe.update_mode=ReflectionProbe.UPDATE_ONCE
	add_child(probe)
	print("VIDEOCLUB_PC_HIGH baked=false ssao=false ceiling_lights=9 shadow_budget=1 glow=local_geometry")
func _process(delta:float)->void:
	timer-=delta
	if timer>0:return
	timer=.2
	var eye:Vector3=game.head.global_position
	if scene_environment:scene_environment.ssr_enabled=false
	var nearest:SpotLight3D=lamps[0]
	for light in lamps:
		if light.position.distance_squared_to(eye)<nearest.position.distance_squared_to(eye):
			nearest=light
	if shadow_lamp and shadow_lamp.position.distance_to(eye)<=nearest.position.distance_to(eye)+.65:
		return
	if shadow_lamp:shadow_lamp.shadow_enabled=false
	shadow_lamp=nearest
	shadow_lamp.shadow_enabled=true

func _checkout_lighting()->void:
	var task_light := SpotLight3D.new()
	task_light.name = "PCCheckoutTaskLight"
	task_light.position = Vector3(.45, 3.03, -7.65)
	task_light.rotation_degrees.x = -90
	task_light.light_color = Color("fff0d5")
	task_light.light_energy = 3.0
	task_light.spot_range = 3.7
	task_light.spot_angle = 61.0
	task_light.light_size = .36
	add_child(task_light)

func _exterior()->void:
	for pos in [Vector3(-10.48,5.3,20),Vector3(11.82,5.3,22.5),Vector3(-18.88,5.3,32),Vector3(23.12,5.3,33)]:
		var light:=SpotLight3D.new()
		light.position=pos
		light.rotation_degrees.x=-90
		light.light_color=Color("ffdba5")
		light.light_energy=5.0
		light.spot_range=12.0
		light.spot_angle=67.0
		light.spot_attenuation=1.2
		light.shadow_enabled=true
		light.distance_fade_enabled=true
		light.distance_fade_begin=28.0
		light.distance_fade_shadow=18.0
		light.distance_fade_length=10.0
		add_child(light)
	for x in [-25.0,-18.65,9.35,15.7]:
		var light:=OmniLight3D.new()
		light.position=Vector3(x,2.2,7.7)
		light.light_color=Color("ffd8a3")
		light.light_energy=1.5
		light.omni_range=5.0
		light.shadow_enabled=false
		add_child(light)
	for pos in [Vector3(-5.4,2.85,0),Vector3(-5.4,2.85,4),Vector3(-2.8,2.85,6.8),Vector3(2.8,2.85,6.8)]:
		var light:=OmniLight3D.new()
		light.position=pos
		light.light_color=Color("498aff")
		light.light_energy=.7
		light.omni_range=3.0
		add_child(light)

func _detail_materials()->void:
	var shaders={}
	for node in game.find_children("*","MeshInstance3D",true,false):
		for surface in range(node.mesh.get_surface_count()):
			var mat=node.get_active_material(surface)
			if not mat is ShaderMaterial:continue
			var path=mat.shader.resource_path
			if path=="res://rain_glass.gdshader":mat.shader=load("res://pc_rain_glass.gdshader")
			elif path=="res://wet_asphalt.gdshader":mat.shader=load("res://pc_wet_asphalt.gdshader")
			elif mat.shader.code.contains("uniform float surface_roughness"):
				var old=mat.shader
				if not shaders.has(old):
					var replacement=Shader.new()
					replacement.code=old.code.replace("smoothstep(4.0,22.0","smoothstep(25.0,100.0")
					shaders[old]=replacement
				mat.shader=shaders[old]
	for rain in game.modes.rain_nodes:
		rain.amount*=2
		rain.draw_pass_1.size=Vector2(.0035,.09)
	# Rebuild RGB image mipchains as RGBA: avoids speckled imported RGB samples.
	for item in game.held_pool.values():
		for part in item.get_children():
			if not part is MeshInstance3D or not str(part.name).begins_with("PaperInsert_"):continue
			var mat:StandardMaterial3D=part.material_override
			var pixels:Image=mat.albedo_texture.get_image()
			pixels.convert(Image.FORMAT_RGBA8)
			pixels.generate_mipmaps()
			mat.albedo_texture=ImageTexture.create_from_image(pixels)

func _box(st:SurfaceTool,center:Vector3,size:Vector3)->void:
	var box=BoxMesh.new()
	box.size=size
	st.append_from(box,0,Transform3D(Basis.IDENTITY,center))

func _neighborhood()->void:
	# Distant architecture is a few merged surfaces, not a skyline painted on the sky.
	var buildings=SurfaceTool.new()
	var trim=SurfaceTool.new()
	var windows=SurfaceTool.new()
	for st in [buildings,trim,windows]:st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng=RandomNumberGenerator.new()
	rng.seed=2002
	for i in range(36):
		var x=-70.0+(i%18)*8.3
		var z=(62.0 if i<18 else -32.0)+rng.randf_range(-5,5)
		var height=rng.randf_range(4,8)
		_box(buildings,Vector3(x,height*.5,z),Vector3(7.2,height,10))
		_box(trim,Vector3(x,height,z),Vector3(7.5,.22,10.3))
		for floor_id in range(2):
			for col in range(4):
				if rng.randf()>.65:continue
				_box(windows,Vector3(x-2.5+col*1.6,1.8+floor_id*2.5,z+(-5.02 if i<18 else 5.02)),Vector3(.65,1.0,.04))
	for idx in range(3):
		var node=MeshInstance3D.new()
		node.name=["PCDistantBuildings","PCRoofTrim","PCDistantWindows"][idx]
		node.mesh=[buildings,trim,windows][idx].commit()
		var material=ShaderMaterial.new()
		material.shader=load("res://pc_exterior_haze.gdshader")
		material.set_shader_parameter("tint",[Color("252c37"),Color("454b52"),Color("c5a778")][idx])
		if idx==2:material.set_shader_parameter("glow",Vector3(.30,.19,.07))
		node.material_override=material
		add_child(node)
	# Small physical fixtures and warm canopy illumination at neighboring shops.
	var metal=StandardMaterial3D.new()
	metal.albedo_color=Color("24272c")
	metal.metallic=.7
	metal.roughness=.25
	for x in [-25.0,-18.65,9.35,15.7]:
		for dx in [-2.1,2.1]:
			var fixture=MeshInstance3D.new()
			var mesh=CylinderMesh.new()
			mesh.top_radius=.10
			mesh.bottom_radius=.10
			mesh.height=.25
			mesh.radial_segments=24
			fixture.mesh=mesh
			fixture.material_override=metal
			fixture.position=Vector3(x+dx,2.65,7.60)
			add_child(fixture)
			var light=SpotLight3D.new()
			light.position=Vector3(x+dx,2.49,7.60)
			light.rotation_degrees.x=-90
			light.light_color=Color("ffd6a0")
			light.light_energy=2.5
			light.spot_range=4
			light.spot_angle=50
			add_child(light)

