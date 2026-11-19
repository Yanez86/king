# Esegui: godot --headless --path . -s tests/test_saves.gd
# Salvataggi automatici: una partita a metà lavoro (alberi da tagliare, un magazzino, una strada, una palizzata, un
# muro intonacato, un tetto consumato, ghiaccio da tagliare, un avventuriero, un lupo che insegue un colono) salvata
# nella cartella della sua colonia, riletta e rimessa in una scena nuova è la stessa: lo stato, gli oggetti e i
# riferimenti tra loro, la griglia dei percorsi, tetti e magazzini. Poi le due partite, col caso uguale, vanno avanti
# uguali: se divergono c'è qualcosa che conta e non si salva (vedi SAVED in main.gd). Inoltre: i file a rotazione, il
# salvataggio rovinato, l'elenco delle colonie, il salvataggio dell'alba e quello appena fondata la colonia
extends SceneTree

const SAVES := preload("res://saves.gd")
const DIR := "user://test_saves"  # non la cartella dei salvataggi: le prove non compaiono nell'elenco di chi gioca
const COLONY := "Testford_1"


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	SAVES.dir = DIR
	clear()
	seed(1)
	var main = load("res://main.tscn").instantiate()
	main.game_start = false
	main.settings_file = ""
	root.add_child(main)
	await process_frame
	check(main.game_id == "" and SAVES.list().is_empty(), "nei test, senza cartella, non si salva")
	main.events = false  # i lupi li mette la prova
	main.deaths = false  # a terra sì, morti no: il sovrano resta il primo dei coloni
	main.atmosphere.climate = false  # temperatura fissa: le due partite non devono dipendere dal meteo che si muove
	var W: int = main.Res.WOOD
	var mid: Vector2i = main.MAP_SIZE / 2

	# un magazzino 5x5 nel prato più vicino alla radura, la porta in basso (le piante tolte); sotto la porta una
	# strada, in un angolo una palizzata
	var spots := []
	for y in range(mid.y - 25, mid.y + 17):
		for x in range(mid.x - 25, mid.x + 17):
			if not Rect2i(x, y, 9, 9).intersects(Rect2i(mid - Vector2i(5, 5), Vector2i(11, 11))):
				spots.append(Rect2i(x, y, 9, 9))
	spots.sort_custom(func(a, b): return Vector2(a.get_center() - mid).length() < Vector2(b.get_center() - mid).length())
	var spot := Rect2i()
	for cand in spots:
		if main.cells_in(cand).all(func(k): return not main.water.has(k) and not main.astar.is_point_solid(k) \
				and main.items.values().all(func(ground): return not ground.has(k))):
			spot = cand
			break
	check(spot.size != Vector2i.ZERO, "c'è posto per un magazzino")
	for k in main.cells_in(spot):
		for plants in [main.trees, main.bushes, main.weeds, main.flax]:
			plants.erase(k)
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
	main.update_roofs()
	main.blueprints[door + Vector2i.DOWN] = [main.Build.ROAD, main.Res.STONE]
	main.build(door + Vector2i.DOWN)
	main.blueprints[spot.position] = [main.Build.PALISADE, W]
	main.build(spot.position)
	# un muro intonacato, un tetto un po' consumato, del ghiaccio da tagliare
	main.plastered[spot.position + Vector2i(1, 1)] = true
	var roof_cell: Vector2i = main.roofed.keys()[0]
	main.wear[roof_cell] = 0.4
	main.ice_marks[main.water.keys()[0]] = true
	# lavoro a metà: alberi da tagliare vicino alla radura, legna a terra da portare in magazzino
	main.order = main.Order.CHOP
	main.mark(Rect2i(mid - Vector2i(10, 10), Vector2i(20, 20)))
	main.order = main.Order.NONE
	main.drop(W, mid + Vector2i(0, 2), 30)
	# un avventuriero spuntato alla bacheca
	var hero = main.new_hero(main.Hero.ARCHER, 2)
	hero.pos = main.center(mid + Vector2i(1, 2))
	hero.stay_until = main.clock + 3.0
	main.guests.append(hero)
	main.board_pick.append(hero)
	for i in 1500:  # 75 secondi: chi taglia, chi porta, prenotazioni e percorsi a metà
		main.tick(0.05)
	check(main.colonists.any(func(c): return c.job != main.Job.NONE), "si lavora")
	var wolf = main.add_animal(main.Beast.WOLF, mid + Vector2i(12, 0))  # appena arrivato: in 75 secondi lo si scaccia
	wolf.target = main.colonists[1]
	wolf.leave_at = main.clock + 1.0
	main.tick(0.05)

	# salvato nella cartella della colonia e riletto
	main.game_id = COLONY
	var state: Dictionary = main.game_state()
	check(main.save_game() == OK and FileAccess.file_exists(SAVES.path_for(COLONY)), "scritto nella cartella della colonia")
	var all := SAVES.list()
	check(all.size() == 1 and all[0]["folder"] == COLONY and all[0].get("version") == SAVES.VERSION
		and all[0].get("title") == main.realm_name() and all[0].get("people") == main.colonists.size()
		and all[0].get("ruler") == main.full_name(main.ruler), "l'elenco delle colonie, con la sua intestazione")
	var loaded := SAVES.read_colony(COLONY)
	check(loaded == state, "riletto uguale a com'era")

	# a rotazione: al più FILES file, il primo il più recente; se si rovina, quello prima
	for i in SAVES.FILES + 1:
		check(main.save_game() == OK, "salvato di nuovo")
	check(range(1, SAVES.FILES + 1).all(func(n): return FileAccess.file_exists(SAVES.path_for(COLONY, n)))
		and not FileAccess.file_exists(SAVES.path_for(COLONY, SAVES.FILES + 1)), "%d file, non di più" % SAVES.FILES)
	check(DirAccess.get_files_at(DIR.path_join(COLONY)).size() == SAVES.FILES, "niente file a metà")
	var broken := FileAccess.open(SAVES.path_for(COLONY), FileAccess.WRITE)
	broken.store_string("rovinato")
	broken.close()
	check(SAVES.read_colony(COLONY) == state and SAVES.list().size() == 1, "rovinato l'ultimo, si riprende da quello prima")

	# rimessa in una scena nuova, come fa Load
	SAVES.pending = loaded
	var copy = load("res://main.tscn").instantiate()
	copy.game_start = false
	copy.settings_file = ""
	root.add_child(copy)
	check(SAVES.pending.is_empty(), "lo stato l'ha preso _ready")
	check(copy.game_id == COLONY, "la stessa colonia: si salva nella sua cartella")
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
		and copy.pantry == main.pantry, "il magazzino")
	check(copy.roofs.size() == main.roofs.size() and copy.roofed.keys() == main.roofed.keys()
		and copy.roofed.values().all(func(r): return r.room == copy.rooms[0]), "i tetti, rifatti sulla stanza ricaricata")
	check(copy.wear == main.wear and copy.plastered == main.plastered and copy.ice_marks == main.ice_marks,
		"usura dei tetti, intonaco e ghiaccio da tagliare")
	var grid := true
	for y in main.MAP_SIZE.y:
		for x in main.MAP_SIZE.x:
			var k := Vector2i(x, y)
			grid = grid and copy.astar.is_point_solid(k) == main.astar.is_point_solid(k) \
				and copy.astar.get_point_weight_scale(k) == main.astar.get_point_weight_scale(k)
	check(grid, "la stessa griglia dei percorsi: roccia, acqua, muri, palizzata, strada")
	check(copy.ground_cols == main.ground_cols and copy.map_seed == main.map_seed and copy.gravel == main.gravel
		and not copy.gravel.is_empty(), "lo stesso terreno, con la roccia di partenza")
	check(copy.realm_button.text == main.realm_button.text, "il reame nella barra in alto")

	# avanti insieme: col caso uguale, le due partite restano uguali (senza cartella: niente salvataggi all'alba)
	main.game_id = ""
	copy.game_id = ""
	copy.events = false
	copy.deaths = false
	copy.atmosphere.climate = false
	for game in [main, copy]:
		seed(7)
		for i in 2000:  # 100 secondi
			game.tick(0.05)
	check(copy.game_state()["main"] == main.game_state()["main"] and copy.game_state()["objects"] == main.game_state()["objects"],
		"dopo 100 secondi ancora uguali")
	copy.queue_free()
	# all'alba si salva da sé; una colonia caduta no
	main.clock = floorf(main.clock) + 1.0 + (main.AUTOSAVE_HOUR - 0.01) / 24.0
	main.tick(0.05)  # passa l'ora: la nuova è quella prima dell'alba
	main.autosave_due = false
	main.clock += 0.02 / 24.0
	main.tick(0.05)
	check(main.autosave_due, "all'alba si salva")
	main.autosave_due = false
	main.game_id = COLONY
	main.fallen = true
	check(main.save_game() != OK, "caduta, non si salva")
	main.game_id = ""
	main.queue_free()

	# una colonia appena fondata (la cartella dalla pagina della nuova partita) compare subito nell'elenco
	var folder := SAVES.create("New Holm")
	check(folder.begins_with("New_Holm_"), "la cartella dal nome del reame")
	SAVES.founding = folder
	var fresh = load("res://main.tscn").instantiate()
	fresh.game_start = false
	fresh.settings_file = ""
	root.add_child(fresh)
	check(SAVES.founding == "" and fresh.game_id == folder, "la colonia nuova ha la sua cartella")
	check(SAVES.list().map(func(h): return h["folder"]) == [folder, COLONY], "salvata appena fondata, la più recente")
	SAVES.remove(folder)
	check(SAVES.list().map(func(h): return h["folder"]) == [COLONY], "cancellata, con tutti i suoi salvataggi")
	fresh.game_id = ""
	fresh.queue_free()

	clear()
	print("OK: salvataggi automatici e caricamento")
	quit()


# via la cartella delle prove
func clear() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for colony in DirAccess.get_directories_at(DIR):
		SAVES.remove(colony)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
