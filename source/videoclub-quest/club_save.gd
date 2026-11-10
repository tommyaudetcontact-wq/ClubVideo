extends Node
const VERSION=2
const CASE_META=["basket_owner","disc_movie","disc_uid","disc_mismatch_seen","dirty","inspected","antitheft","sort_slot","in_basket","in_sort_tray","barcode_scanned","needs_relock","return_account","return_cycle","return_checked","returned_damage"]
const SHIFT_FIELDS=["quota_model","target_customers","arrived_customers","week_losses","week_abandoned","week_refunds","week_cash_error","week_perfect","day_model","rush_model","day","duration","time_left","closing","summary","started","served","abandoned","lost_sales","missed_scans","revenue","refunds","returned","restocked","damaged","initial_cash","wave","break_left","report","business_balance"]
const COUNTER_FIELDS=["price","tender","tender_parts","tender_received","tender_deposited","paid","change","drawer_open","page","rentals","elapsed","customer_delay","chute_serial","tasks","reminders"]
const CLIENT_FIELDS=["appearance","selection_left","nav_goal","queue_joined","pending_finish","await_cash","abandon_wait_cash","patience_limit","patience_started","rental_remaining","queue_slot","rental_count","visit_mask","is_refund","refund_due","children_mess_count","children_mess_delay","id","state","cursor","wait","messy","movie","patience","patience_bonus","missing","handed","is_return","replace_title","replacement_movie","replacement_queue","family","companions","children_played","handoff_wait","return_and_rent","browse_index","price_titles","discount","cash_started","next_mess","mess_done","account_id","visit_balance","account_due","offer_ready","subtotal","gst","qst","billed_titles"]
var game
var save_path="user://club-save.dat"
var autosave_clock=0.0
var load_failed=false
var tools_run=false
var last_status=""
var save_thread:Thread

func setup(g):
	game=g
	name="SavedGame"
	process_mode=Node.PROCESS_MODE_ALWAYS
	tools_run=OS.get_cmdline_args().has("--script")
	if not tools_run and (FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path+".bak")):
		load_failed=not restore_file()
		if load_failed:game._message("Sauvegarde incompatible : elle est conservée. Utilise Nouvelle partie pour recommencer.")
		else:
			game.clerk.set_physics_process(false)
			game.clerk.customers.set_physics_process(false)
			call_deferred("resume_prompt")

func resume_prompt():
	while game.xr_active and not game.spawn_centered:await get_tree().process_frame
	game.clerk.set_physics_process(true)
	game.clerk.customers.set_physics_process(true)
	if not game.modes.menu_open:game.modes.toggle_pause()

func _process(dt):
	if save_thread and not save_thread.is_alive():flush_worker()
	if tools_run or load_failed or get_tree().paused or guest_coop():return
	if not game.clerk.shift.started:return
	autosave_clock+=dt
	if autosave_clock>=60:
		autosave_clock=0
		start_autosave()

func start_autosave():
	if save_thread:return
	var data=snapshot().duplicate(true)
	var path=ProjectSettings.globalize_path(save_path)
	save_thread=Thread.new()
	if save_thread.start(store_snapshot.bind(data,path))!=OK:
		save_thread=null
		last_status="Sauvegarde automatique indisponible : utilise Sauvegarder."

func flush_worker():
	if not save_thread:return
	var success=save_thread.wait_to_finish()
	save_thread=null
	last_status="Partie sauvegardée automatiquement." if success else "Échec de sauvegarde : copie précédente conservée."

func _exit_tree():flush_worker()

func _notification(what):
	if what==NOTIFICATION_APPLICATION_PAUSED and game and not tools_run and not load_failed:save_game(false)

func record_id(record:Dictionary)->int:return int(record.get("id",-1))
func pack_job(job:Dictionary)->Dictionary:
	if job.is_empty():return {}
	return {"movie":job.movie,"time":job.get("time",0.0),"record":record_id(job.record),"account_id":int(job.get("account_id",-1)),"rental_id":int(job.get("rental_id",-1)),"refund":int(job.get("refund",0)),"locked":bool(job.get("locked",false)),"batch":int(job.get("batch",-1)),"billed":bool(job.get("billed",true)),"complaint":bool(job.get("complaint",false)),"charge":int(job.get("charge",0)),"others":job.get("others",[]).map(func(other):return pack_job(other))}
func unpack_job(job:Dictionary)->Dictionary:
	if job.is_empty():return {}
	return {"movie":job.movie,"time":job.time,"record":game.dvd_records[job.record],"account_id":int(job.get("account_id",-1)),"rental_id":int(job.get("rental_id",-1)),"refund":int(job.get("refund",0)),"locked":bool(job.get("locked",false)),"batch":int(job.get("batch",-1)),"billed":bool(job.get("billed",true)),"complaint":bool(job.get("complaint",false)),"charge":int(job.get("charge",0)),"others":job.get("others",[]).map(func(other):return unpack_job(other))}

func pack_case(item:Dictionary,node:Node3D)->Dictionary:
	var result={"movie":item.movie,"kind":item.kind,"scanned":item.get("scanned",false),"task":item.get("task",""),"record":record_id(item.get("record",{})),"transform":node.global_transform,"meta":{}}
	for key in CASE_META:result.meta[key]=node.get_meta(key,"host" if key=="basket_owner" else false if key in ["disc_mismatch_seen","dirty","inspected","antitheft","in_basket","in_sort_tray","barcode_scanned","needs_relock","return_checked","returned_damage"] else -1)
	if node==game.held or (not game.clerk.secondary.is_empty() and node==game.clerk.secondary.node):
		result.transform=Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3(1.45,1.16+.022*(game.clerk.cases.find(item)+1),-6.53))
	return result

func snapshot()->Dictionary:
	var c=game.clerk
	var state={"version":VERSION,"catalogue":game.layout.movies.size(),"records":[],"cases":[],"clients":[],"active":-1,"waiting":[],"returns":[],"loose_discs":[],"cash":[],"shift":{},"counter":{},"repair":{},"till":c.till.duplicate(),"spawn_timer":c.customers.spawn_timer,"next_id":c.customers.next_id,"processed":c.repairs.processed,"options":{"manual":game.modes.manual_mode,"rain":game.modes.rain_enabled,"teleport":game.teleportation.enabled}}
	state.return_schedule_version=2
	if game.streamer_mode:
		state.streamer_fallen=game.streamer.pack_fallen()
		state.streamer_challenge={"duration":game.streamer.duration_index,"remaining":game.streamer.challenge_remaining,"report":game.streamer.challenge_report}
	state.entry_cooldown=c.customers.entry_cooldown
	state.arrival_cluster_left=c.customers.arrival_cluster_left
	state.last_arrival_kind=c.customers.last_arrival_kind
	state.accounts=c.accounts.snapshot()
	state.loose_locks=c.locks.snapshot()
	state.queue_gap=maxf(0,c.customers.queue_gate-c.customers.clock)
	if is_instance_valid(c.lan.guest_basket_node):
		state.guest_basket_transform=Transform3D(Basis.IDENTITY,c.lan.guest_basket_node.home) if c.lan.guest_basket else c.lan.guest_basket_node.body.global_transform
	state.basket_transform=c.basket.body.global_transform if c.basket.hand<0 else Transform3D(Basis.IDENTITY,c.basket.home)
	if game.touch_profile and game.touch_controls and game.touch_controls.basket_carried:
		state.basket_transform=game.touch_controls.basket_resting_pose
	for record in game.dvd_records:
		state.records.append({"movie":record.movie,"disc_movie":record.get("disc_movie",record.movie),"disc_uid":record.get("disc_uid",record.id),"dirty":record.get("dirty",false),"locked":record.get("locked",true),"reserved":record.get("clerk_reserved",false)})
	var case_indices:Dictionary={}
	for i in c.cases.size():
		var item:Dictionary=c.cases[i]
		if item.kind=="streamer_gift":continue
		case_indices[i]=state.cases.size()
		state.cases.append(pack_case(item,item.node))
	# Shelf copies held or dropped manually become equivalent physical service cases.
	for record in game.dvd_records:
		var visual:Node3D=null
		if record==game.held_record and game.held:visual=game.held
		elif record.get("loose",false) and is_instance_valid(record.get("loose_body")):
			for child in record.loose_body.get_children():
				if child is Node3D and not child is CollisionShape3D:visual=child
		if visual:state.cases.append(pack_case({"movie":record.movie,"record":record,"kind":"shelve"},visual))
	for entry in state.cases:
		if entry.record>=0:
			var record=state.records[entry.record]
			record.reserved=true
			for key in ["disc_movie","disc_uid","dirty"]:record[key]=entry.meta[key]
	for customer in c.customers.customers:
		var entry={"position":customer.node.position,"rotation":customer.node.rotation,"record":record_id(customer.get("record",{})),"reservations":[],"items":[],"return_item":case_indices.get(c.cases.find(customer.get("return_item",{})),-1),"return_job":pack_job(customer.get("return_job",{})),"path":customer.path,"carry":customer.has("carry") and is_instance_valid(customer.carry) and customer.carry.visible}
		for key in CLIENT_FIELDS:
			if customer.has(key):entry[key]=customer[key]
		for record in customer.get("reservations",[]):entry.reservations.append(record_id(record))
		for item in customer.get("items",[]):entry.items.append(case_indices[c.cases.find(item)])
		state.clients.append(entry)
		if customer==c.active:state.active=state.clients.size()-1
	for customer in c.waiting:state.waiting.append(c.customers.customers.find(customer))
	for job in c.returns_due:state.returns.append(pack_job(job))
	for key in SHIFT_FIELDS:state.shift[key]=c.shift.get(key)
	for key in COUNTER_FIELDS:state.counter[key]=c.get(key)
	for loose in c.inspection.loose_discs:
		state.loose_discs.append({"data":loose.data.duplicate(),"transform":loose.node.global_transform,"physical":is_instance_valid(loose.get("body"))})
	var guest=c.lan.guest_inspection
	if is_instance_valid(guest) and is_instance_valid(guest.carried):
		state.loose_discs.append({"data":guest.carried_data.duplicate(),"transform":Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3(1.65,.916,-8.7))})
	if is_instance_valid(c.inspection.carried):
		state.loose_discs.append({"data":c.inspection.carried_data.duplicate(),"transform":Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3(.3,.916,-8.7))})
	if is_instance_valid(c.repairs.disc):
		state.repair={"data":c.repairs.data.duplicate(),"remaining":c.repairs.remaining,"source":record_id(c.repairs.source.get_meta("inventory_record",{})) if is_instance_valid(c.repairs.source) else -1}
	for entry in c.wallet.loose:state.cash.append(pack_cash(entry,entry.node.global_transform))
	for entry in c.lan.guest_cash:state.cash.append(pack_cash(entry,entry.node.global_transform))
	for hand in range(2):
		for i in range(c.wallet.palms[hand].size()):
			var entry=c.wallet.palms[hand][i]
			state.cash.append(pack_cash(entry,Transform3D(Basis.IDENTITY,Vector3(.9+hand*.18,1.16+i*.005,-6.6))))
	return state

func pack_cash(entry:Dictionary,transform:Transform3D)->Dictionary:
	return {"value":entry.value,"tender":entry.tender,"customer_id":entry.get("customer_id",-1),"transform":transform}

func guest_coop()->bool:
	return game.touch_profile and game.touch_controls!=null and game.touch_controls.coop_panel!=null and game.touch_controls.coop_panel.connected

func save_game(announce=true)->bool:
	if guest_coop():return false
	flush_worker()
	var committed=store_snapshot(snapshot(),ProjectSettings.globalize_path(save_path))
	last_status="Partie sauvegardée — jour %d"%game.clerk.shift.day if committed else "Échec : copie précédente conservée."
	if announce:game._message(last_status)
	return committed

func store_snapshot(data:Dictionary,path:String)->bool:
	# Disk I/O runs off the rendering thread for periodic autosaves.
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file:return false
	file.store_var(data)
	file.flush()
	var error=file.get_error()
	file.close()
	if error!=OK:return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"):DirAccess.remove_absolute(path+".bak")
		var backup_error=DirAccess.rename_absolute(path,path+".bak")
		if backup_error!=OK:return false
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func read_state()->Dictionary:
	for candidate in [save_path,save_path+".bak"]:
		if not FileAccess.file_exists(candidate):continue
		var file=FileAccess.open(candidate,FileAccess.READ)
		if not file:continue
		var value=file.get_var(false)
		if value is Dictionary:
			value=migrate_state(value)
			if valid_state(value):return value
	return {}

func migrate_state(state:Dictionary)->Dictionary:
	if state.get("version",0)!=1:return state
	var s=state.duplicate(true)
	for entry in s.get("cases",[]):
		var p:Vector3=entry.transform.origin
		if p.z> -6.7 and p.z< -4.4 and absf(p.x)<3.3:entry.transform.origin.z-=.8
		entry.meta.sort_slot=-1
	for entry in s.get("cash",[]):
		var p:Vector3=entry.transform.origin
		if p.z> -6.7 and p.z< -4.4 and absf(p.x)<3.3:entry.transform.origin.z-=.8
	for client in s.get("clients",[]):
		if client.position.z< -3.8:client.position.z-=.8
		var path:PackedVector2Array=client.path
		for i in range(path.size()):
			if path[i].y< -3.8:path[i].y-=.8
		client.path=path
	var slot=0
	for entry in s.get("cases",[]):
		var p:Vector3=entry.transform.origin
		if p.z< -8.3 and p.z> -9.2 and p.x>-.35 and p.x<3.2 and slot<game.clerk.repairs.case_slots.size():
			entry.transform=Transform3D(Basis(Vector3.RIGHT,-PI/2),game.clerk.repairs.case_slots[slot])
			entry.meta.sort_slot=slot
			slot+=1
	var disc_index=0
	for entry in s.get("loose_discs",[]):
		entry.transform.origin=Vector3(1.3+(disc_index%11)*.16,.916+.004*(disc_index/44),-8.55-.16*((disc_index/11)%4))
		disc_index+=1
	s.version=VERSION
	return s

func valid_state(s:Dictionary)->bool:
	if s.get("version",0)!=VERSION or s.get("catalogue",0)!=game.layout.movies.size():return false
	if s.get("records",[]).size()!=game.dvd_records.size():return false
	for key in ["cases","clients","waiting","returns","loose_discs","cash","shift","counter","repair","till"]:
		if not s.has(key):return false
	for i in range(s.records.size()):
		if s.records[i].movie!=game.dvd_records[i].movie:return false
	for item in s.cases:
		if item.record>=s.records.size() or item.record< -1:return false
	for client in s.clients:
		for index in client.items:
			if index<0 or index>=s.cases.size():return false
	return s.active>=-1 and s.active<s.clients.size()

func restore_file()->bool:
	var state=read_state()
	if state.is_empty():return false
	return restore(state)

func restore(s:Dictionary)->bool:
	if not valid_state(s):return false
	var c=game.clerk
	# Restore is used only into a fresh scene; never append into a running session.
	if not c.cases.is_empty() or not c.customers.customers.is_empty():return false
	c.accounts.restore(s.get("accounts",{}))
	if game.streamer_mode:
		game.streamer.load_fallen(s.get("streamer_fallen",{}))
		var challenge:Dictionary=s.get("streamer_challenge",{})
		game.streamer.duration_index=clampi(int(challenge.get("duration",2)),0,3)
		game.streamer.challenge_remaining=float(challenge.get("remaining",-1))
		game.streamer.challenge_report=str(challenge.get("report",""))
		game.streamer.refresh_wrist()
	if s.has("loose_locks"):c.locks.restore(s.loose_locks)
	for i in range(s.records.size()):
		var record:Dictionary=game.dvd_records[i]
		var saved:Dictionary=s.records[i]
		for key in ["disc_movie","disc_uid","dirty"]:record[key]=saved[key]
		record.locked=saved.get("locked",true)
		record.clerk_reserved=saved.reserved
		c.locks.update_slot(record)
		if record.clerk_reserved:
			var zero=Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)
			record.group.multimesh.set_instance_transform(record.index,zero)
			if game.shell and record.shell_index>=0:game.shell.multimesh.set_instance_transform(record.shell_index,zero)
	for saved in s.cases:
		var item=c.new_case(saved.movie,saved.transform.origin,saved.kind)
		item.scanned=saved.scanned
		if saved.task!="":item.task=saved.task
		if saved.record>=0:
			item.record=game.dvd_records[saved.record]
			load("res://clerk_inventory.gd").bind(item.node,item.record)
		for key in CASE_META:
			if saved.meta.has(key):item.node.set_meta(key,saved.meta[key])
		if not saved.meta.has("barcode_scanned"):item.node.set_meta("barcode_scanned",saved.scanned)
		if not saved.meta.has("needs_relock"):item.node.set_meta("needs_relock",saved.kind=="return")
		var lock=item.node.get_node_or_null("Antitheft")
		if lock and not saved.meta.antitheft:
			item.node.remove_child(lock)
			lock.queue_free()
		elif not lock and saved.meta.antitheft:c.add_lock(item.node)
		item.node.global_transform=saved.transform
		var old_position:Vector3=item.node.global_position
		if saved.kind=="rental" and absf(old_position.z+6.30)<.04 and old_position.x>-.95 and old_position.x<-.25 and old_position.y<1.20:
			item.node.global_position=Vector3(-.83,1.14+.022*(c.cases.size()-1),-5.85)
		item.node.freeze=false
		item.node.collision_layer=8
		item.node.collision_mask=1|8
		if item.node.get_meta("sort_slot",-1)>=0 or item.node.get_meta("in_sort_tray",false):
			item.node.freeze=true
			item.node.collision_layer=0
			item.node.collision_mask=0
	c.basket.body.global_transform=s.get("basket_transform",Transform3D(Basis.IDENTITY,c.basket.home))
	c.basket.restore_items()
	if s.has("guest_basket_transform"):
		c.lan.personal_basket().restore_items()
		c.lan.personal_basket().body.global_transform=s.guest_basket_transform
	for saved in s.clients:
		var node=load("res://clerk_props.gd").customer(c.customers,int(saved.get("appearance",int(saved.id)%6)))
		node.position=saved.position
		node.rotation=saved.rotation
		var customer={"node":node,"record":{} if saved.record<0 else game.dvd_records[saved.record],"reservations":[],"items":[],"return_job":unpack_job(saved.return_job),"path":saved.path}
		for key in CLIENT_FIELDS:
			if saved.has(key):customer[key]=saved[key]
		if not customer.has("patience_limit"):customer.patience_limit=randf_range(60,180)
		if customer.get("state","") in ["enter","browse","queue","approach_counter"]:
			customer.patience_started=false
			customer.patience=float(customer.patience_limit)
		if customer.state in ["enter","browse"] and not customer.has("selection_left"):customer.selection_left=randf_range(30,180)
		if not customer.has("account_id"):customer.account_id=c.accounts.create_account()
		for index in saved.reservations:customer.reservations.append(game.dvd_records[index])
		for index in saved.items:customer.items.append(c.cases[index])
		if saved.return_item>=0:customer.return_item=c.cases[saved.return_item]
		if saved.carry or not saved.return_job.is_empty():
			var carry=Node3D.new()
			load("res://customer_actor.gd").equip(node,carry)
			var movie=saved.return_job.movie if not saved.return_job.is_empty() else saved.movie
			load("res://held_case.gd").build(carry,game.layout.movies[movie])
			carry.visible=saved.carry
			customer.carry=carry
		if not customer.has("companions"):customer.companions=[6+int(saved.id)%2] if saved.get("family",false) else []
		c.customers.attach_companions(customer)
		c.customers.customers.append(customer)
	c.active={} if s.active<0 else c.customers.customers[s.active]
	for index in s.waiting:
		if index>=0:c.waiting.append(c.customers.customers[index])
	for job in s.returns:c.returns_due.append(unpack_job(job))
	for key in SHIFT_FIELDS:
		if s.shift.has(key):c.shift.set(key,s.shift[key])
	if not s.shift.has("rush_model"):
		c.shift.wave=1
		c.shift.duration=c.shift.OPEN_SECONDS
		c.shift.time_left=c.shift.OPEN_SECONDS
		c.shift.break_left=0
		c.shift.closing=false
	if not s.shift.has("day_model"):
		c.shift.duration=360.0
		var played:float=maxf(0,float(s.shift.get("duration",360))-float(s.shift.get("time_left",360)))
		c.shift.time_left=maxf(0,360-played)
		if c.shift.summary:c.shift.time_left=0
		c.shift.closing=c.shift.summary or c.shift.time_left<=0
		c.shift.break_left=0
	for key in COUNTER_FIELDS:c.set(key,s.counter[key])
	c.till=s.till.duplicate()
	if not s.shift.has("rush_model"):
		for item in c.cases:
			if item.kind=="return":
				item.scanned=true
				c.accounts.scan_return(item.node)
		for customer in c.customers.customers:
			if not customer.get("is_return",false):continue
			for item in customer.get("items",[]):
				item.node.reparent(c)
				item.node.global_position=c.return_bin+Vector3(0,.15,0)
				item.node.freeze=false
				item.node.collision_layer=8
				item.node.collision_mask=1|8
			c.waiting.erase(customer)
			if c.active==customer:
				c.active={}
				c.price=0
				c.tender=0
				c.tender_parts=[]
				c.tender_received=false
				c.paid=false
			customer.is_return=false
			if customer.get("return_and_rent",false):c.customers.begin_browse(customer)
			else:c.customers.dismiss(customer)
	if not c.active.is_empty() and not c.active.has("cash_started"):
		c.active.cash_started=c.tender_deposited>0 or c.paid or c.tender_parts.reduce(func(sum,value):return sum+value,0)<c.tender
	if int(s.get("return_schedule_version",0))<2:
		for job in c.returns_due:job.time=minf(job.time,c.elapsed+randf_range(120,240))
	if not s.shift.has("quota_model"):
		c.shift.target_customers=4+floori(maxi(0,c.shift.day-1)*1.5)
		var renters:int=c.customers.customers.filter(func(customer):return customer.return_job.is_empty() and not customer.get("is_refund",false) and customer.state!="exit").size()
		c.shift.arrived_customers=mini(c.shift.target_customers,c.shift.served+c.shift.abandoned+renters)
		c.shift.closing=c.shift.summary
		for customer in c.waiting:
			customer.state="queue"
			customer.queue_joined=c.elapsed+float(customer.id)*.001
		c.waiting.clear()
	c.customers.entry_cooldown=float(s.get("entry_cooldown",0))
	c.customers.arrival_cluster_left=int(s.get("arrival_cluster_left",0))
	c.customers.last_arrival_kind=int(s.get("last_arrival_kind",-1))
	c.customers.spawn_timer=s.spawn_timer
	c.customers.next_id=s.next_id
	c.customers.queue_gate=c.customers.clock+float(s.get("queue_gap",0))
	c.repairs.processed=s.processed
	for entry in s.loose_discs:
		var disc=c.inspection.create_disc(entry.data.movie,entry.data.dirty)
		c.inspection.add_child(disc)
		disc.global_transform=entry.transform
		var loose:Dictionary={"node":disc,"data":entry.data.duplicate()}
		if entry.get("physical",false):loose.body=load("res://club_surface_drop.gd").disc_body(c.inspection,disc,entry.transform.origin)
		c.inspection.loose_discs.append(loose)
	if not s.repair.is_empty():
		c.repairs.data=s.repair.data.duplicate()
		c.repairs.remaining=s.repair.remaining
		c.repairs.disc=c.inspection.create_disc(s.repair.data.movie,s.repair.data.dirty)
		c.repairs.add_child(c.repairs.disc)
		c.repairs.disc.position=c.repairs.station+Vector3(0,.035,0)
		c.repairs.disc.rotation=Vector3(PI/2,0,0)
		for item in c.cases:
			if record_id(item.record)==s.repair.source:c.repairs.source=item.node
		if s.repair.remaining<=0:c.repairs.label.text="DISQUE RÉPARÉ\nGâchette pour reprendre"
	for entry in s.cash:
		var piece=c.make_money(entry.value)
		c.wallet.roots[0].add_child(piece)
		piece.global_transform=entry.transform
		c.wallet.palms[0].append({"node":piece,"value":entry.value,"tender":entry.tender,"customer_id":entry.customer_id})
	if not s.cash.is_empty():
		c.wallet.drop_all(0)
		for entry in c.wallet.loose:entry.body.linear_velocity=Vector3.ZERO
	if s.has("options"):
		game.modes.manual_mode=s.options.manual
		game.modes.rain_enabled=s.options.rain
		for rain in game.modes.rain_nodes:rain.emitting=s.options.rain
		game.teleportation.enabled=s.options.teleport
	c.drawer.position.z=-6.82 if c.drawer_open else -6.6
	c.refresh_tender_visual()
	c.refresh_terminal()
	game._update_cover_lod(game.head.global_position,true)
	last_status="Partie reprise — jour %d"%c.shift.day
	return true

func continue_game()->bool:
	flush_worker()
	if read_state().is_empty():
		last_status="Aucune sauvegarde valide."
		return false
	load_failed=true
	get_tree().paused=false
	get_tree().reload_current_scene()
	return true

func archive_previous()->bool:
	flush_worker()
	var path=ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path+".previous"):DirAccess.remove_absolute(path+".previous")
	# Keep the previous run as a separate recovery copy, never load it into a new run.
	if FileAccess.file_exists(save_path) and DirAccess.rename_absolute(path,path+".previous")!=OK:
		last_status="Impossible de préparer la nouvelle partie."
		return false
	if FileAccess.file_exists(save_path+".bak"):DirAccess.remove_absolute(path+".bak")
	return true

func new_game()->bool:
	if not archive_previous():return false
	load_failed=true
	get_tree().paused=false
	get_tree().reload_current_scene()
	return true
