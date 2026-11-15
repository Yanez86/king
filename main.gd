extends Node2D

const MAP_SIZE := Vector2i(100, 100)
const TILE := 16            # pixel per tile
const SPEED := 4.0          # tile al secondo
const ROCK_COUNT := 800

var astar := AStarGrid2D.new()
var rocks: Array[Vector2i] = []
var colonist_pos := Vector2(MAP_SIZE / 2) * TILE + Vector2.ONE * TILE / 2.0
var path: Array[Vector2i] = []

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	astar.region = Rect2i(Vector2i.ZERO, MAP_SIZE)
	astar.cell_size = Vector2.ONE * TILE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()

	for i in ROCK_COUNT:
		var cell := Vector2i(randi() % MAP_SIZE.x, randi() % MAP_SIZE.y)
		if cell != cell_of(colonist_pos):
			astar.set_point_solid(cell)
			rocks.append(cell)

	camera.position = colonist_pos


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var target := cell_of(get_global_mouse_position())
				if astar.is_in_boundsv(target) and not astar.is_point_solid(target):
					path = astar.get_id_path(cell_of(colonist_pos), target)
			MOUSE_BUTTON_WHEEL_UP:
				zoom_by(1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_by(1 / 1.1)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		camera.position -= event.relative / camera.zoom
	elif event is InputEventPanGesture:      # trackpad: due dita
		camera.position += event.delta * 10 / camera.zoom
	elif event is InputEventMagnifyGesture:  # trackpad: pizzico
		zoom_by(event.factor)


func zoom_by(factor: float) -> void:
	camera.zoom = (camera.zoom * factor).clamp(Vector2.ONE * 0.5, Vector2.ONE * 8)


func _process(delta: float) -> void:
	if path.is_empty():
		return
	var goal := Vector2(path[0]) * TILE + Vector2.ONE * TILE / 2.0
	colonist_pos = colonist_pos.move_toward(goal, SPEED * TILE * delta)
	if colonist_pos == goal:
		path.pop_front()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_SIZE * TILE)), Color("4a7a3a"))
	for cell in rocks:
		draw_rect(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), Color("777777"))
	for cell in path:
		draw_circle(Vector2(cell) * TILE + Vector2.ONE * TILE / 2.0, 2, Color.YELLOW)
	draw_circle(colonist_pos, TILE * 0.4, Color.WHITE)


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i((pos / TILE).floor())
