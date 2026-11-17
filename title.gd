extends Control
# Schermata del titolo: la scena di notte animata, il logo che scende al suo posto e il menu sul prato a sinistra.
# Scena e logo li disegna tools/make_splash.py: art/title_scene.png ha FRAMES fotogrammi 320x180 uno sotto l'altro,
# art/title_logo.png è il logo su fondo trasparente; qui sono mostrati a PIXEL volte, cioè a 1280x720.

const FRAMES := 16          # come TITLE_FRAMES in tools/make_splash.py
const FRAME_TIME := 0.15    # secondi per fotogramma, come il fuoco in gioco (ANIMATED in main.gd)
const PIXEL := 4            # pixel dello schermo per pixel della scena
const LOGO_DROP := 6        # pixel della scena: da quanto più in alto scende il logo all'inizio
const ARROW_GAP := 7        # pixel della scena tra la freccia e la voce del menu

@onready var scene_frame: AtlasTexture = $Stage/Scene.texture
@onready var logo: TextureRect = $Stage/Logo
@onready var menu: VBoxContainer = $Stage/Menu
@onready var arrow: TextureRect = $Stage/Arrow
@onready var fade: ColorRect = $Fade
@onready var fullscreen: Button = $Stage/Menu/Fullscreen

var time := 0.0
var frame := 0
var leaving := false  # partita scelta: si sta andando al nero, il menu non risponde più


func _ready() -> void:
	$Stage/Menu/NewGame.pressed.connect(new_game)
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
	tween.tween_callback($Stage/Menu/NewGame.grab_focus)


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
	if leaving:
		return
	leaving = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5)
	tween.tween_callback(get_tree().change_scene_to_file.bind("res://creation.tscn"))  # poi la partita


func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen.text = "Fullscreen" if full else "Window"  # il cambio di modo può arrivare dopo: non rileggerlo


# come il tasto in alto nella partita: dice dove si va, non dove si è
static func fullscreen_text() -> String:
	return "Window" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "Fullscreen"
