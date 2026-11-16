# Esegui: godot --headless --path . -s tests/test_jobs.gd
extends SceneTree


func _initialize() -> void:
	seed(1)  # mappa sempre uguale
	var main = load("res://main.tscn").instantiate()
	main.start_rooms = false  # le prove partono da una mappa senza costruzioni: le stanze di partenza sono in fondo
	root.add_child(main)
	await process_frame  # aspetta che venga chiamato _ready
	main.needs_rate = 0.0  # bisogni fermi: se no a metà prova i coloni vanno a dormire o a mangiare (vedi fondo)

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
	check(covered.size() == main.rocks.size(), "i massi coprono tutta la roccia")
	check(main.boulders.values().has(Vector2i(2, 2)), "ci sono anche massi grandi")
	check(main.ores.values().has(main.Res.IRON) and main.ores.values().has(main.Res.COAL), "ci sono vene di ferro e di carbone")
	for cell in main.ores:
		check(main.boulders.get(cell) == Vector2i.ONE, "ogni vena è un masso da una casella")
	check(main.stockpile.is_empty() and main.rooms.is_empty(), "niente magazzino all'inizio")

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
	main.bushes.clear()  # la fase 10 ne rimette uno
	main.weeds.clear()

	var W: int = main.Res.WOOD
	var S: int = main.Res.STONE
	var trees_before: int = main.trees.size()
	var rocks_before: int = main.rocks.size()
	var area := Rect2i(main.MAP_SIZE / 2 - Vector2i(8, 8), Vector2i(16, 16))

	# fase 1: taglio; senza magazzino la legna resta dove cade l'albero
	main.order = main.Order.CHOP
	main.mark(area)
	var marked: int = main.chop_marks.size()
	check(marked > 0, "ci sono alberi segnati vicino alla partenza")
	for c in main.colonists:  # un colpo ogni 5 secondi, se no il taglio dura troppo
		c.skills[main.Skill.WOODCUTTING] = main.SKILL_MAX
	var per_cut: int = main.GATHER[main.Job.CHOP][2]
	var wood: int = main.chop_marks.keys().reduce(func(sum, k): return sum + main.full_stock(k), 0)
	var cuts: int = main.chop_marks.keys().reduce(func(sum, k): return sum + ceili(main.full_stock(k) / float(per_cut)), 0)
	for i in 20000:  # 1000 secondi simulati
		main.tick(0.05)
		check_work(main)
	var chopped: int = trees_before - main.trees.size()
	check(chopped == marked, "tagliati tutti gli alberi segnati")
	check(main.total(W) == wood, "nessuna legna persa o creata")
	check(main.colonists.reduce(func(sum, c): return sum + c.xp[main.Skill.WOODCUTTING], 0) == cuts, "1 punto esperienza per colpo d'ascia")
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
	check(r.name == "Structure1" and r.kind == main.RoomKind.NONE, "nome e tipo di default")

	# fase 3: dal cartello diventa un magazzino, e i coloni ci portano la legna
	main.open_room(r)
	main.room_name.text_changed.emit("Deposito")
	main.room_kind.item_selected.emit(main.room_kind.get_item_index(main.RoomKind.WAREHOUSE))
	check(r.name == "Deposito" and r.kind == main.RoomKind.WAREHOUSE, "il popup cambia nome e tipo")
	check(main.stockpile.size() == 6, "le caselle della stanza diventano magazzino")
	for i in 10000:
		main.tick(0.05)
		check_work(main)
	check(main.stored(W) > 0, "legna portata in magazzino")
	check(main.total(W) - main.stored(W) == 0 or main.dest_cells(W).is_empty(), "trasportata finché c'è posto")

	# fase 4: scavo
	main.order = main.Order.MINE
	main.mark(area)
	check(main.mine_marks.size() > 0, "ci sono massi segnati vicino alla partenza")
	for i in 10000:
		main.tick(0.05)
		check_work(main)
	var mined: int = rocks_before - main.rocks.size()
	check(mined > 0 and main.mine_marks.is_empty(), "scavati tutti i massi segnati")
	# 5 pietre (o minerale) a colpo, 5 per casella: un colpo e un punto esperienza per casella
	check(main.colonists.reduce(func(sum, c): return sum + c.xp[main.Skill.MINING], 0) == mined, "1 punto esperienza per colpo di piccone")
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
	check(main.rooms.is_empty() and main.stockpile.is_empty(), "stanza aperta: niente cartello né magazzino")

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
	main.get_node("HUD/BuildBar/Row/Wall").button_pressed = true
	main.furniture_button.button_pressed = true  # tasto "Furniture": la barra dei mobili al posto di quella delle strutture
	check(main.furniture_bar.visible and not main.build_bar.visible and main.actions.visible, "barra dei mobili, con Build e X")
	check(main.draft.has(at) and main.draft.has(at + Vector2i.DOWN), "cambiando barra il pavimento in progetto resta")
	check(main.order == main.Order.NONE and main.kind_group.get_pressed_button() == null, "il muro scelto prima qui non vale")
	main.choose_kind(main.Build.ANVIL)
	check(main.build_res == main.Res.IRON and tip_texts(main, "FurnitureBar/Row/Anvil").slice(0, 2) == ["Anvil", "10"], "incudine: solo di ferro")
	main.choose_kind(main.Build.BED)
	check(main.order == main.Order.BUILD and main.build_res == W, "letto: solo di legno")
	check(tip_texts(main, "FurnitureBar/Row/Bed") == ["Bed", "10", "+1 room comfort", main.BUILD_INFO[main.Build.BED]],
		"suggerimento: nome, costo, comfort, descrizione")
	check(tip_texts(main, "BuildBar/Row/Wall").slice(0, 3) == ["Wall", "5/tile", "or 5/tile"], "muro: legno o pietra, per casella")
	for i in 3:
		main.turn(-1)
	check(main.build_turn == 1, "tre quarti a sinistra sono uno a destra")
	main.mark(Rect2i(at, Vector2i.ONE))
	var bed := [main.Build.BED, W, 1]
	check(main.furniture_draft.get(at) == bed, "letto girato nel progetto, sopra il pavimento")
	for kind in [main.Build.WALL, main.Build.LAMP]:
		check(not main.can_build(at + Vector2i.DOWN, kind), "girato, il letto prende la casella sotto: niente muri né mobili")
	check(main.can_build(at + Vector2i.DOWN), "ma il pavimento sì")
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
	# fuoco da campo: quinta riga del foglio; al posto dei quarti di giro, le colonne sono i fotogrammi della fiamma
	check(tip_texts(main, "FurnitureBar/Row/Campfire").slice(0, 2) == ["Campfire", "5"], "tasto del fuoco da campo")
	var fire := [main.Build.CAMPFIRE, W, 0]
	var flame: Rect2 = main.piece_rects(at, fire)[1]
	main.clock += 1.5 * main.FLAME_TIME / main.DAY_LENGTH
	check(flame.position.y == 4 * 32 and main.piece_rects(at, fire)[1].position.x != flame.position.x, "la fiamma guizza")

	var c = main.colonists[0]
	c.job = main.Job.HAUL  # finto lavoro: deve solo camminare
	c.path.assign([main.cell_of(c.pos) + Vector2i.LEFT])
	main.tick(0.05)
	check(c.facing == main.Facing.LEFT and c.walked > 0, "guarda e cammina verso sinistra")

	main.clock = 3 + 8.0 / 24
	check(main.sun_height() > 0 and main.sun_shadow().x < 0, "di mattina il sole è su e le ombre vanno a ovest")
	main.clock = 3 + 16.0 / 24
	check(main.sun_height() > 0 and main.sun_shadow().x > 0, "di pomeriggio le ombre vanno a est")
	check(main.sun_shadow().y < 0, "il sole passa a sud: le ombre vanno verso nord")
	# alberi: tronco fino alla riga 28 del foglio 16x32, sotto solo ombra semitrasparente e vuoto
	check(main.foot_of(main.TREES, Rect2(0, 0, 16, 32)) == 29, "l'ombra parte dalla base del tronco")
	main.clock = 3 + 23.0 / 24
	check(main.sun_height() < 0, "di notte niente sole")
	var lazy = main.Colonist.new()  # senza lavoro né strada: respira
	lazy.idle = main.BREATH_TIME * 0.9
	check(main.frame_of(lazy) == 5 and main.COLONIST_BASE.get_width() == 6 * main.TILE, "chi non fa nulla respira")
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
	main.get_node("HUD/Tools/Row/Chop").button_pressed = true
	check(main.order == main.Order.CHOP, "tasto Chop: si tagliano alberi")
	var uproot: Button = main.get_node("HUD/Tools/Row/Uproot")
	uproot.button_pressed = true
	check(main.order == main.Order.UPROOT and main.order_group.get_pressed_button() == uproot, "un'azione alla volta")
	main.mark(Rect2i(bush, Vector2i.ONE))
	main.mark(Rect2i(weed, Vector2i.ONE))
	check(main.uproot_marks.size() == 2 and main.ripe_bushes().is_empty(), "da estirpare: le bacche non si raccolgono più")
	check(main.job_list().contains("Uproot plants: 2"), "finestra Jobs: piante da estirpare")
	main.structures_button.button_pressed = true
	check(main.order == main.Order.NONE and main.order_group.get_pressed_button() == null, "Structures chiude le azioni")
	check(not main.select_button.button_pressed, "con uno strumento aperto Select è su")
	main.structures_button.button_pressed = false
	check(main.select_button.button_pressed, "chiuso l'ultimo strumento torna Select")
	main.get_node("HUD/Tools/Row/Mine").button_pressed = true
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
	# un colpo d'ascia ogni gather_time (10 s a livello 5, 12 a livello 3): 5 tronchi ai piedi di chi taglia, 1 punto esperienza
	var axe = main.colonists[1]
	main.end_job(axe)
	axe.path.clear()
	var stand: Vector2i = main.TREE_SIDES.map(func(d): return tree + d).filter(func(k): return not main.astar.is_point_solid(k) \
		and not main.trees.has(k) and not main.water.has(k) and main.items.values().all(func(g): return not g.has(k)))[0]
	axe.pos = main.center(stand)
	axe.skills[main.Skill.WOODCUTTING] = 3
	var xp: int = axe.xp[main.Skill.WOODCUTTING]
	var no_path: Array[Vector2i] = []
	var swing: float = main.gather_time(axe, main.Job.CHOP)
	check(is_equal_approx(swing, 12.0), "a livello 3 un colpo d'ascia ogni 12 secondi")
	main.start_job(axe, main.Job.CHOP, no_path, tree, swing)
	for i in int(swing / 0.05) + 1:
		main.tick(0.05)
	check(main.stock[tree] == full - 5 and main.items[W].get(stand, 0) == 5, "un colpo stacca 5 tronchi")
	check(axe.xp[main.Skill.WOODCUTTING] == xp + 1, "1 punto esperienza per colpo")
	main.show_tip(tree)
	check(main.get_node("HUD/ObjectSheet/Box/Info").text == "Logs left: %d / %d" % [full - 5, full], "il suggerimento segue i tronchi che calano")
	main.show_tip(Vector2i(-1, -1))
	check(not main.object_sheet.visible, "fuori mappa niente suggerimento")
	main.end_job(axe)
	# scavo: 15 s a colpo a livello 5, di più per chi è scarso, di meno per chi è bravo
	axe.skills[main.Skill.MINING] = 1
	check(is_equal_approx(main.gather_time(axe, main.Job.MINE), 21.0), "piccone a livello 1: 21 secondi")
	axe.skills[main.Skill.MINING] = main.SKILL_MAX
	check(is_equal_approx(main.gather_time(axe, main.Job.MINE), 7.5), "piccone a livello 10: 7,5 secondi")
	# un mucchio di tronchi ne tiene al massimo 100: il resto va accanto
	var spot: Vector2i = main.cells_in(area).filter(func(k): return main.can_build(k))[0]
	var wood_spot: int = main.total(W)
	main.drop(W, spot, 150)
	check(main.items[W][spot] == 100 and main.total(W) == wood_spot + 150, "oltre 100 tronchi il mucchio trabocca accanto")
	check(main.items[W].values().max() <= main.STACK_MAX[W], "nessun mucchio oltre 100")
	check(main.describe(spot) == ["Wood pile", "100 / 100"], "finestra del mucchio")
	check(main.describe(Vector2i(-5, -5)).is_empty(), "fuori dagli oggetti niente finestra")

	main.chop_marks = {Vector2i(1, 1): true}
	main.blueprints = {Vector2i(1, 2): [main.Build.WALL, W], Vector2i(2, 2): [main.Build.WALL, W]}
	var jobs: String = main.job_list()
	check(jobs.contains("Chop trees: 1") and jobs.contains("Build wall (wood): 2"), "la finestra Jobs conta i lavori per tipo")

	# finestre: si aprono insieme, la X chiude (e il tasto torna su), si trascinano restando nello schermo
	var jobs_button: Button = main.get_node("HUD/Tools/Row/Jobs")
	jobs_button.button_pressed = true
	main.get_node("HUD/Tools/Row/Resources").button_pressed = true
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
		check(row.visible == (main.stored(res) > 0) and row.get_child(2).text == str(main.stored(res)), "quantità in magazzino")
	check(main.stored(V) > 0 and not main.get_node("HUD/ResourcesPanel/Box/Empty").visible, "c'è roba in magazzino")
	main.furniture = {Vector2i(0, 0): [main.Build.BED, W, 0], Vector2i(0, 2): [main.Build.CHAIR, W, 0]}  # il letto della fase 9 è stato abbattuto
	main.furniture_plans = {Vector2i(4, 0): [main.Build.BED, W, 0]}  # in progetto: non conta
	main._process(0.0)
	check(main.stored_label.text == str(main.Res.values().map(main.stored).reduce(func(a, b): return a + b, 0)) and main.colonists_label.text == "3" \
		and main.beds_label.text == "1", "barra in alto: totale risorse, coloni, letti finiti")

	# scheda del colono: nome, abilità 1-10 con la stellina al massimo, talenti sotto
	for col in main.colonists:
		check(col.first_name != "" and col.last_name != "" and col.skills.size() == main.Skill.size(), "colono con nome e abilità")
		check(col.skills.all(func(l): return l >= 1 and l <= main.SKILL_MAX) and col.traits.size() <= 2, "abilità 1-10, al più 2 talenti")
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
	check(icons.size() == 2 and icons[1].tooltip_text.begins_with("Hothead\n"), "talenti: solo icone, il nome nel suggerimento")
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
		col.needs = [100.0, 100.0, 50.0, 100.0, 50.0]
	var sleepy = main.colonists[0]
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
	busy.needs = [100.0, 100.0, 50.0, 100.0, 10.0]
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
	check(main.get_node("HUD/RoomPopup/Box/Comfort").text == "Comfort: 3 / 10", "il cartello mostra il comfort")
	var shown_kinds: Array = range(main.room_kind.item_count).map(main.room_kind.get_item_id)
	check(shown_kinds == [main.RoomKind.NONE, main.RoomKind.WAREHOUSE, main.RoomKind.BEDROOM], "un letto: in tendina la camera sì, dormitorio, cucina e forgia no")
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
	# mappa di gioco: 3 stanze 5x5 con la porta verso fuori, nella prima la scorta di debug
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	check(game.rooms.size() == 3 and game.rooms.all(func(r): return r.cells.size() == 25), "3 stanze 5x5 di partenza")
	for d in game.START_ROOMS:
		check(game.rooms.any(func(r): return r.door == game.MAP_SIZE / 2 + d * 11), "porta verso fuori")
	check(game.rooms.all(func(r): return game.built[r.sign][0] == game.Build.WALL and (r.sign - r.door).length() == 1),
		"cartelli sul muro accanto alla porta")
	for res in game.Res.values():
		check(game.stored(res) == game.DEBUG_STASH, "scorta di debug nel magazzino della prima stanza")
	# il tipo resta finché ci sono i suoi mobili: in una stanza vuota, un letto e poi niente
	var hall = game.rooms.filter(func(r): return r.kind == game.RoomKind.NONE)[0]
	var bed_spot: Vector2i = hall.cells.keys().min()
	game.furniture[bed_spot] = [game.Build.BED, W, 0]
	game.open_room(hall)
	game.room_kind.item_selected.emit(game.room_kind.get_item_index(game.RoomKind.BEDROOM))
	check(hall.kind == game.RoomKind.BEDROOM, "col letto diventa una camera")
	game.order = game.Order.DEMOLISH
	game.mark(Rect2i(bed_spot, Vector2i.ONE))
	check(hall in game.rooms and hall.kind == game.RoomKind.NONE, "abbattuto il letto, la camera torna senza tipo")
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
	game.queue_free()

	print("OK: %d alberi, %d caselle di roccia; legna %d, pietra %d" % [chopped, mined, main.total(W), main.total(S)])
	quit()


# chi lavora usa i fotogrammi d'azione, dalla casella vicina, guardando l'albero o il masso
func check_work(main) -> void:
	var ahead := {main.Facing.DOWN: Vector2i.DOWN, main.Facing.LEFT: Vector2i.LEFT,
		main.Facing.RIGHT: Vector2i.RIGHT, main.Facing.UP: Vector2i.UP}
	var stopped := {}
	for c in main.colonists:
		check(c.carrying <= main.CARRY_MAX, "al massimo 10 oggetti in mano")
		if c.path.is_empty():  # chi è fermo non condivide la casella con un altro fermo
			check(not stopped.has(main.cell_of(c.pos)), "due coloni fermi sulla stessa casella")
			stopped[main.cell_of(c.pos)] = true
		if not main.is_working(c):
			continue
		check(not main.trees.has(main.cell_of(c.pos)), "lavora stando su un albero")
		check(main.WORK_CYCLE.has(main.frame_of(c)), "fotogrammi d'azione mentre lavora")
		if c.work_left < c.work_total:
			var cells: Array = [c.target]  # albero
			if c.job == main.Job.MINE:
				cells = main.boulder_cells(c.target)
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


# testi del suggerimento di un pulsante di costruzione, in ordine: nome, costi, bonus, descrizione
func tip_texts(main, button: String) -> Array:
	var tip: Control = main.get_node("HUD/" + button)._make_custom_tooltip("")
	var texts: Array = tip.find_children("*", "Label", true, false).map(func(l): return l.text)
	tip.free()
	return texts
