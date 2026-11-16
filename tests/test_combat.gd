# Esegui: godot --headless --path . -s tests/test_combat.gd
# Combattimento: branchi di lupi, coloni che combattono o scappano, protezione, a terra e cura
extends SceneTree


func _initialize() -> void:
	seed(1)
	var main = load("res://main.tscn").instantiate()
	main.start_rooms = false
	root.add_child(main)
	await process_frame
	main.needs_rate = 0.0
	main.routines = false  # niente orari: la routine è provata in test_jobs
	main.animals.clear()
	var mid: Vector2i = main.MAP_SIZE / 2
	var area := Rect2i(mid - Vector2i(10, 10), Vector2i(20, 20))
	var free: Array = main.cells_in(area).filter(func(k): return main.can_build(k))
	main.sort_by_distance(free, main.center(mid))
	var a = main.colonists[0]
	var b = main.colonists[1]
	var c = main.colonists[2]

	# branco: entra da un bordo, 2 o 3 lupi ostili che dopo un giorno se ne vanno
	main.clock = main.next_pack
	main.tick(0.0)
	var pack: Array = main.animals.filter(func(w): return main.hostile(w))
	check(pack.size() >= main.PACK[0] and pack.size() <= main.PACK[1], "arriva un branco di %d lupi" % pack.size())
	for w in pack:
		var k: Vector2i = main.cell_of(w.pos)
		check(mini(mini(k.x, k.y), mini(main.MAP_SIZE.x - 1 - k.x, main.MAP_SIZE.y - 1 - k.y)) <= 2, "dal bordo della mappa")
		check(is_equal_approx(w.leave_at, main.clock + main.WOLF_STAY), "se ne andranno")
	check(main.next_pack == main.clock + main.WOLF_EVERY, "il prossimo fra qualche giorno")
	main._process(0.0)
	check(main.info_label.text.begins_with("WOLVES: %d" % pack.size()), "barra in alto: lupi in giro")
	check(main.describe(main.cell_of(pack[0].pos))[1].begins_with("Hostile"), "suggerimento: ostile")
	main.animals.clear()

	# numeri: protezione, colpire, danni
	check(main.armor_factor(a) == 1.0, "senza armatura tutto il danno")
	a.gear = {main.Slot.BODY: main.Res.CHAINMAIL, main.Slot.HEAD: main.Res.HELMET}
	check(is_equal_approx(main.armor_factor(a), 1.0 - 8 * main.ARMOR_BLOCK), "cotta ed elmo: quasi metà danno")
	a.gear = {}
	check(main.melee_damage(a) == main.FIST_DAMAGE, "a mani nude")
	a.gear = {main.Slot.HANDS: main.Res.SWORD}
	check(main.melee_damage(a) == 15.0 and main.reach(a) == main.MELEE_RANGE, "con la spada, corpo a corpo")
	a.gear = {main.Slot.HANDS: main.Res.AXE}
	check(main.melee_damage(a) == 12.0, "anche l'ascia è un'arma")
	a.gear = {main.Slot.HANDS: main.Res.BOW}
	check(main.reach(a) == main.HUNT_RANGE + 2 and main.has_bow(a), "con l'arco tira da lontano")
	check(is_equal_approx(main.melee_chance(5), 0.5) and is_equal_approx(main.melee_chance(10), 0.75), "corpo a corpo: 50% a livello 5")
	for o in main.colonists:
		for s in main.Skill.values():
			o.skills[s] = 1
	a.skills[main.Skill.MELEE] = 9
	check(main.wanted_tool(a) == main.Res.SWORD and main.RECIPES.any(func(r): return r[0] == main.Res.SWORD), "la spada al più bravo nella mischia, dall'incudine")

	# un lupo vicino: chi sta bene lascia il lavoro e combatte; con la spada lo abbatte
	for o in main.colonists:
		o.pos = main.center(free[main.colonists.find(o) * 2])
		o.gear = {}
	a.gear = {main.Slot.HANDS: main.Res.SWORD, main.Slot.BODY: main.Res.CHAINMAIL}
	a.skills[main.Skill.MELEE] = 10
	var spot: Vector2i = free.filter(func(k): return (k - free[30]).length() > 6 and (k - free[30]).length() < 9)[0]
	b.pos = main.center(spot)  # l'arciere a qualche casella dal lupo
	c.pos = main.center(free[-2])
	b.gear = {main.Slot.HANDS: main.Res.BOW}
	b.skills[main.Skill.RANGED] = 10
	var wolf = main.add_animal(main.Beast.WOLF, free[30])
	main.tick(0.05)
	check(a.job == main.Job.FIGHT and a.prey == wolf, "un lupo vicino: combatte")
	var hp_a: float = a.hp
	var fought_far := false
	for i in 4000:
		main.tick(0.05)
		if b.job == main.Job.FIGHT and main.is_working(b) and b.prey in main.animals:
			check(b.pos.distance_to(b.prey.pos) <= (main.reach(b) + 0.25) * main.TILE, "l'arciere tira da dove arriva")
			fought_far = fought_far or b.pos.distance_to(b.prey.pos) > 2 * main.TILE
		if wolf not in main.animals:
			break
	check(wolf not in main.animals, "lupo abbattuto")
	check(main.total(main.Res.MEAT) == main.BEASTS[main.Beast.WOLF]["meat"] and main.total(main.Res.HIDE) == main.BEASTS[main.Beast.WOLF]["hide"],
		"lascia carne e pelle")
	check(a.xp[main.Skill.MELEE] > 0 and fought_far and b.xp[main.Skill.RANGED] > 0, "esperienza in mischia e a distanza, l'arciere da lontano")
	check(main.colonists.all(func(o): return o.job != main.Job.FIGHT and o.prey == null), "finito il combattimento, tutti liberi")
	check(a.hp <= hp_a, "i morsi fanno male")

	# morsi: la protezione riduce il danno, lo stress sale; a 0 punti ferita si resta a terra
	var bitten = main.Colonist.new()
	bitten.skills = main.Skill.values().map(func(_s): return 1)
	bitten.needs = [100.0, 100.0, 100.0, 100.0, 100.0, 0.0]
	bitten.xp = main.Skill.values().map(func(_s): return 0)
	bitten.trend = bitten.needs.map(func(_v): return 0.0)
	bitten.gear = {main.Slot.BODY: main.Res.CHAINMAIL}
	main.colonists.append(bitten)
	var biter = main.add_animal(main.Beast.WOLF, free[40])
	var bites := 0
	while bitten.hp == main.MAX_HP:
		main.bite(biter, bitten)
		bites += 1
	check(is_equal_approx(bitten.hp, main.MAX_HP - main.BEASTS[main.Beast.WOLF]["bite"] * (1.0 - 5 * main.ARMOR_BLOCK)), "la cotta toglie il 30% del morso")
	check(bitten.needs[main.Need.STRESS] == main.HIT_STRESS, "morso: stress")
	biter.target = bitten
	while not bitten.downed:
		main.bite(biter, bitten)
	check(bitten.hp == 0 and bitten.job == main.Job.NONE and biter.target == null, "a terra: il lupo cerca qualcun altro")
	check(not main.fair_game(biter, bitten), "chi è a terra non lo inseguono")
	main.open_sheet(bitten)
	main._process(0.0)
	check(main.get_node("HUD/ColonistSheet/Box/Health").text == "Health: 0 / 100  (downed)", "scheda: a terra")
	main.animals.clear()
	main.needs_rate = 1.0
	var down_ticks := 0
	while bitten.downed and down_ticks < 10000:
		main.update_colonist(bitten, 0.05)
		down_ticks += 1
	var expected: float = main.GET_UP / main.DOWNED_REGEN * main.DAY_LENGTH / 0.05
	check(not bitten.downed and absf(down_ticks - expected) < 3, "a terra si cura, a %d punti si rialza" % main.GET_UP)
	main.colonists.erase(bitten)
	main.needs_rate = 0.0

	# ferito, con un lupo vicino: scappa nella stanza più vicina e lì aspetta; nelle stanze i lupi non entrano
	var den = main.Room.new()
	for k in main.cells_in(Rect2i(free[10], Vector2i(2, 2))):
		den.cells[k] = true
	main.rooms.append(den)
	for o in main.colonists:
		o.hp = main.MAX_HP
	c.hp = main.FLEE_HP - 1
	c.pos = main.center(free[0])
	a.pos = main.center(free[-1])  # gli altri lontani: il lupo insegue c
	b.pos = main.center(free[-2])
	b.gear = {}
	var hunter = main.add_animal(main.Beast.WOLF, free[25])
	main.tick(0.05)
	check(c.job == main.Job.FLEE, "ferito: scappa")
	for i in 400:
		main.tick(0.05)
		if c.path.is_empty() and main.room_at(main.cell_of(c.pos)) == den:
			break
	check(main.room_at(main.cell_of(c.pos)) == den, "al riparo nella stanza")
	for i in 200:
		main.tick(0.05)
		check(main.room_at(main.cell_of(c.pos)) == den and c.job == main.Job.NONE, "al riparo non esce a lavorare")
		check(main.room_at(main.cell_of(hunter.pos)) == null, "il lupo non entra")
	check(hunter.target != c, "il lupo non insegue chi è al chiuso")
	main.rooms.erase(den)
	main.animals.clear()

	# senza nessuno da inseguire (tutti al chiuso), il branco dopo WOLF_STAY se ne va
	var hall = main.Room.new()
	for k in main.cells_in(area):
		hall.cells[k] = true
	main.rooms.append(hall)
	var lone = main.add_animal(main.Beast.WOLF, Vector2i(2, 2))
	lone.leave_at = main.clock + 0.01
	for i in 200:
		main.tick(0.05)
		check(lone.target == null or lone not in main.animals, "nessuno da inseguire")
	check(lone not in main.animals, "il lupo se ne va")
	main.rooms.erase(hall)

	# a caccia: un lupo segnato, colpito o mancato, attacca chi tira
	var prey = main.add_animal(main.Beast.WOLF, free[5])
	main.startle(prey, b)
	check(prey.target == b, "il lupo preso di mira attacca il cacciatore")
	var deer = main.add_animal(main.Beast.DEER, free[6])
	main.startle(deer, b)
	check(deer.fleeing, "il cervo invece scappa")

	print("OK: combattimento")
	quit()


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
