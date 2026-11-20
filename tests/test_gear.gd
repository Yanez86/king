# Esegui: godot --headless --path . -s tests/test_gear.gd
# Abilità costruire, pelli, forgia, sartoria, equipaggiamento e i suoi effetti
extends SceneTree


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(1)
	var main = load("res://main.tscn").instantiate()
	main.game_start = false
	root.add_child(main)
	await process_frame
	main.researched.erase(main.Tech.STEEL)  # qui attrezzi e spade di ferro: l'acciaio è in test_research
	main.needs_rate = 0.0
	main.routines = false  # niente orari: la routine è provata in test_jobs
	main.events = false  # niente branchi di lupi: le prove del combattimento sono in test_combat
	main.animals.clear()
	main.bushes.clear()
	main.flax.clear()
	main.weeds.clear()
	var W: int = main.Res.WOOD
	var I: int = main.Res.INGOT
	var area := Rect2i(main.MAP_SIZE / 2 - Vector2i(10, 10), Vector2i(20, 20))
	var free: Array = main.cells_in(area).filter(func(k): return main.can_build(k))
	main.sort_by_distance(free, main.center(main.MAP_SIZE / 2))
	check(free.size() > 60, "c'è posto vicino alla partenza")
	var smith = main.colonists[0]
	var tailor = main.colonists[1]
	var hunter = main.colonists[2]

	# costruire: il tempo segue il livello, ogni pezzo finito 1 punto esperienza
	for c in main.colonists:
		c.skills[main.Skill.CONSTRUCTION] = 1
	main.add_item(W, free[0], 20)
	main.blueprints[free[3]] = [main.Build.FLOOR, W]
	var started := false
	for i in 400:
		main.tick(0.05)
		for c in main.colonists:
			if c.job == main.Job.BUILD and not started:
				started = true
				check(is_equal_approx(c.work_total, main.BUILD_TIME * 1.4), "costruire a livello 1: 40% di tempo in più")
	check(started and main.built.has(free[3]), "pavimento fatto")
	check(is_equal_approx(main.colonists.reduce(func(n, c): return n + c.xp[main.Skill.CONSTRUCTION], 0.0), main.BUILD_TIME * main.XP_PER_SECOND),
		"esperienza per pezzo costruito: i suoi 2 secondi di lavoro")
	main.built.erase(free[3])
	main.add_item(W, free[0], -main.items[W].get(free[0], 0))
	for k in main.items[W].keys():
		main.add_item(W, k, -main.items[W][k])

	# effetti dell'equipaggiamento: solo il pezzo che li ha
	var guy = main.Colonist.new()
	guy.skills = main.Skill.values().map(func(_s): return 5)
	guy.needs = [100.0, 100.0, 100.0, 100.0, 100.0, 0.0]
	check(main.work_factor(guy, main.Job.MINE) == 1.0 and main.gear_sum(guy, "armor") == 0.0, "senza niente: nessun effetto")
	guy.gear = {main.Slot.HANDS: main.Res.PICKAXE, main.Slot.HEAD: main.Res.HELMET}
	check(is_equal_approx(main.work_factor(guy, main.Job.MINE), 0.75 * 0.9) and main.work_factor(guy, main.Job.CHOP) == 1.0,
		"piccone ed elmo: si scava più in fretta, si taglia come prima")
	check(is_equal_approx(main.gather_time(guy, main.Job.MINE), main.GATHER[main.Job.MINE][1] * 0.675), "anche nel tempo per colpo")
	guy.gear = {main.Slot.BODY: main.Res.CHAINMAIL}
	check(is_equal_approx(main.work_factor(guy, main.Job.CHOP), 1.1) and main.gear_sum(guy, "armor") == 5.0, "cotta: protegge ma rallenta tutto")
	guy.gear = {main.Slot.BODY: main.Res.LEATHER_ARMOR}
	guy.pos = main.center(free[5])
	guy.job = main.Job.HAUL
	main.update_needs(guy, 10.0)
	var leather_stress: float = guy.needs[main.Need.STRESS]
	guy.gear = {main.Slot.BODY: main.Res.CHAINMAIL}
	guy.needs[main.Need.STRESS] = 0.0
	main.update_needs(guy, 10.0)
	check(is_equal_approx(leather_stress, guy.needs[main.Need.STRESS] * 0.75), "cuoio: meno stress lavorando fuori, la cotta no")
	guy.gear = {main.Slot.HANDS: main.Res.BOW, main.Slot.HEAD: main.Res.LEATHER_HOOD}
	guy.skills[main.Skill.RANGED] = 9
	check(main.hunt_range(guy) == main.HUNT_RANGE + 2 and main.hunt_level(guy) == 9 and is_equal_approx(main.gear_sum(guy, "hit"), 0.15),
		"arco e cappuccio: più lontano, mira con armi a distanza, più colpi a segno")
	guy.gear = {}
	check(main.hunt_level(guy) == 5 and main.hunt_range(guy) == main.HUNT_RANGE, "senza arco conta solo la caccia")

	# l'attrezzo che ognuno vuole: quello della sua abilità migliore
	for c in main.colonists:
		for s in [main.Skill.MINING, main.Skill.WOODCUTTING, main.Skill.GATHERING, main.Skill.HUNTING, main.Skill.MELEE]:
			c.skills[s] = 1
	smith.skills[main.Skill.MINING] = 9
	tailor.skills[main.Skill.WOODCUTTING] = 9
	hunter.skills[main.Skill.HUNTING] = 9
	check(main.wanted_tool(smith) == main.Res.PICKAXE and main.wanted_tool(tailor) == main.Res.AXE and main.wanted_tool(hunter) == main.Res.BOW,
		"piccone al minatore, ascia al taglialegna, arco al cacciatore")

	# caccia: l'animale abbattuto lascia anche la pelle
	var rabbit = main.Animal.new()
	rabbit.pos = main.center(free[40])
	rabbit.marked = true
	main.animals.append(rabbit)
	hunter.skills[main.Skill.HUNTING] = 10
	hunter.gear = {main.Slot.HANDS: main.Res.BOW}  # si caccia solo con l'arco
	for i in 6000:
		main.tick(0.05)
		if rabbit not in main.animals:
			break
	check(rabbit not in main.animals and main.total(main.Res.HIDE) == main.BEASTS[main.Beast.RABBIT]["hide"], "il coniglio lascia una pelle")
	for r in [main.Res.HIDE, main.Res.MEAT]:
		for k in main.items[r].keys():
			main.add_item(r, k, -main.items[r][k])
	hunter.skills[main.Skill.HUNTING] = 9

	# forgia: stanza di prova con fornace e incudine; magazzino; ferro, carbone e legna
	var forge = main.Room.new()
	var spot: Vector2i = Vector2i.ZERO
	for k in free:  # 3x3 libero
		if main.cells_in(Rect2i(k, Vector2i(3, 3))).all(func(h): return free.has(h)):
			spot = k
			break
	check(spot != Vector2i.ZERO, "c'è posto per la forgia")
	for k in main.cells_in(Rect2i(spot, Vector2i(3, 3))):
		forge.cells[k] = true
	forge.kind = main.RoomKind.FORGE
	main.rooms.append(forge)
	var furnace: Vector2i = spot + Vector2i(0, 1)
	var anvil: Vector2i = spot + Vector2i(2, 1)
	main.furniture = {furnace: [main.Build.FURNACE, main.Res.STONE, 0], anvil: [main.Build.ANVIL, main.Res.IRON, 0]}
	check(main.stations(main.Build.FURNACE) == [furnace] and main.stations(main.Build.ANVIL) == [anvil], "postazioni della forgia")
	var rest: Array = free.filter(func(k): return not forge.cells.has(k))
	main.stockpile = {}
	for k in rest.slice(-20):
		main.stockpile[k] = true
	main.add_item(main.Res.IRON, rest[0], 50)
	main.add_item(main.Res.COAL, rest[1], 50)
	main.add_item(W, rest[2], 30)
	for c in main.colonists:
		c.skills[main.Skill.SMITHING] = 10  # niente pezzi rovinati
		c.gear = {}
	check(main.gear_wanted(I) == main.STOCK[I] and main.gear_wanted(main.Res.PICKAXE) == 1 and main.gear_wanted(main.Res.CHAINMAIL) == 3,
		"servono lingotti, un piccone, tre corpetti")
	check(main.job_list().contains("Make %s: 10" % main.item_name(I)) and main.job_list().contains("Make %s: 1" % main.item_name(main.Res.PICKAXE)),
		"finestra Jobs: cosa si fa, col tipo davanti al nome")
	main.open_craft(anvil)
	var menu: Control = main.get_node("HUD/CraftPopup/Box")
	check(menu.get_node("List").get_child_count() == 8, "menu dell'incudine: otto ricette (con lo scudo e il pugnale)")
	check(menu.get_node("Head/Lines/Sub/Where").text == "Forge, comfort %d" % main.room_comfort(forge)
		and menu.get_node("Head/Lines/Sub/Who").text == "nobody at work", "in testa la stanza col comfort e chi lavora")
	# il piccone lo chiede il minatore, ma senza lingotti è fermo: la riga dice perché, in rosso
	var pick: Control = menu.get_node("List/Pickaxe/Lines")
	check(main.gear_asked(main.Res.PICKAXE) == 1 and main.gear_asked(main.Res.CHAINMAIL) == 3 and main.gear_asked(I) == 0,
		"chi lo prenderebbe: un piccone, tre corpetti; i lingotti nessuno")
	check(pick.get_node("Main/Colonists").get_child(1).text == "1" and pick.get_node("Main/There are/Count").text == "0 / 1",
		"la riga del piccone: un colono lo chiede, 0 su 1")
	check(main.make_block(main.Res.PICKAXE) == "Short of ingot: takes 2, 0 free" and pick.get_node("Status").visible
		and pick.get_node("Status/Text").text == main.make_block(main.Res.PICKAXE) and not pick.get_node("Status/Bar").visible,
		"fermo: mancano i lingotti, e quanti")
	check(pick.get_node("Main/Tile").get_theme_stylebox("panel").border_color == main.MAKE_STUCK
		and pick.get_node("Main/There are/Pips").get_meta("state") == {"have": 0, "busy": 0, "want": 1, "stuck": true, "done": false},
		"il riquadro e la tacca in rosso")
	# la spada non la chiede nessuno: smorzata, finché non se ne vuole di scorta (+ e −)
	var sword: Control = menu.get_node("List/Sword/Lines")
	check(sword.get_node("Main/There are/Count").text == "not made" and not sword.get_node("Status").visible
		and sword.get_node("Main/Item").modulate.a < 1.0, "la spada non si fa")
	for i in 3:
		sword.get_node("Main/Spare/More").pressed.emit()
	sword.get_node("Main/Spare/Less").pressed.emit()
	check(main.keep[main.Res.SWORD] == 2 and main.gear_wanted(main.Res.SWORD) == 2, "spade di scorta chieste dal menu")
	check(sword.get_node("Main/Spare/Value").text == "2" and sword.get_node("Main/There are/Count").text == "0 / 2"
		and sword.get_node("Main/Item").modulate.a == 1.0, "e la riga si accende: 0 su 2")
	main.keep.erase(main.Res.SWORD)
	# le colonne sono larghe uguali in ogni riga, e il titolo sta sopra la sua
	var heads: Array = menu.get_node("ColumnsRow/Columns").get_children()
	for i in main.CRAFT_COLUMNS.size():
		var column: String = main.CRAFT_COLUMNS[i]
		var wide: float = heads[i + 1].custom_minimum_size.x
		check(heads[i + 1].text == column and wide > 0 and wide == pick.get_node("Main/" + column).custom_minimum_size.x
			and wide == sword.get_node("Main/" + column).custom_minimum_size.x, "colonna %s: allineata, col suo titolo" % column)
	main.craft_popup.hide()
	# le Officine della finestra Produzione: un riquadro per tipo di postazione costruita, nel loro ordine
	check(main.RECIPES.all(func(r): return r[1] in main.STATION_ORDER) and main.STATION_ORDER[0] == main.Build.CAMPFIRE,
		"ogni postazione delle ricette ha il suo posto tra le officine")
	main.tool("Production").button_pressed = true
	var shops: Control = main.production_panel.get_node("Box/Shops")
	check(main.production_panel.visible and shops.get_children().map(func(n): return String(n.name)) == ["Furnace", "Anvil"],
		"le officine: la fornace e l'incudine")
	var anvil_shop: Dictionary = main.shop_state(main.Build.ANVIL)
	check(anvil_shop["pieces"] == [anvil] and anvil_shop["block"] == "" and anvil_shop["workers"].is_empty()
		and anvil_shop["queue"].map(func(q): return q[0]) == [main.Res.PICKAXE, main.Res.AXE, main.Res.HELMET, main.Res.CHAINMAIL]
		and anvil_shop["queue"].map(func(q): return q[1]) == [1, 1, 3, 3] and anvil_shop["queue"].all(func(q): return q[2].begins_with("Short of ingot")),
		"all'incudine mancano un piccone, un'ascia, tre elmi e tre corpetti, tutti fermi senza lingotti")
	var card: Control = shops.get_node("Anvil")
	check(card.get_theme_stylebox("panel").border_color == main.MAKE_STUCK and card.get_node("Row/Lines/Idle").text == "Short of ingot: takes 2, 0 free"
		and card.get_node("Row/Lines/Next").get_child_count() == 1 + 2 * 4 and card.get_node("Row/Lines/Next/Chainmail").tooltip_text.contains("Short of ingot")
		and card.get_node("Row/Lines/Head/Name").text == "Anvil" and card.get_node("Row/Lines/Head/Where").text == "Forge",
		"il riquadro dell'incudine: rosso, col perché e gli oggetti che mancano")
	card = shops.get_node("Furnace")
	check(card.get_theme_stylebox("panel").border_color == main.CENSUS_BORDER and card.get_node("Row/Lines/Idle").text == "Free: waiting for someone with time"
		and card.get_node("Row/Lines/Next/Ingot") != null and card.get_node("Row/Lines/Next").get_child(2).text == "10",
		"la fornace: libera, con dieci lingotti da fare")
	var summary: String = main.production_panel.get_node("Box/Top/Summary").text
	check(summary.contains("0 at work") and summary.contains("1 waiting") and summary.contains("4 stopped"), "in alto il conto")
	main.open_shop(main.Build.FURNACE)
	check(main.craft_popup.visible and main.crafting == furnace, "clic su un'officina: il suo menu")
	main.craft_popup.hide()
	var iron0: int = main.total(main.Res.IRON)
	var seen_busy := false  # il menu della fornace mentre qualcuno fonde: chi, la barra, la tacca a metà
	for i in 60000:
		main.tick(0.05)
		check_station(main)
		var smelter: Array = main.colonists.filter(func(c): return c.job == main.Job.CRAFT and main.RECIPES[c.recipe][0] == I and c.work_left < c.work_total)
		if not seen_busy and not smelter.is_empty():
			seen_busy = true
			main.open_craft(furnace)
			var ingot: Control = menu.get_node("List/Ingot/Lines")
			var state: Dictionary = main.make_state(I)
			check(state["makers"] == main.station_workers(main.Build.FURNACE) and smelter[0] in state["makers"], "chi sta fondendo")
			check(ingot.get_node("Status").visible and ingot.get_node("Status/Bar").visible
				and ingot.get_node("Status/Text").text.begins_with(state["makers"][0].first_name)
				and ingot.get_node("Status/Text").text.ends_with("making it")
				and ingot.get_node("Main/Tile").get_theme_stylebox("panel").border_color == main.MAKE_BUSY,
				"la riga del lingotto: chi lo fa, con la barra, in arancio")
			check(ingot.get_node("Main/There are/Pips").get_meta("state")["busy"] == state["makers"].size()
				and ingot.get_node("Main/There are/Count").text == "%d / %d" % [state["have"], state["have"] + state["makers"].size() + state["missing"]],
				"le tacche: quelli che ci sono, quello in lavorazione, quelli che mancano")
			check(menu.get_node("Head/Lines/Sub/Who").text.ends_with(" at work") and menu.get_node("Head/Lines/Sub/Faces").get_child_count() == state["makers"].size(),
				"in testa chi lavora, con la figurina")
			main.craft_popup.hide()
			main.production_key = ""  # e le Officine: la fornace in arancio, con chi lavora e la sua barra
			main.fill_production()
			card = shops.get_node("Furnace")
			check(card.get_theme_stylebox("panel").border_color == main.MAKE_BUSY and card.get_node("Row/Lines/Now") != null
				and not card.has_node("Row/Lines/Idle") and main.production_bars.size() == state["makers"].size()
				and main.production_bars[0][2] == state["makers"][0] and main.production_bars[0][0].get_meta("part") > 0.0,
				"l'officina dove si lavora: chi, e la barra che avanza")
		if main.colonists.all(func(c): return c.gear.size() == (2 if c == hunter else 3)):  # l'arco qui non si fa
			break
	check(seen_busy, "qualcuno ha fuso i lingotti")
	main.production_panel.hide()
	check(smith.gear == {main.Slot.HANDS: main.Res.PICKAXE, main.Slot.BODY: main.Res.CHAINMAIL, main.Slot.HEAD: main.Res.HELMET},
		"il minatore: piccone, cotta ed elmo")
	check(tailor.gear[main.Slot.HANDS] == main.Res.AXE and hunter.gear.get(main.Slot.HANDS) == null,
		"il taglialegna l'ascia; l'arco non si fa senza banco del falegname")
	var ingots_used: int = 2 + 2 + 3 * (3 + 6)  # piccone, ascia, tre elmi e tre cotte
	check(main.total(I) == iron0 - main.total(main.Res.IRON) - ingots_used, "un lingotto per ferro, consumati quelli dei pezzi")
	check(main.total(main.Res.COAL) == main.total(main.Res.IRON), "e un carbone per lingotto")
	check(main.colonists.reduce(func(n, c): return n + c.xp[main.Skill.SMITHING], 0) >= iron0 - main.total(main.Res.IRON) + 8, "esperienza da fabbro")
	check(main.GEAR.keys().all(func(g): return main.total(g) == 0), "niente pezzi in più del necessario")

	# laboratorio: banco da lavoro e filatoio; con le pelli cuoio invece del metallo, col lino le corde.
	# Falegnameria: banco del falegname, l'arco (legna e corda) al cacciatore
	var shop = main.Room.new()
	var spot2: Vector2i = Vector2i.ZERO
	for k in rest:
		if main.cells_in(Rect2i(k, Vector2i(3, 3))).all(func(h): return rest.has(h) and not main.stockpile.has(h)):
			spot2 = k
			break
	for k in main.cells_in(Rect2i(spot2, Vector2i(3, 3))):
		shop.cells[k] = true
	main.rooms.append(shop)
	var bench: Vector2i = spot2 + Vector2i.ONE
	main.furniture[bench] = [main.Build.WORKBENCH, W, 0]
	main.furniture[spot2 + Vector2i(2, 0)] = [main.Build.SPINNING_WHEEL, W, 0]
	var joinery = main.Room.new()
	var spot3: Vector2i = Vector2i.ZERO
	for k in rest:
		if main.cells_in(Rect2i(k, Vector2i(3, 3))).all(func(h): return rest.has(h) and not main.stockpile.has(h) and not shop.cells.has(h)):
			spot3 = k
			break
	for k in main.cells_in(Rect2i(spot3, Vector2i(3, 3))):
		joinery.cells[k] = true
	main.rooms.append(joinery)
	main.furniture[spot3 + Vector2i.ONE] = [main.Build.CARPENTER_BENCH, W, 0]
	check(main.room_meets(joinery, main.RoomKind.CARPENTRY) and not main.room_meets(shop, main.RoomKind.CARPENTRY), "falegnameria: col suo banco")
	joinery.kind = main.RoomKind.CARPENTRY
	main.open_room(shop)
	check(range(main.room_kind.item_count).map(main.room_kind.get_item_id).has(main.RoomKind.WORKSHOP), "col banco si fa un laboratorio")
	main.room_kind.item_selected.emit(main.room_kind.get_item_index(main.RoomKind.WORKSHOP))
	main.stockpile = {}  # il tipo scelto ricalcola i magazzini
	for k in rest.slice(-20):
		main.stockpile[k] = true
	main.add_item(main.Res.HIDE, rest[3], 20)
	main.add_item(main.Res.FLAX, rest[4], 10)
	for c in main.colonists:
		c.skills[main.Skill.TAILORING] = 10
		c.skills[main.Skill.RANGED] = 10
	tailor.gear.erase(main.Slot.BODY)
	tailor.gear.erase(main.Slot.HEAD)
	check(main.gear_wanted(main.Res.BOW) == 1 and main.gear_wanted(main.Res.LEATHER_ARMOR) == 1, "un arco, un corpetto")
	for i in 30000:  # finché tutti hanno i loro pezzi e le corde di scorta sono filate
		main.tick(0.05)
		check_station(main)
		if main.colonists.all(func(c): return c.gear.size() == 3 and c.job != main.Job.CRAFT) \
				and main.total(main.Res.BOWSTRING) >= main.STOCK[main.Res.BOWSTRING]:
			break
	check(hunter.gear[main.Slot.HANDS] == main.Res.BOW, "il cacciatore ha l'arco")
	check(tailor.gear[main.Slot.BODY] == main.Res.LEATHER_ARMOR and tailor.gear[main.Slot.HEAD] == main.Res.LEATHER_HOOD,
		"con le pelli: armatura e cappuccio di cuoio")
	check(main.total(main.Res.HIDE) == 20 - 4 - 2, "pelli: 4 per l'armatura, 2 per il cappuccio")
	check(main.total(main.Res.BOWSTRING) == main.STOCK[main.Res.BOWSTRING] and main.total(main.Res.FLAX) == 10 - 2 * (main.STOCK[main.Res.BOWSTRING] + 1),
		"lino filato in corde: una nell'arco, le altre di scorta")

	# a metà lavoro, abbattuta la postazione: gli ingredienti già portati restano a terra
	for c in main.colonists:
		c.gear.erase(main.Slot.HEAD)
	var hides: int = main.total(main.Res.HIDE)
	var cut := false
	for i in 4000:
		main.tick(0.05)
		var crafter: Array = main.colonists.filter(func(c): return c.job == main.Job.CRAFT and not c.fetched.is_empty() \
			and main.RECIPES[c.recipe][1] == main.Build.WORKBENCH)
		if not crafter.is_empty():
			main.furniture.erase(bench)
			main.tick(0.05)
			cut = true
			break
	check(cut and main.total(main.Res.HIDE) == hides and not crafter_left(main), "postazione abbattuta: niente perso")

	# scheda: gli slot mostrano i pezzi, col mouse sopra nome, protezione ed effetto
	main.open_sheet(smith)
	var slots: Array = main.get_node("HUD/ColonistSheet/Box/Equipment/Slots").get_children()
	check(slots[main.Slot.HANDS].texture == main.ICONS[main.Res.PICKAXE] and slots[main.Slot.BODY].tooltip_text.begins_with("Chainmail\nArmor 5."),
		"slot della scheda")
	var tip: RichTextLabel = slots[main.Slot.BODY].make_tip.call()
	check(tip.text.begins_with(main.item_title(main.Res.CHAINMAIL) + "\nArmor 5."), "suggerimento dello slot: tipo e nome")
	tip.free()
	# ogni oggetto ha un tipo, con la sua icona davanti al nome
	for r in main.Res.values():
		check(main.ITEM_KIND.has(r), "%s ha un tipo" % main.Res.keys()[r])
	check(main.item_name(main.Res.PICKAXE) == "[img=center]res://art/kind_tool.png[/img] pickaxe"
		and main.item_name(main.Res.SWORD).contains("kind_weapon") and main.item_name(main.Res.HELMET).contains("kind_armor")
		and main.item_name(main.Res.GOLD) == main.COIN, "strumento, arma, armatura; le monete solo la moneta")
	var row: Control = main.resources_list.get_child(main.Res.CHAINMAIL)
	main.update_resources()
	check(row.get_child(1).texture == main.KIND_ICONS[main.ItemKind.ARMOR] and row.get_child(1).tooltip_text == "Armor"
		and row.get_child(2).text == "Chainmail" and row.get_child(3).text == str(main.stored(main.Res.CHAINMAIL)),
		"risorse: icona, tipo, nome e quantità")
	check(main.gear_sum(smith, "armor") >= 5 and main.get_node("HUD/ColonistSheet/Box/Equipment/Title").text \
		== "Equipment  (armor %d)" % main.gear_sum(smith, "armor"), "protezione totale")
	smith.gear.clear()
	main._process(0.0)
	check(slots[main.Slot.HANDS].tooltip_text == "Hands\nAuto. Click to choose." and slots[main.Slot.HANDS].texture is AtlasTexture,
		"slot vuoto: la sagoma")
	check(main.Res.values().all(func(r): return main.ICONS.has(r) and main.STACK_MAX.has(r) and main.items.has(r)), "ogni risorsa ha icona e mucchio")
	check(main.SKILLS_SHEET.get_width() == main.Skill.size() * 8, "un'icona per abilità")

	# scelta dalla scheda: clic sullo slot, il menu; il colono va a prendere quel pezzo e posa lì quello che aveva
	for c in main.colonists:
		main.quit_job(c)
		c.gear = {main.Slot.HANDS: main.Res.PICKAXE, main.Slot.BODY: main.Res.LEATHER_ARMOR, main.Slot.HEAD: main.Res.LEATHER_HOOD}
	var spots: Array = rest.filter(func(k): return main.items.values().all(func(g): return not g.has(k)) and main.room_at(k) == null)
	main._process(0.0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	slots[main.Slot.HANDS].gui_input.emit(click)
	var tools: int = main.GEAR.keys().filter(func(g): return main.GEAR[g]["slot"] == main.Slot.HANDS).size()
	check(main.gear_menu.visible and main.gear_menu.is_item_checked(0) and main.gear_menu.item_count == 3 + tools,
		"menu dello slot: Auto spuntato, Empty, i pezzi")
	main.gear_menu.id_pressed.emit(2 + main.Res.AXE)
	main.gear_menu.hide()
	main._process(0.0)
	check(smith.loadout == {main.Slot.HANDS: main.Res.AXE} and main.fits(smith, main.Slot.HANDS) == [main.Res.AXE]
		and main.gear_wanted(main.Res.AXE) == 1, "scelta l'ascia: se non c'è, si fa")
	check(slots[main.Slot.HANDS].get_node("Pin").visible and not slots[main.Slot.BODY].get_node("Pin").visible
		and slots[main.Slot.HANDS].tooltip_text.ends_with("Chosen: axe (on the way). Click to change."), "puntino d'oro e suggerimento")
	main.add_item(main.Res.AXE, spots[0], 1)
	for i in 4000:
		main.tick(0.05)
		if smith.gear[main.Slot.HANDS] == main.Res.AXE:
			break
	check(smith.gear[main.Slot.HANDS] == main.Res.AXE and main.total(main.Res.PICKAXE) == 1 and main.fits(smith, main.Slot.HANDS).is_empty(),
		"presa l'ascia, posato il piccone")
	# una scelta conta solo il suo pezzo: la cotta si fa anche se in magazzino c'è un'armatura di cuoio
	main.add_item(main.Res.LEATHER_ARMOR, spots[1], 1)
	check(main.gear_wanted(main.Res.CHAINMAIL) == 0, "in automatico basta il cuoio")
	smith.loadout[main.Slot.BODY] = main.Res.CHAINMAIL
	check(main.gear_wanted(main.Res.CHAINMAIL) == 1, "scelta la cotta: se ne fa una")
	smith.loadout.erase(main.Slot.BODY)
	main.add_item(main.Res.LEATHER_ARMOR, spots[1], -1)
	# "Empty": se lo toglie e lo lascia lì, poi va in magazzino come ogni mucchio
	main.open_gear_menu(main.Slot.HEAD)
	main.gear_menu.id_pressed.emit(1)
	main.gear_menu.hide()
	main.quit_job(smith)
	main.find_job(smith)
	check(not smith.gear.has(main.Slot.HEAD) and main.total(main.Res.LEATHER_HOOD) == 1 and main.fits(smith, main.Slot.HEAD).is_empty(),
		"Empty: si toglie il cappuccio e non ne vuole un altro")
	# a caccia: chi ha le mani scelte non va a prendere l'arco, chi è in automatico sì
	var hare = main.Animal.new()
	hare.pos = main.center(spots[2])
	hare.marked = true
	main.animals.append(hare)
	main.add_item(main.Res.BOW, spots[3], 1)
	for c in main.colonists:
		main.quit_job(c)
	check(not main.try_hunt(smith) and main.try_hunt(tailor) and tailor.job == main.Job.EQUIP and tailor.carry_res == main.Res.BOW,
		"l'arco lo prende chi è in automatico")
	main.quit_job(tailor)
	main.animals.clear()
	main.open_gear_menu(main.Slot.HANDS)
	main.gear_menu.id_pressed.emit(0)
	main.gear_menu.hide()
	check(not smith.loadout.has(main.Slot.HANDS), "di nuovo automatico")

	# carbonaia: finito il carbone, alla fornace 5 legna fanno 2 carboni, finché non c'è la scorta del menu
	main.add_item(W, rest[2], 30)  # legna per la carbonaia, quella di prima è andata negli archi
	for res in [main.Res.COAL, main.Res.IRON, I, main.Res.ASH]:  # senza ferro né lingotti la fornace fa solo carbone
		for k in main.items[res].keys():
			main.items[res].erase(k)
	var wood0: int = main.total(W)
	for i in 20000:
		main.tick(0.05)
		if main.total(main.Res.COAL) >= main.STOCK[main.Res.COAL] and not main.colonists.any(func(c): return c.job == main.Job.CRAFT):
			break
	check(main.total(main.Res.COAL) == 6 and main.total(W) == wood0 - 15, "carbonaia: tre volte 5 legna, 6 carboni (scorta 5)")
	check(main.total(main.Res.ASH) == 3, "e una cenere ogni volta, per concimare")

	print("OK: forgia, sartoria ed equipaggiamento")
	quit()


# qualcuno ancora al banco da lavoro?
func crafter_left(main) -> bool:
	return main.colonists.any(func(c): return c.job == main.Job.CRAFT and main.RECIPES[c.recipe][1] == main.Build.WORKBENCH)


# chi produce sta accanto alla postazione, guardandola
func check_station(main) -> void:
	for c in main.colonists:
		if c.job == main.Job.CRAFT and main.is_working(c) and c.work_left < c.work_total:
			check((main.cell_of(c.pos) - c.target).length() == 1, "produce accanto alla postazione")


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
