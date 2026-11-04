extends RefCounted
var accounts={}
var next_account=1
var next_rental=1
func ensure(id:int)->Dictionary:
	if id<0:id=create_account()
	if not accounts.has(id):accounts[id]={"balance":0,"charges":{},"rentals":{}}
	next_account=maxi(next_account,id+1)
	return accounts[id]
func create_account()->int:
	var id=next_account
	next_account+=1
	accounts[id]={"balance":0,"charges":{},"rentals":{}}
	return id
func choose_account(excluded:Array=[])->int:
	var owing=accounts.keys().filter(func(id):return accounts[id].balance>0 and not excluded.has(id))
	if not owing.is_empty() and randf()<.65:return int(owing.pick_random())
	return create_account()
func rental(account:int,movie:int,record:int)->int:
	var entry=ensure(account)
	var id=next_rental
	next_rental+=1
	entry.rentals[id]={"movie":movie,"record":record,"returned":false}
	return id
func scan_return(node:Node3D)->int:
	if node.get_meta("return_checked",false):return 0
	var account=int(node.get_meta("return_account",-1))
	if account<0:
		account=create_account()
		node.set_meta("return_account",account)
	var entry=ensure(account)
	var cycle=int(node.get_meta("return_cycle",-1))
	if cycle<0:
		cycle=rental(account,int(node.get_meta("movie",0)),int(node.get_meta("inventory_record",{}).get("id",-1)))
		node.set_meta("return_cycle",cycle)
	if entry.rentals.has(cycle):entry.rentals[cycle].returned=true
	var fee=200 if node.get_meta("returned_damage",node.get_meta("dirty",false)) else 0
	if not entry.charges.has(cycle):
		entry.charges[cycle]=fee
		entry.balance+=fee
	else:fee=0
	node.set_meta("return_checked",true)
	return fee
func settle(account:int,cents:int):
	var entry=ensure(account)
	entry.balance=maxi(0,int(entry.balance)-cents)
func snapshot()->Dictionary:return {"accounts":accounts.duplicate(true),"next_account":next_account,"next_rental":next_rental}
func restore(data:Dictionary):
	accounts=data.get("accounts",{}).duplicate(true)
	next_account=int(data.get("next_account",1))
	next_rental=int(data.get("next_rental",1))
