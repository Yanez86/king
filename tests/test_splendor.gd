# Esegui: godot --headless --path . -s tests/test_splendor.gd
# Lo splendore che costa (GDD 4.4.3): la manutenzione in oro a ogni festa di fine stagione (15 punti gratis, poi mezza
# moneta a punto, prima le decorazioni più preziose), le trascurate (metà) e le diroccate (niente), la riparazione col
# materiale, i cimeli che non costano, il suggerimento in alto, il salvataggio. Dove conta: vedi test_jobs
extends SceneTree

var main


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(4)
	main = load("res://main.tscn").instantiate()
	main.game_start = false
	main.settings_file = ""
	root.add_child(main)
	await process_frame
	main.events = false
	main.needs_rate = 0.0
	main.routines = false
	main.animals.clear()
	var R = main.Res
	var B = main.Build
	var D = main.Decay
	var mid: Vector2i = main.MAP_SIZE / 2
	var free: Array = main.cells_in(Rect2i(mid - Vector2i(10, 10), Vector2i(21, 21))).filter(func(k): return main.can_build(k))
	main.sort_by_distance(free, main.center(mid))
	# tre statue (8 l'una) su un sentiero, nella colonia; le monete in un magazzino di una casella
	var plaza := []
	var used := {}
	for k in free:
		var square: Array = [k, k + Vector2i.RIGHT, k + Vector2i.DOWN, k + Vector2i.ONE]
		var ring: Array = main.cells_in(Rect2i(k - Vector2i.ONE, Vector2i(4, 4)))
		if plaza.size() < 3 and square.all(func(o): return o in free) and ring.all(func(o): return not used.has(o)):
			plaza.append(k)
			for o in ring:
				used[o] = true
	var spare: Array = free.filter(func(k): return not used.has(k))
	var vault: Vector2i = spare[0]
	main.stockpile = {vault: true}
	check(main.upkeep_due() == 0 and main.colony_splendor() == 0, "senza decorazioni niente da pagare")
	for k in plaza:
		main.furniture[k] = [B.STATUE, R.STONE, 0]
		main.built[k] = [B.PATH, R.STONE]
	# 24 di splendore: i primi 15 gratis (la prima statua e 7 punti della seconda), poi mezza moneta a punto: 0,5 + 4 -> 5
	check(main.colony_splendor() == 24 and main.upkeep_due() == 5, "24 di splendore: 5 monete (%d)" % main.upkeep_due())
	main.items[R.GOLD][vault] = 5
	main.pay_upkeep()
	check(main.stored(R.GOLD) == 0 and main.decor_state.is_empty() and main.chronicle[-1].ends_with("the upkeep of the decorations, 5 coins."),
		"pagata: 5 monete, nella cronaca")
	# monete che non bastano: si pagano prima le più preziose, l'ultima resta senza e si trascura (metà)
	main.items[R.GOLD][vault] = 1
	main.pay_upkeep()
	check(main.decor_state == {plaza[2]: D.NEGLECTED} and main.colony_splendor() == 20 and main.stored(R.GOLD) == 0,
		"una moneta: le prime due pagate, la terza trascurata (%d)" % main.colony_splendor())
	check(main.chronicle[-1].ends_with("Not enough coins: 1 neglected, 0 fell into ruin.")
		and main.decor_about(plaza[2]).begins_with("Neglected"), "nella cronaca e sul riquadro")
	# ancora senza: si dirocca, non dà niente e non si paga più
	main.items[R.GOLD][vault] = 1
	main.pay_upkeep()
	check(main.decor_state == {plaza[2]: D.RUINED} and main.colony_splendor() == 16 and main.upkeep_due() == 1
		and main.decor_about(plaza[2]) == "Ruined: no splendor, until a builder repairs it (1 stone)", "diroccata: niente")
	# un costruttore la ripara con 1 pietra: torna trascurata
	var c = main.colonists[0]
	c.pos = main.center(spare[1])
	main.add_item(R.STONE, spare[2], 5)
	var stone: int = main.total(R.STONE)
	check(main.try_repair(c) and c.job == main.Job.REPAIR and c.mending and main.doing(c) == "Repairing a decoration",
		"un costruttore va a ripararla")
	for i in 4000:
		if main.decor_state.get(plaza[2]) != D.RUINED:
			break
		main.tick(0.05)
	check(main.decor_state.get(plaza[2]) == D.NEGLECTED and main.total(R.STONE) == stone - 1, "riparata con una pietra: trascurata")
	# un cimelio dà splendore ma non costa e non si rovina
	var relic: Vector2i = spare[6]
	main.furniture[relic] = [B.CROWN, R.CROWN, 0]
	main.built[relic] = [B.PATH, R.STONE]
	var due: int = main.upkeep_due()
	check(main.colony_splendor() == 20 + main.SPLENDOR[B.CROWN] and main.upkeep_due() == due, "il cimelio: splendore, niente manutenzione")
	# alla festa di fine stagione si paga da sé: pagata, la trascurata torna a posto; il Capodanno no
	main.today = 90
	check(main.next_feast() == 91, "la prossima festa: la Festa dei Fiori")
	main.today = 364
	check(main.next_feast() == 365 + 91, "dopo la Festa delle Candele, il Capodanno non conta: la Festa dei Fiori dopo")
	main.today = 89
	main.clock = 89.5
	main.tick(0.0)
	main.items[R.GOLD][vault] = 20
	var paid: int = main.upkeep_due()
	main.clock = 91.0
	main.tick(0.0)
	check(main.decor_state.is_empty() and main.stored(R.GOLD) == 20 - paid and main.colony_splendor() == 24 + main.SPLENDOR[B.CROWN],
		"alla festa pagata: tutto a posto")
	# in alto, col mouse sopra lo splendore: la manutenzione della prossima festa
	var tip: String = main.splendor_tip()
	check(tip.begins_with("Colony splendor: 30") and tip.contains("Upkeep at") and tip.contains("Neglected: 0, ruined: 0"), "il suggerimento: %s" % tip)
	# nel salvataggio
	main.decor_state[plaza[0]] = D.NEGLECTED
	check(main.game_state()["main"]["decor_state"] == {plaza[0]: D.NEGLECTED}, "lo stato delle decorazioni si salva")
	# abbattuta, il suo stato se ne va
	main.furniture.erase(plaza[0])
	main.colony_splendor()
	check(main.decor_state.is_empty(), "abbattuta: niente stato")

	print("OK: lo splendore che costa (la manutenzione, trascurate e diroccate, la riparazione)")
	quit()


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
