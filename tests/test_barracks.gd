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

	# fase 3, l'esercitazione: la prima ora di lavoro del giorno nella stanza della classe; +1,5 esperienza a colpo
	var J = main.Job
	var W = main.Work
	var melee: int = main.Skill.MELEE
	main.quit_job(ward)
	main.set_priority(ward, W.DRILL, 0)
	ward.drilled = -1
	main.find_job(ward)
	check(ward.job == J.DRILL and main.furniture[ward.target][0] == B.DUMMY and main.room_at(ward.target) == armory
		and armory.cells.has(ward.dest) and ward.drilled == main.today and is_equal_approx(ward.work_total, main.DAY_LENGTH / 24.0),
		"il guerriero: un'ora a un fantoccio della sala d'armi")
	ward.path.clear()
	ward.pos = main.center(ward.dest)
	ward.xp[melee] = 0
	main.update_colonist(ward, main.TRAIN_HIT + 0.01)
	check(is_equal_approx(ward.xp[melee], main.TRAIN_HIT * main.DRILL_XP * main.XP_PER_SECOND), "un colpo ogni 2,5 s: una volta e mezza il fantoccio di fuori")
	main.quit_job(ward)
	main.find_job(ward)
	check(ward.job != J.DRILL, "una volta al giorno")
	main.quit_job(ward)
	# il lavoro Esercitarsi: chi ha una classe, quando tocca a lui nella tabella; i lavoratori della stanza tutto il turno
	check(main.can_do(ward, W.DRILL) and not main.can_do(bow, W.DRILL) and main.priority(bow, W.DRILL) == 0, "Esercitarsi: solo chi ha una classe")
	check(main.WORK_ORDER.back() == W.DRILL and main.WORK_ICONS.size() == W.size() and main.WORK_INFO.size() == W.size(), "l'ultima colonna della tabella")
	main.set_priority(ward, W.DRILL, 1)
	check(main.find_work(ward) and ward.job == J.DRILL, "con la priorità 1 si allena prima di tutto")
	main.quit_job(ward)
	main.set_priority(ward, W.DRILL, main.PRIORITY_LEVELS)
	check(not main.try_drill(ward, true), "non è un lavoratore della sala")
	armory.workers.append(ward)
	check(main.find_work(ward) and ward.job == J.DRILL, "il lavoratore della sala d'armi si allena e basta")
	main.quit_job(ward)
	armory.workers.erase(ward)
	# arciere: da almeno 5 caselle dal bersaglio, in riga; scassinatore: al banco degli scassi
	main.set_calling(bow, H.ARCHER)
	check(not main.try_drill(bow), "coi bersagli a metà stanza non ci sono 5 caselle: niente tiro")
	var far_x: int = range_room.cells.keys().map(func(k): return k.x).min()
	for k in range_room.cells.keys():  # i bersagli in fondo
		if main.furniture.get(k, [-1])[0] == B.TARGET:
			main.furniture.erase(k)
		if k.x == far_x:
			main.furniture[k] = [B.TARGET, R.WOOD, 0]
	check(main.try_drill(bow) and main.furniture[bow.target][0] == B.TARGET and range_room.cells.has(bow.dest)
		and (bow.dest.x == bow.target.x or bow.dest.y == bow.target.y)
		and absi(bow.dest.x - bow.target.x) + absi(bow.dest.y - bow.target.y) >= main.DRILL_SHOT, "l'arciere tira da 5 caselle o più")
	bow.path.clear()
	bow.pos = main.center(bow.dest)
	bow.xp[main.Skill.RANGED] = 0
	main.update_colonist(bow, main.TRAIN_HIT + 0.01)
	check(bow.xp[main.Skill.RANGED] > 0, "e impara a tirare")
	main.quit_job(bow)
	main.set_calling(bow, H.BURGLAR)
	check(not main.try_drill(bow), "senza banco degli scassi lo scassinatore non si allena")
	main.furniture[inside[6]] = [B.LOCK_BENCH, R.WOOD, 0]
	check(main.try_drill(bow) and bow.target == inside[6], "al banco degli scassi")
	bow.path.clear()
	bow.pos = main.center(bow.dest)
	main.update_colonist(bow, main.TRAIN_HIT + 0.01)
	check(bow.xp[main.Skill.LOCKPICKING] > 0 or bow.skills[main.Skill.LOCKPICKING] > 0, "e impara a scassinare")
	main.furniture.erase(inside[6])
	main.update_colonist(bow, 0.1)
	check(bow.job != J.DRILL, "abbattuto il banco, smette")
	main.quit_job(bow)
	# la milizia: chi ha una classe fa la sua ora in caserma, e vale come esercitazione
	main.enacted.append(main.Law.MILITIA)
	ward.drilled = -1
	main.relax(ward)
	check(ward.job == J.DRILL and ward.drilled == main.today, "con la milizia l'ora libera in caserma")
	main.quit_job(ward)
	main.enacted.clear()
	# negli ultimi mesi della gravidanza niente; nella routine una casella colorata, la prima di lavoro
	var hour: int = main.drill_hour(ward)
	var day: Array = main.routine_of(ward)
	check(hour >= 0 and day[hour] == main.Act.WORK and day[hour - 1] != main.Act.WORK, "l'ora dell'esercitazione: la prima di lavoro")
	main.open_sheet(ward)
	var hours_row: Control = main.get_node("HUD/ColonistSheet/Box/Routine/Hours")
	check(hours_row.get_child(hour).color == main.DRILL_COLOR and hours_row.get_child(hour).tooltip_text.ends_with("Drill")
		and hours_row.get_child((hour + 1) % 24).color != main.DRILL_COLOR, "nella scheda, colorata")
	ward.due = main.clock + 1.0
	check(not main.drills(ward) and main.drill_hour(ward) == -1 and not main.can_do(ward, W.DRILL), "incinta agli ultimi mesi: niente esercitazione")
	ward.due = 0.0

	# fase 4, in battaglia secondo la classe. Guerriero: scappa sotto 20 (lo scassinatore sotto 30), vede i lupi da 16 caselle
	var plain = main.Colonist.new()  # un colono in più, adulto, senza classe
	main.dress(plain, main.people().map(func(o): return o.first_name))
	plain.skills = main.Skill.values().map(func(_s): return 0)
	plain.xp = main.Skill.values().map(func(_s): return 0)
	plain.needs = main.Need.values().map(func(_n): return 60.0)
	plain.trend = plain.needs.map(func(_v): return 0.0)
	main.give_age(plain, main.ADULT_AGE)
	main.colonists.append(plain)
	check(main.flee_hp(ward) == 20.0 and main.flee_hp(bow) == 30.0 and main.flee_hp(plain) == main.FLEE_HP and main.flee_hp() == main.FLEE_HP,
		"il guerriero scappa sotto 20, lo scassinatore sotto 30, gli altri sotto 40")
	main.enacted.append(main.Law.MILITIA)
	check(main.flee_hp(ward) == 20.0 and main.flee_hp(plain) == main.MILITIA_FLEE, "con la milizia gli altri sotto 30")
	main.enacted.clear()
	for o in main.colonists:
		main.quit_job(o)
		o.hp = main.MAX_HP
	ward.pos = main.center(mid)
	plain.pos = main.center(mid + Vector2i(1, 0))
	bow.pos = main.center(mid + Vector2i(0, 8))
	var wolf = main.add_animal(main.Beast.WOLF, mid + Vector2i(14, 0))
	wolf.blocked = 0.0
	check(main.nearest_foe(ward) == wolf and main.nearest_foe(plain) == null, "il guerriero va contro i lupi da 16 caselle, gli altri da 12")
	# copre chi gli sta vicino: il lupo che morde qualcuno entro 2 caselle passa a lui
	wolf.target = plain
	for i in 50:
		main.bite(wolf, plain)
		ward.hp = main.MAX_HP
		ward.downed = false
	check(plain.hp == main.MAX_HP and wolf.target == ward, "il guerriero copre chi ha vicino: il lupo passa a lui")
	plain.pos = main.center(mid + Vector2i(4, 0))
	wolf.target = plain
	main.bite(wolf, plain)
	check(wolf.target == plain, "lontano dal guerriero nessuno lo copre")
	plain.pos = main.center(mid + Vector2i(1, 0))
	ward.downed = true
	main.bite(wolf, plain)
	check(wolf.target == plain, "né un guerriero a terra")
	ward.downed = false
	# scassinatore: i lupi lo mordono a segno il 15% in meno
	plain.pos = main.center(mid + Vector2i(6, 0))
	main.deaths = false
	var bitten := {}
	for o in [bow, plain]:
		o.skills[melee] = 2
		o.gear = {}
		bitten[o] = 0
		for i in 2000:
			o.hp = main.MAX_HP
			o.downed = false
			main.bite(wolf, o)
			bitten[o] += int(o.hp < main.MAX_HP)
	check(bitten[plain] - bitten[bow] > 200 and bitten[plain] - bitten[bow] < 400, "lo scassinatore schiva: %d morsi contro %d" % [bitten[bow], bitten[plain]])
	for o in [bow, plain]:
		o.hp = main.MAX_HP
		o.downed = false
	# arciere: +10% a segno e una casella di gittata in più; arretra dal lupo che gli arriva addosso e tira di nuovo
	main.set_calling(bow, H.ARCHER)
	bow.gear = {S.HANDS: R.BOW}
	plain.gear = {S.HANDS: R.BOW}
	check(is_equal_approx(main.gear_sum(bow, "hit"), main.gear_sum(plain, "hit") + 0.1)
		and is_equal_approx(main.hunt_range(bow), main.hunt_range(plain) + 1.0), "l'arciere: +10% a segno, +1 casella")
	check(is_equal_approx(main.WARRIOR["hit"], 0.1), "il guerriero +10% in mischia")
	wolf.pos = bow.pos + Vector2(2 * main.TILE, 0)
	bow.job = J.FIGHT
	bow.prey = wolf
	bow.work_total = main.attack_time(bow)
	bow.work_left = bow.work_total
	main.update_colonist(bow, 0.01)
	check(not bow.path.is_empty() and main.center(bow.path.back()).distance_to(wolf.pos) >= (main.ARCHER["keep"] + 2) * main.TILE
		and bow.job == J.FIGHT, "il lupo entro 3 caselle: l'arciere arretra")
	main.track_prey(bow)
	check(bow.path.size() > 1, "e non si ferma né torna indietro finché non è lontano")
	bow.pos = main.center(bow.path.back())
	bow.path.clear()
	var shots: int = main.arrows.size()
	wolf.pos = bow.pos + Vector2(2 * main.TILE, 0)
	main.update_colonist(bow, bow.work_total)
	check(main.arrows.size() == shots + 1 and bow.path.is_empty(), "arrivato tira di nuovo, anche col lupo addosso")
	main.arrows.clear()
	plain.job = J.FIGHT
	plain.prey = wolf
	plain.pos = bow.pos
	plain.work_total = main.attack_time(plain)
	plain.work_left = plain.work_total
	main.update_colonist(plain, 0.01)
	check(plain.path.is_empty(), "chi ha solo l'arco, senza la classe, resta dov'è")
	main.quit_job(plain)
	main.quit_job(bow)
	# sale sulla torre di guardia libera più vicina entro 15 caselle, e ci resta finché il pericolo non passa
	bow.pos = main.center(mid + Vector2i(0, 8))
	plain.pos = main.center(mid + Vector2i(1, 8))
	wolf.pos = main.center(mid + Vector2i(10, 8))
	var lookout: Vector2i = mid + Vector2i(-3, 8)
	main.furniture[lookout] = [B.WATCHTOWER, R.WOOD, 0]
	main.react(bow)
	main.react(plain)
	check(bow.job == J.FIGHT and not bow.path.is_empty() and bow.path.back() == lookout and main.posted(bow), "l'arciere va alla torre di guardia")
	check(plain.job == J.FIGHT and not main.posted(plain) and (plain.path.is_empty() or plain.path.back() != lookout), "gli altri no")
	main.track_prey(bow)
	check(bow.path.back() == lookout, "e non si lascia distrarre per strada")
	bow.pos = main.center(lookout)
	bow.path.clear()
	wolf.pos = main.center(lookout + Vector2i(18, 0))
	main.update_colonist(bow, bow.work_total)
	check(bow.job == J.FIGHT and bow.path.is_empty() and main.arrows.is_empty(), "sulla torre: il lupo fuori tiro non lo insegue")
	wolf.pos = main.center(lookout + Vector2i(8, 0))
	main.update_colonist(bow, bow.work_total)
	check(main.arrows.size() == 1 and main.cell_of(bow.pos) == lookout, "a tiro (più lungo, dalla torre) tira")
	main.animals.erase(wolf)
	main.update_colonist(bow, 0.01)
	check(bow.job != J.FIGHT, "passato il pericolo scende")
	main.furniture.erase(lookout)
	main.arrows.clear()

	print("OK: la caserma (ricerca, sala d'armi e tiro a segno, la classe, il corredo, l'esercitazione, in battaglia)")
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
