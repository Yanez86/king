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

	print("OK: nuovi coloni (l'avventuriero che resta)")
	quit()


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
