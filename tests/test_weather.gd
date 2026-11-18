# Esegui: godot --headless --path . -s tests/test_weather.gd
# Meteo e calendario: stagioni, neve, ondate di freddo, acqua che gela, previsioni, pagine ed eventi del calendario
extends SceneTree


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(1)
	var main = load("res://main.tscn").instantiate()
	main.start_rooms = false  # e tutte le ricerche fatte, Astronomia compresa
	root.add_child(main)
	await process_frame
	main.threats = false
	main.needs_rate = 0.0
	var sky = main.atmosphere
	var midsummer: float = 1 + 1.5 * main.SEASON_DAYS  # a mezzogiorno
	var midwinter: float = floorf(midsummer + main.YEAR_DAYS / 2.0)  # a mezzanotte

	# stagioni: caldo a metà estate, a metà inverno sotto la neve
	main.clock = midsummer
	check(sky.mean_temperature() == sky.YEAR_MEAN + sky.YEAR_SWING, "a metà estate il giorno più caldo")
	main.clock = midwinter
	check(sky.mean_temperature() < sky.SNOW_BELOW, "a metà inverno fa freddo da neve")

	# il tempo è deciso in anticipo per PLAN_DAYS giorni; d'inverno pioggia e temporali vengono giù come neve
	var picked := {}
	for i in 20:
		sky.plan.clear()
		sky.update_weather(0.0)
		for p in sky.plan:
			picked[p[2]] = true
	check(picked.has(sky.Weather.SNOW) and not picked.has(sky.Weather.RAIN), "d'inverno la pioggia viene giù come neve")
	check(sky.plan[0][0] <= main.clock and sky.plan.back()[1] >= main.clock + sky.PLAN_DAYS, "deciso fin dove arrivano le previsioni")
	var later: float = main.clock + 1.3
	check(sky.weather_at(later) == sky.plan.filter(func(p): return p[0] <= later and later < p[1])[0][2], "il tempo previsto è quello deciso")
	sky.plan = [[main.clock, main.clock + 3.0, sky.Weather.CLEAR]]
	sky.update_weather(0.0)
	check(sky.forecast == sky.Weather.CLEAR, "il tempo di adesso è quello deciso per adesso")

	# neve a terra: a mezzanotte d'inverno resta, a mezzogiorno d'estate si scioglie in pozzanghere
	sky.weather = sky.Weather.CLEAR
	sky.snow = 0.5
	sky.update_weather(10.0)
	check(sky.snow == 0.5, "sotto lo zero la neve resta")
	main.clock = midsummer
	sky.plan = [[main.clock, main.clock + 3.0, sky.Weather.CLEAR]]
	sky.update_weather(10.0)
	check(sky.snow < 0.5 and sky.wet > 0, "al caldo si scioglie, in pozzanghere")
	sky.snow = 0.0
	sky.wet = 0.0

	# ondata di freddo: d'inverno si decide in anticipo, quando arriva lo dice la cronaca (segnata sul calendario) e fa
	# COLD_WAVE gradi in meno; d'estate mai
	main.clock = midwinter
	sky.waves.clear()
	for i in 500:
		sky.waves_until = int(main.clock)  # di nuovo i tiri per i prossimi giorni
		sky.update_weather(0.0)
		if not sky.waves.is_empty():
			break
	check(not sky.waves.is_empty() and sky.waves[0][0] > main.clock, "d'inverno le ondate di freddo si sanno prima")
	var told: int = main.chronicle.size()
	main.clock = sky.waves[0][0] + 1.0
	sky.update_weather(0.0)
	check(main.chronicle.size() == told + 1 and main.chronicle_days[-1] == int(main.clock), "arrivata: nella cronaca, quel giorno")
	var cold: float = sky.mean_temperature()
	sky.waves.clear()
	check(is_equal_approx(sky.mean_temperature() - cold, sky.COLD_WAVE), "l'ondata di freddo: COLD_WAVE gradi in meno")
	main.clock = midsummer
	for i in 100:
		sky.waves_until = int(main.clock)
		sky.update_weather(0.0)
	check(sky.waves.is_empty(), "d'estate niente ondate di freddo")

	# acqua gelata: regge, l'acqua alta si attraversa e non si pesca; sgelata, chi ci stava sopra torna a riva
	var deep: Array = main.water.keys().filter(func(k): return main.water[k] == main.Ground.DEEP)
	check(not deep.is_empty() and main.astar.is_point_solid(deep[0]), "l'acqua alta non si attraversa")
	main.clock = midwinter
	sky.ice = 1.0
	sky.update_weather(0.0)
	check(sky.frozen and not main.astar.is_point_solid(deep[0]) and main.fishable().is_empty(), "gelata: si cammina sopra, non si pesca")
	check(main.forecast_strip.alerts().any(func(a): return a[0] == main.forecast_strip.Icon.ICE), "l'avviso del ghiaccio")
	var swimmer = main.colonists[0]
	swimmer.pos = main.center(deep[0])
	main.clock = midsummer
	sky.ice = sky.THIN_ICE
	sky.update_weather(0.0)
	check(not sky.frozen and main.astar.is_point_solid(deep[0]), "sgelata: l'acqua alta torna com'era")
	check(not main.astar.is_point_solid(main.cell_of(swimmer.pos)), "chi era sull'acqua alta torna a riva")
	sky.ice = 0.0

	# previsioni: un giorno, due con Astronomia; gelata e ondata in arrivo negli avvisi
	var strip = main.forecast_strip
	check(strip.horizon() == 2.0, "con Astronomia due giorni di previsioni")
	main.researched.erase(main.Tech.ASTRONOMY)
	check(strip.horizon() == 1.0, "senza, uno")
	main.clock = midwinter - 0.5  # mezzogiorno, prima della notte d'inverno
	sky.waves = [[main.clock + 0.5, main.clock + 3.0, false]]
	sky.plan = [[main.clock, main.clock + 3.0, sky.Weather.CLEAR]]
	var alerts: Array = strip.alerts().map(func(a): return a[1])
	check(alerts.any(func(t): return t.begins_with("Cold wave in 12 h")) and alerts.any(func(t): return t.begins_with("Frost")),
		"in arrivo l'ondata di freddo, e la gelata")
	strip.toggle()
	check(strip.panel.visible and strip.rows.get_child_count() >= 1 + 4 + 1, "il pannello: adesso, quattro fasce, gli avvisi")
	strip.toggle()
	sky.waves.clear()

	# calendario: dodici pagine fanno l'anno, ogni giorno sta nella sua; feste, Capodanno, cronaca e scadenze
	var cal = main.calendar
	var year: Array = []
	for p in 12:
		year += cal.days(p)
	check(year == range(main.YEAR_DAYS), "le dodici pagine fanno l'anno, in ordine")
	for d in [0, 1, 30, 31, 90, 91, 92, 364, 365, 400]:
		check(cal.days(cal.month_of(d)).has(d), "il giorno %d sta nella sua pagina" % d)
	check(cal.events(0)[0][0] == cal.Mark.CROWN and cal.events(91)[0] == [cal.Mark.FEAST, main.FEASTS[0]], "Capodanno e feste")
	main.clock = 40.5
	main.note("%s: something happened." % main.date(40))
	check(cal.events(40).has([cal.Mark.CHRONICLE, "something happened."]), "la cronaca sul suo giorno")
	main.revoked[main.Law.CURFEW] = 43.2
	check(cal.events(43).has([cal.Mark.DUE, "Curfew can be enacted again"]), "le scadenze delle leggi")
	main.revoked.erase(main.Law.CURFEW)
	main.info_label.gui_input.emit(click())
	check(cal.visible and cal.page == 1 and cal.grid.get_child_count() == main.MONTH_DAYS, "cliccando la data: la pagina del mese")

	print("OK: stagioni, neve, ondate di freddo, ghiaccio, previsioni e calendario")
	quit()


func click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
