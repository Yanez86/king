# Esegui: godot --headless --path . -s tests/test_jobs.gd
extends SceneTree


func _initialize() -> void:
	seed(1)  # mappa sempre uguale
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame  # aspetta che venga chiamato _ready

	var trees_before: int = main.trees.size()
	main.mark_trees(Rect2i(main.MAP_SIZE / 2 - Vector2i(8, 8), Vector2i(16, 16)))
	var marked: int = main.chop_marks.size()
	check(marked > 0, "ci sono alberi segnati vicino alla partenza")

	for i in 10000:  # 500 secondi simulati
		main.tick(0.05)

	var chopped: int = trees_before - main.trees.size()
	var capacity: int = main.stockpile.size() * main.STACK_MAX
	check(chopped == marked, "tagliati tutti gli alberi segnati")
	check(main.total_wood() == chopped * main.WOOD_PER_TREE, "nessuna legna persa o creata")
	check(main.stored_wood() == mini(main.total_wood(), capacity), "trasportata finché c'è posto")
	for cell in main.stockpile:
		check(main.wood.get(cell, 0) <= main.STACK_MAX, "nessuna pila oltre il limite")
	for c in main.colonists:
		check(c.job == main.Job.NONE, "coloni liberi a fine lavoro")
	check(main.reserved.is_empty(), "nessuna prenotazione rimasta")

	var c = main.colonists[0]
	c.job = main.Job.HAUL  # finto lavoro: deve solo camminare
	c.path.assign([main.cell_of(c.pos) + Vector2i.LEFT])
	main.tick(0.05)
	check(c.facing == main.Facing.LEFT and c.walked > 0, "guarda e cammina verso sinistra")
	print("OK: %d alberi, %d legna, %d nel magazzino (capienza %d)" \
		% [chopped, main.total_wood(), main.stored_wood(), capacity])
	quit()


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
