extends RefCounted
# Salvataggi automatici, per colonia: ognuna ha la sua cartella in `dir` con al più FILES file a rotazione, il primo il
# più recente (gli altri sono una rete di sicurezza se l'ultimo si rovina, non un modo di tornare indietro). Niente
# salvataggi a mano: una colonia è una storia sola. Si salva fondando la colonia, a ogni alba, tornando al titolo,
# uscendo e chiudendo la finestra (vedi autosave in main.gd).
# Un file è compresso; dentro, uno dopo l'altro, due valori di store_var: l'intestazione (quello che mostra l'elenco,
# si legge da sola: vedi header in main.gd) e lo stato della partita (vedi game_state).
# Gli oggetti delle classi interne di main.gd (coloni, animali, stanze...) non passano da store_var: li impacchetta
# Packer in dizionari, e i riferimenti tra loro diventano indici (vedi Unpacker). Si legge senza oggetti (get_var di
# base): un file non può far girare codice. Vedi docs/TECH.md.

static var dir := "user://saves"  # nei test un'altra, così le prove non finiscono nell'elenco di chi gioca
const FILES := 3
const VERSION := 1          # del formato: un salvataggio di una versione più nuova non si carica
const COMPRESSION := FileAccess.COMPRESSION_ZSTD

# lo stato letto da caricare: lo mette chi sceglie la colonia (titolo, opzioni) prima di aprire main.tscn, e main.gd
# lo prende (e lo svuota) in _ready al posto di una partita nuova
static var pending := {}
# la cartella di una colonia appena fondata (vedi create): la mette la pagina della nuova partita, main.gd la prende
# in _ready. Vuota (nei test, o aprendo main.tscn da sola): la partita non si salva
static var founding := ""


# l'n-esimo salvataggio della colonia, dal più recente
static func path_for(colony: String, n := 1) -> String:
	return dir.path_join(colony).path_join("autosave_%d.save" % n)


# una cartella nuova per la colonia `realm` (la crea il primo salvataggio)
static func create(realm: String) -> String:
	var base := "%s_%d" % [realm.validate_filename().replace(" ", "_"), int(Time.get_unix_time_from_system())]
	var folder := base
	var n := 2
	while DirAccess.dir_exists_absolute(dir.path_join(folder)):
		folder = "%s_%d" % [base, n]
		n += 1
	return folder


# Scrive prima su un file a parte e solo se è andato tutto bene fa scorrere gli altri (1 -> 2 -> 3, l'ultimo esce):
# un crash a metà lascia buono il salvataggio di prima
static func write(colony: String, header: Dictionary, state: Dictionary) -> Error:
	var folder := dir.path_join(colony)
	var err := DirAccess.make_dir_recursive_absolute(folder)
	if err != OK:
		return err
	var tmp := folder.path_join("writing.tmp")
	var file := FileAccess.open_compressed(tmp, FileAccess.WRITE, COMPRESSION)
	if file == null:
		return FileAccess.get_open_error()
	header["version"] = VERSION
	file.store_var(header)
	file.store_var(state)
	err = file.get_error()
	file.close()
	if err != OK:
		DirAccess.remove_absolute(tmp)
		return err
	for n in range(FILES, 1, -1):
		if FileAccess.file_exists(path_for(colony, n - 1)):
			if FileAccess.file_exists(path_for(colony, n)):
				DirAccess.remove_absolute(path_for(colony, n))
			DirAccess.rename_absolute(path_for(colony, n - 1), path_for(colony, n))
	return DirAccess.rename_absolute(tmp, path_for(colony, 1))


# l'intestazione, {} se il file non si legge o è di una versione più nuova
static func read_header(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open_compressed(path, FileAccess.READ, COMPRESSION)
	if file == null:
		return {}
	var header = file.get_var()
	if not header is Dictionary or not header.get("version", 0) is int or header.get("version", 0) > VERSION:
		return {}
	return header


# lo stato della partita, {} se il file non si legge o è di una versione più nuova
static func read_state(path: String) -> Dictionary:
	if read_header(path).is_empty():
		return {}
	var file := FileAccess.open_compressed(path, FileAccess.READ, COMPRESSION)
	if file == null:
		return {}
	file.get_var()
	var state = file.get_var()
	return state if state is Dictionary and state.has_all(["main", "objects"]) else {}


# lo stato più recente della colonia che si legge: se il primo è rovinato, quelli prima; {} se nessuno
static func read_colony(colony: String) -> Dictionary:
	for n in range(1, FILES + 1):
		var state := read_state(path_for(colony, n))
		if not state.is_empty():
			return state
	return {}


# le colonie, ognuna con l'intestazione del suo salvataggio più recente che si legge (e "folder"), dalla più recente
static func list() -> Array:
	var out := []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for folder in DirAccess.get_directories_at(dir):
		for n in range(1, FILES + 1):
			var header := read_header(path_for(folder, n))
			if not header.is_empty():
				header["folder"] = folder
				out.append(header)
				break
	out.sort_custom(func(a, b): return a.get("saved", 0.0) > b.get("saved", 0.0))
	return out


# via la colonia, con tutti i suoi salvataggi
static func remove(colony: String) -> void:
	var folder := dir.path_join(colony)
	if colony == "" or not DirAccess.dir_exists_absolute(folder):
		return
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)


# data e ora del computer di quando è stato salvato (`unix`: secondi, come Time.get_unix_time_from_system)
static func when(unix: float) -> String:
	var t := Time.get_datetime_dict_from_unix_time(int(unix) + Time.get_time_zone_from_system()["bias"] * 60)
	return "%02d/%02d/%d %02d:%02d" % [t["day"], t["month"], t["year"], t["hour"], t["minute"]]


# Impacchetta per store_var: un oggetto di una delle classi `classes` diventa {"@": classe, "#": indice} e i suoi campi
# (le variabili dello script) vanno in fields(), una volta sola anche se ci si arriva da più parti. Gli altri oggetti
# (nodi, texture...) diventano null: lo stato del gioco non ne ha.
class Packer:
	var classes: Array
	var objects := []       # per classe: gli oggetti incontrati, nell'ordine dei loro indici
	var ids := {}           # oggetto -> indice in objects della sua classe

	func _init(of: Array) -> void:
		classes = of
		for k in classes.size():
			objects.append([])

	func pack(value: Variant) -> Variant:
		match typeof(value):
			TYPE_OBJECT:
				var k := classes.find(value.get_script()) if is_instance_valid(value) else -1
				if k < 0:
					return null
				if not ids.has(value):
					ids[value] = objects[k].size()
					objects[k].append(value)
				return {"@": k, "#": ids[value]}
			TYPE_ARRAY:
				return value.map(pack)
			TYPE_DICTIONARY:
				var out := {}
				for key in value:
					out[pack(key)] = pack(value[key])
				return out
		return value

	# i campi di tutti gli oggetti incontrati, per classe e per indice; impacchettarli ne fa incontrare altri
	func fields() -> Array:
		var out := []
		for k in classes.size():
			out.append([])
		var more := true
		while more:
			more = false
			for k in classes.size():
				while out[k].size() < objects[k].size():
					var obj: Object = objects[k][out[k].size()]
					var data := {}
					for p in obj.get_property_list():
						if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
							data[p["name"]] = pack(obj.get(p["name"]))
					out[k].append(data)
					more = true
		return out


# Il contrario di Packer: crea gli oggetti di `fields` (vuoti), poi unpack rimette i riferimenti e fill i campi
class Unpacker:
	var objects := []

	func _init(classes: Array, fields: Array) -> void:
		for k in classes.size():
			var made := []
			for i in fields[k].size():
				made.append(classes[k].new())
			objects.append(made)
		for k in classes.size():
			for i in fields[k].size():
				for name in fields[k][i]:
					put(objects[k][i], name, unpack(fields[k][i][name]))

	func unpack(value: Variant) -> Variant:
		match typeof(value):
			TYPE_DICTIONARY:
				if value.size() == 2 and value.has("@") and value.has("#"):
					return objects[value["@"]][value["#"]]
				var out := {}
				for key in value:
					out[unpack(key)] = unpack(value[key])
				return out
			TYPE_ARRAY:
				return value.map(unpack)
		return value

	# `obj.name = value`; negli array tipizzati (Array[Colonist], Array[Vector2i]...) si copiano gli elementi, così
	# l'array resta del suo tipo. I campi che lo script non ha più si ignorano
	static func put(obj: Object, name: String, value: Variant) -> void:
		var now = obj.get(name)
		if now is Array and now.is_typed() and value is Array:
			now.assign(value)
		elif name in obj:
			obj.set(name, value)
