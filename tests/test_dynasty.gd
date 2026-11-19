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

	print("OK: età, vecchiaia e matrimonio")
	quit()


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
