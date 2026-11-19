# Esegui: godot --headless --path . -s tests/test_narrator.gd
# Il narratore (GDD 4.6): la tabella degli eventi, il tiro di mezzanotte (una fetta per evento, al più uno al giorno,
# le fette strette quando insieme passano l'intero), l'ora dell'evento, la pausa, chi è in corso, il salvataggio.
# Gli eventi uno per uno: i viandanti in test_newcomers, l'erudito in test_research
extends SceneTree

var main


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(5)
	main = load("res://main.tscn").instantiate()
	main.game_start = false
	main.settings_file = ""
	root.add_child(main)
	await process_frame
	main.needs_rate = 0.0
	main.animals.clear()  # niente lupi né prede: i branchi li mandano le prove
	var N = main.narrator
	var E = N.Event

	# la tabella: ogni riga col suo tipo, quanto spesso, la sua ora e le sue funzioni
	for e in N.EVENTS:
		var row: Dictionary = N.EVENTS[e]
		var label: String = E.keys()[e]
		check(row.has("kind") and row.has("hour") and row["hour"] >= 0 and row["hour"] < 24 and N.has_method(row["do"]),
			"la riga di %s" % label)
		check(row["every"] is float or main.has_method(row["every"]), "ogni quanto: %s" % label)
		check((not row.has("can") or N.has_method(row["can"])) and (not row.has("busy") or N.has_method(row["busy"])),
			"le sue funzioni: %s" % label)

	# il primo giorno non può capitare niente: i lupi dal quinto (il giorno 4, contato da 0), l'erudito dal giorno 5 (con
	# una locanda), i viandanti dal 10
	main.today = 0
	check(N.pick() == -1, "il primo giorno niente")
	main.today = 3
	check(not N.can_happen(E.WOLVES), "i lupi non prima del quinto giorno")
	main.today = 4
	check(N.can_happen(E.WOLVES), "dal quinto sì")
	var inn = main.Room.new()
	inn.kind = main.RoomKind.INN
	main.rooms.append(inn)
	check(not N.can_happen(E.SCHOLAR), "l'erudito non prima del giorno 5")
	# le fette: dopo P giorni di pausa (o di tregua) senza tiri, una fetta di 1 / (giorni - P + 1) dà in media quei giorni.
	# Dal giorno 10, con la locanda: l'erudito 1/6 (10 giorni, 5 di pausa), i viandanti 1/26 (30 giorni, 5 di pausa), i
	# lupi 1/2 (4 giorni, 3 di tregua); un tiro solo, al più un evento, ognuno quanto la sua fetta
	main.today = 10
	check(is_equal_approx(N.chance(E.SCHOLAR), 1.0 / 6.0) and is_equal_approx(N.chance(E.WANDERERS), 1.0 / 26.0)
		and is_equal_approx(N.chance(E.WOLVES), 0.5), "le fette")
	var counts := tally(20000)
	check(fair(counts, 20000, 0.015), "il tiro: %s" % str(counts))

	# troppe fette: si stringono in proporzione, e qualcosa capita sempre. Con 13 statue (104 di splendore) un viandante
	# ogni 5 giorni scarsi: la sua fetta da sola è 1
	var statues := []
	for i in 13:
		statues.append(Vector2i(i + 2, 2))
		main.furniture[statues[-1]] = [main.Build.STATUE, main.Res.STONE, 0]
	check(main.wander_wait() < 5.0 and is_equal_approx(N.chance(E.WANDERERS), 1.0), "un viandante ogni 5 giorni scarsi")
	counts = tally(12000)
	check(counts[-1] == 0 and fair(counts, 12000, 0.02), "strette: %s" % str(counts))
	for k in statues:
		main.furniture.erase(k)

	# l'evento scelto a mezzanotte aspetta la sua ora: l'erudito alle 9
	main.scholar_until = -1.0
	N.planned = E.SCHOLAR
	main.hour = main.today * 24 + 8
	N.new_hour()
	check(N.planned == E.SCHOLAR and main.scholar_until < 0, "alle 8 non ancora")
	main.hour += 1
	N.new_hour()
	check(N.planned == -1 and main.scholar_until > 0 and N.last[E.SCHOLAR] == main.today
		and main.chronicle[-1].contains("wandering scholar"), "alle 9 arriva, nella cronaca")

	# in corso: intanto non ne viene un altro, e a mezzanotte la pausa riparte da quel giorno
	check(N.busy(E.SCHOLAR) and not N.can_happen(E.SCHOLAR), "l'erudito è alla locanda: non ne viene un altro")
	main.today += 1
	N.new_day()
	check(N.last[E.SCHOLAR] == main.today and N.planned != E.SCHOLAR, "la pausa riparte da oggi")
	main.scholar_until = -1.0
	check(not N.can_happen(E.SCHOLAR), "partito, c'è la pausa")
	main.today += 5
	check(N.can_happen(E.SCHOLAR), "passata la pausa può tornare")

	# scelto, ma alla sua ora non si può più (la locanda abbattuta): quel giorno niente
	N.last.erase(E.SCHOLAR)
	N.planned = E.SCHOLAR
	main.rooms.erase(inn)
	main.hour = main.today * 24 + 9
	N.new_hour()
	check(N.planned == -1 and main.scholar_until < 0 and not N.last.has(E.SCHOLAR), "senza locanda non passa")

	# --- Le minacce ---
	# il branco: dal bordo, 2-3 lupi (uno in più ogni 5 coloni), nella tregua
	main.rooms.append(inn)
	main.today = 20
	N.bad.clear()
	check(N.happen(E.WOLVES), "arriva un branco")
	var pack: Array = main.animals.filter(func(a): return main.hostile(a))
	check(pack.size() >= main.PACK[0] and pack.size() <= main.PACK[1] and main.colony_size() < main.PACK_GROW,
		"%d lupi, con %d coloni" % [pack.size(), main.colony_size()])
	check(N.bad == [main.today] and not N.calm(main.today + 2) and N.calm(main.today + 3) and N.calm(main.today - 3), "la tregua")
	# poi niente minacce: per la tregua, e finché i lupi sono sulla mappa
	main.today += 3
	check(not N.can_happen(E.WOLVES), "i lupi sono ancora qui")
	main.animals.clear()
	check(N.can_happen(E.WOLVES), "se ne sono andati, passata la tregua")
	main.today -= 1
	check(not N.can_happen(E.WOLVES), "nella tregua no")
	main.today += 1
	main.colonists[1].downed = true
	check(not N.can_happen(E.WOLVES) and N.can_happen(E.SCHOLAR), "con un colono a terra niente minacce (le visite sì)")
	main.colonists[1].downed = false
	# la tregua di ieri l'altro passa: a mezzanotte si dimentica
	N.new_day()
	check(N.bad.is_empty(), "a mezzanotte la tregua passata si toglie")
	N.planned = -1
	# con più coloni il branco è più grosso: con 10, due lupi in più
	var people: int = main.colonists.size()
	while main.colony_size() < 10:
		main.colonists.append(main.colonists[0])
	main.spawn_pack()
	pack = main.animals.filter(func(a): return main.hostile(a))
	check(pack.size() >= main.PACK[0] + 2 and pack.size() <= main.PACK[1] + 2, "con 10 coloni %d lupi" % pack.size())
	main.colonists.resize(people)
	main.animals.clear()

	# l'ondata di freddo la decide il meteo, fuori dalla tregua, e la fa partire
	var sky = main.atmosphere
	main.clock = floorf(1 + 1.5 * main.SEASON_DAYS + main.YEAR_DAYS / 2.0)  # metà inverno, a mezzanotte
	sky.waves.clear()
	N.bad = [int(main.clock) + 2]  # i giorni che il meteo decide (domani e dopo) sono nella tregua
	for i in 500:
		sky.waves_until = int(main.clock)
		sky.plan_ahead()
	check(sky.waves.is_empty(), "nella tregua niente ondate di freddo")
	N.bad.clear()
	for i in 500:
		sky.waves_until = int(main.clock)
		sky.plan_ahead()
		if not sky.waves.is_empty():
			break
	check(not sky.waves.is_empty() and N.bad == [int(sky.waves[0][0])], "fuori sì, e comincia la tregua")
	sky.waves.clear()
	N.bad.clear()

	# --- Le fortune ---
	var R = main.Res
	var mid: Vector2i = main.MAP_SIZE / 2
	var open: Array = main.cells_in(Rect2i(mid - Vector2i(3, 3), Vector2i(7, 7))).filter(
		func(k): return not main.astar.is_point_solid(k) and not main.water.has(k))
	# la colonia in difficoltà (il cibo in magazzino per meno di 3 giorni, o la felicità media sotto 40): fetta doppia
	main.today = 30
	for c in main.colonists:
		c.needs[main.Need.HAPPINESS] = 80.0
	main.stockpile = {open[0]: true}
	check(N.struggling() and is_equal_approx(N.chance(E.HERD), 2.0 / 26.0), "senza cibo: in difficoltà, la fetta doppia")
	main.add_item(R.MEAL, open[0], 100)
	check(not N.struggling() and is_equal_approx(N.chance(E.HERD), 1.0 / 26.0), "col cibo no")
	for c in main.colonists:
		c.needs[main.Need.HAPPINESS] = 30.0
	check(N.struggling(), "infelici sì")
	for c in main.colonists:
		c.needs[main.Need.HAPPINESS] = 80.0

	# raccolto abbondante: d'estate e d'autunno, con l'orto seminato; per 10 giorni i campi rendono la metà in più
	var field: Vector2i = open[1]
	var turnip = main.Crop.TURNIP
	main.sown[field] = turnip
	main.today = 10
	check(not N.can_happen(E.BUMPER), "di primavera no")
	main.today = 1 + main.SEASON_DAYS + 10
	check(N.can_happen(E.BUMPER), "d'estate sì")
	var plain: int = main.crop_yield(field, turnip)
	check(N.happen(E.BUMPER) and is_equal_approx(main.bumper_until, main.clock + 10.0), "per 10 giorni")
	var rich: int = main.crop_yield(field, turnip)
	check(rich > plain and absi(rich - roundi(plain * 1.5)) <= 1, "la metà in più: %d invece di %d" % [rich, plain])
	check(main.chronicle[-1].contains("bumper") and not N.can_happen(E.BUMPER), "nella cronaca; poi la pausa")
	main.bumper_until = -1.0
	main.sown.erase(field)

	# un branco di cervi, non d'inverno: 4-6 cervi da un bordo; dopo 2 giorni quelli che nessuno caccia se ne vanno
	main.today = main.YEAR_DAYS - 20
	check(not N.can_happen(E.HERD), "d'inverno niente cervi")
	main.today = 30
	main.animals.clear()
	check(N.happen(E.HERD), "arriva un branco di cervi")
	var deer: Array = main.animals.filter(func(a): return a.kind == main.Beast.DEER)
	check(deer.size() == main.animals.size() and deer.size() >= 4 and deer.size() <= 6
		and deer.all(func(a): return is_equal_approx(a.leave_at, main.clock + 2.0)), "%d cervi" % deer.size())
	check(main.chronicle[-1].contains("deer"), "nella cronaca")
	var hunted = deer[0]
	hunted.hunter = main.colonists[0]
	main.clock += 2.1
	for a in main.animals.duplicate():
		main.update_animal(a, 0.0)
	check(main.animals.size() == 1 and main.animals[0] == hunted, "dopo 2 giorni se ne vanno, tranne quello cacciato")
	hunted.hunter = null
	main.animals.clear()
	main.clock -= 2.1

	# l'ispirazione: a un colono adulto contento (felicità almeno 60), per un giorno lavora più in fretta
	for c in main.colonists:
		c.needs[main.Need.HAPPINESS] = 50.0
	check(not N.can_happen(E.INSPIRATION), "nessuno contento: niente")
	var glad = main.colonists[1]
	glad.needs[main.Need.HAPPINESS] = 70.0
	check(N.happen(E.INSPIRATION) and is_equal_approx(glad.conds.get(main.Cond.INSPIRED, 0.0), main.clock + 1.0)
		and is_equal_approx(main.COND_INFO[main.Cond.INSPIRED][1], 0.8), "il colono contento è ispirato: un giorno, lavora in fretta")
	check(main.chronicle[-1].contains(glad.first_name) and not N.can_happen(E.INSPIRATION), "nella cronaca; nessun altro")
	glad.conds.erase(main.Cond.INSPIRED)
	for c in main.colonists:
		c.needs[main.Need.HAPPINESS] = 80.0

	# il dono del pellegrino: con una sala del trono arriva dal bordo, ci lascia 20-40 monete (+5 autorità) e riparte
	check(not N.can_happen(E.PILGRIM), "senza sala del trono niente pellegrino")
	var hall = main.Room.new()
	hall.kind = main.RoomKind.THRONE_ROOM
	hall.cells = {open[2]: true, open[3]: true}
	main.rooms.append(hall)
	check(N.happen(E.PILGRIM), "con la sala del trono sì")
	var pilgrims: Array = main.guests.filter(func(g): return g.pilgrim)
	var pilgrim = pilgrims[0]
	check(pilgrims.size() == 1 and pilgrim.errand == main.Errand.VISIT and main.visitor(pilgrim) and not pilgrim.wanderer
		and main.census_role(pilgrim) == "Pilgrim" and main.doing(pilgrim) == "Bringing a gift to the crown", "arriva")
	check(N.busy(E.PILGRIM) and not N.can_happen(E.PILGRIM), "uno alla volta")
	var gold: int = main.items[R.GOLD].values().reduce(func(n, v): return n + v, 0)
	var power: float = main.authority
	main.events = false
	walk_until(func(): return pilgrim.errand == main.Errand.LEAVE, 8000)
	var given: int = main.items[R.GOLD].values().reduce(func(n, v): return n + v, 0) - gold
	check(given >= 20 and given <= 40 and main.authority >= power + 5.0 and hall.cells.has(main.cell_of(pilgrim.pos))
		and Array(main.chronicle).any(func(l): return l.contains("the pilgrim")), "al trono lascia %d monete" % given)
	walk_until(func(): return pilgrim not in main.guests, 8000)
	main.events = true
	main.rooms.erase(hall)

	# nei test il narratore tace (main.events)
	main.events = false
	check(range(500).all(func(i): return N.pick() == -1), "con events = false niente")
	N.new_day()
	check(N.planned == -1, "e a mezzanotte non sceglie niente")
	main.events = true

	# nel salvataggio, e ricaricato com'era; un salvataggio di prima del narratore non ha niente
	N.planned = E.WANDERERS
	N.last = {E.SCHOLAR: 7}
	N.bad = [9]
	var state: Dictionary = main.game_state()
	check(state["narrator"] == {"planned": E.WANDERERS, "last": {E.SCHOLAR: 7}, "bad": [9]}, "nel salvataggio: %s" % str(state["narrator"]))
	N.planned = -1
	N.last = {}
	N.bad = []
	N.restore(state["narrator"])
	check(N.planned == E.WANDERERS and N.last == {E.SCHOLAR: 7} and N.bad == [9], "ricaricato")
	var old = load("res://narrator.gd").new()
	old.restore({})
	check(old.planned == -1 and old.last.is_empty() and old.bad.is_empty(), "di prima del narratore: niente in attesa, nessuna pausa")
	old.free()

	print("OK: il narratore (la tabella, il tiro del giorno, l'ora, la pausa, le minacce e la tregua, le fortune, il salvataggio)")
	quit()


# `n` tiri del giorno: quante volte ogni evento (-1: niente)
func tally(n: int) -> Dictionary:
	var counts := {-1: 0}
	for e in main.narrator.EVENTS:
		counts[e] = 0
	for i in n:
		counts[main.narrator.pick()] += 1
	return counts


# ogni evento possibile è uscito quanto la sua fetta (stretta se le fette insieme passano l'intero), al più `tol` di
# scarto; gli altri mai
func fair(counts: Dictionary, n: int, tol: float) -> bool:
	var N = main.narrator
	var total := 0.0
	for e in N.EVENTS:
		if N.can_happen(e):
			total += N.chance(e)
	for e in N.EVENTS:
		var want: float = N.chance(e) / maxf(total, 1.0) if N.can_happen(e) else 0.0
		if absf(counts[e] / float(n) - want) > tol:
			return false
	return true


func walk_until(done: Callable, ticks: int) -> void:
	for i in ticks:
		if done.call():
			return
		main.tick(0.05)
	check(done.call(), "arrivato in tempo")


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
