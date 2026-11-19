# Il narratore (GDD 4.6): ogni giorno, a mezzanotte, sceglie al più un evento tra quelli possibili quel giorno, con un
# tiro solo. Ogni evento ha una fetta grande quanto è frequente (vedi chance): così ognuno tiene il suo ritmo, ma due
# eventi non vengono mai lo stesso giorno; se le fette insieme passano l'intero, si stringono in proporzione. L'evento
# scelto avviene alla sua ora, se allora si può ancora (vedi can_happen); se no quel giorno non succede niente.
# Il respiro: tra una minaccia o una sfortuna e la successiva almeno TRUCE giorni (la tregua), anche con l'ondata di
# freddo, che decide il meteo (vedi calm); niente minacce mentre un colono è a terra o i lupi sono sulla mappa. Quando
# la colonia è in difficoltà (vedi struggling) le fortune hanno la fetta BOON_HELP volte più grande.
# Figlio di main, come atmosphere.gd: legge da lì lo stato della colonia, e gli effetti li fa fare a main.
extends Node

enum Kind { THREAT, VISIT, BOON, BANE }  # minaccia, visita, fortuna, sfortuna
const BAD := [Kind.THREAT, Kind.BANE]  # quelle della tregua
const TRUCE := 3     # giorni almeno tra una minaccia (o sfortuna) e la successiva
const BOON_HELP := 2.0
const STRUGGLE_FOOD := 3.0   # in difficoltà: il cibo in magazzino basta per meno giorni (main.FOOD_DROP a testa)
const STRUGGLE_HAPPY := 40.0  # o la felicità media è sotto
const SUMMER := 1    # in main.SEASONS
const AUTUMN := 2
enum Event { WANDERERS, SCHOLAR, WOLVES, BUMPER, HERD, INSPIRATION, PILGRIM, RATS, THIEF, FEVER }
# Gli eventi, una riga per evento.
# "kind": Kind. "from": giorno da cui può capitare, contato da 0 come main.today. "every": giorni in media tra uno e
# l'altro, pausa (o tregua) compresa: un numero, o il nome di una funzione (di questo script, se no di main) quando
# dipende dallo stato della colonia. "pause": giorni almeno tra uno e l'altro, contati dall'ultimo giorno in cui c'era.
# "hour": l'ora del giorno in cui avviene. "can": funzione di questo script, se serve: quando è possibile, oltre a
# "from" e "pause". "busy": funzione di questo script, vera finché è in corso: intanto non ne viene un altro e la pausa
# riparte ogni giorno. "do": l'effetto, una funzione di questo script (la cronaca la scrive main). I testi sono nel .po,
# come tutti gli altri
const EVENTS := {
	# GDD 4.2.1: uno alla volta, non con Porte chiuse; più spesso con lo splendore, meno con tanti coloni (wander_wait)
	Event.WANDERERS: {"kind": Kind.VISIT, "from": 10, "every": "wander_wait", "pause": 5.0, "hour": 10,
		"can": "wanderers_can", "busy": "wanderers_here", "do": "wanderers_come"},
	# GDD 4.7.2: con una locanda, per un giorno; vende 1-2 libri (vedi main.scholar_arrives)
	Event.SCHOLAR: {"kind": Kind.VISIT, "from": 5, "every": 10.0, "pause": 5.0, "hour": 9,
		"can": "scholar_can", "busy": "scholar_here", "do": "scholar_comes"},
	# GDD 4.4.3: dal quinto giorno, a mezzanotte; 2-3 lupi, uno in più ogni main.PACK_GROW coloni (vedi main.spawn_pack)
	Event.WOLVES: {"kind": Kind.THREAT, "from": 4, "every": 4.0, "hour": 0, "can": "threat_can", "do": "wolves_come"},
	# le fortune (main.BUMPER e seguenti): raccolto abbondante d'estate e d'autunno, con l'orto seminato
	Event.BUMPER: {"kind": Kind.BOON, "every": 40.0, "pause": 30.0, "hour": 7, "can": "bumper_can",
		"do": "bumper_comes"},
	# un branco di cervi, non d'inverno
	Event.HERD: {"kind": Kind.BOON, "every": 25.0, "hour": 8, "can": "herd_can", "do": "herd_comes"},
	# l'ispirazione di un colono adulto contento
	Event.INSPIRATION: {"kind": Kind.BOON, "every": 15.0, "hour": 8, "can": "inspiration_can",
		"do": "inspiration_comes"},
	# il pellegrino, con una sala del trono: uno alla volta
	Event.PILGRIM: {"kind": Kind.BOON, "every": 30.0, "hour": 11, "can": "pilgrim_can", "busy": "pilgrim_here",
		"do": "pilgrim_comes"},
	# le sfortune (main.RATS_FROM e seguenti): i topi nel magazzino con più cibo crudo
	Event.RATS: {"kind": Kind.BANE, "every": 25.0, "pause": 15.0, "hour": 3, "can": "rats_can", "do": "rats_come"},
	# il ladro di notte, dal giorno 15, con le monete in magazzino
	Event.THIEF: {"kind": Kind.BANE, "from": 15, "every": 30.0, "hour": 2, "can": "thief_can", "do": "thief_comes"},
	# la febbre, dal giorno 10; d'inverno il doppio delle volte (vedi fever_every)
	Event.FEVER: {"kind": Kind.BANE, "from": 10, "every": "fever_every", "hour": 7, "can": "fever_can",
		"do": "fever_comes"},
}
const FEVER_EVERY := 20.0
const FEVER_WINTER := 10.0
const SAVED := ["planned", "last", "bad"]

@onready var main = get_parent()
var planned := -1   # l'Event di oggi, scelto a mezzanotte, che aspetta la sua ora; -1: niente
var last := {}      # Event -> l'ultimo giorno (main.today) in cui c'era: la pausa parte da lì
var bad := []       # i giorni di minacce e sfortune recenti e delle ondate di freddo già decise: la tregua (vedi calm)


# A mezzanotte (main.new_day): chi è ancora in corso fa ripartire la sua pausa, poi si sceglie l'evento di oggi
func new_day() -> void:
	bad = bad.filter(func(day): return day > main.today - TRUCE)
	for e in EVENTS:
		if busy(e):
			last[e] = main.today
	planned = pick()


# A ogni ora (main.new_hour): l'evento di oggi, venuta la sua ora
func new_hour() -> void:
	if planned < 0 or main.hour % 24 < EVENTS[planned]["hour"]:
		return
	var e := planned
	planned = -1
	happen(e)


# Il tiro del giorno: tra gli eventi possibili, ognuno con la sua fetta (vedi chance), uno o nessuno. -1: nessuno, e
# sempre nei test (main.events)
func pick() -> int:
	if not main.events:
		return -1
	var slices := {}
	var total := 0.0
	for e in EVENTS:
		if can_happen(e):
			slices[e] = chance(e)
			total += slices[e]
	var roll := randf() * maxf(total, 1.0)
	for e in slices:
		roll -= slices[e]
		if roll < 0.0:
			return e
	return -1


# La fetta di `e` nel tiro di un giorno in cui è possibile. Dopo uno, per `p` giorni di pausa (o di tregua) non si tira;
# poi con una fetta `f` ogni giorno ne passano in media 1 / f - 1 prima del prossimo: perché in tutto siano i suoi
# giorni in media, f = 1 / (giorni - p + 1). Le fortune, con la colonia in difficoltà, BOON_HELP volte tanto
func chance(e: int) -> float:
	var p: float = EVENTS[e].get("pause", 0.0)
	if EVENTS[e]["kind"] in BAD:
		p = maxf(p, TRUCE)
	var f := 1.0 / maxf(every(e) - p + 1.0, 1.0)
	return f * BOON_HELP if EVENTS[e]["kind"] == Kind.BOON and struggling() else f


# la colonia è in difficoltà: il cibo in magazzino basta per meno di STRUGGLE_FOOD giorni, o la felicità media è sotto
# STRUGGLE_HAPPY
func struggling() -> bool:
	var people: Array = main.colonists
	if people.is_empty():
		return false
	var food := 0.0
	for res in main.FOOD:
		food += main.stored(res) * main.FOOD[res]
	var happy: float = people.reduce(func(n, c): return n + c.needs[main.Need.HAPPINESS], 0.0) / people.size()
	return food < people.size() * main.FOOD_DROP * STRUGGLE_FOOD or happy < STRUGGLE_HAPPY


# giorni in media tra un `e` e l'altro, adesso
func every(e: int) -> float:
	var days = EVENTS[e]["every"]
	if days is String:
		return call(days) if has_method(days) else main.call(days)
	return float(days)


# `e` può capitare oggi: dal suo giorno, non in corso, passata la pausa (e la tregua), e quando lo dice la sua "can"
func can_happen(e: int) -> bool:
	var row: Dictionary = EVENTS[e]
	if main.today < row.get("from", 0) or busy(e) or (row["kind"] in BAD and not calm(main.today)):
		return false
	if last.has(e) and main.today - last[e] < row.get("pause", 0.0):
		return false
	return not row.has("can") or call(row["can"])


func busy(e: int) -> bool:
	return EVENTS[e].has("busy") and call(EVENTS[e]["busy"])


# `e` adesso, se si può: l'effetto, e la pausa parte da oggi. false se non si può
func happen(e: int) -> bool:
	if not can_happen(e):
		return false
	call(EVENTS[e]["do"])
	last[e] = main.today
	if EVENTS[e]["kind"] in BAD:
		bad.append(main.today)
	return true


# il giorno `day` è fuori dalla tregua: almeno TRUCE giorni da ogni minaccia o sfortuna, passata o già decisa (le ondate
# di freddo il meteo le decide prima, vedi atmosphere.plan_ahead)
func calm(day: float) -> bool:
	return bad.all(func(b): return absf(day - b) >= TRUCE)


# il meteo ha deciso un'ondata di freddo per il giorno `day`: conta per la tregua
func cold_wave_on(day: float) -> void:
	bad.append(int(day))


# --- Salvataggio (vedi main.game_state) ---

func saved() -> Dictionary:
	var out := {}
	for key in SAVED:
		out[key] = get(key)
	return out


# un salvataggio di prima del narratore non ha niente: nessun evento in attesa, nessuna pausa, nessuna tregua
func restore(state: Dictionary) -> void:
	for key in state:
		if key in SAVED:
			set(key, state[key])


# --- Gli eventi ---

func wanderers_can() -> bool:
	return not main.enacted.has(main.Law.CLOSED_GATES)  # con le porte chiuse non viene nessuno


func wanderers_here() -> bool:
	return main.guests.any(func(g): return g.wanderer)


func wanderers_come() -> void:
	main.come(main.wanderer_group())


func scholar_can() -> bool:
	return main.rooms.any(func(r): return main.is_inn(r))


func scholar_here() -> bool:
	return main.scholar_until >= 0.0


func scholar_comes() -> void:
	main.scholar_arrives()


# una minaccia aspetta che nessuno sia a terra e che i lupi se ne siano andati
func threat_can() -> bool:
	return not main.colonists.any(func(c): return c.downed) and not main.animals.any(func(a): return main.hostile(a))


func wolves_come() -> void:
	main.spawn_pack()


func bumper_can() -> bool:
	return main.season(main.today) in [SUMMER, AUTUMN] and not main.sown.is_empty()


func bumper_comes() -> void:
	main.bumper_harvest()


func herd_can() -> bool:
	return main.season(main.today) != main.WINTER


func herd_comes() -> void:
	main.spawn_herd()


func inspiration_can() -> bool:
	return not main.inspirable().is_empty()


func inspiration_comes() -> void:
	main.inspire()


func pilgrim_can() -> bool:
	return main.rooms.any(func(r): return r.kind == main.RoomKind.THRONE_ROOM)


func pilgrim_here() -> bool:
	return main.guests.any(func(g): return g.pilgrim)


func pilgrim_comes() -> void:
	main.pilgrim_comes()


func rats_can() -> bool:
	return main.rats_target() != null


func rats_come() -> void:
	main.rats()


func thief_can() -> bool:
	return main.stored(main.Res.GOLD) >= main.THIEF_FROM


func thief_comes() -> void:
	main.thief()


func fever_every() -> float:
	return FEVER_WINTER if main.season(main.today) == main.WINTER else FEVER_EVERY


func fever_can() -> bool:
	return not main.feverish().is_empty()


func fever_comes() -> void:
	main.fever()
