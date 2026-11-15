# Esegui: godot --headless --path . -s tests/test_jobs.gd
extends SceneTree


func _initialize() -> void:
	seed(1)  # mappa sempre uguale
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame  # aspetta che venga chiamato _ready

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
	for cell in main.stockpile:
		check(main.astar.is_point_solid(cell), "il magazzino non è transitabile")

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

	var W: int = main.Res.WOOD
	var S: int = main.Res.STONE
	var trees_before: int = main.trees.size()
	var rocks_before: int = main.rocks.size()
	var area := Rect2i(main.MAP_SIZE / 2 - Vector2i(8, 8), Vector2i(16, 16))
	# fase 1: solo scavo, così la pietra trova posto prima che la legna riempia il magazzino
	main.order = main.Order.MINE
	main.mark(area)
	check(main.mine_marks.size() > 0, "ci sono massi segnati vicino alla partenza")
	for i in 10000:  # 500 secondi simulati
		main.tick(0.05)
		check_door(main)
		check_work(main)
	check(main.stored(S) > 0, "pietra portata in magazzino")

	# fase 2: taglio
	main.order = main.Order.CHOP
	main.mark(area)
	var marked: int = main.chop_marks.size()
	check(marked > 0, "ci sono alberi segnati vicino alla partenza")
	for i in 10000:
		main.tick(0.05)
		check_door(main)
		check_work(main)

	var chopped: int = trees_before - main.trees.size()
	var mined: int = rocks_before - main.rocks.size()
	check(chopped == marked, "tagliati tutti gli alberi segnati")
	check(mined > 0, "scavata della roccia")
	for cell in main.boulders:
		for k in main.boulder_cells(cell):
			check(main.astar.is_point_solid(k), "roccia rimasta ancora solida")
	for cell in main.rocks:
		check(main.astar.is_point_solid(cell), "ogni roccia è solida")
	check(main.total(W) == chopped * main.WOOD_PER_TREE, "nessuna legna persa o creata")
	check(main.total(S) == mined * main.STONE_PER_CELL, "nessuna pietra persa o creata")
	check(main.stored(W) > 0, "legna portata in magazzino")
	for res in [W, S]:
		var on_ground: int = main.total(res) - main.stored(res)
		check(on_ground == 0 or main.dest_cells(res).is_empty(), "trasportata finché c'è posto")
	for cell in main.stockpile:
		check(main.items[W].get(cell, 0) <= main.STACK_MAX and main.items[S].get(cell, 0) <= main.STACK_MAX, "nessuna pila oltre il limite")
		check(not (main.items[W].has(cell) and main.items[S].has(cell)), "una sola risorsa per cella")
	for c in main.colonists:
		check(c.job == main.Job.NONE, "coloni liberi a fine lavoro")
	check(main.reserved.is_empty(), "nessuna prenotazione rimasta")

	# fase 3: costruzione col materiale del magazzino (un muro di legno, un pavimento di pietra)
	var spots := []
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if main.can_build(Vector2i(x, y)):
				spots.append(Vector2i(x, y))
	check(spots.size() >= 2, "c'è posto per costruire")
	var wood_left: int = main.total(W)  # totale: il posto liberato in magazzino si riempie con la legna a terra
	var stone_left: int = main.total(S)
	main.order = main.Order.BUILD
	main.build_kind = main.Build.WALL
	main.build_res = W
	main.mark(Rect2i(spots[0], Vector2i.ONE))
	main.build_kind = main.Build.FLOOR
	main.build_res = S
	main.mark(Rect2i(spots[1], Vector2i.ONE))
	for i in 200:
		main.tick(0.05)
	check(main.draft.size() == 2 and main.built.is_empty() and main.reserved.is_empty(), "il progetto aspetta la conferma")
	main.confirm_build()
	check(main.draft.is_empty() and main.blueprints.size() == 2, "confermato: diventa lavoro")
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

	# fase 4: la X cancella il progetto e i lavori già confermati; chi portava il materiale lo lascia a terra
	var free: Array = spots.filter(func(k): return main.can_build(k))
	var wood_now: int = main.total(W)
	main.order = main.Order.BUILD
	main.build_kind = main.Build.WALL
	main.build_res = W
	main.mark(Rect2i(free[0], Vector2i.ONE))
	main.confirm_build()
	main.mark(Rect2i(free[1], Vector2i.ONE))  # questo resta da confermare
	for i in 60:  # 3 secondi: il costruttore è partito
		main.tick(0.05)
	check(main.reserved.has(free[0]), "il lavoro confermato è stato preso")
	main.order = main.Order.ERASE
	main.mark(Rect2i(free[0], Vector2i(2, 2)))
	main.mark(Rect2i(free[1], Vector2i.ONE))
	check(main.draft.is_empty() and main.blueprints.is_empty() and main.reserved.is_empty(), "la X cancella progetto e lavori")
	check(main.total(W) == wood_now, "il materiale del lavoro cancellato non si perde")

	# fase 5: una stanza chiusa di muri col pavimento dentro: nessuno ci resta chiuso
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
	check(room.size != Vector2i.ZERO, "c'è posto per una stanza")
	main.order = main.Order.BUILD
	main.build_res = W
	main.build_kind = main.Build.WALL
	main.mark(room)
	main.build_kind = main.Build.FLOOR
	main.mark(room.grow(-1))
	main.confirm_build()
	for i in 4000:
		main.tick(0.05)
	check(main.blueprints.is_empty(), "stanza finita, pavimento compreso")
	var door: Vector2i = main.warehouse_access()[0]
	for c in main.colonists:
		check(not main.astar.get_id_path(main.cell_of(c.pos), door).is_empty(), "nessuno chiuso nella stanza")

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
	print("OK: %d alberi, %d caselle di roccia; magazzino: %d legna, %d pietra (capienza %d)" \
		% [chopped, mined, main.stored(W), main.stored(S), main.stockpile.size() * main.STACK_MAX])
	quit()


# chi sta per scaricare (carico preso, arrivato a destinazione) deve stare davanti al portone
func check_door(main) -> void:
	for c in main.colonists:
		if c.job == main.Job.HAUL and c.target == c.dest and c.path.is_empty():
			check(main.warehouse_access().has(main.cell_of(c.pos)), "si scarica solo davanti al portone")


# chi lavora usa i fotogrammi d'azione, dalla casella vicina, guardando l'albero o il masso
func check_work(main) -> void:
	var ahead := {main.Facing.DOWN: Vector2i.DOWN, main.Facing.LEFT: Vector2i.LEFT,
		main.Facing.RIGHT: Vector2i.RIGHT, main.Facing.UP: Vector2i.UP}
	var stopped := {}
	for c in main.colonists:
		if c.path.is_empty():  # chi è fermo non condivide la casella con un altro fermo
			check(not stopped.has(main.cell_of(c.pos)), "due coloni fermi sulla stessa casella")
			stopped[main.cell_of(c.pos)] = true
		if not main.is_working(c):
			continue
		check(not main.trees.has(main.cell_of(c.pos)), "lavora stando su un albero")
		check(main.WORK_CYCLE.has(main.frame_of(c)), "fotogrammi d'azione mentre lavora")
		if c.work_left < c.work_total:
			var cells: Array = main.boulder_cells(c.target) if c.job == main.Job.MINE else [c.target]
			check(cells.has(main.cell_of(c.pos) + ahead[c.facing]), "lavora dalla casella vicina, guardando il bersaglio")


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
