extends Node2D

const MAP_SIZE := Vector2i(100, 100)
const TILE := 16            # pixel per tile
const SPEED := 4.0          # tile al secondo
const CHOP_TIME := 3.0      # secondi per abbattere un albero
const WOOD_PER_TREE := 10
const STACK_MAX := 50       # legna massima per cella di magazzino
const CARRY_MAX := 25       # legna massima trasportata per viaggio
const COLONIST_COUNT := 3
# zona magazzino iniziale; i magazzini costruiti dal giocatore aggiungeranno celle a `stockpile`
const START_STOCKPILE := Rect2i(MAP_SIZE / 2 + Vector2i(-2, 1), Vector2i(4, 2))
const TUNIC_COLORS := [Color("a33b3b"), Color("3b5ea3"), Color("c9a23b"), Color("6e3ba3"), Color("d8d0c0")]
const CAPE_COLORS := [Color("2f4a6e"), Color("6e2f2f"), Color("5a3b6e"), Color("4a4a4a"), Color("7a5a2f")]
const HAIR_COLORS := [Color("3b2a1e"), Color("d9b35b"), Color("a8462f"), Color("8b5a2b"), Color("2a2a2a")]

# fogli 48x64 generati da tools/make_sprites.py
const COLONIST_BASE := preload("res://art/colonist_base.png")
const COLONIST_HAIR := preload("res://art/colonist_hair.png")
const COLONIST_TUNIC := preload("res://art/colonist_tunic.png")
const COLONIST_CAPE := preload("res://art/colonist_cape.png")
const WALK_CYCLE := [0, 1, 0, 2]  # colonne del foglio: fermo, passo A, fermo, passo B

enum Job { NONE, CHOP, HAUL }
enum Facing { DOWN, LEFT, RIGHT, UP }  # righe del foglio


class Colonist:
	var pos: Vector2
	var tunic: Color
	var cape: Color
	var hair: Color
	var facing := Facing.DOWN
	var walked := 0.0             # pixel percorsi, scandisce i passi dell'animazione
	var path: Array[Vector2i] = []
	var job := Job.NONE
	var target := Vector2i.ZERO   # dove sta andando: albero, mucchio di legna o cella di magazzino
	var dest := Vector2i.ZERO     # HAUL: cella di magazzino dove scaricare
	var carrying := 0
	var work_left := 0.0


var astar := AStarGrid2D.new()
var rocks := {}             # cella -> true (non attraversabile)
var trees := {}             # cella -> true (attraversabile)
var chop_marks := {}        # cella -> true: alberi da tagliare
var wood := {}              # cella -> quantità a terra (nel magazzino = stoccata)
var stockpile := {}         # cella -> true
var reserved := {}          # cella -> Colonist che la sta usando
var colonists: Array[Colonist] = []
var drag_start = null       # cella d'inizio della selezione, o null
var drag_end := Vector2i.ZERO

@onready var camera: Camera2D = $Camera2D
@onready var hud: Label = $HUD/Label


func _ready() -> void:
	astar.region = Rect2i(Vector2i.ZERO, MAP_SIZE)
	astar.cell_size = Vector2.ONE * TILE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	generate_map()
	for x in range(START_STOCKPILE.position.x, START_STOCKPILE.end.x):
		for y in range(START_STOCKPILE.position.y, START_STOCKPILE.end.y):
			stockpile[Vector2i(x, y)] = true
	for i in COLONIST_COUNT:
		var c := Colonist.new()
		c.pos = center(MAP_SIZE / 2 + Vector2i(i - 1, 0))
		c.tunic = TUNIC_COLORS[i % TUNIC_COLORS.size()]
		c.cape = CAPE_COLORS.pick_random()
		c.hair = HAIR_COLORS.pick_random()
		colonists.append(c)
	camera.position = center(MAP_SIZE / 2)
	$HUD/Fullscreen.pressed.connect(toggle_fullscreen)


func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	$HUD/Fullscreen.text = "Fullscreen" if full else "Window"


func generate_map() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.08
	for x in MAP_SIZE.x:
		for y in MAP_SIZE.y:
			var cell := Vector2i(x, y)
			if (cell - MAP_SIZE / 2).length() < 4:
				continue  # radura di partenza
			var n := noise.get_noise_2d(x, y)
			if n > 0.3:
				rocks[cell] = true
				astar.set_point_solid(cell)
			elif n < -0.15 and randf() < 0.6:
				trees[cell] = true


# --- Simulazione ---

func _process(delta: float) -> void:
	tick(delta)
	hud.text = "Wood: %d stored, %d on ground    Speed: %dx    (Space = pause, 1-3 = speed)" \
		% [stored_wood(), total_wood() - stored_wood(), Engine.time_scale]
	queue_redraw()


func tick(delta: float) -> void:
	for c in colonists:
		update_colonist(c, delta)


func update_colonist(c: Colonist, delta: float) -> void:
	if c.job == Job.NONE:
		find_job(c)
		return
	if not c.path.is_empty():
		var goal := center(c.path[0])
		var d := goal - c.pos
		if absf(d.y) > absf(d.x):  # in diagonale guarda di lato
			c.facing = Facing.DOWN if d.y > 0 else Facing.UP
		elif d.x != 0:
			c.facing = Facing.RIGHT if d.x > 0 else Facing.LEFT
		c.walked += minf(d.length(), SPEED * TILE * delta)
		c.pos = c.pos.move_toward(goal, SPEED * TILE * delta)
		if c.pos == goal:
			c.path.pop_front()
		return
	match c.job:
		Job.CHOP:
			c.work_left -= delta
			if c.work_left <= 0:
				trees.erase(c.target)
				chop_marks.erase(c.target)
				wood[c.target] = wood.get(c.target, 0) + WOOD_PER_TREE
				end_job(c)
		Job.HAUL:
			if c.target != c.dest:  # arrivato al mucchio: carica
				var space: int = STACK_MAX - wood.get(c.dest, 0)
				c.carrying = mini(mini(wood[c.target], CARRY_MAX), space)
				wood[c.target] -= c.carrying
				if wood[c.target] == 0:
					wood.erase(c.target)
				reserved.erase(c.target)
				c.target = c.dest
				c.path = astar.get_id_path(cell_of(c.pos), c.dest)
			else:                   # arrivato al magazzino: scarica
				wood[c.dest] = wood.get(c.dest, 0) + c.carrying
				c.carrying = 0
				end_job(c)


func find_job(c: Colonist) -> void:
	# ordine fisso finché non c'è la tabella delle priorità: prima tagliare, poi trasportare
	var path := path_to_nearest(c.pos, chop_marks.keys().filter(is_free))
	if not path.is_empty():
		start_job(c, Job.CHOP, path)
		c.work_left = CHOP_TIME
		return

	var dests := stockpile.keys().filter(func(cell): return is_free(cell) and wood.get(cell, 0) < STACK_MAX)
	if dests.is_empty():
		return  # magazzino pieno
	var piles := wood.keys().filter(func(cell): return not stockpile.has(cell) and is_free(cell))
	path = path_to_nearest(c.pos, piles)
	if path.is_empty():
		return
	start_job(c, Job.HAUL, path)
	sort_by_distance(dests, center(c.target))
	c.dest = dests[0]  # ponytail: assume la cella di magazzino raggiungibile, è accanto alla partenza
	reserved[c.dest] = c


func start_job(c: Colonist, job: Job, path: Array[Vector2i]) -> void:
	c.job = job
	c.path = path
	c.target = path.back()
	reserved[c.target] = c


func end_job(c: Colonist) -> void:
	for cell in reserved.keys():
		if reserved[cell] == c:
			reserved.erase(cell)
	c.job = Job.NONE


func path_to_nearest(from: Vector2, cells: Array) -> Array[Vector2i]:
	# ponytail: "più vicino" in linea d'aria e un percorso per candidato; passare a distanza di percorso se i coloni fanno giri assurdi
	sort_by_distance(cells, from)
	for cell in cells:
		var path := astar.get_id_path(cell_of(from), cell)
		if not path.is_empty():
			return path
	return []


func sort_by_distance(cells: Array, from: Vector2) -> void:
	cells.sort_custom(func(a, b): return center(a).distance_squared_to(from) < center(b).distance_squared_to(from))


func is_free(cell: Vector2i) -> bool:
	return not reserved.has(cell)


func mark_trees(rect: Rect2i) -> void:
	for cell in trees:
		if rect.has_point(cell):
			chop_marks[cell] = true


func total_wood() -> int:
	var sum := 0
	for amount in wood.values():
		sum += amount
	for c in colonists:
		sum += c.carrying
	return sum


func stored_wood() -> int:
	var sum := 0
	for cell in stockpile:
		sum += wood.get(cell, 0)
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
					mark_trees(selection_rect())
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


func zoom_by(factor: float) -> void:
	camera.zoom = (camera.zoom * factor).clamp(Vector2.ONE * 0.5, Vector2.ONE * 8)


func selection_rect() -> Rect2i:
	var r := Rect2i(drag_start, Vector2i.ZERO).expand(drag_end)
	r.size += Vector2i.ONE  # include entrambe le celle agli estremi
	return r


# --- Disegno (segnaposto finché non ci sono gli sprite) ---

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_SIZE * TILE)), Color("4a7a3a"))
	for cell in stockpile:
		draw_rect(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), Color(0.85, 0.75, 0.45, 0.35))
	for cell in rocks:
		draw_rect(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), Color("777777"))
	for cell in trees:
		draw_circle(center(cell), TILE * 0.45, Color("2d5a27"))
	for cell in chop_marks:
		draw_rect(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), Color.ORANGE, false, 1.0)
	for cell in wood:  # più legna = quadrato più grande
		var side: float = 4.0 + 10.0 * wood[cell] / STACK_MAX
		draw_rect(Rect2(center(cell) - Vector2.ONE * side / 2, Vector2.ONE * side), Color("8b5a2b"))
	for c in colonists:
		var at := (c.pos - Vector2.ONE * TILE / 2.0).round()  # allineato ai pixel
		var frame: int = WALK_CYCLE[int(c.walked / (TILE / 2.0)) % WALK_CYCLE.size()] if not c.path.is_empty() else 0
		var src := Rect2(Vector2(frame, c.facing) * TILE, Vector2.ONE * TILE)
		var dst := Rect2(at, Vector2.ONE * TILE)
		draw_texture_rect_region(COLONIST_BASE, dst, src)
		draw_texture_rect_region(COLONIST_HAIR, dst, src, c.hair)
		draw_texture_rect_region(COLONIST_TUNIC, dst, src, c.tunic)
		draw_texture_rect_region(COLONIST_CAPE, dst, src, c.cape)
		if c.carrying > 0:
			draw_rect(Rect2(at + Vector2(10, 7), Vector2(5, 5)), Color("8b5a2b"))
		if c.job == Job.CHOP and c.path.is_empty():  # barra di avanzamento del taglio
			draw_rect(Rect2(c.pos + Vector2(-6, -11), Vector2(12 * (1 - c.work_left / CHOP_TIME), 2)), Color.YELLOW)
	if drag_start != null:
		var r := selection_rect()
		draw_rect(Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE), Color.ORANGE, false, 1.0)


func center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2.ONE * TILE / 2.0


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i((pos / TILE).floor())
