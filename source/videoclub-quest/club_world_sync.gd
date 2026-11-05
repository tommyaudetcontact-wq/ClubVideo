extends Node3D

const Actor=preload("res://customer_actor.gd")
const Props=preload("res://clerk_props.gd")
const Case=preload("res://held_case.gd")
const Save=preload("res://club_save.gd")
var game
var nodes:Dictionary={}
var originals:Dictionary={}
var hidden:Dictionary={}
var state:Dictionary={}
var basket_pose:Transform3D
var last_stock:Dictionary={}
var shelf_index:Dictionary={}
var drawer_pose:Transform3D

static func shelf_key(game,record:Dictionary)->String:
	return "%s|%d|%d"%[game._position_key(record.world.origin),record.movie,record.index]

static func capture(game)->String:
	var c=game.clerk
	var stock:Dictionary={}
	for record in game.dvd_records:
		var flags:int=int(record.get("dirty",false))|int(record.get("locked",true))<<1
		if record.get("clerk_reserved",false) or record.get("loose",false):flags|=4
		stock[shelf_key(game,record)]=[record.movie,record.disc_movie,record.disc_uid,flags,record.world]
	var cases:Array=[]
	for item in c.cases:
		var node:Node3D=item.node
		if not is_instance_valid(node):continue
		cases.append({"id":str(node.get_instance_id()),"movie":item.movie,"disc":node.get_meta("disc_movie",item.movie),"dirty":node.get_meta("dirty",false),"locked":node.get_meta("antitheft",false),"transform":node.global_transform,"opened":(c.inspection.opened and node==c.inspection.case_node) or (is_instance_valid(c.lan.guest_inspection) and c.lan.guest_inspection.opened and node==c.lan.guest_inspection.case_node),"held":node==game.held or item==c.secondary or node.get_meta("guest_held",false),"busy":node.get_meta("customer_animating",false),"kind":item.kind,"in_basket":item in c.basket.items,"scanned":item.scanned})
	for record in game.modes.loose_dvds:
		var loose:Node3D=record.get("loose_body")
		if is_instance_valid(loose):
			cases.append(shelf_case_state(record,loose,false))
	if is_instance_valid(game.held) and not game.held_record.is_empty():
		cases.append(shelf_case_state(game.held_record,game.held,true))
	var clients:Array=[]
	for customer in c.customers.customers:
		var n:Node3D=customer.node
		clients.append({"id":str(customer.id),"transform":n.global_transform,"moving":customer.cursor<customer.path.size(),"companions":customer.get("companions",[]),"carry":customer.get("movie",-1) if is_instance_valid(customer.get("carry")) and customer.carry.visible else -1})
	var discs:Array=[]
	if c.inspection.opened and is_instance_valid(c.inspection.disc) and c.inspection.disc.visible:
		var id:int=c.inspection.case_node.get_meta("disc_movie",-1)
		discs.append(disc_state(c.inspection.disc,id,c.inspection.case_node.get_meta("dirty",false)))
	for loose in c.inspection.loose_discs:
		discs.append(disc_state(loose.node,loose.data.movie,loose.data.get("dirty",false)))
	if is_instance_valid(c.inspection.carried):
		discs.append(disc_state(c.inspection.carried,c.inspection.carried_data.movie,c.inspection.carried_data.get("dirty",false)))
	var guest=c.lan.guest_inspection
	if is_instance_valid(guest):
		if guest.opened and is_instance_valid(guest.disc) and guest.disc.visible:
			discs.append(disc_state(guest.disc,guest.case_node.get_meta("disc_movie",-1),guest.case_node.get_meta("dirty",false)))
		if is_instance_valid(guest.carried):
			discs.append(disc_state(guest.carried,guest.carried_data.movie,guest.carried_data.get("dirty",false)))
	if is_instance_valid(c.repairs.disc):
		discs.append(disc_state(c.repairs.disc,c.repairs.data.movie,c.repairs.data.get("dirty",false)))
	var cash:Array=[]
	for entry in c.wallet.loose:cash.append({"id":str(entry.node.get_instance_id()),"value":entry.value,"transform":entry.node.global_transform})
	if c.tender_note.visible:
		for i in range(c.tender_parts.size()):
			cash.append({"id":"tender"+str(i),"value":c.tender_parts[i],"transform":c.tender_note.get_child(i).global_transform})
	var bars:Array=[]
	for bar in c.locks.bars:
		if is_instance_valid(bar):
			bars.append({"id":str(bar.get_instance_id()),"transform":bar.global_transform})
	var day:Dictionary={}
	for key in Save.SHIFT_FIELDS:day[key]=c.shift.get(key)
	var payload={"stock":stock,"cases":cases,"clients":clients,"discs":discs,"cash":cash,"bars":bars,"basket":c.basket.body.global_transform,"drawer":c.drawer.global_transform,"shift":day}
	var raw:=var_to_bytes(payload)
	return Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE))

static func shelf_case_state(record:Dictionary,node:Node3D,held:bool)->Dictionary:
	return {"id":str(node.get_instance_id()),"movie":record.movie,"disc":record.disc_movie,"dirty":record.get("dirty",false),"locked":record.get("locked",true),"transform":node.global_transform,"opened":false,"held":held,"kind":"shelve","in_basket":false,"scanned":false}

static func disc_state(node:Node3D,movie:int,dirty:bool)->Dictionary:
	return {"id":str(node.get_instance_id()),"movie":movie,"dirty":dirty,"transform":node.global_transform}

func setup(owner_game):
	game=owner_game
	basket_pose=game.clerk.basket.body.global_transform
	drawer_pose=game.clerk.drawer.global_transform
	for index in range(game.dvd_records.size()):
		shelf_index[shelf_key(game,game.dvd_records[index])]=index
	game.clerk.tender_note.hide()
	for item in game.clerk.cases:hide_local(item.node)
	for item in game.clerk.inspection.loose_discs:hide_local(item.node)
	for entry in game.clerk.wallet.loose:hide_local(entry.node)
	for bar in game.clerk.locks.bars:
		if is_instance_valid(bar):hide_local(bar)
	for record in game.modes.loose_dvds:
		if is_instance_valid(record.get("loose_body")):hide_local(record.loose_body)
	if is_instance_valid(game.clerk.inspection.carried):hide_local(game.clerk.inspection.carried)
	if is_instance_valid(game.clerk.repairs.disc):hide_local(game.clerk.repairs.disc)

func hide_local(node:Node3D):
	hidden[node]=node.visible
	node.hide()

func apply(encoded:String):
	if encoded.length()>262144:return
	var raw:=Marshalls.base64_to_raw(encoded).decompress_dynamic(1048576,FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():return
	var value:Variant=bytes_to_var(raw)
	if not value is Dictionary or not value.get("stock") is Dictionary:return
	var stock:Dictionary=value.stock
	if stock.size()>3500:return
	state=value
	if last_stock!=stock:
		for key in shelf_index:
			var index:int=shelf_index[key]
			var record:Dictionary=game.dvd_records[index]
			var row:Array=stock.get(key,[])
			if not last_stock.is_empty() and row==last_stock.get(key,[]):continue
			if not originals.has(index):
				originals[index]={"disc_movie":record.disc_movie,"disc_uid":record.disc_uid,"dirty":record.get("dirty",false),"locked":record.get("locked",true),"clerk_reserved":record.get("clerk_reserved",false)}
			var matches:bool=not row.is_empty() and int(row[0])==int(record.movie)
			if matches:
				record.disc_movie=row[1]
				record.disc_uid=row[2]
				record.dirty=bool(int(row[3])&1)
				record.locked=bool(int(row[3])&2)
			record.clerk_reserved=not matches or bool(int(row[3])&4)
			update_shelf(record)
		last_stock=stock
		game._update_cover_lod(game.head.global_position,true)
	game.clerk.basket.body.global_transform=value.basket
	game.clerk.drawer.global_transform=value.drawer
	var seen:Dictionary={}
	for key in stock:
		var row:Array=stock[key]
		if int(row[3])&4:continue
		if shelf_index.has(key) and int(game.dvd_records[shelf_index[key]].movie)==int(row[0]):continue
		var id:String="shelf"+key
		seen[id]=true
		if not nodes.has(id):
			var extra:Node3D=make_visual("cases",{"movie":row[0]})
			if not extra:continue
			nodes[id]=extra
			extra.global_transform=row[4]
			if int(row[3])&2:game.clerk.add_lock(extra)
	for category in ["cases","clients","discs","cash","bars"]:
		for entry in value.get(category,[]):
			var key:String=category+entry.id
			seen[key]=true
			var node:Node3D=nodes.get(key)
			if not is_instance_valid(node):
				node=make_visual(category,entry)
				if not node:continue
				nodes[key]=node
			node.global_transform=entry.transform
			if category=="clients":
				Actor.animate(node,"Walk" if entry.moving else "Idle")
				update_carry(node,int(entry.carry))
			elif category=="cases":
				var cover:=node.get_node_or_null("PaperInsert_front") as Node3D
				if cover:cover.visible=not entry.opened
				var lock:=node.get_node_or_null("Antitheft")
				if entry.locked and not lock:game.clerk.add_lock(node)
				elif not entry.locked and lock:
					node.remove_child(lock)
					lock.queue_free()
	for key in nodes.keys():
		if not seen.has(key):
			nodes[key].queue_free()
			nodes.erase(key)

func make_visual(category:String,entry:Dictionary)->Node3D:
	var node:Node3D
	match category:
		"cases":
			if not valid_movie(entry.movie):return null
			node=Node3D.new()
			add_child(node)
			Case.build(node,game.layout.movies[entry.movie])
		"clients":
			node=Props.customer(self,int(entry.id)%6)
			game.clerk.customers.attach_companions({"node":node,"companions":entry.companions})
		"discs":
			if not valid_movie(entry.movie):return null
			node=game.clerk.inspection.create_disc(entry.movie,entry.dirty)
			add_child(node)
		"cash":
			node=game.clerk.make_money(entry.value)
			add_child(node)
		"bars":
			node=Props.box(self,Vector3.ZERO,Vector3(.012,.157,.018),"f2c928")
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func update_carry(node:Node3D,movie:int):
	if node.get_meta("carry_movie",-1)==movie:return
	var old:Variant=node.get_meta("carry_visual",null) if node.has_meta("carry_visual") else null
	if is_instance_valid(old):old.queue_free()
	node.set_meta("carry_movie",movie)
	if not valid_movie(movie):return
	var copy:=Node3D.new()
	Actor.equip(node,copy)
	Case.build(copy,game.layout.movies[movie])
	node.set_meta("carry_visual",copy)

func valid_movie(id:int)->bool:
	return id>=0 and id<game.layout.movies.size()

func update_shelf(record:Dictionary):
	var hide_case:bool=record.clerk_reserved or record.get("loose",false)
	var zero:=Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)
	record.group.multimesh.set_instance_transform(record.index,zero if hide_case else record.local)
	if game.shell and record.shell_index>=0:
		game.shell.multimesh.set_instance_transform(record.shell_index,zero if hide_case else game.shell.global_transform.affine_inverse()*record.world)
	game.clerk.locks.update_slot(record)

func restore_local():
	for index in originals:
		var record:Dictionary=game.dvd_records[index]
		record.merge(originals[index],true)
		update_shelf(record)
	game._update_cover_lod(game.head.global_position,true)
	for node in hidden:
		if is_instance_valid(node):node.visible=hidden[node]
	game.clerk.basket.body.global_transform=basket_pose
	game.clerk.drawer.global_transform=drawer_pose
	game.clerk.refresh_tender_visual()
	queue_free()
