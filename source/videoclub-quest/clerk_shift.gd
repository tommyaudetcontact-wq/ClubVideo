extends RefCounted
var clerk
var day=1
var duration=600.0
var time_left=600.0
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
var wave=0
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
func capacity()->int:return mini(5,day+1)
func can_spawn()->bool:return not enabled or (started and not closing and not summary and break_left<=0)
func spawned():
	if not enabled:return
	wave+=1
	if wave>=2:
		wave=0
		break_left=45.0
func tick(dt:float):
	if not enabled or not started or summary:return
	break_left=maxf(0,break_left-dt)
	if not closing:
		time_left=maxf(0,time_left-dt)
		if time_left<=0:
			closing=true
			clerk.game._message("Fermeture : termine les clients présents et le rangement. Écran JOURNÉE pour faire le bilan.")
	for c in clerk.customers.customers.duplicate():
		if c.state!="service":continue
		if c==clerk.active and clerk.paid:continue
		if not c.has("patience"):c.patience=0.0
		c.patience+=dt
		var limit=120.0+float(c.get("patience_bonus",0))
		if c.patience>=limit:clerk.abandon_customer(c)
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
	for item in clerk.cases:
		if item.kind in ["return","shelve"]:
			clerk.game._message("Vide la chute et range les retours avant la fermeture. Les boîtiers à démêler peuvent attendre.")
			return false
	if is_instance_valid(clerk.repairs.disc) or is_instance_valid(clerk.inspection.carried):
		clerk.game._message("Libère la machine de réparation et dépose tout disque que tu tiens. Les disques sur la table peuvent attendre.")
		return false
	var expected=initial_cash+revenue
	var actual=cash_in_till()
	business_balance+=revenue-refunds
	report="BILAN · JOUR %d\nClients servis : %d · partis : %d\nVentes perdues : %.2f $ · oublis de scan : %d\nRetours reçus : %d · rangés : %d\nRéparations : %d · reste : %d\nPénalités / remboursements : %.2f $\nRésultat net : %.2f $ · cumul : %.2f $\nCaisse attendue : %.2f $\nCaisse comptée : %.2f $\nÉCART : %+.2f $\nClique l’écran pour la journée suivante."%[day,served,abandoned,lost_sales/100.0,missed_scans,returned,restocked,clerk.repairs.processed,clerk.cases.filter(func(i):return i.kind in ["return","sorting","shelve"]).size(),refunds/100.0,(revenue-refunds)/100.0,business_balance/100.0,expected/100.0,actual/100.0,(actual-expected)/100.0]
	summary=true
	return true
func next_day():
	day+=1
	duration=600.0
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
	wave=0
	break_left=5
	clerk.repairs.processed=0
	clerk.customers.spawn_timer=5
func text()->String:
	if not started:return "JOUR 1 · PRÊT\nPrends un objet ou touche la caisse pour commencer.\nJournées de 10 minutes ; difficulté progressive.\nLa fermeture laisse finir les clients et ranger."
	if summary:return report
	return "JOUR %d · %s\nOuverture restante : %d:%02d\nPatience : caisse 2:00 · file 2:00\nRetours : %d · rangés : %d\nFin des arrivées : termine et range, puis clique ici.\nLe bilan compare la caisse réelle au montant attendu."%[day,"FERMETURE" if closing else "OUVERT",int(time_left)/60,int(time_left)%60,returned,restocked]
