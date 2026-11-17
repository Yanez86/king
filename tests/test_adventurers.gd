# Esegui: godot --headless --path . -s tests/test_adventurers.gd
# Avventurieri e rovine (locanda, arrivi, ingaggio con l'oro, spedizione alla torre, ritorno), morte e lutto
extends SceneTree

var main


var lost := false


func _initialize() -> void:
	seed(1)
	main = load("res://main.tscn").instantiate()
	main.start_rooms = false
	root.add_child(main)
	await process_frame
	main.needs_rate = 0.0
	main.routines = false  # niente orari: la routine è provata in test_jobs
	main.threats = false
	main.animals.clear()
	var R = main.Res
	var B = main.Build
	var mid: Vector2i = main.MAP_SIZE / 2
	var tower = main.ruins[0]
	check(main.ruins.size() == 1 and tower.kind == main.RuinKind.TOWER and tower.cleared == 0, "si conosce solo la torre")
	check(main.ICONS.has(R.GOLD) and main.STACK_MAX[R.GOLD] == 100, "l'oro: monete, a mucchi da 100")

	# senza locanda non arriva nessuno, e il prossimo arrivo slitta
	main.clock = main.next_guest + 0.1
	main.update_guests()
	check(main.guests.is_empty() and main.next_guest > main.clock, "senza locanda nessun avventuriero")

	# la locanda: letto, tavolo e bacheca; senza la bacheca non lo è
	var inn = make_room(mid)
	main.furniture[mid + Vector2i(-2, -2)] = [B.BED, R.WOOD, 0]
	main.furniture[mid + Vector2i(1, -2)] = [B.TABLE, R.WOOD, 0]
	check(not main.room_meets(inn, main.RoomKind.INN), "senza bacheca non è una locanda")
	var board := mid + Vector2i(-2, 1)
	main.furniture[board] = [B.NOTICE_BOARD, R.WOOD, 0]
	check(main.room_meets(inn, main.RoomKind.INN) and main.ROOM_CLASS[main.RoomKind.INN] == main.RoomClass.SERVICE, "locanda: servizio")
	inn.kind = main.RoomKind.INN
	var store := mid + Vector2i(8, 0)  # un magazzino all'aperto, con l'oro
	clear(store)
	main.stockpile = {store: true}
	main.add_item(R.GOLD, store, 12)

	# i letti della locanda sono degli avventurieri, gli altri dei coloni
	var bed := mid + Vector2i(-2, -2)
	var colonist = main.colonists[0]
	for o in main.colonists:
		o.pos = main.center(mid + Vector2i(-6 - main.colonists.find(o), 0))
	check(bed not in main.free_beds(colonist), "i coloni non dormono alla locanda")

	# arriva un avventuriero dal bordo e va alla locanda
	main.next_guest = main.clock
	main.update_guests()
	check(main.guests.size() == 1, "con un letto alla locanda arriva un avventuriero")
	var g = main.guests[0]
	var start: Vector2i = main.cell_of(g.pos)
	check(start.x in [0, main.MAP_SIZE.x - 1] or start.y in [0, main.MAP_SIZE.y - 1], "dal bordo della mappa")
	check(g.hero != main.Hero.NONE and g.level >= 1 and g.level <= 2 and g.errand == main.Errand.ARRIVE and g.job == main.Job.TRAVEL,
		"un %s di livello %d, in cammino" % [main.Hero.keys()[g.hero], g.level])
	var data: Dictionary = main.HEROES[g.hero]
	check(g.gear.get(main.Slot.HANDS) == data["gear"][main.Slot.HANDS] and g.kit == data["kit"], "porta l'equipaggiamento della classe")
	for skill in data["skills"]:
		check(g.skills[skill] == data["skills"][skill] * g.level, "abilità della classe secondo il livello")
	check(main.fee(g) == main.FEE_BASE + main.FEE_PER_LEVEL * g.level, "paga secondo il livello")
	main.update_guests()
	check(main.guests.size() == 1, "un letto, un avventuriero")
	walk_until(func(): return g.errand == main.Errand.NONE, 4000)
	check(main.room_at(main.cell_of(g.pos)) == inn and is_equal_approx(g.stay_until, main.clock + main.GUEST_STAY), "arrivato alla locanda, aspetta")
	check(main.free_beds(g) == [bed], "dorme solo nei letti della locanda")
	main.find_job(g)
	check(g.job not in main.WORK_JOBS, "non lavora")

	# la bacheca: chi aspetta, col tasto per la torre; l'oro non basta
	main.open_board()
	var box = main.get_node("HUD/BoardPanel/Box")
	check(main.get_node("HUD/BoardPanel").visible and box.get_node("Heroes").get_child_count() == 1, "la bacheca mostra chi aspetta")
	var send: Button = box.get_node("Heroes").get_child(0).get_child(2)
	check(send.disabled == (main.fee(g) > 12), "senza abbastanza oro non si ingaggia")
	check(not main.hire(g, tower) or main.fee(g) <= 12, "ingaggio rifiutato")
	main.add_item(R.GOLD, store, 50)
	var gold_before: int = main.stored(R.GOLD)
	check(main.hire(g, tower), "ingaggiato")
	check(main.stored(R.GOLD) == gold_before - main.fee(g) and g.hired and g.errand == main.Errand.DEPART, "pagato, va al bordo")
	check(not main.hire(g, tower), "non due volte")
	var exp = main.expeditions[0]
	walk_until(func(): return g not in main.guests, 6000)
	check(g not in main.guests and exp.left_at >= 0 and exp.back_at > main.clock and not exp.lines.is_empty(), "partito: è nella rovina")
	main._process(0.0)
	check("EXPEDITION: 1" in main.info_label.text, "in alto: una spedizione")
	check(exp.lost or tower.cleared > 0 or "collapse" in "".join(exp.lines), "ha esplorato qualcosa")

	# ritorno: col bottino (meno la quota) alla locanda; il diario in una finestra e nella cronaca
	exp.loot = {R.GOLD: 20, R.IRON: 5}
	lost = exp.lost
	print("\n".join(exp.lines))
	main.clock = exp.back_at
	main.update_expeditions()
	check(main.expeditions.is_empty() and main.get_node("HUD/ReportPanel").visible and main.chronicle.size() >= 2, "il diario")
	if not lost:
		check(g in main.guests and g.errand == main.Errand.RETURN and g.trips == 1, "torna dal bordo")
		check(g.loot[R.GOLD] == 20 - floori(20 * main.SHARE) and g.loot[R.IRON] == 5, "si tiene il 30% delle monete")
		walk_until(func(): return g.errand == main.Errand.NONE, 6000)
		check(main.total(R.IRON) == 5 and not g.hired, "lascia il bottino alla locanda")
		# chi aspetta troppo se ne va
		main.clock = g.stay_until
		main.update_guests()
		check(g.errand == main.Errand.LEAVE, "nessuno lo ingaggia: se ne va")
		walk_until(func(): return g not in main.guests, 6000)
		check(g not in main.guests, "andato via")

	# nella rovina, per conto suo: il guardiano ferisce di più chi regge di meno
	var warrior = main.new_hero(main.Hero.WARRIOR, 1)
	var burglar = main.new_hero(main.Hero.BURGLAR, 1)
	check(main.gear_sum(warrior, "armor") == 8, "guerriero: cuoio, elmo e scudo")
	check(main.new_hero(main.Hero.WARRIOR, main.HEAVY_LEVEL).gear[main.Slot.BODY] == R.CHAINMAIL, "da livello 3 la cotta")
	for c in [warrior, burglar]:
		var e = main.Expedition.new()
		e.party.append(c)
		main.fight_monsters(e, main.MONSTER_POWER)
	check(warrior.hp > burglar.hp and burglar.hp < main.MAX_HP, "i mostri fanno più male allo scassinatore")
	# forzieri: lo scassinatore li apre tutti, e con la sacca porta di più; il guerriero non quelli chiusi
	var opened := 0
	for i in 200:
		var e = main.Expedition.new()
		e.party.append(warrior if i % 2 else burglar)
		opened += 1 if main.open_chest(e, main.RUINS[tower.kind]).begins_with("a chest") and i % 2 else 0
		if i % 2 == 0:
			check(e.loot[R.GOLD] >= 15 and e.loot[R.GOLD] <= 38, "lo scassinatore apre tutto, +50%")
	check(opened > 20 and opened < 80, "il guerriero apre circa metà dei forzieri (%d su 100)" % opened)
	# da solo e senza forze, il guardiano lo uccide: spedizione persa
	var doomed = main.new_hero(main.Hero.ARCHER, 1)
	doomed.hp = 1.0
	var ruin = main.Ruin.new()
	ruin.cleared = main.RUINS[ruin.kind]["rooms"] - 1
	var e2 = main.Expedition.new()
	e2.party.append(doomed)
	e2.ruin = ruin
	main.depart(e2)
	check(e2.lost and e2.party.is_empty() and is_equal_approx(e2.back_at - main.clock, (e2.due - main.clock) * main.LOST_AFTER),
		"nessuno torna: la si dà per persa al doppio del tempo")
	# livelli: ogni 2 spedizioni tornate
	var vet = main.new_hero(main.Hero.ARCHER, 1)
	vet.trips = 1
	var e3 = main.Expedition.new()
	e3.party.append(vet)
	e3.ruin = ruin
	e3.left_at = main.clock
	e3.back_at = main.clock
	e3.edge = start
	main.expeditions.append(e3)
	main.update_expeditions()
	check(vet.trips == 2 and vet.level == 2 and vet.skills[main.Skill.RANGED] == 4, "sale di livello")
	main.guests.erase(vet)

	# morte: la protezione abbassa la probabilità di morire; a terra, il morso uccide
	check(is_equal_approx(main.death_chance(colonist), main.DEATH_BASE) or not colonist.gear.is_empty(), "senza protezione 25%")
	colonist.gear = {main.Slot.BODY: R.CHAINMAIL, main.Slot.HEAD: R.HELMET}
	check(is_equal_approx(main.death_chance(colonist), main.DEATH_MIN), "con cotta ed elmo al minimo")
	var others: Array = main.colonists.filter(func(o): return o != colonist)
	for o in others:
		o.pos = main.center(mid)  # al chiuso, nella locanda
	colonist.pos = main.center(mid + Vector2i(0, 8))
	colonist.hp = 0.0
	colonist.downed = true
	var wolf = main.add_animal(main.Beast.WOLF, mid + Vector2i(0, 12))
	main.update_wolf(wolf, 0.05)
	check(wolf.target == colonist, "nessuno in piedi fuori: il lupo va da chi è a terra")
	var spot: Vector2i = main.cell_of(colonist.pos)
	main.bite(wolf, colonist)
	check(colonist not in main.colonists and colonist in main.corpses and wolf.target == null, "a terra, il morso uccide")
	check(main.total(R.CHAINMAIL) == 1 and main.total(R.HELMET) == 1, "l'equipaggiamento resta per terra")
	check(others.all(func(o): return o.conds.has(main.Cond.MOURNING)), "gli altri sono in lutto")
	check("killed by wolves" in main.chronicle[-1], "nella cronaca")
	check(not main.fallen, "la colonia c'è ancora")
	main.queue_redraw()
	await process_frame  # disegna il corpo e chi è vivo
	main.clock += main.CORPSE_DAYS
	main.tick(0.0)
	check(main.corpses.is_empty(), "il corpo sparisce dopo un giorno")
	for o in others:
		main.die(o, "died.")
	check(main.colonists.is_empty() and main.fallen and main.get_node("HUD/Fallen").visible, "morti tutti: la colonia è caduta")
	print("OK: avventurieri, torre e morte (la prima spedizione è %s)" % ("persa" if lost else "tornata"))
	quit()


# stanza 5x5 di legno attorno a `mid`, porta in basso
func make_room(mid: Vector2i):
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var k := mid + Vector2i(dx, dy)
			clear(k)
			if k == mid + Vector2i(0, 3):
				main.built[k] = [main.Build.DOOR, main.Res.WOOD]
			elif maxi(absi(dx), absi(dy)) == 3:
				main.built[k] = [main.Build.WALL, main.Res.WOOD]
				main.astar.set_point_solid(k)
	clear(mid + Vector2i(0, 4))
	main.update_rooms()
	return main.room_at(mid)


func clear(k: Vector2i) -> void:
	for layer in [main.trees, main.rocks, main.bushes, main.weeds, main.water, main.boulders]:
		layer.erase(k)
	main.astar.set_point_solid(k, false)


# fa andare avanti il gioco finché `done` non è vero (al massimo `ticks` giri da 0,05 s)
func walk_until(done: Callable, ticks: int) -> void:
	for i in ticks:
		if done.call():
			return
		main.tick(0.05)
	check(done.call(), "arrivato in tempo")


func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FALLITO: " + what)
		quit(1)
