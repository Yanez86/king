extends Node2D

const MAP_SIZE := Vector2i(100, 100)
const TILE := 16            # pixel per tile
const SPEED := 4.0          # tile al secondo
const CHOP_TIME := 3.0      # secondi per abbattere un albero
const WOOD_PER_TREE := 10
const MINE_TIME := 3.0      # secondi per casella di masso
const STONE_PER_CELL := 5   # pietra per casella di masso (un 2x2 ne dà 20)
const STACK_MAX := 50       # quantità massima per cella di magazzino
const CARRY_MAX := 25       # quantità massima trasportata per viaggio
const BUILD_TIME := 2.0     # secondi per costruire una casella
const RETRY_AFTER := 10.0   # secondi di gioco prima di riprovare a raggiungere una casella irraggiungibile
const COLONIST_COUNT := 3
# magazzino iniziale: edificio solido, le sue celle sono i posti dove si stocca (vedi `stockpile`)
const START_STOCKPILE := Rect2i(MAP_SIZE / 2 + Vector2i(-2, 1), Vector2i(4, 2))
const WAREHOUSE_DOOR := [Vector2i(1, 2), Vector2i(2, 2)]  # caselle davanti al portone, dall'angolo del magazzino
const TUNIC_COLORS := [Color("a33b3b"), Color("3b5ea3"), Color("c9a23b"), Color("6e3ba3"), Color("d8d0c0")]
const CAPE_COLORS := [Color("2f4a6e"), Color("6e2f2f"), Color("5a3b6e"), Color("4a4a4a"), Color("7a5a2f")]
const HAIR_COLORS := [Color("3b2a1e"), Color("d9b35b"), Color("a8462f"), Color("8b5a2b"), Color("2a2a2a")]
const SIDES := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const TREE_SIDES := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]  # da sopra la chioma coprirebbe chi taglia

enum Job { NONE, CHOP, MINE, HAUL, BUILD }
enum Res { WOOD, STONE }
enum Order { CHOP, MINE, BUILD, ERASE }  # cosa segna il trascinamento del mouse
const ORDER_COLORS := [Color.ORANGE, Color("8fd3ff"), Color("e6e2d0"), Color("ff5a5a")]  # contorno della selezione, per Order
enum Build { WALL, FLOOR }             # righe del foglio costruzioni (colonne = Res)
const BUILD_COST := {Build.WALL: 5, Build.FLOOR: 2}  # materiale per casella
enum Facing { DOWN, LEFT, RIGHT, UP }  # righe del foglio
enum TreeKind { OAK, PINE, BIRCH }     # colonne del foglio alberi

# fogli 80x64 generati da tools/make_sprites.py
const COLONIST_BASE := preload("res://art/colonist_base.png")
const COLONIST_HAIR := preload("res://art/colonist_hair.png")
const COLONIST_TUNIC := preload("res://art/colonist_tunic.png")
const COLONIST_CAPE := preload("res://art/colonist_cape.png")
const WALK_CYCLE := [0, 1, 0, 2]  # colonne del foglio: fermo, passo A, fermo, passo B
const WORK_CYCLE := [3, 3, 4]     # carica, carica, colpo: per ogni lavoro a tempo (taglio, scavo, costruzione)
const SWING_TIME := 0.6           # secondi per colpo
const TREES := preload("res://art/trees.png")  # 16x32 ciascuno: la chioma sale nella casella sopra
const BOULDERS := {  # massi: dimensione in caselle -> sprite, dal più grande (ordine usato in generate_map)
	Vector2i(2, 2): preload("res://art/rock_2x2.png"),
	Vector2i(2, 1): preload("res://art/rock_2x1.png"),
	Vector2i(1, 1): preload("res://art/rock_1x1.png"),
}
const WAREHOUSE := preload("res://art/warehouse_day.png")  # 64x32 su START_STOCKPILE, portone su WAREHOUSE_DOOR
const WAREHOUSE_NIGHT := preload("res://art/warehouse_night.png")  # finestre accese
const DAY_LENGTH := 240.0   # secondi per giorno a velocità 1x
const NIGHT := Color(0.25, 0.28, 0.5)
# luce sul mondo nelle 24 ore (0 = mezzanotte, 0.5 = mezzogiorno); l'interfaccia non cambia
const SKY := {0.0: NIGHT, 0.21: NIGHT, 0.25: Color(1.0, 0.7, 0.6), 0.31: Color.WHITE,
	0.69: Color.WHITE, 0.75: Color(1.0, 0.62, 0.45), 0.79: NIGHT, 1.0: NIGHT}
const SHADOW_ALPHA := 0.35  # quanto scuriscono le ombre col sole alto
const SHADOW_SKEW := 1.5    # pixel d'ombra in orizzontale per pixel d'altezza, col sole all'orizzonte
const SHADOW_DROP := 0.3    # e in verticale verso nord (il sole passa a sud): a mezzogiorno resta corta, dietro la base
const GROUND := preload("res://art/ground.png")  # terreno 64x176, righe = Ground
const WATER_SHADER := preload("res://water.gdshader")  # anima l'acqua sul terreno
# righe di GROUND: 4 varianti per terreno, poi i bordi che un terreno disegna su quello vicino; gli angoli 3 righe più giù
enum Ground { GRASS, STONY_GRASS, GRAVEL, SHALLOW, DEEP, GRASS_EDGE, SHORE, SHALLOW_EDGE }
const EDGE_SIDES := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]          # colonne dei lati in GROUND
const EDGE_CORNERS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]  # colonne degli angoli
const SHALLOW_COST := 3.0  # i coloni guadano l'acqua bassa solo se il giro all'asciutto è molto più lungo
const ICONS := {
	Res.WOOD: preload("res://art/icon_wood.png"),
	Res.STONE: preload("res://art/icon_stone.png"),
}
const STRUCTURES := preload("res://art/structures.png")  # 32x32: righe = Build, colonne = Res
# ponytail: muri tutti uguali, ognuno col suo bordo; autotiling (muri che si uniscono) quando servirà


class Colonist:
	var pos: Vector2
	var tunic: Color
	var cape: Color
	var hair: Color
	var facing := Facing.DOWN
	var walked := 0.0             # pixel percorsi, scandisce i passi dell'animazione
	var path: Array[Vector2i] = []
	var job := Job.NONE
	var target := Vector2i.ZERO   # albero, masso (cella d'origine), mucchio, cella di magazzino o progetto
	var dest := Vector2i.ZERO     # HAUL: cella di magazzino dove finisce il carico (si scarica dal portone); BUILD: dove stare a costruire
	var carry_res := Res.WOOD
	var carrying := 0
	var work_left := 0.0
	var work_total := 0.0


var astar := AStarGrid2D.new()
var rocks := {}             # cella -> true (non attraversabile)
var boulders := {}          # cella in alto a sinistra -> dimensione del masso che copre quelle rocce
var water := {}             # cella -> Ground.SHALLOW (si guada) o Ground.DEEP (non si attraversa)
var ground_texture: ImageTexture  # tutto il terreno già disegnato, vedi bake_ground
var trees := {}             # cella -> TreeKind (attraversabile), in ordine di riga: serve a _draw
var chop_marks := {}        # cella -> true: alberi da tagliare
var mine_marks := {}        # cella d'origine -> true: massi da scavare
var items := {Res.WOOD: {}, Res.STONE: {}}  # risorsa -> (cella -> quantità a terra; nel magazzino = stoccata)
var stockpile := {}         # cella -> true
var reserved := {}          # cella -> Colonist che la sta usando
var unreachable := {}       # cella -> `clock` da cui riprovare ad arrivarci, vedi path_to_nearest
var draft := {}             # cella -> [Build, Res]: progetto in preparazione, i coloni lo ignorano fino a "Build"
var blueprints := {}        # cella -> [Build, Res]: da costruire
var built := {}             # cella -> [Build, Res]: i muri sono solidi, i pavimenti si calpestano
var colonists: Array[Colonist] = []
var order := Order.CHOP
var build_kind := Build.WALL  # cosa e con cosa costruisce l'ordine BUILD (scelti nella barra in alto)
var build_res := Res.WOOD
var drag_start = null       # cella d'inizio della selezione, o null
var drag_end := Vector2i.ZERO
var clock := 8.0 / 24       # giorni passati: la parte intera conta i giorni, quella decimale è l'ora
var sky := CanvasModulate.new()   # tinge il mondo secondo SKY
var sky_colors := Gradient.new()
var flat := Node2D.new()          # pavimenti, progetti, mucchi: stanno a terra, le ombre ci cadono sopra
var shadows := CanvasGroup.new()  # fonde le sagome: dove si sovrappongono non scuriscono il doppio
var casters := Node2D.new()       # dentro `shadows`: ci si disegnano le sagome
var feet := {}                    # [texture, rettangolo] -> base della sagoma, vedi foot_of

@onready var camera: Camera2D = $Camera2D
@onready var wood_label: Label = $HUD/TopBar/Row/Wood
@onready var stone_label: Label = $HUD/TopBar/Row/Stone
@onready var info_label: Label = $HUD/TopBar/Row/Info
@onready var fullscreen: Button = $HUD/TopBar/Row/Fullscreen
@onready var build_bar: Control = $HUD/BuildBar
@onready var materials: Control = $HUD/BuildBar/Row/Materials
@onready var actions: Control = $HUD/Actions  # in basso al centro: "Build" e la X rossa
@onready var confirm: Button = $HUD/Actions/Confirm
@onready var erase: Button = $HUD/Actions/Erase
@onready var material_group: ButtonGroup = $HUD/BuildBar/Row/Materials/Wood.button_group


func _ready() -> void:
	astar.region = Rect2i(Vector2i.ZERO, MAP_SIZE)
	astar.cell_size = Vector2.ONE * TILE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	generate_map()
	sky_colors.offsets = PackedFloat32Array(SKY.keys())
	sky_colors.colors = PackedColorArray(SKY.values())
	for layer in [flat, shadows]:  # sopra il terreno di bake_ground, sotto quello che disegna _draw
		layer.show_behind_parent = true
		add_child(layer)
	shadows.add_child(casters)
	flat.draw.connect(draw_flat)
	casters.draw.connect(draw_shadows)
	add_child(sky)
	for x in range(START_STOCKPILE.position.x, START_STOCKPILE.end.x):
		for y in range(START_STOCKPILE.position.y, START_STOCKPILE.end.y):
			stockpile[Vector2i(x, y)] = true
			astar.set_point_solid(Vector2i(x, y))  # il magazzino non è transitabile
	for i in COLONIST_COUNT:
		var c := Colonist.new()
		c.pos = center(MAP_SIZE / 2 + Vector2i(i - 1, 0))
		c.tunic = TUNIC_COLORS[i % TUNIC_COLORS.size()]
		c.cape = CAPE_COLORS.pick_random()
		c.hair = HAIR_COLORS.pick_random()
		colonists.append(c)
	camera.position = center(MAP_SIZE / 2)
	fullscreen.pressed.connect(toggle_fullscreen)
	$HUD/Tools/Row/Structures.toggled.connect(toggle_build)
	$HUD/BuildBar/Row/Wall.pressed.connect(choose_kind.bind(Build.WALL))
	$HUD/BuildBar/Row/Floor.pressed.connect(choose_kind.bind(Build.FLOOR))
	$HUD/BuildBar/Row/Materials/Wood.pressed.connect(choose_res.bind(Res.WOOD))
	$HUD/BuildBar/Row/Materials/Stone.pressed.connect(choose_res.bind(Res.STONE))
	confirm.pressed.connect(confirm_build)
	erase.toggled.connect(toggle_erase)


func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen.text = "Fullscreen" if full else "Window"


# tasto "Structures" (sega e martello) in basso a sinistra: sopra compaiono tipo di costruzione e materiale,
# al centro "Build" e la X per cancellare
func toggle_build(on: bool) -> void:
	build_bar.visible = on
	actions.visible = on
	if not on:
		draft.clear()  # chiudere senza confermare scarta il progetto
		erase.button_pressed = false
		if order in [Order.BUILD, Order.ERASE]:
			order = Order.CHOP


func choose_kind(kind: Build) -> void:
	build_kind = kind
	materials.show()
	erase.button_pressed = false


func choose_res(res: Res) -> void:
	build_res = res
	erase.button_pressed = false
	order = Order.BUILD  # da qui il trascinamento disegna il progetto


# X rossa: finché è premuta il trascinamento cancella caselle del progetto
func toggle_erase(on: bool) -> void:
	if on:
		order = Order.ERASE
	elif order == Order.ERASE:
		order = Order.BUILD if material_group.get_pressed_button() else Order.CHOP


# tasto "Build": il progetto diventa lavoro per i coloni liberi
func confirm_build() -> void:
	for cell in draft:
		if can_build(cell):  # nel frattempo può esserci finita sopra della roba
			blueprints[cell] = draft[cell]
	draft.clear()


func generate_map() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.08
	var lakes := FastNoiseLite.new()
	lakes.seed = noise.seed + 1
	lakes.frequency = 0.04
	for y in MAP_SIZE.y:  # per righe, così `trees` resta ordinato dall'alto in basso
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			if (cell - MAP_SIZE / 2).length() < 4:
				continue  # radura di partenza
			var n := noise.get_noise_2d(x, y)
			var w := lakes.get_noise_2d(x, y)
			if w > 0.3:  # laghi: al centro acqua alta, attorno una fascia di acqua bassa
				water[cell] = Ground.DEEP if w > 0.4 else Ground.SHALLOW
			elif n > 0.3:
				rocks[cell] = true
				astar.set_point_solid(cell)
			elif n < -0.15 and randf() < 0.6:  # pini nel fitto del bosco, querce e qualche betulla ai margini
				trees[cell] = TreeKind.PINE if n < -0.4 else (TreeKind.BIRCH if randf() < 0.2 else TreeKind.OAK)

	for cell in water:  # l'acqua alta non tocca mai la riva, neanche in diagonale: in mezzo c'è sempre quella bassa
		if water[cell] == Ground.DEEP and not (EDGE_SIDES + EDGE_CORNERS).all(func(d): return water.has(cell + d)):
			water[cell] = Ground.SHALLOW
		if water[cell] == Ground.DEEP:
			astar.set_point_solid(cell)
		else:
			astar.set_point_weight_scale(cell, SHALLOW_COST)

	# copre la roccia di massi: in ordine di riga, il più grande che entra (a volte uno più piccolo, per varietà)
	var covered := {}
	for cell in rocks:
		if covered.has(cell):
			continue
		for size in BOULDERS:
			var cells := []
			for dy in size.y:
				for dx in size.x:
					cells.append(cell + Vector2i(dx, dy))
			if size == Vector2i.ONE or (randf() < 0.7 and cells.all(func(k): return rocks.has(k) and not covered.has(k))):
				for k in cells:
					covered[k] = true
				boulders[cell] = size
				break
	bake_ground(noise)


# Disegna il terreno una volta sola in un'unica immagine, che _draw mostra come una texture.
# ponytail: si fa solo alla generazione; quando il terreno cambierà (scavi, ponti) ridisegnare le caselle toccate
func bake_ground(noise: FastNoiseLite) -> void:
	var sheet := GROUND.get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	var img := Image.create_empty(MAP_SIZE.x * TILE, MAP_SIZE.y * TILE, false, Image.FORMAT_RGBA8)
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			var own := ground_of(cell)
			var row := Ground.STONY_GRASS if own == Ground.GRASS and noise.get_noise_2d(x, y) > 0.15 else own
			img.blit_rect(sheet, tile_rect(randi() % 4, row), cell * TILE)
			for i in 4:  # i vicini "più alti" sbordano su questa casella: lati, e angoli se nessun lato li copre già
				var side := edge_row(own, cell + EDGE_SIDES[i])
				if side >= 0:
					img.blend_rect(sheet, tile_rect(i, side), cell * TILE)
				var d: Vector2i = EDGE_CORNERS[i]
				var corner := edge_row(own, cell + d)
				if corner >= 0 and edge_row(own, cell + Vector2i(d.x, 0)) != corner and edge_row(own, cell + Vector2i(0, d.y)) != corner:
					img.blend_rect(sheet, tile_rect(i, corner + 3), cell * TILE)
	ground_texture = ImageTexture.create_from_image(img)
	var water_fx := ShaderMaterial.new()
	water_fx.shader = WATER_SHADER
	water_fx.set_shader_parameter("shallow", sheet.get_pixel(0, Ground.SHALLOW * TILE))  # colori base dell'acqua
	water_fx.set_shader_parameter("deep", sheet.get_pixel(0, Ground.DEEP * TILE))
	var sprite := Sprite2D.new()
	sprite.texture = ground_texture
	sprite.centered = false
	sprite.show_behind_parent = true  # sotto a tutto quello che disegna _draw
	sprite.material = water_fx
	add_child(sprite)


func ground_of(cell: Vector2i) -> int:
	if water.has(cell):
		return water[cell]
	return Ground.GRAVEL if rocks.has(cell) else Ground.GRASS


# Riga del bordo che la casella `next` disegna su una casella di terreno `own`, -1 se nessuno.
func edge_row(own: int, next: Vector2i) -> int:
	if not astar.is_in_boundsv(next):
		return -1
	var other := ground_of(next)
	if own >= Ground.SHALLOW and other < Ground.SHALLOW:
		return Ground.SHORE
	if own == Ground.DEEP and other == Ground.SHALLOW:
		return Ground.SHALLOW_EDGE
	if own == Ground.GRAVEL and other == Ground.GRASS:
		return Ground.GRASS_EDGE
	return -1


func tile_rect(col: int, row: int) -> Rect2i:
	return Rect2i(Vector2i(col, row) * TILE, Vector2i.ONE * TILE)


# --- Simulazione ---

func _process(delta: float) -> void:
	tick(delta)
	wood_label.text = str(stored(Res.WOOD))
	stone_label.text = str(stored(Res.STONE))
	confirm.disabled = draft.is_empty()
	var t := fmod(clock, 1.0)
	info_label.text = "Day %d  %02d:%02d    Order: %s  (C = chop, M = mine)    Speed: %dx  (Space = pause, 1-3)" \
		% [int(clock) + 1, int(t * 24), int(t * 1440) % 60, Order.keys()[order].capitalize(), Engine.time_scale]
	sky.color = sky_colors.sample(t)
	var shade := SHADOW_ALPHA * clampf(sun_height() * 4, 0, 1)  # sfuma all'alba e al tramonto, zero di notte
	shadows.self_modulate = Color(0, 0, 0, shade)
	shadows.visible = shade > 0
	queue_redraw()
	flat.queue_redraw()
	casters.queue_redraw()


func tick(delta: float) -> void:
	clock += delta / DAY_LENGTH
	for c in colonists:
		update_colonist(c, delta)


func update_colonist(c: Colonist, delta: float) -> void:
	if not c.path.is_empty():  # anche senza lavoro: chi è libero può dover uscire da una stanza che si chiude
		var goal := center(c.path[0])
		var d := goal - c.pos
		face(c, d)
		c.walked += minf(d.length(), SPEED * TILE * delta)
		c.pos = c.pos.move_toward(goal, SPEED * TILE * delta)
		if c.pos == goal:
			c.path.pop_front()
		return
	if c.job == Job.NONE:
		find_job(c)
		return
	match c.job:
		Job.CHOP:
			face(c, center(c.target) - c.pos)
			c.work_left -= delta
			if c.work_left <= 0:
				trees.erase(c.target)
				chop_marks.erase(c.target)
				add_item(Res.WOOD, c.target, WOOD_PER_TREE)
				end_job(c)
				try_haul(c, Res.WOOD, [c.target])  # porta subito via quello che ha prodotto
		Job.MINE:
			var cells := boulder_cells(c.target)
			sort_by_distance(cells, c.pos)
			face(c, center(cells[0]) - c.pos)  # verso il masso, così il colpo va a segno
			c.work_left -= delta
			if c.work_left <= 0:
				for cell in cells:
					rocks.erase(cell)
					astar.set_point_solid(cell, false)
				boulders.erase(c.target)
				mine_marks.erase(c.target)
				add_item(Res.STONE, c.target, STONE_PER_CELL * cells.size())
				end_job(c)
				try_haul(c, Res.STONE, [c.target])
		Job.HAUL:
			var ground: Dictionary = items[c.carry_res]
			if c.target != c.dest:  # arrivato al mucchio: carica
				var to_door := path_to_nearest(c, warehouse_access())
				if to_door.is_empty():
					return  # portone occupato: aspetta qui
				var space: int = STACK_MAX - ground.get(c.dest, 0)
				c.carrying = mini(mini(ground[c.target], CARRY_MAX), space)
				add_item(c.carry_res, c.target, -c.carrying)
				reserved.erase(c.target)
				c.target = c.dest
				c.path = to_door
			else:                   # arrivato al portone: scarica
				add_item(c.carry_res, c.dest, c.carrying)
				c.carrying = 0
				end_job(c)
		Job.BUILD:
			var plan: Array = blueprints[c.target]
			if c.carrying == 0:     # arrivato al portone: prende il materiale e va al cantiere
				if not take(plan[1], BUILD_COST[plan[0]]):
					end_job(c)          # nel frattempo l'ha preso un altro
					return
				c.carrying = BUILD_COST[plan[0]]
				c.path = astar.get_id_path(cell_of(c.pos), c.dest)
				return
			face(c, center(c.target) - c.pos)
			c.work_left = maxf(c.work_left - delta, 0.0)
			if c.work_left == 0 and (plan[0] == Build.FLOOR or ready_to_close(c)):
				build(c.target)
				c.carrying = 0
				end_job(c)


func find_job(c: Colonist) -> void:
	# ordine fisso finché non c'è la tabella delle priorità: tagliare, scavare, costruire, trasportare
	var stands := {}  # casella libera accanto a un albero segnato -> albero
	for tree in chop_marks:
		if is_free(tree):
			add_stands(stands, [tree], tree, TREE_SIDES)
	var path := path_to_nearest(c, stands.keys())
	if not path.is_empty():
		start_job(c, Job.CHOP, path, stands[path.back()], CHOP_TIME)
		return

	stands = {}  # casella libera accanto a un masso segnato -> origine del masso
	for origin in mine_marks:
		if is_free(origin):
			add_stands(stands, boulder_cells(origin), origin, SIDES)
	path = path_to_nearest(c, stands.keys())
	if not path.is_empty():
		var origin: Vector2i = stands[path.back()]
		start_job(c, Job.MINE, path, origin, MINE_TIME * boulder_cells(origin).size())
		return

	stands = {}  # casella libera accanto a un progetto col materiale in magazzino -> progetto
	for cell in blueprints:
		if is_free(cell) and stored(blueprints[cell][1]) >= BUILD_COST[blueprints[cell][0]]:
			add_stands(stands, [cell], cell, SIDES)
	path = path_to_nearest(c, stands.keys())
	var to_door := [] if path.is_empty() else path_to_nearest(c, warehouse_access())
	if not to_door.is_empty():  # prima al portone a prendere il materiale, poi al cantiere
		start_job(c, Job.BUILD, to_door, stands[path.back()], BUILD_TIME)
		c.dest = path.back()
		c.carry_res = blueprints[c.target][1]
		return

	for res in Res.values():
		if try_haul(c, res, items[res].keys().filter(func(cell): return not stockpile.has(cell) and is_free(cell))):
			return

	var here := cell_of(c.pos)
	if warehouse_access().has(here):  # senza lavoro davanti al portone: si fa da parte, se no blocca chi scarica
		var aside := []
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var s: Vector2i = here + Vector2i(dx, dy)
				if astar.is_in_boundsv(s) and not astar.is_point_solid(s) and not trees.has(s) and not warehouse_access().has(s):
					aside.append(s)
		c.path = path_to_nearest(c, aside)


# avvia il trasporto del mucchio di `res` più vicino tra `piles`; false se non c'è posto o strada
func try_haul(c: Colonist, res: Res, piles: Array) -> bool:
	var dests := dest_cells(res)
	if dests.is_empty():
		return false  # magazzino pieno per questa risorsa
	var path := path_to_nearest(c, piles)
	if path.is_empty():
		return false
	start_job(c, Job.HAUL, path, path.back(), 0.0)
	c.carry_res = res
	# prima le pile già iniziate della stessa risorsa, poi la più vicina
	# ponytail: una prenotazione = un colono per cella, quindi coloni in parallelo lasciano qualche pila a metà;
	# prenotare lo spazio (quantità) invece della cella se il magazzino si riempie troppo presto
	var from := center(c.target)
	dests.sort_custom(func(a, b): return [not items[res].has(a), center(a).distance_squared_to(from)] \
		< [not items[res].has(b), center(b).distance_squared_to(from)])
	c.dest = dests[0]  # ponytail: assume il portone raggiungibile, è accanto alla partenza
	reserved[c.dest] = c
	return true


func add_stands(stands: Dictionary, cells: Array, target: Vector2i, sides: Array) -> void:
	for cell in cells:
		for side in sides:
			var s: Vector2i = cell + side
			if astar.is_in_boundsv(s) and not astar.is_point_solid(s) and not trees.has(s) \
					and blueprints.get(s, [-1])[0] != Build.WALL:
				stands[s] = target  # non sopra un albero, né sopra un muro da fare (diventerà solido)


func start_job(c: Colonist, job: Job, path: Array[Vector2i], target: Vector2i, work: float) -> void:
	c.job = job
	c.path = path
	c.target = target
	c.work_left = work
	c.work_total = work
	reserved[target] = c


func face(c: Colonist, d: Vector2) -> void:
	if absf(d.y) > absf(d.x):  # in diagonale guarda di lato
		c.facing = Facing.DOWN if d.y > 0 else Facing.UP
	elif d.x != 0:
		c.facing = Facing.RIGHT if d.x > 0 else Facing.LEFT


# fermo sul posto a fare un lavoro a tempo (non il trasporto)
func is_working(c: Colonist) -> bool:
	return c.job != Job.NONE and c.path.is_empty() and c.work_total > 0


func end_job(c: Colonist) -> void:
	for cell in reserved.keys():
		if reserved[cell] == c:
			reserved.erase(cell)
	c.job = Job.NONE


# Percorso di `c` verso la casella più vicina tra `cells` dove nessun altro colono è fermo o sta andando:
# ci si può passare attraverso, ma non fermarsi in due sulla stessa casella.
func path_to_nearest(c: Colonist, cells: Array) -> Array[Vector2i]:
	# ponytail: "più vicino" in linea d'aria e un percorso per candidato; passare a distanza di percorso se i coloni fanno giri assurdi
	# una casella irraggiungibile costa una ricerca su tutta la mappa: la si salta per RETRY_AFTER secondi
	# ponytail: vale per tutti i coloni; con gruppi separati di coloni servirà tenerla per zona (componenti connesse)
	var taken := claimed(c)
	cells = cells.filter(func(cell): return not taken.has(cell))
	sort_by_distance(cells, c.pos)
	var misses := 0
	for cell in cells:
		if unreachable.get(cell, -1.0) > clock:
			continue
		var path := astar.get_id_path(cell_of(c.pos), cell)
		if not path.is_empty():
			return path
		unreachable[cell] = clock + RETRY_AFTER / DAY_LENGTH
		misses += 1
		if misses == 3:
			break  # le altre ai prossimi tick: niente scatti
	return []


# Caselle dove gli altri coloni si fermeranno: fine del percorso (o dove sono, se fermi) e il cantiere di chi costruisce.
func claimed(except: Colonist) -> Dictionary:
	var cells := {}
	for o in colonists:
		if o != except:
			cells[cell_of(o.pos) if o.path.is_empty() else o.path.back()] = true
			if o.job == Job.BUILD:
				cells[o.dest] = true
	return cells


func sort_by_distance(cells: Array, from: Vector2) -> void:
	cells.sort_custom(func(a, b): return center(a).distance_squared_to(from) < center(b).distance_squared_to(from))


func is_free(cell: Vector2i) -> bool:
	return not reserved.has(cell)


# celle di magazzino che possono ricevere `res`: libere, vuote o con la stessa risorsa non piena
func dest_cells(res: Res) -> Array:
	return stockpile.keys().filter(func(cell):
		for other in items:
			if other != res and items[other].has(cell):
				return false
		return is_free(cell) and items[res].get(cell, 0) < STACK_MAX)


# caselle "interruttore" del magazzino: i coloni scaricano stando qui
func warehouse_access() -> Array:
	return WAREHOUSE_DOOR.map(func(offset): return START_STOCKPILE.position + offset)


func add_item(res: Res, cell: Vector2i, amount: int) -> void:
	var ground: Dictionary = items[res]
	ground[cell] = ground.get(cell, 0) + amount
	if ground[cell] <= 0:
		ground.erase(cell)


func boulder_cells(origin: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var size: Vector2i = boulders[origin]
	for dy in size.y:
		for dx in size.x:
			cells.append(origin + Vector2i(dx, dy))
	return cells


func mark(rect: Rect2i) -> void:
	match order:
		Order.CHOP:
			for cell in trees:
				if rect.has_point(cell):
					chop_marks[cell] = true
		Order.MINE:
			for origin in boulders:
				if rect.intersects(Rect2i(origin, boulders[origin])):
					mine_marks[origin] = true
		Order.BUILD:  # nel progetto; i muri solo sul bordo del rettangolo: trascinando si disegna una stanza
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					var edge: bool = x in [rect.position.x, rect.end.x - 1] or y in [rect.position.y, rect.end.y - 1]
					if can_build(Vector2i(x, y)) and (edge or build_kind == Build.FLOOR):
						draft[Vector2i(x, y)] = [build_kind, build_res]  # sovrascrive: ripassando si cambia idea
		Order.ERASE:
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					erase_plan(Vector2i(x, y))


# toglie la casella dal progetto, anche già confermato; chi la stava costruendo lascia a terra il materiale
func erase_plan(cell: Vector2i) -> void:
	draft.erase(cell)
	if not blueprints.erase(cell):
		return
	var c: Colonist = reserved.get(cell)
	if c:
		add_item(c.carry_res, cell_of(c.pos), c.carrying)  # i trasportatori lo riportano in magazzino
		c.carrying = 0
		c.path.clear()
		end_job(c)


# niente acqua, alberi, roccia, edifici, roba a terra, né il portone del magazzino
func can_build(cell: Vector2i) -> bool:
	return astar.is_in_boundsv(cell) and not astar.is_point_solid(cell) and not water.has(cell) \
		and not trees.has(cell) and not built.has(cell) and not blueprints.has(cell) \
		and not warehouse_access().has(cell) and items.values().all(func(ground): return not ground.has(cell))


func build(cell: Vector2i) -> void:
	built[cell] = blueprints[cell]
	blueprints.erase(cell)
	if built[cell][0] == Build.WALL:
		astar.set_point_solid(cell)
		# ponytail: se non resta strada il colono lavora da dov'è; annullare il lavoro quando ci saranno le porte
		for o in colonists:  # chi doveva passare di qui cerca un'altra strada
			if o.path.has(cell):
				o.path = astar.get_id_path(cell_of(o.pos), o.path.back())


# Un muro si chiude solo se nessuno resta tagliato fuori dal magazzino (stanze chiuse, senza porte):
# chi lo sarebbe ed è libero esce verso il portone, chi lavora finisce prima; il costruttore gira dall'altra parte.
func ready_to_close(c: Colonist) -> bool:
	var door: Vector2i = warehouse_access()[0]
	var reaches := func(cell): return not astar.get_id_path(cell, door).is_empty()
	var cut := colonists.filter(func(o): return reaches.call(cell_of(o.pos)))
	astar.set_point_solid(c.target)  # prova: come sarebbe a muro finito
	cut = cut.filter(func(o): return not reaches.call(cell_of(o.pos)))
	var sides: Array = SIDES.map(func(s): return c.target + s).filter(func(s): return astar.is_in_boundsv(s) \
		and blueprints.get(s, [-1])[0] != Build.WALL and reaches.call(s))
	astar.set_point_solid(c.target, false)
	if c in cut and not sides.is_empty():
		sort_by_distance(sides, c.pos)
		c.dest = sides[0]
		c.path = astar.get_id_path(cell_of(c.pos), c.dest)  # passa dal varco ancora aperto
		return false
	cut.erase(c)  # ponytail: se nessun lato porta al magazzino il costruttore resta dentro
	for o in cut:
		if o.job == Job.NONE and o.path.is_empty():
			o.path = path_to_nearest(o, warehouse_access())
	return cut.is_empty()


# toglie `amount` di `res` dal magazzino; false se non basta
func take(res: Res, amount: int) -> bool:
	if stored(res) < amount:
		return false
	for cell in stockpile:
		var n: int = mini(items[res].get(cell, 0), amount)
		add_item(res, cell, -n)
		amount -= n
	return true


func total(res: Res) -> int:
	var sum := 0
	for amount in items[res].values():
		sum += amount
	for c in colonists:
		if c.carry_res == res:
			sum += c.carrying
	return sum


func stored(res: Res) -> int:
	var sum := 0
	for cell in stockpile:
		sum += items[res].get(cell, 0)
	return sum


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var cell := cell_of(get_global_mouse_position())
				if event.pressed:
					drag_start = cell
					drag_end = cell
				elif drag_start != null:
					mark(selection_rect())
					drag_start = null
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed: zoom_by(1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed: zoom_by(1 / 1.1)
	elif event is InputEventMouseMotion:
		if drag_start != null:
			drag_end = cell_of(get_global_mouse_position())
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			camera.position -= event.relative / camera.zoom
	elif event is InputEventPanGesture:      # trackpad: due dita
		camera.position += event.delta * 10 / camera.zoom
	elif event is InputEventMagnifyGesture:  # trackpad: pizzico
		zoom_by(event.factor)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE: Engine.time_scale = 0.0 if Engine.time_scale > 0 else 1.0
			KEY_1: Engine.time_scale = 1.0
			KEY_2: Engine.time_scale = 2.0
			KEY_3: Engine.time_scale = 3.0
			KEY_C: order = Order.CHOP
			KEY_M: order = Order.MINE


func zoom_by(factor: float) -> void:
	camera.zoom = (camera.zoom * factor).clamp(Vector2.ONE * 0.5, Vector2.ONE * 8)


func selection_rect() -> Rect2i:
	var r := Rect2i(drag_start, Vector2i.ZERO).expand(drag_end)
	r.size += Vector2i.ONE  # include entrambe le celle agli estremi
	return r


# --- Disegno ---

# Altezza del sole: 0 all'alba (6:00) e al tramonto (18:00), 1 a mezzogiorno, negativa di notte.
func sun_height() -> float:
	return sin(sun_angle())


func sun_angle() -> float:  # 0 all'alba, PI al tramonto
	return (fmod(clock, 1.0) - 0.25) * TAU


# Di quanto si sposta l'ombra per ogni pixel d'altezza. Il sole sorge a est, passa a sud e tramonta a ovest:
# l'ombra va a ovest al mattino, a est la sera, sempre un po' verso nord; a mezzogiorno è corta, dietro la base.
func sun_shadow() -> Vector2:
	return Vector2(-cos(sun_angle()) * SHADOW_SKEW, -SHADOW_DROP)


func draw_flat() -> void:  # sotto le ombre: il terreno lo disegna lo Sprite2D di bake_ground
	for cell in built:
		if built[cell][0] == Build.FLOOR:
			flat.draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), tile_rect(built[cell][1], built[cell][0]))
	for cell in blueprints:  # in trasparenza
		flat.draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), tile_rect(blueprints[cell][1], blueprints[cell][0]),
			Color(1, 1, 1, 0.4))
	for cell in draft:  # velati d'azzurro, da confermare
		flat.draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), tile_rect(draft[cell][1], draft[cell][0]),
			Color(1, 1, 1, 0.6))
		flat.draw_rect(tile_rect(cell.x, cell.y), Color(0.55, 0.8, 1, 0.45))
	for res in items:  # più roba = icona più grande
		for cell in items[res]:
			var side: float = 8.0 + 8.0 * mini(items[res][cell], STACK_MAX) / STACK_MAX
			flat.draw_texture_rect(ICONS[res], Rect2(center(cell) - Vector2.ONE * side / 2, Vector2.ONE * side), false)


# Le sagome di ciò che sta in piedi, coricate a terra dalla parte opposta al sole; il colore lo dà `shadows`.
func draw_shadows() -> void:
	for cell in built:
		if built[cell][0] == Build.WALL:
			cast(STRUCTURES, Rect2(tile_rect(cell.x, cell.y)), Rect2(tile_rect(built[cell][1], built[cell][0])))
	for cell in boulders:
		var rock: Texture2D = BOULDERS[boulders[cell]]
		cast(rock, Rect2(Vector2(cell) * TILE, rock.get_size()), Rect2(Vector2.ZERO, rock.get_size()))
	cast(WAREHOUSE, Rect2(Vector2(START_STOCKPILE.position * TILE), WAREHOUSE.get_size()), Rect2(Vector2.ZERO, WAREHOUSE.get_size()))
	for cell in trees:
		cast(TREES, Rect2(Vector2(cell.x, cell.y - 1) * TILE, Vector2(1, 2) * TILE), Rect2(Vector2(trees[cell], 0) * TILE, Vector2(1, 2) * TILE))
	for c in colonists:
		var dst := Rect2((c.pos - Vector2.ONE * TILE / 2.0).round(), Vector2.ONE * TILE)
		var src := Rect2(Vector2(frame_of(c), c.facing) * TILE, Vector2.ONE * TILE)
		for sheet in [COLONIST_BASE, COLONIST_HAIR, COLONIST_TUNIC, COLONIST_CAPE]:
			cast(sheet, dst, src)


# Disegna `src` di `tex` dov'è `dst`, ma coricato a terra da dove tocca terra: ogni pixel d'altezza va di sun_shadow.
func cast(tex: Texture2D, dst: Rect2, src: Rect2) -> void:
	var foot := Vector2(dst.get_center().x, dst.position.y + foot_of(tex, src))
	casters.draw_set_transform_matrix(Transform2D(Vector2.RIGHT, -sun_shadow(), foot) * Transform2D(0.0, -foot))
	casters.draw_texture_rect_region(tex, dst, src)


# Dove la sagoma tocca terra, in pixel dalla cima di `src`: sotto l'ultima riga con pixel pieni.
# Le ombre semitrasparenti già disegnate negli sprite e i bordi vuoti non contano, se no l'ombra si stacca.
func foot_of(tex: Texture2D, src: Rect2) -> int:
	var key := [tex, src]
	if not feet.has(key):
		var img := tex.get_image()
		var y := int(src.end.y)
		while y > src.position.y and not range(src.position.x, src.end.x).any(func(x): return img.get_pixel(x, y - 1).a == 1.0):
			y -= 1
		feet[key] = y - int(src.position.y)
	return feet[key]


func _draw() -> void:  # terreno, pavimenti, mucchi e ombre stanno sotto: vedi bake_ground e draw_flat
	for cell in built:  # muri, dentro le loro caselle come i massi
		if built[cell][0] == Build.WALL:
			draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), tile_rect(built[cell][1], built[cell][0]))
	for cell in boulders:  # stanno dentro le loro caselle: niente ordine per righe
		draw_texture(BOULDERS[boulders[cell]], Vector2(cell) * TILE)
	# copre la roba stoccata, prima degli alberi sotto
	draw_texture(WAREHOUSE_NIGHT if sun_height() < 0 else WAREHOUSE, Vector2(START_STOCKPILE.position * TILE))

	# alberi e coloni dall'alto in basso: chi sta più giù copre chi gli sta dietro
	# ponytail: si affida a `trees` già in ordine di riga; se gli alberi ricrescono, ordinarli o passare a nodi con y_sort
	var queue := colonists.duplicate()
	queue.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for cell in trees:
		while not queue.is_empty() and queue[0].pos.y < center(cell).y:
			draw_colonist(queue.pop_front())
		draw_texture_rect_region(TREES, Rect2(Vector2(cell.x, cell.y - 1) * TILE, Vector2(1, 2) * TILE),
			Rect2(Vector2(trees[cell], 0) * TILE, Vector2(1, 2) * TILE))
	for c in queue:
		draw_colonist(c)

	for cell in chop_marks:
		draw_rect(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), Color.ORANGE, false, 1.0)
	for origin in mine_marks:
		draw_rect(Rect2(Vector2(origin) * TILE, Vector2(boulders[origin]) * TILE), Color("8fd3ff"), false, 1.0)
	for c in colonists:
		if is_working(c):  # barra di avanzamento del lavoro
			draw_rect(Rect2(c.pos + Vector2(-6, -11), Vector2(12 * (1 - c.work_left / c.work_total), 2)), Color.YELLOW)
	if drag_start != null:
		var r := selection_rect()
		draw_rect(Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE), ORDER_COLORS[order], false, 1.0)


func draw_colonist(c: Colonist) -> void:
	var at := (c.pos - Vector2.ONE * TILE / 2.0).round()  # allineato ai pixel
	var src := Rect2(Vector2(frame_of(c), c.facing) * TILE, Vector2.ONE * TILE)
	var dst := Rect2(at, Vector2.ONE * TILE)
	draw_texture_rect_region(COLONIST_BASE, dst, src)
	draw_texture_rect_region(COLONIST_HAIR, dst, src, c.hair)
	draw_texture_rect_region(COLONIST_TUNIC, dst, src, c.tunic)
	draw_texture_rect_region(COLONIST_CAPE, dst, src, c.cape)
	if c.carrying > 0:
		draw_texture_rect(ICONS[c.carry_res], Rect2(at + Vector2(8, 6), Vector2(8, 8)), false)


func frame_of(c: Colonist) -> int:
	if not c.path.is_empty():
		return WALK_CYCLE[int(c.walked / (TILE / 2.0)) % WALK_CYCLE.size()]
	if is_working(c):
		return WORK_CYCLE[int((c.work_total - c.work_left) / SWING_TIME * WORK_CYCLE.size()) % WORK_CYCLE.size()]
	return 0


func center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2.ONE * TILE / 2.0


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i((pos / TILE).floor())
