extends RefCounted

# Work only on copied values. Never touch scene nodes or RenderingServer here.
static func write_report(state:Dictionary,samples:Array,history_enabled:bool):
	if not samples.is_empty():
		samples.sort()
		state.frame_sample_count=samples.size()
		state.frame_ms_p99=samples[mini(samples.size()-1,int(samples.size()*.99))]
		state.frame_ms_worst=samples.back()
		state.frame_ms_median=samples[int(samples.size()*.5)]
		state.frame_ms_p95=samples[mini(samples.size()-1,int(samples.size()*.95))]
		state.target_frame_ms=1000.0/72.0
	var file:=FileAccess.open("user://diagnostics.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(state))
	if history_enabled:
		var history:=FileAccess.open("user://performance-history.jsonl",FileAccess.READ_WRITE if FileAccess.file_exists("user://performance-history.jsonl") else FileAccess.WRITE)
		if history:
			history.seek_end()
			state.unix_time=Time.get_unix_time_from_system()
			history.store_line(JSON.stringify(state))
