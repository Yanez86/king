# Esegui: godot --headless --path . -s tests/test_jobs.gd
extends SceneTree


func _initialize() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame  # aspetta che venga chiamato _ready

	var trees_before: int = main.trees.size()
	main.mark_trees(Rect2i(Vector2i.ZERO, main.MAP_SIZE))
	check(main.chop_marks.size() == trees_before, "tutti gli alberi segnati")

	for i in 2000:  # 100 secondi simulati
		main.tick(0.05)

	var chopped: int = trees_before - main.trees.size()
	check(chopped > 0, "i coloni hanno tagliato alberi")
	check(main.total_wood() == chopped * main.WOOD_PER_TREE, "legna = alberi tagliati x resa")
	var busy := {}
	for c in main.colonists:
		if c.job != null:
			check(not busy.has(c.job), "due coloni sullo stesso albero")
			busy[c.job] = true
	print("OK: %d alberi tagliati, %d legna" % [chopped, main.total_wood()])
	quit()


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
