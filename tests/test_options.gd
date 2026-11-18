# Esegui: godot --headless --path . -s tests/test_options.gd
# Menù delle opzioni: apertura con Esc e con l'ingranaggio, pausa, tab (System, Video, Audio, Keybindings), tasti della
# barra in basso; velocità in alto, finestra Wiki
extends SceneTree

const SAVED := "user://test_settings.cfg"


func _initialize() -> void:
	seed(1)
	var main = load("res://main.tscn").instantiate()
	main.start_rooms = false
	main.settings_file = ""  # tasti di partenza: non quelli salvati da chi gioca
	root.add_child(main)
	await process_frame

	check(not main.options.visible, "menù chiuso all'inizio")
	check(main.hotkeys.size() == main.tool_names.size() and main.tool_names.has("Build") and not main.tool_names.has("Separator"),
		"un comando per pulsante della barra in basso, i separatori no")
	check(main.hotkeys["Build"] == KEY_B and main.hotkeys["RoomsLens"] == KEY_L, "tasti di partenza")
	check(main.hotkeys.values().all(func(k): return not k in main.FIXED_KEYS), "nessun tasto fisso tra quelli di partenza")
	var keys: Array = main.hotkeys.values().filter(func(k): return k != KEY_NONE)
	check(keys.size() == main.hotkeys.size() and keys.all(func(k): return keys.count(k) == 1), "tutti diversi")
	check(main.build_button.tooltip_text == "Build (B)", "il tasto nel suggerimento del pulsante")
	check(main.key_list.get_node("Build").text == "B", "e nella sua riga del menù")
	check(main.key_list.get_child_count() == 3 * main.hotkeys.size(), "righe: icona, nome, tasto")

	# tasti della barra: come cliccarne i pulsanti
	press(main, KEY_B)
	check(main.build_button.button_pressed and main.categories.visible, "B apre Build")
	press(main, KEY_M)
	check(main.order == main.Order.MINE and not main.build_button.button_pressed, "M sceglie Mine e chiude Build")
	press(main, KEY_Q)
	check(main.order == main.Order.NONE and main.select_button.button_pressed, "Q torna a Select")
	press(main, KEY_J)
	check(main.jobs_panel.visible, "J apre la finestra Jobs")
	press(main, KEY_J)
	check(not main.jobs_panel.visible, "e la richiude")
	press(main, KEY_B, true)
	check(not main.build_button.button_pressed, "con Ctrl il tasto non vale")

	# velocità in alto: i pulsanti la cambiano e mostrano quella attuale, anche cambiata coi tasti
	var top: Node = main.get_node("HUD/TopBar/Row")
	check(not top.has_node("Fullscreen") and top.get_node("Screen").icon != null and top.get_node("Screen").text == "",
		"in alto lo schermo, senza scritta")
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
	check(tabs.get_children().map(func(t): return String(t.name)) == ["System", "Video", "Audio", "Keybindings"],
		"quattro tab: sistema, video, audio, tasti")
	check(tabs.get_children().all(func(t): return t.text == "" and t.icon != null), "tab: solo icone")
	check(system.get_node("MainMenu").disabled and system.get_node("Load").disabled and not system.get_node("Quit").disabled,
		"menù principale e carica non ci sono ancora, esci sì")
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
	check(main.get_node("HUD/Tools/Row/Mine").tooltip_text == "Mine (B)", "suggerimento aggiornato")
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
	check(wiki.visible and main.get_node("HUD/Tools/Row/Wiki").button_pressed, "F1 apre la Wiki")
	check(topics.item_count == main.WIKI.PAGES.size() and topics.item_count > 5 and topics.is_selected(0), "argomenti, il primo scelto")
	check(wiki.get_node("Box/Body/Text").text == main.WIKI.PAGES[0][1], "la sua pagina")
	topics.select(2)
	topics.item_selected.emit(2)
	check(wiki.get_node("Box/Body/Text").text == main.WIKI.PAGES[2][1], "un'altra voce, un'altra pagina")
	wiki.get_node("Box/Head/Close").pressed.emit()
	check(not wiki.visible and not main.get_node("HUD/Tools/Row/Wiki").button_pressed, "la X la chiude, tasto su")

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
