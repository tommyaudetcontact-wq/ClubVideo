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
	if not closing:
		time_left=maxf(0,time_left-dt)
		if time_left<=0:
			closing=true
			break_left=0
			clerk.game._message("Fermeture : termine les clients, range le club et clôture la caisse.")

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
func game_has_loose_stock()->bool:
	return is_instance_valid(clerk.game.held) or not clerk.game.held_record.is_empty() or clerk.game.modes.loose_dvds.any(func(record):return is_instance_valid(record.get("loose_body")))

func text()->String:
	if summary:return report
	if not started:return "JOUR %d · PRÊT\nOuverture de 6 minutes, puis clôture complète.\nLe bac À démêler reste à part."%day
	return "JOUR %d · %s\nTemps restant : %d:%02d\nRetours : %d · rangés : %d\nRéparations : %d\nClôture : servir, ramasser, ranger et rentrer l’argent.\nÀ démêler peut attendre demain."%[day,"FERMETURE" if closing else "OUVERT",int(time_left)/60,int(time_left)%60,returned,restocked,clerk.repairs.processed]
