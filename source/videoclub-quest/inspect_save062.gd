extends SceneTree
func _initialize():
 await process_frame
 var g=load("res://main.tscn").instantiate()
 root.add_child(g)
 g.clerk.set_physics_process(false)
 g.clerk.customers.set_physics_process(false)
 g.session.save_path="C:/Users/recto/Documents/Codex/2026-11-01/va-x20/work/review-062/quest-save-061.dat"
 var ok=g.session.restore_file()
 print("ACTUAL_QUEST_SAVE migrated=",ok," cases=",g.clerk.cases.size()," loose_discs=",g.clerk.inspection.loose_discs.size()," day=",g.clerk.shift.day)
 g.origin.transform=Transform3D.IDENTITY
 g.head.position=Vector3(.12,1.6,-7.1)
 g.head.look_at(Vector3(.12,1.38,-6.3))
 g.hud.visible=false
 g.clerk.page=0
 g.clerk.refresh_terminal()
 await create_timer(.5).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../checkout-save062-preview.png")
 g.head.position=Vector3(2.6,1.8,-7.5)
 g.head.look_at(Vector3(.3,1.0,-8.8))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../sorting-save062-preview.png")
 quit(0 if ok else 1)
