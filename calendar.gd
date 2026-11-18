# Il calendario: si apre cliccando la data in alto (vedi main.calendar). Una pagina per mese, che si sfoglia; il
# Capodanno sta all'inizio della prima pagina dell'anno, la festa della stagione in fondo al suo terzo mese. Ogni giorno
# porta i segni dei suoi eventi (vedi events): feste e Capodanno, giorni di riposo, quello che dice la cronaca, le
# scadenze (spedizioni che devono tornare, leggi revocate che si possono ripromulgare); col mouse sopra, il dettaglio.
extends PanelContainer

enum Mark { FEAST, CROWN, REST, CHRONICLE, DUE }
const MARK_ICONS := [preload("res://art/icon_star.png"), preload("res://art/icon_crown.png"),
	preload("res://art/icon_pause.png"), preload("res://art/icon_notebook.png"), preload("res://art/icon_jobs.png")]
const CLOSE := preload("res://art/icon_cancel.png")
const COLUMNS := 6

var main
var page := 0         # mese mostrato, contato dal primo dell'anno 1: anno * 12 + mese
var title := Label.new()
var grid := GridContainer.new()
var shown := []       # [oggi, voci della cronaca] per cui è fatta la pagina: cambiati, si rifà


func _ready() -> void:
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	for part in [["<", -1], ["", 0], [">", 1]]:
		if part[1] == 0:
			title.size_flags_horizontal = SIZE_EXPAND_FILL
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			head.add_child(title)
			continue
		var turn := Button.new()
		turn.text = part[0]
		turn.custom_minimum_size = Vector2(32, 32)
		turn.focus_mode = FOCUS_NONE
		turn.tooltip_text = "Previous month" if part[1] < 0 else "Next month"
		turn.pressed.connect(func():
			page = maxi(page + part[1], 0)
			show_page())
		head.add_child(turn)
	var close := Button.new()
	close.icon = CLOSE
	close.custom_minimum_size = Vector2(32, 32)
	close.expand_icon = true
	close.focus_mode = FOCUS_NONE
	close.tooltip_text = "Close"
	close.pressed.connect(hide)
	head.add_child(close)
	grid.columns = COLUMNS
	box.add_child(head)
	box.add_child(grid)
	add_child(box)
	gui_input.connect(main.drag_window.bind(self))
	visibility_changed.connect(func():
		if visible:  # si apre sul mese di oggi, in mezzo allo schermo
			page = month_of(int(main.clock))
			show_page()
			position = ((get_viewport_rect().size - size) / 2).floor()
			move_to_front())


func _process(_delta: float) -> void:
	if visible and shown != [int(main.clock), main.chronicle.size()]:
		show_page()


@warning_ignore("integer_division")
func show_page() -> void:
	shown = [int(main.clock), main.chronicle.size()]
	var month := page % 12
	title.text = "%s, %s, Year %d" % [main.MONTHS[month], main.SEASONS[month / 3], page / 12 + 1]
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for day in days(page):
		grid.add_child(cell(day))
	reset_size()


# I giorni della pagina `p` (anno * 12 + mese), contati da 0 come main.clock: il Capodanno prima del primo mese
# dell'anno, la festa dopo il terzo mese di ogni stagione
@warning_ignore("integer_division")
func days(p: int) -> Array:
	var m := p % 12
	var first: int = p / 12 * main.YEAR_DAYS + 1 + m / 3 * main.SEASON_DAYS + m % 3 * main.MONTH_DAYS
	var out := range(first, first + main.MONTH_DAYS)
	if m == 0:
		out.push_front(first - 1)
	if m % 3 == 2:
		out.append(first + main.MONTH_DAYS)
	return out


# la pagina del giorno `day`: il Capodanno sta col primo mese, la festa col terzo della sua stagione
@warning_ignore("integer_division")
func month_of(day: int) -> int:
	var d: int = posmod(day, main.YEAR_DAYS) - 1
	var m: int = 0 if d < 0 else d / main.SEASON_DAYS * 3 + mini(posmod(d, main.SEASON_DAYS) / main.MONTH_DAYS, 2)
	return day / main.YEAR_DAYS * 12 + m


# Gli eventi del giorno `day`: [Mark, testo]. I giorni di riposo e le scadenze solo da oggi in poi (sono quelli di
# adesso: leggi e spedizioni possono cambiare)
@warning_ignore("integer_division")
func events(day: int) -> Array:
	var out := []
	var today := int(main.clock)
	if main.feast(day):
		var d: int = posmod(day, main.YEAR_DAYS) - 1
		out.append([Mark.CROWN, main.NEW_YEAR] if d < 0 else [Mark.FEAST, main.FEASTS[d / main.SEASON_DAYS]])
	if day >= today and main.enacted.has(main.Law.DAY_OF_REST) and day % main.REST_EVERY == main.REST_EVERY - 1:
		out.append([Mark.REST, "Day of rest"])
	for i in mini(main.chronicle.size(), main.chronicle_days.size()):
		if main.chronicle_days[i] == day:
			out.append([Mark.CHRONICLE, main.chronicle[i].get_slice("\n", 0).trim_prefix(main.date(day) + ": ")])
	if day >= today:
		for exp in main.expeditions:
			if exp.left_at >= 0 and int(exp.due) == day:
				out.append([Mark.DUE, "Expedition due back from the %s" % main.RUINS[exp.ruin.kind]["name"]])
		for law in main.revoked:
			if main.revoked[law] > main.clock and int(main.revoked[law]) == day:
				out.append([Mark.DUE, "%s can be enacted again" % main.law_name(law)])
	return out


# Un giorno: il numero (o "Feast", "Crown"), sotto i segni dei suoi eventi, col mouse sopra data ed eventi; oggi
# premuto, i giorni passati più spenti
func cell(day: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(64, 52)
	b.focus_mode = FOCUS_NONE
	b.toggle_mode = true
	b.button_mask = 0  # non si clicca: si guarda
	b.button_pressed = day == int(main.clock)
	if day < int(main.clock):
		b.modulate = Color(1, 1, 1, 0.55)
	var box := VBoxContainer.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, 4)
	box.add_theme_constant_override("separation", 2)
	var number := Label.new()
	var d: int = posmod(day, main.YEAR_DAYS) - 1
	number.text = "Crown" if d < 0 else "Feast" if main.feast(day) else str(posmod(d, main.SEASON_DAYS) % main.MONTH_DAYS + 1)
	box.add_child(number)
	var marks := HBoxContainer.new()
	marks.mouse_filter = MOUSE_FILTER_IGNORE
	marks.add_theme_constant_override("separation", 1)
	var list := events(day)
	var seen := {}
	for e in list:
		if not seen.has(e[0]):
			seen[e[0]] = true
			var icon: TextureRect = main.ui_icon(MARK_ICONS[e[0]], Rect2(), Vector2(16, 16))
			icon.mouse_filter = MOUSE_FILTER_IGNORE
			marks.add_child(icon)
	box.add_child(marks)
	b.add_child(box)
	b.tooltip_text = "\n".join([main.date(day)] + list.map(func(e): return e[1]))
	return b
