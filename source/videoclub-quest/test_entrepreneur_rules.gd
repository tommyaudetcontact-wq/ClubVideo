extends SceneTree
var failures:=0
func check(value:bool,description:String) -> void:
	if not value:failures+=1;push_error("BUSINESS_RULE: "+description)
func _initialize():
	var movies:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/fictional/catalogue.json"))
	for index in movies.size():movies[index].id=index
	var state=load("res://entrepreneur_state.gd").new()
	state.initialize(movies,713)
	check(state.calendar().year==2012 and state.calendar().month==5 and state.calendar().day==1,"May 2012 start")
	check(state.calendar_days()==31,"May has 31 days")
	state.day=32
	check(state.calendar().month==6 and state.calendar_days()==30,"June has 30 days")
	state.day=277
	check(state.calendar().year==2013 and state.calendar().month==2 and state.calendar_days()==28,"next-year February")
	state.day=1
	check(not state.buy("film",0,-1) and state.cash==25000,"negative prices rejected")
	check(not state.buy("film",0,25001) and state.cash==25000,"overspending rejected")
	check(state.buy("film",0,500) and state.cash==24500 and state.orders.size()==1,"purchase charged once")
	var clone=load("res://entrepreneur_state.gd").new()
	clone.restore(state.snapshot())
	var bundle_count:=0
	var release_count:=0
	for index in 400:
		state.next_day(movies);clone.next_day(movies)
		check(state.offers==clone.offers and state.bundles==clone.bundles and state.weather==clone.weather,"save preserves random continuation")
		check(state.offers.size()>=15 and state.offers.size()<=25,"daily offer bounds")
		check(state.offers.all(func(id):return not state.upcoming.has(id)),"future releases unavailable")
		var seen:Dictionary={}
		for id in state.offers:
			check(not seen.has(id),"unique offers");seen[id]=true
			check(state.purchase_price(movies[id])>=500 and state.purchase_price(movies[id])<=2000,"purchase price bounds")
		for bundle in state.bundles:
			bundle_count+=1
			check(bundle.movies.size() in [5,10,15],"bundle copy count")
			var normal:=0
			for id in bundle.movies:normal+=state.purchase_price(movies[id])
			check(bundle.price==roundi(normal*.75),"bundle discount")
		for id in state.releases:
			if int(state.releases[id])==state.day:
				release_count+=1
				check(state.offers.has(id) and state.is_new(id),"new release offered")
	check(bundle_count>100 and release_count==24,"long-run release and lot coverage")
	state.releases.clear();state.day=1
	var standard:=-1
	for movie in movies:
		if state.rental(movie)==500:standard=int(movie.id);break
	check(standard>=0,"standard price exists")
	check(state.quote(movies,[standard,standard,standard,standard]).total==1800,"four for eighteen")
	check(state.quote(movies,[standard,standard,standard]).total==1500,"three regular films")
	state.releases[standard]=1
	check(state.rental(movies[standard])==750,"new-release price")
	state.day=8
	check(not state.is_new(standard) and state.rental(movies[standard])==500,"novelty expires after seven days")
	print("ENTREPRENEUR_RULES_COMPLETE failures=",failures," simulated_days=400 bundles=",bundle_count," releases=",release_count)
	quit(1 if failures else 0)
