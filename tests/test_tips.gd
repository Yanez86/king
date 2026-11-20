# Esegui: godot --headless --path . -s tests/test_tips.gd
# I suggerimenti annidati (docs/TECH.md): il glossario (ogni cosa ha il suo testo, e ogni collegamento porta a una cosa
# che ce l'ha), il meccanismo (compare, si blocca, apre quello del collegamento, si chiude), dove sono attaccati
extends SceneTree


func _initialize() -> void:
	TranslationServer.set_locale("en")
	seed(1)
	var main = load("res://main.tscn").instantiate()
	main.game_start = false
	root.add_child(main)
	await process_frame
	main.events = false
	var g = main.glossary
	var tips = main.tips
	tips.manual = true

	# il glossario: ogni cosa di ogni tipo ha titolo e testo; ogni collegamento porta a una cosa che ne ha uno
	var names := {"tech": main.Tech, "law": main.Law, "build": main.Build, "item": main.Res, "room": main.RoomKind,
		"cond": main.Cond, "trait": main.Trait, "skill": main.Skill, "work": main.Work}
	var keys: Array = g.CONCEPTS.keys().map(func(c): return "concept:" + c)
	for kind in names:
		for value in names[kind].values():
			if kind == "room" and value == main.RoomKind.NONE:
				continue
			keys.append(g.key_of(kind, names[kind], value))
	var links := {}
	var link := RegEx.create_from_string("\\[url=([^\\]]+)\\]")
	for key in keys:
		var said: Array = g.content(key)
		check(said.size() == 2 and said[0] != "" and said[1] != "", "%s: titolo e testo" % key)
		for m in link.search_all(said[1]):
			links[m.get_string(1)] = key
	check(links.size() > 100, "tanti collegamenti (%d)" % links.size())
	for key in links:
		check(not g.content(key).is_empty(), "il collegamento %s (da %s) porta a qualcosa" % [key, links[key]])
	check(g.content("tech:NOPE").is_empty() and g.content("nope").is_empty(), "una chiave che non c'è: niente")

	# i testi dicono le cose giuste, coi collegamenti
	var oven: String = g.content("tech:STONE_OVEN")[1]
	check(oven.contains("[url=tech:GARDEN]") and oven.contains("[url=build:OVEN]") and oven.contains("[url=item:BREAD]")
		and oven.contains("[url=tech:APIARY]") and oven.contains("[url=item:NOTEBOOK]"), "il Forno: serve l'Orto, sblocca forno e pane, poi l'Apicoltura, un quaderno")
	var bread: String = g.content("item:BREAD")[1]
	check(bread.contains("[url=build:OVEN]") and bread.contains("[url=item:FLOUR]") and bread.contains("[url=tech:STONE_OVEN]"), "il pane: al forno dalla farina")
	var funerals: String = g.content("law:FUNERALS")[1]
	check(funerals.contains("[url=concept:authority]") and funerals.contains("[url=concept:seals]") and funerals.contains("[url=build:GRAVE]"), "una legge: autorità, sigilli, la tomba")
	check(g.content("room:MILL")[1].contains("[url=build:MILLSTONE]") and g.content("build:MILLSTONE")[1].contains("[url=room:MILL]"), "stanza e mobile si nominano")

	# il meccanismo: compare dopo SHOW_DELAY, si blocca dopo LOCK_TIME; bloccato, un collegamento apre il suo accanto
	var thing := Button.new()
	main.get_node("HUD").add_child(thing)
	thing.position = Vector2(200, 200)
	thing.size = Vector2(60, 40)
	tips.attach(thing, "tech:STONE_OVEN")
	check(thing.tooltip_text == "" and thing.get_meta("tip") == "tech:STONE_OVEN", "attaccato: niente suggerimento di Godot")
	var over := Vector2(220, 220)
	tips.source = thing
	tips.source_since = 10.0
	tips.update(10.3, over)
	check(tips.levels.is_empty(), "non ancora")
	tips.update(10.45, over)
	check(tips.levels.size() == 1 and not tips.levels[0].locked and tips.levels[0].key == "tech:STONE_OVEN", "compare, non bloccato")
	var first = tips.levels[0]
	check(first.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "non bloccato il mouse ci passa attraverso")
	tips.update(10.45 + tips.LOCK_TIME, over)
	check(first.locked and first.panel.mouse_filter == Control.MOUSE_FILTER_STOP, "si blocca")
	var inside: Vector2 = first.panel.get_global_rect().get_center()
	tips.update(11.5, inside)
	check(tips.levels.size() == 1, "dentro il suggerimento bloccato resta")
	tips.hover_link(0, "build:OVEN", 11.5)
	tips.update(11.7, inside)
	check(tips.levels.size() == 1, "sul collegamento, non ancora")
	tips.update(11.85, inside)
	check(tips.levels.size() == 2 and tips.levels[1].key == "build:OVEN", "il collegamento apre il suo")
	var second = tips.levels[1]
	check(second.panel.position.x >= first.panel.get_global_rect().end.x or second.panel.get_global_rect().end.x <= first.panel.position.x,
		"accanto al primo, non sopra")
	tips.update(11.85 + tips.LOCK_TIME, inside)
	check(second.locked, "si blocca anche lui")
	tips.link_label = null  # il mouse lascia il collegamento e va nel secondo
	var inside2: Vector2 = second.panel.get_global_rect().get_center()
	tips.update(12.8, inside2)
	tips.update(13.5, inside2)
	check(tips.levels.size() == 2, "nel secondo restano tutti e due")
	tips.update(13.6, inside)
	tips.update(13.6 + tips.GRACE, inside)
	check(tips.levels.size() == 1, "tornando nel primo, il secondo si chiude")
	tips.source = null
	tips.update(14.0, Vector2(5, 700))
	check(tips.levels.size() == 1, "appena fuori resta ancora un attimo")
	tips.update(14.0 + tips.GRACE, Vector2(5, 700))
	check(tips.levels.is_empty(), "fuori da tutto si chiude")
	tips.source = thing
	tips.source_since = 20.0
	tips.update(20.5, over)
	tips.update(20.6, Vector2(5, 700))
	tips.update(20.6 + tips.GRACE, Vector2(5, 700))
	check(tips.levels.is_empty(), "non bloccato, uscendo dalla cosa scompare")

	# dove: le ricerche nella finestra Knowledge, le leggi nella finestra Laws
	main.get_node("HUD/KnowledgePanel").show()
	main.knowledge_key = ""
	main.fill_knowledge()
	var cards: Array = main.get_node("HUD/KnowledgePanel").find_children("*", "Button", true, false).filter(func(b): return b.has_meta("tip"))
	check(cards.size() == main.Tech.size() and cards.all(func(b): return str(b.get_meta("tip")).begins_with("tech:")), "un riquadro per ricerca, col suo suggerimento")
	main.get_node("HUD/KnowledgePanel").hide()
	main.get_node("HUD/LawsPanel").show()
	main.laws_key = ""
	main.fill_laws()
	var laws: Array = main.get_node("HUD/LawsPanel").find_children("*", "Control", true, false).filter(func(b): return str(b.get_meta("tip", "")).begins_with("law:"))
	check(laws.size() >= main.Law.size(), "le leggi, col loro suggerimento")

	print("OK: suggerimenti annidati (%d cose, %d collegamenti diversi)" % [keys.size(), links.size()])
	quit()


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
