extends RefCounted
static func mix_records(records:Array,ratio:float=.10):
	for r in records:
		r.disc_movie=int(r.movie)
		r.disc_uid=int(r.id)
	var count=int(records.size()*ratio)/2*2
	if count<2:return 0
	var pool=records.duplicate()
	var chosen:Array=[]
	var largest=0
	for attempt in range(64):
		pool.shuffle()
		chosen=pool.slice(0,count)
		var frequencies={}
		largest=0
		for r in chosen:
			frequencies[r.movie]=int(frequencies.get(r.movie,0))+1
			largest=maxi(largest,frequencies[r.movie])
		if largest<=count/2:break
	if largest>count/2:return 0
	chosen.sort_custom(func(a,b):return a.movie<b.movie)
	var originals=[]
	for r in chosen:originals.append({"movie":r.movie,"uid":r.id})
	for i in range(count):
		var source=originals[(i+largest)%count]
		chosen[i].disc_movie=source.movie
		chosen[i].disc_uid=source.uid
	return count
static func bind(node:Node3D,record:Dictionary):
	if record.is_empty():return
	node.set_meta("inventory_record",record)
	node.set_meta("movie",int(record.movie))
	node.set_meta("disc_movie",int(record.get("disc_movie",record.movie)))
	node.set_meta("disc_uid",int(record.get("disc_uid",record.id)))
	node.set_meta("inspected",false)
	node.set_meta("dirty",record.get("dirty",false))
	load("res://clerk_locks.gd").bind_visual(node,record)
static func put(node:Node3D,id:int,uid:int):
	node.set_meta("disc_movie",id)
	node.set_meta("disc_uid",uid)
	node.set_meta("inspected",false)
	var record:Dictionary=node.get_meta("inventory_record",{})
	if not record.is_empty():
		record.disc_movie=id
		record.disc_uid=uid
