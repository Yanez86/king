# Esegui: godot --headless --path . -s tests/test_livestock.gd
# Allevamento (GDD 4.4.7): il pascolo con l'erba e la staccionata, il mercante di bestiame, galline e maiali che
# brucano, fanno i piccoli e muoiono di fame, il pollaio e le uova, quanti tenerne e il macello, i lupi nel pascolo
extends SceneTree


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(1)
	var main = load("res://main.tscn").instantiate()
	main.game_start = false
	root.add_child(main)
	await process_frame
	main.needs_rate = 0.0  # bisogni fermi: li accende la prova che li vuole
	main.routines = false
	main.events = false
	main.atmosphere.climate = false
	main.animals.clear()
	main.bushes.clear()
	main.weeds.clear()
	var HEN: int = main.Beast.HEN
	var PIG: int = main.Beast.PIG

	# la ricerca e il tasto: Terra I, dopo la Caccia
	var tech: Dictionary = main.TECHS[main.Tech.HUSBANDRY]
	check(tech["tier"] == 1 and tech["needs"] == [main.Tech.HUNTING] and main.Build.COOP in tech["builds"], "Allevamento: Terra I, dopo la Caccia")
	var button: Button = main.tool("Pasture")
	check(button.visible and button.button_group == main.order_group, "tasto Pasture nel gruppo delle azioni")
	main.researched.erase(main.Tech.HUSBANDRY)
	main.refresh_unlocks()
	check(not button.visible, "senza la ricerca niente pascolo")
	main.researched[main.Tech.HUSBANDRY] = true
	main.refresh_unlocks()

	# il pascolo: sul prato libero, come l'orto; l'erba è alta; sopra si fa solo il pollaio, e il pollaio solo lì
	var area := Rect2i(main.MAP_SIZE / 2 - Vector2i(8, 8), Vector2i(16, 16))
	var field := Rect2i(-1, -1, 8, 6)
	for k in main.cells_in(area):
		if main.cells_in(Rect2i(k, Vector2i(8, 6))).all(func(h): return main.can_plant(h)):
			field.position = k
			break
	check(field.position.x >= 0, "c'è prato per il pascolo")
	main.order = main.Order.PASTURE
	main.mark(field)
	main.order = main.Order.NONE
	check(main.pasture.size() == 48 and main.pasture.values().all(func(g): return g == main.GRASS_MAX), "48 caselle di pascolo, l'erba alta")
	var corner: Vector2i = field.position
	check(not main.can_build(corner) and not main.can_plant(corner), "sul pascolo non si costruisce né si fa l'orto")
	# la staccionata: un tratto per lato di bordo, coi pali ai capi; di fronte e dietro la base sta sul bordo della casella
	var runs: Array = main.fence_runs()
	var edge := Vector2(corner * main.TILE)
	check(runs.size() == 2 * (8 + 6) and runs.filter(func(r): return r["src"] == main.FENCE_RUN).size() == 16
		and runs.filter(func(r): return r["src"] == main.FENCE_SIDE).size() == 12, "28 tratti di staccionata: 16 di fronte e dietro, 12 di lato")
	check(runs.any(func(r): return r["src"] == main.FENCE_RUN and r["pos"] == edge and r["at"] == edge + Vector2(-2, -12))
		and runs.any(func(r): return r["src"] == main.FENCE_RUN and r["pos"] == edge + Vector2(0, 6 * main.TILE)),
		"dietro sul bordo in alto, davanti su quello in basso")
	check(main.center(corner + Vector2i(0, 5)).y < edge.y + 6 * main.TILE and main.center(corner + Vector2i(0, 6)).y > edge.y + 6 * main.TILE,
		"chi è nell'ultima fila passa dietro al tratto davanti, chi è fuori gli passa davanti")
	check(main.FENCE.get_size() == Vector2(56, 29) and main.FENCE_PATCHES.all(func(p): return Rect2(Vector2.ZERO, main.FENCE.get_size()).encloses(p)),
		"i pezzi stanno nel foglio della staccionata")
	check(main.fence_runs() == runs, "finché il pascolo non cambia i tratti restano quelli")
	main.pasture.erase(corner)
	check(main.fence_runs().size() == 2 * (8 + 6) and main.fence_runs().any(func(r): return r["src"] == main.FENCE_RUN and r["pos"] == edge + Vector2(0, main.TILE)),
		"tolto un angolo, la staccionata gli gira attorno")
	main.pasture[corner] = main.GRASS_MAX
	var coop := corner + Vector2i(1, 0)
	check(main.piece_fits(coop, [main.Build.COOP, main.Res.WOOD, 0]), "il pollaio sul pascolo")
	check(not main.piece_fits(corner - Vector2i(3, 0), [main.Build.COOP, main.Res.WOOD, 0]), "il pollaio fuori dal pascolo no")
	check(main.describe(corner + Vector2i(3, 3))[0] == "Pasture", "col mouse sopra: il pascolo")

	# il mercante di bestiame: col pascolo, non d'inverno; vende coppie, compra capi
	main.clock = main.YEAR_DAYS + 100.5  # l'estate dell'anno dopo
	main.tick(0.0)
	check(main.narrator.drover_can(), "col pascolo passa il mercante di bestiame")
	var store := corner - Vector2i(2, 0)
	main.stockpile = {store: true}
	main.add_item(main.Res.GOLD, store, 100)
	main.drover_arrives()
	check(main.drover_stock.size() >= 2 and main.drover_stock.size() <= 3 and main.drover_stock.all(func(k): return k in main.LIVESTOCK),
		"vende 2-3 coppie delle specie che si sanno allevare")
	main.researched.erase(main.Tech.STABLE)
	main.drover_arrives()
	check(main.drover_stock.all(func(k): return k in [HEN, PIG]), "senza la Stalla solo galline e maiali")
	main.researched[main.Tech.STABLE] = true
	check(main.chronicle[-1].contains("livestock dealer"), "lo dice la cronaca")
	main.drover_stock = [HEN, PIG]
	check(main.buy_pair(0) and main.buy_pair(0), "si comprano le coppie")
	check(main.stored(main.Res.GOLD) == 100 - 12 - 30 and main.drover_stock.is_empty(), "pagate con le monete del magazzino")
	var herd: Array = main.animals.filter(main.tame)
	check(herd.size() == 4 and herd.all(func(a): return main.pasture.has(main.cell_of(a.pos)) and main.grown(a))
		and herd.filter(func(a): return a.female).size() == 2, "due coppie adulte, nel pascolo")
	main.open_pasture()
	var rows: Array = main.pasture_popup.get_node("Box/List").get_children()
	check(rows.any(func(n): return n is Button and n.text.begins_with("Sell a hen")), "nel menu del pascolo: vendere")
	check(main.sell_head(HEN) and main.stored(main.Res.GOLD) == 58 + 3, "un capo a un quarto della coppia")
	main.pasture_popup.hide()
	main.drover_until = main.clock - 0.01
	main.tick(0.05)
	check(main.drover_until < 0 and not main.sell_head(PIG), "passato il giorno se ne va")
	main.animals.assign(main.animals.filter(func(a): return not main.tame(a)))

	# brucare: la sazietà cala di FED_DROP al giorno; sull'erba del pascolo la riprende, e l'erba cala
	var pig = main.add_livestock(PIG, corner + Vector2i(4, 3), true, false)
	main.needs_rate = 1.0
	pig.fed = 40.0
	var grass: float = main.pasture[corner + Vector2i(4, 3)]
	main.update_livestock(pig, main.DAY_LENGTH * 0.05)
	check(pig.fed > 40.0 and main.pasture[corner + Vector2i(4, 3)] < grass, "bruca: più sazio, meno erba")
	var outside: Vector2i = main.cells_in(Rect2i(corner - Vector2i(6, 6), Vector2i(5, 5))).filter(func(k): return not main.astar.is_point_solid(k))[-1]
	var hungry = main.add_livestock(PIG, outside, false, false)  # fuori dal pascolo, sul prato
	hungry.fed = 40.0
	main.update_livestock(hungry, main.DAY_LENGTH * 0.1)
	check(is_equal_approx(hungry.fed, 40.0 - main.FED_DROP * 0.1), "fuori dal pascolo non mangia")
	check(main.graze_path(hungry).back() in main.pasture, "e ci torna")
	hungry.fed = 0.0
	hungry.starving = main.clock - main.STARVE_DAYS - 0.01
	main.update_livestock(hungry, 0.05)
	check(hungry not in main.animals and main.chronicle[-1].contains("starved"), "a sazietà 0 per tre giorni muore di fame")
	main.needs_rate = 0.0

	# i piccoli: una femmina adulta e sazia, un maschio adulto e sazio, posto nel pascolo
	pig.fed = 80.0
	pig.next_young = main.clock - 0.01
	main.update_livestock(pig, 0.05)
	check(main.animals.filter(main.tame).size() == 1, "senza maschio niente piccoli")
	var boar = main.add_livestock(PIG, corner + Vector2i(5, 3), false, false)
	boar.fed = 80.0
	main.update_livestock(pig, 0.05)
	var piglets: Array = main.animals.filter(func(a): return main.tame(a) and not main.grown(a))
	check(piglets.size() == 4 and piglets.all(func(a): return a.kind == PIG), "4 porcellini")
	check(pig.next_young == main.clock + 60.0 or is_equal_approx(pig.next_young - main.clock, 60.0), "il prossimo parto fra 60 giorni")
	check(main.herd_space() == 48 - 6 * 2, "il pascolo: 2 caselle a capo, anche i piccoli")
	piglets[0].born -= 30.0
	check(main.grown(piglets[0]), "in 30 giorni sono adulti")
	piglets[0].born += 30.0
	piglets[1].pos = main.center(corner + Vector2i(7, 5))
	piglets[1].path.clear()
	check(main.describe(corner + Vector2i(7, 5))[1].contains("(young)"), "col mouse sopra: piccolo")

	# il macello: oltre quanti tenerne, prima i maschi in più, poi i più vecchi; mai i piccoli
	main.herd_keep[PIG] = 1
	pig.born -= 10.0
	boar.born -= 5.0
	var boar2 = main.add_livestock(PIG, corner + Vector2i(6, 3), false, false)
	boar2.born = boar.born + 1.0  # più giovane, adulto anche lui
	var culls: Array = main.culls()
	check(culls.size() == 2 and culls[0] == boar2 and culls.all(func(a): return main.grown(a)), "il maschio in più, poi il più vecchio")
	check(main.job_list().contains("Slaughter: 2"), "finestra Jobs: da macellare")
	for c in main.colonists:
		c.pos = main.center(corner + Vector2i(3, -1))
	for i in 3000:
		main.tick(0.05)
		if main.culls().is_empty() and main.colonists.all(func(c): return c.job != main.Job.BUTCHER):
			break
	check(main.animals.filter(func(a): return main.tame(a) and main.grown(a)).size() == 1, "macellati: resta un adulto")
	check(main.total(main.Res.MEAT) + main.colonists.filter(func(c): return c.carry_res == main.Res.MEAT).map(func(c): return c.carrying).reduce(func(a, b): return a + b, 0) == 30,
		"due maiali, 30 carne")
	check(main.colonists.any(func(c): return c.xp[main.Skill.HUSBANDRY] > 0), "chi macella impara ad allevare")
	main.herd_keep[PIG] = main.HERD_KEEP
	main.animals.assign(main.animals.filter(func(a): return not main.tame(a)))

	# le uova: all'alba, ogni gallina adulta e sazia un uovo nel pollaio, non d'inverno; chi alleva le raccoglie
	main.furniture[coop] = [main.Build.COOP, main.Res.WOOD, 0]
	for i in 3:
		main.add_livestock(HEN, corner + Vector2i(2 + i, 3), true, false).fed = 80.0
	main.add_livestock(HEN, corner + Vector2i(5, 3), false, false).fed = 80.0
	main.add_livestock(HEN, corner + Vector2i(6, 3), true, true)  # una pulcina: niente uova
	main.lay_eggs()
	check(main.coop_eggs.get(coop, 0) == 3, "tre galline, tre uova")
	check(main.describe(coop)[1] == "Eggs: 3", "col mouse sopra il pollaio: le uova")
	main.coop_eggs.clear()
	var winter: float = main.clock
	main.clock = main.YEAR_DAYS * 2 - 20.5
	main.tick(0.0)
	main.lay_eggs()
	check(main.coop_eggs.is_empty(), "d'inverno niente uova")
	main.clock = winter  # di nuovo d'estate: all'alba (il giorno cambia) le uova
	main.tick(0.0)
	check(main.coop_eggs.get(coop, 0) == 3, "un giorno nuovo, tre uova")
	for i in 3000:
		main.tick(0.05)
		if main.coop_eggs.values().all(func(e): return e == 0) and main.colonists.all(func(c): return c.job != main.Job.TEND):
			break
	var eggs: int = main.total(main.Res.EGG) + main.colonists.filter(func(c): return c.carry_res == main.Res.EGG).map(func(c): return c.carrying).reduce(func(a, b): return a + b, 0)
	check(eggs == 3, "raccolte: 3 uova (%d)" % eggs)
	check(main.Res.EGG in main.RAW_FOOD and main.FOOD[main.Res.EGG] == 25.0 and main.SHELF_LIFE[main.Res.EGG] == 10.0, "le uova: crudo, sazia 25, durano 10 giorni")

	# la caccia non segna gli animali da allevare; i selvatici che arrivano non li contano
	main.order = main.Order.HUNT
	main.mark(field)
	main.order = main.Order.NONE
	check(main.animals.all(func(a): return not a.marked), "non si cacciano")
	for i in 12:
		main.add_livestock(HEN, corner + Vector2i(i % 8, 4), true, true)
	main.next_animal = main.clock
	main.tick(0.05)
	check(main.animals.any(func(a): return not main.tame(a)), "con tante galline arrivano lo stesso i selvatici")
	main.animals.assign(main.animals.filter(main.tame))

	# i lupi vanno anche contro gli animali del pascolo; dietro la palizzata no
	for c in main.colonists:
		c.pos = main.center(main.MAP_SIZE / 2 + Vector2i(30, 30))  # lontani
	var hen = main.animals.filter(func(a): return a.kind == HEN)[0]
	main.animals.assign([hen])
	var wolf = main.add_animal(main.Beast.WOLF, main.cell_of(hen.pos) + Vector2i(1, 0))
	wolf.leave_at = INF
	for i in 400:
		main.tick(0.05)
		if hen not in main.animals:
			break
	check(hen not in main.animals and main.chronicle[-1].contains("wolves killed a hen"), "il lupo sbrana la gallina")
	main.animals.clear()
	var safe = main.add_livestock(HEN, corner + Vector2i(4, 2), true, false)
	var ring: Array = main.cells_in(Rect2i(corner + Vector2i(2, 0), Vector2i(5, 5))).filter(func(k):
		return k.x in [corner.x + 2, corner.x + 6] or k.y in [corner.y, corner.y + 4])
	for k in ring:
		main.built[k] = [main.Build.PALISADE, main.Res.WOOD]
		main.astar.set_point_solid(k)
	wolf = main.add_animal(main.Beast.WOLF, corner + Vector2i(-6, 2))
	wolf.leave_at = INF
	for i in 100:
		main.tick(0.05)
	check(safe in main.animals and safe.blocked > main.clock, "dietro la palizzata la gallina è al sicuro")

	# --- la Stalla (Terra II, dopo l'Allevamento): fieno, mangiatoie, l'inverno dentro, latte, lana, letame ---
	for k in ring:
		main.built.erase(k)
		main.astar.set_point_solid(k, false)
	main.animals.clear()
	var SHEEP: int = main.Beast.SHEEP
	var COW: int = main.Beast.COW
	tech = main.TECHS[main.Tech.STABLE]
	check(tech["tier"] == 2 and tech["needs"] == [main.Tech.HUSBANDRY] and main.RoomKind.STABLE in tech["rooms"]
		and main.Order.HAY in tech["orders"] and main.Res.CHEESE in tech["makes"], "Stalla: Terra II, dopo l'Allevamento")
	check(main.MANURE_SOIL.keys()[0] == main.Res.MANURE and main.MANURE_SOIL[main.Res.MANURE] == 20, "il letame, il primo dei concimi: +20")

	# il fieno: si segna il prato; dalla semina alla fine dell'estate il contadino falcia quello con l'erba alta
	var meadow := Rect2i(field.position + Vector2i(0, 7), Vector2i(3, 1))
	check(main.cells_in(meadow).all(func(h): return main.can_plant(h)), "c'è prato per il fieno")
	main.order = main.Order.HAY
	main.mark(meadow)
	main.order = main.Order.NONE
	check(main.hay_marks.size() == 3 and main.mow_ready().size() == 3, "tre caselle da falciare")
	check(main.describe(meadow.position)[1] == "Ready to mow", "col mouse sopra: da falciare")
	for c in main.colonists:
		c.pos = main.center(meadow.position + Vector2i(0, 1))
	for i in 3000:
		main.tick(0.05)
		if main.mow_ready().is_empty() and main.colonists.all(func(c): return c.job != main.Job.MOW):
			break
	var hay: int = main.total(main.Res.HAY) + main.colonists.filter(func(c): return c.carry_res == main.Res.HAY).map(func(c): return c.carrying).reduce(func(a, b): return a + b, 0)
	check(hay == 3 * main.HAY_CUT, "falciate: %d fieno" % hay)
	check(main.mow_ready().is_empty() and main.describe(meadow.position)[1].begins_with("Grows back"), "poi l'erba ricresce")

	# la stalla: una stanza con la mangiatoia; i trasportatori ci portano il fieno, anche dal magazzino
	var barn = main.Room.new()
	var barn_at := field.position + Vector2i(10, 0)
	for k in main.cells_in(Rect2i(barn_at, Vector2i(5, 2))):
		barn.cells[k] = true
	barn.kind = main.RoomKind.STABLE
	barn.name = "Barn"
	main.rooms.append(barn)
	main.furniture[barn_at] = [main.Build.MANGER, main.Res.WOOD, 0]
	check(main.manger_cells().size() == 2, "la mangiatoia, 2x1")
	for c in main.colonists:  # via dai mucchi: chi ci sta sopra fermo li tiene per sé
		c.pos = main.center(barn_at + Vector2i(2, 1))
		main.end_job(c)
	for i in 3000:
		main.tick(0.05)
		if main.manger_cells().keys().reduce(func(n, k): return n + main.items[main.Res.HAY].get(k, 0), 0) == 12:
			break
	var in_crib: int = main.manger_cells().keys().reduce(func(n, k): return n + main.items[main.Res.HAY].get(k, 0), 0)
	check(in_crib == 12, "il fieno nella mangiatoia (%d)" % in_crib)

	# d'inverno nella stalla: posto per caselle a capo; mangiano il fieno; chi non ha posto patisce il freddo
	main.clock = main.YEAR_DAYS * 2 - 30.5  # d'inverno
	main.tick(0.0)
	check(main.indoors(), "d'inverno si sta dentro")
	var cow = main.add_livestock(COW, field.position + Vector2i(2, 2), true, false)
	var ewe = main.add_livestock(SHEEP, field.position + Vector2i(3, 2), true, false)
	var ram = main.add_livestock(SHEEP, field.position + Vector2i(4, 2), false, false)
	var bull = main.add_livestock(COW, field.position + Vector2i(5, 2), false, false)
	main.assign_stalls()
	check(cow.stall == barn and bull.stall == barn and ewe.stall == barn and ram.stall == null, "10 caselle: le mucche (4) e una pecora (2)")
	for i in 600:
		main.tick(0.05)
		if [cow, bull, ewe].all(func(a): return barn.cells.has(main.cell_of(a.pos))):
			break
	check([cow, bull, ewe].all(func(a): return barn.cells.has(main.cell_of(a.pos))), "vanno nella stalla")
	main.needs_rate = 1.0
	cow.fed = 50.0
	ram.fed = 50.0
	ram.pos = main.center(outside)  # fuori dal pascolo, dove non c'è erba
	main.update_livestock(cow, main.DAY_LENGTH * 0.05)
	main.update_livestock(ram, main.DAY_LENGTH * 0.05)
	check(cow.fed > 50.0, "nella stalla mangia il fieno")
	check(is_equal_approx(ram.fed, 50.0 - main.FED_DROP * 0.05 * main.COLD_HUNGER), "fuori al freddo: la fame doppia")
	var before: int = main.manger_cells().keys().reduce(func(n, k): return n + main.items[main.Res.HAY].get(k, 0), 0)
	cow.fed = 0.0
	main.update_livestock(cow, main.DAY_LENGTH * 0.5)
	var after: int = main.manger_cells().keys().reduce(func(n, k): return n + main.items[main.Res.HAY].get(k, 0), 0)
	check(after < before and cow.dung > 0, "il fieno cala, e viene il letame")
	cow.dung = 0.99
	main.update_livestock(cow, main.DAY_LENGTH * 0.02)
	check(main.total(main.Res.MANURE) == 1, "un letame nella stalla")
	var hen2 = main.add_livestock(HEN, field.position + Vector2i(1, 1), true, false)
	hen2.fed = 50.0
	main.update_livestock(hen2, main.DAY_LENGTH * 0.05)
	check(hen2.fed > 50.0 and hen2.stall == null, "le galline mangiano il fieno di tutte le mangiatoie, dal pollaio")

	# il latte: le femmine adulte di mucca e pecora; chi alleva munge; d'estate tosa le pecore
	cow.milk = 0.0
	cow.fed = 80.0
	main.update_livestock(cow, main.DAY_LENGTH * 0.5)
	check(is_equal_approx(cow.milk, 1.0) and bull.milk == 0.0, "mezza giornata: un latte; il maschio no")
	main.needs_rate = 0.0
	cow.milk = 2.0
	for c in main.colonists:
		c.pos = main.center(barn_at + Vector2i(1, 1))
	for i in 3000:
		main.tick(0.05)
		if cow.milk < 1.0 and main.colonists.all(func(c): return c.job != main.Job.MILK):
			break
	var milk: int = main.total(main.Res.MILK) + main.colonists.filter(func(c): return c.carry_res == main.Res.MILK).map(func(c): return c.carrying).reduce(func(a, b): return a + b, 0)
	check(milk == 2 and main.Res.MILK in main.RAW_FOOD and main.SHELF_LIFE[main.Res.MILK] == 1.0, "munto: 2 latte, crudo, dura un giorno")
	check(main.RECIPES.any(func(r): return r[0] == main.Res.CHEESE and r[1] == main.Build.CAMPFIRE and r[3] == {main.Res.MILK: 3})
		and main.FOOD[main.Res.CHEESE] == 50.0 and main.SHELF_LIFE[main.Res.CHEESE] == 60.0 and main.Res.CHEESE in main.COOKED,
		"il formaggio: 3 latte al fuoco, sazia 50, dura 60 giorni")
	check(not main.shearable(ewe), "d'inverno non si tosa")
	main.clock = main.YEAR_DAYS * 3 + 100.5  # l'estate dopo
	main.tick(0.0)
	check(not main.indoors() and main.shearable(ewe) and main.shearable(ram), "d'estate si tosano le pecore adulte")
	for i in 4000:
		main.tick(0.05)
		if not main.shearable(ewe) and not main.shearable(ram) and main.colonists.all(func(c): return c.job != main.Job.SHEAR):
			break
	var wool: int = main.total(main.Res.WOOL) + main.colonists.filter(func(c): return c.carry_res == main.Res.WOOL).map(func(c): return c.carrying).reduce(func(a, b): return a + b, 0)
	check(wool == 6 and ewe.shorn == main.year_of(main.today), "tosate: 6 lana, una volta all'anno")

	# agnelli e vitelli: uno all'anno, in primavera
	var spring: float = main.next_spring(main.clock)
	var day_of_year: int = posmod(int(spring), main.YEAR_DAYS)
	check(spring > main.clock and day_of_year >= main.BIRTH_SPRING[0] and day_of_year <= main.BIRTH_SPRING[1], "il prossimo parto in primavera")

	# il mercante compra lana e formaggio, tutta quella del magazzino
	main.items[main.Res.WOOL].clear()
	main.add_item(main.Res.WOOL, store + Vector2i(0, 1), 6)
	main.stockpile[store + Vector2i(0, 1)] = true
	var gold: int = main.stored(main.Res.GOLD)
	main.drover_arrives()
	check(main.sell_goods(main.Res.WOOL) and main.stored(main.Res.GOLD) == gold + 6 * 4 and main.stored(main.Res.WOOL) == 0, "6 lana, 24 monete")

	print("OK: pascolo, mercante, brucare, piccoli, macello, uova, lupi; la stalla")
	quit()


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
