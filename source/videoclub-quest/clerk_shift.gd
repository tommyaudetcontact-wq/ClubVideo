extends RefCounted

const OPEN_SECONDS := 360.0
const RUSH_INCREMENT := 30.0
var clerk
var day=1
var duration=OPEN_SECONDS
var time_left=OPEN_SECONDS
var closing=false
var summary=false
var enabled=true
var started=false
var quota_model=1
var target_customers=4
var arrived_customers=0
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
var day_model=1
var wave=1
var break_left=0.0
var report=""
var business_balance=0
const WEEKDAYS=["LUNDI","MARDI","MERCREDI","JEUDI","VENDREDI"]
var week_losses=0
var week_abandoned=0
var week_refunds=0
var week_cash_error=0
var week_perfect=false
func weekday()->String:return WEEKDAYS[(day-1)%5]
func week_number()->int:return (day-1)/5+1
func setup(c):
	clerk=c
	initial_cash=cash_in_till()
func cash_in_till()->int:
	var total=0
	for value in clerk.till:total+=int(value)*int(clerk.till[value])
	return total
func capacity()->int:return 8
func can_spawn()->bool:return not enabled or (started and not closing and not summary and arrived_customers<target_customers)
func spawned():
	arrived_customers+=1
func rush_duration()->float:
	return OPEN_SECONDS+maxi(0,wave-1)*RUSH_INCREMENT
func tick(dt:float):
	if not enabled or not started or summary:return
	if not closing and arrived_customers>=target_customers and clerk.customers.customers.is_empty() and clerk.active.is_empty() and clerk.waiting.is_empty() and clerk.returns_due.is_empty():
		closing=true
		clerk.game._message("Les clients de la journée sont repartis. Fais maintenant le close.")

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
	if not clerk.customers.customers.is_empty():
		clerk.game._message("Attends que les derniers clients soient sortis.")
		return false
	for item in clerk.cases:
		if item.node.get_meta("in_sort_tray",false):continue
		if item.kind=="sorting" and int(item.node.get_meta("sort_slot",-1))>=0:continue
		clerk.game._message("Vide la chute, ramasse et range les boîtiers. À démêler peut attendre demain.")
		return false
	if game_has_loose_stock():
		clerk.game._message("Il reste des boîtiers au sol ou en main : range-les avant de fermer.")
		return false
	if not clerk.wallet.loose.is_empty() or clerk.wallet.occupied(0) or clerk.wallet.occupied(1) or not clerk.lan.guest_cash.is_empty():
		clerk.game._message("Remets l’argent dans la caisse avant la clôture.")
		return false
	if is_instance_valid(clerk.repairs.disc) or is_instance_valid(clerk.inspection.carried) or (is_instance_valid(clerk.lan.guest_inspection) and is_instance_valid(clerk.lan.guest_inspection.carried)):
		clerk.game._message("Libère la machine de réparation et dépose tout disque que tu tiens. Les disques sur la table peuvent attendre.")
		return false
	for disc in clerk.inspection.loose_discs:
		if not clerk.repairs.is_sorting_surface(disc.node.global_position):
			clerk.game._message("Ramasse les disques au sol et pose-les sur la table À démêler.")
			return false
	if clerk.drawer_open:
		clerk.game._message("Ferme le tiroir de caisse avant de clôturer.")
		return false
	var expected=initial_cash+revenue-refunds
	var actual=cash_in_till()
	business_balance+=revenue-refunds
	week_losses+=lost_sales
	week_abandoned+=abandoned
	week_refunds+=refunds
	week_cash_error+=absi(actual-expected)
	report="BILAN · JOUR %d\nClients servis : %d · partis : %d\nVentes perdues : %.2f $ · oublis de scan : %d\nRetours reçus : %d · rangés : %d\nRéparations : %d · reste : %d\nPénalités / remboursements : %.2f $\nRésultat net : %.2f $ · cumul : %.2f $\nCaisse attendue : %.2f $\nCaisse comptée : %.2f $\nÉCART : %+.2f $\nClique l’écran pour la journée suivante."%[day,served,abandoned,lost_sales/100.0,missed_scans,returned,restocked,clerk.repairs.processed,clerk.cases.filter(func(i):return i.kind in ["return","sorting","shelve"]).size(),refunds/100.0,(revenue-refunds)/100.0,business_balance/100.0,expected/100.0,actual/100.0,(actual-expected)/100.0]
	summary=true
	report="%s · SEMAINE %d\n"%[weekday(),week_number()]+report
	if (day-1)%5==4:
		var scratched:int=remaining_scratches()
		var untidy:int=clerk.cases.size()+clerk.inspection.loose_discs.size()
		week_perfect=week_losses==0 and week_abandoned==0 and week_refunds==0 and week_cash_error==0 and scratched==0 and untidy==0
		report+="\n\nSEMAINE %s\nPertes : %.2f $ · abandons : %d · remboursements : %.2f $\nÉcarts de caisse cumulés : %.2f $\nDisques abîmés restants : %d · éléments à ranger : %d\nClique pour commencer lundi."%["PARFAITE !" if week_perfect else "À AMÉLIORER",week_losses/100.0,week_abandoned,week_refunds/100.0,week_cash_error/100.0,scratched,untidy]
	return true
func next_day():
	day+=1
	target_customers+=randi_range(1,2)
	arrived_customers=0
	if (day-1)%5==0:
		week_losses=0
		week_abandoned=0
		week_refunds=0
		week_cash_error=0
		week_perfect=false
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
func game_has_loose_stock()->bool:
	return is_instance_valid(clerk.game.held) or not clerk.game.held_record.is_empty() or clerk.game.modes.loose_dvds.any(func(record):return is_instance_valid(record.get("loose_body")))

func remaining_scratches()->int:
	var count:int=0
	for record in clerk.game.dvd_records:
		if not record.get("clerk_reserved",false) and record.get("dirty",false):count+=1
	for item in clerk.cases:
		if item.node.get_meta("dirty",false):count+=1
	for disc in clerk.inspection.loose_discs:
		if disc.data.get("dirty",false):count+=1
	return count

func text()->String:
	if summary:return report
	if not started:return "JOUR %d · %s · PRÊT\n%d clients locataires, arrivées variées, puis retours et close.\nObjectif vendredi : semaine parfaite.\nLe bac À démêler reste à part."%[day,weekday(),target_customers]
	return "JOUR %d · %s · %s\nClients arrivés : %d / %d\nRetours attendus : %d · reçus : %d · rangés : %d\nRéparations : %d\nClôture après le dernier client et les retours.\nÀ démêler peut attendre demain."%[day,weekday(),"FERMETURE" if closing else "OUVERT",arrived_customers,target_customers,clerk.returns_due.size(),returned,restocked,clerk.repairs.processed]
