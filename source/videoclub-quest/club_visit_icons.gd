extends RefCounted
const RETURN := 1
const RENT := 2
const REFUND := 4
static var textures:Dictionary={}

static func reason_mask(customer:Dictionary)->int:
	if customer.get("state","")=="exit":return 0
	var job:Dictionary=customer.get("return_job",{})
	var mask:int=int(customer.get("visit_mask",RENT))
	if not job.is_empty():
		mask|=RETURN
		if int(job.get("refund",0))>0:mask|=REFUND
	else:mask&=~RETURN
	if customer.get("is_refund",false):mask|=REFUND
	elif job.is_empty():mask&=~REFUND
	if int(customer.get("rental_remaining",customer.get("rental_count",1)))<=0:mask&=~RENT
	if not job.is_empty() and not customer.get("return_and_rent",false):mask&=~RENT
	return mask

static func remaining_count(customer:Dictionary)->int:
	return maxi(0,int(customer.get("rental_remaining",customer.get("rental_count",1))))

static func texture(kind:int)->Texture2D:
	if textures.has(kind):return textures[kind]
	var colors={RETURN:"#269b62",RENT:"#267bc8",REFUND:"#d88420"}
	var marks={
		RETURN:'<path d="M45 19H26a12 12 0 0 0 0 24h17M26 13l-9 9 9 9" fill="none" stroke="white" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>',
		RENT:'<rect x="17" y="13" width="25" height="36" rx="3" fill="none" stroke="white" stroke-width="4"/><circle cx="30" cy="31" r="8" fill="none" stroke="white" stroke-width="3"/><path d="M44 35v17m-8-8h17" stroke="white" stroke-width="4"/>',
		REFUND:'<path d="M43 18H25c-10 0-10 13 0 13h12c10 0 10 14 0 14H19M32 10v44" fill="none" stroke="white" stroke-width="5" stroke-linecap="round"/>'
	}
	var svg='<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><circle cx="32" cy="32" r="30" fill="%s" stroke="white" stroke-width="2"/>%s</svg>'%[colors[kind],marks[kind]]
	var image:=Image.new()
	image.load_svg_from_string(svg)
	image.generate_mipmaps()
	var result:=ImageTexture.create_from_image(image)
	textures[kind]=result
	return result

static func update(parent:Node3D,mask:int,count:int=1):
	var root:=parent.get_node_or_null("VisitIcons") as Node3D
	if not root:
		root=Node3D.new()
		root.name="VisitIcons"
		root.position.y=2.10
		parent.add_child(root)
	root.visible=mask!=0
	var camera:=parent.get_viewport().get_camera_3d()
	if camera and root.global_position.distance_to(camera.global_position)>.01:root.look_at(camera.global_position,Vector3.UP,true)
	if parent.get_meta("visit_icon_mask",-1)==mask and parent.get_meta("visit_icon_count",-1)==count:return
	parent.set_meta("visit_icon_count",count)
	parent.set_meta("visit_icon_mask",mask)
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	var kinds:Array=[]
	for kind in [RETURN,RENT,REFUND]:
		if mask&kind:kinds.append(kind)
	var captions:Dictionary={RETURN:"RETOUR",RENT:"LOCATION",REFUND:"REMBOURSEMENT"}
	for index in range(kinds.size()):
		var y:float=((kinds.size()-1)*.5-index)*.20
		var background:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		quad.size=Vector2(.94,.185)
		background.mesh=quad
		var material:=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color=Color(.025,.04,.07,.88)
		background.material_override=material
		background.position=Vector3(0,y,-.005)
		background.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(background)
		var icon:=Sprite3D.new()
		icon.texture=texture(kinds[index])
		icon.pixel_size=.0024
		icon.position=Vector3(-.37,y,.002)
		icon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(icon)
		var label:=Label3D.new()
		label.text=captions[kinds[index]]+(" ×%d"%count if kinds[index]==RENT and count>1 else "")
		label.font_size=48
		label.pixel_size=.0015
		label.outline_size=10
		label.position=Vector3(.08,y,.004)
		root.add_child(label)
