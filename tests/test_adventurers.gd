# Esegui: godot --headless --path . -s tests/test_adventurers.gd
# Avventurieri e rovine (locanda, arrivi, ingaggio con l'oro, spedizione alla torre, ritorno), morte e lutto
extends SceneTree

var main


var lost := false


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(1)
	main = load("res://main.tscn").instantiate()
	main.game_start = false
	root.add_child(main)
	await process_frame
	main.needs_rate = 0.0
	main.routines = false  # niente orari: la routine è provata in test_jobs
	main.threats = false
	main.animals.clear()
	var R = main.Res
	var B = main.Build
	var mid: Vector2i = main.MAP_SIZE / 2
	var tower = main.ruins[0]
	check(main.ruins.size() == 1 and tower.kind == main.RuinKind.TOWER and tower.cleared == 0, "si conosce solo la torre")
	check(main.ICONS.has(R.GOLD) and main.STACK_MAX[R.GOLD] == 100, "l'oro: monete, a mucchi da 100")

	# senza locanda non arriva nessuno, e il prossimo arrivo slitta
	main.clock = main.next_guest + 0.1
	main.update_guests()
	check(main.guests.is_empty() and main.next_guest > main.clock, "senza locanda nessun avventuriero")

	# la locanda: letto, tavolo e bacheca; senza la bacheca non lo è
	var inn = make_room(mid)
	main.furniture[mid + Vector2i(-2, -2)] = [B.BED, R.WOOD, 0]
	main.furniture[mid + Vector2i(1, -2)] = [B.TABLE, R.WOOD, 0]
	check(not main.room_meets(inn, main.RoomKind.INN), "senza bacheca non è una locanda")
	var board := mid + Vector2i(-2, 1)
	main.furniture[board] = [B.NOTICE_BOARD, R.WOOD, 0]
	check(main.room_meets(inn, main.RoomKind.INN) and main.ROOM_CLASS[main.RoomKind.INN] == main.RoomClass.SERVICE, "locanda: servizio")
	inn.kind = main.RoomKind.INN
	var store := mid + Vector2i(8, 0)  # un magazzino all'aperto, con l'oro e qualche pasto
	var pantry := store + Vector2i.RIGHT
	clear(store)
	clear(pantry)
	main.stockpile = {store: true, pantry: true}
	main.add_item(R.GOLD, store, 12)
	main.add_item(R.MEAL, pantry, 3)

	# i letti della locanda sono degli avventurieri, gli altri dei coloni
	var bed := mid + Vector2i(-2, -2)
	var colonist = main.colonists[0]
	for o in main.colonists:
		o.pos = main.center(mid + Vector2i(-6 - main.colonists.find(o), 0))
	check(bed not in main.free_beds(colonist), "i coloni non dormono alla locanda")

	# arriva un avventuriero dal bordo e va alla locanda
	main.next_guest = main.clock
	main.update_guests()
	check(main.guests.size() == 1, "con un letto alla locanda arriva un avventuriero")
	var g = main.guests[0]
	var start: Vector2i = main.cell_of(g.pos)
	check(start.x in [0, main.MAP_SIZE.x - 1] or start.y in [0, main.MAP_SIZE.y - 1], "dal bordo della mappa")
	check(g.hero != main.Hero.NONE and g.level >= 1 and g.level <= 2 and g.errand == main.Errand.ARRIVE and g.job == main.Job.TRAVEL,
		"un %s di livello %d, in cammino" % [main.Hero.keys()[g.hero], g.level])
	check(g.gifts.size() == 1, "un talento da avventuriero")
	plain(g)  # qui niente talenti: i conti delle prove restano esatti
	var data: Dictionary = main.HEROES[g.hero]
	check(g.gear.get(main.Slot.HANDS) == data["gear"][main.Slot.HANDS] and g.kit == data["kit"], "porta l'equipaggiamento della classe")
	for skill in data["skills"]:
		check(g.skills[skill] == data["skills"][skill] * g.level, "abilità della classe secondo il livello")
	check(main.fee(g) == main.FEE_BASE + main.FEE_PER_LEVEL * g.level, "paga secondo il livello")
	main.update_guests()
	check(main.guests.size() == 1, "un letto, un avventuriero")
	walk_until(func(): return g.errand == main.Errand.NONE, 4000)
	check(main.room_at(main.cell_of(g.pos)) == inn and is_equal_approx(g.stay_until, main.clock + main.RENOWNED_GUESTS[1]),
		"arrivato alla locanda, aspetta (5 giorni: nei test la locanda rinomata è studiata)")
	check(main.free_beds(g) == [bed], "dorme solo nei letti della locanda")
	main.find_job(g)
	check(g.job not in main.WORK_JOBS, "non lavora")

	# la bacheca: chi aspetta, da spuntare; le rovine col tasto per mandarci gli spuntati; l'oro non basta
	main.open_board()
	var box = main.get_node("HUD/BoardPanel/Box")
	check(main.get_node("HUD/BoardPanel").visible and box.get_node("Waiting/People/Heroes").get_child_count() == 1, "la bacheca mostra chi aspetta")
	var pick: CheckBox = box.get_node("Waiting/People/Heroes").get_child(0).get_child(2)
	var send: Button = box.get_node("Ruins").get_child(0).get_child(-1)
	check(send.disabled, "senza nessuno spuntato non si manda nessuno")
	pick.button_pressed = true
	main.fill_board()
	send = box.get_node("Ruins").get_child(0).get_child(-1)
	check(main.board_pick == [g] and send.disabled == (main.fee(g) > 12), "spuntato; senza abbastanza oro non si parte")
	check(not main.send([g], tower) or main.fee(g) <= 12, "ingaggio rifiutato")
	main.add_item(R.GOLD, store, 50)
	var gold_before: int = main.stored(R.GOLD)
	check(main.provisions([g], tower) == 3, "provviste: un giorno a testa, andata, 3 stanze e ritorno")
	main.fill_board()
	check(box.get_node("Gold").text.begins_with(main.coins(main.stored(R.GOLD))), "sulla bacheca le monete con l'icona")
	main.drop(R.LEATHER_ARMOR, mid + Vector2i(6, 6), 1)
	check(main.job_list().contains("Haul %s: 1" % main.item_name(R.LEATHER_ARMOR)) and main.item_name(R.LEATHER_ARMOR).ends_with(" leather armor"),
		"finestra Jobs: nomi senza trattini, col tipo")
	check(main.describe(mid + Vector2i(6, 6))[0] == main.item_title(R.LEATHER_ARMOR) + " pile", "il mucchio: tipo e nome")
	main.items[R.LEATHER_ARMOR].clear()
	check(main.send([g], tower), "ingaggiato")
	check(main.stored(R.GOLD) == gold_before - main.fee(g) and g.hired and g.errand == main.Errand.DEPART, "pagato, va al bordo")
	check(main.stored(R.MEAL) == 0 and main.expeditions[0].food == 3.0 and main.board_pick.is_empty(), "si porta i pasti")
	check(not main.send([g], tower), "non due volte")
	var exp = main.expeditions[0]
	walk_until(func(): return g not in main.guests, 6000)
	check(g not in main.guests and exp.left_at >= 0 and exp.back_at > main.clock and not exp.lines.is_empty(), "partito: è nella rovina")
	main._process(0.0)
	check("EXPEDITION: 1" in main.info_label.text, "in alto: una spedizione")
	check(exp.lost or tower.cleared > 0 or "collapse" in "".join(exp.lines), "ha esplorato qualcosa")

	# ritorno: col bottino (meno la quota) alla locanda; il diario in una finestra e nella cronaca
	exp.loot = {R.GOLD: 20, R.IRON: 5}
	lost = exp.lost
	print("\n".join(exp.lines))
	main.clock = exp.back_at
	main.update_expeditions()
	check(main.expeditions.is_empty() and main.get_node("HUD/ReportPanel").visible and main.chronicle.size() >= 2, "il diario")
	if not lost:
		check(main.COIN in main.get_node("HUD/ReportPanel/Box/Text").text and not " gold" in main.get_node("HUD/ReportPanel/Box/Text").text,
			"nel diario le monete sono un'icona")
	if not lost:
		check(g in main.guests and g.errand == main.Errand.RETURN and g.trips == 1, "torna dal bordo")
		check(g.loot[R.GOLD] == 20 - floori(20 * main.SHARE) and g.loot[R.IRON] == 5, "si tiene il 30% delle monete")
		walk_until(func(): return g.errand == main.Errand.NONE, 6000)
		check(main.total(R.IRON) == 5 and not g.hired, "lascia il bottino alla locanda")
		# chi aspetta troppo se ne va
		main.clock = g.stay_until
		main.update_guests()
		check(g.errand == main.Errand.LEAVE, "nessuno lo ingaggia: se ne va")
		walk_until(func(): return g not in main.guests, 6000)
		check(g not in main.guests, "andato via")

	# in gruppo: si parte quando sono usciti tutti, dallo stesso bordo
	var duo := [plain(main.new_hero(main.Hero.WARRIOR, 1)), plain(main.new_hero(main.Hero.ARCHER, 1))]
	for h in duo:
		h.pos = main.center(mid + Vector2i(-1 + duo.find(h) * 2, 0))
		main.guests.append(h)
	main.add_item(R.GOLD, store, 60)
	tower.cleared = 0  # la prima spedizione può averla finita
	check(main.send(duo, tower), "due insieme")
	var pair = main.expeditions[-1]
	check(pair.food == 0.0, "senza provviste: patiranno la fame")
	for i in 8000:
		if duo.any(func(h): return h in main.guests):
			check(pair.left_at < 0, "si aspetta che escano tutti")
		else:
			break
		main.tick(0.05)
	check(pair.left_at >= 0 and "No food left" in "\n".join(pair.lines), "partiti, e senza cibo hanno fame")
	main.expeditions.erase(pair)

	# nella rovina, per conto suo: il guardiano ferisce di più chi regge di meno
	var warrior = plain(main.new_hero(main.Hero.WARRIOR, 1))
	var burglar = plain(main.new_hero(main.Hero.BURGLAR, 1))
	check(main.gear_sum(warrior, "armor") == 8, "guerriero: cuoio, elmo e scudo")
	check(plain(main.new_hero(main.Hero.WARRIOR, main.HEAVY_LEVEL)).gear[main.Slot.BODY] == R.CHAINMAIL, "da livello 3 la cotta")
	for c in [warrior, burglar]:
		var e = main.Expedition.new()
		e.party.append(c)
		main.fight_monsters(e, main.MONSTER_POWER)
	check(warrior.hp > burglar.hp and burglar.hp < main.MAX_HP, "i mostri fanno più male allo scassinatore")
	# forzieri: lo scassinatore li apre tutti, e con la sacca porta di più; il guerriero non quelli chiusi
	var opened := 0
	for i in 200:
		var e = main.Expedition.new()
		e.party.append(warrior if i % 2 else burglar)
		opened += 1 if main.open_chest(e, main.RUINS[tower.kind], false)[1] and i % 2 else 0
		if i % 2 == 0:
			check(e.loot[R.GOLD] >= 15 and e.loot[R.GOLD] <= 38, "lo scassinatore apre tutto, +50%")
	check(opened > 20 and opened < 80, "il guerriero apre circa metà dei forzieri (%d su 100)" % opened)
	# da solo e senza forze, il guardiano lo uccide: spedizione persa
	var doomed = plain(main.new_hero(main.Hero.ARCHER, 1))
	doomed.hp = 1.0
	var ruin = main.Ruin.new()
	ruin.cleared = main.RUINS[ruin.kind]["rooms"] - 1
	var e2 = main.Expedition.new()
	e2.party.append(doomed)
	e2.ruin = ruin
	main.depart(e2)
	check(e2.lost and e2.party.is_empty() and is_equal_approx(e2.back_at - main.clock, (e2.due - main.clock) * main.LOST_AFTER),
		"nessuno torna: la si dà per persa al doppio del tempo")
	# il tesoro dell'ultima stanza ha la mappa della rovina dopo; se resta chiuso, la stanza resta da fare
	for r in main.ruins.duplicate():  # la prima spedizione può aver già trovato la mappa della miniera
		if r.kind != main.RuinKind.TOWER:
			main.ruins.erase(r)
	var treasure = main.Expedition.new()
	treasure.party.append(burglar)
	treasure.ruin = tower
	check(main.open_chest(treasure, main.RUINS[tower.kind], true)[1] and treasure.maps == [main.RuinKind.MINE], "la mappa della miniera")
	var stuck := false
	for i in 60:
		var r = main.Ruin.new()
		r.cleared = main.RUINS[r.kind]["rooms"] - 1
		var e = main.Expedition.new()
		e.party.append(plain(main.new_hero(main.Hero.WARRIOR, 5)))
		e.ruin = r
		e.food = 10.0
		main.depart(e)
		if "stays locked" in "\n".join(e.lines):
			stuck = r.cleared == main.RUINS[r.kind]["rooms"] - 1 and e.maps.is_empty()
			break
	check(stuck, "tesoro chiuso: l'ultima stanza resta da fare, niente mappa")
	# provviste per una stanza sola: dopo la prima si torna
	var short := false
	for i in 60:
		var r = main.Ruin.new()
		var e = main.Expedition.new()
		e.party.append(plain(main.new_hero(main.Hero.WARRIOR, 5)))
		e.ruin = r
		e.food = main.RUINS[r.kind]["travel"] + main.ROOM_DAYS
		main.depart(e)
		if "Provisions are running low" in "\n".join(e.lines):
			short = r.cleared == 1
			break
	check(short, "provviste agli sgoccioli: si torna")
	# al ritorno le mappe fanno conoscere le rovine, in ordine
	var mapped = main.Expedition.new()
	mapped.party.append(plain(main.new_hero(main.Hero.BURGLAR, 1)))
	mapped.ruin = tower
	mapped.maps = [main.RuinKind.MINE]
	mapped.left_at = main.clock
	mapped.back_at = main.clock
	mapped.edge = start
	main.expeditions.append(mapped)
	main.update_expeditions()
	check(main.ruins.map(func(r): return r.kind) == [main.RuinKind.TOWER, main.RuinKind.MINE], "la miniera sulla bacheca")
	main.fill_board()
	check(box.get_node("Ruins").get_child_count() == 2, "due rovine sulla bacheca")
	main.guests.erase(mapped.party[0])

	# livelli: ogni 2 spedizioni tornate
	var vet = plain(main.new_hero(main.Hero.ARCHER, 1))
	vet.trips = 1
	var e3 = main.Expedition.new()
	e3.party.append(vet)
	e3.ruin = ruin
	e3.left_at = main.clock
	e3.back_at = main.clock
	e3.edge = start
	main.expeditions.append(e3)
	main.update_expeditions()
	check(vet.trips == 2 and vet.level == 2 and vet.skills[main.Skill.RANGED] == 4, "sale di livello")
	main.guests.erase(vet)

	# talenti degli avventurieri: 16, con le loro icone e i loro effetti
	var G = main.Gift
	check(G.size() == 16 and main.HERO_TRAITS_SHEET.get_width() == 16 * 16 and main.GIFT_INFO.size() == 16, "16 talenti con l'icona")
	var greedy = plain(main.new_hero(main.Hero.ARCHER, 2))
	greedy.gifts = [G.GREEDY]
	var jinxed = plain(main.new_hero(main.Hero.ARCHER, 2))
	jinxed.gifts = [G.JINXED]
	check(main.fee(greedy) == 25 and main.fee(jinxed) == 15, "l'avido chiede di più, l'iettato di meno")
	var forager = plain(main.new_hero(main.Hero.ARCHER, 1))
	forager.gifts = [G.FORAGER]
	var guide = plain(main.new_hero(main.Hero.ARCHER, 1))
	guide.gifts = [G.PATHFINDER]
	var fresh_tower = main.Ruin.new()
	main.researched.erase(main.Tech.CARTOGRAPHY)
	check(main.provisions([forager], fresh_tower) == 2 and main.provisions([guide], fresh_tower) == 2
		and main.trip_days(fresh_tower, [guide]) == 2.0, "chi trova cibo e la guida: meno provviste, viaggio più corto")
	main.researched[main.Tech.CARTOGRAPHY] = true
	check(main.trip_days(fresh_tower, [guide]) == 1.875, "con la cartografia l'andata e il ritorno un quarto più corti")
	var famous = plain(main.new_hero(main.Hero.ARCHER, 1))
	famous.gifts = [G.FAMOUS]
	var shine: int = main.colony_splendor()
	main.guests.append(famous)
	check(main.colony_splendor() == shine + 5, "il famoso dà splendore finché è qui")
	main.guests.erase(famous)
	# il codardo fa tornare il gruppo appena è ferito; il leale non prende la quota
	var coward = plain(main.new_hero(main.Hero.WARRIOR, 5))
	coward.gifts = [G.COWARD]
	coward.hp = 59.0
	var scared = main.Expedition.new()
	scared.party.append(coward)
	scared.ruin = main.Ruin.new()
	scared.food = 10.0
	main.depart(scared)
	check(scared.ruin.cleared <= 1 and ("is wounded" in "\n".join(scared.lines) or "collapse" in "\n".join(scared.lines)),
		"il codardo torna dopo la prima stanza")
	var loyal = plain(main.new_hero(main.Hero.WARRIOR, 1))
	loyal.gifts = [G.LOYAL]
	var paid = plain(main.new_hero(main.Hero.ARCHER, 1))
	var shared = main.Expedition.new()
	shared.party.append_array([loyal, paid])
	shared.ruin = main.Ruin.new()
	shared.loot = {R.GOLD: 100}
	shared.left_at = main.clock
	shared.back_at = main.clock
	shared.edge = start
	main.expeditions.append(shared)
	main.update_expeditions()
	check(loyal.loot[R.GOLD] == 85, "il leale non prende la sua parte: il gruppo tiene il 15%")
	main.guests.erase(loyal)
	main.guests.erase(paid)
	# il furtivo a volte evita i mostri, il medico cura, la stanza la dice il diario
	var sneaky = plain(main.new_hero(main.Hero.BURGLAR, 1))
	sneaky.gifts = [G.STEALTHY, G.MEDIC]
	check(main.party_gift([sneaky], "sneak", 0.0) == 0.25 and main.party_gift([sneaky], "heal", 0.0) == 6.0, "furtivo e medico")
	# il berserker picchia il doppio ma prende più ferite
	var calm = plain(main.new_hero(main.Hero.WARRIOR, 1))
	var mad = plain(main.new_hero(main.Hero.WARRIOR, 1))
	mad.gifts = [G.BERSERKER]
	for h in [calm, mad]:
		var e = main.Expedition.new()
		e.party.append(h)
		main.fight_monsters(e, main.MONSTER_POWER * 4)
	check(mad.hp < calm.hp, "il berserker sanguina di più")
	# nella scheda le icone dei talenti, col nome nel suggerimento
	main.guests.append(sneaky)
	main.open_sheet(sneaky)
	var icons: Array = main.get_node("HUD/ColonistSheet/Box/Traits/Icons").get_children()
	check(icons.size() == 2 and icons[0].tooltip_text.begins_with("Stealthy\n"), "talenti nella scheda")
	main.guests.erase(sneaky)
	main.sheet_panel.hide()

	# cimeli: si trovano nella cripta e nel forte; in magazzino, un colono ne fa una decorazione che dà splendore
	for kind in main.RELICS:
		var relic: int = main.RELICS[kind]
		check(main.ICONS.has(relic) and main.BUILD_RES[kind] == relic and main.BUILD_COST[kind] == 1 and main.SPLENDOR.has(kind),
			"cimelio %s" % main.Build.keys()[kind])
		check(main.RUINS.values().any(func(d): return d["finds"].any(func(f): return f[0] == relic)), "si trova in una rovina")
	var shelf := store + Vector2i.DOWN
	var plinth := store + Vector2i(0, 3)
	clear(shelf)
	clear(plinth)
	main.stockpile[shelf] = true
	main.add_item(R.CROWN, shelf, 1)
	var before: int = main.colony_splendor()
	var power: float = main.authority
	main.furniture_plans[plinth] = [B.CROWN, R.CROWN, 0]
	walk_until(func(): return main.furniture.has(plinth), 6000)
	check(main.furniture[plinth][0] == B.CROWN and main.colony_splendor() == before + main.SPLENDOR[B.CROWN] and main.total(R.CROWN) == 0,
		"la corona sul suo cuscino: +6 splendore")
	check(main.authority >= power + main.RELIC_AUTHORITY, "cimelio posato: +3 autorità")
	# la cronaca: tutto, dal più recente
	main.open_board()
	main.fill_board()
	main.get_node("HUD/BoardPanel/Box/ChronicleButton").pressed.emit()
	var pages: String = main.get_node("HUD/ChroniclePanel/Box/Scroll/Text").text
	check(main.get_node("HUD/ChroniclePanel").visible and pages.begins_with(main.chronicle[-1]) and main.chronicle[0] in pages,
		"la cronaca intera, dal più recente")
	main.get_node("HUD/ChroniclePanel").hide()
	main.get_node("HUD/BoardPanel").hide()

	# morte: la protezione abbassa la probabilità di morire; a terra, il morso uccide
	check(is_equal_approx(main.death_chance(colonist), main.DEATH_BASE) or not colonist.gear.is_empty(), "senza protezione 25%")
	colonist.gear = {main.Slot.BODY: R.CHAINMAIL, main.Slot.HEAD: R.HELMET}
	check(is_equal_approx(main.death_chance(colonist), main.DEATH_MIN), "con cotta ed elmo al minimo")
	var others: Array = main.colonists.filter(func(o): return o != colonist)
	for o in others:
		o.pos = main.center(mid)  # al chiuso, nella locanda
	colonist.pos = main.center(mid + Vector2i(0, 8))
	colonist.hp = 0.0
	colonist.downed = true
	var wolf = main.add_animal(main.Beast.WOLF, mid + Vector2i(0, 12))
	main.update_wolf(wolf, 0.05)
	check(wolf.target == colonist, "nessuno in piedi fuori: il lupo va da chi è a terra")
	var spot: Vector2i = main.cell_of(colonist.pos)
	var was_ruler: bool = colonist == main.ruler  # il sovrano: lutto regale, e dopo nella cronaca l'erede
	main.bite(wolf, colonist)
	check(colonist not in main.colonists and colonist in main.corpses and wolf.target == null, "a terra, il morso uccide")
	check(main.total(R.CHAINMAIL) == 1 and main.total(R.HELMET) == 1, "l'equipaggiamento resta per terra")
	check(others.all(func(o): return o.conds.has(main.Cond.ROYAL_MOURNING if was_ruler else main.Cond.MOURNING)), "gli altri sono in lutto")
	check(Array(main.chronicle).slice(-2).any(func(line): return "killed by wolves" in line), "nella cronaca")
	check(not main.fallen, "la colonia c'è ancora")
	main.queue_redraw()
	await process_frame  # disegna il corpo e chi è vivo
	main.clock += main.CORPSE_DAYS
	main.tick(0.0)
	check(main.corpses.is_empty(), "il corpo sparisce dopo un giorno")
	for o in others:
		main.die(o, "died.")
	check(main.colonists.is_empty() and main.fallen and main.get_node("HUD/Fallen").visible, "morti tutti: la colonia è caduta")
	print("OK: avventurieri, torre e morte (la prima spedizione è %s)" % ("persa" if lost else "tornata"))
	quit()


# niente talenti: per le prove che contano i punti ferita e le monete
func plain(h):
	h.gifts = []
	h.traits = []
	return h


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


# fa andare avanti il gioco finché `done` non è vero (al massimo `ticks` giri da 0,05 s)
func walk_until(done: Callable, ticks: int) -> void:
	for i in ticks:
		if done.call():
			return
		main.tick(0.05)
	check(done.call(), "arrivato in tempo")


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
