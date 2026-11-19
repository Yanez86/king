# Esegui: godot --headless --path . -s tests/test_heat.gd
# Tetti, calore e conservazione (GDD 4.4.5): focolare, fornace, calore attraverso i muri di legno, isolamento dei
# muri e dei pezzi, stanze senza gente, comignoli e fumo, il caldo che fa marcire, la lente del calore, un tetto per
# stanza, usura e riparazioni, la ghiacciaia e il ghiaccio, la fontana, l'incendio e i secchi
extends SceneTree

var main


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(1)
	main = load("res://main.tscn").instantiate()
	main.game_start = false  # e tutte le ricerche fatte
	root.add_child(main)
	await process_frame
	main.events = false
	main.needs_rate = 0.0
	main.routines = false
	main.animals.clear()
	var B = main.Build
	var R = main.Res
	var sky = main.atmosphere
	sky.climate = true
	sky.weather = sky.Weather.CLEAR
	sky.weather_strength = 0.0
	main.clock = floorf(1 + 3.5 * main.SEASON_DAYS) + 0.25  # a metà inverno, all'alba
	var out: float = sky.temperature()
	check(out < 5.0, "d'inverno fuori fa freddo (%.1f °C)" % out)

	# due stanze di legno col muro in comune (x = 16): a sinistra la cucina, a destra la camera
	clear(Rect2i(8, 8, 16, 9))
	var left := wall_room(Rect2i(10, 10, 7, 5), Vector2i(13, 14), R.WOOD)
	var right := wall_room(Rect2i(16, 10, 7, 5), Vector2i(19, 14), R.WOOD)
	main.update_rooms()
	var kitchen = main.room_at(Vector2i(12, 12))
	var bedroom = main.room_at(Vector2i(19, 12))
	check(kitchen != null and bedroom != null and kitchen != bedroom, "due stanze accanto")
	check(main.insulation(kitchen) == main.WALL_INSULATION[R.WOOD], "muri di legno: isolano a metà")

	# un tetto per stanza: il muro in comune sotto tutti e due, scandole sui muri di legno, il colmo sul lato lungo
	var plain := func(r): return r.rect.has_point(Vector2i(16, 12)) and not r.vertical and r.material == R.WOOD
	check(main.roofs.size() == 2 and main.roofs.all(plain), "due tetti di scandole, col colmo da est a ovest, che coprono il muro in comune")
	var l_shape := {}
	for k in main.cells_in(Rect2i(0, 0, 5, 2)) + main.cells_in(Rect2i(0, 2, 2, 4)):
		l_shape[k] = true
	check(main.rectangles(l_shape) == [Rect2i(0, 0, 5, 2), Rect2i(0, 2, 2, 4)], "una stanza a L: due rettangoli, due colmi")
	var front := []
	front.resize(5)
	front.fill(main.ROOFS.Front.WOOD)
	var narrow: Dictionary = main.ROOFS.new().bake(Rect2i(0, 0, 5, 9), front, -1, main.ROOFS.Mat.SHINGLE)
	check(not narrow["along_x"] and narrow["mid"] == 2.5 * main.TILE, "più alta che larga: il colmo da nord a sud, a metà")
	check(main.ROOFS.lift(narrow, Vector2(2.5 * main.TILE, 0)) == main.ROOFS.FACADE + narrow["rise"]
		and main.ROOFS.lift(narrow, Vector2(0, 0)) < main.ROOFS.lift(narrow, Vector2(main.TILE, 0)), "il colmo in alto, la gronda in basso")
	var cold: float = main.temperature_at(Vector2i(12, 12))
	check(is_equal_approx(cold, lerpf(out, main.ROOM_TEMP, 0.5)), "sotto il tetto a metà strada verso ROOM_TEMP")

	# il focolare va addossato a un muro: girato di un quarto ha il muro in comune alle spalle
	var hearth := Vector2i(15, 12)
	check(not main.piece_fits(hearth, [B.HEARTH, R.STONE, 0]), "il focolare senza un muro alle spalle non sta")
	check(main.piece_fits(hearth, [B.HEARTH, R.STONE, 1]), "con il muro alle spalle sì")
	main.order = main.Order.BUILD
	main.build_kind = B.HEARTH
	main.build_res = R.STONE
	main.build_turn = 0
	main.mark(Rect2i(hearth, Vector2i.ONE))
	check(main.furniture_draft.is_empty(), "nel progetto non entra se non ha il muro dietro")
	main.build_turn = 1
	main.mark(Rect2i(hearth, Vector2i.ONE))
	check(main.furniture_draft.get(hearth) == [B.HEARTH, R.STONE, 1], "girato verso il muro entra nel progetto")
	main.furniture_draft.clear()
	main.order = main.Order.NONE
	main.furniture[hearth] = [B.HEARTH, R.STONE, 1]
	check(is_equal_approx(main.temperature_at(Vector2i(12, 12)), cold + main.HEAT[B.HEARTH]), "il focolare scalda la sua stanza")
	check(is_equal_approx(main.temperature_at(Vector2i(19, 12)), cold + main.HEAT[B.HEARTH] * main.THROUGH_WALL),
		"e passa metà del calore alla stanza dietro il muro di legno")
	check(main.heat_lines(bedroom).has("Hearth of %s: +6 °C" % kitchen.name), "il cartello della camera dice da dove viene il calore")
	check(main.roof_snow(main.roofed[Vector2i(12, 12)]) < main.roof_snow(main.roofed[Vector2i(19, 12)]),
		"sul tetto della stanza più calda la neve si scioglie prima")
	main.open_room(bedroom)
	check(main.get_node("HUD/RoomPopup/Box/Comfort").tooltip_text.contains("Hearth of"), "nel suggerimento del cartello")
	main.room_popup.hide()

	# il focolare fa da fuoco da campo: la cucina, le ricette, lo svago
	check(main.room_meets(kitchen, main.RoomKind.KITCHEN), "col focolare la stanza può essere una cucina")
	kitchen.kind = main.RoomKind.KITCHEN
	check(main.kitchen_fires() == [hearth], "il focolare è un fuoco della cucina")
	main.open_craft(hearth)
	var rows: Array = main.get_node("HUD/CraftPopup/Box/List").get_children()
	check(rows.size() > 1 and main.get_node("HUD/CraftPopup/Box/Head/Title").text == "Hearth", "al focolare si cucina come al fuoco da campo")
	main.craft_popup.hide()
	var cook = main.colonists[0]
	cook.pos = main.center(Vector2i(12, 15))
	main.drop(R.VEG, Vector2i(12, 17), 4)
	main.keep[R.MEAL] = 10
	check(main.try_cook(cook) and cook.target == hearth, "il cuoco cucina al focolare")
	main.quit_job(cook)
	main.items[R.VEG].clear()
	main.fresh.clear()

	# affumicare: al fuoco da campo più svelti che al focolare
	main.keep[R.MEAL] = 0
	main.keep[R.SMOKED_MEAT] = 5
	main.drop(R.MEAT, Vector2i(12, 17), 4)
	check(main.try_craft(cook) and cook.target == hearth, "si affumica al focolare")
	var at_hearth: float = cook.work_total
	main.quit_job(cook)
	main.furniture.erase(hearth)
	var fire := Vector2i(12, 12)
	main.furniture[fire] = [B.CAMPFIRE, R.WOOD, 0]
	check(main.try_craft(cook) and cook.target == fire, "e al fuoco da campo")
	check(is_equal_approx(cook.work_total, at_hearth * main.SMOKE_TIME), "al fuoco da campo il fumo resta: più svelto")
	main.quit_job(cook)
	main.keep[R.SMOKED_MEAT] = 0
	for res in [R.MEAT, R.VEG]:
		main.items[res].clear()
	main.fresh.clear()
	check(main.heat_through(fire) == null and main.heat_sources(bedroom).is_empty(), "il fuoco da campo non passa i muri")

	# comignoli e fumo: lo sfiatatoio sopra il fuoco da campo, il comignolo sul muro dietro il focolare
	check(main.chimney_of(fire) == [fire, main.Chimney.VENT], "fuoco da campo sotto il tetto: lo sfiatatoio")
	main.furniture.erase(fire)
	main.furniture[hearth] = [B.HEARTH, R.STONE, 1]
	var wall: Vector2i = hearth + Vector2i.RIGHT
	check(main.chimney_of(hearth) == [wall, main.Chimney.STONE], "il comignolo sul muro alle spalle del focolare")
	check(main.smoke_at(hearth).y < wall.y * main.TILE, "il fumo esce dalla cima del comignolo")
	sky._process(0.0)
	check(sky.fires.has(hearth) and sky.fires[hearth].size() == 2 and sky.fires[hearth][0].position == main.smoke_at(hearth),
		"il focolare fuma dal comignolo e ha le braci")
	check(not sky.fires[hearth][1].visible, "sotto il tetto le braci non si vedono")
	main.roofs_shown = false
	sky._process(0.0)
	check(sky.fires[hearth][1].visible and sky.fires[hearth][0].position == main.center(hearth) + Vector2(0, -6),
		"coi tetti tolti si vede il fuoco, e il fumo sale da lui")
	main.roofs_shown = true
	check(main.fire_use(hearth) == 0 and is_equal_approx(sky.fires[hearth][0].modulate.a, sky.IDLE_SMOKE), "acceso e basta: fumo rado")
	var outside := Vector2i(20, 6)
	main.furniture[outside] = [B.CAMPFIRE, R.WOOD, 0]
	check(main.chimney_of(outside)[1] == main.Chimney.NONE, "all'aperto niente comignolo")
	main.furniture.erase(outside)
	sky._process(0.0)
	check(not sky.fires.has(outside), "fuoco abbattuto: niente più fumo")

	# il muro in comune di pietra: il calore non passa, e la pietra isola di più
	main.built[wall] = [B.WALL, R.STONE]
	check(main.heat_through(hearth) == null and main.heat_sources(bedroom).is_empty(), "attraverso la pietra il calore non passa")
	main.built[wall] = [B.WALL, R.WOOD]
	main.furniture.erase(hearth)

	# la fornace passa metà del calore attraverso il muro di legno alle spalle
	var furnace := Vector2i(17, 12)  # nella camera, contro il muro in comune (di legno) a sinistra
	main.furniture[furnace] = [B.FURNACE, R.STONE, 3]
	check(main.heat_through(furnace) == kitchen and is_equal_approx(main.temperature_at(Vector2i(12, 12)),
		cold + main.HEAT[B.FURNACE] * main.THROUGH_WALL), "la fornace scalda la stanza dietro il muro di legno")
	check(main.chimney_of(furnace) == [Vector2i(16, 12), main.Chimney.STONE], "e ha il suo comignolo sul muro")
	main.furniture.erase(furnace)

	for k in main.room_walls(bedroom):
		if main.built[k][0] == B.WALL:
			main.built[k] = [B.WALL, R.STONE]
	var walls: Dictionary = main.room_walls(bedroom)
	var doors: int = walls.keys().filter(func(k): return main.built[k][0] == B.DOOR).size()
	check(is_equal_approx(main.insulation(bedroom), ((walls.size() - doors) * 0.7 + doors * 0.5) / walls.size()),
		"di pietra isola di più: la media dei muri, la porta come il legno")
	var stone: float = main.temperature_at(Vector2i(19, 12))
	main.update_roofs()
	check(main.roofed[Vector2i(19, 12)].material == R.STONE, "muri di pietra, più della porta: tetto di coppi")
	check(stone > cold, "d'inverno la stanza di pietra è più calda di quella di legno")

	# magazzino e dispensa vanno verso STORE_TEMP: d'estate li tiene freschi
	main.clock = 1 + 1.5 * main.SEASON_DAYS  # mezzogiorno, a metà estate
	var lived: float = main.temperature_at(Vector2i(12, 12))
	kitchen.kind = main.RoomKind.WAREHOUSE
	main.update_stockpile()
	var store: float = main.temperature_at(Vector2i(12, 12))
	check(store < lived and is_equal_approx(store, lerpf(sky.temperature(), main.STORE_TEMP, main.insulation(kitchen))),
		"il magazzino va verso STORE_TEMP: più fresco")
	check(main.spoil_rate(Vector2i(12, 12)) < main.spoil_rate(Vector2i(4, 4)), "in magazzino d'estate il cibo dura di più")
	check(main.spoil_rate(Vector2i(4, 4)) > 1.0, "al sole d'estate più in fretta del ritmo pieno")
	kitchen.kind = main.RoomKind.NONE
	main.update_stockpile()

	# lente del calore: colori per malus, il conto col mouse sopra, la freccia del calore che passa; una lente alla volta
	main.clock = floorf(1 + 3.5 * main.SEASON_DAYS) + 0.25  # di nuovo a metà inverno
	main.furniture[hearth] = [B.HEARTH, R.STONE, 1]
	main.built[wall] = [B.WALL, R.WOOD]
	check(main.heat_color(-2.0) == main.FROST_COLOR and main.heat_color(20.0) == main.HEAT_SCALE[0]
		and main.heat_color(9.0) == main.HEAT_SCALE[1] and main.heat_color(5.0) == main.HEAT_SCALE[2],
		"i colori della lente: ghiaccio, caldo, fresco senza malus, un punto di freddo")
	var rooms_button: Button = main.get_node("HUD/Tools/Row/RoomsLens")
	var heat_button: Button = main.get_node("HUD/Tools/Row/HeatLens")
	rooms_button.button_pressed = true
	heat_button.button_pressed = true
	main._process(0.0)
	check(main.heat_lens.visible and not main.lens.visible and not rooms_button.button_pressed, "una lente alla volta")
	check(main.describe(Vector2i(19, 12)) == [bedroom.name, "\n".join(main.heat_lines(bedroom))], "col mouse sopra, il conto dei gradi")
	check(main.passage(hearth, main.furniture[hearth]) == [wall, bedroom, true], "dietro il focolare il muro di legno: passa")
	main.built[wall] = [B.WALL, R.STONE]
	check(main.passage(hearth, main.furniture[hearth]) == [wall, bedroom, false], "di pietra: bloccato (la ✕)")
	main.built[wall] = [B.WALL, R.WOOD]
	heat_button.button_pressed = false
	main._process(0.0)
	check(not main.heat_lens.visible, "spenta col suo tasto")
	main.order = main.Order.BUILD
	main.build_kind = B.HEARTH
	main._process(0.0)
	check(main.heat_lens.visible, "piazzando un focolare la lente si accende da sola")
	main.build_kind = B.BED
	main._process(0.0)
	check(not main.heat_lens.visible, "con un letto no")
	main.order = main.Order.NONE
	main.furniture.erase(hearth)

	# usura dei tetti: tegole smosse da riparare, i buchi lasciano entrare il tempo di fuori
	var spot := Vector2i(13, 12)
	var stamp: int = main.roof_stamp
	main.wear[spot] = 1.0 - 0.00001  # un'ora d'usura e si apre
	main.wear_roofs()
	check(main.roof_stamp != stamp, "si apre un buco: la neve e le pozzanghere ci entrano")
	check(main.holed(spot) and not main.sheltered(spot) and main.temperature_at(spot) == sky.temperature(),
		"sotto il buco si sta come fuori")
	check(main.spoil_rate(spot) == main.spoil_rate(Vector2i(4, 4)), "e il cibo ci marcisce come fuori")
	check(main.roof_repairs().has(spot) and main.job_list().contains("Repair roofs: 1"), "il buco è un lavoro: riparare")
	var mason = main.colonists[1]
	mason.pos = main.center(Vector2i(13, 16))
	for c in main.colonists:
		if c != mason:
			c.pos = main.center(Vector2i(2, 2))
			c.downed = true  # fermi: lavora solo lui
	main.drop(R.WOOD, Vector2i(14, 17), 3)
	var xp: int = mason.xp[main.Skill.CONSTRUCTION]
	for i in 600:
		main.tick(0.05)
		if not main.wear.has(spot):
			break
	check(not main.wear.has(spot) and main.items[R.WOOD].get(Vector2i(14, 17), 0) == 2 and mason.xp[main.Skill.CONSTRUCTION] == xp + 1,
		"riparato con una legna (scandole): l'esperienza da costruttore")
	check(main.sheltered(spot), "di nuovo al coperto")
	for c in main.colonists:
		c.downed = false
	main.items[R.WOOD].clear()
	# il temporale strappa i tetti e la cronaca lo dice
	sky.weather = sky.Weather.STORM
	sky.weather_strength = 1.0
	var notes: int = main.chronicle.size()
	for i in 50:
		main.wear_roofs()
	check(main.wear.values().any(func(w): return w >= main.STORM_DAMAGE[0]), "il temporale strappa delle caselle")
	check(main.chronicle.size() > notes and main.chronicle[main.chronicle.size() - 1].contains("the storm tore tiles off the roof"),
		"nella cronaca, una volta al giorno per stanza")
	check(main.chronicle.size() - notes <= main.rooms.size(), "non a ogni ora")
	sky.weather = sky.Weather.CLEAR
	sky.weather_strength = 0.0
	main.wear.clear()
	main.roof_stamp += 1

	# isolare: pelli alle pareti (fino a 3), la portiera alla porta, l'intonaco sui muri di legno
	var base: float = main.insulation(kitchen)
	check(not main.piece_fits(Vector2i(12, 12), [B.WALL_HIDES, R.HIDE, 0]), "le pelli vanno appese a un muro")
	for x in [11, 12, 13, 14]:
		main.furniture[Vector2i(x, 11)] = [B.WALL_HIDES, R.HIDE, 0]  # contro il muro in alto
	check(is_equal_approx(main.insulation(kitchen), base + 0.05 * 3), "pelli alle pareti: +5% ciascuna, al massimo 3")
	var door := Vector2i(13, 14)
	check(main.piece_fits(door + Vector2i.UP, [B.DOOR_CURTAIN, R.HIDE, 2]) and not main.piece_fits(Vector2i(12, 13), [B.DOOR_CURTAIN, R.HIDE, 2]),
		"la portiera va davanti alla porta")
	main.furniture[door + Vector2i.UP] = [B.DOOR_CURTAIN, R.HIDE, 2]
	check(is_equal_approx(main.insulation(kitchen), base + 0.05 * 3 + 0.1), "la portiera: +10%")
	for x in [11, 12, 13, 14]:
		main.furniture.erase(Vector2i(x, 11))
	main.furniture.erase(door + Vector2i.UP)
	var plank := Vector2i(12, 10)  # il muro in alto della cucina, di legno
	check(main.can_build(plank, B.PLASTER) and not main.can_build(Vector2i(12, 12), B.PLASTER), "si intonacano solo i muri di legno")
	main.blueprints[plank] = [B.PLASTER, R.STONE]
	main.build(plank)
	check(main.plastered.has(plank) and main.built[plank] == [B.WALL, R.WOOD] and main.room_walls(kitchen)[plank] == main.PLASTER_INSULATION,
		"intonacato: il muro resta di legno, ma isola di più")
	check(main.structure_src(plank, main.built[plank], [main.built]).position.y == main.PLASTER_ROW * main.TILE, "e diventa bianco")
	check(not main.can_build(plank, B.PLASTER), "una volta basta")
	main.plastered.erase(plank)

	# la stufa a olle passa tutto il calore, anche attraverso la pietra
	main.built[wall] = [B.WALL, R.STONE]
	main.furniture[hearth] = [B.TILED_STOVE, R.STONE, 1]
	check(main.heat_through(hearth) == bedroom and main.heat_sources(bedroom)[0][1] == main.HEAT[B.TILED_STOVE],
		"la stufa a olle scalda la stanza dietro il muro di pietra quanto la sua")
	main.furniture.erase(hearth)
	main.built[wall] = [B.WALL, R.WOOD]

	# il baldacchino: le tende scaldano chi ci dorme
	var sleeper = main.colonists[2]
	main.furniture[Vector2i(18, 11)] = [B.CANOPY_BED, R.WOOD, 0]
	sleeper.pos = main.center(Vector2i(18, 11))
	sleeper.job = main.Job.SLEEP
	check(main.bed_warmth(sleeper) == main.BED_WARMTH[B.CANOPY_BED], "nel baldacchino 4 gradi in più")
	sleeper.job = main.Job.NONE
	main.furniture.erase(Vector2i(18, 11))
	check(main.tech_for("builds", B.TAPESTRY) == main.Tech.LOOM and main.tech_for("builds", B.TILED_STOVE) == main.Tech.TILED_STOVE
		and main.tech_for("builds", B.WALL_HIDES) == main.Tech.HUNTING and main.tech_for("builds", B.PLASTER) == main.Tech.MASONRY,
		"le ricerche: telaio, stufa a olle, caccia, muratura")

	# la ghiacciaia: una stanza di pietra con la fossa del ghiaccio, senza fuochi
	clear(Rect2i(8, 18, 12, 9))
	wall_room(Rect2i(10, 20, 7, 6), Vector2i(12, 25), R.STONE)
	main.update_rooms()
	var ice_room = main.room_at(Vector2i(12, 22))
	check(not main.room_meets(ice_room, main.RoomKind.ICEHOUSE), "senza la fossa non è una ghiacciaia")
	var pit := Vector2i(11, 21)
	main.furniture[pit] = [B.ICE_PIT, R.STONE, 0]
	check(main.room_meets(ice_room, main.RoomKind.ICEHOUSE), "di pietra, con la fossa: può esserlo")
	main.furniture[Vector2i(15, 23)] = [B.CAMPFIRE, R.WOOD, 0]
	check(not main.room_meets(ice_room, main.RoomKind.ICEHOUSE), "con un fuoco dentro no")
	main.furniture.erase(Vector2i(15, 23))
	main.built[Vector2i(16, 22)] = [B.WALL, R.WOOD]
	check(not main.room_meets(ice_room, main.RoomKind.ICEHOUSE), "con un muro di legno no")
	main.built[Vector2i(16, 22)] = [B.WALL, R.STONE]
	ice_room.kind = main.RoomKind.ICEHOUSE
	main.update_stockpile()
	var pits: Dictionary = main.pit_cells()
	check(pits.size() == 4 and main.dest_cells(R.ICE).all(func(k): return pits.has(k)) and main.dest_cells(R.ICE).size() == 4,
		"il ghiaccio va solo nelle fosse")
	check(main.dest_cells(R.VEG).has(Vector2i(14, 22)) and not main.dest_cells(R.VEG).has(pit), "il cibo nel resto della stanza")
	main.clock = floorf(1 + 1.5 * main.SEASON_DAYS) + 0.5  # mezzogiorno, a metà estate
	var dry: float = main.temperature_at(Vector2i(14, 22))
	main.items[R.ICE][pit] = 20
	var iced: float = main.temperature_at(Vector2i(14, 22))
	check(is_equal_approx(iced, lerpf(sky.temperature(), main.ICE_TEMP, main.insulation(ice_room))) and iced < dry,
		"col ghiaccio la stanza va verso 0 °C")
	check(main.spoil_rate(Vector2i(14, 22)) < main.spoil_rate(Vector2i(4, 4)) / 6.0, "il cibo ci marcisce molto più piano che fuori")
	for i in 24:
		main.melt_ice()
	var melted: int = 20 - main.room_ice(ice_room)
	check(melted > 0 and melted < 20, "d'estate il ghiaccio si scioglie piano (%d blocchi in un giorno)" % melted)
	main.wear[Vector2i(13, 22)] = 1.5
	var before: int = main.room_ice(ice_room)
	for i in 24:
		main.melt_ice()
	check(before - main.room_ice(ice_room) > melted, "con un buco nel tetto si scioglie prima")
	main.wear.clear()

	# tagliare il ghiaccio: sull'acqua gelata segnata, finché nelle fosse c'è posto
	var hole: Vector2i = main.water.keys()[0]
	main.order = main.Order.ICE
	main.mark(Rect2i(hole, Vector2i.ONE))
	main.order = main.Order.NONE
	check(main.ice_marks.has(hole) and main.ice_ready().is_empty(), "segnata, ma l'acqua non è gelata")
	sky.frozen = true
	main.freeze_water(true)
	check(main.ice_ready() == [hole] and main.job_list().contains("Cut ice: 1 spots"), "gelata: si taglia")
	main.items[R.ICE][pit] = main.STACK_MAX[R.ICE]
	for k in pits:
		main.items[R.ICE][k] = main.STACK_MAX[R.ICE]
	check(main.ice_ready().is_empty(), "le fosse sono piene: niente taglio")
	for k in pits:
		main.items[R.ICE].erase(k)
	var cutter = main.colonists[0]
	cutter.pos = main.center(hole)
	for c in main.colonists:
		c.downed = c != cutter
	for i in 3000:
		main.tick(0.05)
		if main.total(R.ICE) > 0 and cutter.job == main.Job.HAUL:
			break
	check(main.total(R.ICE) > 0, "il ghiaccio tagliato")
	for i in 6000:
		main.tick(0.05)
		if main.room_ice(ice_room) > 0:
			break
	check(main.room_ice(ice_room) > 0, "portato nella fossa della ghiacciaia")
	for c in main.colonists:
		c.downed = false
	sky.frozen = false
	main.freeze_water(false)
	main.ice_marks.clear()

	# d'estate la fontana rinfresca la sua stanza
	main.furniture[Vector2i(13, 21)] = [B.FOUNTAIN, R.STONE, 0]
	ice_room.kind = main.RoomKind.NONE
	main.update_stockpile()
	check(main.heat_sources(ice_room).any(func(src): return src[1] == -main.FOUNTAIN_COOL), "la fontana: −3 °C quando fa caldo")
	check(main.heat_lines(ice_room).has("Fountain: −3 °C"), "e il cartello lo dice")
	main.furniture.erase(Vector2i(13, 21))

	# incendio: le scandole bruciano e il fuoco passa accanto, i coppi no; i coloni lo spengono coi secchi
	main.update_roofs()
	var roof_cell := Vector2i(12, 11)  # sul tetto della cucina, di legno
	check(main.flammable(roof_cell), "le scandole possono bruciare")
	check(not main.flammable(Vector2i(13, 22)), "i coppi della ghiacciaia no")
	var notes_before: int = main.chronicle.size()
	main.ignite(roof_cell)
	check(main.burning.has(roof_cell) and main.chronicle[main.chronicle.size() - 1].contains("is burning"), "prende fuoco: nella cronaca")
	check(main.job_list().contains("Put out the fire: 1 tiles"), "spegnere è un lavoro")
	var spread_ok := false
	for i in 200:
		main.burn(main.DAY_LENGTH / 24.0 / 10.0)  # un decimo d'ora alla volta
		if main.burning.size() > 1:
			spread_ok = true
			break
	check(spread_ok, "il fuoco passa alle scandole accanto")
	for i in 2000:  # finché non ha bruciato tutto quello che poteva: quanto, lo decide il caso
		main.burn(main.DAY_LENGTH / 24.0 / 10.0)
		if main.burning.is_empty():
			break
	check(main.burning.is_empty() and main.holed(roof_cell), "senza nessuno a spegnerlo, il tetto brucia: resta un buco")
	check(main.chronicle[main.chronicle.size() - 1].contains("the fire is out"), "la cronaca dice quando è finito")
	main.wear.clear()
	main.roof_stamp += 1
	# coi secchi: i coloni mollano il lavoro, vanno all'acqua e tornano a spegnerlo
	var fireman = main.colonists[0]
	for c in main.colonists:
		c.pos = main.center(Vector2i(12, 15))
		c.path.clear()
	main.drop(R.WOOD, Vector2i(20, 17), 5)
	main.chop_marks[main.trees.keys()[0]] = true  # chi lavora molla tutto
	for i in 50:
		main.tick(0.05)
	main.ignite(roof_cell)
	check(main.colonists.all(func(c): return c.job not in main.WORK_JOBS), "al fuoco si molla il lavoro")
	var bucket_seen := false
	for i in 20000:
		main.tick(0.05)
		bucket_seen = bucket_seen or fireman.bucket
		if main.burning.is_empty():
			break
	check(bucket_seen and main.burning.is_empty() and not main.holed(roof_cell), "spento coi secchi prima che bruci tutto")
	main.chop_marks.clear()
	main.items[R.WOOD].clear()
	main.wear.clear()
	main.roof_stamp += 1
	check(main.chronicle.size() > notes_before, "tutto nella cronaca")

	# il suggerimento del pulsante dice quanto scalda
	var tip: Control = main.build_tip(B.HEARTH)
	var texts: Array = tip.get_children().filter(func(n): return n is Label).map(func(l): return l.text)
	check(texts.has("+12 °C in the room, +6 °C behind a wooden wall"), "il pulsante del focolare dice quanto scalda")
	tip.free()
	check(main.unlocked("builds", B.HEARTH) and main.tech_for("builds", B.HEARTH) == main.Tech.MASONRY, "il focolare viene con la Muratura")
	sky.climate = false
	print("OK: focolare, calore nei muri, isolamento, lente, tetti, usura, ghiacciaia, incendio")
	quit()


# toglie dal rettangolo alberi, rocce, acqua, cespugli, erbacce e mucchi
func clear(rect: Rect2i) -> void:
	for cell in main.cells_in(rect):
		main.trees.erase(cell)
		main.bushes.erase(cell)
		main.flax.erase(cell)
		main.weeds.erase(cell)
		main.water.erase(cell)
		main.rocks.erase(cell)
		main.ores.erase(cell)
		main.boulders.erase(cell)
		main.astar.set_point_solid(cell, false)
		main.astar.set_point_weight_scale(cell, 1.0)
		for res in main.items:
			main.items[res].erase(cell)


# muri del materiale `res` sul bordo del rettangolo, con una porta in `door`
func wall_room(rect: Rect2i, door: Vector2i, res) -> Array:
	var cells := []
	for cell in main.cells_in(rect):
		if cell.x in [rect.position.x, rect.end.x - 1] or cell.y in [rect.position.y, rect.end.y - 1]:
			main.built[cell] = [main.Build.DOOR if cell == door else main.Build.WALL, main.Res.WOOD if cell == door else res]
			if cell != door:
				main.astar.set_point_solid(cell)
			cells.append(cell)
	return cells


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
