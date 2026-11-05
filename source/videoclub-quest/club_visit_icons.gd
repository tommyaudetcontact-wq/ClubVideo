extends RefCounted
const RETURN := 1
const RENT := 2
const REFUND := 4
static var textures:Dictionary={}

static func reason_mask(customer:Dictionary)->int:
	if customer.has("visit_mask"):return int(customer.visit_mask)
	var job:Dictionary=customer.get("return_job",{})
	if customer.get("is_refund",false):return RETURN|REFUND
	if not job.is_empty():
		return RETURN|(REFUND if int(job.get("refund",0))>0 else 0)|(RENT if customer.get("return_and_rent",false) else 0)
	return RENT

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

static func update(parent:Node3D,mask:int):
	if parent.get_meta("visit_icon_mask",-1)==mask:return
	parent.set_meta("visit_icon_mask",mask)
	var root:=parent.get_node_or_null("VisitIcons") as Node3D
	if not root:
		root=Node3D.new()
		root.name="VisitIcons"
		root.position.y=2.02
		parent.add_child(root)
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	var kinds:Array=[]
	for kind in [RETURN,RENT,REFUND]:
		if mask&kind:kinds.append(kind)
	for index in range(kinds.size()):
		var icon:=Sprite3D.new()
		icon.texture=texture(kinds[index])
		icon.pixel_size=.0032
		icon.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		icon.position.x=(index-(kinds.size()-1)*.5)*.23
		icon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(icon)
