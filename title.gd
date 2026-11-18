extends Control
# Schermata del titolo: la scena di notte animata, il logo che scende al suo posto e il menu sul prato a sinistra.
# Scena e logo li disegna tools/make_splash.py: art/title_scene.png ha FRAMES fotogrammi 320x180 uno sotto l'altro,
# art/title_logo.png è il logo su fondo trasparente; qui sono mostrati a PIXEL volte, cioè a 1280x720.

const FRAMES := 16          # come TITLE_FRAMES in tools/make_splash.py
const FRAME_TIME := 0.15    # secondi per fotogramma, come il fuoco in gioco (ANIMATED in main.gd)
const PIXEL := 4            # pixel dello schermo per pixel della scena
const LOGO_DROP := 6        # pixel della scena: da quanto più in alto scende il logo all'inizio
const ARROW_GAP := 7        # pixel della scena tra la freccia e la voce del menu
const SAVES := preload("res://saves.gd")
const SAVE_LIST := preload("res://save_list.gd")

@onready var scene_frame: AtlasTexture = $Stage/Scene.texture
@onready var logo: TextureRect = $Stage/Logo
@onready var menu: VBoxContainer = $Stage/Menu
@onready var arrow: TextureRect = $Stage/Arrow
@onready var fade: ColorRect = $Fade
@onready var fullscreen: Button = $Stage/Menu/Fullscreen

var time := 0.0
var frame := 0
var leaving := false  # partita scelta: si sta andando al nero, il menu non risponde più
var saves := PanelContainer.new()  # Colonies: l'elenco delle colonie al centro, sopra la scena (vedi show_saves)
var save_list := SAVE_LIST.new()


func _ready() -> void:
	var config := ConfigFile.new()  # la lingua scelta nelle opzioni della partita (vedi set_language in main.gd)
	if config.load("user://settings.cfg") == OK and config.has_section_key("game", "language"):
		TranslationServer.set_locale(config.get_value("game", "language"))
	Engine.time_scale = 1.0  # dal menù delle opzioni della partita si arriva qui col gioco fermo
	$Stage/Menu/NewGame.pressed.connect(new_game)
	# con delle colonie salvate: Continue riprende quella giocata più di recente, Colonies le elenca
	var any := not SAVES.list().is_empty()
	$Stage/Menu/Continue.visible = any
	$Stage/Menu/Load.visible = any
	$Stage/Menu/Continue.pressed.connect(continue_game)
	$Stage/Menu/Load.pressed.connect(show_saves.bind(true))
	saves.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	saves.grow_horizontal = Control.GROW_DIRECTION_BOTH
	saves.grow_vertical = Control.GROW_DIRECTION_BOTH
	saves.hide()
	saves.add_child(save_list)
	add_child(saves)
	move_child(saves, fade.get_index())  # sotto il nero dell'uscita
	save_list.chosen.connect(play)
	save_list.closed.connect(show_saves.bind(false))
	fullscreen.pressed.connect(toggle_fullscreen)
	$Stage/Menu/Quit.pressed.connect(get_tree().quit)
	for button: Button in menu.get_children():
		button.mouse_entered.connect(button.grab_focus)  # mouse e tastiera muovono la stessa freccia
		button.focus_entered.connect(point_at.bind(button))
	fullscreen.text = fullscreen_text()
	# entrata: dal nero compare la scena, il logo scende al suo posto a scatti di un pixel, poi arriva il menu
	menu.modulate.a = 0.0
	logo.modulate.a = 0.0
	arrow.hide()
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.8)
	tween.parallel().tween_property(logo, "modulate:a", 1.0, 0.8)
	tween.parallel().tween_method(drop_logo, float(LOGO_DROP), 0.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu, "modulate:a", 1.0, 0.4)
	var first: Button = $Stage/Menu/Continue if any else $Stage/Menu/NewGame
	tween.tween_callback(first.grab_focus)


func _process(delta: float) -> void:
	time += delta
	var f := int(time / FRAME_TIME) % FRAMES
	if f != frame:
		frame = f
		scene_frame.region.position.y = f * scene_frame.region.size.y
	arrow.position.x = menu.position.x - ARROW_GAP * PIXEL + (PIXEL if int(time / 0.4) % 2 else 0)  # dondola


func drop_logo(height: float) -> void:
	logo.position.y = -roundi(height) * PIXEL


func point_at(button: Button) -> void:
	arrow.show()
	arrow.position.y = snappedf(menu.position.y + button.position.y + (button.size.y - arrow.size.y) / 2, PIXEL)


func new_game() -> void:
	if not leaving:
		leave("res://creation.tscn")  # poi la partita


# la colonia giocata più di recente; se non si legge, l'elenco (lo dice lui)
func continue_game() -> void:
	var all := SAVES.list()
	if leaving or all.is_empty():
		return
	var state := SAVES.read_colony(all[0]["folder"])
	if state.is_empty():
		show_saves(true)
	else:
		play(state)


# la partita salvata: main.gd la prende in _ready (vedi SAVES.pending)
func play(state: Dictionary) -> void:
	if leaving:
		return
	SAVES.pending = state
	leave("res://main.tscn")


# al nero, poi la scena
func leave(scene: String) -> void:
	leaving = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5)
	tween.tween_callback(get_tree().change_scene_to_file.bind(scene))


# l'elenco delle colonie al posto del menu, o di nuovo il menu (Back, Esc)
func show_saves(on: bool) -> void:
	if leaving:
		return
	saves.visible = on
	menu.visible = not on
	arrow.visible = not on
	if on:
		save_list.refresh()
		save_list.list.grab_focus()
	else:
		var any := not SAVES.list().is_empty()  # magari li ha cancellati tutti
		$Stage/Menu/Continue.visible = any
		$Stage/Menu/Load.visible = any
		var back: Button = $Stage/Menu/Load if any else $Stage/Menu/NewGame
		back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if saves.visible and event.is_action_pressed("ui_cancel"):
		show_saves(false)
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen.text = "Fullscreen" if full else "Window"  # il cambio di modo può arrivare dopo: non rileggerlo


# dice dove si va, non dove si è
static func fullscreen_text() -> String:
	return "Window" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "Fullscreen"
