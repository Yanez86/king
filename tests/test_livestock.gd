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
	var button: Button = main.get_node("HUD/Tools/Row/Pasture")
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
	check(main.drover_stock.size() >= 2 and main.drover_stock.size() <= 3 and main.drover_stock.all(func(k): return k in [HEN, PIG]),
		"vende 2-3 coppie di galline o maiali")
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
	var hungry = main.add_livestock(PIG, corner - Vector2i(5, 5), false, false)  # fuori dal pascolo, sul prato
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

	print("OK: pascolo, mercante, brucare, piccoli, macello, uova, lupi")
	quit()


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
