# Esegui: godot --headless --path . -s tests/test_grain.gd
# Grano, forno e mulino (GDD 4.4.7): il torrente delle mappe nuove, il grano nei campi, il mulino ad acqua sulla riva,
# la farina, la ruota ferma col gelo; il forno: pane, stufato, conserve, e l'ordine dei cibi
extends SceneTree


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(1)
	var main = load("res://main.tscn").instantiate()
	main.game_start = false
	root.add_child(main)
	await process_frame
	main.needs_rate = 0.0  # bisogni fermi
	main.routines = false  # niente orari
	main.events = false  # niente lupi
	main.atmosphere.climate = false
	main.animals.clear()

	# il torrente: da un bordo a quello di fronte, lontano dalla radura, d'acqua bassa (qua e là una pozza alta)
	var stream: Dictionary = main.stream
	check(stream.size() > 150, "c'è un torrente")
	var clear := func(k): return main.water.has(k) and not main.trees.has(k) and not main.rocks.has(k) and not main.bushes.has(k)
	check(stream.keys().all(clear), "il torrente è acqua: niente alberi, roccia o cespugli")
	var xs: Array = stream.keys().map(func(k): return k.x)
	var ys: Array = stream.keys().map(func(k): return k.y)
	var edge: int = main.MAP_SIZE.x - 1
	check((xs.min() == 0 and xs.max() == edge) or (ys.min() == 0 and ys.max() == edge), "da un bordo a quello di fronte")
	var near: float = stream.keys().map(func(k): return Vector2(k - main.MAP_SIZE / 2).length()).min()
	check(near > main.CLEARING[1] + 2, "lontano dalla radura: %.1f caselle dal centro" % near)
	var shallow: int = stream.keys().filter(func(k): return main.water[k] == main.Ground.SHALLOW).size()
	check(shallow > stream.size() * 0.8, "quasi tutto acqua bassa: si guada")
	check(stream.keys().filter(func(k): return main.water[k] == main.Ground.SHALLOW).all(func(k): return not main.astar.is_point_solid(k)),
		"l'acqua bassa del torrente si attraversa")

	# il grano: una coltura del piano, col Mulino; matura in 100 giorni e dà grano, che non si mangia né marcisce
	check(main.CROP_DAYS[main.Crop.GRAIN] == 100.0 and main.CROP_RES[main.Crop.GRAIN] == main.Res.GRAIN
		and main.CROP_YIELD[main.Crop.GRAIN] == 25, "grano: 100 giorni, 25 a casella")
	check(main.Res.GRAIN not in main.RAW_FOOD and not main.FOOD.has(main.Res.GRAIN) and not main.SHELF_LIFE.has(main.Res.GRAIN)
		and not main.SHELF_LIFE.has(main.Res.FLOUR), "grano e farina non si mangiano e non marciscono")
	check(main.TECHS[main.Tech.MILL]["needs"] == [main.Tech.GARDEN] and main.TECHS[main.Tech.MILL]["tier"] == 1,
		"il Mulino viene dopo l'Orto, livello I")
	var area := Rect2i(main.MAP_SIZE / 2 - Vector2i(8, 8), Vector2i(16, 16))
	var plot := Vector2i(-1, -1)
	for k in main.cells_in(area):
		if main.can_plant(k):
			plot = k
			break
	check(plot.x >= 0, "c'è prato per l'orto")
	main.researched[main.Tech.GARDEN] = true
	main.clock = main.YEAR_DAYS + 150.5  # l'estate dell'anno dopo, a mezzogiorno
	main.tick(0.0)
	main.garden[plot] = main.clock - main.CROP_DAYS[main.Crop.GRAIN] - 0.1  # seminato a grano cento giorni fa
	main.sown[plot] = main.Crop.GRAIN
	main.add_soil(plot, 60 - main.soil_at(plot))  # a 60 la resa di base
	main.update_fields()
	for c in main.colonists:
		c.pos = main.center(plot + Vector2i(0, 1))
	for i in 2000:
		main.tick(0.05)
		if not main.items[main.Res.GRAIN].is_empty() or main.colonists.any(func(c): return c.carry_res == main.Res.GRAIN and c.carrying > 0):
			break
	var reaped: int = main.items[main.Res.GRAIN].values().reduce(func(a, b): return a + b, 0) \
		+ main.colonists.filter(func(c): return c.carry_res == main.Res.GRAIN).map(func(c): return c.carrying).reduce(func(a, b): return a + b, 0)
	check(reaped == 25, "raccolto: 25 grano (%d)" % reaped)
	main.garden.erase(plot)
	main.sown.erase(plot)
	main.update_fields()
	main.items[main.Res.GRAIN].clear()  # il raccolto si mette da parte: al mulino solo quello di sotto
	for c in main.colonists:
		main.end_job(c)
		c.carrying = 0

	# il mulino ad acqua: 2x2, sulla riva, con tutto il lato della ruota nel torrente; girato, la ruota cambia lato
	var mill := Vector2i(-1, -1)
	var turn := -1
	for k in main.cells_in(Rect2i(Vector2i.ZERO, main.MAP_SIZE)):
		for t in 4:
			if main.piece_fits(k, [main.Build.WATER_MILL, main.Res.WOOD, t]):
				mill = k
				turn = t
				break
		if mill.x >= 0:
			break
	check(mill.x >= 0, "c'è un posto per il mulino sulla riva del torrente")
	check(main.wheel_cells(mill, [main.Build.WATER_MILL, main.Res.WOOD, turn]).all(func(k): return stream.has(k)),
		"la ruota pesca nel torrente")
	check(not main.piece_fits(mill, [main.Build.WATER_MILL, main.Res.WOOD, (turn + 2) % 4]), "con la ruota dall'altra parte no")
	var lake: Array = main.water.keys().filter(func(k): return not stream.has(k))
	var on_lake := 0
	for k in main.cells_in(Rect2i(Vector2i.ZERO, main.MAP_SIZE)):
		var plan: Array = [main.Build.WATER_MILL, main.Res.WOOD, 0]
		if main.piece_fits(k, plan) and main.wheel_cells(k, plan).any(func(w): return w in lake):
			on_lake += 1
	check(on_lake == 0, "non sulla riva di un lago: serve l'acqua che scorre")
	check(main.Build.WATER_MILL in main.OUTDOOR and main.FURNITURE[main.Build.WATER_MILL] == Vector2i(2, 2), "all'aperto, 2x2")

	# macinare: il mugnaio (Produrre, abilità cucinare) porta 2 grano al mulino: 2 farina, che non si rovina mai
	main.furniture[mill] = [main.Build.WATER_MILL, main.Res.WOOD, turn]
	check(main.is_station(main.Build.WATER_MILL) and main.stations(main.Build.WATER_MILL) == [mill], "il mulino è una postazione")
	var by: Vector2i = main.cells_in(Rect2i(mill - Vector2i(3, 3), Vector2i(8, 8))).filter(func(k): return main.can_build(k))[0]
	main.drop(main.Res.GRAIN, by, 6)
	main.researched.erase(main.Tech.MILL)
	for c in main.colonists:
		c.pos = main.center(by)
		c.skills[main.Skill.COOKING] = 0  # a livello 0 il cibo brucia una volta su tre: la farina no
		main.end_job(c)
	for i in 200:
		main.tick(0.05)
	check(main.items[main.Res.FLOUR].is_empty(), "senza la ricerca Mulino non si macina")
	main.researched[main.Tech.MILL] = true
	main.keep[main.Res.FLOUR] = 10
	for i in 6000:
		main.tick(0.05)
		if main.available(main.Res.GRAIN) == 0 and main.colonists.all(func(c): return c.job != main.Job.CRAFT):
			break
	var flour: int = main.items[main.Res.FLOUR].values().reduce(func(a, b): return a + b, 0) \
		+ main.colonists.filter(func(c): return c.carry_res == main.Res.FLOUR).map(func(c): return c.carrying).reduce(func(a, b): return a + b, 0)
	check(flour == 6, "6 grano, 6 farina (%d)" % flour)
	check(main.colonists.any(func(c): return c.xp[main.Skill.COOKING] > 0), "il mugnaio impara a cucinare")

	# col gelo la ruota si ferma: il mulino non è più una postazione, il suo menu lo dice
	main.atmosphere.frozen = true
	check(main.stations(main.Build.WATER_MILL).is_empty(), "torrente gelato: non si macina")
	main.open_craft(mill)
	var note: Label = main.get_node("HUD/CraftPopup/Box/Room")
	check(note.visible and note.text == "The stream is frozen: the wheel stands still.", "il menu dice della ruota ferma")
	main.atmosphere.frozen = false
	main.open_craft(mill)
	check(not note.visible, "sgelato, il mulino lavora")
	main.craft_popup.hide()
	check(main.describe(mill)[1] == "Click: what to make", "col mouse sopra: cosa fare")

	# il forno di pietra (Terra II, dopo l'Orto): 2x1, in una cucina, scalda come il fuoco; pane, stufato, conserve
	check(main.TECHS[main.Tech.STONE_OVEN]["tier"] == 2 and main.TECHS[main.Tech.STONE_OVEN]["needs"] == [main.Tech.GARDEN], "il Forno di pietra: Terra II, dopo l'Orto")
	check(main.FURNITURE[main.Build.OVEN] == Vector2i(2, 1) and main.HEAT[main.Build.OVEN] == main.FIRE_HEAT
		and main.STATION_ROOM[main.Build.OVEN] == main.RoomKind.KITCHEN, "2x1, in cucina, scalda come il fuoco da campo")
	main.furniture.erase(mill)
	for res in [main.Res.GRAIN, main.Res.FLOUR]:
		main.items[res].clear()
	var spot := Vector2i(-1, -1)
	for k in main.cells_in(area):
		if main.cells_in(Rect2i(k, Vector2i(5, 4))).all(func(h): return main.can_build(h)):
			spot = k
			break
	check(spot.x >= 0, "c'è posto per la cucina")
	var kitchen = main.Room.new()  # stanza di prova fatta di dati, senza fuoco: nessuno cucina pasti
	for k in main.cells_in(Rect2i(spot, Vector2i(5, 4))):
		kitchen.cells[k] = true
	kitchen.kind = main.RoomKind.KITCHEN
	main.rooms.append(kitchen)
	var oven := spot + Vector2i(1, 1)
	main.furniture[oven] = [main.Build.OVEN, main.Res.STONE, 0]
	check(main.stations(main.Build.OVEN) == [oven], "il forno lavora in cucina")
	var pantry := spot + Vector2i(2, 5)  # gli ingredienti, fuori dalla cucina
	for c in main.colonists:
		c.pos = main.center(pantry)
		c.skills[main.Skill.COOKING] = main.SKILL_MAX  # niente bruciato
		main.end_job(c)
	var total := func(res) -> int:
		return main.items[res].values().reduce(func(a, b): return a + b, 0) \
			+ main.colonists.filter(func(c): return c.carry_res == res).map(func(c): return c.carrying).reduce(func(a, b): return a + b, 0)
	var bake := func(keep: Dictionary, done: Callable) -> void:  # finché `done`, o per un bel po'
		for res in [main.Res.BREAD, main.Res.STEW, main.Res.PRESERVES]:
			main.keep[res] = keep.get(res, 0)
		for i in 4000:
			main.tick(0.05)
			if done.call():
				break
	main.drop(main.Res.FLOUR, pantry, 4)
	main.researched.erase(main.Tech.STONE_OVEN)
	bake.call({main.Res.BREAD: 8}, func(): return false)
	check(total.call(main.Res.BREAD) == 0, "senza la ricerca niente pane")
	main.researched[main.Tech.STONE_OVEN] = true
	bake.call({main.Res.BREAD: 8}, func(): return total.call(main.Res.BREAD) >= 6)
	check(total.call(main.Res.BREAD) == 6 and total.call(main.Res.FLOUR) == 0, "2 farina, 3 pani: 4 farina, 6 pani (%d)" % total.call(main.Res.BREAD))
	main.drop(main.Res.TURNIP, pantry + Vector2i(1, 0), 4)
	main.drop(main.Res.SMOKED_MEAT, pantry + Vector2i(2, 0), 2)
	bake.call({main.Res.STEW: 4}, func(): return total.call(main.Res.STEW) + total.call(main.Res.FINE_MEAL) >= 4)
	var stew: int = total.call(main.Res.STEW) + total.call(main.Res.FINE_MEAL)
	check(stew == 4 and total.call(main.Res.TURNIP) == 0 and total.call(main.Res.SMOKED_MEAT) == 0,
		"2 vegetali e 1 carne, anche affumicata: 2 stufati (o pasti squisiti): %d" % stew)
	main.drop(main.Res.CABBAGE, pantry + Vector2i(1, 0), 2)
	main.drop(main.Res.VEG, pantry + Vector2i(2, 0), 2)
	bake.call({main.Res.PRESERVES: 2}, func(): return total.call(main.Res.PRESERVES) >= 2)
	check(total.call(main.Res.PRESERVES) == 2 and total.call(main.Res.VEG) == 0 and total.call(main.Res.CABBAGE) == 2,
		"2 vegetali, 2 conserve: prima quelli che marciscono prima")
	main.open_craft(oven)
	var rows: Array = main.get_node("HUD/CraftPopup/Box/List").get_children()
	check(rows.size() == 3, "nel menu del forno pane, stufato e conserve")
	var any: Array = rows[1].get_children().filter(func(n): return n is TextureRect and n.tooltip_text.begins_with("Any of: "))
	check(any.size() == 2, "lo stufato: i vegetali e la carne o il pesce, a scelta")
	main.craft_popup.hide()

	# mangiare: prima il pasto squisito, lo stufato, il pasto, il pane, poi il crudo; lo stufato rifocilla, il pane sazia
	check(main.EATEN.slice(0, 4) == [main.Res.FINE_MEAL, main.Res.STEW, main.Res.MEAL, main.Res.BREAD]
		and main.EATEN.slice(4) == main.RAW_FOOD and main.Res.PRESERVES in main.RAW_FOOD, "l'ordine dei cibi")
	check(main.FOOD[main.Res.BREAD] == 60.0 and main.SHELF_LIFE[main.Res.BREAD] == 8.0 and main.FOOD[main.Res.STEW] == 100.0
		and main.SHELF_LIFE[main.Res.STEW] == 3.0 and main.SHELF_LIFE[main.Res.PRESERVES] == 120.0, "quanto saziano, quanto durano")
	var eater = main.colonists[0]
	eater.conds.clear()
	eater.needs[main.Need.FOOD] = 0.0
	eater.carry_res = main.Res.STEW
	eater.carrying = 1
	main.eat(eater)
	check(eater.needs[main.Need.FOOD] == 100.0 and eater.conds.has(main.Cond.WELL_FED) and eater.conds.has(main.Cond.WARMED),
		"lo stufato: ben nutrito e rifocillato")
	eater.conds.clear()
	eater.needs[main.Need.FOOD] = 0.0
	eater.carry_res = main.Res.BREAD
	eater.carrying = 1
	main.eat(eater)
	check(eater.needs[main.Need.FOOD] == 60.0 and eater.conds.is_empty(), "il pane sazia e basta")
	main.atmosphere.climate = true  # a metà inverno, fuori: il freddo toglie comfort
	main.clock = 2 * main.YEAR_DAYS + 3 * main.SEASON_DAYS + 45.5
	main.tick(0.0)
	eater.pos = main.center(pantry)
	eater.job = main.Job.HAUL
	check(main.weather_comfort(pantry) < 0, "fa freddo")
	main.needs_rate = 1.0
	eater.needs[main.Need.COMFORT] = 50.0
	main.update_needs(eater, 10.0)
	var cold: float = 50.0 - eater.needs[main.Need.COMFORT]
	eater.needs[main.Need.COMFORT] = 50.0
	main.add_cond(eater, main.Cond.WARMED)
	main.update_needs(eater, 10.0)
	check(cold > 0 and is_equal_approx(50.0 - eater.needs[main.Need.COMFORT], cold * main.WARMED_COLD), "rifocillato: il freddo toglie metà")
	main.needs_rate = 0.0
	main.atmosphere.climate = false

	print("OK: torrente di %d caselle, mulino in %s; il forno" % [stream.size(), mill])
	quit()


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
