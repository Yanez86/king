extends VBoxContainer
# Elenco delle colonie salvate (vedi saves.gd): una per riga, dalla giocata più di recente, coi dettagli di quella
# scelta sotto. Load (anche doppio clic o Invio) legge il suo salvataggio più recente e lo passa con `chosen`; Delete
# la cancella con tutti i suoi salvataggi, dopo la conferma (di nuovo il tasto); Back manda `closed`. Sta nel menù
# delle opzioni (la pagina di Load game) e sulla schermata del titolo (Colonies).

signal chosen(state: Dictionary)
signal closed

const SAVES := preload("res://saves.gd")

var keyboard := true        # false in partita: niente fuoco da tastiera, se no Spazio e Invio premerebbero i tasti
var list := ItemList.new()
var details := Label.new()
var load_button := Button.new()
var delete_button := Button.new()
var back_button := Button.new()
var saves := []             # le intestazioni, come le righe di `list` (vedi SAVES.list)
var deleting := -1          # la riga di cui Delete aspetta la conferma
var current := ""           # in partita: la cartella della colonia che si gioca, che da qui non si cancella


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "Colonies"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	list.custom_minimum_size = Vector2(400, 180)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.focus_mode = Control.FOCUS_ALL if keyboard else Control.FOCUS_NONE
	list.item_selected.connect(select)
	list.item_activated.connect(func(_i): load_selected())
	add_child(list)
	details.custom_minimum_size = Vector2(400, 0)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(details)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for pair in [[load_button, "Load"], [delete_button, "Delete"], [back_button, "Back"]]:
		var button: Button = pair[0]
		button.text = pair[1]
		button.custom_minimum_size = Vector2(110, 36)
		button.focus_mode = Control.FOCUS_ALL if keyboard else Control.FOCUS_NONE
		row.add_child(button)
	load_button.pressed.connect(load_selected)
	delete_button.pressed.connect(delete_selected)
	back_button.pressed.connect(closed.emit)
	add_child(row)
	refresh()


# rilegge i salvataggi dal disco e sceglie il più recente
func refresh() -> void:
	saves = SAVES.list()
	list.clear()
	for header in saves:
		list.add_item("%s · %s" % [header.get("title", "?"), header.get("date", "")])
	if not saves.is_empty():
		list.select(0)
		list.ensure_current_is_visible()
	select(0)


func select(i: int) -> void:
	deleting = -1
	delete_button.text = "Delete"
	load_button.disabled = saves.is_empty()
	delete_button.disabled = saves.is_empty() or saves[i]["folder"] == current
	if saves.is_empty():
		details.text = tr("No colonies yet.")
		return
	var header: Dictionary = saves[i]
	var people: int = header.get("people", 0)
	details.text = "%s\n%s\n%s" % [tr("Ruler: %s") % header.get("ruler", "?"),
		tr_n("%d colonist", "%d colonists", people) % people, tr("Saved on %s") % SAVES.when(header.get("saved", 0.0))]


func selected() -> int:
	var rows := list.get_selected_items()
	return rows[0] if not rows.is_empty() else -1


func load_selected() -> void:
	var i := selected()
	if i < 0:
		return
	var state := SAVES.read_colony(saves[i]["folder"])
	if state.is_empty():
		details.text = tr("This save can't be read.")
		return
	chosen.emit(state)


func delete_selected() -> void:
	var i := selected()
	if i < 0:
		return
	if deleting != i:
		deleting = i
		delete_button.text = "Sure?"
		return
	SAVES.remove(saves[i]["folder"])
	refresh()
