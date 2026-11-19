# Esegui: godot --headless --path . -s tests/test_newcomers.gd
# Nuovi coloni (GDD 4.2.1): l'avventuriero contento che dopo 3 spedizioni chiede di restare, la finestra della
# domanda (Accogli, No, più tardi dalla scheda), il colono che diventa, il forestiero
extends SceneTree

const SAVES := preload("res://saves.gd")

var main


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(5)
	main = load("res://main.tscn").instantiate()
	main.game_start = false
	main.settings_file = ""
	root.add_child(main)
	await process_frame
	main.threats = false
	main.needs_rate = 0.0
	var R = main.Res
	var mid: Vector2i = main.MAP_SIZE / 2
	var inn = make_room(mid + Vector2i(0, -10))
	for k in [Vector2i(-2, -2), Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2)]:
		main.furniture[mid + Vector2i(0, -10) + k] = [main.Build.BED, R.WOOD, 0]
	main.furniture[mid + Vector2i(2, -11)] = [main.Build.TABLE, R.WOOD, 0]
	main.furniture[mid + Vector2i(-2, -9)] = [main.Build.NOTICE_BOARD, R.WOOD, 0]
	inn.kind = main.RoomKind.INN
	var panel = main.get_node("HUD/RequestPanel")

	# un guerriero di livello 3 torna alla locanda dalla seconda spedizione: non chiede ancora niente
	var g = guest(main.Hero.WARRIOR, 3, inn)
	g.trips = 2
	back(g)
	check(main.requests.is_empty() and not panel.visible, "dopo 2 spedizioni non chiede di restare")
	# dalla terza, contento, sì: la finestra si apre
	g.trips = 3
	back(g)
	check(main.requests == [[g]] and main.request_of(g) == [g] and panel.visible and main.asking == [g], "dopo 3 chiede di restare")
	var text: String = panel.get_node("Box/Text").text
	check(main.full_name(g) in text and "back from 3 expeditions" in text and "foreigner" in text, "la domanda: chi, cosa: %s" % text)
	check(panel.get_node("Box/People").get_child_count() == 1, "la sua figurina")
	# scontento no
	var sad = guest(main.Hero.ARCHER, 1, inn)
	sad.trips = 3
	sad.needs[main.Need.HAPPINESS] = main.STAY_HAPPY - 1
	back(sad)
	check(main.request_of(sad).is_empty(), "scontento: non chiede")

	# chiusa con la X, la domanda resta sulla scheda: il pulsante la riapre
	panel.hide()
	main.open_sheet(g)
	var sheet = main.get_node("HUD/ColonistSheet/Box")
	check(sheet.get_node("Family/Request").visible and "Asks to stay in the colony." in sheet.get_node("Hero").text, "sulla scheda")
	sheet.get_node("Family/Request").pressed.emit()
	check(panel.visible and main.asking == [g], "il pulsante della scheda riapre la domanda")

	# salvata e ricaricata, la domanda c'è ancora (ed è lo stesso avventuriero)
	var state: Dictionary = main.game_state()
	SAVES.pending = state
	var copy = load("res://main.tscn").instantiate()
	copy.game_start = false
	copy.settings_file = ""
	root.add_child(copy)
	await process_frame
	check(copy.requests.size() == 1 and copy.requests[0][0] in copy.guests and copy.get_node("HUD/RequestPanel").visible,
		"ricaricata: la domanda c'è ancora, e si riapre")
	copy.free()
	Engine.time_scale = 1.0

	# No: resta un avventuriero, e lo richiede dopo altre 3 spedizioni
	panel.get_node("Box/Row/No").pressed.emit()
	check(main.requests.is_empty() and not panel.visible and g in main.guests and g.refused_at == 3, "no: resta avventuriero")
	check(not sheet.get_node("Family/Request").visible, "la scheda si rifà: niente più pulsante")
	g.trips = 5
	back(g)
	check(main.requests.is_empty(), "dopo 2 spedizioni ancora no")
	g.trips = 6
	back(g)
	check(main.request_of(g) == [g], "dopo altre 3 lo richiede")

	# ingaggiato ritira la domanda; se ne va, lo stesso
	main.add_item(R.GOLD, mid + Vector2i(12, 0), 100)
	main.stockpile[mid + Vector2i(12, 0)] = true
	check(main.send([g], main.ruins[0]) and main.requests.is_empty() and not panel.visible, "ingaggiato: non aspetta più la risposta")
	main.expeditions.clear()
	g.hired = false
	g.trips = 9
	back(g)
	check(main.request_of(g) == [g], "tornato, chiede")
	main.clock = g.stay_until
	main.update_guests()
	check(main.requests.is_empty() and g.errand == main.Errand.LEAVE, "nessuno risponde: se ne va")
	main.guests.erase(g)

	# Accogli: un guerriero diventa colono, con la sua roba; forestiero per 5 giorni
	var w = guest(main.Hero.WARRIOR, 3, inn)
	w.gifts = [main.Gift.FAMOUS]
	w.trips = 3
	var splendor: int = main.colony_splendor()
	back(w)
	panel.get_node("Box/Row/Yes").pressed.emit()
	check(w in main.colonists and w not in main.guests and w.hero == main.Hero.NONE and w.former == main.Hero.WARRIOR, "accolto: è un colono")
	check(w.skills[main.Skill.MELEE] == 6 and w.gear[main.Slot.HANDS] == R.SWORD and w.gear[main.Slot.BODY] == R.CHAINMAIL,
		"tiene abilità ed equipaggiamento")
	check(w.gear.get(main.Slot.SHIELD) == R.SHIELD and main.Look.SHIELD not in w.kit and main.gear_sum(w, "armor") == 5 + 3 + 3,
		"lo scudo del corredo è uno scudo vero, nel suo slot")
	check(main.colony_splendor() == splendor, "il famoso dà ancora splendore")
	check(is_equal_approx(w.conds.get(main.Cond.FOREIGNER, 0.0), main.clock + 5.0), "forestiero per 5 giorni")
	check(is_equal_approx(main.cond_product(w, 1), 1.1) and main.mood_bonus(w) == -5.0, "forestiero: +10% tempo, -5 felicità")
	check(main.free_beds(w).all(func(o): return not main.is_inn(main.room_at(o))), "dorme nei letti dei coloni")
	check(Array(main.chronicle).any(func(l): return main.full_name(w) + " stays in the colony." in l), "la cronaca lo scrive")
	main.open_sheet(w)
	check("Once a warrior, level 3, 3 expeditions" in sheet.get_node("Hero").text, "sulla scheda: un tempo guerriero")
	main.routines = false
	main.find_job(w)
	check(w.job != main.Job.RELAX, "lavora come gli altri")

	# lo scassinatore si toglie maschera e sacca, l'arciere tiene la faretra
	var b = guest(main.Hero.BURGLAR, 2, inn)
	var a = guest(main.Hero.ARCHER, 2, inn)
	for o in [b, a]:
		o.trips = 3
		back(o)
	check(main.requests == [[b], [a]] and main.asking == [b], "due domande: una alla volta")
	main.answer(true)
	check(main.asking == [a] and panel.visible, "risposto alla prima, la seconda")
	main.answer(true)
	check(b.kit.is_empty() and b.gear[main.Slot.HANDS] == R.DAGGER, "lo scassinatore senza maschera né sacca, col pugnale")
	check(a.kit == [main.Look.QUIVER] and a.gear[main.Slot.HANDS] == R.BOW, "l'arciere con la faretra")
	check(main.requests.is_empty() and not panel.visible, "finite le domande")

	# --- Viandanti ---
	main.next_guest = INF  # niente altri arrivi alla locanda durante le prove
	main.next_suitor = INF
	w.gifts = []
	# l'attesa: in media 30 giorni; lo splendore attira (+15: 30 / 1,75); sopra 8 coloni frena (16: ×4)
	check(main.colony_splendor() == 0 and main.colonists.size() <= main.CROWD and is_equal_approx(main.wander_wait(), 30.0),
		"senza splendore uno ogni 30 giorni")
	for o in [w, b, a]:
		o.gifts = [main.Gift.FAMOUS]
	check(is_equal_approx(main.wander_wait(), 30.0 / 1.75), "a 15 di splendore uno ogni 17")
	var extra := []
	while main.colonists.size() < 16:
		extra.append(person())
	check(is_equal_approx(main.wander_wait(), 30.0 / 1.75 * 4.0), "a 16 coloni l'attesa è 4 volte tanto")
	for o in extra:
		main.colonists.erase(o)
	for o in [w, b, a]:
		o.gifts = []
	# non prima del giorno 10
	main.next_wanderer = 0.0
	main.update_wanderers()
	check(main.next_wanderer >= main.WANDERER_FROM and not main.guests.any(func(g): return g.wanderer), "dal giorno 10")

	# chi arriva: 70% soli, 15% coppie, 15% famiglie; uno su quattro con un attrezzo
	var kinds := [0, 0, 0]
	var tools := 0
	for i in 2000:
		var group: Array = main.wanderer_group()
		kinds[2 if group.any(func(o): return main.age_of(o) < main.ADULT) else group.size() - 1] += 1
		tools += 1 if group[0].gear.has(main.Slot.HANDS) else 0
		for o in group:  # niente cicli di riferimenti: si liberano
			o.fellows = []
			o.spouse = null
	check(kinds[0] > 1300 and kinds[0] < 1500 and kinds[1] > 220 and kinds[1] < 380 and kinds[2] > 220 and kinds[2] < 380,
		"soli, coppie, famiglie: %s" % str(kinds))
	check(tools > 420 and tools < 580, "attrezzi: %d su 2000" % tools)
	var couple: Array = main.wanderer_group(1)
	check(couple.size() == 2 and couple[0].spouse == couple[1] and couple[1].spouse == couple[0] and couple[0].sex != couple[1].sex
		and couple[0].last_name == couple[1].last_name, "la coppia: sposata, lo stesso cognome")
	var lone: Array = main.wanderer_group(0)
	var adult = lone[0]
	check(lone.size() == 1 and adult.wanderer and main.age_of(adult) >= 16 and main.age_of(adult) <= 45
		and adult.skills.reduce(func(n, v): return n + v, 0) == 4 and adult.skills.max() <= 3 and adult.traits.size() <= 2,
		"uno solo: 16-45 anni, 4 punti abilità, al più 2 talenti")

	# una famiglia arriva dal bordo e va nella radura (né sala del trono né fuoco): lì chiede di restare
	var family: Array = main.wanderer_group(2)
	var kid = family[-1]
	check(main.age_of(kid) >= 4 and main.age_of(kid) <= 11 and kid.skills.max() == 0 and kid.traits.is_empty()
		and family.all(func(o): return o.last_name == family[0].last_name and o.fellows == family), "il figlio, 4-11 anni")
	check((kid.mother in family or kid.father in family) and family.slice(0, -1).all(func(p): return main.age_of(p) >= main.age_of(kid) + 16),
		"i genitori, abbastanza grandi")
	main.come(family)
	check(family.all(func(o): return o in main.guests and o.errand == main.Errand.VISIT and o.job == main.Job.TRAVEL), "arrivano")
	main.update_wanderers()
	check(main.next_wanderer == 0.0 and main.guests.filter(func(g): return g.wanderer).size() == family.size(), "uno alla volta")
	walk_until(func(): return not main.requests.is_empty(), 8000)
	var head = main.requests[0][0]
	check(main.requests[0] == family and panel.visible and main.cell_of(head.pos).distance_to(mid) <= 5.0, "nella radura, chiedono")
	check(family.all(func(o): return is_equal_approx(o.stay_until, main.clock + main.WANDERER_WAIT)), "aspettano 2 giorni")
	text = panel.get_node("Box/Text").text
	check(text.begins_with("Wanderers ask to stay in the colony: ") and main.full_name(kid) in text
		and panel.get_node("Box/Row/No").text == "Send away", "la domanda dei viandanti: %s" % text)
	main.find_job(head)
	check(head.job not in main.WORK_JOBS and main.free_beds(head).all(func(o): return main.is_inn(main.room_at(o))),
		"intanto non lavorano, e dormono alla locanda")
	main.open_board()
	var rows: int = main.get_node("HUD/BoardPanel/Box/Heroes").get_children().filter(func(r): return r is HBoxContainer).size()
	check(rows == main.guests.filter(func(g): return g.hero != main.Hero.NONE and g.errand != main.Errand.LEAVE).size()
		and rows < main.guests.size(), "non sono sulla bacheca")
	main.get_node("HUD/BoardPanel").hide()
	main.answer(true)
	check(family.all(func(o): return o in main.colonists and o not in main.guests and not o.wanderer and o.conds.has(main.Cond.FOREIGNER)),
		"accolti: coloni, forestieri")
	check(not main.can_do(kid, main.Work.BUILD) and main.children_of(kid.mother if kid.mother != null else kid.father).has(kid),
		"il figlio è un bambino della colonia, coi suoi genitori")
	check(Array(main.chronicle)[-1].ends_with(" stay in the colony."), "la cronaca: restano")

	# Manda via: se ne vanno; senza risposta per 2 giorni, lo stesso
	main.come(main.wanderer_group(0))
	walk_until(func(): return not main.requests.is_empty(), 8000)
	var gone = main.requests[0][0]
	main.answer(false)
	check(gone.errand == main.Errand.LEAVE and main.requests.is_empty() and gone not in main.colonists, "mandato via, se ne va")
	walk_until(func(): return gone not in main.guests, 8000)
	main.come(main.wanderer_group(1))
	walk_until(func(): return not main.requests.is_empty(), 8000)
	var pair: Array = main.requests[0]
	main.clock = pair[0].stay_until
	main.update_guests()
	check(pair.all(func(o): return o.errand == main.Errand.LEAVE) and main.requests.is_empty() and not panel.visible,
		"nessuna risposta in 2 giorni: se ne vanno insieme")

	# --- Le leggi dell'Accoglienza ---
	var L = main.Law
	main.authority = 1000.0
	check(main.LAWS[L.CLOSED_GATES]["kind"] == main.LawKind.PEOPLE and main.LAWS[L.OATH]["tier"] == 1, "categoria Popolo; il giuramento in baronia")
	# porte chiuse: nessuno chiede di restare, nessun viandante; tutti +5
	check(main.codify(L.CLOSED_GATES) and main.enact(L.CLOSED_GATES), "porte chiuse")
	var stays = guest(main.Hero.ARCHER, 2, inn)
	stays.trips = 3
	back(stays)
	check(main.requests.is_empty(), "porte chiuse: l'avventuriero non chiede")
	main.next_wanderer = main.clock
	main.update_wanderers()
	check(not main.guests.any(func(g): return g.wanderer and g.errand != main.Errand.LEAVE), "porte chiuse: nessun viandante")
	check(main.law_mood_of(w, L.CLOSED_GATES) == 5.0, "tutti +5")
	# porte aperte, al posto delle chiuse: si chiede dopo 2 spedizioni, viandanti il doppio, forestieri per 10 giorni (-5)
	var wait: float = main.wander_wait()
	check(main.codify(L.OPEN_GATES) and main.enact(L.OPEN_GATES) and not main.enacted.has(L.CLOSED_GATES), "porte aperte, al posto delle chiuse")
	check(is_equal_approx(main.wander_wait(), wait / 2.0), "i viandanti il doppio")
	stays.trips = 2
	back(stays)
	check(main.request_of(stays) == [stays], "porte aperte: chiede dopo 2 spedizioni")
	main.answer(true)
	check(is_equal_approx(stays.conds[main.Cond.FOREIGNER], main.clock + 10.0), "forestiero per 10 giorni")
	check(main.law_mood_of(stays, L.OPEN_GATES) == -5.0 and main.law_mood_of(main.ruler, L.OPEN_GATES) == 0.0, "i forestieri -5, gli altri niente")
	check("foreigners -5" in main.law_tip(L.OPEN_GATES), "nel suggerimento della legge")
	main.revoke(L.OPEN_GATES)

	# giuramento (baronia): chi resta va nella sala del trono, un'ora in ginocchio, e giura: 10 autorità, non è forestiero
	check(main.codify_block(L.OATH) == "Needs a barony", "il giuramento vuole la baronia")
	main.rank = 1
	check(main.codify(L.OATH) and main.enact(L.OATH), "giuramento")
	var hall = make_room(mid + Vector2i(10, -10))
	main.furniture[mid + Vector2i(10, -12)] = [main.Build.THRONE, R.WOOD, 0]
	hall.kind = main.RoomKind.THRONE_ROOM
	main.come(main.wanderer_group(0))
	walk_until(func(): return not main.requests.is_empty(), 8000)
	var vow = main.requests[0][0]
	check(main.cell_of(vow.pos).distance_to(mid + Vector2i(10, -10)) <= 3.0, "i viandanti vanno nella sala del trono")
	main.answer(true)
	check(vow.oath and vow.conds.has(main.Cond.FOREIGNER), "accolto: deve giurare")
	walk_until(func(): return vow.job == main.Job.OATH and vow.path.is_empty(), 4000)
	check(main.room_at(main.cell_of(vow.pos)) == hall, "in ginocchio nella sala del trono")
	walk_until(func(): return vow.sworn, 2000)
	check(not vow.oath and not vow.conds.has(main.Cond.FOREIGNER), "ha giurato: non è forestiero")
	check(main.law_mood_of(vow, L.OATH) == 5.0 and main.law_mood_of(main.ruler, L.OATH) == 0.0, "chi ha giurato +5")
	var other = main.wanderer_group(0)[0]
	main.authority = 25.0
	main.swear(other)
	check(other.sworn and main.authority == 15.0, "il giuramento costa 10 autorità")
	check(Array(main.chronicle).any(func(l): return main.full_name(vow) + " swears loyalty to the crown." in l), "nella cronaca")
	# senza autorità resta forestiero
	main.authority = 5.0
	var poor = main.wanderer_group(0)[0]
	main.guests.append(poor)
	main.requests.append([poor])
	main.asking = [poor]
	main.answer(true)
	main.swear(poor)
	check(not poor.sworn and poor.conds.has(main.Cond.FOREIGNER) and main.authority == 5.0, "senza autorità resta forestiero")
	# revocata la legge, niente giuramento
	main.authority = 1000.0
	poor.oath = true
	main.revoke(L.OATH)
	check(not main.try_oath(poor) and not poor.oath and not poor.sworn, "revocata la legge, niente giuramento")

	# --- Compagnia della corona: i coloni partono con gli avventurieri ---
	main.routines = false
	for o in main.colonists:  # niente di strano: in piedi, non incinte, senza giuramento da fare
		o.downed = false
		o.due = 0.0
		o.oath = false
		o.errand = main.Errand.NONE
	var ready: Array = main.volunteers()
	check(main.ruler not in ready and kid not in ready and w in ready, "partono gli adulti, non il sovrano né i bambini")
	w.due = 1.0
	check(w not in main.volunteers(), "né le incinte")
	w.due = 0.0
	main.researched.erase(main.Tech.CROWN_COMPANY)
	check(main.volunteers().is_empty(), "senza la ricerca nessuno")
	main.researched[main.Tech.CROWN_COMPANY] = true
	check(main.role_of(w) == {"weapon": main.Skill.MELEE, "hurt": 2.0} and main.role_of(a)["weapon"] == main.Skill.RANGED,
		"chi era avventuriero combatte come la sua classe")
	var farmer = person()
	farmer.skills[main.Skill.RANGED] = 4
	check(main.role_of(farmer) == {"weapon": main.Skill.RANGED, "hurt": 1.0}, "gli altri con la loro arma migliore, la parte media dei colpi")
	# la bacheca: sotto chi aspetta alla locanda, i coloni; ci vuole almeno un avventuriero
	var leader = guest(main.Hero.WARRIOR, 2, inn)
	main.board_pick.clear()
	main.open_board()
	var board = main.get_node("HUD/BoardPanel/Box")
	check(board.get_node("Company").visible and board.get_node("Company/List").get_child_count() == main.volunteers().size(),
		"la bacheca mostra i coloni che possono partire")
	main.toggle_pick(true, farmer)
	main.fill_board()
	var send_button: Button = board.get_node("Ruins").get_child(0).get_child(-1)
	check(send_button.disabled and send_button.tooltip_text == "At least one adventurer must go", "un colono da solo non parte")
	check(not main.send([farmer], main.ruins[0]), "un colono da solo non parte")
	main.get_node("HUD/BoardPanel").hide()
	var tower = main.ruins[0]
	tower.cleared = 0
	main.stockpile[mid + Vector2i(12, 0)] = true  # le stanze rifatte (la sala del trono) l'avevano tolto
	var gold: int = main.stored(R.GOLD)
	check(main.send([leader, farmer], tower), "il guerriero e il colono partono")
	check(main.stored(R.GOLD) == gold - main.fee(leader) and main.fee(farmer) == 0, "il colono non ha paga")
	var trip = main.expeditions[-1]
	var size: int = main.colony_size()
	walk_until(func(): return trip.left_at >= 0, 8000)
	check(farmer not in main.colonists and farmer not in main.guests and main.colony_size() == size, "partiti: il colono è fuori dalla mappa, ma conta")
	check(farmer not in main.volunteers(), "via, non si spunta")
	# il ritorno: il colono non prende la quota, torna in colonia, passa dalla locanda e torna al lavoro
	trip.lost = false
	trip.party.assign([leader, farmer])
	trip.dead.clear()
	trip.loot = {R.GOLD: 100}
	main.clock = trip.back_at
	main.update_expeditions()
	check(farmer in main.colonists and farmer.trips == 1 and farmer.errand == main.Errand.RETURN and leader in main.guests,
		"tornati: il colono è di nuovo in colonia")
	check(leader.loot[R.GOLD] == 100 - floori(100 * main.SHARE / 2.0) and farmer.loot.is_empty(),
		"la quota la prende solo l'avventuriero, e porta lui il bottino")
	walk_until(func(): return farmer.errand == main.Errand.NONE, 8000)
	check(not farmer.hired and farmer in main.volunteers(), "arrivato: può ripartire")
	main.find_job(farmer)
	check(farmer.job != main.Job.RELAX and farmer.job != main.Job.TRAVEL, "e lavora")

	# morto nella rovina: la colonia lo sa al ritorno; lutto e -5 autorità; finché non si sa, conta ancora
	var fallen = person()
	main.colonists.erase(fallen)
	var grim = main.Expedition.new()
	grim.ruin = tower
	grim.left_at = main.clock
	grim.back_at = main.clock + 1.0
	grim.lost = true
	grim.dead.append(fallen)
	main.expeditions.append(grim)
	if main.ruler.sex == main.Sex.MALE:  # un figlio del sovrano: in spedizione resta nella linea di successione
		fallen.father = main.ruler
	else:
		fallen.mother = main.ruler
	check(main.colony_size() == main.colonists.size() + 1 and fallen in main.line_of(main.ruler),
		"finché non si sa, conta: per il titolo e per la successione")
	main.authority = 50.0
	main.clock = grim.back_at
	main.update_expeditions()
	check(fallen.died > 0.0 and main.authority == 45.0 and main.colonists.all(func(o): return o.conds.has(main.Cond.MOURNING)),
		"lutto e -5 autorità")
	check(Array(main.chronicle).any(func(l): return main.full_name(fallen) + " died in the Ruined tower." in l) and fallen not in main.corpses,
		"nella cronaca; il corpo resta là")

	print("OK: nuovi coloni (l'avventuriero che resta, i viandanti, le leggi dell'Accoglienza, la compagnia della corona)")
	quit()


# un colono in più, adulto, accanto al centro
func person():
	var c = main.Colonist.new()
	main.dress(c, main.people().map(func(o): return o.first_name))
	c.pos = main.center(main.MAP_SIZE / 2 + Vector2i(main.colonists.size(), 1))
	c.skills = main.Skill.values().map(func(_s): return 0)
	c.xp = main.Skill.values().map(func(_s): return 0)
	c.needs = main.Need.values().map(func(_n): return 60.0)
	c.trend = c.needs.map(func(_v): return 0.0)
	main.give_age(c, main.ADULT_AGE)
	main.colonists.append(c)
	return c


# fa andare avanti il gioco finché `done` non è vero (al massimo `ticks` giri da 0,05 s)
func walk_until(done: Callable, ticks: int) -> void:
	for i in ticks:
		if done.call():
			return
		main.tick(0.05)
	check(done.call(), "arrivato in tempo")


# un avventuriero alla locanda, senza talenti, contento
func guest(kind, level: int, inn):
	var h = main.new_hero(kind, level)
	h.gifts = []
	h.traits = []
	h.needs[main.Need.HAPPINESS] = 70.0
	h.pos = main.center(inn.cells.keys()[0])
	main.guests.append(h)
	return h


# `h` torna alla locanda da una spedizione
func back(h) -> void:
	h.errand = main.Errand.RETURN
	h.job = main.Job.TRAVEL
	main.arrive(h)


# stanza 5x5 di legno attorno a `mid`, porta in basso
func make_room(mid: Vector2i):
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var k := mid + Vector2i(dx, dy)
			clear(k)
			if k == mid + Vector2i(0, 3):
				main.built[k] = [main.Build.DOOR, main.Res.WOOD]
			elif maxi(absi(dx), absi(dy)) == 3:
				main.built[k] = [main.Build.WALL, main.Res.WOOD]
				main.astar.set_point_solid(k)
	clear(mid + Vector2i(0, 4))
	main.update_rooms()
	return main.room_at(mid)


func clear(k: Vector2i) -> void:
	for layer in [main.trees, main.rocks, main.bushes, main.weeds, main.water, main.boulders]:
		layer.erase(k)
	main.astar.set_point_solid(k, false)


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
