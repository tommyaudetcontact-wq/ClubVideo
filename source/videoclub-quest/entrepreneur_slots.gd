extends RefCounted
var b
var markers:MultiMeshInstance3D
var clock:=0.0
func setup(owner_business) -> void:b=owner_business
func pose(shelf:int,slot:int) -> Transform3D:
	var entry:Dictionary=b.state.shelves[shelf]
	var columns:int=b.Rules.SHELF_COLUMNS[int(entry.model)]
	return entry.pose*Transform3D(Basis.IDENTITY,Vector3(-columns*.145/2+.0725+(slot%columns)*.145,.32+int(slot/columns)*.35,.14))
func is_free(shelf:int,slot:int,except_id:int=-1) -> bool:
	for id in b.state.stock:
		if int(id)==except_id:continue
		var entry:Dictionary=b.state.stock[id]
		if not entry.get("sold",false) and entry.get("shelved",false) and int(entry.shelf)==shelf and int(entry.slot)==slot:return false
	return true
func closest(point:Vector3,except_id:int=-1,radius:float=.24) -> Dictionary:
	var best:=radius;var result:Dictionary={}
	for shelf in b.state.shelves.size():
		var local:Vector3=b.state.shelves[shelf].pose.affine_inverse()*point
		if absf(local.z-.14)>.30:continue
		var columns:int=b.Rules.SHELF_COLUMNS[int(b.state.shelves[shelf].model)]
		var col:=clampi(roundi((local.x+columns*.145/2-.0725)/.145),0,columns-1)
		var row:=clampi(roundi((local.y-.32)/.35),0,3)
		var slot:int=row*columns+col
		var transform:=pose(shelf,slot);var distance:=point.distance_to(transform.origin)
		if distance<best and is_free(shelf,slot,except_id):best=distance;result={"shelf":shelf,"slot":slot,"pose":transform}
	return result
func choose(record:Dictionary,point:Vector3) -> bool:
	if record.is_empty() or not b.state.stock.has(int(record.id)):return false
	var slot:=closest(point,int(record.id))
	if slot.is_empty():return false
	var entry:Dictionary=b.state.stock[int(record.id)]
	entry.shelf=slot.shelf;entry.slot=slot.slot
	b.move_record(record)
	return true
func ray_target(origin:Vector3,direction:Vector3,id:int=-1) -> Vector3:
	var best:=2.3;var result:=Vector3.INF
	for index in b.state.shelves.size():
		var shelf:Transform3D=b.state.shelves[index].pose
		var start:Vector3=shelf.affine_inverse()*origin;var ray:Vector3=shelf.basis.inverse()*direction
		if absf(ray.z)<.01:continue
		var distance:float=(.14-start.z)/ray.z
		if distance<0 or distance>best:continue
		var hit:=closest(origin+direction*distance,id,.15)
		if not hit.is_empty():best=distance;result=hit.pose.origin
	return result
func tick(dt:float) -> void:
	clock+=dt
	if clock<.12:return
	clock=0
	var record:Dictionary=b.game.clerk.held_service.get("record",{})
	var guest:bool=b.is_remote_guest() and not b.game.touch_controls.coop_panel.guest_case_id.is_empty()
	if record.is_empty() and not guest:
		if markers:markers.hide()
		return
	if not markers:
		markers=MultiMeshInstance3D.new();markers.name="AvailableShelfSlots"
		markers.multimesh=MultiMesh.new();markers.multimesh.transform_format=MultiMesh.TRANSFORM_3D;markers.multimesh.instance_count=256
		var outline:=SurfaceTool.new();outline.begin(Mesh.PRIMITIVE_LINES)
		for edge in [[Vector3(-.068,-.10,0),Vector3(.068,-.10,0)],[Vector3(.068,-.10,0),Vector3(.068,.10,0)],[Vector3(.068,.10,0),Vector3(-.068,.10,0)],[Vector3(-.068,.10,0),Vector3(-.068,-.10,0)]]:
			outline.add_vertex(edge[0]);outline.add_vertex(edge[1])
		markers.multimesh.mesh=outline.commit()
		var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("f2d45d")
		markers.material_override=mat;b.add_child(markers)
	var count:=0
	for shelf in b.state.shelves.size():
		if b.state.shelves[shelf].pose.origin.distance_to(b.game.head.global_position)>3.0:continue
		for slot in b.Rules.SHELF_COLUMNS[int(b.state.shelves[shelf].model)]*4:
			if count>=256:break
			if not is_free(shelf,slot,int(record.get("id",-1))):continue
			var transform:=pose(shelf,slot);transform.origin+=transform.basis.z*.025
			markers.multimesh.set_instance_transform(count,transform);count+=1
	markers.multimesh.visible_instance_count=count;markers.visible=count>0
