extends Node3D

var anchors:Array[Node3D]=[]
var targets:Array[Transform3D]=[]
var valid_pose:=false

const Actor=preload("res://customer_actor.gd")
const Props=preload("res://clerk_props.gd")
var body:Node3D
var skeleton:Skeleton3D
var model_choice:=-1
var tracked_hands:=false
var local_player:=false
var local_game
var floor_y:=0.0
var previous_position:=Vector3.ZERO

func _ready():
	for index in range(3):
		var anchor:=Node3D.new()
		add_child(anchor)
		anchors.append(anchor)
		targets.append(Transform3D.IDENTITY)
	hide()

static func appearance(game)->Dictionary:
	return {"clerk_model":game.clerk_model,"floor":game.origin.global_position.y}

func build_body(choice:int):
	if choice==model_choice:return
	if is_instance_valid(body):body.queue_free()
	model_choice=choice
	body=Node3D.new()
	add_child(body)
	if not Actor.attach(body,0 if choice==1 else 1):return
	var visual:=body.get_node("ActorVisual")
	skeleton=visual.find_children("*","Skeleton3D",true,false)[0]
	skeleton.force_update_all_bone_transforms()
	var mount:=BoneAttachment3D.new()
	mount.bone_idx=skeleton.find_bone("Joint1")
	skeleton.add_child(mount)
	var apron:=Props.box(mount,Vector3(0,.245,.122),Vector3(.267,.36,.024),"234b77")
	apron.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-.09,.09]:
		var strap:=Props.box(mount,Vector3(x,.46,.102),Vector3(.031,.12,.020),"234b77")
		strap.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plate:=Props.box(mount,Vector3(0,.363,.144),Vector3(.126,.043,.008),"e4c98b")
	plate.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var badge:=Props.label(mount,"VIDÉO CLUB",Vector3(0,.363,.153),.00060,19)
	badge.modulate=Color("102135")
	previous_position=Vector3.INF

func attach_local(game):
	local_game=game
	local_player=true

static func pack(game)->Array:
	var points:Array=[game.head]
	if game.xr_active or game.touch_profile:points.append_array(game.hands)
	var result:Array=[]
	for point in points:
		var position:Vector3=point.global_position
		var rotation:Vector3=point.global_basis.get_euler()
		result.append([position.x,position.y,position.z,rotation.x,rotation.y,rotation.z])
	return result

func receive(data:Variant,appearance_data:Dictionary={}):
	if not data is Array or data.size() not in [1,3]:return
	var decoded:Array[Transform3D]=[]
	for values in data:
		if not values is Array or values.size()!=6:return
		for value in values:
			if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value))>50.0:return
		var position:=Vector3(values[0],values[1],values[2])
		var rotation:=Vector3(values[3],values[4],values[5])
		decoded.append(Transform3D(Basis.from_euler(rotation),position))
	var choice:int=1 if appearance_data.get("clerk_model",0)==1 else 0
	build_body(choice)
	var ground:Variant=appearance_data.get("floor",0)
	floor_y=clampf(float(ground),-4,4) if (ground is float or ground is int) and is_finite(float(ground)) else 0.0
	tracked_hands=decoded.size()==3
	for index in range(anchors.size()):
		anchors[index].visible=index<decoded.size()
		if index>=decoded.size():continue
		targets[index]=decoded[index]
		if not valid_pose:anchors[index].global_transform=targets[index]
	valid_pose=true
	show()

func _process(delta:float):
	if local_player:
		var connected:bool=local_game.clerk.lan.authenticated or (local_game.touch_controls and local_game.touch_controls.coop_panel.connected)
		visible=connected
		if not connected:return
		build_body(local_game.clerk_model)
		floor_y=local_game.origin.global_position.y
		anchors[0].global_transform=local_game.head.global_transform
		tracked_hands=local_game.xr_active
		if tracked_hands:
			for i in range(2):anchors[i+1].global_transform=local_game.hands[i].global_transform
	else:
		if not visible:return
		for index in range(anchors.size()):
			if anchors[index].visible:
				anchors[index].global_transform=anchors[index].global_transform.interpolate_with(targets[index],1.0-exp(-delta*19.0))
	if not is_instance_valid(skeleton):return
	update_body(delta)

func update_body(delta:float):
	var head:Transform3D=anchors[0].global_transform
	var yaw:=head.basis.get_euler().y
	var horizontal:=Basis(Vector3.UP,yaw)
	var body_position:=Vector3(head.origin.x,floor_y,head.origin.z)+horizontal*Vector3(0,0,.08)
	var rest_eye:=1.64 if model_choice==0 else 1.58
	var height:=clampf((head.origin.y-floor_y)/rest_eye,.57,1.19)
	var first_pose:=not previous_position.is_finite()
	var speed:=0.0 if first_pose else body_position.distance_to(previous_position)/maxf(delta,.001)
	previous_position=body_position
	body.global_transform=Transform3D(horizontal.scaled_local(Vector3(1,height,1)),body_position)
	Actor.animate(body,"Walk" if speed>.24 and speed<6 else "Idle")
	var head_bone:=skeleton.find_bone("Joint2")
	var head_pose:=skeleton.get_bone_global_pose_no_override(head_bone)
	head_pose.basis=(skeleton.global_basis.inverse()*head.basis*Basis(Vector3.UP,PI)).orthonormalized()
	if local_player:head_pose.basis=head_pose.basis.scaled_local(Vector3.ONE*.001)
	skeleton.set_bone_global_pose_override(head_bone,head_pose,1.0,true)
	if tracked_hands:
		solve_arm("Joint12","Joint13","CaseHand",anchors[1].global_transform)
		solve_arm("Joint6","Joint7","Joint8",anchors[2].global_transform)

func solve_arm(shoulder_name:String,elbow_name:String,wrist_name:String,controller:Transform3D):
	var shoulder_id:=skeleton.find_bone(shoulder_name)
	var elbow_id:=skeleton.find_bone(elbow_name)
	var wrist_id:=skeleton.find_bone(wrist_name)
	var shoulder:=skeleton.get_bone_global_pose_no_override(shoulder_id)
	var elbow:=skeleton.get_bone_global_pose_no_override(elbow_id)
	var wrist:=skeleton.get_bone_global_pose_no_override(wrist_id)
	var upper_length:=elbow.origin.distance_to(shoulder.origin)
	var lower_length:=wrist.origin.distance_to(elbow.origin)
	if upper_length<.02 or lower_length<.02:return
	var hand_target:=skeleton.to_local(controller.origin)
	var offset:=hand_target-shoulder.origin
	if offset.length_squared()<.0001:return
	var direction:=offset.normalized()
	var reach:=clampf(offset.length(),absf(upper_length-lower_length)+.01,upper_length+lower_length-.006)
	var pole:=Vector3(0,-1,-.35)
	pole=(pole-direction*pole.dot(direction)).normalized()
	if pole.length_squared()<.01:pole=direction.cross(Vector3.RIGHT).normalized()
	var along:=(upper_length*upper_length-lower_length*lower_length+reach*reach)/(2.0*reach)
	var bend:=sqrt(maxf(0,upper_length*upper_length-along*along))
	var elbow_target:=shoulder.origin+direction*along+pole*bend
	var wrist_target:=shoulder.origin+direction*reach
	shoulder.basis=Basis(Quaternion((elbow.origin-shoulder.origin).normalized(),(elbow_target-shoulder.origin).normalized()))*shoulder.basis
	elbow.basis=Basis(Quaternion((wrist.origin-elbow.origin).normalized(),(wrist_target-elbow_target).normalized()))*elbow.basis
	elbow.origin=elbow_target
	wrist.origin=wrist_target
	wrist.basis=(skeleton.global_basis.inverse()*controller.basis*Basis(Vector3.UP,PI)).orthonormalized()
	if local_player:wrist.basis=wrist.basis.scaled_local(Vector3.ONE*.001)
	skeleton.set_bone_global_pose_override(shoulder_id,shoulder,1.0,true)
	skeleton.set_bone_global_pose_override(elbow_id,elbow,1.0,true)
	skeleton.set_bone_global_pose_override(wrist_id,wrist,1.0,true)
