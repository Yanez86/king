# Esegui: godot --headless --path . -s tests/test_rock.gd
# Roccia, gallerie e stanze nella montagna (GDD 4.4.8): le gallerie sotto la cima del massiccio, l'imbocco all'aperto,
# la cima che si toglie, le stanze nella roccia senza tetto. (Il massiccio, lo scavo a caselle e le vene nascoste sono
# in test_jobs.gd.)
extends SceneTree

var main


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(2)  # una mappa con una montagna grande
	main = load("res://main.tscn").instantiate()
	main.game_start = false
	root.add_child(main)
	await process_frame
	main.events = false
	main.needs_rate = 0.0
	main.routines = false
	main.animals.clear()
	var B = main.Build
	var W: int = main.Res.WOOD

	# all'inizio niente gallerie; dentro il massiccio c'è roccia sopra, sul bordo no
	check(main.caves.is_empty(), "all'inizio nessuna galleria")
	var site: Array = dig_site()
	var way: Array = site[0]     # da fuori verso dentro: la prima casella è sul bordo del massiccio
	var block: Rect2i = site[1]  # 7x7, tutto dentro: la galleria arriva sul lato sinistro, alla terza riga
	check(not main.deep(way[0]) and way.slice(1).all(func(k): return main.deep(k)), "sul bordo non c'è roccia sopra, dentro sì")

	# scavare: la prima casella è l'imbocco, all'aperto; le altre sono gallerie, al riparo, e non ci si coltiva
	for k in way:
		main.dig(k)
	check(not main.caves.has(way[0]) and way.slice(1).all(func(k): return main.caves.has(k)), "l'imbocco è all'aperto, il resto è galleria")
	check(way.all(func(k): return not main.rocks.has(k) and not main.astar.is_point_solid(k)), "ci si passa")
	check(not main.sheltered(way[0]) and main.sheltered(way[1]), "in galleria si sta al riparo, all'imbocco no")
	check(way.all(func(k): return not main.can_plant(k)) and main.can_build(way[1]) and main.can_build(way[1], B.DOOR), "nella roccia non si coltiva; si costruisce")
	var door: Vector2i = Vector2i(block.position.x, block.position.y + 2)
	check(way[-1] == door, "la galleria arriva al blocco")
	var room_rect := Rect2i(block.position + Vector2i.ONE, Vector2i(4, 3))
	for k in main.cells_in(room_rect):
		main.dig(k)
	check(main.caves.size() == way.size() - 1 + 12, "una stanza 4x3 scavata dietro")

	# la cima copre le gallerie: nell'immagine "chiusa" la roccia accanto a una galleria non ha bordi, in quella aperta sì
	var beside: Vector2i = room_rect.position + Vector2i(1, -1)  # roccia piena sopra la stanza
	check(main.solid_massif(beside) and tile(0, beside) != tile(1, beside), "aperta: il bordo della galleria si vede")
	var edges := func(closed: int, k: Vector2i) -> bool:  # la riga in fondo alla casella: la parete, se sotto è aperto
		return main.rock_images[closed].get_pixelv(k * main.TILE + Vector2i(8, 15)) == main.MASSIF.get_image().get_pixel(2 * main.TILE + 8, main.TILE + 15)
	check(edges.call(0, beside) and not edges.call(1, beside), "la parete sopra la stanza c'è solo a cima tolta")
	check(main.rock_images[0].get_pixelv(room_rect.position * main.TILE + Vector2i(8, 8)).a == 0.0 and main.rock_images[1].get_pixelv(room_rect.position * main.TILE + Vector2i(8, 8)).a == 0.0,
		"la galleria stessa è vuota nelle due: la cima la disegna _draw, sopra chi ci passa")
	check(main.ceiling_shown() and main.covered(room_rect.position) and not main.covered(way[0]), "la cima copre le gallerie, non l'imbocco")
	main.order = main.Order.MINE
	check(not main.ceiling_shown() and not main.covered(room_rect.position), "scegliendo Mine la cima si toglie: si vede dove si scava")
	main.order = main.Order.NONE
	main.roofs_shown = false
	check(not main.ceiling_shown(), "e col pulsante Roofs, come i tetti")
	main.roofs_shown = true
	await process_frame
	check(main.rock_sprite.texture == main.rock_textures[1], "in gioco si vede l'immagine giusta")

	# una porta nella galleria fa una stanza: i muri sono la roccia, il tetto è la roccia
	main.built[door] = [B.DOOR, W]
	main.update_rooms()
	check(main.rooms.size() == 1 and main.rooms[0].cells.size() == 12, "la porta chiude la stanza: %d" % main.rooms.size())
	var room = main.rooms[0]
	check(main.roofs.is_empty() and main.roofed.is_empty(), "nessun tetto da costruire: sopra c'è la roccia")
	var walls: Dictionary = main.room_walls(room)
	check(walls.size() == 14 and walls.values().count(main.ROCK_INSULATION) == 13, "13 caselle di roccia e la porta la chiudono")
	check(is_equal_approx(main.insulation(room), (13 * main.ROCK_INSULATION + main.WALL_INSULATION[W]) / 14.0), "isola come una cantina")
	check(main.cells_in(room_rect).all(func(k): return main.sheltered(k)), "dentro si sta al riparo")
	# un fuoco dentro: senza tetto niente comignolo, e sotto la cima non si vede
	var fire: Vector2i = room_rect.position + Vector2i(3, 1)
	main.furniture[fire] = [B.CAMPFIRE, W, 0]
	check(main.chimney_of(fire)[1] == main.Chimney.NONE and main.covered(fire), "il fuoco sotto la roccia: niente comignolo, non si vede")
	for i in 200:  # qualche ora con una stanza nella roccia: tetti, usura, meteo, calore
		main.tick(0.5)
	check(main.rooms.size() == 1 and main.roofs.is_empty() and main.wear.is_empty(), "nessuna usura: non c'è tetto")
	main.built.erase(door)
	main.update_rooms()
	check(main.rooms.is_empty(), "senza porta non è una stanza")

	# crolli (fase 3): la stanza 4x3 regge da sola, ogni casella ha roccia entro 2
	main.furniture.erase(fire)
	main.find_shaky()
	check(main.shaky.is_empty() and main.cells_in(room_rect).all(func(k): return main.holds(k)), "fino a 4 caselle di larghezza regge da sola")
	check(main.describe(room_rect.position) == ["Tunnel", "The rock overhead holds."], "col mouse sopra: regge")
	# allargata a 5x5 il centro resta a 3 caselle dalla roccia: segnando lo scavo si vede prima
	var hall := Rect2i(block.position + Vector2i.ONE, Vector2i(5, 5))
	var mid: Vector2i = hall.position + Vector2i(2, 2)
	main.order = main.Order.MINE
	main.mark(hall)
	main.find_unsafe(Rect2i())
	check(main.unsafe_marks.keys() == [mid], "segnando la sala 5x5, in rosso il centro: %s" % [main.unsafe_marks.keys()])
	main.mine_marks.clear()
	main.find_unsafe(hall)
	check(main.unsafe_marks.keys() == [mid], "anche mentre la si trascina")
	main.order = main.Order.NONE
	for k in main.cells_in(hall):
		if main.rocks.has(k):
			main.dig(k)
	check(main.shaky.keys() == [mid] and not main.holds(mid), "scavata, il centro è pericolante")
	check(main.describe(mid) == ["Tunnel", "Unsafe: no rock, prop or wall within 2 tiles. It may give way."], "col mouse sopra: pericolante")
	# il puntello: solo in galleria, regge per 2 caselle attorno; un muro anche
	check(main.can_build(mid, B.PROP) and not main.can_build(way[0], B.PROP) and not main.can_build(main.MAP_SIZE / 2, B.PROP), "il puntello solo in galleria")
	check(main.BUILD_COST[B.PROP] == 4 and main.FURNITURE[B.PROP] == Vector2i.ONE and main.kind_buttons[B.PROP] != null, "4 legna, una casella, il suo tasto")
	main.furniture[mid + Vector2i(1, 1)] = [B.PROP, W, 0]
	main.find_shaky()
	check(main.shaky.is_empty(), "con un puntello accanto regge")
	main.furniture.erase(mid + Vector2i(1, 1))
	main.built[mid + Vector2i(-2, 0)] = [B.WALL, W]
	main.find_shaky()
	check(main.shaky.is_empty(), "e con un muro entro 2 caselle")
	main.built.erase(mid + Vector2i(-2, 0))
	main.find_shaky()
	check(main.shaky.keys() == [mid], "tolti, di nuovo pericolante")
	# il crollo: 1 su 4 al giorno; macerie, chi è sotto si ferisce e si ritrova accanto, quello che c'era si perde
	var victim = main.colonists[0]
	victim.gear.clear()
	victim.hp = main.MAX_HP
	victim.pos = main.center(mid)
	main.furniture[mid] = [B.CHAIR, W, 0]
	main.built[mid] = [B.FLOOR, W]
	var told: int = main.chronicle.size()
	var hours := 0
	while not main.rubble.has(mid) and hours < 24 * 40:
		main.collapse_hour()
		hours += 1
	check(main.rubble.has(mid) and hours > 1, "prima o poi cede (dopo %d ore)" % hours)
	check(main.rocks.has(mid) and main.astar.is_point_solid(mid) and not main.caves.has(mid), "macerie: roccia di nuovo, non ci si passa")
	check(main.chronicle.size() == told + 1 and main.chronicle[-1].contains("gave way"), "lo dice la cronaca")
	check(not main.furniture.has(mid) and not main.built.has(mid), "mobili e pavimento si perdono")
	check(is_equal_approx(victim.hp, main.MAX_HP - main.COLLAPSE_HURT) and main.cell_of(victim.pos) != mid \
		and not main.astar.is_point_solid(main.cell_of(victim.pos)), "chi era sotto si ferisce e ne esce")
	check(main.shaky.is_empty(), "le macerie reggono: il crollo si ferma")
	check(main.describe(mid) == ["Rubble", "Stone left: 2 / 2"] and main.full_stock(mid) == main.RUBBLE_STONE, "le macerie: poca pietra")
	check(tile(0, mid) != tile(1, mid), "a cima tolta si vedono i sassi caduti")
	var quiet: int = main.chronicle.size()
	for i in 24 * 5:
		main.collapse_hour()
	check(main.rubble.size() == 1 and main.chronicle.size() == quiet, "poi più niente")
	# con l'elmo fa meno male
	var helmed = main.colonists[1]
	helmed.gear = {main.Slot.HEAD: main.Res.HELMET}
	helmed.hp = main.MAX_HP
	check(main.armor_factor(helmed) < 1.0, "l'elmo ripara")
	# le macerie si scavano di nuovo: 2 pietra, e il centro torna pericolante
	var digger = main.colonists[2]
	digger.pos = main.center(mid + Vector2i.LEFT)
	digger.skills[main.Skill.MINING] = main.SKILL_MAX
	var stone: int = main.total(main.Res.STONE)
	main.order = main.Order.MINE
	main.mark(Rect2i(mid, Vector2i.ONE))
	main.order = main.Order.NONE
	check(main.mine_marks.has(mid), "le macerie si segnano")
	for i in 2000:
		main.tick(0.05)
		if not main.rocks.has(mid):
			break
	check(not main.rubble.has(mid) and main.caves.has(mid) and main.total(main.Res.STONE) == stone + main.RUBBLE_STONE, "scavate: 2 pietra, di nuovo galleria")
	check(main.shaky.has(mid), "e di nuovo senza sostegno")

	print("OK: gallerie, imbocco, la cima che copre, stanze nella roccia; crolli, puntelli, macerie")
	quit()


# i pixel della casella `k` nell'immagine del massiccio (0 aperta, 1 con la cima)
func tile(closed: int, k: Vector2i) -> PackedByteArray:
	return main.rock_images[closed].get_region(Rect2i(k * main.TILE, Vector2i.ONE * main.TILE)).get_data()


# Un posto dove scavare una galleria e una stanza: [le caselle della galleria da fuori verso dentro, il blocco 7x7 tutto
# dentro il massiccio a cui arriva]. La galleria è dritta, da sinistra, e parte da una casella con l'aperto accanto
func dig_site() -> Array:
	for start in main.massif:
		if main.rocks.has(start + Vector2i.LEFT) or not main.astar.is_in_boundsv(start + Vector2i.LEFT) \
				or main.astar.is_point_solid(start + Vector2i.LEFT):
			continue
		var way := [start]
		while way.size() < 16 and main.massif.has(way[-1] + Vector2i.RIGHT):
			way.append(way[-1] + Vector2i.RIGHT)
			var block := Rect2i(way[-1] + Vector2i(0, -2), Vector2i(7, 7))
			if way.size() >= 3 and main.cells_in(block).all(func(k): return main.deep(k)) and way.slice(1).all(func(k): return main.deep(k)):
				return [way, block]
	check(false, "c'è un posto dove scavare")
	return []


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
