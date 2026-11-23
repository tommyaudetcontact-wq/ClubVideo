extends RefCounted
static var phase:="initialisation"
static var started:=Time.get_ticks_msec()
static func mark(next_phase:String,tree:SceneTree=null) -> void:
	phase=next_phase
	var report:Dictionary={"phase":phase,"elapsed_ms":Time.get_ticks_msec()-started,"paused":tree.paused if tree else false}
	var file:=FileAccess.open("user://startup-status.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(report))
