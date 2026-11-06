extends Node3D
const Props=preload("res://clerk_props.gd")
const Actor=preload("res://customer_actor.gd")
const MAX_VISIBLE_PEOPLE=8
const VisitIcons=preload("res://club_visit_icons.gd")
var game
var clerk
var grid=AStarGrid2D.new()
var customers:Array=[]
var spawn_timer=3.0
var arrival_cluster_left=0
var last_arrival_kind=-1
var next_id=0
var clock=0.0
var queue_gate=0.0
var walk_cache={}
func setup(g,c):
	game=g
	clerk=c
	grid.region=Rect2i(-24,-30,48,72)
	grid.cell_size=Vector2(.25,.25)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(-24,24):
		for z in range(-30,42):
			var p=Vector3(x*.25,0,z*.25)
			for b in game.layout.colliders:
				if p.x>b.min[0]-.24 and p.x<b.max[0]+.24 and p.z>b.min[2]-.24 and p.z<b.max[2]+.24:
					grid.set_point_solid(Vector2i(x,z))
					break
func route(c:Dictionary,target:Vector3)->bool:
	var start=Vector2i(roundi(c.node.global_position.x/.25),roundi(c.node.global_position.z/.25))
	var end=Vector2i(roundi(target.x/.25),roundi(target.z/.25))
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(end) or grid.is_point_solid(end):return false
	c.path=grid.get_point_path(start,end)
	c.cursor=1
	return not c.path.is_empty()
func spawn_customer():
	if customers.size()>=clerk.shift.capacity() or population()>=MAX_VISIBLE_PEOPLE:return
	var n=Props.customer(self,next_id%6)
	n.position=Vector3(-4.0,0,9.0)
	var c={"node":n,"id":next_id,"state":"enter","path":PackedVector2Array(),"cursor":0,"wait":0.0,"messy":randf()<minf(.40,.18+.02*clerk.shift.day),"movie":randi_range(0,game.layout.movies.size()-1)}
	next_id+=1
	customers.append(c)
	var remaining:=MAX_VISIBLE_PEOPLE-population()
	var group:=randf()
	c.companions=[]
	if remaining>=1 and group<.24:
		c.family=true
		c.children_mess_count=randi_range(1,3) if randf()<.30 else 0
		c.children_mess_delay=randf_range(8,25)
		c.companions.append(randi_range(6,7))
		if remaining>=2 and randf()<.38:c.companions.append((c.companions[0]+1)%2+6)
	elif remaining>=1 and group<.44:
		c.companions.append((int(c.id)%6+randi_range(1,5))%6)
	attach_companions(c)
	c.return_job=clerk.take_due_return()
	c.account_id=int(c.return_job.get("account_id",-1))
	if c.account_id<0:c.account_id=clerk.accounts.choose_account(customers.map(func(customer):return int(customer.get("account_id",-1))))
	c.visit_balance=int(clerk.accounts.ensure(c.account_id).balance)
	c.return_and_rent=not c.return_job.is_empty() and randf()<.55
	c.visit_mask=VisitIcons.reason_mask(c)
	VisitIcons.update(n,c.visit_mask,int(c.get("rental_count",1)))
	if not c.return_job.is_empty():
		c.return_job.account_id=c.account_id
		var carry=Node3D.new()
		Actor.equip(n,carry)
		load("res://held_case.gd").build(carry,game.layout.movies[c.return_job.movie])
		c.carry=carry
	route(c,Vector3(-4,0,4.5))
func attach_companions(customer:Dictionary):
	var parent:Node3D=customer.node
	for i in range(customer.get("companions",[]).size()):
		var model:int=customer.companions[i]
		var follower:=Props.customer(parent,model)
		follower.name="Companion%d"%i
		follower.position=Vector3(.28 if i==0 else -.23,0,.53+i*.41)
		if model>=6 and not follower.has_node("ActorVisual"):follower.scale=Vector3.ONE*.66

func population()->int:
	var total:=customers.size()
	for customer in customers:total+=customer.get("companions",[]).size()
	return total

func traffic_interval(_progress:float,_day:int)->Vector2:
	var pressure:=minf(8,float(maxi(0,clerk.shift.wave-1))*1.5)
	return Vector2(14-pressure,22-pressure)

func _physics_process(dt):
	if not game:return
	clock+=dt
	spawn_timer-=dt
	if spawn_timer<=0 and customers.size()<clerk.shift.capacity() and population()<MAX_VISIBLE_PEOPLE and clerk.shift.can_spawn():
		spawn_customer()
		clerk.shift.spawned()
		spawn_timer=next_arrival_delay()
	for c in customers.duplicate():
		var moving=false
		if c.cursor<c.path.size():
			var p:Vector2=c.path[c.cursor]
			var target=Vector3(p.x,0,p.y)
			var offset=target-c.node.position
			var blocked=false
			for other in customers:
				if other.id<c.id and c.node.position.distance_to(other.node.position)<.65:blocked=true
			var player=game.head.global_position
			player.y=0
			if c.node.position.distance_to(player)<.48:blocked=true
			var remote:Node3D=clerk.lan.remote_avatar
			if is_instance_valid(remote) and remote.valid_pose:
				var guest:Vector3=remote.targets[0].origin
				guest.y=0
				if c.node.position.distance_to(guest)<.48:blocked=true
			if offset.length()<.07:c.cursor+=1
			elif not blocked:
				c.node.position+=offset.normalized()*minf(dt*.95,offset.length())
				c.node.rotation.y=lerp_angle(c.node.rotation.y,atan2(-offset.x,-offset.z),minf(1,dt*8))
				moving=true
		else:
			match c.state:
				"approach_counter":
					c.state="service"
					c.patience=0.0
				"enter":
					if not c.return_job.is_empty():
						c.state="return_drop"
						route(c,Vector3(-2.5,0,-4.8))
					else:begin_browse(c)
				"return_counter":
					c.state="return_drop"
					route(c,Vector3(-2.5,0,-4.8))
				"replacement_browse":
					c.wait-=dt
					if c.wait<=0:
						var candidate=clerk.reserve_stock(c.get("replacement_movie",randi_range(0,game.layout.movies.size()-1)))
						if not candidate.is_empty():
							clerk.replace_requested_title(c.replace_title,candidate)
							c.state="replacement_return"
							route(c,Vector3(-.6,0,-5.05))
						else:choose_alternative(c,c.replace_title,true)
				"replacement_return":
					c.state="service"
					c.node.rotation.y=0
					if not c.get("replacement_queue",[]).is_empty():
						var next_title=c.replacement_queue.pop_front()
						choose_alternative(c,next_title)
					clerk.refresh_terminal()
				"return_drop":
					var job:Dictionary=c.return_job
					var jobs:Array=[job]+job.get("others",[])
					var refund:=0
					for returned_job in jobs:
						clerk.deliver_return(returned_job,c)
						refund+=int(returned_job.get("refund",0))
					c.return_job={}
					if refund>0:
						c.is_refund=true
						c.refund_due=refund
						join_queue(c)
					elif c.get("return_and_rent",false):
						c.return_and_rent=false
						begin_browse(c)
					else:dismiss(c)
				"browse":
					if not c.has("reservations"):
						begin_browse(c)
						continue
					c.wait-=dt
					var index=int(c.get("browse_index",0))
					if index<c.reservations.size():
						var toward:Vector3=c.reservations[index].world.origin-c.node.position
						c.node.rotation.y=lerp_angle(c.node.rotation.y,atan2(-toward.x,-toward.z),minf(1,dt*5))
					if c.messy and not c.get("mess_done",false) and index==c.get("next_mess",0) and c.wait<3:
						clerk.make_mess(c)
						c.mess_done=true
					if c.wait<=0:
						if c.has("carry") and is_instance_valid(c.carry):c.carry.visible=true
						c.browse_index=index+1
						if c.browse_index<c.reservations.size():browse_next(c)
						else:
							join_queue(c)
				"queue":
					if clock<queue_gate:continue
					if c.node.has_node("ActorVisual") and c.has("carry") and is_instance_valid(c.carry) and c.carry.visible:
						if not c.has("handoff_wait"):
							c.handoff_wait=1.70
							Actor.animate(c.node,"HandOff")
						c.handoff_wait-=dt
						if c.handoff_wait>0:continue
					c.erase("handoff_wait")
					queue_gate=clock+12.0
					c.state="service"
					c.node.rotation.y=0
					clerk.customer_ready(c)
				"exit":
					customers.erase(c)
					c.node.queue_free()
					continue
		update_children(c,dt)
		update_service_visual(c,dt)
		var holding:bool=c.has("carry") and is_instance_valid(c.carry) and c.carry.visible
		var picking:bool=c.state=="browse" and not moving and c.cursor>=c.path.size() and c.wait<2.65
		if picking and c.wait<1.21 and c.has("carry") and is_instance_valid(c.carry):c.carry.visible=true
		if c.node.has_node("ActorVisual"):
			var key:="Receive" if c==clerk.active and c.state=="service" else "Pick" if picking else ("CarryWalk" if holding else "Walk") if moving else ("CarryIdle" if holding else "Idle")
			Actor.animate(c.node,key)
			for i in range(c.get("companions",[]).size()):
				var follower:Node3D=c.node.get_node_or_null("Companion%d"%i)
				if follower and not follower.has_meta("aisle_run"):Actor.animate(follower,"Walk" if moving else "Idle")
		else:
			for side in [-1,1]:
				c.node.get_node("Arm"+str(side)).scale.y=1.6 if c==clerk.active and side==1 else 1.0
				c.node.get_node("Leg"+str(side)).rotation.x=sin(clock*8+side*PI/2)*(.30 if moving else 0)
				c.node.get_node("Arm"+str(side)).rotation.x=1.25 if c==clerk.active and side==1 else -sin(clock*8+side*PI/2)*(.25 if moving else 0)
func update_children(c:Dictionary,dt:float):
	if not c.get("family",false):return
	if not c.has("children_mess_count"):
		c.children_mess_count=randi_range(1,3) if randf()<.30 else 0
		c.children_mess_delay=randf_range(8,25)
	c.children_mess_delay=maxf(0,float(c.get("children_mess_delay",0))-dt)
	if c.children_mess_count>0 and c.children_mess_delay<=0 and c.state not in ["enter","exit"] and not c.get("children_played",false):
		c.children_played=true
		for i in range(c.companions.size()):
			var child:Node3D=c.node.get_node_or_null("Companion%d"%i)
			if not child or int(c.companions[i])<6:continue
			var run:Dictionary={"node":child}
			if route(run,Vector3(-1.0 if i==0 else 1.0,0,.5)):
				child.set_meta("aisle_run",{"path":run.path,"cursor":1,"home":child.position,"drop":c.children_mess_count,"back":false})
				break
	for i in range(c.companions.size()):
		var child:Node3D=c.node.get_node_or_null("Companion%d"%i)
		if not child or not child.has_meta("aisle_run"):continue
		var run:Dictionary=child.get_meta("aisle_run")
		if run.cursor>=run.path.size():
			if not run.back:
				for j in range(run.drop):clerk.make_mess({"node":child})
				run.back=true
			var home:Vector3=c.node.to_global(run.home)
			var route_back:Dictionary={"node":child}
			if not run.get("routed_home",false):
				run.routed_home=true
				if route(route_back,home):
					run.path=route_back.path
					run.cursor=1
			if run.cursor>=run.path.size() or child.global_position.distance_to(home)<.36:
				child.position=run.home
				child.rotation.y=0
				child.remove_meta("aisle_run")
				continue
		var point:Vector2=run.path[run.cursor]
		var target:=Vector3(point.x,0,point.y)
		var offset:=target-child.global_position
		child.global_position=child.global_position.move_toward(target,dt*2.1)
		if offset.length()>.05:child.global_rotation.y=atan2(-offset.x,-offset.z)
		else:run.cursor+=1
		Actor.animate(child,"Walk")

func dismiss(c:Dictionary):
	c.state="exit"
	route(c,Vector3(-4,0,9.0))

func choose_alternative(c:Dictionary,title:int,retry:bool=false):
	if not retry and c.state in ["replacement_browse","replacement_return"]:
		if not c.has("replacement_queue"):c.replacement_queue=[]
		if not c.replacement_queue.has(title):c.replacement_queue.append(title)
		return
	var excluded=clerk.active.get("missing",[]).duplicate()
	for item in clerk.active.get("items",[]):excluded.append(item.movie)
	var candidates=game.dvd_records.filter(func(r):return not excluded.has(r.movie) and not r.get("clerk_reserved",false) and not r.get("loose",false))
	if candidates.is_empty():
		c.state="service"
		game._message("Aucun autre titre disponible pour ce client.")
		return
	var record:Dictionary=candidates.pick_random()
	c.replacement_movie=record.movie
	c.replace_title=title
	c.wait=randf_range(6,11)
	c.state="replacement_browse"
	route(c,aisle_for(record.world.origin))

func aisle_for(shelf:Vector3)->Vector3:
	var key=Vector2i(roundi(shelf.x*4),roundi(shelf.z*4))
	if walk_cache.has(key):return walk_cache[key]
	var best=Vector3(-4,0,1.5)
	var distance=INF
	for x in range(key.x-6,key.x+7):
		for z in range(key.y-6,key.y+7):
			var cell=Vector2i(x,z)
			if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):continue
			var point=Vector3(x*.25,0,z*.25)
			var gap=Vector2(point.x-shelf.x,point.z-shelf.z).length_squared()
			if gap<distance:
				best=point
				distance=gap
	walk_cache[key]=best
	return best
func begin_browse(c:Dictionary):
	if not clerk.select_film(c):
		dismiss(c)
		return
	c.browse_index=0
	c.next_mess=randi_range(0,c.reservations.size()-1)
	c.mess_done=false
	if c.has("carry") and is_instance_valid(c.carry):c.carry.visible=false
	browse_next(c)
func browse_next(c:Dictionary):
	c.state="browse"
	c.wait=randf_range(6,12)
	var record:Dictionary=c.reservations[c.browse_index]
	if not route(c,aisle_for(record.world.origin)):
		# A blocked shelf never creates a permanently stuck customer.
		c.wait=2.0
		c.path=PackedVector2Array()
		c.cursor=0

func update_service_visual(c:Dictionary,dt:float):
	var at_counter=c.state=="service"
	if at_counter:
		var toward:Vector3=game.head.global_position-c.node.global_position
		if toward.length_squared()>.01:c.node.rotation.y=lerp_angle(c.node.rotation.y,atan2(-toward.x,-toward.z),minf(1,dt*6))
	var bar=c.node.get_node_or_null("Patience")
	if bar:bar.hide()
	VisitIcons.update(c.node,VisitIcons.reason_mask(c),int(c.get("rental_count",1)))

func next_arrival_delay()->float:
	if arrival_cluster_left>0:
		arrival_cluster_left-=1
		return randf_range(1.8,4.5)
	var roll:=randf()
	var kind:=0 if roll<.50 else 1 if roll<.80 else 2
	if kind==last_arrival_kind:kind=(kind+1+randi_range(0,1))%3
	last_arrival_kind=kind
	var pressure:=clampf((clerk.shift.wave-1)*.06,0,.35)
	if kind==1:
		arrival_cluster_left=randi_range(1,2)
		return randf_range(2,5)
	if kind==2:return randf_range(30,55)*(1-pressure)
	return randf_range(12,26)*(1-pressure)

func join_queue(customer:Dictionary):
	var occupied:Array=[] if clerk.active.is_empty() else [0]
	for other in customers:
		if other!=customer and other!=clerk.active and other.state in ["queue","service","approach_counter","replacement_browse","replacement_return"]:occupied.append(int(other.get("queue_slot",0)))
	var slot:=0
	while occupied.has(slot) and slot<7:slot+=1
	customer.queue_slot=slot
	customer.state="queue"
	var x:Array=[-.6,.25,1.10,1.95,2.80,3.65,-1.45,-2.30]
	route(customer,Vector3(x[slot],0,-5.05))
