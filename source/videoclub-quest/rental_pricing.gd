extends RefCounted
static func unit(movie:Dictionary)->int:
	if movie.get("console","")!="":return 495 if int(movie.id)%2==0 else 595
	if int(movie.get("year",2000))<=1995:return 275
	return 375 if int(movie.get("year",2000))<=2001 else 425
static func quote(movies:Array,ids:Array)->Dictionary:
	var total=0
	var classics=0
	for id in ids:
		var cents=unit(movies[int(id)])
		total+=cents
		if cents==275:classics+=1
	var bundles=classics/3
	var discount=bundles*325
	var subtotal=total-discount
	# Quebec early-2000s game rules: TPS 7%, TVQ 7.5% of the TPS-inclusive amount.
	# Sources: finances.gouv.qc.ca/documents/Autres/fr/AUTFR_Fascicule2_FiscaliteParticuliers.pdf
	# collections.banq.qc.ca/ark%3A/52327/bs19680
	var gst=roundi(subtotal*.07)
	var qst=roundi((subtotal+gst)*.075)
	return {"total":subtotal+gst+qst,"subtotal":subtotal,"gst":gst,"qst":qst,"discount":discount,"bundles":bundles}
static func payment(amount:int)->Array:
	if amount<=0:return []
	var choices:Array=[]
	# Notes are the common offer; coins are either exact or the smallest practical rounding.
	for note in [500,1000,2000]:
		if note>=amount:
			choices.append([note])
			if note==500:choices.append([note])
			if note>=1000 or amount>1000:break
	var exact:Array=[]
	var remaining=amount
	for value in [1000,500,200,100,25,10,5,1]:
		while remaining>=value:
			exact.append(value)
			remaining-=value
	choices.append(exact)
	var rounded=ceili(amount/200.0)*200
	if rounded<=1000:
		var toonies=[]
		for i in range(rounded/200):toonies.append(200)
		choices.append(toonies)
	if amount>500:
		var mixed=[]
		var rest=amount
		while rest>500:
			mixed.append(500)
			rest-=500
		for i in range(ceili(rest/100.0)):mixed.append(100)
		choices.append(mixed)
	return choices.pick_random().duplicate()
