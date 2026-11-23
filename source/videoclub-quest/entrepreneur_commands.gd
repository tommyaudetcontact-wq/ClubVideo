extends RefCounted
## Visiting players send intent, never prices, balances, or inventory state.
static func perform(business,command:Dictionary,position:Vector3) -> String:
	if str(command.get("op","")) in ["parcel","take_board","place_board","drill","screw","place_shelf","place_poster","cancel_poster","sign","move_shelf","carton_use","carton_take","carton_drop","shelve_at","place_decor"]:
		return physical(business,command,position)
	var near_computer:bool=position.distance_to(business.game.clerk.screen.global_position)<=2.5 or position.distance_to(business.office_screen.global_position)<=2.5
	if not near_computer:return "Approche-toi d’un ordinateur pour gérer la boutique."
	var op:=str(command.get("op",""))
	var id:=int(command.get("id",-1))
	var success:=false
	match op:
		"buy":
			if int(command.get("day",-1))!=business.state.day:return "La boutique en ligne a changé. Actualise la commande."
			match str(command.get("kind","")):
				"film":success=business.buy_film(id)
				"shelf":success=business.buy_shelf(id)
				"decoration":success=business.decor.buy(id)
				"bundle":
					if id<0 or id>=business.state.bundles.size():return "Ce lot n’est plus disponible."
					var batch:Dictionary=business.state.bundles[id]
					success=business.state.buy("films",-1,batch.price,batch.movies)
			business.flush_orders()
			return "Commande confirmée. Livraison au backstore." if success else "Commande impossible : fonds insuffisants ou article indisponible."
		"poster":
			if not business.state.offers.has(id):return "Ce film n’est plus proposé aujourd’hui."
			success=business.state.buy("poster",id,1500)
			return "Affiche commandée." if success else "Fonds insuffisants."
		"label":
			var genre:=int(command.get("genre",-1))
			if id<0 or id>=business.state.shelves.size() or genre<0 or genre>=business.state.CATEGORIES.size():return "Rayon ou catégorie indisponible."
			return "Étiquette commandée." if business.state.buy("sign",genre,300,[id]) else "Fonds insuffisants."
		"sell":return "Exemplaire revendu." if business.sell_copy(id) else "Cet exemplaire ne peut pas être revendu."
		"claim":
			var customer:Dictionary=business.game.clerk.active
			if customer.is_empty() or int(customer.get("account_id",-1))!=id:return "Ce client doit être à la caisse pour réclamer ses frais."
			if not business.ledgers.has(id):return "Dossier indisponible."
			var ledger:Dictionary=business.ledgers[id]
			var amount:int=ledger.get("balance",0)
			customer.account_due=int(customer.get("account_due",0))+amount
			business.game.clerk.accounts.ensure(id).balance+=amount
			ledger.balance=0
			business.game.clerk.refresh_invoice()
			return "Frais ajoutés à la facture." if amount>0 else "Aucun frais à réclamer."
		"ban":
			if not business.ledgers.has(id):return "Dossier indisponible."
			business.ledgers[id].banned=not business.ledgers[id].get("banned",false)
			return "Dossier mis à jour."
		"cancel":
			for index in business.state.reservations.size():
				var reservation:Dictionary=business.state.reservations[index]
				if int(reservation.account)==id and int(reservation.movie)==int(command.get("movie",-1)):
					business.cancel_reservation(index)
					return "Réservation annulée."
			return "Cette réservation n’est plus active."
		"day":
			match business.state.phase:
				"preparation":return "Boutique ouverte." if business.open_day() else "Prépare les rayons avant d’ouvrir."
				"closing":return "Close terminé." if business.close_day() else "La boutique doit encore être rangée."
				"closed":business.next_day();return "Nouvelle journée."
			return "La boutique ferme à minuit."
		"save":return "Partie partagée sauvegardée." if business.game.session.save_game(false) else "Échec de sauvegarde."
	return "Action de gestion inconnue."
static func point_from(command:Dictionary) -> Vector3:
	var values:Variant=command.get("point")
	if not values is Array or values.size()!=3:return Vector3.INF
	for value in values:
		if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value))>50:return Vector3.INF
	return Vector3(float(values[0]),float(values[1]),float(values[2]))
static func physical(b,command:Dictionary,position:Vector3) -> String:
	var op:=str(command.get("op",""))
	var id:=int(command.get("id",-1))
	b.freight.tick()
	if op=="place_decor":
		var point:=point_from(command)
		var angle:float=float(command.get("angle",0))
		if not point.is_finite() or not is_finite(angle) or position.distance_to(point)>5:return "Placement indisponible."
		var pose:=Transform3D(Basis(Vector3.UP,snappedf(angle,PI/4)),point)
		return "Décoration posée." if b.decor.install(id,pose) else "Cet emplacement est occupé."
	if op=="shelve_at":
		var item:Dictionary=b.game.clerk.lan.guest_case
		var point:=point_from(command)
		if item.is_empty() or not point.is_finite() or position.distance_to(point)>2.3:return "Approche-toi du rayon avec un boîtier."
		if not item.node.get_meta("antitheft",false):return "Remets l’antivol avant de ranger."
		if not b.slots.choose(item.record,point):return "Cette place n’est plus disponible."
		item.node.global_position=item.record.world.origin;b.game.clerk.lan.drop_guest_case();return "Boîtier rangé."
	if op=="move_shelf":
		if id<0 or id>=b.state.shelves.size() or not b.assembly.is_empty():return "Rayon indisponible."
		b.start_move_shelf(id);b.guest_placing=true;return "Vise le sol pour déplacer le rayon."
	if op.begins_with("carton_"):
		var order:Dictionary=b.freight.order_for(id)
		if order.is_empty() or order.kind not in ["films","shelf","decoration"] or not b.packages.has(id):return "Carton indisponible."
		if position.distance_to(b.packages[id].global_position)>2.8 and b.freight.guest_id!=id:return "Approche-toi du carton."
		if b.freight.held_id==id:return "Ton collègue tient ce carton."
		if op=="carton_take":b.freight.guest_id=id;return "Carton pris."
		if op=="carton_drop":
			if b.freight.guest_id!=id:return "Tu ne tiens pas ce carton."
			var point:=point_from(command)
			if not point.is_finite() or position.distance_to(point)>3:return "Emplacement trop éloigné."
			point.x=clampf(point.x,-5.25,5.25);point.z=clampf(point.z,-13.9,6.2);point.y=maxf(.135,point.y)
			for box in b.game.layout.colliders:
				if point.x+.24>box.min[0] and point.x-.24<box.max[0] and point.z+.20>box.min[2] and point.z-.20<box.max[2] and point.y-.13<box.max[1]:point.y=box.max[1]+.135
			b.packages[id].position=point;b.freight.guest_id=-1;return "Carton déposé."
		if order.kind=="shelf" and order.get("opened",false):return physical(b,{"op":"take_board"},position)
		if order.kind!="films":b.open_parcel(id)
		elif not order.get("opened",false):b.freight.open_box(order)
		else:b.freight.extract(order,1,true)
		return ""
	if op=="sign":
		if position.distance_to(b.sign.global_position)>2.5:return "Approche-toi du néon."
		b.action(0,1)
		return ""
	if op=="parcel":
		if not b.packages.has(id) or position.distance_to(b.packages[id].global_position)>2.8:return "Approche-toi du colis."
		var orders:Array=b.state.orders.filter(func(order):return int(order.id)==id)
		if orders.is_empty():return "Ce colis a déjà été ouvert."
		if orders[0].kind in ["films","shelf","decoration"]:
			if b.freight.held_id==id:return "Ton collègue tient ce carton."
			if b.freight.guest_id!=id:b.freight.guest_id=id;return "Carton pris."
			if orders[0].kind=="shelf" and orders[0].get("opened",false):return physical(b,{"op":"take_board"},position)
			if orders[0].kind!="films":b.open_parcel(id)
			elif not orders[0].get("opened",false):b.freight.open_box(orders[0])
			else:b.freight.extract(orders[0],1,true)
			return ""
		if orders[0].kind=="poster":
			if b.poster_placement.active() or (b.guest_poster_order>=0 and b.guest_poster_order!=id):return "Une affiche est déjà en cours de placement."
			b.guest_poster_order=id
			return "Vise un mur pour poser l’affiche."
		b.open_parcel(id)
		if is_instance_valid(b.ghost):b.guest_placing=true
		return ""
	if op=="cancel_poster":
		if b.guest_poster_order==id:b.guest_poster_order=-1
		return "Colis de l’affiche conservé."
	if op=="place_poster":
		if b.guest_poster_order!=id:return "Cette affiche n’est plus en cours de placement."
		var point:=point_from(command)
		if not point.is_finite() or position.distance_to(point)>5:return "Vise un mur à proximité."
		var hit:Dictionary=b.poster_placement.wall_pose(position,(point-position).normalized())
		if hit.is_empty() or hit.pose.origin.distance_to(point)>.12 or not b.poster_placement.allowed(hit.pose,position):return "Cet emplacement est occupé ou masqué."
		var orders:Array=b.state.orders.filter(func(order):return int(order.id)==id)
		if orders.is_empty():return "Cette affiche a déjà été posée."
		b.state.posters.append({"movie":int(orders[0].value),"day":b.state.day,"pose":hit.pose})
		b.place_poster(int(orders[0].value));b.consume_order(orders[0]);b.guest_poster_order=-1
		return "Affiche posée."
	if op=="place_shelf":
		if not b.guest_placing or not is_instance_valid(b.ghost):return "Aucune étagère à poser."
		var point:=point_from(command)
		var angle:Variant=command.get("angle",0)
		if not point.is_finite() or not (angle is int or angle is float) or not is_finite(float(angle)) or absf(float(angle))>100:return "Placement invalide."
		if Vector2(point.x-position.x,point.z-position.z).length()>5:return "Approche-toi de l’emplacement."
		var pose:Transform3D=b.snap_placement(point,snappedf(float(angle),PI/4),int(b.assembly.model))
		if not b.valid_placement(pose,int(b.assembly.model)):return "Le passage est bloqué."
		b.ghost.transform=pose;b.finish_placement()
		return "Étagère posée."
	if op=="drill":
		if position.distance_to(b.drill.global_position)>2.8 and not b.guest_drill:return "Approche-toi de la perceuse."
	elif not is_instance_valid(b.assembly_node) or position.distance_to(b.assembly_node.global_position)>2.8:return "Approche-toi du chantier."
	match op:
		"take_board":
			if b.assembly.is_empty() or int(b.assembly.boards)>=6:return "Les planches sont déjà posées."
			if b.board_hand>=0 or b.guest_board or b.guest_drill:return "Une planche ou un outil est déjà en main."
			b.guest_board=true
			b.guest_board_node=b.Props.box(b,Vector3.ZERO,Vector3(.35,.025,.18),"b58b5b")
			return "Planche prise."
		"place_board":
			if not b.guest_board:return "Prends la planche à côté de l’établi."
			b.guest_board=false
			if is_instance_valid(b.guest_board_node):b.guest_board_node.queue_free();b.guest_board_node=null
			b.place_board()
			return "Planche placée."
		"drill":
			if b.drill_hand>=0 or b.guest_board:return "La perceuse est déjà utilisée, ou ta main est occupée."
			b.guest_drill=not b.guest_drill
			if not b.guest_drill:b.drill.position=Vector3(-3.1,.94,-12.8);b.drill.rotation=Vector3.ZERO
			return "Perceuse prise." if b.guest_drill else "Perceuse reposée."
		"screw":
			if not b.guest_drill or b.assembly.is_empty() or int(b.assembly.boards)!=6:return "Pose les six planches puis prends la perceuse."
			b.fasten_screw(.61,int(command.get("index",-1)))
			if is_instance_valid(b.ghost):
				b.guest_drill=false;b.guest_placing=true
				b.drill.position=Vector3(-3.1,.94,-12.8);b.drill.rotation=Vector3.ZERO
			return "Vis fixée."
	return "Action d’atelier indisponible."
