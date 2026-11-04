extends Node3D

var left := false
var skeleton: Skeleton3D
var joints: Array[int] = []
var rest_rotations: Array[Quaternion] = []
var bend_axes: Array[Vector3] = []
var curl := 0.0
var thumb_joint := -1
var thumb_rest: Quaternion
var thumb_axis: Vector3

func _ready() -> void:
	var asset: Node3D = load("res://assets/hands/%s.glb" % ("left" if left else "right")).instantiate()
	add_child(asset)
	skeleton = asset.find_children("*","Skeleton3D",true,false)[0]
	var wrist := skeleton.find_bone("wrist")
	var wrist_rest := skeleton.get_bone_global_rest(wrist)
	thumb_joint = skeleton.find_bone("thumb-metacarpal")
	thumb_rest = skeleton.get_bone_rest(thumb_joint).basis.get_rotation_quaternion()
	thumb_axis = (skeleton.get_bone_global_rest(thumb_joint).basis.inverse()*wrist_rest.basis*Vector3.UP).normalized()
	asset.transform = Transform3D(Basis.IDENTITY,Vector3(0,0,0.055))*wrist_rest.affine_inverse()
	for mesh in asset.find_children("*","MeshInstance3D",true,false):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("b68d77")
		material.roughness = 0.62
		mesh.material_override = material
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for finger in ["index-finger","middle-finger","ring-finger","pinky-finger"]:
		for part in ["phalanx-proximal","phalanx-intermediate","phalanx-distal"]:
			var joint := skeleton.find_bone(finger+"-"+part)
			joints.append(joint)
			rest_rotations.append(skeleton.get_bone_rest(joint).basis.get_rotation_quaternion())
			bend_axes.append((skeleton.get_bone_global_rest(joint).basis.inverse()*wrist_rest.basis*Vector3.RIGHT).normalized())

func update_grip(delta: float, trigger: float, grip: float, holding: bool) -> void:
	curl = move_toward(curl,maxf(grip,0.65 if holding else 0.08),delta*7)
	skeleton.set_bone_pose_rotation(thumb_joint,thumb_rest*Quaternion(thumb_axis,(0.45 if left else -0.45)*curl))
	for i in range(joints.size()):
		var amount := (0.12 if holding else trigger*.85) if i<3 else curl
		var angle: float = [0.8,1.05,0.65][i%3]*amount
		skeleton.set_bone_pose_rotation(joints[i],rest_rotations[i]*Quaternion(bend_axes[i],-angle))
