extends Node3D
var clerk
var game
var fan:MeshInstance3D
var sound:AudioStreamPlayer3D
var clock=0.0
var last_case:Node3D
var flash=0.0
var direction=Vector3(0,.15,-1).normalized()
func setup(c):
	clerk=c
	game=c.game
	name="BarcodeScannerBeam"
	position=Vector3(.40,1.27,-6.26)
	var window=game.model.find_child("scanner-red-window",true,false)
	if window:global_position=window.global_position
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_vertex(Vector3.ZERO)
	st.add_vertex(direction*.42+Vector3(-.22,0,0))
	st.add_vertex(direction*.42+Vector3(.22,0,0))
	fan=MeshInstance3D.new()
	fan.mesh=st.commit()
	var mat=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color=Color(1,.015,.01,.20)
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test=false
	fan.material_override=mat
	fan.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fan)
	sound=AudioStreamPlayer3D.new()
	add_child(sound)
	sound.max_distance=6
	sound.volume_db=-15
	var wav=AudioStreamWAV.new()
	wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate=22050
	var data=PackedByteArray()
	data.resize(2646*2)
	for i in range(2646):data.encode_s16(i*2,int(sin(i*TAU*1800/22050.0)*8000*minf(1,float(2646-i)/250)))
	wav.data=data
	sound.stream=wav
func intersects_case(node:Node3D)->bool:
	# The back must actually enter the fan; hovering near the scanner body is insufficient.
	var p=node.to_global(Vector3(0,-.045,-.008))-global_position
	var depth=p.dot(direction)
	if depth<.025 or depth>.43 or absf(p.x)>.025+depth*.55:return false
	var vertical=p.dot(Vector3(0,1,.15).normalized())
	if absf(vertical)>.07:return false
	var outward=-node.global_basis.z.normalized()
	return outward.dot(-direction)>.25
func tick(dt:float):
	clock+=dt
	flash=maxf(0,flash-dt)
	fan.material_override.albedo_color=Color(1,.015,.01,.55 if flash>0 else (.18+.10*absf(sin(clock*24))))
	if game.touch_profile:return
	var node:Node3D=game.held
	if not clerk.inspection.opened and not clerk.secondary.is_empty() and intersects_case(clerk.secondary.node) and (not is_instance_valid(node) or not intersects_case(node)):
		var previous=clerk.held_service
		var previous_hand=game.held_hand
		clerk.held_service=clerk.secondary
		game.held=clerk.secondary.node
		game.held_hand=clerk.secondary_hand
		game.held_record={}
		game.movie_id=clerk.secondary.movie
		game.held_by_grip=true
		clerk.secondary=previous
		clerk.secondary_hand=previous_hand
		node=game.held
	if not is_instance_valid(node) or clerk.inspection.opened or not intersects_case(node):
		last_case=null
		return
	if last_case==node:return
	last_case=node
	if clerk.held_service.is_empty():clerk.adopt_held_case()
	last_case=game.held
	if clerk.scan_held():
		flash=.16
		sound.play()
