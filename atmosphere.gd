# Atmosfera, per dare profondità: bloom sulle luci di notte, aloni a terra attorno a lampade e fuochi, braci e fumo
# dei fuochi da campo, lucciole nelle notti calde, ombre delle nuvole di giorno; il meteo: pioggia, neve, nebbia e tempesta.
# A terra la neve si accumula e si scioglie in pozzanghere, che poi si asciugano; anche la pioggia le riempie.
# Il meteo conta anche per i coloni: temperatura (vedi temperature, con le stagioni) e pioggia (raining) tolgono comfort.
# Figlio di main: legge da lì mobili, tetti e ora. F8 accende e spegne tutto, per confrontare; F9 passa al tempo dopo.
extends Node2D

enum Weather { CLEAR, RAIN, SNOW, FOG, STORM }

const WARM := Color(1.0, 0.62, 0.28)          # luce di lampade e fuochi
const SMOKE := Color(0.62, 0.6, 0.66)
const FORGE_SMOKE := Color(0.36, 0.34, 0.4)   # la fornace fa un fumo scuro
const SMOKING_SMOKE := Color(0.5, 0.48, 0.5)  # quello dell'affumicatura, più fitto
const IDLE_SMOKE := 0.45                      # fuoco che nessuno usa: fumo più rado (vedi main.fire_use)
const CLOUD := Color(0.12, 0.1, 0.2)          # ombra delle nuvole, come SHADOW
const MIST := Color(0.78, 0.8, 0.86)          # nebbia
const WIND := Vector2(0.004, 0.0015)          # deriva delle nuvole: mappe di rumore al secondo di gioco
# il prossimo tempo, a caso tra questi: sereno quasi metà delle volte. Col freddo (media del giorno sotto SNOW_BELOW)
# pioggia e temporale vengono giù come neve: d'inverno, e a volte all'inizio della primavera
const FORECAST := [Weather.CLEAR, Weather.CLEAR, Weather.CLEAR, Weather.CLEAR, Weather.RAIN, Weather.RAIN, Weather.RAIN,
	Weather.FOG, Weather.FOG, Weather.STORM]
const SNOW_BELOW := 3.0
# temperatura fuori (vedi temperature): la media del giorno va da YEAR_MEAN + YEAR_SWING a metà estate a YEAR_MEAN -
# YEAR_SWING a metà inverno, senza salti tra le stagioni (main.SEASONS); a mezzogiorno DAY_SWING gradi in più, a
# mezzanotte in meno; più o meno secondo il tempo. Toglie comfort, con la pioggia: vedi main.weather_comfort
const YEAR_MEAN := 11.0                       # estate 23 gradi, inverno -1, all'inizio della primavera 2
const YEAR_SWING := 12.0
const DAY_SWING := 5.0
const WEATHER_TEMP := {Weather.CLEAR: 0.0, Weather.RAIN: -3.0, Weather.SNOW: -2.0, Weather.FOG: -2.0, Weather.STORM: -5.0}
# ondata di freddo: quando la media del giorno è sotto COLD_WAVE_BELOW (da metà autunno al disgelo), ogni giorno con
# probabilità COLD_WAVE_CHANCE arriva e per COLD_WAVE_DAYS giorni fa COLD_WAVE gradi in meno (mezza giornata per arrivare
# e per andarsene, vedi cold_wave); lo dicono la cronaca e la barra in alto
const COLD_WAVE := 10.0
const COLD_WAVE_BELOW := 8.0
const COLD_WAVE_CHANCE := 0.03
const COLD_WAVE_DAYS := Vector2(2, 4)
const PLAN_DAYS := 2.5                        # il tempo è deciso fin qui in anticipo: le previsioni lo leggono (vedi plan)
# acqua: sotto lo zero gela, tanto più in fretta quanto fa freddo (a -5 gradi in un giorno), sopra sgela allo stesso
# modo; piena regge (vedi main.freeze_water: ci si cammina, non si pesca) e torna acqua quando è sciolta fino a THIN_ICE
const FREEZE_HOURS := 120.0                   # ore per grado sotto lo zero
const THIN_ICE := 0.5
const WEATHER_HOURS := Vector2(6, 20)         # quanto dura un tempo, in ore di gioco
const WEATHER_FADE := 8.0                     # secondi di gioco per comparire o sparire
# quanto si copre il cielo: 0 nuvole sparse, 1 tutto coperto
const OVERCAST := {Weather.CLEAR: 0.0, Weather.RAIN: 0.7, Weather.SNOW: 0.5, Weather.FOG: 0.3, Weather.STORM: 1.0}
const SNOW_HOURS := 4.0                       # ore di neve perché copra tutto
const MELT_HOURS := 120.0                     # ore per grado sopra lo 0 perché si sciolga tutta: a 10 gradi 12 ore
const WET_HOURS := 2.0                        # ore di pioggia perché le pozzanghere siano piene
const DRY_HOURS := 8.0                        # ore perché si asciughino
# neve e pozzanghere sul terreno, a pixel interi: la neve si posa prima dove il rumore è alto e il bordo è più scuro;
# le pozzanghere stanno nelle conche (rumore basso), col bordo in alto che riflette il cielo e le gocce che brillano
const GROUND_SHADER := """
shader_type canvas_item;
uniform sampler2D noise : repeat_enable;
uniform sampler2D uncovered : filter_nearest;  // un pixel per casella: bianco dove restano (fuori, non sull'acqua)
uniform vec2 map_size;
uniform float snow;
uniform float wet;
uniform float rain;
uniform float time;
uniform vec4 snow_light : source_color = vec4(0.96, 0.97, 0.98, 1.0);
uniform vec4 snow_shade : source_color = vec4(0.77, 0.81, 0.87, 1.0);
uniform vec4 puddle : source_color = vec4(0.2, 0.38, 0.45, 0.85);
uniform vec4 puddle_light : source_color = vec4(0.62, 0.8, 0.84, 0.9);
varying vec2 world;
void vertex() { world = VERTEX; }
float hollow(vec2 px) { return texture(noise, px / 192.0 + vec2(0.31, 0.67)).r; }
void fragment() {
	vec2 px = floor(world);
	vec4 c = vec4(0.0);
	float s = texture(noise, px / 256.0).r * 0.75 + texture(noise, px / 40.0).r * 0.25;
	float edge = 1.0 - snow * 1.2;
	if (s > edge) {
		c = s > edge + 0.03 && texture(noise, px / 24.0 + 0.5).r > 0.25 ? snow_light : snow_shade;
	} else if (hollow(px) < wet * 0.3) {
		c = hollow(px - vec2(0.0, 1.0)) < wet * 0.3 ? puddle : puddle_light;
		float drop = fract(sin(dot(px, vec2(12.9898, 78.233)) + floor(time * 6.0)) * 43758.5453);
		if (drop > 1.0 - 0.03 * rain) c = puddle_light;
	}
	COLOR = vec4(c.rgb, c.a * texture(uncovered, (px + 0.5) / map_size).r);
}
"""
# rumore che scorre sulla mappa, per nuvole e nebbia: c'è dove il rumore supera `cover`, sfumato per `soft`
const NOISE_SHADER := """
shader_type canvas_item;
uniform sampler2D noise : repeat_enable;
uniform vec2 drift;
uniform vec4 tint : source_color = vec4(0.0);
uniform float cover = 0.52;
uniform float soft = 0.08;
uniform float size = 512.0;  // pixel del mondo prima che il rumore si ripeta
varying vec2 world;
void vertex() { world = VERTEX; }
void fragment() {
	float n = texture(noise, floor(world) / size - drift).r;  // a pixel interi, come il resto
	COLOR = vec4(tint.rgb, smoothstep(cover, cover + soft, n) * tint.a);
}
"""

@onready var main = get_parent()
var reach := {}                   # mobile che fa luce -> raggio dell'alone in pixel
var glow := Node2D.new()          # nel livello delle luci, che la notte non scurisce: si somma a quello che c'è sotto
var env := Environment.new()
var halo := GradientTexture2D.new()
var fires := {}                   # cella del fuoco (main.HEAT) -> [fumo, braci se fa fiamma]
var flames := []                  # i fuochi con le braci: fuoco da campo e focolare (la fornace è chiusa)
var blazes := {}                  # casella di tetto in fiamme (main.burning) -> il suo fumo, nero e fitto
const BLAZE_SMOKE := Color(0.22, 0.2, 0.24)
const BLAZE_REACH := 44.0         # alone di un tetto in fiamme, di notte
var fireflies := CPUParticles2D.new()
var clouds := ShaderMaterial.new()
var map_rect: Rect2
var weather: int = Weather.CLEAR  # il tempo che si vede, o che sta sparendo per lasciare il posto a `forecast`
var forecast: int = Weather.CLEAR
var plan: Array = []              # il tempo deciso per i prossimi giorni: [da, fino a, Weather], in giorni come main.clock
var weather_strength := 0.0       # 0..1: quanto si vede `weather`
var waves: Array = []             # ondate di freddo decise: [da, fino a, già annunciata nella cronaca]
var waves_until := 0              # ultimo giorno per cui si è vista se arrivava un'ondata
var ice := 0.0                    # 0..1: quanto è gelata l'acqua
var frozen := false               # l'acqua regge
var climate := true               # false (nelle prove): niente meteo né stagioni, fuori sempre main.ROOM_TEMP gradi
var flash := 0.0                  # lampo: 1 quando scocca, poi si spegne
var sky_layer := CanvasLayer.new()  # pioggia e neve sullo schermo, non sul mondo: fitte uguale a ogni zoom
var precip := Node2D.new()        # in sky_layer, col colore del cielo: di notte pioggia e neve si scuriscono
var rain := CPUParticles2D.new()
var splashes := CPUParticles2D.new()
var flakes := CPUParticles2D.new()
var lightning := Node2D.new()     # in sky_layer, sopra tutto il mondo: schiarisce anche di notte
var fog := Node2D.new()
var mist := ShaderMaterial.new()
var snow := 0.0                   # 0..1: quanta terra copre la neve, e quanto sono bianchi i tetti (vedi main.draw_roofs)
var wet := 0.0                    # 0..1: quanto sono grandi le pozzanghere
var ground := Node2D.new()        # neve e pozzanghere: sopra il terreno, sotto pavimenti, mucchi e ombre
var ground_fx := ShaderMaterial.new()
var uncovered := ImageTexture.new()
var uncovered_for := {}           # il main.roofed con cui è fatta `uncovered`: quando cambia, si rifà
var uncovered_ice := false        # e se l'acqua era gelata (sul ghiaccio la neve si posa)
var uncovered_stamp := 0          # e main.roof_stamp: i buchi nei tetti


func _ready() -> void:
	reach = {main.Build.LAMP: 26.0, main.Build.LANTERN: 34.0, main.Build.CAMPFIRE: 48.0, main.Build.HEARTH: 36.0}
	flames = [main.Build.CAMPFIRE, main.Build.HEARTH]
	map_rect = Rect2(Vector2.ZERO, Vector2(main.MAP_SIZE * main.TILE))
	plan = [[main.clock, main.clock + 0.25, Weather.CLEAR]]  # la partita comincia col sereno
	waves_until = int(main.clock)                              # e senza ondate di freddo il primo giorno
	# bloom vero: solo sul mondo e sulle luci (livelli 0 e 1), l'interfaccia (livello 2) resta nitida
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = 1
	env.glow_hdr_threshold = 0.7
	env.glow_bloom = 0.0
	for level in 7:  # bagliore stretto, attorno ai pixel accesi: le luci sono piccole
		env.set_glow_level(level, [0.6, 1.0, 1.0, 0.4, 0.0, 0.0, 0.0][level])
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	# alone a gradini, come la pixel art: dal centro al bordo sempre più tenue
	halo.gradient = ramp([Color(1, 1, 1, 0.38), Color(1, 1, 1, 0.24), Color(1, 1, 1, 0.13), Color(1, 1, 1, 0.05),
		Color(1, 1, 1, 0)], [0.0, 0.2, 0.45, 0.7, 1.0])
	halo.gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	halo.fill = GradientTexture2D.FILL_RADIAL
	halo.fill_from = Vector2(0.5, 0.5)
	halo.fill_to = Vector2(0.5, 0.0)
	glow.material = CanvasItemMaterial.new()
	glow.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.draw.connect(draw_halos)
	main.lights.add_child(glow)
	# lucciole: nascono attorno alla telecamera ma restano dove sono nate, pulsando
	fireflies.amount = 60
	fireflies.lifetime = 6.0
	fireflies.local_coords = false
	fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fireflies.spread = 180.0
	fireflies.gravity = Vector2.ZERO
	fireflies.initial_velocity_min = 2.0
	fireflies.initial_velocity_max = 6.0
	fireflies.color = Color(0.8, 1.0, 0.4)
	fireflies.color_ramp = ramp([Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0.15), Color.WHITE, Color(1, 1, 1, 0.1),
		Color.WHITE, Color(1, 1, 1, 0)])
	fireflies.material = glow.material
	glow.add_child(fireflies)
	# ombre delle nuvole (questo nodo) e nebbia: rettangoli grandi quanto la mappa, sopra tutto il mondo
	var noise := NoiseTexture2D.new()
	noise.seamless = true
	noise.noise = FastNoiseLite.new()
	clouds.shader = Shader.new()
	clouds.shader.code = NOISE_SHADER
	clouds.set_shader_parameter("noise", noise)
	material = clouds
	mist.shader = clouds.shader
	mist.set_shader_parameter("noise", noise)
	mist.set_shader_parameter("cover", 0.2)  # quasi dappertutto, a banchi più fitti
	mist.set_shader_parameter("soft", 0.55)
	mist.set_shader_parameter("size", 320.0)
	fog.material = mist
	fog.draw.connect(func(): fog.draw_rect(map_rect, Color.WHITE))
	add_child(fog)
	ground_fx.shader = Shader.new()
	ground_fx.shader.code = GROUND_SHADER
	ground_fx.set_shader_parameter("noise", noise)
	ground_fx.set_shader_parameter("uncovered", uncovered)
	ground_fx.set_shader_parameter("map_size", map_rect.size)
	ground.material = ground_fx
	ground.show_behind_parent = true
	ground.draw.connect(func(): ground.draw_rect(map_rect, Color.WHITE))
	main.add_child(ground)
	main.move_child(ground, main.flat.get_index())
	# pioggia, schizzi a terra e neve: in tutto lo schermo, compaiono sfumando
	sky_layer.layer = 1
	add_child(sky_layer)
	sky_layer.add_child(precip)
	var drop := Image.create_empty(1, 4, false, Image.FORMAT_RGBA8)  # goccia: una riga che sfuma verso l'alto
	for y in 4:
		drop.set_pixel(0, y, Color(1, 1, 1, 0.25 + y * 0.25))
	rain.texture = ImageTexture.create_from_image(drop)
	rain.particle_flag_align_y = true  # la riga segue la direzione in cui cade
	rain.lifetime = 0.45
	rain.spread = 2.0
	rain.initial_velocity_min = 500.0
	rain.initial_velocity_max = 650.0
	rain.scale_amount_min = 2.0
	rain.scale_amount_max = 2.0
	rain.color = Color(0.75, 0.82, 1.0, 0.6)
	rain.color_ramp = ramp([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE], [0.0, 0.2, 1.0])
	splashes.amount = 80
	splashes.lifetime = 0.35
	splashes.initial_velocity_max = 0.0
	splashes.scale_amount_min = 2.0
	splashes.scale_amount_max = 2.0
	splashes.scale_amount_curve = Curve.new()
	splashes.scale_amount_curve.add_point(Vector2(0, 0.5))
	splashes.scale_amount_curve.add_point(Vector2(1, 1.5))
	splashes.color = rain.color
	splashes.color_ramp = ramp([Color.WHITE, Color(1, 1, 1, 0)])
	flakes.amount = 300
	flakes.lifetime = 7.0
	flakes.direction = Vector2(0.25, 1)
	flakes.spread = 30.0
	flakes.initial_velocity_min = 25.0
	flakes.initial_velocity_max = 50.0
	flakes.scale_amount_min = 2.0
	flakes.scale_amount_max = 4.0
	flakes.color_ramp = ramp([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	for p in [rain, splashes, flakes]:
		p.emitting = false
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.gravity = Vector2.ZERO
		precip.add_child(p)
	lightning.material = glow.material
	lightning.draw.connect(func(): lightning.draw_rect(get_viewport_rect(),
		Color(0.75, 0.8, 1.0, 0.8 * flash * flash * (0.6 + 0.4 * sin(flash * 30.0)))))  # tremola mentre si spegne
	sky_layer.add_child(lightning)


func _process(delta: float) -> void:
	var night := darkness()
	var seconds: float = main.clock * main.DAY_LENGTH  # tempo di gioco: in pausa tutto si ferma
	env.glow_enabled = visible and night > 0
	env.glow_intensity = 1.6 * night
	update_weather(delta)
	var cover: float = OVERCAST[weather] * weather_strength
	clouds.set_shader_parameter("drift", WIND * seconds)
	clouds.set_shader_parameter("cover", 0.52 - 0.45 * cover)  # col cielo coperto le nuvole si uniscono
	clouds.set_shader_parameter("tint", Color(CLOUD, (0.3 + 0.15 * cover) * (1.0 - night)))
	mist.set_shader_parameter("drift", WIND * seconds * 0.5)
	mist.set_shader_parameter("tint", Color(MIST, 0.55 * weather_strength if weather == Weather.FOG else 0.0))
	if not is_same(main.roofed, uncovered_for) or frozen != uncovered_ice or main.roof_stamp != uncovered_stamp:
		update_uncovered()
	ground_fx.set_shader_parameter("snow", snow)
	ground_fx.set_shader_parameter("wet", wet)
	ground_fx.set_shader_parameter("rain", weather_strength if rain.emitting else 0.0)
	ground_fx.set_shader_parameter("time", seconds)
	fireflies.emitting = night > 0.6 and weather == Weather.CLEAR and temperature() > 12.0  # le notti calde
	fireflies.position = main.camera.position
	fireflies.emission_rect_extents = get_viewport_rect().size / main.camera.zoom / 2
	for cell in fires.keys():  # fuochi spenti o abbattuti (o un mobile diverso al suo posto)
		var kind: int = main.furniture.get(cell, [-1])[0]
		if not main.HEAT.has(kind) or (fires[cell].size() > 1) != (kind in flames):
			for p in fires[cell]:
				p.queue_free()
			fires.erase(cell)
	for cell in main.furniture:
		var kind: int = main.furniture[cell][0]
		if main.HEAT.has(kind) and not fires.has(cell):
			fires[cell] = light_fire(main.center(cell), kind in flames)
		if fires.has(cell):  # il fumo esce dal comignolo (o dallo sfiatatoio), le braci sotto un tetto non si vedono
			var smoke: CPUParticles2D = fires[cell][0]
			var use: int = main.fire_use(cell)
			smoke.position = main.smoke_at(cell)
			smoke.color = SMOKING_SMOKE if use == 2 else (FORGE_SMOKE if kind == main.Build.FURNACE else SMOKE)
			smoke.modulate.a = IDLE_SMOKE if use == 0 else 1.0
			smoke.scale_amount_max = 7.0 if use == 2 else 5.0
			if fires[cell].size() > 1:
				fires[cell][1].visible = not (main.roofs_shown and main.roofed.has(cell))
	for cell in blazes.keys():  # tetti spenti o bruciati del tutto
		if not main.burning.has(cell):
			blazes[cell].queue_free()
			blazes.erase(cell)
	for cell in main.burning:
		if not blazes.has(cell):
			var smoke := make_smoke(main.center(cell) + Vector2(0, -6))
			smoke.color = BLAZE_SMOKE
			smoke.scale_amount_min = 5.0
			smoke.scale_amount_max = 8.0
			blazes[cell] = smoke
	glow.queue_redraw()


func _draw() -> void:
	draw_rect(map_rect, Color.WHITE)  # lo colora NOISE_SHADER: ombre delle nuvole


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_F8:
		visible = not visible
		glow.visible = visible
		sky_layer.visible = visible
	elif event.keycode == KEY_F9:  # prova: subito il tempo dopo, per un giorno
		plan = [[main.clock, main.clock + 1.0, (weather + 1) % Weather.size()]]
		weather_strength = 0.0


# ogni tanto cambia il tempo: quello di prima sparisce piano, poi compare piano il nuovo
func update_weather(delta: float) -> void:
	if climate:
		plan_ahead()
		forecast = weather_at(main.clock)
		for w in waves:  # arriva un'ondata: lo dice la cronaca
			if w[0] <= main.clock and not w[2]:
				w[2] = true
				main.note(tr("%s: a cold wave. Keep the fires burning.") % main.date(int(main.clock)))
	weather_strength = move_toward(weather_strength, 1.0 if weather == forecast else 0.0, delta / WEATHER_FADE)
	if weather != forecast and weather_strength == 0.0:
		weather = forecast
		var storm := weather == Weather.STORM
		rain.amount = 500 if storm else 250  # ricomincia da capo: si può, adesso non si vede
		rain.direction = Vector2(0.55 if storm else 0.15, 1)
		rain.emitting = storm or weather == Weather.RAIN
		splashes.emitting = rain.emitting
		flakes.emitting = weather == Weather.SNOW
		for p in [rain, splashes, flakes]:  # niente avanzi del tempo di prima mentre compare il nuovo
			p.visible = p.emitting
	var hour: float = main.DAY_LENGTH / 24.0
	if weather == Weather.SNOW:
		snow = minf(snow + delta * weather_strength / (SNOW_HOURS * hour), 1.0)
	elif snow > 0:  # sopra lo 0 si scioglie, e l'acqua finisce nelle pozzanghere; sotto resta
		var melt := minf(snow, delta * maxf(temperature(), 0.0) / (MELT_HOURS * hour))
		snow -= melt
		wet = minf(wet + melt * 2.0, 1.0)
	if rain.emitting:
		wet = minf(wet + delta * weather_strength / (WET_HOURS * hour), 1.0)
	else:
		wet = maxf(wet - delta / (DRY_HOURS * hour), 0.0)
	ice = clampf(ice - delta * temperature() / (FREEZE_HOURS * hour), 0.0, 1.0)
	if frozen != (ice >= 1.0 or (frozen and ice > THIN_ICE)):
		frozen = not frozen
		main.freeze_water(frozen)
	main.water_fx.set_shader_parameter("ice", ice)
	var view := get_viewport_rect()
	for p in [rain, splashes, flakes]:
		p.position = view.get_center()
		p.emission_rect_extents = view.size / 2
	precip.modulate = Color(main.sky.color.lerp(Color.WHITE, 0.35), weather_strength)  # di notte scura, ma si vede
	if weather == Weather.STORM and randf() < delta * weather_strength / 5.0:  # un lampo ogni 5 secondi, circa
		flash = 1.0
	flash = move_toward(flash, 0.0, delta * 2.5)
	lightning.queue_redraw()


# Decide il tempo fino a PLAN_DAYS giorni da adesso: prima le ondate di freddo, un tiro per giorno (non per i giorni
# saltati); poi un tempo a caso da FORECAST dopo l'altro, per WEATHER_HOURS ore, neve invece di pioggia col freddo
func plan_ahead() -> void:
	waves = waves.filter(func(w): return w[1] > main.clock)
	var horizon: float = main.clock + PLAN_DAYS
	waves_until = maxi(waves_until, int(main.clock))
	while waves_until < int(horizon):
		waves_until += 1
		var day := float(waves_until)
		if seasonal(day) < COLD_WAVE_BELOW and cold_wave(day) == 0.0 and randf() < COLD_WAVE_CHANCE:
			waves.append([day, day + randf_range(COLD_WAVE_DAYS.x, COLD_WAVE_DAYS.y), false])
	if plan.is_empty() or plan.back()[1] < main.clock:  # orologio saltato avanti (le prove): si riparte da adesso
		plan = [[main.clock, main.clock, forecast]]
	while plan.back()[1] < horizon:
		var from: float = plan.back()[1]
		var w: int = FORECAST.pick_random()
		if w in [Weather.RAIN, Weather.STORM] and mean_temperature(from) < SNOW_BELOW:
			w = Weather.SNOW
		plan.append([from, from + randf_range(WEATHER_HOURS.x, WEATHER_HOURS.y) / 24.0, w])
	while plan.size() > 1 and plan[0][1] <= main.clock:
		plan.pop_front()


# il tempo deciso per il momento `at`, in giorni come main.clock (dentro PLAN_DAYS)
func weather_at(at: float) -> int:
	for p in plan:
		if at < p[1]:
			return p[2]
	return plan.back()[2]


# gradi fuori, adesso (dentro le stanze: main.temperature_at)
func temperature() -> float:
	return outdoor(main.clock, weather, weather_strength)


# gradi previsti fuori al momento `at`, col tempo deciso (vedi plan)
func forecast_temperature(at: float) -> float:
	return outdoor(at, weather_at(at), 1.0)


# gradi fuori al momento `at`: media del giorno, più o meno secondo l'ora e secondo il tempo `w` (a forza `strength`)
func outdoor(at: float, w: int, strength: float) -> float:
	if not climate:
		return main.ROOM_TEMP
	var sun := sin((fposmod(at, 1.0) - 0.25) * TAU)  # come main.sun_height
	return mean_temperature(at) + DAY_SWING * sun + WEATHER_TEMP[w] * strength


# media del giorno al momento `at` (se manca, adesso), meno l'ondata di freddo
func mean_temperature(at := -1.0) -> float:
	if at < 0:
		at = main.clock
	return seasonal(at) - COLD_WAVE * cold_wave(at)


# media del giorno secondo il punto dell'anno: il caldo più forte a metà estate (il Capodanno è il giorno 0)
func seasonal(at: float) -> float:
	var midsummer: float = 1.0 + 1.5 * main.SEASON_DAYS
	return YEAR_MEAN + YEAR_SWING * cos((at - midsummer) / main.YEAR_DAYS * TAU)


# 0..1: quanto si sente un'ondata di freddo al momento `at` (se manca, adesso): mezza giornata per arrivare e andarsene
func cold_wave(at := -1.0) -> float:
	if at < 0:
		at = main.clock
	var f := 0.0
	for w in waves:
		f = maxf(f, clampf(minf(at - w[0], w[1] - at) * 2.0, 0.0, 1.0))
	return f


# 0..1: quanto piove, anche col temporale
func raining() -> float:
	return weather_strength if weather == Weather.RAIN or weather == Weather.STORM else 0.0


# 0 di giorno, 1 a notte fonda
func darkness() -> float:
	return clampf(0.5 - main.sun_height() * 4.0, 0.0, 1.0)


# dove neve e pozzanghere restano: non sotto i tetti (tranne dove hanno un buco), non sull'acqua se non è gelata
func update_uncovered() -> void:
	uncovered_for = main.roofed
	uncovered_ice = frozen
	uncovered_stamp = main.roof_stamp
	var img := Image.create_empty(main.MAP_SIZE.x, main.MAP_SIZE.y, false, Image.FORMAT_L8)
	img.fill(Color.WHITE)
	for cell in main.roofed.keys().filter(func(k): return not main.holed(k)) + ([] if frozen else main.water.keys()):
		img.set_pixelv(cell, Color.BLACK)
	uncovered.set_image(img)


# alone attorno a ogni luce accesa, che cresce col buio; quello dei fuochi trema
func draw_halos() -> void:
	var night := darkness()
	if night == 0:
		return
	var seconds: float = main.clock * main.DAY_LENGTH
	for cell in main.furniture:
		var kind: int = main.furniture[cell][0]
		if not reach.has(kind) or (main.roofs_shown and main.roofed.has(cell)):  # sotto un tetto non si vede
			continue
		var r: float = reach[kind]
		if kind == main.Build.CAMPFIRE:
			r *= 1.0 + 0.05 * sin(seconds * 11.0 + cell.x) + 0.03 * sin(seconds * 23.0 + cell.y)
		r = roundf(r)
		glow.draw_texture_rect(halo, Rect2((main.center(cell) - Vector2.ONE * r).round(), Vector2.ONE * r * 2), false,
			Color(WARM, night))
	for cell in main.burning:  # i tetti in fiamme si vedono da lontano
		var r := roundf(BLAZE_REACH * (1.0 + 0.08 * sin(seconds * 13.0 + cell.x)))
		glow.draw_texture_rect(halo, Rect2((main.center(cell) - Vector2.ONE * r).round(), Vector2.ONE * r * 2), false,
			Color(WARM, night))


# fumo che sale e piega col vento (si scurisce di notte) e, se `flames`, braci che salgono (luminose, nel livello delle
# luci): [fumo, braci]
func light_fire(at: Vector2, flames := true) -> Array:
	var smoke := make_smoke(at)
	if not flames:
		return [smoke]
	var embers := CPUParticles2D.new()
	embers.position = at + Vector2(0, -3)
	embers.amount = 8
	embers.lifetime = 1.2
	embers.preprocess = 1.2
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(3, 1)
	embers.direction = Vector2.UP
	embers.spread = 25.0
	embers.gravity = Vector2(4, -12)
	embers.initial_velocity_min = 8.0
	embers.initial_velocity_max = 18.0
	embers.color_ramp = ramp([Color(1, 0.95, 0.6), Color(1, 0.5, 0.15), Color(0.9, 0.25, 0.1, 0)])
	embers.material = glow.material
	glow.add_child(embers)
	return [smoke, embers]


func make_smoke(at: Vector2) -> CPUParticles2D:
	var smoke := CPUParticles2D.new()
	smoke.position = at + Vector2(0, -6)
	smoke.amount = 12
	smoke.lifetime = 3.5
	smoke.preprocess = 3.5
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(2, 1)
	smoke.direction = Vector2.UP
	smoke.spread = 10.0
	smoke.gravity = Vector2(5, -3)
	smoke.initial_velocity_min = 6.0
	smoke.initial_velocity_max = 10.0
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 5.0
	smoke.scale_amount_curve = Curve.new()
	smoke.scale_amount_curve.add_point(Vector2(0, 0.6))
	smoke.scale_amount_curve.add_point(Vector2(1, 1.0))
	smoke.color = SMOKE
	smoke.color_ramp = ramp([Color(1, 1, 1, 0), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)], [0.0, 0.15, 1.0])
	add_child(smoke)
	return smoke


# gradiente coi colori `colors`, alle posizioni `offsets` (se mancano, a distanza uguale)
func ramp(colors: Array, offsets := []) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets if offsets else range(colors.size()).map(func(i): return i / (colors.size() - 1.0)))
	g.colors = PackedColorArray(colors)
	return g
