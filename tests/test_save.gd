# Esegui: godot --headless --path . -s tests/test_save.gd
# Salvataggi: una colonia giocata quasi un giorno si salva, si ricarica uguale e continua; file a rotazione e di riserva
extends SceneTree

const Saves := preload("res://saves.gd")
const COLONY := "test_colony"


func _initialize() -> void:
	seed(1)
	Saves.remove(COLONY)  # avanzi di una prova interrotta
	var main = load("res://main.tscn").instantiate()
	main.colony = COLONY
	main.colony_name = "Testford"
	root.add_child(main)
	await process_frame
	check(FileAccess.file_exists(Saves.path(COLONY)), "colonia nuova: salvata subito")
	check(not FileAccess.file_exists(Saves.path(COLONY, 2)), "un file solo, all'inizio")

	# un po' di vita: alberi da tagliare, un masso da scavare, un pavimento e una panca, una stanza col suo nome
	var mid: Vector2 = main.center(main.MAP_SIZE / 2)
	var trees: Array = main.trees.keys()
	main.sort_by_distance(trees, mid)
	for cell in trees.slice(0, 3):
		main.chop_marks[cell] = true
	var boulders: Array = main.boulders.keys()
	main.sort_by_distance(boulders, mid)
	main.mine_marks[boulders[0]] = true
	var free: Array = main.cells_in(Rect2i(main.MAP_SIZE / 2 - Vector2i(3, 3), Vector2i(7, 7))).filter(func(k): return main.can_build(k))
	main.blueprints[free[0]] = [main.Build.FLOOR, main.Res.WOOD]
	main.furniture_plans[free[1]] = [main.Build.LAMP, main.Res.WOOD, 0]
	main.rooms[1].name = "Barracks"
	main.rooms[1].owners.assign([main.colonists[0]])
	for i in 5000:  # 250 secondi: passa l'alba del secondo giorno
		main.tick(0.05)
	for i in 6000:  # e il masso finisce scavato (di giorno si lavora)
		if main.rocks.size() < main.gravel.size():
			break
		main.tick(0.05)
	check(FileAccess.file_exists(Saves.path(COLONY, 2)), "all'alba un altro salvataggio, il primo scorre al secondo posto")
	check(main.next_save > main.clock and main.next_save == floorf(main.next_save) + main.DAWN, "il prossimo all'alba dopo")
	main.spawn_pack()  # lupi che inseguono qualcuno: riferimenti da animale a colono
	for i in 100:
		main.tick(0.05)
	check(main.animals.any(func(a): return a.target != null), "un lupo insegue un colono")
	check(main.rocks.size() < main.gravel.size(), "un masso è stato scavato")

	var started := Time.get_ticks_usec()
	main.autosave()
	var took := (Time.get_ticks_usec() - started) / 1000.0
	var size := FileAccess.get_file_as_bytes(Saves.path(COLONY)).size()
	var before := snapshot(main)
	var image: PackedByteArray = main.ground_texture.get_image().get_data()
	var data := Saves.read(COLONY)
	check(data.info.name == "Testford" and data.info.colonists == 3 and data.info.day == int(main.clock) + 1, "info per l'elenco")
	root.remove_child(main)
	main.free()

	var loaded = load("res://main.tscn").instantiate()
	loaded.colony = COLONY
	loaded.saved = data
	root.add_child(loaded)  # _ready carica: confronto prima che passi il tempo
	var after := snapshot(loaded)
	for key in before:
		check(before[key] == after[key], "uguale dopo il caricamento: " + key)
	check(loaded.ground_texture.get_image().get_data() == image, "terreno disegnato uguale, ghiaia sotto gli scavi compresa")
	check(loaded.colonists.all(func(c): return c.job == loaded.Job.NONE and c.carrying == 0 and c.fetched.is_empty()),
		"caricando nessuno ha lavori a metà né roba in mano")
	await process_frame
	var busy := false
	for i in 2000:  # e continua: lavori, lupi (i feriti poi restano al chiuso finché ci sono, senza lavoro)
		loaded.tick(0.05)
		busy = busy or loaded.colonists.any(func(c): return c.job != loaded.Job.NONE)
	check(busy, "dopo il caricamento si lavora (e si combatte) di nuovo")

	# file: al più FILES, e se il primo è rovinato si legge quello prima
	for i in 3:
		loaded.autosave()
	var files := DirAccess.get_files_at(Saves.ROOT + "/" + COLONY)
	check(files.size() == Saves.FILES, "al più %d file per colonia: %s" % [Saves.FILES, files])
	var second := Saves.read_file(Saves.path(COLONY, 2))
	var broken := FileAccess.open(Saves.path(COLONY), FileAccess.WRITE)
	broken.store_string("rovinato")
	broken.close()
	check(Saves.read(COLONY).info.saved_at == second.info.saved_at, "primo file rovinato: si legge il secondo")
	check(Saves.colonies().any(func(c): return c.folder == COLONY), "la colonia è nell'elenco")
	Saves.remove(COLONY)
	check(not DirAccess.dir_exists_absolute(Saves.ROOT + "/" + COLONY), "colonia cancellata")
	print("OK: salvataggi (%d coloni, %d animali; un salvataggio: %d KB in %.0f ms)" % [before.colonists.size(),
		before.animals.size(), size / 1024, took])
	quit()


# Lo stato che il caricamento deve riportare uguale. Le risorse si contano in totale: quelle in mano tornano a terra.
func snapshot(main) -> Dictionary:
	var names := func(list): return list.map(func(c): return c.first_name + c.last_name)
	var solid := []
	var weights := {}
	for y in main.MAP_SIZE.y:
		for x in main.MAP_SIZE.x:
			var cell := Vector2i(x, y)
			if main.astar.is_point_solid(cell):
				solid.append(cell)
			if main.astar.get_point_weight_scale(cell) != 1.0:
				weights[cell] = main.astar.get_point_weight_scale(cell)
	return {
		"clock": main.clock, "next_animal": main.next_animal, "next_pack": main.next_pack, "wild": main.wild.state,
		"camera": main.camera.position, "seed": main.map_seed, "solid": solid, "weights": weights,
		"totals": main.Res.values().map(main.total), "stockpile": main.stockpile.keys(),
		"trees": main.trees.duplicate(), "rocks": main.rocks.duplicate(), "boulders": main.boulders.duplicate(),
		"ores": main.ores.duplicate(), "water": main.water.duplicate(), "bushes": main.bushes.duplicate(),
		"weeds": main.weeds.duplicate(), "stock": main.stock.duplicate(), "chop": main.chop_marks.duplicate(),
		"mine": main.mine_marks.duplicate(), "built": main.built.duplicate(true),
		"blueprints": main.blueprints.duplicate(true), "furniture": main.furniture.duplicate(true),
		"furniture_plans": main.furniture_plans.duplicate(true),
		"rooms": main.rooms.map(func(r): return [r.cells.keys().min(), r.cells.size(), r.door, r.name, r.kind, r.banned,
			names.call(r.owners)]),
		"colonists": main.colonists.map(func(c): return [c.first_name, c.nickname, c.last_name, c.hp, c.downed,
			c.skills.duplicate(), c.xp.duplicate(), c.needs.duplicate(), c.traits.duplicate(), c.conds.duplicate(),
			c.pos, c.facing, c.tunic, c.cape, c.hair, c.gear.duplicate(), c.worked, c.workday, c.streak, c.pause_until,
			c.hour]),
		"animals": main.animals.map(func(a): return [a.kind, a.pos, a.damage, a.marked, a.leave_at, a.left,
			a.target.first_name if a.target else ""]),
	}


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
