extends RefCounted
## Persistent business rules. Currency is stored as integer cents.
const OPEN_SECONDS:=480.0
const SHELF_PRICES:=[10000,17500,25000]
const SHELF_COLUMNS:=[4,8,12]
const CATEGORIES:=["action","horreur","suspense policier","science-fiction","comédie","cinéma familial","fantastique","aventure","drame","comédie romantique"]
const START_DATE:=1335830400 # May 1, 2012, UTC.
var day:=1
var phase:="preparation"
var played:=0.0
var cash:=25000
var weather:="soleil"
var offers:Array=[]
var bundles:Array=[]
var next_bundle:=3
var next_release:=6
var releases:Dictionary={}
var upcoming:Array=[]
var ratings:Dictionary={}
var shelves:Array=[]
var stock:Dictionary={}
var orders:Array=[]
var posters:Array=[]
var reservations:Array=[]
var daily_receipts:=0
var daily_refunds:=0
var next_order:=1
var report:=""
var rng:=RandomNumberGenerator.new()

func initialize(movies:Array,seed_value:int) -> void:
	rng.seed=seed_value
	for movie in movies:
		ratings[int(movie.id)]=snappedf(rng.randf_range(1.5,5.0),.5)
	var future:Array=movies.filter(func(movie):return movie.get("fictional",false) and int(movie.get("year",0))>=2005).map(func(movie):return int(movie.id))
	while upcoming.size()<mini(24,future.size()+upcoming.size()) and not future.is_empty():
		upcoming.append(future.pop_at(rng.randi_range(0,future.size()-1)))
	roll_offers(movies)

func calendar() -> Dictionary:
	return Time.get_date_dict_from_unix_time(START_DATE+(day-1)*86400)

func calendar_days() -> int:
	var date:=calendar()
	var next_month:int=int(date.month)+1
	var next_year:int=int(date.year)
	if next_month==13:next_month=1;next_year+=1
	var first:=Time.get_unix_time_from_datetime_dict({"year":date.year,"month":date.month,"day":1})
	var next:=Time.get_unix_time_from_datetime_dict({"year":next_year,"month":next_month,"day":1})
	return int((next-first)/86400)

func hour() -> String:
	var minutes:=480+floori(clampf(played/OPEN_SECONDS,0,1)*960)
	return "%02d:%02d"%[minutes/60,minutes%60]

func is_new(movie:int) -> bool:
	return releases.has(movie) and day-int(releases[movie])<7

func rental(movie:Dictionary) -> int:
	if is_new(int(movie.id)):return 750
	return 375 if int(movie.get("year",2000))<=int(calendar().year)-10 else 500

func purchase_price(movie:Dictionary) -> int:
	var base:=16.0 if is_new(int(movie.id)) else 10.0 if int(movie.get("year",2000))>2002 else 6.5
	var genre:=str(movie.get("genre","")).to_lower()
	base+=.75 if "science" in genre or "fantast" in genre else .5 if "action" in genre else -.25 if "drame" in genre else 0.0
	return clampi(roundi(base+(float(ratings.get(int(movie.id),3)) - 3.0)*1.5),5,20)*100

func quote(movies:Array,ids:Array) -> Dictionary:
	var total:=0
	var standard:=0
	for id in ids:
		var cost:=rental(movies[int(id)])
		total+=cost
		if cost==500:standard+=1
	var discount:=int(standard/4)*200
	return {"total":total-discount,"subtotal":total-discount,"discount":discount,"gst":0,"qst":0,"bundles":int(standard/4)}

func roll_offers(movies:Array) -> void:
	var catalogue:Array=movies.filter(func(movie):return movie.get("fictional",false))
	if catalogue.is_empty():catalogue=movies
	var released:=-1
	if day>=next_release:
		if not upcoming.is_empty():
			released=int(upcoming.pop_front())
			releases[released]=day
		next_release=day+rng.randi_range(5,14)
	offers=[]
	var pool:Array=catalogue.filter(func(movie):return not upcoming.has(int(movie.id))).map(func(movie):return int(movie.id))
	var offer_count:=mini(pool.size(),rng.randi_range(15,25))
	while offers.size()<offer_count and not pool.is_empty():
		var index:=rng.randi_range(0,pool.size()-1)
		offers.append(pool.pop_at(index))
	# Predictable affordable starters; the remaining daily selections are seeded.
	if day==1:
		offers=catalogue.filter(func(movie):return not upcoming.has(int(movie.id))).slice(0,18).map(func(movie):return int(movie.id))
	if released>=0 and not offers.has(released):
		if not offers.is_empty():offers.pop_back()
		offers.append(released)
	bundles=[]
	if day>=next_bundle:
		for batch in range(rng.randi_range(1,2)):
			var count:int=[5,10,15][rng.randi_range(0,2)]
			var contents:Array=[]
			var normal:=0
			for index in count:
				var movie:int=offers[rng.randi_range(0,offers.size()-1)]
				contents.append(movie)
				normal+=purchase_price(movies[movie])
			bundles.append({"movies":contents,"price":roundi(normal*.75)})
		next_bundle=day+rng.randi_range(2,4)

func buy(kind:String,value:int,price:int,contents:Array=[]) -> bool:
	if price<0 or cash<price:return false
	cash-=price
	orders.append({"id":next_order,"kind":kind,"value":value,"contents":contents.duplicate(),"remaining":10.0,"delivered":false})
	next_order+=1
	return true

func arrival_limit() -> int:
	if day==1:return 6
	var available:int=stock.values().filter(func(item):return not item.get("sold",false)).size()
	var weekend:bool=int(calendar().weekday) in [0,6]
	return mini(32,4+available/3+posters.size()/2+day/3+(4 if weekend else 0))

func start_day() -> bool:
	if phase!="preparation":return false
	if shelves.is_empty() or not stock.values().any(func(item):return item.get("shelved",false) and not item.get("sold",false)):return false
	phase="open"
	played=0
	daily_receipts=0
	daily_refunds=0
	return true

func next_day(movies:Array) -> void:
	day+=1
	phase="preparation"
	played=0
	weather="pluie" if rng.randf()<.35 else "soleil"
	roll_offers(movies)

func snapshot() -> Dictionary:
	var result:Dictionary={}
	for field in ["day","phase","played","cash","weather","offers","bundles","next_bundle","next_release","releases","upcoming","ratings","shelves","stock","orders","posters","reservations","daily_receipts","daily_refunds","next_order","report"]:
		var value:Variant=get(field)
		result[field]=value.duplicate(true) if value is Array or value is Dictionary else value
	result.rng_seed=rng.seed
	result.rng_state=rng.state
	return result

func restore(saved:Dictionary) -> void:
	for field in snapshot():
		if field in ["rng_seed","rng_state"]:continue
		if saved.has(field):set(field,saved[field])
	rng.seed=int(saved.get("rng_seed",1))
	rng.state=int(saved.get("rng_state",rng.state))
