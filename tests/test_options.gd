# Esegui: godot --headless --path . -s tests/test_options.gd
# Menù delle opzioni: apertura con Esc e con l'ingranaggio, pausa, tab (System, Video, Audio, Keybindings, Debug), tasti della
# barra in basso; le barre di Ordini e Viste, gli ordini spenti in costruzione, il menu a sinistra, Esc che chiude prima
# quello che è aperto; la velocità in basso a destra, finestra Wiki
extends SceneTree

const SAVED := "user://test_settings.cfg"


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(1)
	var main = load("res://main.tscn").instantiate()
	main.game_start = false
	main.settings_file = ""  # tasti di partenza: non quelli salvati da chi gioca
	root.add_child(main)
	await process_frame

	check(not main.options.visible, "menù chiuso all'inizio")
	check(main.hotkeys.size() == main.tool_names.size() and main.tool_names.has("Build") and not main.tool_names.has("Separator"),
		"un comando per pulsante della barra in basso, i separatori no")
	check(main.hotkeys["Build"] == KEY_B and main.hotkeys["RoomsLens"] == KEY_L, "tasti di partenza")
	check(main.hotkeys.values().all(func(k): return not k in main.FIXED_KEYS), "nessun tasto fisso tra quelli di partenza")
	var keys: Array = main.hotkeys.values().filter(func(k): return k != KEY_NONE)
	check(keys.all(func(k): return keys.count(k) == 1), "tutti diversi")
	check(main.hotkeys.keys().filter(func(n): return main.hotkeys[n] == KEY_NONE) == ["Orders", "Views"],
		"senza tasto solo Ordini e Viste: i loro tasti ce l'hanno")
	check(main.hotkeys["Census"] == KEY_A and main.hotkeys["Chronicle"] == KEY_D and main.hotkeys["Menu"] == KEY_TAB,
		"A gli abitanti, D la cronaca, Tab il menu")
	check(main.build_button.tooltip_text == "Build (B)", "il tasto nel suggerimento del pulsante")
	check(main.key_list.get_node("Build").text == "B", "e nella sua riga del menù")
	check(main.key_list.get_child_count() == 3 * main.hotkeys.size(), "righe: icona, nome, tasto")

	# la barra in basso: Seleziona, Costruisci, Ordini, Distruggi | Viste; gli ordini e le viste nelle loro barre
	check(main.hotbar.get_children().filter(func(b): return b is Button).map(func(b): return String(b.name))
		== ["Select", "Build", "Orders", "Destroy", "Views"], "cinque tasti in basso")
	check(main.tool("Chop").get_parent() == main.get_node("HUD/OrdersBar/Row") and main.tool("RoomsLens").get_parent()
		== main.get_node("HUD/ViewsBar/Row") and not main.get_node("HUD/OrdersBar").visible, "ordini e viste nelle loro barre, chiuse")

	# tasti della barra: come cliccarne i pulsanti; in costruzione niente ordini, Distruggi sì
	press(main, KEY_B)
	check(main.build_button.button_pressed and main.categories.visible and main.orders_button.disabled, "B apre Build, Ordini spento")
	check(main.orders_button.tooltip_text.ends_with("close it first (Esc)"), "e dice perché")
	press(main, KEY_M)
	check(main.order != main.Order.MINE and main.build_button.button_pressed, "in costruzione M non fa niente")
	press(main, KEY_X)
	check(main.order == main.Order.DEMOLISH and not main.build_button.button_pressed and not main.orders_button.disabled,
		"X sceglie Distruggi e chiude Build")
	press(main, KEY_M)
	check(main.order == main.Order.MINE and main.orders_button.button_pressed and main.get_node("HUD/OrdersBar").visible,
		"M sceglie Mine e apre la barra degli Ordini")
	press(main, KEY_X)
	check(main.order == main.Order.DEMOLISH and not main.get_node("HUD/OrdersBar").visible, "Distruggi chiude la barra")
	main.orders_button.button_pressed = true
	main.tool("Chop").button_pressed = true
	main.orders_button.button_pressed = false
	check(main.order == main.Order.NONE and main.select_button.button_pressed, "chiusa la barra, l'ordine scelto si lascia")
	main.orders_button.button_pressed = true
	main.tool("Chop").button_pressed = true
	press(main, KEY_Q)
	check(main.order == main.Order.NONE and main.select_button.button_pressed and not main.get_node("HUD/OrdersBar").visible,
		"Q torna a Select e chiude la barra")
	press(main, KEY_L)
	check(main.lens.visible and not main.get_node("HUD/ViewsBar").visible, "L, la lente delle stanze, anche a barra chiusa")
	main.views_button.button_pressed = true
	var views: Control = main.get_node("HUD/ViewsBar")
	await process_frame
	check(views.visible and views.get_global_rect().position.x >= main.get_node("HUD/Tools").get_global_rect().end.x,
		"le viste accanto alla barra in basso")
	press(main, KEY_L)
	main.views_button.button_pressed = false

	# il menu a sinistra: Tab lo apre, una finestra scelta lo chiude; i tasti rapidi accanto ai nomi
	var drawer: Control = main.drawer
	check(not drawer.visible and main.tool("Census").get_parent() == drawer.get_node("Box"), "il menu chiuso")
	press(main, KEY_TAB)
	check(drawer.visible and main.menu_tab.button_pressed and main.menu_tab.text == "<", "Tab lo apre")
	check(main.tool("Jobs").get_node("Key").text == "J" and main.tool("Census").get_node("Key").text == "A", "i tasti accanto")
	main.tool("Census").button_pressed = true
	main.tool("Census").pressed.emit()
	check(main.get_node("HUD/CensusPanel").visible and not main.menu_tab.button_pressed, "scelta una finestra, si chiude")
	press(main, KEY_A)
	check(not main.get_node("HUD/CensusPanel").visible and not main.tool("Census").button_pressed, "A la richiude")
	main.toggle_census()
	check(main.tool("Census").button_pressed, "il numero dei coloni in alto la apre ancora, col tasto del menu")
	main.get_node("HUD/CensusPanel").hide()
	check(not main.tool("Census").button_pressed, "chiusa con la X: il tasto si alza")
	# la Produzione sta nel menu, dopo le Risorse, col tasto S
	var box: Control = drawer.get_node("Box")
	check(main.hotkeys["Production"] == KEY_S and main.tool("Production").get_parent() == box
		and main.tool("Production").get_index() == main.tool("Resources").get_index() + 1 and main.tool("Production").get_node("Key").text == "S",
		"la Produzione nel menu, dopo le Risorse, col tasto S")
	press(main, KEY_S)
	check(main.production_panel.visible and main.tool("Production").button_pressed
		and main.production_panel.get_node("Box/None").visible and not main.production_panel.get_node("Box/Shops").visible,
		"S la apre; senza postazioni lo dice")
	main.production_panel.hide()
	check(not main.tool("Production").button_pressed, "chiusa con la X: il tasto si alza")
	press(main, KEY_S)
	press(main, KEY_S)
	check(not main.production_panel.visible, "S la richiude")
	main.chronicle.append("prova")
	main.update_dots()
	check(main.tool("Chronicle").get_node("Dot").visible and main.menu_tab.get_node("Dot").visible, "una voce nuova: il pallino")
	press(main, KEY_D)
	main.update_dots()
	check(main.get_node("HUD/ChroniclePanel").visible and not main.tool("Chronicle").get_node("Dot").visible, "letta, via il pallino")
	press(main, KEY_D)
	check(not main.get_node("HUD/ChroniclePanel").visible, "D la richiude")
	main.chronicle.clear()

	# Esc chiude prima quello che è aperto: il menu, la costruzione, l'ordine; poi apre le opzioni
	press(main, KEY_TAB)
	press(main, KEY_ESCAPE)
	check(not main.menu_tab.button_pressed and not main.options.visible, "Esc chiude il menu")
	press(main, KEY_B)
	press(main, KEY_ESCAPE)
	check(not main.build_button.button_pressed and not main.options.visible, "poi la costruzione")
	press(main, KEY_C)
	press(main, KEY_ESCAPE)
	check(main.order == main.Order.NONE and not main.get_node("HUD/OrdersBar").visible and not main.options.visible, "poi l'ordine")
	press(main, KEY_Q)
	check(main.order == main.Order.NONE and main.select_button.button_pressed, "Q torna a Select")
	press(main, KEY_J)
	check(main.jobs_panel.visible, "J apre la finestra Jobs")
	press(main, KEY_J)
	check(not main.jobs_panel.visible, "e la richiude")
	press(main, KEY_B, true)
	check(not main.build_button.button_pressed, "con Ctrl il tasto non vale")

	# velocità in basso a destra: i pulsanti la cambiano e mostrano quella attuale, anche cambiata coi tasti
	var top: Node = main.get_node("HUD/Speed/Row")
	var bar: Node = main.get_node("HUD/TopBar/Row")
	check(not bar.has_node("Fullscreen") and bar.get_node("Screen").icon != null and bar.get_node("Screen").text == ""
		and not bar.has_node("Pause"), "in alto lo schermo, senza scritta; la velocità non più")
	await process_frame
	var corner: Rect2 = main.get_node("HUD/Speed").get_global_rect()
	check(corner.end.x > main.get_viewport().get_visible_rect().size.x - 20 and corner.end.y > main.get_viewport().get_visible_rect().size.y - 20,
		"in basso a destra")
	top.get_node("Fast").pressed.emit()
	check(Engine.time_scale == 2.0, "Fast: 2x")
	press(main, KEY_3)
	await process_frame
	check(top.get_node("Fastest").button_pressed and not top.get_node("Fast").button_pressed, "3: premuto Fastest")
	press(main, KEY_SPACE)
	await process_frame
	check(Engine.time_scale == 0.0 and top.get_node("Pause").button_pressed, "Space: pausa")
	top.get_node("Play").pressed.emit()
	await process_frame
	check(Engine.time_scale == 1.0 and top.get_node("Play").button_pressed and not top.get_node("Pause").button_pressed, "Play: 1x")

	# Esc e ingranaggio: il menù apre sempre la tab System e ferma il gioco, chiuso riprende alla velocità di prima
	Engine.time_scale = 2.0
	press(main, KEY_ESCAPE)
	check(main.options.visible and Engine.time_scale == 0.0, "Esc apre il menù e ferma il gioco")
	var tabs: Node = main.get_node("HUD/Options/Window/Box/Body/Tabs")
	var system: Control = main.get_node("HUD/Options/Window/Box/Body/Pages/System")
	var video: Control = main.get_node("HUD/Options/Window/Box/Body/Pages/Video")
	check(system.is_visible_in_tree() and not main.key_list.is_visible_in_tree(), "tab System aperta")
	check(tabs.get_children().map(func(t): return String(t.name)) == ["System", "Video", "Audio", "Keybindings", "Debug"],
		"cinque tab: sistema, video, audio, tasti, debug")
	check(tabs.get_children().all(func(t): return t.text == "" and t.icon != null), "tab: solo icone")
	check(["Load", "MainMenu", "Quit"].all(func(b): return not system.get_node(b).disabled) and not system.has_node("Save"),
		"carica, menù principale, esci; niente salvataggi a mano")
	var languages: OptionButton = system.get_node("Language/Languages")
	check(range(languages.item_count).map(languages.get_item_text) == ["English", "Italiano"], "lingue, nella loro lingua")
	languages.select(1)
	languages.item_selected.emit(1)
	check(TranslationServer.get_locale() == "it" and main.tr("Options") == "Opzioni", "Italiano: i testi tradotti cambiano")
	languages.select(0)
	languages.item_selected.emit(0)
	check(main.tr("Options") == "Options", "e si torna all'inglese")
	await process_frame
	var size: Vector2 = main.options.get_node("Window").size
	tabs.get_node("Video").button_pressed = true
	await process_frame
	check(video.is_visible_in_tree() and not system.is_visible_in_tree(), "tab Video: la sua pagina al posto di System")
	check(video.get_node("Resolution/Sizes").item_count >= 1 and video.get_node("Resolution/Sizes").get_item_text(0) == "1280 x 720",
		"risoluzioni, dalla più piccola")
	check(not video.get_node("Fullscreen").button_pressed, "nei test in finestra")
	check(main.options.get_node("Window").size == size, "cambiando tab la finestra non cambia misura")
	tabs.get_node("Keybindings").button_pressed = true
	check(main.key_list.is_visible_in_tree() and not video.is_visible_in_tree() and not tabs.get_node("Video").button_pressed,
		"i tasti, una tab alla volta")
	press(main, KEY_B)
	press(main, KEY_SPACE)
	check(not main.build_button.button_pressed and Engine.time_scale == 0.0, "col menù aperto i tasti del gioco non valgono")
	press(main, KEY_ESCAPE)
	check(not main.options.visible and Engine.time_scale == 2.0, "Esc lo chiude: si riprende a 2x")
	main.get_node("HUD/TopBar/Row/Options").pressed.emit()
	check(main.options.visible, "anche l'ingranaggio lo apre")
	check(system.is_visible_in_tree() and tabs.get_node("System").button_pressed, "di nuovo su System")
	main.get_node("HUD/Options/Window/Box/Head/Close").pressed.emit()
	check(not main.options.visible and Engine.time_scale == 2.0, "e la X lo chiude")
	Engine.time_scale = 1.0

	# cambiare un tasto: clic sul tasto del comando, poi quello nuovo
	main.toggle_options()
	main.key_list.get_node("Mine").pressed.emit()
	check(main.rebinding == "Mine" and main.key_list.get_node("Mine").text == "Press a key", "Mine aspetta il tasto")
	for key in [KEY_SPACE, KEY_1, KEY_E, KEY_SHIFT]:
		press(main, key)
	check(main.rebinding == "Mine" and main.hotkeys["Mine"] == KEY_M, "tasti fissi e modificatori non si prendono")
	press(main, KEY_B)
	check(main.hotkeys["Mine"] == KEY_B and main.hotkeys["Build"] == KEY_NONE and main.rebinding == "", "B passa a Mine, Build resta senza")
	check(main.key_list.get_node("Build").text == "-" and main.build_button.tooltip_text == "Build", "senza tasto: un trattino")
	check(main.tool("Mine").tooltip_text == "Mine (B)", "suggerimento aggiornato")
	check(main.options.visible, "il tasto preso non chiude il menù")
	main.start_rebind("Chop")
	press(main, KEY_ESCAPE)
	check(main.options.visible and main.hotkeys["Chop"] == KEY_C and main.rebinding == "", "Esc annulla, senza chiudere il menù")
	main.start_rebind("Chop")
	press(main, KEY_DELETE)
	check(main.hotkeys["Chop"] == KEY_NONE, "Canc toglie il tasto")
	main.start_rebind("Fish")
	main.toggle_options()
	check(main.rebinding == "" and main.hotkeys["Fish"] == KEY_F, "chiuso il menù non si aspetta più")
	press(main, KEY_B)
	check(main.order == main.Order.MINE, "il tasto nuovo vale")
	press(main, KEY_C)
	check(main.order == main.Order.MINE, "quello tolto non fa più niente")
	main.select_tool()
	main.get_node("HUD/Options/Window/Box/Body/Pages/Keybindings/Reset").pressed.emit()
	check(main.hotkeys["Build"] == KEY_B and main.hotkeys["Mine"] == KEY_M and main.hotkeys["Chop"] == KEY_C, "Reset: quelli di partenza")

	# Wiki: tasto in basso (F1), una voce per pagina, si apre sulla prima
	var wiki: Control = main.get_node("HUD/WikiPanel")
	var topics: ItemList = wiki.get_node("Box/Body/Topics")
	check(not wiki.visible and main.hotkeys["Wiki"] == KEY_F1, "Wiki chiusa, tasto F1")
	press(main, KEY_F1)
	check(wiki.visible and main.get_node("HUD/TopBar/Row/Wiki").button_pressed, "F1 apre la Wiki")
	check(topics.item_count == main.WIKI.PAGES.size() and topics.item_count > 5 and topics.is_selected(0), "argomenti, il primo scelto")
	check(wiki.get_node("Box/Body/Text").text == main.glossary.wikify(main.WIKI.PAGES[0][1]), "la sua pagina, coi collegamenti")
	topics.select(2)
	topics.item_selected.emit(2)
	check(wiki.get_node("Box/Body/Text").text == main.glossary.wikify(main.WIKI.PAGES[2][1]), "un'altra voce, un'altra pagina")
	wiki.get_node("Box/Head/Close").pressed.emit()
	check(not wiki.visible and not main.get_node("HUD/TopBar/Row/Wiki").button_pressed, "la X la chiude, tasto su")

	# salvati: si ritrovano
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED))
	main.settings_file = SAVED
	main.bind_key("Hunt", KEY_K)
	main.hotkeys.clear()
	main.load_keys()
	check(main.hotkeys["Hunt"] == KEY_K and main.hotkeys["Build"] == KEY_B, "tasti salvati e ricaricati")
	main.bind_key("Build", KEY_NONE)
	main.load_keys()
	check(main.hotkeys["Build"] == KEY_NONE, "anche quelli tolti")
	main.set_language("it")
	var config := ConfigFile.new()
	config.load(SAVED)
	check(config.get_value("game", "language") == "it" and config.get_value("keys", "Build") == KEY_NONE,
		"la lingua si salva accanto ai tasti")
	TranslationServer.set_locale("en")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED))
	# tab Debug: Advance 12 hours fa andare avanti la partita davvero, mezza giornata di tick; in alto niente più Debug,
	# ma la data e il meteo
	check(not bar.has_node("Debug") and bar.get_node("Info") == main.info_label and main.forecast_strip.get_parent() == bar
		and main.forecast_strip.get_index() == main.info_label.get_index() + 1, "in alto data e meteo, niente Debug")
	var day: float = main.clock
	main.get_node("HUD/Options/Window/Box/Body/Pages/Debug/Advance").pressed.emit()
	check(is_equal_approx(main.clock, day + 0.5), "avanti di 12 ore")
	# le animazioni dell'interfaccia: brevi, e finite lasciano tutto com'era
	press(main, KEY_J)
	check(main.jobs_panel.visible and main.jobs_panel.modulate.a == 0.0, "una finestra che si apre: c'è subito, e compare")
	main.tool("Build").button_down.emit()
	check(main.tool("Build").scale == Vector2.ONE * main.PRESS_SCALE, "un tasto premuto si stringe")
	main.beds_label.text = "3"
	main.set_count(main.beds_label, "4")
	check(main.beds_label.text == "4" and main.beds_label.scale == Vector2.ONE * main.BUMP_SCALE and main.beds_label.modulate == main.MARK_GOLD,
		"un numero che cambia: d'oro, e fa un saltello")
	main.set_count(main.beds_label, "4")
	main.get_node("HUD/OrdersBar").show()
	check(main.get_node("HUD/OrdersBar").modulate.a == 0.0, "una barra che si apre sale dal basso")
	for moved in [main.jobs_panel, main.tool("Build"), main.beds_label, main.get_node("HUD/OrdersBar")]:
		moved.get_meta("motion").custom_step(1.0)  # un secondo: più di quanto durano
	check(main.jobs_panel.scale == Vector2.ONE and main.jobs_panel.modulate.a == 1.0 and main.tool("Build").scale == Vector2.ONE
		and main.beds_label.scale == Vector2.ONE and main.beds_label.modulate == Color.WHITE
		and main.get_node("HUD/OrdersBar").scale == Vector2.ONE and main.get_node("HUD/OrdersBar").modulate.a == 1.0,
		"finite le animazioni, tutto è come prima")
	main.get_node("HUD/OrdersBar").hide()
	press(main, KEY_J)
	check(main.hud_dots.size() == main.drawer.get_node("Box").get_child_count() + 1, "un pallino che pulsa per finestra del menu, e uno sulla linguetta")


	# la notte svelta: quando tutti dormono il gioco va a 3x da solo, e torna com'era appena uno si sveglia
	var sleep := func(on: bool):
		for col in main.colonists:
			col.path.clear()
			col.job = main.Job.SLEEP if on else main.Job.NONE
	Engine.time_scale = 1.0
	sleep.call(false)
	main.night_speed()
	check(Engine.time_scale == 1.0, "di giorno la velocità resta la tua")
	sleep.call(true)
	main.colonists[0].job = main.Job.NONE
	main.night_speed()
	check(Engine.time_scale == 1.0, "con uno sveglio niente")
	sleep.call(true)
	main.night_speed()
	check(main.all_asleep() and Engine.time_scale == 3.0, "tutti a dormire: 3x")
	main.night_speed()
	main.colonists[0].job = main.Job.NONE
	main.night_speed()
	check(Engine.time_scale == 1.0, "uno si sveglia: di nuovo 1x")
	Engine.time_scale = 2.0
	sleep.call(true)
	main.night_speed()
	check(Engine.time_scale == 3.0, "da 2x a 3x")
	Engine.time_scale = 1.0  # il giocatore rallenta di notte: per questa notte vale la sua
	main.night_speed()
	main.night_speed()
	check(Engine.time_scale == 1.0, "scelta un'altra velocità di notte, resta quella")
	sleep.call(false)
	main.night_speed()
	check(Engine.time_scale == 1.0, "e al mattino pure")
	Engine.time_scale = 0.0  # in pausa aspetta
	sleep.call(true)
	main.night_speed()
	check(Engine.time_scale == 0.0, "in pausa resta in pausa")
	Engine.time_scale = 2.0
	main.night_speed()
	check(Engine.time_scale == 3.0, "tolta la pausa, 3x")
	Engine.time_scale = 0.0
	main.night_speed()
	Engine.time_scale = 3.0
	main.night_speed()
	sleep.call(false)
	main.night_speed()
	check(Engine.time_scale == 2.0, "la pausa di notte non fa perdere la velocità di prima")
	Engine.time_scale = 3.0
	sleep.call(true)
	main.night_speed()
	sleep.call(false)
	main.night_speed()
	check(Engine.time_scale == 3.0, "chi giocava già a 3x resta a 3x")
	Engine.time_scale = 1.0
	print("OK: menù delle opzioni e tasti")
	quit()


func press(main, key: Key, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	event.ctrl_pressed = ctrl
	main._unhandled_input(event)


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
