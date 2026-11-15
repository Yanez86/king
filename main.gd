extends Node2D

const MAP_SIZE := Vector2i(100, 100)
const TILE := 16            # pixel per tile
const SPEED := 4.0          # tile al secondo
const CHOP_TIME := 3.0      # secondi per abbattere un albero
const WOOD_PER_TREE := 10
const COLONIST_COUNT := 3


class Colonist:
	var pos: Vector2
	var path: Array[Vector2i] = []
	var job = null          # cella dell'albero da tagliare, o null se libero
	var work_left := 0.0


var astar := AStarGrid2D.new()
var rocks := {}             # cella -> true (non attraversabile)
var trees := {}             # cella -> true (attraversabile)
var chop_marks := {}        # cella -> Colonist che l'ha prenotato, o null se libero
var wood := {}              # cella -> quantità a terra
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
	for i in COLONIST_COUNT:
		var c := Colonist.new()
		c.pos = center(MAP_SIZE / 2 + Vector2i(i - 1, 0))
		colonists.append(c)
	camera.position = center(MAP_SIZE / 2)


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
	hud.text = "Wood: %d    Speed: %dx    (Space = pause, 1-3 = speed)" % [total_wood(), Engine.time_scale]
	queue_redraw()


func tick(delta: float) -> void:
	for c in colonists:
		update_colonist(c, delta)


func update_colonist(c: Colonist, delta: float) -> void:
	if c.job == null:
		find_job(c)
		return
	if not c.path.is_empty():
		var goal := center(c.path[0])
		c.pos = c.pos.move_toward(goal, SPEED * TILE * delta)
		if c.pos == goal:
			c.path.pop_front()
		return
	c.work_left -= delta
	if c.work_left <= 0:
		trees.erase(c.job)
		chop_marks.erase(c.job)
		wood[c.job] = wood.get(c.job, 0) + WOOD_PER_TREE
		c.job = null


func find_job(c: Colonist) -> void:
	var free := chop_marks.keys().filter(func(cell): return chop_marks[cell] == null)
	free.sort_custom(func(a, b): return center(a).distance_squared_to(c.pos) < center(b).distance_squared_to(c.pos))
	# ponytail: "più vicino" in linea d'aria e un percorso per candidato; passare a distanza di percorso se i coloni fanno giri assurdi
	for cell in free:
		var path := astar.get_id_path(cell_of(c.pos), cell)
		if not path.is_empty():
			c.path = path
			c.job = cell
			c.work_left = CHOP_TIME
			chop_marks[cell] = c
			return


func mark_trees(rect: Rect2i) -> void:
	for cell in trees:
		if rect.has_point(cell) and not chop_marks.has(cell):
			chop_marks[cell] = null


func total_wood() -> int:
	var sum := 0
	for amount in wood.values():
		sum += amount
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
	for cell in rocks:
		draw_rect(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), Color("777777"))
	for cell in trees:
		draw_circle(center(cell), TILE * 0.45, Color("2d5a27"))
	for cell in chop_marks:
		draw_rect(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), Color.ORANGE, false, 1.0)
	for cell in wood:
		draw_rect(Rect2(Vector2(cell) * TILE + Vector2.ONE * 4, Vector2.ONE * 8), Color("8b5a2b"))
	for c in colonists:
		draw_circle(c.pos, TILE * 0.4, Color.WHITE)
		if c.job != null and c.path.is_empty():  # barra di avanzamento del lavoro
			draw_rect(Rect2(c.pos + Vector2(-6, -11), Vector2(12 * (1 - c.work_left / CHOP_TIME), 2)), Color.YELLOW)
	if drag_start != null:
		var r := selection_rect()
		draw_rect(Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE), Color.ORANGE, false, 1.0)


func center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2.ONE * TILE / 2.0


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i((pos / TILE).floor())
