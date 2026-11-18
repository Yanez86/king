# Il meteo in alto, accanto alla data (vedi main.forecast_strip): icona e gradi di adesso, le icone delle prossime quattro
# fasce di sei ore e quelle degli avvisi (ondata di freddo, gelata, acqua gelata, temporale). Cliccata apre il pannello
# delle previsioni: 24 ore, un giorno in più con la ricerca Astronomia. Legge tutto da main.atmosphere.
extends HBoxContainer

enum Icon { SUN, MOON, RAIN, SNOW, FOG, STORM, COLD, FROST, ICE }  # colonne di SHEET
const SHEET := preload("res://art/weather.png")
const CLOSE := preload("res://art/icon_cancel.png")
const NAMES := ["Clear", "Rain", "Snow", "Fog", "Storm"]  # per atmosphere.Weather
const SLOT := 0.25         # una fascia: sei ore, in giorni come main.clock
const ICON_SIZE := Vector2(24, 24)

var main
var now_icon: TextureRect
var now_temp := Label.new()
var next_icons: Array[TextureRect] = []
var alert_icons: Array[TextureRect] = []
var panel := PanelContainer.new()
var rows := VBoxContainer.new()
var shown_hour := -1       # l'ora per cui è fatto il pannello: cambiata, si rifà
var frames: Array[AtlasTexture] = []  # le icone di SHEET, per Icon


func _ready() -> void:
	for i in Icon.size():
		frames.append(AtlasTexture.new())
		frames[i].atlas = SHEET
		frames[i].region = Rect2(i * 16, 0, 16, 16)
	mouse_filter = MOUSE_FILTER_STOP
	add_theme_constant_override("separation", 2)
	now_icon = icon(Icon.SUN)
	add_child(now_icon)
	add_child(now_temp)
	var then := Label.new()
	then.text = " >"
	add_child(then)
	for i in 4:
		next_icons.append(icon(Icon.SUN))
		add_child(next_icons[-1])
	for i in 4:
		alert_icons.append(icon(Icon.COLD))
		add_child(alert_icons[-1])
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			toggle())
	# il pannello: come le altre finestre, titolo e X; si trascina
	panel.visible = false
	panel.custom_minimum_size = Vector2(380, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "Weather"
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var close := Button.new()
	close.icon = CLOSE
	close.custom_minimum_size = Vector2(32, 32)
	close.expand_icon = true
	close.focus_mode = FOCUS_NONE
	close.tooltip_text = "Close"
	close.pressed.connect(panel.hide)
	head.add_child(title)
	head.add_child(close)
	box.add_child(head)
	box.add_child(rows)
	panel.add_child(box)
	panel.gui_input.connect(main.drag_window.bind(panel))
	main.get_node("HUD").add_child(panel)


func _process(_delta: float) -> void:
	var sky = main.atmosphere
	now_icon.texture = frame(icon_for(sky.forecast, main.clock))
	now_temp.text = "%d°C" % roundi(sky.temperature())
	var slot := floorf(main.clock / SLOT) * SLOT
	for i in 4:
		var at := slot + (i + 1.5) * SLOT  # a metà della fascia
		next_icons[i].texture = frame(icon_for(sky.weather_at(at), at))
	var warnings := alerts()
	for i in alert_icons.size():
		alert_icons[i].visible = i < warnings.size()
		if i < warnings.size():
			alert_icons[i].texture = frame(warnings[i][0])
	var tip := "Weather: click for the forecast"
	for w in warnings:
		tip += "\n" + w[1]
	if tooltip_text != tip:
		tooltip_text = tip
	if panel.visible and int(main.clock * 24) != shown_hour:
		fill()


func toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		fill()
		panel.reset_size()
		var at := global_position + Vector2(0, size.y + 8)  # sotto la striscia, dentro lo schermo
		panel.position = at.clamp(Vector2.ZERO, get_viewport_rect().size - panel.size)
		panel.move_to_front()


# Le previsioni: adesso, poi una riga per fascia di sei ore fino a horizon() (tempo e gradi più bassi e più alti), gli avvisi
func fill() -> void:
	shown_hour = int(main.clock * 24)
	var sky = main.atmosphere
	for child in rows.get_children():
		child.queue_free()
	rows.add_child(row(icon_for(sky.forecast, main.clock), "Now", NAMES[sky.forecast], "%d°C" % roundi(sky.temperature())))
	var slot := floorf(main.clock / SLOT) * SLOT
	for i in range(1, roundi(horizon() / SLOT) + 1):
		var from := slot + i * SLOT
		var temps := range(7).map(func(h): return sky.forecast_temperature(from + h / 24.0))
		var w: int = sky.weather_at(from + SLOT / 2)
		var hour := roundi(fposmod(from, 1.0) * 24)
		rows.add_child(row(icon_for(w, from + SLOT / 2), "%s %02d-%02d" % [day_word(from), hour, hour + 6], NAMES[w],
			"%d / %d°C" % [roundi(temps.min()), roundi(temps.max())]))
	rows.add_child(HSeparator.new())
	var warnings := alerts()
	for w in warnings:
		rows.add_child(row(w[0], w[1], "", ""))
	if warnings.is_empty():
		rows.add_child(row(-1, "No warnings", "", ""))
	if not main.researched.has(main.Tech.ASTRONOMY):
		var hint := Label.new()
		hint.text = "Research Astronomy to see one more day."
		hint.modulate = Color(1, 1, 1, 0.6)
		rows.add_child(hint)
	panel.reset_size()


# Avvisi fino a horizon(): [Icon, testo]. Ondata di freddo (in corso o in arrivo), gelata (la prima ora sotto lo zero e
# il freddo più forte), acqua gelata o che gela o sgela, temporale
func alerts() -> Array:
	var sky = main.atmosphere
	var out := []
	var hours := roundi(horizon() * 24)
	for w in sky.waves:
		if w[0] <= main.clock and main.clock < w[1]:
			out.append([Icon.COLD, "Cold wave until %s" % when(w[1])])
		elif w[0] > main.clock and w[0] < main.clock + horizon():
			out.append([Icon.COLD, "Cold wave in %d h" % ceili((w[0] - main.clock) * 24)])
	var temps := range(hours + 1).map(func(h): return sky.temperature() if h == 0 else sky.forecast_temperature(main.clock + h / 24.0))
	var first := -1  # la prima ora sotto lo zero
	for h in temps.size():
		if temps[h] < 0:
			first = h
			break
	if first == 0:
		out.append([Icon.FROST, "Frost: below zero now, down to %d°C" % roundi(temps.min())])
	elif first > 0:
		out.append([Icon.FROST, "Frost in %d h, down to %d°C" % [first, roundi(temps.min())]])
	if sky.frozen:
		out.append([Icon.ICE, "Water frozen: walkable, no fishing" if sky.ice >= 1.0 or sky.temperature() <= 0
			else "Ice thawing: it still holds"])
	elif sky.ice > 0:
		out.append([Icon.ICE, "Ice forming on the water" if sky.temperature() < 0 else "Thin ice melting"])
	var storm := range(hours + 1).filter(func(h): return sky.weather_at(main.clock + h / 24.0) == sky.Weather.STORM)
	if not storm.is_empty():
		out.append([Icon.STORM, "Storm now" if storm[0] == 0 else "Storm in %d h" % storm[0]])
	return out


# giorni di previsioni: uno, due con Astronomia
func horizon() -> float:
	return 2.0 if main.researched.has(main.Tech.ASTRONOMY) else 1.0


# icona del tempo `w` al momento `at`: il sereno di notte è la luna
func icon_for(w: int, at: float) -> int:
	if w == main.atmosphere.Weather.CLEAR:
		return Icon.SUN if fposmod(at, 1.0) >= 0.25 and fposmod(at, 1.0) < 0.75 else Icon.MOON
	return w + 1  # RAIN, SNOW, FOG, STORM vengono subito dopo il sole e la luna


func day_word(at: float) -> String:
	return ["Today", "Tomorrow", "In 2 days"][clampi(int(at) - int(main.clock), 0, 2)]


func when(at: float) -> String:
	return "%s %02d:00" % [main.date(int(at)), int(fposmod(at, 1.0) * 24)]


func frame(i: int) -> AtlasTexture:
	return frames[i]


func icon(i: int) -> TextureRect:
	return main.ui_icon(SHEET, Rect2(i * 16, 0, 16, 16), ICON_SIZE)


# riga del pannello: icona (-1 nessuna), poi i testi in colonna (quelli vuoti no)
func row(i: int, what: String, weather_name: String, temps: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_child(icon(i) if i >= 0 else Control.new())
	line.get_child(0).custom_minimum_size = ICON_SIZE
	for t in [[what, 170.0], [weather_name, 70.0], [temps, 90.0]].filter(func(t): return t[0] != ""):
		var label := Label.new()
		label.text = t[0]
		label.custom_minimum_size.x = t[1]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(label)
	return line
