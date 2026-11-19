extends SceneTree
var failures:=0
func check(value:bool,description:String) -> void:
	if not value:failures+=1;push_error("CATALOGUE_MIGRATION: "+description)
func _initialize():
	await process_frame
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false);g.clerk.set_physics_process(false);g.clerk.customers.set_physics_process(false)
	var c=g.clerk
	var copy:Dictionary=g.dvd_records[201]
	var item:Dictionary=c.new_case(copy.movie,Vector3(1,1.2,-6),"shelve")
	item.record=copy
	load("res://clerk_inventory.gd").bind(item.node,copy)
	var state:Dictionary=g.session.snapshot()
	state.catalogue=60
	state.shift.revenue=12345
	for record in state.records:
		record.movie=32;record.disc_movie=32
	state.records[201].disc_uid=202
	state.cases[0].movie=32
	state.cases[0].meta.disc_movie=-1
	state.cases[0].meta.disc_uid=-1
	state.accounts={"accounts":{7:{"balance":625,"charges":{},"rentals":{3:{"movie":32,"record":201,"returned":false}}}},"next_account":8,"next_rental":4}
	state.loose_discs=[{"data":{"movie":32,"uid":202,"dirty":true,"inspected":false},"transform":Transform3D(Basis.IDENTITY,Vector3(1,.95,-8.5)),"physical":false}]
	var migrated:Dictionary=g.session.migrate_state(state)
	check(g.session.valid_state(migrated),"migrated save validates")
	check(state.catalogue==60 and state.records[201].movie==32,"input backup unchanged")
	check(migrated.catalogue==200 and migrated.catalogue_migrated_from==60,"catalogue version recorded")
	check(migrated.records[201].movie==copy.movie,"case identity preserved")
	check(migrated.records[201].disc_movie==g.dvd_records[202].movie,"mixed physical disc identity preserved")
	check(migrated.cases[0].meta.disc_movie==-1,"empty case remains empty")
	check(migrated.loose_discs[0].data.movie==g.dvd_records[202].movie,"loose disc identity preserved")
	check(migrated.accounts.accounts[7].rentals[3].movie==copy.movie,"outstanding loan title updated")
	check(migrated.accounts.accounts[7].balance==625 and migrated.shift.revenue==12345 and migrated.till==state.till,"finances unchanged")
	g.queue_free()
	await process_frame
	g=load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false);g.clerk.set_physics_process(false);g.clerk.customers.set_physics_process(false)
	c=g.clerk
	check(g.session.restore(migrated),"migrated game restores")
	check(c.cases[0].node.get_meta("disc_movie")==-1,"restored case stays empty")
	var incompatible:Dictionary=state.duplicate(true)
	incompatible.records.pop_back()
	check(not g.session.valid_state(g.session.migrate_state(incompatible)),"different layout preserved as incompatible")
	print("CATALOGUE_MIGRATION_COMPLETE failures=",failures)
	quit(1 if failures else 0)
