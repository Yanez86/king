# Il narratore (GDD 4.6): ogni giorno, a mezzanotte, sceglie al più un evento tra quelli possibili quel giorno, con un
# tiro solo. Ogni evento ha una fetta grande quanto è frequente ("in media ogni 10 giorni" è una fetta di 1/10): così
# ognuno tiene il suo ritmo, ma due eventi non vengono mai lo stesso giorno; se le fette insieme passano l'intero, si
# stringono in proporzione. L'evento scelto avviene alla sua ora, se allora si può ancora (vedi can_happen); se no quel
# giorno non succede niente.
# Figlio di main, come atmosphere.gd: legge da lì lo stato della colonia, e gli effetti li fa fare a main.
extends Node

enum Kind { THREAT, VISIT, BOON, BANE }  # minaccia, visita, fortuna, sfortuna
enum Event { WANDERERS, SCHOLAR }
# Gli eventi, una riga per evento.
# "kind": Kind. "from": giorno da cui può capitare, contato da 0 come main.today. "every": giorni in media tra uno e
# l'altro, pausa compresa: un numero, o il nome di una funzione di main quando dipende dallo stato della colonia.
# "pause": giorni almeno tra uno e l'altro, contati dall'ultimo giorno in cui c'era. "hour": l'ora del giorno in cui
# avviene. "can": funzione di questo script, se serve: quando è possibile, oltre a "from" e "pause". "busy": funzione di
# questo script, vera finché è in corso: intanto non ne viene un altro e la pausa riparte ogni giorno. "do": l'effetto,
# una funzione di questo script (la cronaca la scrive main). I testi sono nel .po, come tutti gli altri
const EVENTS := {
	# GDD 4.2.1: uno alla volta, non con Porte chiuse; più spesso con lo splendore, meno con tanti coloni (wander_wait)
	Event.WANDERERS: {"kind": Kind.VISIT, "from": 10, "every": "wander_wait", "pause": 5.0, "hour": 10,
		"can": "wanderers_can", "busy": "wanderers_here", "do": "wanderers_come"},
	# GDD 4.7.2: con una locanda, per un giorno; vende 1-2 libri (vedi main.scholar_arrives)
	Event.SCHOLAR: {"kind": Kind.VISIT, "from": 5, "every": 10.0, "pause": 5.0, "hour": 9,
		"can": "scholar_can", "busy": "scholar_here", "do": "scholar_comes"},
}
const SAVED := ["planned", "last"]

@onready var main = get_parent()
var planned := -1   # l'Event di oggi, scelto a mezzanotte, che aspetta la sua ora; -1: niente
var last := {}      # Event -> l'ultimo giorno (main.today) in cui c'era: la pausa parte da lì


# A mezzanotte (main.new_day): chi è ancora in corso fa ripartire la sua pausa, poi si sceglie l'evento di oggi
func new_day() -> void:
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


# la fetta di `e` nel tiro di un giorno in cui è possibile: 1 / i giorni in media tra due, tolta la pausa (in cui non
# si tira), così la media resta quella, pausa compresa
func chance(e: int) -> float:
	return 1.0 / maxf(every(e) - EVENTS[e].get("pause", 0.0), 1.0)


# giorni in media tra un `e` e l'altro, adesso
func every(e: int) -> float:
	var days = EVENTS[e]["every"]
	return main.call(days) if days is String else float(days)


# `e` può capitare oggi: dal suo giorno, non in corso, passata la pausa, e quando lo dice la sua "can"
func can_happen(e: int) -> bool:
	var row: Dictionary = EVENTS[e]
	if main.today < row.get("from", 0) or busy(e):
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
	return true


# --- Salvataggio (vedi main.game_state) ---

func saved() -> Dictionary:
	var out := {}
	for key in SAVED:
		out[key] = get(key)
	return out


# un salvataggio di prima del narratore non ha niente: nessun evento in attesa, nessuna pausa
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
