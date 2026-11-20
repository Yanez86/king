# I suggerimenti annidati, come in Crusader Kings (docs/TECH.md): col mouse fermo su una cosa compare il suo
# suggerimento, che dopo un po' si blocca (una barretta d'oro si riempie); bloccato ci si entra col mouse, e i nomi in oro
# (i collegamenti, [url=tipo:NOME] nel testo) aprono il loro suggerimento accanto, e così via. Un suggerimento si chiude
# quando il mouse è stato per GRACE secondi fuori da lui, da quelli dopo e da quello che l'ha aperto.
# Il contenuto lo dà `content` (chiave -> [titolo, testo BBCode], vedi glossary.gd). Le cose si registrano con attach
# (con una nota in fondo, per quello che cambia: le ore che mancano a una condizione), i testi coi collegamenti fuori dai
# suggerimenti (la wiki) con attach_text: lì il collegamento fa da cosa. Un clic su un collegamento dice clicked.
# I tempi sono quelli veri (Time), non quelli del gioco: con la pausa Engine.time_scale è 0. Le prove chiamano update
# con un tempo e un mouse loro.
extends CanvasLayer

signal clicked(key: String)  # clic su un collegamento: in un suggerimento o in un testo di attach_text

const SHOW_DELAY := 0.4     # secondi col mouse fermo sulla cosa prima che compaia
const LINK_DELAY := 0.3     # secondi su un collegamento prima che si apra il suo
const LOCK_TIME := 0.8      # secondi dopo che è comparso: poi si blocca
const GRACE := 0.25         # secondi fuori prima di chiudersi
const WIDTH := 440.0        # pixel: la larghezza del testo
const GAP := 4.0            # pixel tra un suggerimento e quello dopo
const NEAR := Vector2(18, 20)  # dal mouse, il primo
const LOCK_COLOR := Color("e8c34a")
const WAIT_COLOR := Color(0.91, 0.76, 0.29, 0.45)

var content: Callable       # chiave -> [titolo, testo]; [] se la chiave non dice niente
var levels: Array = []      # i suggerimenti aperti, dal primo: Level
var source: Control = null  # la cosa col mouse sopra (vedi attach), o il testo col collegamento sotto il mouse
var source_key := ""        # in quel testo, il collegamento (vedi attach_text)
var source_since := 0.0
var link_label: RichTextLabel = null  # il collegamento col mouse sopra: in quale testo, quale chiave, da quando
var link_key := ""
var link_since := 0.0
var manual := false         # le prove muovono loro tempo e mouse (vedi update)


class Level:
	var key := ""
	var panel: PanelContainer
	var label: RichTextLabel
	var bar: ColorRect
	var born := 0.0
	var locked := false
	var out_since := -1.0   # da quando il mouse è fuori; -1 dentro


func _ready() -> void:
	layer = 100  # sopra a tutto


func _process(_delta: float) -> void:
	if not manual:
		update(Time.get_ticks_msec() / 1000.0, get_viewport().get_mouse_position())


# `control` mostra il suggerimento di `key` (che può cambiare: si legge quando compare), con `note` in fondo; il
# suggerimento di Godot no. Si può richiamare a ogni aggiornamento: si collega una volta sola
func attach(control: Control, key: String, note := "") -> void:
	control.tooltip_text = ""
	control.set_meta("tip", key)
	control.set_meta("tip_note", note)
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		control.mouse_filter = Control.MOUSE_FILTER_PASS
	if not control.mouse_entered.is_connected(_entered):
		control.mouse_entered.connect(_entered.bind(control))
		control.mouse_exited.connect(_exited.bind(control))


func _entered(control: Control) -> void:
	source = control
	source_since = now()


# un testo coi collegamenti (BBCode [url=chiave]) fuori dai suggerimenti: col mouse su un collegamento si apre il suo
# suggerimento come per una cosa attaccata; col clic, clicked
func attach_text(label: RichTextLabel) -> void:
	label.set_meta("tip_text", true)
	label.meta_hover_started.connect(func(meta):
		source = label
		source_key = str(meta)
		source_since = now())
	label.meta_hover_ended.connect(func(_meta):
		if source == label:
			source = null)
	label.meta_clicked.connect(func(meta):
		close_all()
		clicked.emit(str(meta)))


# la chiave della cosa sotto il mouse: quella attaccata, o il collegamento del testo
func source_tip() -> String:
	if source == null or not is_instance_valid(source):
		return ""
	return source_key if source.has_meta("tip_text") else str(source.get_meta("tip", ""))


func _exited(control: Control) -> void:
	if source == control:
		source = null


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


# Un passo: al tempo `t`, col mouse in `mouse`. Prima chiude quello che il mouse ha lasciato, poi blocca chi è ora,
# poi apre il primo (dalla cosa) o quello dopo (da un collegamento)
func update(t: float, mouse: Vector2) -> void:
	var touched := -1  # l'ultimo livello che il mouse tocca: lui, o quello che l'ha aperto
	for i in levels.size():
		var lv: Level = levels[i]
		var on_panel := lv.locked and lv.panel.get_global_rect().has_point(mouse)
		var on_source: bool = (i == 0 and is_over(source, mouse) and source_tip() == lv.key) \
			or (i > 0 and link_label == levels[i - 1].label and link_key == lv.key)
		if on_panel or on_source:
			touched = i
	for i in range(levels.size() - 1, touched, -1):
		var lv: Level = levels[i]
		if lv.out_since < 0:
			lv.out_since = t
		elif t - lv.out_since >= GRACE:
			close_from(i)
	for i in range(mini(touched + 1, levels.size())):
		levels[i].out_since = -1.0
	for lv in levels:
		var part := clampf((t - lv.born) / LOCK_TIME, 0.0, 1.0)
		lv.bar.custom_minimum_size.x = floorf(lv.bar.get_parent().size.x * part)  # nel contenitore: la misura minima, non size
		if part >= 1.0 and not lv.locked:
			lock(lv)
	if is_over(source, mouse) and source_tip() != "" and t - source_since >= SHOW_DELAY \
			and (levels.is_empty() or levels[0].key != source_tip()):
		close_from(0)
		open(source_tip(), t, null, mouse, str(source.get_meta("tip_note", "")))
	if link_label != null:
		var at := levels.find_custom(func(lv): return lv.label == link_label)
		if at >= 0 and levels[at].locked and t - link_since >= LINK_DELAY \
				and (levels.size() == at + 1 or levels[at + 1].key != link_key):
			close_from(at + 1)
			open(link_key, t, levels[at], mouse)


func is_over(control: Control, mouse: Vector2) -> bool:
	return control != null and is_instance_valid(control) and control.is_visible_in_tree() \
		and control.get_global_rect().has_point(mouse)


# Apre il suggerimento di `key`, con `note` in fondo: il primo vicino al mouse (sotto, o sopra se sotto non ci sta),
# gli altri accanto a `parent` all'altezza del mouse
func open(key: String, t: float, parent: Level, mouse: Vector2, note := "") -> void:
	var said: Array = content.call(key) if content.is_valid() else []
	if said.is_empty():
		return
	var lv := Level.new()
	lv.key = key
	lv.born = t
	lv.panel = PanelContainer.new()
	lv.panel.theme_type_variation = "TooltipPanel"
	lv.panel.add_theme_stylebox_override("panel", solid(lv.panel.get_theme_stylebox("panel")))
	lv.panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # finché non è bloccato il mouse ci passa attraverso
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv.bar = ColorRect.new()
	lv.bar.color = WAIT_COLOR
	lv.bar.custom_minimum_size = Vector2(0, 2)
	lv.bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lv.bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.text = said[0]
	title.add_theme_color_override("font_color", LOCK_COLOR)
	lv.label = RichTextLabel.new()
	lv.label.bbcode_enabled = true
	lv.label.fit_content = true
	lv.label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.label.custom_minimum_size.x = WIDTH
	lv.label.scroll_active = false
	lv.label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv.label.text = said[1] + ("\n\n" + note if note != "" else "")
	lv.label.meta_hover_started.connect(func(meta):
		link_label = lv.label
		link_key = str(meta)
		link_since = now() if not manual else link_since)
	lv.label.meta_hover_ended.connect(func(_meta):
		if link_label == lv.label:
			link_label = null)
	lv.label.meta_clicked.connect(func(meta):
		close_all()
		clicked.emit(str(meta)))
	box.add_child(lv.bar)
	box.add_child(title)
	box.add_child(lv.label)
	lv.panel.add_child(box)
	add_child(lv.panel)
	lv.panel.reset_size()
	var screen := get_viewport().get_visible_rect().size
	var size := lv.panel.get_combined_minimum_size()
	var at := mouse + NEAR
	if parent != null:
		var p := parent.panel.get_global_rect()
		at = Vector2(p.end.x + GAP, mouse.y - 12)
		if at.x + size.x > screen.x:  # a destra non ci sta: a sinistra
			at.x = p.position.x - GAP - size.x
	else:
		if at.x + size.x > screen.x:
			at.x = mouse.x - NEAR.x - size.x
		if at.y + size.y > screen.y:  # sotto non ci sta (la barra in basso): sopra, senza coprire la cosa
			at.y = mouse.y - NEAR.y - size.y
	at.x = clampf(at.x, 0.0, maxf(screen.x - size.x, 0.0))
	at.y = clampf(at.y, 0.0, maxf(screen.y - size.y, 0.0))
	lv.panel.position = at
	levels.append(lv)


# la cornice del tema, ma piena (quella delle finestre lascia intravedere sotto: sopra una finestra non si leggerebbe).
# Fatta una volta
var solid_frame: StyleBox = null


func solid(frame: StyleBox) -> StyleBox:
	if solid_frame == null:
		solid_frame = frame.duplicate()
		if solid_frame is StyleBoxFlat:
			solid_frame.bg_color.a = 1.0
		elif solid_frame is StyleBoxTexture and solid_frame.texture != null and solid_frame.texture.get_image() != null:
			var image: Image = solid_frame.texture.get_image()
			image.decompress()
			for y in image.get_height():
				for x in image.get_width():
					var c := image.get_pixel(x, y)
					if c.a > 0.0:
						image.set_pixel(x, y, Color(c, 1.0))
			solid_frame.texture = ImageTexture.create_from_image(image)
	return solid_frame


# bloccato: il mouse ci può entrare, i collegamenti rispondono, la barretta d'oro piena
func lock(lv: Level) -> void:
	lv.locked = true
	lv.panel.mouse_filter = Control.MOUSE_FILTER_STOP
	lv.label.mouse_filter = Control.MOUSE_FILTER_PASS
	lv.bar.color = LOCK_COLOR


# chiude il suggerimento `i` e quelli dopo
func close_from(i: int) -> void:
	while levels.size() > i:
		var lv: Level = levels.pop_back()
		if link_label == lv.label:
			link_label = null
		lv.panel.queue_free()


func close_all() -> void:
	close_from(0)


# le prove: il mouse va su un collegamento (`key`) del suggerimento `i`, al tempo `t`
func hover_link(i: int, key: String, t: float) -> void:
	link_label = levels[i].label
	link_key = key
	link_since = t
