# Esegui: godot --headless --path . -s tests/test_saves.gd
# Salvataggio: una partita a metà lavoro (alberi da tagliare, un magazzino, una strada, una palizzata, un avventuriero,
# un lupo che insegue un colono) scritta su file, riletta e rimessa in una scena nuova è la stessa: lo stato, gli
# oggetti e i riferimenti tra loro, la griglia dei percorsi, tetti e magazzini. Poi le due partite, col caso uguale,
# vanno avanti uguali: se divergono c'è qualcosa che conta e non si salva (vedi SAVED in main.gd)
extends SceneTree

const SAVES := preload("res://saves.gd")
const FILE := "user://test_saves.save"  # fuori dalla cartella dei salvataggi: non compare nell'elenco di chi gioca


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(1)
	var main = load("res://main.tscn").instantiate()
	main.game_start = false
	main.settings_file = ""
	root.add_child(main)
	await process_frame
	main.threats = false  # i lupi li mette la prova
	main.deaths = false  # a terra sì, morti no: il sovrano resta il primo dei coloni
	main.atmosphere.climate = false  # temperatura fissa: le due partite non devono dipendere dal meteo che si muove
	var W: int = main.Res.WOOD
	var mid: Vector2i = main.MAP_SIZE / 2

	# un magazzino 5x5 nel prato più vicino alla radura, la porta in basso; sotto la porta una strada, in un angolo
	# una palizzata
	var spots := []
	for y in range(mid.y - 25, mid.y + 17):
		for x in range(mid.x - 25, mid.x + 17):
			if not Rect2i(x, y, 9, 9).intersects(Rect2i(mid - Vector2i(5, 5), Vector2i(11, 11))):
				spots.append(Rect2i(x, y, 9, 9))
	spots.sort_custom(func(a, b): return Vector2(a.get_center() - mid).length() < Vector2(b.get_center() - mid).length())
	var spot := Rect2i()
	for cand in spots:
		if main.cells_in(cand).all(func(k): return main.can_build(k)):
			spot = cand
			break
	check(spot.size != Vector2i.ZERO, "c'è posto per un magazzino")
	var door: Vector2i = spot.position + Vector2i(4, 7)
	for k in main.cells_in(spot.grow(-1)):
		if k == door:
			main.built[k] = [main.Build.DOOR, W]
		elif not spot.grow(-2).has_point(k):
			main.built[k] = [main.Build.WALL, W]
			main.astar.set_point_solid(k)
	main.update_rooms()
	check(main.rooms.size() == 1, "murato")
	main.retype(main.rooms[0], main.RoomKind.WAREHOUSE)
	main.update_stockpile()
	main.blueprints[door + Vector2i.DOWN] = [main.Build.ROAD, main.Res.STONE]
	main.build(door + Vector2i.DOWN)
	main.blueprints[spot.position] = [main.Build.PALISADE, W]
	main.build(spot.position)
	# lavoro a metà: alberi da tagliare vicino alla radura, legna a terra da portare in magazzino
	main.order = main.Order.CHOP
	main.mark(Rect2i(mid - Vector2i(10, 10), Vector2i(20, 20)))
	main.order = main.Order.NONE
	main.drop(W, mid + Vector2i(0, 2), 30)
	# un avventuriero spuntato alla bacheca, un lupo che insegue il secondo colono
	var hero = main.new_hero(main.Hero.ARCHER, 2)
	hero.pos = main.center(mid + Vector2i(1, 2))
	hero.stay_until = main.clock + 3.0
	main.guests.append(hero)
	main.board_pick.append(hero)
	var wolf = main.add_animal(main.Beast.WOLF, mid + Vector2i(12, 0))
	wolf.target = main.colonists[1]
	wolf.leave_at = main.clock + 1.0
	for i in 1500:  # 75 secondi: chi taglia, chi porta, prenotazioni e percorsi a metà
		main.tick(0.05)
	check(main.colonists.any(func(c): return c.job != main.Job.NONE), "si lavora")

	# scritto e riletto
	var state: Dictionary = main.game_state()
	check(SAVES.write(FILE, main.header(), state) == OK and FileAccess.file_exists(FILE), "scritto su file")
	var header := SAVES.read_header(FILE)
	check(header.get("version") == SAVES.VERSION and header.get("title") == main.realm_name()
		and header.get("people") == main.colonists.size() and header.get("ruler") == main.full_name(main.ruler), "intestazione")
	var loaded := SAVES.read_state(FILE)
	check(loaded == state, "riletto uguale a com'era")

	# rimesso in una scena nuova, come fa Load
	SAVES.pending = loaded
	var copy = load("res://main.tscn").instantiate()
	copy.game_start = false
	copy.settings_file = ""
	root.add_child(copy)
	check(SAVES.pending.is_empty(), "lo stato l'ha preso _ready")
	check(copy.game_state() == state, "la partita ricaricata è la stessa")
	check(Engine.time_scale == 0.0, "e riparte in pausa")
	Engine.time_scale = 1.0
	check(copy.ruler == copy.colonists[0] and copy.ruler != main.ruler, "il sovrano: un oggetto nuovo, lo stesso dei coloni")
	check(copy.reserved.values().all(func(c): return c in copy.colonists or c in copy.guests), "prenotazioni dei coloni ricaricati")
	check(copy.board_pick.size() == 1 and copy.board_pick[0] in copy.guests, "alla bacheca lo stesso avventuriero")
	var wolves: Array = copy.animals.filter(func(a): return a.kind == copy.Beast.WOLF)
	check(wolves.size() == 1 and (wolves[0].target == null or wolves[0].target in copy.colonists), "il lupo insegue uno dei coloni ricaricati")
	check(copy.colonists.all(func(c): return c.path.is_typed()) and copy.rooms.is_typed(), "array tipizzati come prima")
	check(copy.rooms.size() == 1 and copy.rooms[0].kind == copy.RoomKind.WAREHOUSE and copy.stockpile == main.stockpile
		and copy.pantry == main.pantry and copy.roofed == main.roofed, "magazzino e tetti")
	var grid := true
	for y in main.MAP_SIZE.y:
		for x in main.MAP_SIZE.x:
			var k := Vector2i(x, y)
			grid = grid and copy.astar.is_point_solid(k) == main.astar.is_point_solid(k) \
				and copy.astar.get_point_weight_scale(k) == main.astar.get_point_weight_scale(k)
	check(grid, "la stessa griglia dei percorsi: roccia, acqua, muri, palizzata, strada")
	check(copy.ground_cols == main.ground_cols and copy.map_seed == main.map_seed, "lo stesso terreno")
	check(copy.realm_button.text == main.realm_button.text, "il reame nella barra in alto")

	# avanti insieme: col caso uguale, le due partite restano uguali
	copy.threats = false
	copy.deaths = false
	copy.atmosphere.climate = false
	for game in [main, copy]:
		seed(7)
		for i in 2000:  # 100 secondi
			game.tick(0.05)
	check(copy.game_state()["main"] == main.game_state()["main"] and copy.game_state()["objects"] == main.game_state()["objects"],
		"dopo 100 secondi ancora uguali")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	print("OK: salvataggio e caricamento")
	quit()


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
