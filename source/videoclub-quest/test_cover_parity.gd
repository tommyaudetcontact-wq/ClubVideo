extends SceneTree
var failures=0
func check(ok,label):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func _initialize():
 await process_frame
 root.size=Vector2i(1920,1200)
 var g=load("res://main.tscn").instantiate()
 root.add_child(g)
 var full=true
 var shared=true
 for id in g.held_pool:
  for side in ["front","back","spine"]:
   var path="res://assets/covers/%02d-%s.jpg"%[id,side]
   var original:Texture2D=load(path)
   var actual:Texture2D=g.held_pool[id].get_node("PaperInsert_"+side).material_override.albedo_texture
   full=full and actual.get_size()==original.get_size() and actual.get_image().get_format()==Image.FORMAT_RGBA8 and actual.get_image().has_mipmaps()
   if side!="spine":
    var side_id=0 if side=="front" else 1
    shared=shared and actual==g.lod_groups[id][side_id].multimesh.mesh.material.albedo_texture
 check(full,"All 180 held paper faces retain original resolution, RGBA8 and mipmaps")
 check(shared,"Held and shelf faces share textures without duplicate GPU allocation")
 check(g.COVER_DETAIL_BUDGET==48,"Quest shelf LOD budget unchanged")
 check(g.baked_lighting_active,"Quest lighting retained")
 g.origin.transform=Transform3D.IDENTITY
 g.head.position=Vector3(0,1.6,4)
 g.head.rotation=Vector3.ZERO
 g.head.fov=65
 g.hud.visible=false
 var ids=[0,36]
 for i in range(2):
  var item=g.held_pool[ids[i]]
  item.position=Vector3(-.09+i*.18,1.6,3.62)
  item.visible=true
 await create_timer(2).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../quest-jaquettes-detail-047.png")
 for id in ids:g.held_pool[id].rotation.y=PI
 await create_timer(.5).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../quest-jaquettes-dos-047.png")
 print("COVER_PARITY_TESTS failures=",failures)
 quit(1 if failures else 0)
