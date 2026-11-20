# Esegui: godot --headless --path . -s tests/test_jobs.gd
extends SceneTree


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(1)  # mappa sempre uguale
	var main = load("res://main.tscn").instantiate()
	main.game_start = false  # le prove partono con tre coloni e niente a terra: la partenza di gioco è in fondo
	root.add_child(main)
	await process_frame  # aspetta che venga chiamato _ready
	main.needs_rate = 0.0  # bisogni fermi: se no a metà prova i coloni vanno a dormire o a mangiare (vedi fondo)
	main.events = false  # niente branchi di lupi: le prove del combattimento sono in test_combat
	main.atmosphere.climate = false  # niente freddo né meteo: il comfort è quello dei mobili (il clima è provato col cartello)
	for c in main.colonists:
		check(c.skills.all(func(l): return l == 0) and c.xp.all(func(x): return x == 0), "tutti i coloni partono da 0 in ogni abilità")
	check(main.animals.size() == main.BEASTS.values().reduce(func(n, b): return n + b["start"], 0), "animali all'inizio")
	main.animals.clear()  # girano per la mappa: le prove della caccia sono in test_food
	main.routines = false  # niente orari: lavorano sempre, anche di notte (la routine è provata in fondo)

	var rows: Array = main.trees.keys().map(func(cell): return cell.y)
	var sorted_rows := rows.duplicate()
	sorted_rows.sort()
	check(rows == sorted_rows, "alberi in ordine di riga (serve al disegno)")

	var covered := {}
	for cell in main.boulders:
		var size: Vector2i = main.boulders[cell]
		for dy in size.y:
			for dx in size.x:
				var k: Vector2i = cell + Vector2i(dx, dy)
				check(main.rocks.has(k) and not covered.has(k), "massi solo sulla roccia, senza sovrapporsi")
				covered[k] = true
	# la roccia unita è massiccio, quella sparsa è coperta di massi
	check(covered.size() + main.massif.size() == main.rocks.size() and covered.keys().all(func(k): return not main.massif.has(k)),
		"i massi coprono tutta la roccia fuori dal massiccio")
	check(main.boulders.values().has(Vector2i(2, 2)), "ci sono anche massi grandi")
	var rock_sets: Array = rock_groups(main)
	for group in rock_sets:
		check(group.all(func(k): return main.massif.has(k)) == (group.size() >= main.MASSIF_MIN) \
			and group.any(func(k): return main.massif.has(k)) == (group.size() >= main.MASSIF_MIN), "massiccio da MASSIF_MIN caselle unite in su")
	check(rock_sets.any(func(g): return g.size() >= 150), "c'è una montagna dove scavare dentro: %d" % rock_sets.map(func(g): return g.size()).max())
	check(main.massif.keys().all(func(k): return (k - main.MAP_SIZE / 2).length() >= main.CLEARING[0]), "niente massiccio nella radura")
	check(main.ores.values().has(main.Res.IRON) and main.ores.values().has(main.Res.COAL), "ci sono vene di ferro e di carbone")
	for cell in main.ores:
		check(main.boulders.get(cell) == Vector2i.ONE or main.massif.has(cell), "ogni vena è un masso da una casella, o una casella del massiccio")
	for res in [main.Res.IRON, main.Res.COAL]:
		check(main.ores.keys().filter(func(k): return main.ores[k] == res and main.vein_shows(k)).size() >= main.ORE_SHOWING, "vene in vista all'inizio")
	var hidden: Array = main.ores.keys().filter(func(k): return not main.vein_shows(k))
	check(not hidden.is_empty() and hidden.all(func(k): return main.massif.has(k) and main.SIDES.all(func(d): return main.rocks.has(k + d) or not main.astar.is_in_boundsv(k + d))),
		"le vene chiuse nel massiccio non si vedono")
	check(main.describe(hidden[0]) == ["Rock", "Stone left: 5 / 5"], "una vena nascosta si legge come roccia")
	var sheet: Image = main.MASSIF.get_image()
	check(sheet.get_size() == Vector2i(4, 5) * main.TILE, "il foglio del massiccio: cima, lati, angoli, vene, macerie e crepe")
	var inside: Array = main.massif.keys().filter(func(k): return (main.EDGE_SIDES + main.EDGE_CORNERS).all(func(d): return main.massif.has(k + d)) and not main.ores.has(k))
	var face: Array = main.massif.keys().filter(func(k): return not main.rocks.has(k + Vector2i.DOWN) and main.astar.is_in_boundsv(k + Vector2i.DOWN))
	check(main.rock_images[0].get_pixelv(inside[0] * main.TILE + Vector2i(8, 15)) != main.rock_images[0].get_pixelv(face[0] * main.TILE + Vector2i(8, 15)),
		"dove sotto è aperto il massiccio mostra la parete")
	check(main.rock_images[0].get_pixelv(main.boulders.keys()[0] * main.TILE + Vector2i(8, 8)).a == 0.0, "fuori dal massiccio niente: i massi li disegna _draw")
	check(main.stockpile.is_empty() and main.rooms.is_empty(), "niente magazzino all'inizio")

	# i segni sono contorni: ogni foglio dei contorni ha un riquadro per sprite, un pixel più largo per lato
	for pair in [[main.TREES, main.TREES_OUTLINE, Vector2(1, 2) * main.TILE], [main.PLANTS, main.PLANTS_OUTLINE, Vector2.ONE * main.TILE],
			[main.ANIMALS, main.ANIMALS_OUTLINE, Vector2.ONE * main.TILE]]:
		var tiles: Vector2 = (pair[0].get_size() / pair[2]).round()
		check(pair[1].get_size() == tiles * (pair[2] + Vector2(2, 2)), "il foglio dei contorni ha un riquadro per sprite")
	for cell in main.boulders:
		var rock: Texture2D = main.boulder_tex(cell)
		check(main.ROCK_OUTLINES.has(rock) and main.ROCK_OUTLINES[rock].get_size() == rock.get_size() + Vector2(2, 2), "ogni masso ha il suo contorno")
	check(main.ORDER_COLORS[main.Order.UPROOT].h > 0.1 and main.ORDER_COLORS[main.Order.UPROOT].h < 0.2, "estirpare è giallo: sul prato si vede")

	check(main.water.values().has(main.Ground.DEEP) and main.water.values().has(main.Ground.SHALLOW), "ci sono laghi")
	for cell in main.water:
		check(not main.rocks.has(cell) and not main.trees.has(cell), "niente rocce né alberi in acqua")
		check(main.astar.is_point_solid(cell) == (main.water[cell] == main.Ground.DEEP), "solo l'acqua alta blocca")
		if main.water[cell] == main.Ground.DEEP:
			for d in main.EDGE_SIDES + main.EDGE_CORNERS:
				check(main.water.has(cell + d), "l'acqua alta non tocca la riva")
	# l'erba sopra una casella di ghiaia sborda dal lato giusto: la riga in cima diventa erba
	var edged: Array = main.rocks.keys().filter(func(c): return c.y > 0 and main.ground_of(c + Vector2i.UP) == main.Ground.GRASS)
	var top: Color = main.ground_texture.get_image().get_pixelv(edged[0] * main.TILE + Vector2i(8, 0))
	check(top.is_equal_approx(Color("4a7a3a")), "bordo d'erba sulla ghiaia")

	check(not main.bushes.is_empty() and not main.weeds.is_empty(), "ci sono cespugli ed erbacce")
	for cell in main.bushes.keys() + main.weeds.keys():
		check(not main.rocks.has(cell) and not main.water.has(cell) and not main.trees.has(cell), "piante solo sul prato")
	check(main.bushes.values().all(func(t): return t <= main.clock), "bacche mature fin dall'inizio")
	check(not main.flax.is_empty() and main.flax.keys().all(func(k): return main.bushes.has(k)), "c'è il lino, in mezzo ai cespugli")
	main.bushes.clear()  # la fase 10 ne rimette uno
	main.flax.clear()
	main.weeds.clear()

	var W: int = main.Res.WOOD
	var S: int = main.Res.STONE
	var trees_before: int = main.trees.size()
	var rocks_before: int = main.rocks.size()
	var area := Rect2i(main.MAP_SIZE / 2 - Vector2i(12, 12), Vector2i(24, 24))  # fino al bordo della radura, tra alberi e massi

	# fase 1: taglio; senza magazzino la legna resta dove cade l'albero
	main.order = main.Order.CHOP
	main.mark(area)
	var marked: int = main.chop_marks.size()
	check(marked > 0, "ci sono alberi segnati vicino alla partenza")
	for c in main.colonists:  # un colpo ogni 5 secondi, se no il taglio dura troppo
		c.skills[main.Skill.WOODCUTTING] = main.SKILL_MAX
	var wood: int = main.chop_marks.keys().reduce(func(sum, k): return sum + main.full_stock(k), 0)
	var swings: int = main.chop_marks.keys().reduce(func(sum, k): return sum + ceili(main.full_stock(k) / 5.0), 0)
	for i in 20000:  # 1000 secondi simulati
		main.tick(0.05)
		check_work(main)
	var chopped: int = trees_before - main.trees.size()
	check(chopped == marked, "tagliati tutti gli alberi segnati")
	check(main.total(W) == wood, "nessuna legna persa o creata")
	var chop_xp: float = main.colonists.reduce(func(sum, c): return sum + c.xp[main.Skill.WOODCUTTING], 0.0)
	check(absf(chop_xp - swings * 10.0 * main.XP_PER_SECOND) < 0.01, "esperienza a ogni colpo d'ascia, in proporzione: %.2f" % chop_xp)
	check(main.stored(W) == 0, "senza magazzino non si trasporta niente")
	for c in main.colonists:
		check(c.job == main.Job.NONE, "coloni liberi a fine lavoro")
	check(main.reserved.is_empty(), "nessuna prenotazione rimasta")

	# fase 2: stanza di legno con la porta, costruita con la legna presa dai mucchi a terra
	var room := find_room(main, area)
	check(room.size != Vector2i.ZERO, "c'è posto per una stanza")
	main.order = main.Order.BUILD
	main.build_kind = main.Build.WALL
	main.build_res = W
	main.mark(room)
	# in mezzo a un muro che dà su una casella libera: sotto, sopra, a sinistra o a destra
	var sides := [[Vector2i(room.position.x + 2, room.end.y - 1), Vector2i.DOWN], [Vector2i(room.position.x + 2, room.position.y), Vector2i.UP],
		[Vector2i(room.position.x, room.position.y + 1), Vector2i.LEFT], [Vector2i(room.end.x - 1, room.position.y + 1), Vector2i.RIGHT]]
	var exit: Array = sides.filter(func(s): return main.can_build(s[0] + s[1]))[0]
	var entrance: Vector2i = exit[0]
	main.build_kind = main.Build.DOOR
	main.mark(Rect2i(entrance, Vector2i.ONE))
	check(main.draft[entrance][0] == main.Build.DOOR, "la porta prende il posto del muro nel progetto")
	for i in 200:
		main.tick(0.05)
	check(main.draft.size() == 14 and main.built.is_empty() and main.reserved.is_empty(), "il progetto aspetta la conferma")
	main.confirm_build()
	check(main.draft.is_empty() and main.blueprints.size() == 14, "confermato: diventa lavoro")
	for i in 4000:
		main.tick(0.05)
		check_work(main)
	check(main.blueprints.is_empty() and main.built[entrance] == [main.Build.DOOR, W], "stanza e porta di legno costruite")
	check(main.total(W) == wood - 14 * main.BUILD_COST[main.Build.WALL], "muri e porta consumano la legna")
	check(not main.astar.is_point_solid(entrance) and main.astar.is_point_solid(room.position), "dalla porta si passa, dai muri no")
	var facing := 1 if exit[1].x != 0 else 0  # nei muri di lato si vede dall'alto
	check(main.structure_src(entrance, main.built[entrance], [main.built]).position == Vector2i(facing * main.TILE, 48), "porta di fronte o di lato secondo il muro")
	var corner: Rect2i = main.structure_src(room.position, main.built[room.position], [main.built])
	check(corner.position == Vector2i(2 | 4, W) * main.TILE, "l'angolo in alto a sinistra si collega a destra e in giù")

	# la stanza è finita: chiusa, murata, con la porta; il cartello sta fuori davanti alla porta
	check(main.rooms.size() == 1, "stanza riconosciuta")
	var r = main.rooms[0]
	var across := Vector2i(absi(exit[1].y), absi(exit[1].x))
	check(r.door == entrance and r.sign in [entrance + across, entrance - across] and main.built[r.sign][0] == main.Build.WALL,
		"cartello sul muro accanto alla porta")
	check(r.cells.size() == 6 and r.cells.has(room.position + Vector2i(2, 1)), "dentro ci sono le 3x2 caselle")
	check(main.roofed.size() == room.size.x * room.size.y and main.roofed.has(room.position) and main.roofs.size() == 1
		and main.roofed[entrance].rect == room and main.roofed[entrance].look["along_x"]
		and main.roofed[entrance].look["base"] == room.end.y * main.TILE,
		"un tetto su stanza, muri e porta, col colmo sul lato lungo e la facciata sul muro in fondo")
	check(main.roofed[entrance].material == W, "muri di legno: tetto di scandole")
	var someone = main.colonists[0]  # chi passa dietro la casa si vede da un buco nel tetto; dentro solo il colono scelto
	var someone_was: Vector2 = someone.pos
	var house = main.roofs[0]
	someone.pos = main.center(Vector2i(room.position.x + 2, room.position.y - 1))
	check(main.roof_holes([someone]).has(house), "dietro la casa si vede da un buco nel tetto")
	someone.pos = main.center(room.position + Vector2i(1, 1))
	check(main.roof_holes([someone]).is_empty(), "dentro la casa non si vede")
	main.open_sheet(someone)
	check(main.roof_holes([someone]).has(house), "dentro la casa si vede se è il colono scelto")
	main.sheet_panel.hide()
	someone.pos = someone_was
	check(r.name == "Structure1" and r.kind == main.RoomKind.NONE, "nome e tipo di default")

	# fase 3: dal cartello diventa un magazzino, e i coloni ci portano la legna
	main.open_room(r)
	main.room_name.text_changed.emit("Deposito")
	main.room_kind.item_selected.emit(main.room_kind.get_item_index(main.RoomKind.WAREHOUSE))
	check(r.name == "Deposito" and r.kind == main.RoomKind.WAREHOUSE, "il popup cambia nome e tipo")
	check(main.room_class(r) == main.RoomClass.SERVICE and not main.get_node("HUD/RoomPopup/Box/Owners").visible,
		"il magazzino è una stanza di servizio: niente proprietari né lavoratori")
	check(main.stockpile.size() == 6, "le caselle della stanza diventano magazzino")
	for i in 10000:
		main.tick(0.05)
		check_work(main)
	check(main.stored(W) > 0, "legna portata in magazzino")
	check(main.total(W) - main.stored(W) == 0 or main.dest_cells(W).is_empty(), "trasportata finché c'è posto")

	# fase 4: scavo
	main.order = main.Order.MINE
	main.mark(area)
	var boulders_marked: int = main.mine_marks.size()
	var blows: int = main.mine_marks.keys().reduce(func(sum, k): return sum + ceili(main.full_stock(k) / 5.0), 0)
	check(boulders_marked > 0, "ci sono massi segnati vicino alla partenza")
	for c in main.colonists:  # da livello 0 un colpo ogni 22,5 secondi: troppo lento per la prova
		c.skills[main.Skill.MINING] = main.SKILL_MAX
	for i in 10000:
		main.tick(0.05)
		check_work(main)
	var mined: int = rocks_before - main.rocks.size()
	check(mined > 0 and main.mine_marks.is_empty(), "scavati tutti i massi segnati")
	var mine_xp: float = main.colonists.reduce(func(sum, c): return sum + c.xp[main.Skill.MINING], 0.0)
	check(absf(mine_xp - blows * 15.0 * main.XP_PER_SECOND) < 0.01, "esperienza a ogni colpo di piccone: %.2f" % mine_xp)
	for cell in main.boulders:
		for k in main.boulder_cells(cell):
			check(main.astar.is_point_solid(k), "roccia rimasta ancora solida")
	for cell in main.rocks:
		check(main.astar.is_point_solid(cell), "ogni roccia è solida")
	var rock_res := [S, main.Res.IRON, main.Res.COAL]  # le vene vicino alla partenza danno ferro o carbone invece della pietra
	check(rock_res.reduce(func(sum, r): return sum + main.total(r), 0) == mined * main.STONE_PER_CELL, "nessuna pietra persa o creata")
	for res in [W] + rock_res:
		check(main.total(res) - main.stored(res) == 0 or main.dest_cells(res).is_empty(), "trasportata finché c'è posto")
	for cell in main.stockpile:
		check(main.items[W].get(cell, 0) <= main.STACK_MAX[W] and main.items[S].get(cell, 0) <= main.STACK_MAX[S], "nessuna pila oltre il limite")
		check(not (main.items[W].has(cell) and main.items[S].has(cell)), "una sola risorsa per cella")
	for c in main.colonists:
		check(c.job == main.Job.NONE, "coloni liberi a fine lavoro")
	check(main.reserved.is_empty(), "nessuna prenotazione rimasta")

	# una vena di ferro in mezzo al prato (nessun vicino costruito, così non chiude niente): scavata dà ferro, non pietra
	var vein: Vector2i = main.cells_in(area).filter(func(k): return main.SIDES.all(func(s): return main.can_build(k + s)) \
		and main.can_build(k) and main.colonists.all(func(o): return main.cell_of(o.pos) != k))[0]
	main.rocks[vein] = true
	main.boulders[vein] = Vector2i.ONE
	main.ores[vein] = main.Res.IRON
	main.astar.set_point_solid(vein)
	check(main.describe(vein) == ["Iron vein", "Iron left: 5 / 5"], "finestra della vena")
	var iron_before: int = main.total(main.Res.IRON)
	var stone_before: int = main.total(S)
	main.order = main.Order.MINE
	main.mark(Rect2i(vein, Vector2i.ONE))
	for i in 2000:
		main.tick(0.05)
		check_work(main)
	check(not main.ores.has(vein) and not main.boulders.has(vein), "vena scavata")
	check(main.total(main.Res.IRON) == iron_before + main.STONE_PER_CELL and main.total(S) == stone_before, "dà ferro, niente pietra")

	# il massiccio si scava una casella per volta, da dove ci si arriva verso dentro: un blocco 3x3 in mezzo al prato,
	# con una vena nel mezzo che non si vede finché lo scavo non la scopre
	var bare := func(k): return main.can_build(k) and main.colonists.all(func(o): return main.cell_of(o.pos) != k) \
		and main.items.values().all(func(heap): return not heap.has(k))
	vein = main.cells_in(area).filter(func(k): return main.cells_in(Rect2i(k - Vector2i(2, 2), Vector2i(5, 5))).all(bare))[0]
	var block := Rect2i(vein - Vector2i.ONE, Vector2i(3, 3))
	for k in main.cells_in(block):
		main.rocks[k] = true
		main.massif[k] = true
		main.astar.set_point_solid(k)
	main.ores[vein] = main.Res.COAL
	for k in main.cells_in(block):
		main.redraw_rock(k)
	check(not main.vein_shows(vein) and main.describe(vein)[0] == "Rock", "la vena in mezzo non si vede")
	var rock_px: Color = main.rock_images[0].get_pixelv(vein * main.TILE + Vector2i(8, 8))
	main.mark(Rect2i(vein + Vector2i.LEFT, Vector2i(2, 1)))  # la casella sul bordo e quella in mezzo
	check(main.mine_marks.size() == 2 and main.mine_marks.has(vein), "il massiccio si segna a caselle")
	check(main.full_stock(vein) == main.STONE_PER_CELL, "ogni casella ha la sua pietra")
	var digger = main.colonists[0]
	check(main.find_work(digger) and digger.target == vein + Vector2i.LEFT, "si comincia da dove ci si arriva")
	main.quit_job(digger)
	var coal_before: int = main.total(main.Res.COAL)
	stone_before = main.total(S)
	var seen_vein := false
	for i in 3000:
		main.tick(0.05)
		check_work(main)
		if not main.rocks.has(vein + Vector2i.LEFT) and main.rocks.has(vein) and not seen_vein:
			seen_vein = true
			check(main.vein_shows(vein) and main.describe(vein) == ["Coal vein", "Coal left: 5 / 5\nMarked: mine"], "scavando accanto la vena si scopre")
			check(main.rock_images[0].get_pixelv(vein * main.TILE + Vector2i(8, 8)) != rock_px \
				or main.rock_images[0].get_region(Rect2i(vein * main.TILE, Vector2i.ONE * main.TILE)).get_data() != main.rock_images[0].get_region(Rect2i((vein + Vector2i.UP) * main.TILE, Vector2i.ONE * main.TILE)).get_data(),
				"e si disegna")
	check(seen_vein and main.mine_marks.is_empty(), "scavate le due caselle, la seconda dopo la prima")
	check(not main.rocks.has(vein) and main.massif.has(vein) and not main.astar.is_point_solid(vein), "la casella scavata è una galleria: ci si passa")
	check(main.rock_images[0].get_pixelv(vein * main.TILE + Vector2i(8, 8)).a == 0.0, "scavata, il massiccio lì non si disegna più")
	check(main.total(main.Res.COAL) == coal_before + main.STONE_PER_CELL and main.total(S) == stone_before + main.STONE_PER_CELL, "una casella di pietra, una di carbone")
	check(main.cells_in(block).filter(func(k): return main.rocks.has(k)).size() == 7 and main.solid_massif(vein + Vector2i.UP), "il resto del blocco è ancora roccia")
	for k in main.cells_in(block):  # via il blocco: il resto delle prove vuole il prato
		main.rocks.erase(k)
		main.massif.erase(k)
		main.astar.set_point_solid(k, false)
		main.redraw_rock(k)

	# fase 5: un muro di legno e un pavimento di pietra, col materiale preso dal magazzino o da terra
	var spots := []
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if main.can_build(Vector2i(x, y)):
				spots.append(Vector2i(x, y))
	check(spots.size() >= 2, "c'è posto per costruire")
	var wood_left: int = main.total(W)
	var stone_left: int = main.total(S)
	main.order = main.Order.BUILD
	main.build_kind = main.Build.WALL
	main.build_res = W
	main.mark(Rect2i(spots[0], Vector2i.ONE))
	main.build_kind = main.Build.FLOOR
	main.build_res = S
	main.mark(Rect2i(spots[1], Vector2i.ONE))
	main.confirm_build()
	for i in 2000:
		main.tick(0.05)
		check_work(main)
	check(main.blueprints.is_empty(), "costruiti tutti i progetti")
	check(main.built[spots[0]] == [main.Build.WALL, W] and main.astar.is_point_solid(spots[0]), "muro di legno solido")
	check(main.built[spots[1]] == [main.Build.FLOOR, S] and not main.astar.is_point_solid(spots[1]), "pavimento calpestabile")
	check(main.total(W) == wood_left - main.BUILD_COST[main.Build.WALL], "il muro consuma la legna")
	check(main.total(S) == stone_left - main.BUILD_COST[main.Build.FLOOR], "il pavimento consuma la pietra")
	for c in main.colonists:
		check(c.job == main.Job.NONE and not main.astar.is_point_solid(main.cell_of(c.pos)), "nessuno murato")
	check(main.reserved.is_empty(), "nessuna prenotazione rimasta dopo la costruzione")

	# fase 6: la X cancella il progetto e i lavori già confermati; chi portava il materiale lo lascia a terra
	var free: Array = spots.filter(func(k): return main.can_build(k))
	var wood_now: int = main.total(W)
	main.order = main.Order.BUILD
	main.build_kind = main.Build.WALL
	main.build_res = W
	main.mark(Rect2i(free[0], Vector2i.ONE))
	main.confirm_build()
	main.mark(Rect2i(free[1], Vector2i.ONE))  # questo resta da confermare
	var carried := func(): return main.colonists.any(func(o): return o.job == main.Job.BUILD and o.carrying > 0)
	for i in 400:  # finché il costruttore ha preso il materiale
		main.tick(0.05)
		if carried.call():
			break
	check(carried.call() and main.reserved.has(free[0]), "il lavoro confermato è stato preso, col materiale in mano")
	main.order = main.Order.ERASE
	main.mark(Rect2i(free[0], Vector2i(2, 2)))
	main.mark(Rect2i(free[1], Vector2i.ONE))
	check(main.draft.is_empty() and main.blueprints.is_empty() and main.reserved.is_empty(), "la X cancella progetto e lavori")
	check(main.total(W) == wood_now, "il materiale del lavoro cancellato non si perde")

	# fase 7: una stanza senza porta col pavimento dentro: nessuno ci resta chiuso
	var closed := find_room(main, area)
	check(closed.size != Vector2i.ZERO, "c'è posto per una stanza chiusa")
	main.order = main.Order.BUILD
	main.build_res = W
	main.build_kind = main.Build.WALL
	main.mark(closed)
	main.build_kind = main.Build.FLOOR
	main.mark(closed.grow(-1))
	main.confirm_build()
	for i in 4000:
		main.tick(0.05)
		check_work(main)
	check(main.blueprints.is_empty(), "stanza finita, pavimento compreso")
	check(main.rooms.size() == 1, "senza porta non è una struttura")
	for c in main.colonists:
		check(main.flood(main.cell_of(c.pos), false).size() >= main.ROOM_MAX, "nessuno chiuso nella stanza")

	# fase 8: "Destroy" abbatte un muro del magazzino: niente più stanza, niente più magazzino
	main.order = main.Order.DEMOLISH
	main.mark(Rect2i(room.position, Vector2i.ONE))  # l'angolo tocca l'interno solo in diagonale: resta chiusa
	check(not main.built.has(room.position) and main.rooms.size() == 1, "abbattuto l'angolo, la stanza resta")
	# un muro a metà lato che dà fuori su una casella libera: abbattuto, apre la stanza
	var gap: Vector2i = sides.filter(func(s): return s[0] != entrance and not main.astar.is_point_solid(s[0] + s[1]))[0][0]
	main.mark(Rect2i(gap, Vector2i.ONE))
	check(not main.built.has(gap) and not main.astar.is_point_solid(gap), "muro abbattuto, ci si passa")
	check(main.rooms.is_empty() and main.stockpile.is_empty() and main.roofed.is_empty(),
		"stanza aperta: niente cartello, magazzino né tetto")

	# fase 9: un letto girato con E (tre quarti a sinistra = uno a destra) sopra un pavimento in progetto
	var at := Vector2i(-1, -1)  # due caselle libere una sopra l'altra
	for k in main.cells_in(area):
		if main.can_build(k) and main.can_build(k + Vector2i.DOWN):
			at = k
			break
	check(at != Vector2i(-1, -1), "c'è posto per un letto")
	main.order = main.Order.BUILD
	main.build_kind = main.Build.FLOOR
	main.build_res = W
	main.mark(Rect2i(at, Vector2i(1, 2)))
	main.build_button.button_pressed = true  # tasto "Build": sopra compaiono le categorie, ancora nessuna aperta
	main.update_plate()
	check(main.categories.visible and not main.build_bar.visible and not main.furniture_bar.visible and main.actions.visible,
		"Build apre le categorie, senza barre; in alto la targa del progetto")
	main.structures_button.button_pressed = true
	check(main.build_bar.visible, "categoria Structures: la sua barra")
	main.get_node("HUD/BuildBar/Row/Wall").button_pressed = true
	var home: Button = main.get_node("HUD/Categories/Row/Home")
	var crafts: Button = main.get_node("HUD/Categories/Row/Crafts")
	home.button_pressed = true  # categoria "Home": la barra dei mobili al posto di quella delle strutture, col solo gruppo di casa
	var groups: Array = main.FURNITURE_GROUPS.map(func(g): return main.furniture_bar.get_node("Row/" + g))
	check(main.furniture_bar.visible and not main.build_bar.visible, "barra dei mobili")
	check(not main.structures_button.button_pressed, "una categoria alla volta")
	check(groups.filter(func(g): return g.visible) == [groups[0]] and main.kind_buttons[main.Build.BED].is_visible_in_tree()
		and not main.kind_buttons[main.Build.ANVIL].is_visible_in_tree(), "solo i mobili di casa")
	crafts.button_pressed = true
	check(main.furniture_bar.visible and not home.button_pressed and groups.filter(func(g): return g.visible) == [groups[2]]
		and main.kind_buttons[main.Build.ANVIL].is_visible_in_tree(), "Crafts: i mestieri al posto della casa")
	var widest := 0.0
	for g in groups:  # ogni gruppo, con tutte le ricerche fatte, sta in 1280 pixel
		widest = maxf(widest, g.get_combined_minimum_size().x)
	check(widest + 200 < 1280, "il gruppo più largo sta nello schermo: %d pixel" % widest)
	home.button_pressed = true
	check(main.draft.has(at) and main.draft.has(at + Vector2i.DOWN), "cambiando barra il pavimento in progetto resta")
	check(main.order == main.Order.NONE and main.kind_group.get_pressed_button() == null, "il muro scelto prima qui non vale")
	main.choose_kind(main.Build.ANVIL)
	check(main.build_res == main.Res.IRON and tip_text(main, "FurnitureBar/Row/Crafts/Anvil").begins_with("Anvil\n") and tip_text(main, "FurnitureBar/Row/Crafts/Anvil").contains("Cost: 10 Iron "), "incudine: solo di ferro")
	main.choose_kind(main.Build.BED)
	check(main.order == main.Order.BUILD and main.build_res == W, "letto: solo di legno")
	check(tip_text(main, "FurnitureBar/Row/Home/Bed").begins_with("Bed\n" + main.BUILD_INFO[main.Build.BED] + "\n\nCost: 10 Wood  2x1\n+1 room Comfort"),
		"suggerimento: nome, descrizione, costo, comfort (%s)" % tip_text(main, "FurnitureBar/Row/Home/Bed"))
	check(tip_text(main, "BuildBar/Row/Wall").contains("Cost: 5 Wood or 5 Stone a tile"), "muro: legno o pietra, per casella")
	for i in 3:
		main.turn(-1)
	check(main.build_turn == 1, "tre quarti a sinistra sono uno a destra")
	main.mark(Rect2i(at, Vector2i.ONE))
	var bed := [main.Build.BED, W, 1]
	check(main.furniture_draft.get(at) == bed, "letto girato nel progetto, sopra il pavimento")
	for kind in [main.Build.WALL, main.Build.LAMP]:
		check(not main.can_build(at + Vector2i.DOWN, kind), "girato, il letto prende la casella sotto: niente muri né mobili")
	check(main.can_build(at + Vector2i.DOWN), "ma il pavimento sì")
	main.drop(W, main.cell_of(main.colonists[0].pos), 90)  # legna per i mobili: vicino alla partenza ora c'è anche la montagna, e meno alberi
	var wood_bed: int = main.total(W)
	main.confirm_build()
	check(main.furniture_draft.is_empty() and main.furniture_plans.get(at) == bed, "confermato: il letto diventa lavoro")
	for i in 2000:
		main.tick(0.05)
		check_work(main)
	check(main.furniture.get(at) == bed and main.furniture_plans.is_empty(), "letto costruito")
	check(main.built.get(at + Vector2i.DOWN, [-1]) == [main.Build.FLOOR, W], "col pavimento sotto")
	check(main.total(W) == wood_bed - 2 * main.BUILD_COST[main.Build.FLOOR] - main.BUILD_COST[main.Build.BED], "letto e pavimento consumano la legna")
	check(not main.astar.is_point_solid(at), "sul letto si passa")
	main.order = main.Order.DEMOLISH
	main.mark(Rect2i(at + Vector2i.DOWN, Vector2i.ONE))
	check(main.furniture.is_empty(), "Destroy toglie anche i mobili")
	# abat-jour: 2 legna e 1 carbone, un viaggio per materiale; quello già portato aspetta al cantiere
	check(tip_text(main, "FurnitureBar/Row/Home/Lamp").contains("Cost: 2 Wood, 1 Coal"), "abat-jour: legna e carbone")
	var C: int = main.Res.COAL
	main.drop(C, at + Vector2i(0, 3), 3)
	var lamp := [main.Build.LAMP, W, 0]
	var wood_lamp: int = main.total(W)
	var coal_lamp: int = main.total(C)
	main.furniture_plans[at] = lamp
	var halfway := false
	for i in 2000:
		main.tick(0.05)
		check_work(main)
		halfway = halfway or main.delivered.get([main.Job.FURNISH, at], {}).size() == 1
		if main.furniture.has(at):
			break
	check(halfway and main.furniture.get(at) == lamp and main.delivered.is_empty(), "abat-jour fatto in due viaggi")
	check(main.total(W) == wood_lamp - 2 and main.total(C) == coal_lamp - 1, "consuma 2 legna e 1 carbone")
	main.furniture.erase(at)
	main.furniture_plans[at] = lamp  # di nuovo, e annullato appena portato il primo materiale: torna a terra
	for i in 2000:
		main.tick(0.05)
		if not main.delivered.is_empty():
			break
	var lamp_got: Dictionary = main.delivered.get([main.Job.FURNISH, at], {})
	check(lamp_got.size() == 1, "un materiale al cantiere")
	var lamp_res: int = lamp_got.keys()[0]
	var lamp_before: int = main.items[lamp_res].get(at, 0)
	main.erase_plan(at)
	check(main.delivered.is_empty() and main.furniture_plans.is_empty() and main.items[lamp_res].get(at, 0) == lamp_before + lamp_got[lamp_res],
		"annullato: il materiale portato torna a terra")
	main.items[lamp_res].erase(at)  # via, che qui sotto si costruisce ancora
	main.items[C].erase(at + Vector2i(0, 3))
	# fuoco da campo: quinta riga del foglio; al posto dei quarti di giro, le colonne sono i fotogrammi della fiamma
	check(tip_text(main, "FurnitureBar/Row/Fire/Campfire").contains("Cost: 5 Wood "), "tasto del fuoco da campo")
	var fire := [main.Build.CAMPFIRE, W, 0]
	var flame: Rect2 = main.piece_rects(at, fire)[1]
	main.clock += 1.5 * main.ANIMATED[main.Build.CAMPFIRE] / main.DAY_LENGTH
	check(flame.position.y == 4 * 32 and main.piece_rects(at, fire)[1].position.x != flame.position.x, "la fiamma guizza")
	# sentiero: un pavimento di pietra a 1 per casella; ci stanno i mobili, l'erba ci sborda sopra ma non dai muri
	check(tip_text(main, "BuildBar/Row/Path").contains("Cost: 1 Stone a tile"), "tasto del sentiero")
	main.built[at] = [main.Build.PATH, main.Res.STONE]
	check(main.can_build(at, main.Build.LAMP) and not main.can_build(at, main.Build.FLOOR), "mobili sul sentiero")
	check(main.structure_src(at, main.built[at], [main.built]) == main.tile_rect(2, 2), "sentiero nel foglio")
	main.built[at + Vector2i.RIGHT] = [main.Build.WALL, W]
	check(main.is_lawn(at + Vector2i.UP) and not main.is_lawn(at + Vector2i.RIGHT), "erba dal prato, non dal muro")
	main.built.erase(at)
	main.built.erase(at + Vector2i.RIGHT)
	# decorazioni: ognuna col suo tasto e il suo splendore; la panca girata sta in piedi, fontana e stendardo si muovono
	for kind in main.SPLENDOR:
		check(main.FURNITURE.has(kind) and main.BUILD_INFO.has(kind), "decorazione %s" % main.Build.keys()[kind])
	check(tip_text(main, "FurnitureBar/Row/Decor/Statue").contains("Cost: 40 Stone "), "tasto della statua")
	check(main.piece_rect(at, [main.Build.BENCH, W, 1]).size == Vector2i(1, 2), "panca girata in verticale")
	var water: Rect2 = main.piece_rects(at, [main.Build.FOUNTAIN, main.Res.STONE, 0])[1]
	main.clock += 1.5 * main.ANIMATED[main.Build.FOUNTAIN] / main.DAY_LENGTH
	check(main.piece_rects(at, [main.Build.FOUNTAIN, main.Res.STONE, 0])[1].position.x != water.position.x, "la fontana zampilla")
	check(main.colony_splendor() == 0, "niente splendore senza decorazioni")
	# lo splendore conta solo nella colonia (qui vicino alle stanze, e lungo un sentiero)
	main.furniture[at] = [main.Build.STATUE, main.Res.STONE, 0]
	var lane: Array = range(-1, 13).map(func(i): return at + Vector2i(i, -2))
	for k in lane:
		main.built[k] = [main.Build.PATH, main.Res.STONE]
	check(main.colony_splendor() == 8 and main.describe(at)[1] == "+8 colony splendor", "nella colonia sì")
	main.furniture[at + Vector2i(3, 0)] = [main.Build.FLOWER_BED, W, 0]
	check(main.colony_splendor() == main.SPLENDOR[main.Build.STATUE] + main.SPLENDOR[main.Build.FLOWER_BED], "splendore sommato")
	# un'aiuola dà splendore solo senza un'altra entro 4 caselle che già lo dà (vale la più vecchia)
	main.furniture[at + Vector2i(5, 0)] = [main.Build.FLOWER_BED, W, 0]
	check(main.colony_splendor() == 9 and main.describe(at + Vector2i(5, 0))[1] == "No splendor: another flower bed within 4 tiles",
		"un'aiuola troppo vicina: niente")
	main.furniture[at + Vector2i(8, 0)] = [main.Build.FLOWER_BED, W, 0]
	check(main.colony_splendor() == 10, "a 5 caselle sì")
	# lo stendardo conta una volta sola: il primo +2, gli altri niente
	main.furniture[at + Vector2i(10, 0)] = [main.Build.BANNER, W, 0]
	main.furniture[at + Vector2i(11, 0)] = [main.Build.BANNER, W, 0]
	main.furniture[at + Vector2i(12, 0)] = [main.Build.BANNER, W, 0]
	check(main.colony_splendor() == 12 and main.describe(at + Vector2i(12, 0))[1] == "No splendor: only the first one counts",
		"lo stendardo: +2, solo il primo")
	for k in lane:
		main.built.erase(k)
	main.furniture.clear()
	# dentro la palizzata conta anche lontano dai sentieri
	var pen: Array = main.cells_in(Rect2i(3, 3, 9, 9)).filter(func(k): return k.x in [3, 11] or k.y in [3, 11])
	main.furniture[Vector2i(7, 7)] = [main.Build.FLOWER_BED, W, 0]
	check(main.colony_splendor() == 0 and main.decor_about(Vector2i(7, 7)).begins_with("No splendor: outside the colony"),
		"nel prato, lontano da tutto, niente")
	for k in pen:
		main.built[k] = [main.Build.PALISADE, W]
	check(main.colony_splendor() == 1, "dentro la palizzata sì")
	for k in pen:
		main.built.erase(k)
	main.furniture.clear()

	var c = main.colonists[0]
	c.pos = main.center(main.cells_in(area).filter(func(k): return main.can_build(k) and main.can_build(k + Vector2i.LEFT))[0])
	c.job = main.Job.HAUL  # finto lavoro: deve solo camminare, verso una casella libera
	c.path.assign([main.cell_of(c.pos) + Vector2i.LEFT])
	main.tick(0.05)
	check(c.facing == main.Facing.LEFT and c.walked > 0, "guarda e cammina verso sinistra")

	main.clock = 3 + 8.0 / 24
	check(main.sun_height() > 0, "di mattina il sole è su")
	main.clock = 3 + 16.0 / 24
	check(main.sun_height() > 0, "e di pomeriggio pure")
	# ombre col sole a picco: un ovale netto sotto i piedi, centrato, che non cambia con l'ora
	var blob: Array = main.blob(Vector2i(20, 30), 10)
	check(blob == [Rect2i(16, 29, 8, 1), Rect2i(15, 30, 10, 1), Rect2i(16, 31, 8, 1)], "ovale d'ombra di 10x3 pixel")
	check(main.foot_of(main.COLONIST_BASE, Rect2(0, 0, 16, 16)) == 16, "i coloni toccano terra sull'ultima riga")
	check(main.foot_of(main.ANIMALS, Rect2(0, 0, 16, 16)) == 15, "il coniglio una riga più su")
	# alberi: tronco fino alla riga 28 del foglio 16x32, sotto solo l'ombra semitrasparente della chioma
	check(main.foot_of(main.TREES, Rect2(0, 0, 16, 32)) == 29, "l'ombra della chioma non conta come tronco")
	main.clock = 3 + 23.0 / 24
	check(main.sun_height() < 0, "di notte niente sole")
	check(main.shadows.visible and main.shadows.self_modulate == main.SHADOW, "le ombre restano uguali anche di notte")
	var lazy = main.Colonist.new()  # senza lavoro né strada: respira
	lazy.idle = main.BREATH_TIME * 0.9
	check(main.frame_of(lazy) == 5 and main.COLONIST_BASE.get_width() == 8 * main.TILE, "chi non fa nulla respira")
	lazy.idle = 0.0
	check(main.frame_of(lazy) == 0, "il respiro parte da fermo")
	main.end_job(c)  # via il finto trasporto di prima: non ha un mucchio vero
	var turns := 0
	for i in 600:  # 30 secondi
		var before: Array = main.colonists.map(func(o): return o.facing)
		main.tick(0.05)
		for k in main.colonists.size():
			var o = main.colonists[k]
			if o.idle > 0.05 and o.facing != before[k]:  # fermo già da prima: si è girato da solo
				turns += 1
	check(turns > 0, "chi non fa nulla si guarda attorno")

	# fase 10: un cespuglio e un'erbaccia; chi non ha ordini non raccoglie le bacche, neanche col magazzino
	var V: int = main.Res.VEG
	var free_cells: Array = main.cells_in(area).filter(func(k): return main.can_build(k))
	check(free_cells.size() >= 4, "c'è posto per le piante")
	var bush: Vector2i = free_cells[0]
	var weed: Vector2i = free_cells[1]
	main.bushes[bush] = main.clock
	main.weeds[weed] = true
	check(not main.can_build(bush) and not main.can_build(weed), "sulle piante non si costruisce")
	for i in 400:
		main.tick(0.05)
	check(main.ripe_bushes() == [bush] and main.total(V) == 0, "senza magazzino le bacche restano sul cespuglio")
	# magazzino finto, lontano dalle piante, con già una bacca per cella: la legna e la pietra rimaste a terra non ci vanno
	main.stockpile = {free_cells[-1]: true, free_cells[-2]: true}
	for cell in main.stockpile:
		main.add_item(V, cell, 1)
	for i in 400:
		main.tick(0.05)
		check_work(main)
	check(main.ripe_bushes() == [bush] and main.stored(V) == 2, "senza ordini le bacche restano sul cespuglio")
	check(main.colonists.all(func(c): return c.job == main.Job.NONE), "chi non ha niente da fare resta fermo")

	# tasti dopo Destroy: uno alla volta; Uproot segna erbacce e cespugli, anche a clic su una casella
	main.tool("Chop").button_pressed = true
	check(main.order == main.Order.CHOP, "tasto Chop: si tagliano alberi")
	var uproot: Button = main.tool("Uproot")
	uproot.button_pressed = true
	check(main.order == main.Order.UPROOT and main.order_group.get_pressed_button() == uproot, "un'azione alla volta")
	main.mark(Rect2i(bush, Vector2i.ONE))
	main.mark(Rect2i(weed, Vector2i.ONE))
	check(main.uproot_marks.size() == 2 and main.ripe_bushes().is_empty(), "da estirpare: le bacche non si raccolgono più")
	check(main.job_list().contains("Uproot plants: 2"), "finestra Jobs: piante da estirpare")
	main.build_button.button_pressed = true
	check(main.order == main.Order.NONE and main.order_group.get_pressed_button() == null, "Build chiude le azioni")
	check(not main.select_button.button_pressed, "con uno strumento aperto Select è su")
	main.get_node("HUD/Categories/Row/Home").button_pressed = true
	main.choose_kind(main.Build.LAMP)
	var lamp_at: Vector2i = main.cells_in(area).filter(func(k): return main.can_build(k, main.Build.LAMP))[0]
	main.mark(Rect2i(lamp_at, Vector2i.ONE))
	check(main.furniture_draft.has(lamp_at), "lampada nel progetto")
	main.update_plate()
	check(main.actions.visible and main.erase.visible and not main.edit_button.visible and not main.confirm.disabled,
		"in costruzione la targa: Costruisci, Scarta e la gomma")
	main.build_button.button_pressed = false
	check(not main.categories.visible and not main.furniture_bar.visible, "Build chiude categorie e barra")
	check(main.category_group.get_pressed_button() == null and main.furniture_draft.has(lamp_at), "chiuso Build, il progetto resta")
	check(main.select_button.button_pressed, "chiuso l'ultimo strumento torna Select")
	main.update_plate()
	check(main.actions.visible and main.edit_button.visible and not main.erase.visible, "fuori la targa resta: Costruisci, Modifica, Scarta")
	check(main.plan_summary.get_parsed_text().contains("1") and main.plan_summary.tooltip_text.contains("Lamp: 1"), "la targa dice cosa c'è")
	main.discard_button.pressed.emit()
	check(main.furniture_draft.has(lamp_at) and main.discard_button.text == "Sure?", "Scarta: il primo clic chiede conferma")
	main.discard_button.pressed.emit()
	main.update_plate()
	check(main.furniture_draft.is_empty() and not main.actions.visible and main.discard_button.text == "Discard", "il secondo scarta: la targa sparisce")
	main.edit_button.pressed.emit()
	check(main.build_button.button_pressed, "Modifica riapre la costruzione")
	main.update_plate()
	check(main.actions.visible and main.confirm.disabled and main.plan_summary.get_parsed_text().begins_with("Right click"),
		"in costruzione senza progetto: la targa dice come si toglie")
	# il clic destro toglie un pezzo (il mobile prima del pavimento sotto); trascinato sposta la telecamera e non toglie
	var floor_at: Vector2i = main.cells_in(area).filter(func(k): return main.can_build(k, main.Build.FLOOR))[0]
	main.draft[floor_at] = [main.Build.FLOOR, W]
	main.draft[floor_at + Vector2i.RIGHT] = [main.Build.FLOOR, W]
	main.furniture_draft[floor_at] = [main.Build.LAMP, W, 0]
	map_click(main, MOUSE_BUTTON_RIGHT, floor_at, floor_at + Vector2i(3, 0))
	check(main.furniture_draft.has(floor_at), "il destro trascinato non toglie niente")
	map_click(main, MOUSE_BUTTON_RIGHT, floor_at, floor_at)
	check(not main.furniture_draft.has(floor_at) and main.draft.has(floor_at), "il destro toglie il mobile, il pavimento resta")
	map_click(main, MOUSE_BUTTON_RIGHT, floor_at, floor_at)
	check(not main.draft.has(floor_at) and main.draft.has(floor_at + Vector2i.RIGHT), "poi il pavimento, una casella")
	main.build_button.button_pressed = false
	main.draft[floor_at] = [main.Build.FLOOR, W]
	map_click(main, MOUSE_BUTTON_RIGHT, floor_at, floor_at)
	check(main.draft.has(floor_at), "fuori dalla costruzione il destro non toglie")
	main.build_button.button_pressed = true
	map_click(main, MOUSE_BUTTON_LEFT, floor_at, floor_at + Vector2i.RIGHT, true)
	check(main.draft.is_empty() and main.drag_start == null, "Maiusc + trascinamento: la gomma su un'area")
	main.build_button.button_pressed = false
	main.build_button.button_pressed = true
	main.structures_button.button_pressed = true
	main.tool("Mine").button_pressed = true
	check(not main.build_button.button_pressed and not main.categories.visible and not main.build_bar.visible, "un'azione chiude Build")
	main.tool("Mine").button_pressed = true
	main.select_button.button_pressed = true
	check(main.order == main.Order.NONE and main.order_group.get_pressed_button() == null, "Select chiude le azioni")
	main.select_button.button_pressed = false
	check(main.select_button.button_pressed, "Select non si spegne cliccandolo")
	for i in 1000:
		main.tick(0.05)
		check_work(main)
	check(not main.bushes.has(bush) and not main.weeds.has(weed) and main.uproot_marks.is_empty(), "estirpati")
	check(main.can_build(bush) and main.can_build(weed), "estirpate le piante, ci si costruisce")
	check(main.reserved.is_empty() and main.stored(V) == 2, "estirpando non si raccoglie")
	check(not main.job_list().contains("Uproot") and not main.job_list().contains("Harvest"), "finestra Jobs: niente da estirpare né raccogliere")

	# suggerimento in basso a destra: l'albero dice quanti tronchi restano, anche col mouse sulla chioma
	var tree: Vector2i = main.trees.keys().filter(func(k): return not main.trees.has(k + Vector2i.UP))[0]
	var full: int = main.TREE_LOGS[main.trees[tree]]
	check(main.TREE_LOGS.values().all(func(n): return n >= 20 and n <= 35), "da 20 a 35 tronchi per albero")
	check(main.describe(tree) == [main.TreeKind.keys()[main.trees[tree]].capitalize(), "Logs left: %d / %d" % [full, full]], "finestra dell'albero")
	check(main.describe(tree + Vector2i.UP) == main.describe(tree), "vale anche la chioma")
	main.show_tip(tree)
	check(main.object_sheet.visible, "il suggerimento compare")
	# un colpo d'ascia ogni gather_time (10 s a livello 5, 12 a livello 3): 5 tronchi ai piedi di chi taglia, ancora niente esperienza
	var axe = main.colonists[1]
	main.end_job(axe)
	axe.path.clear()
	var stand: Vector2i = main.TREE_SIDES.map(func(d): return tree + d).filter(func(k): return not main.astar.is_point_solid(k) \
		and not main.trees.has(k) and not main.water.has(k) and main.items.values().all(func(g): return not g.has(k)))[0]
	axe.pos = main.center(stand)
	axe.skills[main.Skill.WOODCUTTING] = 3
	axe.xp[main.Skill.WOODCUTTING] = 0.0
	var no_path: Array[Vector2i] = []
	var swing: float = main.gather_time(axe, main.Job.CHOP)
	check(is_equal_approx(swing, 12.0), "a livello 3 un colpo d'ascia ogni 12 secondi")
	main.start_job(axe, main.Job.CHOP, no_path, tree, swing)
	for i in int(swing / 0.05) + 1:
		main.tick(0.05)
	check(main.stock[tree] == full - 5 and main.items[W].get(stand, 0) == 5, "un colpo stacca 5 tronchi")
	check(is_equal_approx(axe.xp[main.Skill.WOODCUTTING], 10.0 * main.XP_PER_SECOND) and axe.skills[main.Skill.WOODCUTTING] == 3,
		"un colpo d'ascia: 2,8 punti, ancora livello 3")
	main.show_tip(tree)
	check(main.get_node("HUD/ObjectSheet/Box/Info").text == "Logs left: %d / %d" % [full - 5, full], "il suggerimento segue i tronchi che calano")
	main.show_tip(Vector2i(-1, -1))
	check(not main.object_sheet.visible, "fuori mappa niente suggerimento")
	main.end_job(axe)
	# scavo: 15 s a colpo a livello 5, di più per chi è scarso, di meno per chi è bravo
	axe.skills[main.Skill.MINING] = 0
	check(is_equal_approx(main.gather_time(axe, main.Job.MINE), 22.5), "piccone a livello 0: 22,5 secondi")
	axe.skills[main.Skill.MINING] = main.SKILL_MAX
	check(is_equal_approx(main.gather_time(axe, main.Job.MINE), 7.5), "piccone a livello 10: 7,5 secondi")
	# un mucchio di tronchi ne tiene al massimo 100: il resto va accanto
	var spot: Vector2i = main.cells_in(area).filter(func(k): return main.can_build(k))[0]
	var wood_spot: int = main.total(W)
	main.drop(W, spot, 150)
	check(main.items[W][spot] == 100 and main.total(W) == wood_spot + 150, "oltre 100 tronchi il mucchio trabocca accanto")
	check(main.items[W].values().max() <= main.STACK_MAX[W], "nessun mucchio oltre 100")
	check(main.describe(spot) == [main.item_title(W) + " pile", "100 / 100"], "finestra del mucchio: tipo e nome")
	check(main.describe(Vector2i(-5, -5)).is_empty(), "fuori dagli oggetti niente finestra")

	main.chop_marks = {Vector2i(1, 1): true}
	main.blueprints = {Vector2i(1, 2): [main.Build.WALL, W], Vector2i(2, 2): [main.Build.WALL, W]}
	var jobs: String = main.job_list()
	check(jobs.contains("Chop trees: 1") and jobs.contains("Build wall (%s): 2" % main.item_name(W)), "la finestra Jobs conta i lavori per tipo")

	# finestre: si aprono insieme, la X chiude (e il tasto torna su), si trascinano restando nello schermo
	var jobs_button: Button = main.tool("Jobs")
	jobs_button.button_pressed = true
	main.tool("Resources").button_pressed = true
	check(main.resources_panel.visible and main.jobs_panel.visible, "Resources e Jobs aperte insieme")
	main.get_node("HUD/JobsPanel/Box/Head/Close").pressed.emit()
	check(not main.jobs_panel.visible and not jobs_button.button_pressed, "la X chiude Jobs e alza il tasto")
	var move := InputEventMouseMotion.new()
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	move.relative = Vector2(-30, 20)
	var was: Vector2 = main.resources_panel.position
	main.drag_window(move, main.resources_panel)
	check(main.resources_panel.position == was + move.relative, "la finestra si trascina")
	move.relative = Vector2(-9999, -9999)
	main.drag_window(move, main.resources_panel)
	check(main.resources_panel.position == Vector2.ZERO, "trascinata non esce dallo schermo")

	# finestra Resources: il totale di tutti i magazzini, solo le risorse che ci sono
	main.update_resources()
	for res in main.Res.values():
		var row: Control = main.resources_list.get_child(res)
		check(row.visible == (main.stored(res) > 0) and row.get_child(-1).text == str(main.stored(res)), "quantità in magazzino")
	check(main.stored(V) > 0 and not main.get_node("HUD/ResourcesPanel/Box/Empty").visible, "c'è roba in magazzino")
	main.furniture = {Vector2i(0, 0): [main.Build.BED, W, 0], Vector2i(0, 2): [main.Build.CHAIR, W, 0]}  # il letto della fase 9 è stato abbattuto
	main.furniture_plans = {Vector2i(4, 0): [main.Build.BED, W, 0]}  # in progetto: non conta
	main._process(0.0)
	check(main.stored_label.text == str(main.Res.values().map(main.stored).reduce(func(a, b): return a + b, 0)) and main.colonists_label.text == "3" \
		and main.beds_label.text == "1", "barra in alto: totale risorse, coloni, letti finiti")

	# scheda del colono: nome, abilità 0-10 con la stellina al massimo, talenti sotto
	for col in main.colonists:
		check(col.first_name != "" and col.last_name != "" and col.skills.size() == main.Skill.size(), "colono con nome e abilità")
		check(col.skills.all(func(l): return l >= 0 and l <= main.SKILL_MAX) and col.traits.size() <= 2, "abilità 0-10, al più 2 talenti")
	var guy = main.colonists[0]
	guy.skills[main.Skill.MINING] = main.SKILL_MAX
	guy.skills[main.Skill.COOKING] = 3
	guy.traits = [main.Trait.GLUTTON, main.Trait.HOTHEAD]
	guy.nickname = "Owl"
	main.open_sheet(guy)
	main.open_sheet(guy)  # riaprendo non si accumulano righe
	var grid: Array = main.get_node("HUD/ColonistSheet/Box/Skills").get_children()
	check(main.sheet_panel.visible and grid.size() == main.Skill.size() * 4, "la scheda mostra tutte le abilità")
	check(grid[main.Skill.COOKING * 4].texture.region == Rect2(main.Skill.COOKING * 8, 0, 8, 8), "ogni abilità con la sua icona 8x8")
	check(grid[main.Skill.MINING * 4 + 3].texture == main.STAR and grid[main.Skill.COOKING * 4 + 3].texture == null, "stellina solo al massimo")
	var icons: Array = main.get_node("HUD/ColonistSheet/Box/Traits/Icons").get_children()
	check(icons.size() == 2 and icons[1].get_meta("tip") == "trait:HOTHEAD", "talenti: solo icone, il nome nel suggerimento")
	check(main.full_name(guy) == '%s "Owl" %s' % [guy.first_name, guy.last_name], "soprannome tra virgolette")
	guy.nickname = ""
	check(main.full_name(guy) == "%s %s" % [guy.first_name, guy.last_name], "senza soprannome")
	check(main.colonist_at(guy.pos + Vector2(3, -4)) == guy and main.colonist_at(guy.pos + Vector2(40, 40)) != guy, "si clicca sul colono")

	# bisogni: stanco (sotto 30) va a letto, stremato (10) dorme dove si trova, affamato mangia un vegetale
	main.chop_marks.clear()  # via i lavori finti della finestra Jobs
	main.blueprints.clear()
	main.furniture_plans.clear()
	var bed_cell: Vector2i = main.cells_in(area).filter(func(k): return main.can_build(k, main.Build.BED) \
		and main.can_build(k + Vector2i.RIGHT, main.Build.BED) and main.flood(k, false).size() >= main.ROOM_MAX)[0]
	main.furniture = {bed_cell: [main.Build.BED, W, 0]}
	main.needs_rate = 1.0
	for col in main.colonists:
		main.quit_job(col)
		col.needs = [100.0, 100.0, 100.0, 50.0, 100.0, 50.0]
		col.traits = []  # i talenti cambiano i ritmi: qui quelli di base
	var sleepy = main.colonists[0]
	var aside: Array = main.cells_in(area).filter(func(k): return main.can_build(k) and (k - bed_cell).length() > 3)
	for col in main.colonists:  # chi è fermo sul letto lo tiene occupato: gli altri da un'altra parte
		if col != sleepy:
			col.pos = main.center(aside[main.colonists.find(col)])
	sleepy.needs[main.Need.REST] = main.NEED_LOW - 1
	for i in 2000:
		main.tick(0.05)
		if main.in_bed(sleepy) and sleepy.path.is_empty():
			break
	check(main.in_bed(sleepy) and sleepy.target == bed_cell, "stanco: va a dormire nel letto libero")
	var rest0: float = sleepy.needs[main.Need.REST]
	var slept := 0
	for i in 3000:
		main.tick(0.05)
		slept += 1
		if sleepy.job != main.Job.SLEEP:
			break
	check(sleepy.job != main.Job.SLEEP and sleepy.needs[main.Need.REST] > 99, "si sveglia riposato")
	# il letto è fuori dalle stanze: comfort 0, il 20% in più delle 8 ore (in proporzione al riposo che mancava)
	var expected: float = (main.NEED_MAX - rest0) / main.NEED_MAX * main.SLEEP_TIME * main.DAY_LENGTH * 1.2 / 0.05
	check(absf(slept - expected) < expected * 0.03, "fuori da una stanza dorme il 20% in più")
	check(sleepy.needs[main.Need.COMFORT] < 50, "a letto ma fuori da una stanza il comfort scende")
	check(sleepy.needs[main.Need.STRESS] < 50, "dormendo lo stress scende")
	var busy = main.Colonist.new()
	busy.needs = [100.0, 100.0, 100.0, 50.0, 100.0, 10.0]
	busy.job = main.Job.HAUL
	main.update_needs(busy, 10.0)
	check(busy.needs[main.Need.STRESS] > 10, "lavorando lo stress sale")
	var worn = main.colonists[1]
	worn.needs[main.Need.REST] = main.EXHAUSTED + 0.01
	worn.needs[main.Need.STRESS] = 80.0
	worn.carry_res = W
	worn.carrying = 4
	var wood_worn: int = main.total(W)
	main.tick(0.05)
	check(worn.job == main.Job.SLEEP and worn.path.is_empty() and not main.in_bed(worn), "stremato: dorme dove si trova")
	check(worn.carrying == 0 and main.total(W) == wood_worn, "e lascia a terra quello che portava")
	var stiff: float = worn.needs[main.Need.COMFORT]
	for i in 100:
		main.tick(0.05)
	check(worn.needs[main.Need.COMFORT] < stiff, "per terra il comfort scende")
	for col in main.colonists:  # dopo il sonno qui sopra hanno tutti fame: mangia solo `hungry`
		col.needs[main.Need.FOOD] = 100.0
	var hungry = main.colonists[2]
	hungry.needs[main.Need.FOOD] = main.NEED_LOW - 1
	var veg: int = main.total(V)
	for i in 2000:
		main.tick(0.05)
		if hungry.needs[main.Need.FOOD] > main.NEED_LOW:
			break
	check(main.total(V) == veg - 1 and hungry.needs[main.Need.FOOD] > main.NEED_LOW, "affamato: mangia un vegetale")
	check(main.colonists.all(func(o): return o.needs[main.Need.HAPPINESS] < 100), "la felicità segue gli altri bisogni")
	main.open_sheet(worn)
	main._process(0.0)
	var needs_row: Array = main.sheet_needs.get_children()  # per bisogno: nome, freccia giù, barra, freccia su
	var rest_bar: ProgressBar = needs_row[main.Need.REST * 4 + 2]
	check(needs_row.size() == main.Need.size() * 4 and rest_bar.value == worn.needs[main.Need.REST], "barre dei bisogni nella scheda")
	check(rest_bar.get_theme_stylebox("fill").modulate_color == main.NEED_COLORS[1], "barra arancio sotto 30")
	# `worn` dorme per terra: il riposo sale (freccia a destra), la fame scende (a sinistra); _process(0) non le spegne
	check(needs_row[main.Need.REST * 4 + 3].modulate == main.TREND_UP and needs_row[main.Need.REST * 4 + 1].modulate == main.TREND_OFF, "riposo che sale: freccia a destra")
	check(needs_row[main.Need.FOOD * 4 + 1].modulate == main.TREND_DOWN and needs_row[main.Need.FOOD * 4 + 3].modulate == main.TREND_OFF, "cibo che scende: freccia a sinistra")
	check(needs_row[main.Need.STRESS * 4].get_child(0).texture == main.STRESS_ICON, "lo stress ha la sua icona")
	check(needs_row[main.Need.STRESS * 4 + 1].modulate == main.TREND_UP, "stress che scende: freccia a sinistra, verde")

	# stanze: comfort dai mobili e dal pavimento, cala se ci si sta stretti; i tipi chiedono i loro mobili
	var den = main.Room.new()  # stanza di prova 3x2 fatta solo di dati: i conti del comfort non guardano i muri
	var o := Vector2i(1, 1)
	for k in main.cells_in(Rect2i(o, Vector2i(3, 2))):
		den.cells[k] = true
	main.rooms.append(den)
	main.furniture = {o: [main.Build.BED, W, 0], o + Vector2i(2, 0): [main.Build.LAMP, W, 0], o + Vector2i(0, 1): [main.Build.CHAIR, W, 0]}
	check(main.room_comfort(den) == 2, "letto, abat-jour e sedia: comfort 2")
	for k in den.cells:
		main.built[k] = [main.Build.FLOOR, S]
	check(main.room_comfort(den) == 3, "tutta pavimentata di pietra: +1.5")
	main.open_room(den)
	check(not main.get_node("HUD/RoomPopup/Box/Owners").visible, "senza tipo niente proprietari né lavoratori")
	main.room_kind.item_selected.emit(main.room_kind.get_item_index(main.RoomKind.BEDROOM))
	check(main.room_class(den) == main.RoomClass.RESIDENCE and main.get_node("HUD/RoomPopup/Box/Owners").visible
		and main.get_node("HUD/RoomPopup/Box/Owners/Title").text == "Owners", "la camera è una residenza: ha i proprietari")
	check(main.get_node("HUD/RoomPopup/Box/Comfort").text.begins_with("Comfort: 3 / 10    ")
		and main.get_node("HUD/RoomPopup/Box/Comfort").text.ends_with("°C"), "il cartello mostra il comfort e i gradi")
	# freddo e pioggia: fuori meno comfort che dentro; il fuoco da campo scalda la stanza, la protezione chi la porta
	var sky = main.atmosphere
	sky.climate = true
	sky.weather = sky.Weather.SNOW
	sky.weather_strength = 1.0
	var open_air: Vector2i = o + Vector2i(5, 0)  # fuori dalla stanza, all'aperto
	var snug: Vector2i = o
	check(main.temperature_at(open_air) < main.temperature_at(snug) and main.weather_comfort(open_air) < 0,
		"nevica: fuori fa più freddo che in camera, e il freddo toglie comfort")
	var chilly: float = main.temperature_at(snug)
	main.furniture[o + Vector2i(1, 1)] = [main.Build.CAMPFIRE, W, 0]
	check(main.temperature_at(snug) == chilly + main.FIRE_HEAT, "il fuoco da campo scalda la stanza")
	main.furniture.erase(o + Vector2i(1, 1))
	check(main.weather_comfort(open_air, 40.0) == 0, "coperto bene il freddo non si sente")
	sky.weather = sky.Weather.RAIN
	check(main.weather_comfort(open_air, 40.0) == -main.WET_COMFORT and main.weather_comfort(snug, 40.0) == 0,
		"piove: si bagna solo chi sta fuori")
	sky.weather = sky.Weather.CLEAR
	sky.weather_strength = 0.0
	sky.climate = false
	var shown_kinds: Array = range(main.room_kind.item_count).map(main.room_kind.get_item_id)
	check(shown_kinds == [main.RoomKind.NONE, main.RoomKind.WAREHOUSE, main.RoomKind.BEDROOM, main.RoomKind.PANTRY],
		"un letto: in tendina la camera sì (e la dispensa, senza mobili), dormitorio, cucina e forgia no")
	var ticks: Array = main.room_owners.get_children()
	check(ticks.size() == main.colonists.size() and den.owners.is_empty(), "una casella per colono, nessun proprietario")
	ticks[0].button_pressed = true
	ticks[2].button_pressed = true
	ticks[0].button_pressed = false
	check(den.owners == [main.colonists[2]], "spunte: un proprietario")
	ticks[1].button_pressed = true
	main.open_room(den)
	check(den.owners.size() == 2 and main.room_owners.get_child(1).button_pressed and not main.room_owners.get_child(0).button_pressed,
		"più proprietari, e riaprendo il cartello restano spuntati")
	main.lens.visible = true
	main._process(0.0)
	var figures: Array = main.lens_canvas.get_children()
	check(figures.size() == 2 and figures.all(func(f): return f.position.y > main.room_mid(den).y), "lente: i proprietari sotto il tipo")
	var tip: Control = figures[0]._make_custom_tooltip("")
	check(tip.get_node("Head/Name").text == main.full_name(den.owners[0]) and tip.get_node("Needs").get_child_count() == main.Need.size() * 4,
		"col mouse sopra, la scheda del colono")
	tip.free()
	main._process(0.0)
	check(main.lens_canvas.get_child(0) == figures[0], "le figurine non si rifanno a ogni fotogramma (il suggerimento resterebbe a metà)")
	main.lens.visible = false
	# stanza di lavoro: niente proprietari, ma lavoratori; ci si entra comunque
	main.furniture[o + Vector2i(2, 1)] = [main.Build.CAMPFIRE, W, 0]
	main.refresh_room()  # in tendina compare la cucina
	main.room_kind.item_selected.emit(main.room_kind.get_item_index(main.RoomKind.KITCHEN))
	check(main.room_class(den) == main.RoomClass.WORK and den.owners.is_empty()
		and main.get_node("HUD/RoomPopup/Box/Owners/Title").text == "Workers", "la cucina è di lavoro: i proprietari se ne vanno")
	main.room_owners.get_child(0).button_pressed = true
	check(den.workers == [main.colonists[0]] and den.owners.is_empty(), "spunte: un lavoratore")
	check(not main.closed_cells(main.colonists[1]).has(o), "nella stanza di lavoro entrano anche gli altri")
	main.lens.visible = true
	main._process(0.0)
	check(main.lens_canvas.get_child_count() == 1, "lente: il lavoratore sotto il tipo")
	main.lens.visible = false
	main.room_kind.item_selected.emit(main.room_kind.get_item_index(main.RoomKind.WAREHOUSE))
	check(den.workers.is_empty() and den.owners.is_empty(), "magazzino: né lavoratori né proprietari")
	main.room_popup.hide()
	main.furniture.erase(o + Vector2i(2, 1))
	den.kind = main.RoomKind.NONE  # se no le sue caselle restano magazzino
	main.update_stockpile()
	var guest = main.colonists[0]
	guest.pos = main.center(o)
	main.colonists[1].pos = main.center(Vector2i.ZERO)
	main.colonists[2].pos = main.center(Vector2i.ZERO)
	check(main.comfort_of(guest) == 3 and main.comfort_of(main.colonists[2]) == 0, "da solo in 6 caselle tutto il comfort, fuori 0")
	main.colonists[1].pos = main.center(o + Vector2i(1, 1))
	check(main.comfort_of(guest) == 1, "in due: 3 caselle a testa, comfort a metà (per difetto)")
	check(is_equal_approx(main.comfort_time(0), 1.2) and main.comfort_time(5) == 1.0 and is_equal_approx(main.comfort_time(10), 0.8),
		"comfort 0: 20% di tempo in più, 10: 20% in meno")
	main.rooms.erase(den)
	for k in den.cells:
		main.built.erase(k)

	# routine: ogni ora è sonno, lavoro o tempo libero; i talenti la cambiano, e cambiano i ritmi dei bisogni
	var SLEEP: int = main.Act.SLEEP
	var WORK: int = main.Act.WORK
	var FREE: int = main.Act.FREE
	var plain = main.Colonist.new()
	var day: Array = main.routine_of(plain)
	check(day.size() == 24 and day.count(SLEEP) == 8 and day.count(WORK) == 10, "routine base: 8 ore di sonno, 10 di lavoro")
	check(day[23] == SLEEP and day[6] == FREE and day[7] == WORK and day[12] == FREE and day[19] == FREE, "dorme 22-6, pranzo alle 12, sera libera")
	check(main.wake_hour(day) == 6 and main.fx(plain, "work", main.WORK_HOURS) == 8.0, "si alza alle 6, lavora al più 8 ore")
	var owl = main.Colonist.new()
	owl.traits = [main.Trait.NIGHT_OWL]
	check(main.routine_of(owl)[12] == SLEEP and main.routine_of(owl)[2] == WORK and main.wake_hour(main.routine_of(owl)) == 18,
		"nottambulo: dorme di giorno, lavora di notte")
	var lark = main.Colonist.new()
	lark.traits = [main.Trait.EARLY_BIRD]
	check(main.routine_of(lark)[20] == SLEEP and main.routine_of(lark)[5] == WORK and main.wake_hour(main.routine_of(lark)) == 4,
		"mattiniero: tutto due ore prima")
	var napper = main.Colonist.new()
	napper.traits = [main.Trait.NAPPER]
	check(main.routine_of(napper)[13] == SLEEP and main.routine_of(napper)[22] == FREE and main.wake_hour(main.routine_of(napper)) == 6,
		"pennichella alle 13; la giornata comincia col sonno lungo")
	var drudge = main.Colonist.new()
	drudge.traits = [main.Trait.WORKAHOLIC]
	check(not main.routine_of(drudge).has(FREE) and main.fx(drudge, "work", main.WORK_HOURS) == 12.0, "stacanovista: niente tempo libero, 12 ore")
	var sleepyhead = main.Colonist.new()
	sleepyhead.traits = [main.Trait.SLEEPYHEAD, main.Trait.TIRELESS]  # in contrasto: solo per provare fx
	check(is_equal_approx(main.fx(sleepyhead, "sleep", 1.0), 10.0 / 8 * 6.0 / 8), "i ritmi dei talenti si moltiplicano")
	check(main.clash(main.Trait.SLEEPYHEAD, main.Trait.TIRELESS) and not main.clash(main.Trait.GLUTTON, main.Trait.LAZY), "talenti in contrasto")
	check(main.TRAITS_SHEET.get_width() == main.Trait.size() * main.TILE, "un'icona 16x16 per talento")
	var eater = main.Colonist.new()
	eater.traits = [main.Trait.GLUTTON]
	var monk = main.Colonist.new()
	monk.traits = [main.Trait.ASCETIC]
	for who in [plain, eater, monk]:
		who.needs = [100.0, 100.0, 50.0, 50.0, 100.0, 0.0]
		main.update_needs(who, 10.0)
	check(is_equal_approx(100 - eater.needs[main.Need.FOOD], 1.5 * (100 - plain.needs[main.Need.FOOD])), "goloso: fame più in fretta")
	check(plain.needs[main.Need.FUN] < 50 and monk.needs[main.Need.FUN] == main.NEED_MAX, "da svegli ci si annoia; l'asceta mai")

	# in gioco: la notte si dorme (per terra, senza letti) e si resta giù fino all'ora di alzarsi, poi colazione e svago
	main.routines = true
	main.furniture = {}
	for marks in [main.chop_marks, main.mine_marks, main.uproot_marks, main.blueprints, main.furniture_plans]:
		marks.clear()
	check(not main.items[V].is_empty(), "ci sono vegetali per la colazione")
	var pile: Vector2i = main.items[V].keys()[0]
	var near: Array = main.flood(pile, false).keys().filter(func(k): return k != pile and not main.trees.has(k))
	for k in main.colonists.size():
		var col = main.colonists[k]
		main.quit_job(col)
		col.traits = []
		col.needs = [100.0, 100.0, 50.0, 50.0, 100.0, 0.0]
		col.pos = main.center(near[k])
		col.look_again = 0.0  # se no chi non ha trovato lavoro nelle prove prima aspetta a cercare
	var worker = main.colonists[0]
	main.clock = floorf(main.clock) + 1 + 22.5 / 24
	main.tick(0.05)
	check(main.colonists.all(func(who): return who.job == main.Job.SLEEP), "alle 22 vanno tutti a dormire, per terra se non c'è un letto")
	for i in 20:
		main.tick(0.05)
	check(main.colonists.all(func(who): return who.job == main.Job.SLEEP), "riposati, restano giù finché è ora di dormire")
	main.clock = floorf(main.clock) + 1 + 6.5 / 24
	worker.needs[main.Need.FOOD] = main.SNACK - 5
	main.tick(0.05)
	check(main.colonists.all(func(who): return who.job != main.Job.SLEEP), "alle 6 si alzano")
	main.tick(0.05)
	check(worker.job == main.Job.EAT, "a colazione mangia anche senza fame")
	check(main.colonists[1].job == main.Job.RELAX and main.colonists[2].job == main.Job.RELAX, "nel tempo libero si svagano")
	var fun0: float = main.colonists[1].needs[main.Need.FUN]
	for i in 20:
		main.tick(0.05)
	check(main.colonists[1].needs[main.Need.FUN] > fun0, "svagandosi il divertimento sale")

	# ore di lavoro: si lavora solo nelle sue ore e fino al massimo; a fine turno si molla, ma prima si posa il carico
	main.clock = floorf(main.clock) + 9.0 / 24
	check(main.may_work(worker), "alle 9 si lavora")
	worker.worked = main.WORK_HOURS
	check(not main.may_work(worker), "fatte le 8 ore, basta")
	worker.worked = 0.0
	var idler = main.Colonist.new()
	idler.traits = [main.Trait.LAZY]
	idler.job = main.Job.HAUL
	idler.carrying = 1
	main.update_routine(idler, main.DAY_LENGTH / 24 * 3)
	check(is_equal_approx(idler.worked, 3.0) and main.may_work(idler), "conta le ore di lavoro")
	main.update_routine(idler, main.DAY_LENGTH / 24 * 3)
	check(not main.may_work(idler) and idler.job == main.Job.HAUL, "pigro: 6 ore e basta, ma finisce di portare quello che ha in mano")
	idler.carrying = 0
	main.update_routine(idler, 0.0)
	check(idler.job == main.Job.NONE, "a mani vuote molla il lavoro")
	main.clock += 1.0
	main.update_routine(idler, 0.0)
	check(idler.worked == 0.0 and main.may_work(idler), "ogni giornata si riparte da zero")
	var fidget = main.Colonist.new()
	fidget.traits = [main.Trait.RESTLESS]
	fidget.job = main.Job.HAUL
	fidget.carrying = 1
	main.update_routine(fidget, main.DAY_LENGTH / 24 * 2)
	check(fidget.pause_until > main.clock and not main.may_work(fidget), "irrequieto: dopo 2 ore di fila si prende una pausa")
	main.clock = floorf(main.clock) + 18.5 / 24
	worker.job = main.Job.CHOP  # finto taglio: a fine turno lo molla prima del colpo
	worker.target = main.cell_of(worker.pos)
	worker.path.clear()
	worker.work_left = 5.0
	worker.work_total = 5.0
	main.tick(0.05)
	check(worker.job != main.Job.CHOP, "alle 18 molla il lavoro")

	# talenti che cambiano la routine di colpo: l'iracondo se ne va a sbollire, il sonnambulo cammina dormendo
	var angry = main.colonists[1]
	angry.traits = [main.Trait.HOTHEAD]
	angry.needs[main.Need.STRESS] = 95.0
	main.tick(0.05)
	check(angry.job == main.Job.TANTRUM, "iracondo troppo stressato: sfuriata")
	for i in 200:  # un'ora: la sfuriata ne dura due
		main.tick(0.05)
	check(angry.job == main.Job.TANTRUM and angry.needs[main.Need.STRESS] < 90, "intanto sbollisce")
	var dreamer = main.colonists[2]
	main.quit_job(dreamer)
	dreamer.pos = main.center(main.cells_in(area).filter(func(k): return main.can_build(k) and main.flood(k, false).size() >= main.ROOM_MAX)[0])
	var stay: Array[Vector2i] = []
	main.start_job(dreamer, main.Job.SLEEP, stay, main.cell_of(dreamer.pos), 0.0)
	main.sleepwalk(dreamer)
	check(dreamer.job == main.Job.SLEEP and not dreamer.path.is_empty() and main.reserved.get(dreamer.path.back()) == dreamer,
		"il sonnambulo si alza dormendo e va a dormire altrove")
	worker.traits = [main.Trait.NIGHT_OWL]
	main.open_sheet(worker)
	var hours_row: Array = main.get_node("HUD/ColonistSheet/Box/Routine/Hours").get_children()
	check(hours_row.size() == 24 and hours_row[12].color == main.ROUTINE_COLORS[SLEEP] and hours_row[2].color == main.ROUTINE_COLORS[WORK],
		"nella scheda la routine ora per ora")
	main.sheet_panel.hide()
	main.routines = false

	# tabella delle priorità: all'inizio tutto 3, cioè l'ordine di Work; prima la priorità più alta, a pari priorità
	# l'ordine di Work, 0 mai. Nella finestra Jobs un tasto per colono e lavoro: clic dopo, clic destro prima
	var P = main.Work
	var prio_worker = main.colonists[1]
	check(P.values().all(func(w): return main.priority(prio_worker, w) == main.PRIORITY_DEFAULT), "all'inizio tutto 3")
	for col in main.colonists:
		main.quit_job(col)
		if col != prio_worker:
			for w in P.values():
				main.set_priority(col, w, 0)  # gli altri stanno fermi
	var near_tree: Array = main.trees.keys()
	main.sort_by_distance(near_tree, prio_worker.pos)
	var near_rock: Array = main.boulders.keys()
	main.sort_by_distance(near_rock, prio_worker.pos)
	main.chop_marks[near_tree[0]] = true
	main.mine_marks[near_rock[0]] = true
	check(main.find_work(prio_worker) and prio_worker.job == main.Job.CHOP, "a pari priorità prima tagliare, poi scavare (l'ordine di Work)")
	main.quit_job(prio_worker)
	main.set_priority(prio_worker, P.MINE, 1)
	check(main.find_work(prio_worker) and prio_worker.job == main.Job.MINE, "scavare a 1 viene prima")
	main.quit_job(prio_worker)
	main.set_priority(prio_worker, P.MINE, 0)
	main.set_priority(prio_worker, P.CHOP, 4)
	check(main.find_work(prio_worker) and prio_worker.job == main.Job.CHOP, "scavare mai: taglia, anche a 4")
	main.quit_job(prio_worker)
	for w in P.values():
		main.set_priority(prio_worker, w, 0)
	check(not main.find_work(prio_worker) and prio_worker.job == main.Job.NONE, "tutto a mai: non lavora")
	main.chop_marks.erase(near_tree[0])
	main.mine_marks.erase(near_rock[0])
	for col in main.colonists:
		col.priorities.clear()  # di nuovo tutto 3
	main.jobs_panel.show()
	main.refresh_priorities()
	var prio_grid: GridContainer = main.priority_grid
	check(prio_grid.columns == P.size() + 1 and prio_grid.get_child_count() == prio_grid.columns * (main.colonists.size() + 1),
		"in testa le icone dei lavori, poi una riga per colono")
	var row: int = main.colonists.find(prio_worker) + 1
	var cook_cell: Button = prio_grid.get_child(row * prio_grid.columns + 1 + main.WORK_ORDER.find(P.COOK))  # le colonne nell'ordine di WORK_ORDER
	check(cook_cell.text == "3", "il tasto dice la priorità")
	cook_cell.pressed.emit()
	check(main.priority(prio_worker, P.COOK) == 4 and cook_cell.text == "4", "clic: dopo")
	cook_cell.pressed.emit()
	check(main.priority(prio_worker, P.COOK) == 0 and cook_cell.text == "–", "dopo il 4, mai")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	cook_cell.gui_input.emit(right)
	check(main.priority(prio_worker, P.COOK) == 4, "clic destro: prima")
	var govern_col: int = 1 + main.WORK_ORDER.find(P.GOVERN)
	check(prio_grid.get_child(row * prio_grid.columns + govern_col) is not Button and prio_grid.get_child(govern_col + prio_grid.columns
		* (main.colonists.find(main.ruler) + 1)) is Button, "governa solo il sovrano")
	main.jobs_panel.hide()
	prio_worker.priorities.clear()

	# partenza di gioco: il sovrano e 3 coloni nella radura, niente di costruito; a terra le monete e un'arma abbandonata
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for col in game.colonists:  # talenti a caso, ma mai due uguali o in contrasto
		for a in col.traits:
			check(col.traits.count(a) == 1 and col.traits.all(func(b): return a == b or not game.clash(a, b)), "talenti compatibili")
	check(game.colonists.size() == game.COLONIST_COUNT + 1 and game.ruler == game.colonists[0], "il sovrano e 3 coloni")
	check(game.keep[game.Res.MEAL] == game.MEALS_PER_COLONIST * game.colonists.size(), "pasti da tenere: 2 a testa")
	check(game.built.is_empty() and game.rooms.is_empty() and game.stockpile.is_empty(), "niente stanze né magazzino")
	for res in game.Res.values():
		var start: int = game.START_GOLD if res == game.Res.GOLD else (1 if res in game.FOUND_WEAPONS else 0)
		check(game.stored(res) == 0 and game.total(res) <= start, "niente in magazzino; a terra solo monete e arma")
	check(game.total(game.Res.GOLD) == game.START_GOLD and game.FOUND_WEAPONS.map(game.total).reduce(func(a, b): return a + b) == 1,
		"le monete nella radura e un'arma sul prato")
	# una stanza 5x5 di legno, nel prato più vicino alla radura (con un giro libero attorno), la porta in basso
	var clearing: Vector2i = game.MAP_SIZE / 2
	var room_spots := []
	for y in range(clearing.y - 25, clearing.y + 17):
		for x in range(clearing.x - 25, clearing.x + 17):
			if not Rect2i(x, y, 9, 9).intersects(Rect2i(clearing - Vector2i(5, 5), Vector2i(11, 11))):
				room_spots.append(Rect2i(x, y, 9, 9))
	room_spots.sort_custom(func(a, b): return Vector2(a.get_center() - clearing).length() < Vector2(b.get_center() - clearing).length())
	var room_spot := Rect2i()
	for cand in room_spots:  # niente acqua, massi né cose a terra: le piante le si toglie, come chi sgombera il prato
		if game.cells_in(cand).all(func(k): return not game.water.has(k) and not game.astar.is_point_solid(k) \
				and game.items.values().all(func(ground): return not ground.has(k))):
			room_spot = cand
			break
	check(room_spot.size != Vector2i.ZERO, "c'è posto per una stanza vicino alla radura")
	for k in game.cells_in(room_spot):
		for plants in [game.trees, game.bushes, game.weeds, game.flax]:
			plants.erase(k)
	check(game.cells_in(room_spot).all(func(k): return game.can_build(k)), "sgomberato, ci si costruisce")
	var door: Vector2i = room_spot.position + Vector2i(4, 7)
	for k in game.cells_in(room_spot.grow(-1)):
		if k == door:
			game.built[k] = [game.Build.DOOR, W]
		elif not room_spot.grow(-2).has_point(k):
			game.built[k] = [game.Build.WALL, W]
			game.astar.set_point_solid(k)
	game.update_rooms()
	check(game.rooms.size() == 1 and game.rooms[0].cells.size() == 25 and game.rooms[0].door == door, "murata: una stanza 5x5")
	check(game.built[game.rooms[0].sign][0] == game.Build.WALL and (game.rooms[0].sign - door).length() == 1,
		"il cartello sul muro accanto alla porta")
	# il tipo resta finché ci sono i suoi mobili: in una stanza vuota, un letto e poi niente
	var hall = game.rooms[0]
	var bed_spot: Vector2i = hall.cells.keys().min()
	game.furniture[bed_spot] = [game.Build.BED, W, 0]
	game.open_room(hall)
	game.room_kind.item_selected.emit(game.room_kind.get_item_index(game.RoomKind.BEDROOM))
	check(hall.kind == game.RoomKind.BEDROOM, "col letto diventa una camera")
	game.order = game.Order.DEMOLISH
	game.mark(Rect2i(bed_spot, Vector2i.ONE))
	check(hall in game.rooms and hall.kind == game.RoomKind.NONE, "abbattuto il letto, la camera torna senza tipo")
	game.furniture[bed_spot] = [game.Build.BED, W, 0]  # di nuovo camera: solo le residenze hanno i proprietari
	game.open_room(hall)
	game.room_kind.item_selected.emit(game.room_kind.get_item_index(game.RoomKind.BEDROOM))
	# accesso: si entra solo nelle stanze proprie o senza proprietari; in quelle bandite nessuno
	var visitor = game.colonists[0]
	var host = game.colonists[1]
	var far: Vector2i = hall.cells.keys().max()
	check(not game.path_to_nearest(visitor, [far]).is_empty(), "senza proprietari: aperta a tutti")
	game.open_room(hall)
	visitor.pos = game.center(bed_spot)  # dentro, a dormire
	visitor.job = game.Job.SLEEP
	game.room_owners.get_child(1).button_pressed = true
	check(hall.owners == [host] and visitor.job == game.Job.NONE, "diventa di un altro: chi ci dormiva si alza")
	check(game.path_to_nearest(visitor, [far]).is_empty() and not game.path_to_nearest(host, [far]).is_empty(),
		"ci entra solo il proprietario")
	check(not game.path_of(visitor, bed_spot, game.MAP_SIZE / 2).is_empty(), "chi è dentro una stanza vietata esce")
	var banned: CheckBox = game.get_node("HUD/RoomPopup/Box/Banned")
	banned.button_pressed = true
	check(hall.banned and game.path_to_nearest(host, [far]).is_empty(), "bandita: nemmeno il proprietario")
	game.open_room(hall)
	check(banned.button_pressed, "riaprendo il cartello resta bandita")
	check(hall.cells.keys().all(func(k): return not game.astar.is_point_solid(k)), "dopo le ricerche la stanza torna percorribile")
	banned.button_pressed = false
	game.order = game.Order.DEMOLISH
	game.mark(Rect2i(bed_spot, Vector2i.ONE))
	check(hall.kind == game.RoomKind.NONE and hall.owners.is_empty(), "senza letto non è più una residenza: niente proprietari")
	game.queue_free()

	# i livelli (GDD 4.2): dal livello n al n+1 servono 10 × (n+1) punti, 150 fino al 5; i punti avanzati restano
	var pupil = main.colonists[0]
	var K = main.Skill.FISHING
	pupil.skills[K] = 0
	pupil.xp[K] = 0.0
	main.learn(pupil, K, 9.0 / main.XP_PER_SECOND)
	check(pupil.skills[K] == 0 and is_equal_approx(pupil.xp[K], 9.0), "9 punti: ancora livello 0")
	main.learn(pupil, K, 3.0 / main.XP_PER_SECOND)
	check(pupil.skills[K] == 1 and is_equal_approx(pupil.xp[K], 2.0), "12 punti: livello 1, ne avanzano 2")
	main.learn(pupil, K, 138.0 / main.XP_PER_SECOND)
	check(pupil.skills[K] == 5 and is_equal_approx(pupil.xp[K], 0.0) and is_equal_approx(main.xp_total(pupil, K), 150.0), "150 punti: livello 5")
	main.learn(pupil, K, 1000.0 / main.XP_PER_SECOND)
	check(pupil.skills[K] == main.SKILL_MAX and main.xp_total(pupil, K) > 550.0, "al 10 si ferma")
	main.open_sheet(pupil)
	var tips: Array = []
	for n in main.get_node("HUD/ColonistSheet/Box").find_children("*", "Label", true, false):
		tips.append(n.tooltip_text)
	check(tips.has("Top level"), "sulla scheda: livello massimo")
	# un turno di 8 ore a livello 0: circa 15 punti
	check(absf(8 * main.DAY_LENGTH / 24.0 / main.skill_time(0) * main.XP_PER_SECOND - 15.0) < 0.1, "un turno a livello 0: 15 punti")
	# i ragazzi imparano il doppio; gli avventurieri contano i punti ma crescono con le spedizioni
	var lad = main.colonists[1]
	var born: float = lad.born
	lad.born = main.clock - 13 * main.life_year()
	lad.skills[K] = 0
	lad.xp[K] = 0.0
	main.learn(lad, K, 5.0 / main.XP_PER_SECOND)
	check(lad.skills[K] == 1 and is_equal_approx(lad.xp[K], 0.0), "a 13 anni 5 punti valgono 10: livello 1")
	lad.born = born
	var hero = main.new_hero(main.Hero.ARCHER, 1)
	var aim: int = hero.skills[main.Skill.RANGED]
	main.learn(hero, main.Skill.RANGED, 100.0 / main.XP_PER_SECOND)
	check(hero.skills[main.Skill.RANGED] == aim and is_equal_approx(hero.xp[main.Skill.RANGED], 100.0), "l'avventuriero: punti sì, livello no")

	print("OK: %d alberi, %d caselle di roccia; legna %d, pietra %d" % [chopped, mined, main.total(W), main.total(S)])
	quit()


var last_pos := {}  # colono -> posizione al controllo prima, vedi check_work


# chi lavora usa i fotogrammi d'azione, dalla casella vicina, guardando l'albero o il masso
# un clic sulla mappa col tasto `button`, premuto su `from` e lasciato su `to` (col sinistro passando dal mouse mosso);
# `shift` col tasto Maiusc giù
func map_click(main, button: MouseButton, from: Vector2i, to: Vector2i, shift := false) -> void:
	var screen := func(cell: Vector2i): return main.get_canvas_transform() * main.center(cell)
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.shift_pressed = shift
	event.position = screen.call(from)
	main._unhandled_input(event)
	var motion := InputEventMouseMotion.new()
	motion.position = screen.call(to)
	main._unhandled_input(motion)
	var release: InputEventMouseButton = event.duplicate()
	release.pressed = false
	release.position = screen.call(to)
	main._unhandled_input(release)


func check_work(main) -> void:
	var ahead := {main.Facing.DOWN: Vector2i.DOWN, main.Facing.LEFT: Vector2i.LEFT,
		main.Facing.RIGHT: Vector2i.RIGHT, main.Facing.UP: Vector2i.UP}
	var stopped := {}
	for c in main.colonists:
		check(c.carrying <= main.CARRY_MAX, "al massimo 10 oggetti in mano")
		check(not main.astar.is_point_solid(main.cell_of(c.pos)) or not c.path.is_empty(), "nessuno resta chiuso dentro un muro")
		if c.path.is_empty():  # chi è fermo non condivide la casella con un altro fermo
			check(not stopped.has(main.cell_of(c.pos)), "due coloni fermi sulla stessa casella")
			stopped[main.cell_of(c.pos)] = true
		var moved: bool = last_pos.get(c, c.pos) != c.pos  # appena arrivato: si gira verso il lavoro al prossimo tick
		last_pos[c] = c.pos
		if not main.is_working(c) or moved:
			continue
		check(not main.trees.has(main.cell_of(c.pos)), "lavora stando su un albero")
		check(main.WORK_CYCLE.has(main.frame_of(c)), "fotogrammi d'azione mentre lavora")
		if c.work_left < c.work_total:
			var cells: Array = [c.target]  # albero
			if c.job == main.Job.MINE:
				cells = main.work_cells(c.job, c.target)
			elif c.job in [main.Job.BUILD, main.Job.FURNISH]:  # un mobile può prendere più caselle
				cells = main.cells_in(main.piece_rect(c.target, main.plans_of(c.job)[c.target]))
			check(cells.has(main.cell_of(c.pos) + ahead[c.facing]), "lavora dalla casella vicina, guardando il bersaglio")


# il rettangolo 5x4 tutto costruibile più vicino al centro della mappa, dentro `area`
func find_room(main, area: Rect2i) -> Rect2i:
	var mid: Vector2 = main.center(main.MAP_SIZE / 2)
	var room := Rect2i()
	for y in range(area.position.y, area.end.y - 3):
		for x in range(area.position.x, area.end.x - 4):
			var cand := Rect2i(x, y, 5, 4)
			var ok := true
			for k in range(x, x + 5):
				for h in range(y, y + 4):
					ok = ok and main.can_build(Vector2i(k, h))
			if ok and (room.size == Vector2i.ZERO or main.center(cand.position).distance_to(mid) < main.center(room.position).distance_to(mid)):
				room = cand
	return room


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)


# il suggerimento (annidato, vedi glossary.gd) di un pulsante di costruzione, senza icone né BBCode: nome, poi il testo
func tip_text(main, button: String) -> String:
	var said: Array = main.glossary.content(main.get_node("HUD/" + button).get_meta("tip"))
	var plain := RegEx.create_from_string("\\[img[^\\]]*\\][^\\[]*\\[/img\\] ?").sub(said[1], "", true)
	return said[0] + "\n" + RegEx.create_from_string("\\[[^\\]]*\\]").sub(plain, "", true)


# la roccia in gruppi di caselle unite da un lato
func rock_groups(main) -> Array:
	var seen := {}
	var groups := []
	for start in main.rocks:
		if seen.has(start):
			continue
		var group := [start]
		seen[start] = true
		var i := 0
		while i < group.size():
			for side in main.SIDES:
				if main.rocks.has(group[i] + side) and not seen.has(group[i] + side):
					seen[group[i] + side] = true
					group.append(group[i] + side)
			i += 1
		groups.append(group)
	return groups
