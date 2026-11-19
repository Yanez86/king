# Esegui: godot --headless --path . -s tests/test_medicine.gd
# Medicina e morte (GDD 4.2.2): le erbe medicinali nei prati, l'unguento al fuoco e chi se lo spalma, l'abilità
# Medicina; il salvataggio di prima delle erbe
extends SceneTree

const SAVES := preload("res://saves.gd")

var main


func _initialize() -> void:
	TranslationServer.set_locale("en")  # i testi confrontati sono quelli inglesi
	seed(3)
	main = load("res://main.tscn").instantiate()
	main.game_start = false  # e tutte le ricerche fatte
	main.settings_file = ""
	root.add_child(main)
	await process_frame
	main.events = false
	main.needs_rate = 0.0  # i punti ferita non tornano da soli: si vede solo l'unguento
	main.routines = false
	main.deaths = false
	main.animals.clear()
	var R = main.Res
	var B = main.Build
	var mid: Vector2i = main.MAP_SIZE / 2
	var a = main.colonists[0]
	var b = main.colonists[1]
	var c = main.colonists[2]

	# --- Erboristeria ---

	# l'abilità Medicina: l'ultima, a 0 per tutti; col suo nome e la sua icona
	check(main.Skill.MEDICINE == main.Skill.size() - 1 and main.colonists.all(func(o): return o.skills.size() == main.Skill.size() \
		and o.skills[main.Skill.MEDICINE] == 0), "l'abilità Medicina, a 0")
	check(main.named(main.Skill, main.Skill.MEDICINE, "skill") == "Medicine", "si chiama Medicine")

	# le erbe medicinali: cespugli sparsi nei prati, fuori dalla radura, mai su alberi, acqua o roccia
	var herbs: Array = main.herbs.keys()
	check(herbs.size() > 20, "erbe nei prati: %d" % herbs.size())
	check(herbs.all(func(k): return main.bushes.has(k) and not main.flax.has(k) and Vector2(k - mid).length() >= 4 \
		and not main.trees.has(k) and not main.water.has(k) and not main.rocks.has(k)), "dove c'è prato libero")
	main.sort_by_distance(herbs, main.center(mid))
	var herb: Vector2i = herbs[0]
	check(main.bush_res(herb) == R.HERBS and main.plant_col(herb) == 5, "danno erbe, e hanno il loro disegno")
	check(main.describe(herb)[0] == "Medicinal herbs" and main.describe(herb)[1].begins_with("Herbs: 5 / 5"),
		"col mouse sopra: %s" % str(main.describe(herb)))
	check(main.STACK_MAX[R.HERBS] > 0 and not main.SHELF_LIFE.has(R.HERBS) and main.ICONS.has(R.HERBS), "non marciscono")

	# raccolte col segno Harvest, come le bacche: 5 erbe, poi rifioriscono
	for o in [b, c]:
		for w in main.Work.values():
			main.set_priority(o, w, 0)  # gli altri due stanno a guardare
	main.harvest_marks[herb] = true
	check(main.try_work_kind(a, main.Work.GATHER) and a.target == herb, "si raccolgono")
	walk_until(func(): return main.bushes[herb] > main.clock and a.job == main.Job.NONE and a.carrying == 0, 6000)
	check(main.total(R.HERBS) == main.BERRIES_PER_BUSH, "5 erbe (%d)" % main.total(R.HERBS))
	check(is_equal_approx(main.bushes[herb], main.clock + main.BERRY_REGROW) or main.bushes[herb] > main.clock,
		"rifioriscono fra 2 giorni")
	check(main.describe(herb)[1].begins_with("Herbs in"), "in fiore fra poco: %s" % main.describe(herb)[1])
	main.harvest_marks.clear()
	for res in [R.HERBS]:
		main.items[res].clear()

	# estirpate se ne vanno
	var other: Vector2i = herbs[1]
	main.uproot_marks[other] = true
	check(main.try_work_kind(a, main.Work.GATHER) and a.job == main.Job.UPROOT, "si estirpano")
	walk_until(func(): return not main.bushes.has(other), 4000)
	check(not main.herbs.has(other), "estirpate non ci sono più")

	# l'unguento: dall'Erboristeria, al fuoco da campo di una cucina, 2 erbe, con l'abilità Medicina; se ne tengono 3
	var recipe: Array = main.RECIPES.filter(func(r): return r[0] == R.OINTMENT)[0]
	check(recipe[1] == B.CAMPFIRE and recipe[2] == main.Skill.MEDICINE and recipe[3] == {R.HERBS: 2},
		"la ricetta dell'unguento")
	check(main.tech_for("makes", R.OINTMENT) == main.Tech.HERBALISM and main.TECHS[main.Tech.HERBALISM]["tier"] == 1
		and main.TECHS[main.Tech.HERBALISM]["branch"] == main.Branch.LORE, "dall'Erboristeria, Sapere I")
	check(main.keep[R.OINTMENT] == 3, "se ne tengono 3")
	clear(Rect2i(mid + Vector2i(6, -4), Vector2i(9, 9)))
	wall_room(Rect2i(mid + Vector2i(7, -3), Vector2i(7, 7)), mid + Vector2i(10, 3))
	main.update_rooms()
	var kitchen = main.room_at(mid + Vector2i(10, 0))
	var fire: Vector2i = mid + Vector2i(10, -1)
	main.furniture[fire] = [B.CAMPFIRE, R.WOOD, 0]
	kitchen.kind = main.RoomKind.KITCHEN
	main.keep[R.MEAL] = 0
	main.drop(R.HERBS, mid + Vector2i(10, 1), 2)
	main.researched.erase(main.Tech.HERBALISM)
	check(not main.try_craft(a), "senza l'Erboristeria niente unguento")
	main.researched[main.Tech.HERBALISM] = true
	check(main.try_craft(a) and main.RECIPES[a.recipe][0] == R.OINTMENT and a.target == fire, "con l'Erboristeria sì")
	walk_until(func(): return a.job == main.Job.NONE, 4000)
	check(main.total(R.OINTMENT) == 1 or main.total(R.HERBS) == 0, "fatto (o rovinato)")
	check(a.xp[main.Skill.MEDICINE] == 1, "+1 esperienza in Medicina")
	main.keep[R.OINTMENT] = 0
	for res in [R.OINTMENT, R.HERBS]:
		main.items[res].clear()

	# chi è ferito, sotto 60, se lo spalma: va al mucchio, lo prende, 3 s, +30
	var spot: Vector2i = mid + Vector2i(0, 3)
	main.drop(R.OINTMENT, spot, 2)
	a.hp = 65.0
	main.find_job(a)
	check(a.job != main.Job.SALVE, "a 65 no")
	main.quit_job(a)
	a.hp = 40.0
	main.find_job(a)
	check(a.job == main.Job.SALVE and a.target == spot, "a 40 va a prendere l'unguento")
	walk_until(func(): return a.carrying == 1, 2000)
	check(a.carry_res == R.OINTMENT and main.items[R.OINTMENT][spot] == 1, "lo prende dal mucchio")
	check(main.DOING[main.Job.SALVE] == "Tending a wound", "cosa fa")
	walk_until(func(): return a.job == main.Job.NONE, 400)
	check(is_equal_approx(a.hp, 70.0) and a.carrying == 0, "+30 punti ferita (%.1f)" % a.hp)
	check(a.xp[main.Skill.MEDICINE] == 1, "spalmarselo non insegna niente")
	main.find_job(a)
	check(a.job != main.Job.SALVE, "a 70 basta")
	main.quit_job(a)
	a.hp = 95.0
	a.pos = main.center(mid + Vector2i(2, 0))  # via dal mucchio: lì non si fermano in due
	b.hp = 20.0
	main.find_job(b)
	check(b.job == main.Job.SALVE and is_equal_approx(b.work_total, main.SALVE_TIME), "anche gli altri")
	main.quit_job(b)
	check(main.items[R.OINTMENT][spot] == 1, "mollato prima di prenderlo, l'unguento resta lì")
	b.hp = 100.0

	# gli ospiti no
	var guest = main.new_hero(main.Hero.WARRIOR, 1)
	guest.pos = main.center(mid)
	main.guests.append(guest)
	guest.hp = 20.0
	main.drop(R.OINTMENT, spot, 1)
	main.find_job(guest)
	check(guest.job != main.Job.SALVE, "un avventuriero non usa gli unguenti della colonia")
	main.guests.erase(guest)
	main.items[R.OINTMENT].clear()

	# --- Salvataggio ---

	# una partita di prima delle erbe e dell'abilità: caricata, le erbe spuntano sul prato e la Medicina è a 0
	for o in main.colonists:
		o.skills.resize(main.Skill.MEDICINE)
		o.xp.resize(main.Skill.MEDICINE)
	main.keep.erase(R.OINTMENT)
	for k in main.herbs:  # allora non c'erano
		main.bushes.erase(k)
	main.herbs.clear()
	var state: Dictionary = main.game_state()
	state["main"].erase("herbs")
	SAVES.pending = state
	var copy = load("res://main.tscn").instantiate()
	copy.game_start = false
	copy.settings_file = ""
	root.add_child(copy)
	await process_frame
	check(copy.herbs.size() > 20 and copy.herbs.keys().all(func(k): return copy.bushes.has(k) and not copy.rocks.has(k) \
		and not copy.astar.is_point_solid(k) and copy.room_at(k) == null), "erbe spuntate sul prato: %d" % copy.herbs.size())
	check(copy.colonists.all(func(o): return o.skills.size() == copy.Skill.size() and o.xp.size() == copy.Skill.size() \
		and o.skills[copy.Skill.MEDICINE] == 0), "la Medicina a 0")
	check(copy.keep[R.OINTMENT] == 3, "la scorta dell'unguento")
	copy.free()
	Engine.time_scale = 1.0

	print("OK: medicina e morte (erbe e unguento)")
	quit()


func walk_until(done: Callable, ticks: int) -> void:
	for i in ticks:
		if done.call():
			return
		main.tick(0.05)
	check(done.call(), "arrivato in tempo")


# toglie dal rettangolo alberi, rocce, acqua, cespugli, erbacce e mucchi
func clear(rect: Rect2i) -> void:
	for cell in main.cells_in(rect):
		for plants in [main.trees, main.bushes, main.flax, main.herbs, main.weeds, main.water, main.rocks, main.ores,
				main.boulders]:
			plants.erase(cell)
		main.astar.set_point_solid(cell, false)
		main.astar.set_point_weight_scale(cell, 1.0)
		for res in main.items:
			main.items[res].erase(cell)


# muri di legno sul bordo del rettangolo, con una porta in `door`
func wall_room(rect: Rect2i, door: Vector2i) -> void:
	for cell in main.cells_in(rect):
		if cell.x in [rect.position.x, rect.end.x - 1] or cell.y in [rect.position.y, rect.end.y - 1]:
			main.built[cell] = [main.Build.DOOR if cell == door else main.Build.WALL, main.Res.WOOD]
			if cell != door:
				main.astar.set_point_solid(cell)


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
