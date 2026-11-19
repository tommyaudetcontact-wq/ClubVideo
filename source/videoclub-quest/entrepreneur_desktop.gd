extends Control
var desktop
var business
var page:=0
var offset:=0
var selected:=-1
var selected_genre:=0
var heading:Label
var message:Label
var rows:Array[Button]=[]
var row_ids:Array=[]
var primary:Button
var secondary:Button
const TABS:=["Commandes","Inventaire","Clients","Réservations","Calendrier","Rayons"]

func setup(owner_desktop) -> void:
	desktop=owner_desktop
	position=Vector2(12,60)
	size=Vector2(810,605)
	for index in TABS.size():
		var tab:=index
		add_button(Rect2(index*135,0,131,40),TABS[index],func():page=tab;offset=0;selected=-1;refresh())
	heading=desktop.label(self,Rect2(8,48,794,62),25,Color("17396b"))
	for index in range(5):
		var row:=index
		add_button(Rect2(8,120+index*62,794,56),"",func():select_row(row))
		rows.append(desktop.targets.back())
	message=desktop.label(self,Rect2(8,435,794,70),22,Color("17396b"))
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_button(Rect2(8,518,135,40),"Précédent",func():offset=maxi(0,offset-5);refresh())
	add_button(Rect2(151,518,135,40),"Suivant",func():offset+=5;refresh())
	add_button(Rect2(294,518,248,40),"",act)
	primary=desktop.targets.back()
	add_button(Rect2(550,518,252,40),"",alternate)
	secondary=desktop.targets.back()
	add_button(Rect2(8,566,794,35),"Journée · ouvrir / clôturer / lendemain",day_action)

func add_button(bounds:Rect2,text:String,callback:Callable) -> void:
	desktop.button(self,bounds,text,callback,Color("315d9d"))
	desktop.targets.back().add_theme_font_size_override("font_size",21)

func refresh() -> void:
	business=desktop.clerk.game.entrepreneur
	if not business:return
	var state=business.state
	heading.text="%s · %.2f $ disponibles · %s · %02d/%02d/%04d"%[state.hour(),state.cash/100.0,state.weather,state.calendar().day,state.calendar().month,state.calendar().year]
	row_ids=[]
	var descriptions:Array[String]=[]
	match page:
		0:
			for model in range(3):
				row_ids.append({"kind":"shelf","id":model})
				descriptions.append("Étagère %d de large · %d places · %.2f $"%[state.SHELF_COLUMNS[model],state.SHELF_COLUMNS[model]*4,state.SHELF_PRICES[model]/100.0])
			for index in state.bundles.size():
				row_ids.append({"kind":"bundle","id":index})
				descriptions.append("Lot de %d films · %.2f $"%[state.bundles[index].movies.size(),state.bundles[index].price/100.0])
			for id in state.offers:
				row_ids.append({"kind":"film","id":id})
				var movie:Dictionary=business.game.layout.movies[id]
				descriptions.append("%s · %d · %.2f $\n%s · %s · %.1f/5 · %s"%[str(movie.title).left(28),int(movie.year),state.purchase_price(movie)/100.0,str(movie.genre),"NOUVEAU" if state.is_new(id) else "VIEUX" if state.rental(movie)==375 else "STANDARD",state.ratings[id],business.review_tag(id)])
			message.text="Sélectionne un achat, puis Commander. Livraison au backstore après 10 s. Les prix de location affichés sont tout compris."
			primary.text="Commander"
			secondary.text="Affiche du film · 15 $"
		1:
			for id in state.stock:
				var entry:Dictionary=state.stock[id]
				if entry.get("sold",false):continue
				row_ids.append({"kind":"stock","id":id})
				var location:="PRÊTÉ / RETOUR À SCANNER" if not entry.get("returned_scanned",true) else "Rayon %d, place %d"%[int(entry.shelf)+1,int(entry.slot)+1] if entry.get("shelved",false) else "À RANGER"
				var movie:Dictionary=business.game.layout.movies[entry.movie]
				descriptions.append("%s · %d · %.1f/5\n%s · %s"%[str(movie.title).left(27),int(movie.year),float(state.ratings.get(int(entry.movie),3)),str(movie.genre),location])
			message.text="Un retour reste prêté jusqu’au scan. Localiser indique son emplacement en jaune si le boîtier est dans la boutique."
			primary.text="Localiser en jaune"
			secondary.text="Revendre · 2 $"
		2:
			for id in business.ledgers:
				var entry:Dictionary=business.ledgers[id]
				row_ids.append({"kind":"client","id":id})
				descriptions.append("Client %03d · %d visites · %d retards · %.2f $ · %s"%[id,entry.get("visits",0),entry.get("late",0),entry.get("balance",0)/100.0,"BANNI" if entry.get("banned",false) else "ACTIF"])
			message.text="Les frais sont à réclamer au client à sa prochaine visite. Bannir empêche ses nouvelles locations."
			primary.text="Réclamer les frais"
			secondary.text="Bannir / réadmettre"
		3:
			for index in state.reservations.size():
				var entry:Dictionary=state.reservations[index]
				row_ids.append({"kind":"reservation","id":index})
				descriptions.append("Client %03d · %s · jour %d · %s"%[entry.account,str(business.game.layout.movies[entry.movie].title).left(22),entry.day,"PRÊT" if entry.ready else "À PRÉPARER"])
			message.text="Apporte le bon exemplaire au présentoir derrière la caisse. Le client viendra aujourd’hui ou demain."
			primary.text="Localiser un exemplaire"
			secondary.text="Annuler la réservation"
		4:
			var date:Dictionary=state.calendar()
			descriptions.append("Aujourd’hui · %02d/%02d/%04d · %s"%[date.day,date.month,date.year,state.weather])
			descriptions.append("8 min d’ouverture · 08:00 → 24:00")
			descriptions.append("Prochaine sortie · jour %d"%state.next_release)
			descriptions.append("Prochains lots · jour %d"%state.next_bundle)
			descriptions.append(state.report if not state.report.is_empty() else "Préparation libre · ouvre le néon pour commencer.")
			message.text="Le calendrier papier est au bureau du backstore. Les samedis et dimanches attirent davantage de visiteurs."
			primary.text="Sauvegarder"
			secondary.text=""
		5:
			for index in state.shelves.size():
				row_ids.append({"kind":"shelf","id":index})
				var shelf:Dictionary=state.shelves[index]
				descriptions.append("Rayon %d · %d places\nÉtiquette : %s"%[index+1,state.SHELF_COLUMNS[int(shelf.model)]*4,str(shelf.get("genre","")) if not str(shelf.get("genre","")).is_empty() else "aucune"])
			message.text="Choix : %s. Commande une étiquette, puis ouvre son colis : elle sera posée sur ce rayon."%str(state.CATEGORIES[selected_genre])
			primary.text="Changer la catégorie"
			secondary.text="Étiquette · 3 $"
	offset=mini(offset,maxi(0,descriptions.size()-1)/5*5)
	for index in rows.size():
		var position_index:=offset+index
		rows[index].visible=position_index<descriptions.size()
		if rows[index].visible:
			rows[index].text=descriptions[position_index]
			rows[index].modulate=Color("ffe4a4") if selected==position_index else Color.WHITE
	secondary.visible=not secondary.text.is_empty()

func select_row(index:int) -> void:
	selected=offset+index
	refresh()

func act() -> void:
	if not business:return
	if page==4:
		business.game.session.save_game()
		return
	if selected<0 or selected>=row_ids.size():return
	var item:Dictionary=row_ids[selected]
	var success:=false
	if page==5:
		selected_genre=(selected_genre+1)%business.state.CATEGORIES.size()
		refresh()
		return
	match page:
		0:
			match item.kind:
				"shelf":success=business.buy_shelf(item.id)
				"film":success=business.buy_film(item.id)
				"bundle":
					var batch:Dictionary=business.state.bundles[item.id]
					success=business.state.buy("films",-1,batch.price,batch.movies)
			business.game._message("Commande confirmée. Livraison au backstore." if success else "Fonds insuffisants.")
		1:business.locate_id=int(item.id)
		2:
			var customer:Dictionary=business.game.clerk.active
			if customer.is_empty() or int(customer.get("account_id",-1))!=int(item.id):
				business.game._message("Ce client doit être à la caisse pour réclamer ses frais.")
			else:
				var ledger:Dictionary=business.ledgers[item.id]
				var amount:int=ledger.get("balance",0)
				customer.account_due=int(customer.get("account_due",0))+amount
				business.game.clerk.accounts.ensure(item.id).balance+=amount
				ledger.balance=0
				business.game.clerk.refresh_invoice()
		3:
			var reservation:Dictionary=business.state.reservations[item.id]
			var copies:Array=business.state.stock.keys().filter(func(id):return business.state.stock[id].movie==reservation.movie and not business.state.stock[id].get("sold",false))
			if not copies.is_empty():business.locate_id=int(copies[0])
	refresh()

func alternate() -> void:
	if selected<0 or selected>=row_ids.size():return
	var item:Dictionary=row_ids[selected]
	match page:
		0:
			if item.kind=="film":
				var ok:bool=business.state.buy("poster",item.id,1500)
				business.game._message("Affiche commandée." if ok else "Fonds insuffisants.")
		1:business.sell_copy(int(item.id))
		2:
			var ledger:Dictionary=business.ledgers[item.id]
			ledger.banned=not ledger.get("banned",false)
		3:business.cancel_reservation(int(item.id))
		5:
			var ok:bool=business.state.buy("sign",selected_genre,300,[int(item.id)])
			business.game._message("Étiquette commandée pour ce rayon." if ok else "Fonds insuffisants.")
	refresh()

func day_action() -> void:
	match business.state.phase:
		"preparation":business.open_day()
		"closing":business.close_day()
		"closed":business.next_day()
		"open":business.game._message("Boutique ouverte jusqu’à minuit.")
	refresh()
