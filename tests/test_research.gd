# Esegui: godot --headless --path . -s tests/test_research.gd
# Ricerca (GDD 4.7): sblocchi e costi del sapere, studio allo scrittoio, governo dal trono, leggi e loro effetti,
# decima e granaio, libri nelle rovine, le finestre Knowledge e Laws; in una partita vera lupi dal giorno 5 e l'arma
# abbandonata sulla mappa
extends SceneTree


func _initialize() -> void:
	seed(1)
	var main = load("res://main.tscn").instantiate()
	main.start_rooms = false
	root.add_child(main)
	await process_frame
	main.needs_rate = 0.0
	main.routines = false
	main.threats = false
	main.animals.clear()
	main.bushes.clear()
	main.flax.clear()
	main.weeds.clear()
	var T = main.Tech
	var L = main.Law
	var R = main.Res
	var B = main.Build
	check(main.researched.size() == T.size(), "nei test tutto studiato")
	check(main.TECHS_SHEET.get_width() == T.size() * 16 and main.LAWS_SHEET.get_width() == L.size() * 16
		and main.CONDITIONS_SHEET.get_width() == main.Cond.size() * 16 and main.BRANCHES_SHEET.get_width() == main.Branch.size() * 16,
		"un'icona per ricerca, per legge, per condizione, per ramo")
	check(main.Res.values().all(func(r): return main.ICONS.has(r) and main.STACK_MAX.has(r) and main.ITEM_KIND.has(r)), "i libri sono oggetti")

	# sblocchi: senza ricerche niente forgia, pietra, lampade; quello che nessuna ricerca nomina c'è
	main.researched.clear()
	main.refresh_unlocks()
	var furnace_button: Button = main.furniture_bar.get_node("Row/Furnace")
	check(not furnace_button.visible and not main.get_node("HUD/BuildBar/Row/Materials/Stone").visible, "forgia e pietra nascoste")
	check(main.furniture_bar.get_node("Row/Bed").visible and main.furniture_bar.get_node("Row/Desk").visible
		and main.furniture_bar.get_node("Row/Throne").visible, "letto, scrittoio e trono dall'inizio")
	check(not main.unlocked("makes", R.INGOT) and main.unlocked("builds", B.CAMPFIRE), "lingotti no, fuoco da campo sì")
	check(main.research_block(T.FORGE) == "60 more study" and not main.research(T.FORGE), "senza studio non si studia")
	main.study = 70.0
	check(main.research(T.FORGE) and is_equal_approx(main.study, 10.0) and furnace_button.visible and main.unlocked("makes", R.INGOT),
		"forgia: 60 punti, fornace e lingotti sbloccati")
	check(main.research_block(T.CHAINMAIL) == "First: Iron Arms", "la cotta dopo le armi di ferro")
	main.study = 500.0
	check(main.research(T.IRON_ARMS), "armi di ferro")
	check(main.research_block(T.CHAINMAIL) == "Needs a notebook in a warehouse", "livello II: serve un quaderno")
	var area := Rect2i(main.MAP_SIZE / 2 - Vector2i(12, 12), Vector2i(24, 24))
	var free: Array = main.cells_in(area).filter(func(k): return main.can_build(k))
	main.sort_by_distance(free, main.center(main.MAP_SIZE / 2))
	main.stockpile = {free[-1]: true, free[-2]: true}
	main.add_item(R.NOTEBOOK, free[-1], 1)
	check(main.research(T.CHAINMAIL) and main.stored(R.NOTEBOOK) == 0 and is_equal_approx(main.study, 120.0), "il quaderno si consuma")

	# la finestra Knowledge: un pulsante per ricerca; cliccato, studia
	main.study = 40.0
	main.get_node("HUD/Tools/Row/Knowledge").button_pressed = true
	main.fill_knowledge()
	var buttons: Array = main.get_node("HUD/KnowledgePanel/Box/Scroll/Tree").find_children("*", "Button", true, false)
	check(buttons.size() == T.size(), "un pulsante per ricerca")
	var inn_button: Button = buttons.filter(func(b): return b.text.begins_with("Inn"))[0]
	check(not inn_button.disabled, "la locanda si può studiare")
	inn_button.pressed.emit()
	check(main.researched.has(T.INN) and is_zero_approx(main.study), "il pulsante studia")
	main.get_node("HUD/KnowledgePanel/Box/Head/Close").pressed.emit()
	check(not main.get_node("HUD/Tools/Row/Knowledge").button_pressed, "la X chiude Knowledge e alza il tasto")
	for t in T.values():
		main.researched[t] = true
	main.refresh_unlocks()

	# lo studio e la sala del trono: due stanze 3x3 coi loro mobili
	var spots := []
	for k in free:
		var square: Array = main.cells_in(Rect2i(k, Vector2i(3, 3)))
		if square.all(func(h): return free.has(h) and not spots.any(func(s): return s.has(h))):
			spots.append(square)
		if spots.size() == 2:
			break
	check(spots.size() == 2, "c'è posto per lo studio e la sala del trono")
	var study_room = main.Room.new()
	var throne_room = main.Room.new()
	for k in spots[0]:
		study_room.cells[k] = true
	for k in spots[1]:
		throne_room.cells[k] = true
	study_room.kind = main.RoomKind.STUDY
	throne_room.kind = main.RoomKind.THRONE_ROOM
	main.rooms.append_array([study_room, throne_room])
	var desk: Vector2i = spots[0][4]
	var throne: Vector2i = spots[1][4]
	main.furniture = {desk: [B.DESK, R.WOOD, 0], throne: [B.THRONE, R.WOOD, 0]}
	check(main.room_meets(study_room, main.RoomKind.STUDY) and main.room_meets(throne_room, main.RoomKind.THRONE_ROOM), "scrittoio e trono fanno le stanze")
	var scholar = main.colonists[1]
	var other = main.colonists[2]
	check(not main.try_seat(scholar, B.THRONE, false), "sul trono solo il sovrano")
	main.open_room(throne_room)
	check(main.room_owners.get_child_count() == 1, "nella sala del trono si spunta solo il sovrano")
	main.room_popup.hide()
	study_room.workers.append(scholar)
	for c in main.colonists:
		c.pos = main.center(free[30 + main.colonists.find(c)])
		c.skills[main.Skill.RESEARCH] = 0
	scholar.skills[main.Skill.RESEARCH] = 0
	check(is_equal_approx(main.page_time(scholar, study_room), main.PAGE_TIME * 1.5 * main.comfort_time(0)), "una pagina a livello 0")
	main.study = 0.0
	main.authority = 0.0
	for i in 600:
		main.tick(0.05)
	check(main.study >= 3 and scholar.xp[main.Skill.RESEARCH] == main.study and other.xp[main.Skill.RESEARCH] == 0,
		"studia il lavoratore dello studio, una pagina un punto e un'esperienza")
	check(main.authority >= 1.0 and main.ruler.job in [main.Job.GOVERN, main.Job.NONE], "il sovrano, senza altro da fare, governa")
	# di notte senza lampada più piano, con le librerie più in fretta
	var day_time: float = main.page_time(scholar, study_room)
	main.clock = floorf(main.clock) + 22.0 / 24
	check(is_equal_approx(main.page_time(scholar, study_room), day_time * main.NIGHT_STUDY), "di notte, al buio, più piano")
	main.furniture[spots[0][0]] = [B.LAMP, R.WOOD, 0]
	check(is_equal_approx(main.page_time(scholar, study_room), day_time * main.comfort_time(main.room_comfort(study_room)) / main.comfort_time(0)),
		"con l'abat-jour no")
	main.furniture.erase(spots[0][0])
	main.clock = floorf(main.clock) + 1.0 + 10.0 / 24
	main.today = int(main.clock)
	main.furniture[spots[0][2]] = [B.BOOKSHELF, R.WOOD, 0]
	check(is_equal_approx(main.page_time(scholar, study_room), day_time * (1.0 - main.SHELF_BONUS)), "una libreria: 10% più in fretta")
	main.furniture.erase(spots[0][2])
	main.ruler.needs[main.Need.HAPPINESS] = 90.0
	check(is_equal_approx(main.govern_rate(main.ruler), 1.25), "sovrano sereno, più autorità")
	for c in main.colonists:
		main.quit_job(c)
	main.furniture.clear()
	main.rooms.erase(study_room)
	main.rooms.erase(throne_room)

	# leggi: codificare (una volta), promulgare su un sigillo, revocare
	main.authority = 30.0
	check(main.codify_block(L.LONG_SHIFTS) == "10 more authority" and not main.enact(L.LONG_SHIFTS), "senza autorità né codifica niente")
	main.authority = 200.0
	check(main.codify(L.LONG_SHIFTS) and main.enact(L.LONG_SHIFTS) and is_equal_approx(main.authority, 150.0), "codificata (40) e promulgata (10)")
	var guy = main.Colonist.new()
	guy.needs = [100.0, 100.0, 100.0, 100.0, 100.0, 0.0]
	check(main.work_hours(guy) == 10.0, "turni lunghi: 10 ore")
	guy.traits = [main.Trait.LAZY]
	check(main.work_hours(guy) == 7.0 and main.law_mood(guy) == -10.0, "il pigro 7, e non è contento")
	guy.traits = [main.Trait.WORKAHOLIC]
	check(main.work_hours(guy) == 12.0 and main.law_mood(guy) == 3.0, "lo stacanovista resta a 12, ed è contento")
	guy.traits = []
	check(main.law_mood(guy) == -5.0 and is_equal_approx(main.shift_stress(), 1.25), "gli altri -5, e più stress")
	check(main.mood_bonus(guy) == -5.0, "la legge pesa sulla felicità")
	main.codify(L.SHORT_DAY)
	check(main.rival(L.SHORT_DAY) == L.LONG_SHIFTS and main.enact(L.SHORT_DAY) and main.enacted == [L.SHORT_DAY], "giornata corta al posto dei turni lunghi")
	check(main.work_hours(guy) == 6.0 and main.enact_block(L.LONG_SHIFTS).begins_with("Revoked"), "6 ore; i turni lunghi aspettano")
	main.codify(L.CURFEW)
	check(main.enact(L.CURFEW) and main.enacted.size() == main.TITLES[0]["seals"], "due sigilli pieni")
	main.codify(L.DAY_OF_REST)
	check(main.enact_block(L.DAY_OF_REST) == "No free seal: revoke a law first", "niente sigillo libero")
	check(main.routine_of(guy)[21] == main.Act.SLEEP and main.routine_of(guy)[20] == main.Act.FREE, "coprifuoco: alle 21 a letto")
	main.revoke(L.CURFEW)
	main.revoke(L.SHORT_DAY)
	check(main.enacted.is_empty() and main.revoked[L.CURFEW] > main.clock, "revocate")
	main.clock += main.REVOKE_WAIT
	check(main.enact(L.DAY_OF_REST), "riposo festivo")
	main.clock = 6.5  # il settimo giorno
	check(main.holiday(), "il settimo giorno è festa")
	main.clock = 7.5
	check(not main.holiday(), "l'ottavo no")
	main.revoke(L.DAY_OF_REST)

	# la decima: un pezzo su dieci al granaio, anche a pezzi
	main.clock += main.REVOKE_WAIT
	main.authority = 200.0
	check(main.codify_block(L.LOOT_TAX) == "", "la gabella con la locanda")
	main.codify(L.TITHE)
	main.enact(L.TITHE)
	var field: Vector2i = free[0]
	main.produce(R.VEG, field, 10)
	check(main.items[R.VEG].get(field, 0) == 9 and main.granary[R.VEG] == 1, "10 vegetali: 9 a terra, 1 al granaio")
	main.produce(R.WOOD, free[1], 5)
	main.produce(R.WOOD, free[1], 5)
	check(main.granary[R.WOOD] == 1 and main.items[R.WOOD][free[1]] == 9, "5 e 5: uno al granaio")
	check(main.food_stored() >= 1, "le provviste contano anche il granaio")
	main.get_node("HUD/Tools/Row/Laws").button_pressed = true
	main.fill_laws()
	var law_buttons: Array = main.get_node("HUD/LawsPanel/Box/Scroll/List").find_children("*", "Button", true, false)
	check(law_buttons.size() == L.size() and law_buttons.filter(func(b): return b.text == "Revoke").size() == 1, "una riga per legge, la decima da revocare")
	check(main.get_node("HUD/LawsPanel/Box/Authority").text.contains("Granary: "), "il granaio nella finestra")
	main.get_node("HUD/LawsPanel").hide()

	# tassa di soggiorno e festa del raccolto, all'alba
	main.codify(L.LODGING_TAX)
	main.codify(L.HARVEST_FEAST)
	main.revoke(L.TITHE)
	main.clock += main.REVOKE_WAIT
	main.enact(L.LODGING_TAX)
	main.enact(L.HARVEST_FEAST)
	var guest = main.new_hero(main.Hero.ARCHER, 1)
	guest.pos = main.center(free[2])
	main.guests.append(guest)
	check(main.law_mood(guest) == -3.0, "agli avventurieri la tassa non piace")
	var gold: int = main.total(R.GOLD)
	main.clock = main.SEASON_DAYS - 0.5  # l'ultimo giorno della stagione: festa
	check(main.holiday(), "festa del raccolto")
	var power: float = main.authority
	main.clock = main.SEASON_DAYS + 0.01
	main.tick(0.0)
	check(main.total(R.GOLD) == gold + 1, "una moneta a notte per chi aspetta alla locanda")
	check(main.colonists.all(func(c): return c.conds.has(main.Cond.FESTIVE)) and main.authority >= power + main.FEAST_AUTHORITY,
		"dopo la festa: felici, e più autorità")
	main.guests.clear()

	# il titolo: sale con lo splendore, mai giù; sigilli, nome del reame, corona sullo stemma; le leggi delle fasce
	check(main.rank == 0 and main.realm_button.text.begins_with("Lordship of") and main.arms_tex.get_height() == 16, "si parte signori")
	main.authority = 1000.0
	check(main.codify_block(L.TALLAGE) == "Needs a barony", "la taglia vuole la baronia")
	var statues: Array = [free[10], free[11]]  # 8 di splendore l'una
	for k in statues:
		main.furniture[k] = [B.STATUE, R.STONE, 0]
	main.tick(0.0)
	check(main.rank == 1 and main.realm_button.text.begins_with("Barony of") and main.chronicle[-1].begins_with("Barony of"),
		"16 di splendore: baronia, nella cronaca")
	check(main.arms_tex.get_height() == 16 + main.CROWN_RISE
		and main.get_node("HUD/TopBar/Row/RealmIcon").custom_minimum_size == Vector2(32, 42), "la corona sopra lo stemma")
	main.codified.erase(L.TITHE)
	check(main.codify_block(L.TALLAGE) == "First: Tithe", "la taglia dopo la decima")
	main.codified[L.TITHE] = true
	check(main.codify(L.TALLAGE) and main.enact(L.TALLAGE) and main.enacted.size() == 3, "codificata, sul terzo sigillo")
	main.produce(R.VEG, free[3], 10)
	check(main.items[R.VEG].get(free[3], 0) == 8, "con la taglia due pezzi su dieci al granaio")
	check(main.codify_block(L.TRIBUTE) == "Needs a county", "il tributo vuole la contea")
	for k in [free[12], free[13], free[14]]:
		main.furniture[k] = [B.STATUE, R.STONE, 0]
		statues.append(k)
	main.tick(0.0)
	check(main.rank == 2 and main.codify(L.TRIBUTE), "40 di splendore: contea, e il tributo")
	main.fill_laws()
	check(main.get_node("HUD/LawsPanel/Box/Authority").text.begins_with("County of %s: a kingdom at 60" % main.realm), "la prossima soglia nella finestra")
	for k in statues:
		main.furniture.erase(k)
	main.tick(0.0)
	check(main.rank == 2, "il titolo non cala")

	# eventi d'autorità: mai sotto zero; tesoro +5; all'alba -1 per scontento; colono morto -5
	main.gain(-1000.0)
	check(main.authority == 0.0, "l'autorità non va sotto zero")
	var trip = main.Expedition.new()
	trip.party.append(main.new_hero(main.Hero.ARCHER, 1))
	trip.ruin = main.ruins[0]
	trip.left_at = 0.0
	trip.back_at = main.clock
	trip.edge = Vector2i(0, main.MAP_SIZE.y / 2)
	trip.treasure = true
	main.expeditions.append(trip)
	main.update_expeditions()
	check(main.authority == main.TREASURE_AUTHORITY and trip.lines[-1].contains("+5 authority"), "il tesoro: +5, nel diario")
	main.guests.clear()
	main.get_node("HUD/ReportPanel").hide()
	main.authority = 10.0
	main.colonists[1].needs[main.Need.HAPPINESS] = 10.0
	main.today = 3  # a metà stagione: niente feste
	main.new_day()
	check(main.authority == 9.0, "uno scontento: -1 all'alba")

	# granaio aperto: dopo la decima e in baronia; senza cibo in magazzino il granaio ne manda, a stagione un pasto a tutti
	main.authority = 500.0
	check(main.codify(L.OPEN_GRANARY), "granaio aperto codificato")
	main.revoke(L.TRIBUTE)
	main.enacted.clear()
	check(main.enact(L.OPEN_GRANARY), "e promulgato")
	for res in main.MEALS + main.RAW_FOOD:
		for cell in main.items[res].keys():
			main.items[res].erase(cell)
	main.granary = {R.MEAL: 2, R.VEG: 10}
	main.stockpile = {free[20]: true, free[21]: true, free[22]: true}  # caselle che nessuno ha prenotato
	main.new_hour()
	check(main.stored(R.MEAL) == 2 and main.stored(R.VEG) == 1 and main.granary[R.MEAL] == 0 and main.granary[R.VEG] == 9,
		"magazzino vuoto: un pezzo a colono dal granaio, prima i pasti")
	main.new_hour()
	check(main.granary[R.VEG] == 9, "c'è cibo in magazzino: il granaio resta chiuso")
	for c in main.colonists:
		c.needs[main.Need.FOOD] = 20.0
	main.today = main.SEASON_DAYS
	main.new_day()
	var fed: Array = main.colonists.filter(func(c): return c.needs[main.Need.FOOD] == main.NEED_MAX and c.conds.has(main.Cond.WELL_FED))
	check(main.granary[R.VEG] == 6 and fed.size() == 3, "stagione nuova: un pasto a tutti dal granaio")

	# libri nelle rovine: nei forzieri a volte, nel tesoro sempre; nel monastero sempre
	var burglar = main.new_hero(main.Hero.BURGLAR, 5)
	burglar.gifts = [main.Gift.LOYAL]
	var books := 0
	for i in 400:
		var e = main.Expedition.new()
		e.party.append(burglar)
		main.open_chest(e, main.RUINS[main.RuinKind.TOWER], false)
		books += e.loot.get(R.NOTEBOOK, 0)
		check(not e.loot.has(R.TOME) and not e.loot.has(R.CODEX), "nella torre solo quaderni")
	check(books > 100 and books < 180, "un forziere su tre circa ha un quaderno (%d su 400)" % books)
	var treasure = main.Expedition.new()
	treasure.party.append(burglar)
	treasure.ruin = main.ruins[0]
	main.open_chest(treasure, main.RUINS[main.RuinKind.FORT], true)
	check(treasure.loot.get(R.CODEX, 0) >= 1, "nel tesoro del forte un codice di porpora")
	var monk = main.Expedition.new()
	monk.party.append(burglar)
	main.open_chest(monk, main.RUINS[main.RuinKind.MONASTERY], false)
	check(main.BOOKS.any(func(b): return monk.loot.has(b)), "nel monastero un libro sempre")
	burglar.gifts = [main.Gift.SCHOLAR]
	books = 0
	for i in 400:
		var e = main.Expedition.new()
		e.party.append(burglar)
		main.open_chest(e, main.RUINS[main.RuinKind.TOWER], false)
		books += e.loot.get(R.NOTEBOOK, 0)
	check(books > 230, "con lo studioso il doppio (%d su 400)" % books)

	main.authority = 10.0
	main.die(main.colonists[2], "fell")
	check(main.authority == 5.0, "un colono morto: -5 autorità")

	# dispensa fredda: una stanza che è magazzino solo per il cibo, che ci marcisce a un terzo; il cibo ci va per primo
	var den = main.Room.new()
	den.cells = {free[23]: true, free[24]: true}
	den.kind = main.RoomKind.PANTRY
	main.rooms.append(den)
	main.update_stockpile()
	main.stockpile[free[25]] = true  # e un magazzino qualunque
	check(main.stockpile.has(free[23]) and main.spoil_rate(free[23]) == main.SPOIL_PANTRY and main.spoil_rate(free[25]) == main.SPOIL_STORED,
		"la dispensa: il cibo dura il triplo")
	check(free[23] not in main.dest_cells(R.WOOD) and free[23] in main.dest_cells(R.VEG), "in dispensa solo quello che marcisce")
	main.researched.erase(T.COLD_STORE)
	check(not main.room_meets(den, main.RoomKind.PANTRY), "senza la ricerca niente dispensa")
	main.researched[T.COLD_STORE] = true
	var porter = main.colonists[0]
	main.quit_job(porter)
	main.add_item(R.VEG, free[26], 5)
	check(main.try_haul(porter, R.VEG, [free[26]]) and main.pantry.has(porter.dest), "il cibo si porta in dispensa")
	main.quit_job(porter)

	# strada lastricata: la si preferisce e ci si va un quarto più svelti
	var road: Vector2i = free[27]
	main.blueprints[road] = [B.ROAD, R.STONE]
	main.build(road)
	check(is_equal_approx(main.astar.get_point_weight_scale(road), 0.8), "la strada si preferisce")
	var walker = main.colonists[1]
	walker.job = main.Job.NONE
	walker.pos = main.center(road)
	walker.path.assign([road + Vector2i.RIGHT])
	main.update_colonist(walker, 0.1)
	check(is_equal_approx(walker.pos.distance_to(main.center(road)), main.SPEED * main.TILE * 0.1 * main.ROAD_SPEED), "sulla strada più svelti")

	# provviste secche: la galletta vale due provviste, parte dopo il granaio e prima dei pasti
	main.granary = {R.VEG: 1}
	for res in main.MEALS + main.RAW_FOOD:
		for cell in main.items[res].keys():
			main.items[res].erase(cell)
	main.add_item(R.HARDTACK, free[25], 3)
	main.add_item(R.MEAL, free[23], 4)
	check(main.food_stored() == 1 + 6 + 4, "nelle provviste la galletta conta due")
	var hiker = main.new_hero(main.Hero.ARCHER, 1)
	main.guests.append(hiker)
	main.add_item(R.GOLD, free[28], main.fee(hiker))
	main.stockpile[free[28]] = true
	var walk_to = main.Ruin.new()
	main.ruins.append(walk_to)
	check(main.provisions([hiker], walk_to) == 3 and main.send([hiker], walk_to), "partito per la torre: 3 provviste (2,25 giorni)")
	check(main.expeditions[-1].food == 3.0 and main.granary[R.VEG] == 0 and main.stored(R.HARDTACK) == 2 and main.stored(R.MEAL) == 4,
		"il granaio e una galletta: niente pasti")
	main.expeditions.clear()
	main.guests.clear()
	main.ruins.erase(walk_to)

	# cartografia: la prossima stanza di una rovina, sulla bacheca; l'esplorazione trova quella
	var crypt = main.Ruin.new()
	main.ruins.append(crypt)
	var ahead: int = main.next_chamber(crypt)
	check(main.next_chamber(crypt) == ahead, "la prossima stanza resta quella")
	main.board_key = ""
	main.fill_board()
	var rows: Array = main.get_node("HUD/BoardPanel/Box/Ruins").find_children("*", "Label", true, false).map(func(l): return l.text)
	check(rows.any(func(t): return t.contains("next: " + main.CHAMBER_NAMES[ahead])), "sulla bacheca la prossima stanza")
	crypt.next = main.Chamber.COLLAPSE
	var dig = main.Expedition.new()
	dig.party.append(main.new_hero(main.Hero.WARRIOR, 5))
	dig.ruin = crypt
	dig.left_at = main.clock
	dig.food = 10.0
	main.explore(dig, 0.5)
	check(dig.lines[1].contains("collapse") and crypt.next == -1, "l'esplorazione trova la stanza vista, poi se ne pesca un'altra")
	main.ruins.erase(crypt)

	# fantoccio: nel tempo libero ci si allena, +1 esperienza in mischia a colpo
	var open := func(k: Vector2i) -> bool: return main.can_build(k)
	var post: Vector2i = free.filter(func(k): return main.SIDES.all(func(d): return open.call(k + d)) and open.call(k))[5]
	main.furniture[post] = [B.DUMMY, R.WOOD, 0]
	var trainee = main.colonists[1]
	main.quit_job(trainee)
	trainee.pos = main.center(post + Vector2i.LEFT)
	main.relax(trainee)
	check(trainee.job == main.Job.RELAX and trainee.target == post and trainee.work_total > 0, "svago al fantoccio, prenotato")
	var melee: int = trainee.xp[main.Skill.MELEE]
	for i in 30:
		main.update_colonist(trainee, 0.1)
	check(trainee.xp[main.Skill.MELEE] == melee + 1 and main.is_working(trainee), "tre secondi: un colpo, +1 esperienza")
	main.quit_job(trainee)

	# milizia: la prima ora libera del giorno al fantoccio, e si scappa solo sotto 30
	main.enacted.clear()
	main.authority = 1000.0
	check(main.codify(L.MILITIA) and main.enact(L.MILITIA), "milizia promulgata")
	main.furniture[free[31]] = [B.CAMPFIRE, R.WOOD, 0]
	trainee.pos = main.center(free[31] + Vector2i.DOWN)  # accanto al fuoco: senza milizia starebbe lì
	main.relax(trainee)
	check(trainee.target == post and trainee.drilled == main.today, "con la milizia al fantoccio, anche col fuoco vicino")
	main.quit_job(trainee)
	main.relax(trainee)
	check(trainee.target != post, "l'ora del giorno è fatta: poi svago dove capita")
	main.quit_job(trainee)
	main.furniture.erase(free[31])
	check(main.flee_hp() == main.MILITIA_FLEE, "con la milizia si scappa solo sotto 30")
	main.revoke(L.MILITIA)
	check(main.flee_hp() == main.FLEE_HP, "senza, sotto 40")

	# turno di guardia: veglia un colono (prima i nottambuli) che dorme di giorno; di notte i lupi si vedono da lontano
	for c in main.colonists:
		c.traits = []
	check(main.codify(L.NIGHT_WATCH) and main.enact(L.NIGHT_WATCH), "turno di guardia promulgato")
	var guard = main.watchman()
	check(guard != null and guard != main.ruler and main.routine_of(guard)[12] == main.Act.SLEEP
		and main.routine_of(main.ruler)[12] != main.Act.SLEEP, "la guardia dorme di giorno, il sovrano no")
	main.ruler.traits = [main.Trait.NIGHT_OWL]
	check(main.watchman() == main.ruler, "prima i nottambuli")
	main.ruler.traits = []
	var far = main.add_animal(main.Beast.WOLF, main.cell_of(guard.pos) + Vector2i(30, 0) if main.roams(main.cell_of(guard.pos) + Vector2i(30, 0)) else main.cell_of(guard.pos) + Vector2i(-30, 0))
	far.blocked = 0.0
	main.clock = float(main.today) + 12.0 / 24
	check(not main.on_watch() and main.nearest_foe(main.ruler) == null, "di giorno nessuna guardia: il lupo lontano non si vede")
	main.clock = float(main.today) + 23.0 / 24
	main.quit_job(guard)
	check(main.on_watch() and main.nearest_foe(main.ruler) == far, "di notte, con la guardia sveglia, sì")
	main.animals.erase(far)
	main.revoke(L.NIGHT_WATCH)

	# palizzata e cancello: solidi i pali, il cancello si passa ma non dai lupi; un recinto non è una stanza.
	# Il pedaggio: chi arriva paga al cancello
	var yard := Vector2i.ZERO
	for k in free:
		if main.cells_in(Rect2i(k, Vector2i(5, 5))).all(func(h): return free.has(h) and main.can_build(h)):
			yard = k
			break
	check(yard != Vector2i.ZERO, "c'è posto per un recinto")
	var gate_cell: Vector2i = yard + Vector2i(2, 0)
	var door_cell: Vector2i = yard + Vector2i(2, 4)
	for k in main.cells_in(Rect2i(yard, Vector2i(5, 5))):
		if k.x in [yard.x, yard.x + 4] or k.y in [yard.y, yard.y + 4]:
			main.blueprints[k] = [B.GATE if k == gate_cell else (B.DOOR if k == door_cell else B.PALISADE), R.WOOD]
			main.build(k)
	main.update_rooms()
	check(main.astar.is_point_solid(yard) and not main.astar.is_point_solid(gate_cell), "pali solidi, cancello aperto")
	check(main.room_at(yard + Vector2i(2, 2)) == null, "il recinto con una porta non è una stanza")
	var outside: Vector2i = gate_cell + Vector2i.UP
	check(main.beast_path(outside, yard + Vector2i(2, 2)).is_empty() and not main.astar.get_id_path(outside, yard + Vector2i(2, 2)).is_empty(),
		"i lupi non entrano dal cancello, i coloni sì")
	check(main.codify(L.TOLL) and main.enact(L.TOLL), "pedaggio promulgato")
	var visitor = main.new_hero(main.Hero.ARCHER, 1)
	visitor.pos = main.center(outside + Vector2i(0, -10))
	main.pay_toll(visitor)
	check(main.items[R.GOLD].get(gate_cell, 0) == main.TOLL, "due monete al cancello")

	# una partita vera: niente studiato, lupi dal quinto giorno, un'arma abbandonata sulla mappa
	main.queue_free()
	var real = load("res://main.tscn").instantiate()
	root.add_child(real)
	await process_frame
	check(real.researched.is_empty() and not real.furniture_bar.get_node("Row/Furnace").visible, "si parte senza ricerche")
	check(is_equal_approx(real.next_pack, 4.0), "il primo branco il quinto giorno")
	var found := []
	for res in real.FOUND_WEAPONS:
		for cell in real.items[res]:
			found.append(Vector2(cell - real.MAP_SIZE / 2).length())
	check(found.size() == 1 and found[0] >= 15 and found[0] <= 25, "un'arma, tra 15 e 25 caselle dalla radura")

	print("OK: ricerca, studio, governo, leggi e libri")
	quit()


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
