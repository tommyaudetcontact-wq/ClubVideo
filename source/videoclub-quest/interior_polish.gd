extends Node3D
# Two shadowless local lights supplement the baked diffuse lighting. A single
# captured probe supplies the ceiling reflections missing from the night sky.
var game
var lamps:Array[OmniLight3D]=[]
var positions:Array[Vector3]=[]
var selection_timer:=0.0
var targets:Array[Vector3]=[]
func setup(owner_game)->void:
	game=owner_game
	name="InteriorPolish"
	# The baked illumination covers matte surfaces. Reserve extra light/probe
	# evaluation for materials with a visible specular response, including glass.
	for node in game.find_children("*","GeometryInstance3D",true,false):
		if node is MeshInstance3D:
			var glossy:=false
			for i in range(node.mesh.get_surface_count()):
				var material=node.get_active_material(i)
				if material is ShaderMaterial and material.shader.resource_path in ["res://rain_glass.gdshader","res://wet_asphalt.gdshader"]:glossy=true
				if material is StandardMaterial3D:
					if material.metallic>.1 or material.roughness<.5:glossy=true
			if glossy:node.layers|=2
	for x in [-3.9,0.0,3.9]:
		for z in [-4.5,0.3,4.5]:positions.append(Vector3(x,3.05,z))
	for i in range(2):
		var lamp:=OmniLight3D.new()
		lamp.name="NearbyLight%d"%i
		lamp.omni_range=3.8
		lamp.omni_attenuation=1.4
		lamp.light_color=Color("fff1dc")
		lamp.light_energy=0.0
		lamp.light_specular=1.4
		lamp.light_cull_mask=0xFFFFFFFF if game.pc_vr else 2
		lamp.shadow_enabled=false
		add_child(lamp)
		lamps.append(lamp)
	var probe:=ReflectionProbe.new()
	probe.name="InteriorCeilingReflection"
	probe.position=Vector3(0,1.8,0)
	probe.size=Vector3(11.5,3.5,14)
	probe.origin_offset=Vector3(0,.8,0)
	probe.interior=true
	probe.box_projection=true
	probe.enable_shadows=false
	probe.intensity=.8
	probe.reflection_mask=0xFFFFFFFF if game.pc_vr else 2
	probe.update_mode=ReflectionProbe.UPDATE_ONCE
	add_child(probe)
	targets=[positions[0],positions[1]]
	# Face the OUVERT print towards arriving customers, not into the shop.
	var sign_node=game.model.find_child("open-sign",true,false)
	if sign_node:
		sign_node.rotate_y(PI)
		if sign_node is MeshInstance3D:
			var mat=sign_node.get_active_material(0).duplicate()
			mat.cull_mode=BaseMaterial3D.CULL_BACK
			sign_node.material_override=mat
func _process(delta:float)->void:
	if not is_instance_valid(game.head):return
	var eye:Vector3=game.head.global_position
	selection_timer-=delta
	if selection_timer<=0.0:
		selection_timer=.15
		var candidates=positions.duplicate()
		candidates.sort_custom(func(a,b):return a.distance_squared_to(eye)<b.distance_squared_to(eye))
		targets=[candidates[0],candidates[1]]
	for i in range(lamps.size()):
		var lamp=lamps[i]
		var target:Vector3=targets[i]
		if lamp.position!=target:
			lamp.light_energy=move_toward(lamp.light_energy,0.0,delta*1.5)
			if lamp.light_energy<.001:lamp.position=target
		else:
			var strength=.45*(1.0-smoothstep(2.2,4.2,eye.distance_to(target)))
			lamp.light_energy=move_toward(lamp.light_energy,strength,delta*.8)
