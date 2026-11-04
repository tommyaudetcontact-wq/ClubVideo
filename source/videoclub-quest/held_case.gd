extends RefCounted
# Detailed rounded shell is used only by the visible held/loose case, never shelf copies.
static var plastics:Dictionary={}
static var shells:Dictionary={}
static var resting_plastics:Dictionary={}
static func build(item:Node3D, entry:Dictionary)->void:
 var platform:String=entry.get("console","DVD")
 var h:float=entry.get("caseHeight",.19)
 if not plastics.has(platform):
  var mat=StandardMaterial3D.new()
  mat.albedo_color=Color("17191b")
  if platform=="Xbox":mat.albedo_color=Color("438b25")
  if platform=="Xbox 360":mat.albedo_color=Color(.20,.66,.08,.58)
  if platform=="PlayStation 3" or platform=="PS3":mat.albedo_color=Color(.83,.87,.9,.28)
  if platform=="Wii":mat.albedo_color=Color("ededdf")
  if mat.albedo_color.a<1:mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  mat.roughness=.25
  mat.metallic_specular=.45
  mat.normal_enabled=true
  mat.normal_texture=load("res://assets/material-lab/paint-normal.png")
  mat.normal_scale=.055
  mat.roughness_texture=load("res://assets/material-lab/paint-roughness.png")
  mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
  plastics[platform]=mat
  shells[platform]=rounded_shell(.135,h,.014)
 var body=MeshInstance3D.new()
 body.name="MoldedPlasticOnly"
 body.mesh=shells[platform]
 body.material_override=plastics[platform]
 body.set_meta("plastic_platform",platform)
 body.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 item.add_child(body)
 var ps3=platform=="PlayStation 3" or platform=="PS3"
 for side in ["front","back","spine"]:
  var m=StandardMaterial3D.new()
  m.albedo_texture=load("res://cover_textures.gd").get_cover("res://assets/covers/%02d-%s.jpg"%[entry.id,side])
  m.roughness=.16
  m.clearcoat_enabled=true
  m.clearcoat=.8
  m.clearcoat_roughness=.10
  m.metallic_specular=.4
  m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
  var mesh=QuadMesh.new()
  mesh.size=Vector2(.127,.151 if ps3 else h-.009) if side!="spine" else Vector2(.010,.151 if ps3 else h-.009)
  var part=MeshInstance3D.new()
  part.name="PaperInsert_"+side
  part.mesh=mesh
  part.material_override=m
  part.position.y=-.005 if ps3 else 0
  if side=="front":part.position.z=.00715
  elif side=="back":
   part.position.z=-.00715
   part.rotation.y=PI
  else:
   part.position.x=-.0676
   part.rotation.y=-PI/2
  part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  item.add_child(part)
static func set_detail(item:Node3D, enabled:bool)->void:
 for part in item.get_children():
  if part is MeshInstance3D and str(part.name).begins_with("PaperInsert_"):
   var sleeve:StandardMaterial3D=part.material_override.duplicate()
   sleeve.clearcoat_enabled=enabled
   sleeve.roughness=.16 if enabled else .62
   part.material_override=sleeve
 var body=item.get_node_or_null("MoldedPlasticOnly")
 if not body:return
 var platform:String=body.get_meta("plastic_platform")
 if enabled:
  body.material_override=plastics[platform]
 else:
  if not resting_plastics.has(platform):
   var mat:StandardMaterial3D=plastics[platform].duplicate()
   mat.normal_enabled=false
   mat.roughness_texture=null
   mat.albedo_color.a=1.0
   mat.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
   mat.roughness=.45
   resting_plastics[platform]=mat
  body.material_override=resting_plastics[platform]
static func rounded_shell(w:float,h:float,d:float)->ArrayMesh:
 var st=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rings=[]
 for level in range(4):
  var inset=.001 if level==0 or level==3 else 0.0
  var z=[-d/2,-d/2+.001,d/2-.001,d/2][level]
  var ring=[]
  for corner in range(4):
   var angle=corner*PI/2
   var center=Vector2((w/2-.004)*(1 if corner==0 or corner==3 else -1),(h/2-.004)*(1 if corner<2 else -1))
   for step in range(7):
    var a=angle+step*PI/12
    ring.append(Vector3(center.x+(.004-inset)*cos(a),center.y+(.004-inset)*sin(a),z))
  rings.append(ring)
 for level in range(3):
  for i in range(28):
   var j=(i+1)%28
   for v in [rings[level][i],rings[level+1][i],rings[level+1][j],rings[level][i],rings[level+1][j],rings[level][j]]:
    st.set_uv(Vector2(v.x/w+.5,.5-v.y/h)*3.0)
    st.add_vertex(v)
 for i in range(28):
  var j=(i+1)%28
  for v in [Vector3(0,0,-d/2),rings[0][i],rings[0][j],Vector3(0,0,d/2),rings[3][j],rings[3][i]]:
   st.set_uv(Vector2(v.x/w+.5,.5-v.y/h)*3.0)
   st.add_vertex(v)
 st.generate_normals()
 st.generate_tangents()
 return st.commit()
