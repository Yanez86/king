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
	var buttons: Array = main.get_node("HUD/KnowledgePanel/Box/Tree").find_children("*", "Button", true, false)
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
	check(main.enact(L.CURFEW) and main.enacted.size() == main.SEALS, "due sigilli pieni")
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
	var law_buttons: Array = main.get_node("HUD/LawsPanel/Box/List").find_children("*", "Button", true, false)
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
