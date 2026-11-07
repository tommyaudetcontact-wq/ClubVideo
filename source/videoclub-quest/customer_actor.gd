extends RefCounted

static var wardrobe:StandardMaterial3D

static func attach(parent:Node3D,index:int)->bool:
	var path:="res://assets/customers/client-%d.glb"%posmod(index,8)
	if not ResourceLoader.exists(path):return false
	var visual:Node3D=load(path).instantiate()
	visual.name="ActorVisual"
	visual.rotation.y=PI
	parent.add_child(visual)
	if not wardrobe:
		wardrobe=StandardMaterial3D.new()
		wardrobe.vertex_color_use_as_albedo=true
		wardrobe.albedo_texture=load("res://assets/customers/wardrobe.png")
		wardrobe.roughness=.79
		wardrobe.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=wardrobe
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var players:=visual.find_children("*","AnimationPlayer",true,false)
	if not players.is_empty():
		var player:AnimationPlayer=players[0]
		visual.set_meta("player",player)
		for key in ["Idle","Walk","CarryWalk","CarryIdle"]:
			if player.has_animation(key):player.get_animation(key).loop_mode=Animation.LOOP_LINEAR
		if player.has_animation("Idle"):player.play("Idle")
	var skeletons:=visual.find_children("*","Skeleton3D",true,false)
	if not skeletons.is_empty():
		var skeleton:Skeleton3D=skeletons[0]
		var wrist:=skeleton.find_bone("CaseHand")
		if wrist>=0:
			var socket:=BoneAttachment3D.new()
			socket.name="Boitier"
			socket.bone_idx=wrist
			skeleton.add_child(socket)
			var mount:=Node3D.new()
			mount.position=Vector3(0,-.028,.042)
			socket.add_child(mount)
			visual.set_meta("mount",mount)
			visual.set_meta("skeleton",skeleton)
			visual.set_meta("reach_shoulder",skeleton.get_bone_parent(skeleton.get_bone_parent(wrist)))
	var proxy:=Node3D.new()
	proxy.name="Arm1"
	proxy.position=Vector3(.26,1.37,0)
	parent.add_child(proxy)
	return true

static func mount(parent:Node3D)->Node3D:
	var visual:=parent.get_node_or_null("ActorVisual")
	return visual.get_meta("mount",parent) if visual else parent

static func equip(parent:Node3D,case_node:Node3D):
	var hand:=mount(parent)
	hand.add_child(case_node)
	if hand==parent:
		case_node.position=Vector3(.25,.92,-.12)
		case_node.rotation.y=PI/2

static func animate(parent:Node3D,key:String):
	var visual:=parent.get_node_or_null("ActorVisual")
	if not visual:return
	var player:AnimationPlayer=visual.get_meta("player",null)
	if not player or visual.get_meta("clip","")==key:return
	var skeleton:Skeleton3D=visual.get_meta("skeleton",null)
	var shoulder:int=visual.get_meta("reach_shoulder",-1)
	if skeleton and shoulder>=0 and visual.has_meta("receive_shoulder"):
		skeleton.set_bone_pose_rotation(shoulder,visual.get_meta("receive_shoulder"))
		visual.remove_meta("receive_shoulder")
	if key=="Receive" and player.has_animation("HandOff"):
		visual.set_meta("clip",key)
		player.play("HandOff")
		player.seek(1.60,true)
		player.pause()
		if skeleton and shoulder>=0:
			var original:=skeleton.get_bone_pose_rotation(shoulder)
			var parent_pose:=skeleton.get_bone_global_pose(skeleton.get_bone_parent(shoulder))
			var world_basis:Basis=skeleton.global_basis*parent_pose.basis
			var reach_axis:Vector3=(world_basis.inverse()*(parent.global_basis.x)).normalized()
			visual.set_meta("receive_shoulder",original)
			skeleton.set_bone_pose_rotation(shoulder,Quaternion(reach_axis,deg_to_rad(51.0))*original)
		return
	if not player.has_animation(key):return
	visual.set_meta("clip",key)
	player.play(key,.17,1.43 if key in ["Walk","CarryWalk"] else (2.4 if key=="HandOff" else 1.0))
