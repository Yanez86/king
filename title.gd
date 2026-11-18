extends Control
# Schermata del titolo: la scena di notte animata, il logo che scende al suo posto e il menu sul prato a sinistra.
# Scena e logo li disegna tools/make_splash.py: art/title_scene.png ha FRAMES fotogrammi 320x180 uno sotto l'altro,
# art/title_logo.png è il logo su fondo trasparente; qui sono mostrati a PIXEL volte, cioè a 1280x720.
# Le colonie salvate (vedi saves.gd): "Continue" riprende la più recente, "Colonies" le elenca tutte; da lì si
# riprende quella scelta o la si cancella (la X, premuta due volte).

const Saves := preload("res://saves.gd")
const MAIN := preload("res://main.tscn")
const FRAMES := 16          # come TITLE_FRAMES in tools/make_splash.py
const FRAME_TIME := 0.15    # secondi per fotogramma, come il fuoco in gioco (ANIMATED in main.gd)
const PIXEL := 4            # pixel dello schermo per pixel della scena
const LOGO_DROP := 6        # pixel della scena: da quanto più in alto scende il logo all'inizio
const ARROW_GAP := 7        # pixel della scena tra la freccia e la voce scelta
const DETAILS := Color("a8a49a")   # giorno e coloni sotto il nome di una colonia
const WARNING := Color("d84a3a")   # "premi ancora per cancellare"
const DELETE_ICON := preload("res://art/icon_cancel.png")

@onready var scene_frame: AtlasTexture = $Stage/Scene.texture
@onready var logo: TextureRect = $Stage/Logo
@onready var menu: VBoxContainer = $Stage/Menu
@onready var list_box: VBoxContainer = $Stage/Colonies   # l'elenco delle colonie, al posto del menu
@onready var entries: VBoxContainer = $Stage/Colonies/Scroll/Entries
@onready var arrow: TextureRect = $Stage/Arrow
@onready var fade: ColorRect = $Fade
@onready var fullscreen: Button = $Stage/Menu/Fullscreen

var time := 0.0
var frame := 0
var leaving := false  # partita scelta: si sta andando al nero, il menu non risponde più
var colonies := []    # [{folder, info}], la più recente per prima (vedi Saves.colonies)
var arrow_x := 0.0
var armed: Button     # la X premuta una volta: alla seconda cancella


func _ready() -> void:
	Engine.time_scale = 1.0  # dalla partita si può tornare in pausa o a 3x: qui il fuoco va alla sua velocità
	$Stage/Menu/Continue.pressed.connect(func(): start(colonies[0]))
	$Stage/Menu/NewGame.pressed.connect(new_game)
	$Stage/Menu/Colonies.pressed.connect(show_list)
	fullscreen.pressed.connect(toggle_fullscreen)
	$Stage/Menu/Quit.pressed.connect(get_tree().quit)
	$Stage/Colonies/Back.pressed.connect(show_menu)
	for button: Button in menu.get_children() + [$Stage/Colonies/Back]:
		follow(button)
	fullscreen.text = fullscreen_text()
	refresh_colonies()
	list_box.hide()
	# entrata: dal nero compare la scena, il logo scende al suo posto a scatti di un pixel, poi arriva il menu
	menu.modulate.a = 0.0
	logo.modulate.a = 0.0
	arrow.hide()
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.8)
	tween.parallel().tween_property(logo, "modulate:a", 1.0, 0.8)
	tween.parallel().tween_method(drop_logo, float(LOGO_DROP), 0.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu, "modulate:a", 1.0, 0.4)
	tween.tween_callback(first_button(menu).grab_focus)


func _process(delta: float) -> void:
	time += delta
	var f := int(time / FRAME_TIME) % FRAMES
	if f != frame:
		frame = f
		scene_frame.region.position.y = f * scene_frame.region.size.y
	arrow.position.x = arrow_x + (PIXEL if int(time / 0.4) % 2 else 0)  # dondola


func _unhandled_input(event: InputEvent) -> void:
	if list_box.visible and event.is_action_pressed("ui_cancel"):
		show_menu()


# mouse e tastiera muovono la stessa freccia
func follow(button: Button) -> void:
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(point_at.bind(button))


func first_button(box: Control) -> Button:
	return box.find_children("*", "Button", true, false).filter(func(b): return b.visible)[0]


func drop_logo(height: float) -> void:
	logo.position.y = -roundi(height) * PIXEL


func point_at(button: Button) -> void:
	if armed and button != armed:
		disarm()
	arrow.visible = not button.has_meta("delete")  # la X si accende da sola: la freccia coprirebbe il nome
	if not arrow.visible:
		return
	var at: Vector2 = button.global_position - $Stage.global_position
	arrow_x = at.x - ARROW_GAP * PIXEL
	arrow.position.y = snappedf(at.y + (button.size.y - arrow.size.y) / 2, PIXEL)


# "Continue" e "Colonies" ci sono solo se c'è almeno una colonia salvata
func refresh_colonies() -> void:
	colonies = Saves.colonies()
	$Stage/Menu/Continue.visible = not colonies.is_empty()
	$Stage/Menu/Colonies.visible = not colonies.is_empty()
	for entry in entries.get_children():  # anche quella della X appena premuta: via a fine fotogramma
		entries.remove_child(entry)
		entry.queue_free()
	for colony in colonies:
		entries.add_child(make_entry(colony))


# Una colonia nell'elenco: il nome (la riprende), la X (la cancella), sotto giorno e coloni.
func make_entry(colony: Dictionary) -> Control:
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var open := Button.new()
	open.text = colony.info.name
	open.alignment = HORIZONTAL_ALIGNMENT_LEFT
	open.pressed.connect(start.bind(colony))
	var delete := Button.new()
	delete.icon = DELETE_ICON
	delete.expand_icon = true
	delete.custom_minimum_size = Vector2(16, 16) * 2
	delete.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	delete.tooltip_text = "Delete this colony"
	delete.set_meta("delete", true)
	delete.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 0.4))  # si accende col mouse o la tastiera
	for state in ["icon_focus_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		delete.add_theme_color_override(state, Color.WHITE)
	delete.pressed.connect(press_delete.bind(delete, colony))
	row.add_child(open)
	row.add_child(delete)
	var details := Label.new()
	details.name = "Details"
	var n: int = colony.info.colonists
	details.text = "Day %d, %d colonist%s" % [colony.info.day, n, "" if n == 1 else "s"]
	details.add_theme_font_size_override("font_size", 20)
	details.add_theme_color_override("font_color", DETAILS)
	entry.add_child(row)
	entry.add_child(details)
	for button in [open, delete]:
		follow(button)
	return entry


func show_list() -> void:
	menu.hide()
	list_box.show()
	first_button(list_box).grab_focus()


func show_menu() -> void:
	disarm()
	list_box.hide()
	menu.show()
	if $Stage/Menu/Colonies.visible:
		$Stage/Menu/Colonies.grab_focus()
	else:
		first_button(menu).grab_focus()


# la prima volta chiede conferma sotto il nome, la seconda cancella
func press_delete(button: Button, colony: Dictionary) -> void:
	if armed != button:
		disarm()
		armed = button
		var details: Label = button.get_parent().get_parent().get_node("Details")
		details.text = "Delete forever? Press again"
		details.add_theme_color_override("font_color", WARNING)
		return
	armed = null
	var index := colonies.find(colony)
	Saves.remove(colony.folder)
	refresh_colonies()
	if colonies.is_empty():
		show_menu()
	else:
		first_button(entries.get_child(mini(index, colonies.size() - 1))).grab_focus()


func disarm() -> void:
	if armed == null:
		return
	var entry := armed.get_parent().get_parent()
	var colony: Dictionary = colonies[entry.get_index()]
	var n: int = colony.info.colonists
	var details: Label = entry.get_node("Details")
	details.text = "Day %d, %d colonist%s" % [colony.info.day, n, "" if n == 1 else "s"]
	details.add_theme_color_override("font_color", DETAILS)
	armed = null


func new_game() -> void:
	if leaving:
		return
	var made := Saves.create()  # [cartella, nome]
	var main := MAIN.instantiate()
	main.colony = made[0]
	main.colony_name = made[1]
	go(main)


func start(colony: Dictionary) -> void:
	if leaving:
		return
	var data := Saves.read(colony.folder)
	if data.is_empty():  # rovinata da quando è stato aperto il titolo
		refresh_colonies()
		return
	var main := MAIN.instantiate()
	main.colony = colony.folder
	main.colony_name = colony.info.name
	main.saved = data
	go(main)


# verso il nero, poi la partita: genera la mappa o carica il salvataggio in _ready
func go(main: Node) -> void:
	leaving = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5)
	tween.tween_callback(get_tree().change_scene_to_node.bind(main))


func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen.text = "Fullscreen" if full else "Window"  # il cambio di modo può arrivare dopo: non rileggerlo


# come il tasto in alto nella partita: dice dove si va, non dove si è
static func fullscreen_text() -> String:
	return "Window" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "Fullscreen"
