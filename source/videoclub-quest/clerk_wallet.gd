extends Node3D
var clerk
var game
var palms=[[],[]]
var roots:Array=[]
var totals:Array=[]
var loose:Array=[]
var supported=[false,false]
var palm_bones:Array=[]
var safety_timer=0.0
func setup(c):
	clerk=c
	game=c.game
	for i in range(2):
		var root=Node3D.new()
		game.hands[i].add_child(root)
		root.position=Vector3(0,-.015,-.07)
		roots.append(root)
		var s:Skeleton3D=game.hand_visuals[i].skeleton
		palm_bones.append([s.find_bone("wrist"),s.find_bone("middle-finger-phalanx-proximal"),s.find_bone("index-finger-phalanx-proximal"),s.find_bone("pinky-finger-phalanx-proximal")])
		var label=clerk.Props.label(root,"",Vector3(0,.07,0),.0008,44)
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test=true
		label.modulate=Color.WHITE
		label.outline_size=8
		totals.append(label)
func occupied(hand:int)->bool:return not palms[hand].is_empty()
func total(hand:int)->int:
	var sum=0
	for entry in palms[hand]:sum+=entry.value
	return sum
func arrange(hand:int):
	var bills=0
	var coins=0
	for entry in palms[hand]:
		var n:Node3D=entry.node
		if entry.value>=500:
			n.position=Vector3(bills*.008,.004+bills*.002,.025)
			n.rotation=Vector3(0,bills*.10,0)
			bills+=1
		else:
			n.position=Vector3((coins%3-1)*.028,.006+(coins/6)*.004,-.035-(coins/3%2)*.028)
			n.rotation=Vector3.ZERO
			coins+=1
	totals[hand].text=("%.2f $"%(total(hand)/100.0)) if occupied(hand) else ""
func take(hand:int,value:int,tender:bool=false):
	if hand==clerk.basket.hand or hand==game.held_hand or hand==clerk.secondary_hand or clerk.locks.occupies(hand) or hand==clerk.inspection.finger or palms[hand].size()>=32:return
	if tender:
		if not clerk.tender_note.visible:
			game._message("Le client n'a plus d'argent à prendre sur le comptoir.")
			return
		clerk.active.cash_started=true
		if not clerk.tender_parts.is_empty():
			value=clerk.tender_parts.pop_front()
			clerk.refresh_tender_visual()
		else:clerk.tender_note.visible=false
	else:
		if not clerk.drawer_open or not (clerk.tender_received or clerk.active.get("await_cash",false)) or clerk.till[value]<=0:return
		clerk.till[value]-=1
		clerk.track_cash_delta(value,-1,int(clerk.active.get("id",-1)))
	var n=clerk.make_money(value)
	roots[hand].add_child(n)
	palms[hand].append({"node":n,"value":value,"tender":tender,"customer_id":clerk.active.get("id",-1)})
	arrange(hand)
func remove_one(hand:int,index:int,deposit:bool):
	var entry=palms[hand][index]
	if deposit:deposit_entry(entry)
	entry.node.queue_free()
	palms[hand].remove_at(index)
	arrange(hand)
	clerk.refresh_terminal()
func deposit_entry(entry:Dictionary):
	clerk.till[entry.value]+=1
	clerk.track_cash_delta(int(entry.value),1,int(entry.get("customer_id",-1)))
	if entry.tender and entry.get("customer_id",-1)==clerk.active.get("id",-2):
		clerk.tender_deposited+=entry.value
		clerk.tender_received=clerk.tender_deposited>=clerk.tender
		if clerk.tender_received and clerk.tender==clerk.price:clerk.paid=true

func record_change(amount:int):
	if clerk.active.get("is_refund",false):
		clerk.complete_refund(amount)
		return
	clerk.change+=amount
	clerk.paid=true
	clerk.refresh_terminal()

func can_return_tender(hand:int)->bool:
	return not clerk.active.is_empty() and occupied(hand) and palms[hand].all(func(entry):return entry.get("tender",false) and int(entry.get("customer_id",-1))==int(clerk.active.id))

func give_customer(hand:int)->bool:
	if clerk.active.is_empty() or not occupied(hand):return false
	if can_return_tender(hand):
		while occupied(hand):remove_one(hand,0,false)
		clerk.try_finish_checkout()
		clerk.refresh_terminal()
		game._message("Son argent est rendu au client.")
		return true
	if not (clerk.tender_received or clerk.active.get("await_cash",false)):return false
	for entry in palms[hand]:
		if entry.tender:return false
	record_change(total(hand))
	while occupied(hand):remove_one(hand,0,false)
	clerk.try_finish_checkout()
	clerk.refresh_terminal()
	game._message("Monnaie remise dans la main du client.")
	return true

func interact(hand:int,grip:bool)->bool:
	var p:Vector3=game.hands[hand].global_position
	if grip:
		if hand==clerk.basket.hand or hand==game.held_hand or hand==clerk.secondary_hand or clerk.locks.occupies(hand) or hand==clerk.inspection.finger:return false
		# Remove one selected piece from the other palm, without inventing money.
		var other=1-hand
		for entry in loose:
			if reach_distance(hand,entry.node.global_position)<.14 and palms[hand].size()<32:
				return pick_loose(hand,entry)
		var palm_piece={}
		var palm_distance=.10
		for entry in palms[other]:
			var gap=clerk.inspection.finger_transform(hand).origin.distance_to(entry.node.global_position)
			if gap<palm_distance:
				palm_piece=entry
				palm_distance=gap
		if not palm_piece.is_empty() and palms[hand].size()<32:
			palms[other].erase(palm_piece)
			palms[hand].append(palm_piece)
			palm_piece.node.reparent(roots[hand],false)
			supported[hand]=false
			arrange(other)
			arrange(hand)
			return true
		var closest={}
		var distance=.11
		for target in clerk.targets:
			if target.action=="tender" and clerk.tender_note.visible and reach_distance(hand,target.node.global_position)<.15:
				while clerk.tender_note.visible and palms[hand].size()<32:
					var count=palms[hand].size()
					take(hand,clerk.tender,true)
					if palms[hand].size()==count:break
				return true
			if target.action=="money" and clerk.drawer_open:
				var gap=reach_distance(hand,target.node.global_position)
				if gap<distance:
					distance=gap
					closest=target
		if not closest.is_empty():
			take(hand,closest.value)
			return true
		return occupied(hand)
	if not occupied(hand):return false
	release_grip(hand)
	return true
func pick_loose(hand:int,entry:Dictionary)->bool:
	if palms[hand].size()>=32 or entry not in loose:return false
	var body=entry.body
	entry.node.reparent(roots[hand],false)
	body.queue_free()
	entry.erase("body")
	loose.erase(entry)
	palms[hand].append(entry)
	supported[hand]=false
	arrange(hand)
	return true

func reach_distance(hand:int,p:Vector3)->float:
	return minf(game.hands[hand].global_position.distance_to(p),minf(roots[hand].global_position.distance_to(p),clerk.inspection.finger_transform(hand).origin.distance_to(p)))
func release_grip(hand:int):
	if not occupied(hand):return
	var p:Vector3=game.hands[hand].global_position
	# A receiving palm wins over the drawer underneath it.
	var other=1-hand
	if game.held_hand!=other and clerk.secondary_hand!=other and not clerk.locks.occupies(other) and clerk.inspection.finger!=other and roots[hand].global_position.distance_to(roots[other].global_position)<.22:
		for entry in palms[hand].duplicate():
			if palms[other].size()>=32:break
			palms[hand].erase(entry)
			palms[other].append(entry)
			entry.node.reparent(roots[other],false)
		supported[other]=true
		supported[hand]=false
		arrange(hand)
		arrange(other)
		if not occupied(hand):return
	if clerk.in_customer_zone(p):
		if give_customer(hand):return
	if clerk.drawer_open and inside_drawer(p):
		while occupied(hand):remove_one(hand,palms[hand].size()-1,true)
		supported[hand]=false
		return
	drop_all(hand)
func inside_drawer(p:Vector3)->bool:
	var local=clerk.drawer.to_local(p)
	return absf(local.x)<.39 and absf(local.z)<.24 and local.y>-.03 and local.y<.22
func drop_all(hand:int):
	for entry in palms[hand].duplicate():
		if load("res://club_surface_drop.gd").release_cash_entry(self,entry,entry.node.global_transform,game.head.global_position):
			palms[hand].erase(entry)
			entry.body.linear_velocity=game.candy.hand_velocity(hand).limit_length(3)
	supported[hand]=false
	arrange(hand)

func recover_cash():
	for entry in loose:
		if not is_instance_valid(entry.get("body")):continue
		var body:RigidBody3D=entry.body
		var point:=PhysicsPointQueryParameters3D.new()
		point.position=body.global_position
		point.collision_mask=1
		var inside:bool=not body.get_world_3d().direct_space_state.intersect_point(point,1).is_empty()
		if body.global_position.y>=-.1 and not inside:continue
		var desired:Transform3D=entry.get("last_safe",Transform3D(Basis.IDENTITY,Vector3(-.1,1.8,-6.2)))
		var safe:Vector3=load("res://club_drop_safety.gd").position_for(body,desired.origin,desired.basis)
		if not safe.is_finite():continue
		body.freeze=true
		body.global_transform=Transform3D(desired.basis,safe)
		body.linear_velocity=Vector3.ZERO
		body.angular_velocity=Vector3.ZERO
		body.freeze=false
		body.sleeping=false

func _physics_process(_dt):
	safety_timer-=_dt
	if safety_timer<=0:
		safety_timer=.5
		recover_cash()
	for hand in range(2):
		var s:Skeleton3D=game.hand_visuals[hand].skeleton
		var bones:Array=palm_bones[hand]
		if bones.has(-1):continue
		var wrist=s.to_global(s.get_bone_global_pose(bones[0]).origin)
		var middle=s.to_global(s.get_bone_global_pose(bones[1]).origin)
		var index=s.to_global(s.get_bone_global_pose(bones[2]).origin)
		var pinky=s.to_global(s.get_bone_global_pose(bones[3]).origin)
		var x=(index-pinky).normalized()*(1 if hand==0 else -1)
		# The asset's +Y wrist side is the back of the hand; cash sits on the palm.
		var y=-x.cross((middle-wrist).normalized()).normalized()
		var z=x.cross(y).normalized()
		roots[hand].global_transform=Transform3D(Basis(x,y,z).orthonormalized(),wrist.lerp(middle,.62)+y*.035)
	# A deposited handful stays supported until deliberately picked up/released.
	# Controller grip axes are not a reliable palm-up detector.
