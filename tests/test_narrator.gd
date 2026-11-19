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
	# lupi 1/2 (4 giorni, 3 di tregua); un tiro solo, al più un evento
	main.today = 10
	check(is_equal_approx(N.chance(E.SCHOLAR), 1.0 / 6.0) and is_equal_approx(N.chance(E.WANDERERS), 1.0 / 26.0)
		and is_equal_approx(N.chance(E.WOLVES), 0.5), "le fette")
	var counts := {-1: 0, E.WANDERERS: 0, E.SCHOLAR: 0, E.WOLVES: 0}
	for i in 20000:
		counts[N.pick()] += 1
	check(absf(counts[E.SCHOLAR] / 20000.0 - 1.0 / 6.0) < 0.015 and absf(counts[E.WANDERERS] / 20000.0 - 1.0 / 26.0) < 0.007
		and absf(counts[E.WOLVES] / 20000.0 - 0.5) < 0.02, "il tiro: %s" % str(counts))

	# troppe fette: si stringono in proporzione, e qualcosa capita sempre. Con 13 statue (104 di splendore) un viandante
	# ogni 5 giorni scarsi: la sua fetta è 1, con quelle dell'erudito e dei lupi 1 + 1/6 + 1/2
	var statues := []
	for i in 13:
		statues.append(Vector2i(i + 2, 2))
		main.furniture[statues[-1]] = [main.Build.STATUE, main.Res.STONE, 0]
	check(main.wander_wait() < 5.0 and is_equal_approx(N.chance(E.WANDERERS), 1.0), "un viandante ogni 5 giorni scarsi")
	counts = {-1: 0, E.WANDERERS: 0, E.SCHOLAR: 0, E.WOLVES: 0}
	for i in 12000:
		counts[N.pick()] += 1
	check(counts[-1] == 0 and absf(counts[E.WANDERERS] / 12000.0 - 0.6) < 0.02 and absf(counts[E.WOLVES] / 12000.0 - 0.3) < 0.02,
		"strette: %s" % str(counts))
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

	print("OK: il narratore (la tabella, il tiro del giorno, l'ora, la pausa, le minacce e la tregua, il salvataggio)")
	quit()


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
