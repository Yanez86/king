extends Control
# Nuova partita (GDD 4.3.1), due pagine: la casata (nome, colonia, stemma) e il sovrano (nome, sesso, aspetto e
# Main.RULER_POINTS punti abilità, al massimo Main.RULER_SKILL_CAP per abilità). "Start" passa tutto alla partita
# (Main.setup) e la apre; "Back" dalla prima pagina torna al titolo. L'interfaccia è fatta qui, nel codice.

const Main := preload("res://main.gd")
const DICE := preload("res://art/icon_dice.png")
const TURN_ICONS := [preload("res://art/icon_rotate_left.png"), preload("res://art/icon_rotate_right.png")]
const TURNS := [Main.Facing.DOWN, Main.Facing.LEFT, Main.Facing.UP, Main.Facing.RIGHT]  # in senso orario, visto da sopra
const PREVIEW := 8          # pixel dello schermo per pixel dello sprite (sovrano e stemma)
const PAGE_TITLES := ["Your House", "Your Ruler"]
# le proprietà del Colonist che si scelgono qui: vanno in Main.setup["ruler"]
const CHOSEN := ["first_name", "nickname", "last_name", "sex", "hair_style", "beard", "hair", "tunic", "cape", "skills",
	"traits"]

var ruler: Main.Colonist = Main.Colonist.new()  # quello che si sta facendo: lo disegna l'anteprima
var arms := Main.random_arms()  # lo stemma della casata, vedi Main.Tincture
var dressed := false        # maglia e mantello scelti a mano: non seguono più lo stemma
var page := 0               # indice in `pages`
var pages: Array[Control] = []
var turn := 0               # indice in TURNS: dove guarda l'anteprima
var time := 0.0             # secondi: il respiro del sovrano, lo stendardo che sventola
var title := Label.new()
var house := LineEdit.new()
var colony := LineEdit.new()
var first := LineEdit.new()
var nick := LineEdit.new()
var beard := CheckBox.new()
var preview := Control.new()
var shield := TextureRect.new()
var banner_preview := Control.new()
var banner: ImageTexture    # il drappo dello stendardo, vedi Main.banner_texture
var points := Label.new()
var back_button := Button.new()
var forward := Button.new()  # "Next", nell'ultima pagina "Start"
var levels := {}            # Skill -> [livello, "-", "+"]
var trait_buttons := {}     # Trait -> pulsante, vedi traits_grid
var synced := []            # [pulsante, valore corrente (Callable), valore del pulsante]: premuto se coincidono
var arms_icons := []        # [pulsante, voce dello stemma, valore]: l'icona è lo stemma con quel valore


func _ready() -> void:
	Main.dress(ruler)
	ruler.skills = Main.Skill.values().map(func(_s): return 0)
	var back := ColorRect.new()
	back.color = Color("1f1a24")  # come il fondo del titolo
	back.set_anchors_preset(PRESET_FULL_RECT)
	add_child(back)
	var middle := CenterContainer.new()
	middle.set_anchors_preset(PRESET_FULL_RECT)
	add_child(middle)
	var panel := PanelContainer.new()
	middle.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	pages = [house_page(), ruler_page()]
	for p in pages:
		box.add_child(p)
	var buttons := HBoxContainer.new()
	back_button.text = "Back"
	back_button.pressed.connect(func(): go(page - 1))
	buttons.add_child(back_button)
	var gap := Control.new()
	gap.size_flags_horizontal = SIZE_EXPAND_FILL
	buttons.add_child(gap)
	forward.custom_minimum_size.x = 120
	forward.pressed.connect(func(): go(page + 1))
	buttons.add_child(forward)
	box.add_child(buttons)
	arms_changed()
	go(0)


func _process(delta: float) -> void:
	time += delta
	preview.queue_redraw()
	banner_preview.queue_redraw()


# alla pagina `to`: prima della prima si torna al titolo, dopo l'ultima si parte
func go(to: int) -> void:
	if to < 0:
		get_tree().change_scene_to_file("res://title.tscn")
		return
	if to >= pages.size():
		begin()
		return
	page = to
	for i in pages.size():
		pages[i].visible = i == page
	title.text = PAGE_TITLES[page]
	forward.text = "Start" if page == pages.size() - 1 else "Next"
	refresh()


# la casata: a sinistra i nomi e le scelte dello stemma, a destra lo scudo grande e lo stendardo
func house_page() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var names := GridContainer.new()
	names.columns = 3
	name_row(names, "House", house, ruler.last_name, func(): return Main.LAST_NAMES.pick_random())
	name_row(names, "Colony", colony, Main.COLONY_NAMES.pick_random(), func(): return Main.COLONY_NAMES.pick_random())
	box.add_child(names)
	for r in [["Shape", "shape", Main.Shape], ["Division", "division", Main.Division], ["Field", "field", null],
			["Second field", "field2", null], ["Ordinary", "ordinary", Main.Ordinary], ["Ordinary tincture", "ordinary_tincture", null],
			["Charge", "charge", Main.Charge], ["Charge tincture", "charge_tincture", null]]:
		var key: String = r[1]
		var values: Array = r[2].values() if r[2] != null else Main.Tincture.values()
		var context: String = {"division": "division", "ordinary": "heraldry", "charge": "heraldry"}.get(key, "")  # vedi Main.named
		var show := show_arms.bind(key, r[2], context) if r[2] != null else show_tincture
		box.add_child(pick_row(r[0], values, func(): return arms[key], set_arms.bind(key), show))
	var dice := small_button(DICE, "Random coat of arms")
	dice.text = "Random"
	dice.custom_minimum_size.x = 0
	dice.size_flags_horizontal = SIZE_SHRINK_BEGIN
	dice.pressed.connect(func():
		arms = Main.random_arms()
		arms_changed())
	box.add_child(dice)
	row.add_child(box)
	var right := VBoxContainer.new()
	right.size_flags_vertical = SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 16)
	shield.custom_minimum_size = Vector2.ONE * 16 * PREVIEW
	shield.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	right.add_child(shield)
	banner_preview.custom_minimum_size = Vector2.ONE * Main.TILE * PREVIEW / 2
	banner_preview.size_flags_horizontal = SIZE_SHRINK_CENTER
	banner_preview.tooltip_text = "Your banner"
	banner_preview.draw.connect(draw_banner)
	right.add_child(banner_preview)
	row.add_child(right)
	return row


# il sovrano: a sinistra nomi, sesso e aspetto; in mezzo lui grande, che respira e si gira; a destra le abilità
func ruler_page() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var names := GridContainer.new()
	names.columns = 3
	name_row(names, "Name", first, ruler.first_name, func(): return Main.FIRST_NAMES[ruler.sex].pick_random())
	name_row(names, "Nickname", nick, tr(ruler.nickname), func(): return tr(Main.NICKNAMES.pick_random()))
	nick.placeholder_text = "(optional)"
	box.add_child(names)
	box.add_child(pick_row("Sex", Main.Sex.values(), func(): return ruler.sex, set_sex, show_sex))
	box.add_child(pick_row("Hair", Main.Hair.values(), func(): return ruler.hair_style, set_look.bind("hair_style"),
		show_text.bind(Main.Hair)))
	beard.text = "Beard"
	beard.focus_mode = FOCUS_NONE
	beard.button_pressed = ruler.beard
	beard.disabled = ruler.sex == Main.Sex.FEMALE
	beard.toggled.connect(func(on): ruler.beard = on)
	box.add_child(beard)
	box.add_child(pick_row("Hair color", Main.HAIR_COLORS, func(): return ruler.hair, set_look.bind("hair"), show_swatch))
	for part in ["tunic", "cape"]:  # gli smalti dello stemma
		box.add_child(pick_row(part.capitalize(), Main.TINCTURE_COLORS, func(): return ruler.get(part), dress_in.bind(part), show_swatch))
	var label := Label.new()
	label.text = tr("Traits (up to %d)") % Main.RULER_TRAITS
	box.add_child(label)
	box.add_child(traits_grid())
	row.add_child(box)
	row.add_child(preview_column())
	row.add_child(skills_column())
	return row


func preview_column() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_vertical = SIZE_SHRINK_CENTER
	preview.custom_minimum_size = Vector2.ONE * Main.TILE * PREVIEW
	preview.draw.connect(draw_preview)
	box.add_child(preview)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 2:  # a sinistra, a destra
		var button := small_button(TURN_ICONS[i], "Turn")
		button.pressed.connect(func(): turn = posmod(turn + (1 if i else -1), TURNS.size()))
		row.add_child(button)
	box.add_child(row)
	return box


# le abilità, coi punti da dare (lo scassinare no: è degli avventurieri)
func skills_column() -> Control:
	var box := VBoxContainer.new()
	box.add_child(points)
	var grid := GridContainer.new()
	grid.columns = 5
	for s in Main.Skill.values():
		if s == Main.Skill.LOCKPICKING:
			continue
		var label := Label.new()
		label.text = Main.named(Main.Skill, s, "skill")
		label.custom_minimum_size.x = 110
		var level := Label.new()
		level.custom_minimum_size.x = 24
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var less := Button.new()
		less.text = "-"
		less.pressed.connect(spend.bind(s, -1))
		var more := Button.new()
		more.text = "+"
		more.pressed.connect(spend.bind(s, 1))
		for node in [Main.ui_icon(Main.SKILLS_SHEET, Rect2(s * 8, 0, 8, 8), Vector2(16, 16)), label, less, level, more]:
			grid.add_child(node)
		levels[s] = [level, less, more]
	box.add_child(grid)
	return box


func name_row(grid: GridContainer, text: String, edit: LineEdit, value: String, roll: Callable) -> void:
	var label := Label.new()
	label.text = text
	grid.add_child(label)
	edit.text = value
	edit.max_length = 20
	edit.custom_minimum_size.x = 200
	edit.text_changed.connect(refresh.unbind(1))
	grid.add_child(edit)
	var dice := small_button(DICE, "Random")
	dice.pressed.connect(func():
		edit.text = roll.call()
		refresh())
	grid.add_child(dice)


# riga di pulsanti a scelta unica, uno per valore: `show` lo prepara (testo, icona o colore), `pick` riceve il
# valore scelto; è premuto quello uguale a `current` (vedi refresh)
func pick_row(text: String, values: Array, current: Callable, pick: Callable, show: Callable) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 150
	row.add_child(label)
	var group := ButtonGroup.new()
	for v in values:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = FOCUS_NONE
		button.custom_minimum_size = Vector2(36, 36)
		show.call(button, v)
		button.pressed.connect(func(): pick.call(v))
		row.add_child(button)
		synced.append([button, current, v])
	return row


func small_button(icon: Texture2D, tip: String) -> Button:
	var button := Button.new()
	button.icon = icon
	button.tooltip_text = tip
	button.focus_mode = FOCUS_NONE
	button.custom_minimum_size = Vector2(32, 32)
	button.expand_icon = true
	return button


func show_sex(button: Button, s: int) -> void:
	button.text = Main.SEX_NAMES[s]
	button.icon = Main.SEX_ICONS[s]


func show_text(button: Button, v: int, names: Dictionary) -> void:
	button.text = Main.named(names, v)


func show_swatch(button: Button, color: Color) -> void:
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.mouse_filter = MOUSE_FILTER_IGNORE
	button.add_child(swatch)
	swatch.set_anchors_and_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, 7)


func show_tincture(button: Button, t: int) -> void:
	show_swatch(button, Main.TINCTURE_COLORS[t])
	button.tooltip_text = Main.named(Main.Tincture, t)


# forma, partizione, pezza o figura: l'icona è lo stemma con questa scelta (vedi arms_changed), il nome nel suggerimento
func show_arms(button: Button, v: int, key: String, names: Dictionary, context: String) -> void:
	button.tooltip_text = Main.named(names, v, context)
	arms_icons.append([button, key, v])


func set_arms(v: int, key: String) -> void:
	arms[key] = v
	arms_changed()


func set_look(v, key: String) -> void:
	ruler.set(key, v)
	refresh()


func dress_in(color: Color, part: String) -> void:
	ruler.set(part, color)
	dressed = true
	refresh()


# la barba solo agli uomini; il nome, se era dell'altro sesso, se ne prende uno del suo
func set_sex(s: int) -> void:
	ruler.sex = s
	beard.disabled = s == Main.Sex.FEMALE
	if beard.disabled:
		beard.button_pressed = false
	if first.text not in Main.FIRST_NAMES[s] and Main.FIRST_NAMES.values().any(func(names): return first.text in names):
		first.text = Main.FIRST_NAMES[s].pick_random()
	refresh()


# lo stemma è cambiato: scudo, stendardo e icone delle scelte; maglia e mantello coi primi due smalti, se non scelti
func arms_changed() -> void:
	if not dressed:
		ruler.tunic = Main.TINCTURE_COLORS[arms.field]
		ruler.cape = Main.TINCTURE_COLORS[arms.field2]
	shield.texture = Main.arms_texture(arms)
	banner = Main.banner_texture(arms)
	for entry in arms_icons:
		var variant := arms.duplicate()
		variant[entry[1]] = entry[2]
		var img: Image = Main.arms_texture(variant).get_image()
		img.resize(32, 32, Image.INTERPOLATE_NEAREST)  # 2x esatto: i pixel restano quadrati
		entry[0].icon = ImageTexture.create_from_image(img)
	refresh()


func draw_preview() -> void:
	var frame: int = Main.IDLE_CYCLE[int(time / Main.BREATH_TIME * Main.IDLE_CYCLE.size()) % Main.IDLE_CYCLE.size()]
	var src := Rect2(Vector2(frame, TURNS[turn]) * Main.TILE, Vector2.ONE * Main.TILE)
	Main.draw_figure(preview, Rect2(Vector2.ZERO, preview.custom_minimum_size), src, ruler)


# lo stendardo che sventola, come sulla mappa: l'asta dal foglio dei mobili, il drappo della casata sopra
func draw_banner() -> void:
	var col := int(time / Main.ANIMATED[Main.Build.BANNER]) % 4
	var dst := Rect2(Vector2.ZERO, banner_preview.custom_minimum_size)
	banner_preview.draw_texture_rect_region(Main.FURNITURE_SHEET, dst,
		Rect2(col * 32, (Main.Build.BANNER - Main.Build.BED) * 32, Main.TILE, Main.TILE))
	banner_preview.draw_texture_rect_region(banner, dst, Rect2(col * Main.TILE, 0, Main.TILE, Main.TILE))


# i talenti: un pulsante per talento, con l'icona e i punti che costa (-2) o dà (+2); nome, effetto e costo nel suggerimento
func traits_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = 5
	for t in Main.Trait.values():
		var cost: int = Main.TRAIT_COST.get(t, 0)
		var img := Main.image_of(Main.TRAITS_SHEET).get_region(Rect2i(t * 16, 0, 16, 16))
		img.resize(32, 32, Image.INTERPOLATE_NEAREST)
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = FOCUS_NONE
		button.icon = ImageTexture.create_from_image(img)
		button.text = "%+d" % -cost if cost else ""
		button.custom_minimum_size = Vector2(72, 40)
		button.tooltip_text = "%s\n%s\n%s" % [Main.named(Main.Trait, t), tr(Main.TRAIT_INFO[t]),
			tr("Costs %d skill points") % cost if cost > 0 else (tr("Gives %d skill points") % -cost if cost < 0 else tr("Free"))]
		button.pressed.connect(toggle_trait.bind(t))
		grid.add_child(button)
		trait_buttons[t] = button
		synced.append([button, func(): return t in ruler.traits, true])
	return grid


# preso, se ce n'è posto, non è in contrasto con l'altro e bastano i punti; tolto, se i punti che dava non sono già spesi
func can_toggle(t: int) -> bool:
	var cost: int = Main.TRAIT_COST.get(t, 0)
	if t in ruler.traits:
		return points_left() + cost >= 0
	return ruler.traits.size() < Main.RULER_TRAITS and not ruler.traits.any(func(o): return Main.clash(o, t)) \
		and points_left() - cost >= 0


func toggle_trait(t: int) -> void:
	if can_toggle(t):
		if t in ruler.traits:
			ruler.traits.erase(t)
		else:
			ruler.traits.append(t)
	refresh()


func points_left() -> int:
	return Main.RULER_POINTS - ruler.skills.reduce(func(sum, level): return sum + level, 0) \
		- ruler.traits.reduce(func(sum, t): return sum + Main.TRAIT_COST.get(t, 0), 0)


func can_spend(s: int, d: int) -> bool:
	var level: int = ruler.skills[s] + d
	return level >= 0 and level <= Main.RULER_SKILL_CAP and points_left() - d >= 0


func spend(s: int, d: int) -> void:
	if can_spend(s, d):
		ruler.skills[s] += d
	refresh()


# dai campi al sovrano; i pulsanti premuti e quelli che si possono premere. Avanti: la casata vuole nome e colonia,
# il sovrano il nome
func refresh() -> void:
	ruler.last_name = house.text.strip_edges()
	ruler.first_name = first.text.strip_edges()
	ruler.nickname = nick.text.strip_edges()
	points.text = tr("Skill points left: %d / %d") % [points_left(), Main.RULER_POINTS]
	for s in levels:
		levels[s][0].text = str(ruler.skills[s])
		levels[s][1].disabled = not can_spend(s, -1)
		levels[s][2].disabled = not can_spend(s, 1)
	for t in trait_buttons:
		trait_buttons[t].disabled = not can_toggle(t)
	for entry in synced:
		entry[0].set_pressed_no_signal(entry[1].call() == entry[2])
	forward.disabled = ruler.last_name == "" or colony.text.strip_edges() == "" if page == 0 else ruler.first_name == ""


func make_setup() -> Dictionary:
	var made := {}
	for key in CHOSEN:
		made[key] = ruler.get(key)
	return {"colony": colony.text.strip_edges(), "arms": arms, "ruler": made}.duplicate(true)


func begin() -> void:
	Main.setup = make_setup()
	Main.SAVES.founding = Main.SAVES.create(Main.setup["colony"])  # la cartella dei salvataggi della nuova colonia
	get_tree().change_scene_to_file("res://main.tscn")
