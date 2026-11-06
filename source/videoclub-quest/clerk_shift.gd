extends RefCounted

const OPEN_SECONDS := 180.0
const RUSH_INCREMENT := 30.0
var clerk
var day=1
var duration=OPEN_SECONDS
var time_left=OPEN_SECONDS
var closing=false
var summary=false
var enabled=true
var started=false
var served=0
var abandoned=0
var lost_sales=0
var missed_scans=0
var revenue=0
var refunds=0
var returned=0
var restocked=0
var damaged=0
var initial_cash=0
var rush_model=1
var wave=1
var break_left=0.0
var report=""
var business_balance=0
func setup(c):
	clerk=c
	initial_cash=cash_in_till()
func cash_in_till()->int:
	var total=0
	for value in clerk.till:total+=int(value)*int(clerk.till[value])
	return total
func capacity()->int:return 8
func can_spawn()->bool:return not enabled or (started and not closing and not summary and break_left<=0)
func spawned():
	pass
func rush_duration()->float:
	return OPEN_SECONDS+maxi(0,wave-1)*RUSH_INCREMENT
func tick(dt:float):
	if not enabled or not started or summary:return
	var remaining:=maxf(0.0,dt)
	while remaining>0:
		if break_left>0:
			var rest:=minf(remaining,break_left)
			break_left=maxf(0.0,break_left-rest)
			remaining-=rest
			if break_left<=0:
				wave+=1
				duration=rush_duration()
				time_left=duration
				closing=false
				clerk.customers.spawn_timer=randf_range(2,10)
				clerk.game._message("Rush %d : les clients arrivent."%wave)
		else:
			var work:=minf(remaining,time_left)
			time_left=maxf(0.0,time_left-work)
			remaining-=work
			if time_left<=0:
				break_left=duration/3.0
				closing=true
				clerk.game._message("Temps mort : termine les clients et organise les retours.")

func record_sale(total:int):
	served+=1
	revenue+=total
func finish()->bool:
	if summary:return true
	if not closing:
		clerk.game._message("La journée est encore ouverte.")
		return false
	if not clerk.active.is_empty() or not clerk.waiting.is_empty():
		clerk.game._message("Termine les clients présents avant de clôturer.")
		return false
	for c in clerk.customers.customers:
		if c.state!="exit":return false
	if is_instance_valid(clerk.repairs.disc) or is_instance_valid(clerk.inspection.carried) or (is_instance_valid(clerk.lan.guest_inspection) and is_instance_valid(clerk.lan.guest_inspection.carried)):
		clerk.game._message("Libère la machine de réparation et dépose tout disque que tu tiens. Les disques sur la table peuvent attendre.")
		return false
	var expected=initial_cash+revenue-refunds
	var actual=cash_in_till()
	business_balance+=revenue-refunds
	report="BILAN · JOUR %d\nClients servis : %d · partis : %d\nVentes perdues : %.2f $ · oublis de scan : %d\nRetours reçus : %d · rangés : %d\nRéparations : %d · reste : %d\nPénalités / remboursements : %.2f $\nRésultat net : %.2f $ · cumul : %.2f $\nCaisse attendue : %.2f $\nCaisse comptée : %.2f $\nÉCART : %+.2f $\nClique l’écran pour la journée suivante."%[day,served,abandoned,lost_sales/100.0,missed_scans,returned,restocked,clerk.repairs.processed,clerk.cases.filter(func(i):return i.kind in ["return","sorting","shelve"]).size(),refunds/100.0,(revenue-refunds)/100.0,business_balance/100.0,expected/100.0,actual/100.0,(actual-expected)/100.0]
	summary=true
	return true
func next_day():
	day+=1
	duration=OPEN_SECONDS
	time_left=duration
	closing=false
	summary=false
	served=0
	abandoned=0
	lost_sales=0
	missed_scans=0
	revenue=0
	refunds=0
	returned=0
	restocked=0
	damaged=0
	initial_cash=cash_in_till()
	wave=1
	break_left=0
	clerk.repairs.processed=0
	clerk.customers.spawn_timer=5
func text()->String:
	if not started:return "PRÊT\nPremier rush de 3 minutes, puis 1 minute de temps mort.\nChaque rush dure 30 secondes de plus.\nLes clients attendent sans limite."
	if summary:return report
	var clock:float=break_left if break_left>0 else time_left
	return "RUSH %d · %s\nTemps restant : %d:%02d\nClients patients sans limite\nRetours : %d · rangés : %d\nRéparations : %d\nPendant la pause, les retours peuvent attendre."%[wave,"TEMPS MORT" if break_left>0 else "CLIENTS EN ARRIVÉE",int(clock)/60,int(clock)%60,returned,restocked,clerk.repairs.processed]
