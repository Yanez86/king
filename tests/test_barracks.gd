# Esegui: godot --headless --path . -s tests/test_barracks.gd
# La caserma, fase 2 (GDD 4.4.6): la ricerca Caserma, la sala d'armi (due fantocci e una rastrelliera) e il tiro a
# segno (due bersagli, lungo almeno 8 caselle), il pugnale all'incudine; la classe dalla scheda (adulti, la stanza,
# l'arma), il suo livello, il corredo che l'equipaggiamento automatico prende (anche al posto di un attrezzo), la
# faretra, la maschera e il cappuccio colorato; nell'elenco degli abitanti; nel salvataggio
extends SceneTree

var main


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(6)
	main = load("res://main.tscn").instantiate()
	main.game_start = false
	main.settings_file = ""
	root.add_child(main)
	await process_frame
	main.events = false
	main.needs_rate = 0.0
	main.routines = false
	main.animals.clear()
	var B = main.Build
	var R = main.Res
	var H = main.Hero
	var S = main.Slot
	var K = main.RoomKind
	var mid: Vector2i = main.MAP_SIZE / 2

	# la ricerca: Ferro II, dopo il fantoccio; senza, niente mobili, stanze né pugnale
	var T = main.Tech
	check(main.TECHS[T.BARRACKS]["tier"] == 2 and main.TECHS[T.BARRACKS]["needs"] == [T.TRAINING_DUMMY], "Caserma: Ferro II, dopo il fantoccio")
	main.researched.erase(T.BARRACKS)
	main.refresh_unlocks()
	check(not main.kind_buttons[B.WEAPON_RACK].visible and not main.kind_buttons[B.TARGET].visible
		and not main.kind_buttons[B.LOCK_BENCH].visible and not main.unlocked("makes", R.DAGGER), "senza la ricerca niente caserma")
	var ward = main.colonists[1]
	check(main.calling_block(ward, H.WARRIOR) == "needs the Barracks research", "né classi")
	main.researched[T.BARRACKS] = true
	main.refresh_unlocks()
	check(main.kind_buttons[B.WEAPON_RACK].visible and main.unlocked("rooms", K.ARMORY) and main.unlocked("makes", R.DAGGER),
		"con la ricerca: rastrelliera, sala d'armi, pugnale")
	check(main.RECIPES.any(func(r): return r[0] == R.DAGGER and r[1] == B.ANVIL), "il pugnale all'incudine")

	# la sala d'armi: due fantocci e una rastrelliera
	var armory = room(Rect2i(mid + Vector2i(-12, -12), Vector2i(7, 7)))
	var inside: Array = armory.cells.keys()
	main.furniture[inside[0]] = [B.DUMMY, R.WOOD, 0]
	main.furniture[inside[2]] = [B.WEAPON_RACK, R.WOOD, 0]
	check(not main.room_meets(armory, K.ARMORY), "un fantoccio solo: non basta")
	main.furniture[inside[4]] = [B.DUMMY, R.WOOD, 0]
	check(main.room_meets(armory, K.ARMORY), "due fantocci e una rastrelliera: sala d'armi")
	# il tiro a segno: due bersagli, in una stanza lunga almeno 8 caselle
	var short = room(Rect2i(mid + Vector2i(-4, -12), Vector2i(7, 7)))
	for k in short.cells.keys().slice(0, 2):
		main.furniture[k] = [B.TARGET, R.WOOD, 0]
	check(not main.room_meets(short, K.ARCHERY_RANGE), "lunga 5: non è un tiro a segno")
	var range_room = room(Rect2i(mid + Vector2i(-12, -4), Vector2i(11, 4)))
	for k in range_room.cells.keys().slice(0, 2):
		main.furniture[k] = [B.TARGET, R.WOOD, 0]
	check(main.room_meets(range_room, K.ARCHERY_RANGE), "lunga 9 con due bersagli: tiro a segno")

	# la classe: un adulto, la stanza della classe, l'arma
	var kid = main.colonists[0]
	var born: float = kid.born
	kid.born = main.clock - 10 * main.life_year()
	check(main.calling_block(kid, H.WARRIOR) == "not grown up yet", "un bambino no")
	kid.born = born
	ward.skills[main.Skill.MELEE] = 2
	check(main.calling_block(ward, H.WARRIOR) == "needs a room: armory", "senza sala d'armi no")
	armory.kind = K.ARMORY
	check(main.calling_block(ward, H.WARRIOR) == "needs 3 in Melee" and main.calling_block(ward, H.BURGLAR) == "",
		"il guerriero vuole 3 in mischia, lo scassinatore 2")
	ward.skills[main.Skill.MELEE] = 7
	check(main.calling_block(ward, H.WARRIOR) == "" and main.calling_block(ward, H.ARCHER) == "needs a room: archery range", "il guerriero sì")

	# guerriero: spada, cotta (o cuoio), elmo, e lo scudo quando ha la spada; l'ascia la posa
	ward.gear = {S.HANDS: R.AXE}
	main.set_calling(ward, H.WARRIOR)
	check(ward.calling == H.WARRIOR and ward.kit.is_empty() and ward.hood_tint == null, "guerriero: niente corredo da vedere")
	check(main.fits(ward, S.HANDS) == [R.SWORD] and main.fits(ward, S.BODY) == [R.CHAINMAIL, R.LEATHER_ARMOR]
		and main.fits(ward, S.HEAD) == [R.HELMET] and main.fits(ward, S.SHIELD).is_empty(), "la spada al posto dell'ascia; lo scudo dopo")
	check(main.calling_level(ward) == 3 and main.calling_title(ward) == "Warrior of the colony, level 3", "livello: metà della mischia")
	var sword_at: Vector2i = main.cell_of(ward.pos) + Vector2i(2, 0)
	main.add_item(R.SWORD, sword_at, 1)
	check(main.try_equip(ward) and ward.job == main.Job.EQUIP and ward.carry_res == R.SWORD, "va a prendere la spada")
	for i in 2000:
		if ward.gear.get(S.HANDS) == R.SWORD:
			break
		main.tick(0.05)
	check(ward.gear.get(S.HANDS) == R.SWORD and main.total(R.AXE) >= 1, "spada in mano, l'ascia posata")
	check(main.fits(ward, S.HANDS).is_empty() and main.fits(ward, S.SHIELD) == [R.SHIELD], "con la spada: lo scudo")
	ward.gear[S.BODY] = R.LEATHER_ARMOR
	check(main.fits(ward, S.BODY).is_empty(), "il cuoio va bene: non lo cambia")
	# arciere: arco, cuoio, cappuccio verde, la faretra
	range_room.kind = K.ARCHERY_RANGE
	var bow = main.colonists[2]
	bow.skills[main.Skill.RANGED] = 4
	main.set_calling(bow, H.ARCHER)
	check(bow.kit == [main.Look.QUIVER] and bow.hood_tint == main.HEROES[H.ARCHER]["hood"] and main.fits(bow, S.HANDS) == [R.BOW]
		and main.fits(bow, S.HEAD) == [R.LEATHER_HOOD] and main.calling_level(bow) == 2, "arciere: la faretra, il cappuccio verde, l'arco")
	# scassinatore: pugnale, maschera e sacca, cappuccio scuro; scassinare lo impara solo con la classe: livello 1
	main.set_calling(bow, H.BURGLAR)
	check(bow.kit == [main.Look.MASK, main.Look.PACK] and bow.hood_tint == main.HEROES[H.BURGLAR]["hood"]
		and main.fits(bow, S.HANDS) == [R.DAGGER] and main.calling_level(bow) == 1, "scassinatore: pugnale, maschera, sacca")
	check(main.gear_wanted(R.DAGGER) >= 1, "un pugnale da fare all'incudine")
	# senza classe torna com'era
	main.set_calling(bow, H.NONE)
	check(bow.calling == H.NONE and bow.kit.is_empty() and bow.hood_tint == null and main.fits(bow, S.HANDS) != [R.DAGGER], "senza classe")

	# nella scheda: la riga della classe e "Class…"; il menu, con le classi spente col perché
	main.open_sheet(ward)
	var box = main.get_node("HUD/ColonistSheet/Box")
	check(box.get_node("Family/Class").visible and box.get_node("Hero").text.contains("Warrior of the colony, level 3"), "la scheda del guerriero")
	main.open_class_menu()
	var menu: PopupMenu = main.class_menu
	check(menu.item_count == 4 and menu.is_item_checked(menu.get_item_index(H.WARRIOR))
		and not menu.is_item_disabled(menu.get_item_index(H.NONE)), "il menu: nessuna e le tre classi")
	main.class_pressed(H.NONE)
	check(ward.calling == H.NONE, "dal menu: nessuna classe")
	main.class_pressed(H.WARRIOR)
	check(ward.calling == H.WARRIOR and main.census_role(ward) == "Warrior of the colony, level 3", "nell'elenco degli abitanti")
	# nel salvataggio
	check(str(main.game_state()["objects"]).contains("calling"), "la classe si salva")

	print("OK: la caserma (ricerca, sala d'armi e tiro a segno, la classe, il corredo)")
	quit()


# una stanza chiusa da muri di legno sul bordo di `rect`, con una porta in basso: l'erba sgombra
func room(rect: Rect2i):
	for k in main.cells_in(rect):
		main.trees.erase(k)
		main.rocks.erase(k)
		main.water.erase(k)
		main.bushes.erase(k)
		main.astar.set_point_solid(k, false)
		var edge: bool = k.x == rect.position.x or k.y == rect.position.y or k.x == rect.end.x - 1 or k.y == rect.end.y - 1
		if edge:
			main.built[k] = [main.Build.WALL, main.Res.WOOD]
			main.astar.set_point_solid(k)
	var door := Vector2i(rect.position.x + rect.size.x / 2, rect.end.y - 1)
	main.built[door] = [main.Build.DOOR, main.Res.WOOD]
	main.astar.set_point_solid(door, false)
	main.update_rooms()
	return main.room_at(rect.position + Vector2i.ONE)


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
