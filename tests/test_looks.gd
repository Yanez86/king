# Esegui: godot --headless --path . -s tests/test_looks.gd
# Aspetto: sesso (nome, acconciatura, scheda) e livelli dello sprite secondo l'equipaggiamento
extends SceneTree


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(1)
	var main = load("res://main.tscn").instantiate()
	main.game_start = false
	root.add_child(main)
	await process_frame
	main.events = false

	# fogli: una voce di 4 direzioni (64 px) per ogni riga di Held, Look e acconciatura
	var cell_h: int = 4 * main.TILE
	check(main.COLONIST_HANDS.get_height() == main.Held.size() * cell_h, "un foglio di mani per ogni Held")
	check(main.COLONIST_GEAR.get_height() == main.Look.size() * cell_h, "un foglio di equipaggiamento per ogni Look")
	check(main.COLONIST_HAIR_STYLES.get_height() == 3 * cell_h, "capelli lunghi, treccia e barba")
	for res in main.GEAR:
		check(main.GEAR[res].has("look"), "ogni pezzo si vede addosso: %s" % main.Res.keys()[res])

	# sesso: nome e acconciatura del suo sesso, barba solo gli uomini
	var seen := {}
	for i in 200:
		var c = main.Colonist.new()
		main.dress(c)
		seen[c.sex] = true
		check(c.first_name in main.FIRST_NAMES[c.sex], "nome del suo sesso")
		check(c.hair_style in main.HAIR_STYLES[c.sex], "acconciatura del suo sesso")
		check(not (c.beard and c.sex == main.Sex.FEMALE), "niente barba alle donne")
	check(seen.size() == 2, "nascono uomini e donne")
	for c in main.colonists:
		check(c.first_name in main.FIRST_NAMES[c.sex], "i coloni di partenza hanno un sesso e un nome adatto")

	# la scheda dice il sesso, con l'icona
	var c = main.colonists[0]
	c.sex = main.Sex.FEMALE
	main.open_sheet(c)
	var box = main.get_node("HUD/ColonistSheet/Box")
	check(box.get_node("Sex/Label").text == "Female, %d years old" % main.age_of(c), "la scheda dice il sesso e l'età")
	check(box.get_node("Sex/Icon").texture == main.SEX_ICONS[main.Sex.FEMALE], "e ne mostra l'icona")
	c.sex = main.Sex.MALE
	main.open_sheet(c)
	check(box.get_node("Sex/Label").text.begins_with("Male, "), "uomo")

	# livelli: a mani vuote l'attrezzo qualunque, niente armatura né copricapo
	c.gear.clear()
	c.hair_style = main.Hair.SHORT
	c.beard = false
	var layers: Array = main.figure_layers(c)
	check(layers.size() == 5, "corpo, maglia, mantello, capelli e mani")
	check(layers[-1][0] == main.COLONIST_HANDS and layers[-1][1] == main.Held.TOOL, "a mani vuote un attrezzo qualunque")
	# guerriero: cotta sopra la maglia, elmo sopra i capelli, spada in mano
	c.gear = {main.Slot.BODY: main.Res.CHAINMAIL, main.Slot.HEAD: main.Res.HELMET, main.Slot.HANDS: main.Res.SWORD}
	c.beard = true
	layers = main.figure_layers(c)
	var rows: Array = layers.map(func(l): return [l[0], l[1]])
	var at := func(sheet, row): return rows.find([sheet, row])
	check(at.call(main.COLONIST_GEAR, main.Look.CHAINMAIL) > at.call(main.COLONIST_TUNIC, 0), "la cotta copre la maglia")
	check(at.call(main.COLONIST_GEAR, main.Look.HELMET) > at.call(main.COLONIST_HAIR, 0), "l'elmo copre i capelli")
	check(at.call(main.COLONIST_HAIR_STYLES, main.BEARD) > 0, "la barba")
	check(layers[-1][1] == main.Held.SWORD, "la spada in mano, sopra a tutto")
	# donna col cappuccio di cuoio (tinto) e l'arco; la treccia esce dal cappuccio
	c.sex = main.Sex.FEMALE
	c.beard = false
	c.hair_style = main.Hair.BRAID
	c.gear = {main.Slot.BODY: main.Res.LEATHER_ARMOR, main.Slot.HEAD: main.Res.LEATHER_HOOD, main.Slot.HANDS: main.Res.BOW}
	layers = main.figure_layers(c)
	var hood: Array = layers.filter(func(l): return l[0] == main.COLONIST_GEAR and l[1] == main.Look.HOOD)
	check(hood.size() == 1 and hood[0][2] == main.GEAR[main.Res.LEATHER_HOOD]["tint"], "il cappuccio, color cuoio")
	check(layers.any(func(l): return l[0] == main.COLONIST_HAIR_STYLES and l[1] == main.Hair.BRAID - 1), "la treccia")
	check(layers[-1][1] == main.Held.BOW, "l'arco")
	# ogni livello ha pixel nel fotogramma da fermo, guardando giù (non è una voce vuota del foglio)
	for l in layers:
		var img: Image = l[0].get_image()
		var src: Rect2 = main.layer_src(Rect2(0, 0, main.TILE, main.TILE), l)
		var full := false
		for y in range(src.position.y, src.end.y):
			for x in range(src.position.x, src.end.x):
				full = full or img.get_pixel(x, y).a > 0.0
		check(full or l[0] == main.COLONIST_HAIR_STYLES, "livello disegnato: %s riga %d" % [l[0].resource_path, l[1]])
	# disegnarlo (sulla mappa e nelle ombre) non dà errori
	c.pos = main.center(main.MAP_SIZE / 2)
	main.queue_redraw()
	await process_frame
	await process_frame
	print("OK: sesso e aspetto")
	quit()


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
