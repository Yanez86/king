# Esegui: godot --headless --path . -s tests/test_food.gd
# Cibo: freschezza e marcio, intossicazione, cucina, pasti e loro bonus
extends SceneTree


func _initialize() -> void:
	seed(1)
	var main = load("res://main.tscn").instantiate()
	main.start_rooms = false
	root.add_child(main)
	await process_frame
	main.needs_rate = 0.0  # bisogni fermi: nessuno va a mangiare finché non lo decide la prova
	main.bushes.clear()
	main.weeds.clear()
	var V: int = main.Res.VEG
	var MEAL: int = main.Res.MEAL
	var FINE: int = main.Res.FINE_MEAL
	var area := Rect2i(main.MAP_SIZE / 2 - Vector2i(8, 8), Vector2i(16, 16))
	var free: Array = main.cells_in(area).filter(func(k): return main.can_build(k))
	main.sort_by_distance(free, main.center(main.MAP_SIZE / 2))
	check(free.size() > 40, "c'è posto vicino alla partenza")
	for c in main.colonists:  # niente lavori: restano fermi
		c.pos = main.center(free[-1 - main.colonists.find(c)])

	# freschezza: a terra fuori marcisce in SHELF_LIFE giorni, in magazzino nel doppio; i mucchi si mescolano
	var out: Vector2i = free[0]
	var inside: Vector2i = free[1]
	main.stockpile = {inside: true}
	main.add_item(V, out, 4)
	main.add_item(V, inside, 4)
	check(main.fresh[out] == main.SHELF_LIFE[V], "appena raccolto: fresco")
	main.spoil(1.0)
	check(is_equal_approx(main.fresh[out], main.SHELF_LIFE[V] - 1.0) and is_equal_approx(main.fresh[inside], main.SHELF_LIFE[V] - 0.5),
		"fuori un giorno, in magazzino mezzo")
	main.add_item(V, out, 4)  # 4 vecchi di un giorno e 4 freschi: la media
	check(is_equal_approx(main.fresh[out], main.SHELF_LIFE[V] - 0.5), "mescolando, la media pesata")
	check(main.describe(out)[1] == "8 / 50\nFresh, rots in 2.5 days", "il suggerimento dice quanto è fresco")
	check(main.describe(inside)[1] == "4 / 50\nFresh, rots in 5.0 days", "in magazzino ci mette il doppio")
	main.spoil(2.0)
	check(main.describe(out)[1].contains("Almost rotten"), "quasi marcio")
	main.spoil(0.6)
	check(not main.items[V].has(out) and not main.fresh.has(out) and main.items[V].has(inside), "marcito: il mucchio sparisce")
	main.add_item(main.Res.WOOD, out, 5)
	check(not main.fresh.has(out), "la legna non marcisce")
	main.add_item(main.Res.WOOD, out, -5)
	main.add_item(V, inside, -4)
	check(not main.fresh.has(inside), "mucchio finito: niente freschezza rimasta")

	# trasportato in magazzino, il cibo tiene la sua età
	var porter = main.colonists[0]
	main.add_item(V, out, 3, 1.0)
	main.stockpile = {inside: true}
	main.needs_rate = 0.0
	check(main.try_haul(porter, V, [out]), "si porta in magazzino")
	for i in 400:
		main.tick(0.05)
	check(main.items[V].get(inside, 0) == 3 and main.fresh[inside] < 1.0 and main.fresh[inside] > 0.9, "in magazzino col suo invecchiamento")
	main.add_item(V, inside, -3)
	# chi va a prendere un mucchio che marcisce intanto lascia perdere
	main.add_item(V, out, 3, 0.5)
	main.stockpile = {free[2]: true}
	porter.pos = main.center(free[-1])
	check(main.try_haul(porter, V, [out]), "va a prendere un mucchio quasi marcio")
	main.tick(0.05)
	main.spoil(0.5)  # marcisce mentre lui è per strada
	for i in 400:
		main.tick(0.05)
	check(porter.job == main.Job.NONE and porter.carrying == 0 and not main.items[V].has(out) and main.reserved.is_empty(),
		"marcito prima che arrivi: niente in mano, nessuna prenotazione")
	main.stockpile = {}

	# mangiare: il crudo sazia meno e può intossicare, di più se vecchio
	check(is_equal_approx(main.poison_chance(main.SHELF_LIFE[V]), main.POISON_FRESH) and is_equal_approx(main.poison_chance(0.0), main.POISON_STALE),
		"intossicarsi: 5% fresco, 40% quasi marcio")
	var eater = main.Colonist.new()
	eater.needs = [0.0, 100.0, 50.0, 50.0, 50.0]
	eater.skills = main.Skill.values().map(func(_s): return 5)
	var poisoned := 0
	for i in 1000:
		eater.conds.clear()
		eater.carry_res = V
		eater.carrying = 1
		eater.carry_days = 0.0
		main.eat(eater)
		poisoned += int(eater.conds.has(main.Cond.POISONED))
	check(poisoned > 340 and poisoned < 460, "quasi marcio: si intossica circa 4 volte su 10 (%d su 1000)" % poisoned)
	check(eater.needs[main.Need.FOOD] == main.NEED_MAX and not eater.conds.has(main.Cond.ATE_RAW), "chi non è goloso non si lamenta")
	eater.conds = {main.Cond.POISONED: main.clock + 1.0}
	check(is_equal_approx(main.work_factor(eater), 1.5), "intossicato: lavora il 50% più lentamente")
	check(is_equal_approx(main.gather_time(eater, main.Job.CHOP), main.GATHER[main.Job.CHOP][1] * 1.5), "anche a tagliare")
	eater.needs[main.Need.FOOD] = 0.0
	eater.carry_res = MEAL
	eater.carrying = 1
	main.eat(eater)
	check(eater.needs[main.Need.FOOD] == main.FOOD[MEAL] and eater.conds.has(main.Cond.WELL_FED), "pasto: sazia di più, ben nutrito")
	eater.conds.erase(main.Cond.POISONED)
	check(is_equal_approx(main.work_factor(eater), 0.9) and main.mood_bonus(eater) == 5.0, "ben nutrito: 10% più veloce, più felice")
	eater.carry_res = FINE
	eater.carrying = 1
	main.eat(eater)
	check(eater.conds.keys() == [main.Cond.FEASTED] and is_equal_approx(main.work_factor(eater), 0.8), "squisito: prende il posto del ben nutrito")
	eater.traits = [main.Trait.GLUTTON]
	check(main.mood_bonus(eater) == 20.0, "il goloso se lo gode il doppio")
	eater.carry_res = V
	eater.carrying = 1
	eater.carry_days = main.SHELF_LIFE[V]
	main.eat(eater)
	check(eater.conds.has(main.Cond.ATE_RAW), "il goloso col crudo si lamenta")
	# lo stress da lavoro e la felicità seguono le condizioni; finite, spariscono
	var worker = main.Colonist.new()
	worker.needs = [100.0, 100.0, 100.0, 100.0, 0.0]
	worker.job = main.Job.HAUL
	main.needs_rate = 1.0
	main.update_needs(worker, 10.0)
	var plain_stress: float = worker.needs[main.Need.STRESS]
	worker.needs[main.Need.STRESS] = 0.0
	main.add_cond(worker, main.Cond.FEASTED)
	main.update_needs(worker, 10.0)
	check(is_equal_approx(worker.needs[main.Need.STRESS], plain_stress / 2), "pasto squisito: metà stress lavorando")
	main.clock += main.COND_INFO[main.Cond.FEASTED][0]
	main.update_needs(worker, 0.0)
	check(worker.conds.is_empty(), "finito il tempo, la condizione sparisce")
	main.needs_rate = 0.0

	# cucina: stanza di prova fatta di dati, col fuoco da campo; magazzino lontano; vegetali a terra
	var kitchen = main.Room.new()
	var fire: Vector2i = Vector2i.ZERO
	for k in free:  # un 3x3 libero: fuoco in mezzo
		if main.cells_in(Rect2i(k - Vector2i.ONE, Vector2i(3, 3))).all(func(h): return free.has(h)):
			fire = k
			break
	check(fire != Vector2i.ZERO, "c'è posto per la cucina")
	for k in main.cells_in(Rect2i(fire - Vector2i.ONE, Vector2i(3, 3))):
		kitchen.cells[k] = true
	main.rooms.append(kitchen)
	main.furniture = {fire: [main.Build.CAMPFIRE, main.Res.WOOD, 0]}
	var store: Array = free.filter(func(k): return not kitchen.cells.has(k)).slice(-12, -6)  # lontano da dove stanno i coloni
	var pile: Vector2i = free.filter(func(k): return not kitchen.cells.has(k) and not store.has(k))[0]
	main.add_item(V, pile, 20)
	check(main.total(V) == 20, "solo i vegetali per cucinare")
	check(main.kitchen_fires().is_empty() and not main.try_cook(main.colonists[0]), "senza una cucina non si cucina")
	main.open_room(kitchen)
	check(range(main.room_kind.item_count).map(main.room_kind.get_item_id).has(main.RoomKind.KITCHEN), "col fuoco si può fare una cucina")
	main.room_kind.item_selected.emit(main.room_kind.get_item_index(main.RoomKind.KITCHEN))
	main.stockpile = {}  # dopo: il tipo scelto ricalcola i magazzini dalle stanze
	for k in store:
		main.stockpile[k] = true
	check(kitchen.kind == main.RoomKind.KITCHEN and main.kitchen_fires() == [fire], "il fuoco di una cucina")
	check(main.meals_wanted() == main.MEALS_PER_COLONIST * 3 and main.job_list().contains("Cook meals: 6"), "finestra Jobs: pasti da cucinare")
	for c in main.colonists:
		c.skills[main.Skill.COOKING] = main.SKILL_MAX  # niente pasti bruciati
	var comfort: int = main.room_comfort(kitchen)
	check(comfort == 0 and main.burn_chance(main.SKILL_MAX, comfort) == 0.0, "a livello 10 non si brucia niente")
	check(is_equal_approx(main.burn_chance(1, 5), 0.3) and main.burn_chance(6, 5) == 0.0 and is_equal_approx(main.burn_chance(6, 0), 0.15),
		"bruciato: 30% a livello 1, niente dal 6, di più in una cucina scomoda")
	check(is_equal_approx(main.fine_chance(10, 5), 0.25) and main.fine_chance(5, 5) == 0.0, "squisito: fino al 25% a livello 10")
	check(is_equal_approx(main.cook_time(main.colonists[0], 0), main.COOK_TIME * 0.5 * 1.2), "cucina scomoda: 20% di tempo in più")
	var cooks := {}
	for i in 6000:  # 300 secondi
		main.tick(0.05)
		check_cook(main, fire)
		for c in main.colonists:
			if c.job == main.Job.COOK:
				cooks[c] = true
	var meals: int = main.total(MEAL) + main.total(FINE)
	var xp: int = main.colonists.reduce(func(sum, c): return sum + c.xp[main.Skill.COOKING], 0)
	check(meals == 6 and main.meals_wanted() == 0, "cucinati i pasti che mancavano, non di più")
	check(xp == 6 and main.total(V) == 20 - 6 * main.COOK_VEG, "2 vegetali e 1 punto esperienza per pasto")
	check(main.stored(MEAL) + main.stored(FINE) == 6, "i pasti finiscono in magazzino")
	check(main.total(FINE) > 0, "a livello 10 qualcuno viene squisito")
	check(main.colonists.all(func(c): return c.job == main.Job.NONE) and main.reserved.is_empty(), "poi tutti liberi")

	# chi ha fame prende un pasto prima del crudo, e lo mangia seduto al tavolo vicino
	var table: Vector2i = Vector2i.ZERO
	for k in free:
		var spot: Array = main.cells_in(Rect2i(k, Vector2i(3, 2)))
		if spot.all(func(h): return main.can_build(h, main.Build.TABLE) and not kitchen.cells.has(h) and not main.stockpile.has(h)):
			table = k
			break
	check(table != Vector2i.ZERO, "c'è posto per tavolo e sedia")
	main.furniture[table] = [main.Build.TABLE, main.Res.WOOD, 0]
	var chair: Vector2i = table + Vector2i(2, 0)
	main.furniture[chair] = [main.Build.CHAIR, main.Res.WOOD, 0]
	check(main.seats() == [chair], "la sedia accanto al tavolo è un posto a tavola")
	var hungry = main.colonists[1]
	hungry.needs[main.Need.FOOD] = main.NEED_LOW - 1
	hungry.traits = []
	hungry.conds.clear()
	var before: int = main.total(MEAL) + main.total(FINE)
	main.needs_rate = 0.0
	for i in 2000:
		main.tick(0.05)
		if hungry.needs[main.Need.FOOD] > main.NEED_LOW:
			break
	check(main.total(MEAL) + main.total(FINE) == before - 1 and main.total(V) == 20 - 6 * main.COOK_VEG, "un pasto, non il crudo")
	check(main.cell_of(hungry.pos) == chair and hungry.conds.has(main.Cond.AT_TABLE), "mangiato seduto al tavolo")
	check(hungry.conds.has(main.Cond.WELL_FED) or hungry.conds.has(main.Cond.FEASTED), "ben nutrito")
	# il goloso va a mangiare prima
	var glutton = main.colonists[2]
	glutton.traits = [main.Trait.GLUTTON]
	glutton.needs[main.Need.FOOD] = main.GLUTTON_HUNGER - 1
	var went := false
	for i in 400:
		main.tick(0.05)
		went = went or glutton.job == main.Job.EAT
	check(went and glutton.needs[main.Need.FOOD] > main.GLUTTON_HUNGER, "il goloso ha fame prima: va a mangiare sopra NEED_LOW")

	# scheda: le condizioni come icone, col nome e quanto manca nel suggerimento
	main.open_sheet(hungry)
	main._process(0.0)
	var icons: Array = main.get_node("HUD/ColonistSheet/Box/Conditions/Icons").get_children()
	check(icons.size() == hungry.conds.size() and icons.any(func(i): return i.tooltip_text.begins_with("At Table\n")), "condizioni nella scheda")
	main.open_sheet(glutton)
	glutton.conds.clear()
	main._process(0.0)
	check(not main.get_node("HUD/ColonistSheet/Box/Conditions").visible, "senza condizioni la sezione non c'è")
	main.add_cond(glutton, main.Cond.POISONED)
	main._process(0.0)
	icons = main.get_node("HUD/ColonistSheet/Box/Conditions/Icons").get_children()
	check(icons.size() == 1 and icons[0].tooltip_text.ends_with("24 h left"), "appena intossicato: un giorno")
	check(main.Res.values().all(func(r): return main.ICONS.has(r) and main.STACK_MAX.has(r) and main.items.has(r)), "ogni risorsa ha icona e mucchio")

	# Harvest: i cespugli segnati si raccolgono ogni volta che maturano, e le bacche vanno in magazzino
	for c in main.colonists:
		c.traits = []
		c.conds.clear()
		c.needs[main.Need.FOOD] = 100.0
		main.quit_job(c)
	main.rooms.erase(kitchen)  # niente più cucina: nessuno trasforma le bacche
	var bush: Vector2i = free.filter(func(k): return main.can_build(k) and not main.stockpile.has(k))[0]
	main.bushes[bush] = main.clock
	var veg0: int = main.total(V)
	for i in 200:
		main.tick(0.05)
	check(main.total(V) == veg0, "senza segno le bacche restano sul cespuglio")
	main.get_node("HUD/Tools/Row/Harvest").button_pressed = true
	check(main.order == main.Order.HARVEST, "tasto Harvest")
	main.mark(Rect2i(bush, Vector2i.ONE))
	check(main.harvest_marks.has(bush) and main.describe(bush)[1].ends_with("Marked: harvest"), "cespuglio segnato")
	check(main.job_list().contains("Harvest bushes: 1"), "finestra Jobs: cespugli da raccogliere")
	for i in 4000:
		main.tick(0.05)
	check(main.total(V) == veg0 + main.BERRIES_PER_BUSH and main.stored(V) >= main.BERRIES_PER_BUSH, "raccolte e portate in magazzino")
	check(main.harvest_marks.has(bush) and main.ripe_bushes().is_empty(), "il segno resta, le bacche ricrescono")
	main.clock = main.bushes[bush]
	for i in 4000:
		main.tick(0.05)
	check(main.total(V) == veg0 + 2 * main.BERRIES_PER_BUSH, "maturate di nuovo, raccolte di nuovo")
	main.order = main.Order.UPROOT
	main.mark(Rect2i(bush, Vector2i.ONE))
	check(main.uproot_marks.has(bush) and not main.harvest_marks.has(bush), "da estirpare: non si raccoglie più")
	main.order = main.Order.HARVEST
	main.mark(Rect2i(bush, Vector2i.ONE))
	check(main.harvest_marks.has(bush) and not main.uproot_marks.has(bush), "si cambia idea")

	print("OK: %d pasti cucinati, %d intossicati su 1000 crudi quasi marci" % [meals, poisoned])
	quit()


# chi cucina sta accanto al fuoco, dentro la cucina, guardandolo
func check_cook(main, fire: Vector2i) -> void:
	for c in main.colonists:
		if c.job == main.Job.COOK and main.is_working(c) and c.work_left < c.work_total:  # al mucchio non ha ancora iniziato
			var here: Vector2i = main.cell_of(c.pos)
			check((here - fire).length() == 1, "cucina accanto al fuoco")
			check(main.WORK_CYCLE.has(main.frame_of(c)), "fotogrammi d'azione mentre cucina")


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
