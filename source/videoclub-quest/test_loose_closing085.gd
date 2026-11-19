extends SceneTree

func _initialize():
	await process_frame
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	var clerk=game.clerk
	var shift=clerk.shift
	assert(shift.duration==360 and shift.time_left==360)
	shift.started=true
	shift.tick(359)
	assert(not shift.closing and shift.time_left==1)
	shift.tick(1)
	assert(shift.closing and shift.time_left==0)
	var disc=MeshInstance3D.new()
	clerk.add_child(disc)
	var loose={"node":disc,"data":{"movie":0,"uid":123,"dirty":false,"inspected":false}}
	clerk.inspection.loose_discs.append(loose)
	clerk.inspection.carried=disc
	assert(not shift.finish())
	clerk.inspection.carried=null
	clerk.repairs.disc=disc
	assert(not shift.finish())
	clerk.repairs.disc=null
	assert(shift.finish())
	shift.next_day()
	assert(shift.duration==360 and shift.time_left==360)
	assert(clerk.inspection.loose_discs.size()==1 and clerk.inspection.loose_discs[0].data.uid==123)
	print("LOOSE_CLOSING085_OK")
	quit()


