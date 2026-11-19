# Esegui: godot --headless --path . -s tests/test_dynasty.gd
# La dinastia (GDD 4.3.3): l'età, che cresce di un anno a stagione, e la vecchiaia
extends SceneTree

const SAVES := preload("res://saves.gd")


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(3)
	var main = load("res://main.tscn").instantiate()
	main.game_start = false
	main.settings_file = ""
	root.add_child(main)
	await process_frame
	main.threats = false
	var ruler = main.ruler

	# età: il sovrano tra 20 e 30 anni, gli altri tra 18 e 40, come gli avventurieri; un anno di vita a stagione
	check(main.LIFE_YEAR == main.YEAR_DAYS / 4.0, "un anno di vita a stagione")
	check(main.age_of(ruler) >= 20 and main.age_of(ruler) <= 30, "il sovrano tra 20 e 30 anni: %d" % main.age_of(ruler))
	check(main.colonists.all(func(c): return main.age_of(c) >= 18 and main.age_of(c) <= 40), "i coloni tra 18 e 40")
	var hero = main.new_hero(main.Hero.ARCHER, 1)
	check(main.age_of(hero) >= 18 and main.age_of(hero) <= 40, "anche gli avventurieri")
	var c = main.colonists[1]
	c.born = main.clock - 30.5 * main.LIFE_YEAR
	main.open_sheet(c)
	var sex: String = main.SEX_NAMES[c.sex]
	check(main.get_node("HUD/ColonistSheet/Box/Sex/Label").text == "%s, 30 years old" % sex, "nella scheda, accanto al sesso")
	main.clock += main.LIFE_YEAR
	check(main.age_of(c) == 31, "una stagione dopo, un anno in più")

	# vecchiaia: dai 60 anni, a ogni compleanno si muore con (età - 58) × 2%; a 59 mai
	var deaths := {59: 0, 60: 0, 70: 0}
	for years in deaths:
		for i in 500:
			var old = main.Colonist.new()
			old.born = floorf(main.clock) - (years - 0.001) * main.LIFE_YEAR  # compie gli anni proprio oggi
			old.needs = main.Need.values().map(func(_n): return 50.0)
			old.skills = main.Skill.values().map(func(_s): return 0)
			old.xp = main.Skill.values().map(func(_s): return 0)
			main.colonists.append(old)
		var before: int = main.colonists.size()
		main.today = int(main.clock)
		main.new_day()
		deaths[years] = before - main.colonists.size()
		for o in main.colonists.duplicate():  # via i vecchi rimasti
			if o.born < main.clock - 50 * main.LIFE_YEAR:
				main.colonists.erase(o)
		main.corpses.clear()
	check(deaths[59] == 0, "a 59 anni nessuno muore di vecchiaia")
	check(deaths[60] > 5 and deaths[60] < 40, "a 60 il 4%%: %d su 500" % deaths[60])
	check(deaths[70] > 90 and deaths[70] < 150, "a 70 il 24%%: %d su 500" % deaths[70])
	check(Array(main.chronicle).any(func(line): return "died of old age, at 70." in line), "la cronaca lo scrive")
	main.deaths = false
	var spared = main.Colonist.new()
	spared.born = floorf(main.clock) - 89.999 * main.LIFE_YEAR
	spared.needs = main.Need.values().map(func(_n): return 50.0)
	main.colonists.append(spared)
	main.new_day()
	check(spared in main.colonists, "senza morti (nei test) nessuno muore di vecchiaia")
	main.colonists.erase(spared)

	# matrimonio: il sovrano adulto sposa una persona adulta dell'altro sesso, senza coniuge, abbastanza felice
	for i in 2:  # in tutto quattro, oltre al sovrano
		person(main)
	var others: Array = main.colonists.filter(func(o): return o != ruler)
	ruler.sex = main.Sex.MALE
	for i in others.size():
		others[i].sex = main.Sex.FEMALE if i < 3 else main.Sex.MALE
		others[i].born = main.clock - 25.5 * main.LIFE_YEAR
		others[i].needs[main.Need.HAPPINESS] = 80.0
	var bride = others[0]
	var sad = others[1]
	sad.needs[main.Need.HAPPINESS] = 20.0
	var girl = others[2]
	girl.born = main.clock - 15.5 * main.LIFE_YEAR
	check(main.can_marry(), "il sovrano adulto, senza coniuge, si può sposare")
	var options: Array = main.suitors()
	check(options.map(func(o): return o[0]) == [bride, sad], "le donne adulte, non i ragazzi né gli uomini")
	check(options[0][1] == "" and options[1][1] == "not happy enough", "chi è infelice non accetta")
	main.open_sheet(ruler)
	var family: Control = main.get_node("HUD/ColonistSheet/Box/Family")
	check(family.get_node("Marry").visible and not family.get_node("Spouse").visible, "nella scheda: Arrange a marriage…")
	family.get_node("Marry").pressed.emit()
	check(main.marriage_menu.visible and main.marriage_menu.item_count == 2 and not main.marriage_menu.is_item_disabled(0)
		and main.marriage_menu.is_item_disabled(1) and main.marriage_menu.get_item_text(1).ends_with("not happy enough"),
		"il menu: chi non accetta è spento, col perché")
	var authority_before: float = main.authority
	main.marriage_menu.id_pressed.emit(main.colonists.find(bride))
	check(ruler.spouse == bride and bride.spouse == ruler and main.married(ruler) and main.married(bride), "sposati")
	check(main.colonists.all(func(o): return o.conds.has(main.Cond.WEDDING)), "le nozze: tutti fanno festa")
	check(is_equal_approx(main.authority, authority_before + main.WEDDING_AUTHORITY), "+%d autorità" % main.WEDDING_AUTHORITY)
	check(Array(main.chronicle).any(func(line): return "%s married %s." % [main.full_name(ruler), main.full_name(bride)] in line),
		"la cronaca lo scrive")
	check(not family.get_node("Marry").visible and family.get_node("Spouse").text == "Spouse: " + main.full_name(bride),
		"nella scheda il coniuge")
	check(not main.can_marry(), "sposato, niente altri matrimoni")
	main.die(bride, "is gone.")
	main.open_sheet(ruler)
	check(family.get_node("Spouse").text.ends_with(" †") and main.can_marry() and not main.married(ruler),
		"vedovo: la croce accanto al nome, e ci si può risposare")

	# un salvataggio di prima delle età: tutti adulti
	var state: Dictionary = main.game_state()
	var k: int = main.saved_classes().find(main.Colonist)
	for fields in state["objects"][k]:
		fields.erase("born")
	SAVES.pending = state
	var copy = load("res://main.tscn").instantiate()
	copy.game_start = false
	copy.settings_file = ""
	root.add_child(copy)
	check(copy.colonists.all(func(o): return o.born != INF and copy.age_of(o) >= 18 and copy.age_of(o) <= 40),
		"caricato un salvataggio di prima delle età, tutti adulti")
	check(copy.age_of(copy.ruler) <= 30, "il sovrano al più 30 anni")
	Engine.time_scale = 1.0  # caricata riparte in pausa

	# figli: la coppia sposata che dorme nella stessa stanza; di notte l'1%
	copy.queue_free()
	var wife = sad
	wife.needs[main.Need.HAPPINESS] = 80.0
	main.marry(ruler, wife)
	var room = build_room(main)
	check(room != null, "una stanza per la coppia")
	var beds: Array = room.cells.keys()
	ruler.pos = main.center(beds[0])
	wife.pos = main.center(beds[1])
	ruler.job = main.Job.SLEEP
	wife.job = main.Job.SLEEP
	wife.born = main.clock - 25.5 * main.LIFE_YEAR
	main.conceive(ruler)
	check(ruler.due == 0.0, "il marito non resta incinto")
	wife.job = main.Job.NONE
	for i in 2000:
		main.conceive(wife)
	check(wife.due == 0.0, "sveglia, niente")
	wife.job = main.Job.SLEEP
	wife.pos = main.center(main.MAP_SIZE / 2 + Vector2i(30, 30))
	for i in 2000:
		main.conceive(wife)
	check(wife.due == 0.0, "in un'altra stanza, niente")
	wife.pos = main.center(beds[1])
	wife.born = main.clock - 41.5 * main.LIFE_YEAR
	for i in 2000:
		main.conceive(wife)
	check(wife.due == 0.0, "dopo i 40 anni, niente")
	wife.born = main.clock - 25.5 * main.LIFE_YEAR
	var tries := 0
	while wife.due == 0.0 and tries < 3000:
		main.conceive(wife)
		tries += 1
	check(wife.due > 0.0 and tries > 10 and tries < 1000, "insieme nella stanza, di notte: incinta dopo %d notti" % tries)
	check(is_equal_approx(wife.due, main.clock + main.PREGNANCY) and wife.conds.has(main.Cond.PREGNANT), "incinta per tre quarti d'anno")
	var early: float = main.work_factor(wife)
	main.clock = wife.due - main.PREGNANCY / 4.0
	check(is_equal_approx(main.work_factor(wife), early * main.PREGNANT_SLOW), "negli ultimi mesi lavora più piano")
	# il parto: un neonato della casata, col nome dalla finestra
	wife.traits = [main.Trait.GLUTTON]
	ruler.traits = [main.Trait.EARLY_BIRD]
	main.clock = wife.due
	main.hour = int(main.clock * 24)
	main.new_hour()
	check(main.babies.size() == 1 and wife.due == 0.0 and not wife.conds.has(main.Cond.PREGNANT), "è nato")
	var baby = main.babies[0]
	check(baby.mother == wife and baby.father == ruler and baby.last_name == ruler.last_name and baby.tunic == ruler.tunic,
		"figlio dei due, col cognome e i colori della casata")
	check(main.age_of(baby) == 0 and baby not in main.colonists and not baby.beard, "un neonato, non ancora un colono")
	check(is_equal_approx(wife.fertile_from, main.clock + main.LIFE_YEAR), "per un anno niente altri figli")
	var panel: Control = main.get_node("HUD/BirthPanel")
	check(panel.visible and panel.get_node("Box/Row/Name").text == baby.first_name, "la finestra chiede il nome")
	check(Array(main.chronicle).any(func(line): return "%s is born, child of" % main.full_name(baby) in line), "la cronaca")
	panel.get_node("Box/Row/Name").text_changed.emit("Arnolfo")
	check(baby.first_name == "Arnolfo" and main.chronicle[main.chronicle.size() - 1].contains("Arnolfo"), "il nome scelto, anche nella cronaca")
	panel.get_node("Box/Row/Dice").pressed.emit()
	check(baby.first_name in main.FIRST_NAMES[baby.sex], "il dado: un nome a caso")
	panel.get_node("Box/Ok").pressed.emit()
	check(not panel.visible, "e si chiude")
	main.open_sheet(ruler)
	check(main.get_node("HUD/ColonistSheet/Box/Kin").text == "Children: %s (0)" % baby.first_name, "nella scheda i figli")
	# in braccio alla madre, o nella culla della stanza
	check(baby.cradle == Vector2i(-1, -1) and main.carrier_of(baby) == wife, "senza culla, in braccio alla madre")
	main.furniture[beds[2]] = [main.Build.CRADLE, main.Res.WOOD, 0]
	main.place_babies()
	check(baby.cradle == beds[2], "nella culla")
	main.furniture.erase(beds[2])
	main.place_babies()
	check(baby.cradle == Vector2i(-1, -1), "tolta la culla, di nuovo in braccio")
	# i talenti: ognuno al 50%, al più due, mai in contrasto
	var got := {main.Trait.GLUTTON: 0, main.Trait.EARLY_BIRD: 0}
	for i in 300:
		wife.spouse = ruler
		main.give_birth(wife)
		var b = main.babies.pop_back()
		for t in b.traits:
			got[t] += 1
	check(got.values().all(func(n): return n > 110 and n < 190), "ogni talento passa una volta su due: %s" % got)
	main.get_node("HUD/BirthPanel").hide()

	# crescere: a 4 anni il neonato diventa un bambino della colonia; i bambini raccolgono e trasportano a metà
	# velocità, i ragazzi non fanno i lavori pesanti; a 16 la maggiore età
	baby.born = main.clock - 4.01 * main.LIFE_YEAR
	main.today = int(main.clock)
	main.new_day()
	check(baby in main.colonists and baby not in main.babies and baby.pos == wife.pos, "a 4 anni, un bambino accanto alla madre")
	var W = main.Work
	check(main.can_do(baby, W.GATHER) and main.can_do(baby, W.HAUL) and not main.can_do(baby, W.BUILD)
		and not main.can_do(baby, W.COOK) and main.priority(baby, W.BUILD) == 0, "i bambini: raccogliere e trasportare")
	check(is_equal_approx(main.work_factor(baby), main.CHILD_SLOW * main.cond_product(baby, 1)), "a metà velocità")
	check(not main.try_equip(baby), "niente armi né armature")
	main.refresh_priorities()
	var grid: Control = main.priority_grid
	var row: int = (W.size() + 1) * (main.colonists.find(baby) + 1)  # le icone e le righe prima: qui il nome
	check(grid.get_child(row + 1 + W.BUILD) is not Button and grid.get_child(row + 1 + W.HAUL) is Button,
		"nella tabella delle priorità solo i suoi lavori")
	baby.born = main.clock - 13.5 * main.LIFE_YEAR
	check(main.can_do(baby, W.COOK) and main.can_do(baby, W.STUDY) and not main.can_do(baby, W.BUILD) and not main.can_do(baby, W.HUNT)
		and is_equal_approx(main.work_factor(baby), main.cond_product(baby, 1)), "un ragazzo: tutto tranne i lavori pesanti")
	baby.born = main.clock - (main.ADULT + 0.001) * main.LIFE_YEAR  # compiuti oggi
	main.new_day()
	check(main.can_do(baby, W.BUILD) and Array(main.chronicle).any(func(line): return "%s comes of age." % main.full_name(baby) in line),
		"a 16 anni la maggiore età, nella cronaca")

	# successione: alla morte del sovrano il primo figlio vivo; lutto regale, poi l'incoronazione
	var house: String = main.house_name
	check(house == ruler.last_name and main.reigns.size() == 1 and main.reigns[0][0] == ruler, "la casata e il primo regno")
	var heir = baby  # il primo figlio, ormai adulto
	for o in main.colonists:  # il lutto di prima: qui il tempo non scorre, e non finirebbe
		o.conds.erase(main.Cond.MOURNING)
	main.die(ruler, "is gone.")
	check(main.ruler == heir and main.regent_for == null, "regna il primo figlio")
	check(main.colonists.all(func(o): return o.conds.has(main.Cond.ROYAL_MOURNING) and not o.conds.has(main.Cond.MOURNING)),
		"lutto regale per tutti, al posto del lutto")
	check(main.reigns.size() == 2 and main.reigns[0][2] > 0.0 and main.reigns[1][0] == heir, "il regno di prima finisce, comincia il nuovo")
	check(is_equal_approx(main.coronation_at, main.clock + main.ROYAL_MOURNING_DAYS)
		and Array(main.chronicle).any(func(line): return "%s inherits the crown." % main.full_name(heir) in line), "incoronato dopo il lutto")
	var before: float = main.authority
	main.clock = main.coronation_at
	main.hour = int(main.clock * 24)
	main.new_hour()
	check(main.coronation_at == 0.0 and main.colonists.all(func(o): return o.conds.has(main.Cond.CORONATION))
		and is_equal_approx(main.authority, before + main.CORONATION_AUTHORITY), "l'incoronazione: festa e autorità")
	check(main.get_node("HUD/ReportPanel").visible and main.get_node("HUD/ReportPanel/Box/Head/Title").text == "Coronation", "e una finestra")
	main.get_node("HUD/ReportPanel").hide()

	# un erede bambino: regna un reggente (l'adulto con più abilità, se i genitori non ci sono) fino ai suoi 16 anni
	var kid = person(main)
	kid.born = main.clock - 10.5 * main.LIFE_YEAR
	kid.father = heir
	var kid2 = person(main)
	kid2.born = main.clock - 6.5 * main.LIFE_YEAR
	kid2.father = heir
	var wise = person(main)
	wise.skills = main.Skill.values().map(func(_s): return 5)
	var second = person(main)
	second.skills = main.Skill.values().map(func(_s): return 3)
	main.die(heir, "is gone.")
	check(main.regent_for == kid and main.ruler == wise and main.ruler_title(wise) == "Regent", "il primo figlio, con un reggente")
	check(not main.can_marry(), "il reggente non si sposa da sovrano")
	main.open_sheet(kid)
	check(main.get_node("HUD/ColonistSheet/Box/Hero").text.contains("Heir of"), "nella scheda: erede")
	main.die(wise, "is gone.")
	check(main.regent_for == kid and main.ruler == second, "morto il reggente, un altro")
	main.die(kid, "is gone.")
	check(main.regent_for == kid2 and main.ruler == second, "morto l'erede, il fratello")
	kid2.born = main.clock - (main.ADULT + 0.001) * main.LIFE_YEAR
	main.today = int(main.clock)
	main.new_day()
	check(main.ruler == kid2 and main.regent_for == null and main.reigns[-1][0] == kid2
		and kid2.conds.has(main.Cond.CORONATION), "a 16 anni l'erede è incoronato")
	main.get_node("HUD/ReportPanel").hide()

	# nessun erede: la colonia sceglie una casata nuova; il giocatore può indicarne un altro
	var arms_before: Dictionary = main.arms
	main.die(kid2, "is gone.")
	var panel2: Control = main.get_node("HUD/SuccessionPanel")
	check(main.ruler == second and main.house_name == second.last_name and main.reigns[-1][0] == second, "regna il più abile")
	check(panel2.visible and panel2.get_node("Box/List").get_child_count() >= 2, "la finestra: chi sceglie la colonia")
	check(Array(main.chronicle).any(func(line): return "has no heirs. %s begins the house of %s." % [main.full_name(second), second.last_name] in line),
		"la cronaca")
	var other: Button = panel2.get_node("Box/List").get_child(1)
	var chosen = main.colonists.filter(func(o): return main.age_of(o) >= main.ADULT and o != second).filter(func(o):
		return other.text.begins_with(main.full_name(o)))[0]
	other.pressed.emit()
	check(main.ruler == chosen and main.house_name == chosen.last_name and main.reigns[-1][0] == chosen and not panel2.visible,
		"scelto un altro: regna lui, con la sua casata")
	check(main.chronicle[main.founding_line].contains(main.full_name(chosen)), "anche nella cronaca")

	# pretendenti: con una locanda, ogni 20 giorni circa una persona dell'altro sesso di un'altra casata, con la dote
	main.get_node("HUD/SuccessionPanel").hide()
	var lord = main.ruler
	lord.spouse = null
	check(main.can_marry(), "il sovrano nuovo si può sposare")
	main.next_suitor = 0.0
	main.update_suitors()
	check(is_equal_approx(main.next_suitor, main.clock + main.SUITOR_EVERY), "il primo fra 20 giorni")
	main.clock = main.next_suitor
	main.update_suitors()
	check(not main.guests.any(func(g): return g.suitor), "senza locanda nessuno")
	room.kind = main.RoomKind.INN
	main.next_suitor = main.clock
	main.update_suitors()
	var suitor = main.guests.filter(func(g): return g.suitor).front()
	check(suitor != null and suitor.sex != lord.sex and suitor.errand == main.Errand.ARRIVE, "arriva, dell'altro sesso")
	check(main.age_of(suitor) >= 16 and main.age_of(suitor) <= 30 and suitor.last_name != main.house_name
		and not suitor.house_arms.is_empty() and suitor.skills.reduce(func(n, v): return n + v, 0) == main.SUITOR_SKILLS,
		"16-30 anni, un'altra casata col suo stemma, qualche abilità")
	check(suitor.dowry[main.Res.GOLD] >= 20 and suitor.dowry[main.Res.GOLD] <= 80, "la dote: 20-80 monete")
	check(Array(main.chronicle).any(func(line): return "ask for the hand of %s" % main.full_name(lord) in line), "la cronaca")
	check(not main.suitors().any(func(o): return o[0] == suitor), "per strada non si sposa")
	main.arrive(suitor)
	check(is_equal_approx(suitor.stay_until, main.clock + main.SUITOR_STAY), "alla locanda aspetta 5 giorni")
	main.update_suitors()
	check(main.guests.filter(func(g): return g.suitor).size() == 1, "uno alla volta")
	main.open_sheet(suitor)
	check(main.get_node("HUD/ColonistSheet/Box/Hero").text.begins_with("Suitor from the house of %s" % suitor.last_name)
		and main.get_node("HUD/ColonistSheet/Box/Head/Arms").visible, "la scheda: pretendente, col suo stemma")
	var offer: Array = main.suitors().filter(func(o): return o[0] == suitor)
	check(offer.size() == 1 and offer[0][1] == "", "accetta sempre")
	main.open_marriage_menu()
	var item: int = main.marriage_menu.get_item_index(main.people().find(suitor))
	check(main.marriage_menu.get_item_text(item).contains("dowry: %d coins" % suitor.dowry[main.Res.GOLD]), "nel menu, con la dote")
	var gold: int = main.total(main.Res.GOLD)
	main.marriage_menu.id_pressed.emit(main.people().find(suitor))
	check(lord.spouse == suitor and suitor in main.colonists and suitor not in main.guests and not suitor.suitor, "sposato: un colono")
	check(main.total(main.Res.GOLD) == gold + suitor.dowry[main.Res.GOLD], "la dote resta in colonia")
	check(Array(main.chronicle).any(func(line): return "brings a dowry" in line), "la cronaca")

	print("OK: età, vecchiaia, matrimonio, figli, crescita, successione e pretendenti")
	quit()


# una stanza 5x5 (3x3 dentro) sul prato libero vicino al centro, la porta in basso
func build_room(main):
	var mid: Vector2i = main.MAP_SIZE / 2
	for y in range(mid.y - 20, mid.y + 20):
		for x in range(mid.x - 20, mid.x + 20):
			var spot := Rect2i(x, y, 5, 5)
			if spot.grow(1).has_point(mid) or not main.cells_in(spot.grow(1)).all(func(k): return (not main.water.has(k)
					and not main.rocks.has(k) and not main.boulders.has(k) and not main.built.has(k)
					and main.items.values().all(func(ground): return not ground.has(k)))):
				continue
			for k in main.cells_in(spot.grow(1)):
				for plants in [main.trees, main.bushes, main.weeds, main.flax]:
					plants.erase(k)
				main.astar.set_point_solid(k, false)
			for k in main.cells_in(spot):
				if k == spot.position + Vector2i(2, 4):
					main.built[k] = [main.Build.DOOR, main.Res.WOOD]
				elif not spot.grow(-1).has_point(k):
					main.built[k] = [main.Build.WALL, main.Res.WOOD]
					main.astar.set_point_solid(k)
			main.update_rooms()
			for room in main.rooms:
				if room.cells.has(spot.position + Vector2i(2, 2)):
					return room
	return null


# un colono in più, adulto, accanto al centro
func person(main) -> Variant:
	var c = main.Colonist.new()
	main.dress(c, main.people().map(func(o): return o.first_name))
	c.pos = main.center(main.MAP_SIZE / 2 + Vector2i(main.colonists.size(), 1))
	c.skills = main.Skill.values().map(func(_s): return 0)
	c.xp = main.Skill.values().map(func(_s): return 0)
	c.needs = main.Need.values().map(func(_n): return 60.0)
	c.trend = c.needs.map(func(_v): return 0.0)
	main.give_age(c, main.ADULT_AGE)
	main.colonists.append(c)
	return c


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
