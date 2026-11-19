# Esegui: godot --headless --path . -s tests/test_medicine.gd
# Medicina e morte (GDD 4.2.2): le erbe medicinali nei prati, l'unguento al fuoco e chi se lo spalma, l'abilità
# Medicina; l'infermeria, il riposo a letto, il medico che soccorre e cura, la febbre; le tombe, la sepoltura e il lutto
# più corto; la legge Funerali e il memoriale dei caduti; il salvataggio
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

	# --- Medicina ---

	var M = main.Tech.MEDICINE
	check(main.TECHS[M]["tier"] == 2 and main.TECHS[M]["needs"] == [main.Tech.HERBALISM] and main.TECHS[M]["builds"] == [B.MEDICINE_CHEST]
		and main.TECHS[M]["rooms"] == [main.RoomKind.INFIRMARY], "la Medicina: Sapere II, dopo l'Erboristeria; l'armadio e l'infermeria")
	check(main.WORK_ORDER[0] == main.Work.DOCTOR and main.WORK_ORDER.size() == main.Work.size(), "Curare: la prima colonna")
	check(main.named(main.Work, main.Work.DOCTOR, "work") == "Doctor", "si chiama Doctor")

	# l'infermeria: un letto e l'armadio dei rimedi
	var ward_rect := Rect2i(mid + Vector2i(-16, -4), Vector2i(9, 9))
	clear(ward_rect)
	wall_room(ward_rect.grow(-1), mid + Vector2i(-12, 3))
	var bed1: Vector2i = mid + Vector2i(-14, -2)
	var bed2: Vector2i = mid + Vector2i(-14, 0)
	var chest: Vector2i = mid + Vector2i(-10, -2)
	main.furniture[bed1] = [B.BED, R.WOOD, 0]
	main.furniture[chest] = [B.MEDICINE_CHEST, R.WOOD, 0]
	main.update_rooms()
	var ward = main.room_at(bed1)
	check(ward != null and main.room_meets(ward, main.RoomKind.INFIRMARY), "con un letto e l'armadio può essere un'infermeria")
	main.retype(ward, main.RoomKind.INFIRMARY)
	main.furniture[bed2] = [B.BED, R.WOOD, 0]
	check(main.infirmary_beds().size() == 2, "due letti in infermeria")
	check(not main.free_beds(b).has(bed1) and not main.sick(b), "chi sta bene non ci dorme")
	b.hp = 45.0
	check(main.sick(b) and main.free_beds(b).has(bed1), "chi sta male sì")
	b.hp = 100.0
	b.conds[main.Cond.FEVER] = main.clock + 1.0
	check(main.sick(b), "anche con la febbre")
	b.conds.erase(main.Cond.FEVER)

	# a riposo: chi è sotto 50 va a letto in infermeria e ci resta fino a 80
	for o in [a, b, c]:
		o.pos = main.center(mid + Vector2i(0, 1 + [a, b, c].find(o)))
	b.hp = 45.0
	main.find_job(b)
	check(b.job == main.Job.SLEEP and main.infirmary_beds().size() == 1, "va a letto in infermeria")
	walk_until(func(): return b.path.is_empty(), 2000)
	check(main.in_bed(b) and main.resting(b) and main.doing(b) == "Resting in the infirmary", "ci sta a riposo: %s" % main.doing(b))
	b.needs[main.Need.REST] = 100.0
	main.tick(0.05)
	check(b.job == main.Job.SLEEP, "riposato, resta a letto: è ancora ferito")
	main.needs_rate = 1.0  # le cure: in infermeria il 50% più in fretta, dormendo
	var before: float = b.hp
	main.update_needs(b, 2.0)
	var in_ward: float = b.hp - before
	check(is_equal_approx(in_ward, main.HP_REGEN * 2 * main.INFIRMARY_HEAL * 2.0 / main.DAY_LENGTH), "in infermeria: %.4f" % in_ward)
	main.add_cond(b, main.Cond.TREATED)
	before = b.hp
	main.update_needs(b, 2.0)
	check(is_equal_approx(b.hp - before, in_ward * main.TREATED_HEAL), "medicato: il doppio")
	b.conds.erase(main.Cond.TREATED)
	main.needs_rate = 0.0
	b.hp = 85.0
	main.tick(0.05)
	check(b.job != main.Job.SLEEP or not main.in_bed(b), "a 85 si alza")
	b.hp = 100.0
	main.quit_job(b)

	# il medico: senza la Medicina niente; con la Medicina soccorre chi è a terra e lo porta in infermeria
	for w in main.Work.values():
		main.set_priority(a, w, 0)
	main.set_priority(a, main.Work.DOCTOR, 1)
	var field: Vector2i = mid + Vector2i(-3, 6)
	c.pos = main.center(field)
	c.hp = 0.0
	c.downed = true
	main.quit_job(c)
	main.researched.erase(M)
	check(not main.try_doctor(a), "senza la Medicina nessun medico")
	main.researched[M] = true
	check(main.try_doctor(a) and a.job == main.Job.RESCUE and a.patient == c, "il medico va a soccorrerlo")
	check(not main.try_doctor(b) or b.patient != c, "un altro medico non va dallo stesso")
	main.quit_job(b)
	walk_until(func(): return c.carried_by == a, 2000)
	check(main.doing(c) == "Carried by %s" % a.first_name and main.doing(a) == "Rescuing the wounded", "in spalla: %s" % main.doing(c))
	main.tick(0.05)
	check(c.pos.distance_to(a.pos) < 1.0 and c.pos.y > a.pos.y, "lo porta con sé (disegnato sopra di lui)")

	# salvata a metà strada: il medico e il malato restano legati
	var mid_carry: Dictionary = main.game_state()
	SAVES.pending = mid_carry
	var copy2 = load("res://main.tscn").instantiate()
	copy2.game_start = false
	copy2.settings_file = ""
	root.add_child(copy2)
	await process_frame
	var a2 = copy2.colonists[0]
	var c2 = copy2.colonists[2]
	check(a2.job == copy2.Job.RESCUE and a2.patient == c2 and c2.carried_by == a2, "ricaricata: ancora in spalla")
	copy2.free()
	Engine.time_scale = 1.0

	walk_until(func(): return c.carried_by == null and a.job != main.Job.RESCUE, 3000)
	check(main.on_bed(c) and c.job == main.Job.SLEEP and main.cell_of(c.pos) in [bed1, bed2] and c.downed, "messo a letto, ancora a terra")
	check(main.cell_of(a.pos) != main.cell_of(c.pos) or not a.path.is_empty(), "il medico si fa da parte")

	# poi lo cura: prima va a prendere un unguento, poi accanto al letto; medicato, +30, si rialza
	var pile: Vector2i = mid + Vector2i(-2, 0)
	main.drop(R.OINTMENT, pile, 1)
	walk_until(func(): return a.job == main.Job.TREAT, 400)
	check(a.patient == c and a.target == pile and a.work_total == 0, "prima al mucchio dell'unguento")
	walk_until(func(): return a.job != main.Job.TREAT, 3000)
	check(c.conds.has(main.Cond.TREATED) and is_equal_approx(c.hp, main.SALVE_HEAL) and main.total(R.OINTMENT) == 0,
		"medicato con l'unguento: %.1f" % c.hp)
	check(a.xp[main.Skill.MEDICINE] == 2, "+1 esperienza in Medicina")
	main.tick(0.05)
	check(not c.downed and c.job == main.Job.SLEEP and main.resting(c), "si rialza, ma resta a letto in infermeria")
	check(not main.treatable(c), "medicato non lo si cura di nuovo")
	main.find_job(a)
	check(a.job != main.Job.TREAT, "niente da curare")
	main.quit_job(a)

	# senza letti liberi in infermeria lo cura dove si trova; mollato a metà, il malato resta giù lì
	main.quit_job(c)
	c.pos = main.center(field)
	c.hp = 10.0
	c.downed = true
	c.conds.erase(main.Cond.TREATED)
	main.furniture.erase(bed1)
	main.furniture.erase(bed2)
	check(main.infirmary_beds().is_empty(), "niente letti")
	check(main.try_doctor(a) and a.job == main.Job.TREAT and a.work_total > 0, "lo cura dov'è, senza unguento")
	walk_until(func(): return a.job != main.Job.TREAT, 3000)
	check(c.conds.has(main.Cond.TREATED) and is_equal_approx(c.hp, 10.0), "medicato, senza i 30")
	main.furniture[bed1] = [B.BED, R.WOOD, 0]
	c.conds.erase(main.Cond.TREATED)
	check(main.try_doctor(a) and a.job == main.Job.RESCUE, "di nuovo un letto: lo soccorre")
	walk_until(func(): return c.carried_by == a, 2000)
	walk_until(func(): return a.pos.distance_to(c.pos) < 1.0 and main.cell_of(a.pos) != field, 400)
	var dropped: Vector2i = main.cell_of(a.pos)
	main.quit_job(a)
	check(c.carried_by == null and main.cell_of(c.pos) == dropped and c.pos == main.center(dropped), "mollato, resta giù lì")
	check(not main.try_doctor(c) and c.job == main.Job.NONE, "chi è a terra non cura")

	# la febbre: a letto, il medico la cura e passa entro mezza giornata
	c.hp = 100.0
	c.downed = false
	b.conds[main.Cond.FEVER] = main.clock + 3.0
	b.pos = main.center(mid + Vector2i(0, 2))
	main.find_job(b)
	check(b.job == main.Job.SLEEP, "con la febbre a letto in infermeria")
	walk_until(func(): return b.path.is_empty(), 2000)
	check(main.treatable(b), "da curare")
	check(main.try_doctor(a) and a.patient == b and a.job == main.Job.TREAT, "il medico va da lei")
	walk_until(func(): return a.job != main.Job.TREAT, 3000)
	check(b.conds[main.Cond.FEVER] <= main.clock + main.FEVER_TREATED and b.conds.has(main.Cond.TREATED), "la febbre passa presto")
	main.quit_job(b)
	b.conds.clear()

	# il medico non cura sé stesso
	main.add_cond(a, main.Cond.FEVER)
	a.pos = main.center(bed1)
	var none: Array[Vector2i] = []
	main.start_job(a, main.Job.SLEEP, none, bed1, 0.0)
	main.set_priority(a, main.Work.DOCTOR, 1)
	check(not main.try_doctor(a), "da sé non si cura")
	main.quit_job(a)
	a.conds.clear()
	a.hp = 100.0

	# --- Tombe e sepoltura ---

	var MOURN = main.Cond.MOURNING
	check(main.FURNITURE[B.GRAVE] == Vector2i(1, 2) and main.BUILD_COST[B.GRAVE] == 4 and main.tech_for("builds", B.GRAVE) < 0,
		"la tomba: 1x2, 4 legna, dall'inizio")
	check(not main.piece_fits(mid + Vector2i(-12, -1), [B.GRAVE, R.WOOD, 0]), "non dentro una stanza")
	var yard: Vector2i = mid + Vector2i(-4, 9)
	clear(Rect2i(yard - Vector2i(2, 2), Vector2i(9, 7)))
	check(main.piece_fits(yard, [B.GRAVE, R.WOOD, 0]) and main.piece_fits(yard, [B.GRAVE, R.WOOD, 1]), "sul prato sì, anche coricata")
	main.built[yard] = [B.PATH, R.STONE]
	check(not main.piece_fits(yard, [B.GRAVE, R.WOOD, 0]), "non su un sentiero")
	main.built.erase(yard)

	# muore un colono: il lutto (che si ricorda), il corpo a terra per 2 giorni, col mouse sopra
	var dead = person()
	main.die(dead, "fell asleep in the snow.")
	check(main.corpses.has(dead) and dead.cause == "fell asleep in the snow." and dead.mourned == main.clock + 3.0
		and a.conds[MOURN] == dead.mourned, "il lutto di 3 giorni")
	check(main.describe(main.cell_of(dead.pos))[0] == main.full_name(dead)
		and main.describe(main.cell_of(dead.pos))[1].begins_with("Dead. Gone in 2.0 days"), "il morto a terra: %s" % str(main.describe(main.cell_of(dead.pos))))
	check(not main.try_bury(b), "senza tombe non lo si seppellisce")

	# una tomba vuota: il trasportatore se lo carica in spalla e ce lo seppellisce
	main.furniture[yard] = [B.GRAVE, R.WOOD, 0]
	check(main.empty_graves() == [yard] and main.describe(yard)[1].begins_with("Empty"), "una tomba vuota")
	check(main.piece_rects(yard, main.furniture[yard])[1].position.x == 0, "la fossa aperta")
	main.set_priority(b, main.Work.HAUL, 1)
	b.pos = main.center(mid + Vector2i(2, 2))
	check(main.try_work_kind(b, main.Work.HAUL) and b.job == main.Job.BURY and b.patient == dead, "il trasportatore va dal morto")
	check(not main.try_bury(c), "un altro non va dallo stesso morto")
	walk_until(func(): return dead.carried_by == b, 2000)
	check(main.doing(b) == "Burying %s" % dead.first_name, "cosa fa: %s" % main.doing(b))
	main.clock = dead.died + main.CORPSE_DAYS + 0.1  # in spalla il corpo non sparisce
	main.tick(0.05)
	check(main.corpses.has(dead), "in spalla non sparisce")
	walk_until(func(): return b.job != main.Job.BURY, 3000)
	check(main.graves.get(yard) == dead and not main.corpses.has(dead) and dead.carried_by == null, "sepolto")
	check(dead.mourned == dead.died + 2.0 and a.conds[MOURN] == dead.mourned, "il lutto: un giorno in meno")
	check(main.piece_rects(yard, main.furniture[yard])[1].position.x == 64, "il tumulo")
	var epitaph: String = main.describe(yard)[1]
	check(epitaph.begins_with("Here lies %s." % main.full_name(dead)) and epitaph.contains("Died on")
		and epitaph.ends_with("%s fell asleep in the snow." % dead.first_name), "la tomba dice chi c'è: %s" % epitaph)
	check(main.empty_graves().is_empty() and not main.try_bury(b), "piena")
	check(main.cell_of(b.pos) != yard or not b.path.is_empty(), "si fa da parte")

	# un lutto venuto dopo non si accorcia per la sepoltura del primo; il lutto regale e l'incoronazione sì
	var first = person()
	var second = person()
	main.die(first, "drowned.")
	main.clock += 0.5
	main.die(second, "drowned.")
	var grave2: Vector2i = yard + Vector2i(2, 0)
	main.furniture[grave2] = [B.GRAVE, R.WOOD, 0]
	main.bury(first, grave2)
	check(a.conds[MOURN] == second.mourned, "il lutto del secondo resta intero")
	main.bury(second, yard + Vector2i(4, 0))
	check(a.conds[MOURN] == second.died + 2.0, "sepolto anche lui: un giorno in meno")
	var king = person()
	king.mourned = main.clock + main.ROYAL_MOURNING_DAYS
	b.conds[main.Cond.ROYAL_MOURNING] = king.mourned
	main.coronation_at = king.mourned
	main.bury(king, yard + Vector2i(6, 0))
	check(b.conds[main.Cond.ROYAL_MOURNING] == king.mourned and main.coronation_at == king.mourned
		and is_equal_approx(king.mourned, main.clock + main.ROYAL_MOURNING_DAYS - 1.0), "il lutto regale e l'incoronazione, un giorno prima")
	main.coronation_at = 0.0
	for o in main.colonists:
		o.conds.clear()

	# il corpo che nessuno seppellisce sparisce dopo 2 giorni
	var lost = person()
	main.die(lost, "drowned.")
	main.set_priority(b, main.Work.HAUL, 0)
	main.clock = lost.died + main.CORPSE_DAYS + 0.01
	main.tick(0.05)
	check(not main.corpses.has(lost), "dopo 2 giorni il corpo non c'è più")

	# salvata: le tombe coi loro morti
	var with_graves: Dictionary = main.game_state()
	SAVES.pending = with_graves
	var copy3 = load("res://main.tscn").instantiate()
	copy3.game_start = false
	copy3.settings_file = ""
	root.add_child(copy3)
	await process_frame
	check(copy3.graves.size() == 4 and copy3.graves[yard].first_name == dead.first_name
		and copy3.graves[yard].cause == dead.cause, "ricaricata: le tombe e chi c'è sepolto")
	copy3.free()
	Engine.time_scale = 1.0

	# --- Funerali e memoriale ---

	var L = main.Law.FUNERALS
	var law: Dictionary = main.LAWS[L]
	check(law["kind"] == main.LawKind.FEASTS and law["cost"] == 30 and law["piece"] == B.GRAVE and law.get("tier", 0) == 0,
		"la legge Funerali: Feste, signoria, 30, serve una tomba")
	var kept: Dictionary = main.furniture.duplicate()
	for o in main.furniture.keys():
		if main.furniture[o][0] == B.GRAVE:
			main.furniture.erase(o)
	main.authority = 100.0
	check(main.codify_block(L) == "Needs a grave" and main.law_tip(L).ends_with("Needs a grave"), "senza tombe non si codifica: %s" % main.codify_block(L))
	main.furniture = kept
	check(main.codify(L) and main.enact(L), "con una tomba sì")

	# il funerale: sepolto la mattina, alle 18; la sera subito; dopo le 22 il giorno dopo
	var day: float = floorf(main.clock) + 1.0
	main.clock = day + 10.0 / 24
	check(is_equal_approx(main.funeral_time(), day + 18.0 / 24), "sepolto alle 10: alle 18")
	main.clock = day + 19.0 / 24
	check(main.funeral_time() == main.clock, "alle 19: subito")
	main.clock = day + 23.0 / 24
	check(is_equal_approx(main.funeral_time(), day + 1.0 + 18.0 / 24), "alle 23: domani alle 18")
	main.clock = day + 10.0 / 24
	main.tick(0.0)
	var mourned = person()
	main.die(mourned, "drowned.")
	var grave3: Vector2i = yard + Vector2i(0, 3)
	main.furniture[grave3] = [B.GRAVE, R.WOOD, 0]
	main.bury(mourned, grave3)
	check(main.funerals.size() == 1 and main.funerals[0][0] == grave3 and main.funerals[0][2] == mourned, "un funerale in attesa")

	# salvato col funerale in attesa
	var waiting: Dictionary = main.game_state()
	SAVES.pending = waiting
	var copy4 = load("res://main.tscn").instantiate()
	copy4.game_start = false
	copy4.settings_file = ""
	root.add_child(copy4)
	await process_frame
	check(copy4.funerals.size() == 1 and copy4.funerals[0][2] == copy4.graves[grave3], "ricaricata: il funerale aspetta ancora")
	copy4.free()
	Engine.time_scale = 1.0

	# alle 18 chi è in colonia va attorno alla tomba; chi dorme no
	var sleeper = person()
	main.start_job(sleeper, main.Job.SLEEP, none, main.cell_of(sleeper.pos), 0.0)
	for o in main.colonists:
		if o != sleeper:
			o.pos = main.center(mid + Vector2i(main.colonists.find(o) - 3, 2))
	main.clock = day + 18.0 / 24 - 0.0001
	main.tick(0.05)
	main.tick(0.05)
	check(main.funerals.is_empty(), "è l'ora")
	var mourners: Array = main.colonists.filter(func(o): return o.job == main.Job.FUNERAL)
	check(mourners.size() == main.colonists.size() - 1 and sleeper.job == main.Job.SLEEP, "vanno tutti, tranne chi dorme")
	check(mourners.all(func(o): return o.patient == mourned and o.dest == grave3), "alla sua tomba")
	check(main.chronicle[-1].ends_with("the funeral of %s." % main.full_name(mourned)), "nella cronaca")
	check(main.doing(mourners[0]) == "At the funeral of %s" % mourned.first_name, "cosa fanno: %s" % main.doing(mourners[0]))
	walk_until(func(): return mourners.all(func(o): return o.path.is_empty()), 2000)
	check(mourners.all(func(o): return Vector2(main.cell_of(o.pos) - grave3).length() <= main.FUNERAL_REACH * 1.5), "attorno alla tomba")
	var cells := {}
	for o in mourners:
		cells[main.cell_of(o.pos)] = true
	check(cells.size() == mourners.size(), "ognuno al suo posto")
	walk_until(func(): return mourners.all(func(o): return o.job != main.Job.FUNERAL), 1000)
	check(mourners.all(func(o): return o.conds.get(main.Cond.FAREWELL, -1.0) == mourned.mourned), "l'ultimo saluto, quanto il lutto")
	check(main.COND_INFO[main.Cond.FAREWELL][3] == 5.0 and main.COND_INFO[MOURN][3] == -15.0, "il lutto pesa 5 in meno: -10")
	check(not sleeper.conds.has(main.Cond.FAREWELL), "chi dormiva no")
	for o in main.colonists:
		o.conds.clear()
	main.revoke(L)

	# il memoriale dei caduti: dalla Statuaria, di pietra, splendore; il lutto un giorno in meno
	check(main.TECHS[main.Tech.STATUARY]["builds"].has(B.MEMORIAL) and main.BUILD_RES[B.MEMORIAL] == R.STONE
		and main.SPLENDOR[B.MEMORIAL] == 2 and main.FURNITURE[B.MEMORIAL] == Vector2i.ONE, "il memoriale")
	check(main.mourning_days(false) == 3.0 and main.mourning_days(true) == 7.0, "senza: 3 giorni, il regale 7")
	main.furniture[mid + Vector2i(4, -6)] = [B.MEMORIAL, R.STONE, 0]
	check(main.mourning_days(false) == 2.0 and main.mourning_days(true) == 6.0, "col memoriale: 2, il regale 6")
	var remembered = person()
	main.die(remembered, "drowned.")
	check(a.conds[MOURN] == main.clock + 2.0, "il lutto di 2 giorni")
	main.bury(remembered, yard + Vector2i(2, 3))
	check(a.conds[MOURN] == remembered.died + 1.0, "sepolto: uno")
	main.furniture.erase(mid + Vector2i(4, -6))
	for o in main.colonists:
		o.conds.clear()

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

	print("OK: medicina e morte (erbe e unguento, infermeria e medico, tombe, funerali e memoriale)")
	quit()


# un colono in più, adulto, accanto al centro
func person():
	var o = main.Colonist.new()
	main.dress(o, main.people().map(func(x): return x.first_name))
	o.pos = main.center(main.MAP_SIZE / 2 + Vector2i(main.colonists.size(), 1))
	o.skills = main.Skill.values().map(func(_s): return 0)
	o.xp = main.Skill.values().map(func(_s): return 0)
	o.needs = main.Need.values().map(func(_n): return 60.0)
	o.trend = o.needs.map(func(_v): return 0.0)
	main.give_age(o, main.ADULT_AGE)
	main.colonists.append(o)
	return o


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
