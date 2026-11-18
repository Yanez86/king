extends RefCounted
# Salvataggi automatici. Ogni colonia ha la sua cartella in ROOT con al più FILES file a rotazione: il primo è il più
# recente, gli altri sono i giorni prima, una rete di sicurezza se l'ultimo si rovina (non un modo di tornare indietro).
# Un file è il dizionario {"version", "info", "state"} scritto con store_var e compresso: "info" (nome, giorno, coloni,
# quando) serve all'elenco del titolo, "state" lo scrive e lo legge main.gd (vedi save_state e load_state).

const ROOT := "user://saves"
const FILES := 3
const VERSION := 1          # da aumentare quando cambia il formato di "state", con la conversione dei vecchi in load_state
const NAME_START := ["Ash", "Oak", "Elm", "Thorn", "Raven", "Wolf", "Stone", "Mill", "Fern", "Briar", "Hart", "King",
	"Red", "Black", "Bright", "Wild"]
const NAME_END := ["ford", "vale", "wick", "stead", "bury", "holm", "field", "moor", "haven", "wood", "mere", "dale",
	"crest", "hollow"]


static func path(colony: String, n := 1) -> String:
	return "%s/%s/autosave_%d.save" % [ROOT, colony, n]


# Nuova colonia: una cartella vuota (il primo salvataggio lo fa main.gd appena generata la mappa) e un nome da borgo
# che non c'è già. Restituisce [cartella, nome].
static func create() -> Array:
	var taken := colonies().map(func(c): return c.info.name)
	var name := ""
	for i in 50:
		name = NAME_START.pick_random() + NAME_END.pick_random()
		if name not in taken:
			break
	var folder := "colony_%d" % int(Time.get_unix_time_from_system())
	while DirAccess.dir_exists_absolute(ROOT + "/" + folder):
		folder += "b"
	DirAccess.make_dir_recursive_absolute(ROOT + "/" + folder)
	return [folder, name]


# Scrive prima su un file temporaneo e solo se è andato tutto bene fa scorrere gli altri: un crash a metà lascia
# intatto il salvataggio precedente.
static func write(colony: String, info: Dictionary, state: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ROOT + "/" + colony)
	var temp := "%s/%s/writing.save" % [ROOT, colony]
	var file := FileAccess.open_compressed(temp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		push_error("Salvataggio non riuscito (%s): errore %d" % [temp, FileAccess.get_open_error()])
		return false
	info.saved_at = Time.get_unix_time_from_system()
	var ok := file.store_var({"version": VERSION, "info": info, "state": state})
	file.close()
	if not ok:
		push_error("Salvataggio non riuscito: " + temp)
		return false
	for n in range(FILES, 1, -1):  # 2 -> 3, 1 -> 2: l'ultimo esce
		if FileAccess.file_exists(path(colony, n - 1)):
			DirAccess.remove_absolute(path(colony, n))
			DirAccess.rename_absolute(path(colony, n - 1), path(colony, n))
	return DirAccess.rename_absolute(temp, path(colony, 1)) == OK


# Il salvataggio più recente che si legge, o {} se nessuno: se il primo è rovinato prova quelli prima.
static func read(colony: String) -> Dictionary:
	for n in range(1, FILES + 1):
		var data := read_file(path(colony, n))
		if not data.is_empty():
			return data
	return {}


static func read_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file := FileAccess.open_compressed(file_path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return {}
	var data = file.get_var()
	file.close()
	if not (data is Dictionary and data.get("version", 0) is int and data.has_all(["info", "state"])):
		return {}
	if data.version > VERSION:  # da una versione del gioco più nuova: non sappiamo leggerlo
		return {}
	return data


# Colonie con un salvataggio leggibile, la più recente per prima: [{folder, info}]
static func colonies() -> Array:
	var out := []
	if not DirAccess.dir_exists_absolute(ROOT):
		return out
	for folder in DirAccess.get_directories_at(ROOT):
		var data := read(folder)
		if not data.is_empty():
			out.append({"folder": folder, "info": data.info})
	out.sort_custom(func(a, b): return a.info.saved_at > b.info.saved_at)
	return out


static func remove(colony: String) -> void:
	var dir := ROOT + "/" + colony
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)
	DirAccess.remove_absolute(dir)
