extends SceneTree
var failures:=0
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func _initialize():
 await process_frame
 var g=load("res://main.tscn").instantiate()
 root.add_child(g)
 await process_frame
 check(g.layout.movies.size()==60 and g.dvd_groups.size()==60,"24 films plus 36 distinct console games")
 check(g.dvd_records.size()==1629,"Original number of shelf cases preserved")
 var consoles:Dictionary={}
 var titles:Dictionary={}
 var copies:=0
 var misplaced:=0
 for r in g.dvd_records:
  if int(r.movie)>=24:
   copies+=1
   titles[r.movie]=true
   consoles[g.layout.movies[r.movie].console]=true
   if not load("res://games_catalogue.gd").right_aisle(r.world.origin):misplaced+=1
 check(copies==375 and misplaced==0,"Games replace only the rightmost aisle's 375 cases")
 check(consoles.size()==6 and titles.size()==36,"Every platform contains all six selected games")
 var per_console:Dictionary={}
 for r in g.layout.movies:
  if r.get("kind","")=="game":per_console[r.console]=per_console.get(r.console,0)+1
 check(per_console.values().all(func(n):return n==6),"Exactly six unique games per platform")
 check(g.held_pool.size()==60 and g.poster_cache.size()==60,"All film and game covers prepared before pickup")
 check(g.trailer_streams.size()==60,"Every film and game has a local matching video")
 var videos_ok:=true
 for id in range(24,60):
  g._play_trailer(id)
  if g.active_trailer!=id or g.trailer_player.stream!=g.trailer_streams[id]:videos_ok=false
 check(videos_ok,"All 36 game selections switch the shared CRT player to their own video")
 check(g.screens.all(func(screen):return screen.material_override.albedo_texture==g.screen_view.get_texture()),"All five TVs retain the same synchronized video texture")
 var first:Dictionary
 for r in g.dvd_records:
  if int(r.movie)==24:first=r;break
 g._take(first,0,false)
 check(g.held!=null and g.movie_id==24,"Game can be picked up using existing grip orientation")
 g._flip_held()
 await create_timer(.4).timeout
 check(g.held_back,"Game can be flipped to its back")
 g._release()
 await create_timer(.4).timeout
 check(g.held==null,"Game returns to original shelf slot")
 g.hud.visible=false
 g.head.global_position=Vector3(4.8,1.60,4.35)
 g.head.look_at(Vector3(3.2,1.15,.4))
 await create_timer(.8).timeout
 root.get_texture().get_image().save_png("res://../rayon-jeux-droite-xbox-ps2-gamecube.png")
 g.head.global_position=Vector3(1.65,1.60,4.25)
 g.head.look_at(Vector3(2.9,1.15,.4))
 await create_timer(.5).timeout
 root.get_texture().get_image().save_png("res://../rayon-jeux-droite-wii-360-ps3.png")
 print("GAME_AISLE_TESTS failures=",failures," copies=",copies)
 quit(1 if failures else 0)
