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

	# il mulino ad acqua: una stanza sulla riva (tipo Mulino) con la macina e il pignone sul muro; dall'altra parte del
	# muro, nel torrente, la ruota (2x2) con le spalle al muro
	check(main.Build.WATER_WHEEL in main.OUTDOOR and main.FURNITURE[main.Build.WATER_WHEEL] == Vector2i(2, 2)
		and main.ROOM_NEEDS[main.RoomKind.MILL] == {main.Build.MILLSTONE: 1, main.Build.MILL_GEAR: 1}
		and main.STATION_ROOM[main.Build.MILLSTONE] == main.RoomKind.MILL, "la ruota fuori, 2x2; la macina e il pignone nel mulino")
	var wheel := Vector2i(-1, -1)
	var turn := -1
	var wall: Array = []
	var inward := Vector2i.ZERO
	for k in main.cells_in(Rect2i(Vector2i.ZERO, main.MAP_SIZE)):
		for t in 4:
			var plan: Array = [main.Build.WATER_WHEEL, main.Res.WOOD, t]
			var rect: Rect2i = main.piece_rect(k, plan)
			if not main.cells_in(rect).all(func(h): return stream.has(h)):
				continue
			var back: Vector2i = main.BACKS[t]
			var behind: Array = main.cells_in(rect).map(func(h): return h + back).filter(func(h): return not rect.has_point(h))
			if behind.all(func(h): return [1, 2, 3, 4].all(func(i): return main.can_build(h + back * (i - 1), main.Build.WALL))):
				wheel = k
				turn = t
				wall = behind
				inward = back
				break
		if wheel.x >= 0:
			break
	check(wheel.x >= 0, "c'è un posto per il mulino sulla riva del torrente")
	var wheel_plan: Array = [main.Build.WATER_WHEEL, main.Res.WOOD, turn]
	check(not main.piece_fits(wheel, wheel_plan), "la ruota senza il muro alle spalle no")
	for k in wall:
		main.built[k] = [main.Build.WALL, main.Res.WOOD]
		main.astar.set_point_solid(k)
	check(main.piece_fits(wheel, wheel_plan), "nel torrente, con le spalle al muro: sì")
	var lake: Array = main.water.keys().filter(func(k): return not stream.has(k))
	check(lake.is_empty() or not main.can_build(lake[0], main.Build.WATER_WHEEL), "non in un lago: serve l'acqua che scorre")
	var mill_room = main.Room.new()  # stanza di prova fatta di dati, dietro il muro
	for k in wall:
		for i in [1, 2, 3]:
			mill_room.cells[k + inward * i] = true
	mill_room.kind = main.RoomKind.MILL
	main.rooms.append(mill_room)
	var gear: Vector2i = wall[0] + inward
	var mill: Vector2i = wall[1] + inward * 3  # la macina
	main.furniture[gear] = [main.Build.MILL_GEAR, main.Res.WOOD, main.BACKS.find(-inward)]
	main.furniture[mill] = [main.Build.MILLSTONE, main.Res.STONE, 0]
	check(main.piece_fits(wall[1] + inward, [main.Build.MILL_GEAR, main.Res.WOOD, main.BACKS.find(-inward)]), "il pignone contro il muro, dentro")
	check(main.stations(main.Build.MILLSTONE).is_empty() and main.station_block(mill).begins_with("Nothing turns the gear"), "senza la ruota la macina sta ferma")
	check(main.describe(gear)[1] == "No water wheel or capstan behind this wall.", "col mouse sopra il pignone: niente ruota")
	main.furniture[wheel] = wheel_plan
	check(main.geared(gear) and main.mill_turns(mill_room) and main.stations(main.Build.MILLSTONE) == [mill], "con la ruota il mulino gira")
	check(main.describe(gear)[1] == "Turned by the water wheel.", "col mouse sopra il pignone: la ruota lo gira")

	# macinare: il mugnaio (Produrre, abilità cucinare) porta 2 grano alla macina: 2 farina, che non si rovina mai
	var by: Vector2i = main.cells_in(Rect2i(mill + inward * 2 - Vector2i(3, 3), Vector2i(8, 8))).filter(func(k): return main.can_build(k) and not mill_room.cells.has(k))[0]
	main.drop(main.Res.GRAIN, by, 6)
	main.researched.erase(main.Tech.MILL)
	for c in main.colonists:
		c.pos = main.center(mill + inward)  # nel mulino: chi sta fermo sopra un mucchio lo tiene per sé
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

	# col gelo la ruota si ferma: la macina non lavora, il suo menu lo dice
	main.atmosphere.frozen = true
	check(main.stations(main.Build.MILLSTONE).is_empty(), "torrente gelato: non si macina")
	main.open_craft(mill)
	var note: Label = main.get_node("HUD/CraftPopup/Box/Room")
	check(note.visible and note.text == "The stream is frozen: the wheel stands still.", "il menu dice della ruota ferma")
	main.atmosphere.frozen = false
	main.open_craft(mill)
	check(not note.visible, "sgelato, il mulino lavora")
	main.craft_popup.hide()
	check(main.describe(mill)[1].ends_with("Click: what to make"), "col mouse sopra: cosa fare")
	main.furniture.erase(wheel)

	# il maneggio (col Mulino): fuori, 2x2 contro il muro esterno come la ruota, l'albero al pignone; lo gira una mucca
	# adulta e sazia, se no lo spinge il mugnaio a mano (più piano, e stanca); col gelo lavora lo stesso
	check(main.TECHS[main.Tech.MILL]["builds"].has(main.Build.CAPSTAN) and main.Build.CAPSTAN in main.OUTDOOR
		and main.FURNITURE[main.Build.CAPSTAN] == Vector2i(2, 2) and main.AGAINST[main.Build.CAPSTAN] == [main.Build.WALL],
		"il maneggio: col Mulino, all'aperto, 2x2, contro un muro")
	var site := Vector2i(-1, -1)
	for k in main.cells_in(area):
		if main.cells_in(Rect2i(k, Vector2i(2, 6))).all(func(h): return main.can_build(h, main.Build.WALL)):
			site = k
			break
	check(site.x >= 0, "c'è posto per il mulino col maneggio")
	var capstan_plan: Array = [main.Build.CAPSTAN, main.Res.WOOD, 2]  # le spalle in basso, al muro
	check(not main.piece_fits(site, capstan_plan), "senza il muro alle spalle no")
	for k in [site + Vector2i(0, 2), site + Vector2i(1, 2)]:
		main.built[k] = [main.Build.WALL, main.Res.WOOD]
		main.astar.set_point_solid(k)
	check(main.piece_fits(site, capstan_plan), "contro il muro sì")
	var mill2 = main.Room.new()
	for k in main.cells_in(Rect2i(site + Vector2i(0, 3), Vector2i(2, 3))):
		mill2.cells[k] = true
	mill2.kind = main.RoomKind.MILL
	main.rooms.append(mill2)
	var gear2 := site + Vector2i(0, 3)
	var stone2 := site + Vector2i(1, 5)
	main.furniture[gear2] = [main.Build.MILL_GEAR, main.Res.WOOD, 0]  # le spalle in alto, al muro
	main.furniture[stone2] = [main.Build.MILLSTONE, main.Res.STONE, 0]
	check(main.station_block(stone2).begins_with("Nothing turns the gear"), "senza niente dietro il muro la macina sta ferma")
	main.furniture[site] = capstan_plan
	check(main.mill_drive(mill2) == site and main.stations(main.Build.MILLSTONE).has(stone2), "col maneggio dietro il muro la macina lavora")
	check(main.describe(gear2)[1] == "Turned by the capstan.", "col mouse sopra il pignone: il maneggio")
	main.animals.clear()
	main.items[main.Res.FLOUR].clear()
	main.drop(main.Res.GRAIN, stone2 + Vector2i(2, 0), 2)
	for c in main.colonists:
		c.pos = main.center(stone2 + Vector2i(-1, 0))
		c.needs[main.Need.REST] = 80.0
		main.end_job(c)
	var pusher = null
	for i in 6000:
		main.tick(0.05)
		for c in main.colonists:
			if c.job == main.Job.CRAFT and c.pushing and is_equal_approx(c.pos.distance_to(main.mill_hub(site)), main.TILE):
				pusher = c
		if main.available(main.Res.GRAIN) == 0 and main.colonists.all(func(c): return c.job != main.Job.CRAFT):
			break
	flour = main.items[main.Res.FLOUR].values().reduce(func(a, b): return a + b, 0) \
		+ main.colonists.filter(func(c): return c.carry_res == main.Res.FLOUR).map(func(c): return c.carrying).reduce(func(a, b): return a + b, 0)
	check(pusher != null and flour == 2, "senza mucca la spinge il mugnaio, girando attorno al palo: 2 farina (%d)" % flour)
	check(pusher != null and pusher.needs[main.Need.REST] == 80.0 - main.PUSH_TIRE, "e si stanca")
	main.atmosphere.frozen = true
	var cow = main.add_livestock(main.Beast.COW, site + Vector2i(4, 0), true, false)
	var calf = main.add_livestock(main.Beast.COW, site + Vector2i(4, 1), false, true)
	check(main.draft_cows(site) == [cow], "una mucca adulta e sazia: la attacca (il vitello no)")
	main.drop(main.Res.GRAIN, stone2 + Vector2i(2, 0), 2)
	var circled := false
	for i in 6000:
		main.tick(0.05)
		var miller: Array = main.colonists.filter(func(c): return c.job == main.Job.CRAFT and c.prey == cow)
		if not miller.is_empty():
			check(not miller[0].pushing, "con la mucca non spinge lui")
			circled = circled or is_equal_approx(cow.pos.distance_to(main.mill_hub(site)), main.TILE)
		if main.available(main.Res.GRAIN) == 0 and main.colonists.all(func(c): return c.job != main.Job.CRAFT):
			break
	flour = main.items[main.Res.FLOUR].values().reduce(func(a, b): return a + b, 0) \
		+ main.colonists.filter(func(c): return c.carry_res == main.Res.FLOUR).map(func(c): return c.carrying).reduce(func(a, b): return a + b, 0)
	check(flour == 4 and circled, "col gelo, la mucca gira attorno al palo: 2 farina in più (%d)" % flour)
	check(cow.handler == null, "finito, la mucca torna libera")
	main.atmosphere.frozen = false
	for o in [site, gear2, stone2]:
		main.furniture.erase(o)
	main.rooms.erase(mill2)
	main.animals.clear()
	main.items[main.Res.FLOUR].clear()

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
	check(rows.size() == 4 and rows[3] is Button, "nel menu del forno pane, stufato e conserve; in fondo il banchetto")
	var any: Array = rows[1].find_children("*", "TextureRect", true, false).filter(func(n): return n.tooltip_text.begins_with("Any of: "))
	check(any.size() == 2, "lo stufato: i vegetali e la carne o il pesce, a scelta")
	main.craft_popup.hide()

	# mangiare: prima il pasto squisito, lo stufato, il pasto, il pane, poi il crudo; lo stufato rifocilla, il pane sazia
	check(main.EATEN.slice(0, 6) == [main.Res.FINE_MEAL, main.Res.STEW, main.Res.MEAL, main.Res.BREAD, main.Res.CHEESE, main.Res.HONEY]
		and main.EATEN.slice(6) == main.RAW_FOOD and main.Res.PRESERVES in main.RAW_FOOD, "l'ordine dei cibi (il formaggio della stalla, il miele)")
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

	# l'apicoltura (Terra III, dopo il Forno di pietra): l'arnia fa il miele coi fiori vicini, in primavera e d'estate
	var bees: Dictionary = main.TECHS[main.Tech.APIARY]
	check(bees["tier"] == 3 and bees["needs"] == [main.Tech.STONE_OVEN] and main.Build.HIVE in bees["builds"]
		and main.Res.CANDLE in bees["makes"], "Apicoltura: Terra III, dopo il Forno di pietra")
	main.clock = 3 * main.YEAR_DAYS + 120.5  # d'estate
	main.tick(0.0)
	var hive := spot + Vector2i(0, 8)
	var beds: Array = main.cells_in(Rect2i(hive + Vector2i(1, -1), Vector2i(4, 1)))
	check(main.can_build(hive) and beds.all(func(k): return main.can_build(k)), "c'è posto per l'arnia e le aiuole")
	main.furniture[hive] = [main.Build.HIVE, main.Res.WOOD, 0]
	main.flax.clear()
	main.herbs.clear()
	main.bushes.clear()
	main.make_honey()
	check(main.hives[hive] == 0.0 and main.flowers_near(hive) == 0, "senza fiori niente miele")
	main.furniture[beds[0]] = [main.Build.FLOWER_BED, main.Res.WOOD, 0]
	main.make_honey()
	check(main.hives[hive] == main.HIVE_RATE[1], "con pochi fiori, poco")
	for k in beds.slice(1):
		main.furniture[k] = [main.Build.FLOWER_BED, main.Res.WOOD, 0]
	main.make_honey()
	check(main.hives[hive] == main.HIVE_RATE[1] + main.HIVE_RATE[0] and main.flowers_near(hive) == 4, "con quattro fiori, mezzo al giorno")
	check(main.describe(hive)[1].begins_with("Honey: 0 / 4. Flowers nearby: 4"), "col mouse sopra: il miele e i fiori")
	main.hives[hive] = float(main.HIVE_FULL)
	for c in main.colonists:
		c.pos = main.center(hive + Vector2i(0, 2))
		main.end_job(c)
	for i in 3000:
		main.tick(0.05)
		if main.hives[hive] == 0.0 and main.colonists.all(func(c): return c.job != main.Job.HONEY):
			break
	check(total.call(main.Res.HONEY) == 4 and total.call(main.Res.WAX) == 1, "piena: 4 miele e 1 cera")
	check(main.FOOD[main.Res.HONEY] == 20.0 and not main.SHELF_LIFE.has(main.Res.HONEY) and main.Res.HONEY in main.COOKED, "il miele sazia 20 e non marcisce")
	var winter_clock: float = main.clock
	main.clock = main.YEAR_DAYS * 2 - 20.5
	main.tick(0.0)
	main.hives[hive] = 1.0
	main.make_honey()
	check(main.hives[hive] == 1.0, "d'inverno niente miele")
	main.clock = winter_clock
	main.tick(0.0)

	# le candele: di notte lo scrittoio con la candela non vuole l'abat-jour, con l'abat-jour è più svelto
	var candle_recipe: Array = main.RECIPES.filter(func(r): return r[0] == main.Res.CANDLE)[0]
	check(candle_recipe[1] == main.Build.WORKBENCH and candle_recipe[3] == {main.Res.WAX: 1} and candle_recipe[5] == 4, "al banco da lavoro: 1 cera, 4 candele")
	var study = main.Room.new()
	var desk := spot + Vector2i(0, 10)
	for k in main.cells_in(Rect2i(desk, Vector2i(3, 2))):
		study.cells[k] = true
	study.kind = main.RoomKind.STUDY
	main.rooms.append(study)
	main.furniture[desk] = [main.Build.DESK, main.Res.WOOD, 0]
	var shelf := spot + Vector2i(4, 10)
	main.stockpile = {shelf: true}
	main.add_item(main.Res.CANDLE, shelf, 2)
	var scholar = main.colonists[0]
	main.clock = floorf(main.clock) + 22.0 / 24.0  # le dieci di sera
	main.tick(0.0)
	var dark: float = main.page_time(scholar, study)
	var lit: float = main.page_time(scholar, study, desk)
	check(is_equal_approx(lit * main.NIGHT_STUDY, dark) and main.stored(main.Res.CANDLE) == 1, "una candela: come di giorno, senza abat-jour")
	main.page_time(scholar, study, desk)
	check(main.stored(main.Res.CANDLE) == 1, "una sola a notte")
	main.furniture[desk + Vector2i(1, 0)] = [main.Build.LAMP, main.Res.WOOD, 0]
	check(is_equal_approx(main.page_time(scholar, study, desk), main.page_time(scholar, study) * main.CANDLE_STUDY), "con l'abat-jour il 10% più svelto")
	main.clock += 1.0  # la notte dopo
	main.tick(0.0)
	main.page_time(scholar, study, desk)
	check(main.stored(main.Res.CANDLE) == 0, "la notte dopo, un'altra candela")

	# il banchetto reale (Terra IV, dopo l'Apicoltura): dal menu del forno, una volta a stagione; una sala del trono col
	# tavolo, a testa uno stufato, un pane e un miele; il giorno dopo alle 18 tutti nella sala: +15 per 3 giorni, +20
	check(main.TECHS[main.Tech.BANQUET]["tier"] == 4 and main.TECHS[main.Tech.BANQUET]["needs"] == [main.Tech.APIARY], "Banchetto reale: Terra IV, dopo l'Apicoltura")
	main.clock = 4 * main.YEAR_DAYS + 120.4  # d'estate, di giorno
	main.tick(0.0)
	check(main.banquet_block() == "Needs a throne room with a table.", "senza la sala del trono no")
	var hall = main.Room.new()
	var hall_at := spot + Vector2i(0, 14)
	for k in main.cells_in(Rect2i(hall_at, Vector2i(5, 4))):
		hall.cells[k] = true
	hall.kind = main.RoomKind.THRONE_ROOM
	hall.name = "Hall"
	main.rooms.append(hall)
	main.furniture[hall_at + Vector2i(1, 1)] = [main.Build.TABLE, main.Res.WOOD, 0]
	main.furniture[hall_at + Vector2i(0, 1)] = [main.Build.CHAIR, main.Res.WOOD, 1]
	var heads: int = main.colonists.size()
	check(main.banquet_block().begins_with("Missing in the warehouses: "), "senza da mangiare no")
	var pantry2 := spot + Vector2i(6, 14)
	main.stockpile = {}
	var shelves := [main.Res.STEW, main.Res.BREAD, main.Res.HONEY, main.Res.ICE]
	for i in shelves.size():
		main.stockpile[pantry2 + Vector2i(0, i)] = true
		main.add_item(shelves[i], pantry2 + Vector2i(0, i), heads + 2)
	check(main.banquet_block() == "", "con tutto si può")
	main.open_craft(oven)
	var feast_button: Button = main.get_node("HUD/CraftPopup/Box/List").get_children()[-1]
	check(feast_button.text.begins_with("Royal banquet: %d stew" % heads) and not feast_button.disabled, "nel menu del forno")
	feast_button.pressed.emit()
	main.craft_popup.hide()
	check(main.banquet_at > main.clock and main.stored(main.Res.STEW) == 2 and main.stored(main.Res.BREAD) == 2, "ordinato: preso dai magazzini")
	check(main.banquet_sorbet and main.stored(main.Res.ICE) == heads + 2 - ceili(heads / 4.0), "d'estate, col ghiaccio, il sorbetto")
	check(main.banquet_block().begins_with("Already ordered"), "uno alla volta")
	var authority: float = main.authority
	for c in main.colonists:
		main.end_job(c)
	main.clock = main.banquet_at - 0.0002
	main.tick(0.0)
	main.tick(0.1)
	check(main.colonists.all(func(c): return c.job == main.Job.FEAST) and absf(main.authority - authority - 20.0) < 0.01, "alle 18 tutti al banchetto; +20 autorità")
	for i in 3000:
		main.tick(0.1)
		if main.colonists.all(func(c): return c.job != main.Job.FEAST):
			break
	check(main.colonists.all(func(c): return c.conds.has(main.Cond.BANQUET) and c.conds.has(main.Cond.SORBET)), "finito: il banchetto e il sorbetto")
	check(main.colonists.all(func(c): return hall.cells.has(main.cell_of(c.pos))), "nella sala del trono")
	check(main.banquet_block().begins_with("Once a season"), "poi una stagione di attesa")

	print("OK: torrente di %d caselle, mulino in %s; il forno; le api; il banchetto" % [stream.size(), mill])
	quit()


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
