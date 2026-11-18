# Esegui: godot --headless --path . -s tests/test_ruler.gd
# Il sovrano e la casata: le due pagine della nuova partita (nomi, stemma, punti abilità, sesso), lo stemma composto
# (scudo e stendardo, regola degli smalti) e il sovrano in partita (reame, scheda)
extends SceneTree


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(1)
	var page = load("res://creation.tscn").instantiate()
	root.add_child(page)
	await process_frame
	var Main = page.Main
	var Skill = Main.Skill
	var T = Main.Tincture

	# la casata
	check(page.page == 0 and page.pages[0].visible and not page.pages[1].visible, "si parte dalla casata")
	check(not page.forward.disabled and page.forward.text == "Next", "nomi già pronti: si va avanti")
	page.house.text = " "
	page.refresh()
	check(page.forward.disabled, "senza il nome della casata no")
	page.house.text = "Valdora"
	page.colony.text = "Valbruna"
	page.set_arms(T.AZURE, "field")
	page.set_arms(T.OR, "field2")
	check(page.ruler.tunic == Main.TINCTURE_COLORS[T.AZURE] and page.ruler.cape == Main.TINCTURE_COLORS[T.OR],
		"maglia e mantello coi primi due smalti")
	var pressed: Array = page.synced.filter(func(e): return e[0].button_pressed).map(func(e): return e[2])
	check(page.synced.filter(func(e): return e[0].button_pressed).size() == 8 + 5 and T.AZURE in pressed,
		"una scelta premuta per riga")
	page.go(1)
	check(page.pages[1].visible and page.forward.text == "Start", "poi il sovrano")
	page.dress_in(Main.TINCTURE_COLORS[T.VERT], "tunic")
	page.set_arms(T.GULES, "field")
	check(page.ruler.tunic == Main.TINCTURE_COLORS[T.VERT] and page.ruler.cape == Main.TINCTURE_COLORS[T.OR],
		"scelti a mano, non seguono più lo stemma")

	# il sovrano: punti abilità, nome, sesso
	check(page.points_left() == Main.RULER_POINTS, "punti tutti da dare")
	for i in 7:
		page.spend(Skill.MINING, 1)
	check(page.ruler.skills[Skill.MINING] == Main.RULER_SKILL_CAP, "al massimo 3 per abilità")
	for s in [Skill.COOKING, Skill.MELEE, Skill.FISHING, Skill.HUNTING]:
		for i in 5:
			page.spend(s, 1)
	check(page.points_left() == 0 and page.ruler.skills[Skill.FISHING] == 3 and page.ruler.skills[Skill.HUNTING] == 0,
		"12 punti in tutto")
	check(page.levels[Skill.RANGED][2].disabled and not page.levels[Skill.MELEE][1].disabled, "finiti i punti, il + si spegne")
	page.spend(Skill.MINING, -1)
	check(page.points_left() == 1, "il - li ridà")
	var Trait = Main.Trait
	page.toggle_trait(Trait.WORKAHOLIC)
	check(page.ruler.traits.is_empty() and page.trait_buttons[Trait.WORKAHOLIC].disabled, "un pregio costa 2 punti: con 1 no")
	page.toggle_trait(Trait.GLUTTON)
	check(page.points_left() == 3 and page.trait_buttons[Trait.GLUTTON].button_pressed, "un difetto ne dà 2")
	check(page.trait_buttons[Trait.SMALL_APPETITE].disabled and not page.trait_buttons[Trait.EASYGOING].disabled, "niente talenti in contrasto")
	page.toggle_trait(Trait.WORKAHOLIC)
	check(page.points_left() == 1 and page.ruler.traits == [Trait.GLUTTON, Trait.WORKAHOLIC], "ora il pregio sì")
	check(page.trait_buttons[Trait.EARLY_BIRD].disabled, "al massimo due")
	page.toggle_trait(Trait.GLUTTON)
	check(Trait.GLUTTON in page.ruler.traits, "il difetto non si toglie: i suoi punti sono spesi")
	page.toggle_trait(Trait.WORKAHOLIC)
	page.toggle_trait(Trait.WORKAHOLIC)
	check(page.ruler.traits.size() == 2 and page.points_left() == 1, "il pregio si toglie e si rimette")
	page.first.text = ""
	page.refresh()
	check(page.forward.disabled, "senza nome non si parte")
	page.first.text = "Ilda"
	page.set_sex(Main.Sex.FEMALE)
	check(page.first.text == "Ilda" and page.beard.disabled and not page.forward.disabled, "un nome inventato resta; niente barba alle donne")
	page.first.text = Main.FIRST_NAMES[Main.Sex.FEMALE][0]
	page.set_sex(Main.Sex.MALE)
	check(page.first.text in Main.FIRST_NAMES[Main.Sex.MALE] and not page.beard.disabled, "un nome dell'altro sesso cambia")
	page.first.text = "Ilda"
	page.set_sex(Main.Sex.FEMALE)

	# lo stemma: scudo francese, d'oro al capo di rosso, una stella d'azzurro
	var a := {"shape": Main.Shape.HEATER, "division": Main.Division.PLAIN, "field": T.OR, "field2": T.GULES,
		"ordinary": Main.Ordinary.CHIEF, "ordinary_tincture": T.GULES, "charge": Main.Charge.STAR, "charge_tincture": T.AZURE}
	var img: Image = Main.arms_texture(a).get_image()
	check(img.get_size() == Vector2i(16, 16) and img.get_pixel(0, 15).a == 0 and img.get_pixel(0, 0).a == 1, "forma col bordo")
	check(same(img.get_pixel(4, 11), Main.TINCTURE_COLORS[T.OR]) and same(img.get_pixel(7, 2), Main.TINCTURE_COLORS[T.GULES])
		and same(img.get_pixel(7, 4), Main.TINCTURE_COLORS[T.AZURE]), "campo, capo e la punta della stella")
	a.ordinary = Main.Ordinary.NONE
	a.charge = Main.Charge.NONE
	a.division = Main.Division.PALE
	img = Main.arms_texture(a).get_image()
	check(same(img.get_pixel(3, 7), Main.TINCTURE_COLORS[T.OR]) and same(img.get_pixel(12, 7), Main.TINCTURE_COLORS[T.GULES]), "partito")
	var flag: Image = Main.banner_texture(a).get_image()
	check(flag.get_size() == Vector2i(64, 16) and same(flag.get_pixel(5, 3), Main.TINCTURE_COLORS[T.OR])
		and same(flag.get_pixel(11, 3), Main.TINCTURE_COLORS[T.GULES]) and flag.get_pixel(3, 3).a == 0, "lo stendardo partito, l'asta no")
	check(same(flag.get_pixel(8, 3), Main.TINCTURE_COLORS[T.OR].darkened(1.0 - Main.BANNER_SHADE)), "la piega in ombra")
	var metal := func(t): return t in Main.METALS
	for i in 300:
		var r: Dictionary = Main.random_arms()
		check(metal.call(r.field) != metal.call(r.field2) and (r.ordinary == 0 or metal.call(r.ordinary_tincture) != metal.call(r.field))
			and (r.charge == 0 or metal.call(r.charge_tincture) != metal.call(r.field)), "il dado rispetta la regola degli smalti")
		check(r.charge == 0 or r.ordinary not in Main.CENTRAL, "niente figure sulle pezze che passano dal centro")

	# in partita
	Main.setup = page.make_setup()
	var chosen: Dictionary = page.arms.duplicate()
	page.free()
	var main = load("res://main.tscn").instantiate()
	main.start_rooms = false
	main.settings_file = ""
	root.add_child(main)
	await process_frame
	var r = main.ruler
	check(r == main.colonists[0] and r.first_name == "Ilda" and r.last_name == "Valdora" and r.sex == Main.Sex.FEMALE,
		"il sovrano è il primo colono, come l'ha fatto il giocatore")
	check(r.skills[Skill.MINING] == 2 and r.skills[Skill.COOKING] == 3 and r.traits == [Main.Trait.GLUTTON, Main.Trait.WORKAHOLIC],
		"con le sue abilità e i suoi talenti")
	check(r.tunic == Main.TINCTURE_COLORS[T.VERT], "vestito come l'ha scelto")
	check(main.colonists.slice(1).all(func(c): return c.skills.max() == 0 and c.first_name != "Ilda"), "gli altri partono da 0, con altri nomi")
	check(main.realm == "Valbruna" and main.realm_button.text == "Lordship of Valbruna", "il reame nella barra in alto")
	check(main.arms == chosen and main.get_node("HUD/TopBar/Row/RealmIcon").texture == main.arms_tex, "e lo stemma accanto")
	main.realm_button.pressed.emit()
	var box = main.get_node("HUD/ColonistSheet/Box")
	check(main.shown == r and box.get_node("Hero").text.contains("Lady of Valbruna") and box.get_node("Head/Arms").visible,
		"dalla barra la scheda del sovrano, col titolo e lo stemma")
	main.open_sheet(main.colonists[1])
	check(not box.get_node("Hero").visible and not box.get_node("Head/Arms").visible, "gli altri senza")
	print("OK: il sovrano e la casata")
	quit()


func same(a: Color, b: Color) -> bool:  # a meno degli 8 bit per canale dell'immagine
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01 and absf(a.a - b.a) < 0.01


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
