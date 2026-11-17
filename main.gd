extends Node2D

const MAP_SIZE := Vector2i(100, 100)
const TILE := 16            # pixel per tile
const SPEED := 4.0          # tile al secondo
const STONE_PER_CELL := 5   # pietra (o ferro, carbone) in un masso, per casella (un 2x2 ne ha 20): vedi full_stock
const ORE_VEIN := 0.35      # soglia del rumore delle vene: più alta, meno minerale nella roccia (vedi generate_map)
const UPROOT_TIME := 1.5    # secondi per estirpare un'erbaccia o un cespuglio
const BERRIES_PER_BUSH := 5 # bacche (vegetali) su un cespuglio maturo
const BERRY_REGROW := 2.0   # giorni prima che il cespuglio rifaccia le bacche
const CARRY_MAX := 10       # quantità massima trasportata per viaggio, di una risorsa sola
const BUILD_TIME := 2.0     # secondi per costruire una casella
const LOOK_AGAIN := 0.5     # secondi tra una ricerca di lavoro e l'altra, per chi non ne trova
const RETRY_AFTER := 10.0   # secondi di gioco prima di riprovare a raggiungere una casella irraggiungibile
const COLONIST_COUNT := 3
const ROOM_MAX := 400       # caselle: una zona chiusa più grande non è una stanza, è il mondo fuori
const START_ROOMS := [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]  # stanze 5x5 già murate attorno alla radura, porta verso fuori
const DEBUG_STASH := 100    # debug: quanto di ogni risorsa c'è all'inizio nella prima stanza, che fa da magazzino
const TUNIC_COLORS := [Color("a33b3b"), Color("3b5ea3"), Color("c9a23b"), Color("6e3ba3"), Color("d8d0c0")]
const CAPE_COLORS := [Color("2f4a6e"), Color("6e2f2f"), Color("5a3b6e"), Color("4a4a4a"), Color("7a5a2f")]
const HAIR_COLORS := [Color("3b2a1e"), Color("d9b35b"), Color("a8462f"), Color("8b5a2b"), Color("2a2a2a")]
const SIDES := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const TREE_SIDES := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]  # da sopra la chioma coprirebbe chi taglia

enum Job { NONE, CHOP, MINE, UPROOT, HAUL, BUILD, FURNISH, HARVEST, SLEEP, EAT, COOK, FISH, HUNT, EQUIP, CRAFT, FIGHT, FLEE,
	RELAX, TANTRUM, TRAVEL }
const WORK_JOBS := [Job.CHOP, Job.MINE, Job.UPROOT, Job.HAUL, Job.BUILD, Job.FURNISH, Job.HARVEST, Job.COOK, Job.FISH,
	Job.HUNT, Job.CRAFT]  # contano come ore di lavoro
# VEG: vegetali, dalle bacche dei cespugli; IRON, COAL: dai massi con le vene; MEAL, FINE_MEAL: pasti, dalla cucina;
# MEAT, HIDE: carne e pelle, dagli animali cacciati; FISH: pesce, dai punti di pesca; INGOT: lingotti, dalla fornace;
# da PICKAXE in poi: equipaggiamento (vedi GEAR), dalla forgia e dal banco da lavoro (vedi RECIPES); GOLD: monete, per
# ingaggiare gli avventurieri (vedi send); DAGGER: il pugnale degli scassinatori, non si fabbrica; da CHALICE in poi
# i cimeli, dalle rovine: si piazzano come decorazioni (vedi RELICS)
enum Res { WOOD, STONE, VEG, IRON, COAL, MEAL, FINE_MEAL, MEAT, FISH, HIDE, INGOT,
	PICKAXE, AXE, SICKLE, BOW, LEATHER_ARMOR, LEATHER_HOOD, HELMET, CHAINMAIL, SWORD, GOLD, DAGGER,
	CHALICE, OLD_BANNER, BUST, CROWN }
const STACK_MAX := {Res.WOOD: 100, Res.STONE: 50, Res.VEG: 50, Res.IRON: 50, Res.COAL: 50, Res.MEAL: 20, Res.FINE_MEAL: 20,
	Res.MEAT: 50, Res.FISH: 50, Res.HIDE: 50, Res.INGOT: 50, Res.PICKAXE: 10, Res.AXE: 10, Res.SICKLE: 10, Res.BOW: 10,
	Res.LEATHER_ARMOR: 10, Res.LEATHER_HOOD: 10, Res.HELMET: 10, Res.CHAINMAIL: 10, Res.SWORD: 10, Res.GOLD: 100, Res.DAGGER: 10,
	Res.CHALICE: 5, Res.OLD_BANNER: 5, Res.BUST: 5, Res.CROWN: 5}  # quantità massima per mucchio (casella)
const MEALS := [Res.FINE_MEAL, Res.MEAL]  # cotti: chi ha fame li prende in quest'ordine, poi il crudo
const RAW_FOOD := [Res.VEG, Res.FISH, Res.MEAT]  # crudo: si cucina, o si mangia in quest'ordine se non ci sono pasti
const STASH := [Res.WOOD, Res.STONE, Res.VEG, Res.IRON, Res.COAL]  # scorta di debug: il resto si produce
const START_GOLD := 60      # monete nel magazzino all'inizio
# cibo: quanto sazia (vedi eat) e in quanti giorni marcisce a terra fuori (vedi spoil); in magazzino ci mette il doppio.
# Il crudo sazia meno e può intossicare (vedi poison_chance), i pasti no e danno un bonus (vedi Cond)
const FOOD := {Res.VEG: 35.0, Res.FISH: 30.0, Res.MEAT: 40.0, Res.MEAL: 100.0, Res.FINE_MEAL: 100.0}
const SHELF_LIFE := {Res.VEG: 3.0, Res.FISH: 1.5, Res.MEAT: 2.0, Res.MEAL: 3.0, Res.FINE_MEAL: 3.0}
const SPOIL_STORED := 0.5   # in magazzino il cibo marcisce a metà velocità
# probabilità di intossicarsi mangiando crudo: [appena preso, quasi marcio], in mezzo in proporzione
const POISON := {Res.VEG: [0.05, 0.4], Res.FISH: [0.1, 0.5], Res.MEAT: [0.15, 0.6]}
const FRESH_WORDS := [[0.5, "Fresh"], [0.2, "Stale"], [0.0, "Almost rotten"]]  # sopra quale parte della durata, nel suggerimento
# cucinare (vedi try_cook): 2 crudi dello stesso mucchio (vegetali, pesce o carne) -> 1 pasto al fuoco da campo di una
# cucina, finché in giro ci sono meno di MEALS_PER_COLONIST pasti a testa
const COOK_RAW := 2
const COOK_TIME := 8.0      # secondi a livello 5, come gather_time; anche secondo il comfort della cucina (vedi comfort_time)
const MEALS_PER_COLONIST := 2
const BURN_PER_LEVEL := 0.06   # bruciato: per livello sotto il 6 (30% a livello 1)...
const BURN_PER_COMFORT := 0.03 # ...e per punto di comfort della cucina sotto 5 (sopra lo abbassa)
const FINE_PER_LEVEL := 0.05   # squisito: per livello sopra il 5 (25% a livello 10)...
const FINE_PER_COMFORT := 0.02 # ...e per punto di comfort della cucina sopra 5
const SEAT_RANGE := 20      # caselle: chi ha preso da mangiare va a una sedia accanto a un tavolo, se ce n'è una entro qui
# pesca (vedi Job.FISH in GATHER): da una casella accanto all'acqua segnata con "Fish"; ogni lancio prende un pesce con
# probabilità catch_chance. Finiti i pesci di un punto, tornano dopo FISH_REGROW giorni (vedi fish_spots)
const FISH_PER_SPOT := 4
const FISH_REGROW := 1.0
const CATCH_BASE := 0.3     # + CATCH_PER_LEVEL per livello: 36% a livello 1, 90% a livello 10
const CATCH_PER_LEVEL := 0.06
# caccia (vedi try_hunt): animali che girano per la mappa; quelli segnati con "Hunt" li insegue un cacciatore, che tira
# da al più HUNT_RANGE caselle. Ogni tiro: AIM_TIME a livello 5, colpisce con probabilità hit_chance; l'animale scappa
enum Beast { RABBIT, DEER, WOLF }  # righe di ANIMALS
# "hp": danni per abbatterlo; "speed": caselle al secondo; "start": quanti all'inizio; i lupi ("hostile") arrivano in
# branco (vedi spawn_pack) e mordono ("bite": danno)
const BEASTS := {
	Beast.RABBIT: {"hp": 10, "meat": 3, "hide": 1, "speed": 2.0, "start": 6},
	Beast.DEER: {"hp": 20, "meat": 10, "hide": 3, "speed": 1.5, "start": 3},
	Beast.WOLF: {"hp": 30, "meat": 5, "hide": 2, "speed": 3.0, "start": 0, "hostile": true, "bite": 8.0},
}
const ANIMALS := preload("res://art/animals.png")  # 16x16, colonne: fermo, passo; guardano a destra
const ANIMALS_MAX := 12     # sotto questo numero ogni ANIMAL_RESPAWN giorni ne arriva uno nuovo, lontano dalla radura
const ANIMAL_RESPAWN := 0.5
const WILD_RADIUS := 15     # caselle dal centro della mappa (la radura) dove non nascono animali
const WANDER := 5           # caselle: quanto lontano gira un animale ogni volta
const WANDER_REST := [2.0, 8.0]  # secondi fermo tra un giro e l'altro
const FLEE := 8             # caselle: quanto scappa un animale preso di mira
const FLEE_SPEED := 2.0     # scappando corre più veloce
const HUNT_RANGE := 6.0     # caselle
const AIM_TIME := 4.0       # secondi per tiro a livello 5 (vedi skill_time)
const HIT_BASE := 0.3       # + HIT_PER_LEVEL per livello, - HIT_PER_TILE per casella di distanza
const HIT_PER_LEVEL := 0.05
const HIT_PER_TILE := 0.05
const SHOT_DAMAGE := 10.0   # tiro senza arco (sassi, lance improvvisate); con l'arco "shot" di GEAR
# combattimento (vedi react, Job.FIGHT, update_wolf): i lupi arrivano in branco dal bordo della mappa e inseguono i coloni
# fuori dalle stanze; chi sta bene combatte, chi è ferito scappa al chiuso. A 0 punti ferita si resta a terra, o si
# muore (vedi die): coi lupi, con le probabilità di DEATH_BASE; a terra, il primo morso uccide
const WOLF_FIRST := 2.0     # giorno del primo branco (vedi threats)
const WOLF_EVERY := 3.0     # giorni tra un branco e l'altro
const PACK := [2, 3]        # lupi per branco, da-a
const WOLF_STAY := 1.0      # giorni: poi, se non inseguono nessuno, se ne vanno
const WOLF_SIGHT := 70      # caselle: fiutano la colonia da tutta la mappa; chi è più lontano non lo trovano
const BITE_RANGE := 1.2     # caselle
const BITE_TIME := 1.5      # secondi tra un morso e l'altro
const BITE_HIT := 0.7       # - DODGE_PER_LEVEL per livello di mischia di chi è morso
const DODGE_PER_LEVEL := 0.03
const ALERT := 12           # caselle: un colono con un lupo così vicino lascia tutto e combatte (o scappa)
const FLEE_HP := 40.0       # sotto, scappa in una stanza invece di combattere
const MELEE_RANGE := 1.2    # caselle
const MELEE_TIME := 1.5     # secondi per colpo a livello 5
const SHOOT_TIME := 2.0     # secondi per tiro con l'arco a livello 5
const MELEE_BASE := 0.5     # a segno + MELEE_PER_LEVEL per livello sopra il 5
const MELEE_PER_LEVEL := 0.05
const FIST_DAMAGE := 5.0    # senza niente in mano; se no "damage" di GEAR
const ARMOR_BLOCK := 0.06   # danno -6% per punto di protezione, al massimo ARMOR_MAX
const ARMOR_MAX := 0.8
const HIT_STRESS := 5.0     # stress per ogni morso preso
const HP_REGEN := 30.0      # punti ferita al giorno; il doppio dormendo
const DOWNED_REGEN := 40.0  # a terra si rialza a GET_UP
const GET_UP := 30.0
const DEATH_BASE := 0.25    # il colpo che butta a terra uccide con questa probabilità, meno DEATH_PER_ARMOR per punto
const DEATH_PER_ARMOR := 0.03  # di protezione, ma almeno DEATH_MIN
const DEATH_MIN := 0.05
const CORPSE_DAYS := 1.0    # il corpo resta a terra un giorno, poi sparisce (vedi corpses)

# --- Avventurieri (vedi GDD 4.4.4): arrivano alla locanda, si ingaggiano con l'oro alla bacheca, esplorano le rovine ---
enum Hero { NONE, WARRIOR, ARCHER, BURGLAR }  # classe; NONE: un colono
# dove va un avventuriero col Job.TRAVEL: alla locanda, via per sempre, al bordo per partire, alla locanda di ritorno
enum Errand { NONE, ARRIVE, LEAVE, DEPART, RETURN }
# "skills": abilità -> livello per livello dell'avventuriero; "weapon": l'abilità con cui combatte nella rovina; "gear" e
# "kit" quello che porta ("heavy": l'armatura da HEAVY_LEVEL); "hurt": quanti colpi prende nella rovina, rispetto agli
# altri del gruppo; "cover": i danni al gruppo, se c'è lui (tira per primo); "haul": il bottino, se c'è lui (la sacca)
const HEROES := {
	Hero.WARRIOR: {"skills": {Skill.MELEE: 2}, "weapon": Skill.MELEE, "hurt": 2.0, "kit": [Look.SHIELD],
		"gear": {Slot.HANDS: Res.SWORD, Slot.BODY: Res.LEATHER_ARMOR, Slot.HEAD: Res.HELMET}, "heavy": Res.CHAINMAIL,
		"tunic": Color("8a2a2a"), "cape": Color("6e2f2f")},
	Hero.ARCHER: {"skills": {Skill.RANGED: 2}, "weapon": Skill.RANGED, "hurt": 0.5, "cover": 0.75, "kit": [Look.QUIVER],
		"gear": {Slot.HANDS: Res.BOW, Slot.BODY: Res.LEATHER_ARMOR, Slot.HEAD: Res.LEATHER_HOOD}, "hood": Color("6f8a4a"),
		"tunic": Color("4f6b30"), "cape": Color("3b4a2a")},
	Hero.BURGLAR: {"skills": {Skill.LOCKPICKING: 2, Skill.MELEE: 1}, "weapon": Skill.MELEE, "hurt": 1.0, "haul": 1.5,
		"kit": [Look.MASK, Look.PACK], "gear": {Slot.HANDS: Res.DAGGER, Slot.BODY: Res.LEATHER_ARMOR, Slot.HEAD: Res.LEATHER_HOOD},
		"hood": Color("4a4858"), "tunic": Color("3a3848"), "cape": Color("2a2833")},
}
# Talenti degli avventurieri: uno a testa (vedi new_hero), con la sua icona (colonne di HERO_TRAITS_SHEET).
# Effetti (vedi gift, party_gift): "fee" paga x; "share" quota delle monete; "turn_back" punti ferita sotto cui fa
# tornare il gruppo; "weapon" la sua arma x nella forza del gruppo; "hurt" ferite x (mostri e trappole); "trips"
# spedizioni per salire di livello; "splendor" splendore della colonia mentre è sulla mappa. Del gruppo, se c'è lui:
# "finds" oggetti in più per forziere; "maps" probabilità delle mappe x; "lure" le trappole colpiscono lui; "sneak"
# probabilità di evitare i mostri; "heal" punti ferita a testa dopo ogni stanza; "carry" chi cade non muore mai (se
# non è solo); "food" provviste x; "travel" giorni di viaggio x; "disarm" + a disinnescare le trappole
enum Gift { GREEDY, LOYAL, RECKLESS, COWARD, LUCKY, CARTOGRAPHER, JINXED, BERSERKER, STOUT, STEALTHY, MEDIC, FORAGER,
	PATHFINDER, KEEN_EYED, SCHOLAR, FAMOUS }
const HERO_TRAITS_SHEET := preload("res://art/hero_traits.png")  # 16x16, colonne nell'ordine di Gift
const GIFT_FX := {
	Gift.GREEDY: {"fee": 1.25},
	Gift.LOYAL: {"share": 0.0},
	Gift.RECKLESS: {"turn_back": 20.0},
	Gift.COWARD: {"turn_back": 60.0},
	Gift.LUCKY: {"finds": 1},
	Gift.CARTOGRAPHER: {"maps": 3.0},
	Gift.JINXED: {"lure": true, "fee": 0.75},
	Gift.BERSERKER: {"weapon": 2.0, "hurt": 1.5},
	Gift.STOUT: {"hurt": 2.0 / 3},
	Gift.STEALTHY: {"sneak": 0.25},
	Gift.MEDIC: {"heal": 6.0, "carry": true},
	Gift.FORAGER: {"food": 2.0 / 3},
	Gift.PATHFINDER: {"travel": 0.5},
	Gift.KEEN_EYED: {"disarm": 0.3},
	Gift.SCHOLAR: {"trips": 1},
	Gift.FAMOUS: {"splendor": 5},
}
const GIFT_INFO := {
	Gift.GREEDY: "Always wants more.\nAsks 25% more to be hired.",
	Gift.LOYAL: "Fights for the glory of the realm.\nKeeps no share of the gold.",
	Gift.RECKLESS: "Never knows when to stop.\nThe party turns back for them only under 20 health.",
	Gift.COWARD: "Lives to fight another day.\nThe party turns back when they drop under 60 health.",
	Gift.LUCKY: "Born under a good star.\nOne more item in every chest the party opens.",
	Gift.CARTOGRAPHER: "Draws every corridor.\nThe party finds maps three times as often.",
	Gift.JINXED: "Bad things happen around them.\nEvery trap hits them. Asks 25% less.",
	Gift.BERSERKER: "Fights like a storm.\nTheir weapon counts double, but they take 50% more wounds.",
	Gift.STOUT: "Hard as an old oak.\nTakes a third fewer wounds.",
	Gift.STEALTHY: "Moves without a sound.\nThe party slips past monsters one time in four.",
	Gift.MEDIC: "Knows herbs and bandages.\nAfter each room everyone heals 6; whoever falls is carried home.",
	Gift.FORAGER: "Finds food anywhere.\nThe party eats a third less.",
	Gift.PATHFINDER: "Knows every shortcut.\nThe journey takes half the time.",
	Gift.KEEN_EYED: "Nothing escapes their eyes.\n+30% to disarm traps.",
	Gift.SCHOLAR: "Learns from everything.\nGoes up a level after every expedition.",
	Gift.FAMOUS: "Their name is sung in every tavern.\n+5 colony splendor while they are here.",
}
const HERO_TRAIT_CHANCE := 0.3  # avventurieri con anche un talento dei coloni (bisogni e routine)
const HEAVY_LEVEL := 3      # il guerriero ha la cotta di maglia da questo livello
const HERO_LEVEL_MAX := 5
const SPLENDOR_PER_LEVEL := 10  # chi arriva: livello 1, +1 ogni tanti punti di splendore, ±1 a caso
const GUEST_EVERY := 2.0    # giorni tra un arrivo e l'altro (±GUEST_JITTER), se alla locanda c'è un letto libero
const GUEST_JITTER := 0.5
const GUEST_STAY := 3.0     # giorni alla locanda: poi, se nessuno l'ha ingaggiato, se ne va
const GUEST_REST := 2.0     # giorni alla locanda dopo una spedizione, prima di andarsene
const FEE_BASE := 10        # monete d'ingaggio: FEE_BASE + FEE_PER_LEVEL per livello
const FEE_PER_LEVEL := 5
const SHARE := 0.3          # al ritorno si tiene questa parte delle monete trovate
const TRIPS_PER_LEVEL := 2  # spedizioni tornate per salire di un livello
# Rovine, fuori dalla mappa: "danger" pericolo, "rooms" stanze, "travel" giorni di viaggio (andata), "gold" monete per
# forziere (da-a), "finds" un oggetto per forziere, a caso tra questi [risorsa, quantità]. In quest'ordine: all'inizio
# si conosce la prima, il tesoro di ognuna ha la mappa della successiva (e a volte un forziere qualunque, MAP_CHANCE)
enum RuinKind { TOWER, MINE, CRYPT, FORT }
const RUINS := {
	RuinKind.TOWER: {"name": "Ruined tower", "danger": 1, "rooms": 3, "travel": 0.5, "gold": [10, 25],
		"finds": [[Res.WOOD, 10], [Res.STONE, 10], [Res.IRON, 5]]},
	RuinKind.MINE: {"name": "Abandoned mine", "danger": 2, "rooms": 5, "travel": 1.0, "gold": [20, 45],
		"finds": [[Res.IRON, 10], [Res.COAL, 10], [Res.INGOT, 4], [Res.PICKAXE, 1]]},
	RuinKind.CRYPT: {"name": "Crypt", "danger": 3, "rooms": 6, "travel": 1.0, "gold": [35, 70],
		"finds": [[Res.SWORD, 1], [Res.HELMET, 1], [Res.LEATHER_ARMOR, 1], [Res.INGOT, 6], [Res.CHALICE, 1], [Res.BUST, 1]]},
	RuinKind.FORT: {"name": "Ruined fort", "danger": 4, "rooms": 8, "travel": 2.0, "gold": [60, 120],
		"finds": [[Res.CHAINMAIL, 1], [Res.SWORD, 2], [Res.HELMET, 1], [Res.INGOT, 10], [Res.OLD_BANNER, 1], [Res.CROWN, 1]]},
}
const MAP_CHANCE := 0.15    # in un forziere qualunque, la mappa di una rovina che ancora non si conosce
const TREASURE_GOLD := 3    # il tesoro dell'ultima stanza: monete di tanti forzieri
const MAX_PARTY := 4        # avventurieri per spedizione
const HUNGER_HURT := 20.0   # punti ferita al giorno, a testa, senza provviste
enum Chamber { EMPTY, TRAP, MONSTERS, CHEST, COLLAPSE }  # cosa c'è in una stanza della rovina (vedi explore)
const CHAMBER_ODDS := {Chamber.EMPTY: 25, Chamber.TRAP: 20, Chamber.MONSTERS: 35, Chamber.CHEST: 15, Chamber.COLLAPSE: 5}
const ROOM_DAYS := 0.5      # giorni per stanza
const MONSTER_POWER := 5.0  # forza dei mostri per punto di pericolo; il guardiano dell'ultima stanza il doppio
const MONSTER_HURT := 20.0  # danni a testa: questo x forza dei mostri / forza media del gruppo, poi la protezione
const TRAP_DISARM := 0.2    # + TRAP_PER_LEVEL per livello di scassinare del migliore
const TRAP_PER_LEVEL := 0.08
const TRAP_HURT := 15.0     # danni per punto di pericolo, a uno a caso, se non la disinnesca nessuno
const LOCKED := 0.5         # forzieri chiusi: li apre solo chi ha scassinare almeno LOCK_PER_DANGER per punto di pericolo
const LOCK_PER_DANGER := 2
const TURN_BACK := 40.0     # punti ferita sotto cui il gruppo torna indietro
const FALL_DEATH := 0.5     # a 0 punti ferita nella rovina si muore una volta su due; se no lo riportano gli altri
const CARRIED_HP := 5.0     # chi è riportato a casa
const LOST_AFTER := 2.0     # una spedizione da cui non torna nessuno la si dà per persa al doppio del tempo previsto
# Equipaggiamento: un pezzo per slot (vedi Colonist.gear), messo da sé col primo che trova in magazzino (vedi try_equip).
# Nelle mani l'attrezzo della sua abilità migliore tra quelle degli attrezzi ("skill"). Armature: "armor" è la protezione,
# per il combattimento e il freddo che verranno; i bonus li dà solo il pezzo che li ha. Chiavi:
# "time": {Job: tempo x}, "slow": tempo x per ogni lavoro, "hit": a segno + cacciando, "range": caselle di tiro in più,
# "outdoor_stress": stress x lavorando fuori dalle stanze; "look": come si vede addosso (Held in mano, Look sul corpo
# e in testa), "tint": tinta di quel livello (vedi figure_layers)
enum Slot { HANDS, BODY, HEAD }  # come HUD/ColonistSheet/Box/Equipment/Slots
enum Held { TOOL, PICKAXE, AXE, SICKLE, SWORD, BOW, DAGGER }  # righe di colonist_hands; TOOL: a mani vuote, nei lavori
enum Look { LEATHER_ARMOR, CHAINMAIL, HELMET, HOOD, SHIELD, QUIVER, MASK, PACK }  # righe di colonist_gear
const GEAR := {
	Res.PICKAXE: {"slot": Slot.HANDS, "skill": Skill.MINING, "time": {Job.MINE: 0.75}, "damage": 10.0,
		"look": Held.PICKAXE, "info": "Mining 25% faster. Melee damage 10."},
	Res.AXE: {"slot": Slot.HANDS, "skill": Skill.WOODCUTTING, "time": {Job.CHOP: 0.75}, "damage": 12.0,
		"look": Held.AXE, "info": "Woodcutting 25% faster. Melee damage 12."},
	Res.SICKLE: {"slot": Slot.HANDS, "skill": Skill.GATHERING, "time": {Job.HARVEST: 0.75, Job.UPROOT: 0.75}, "damage": 8.0,
		"look": Held.SICKLE, "info": "Harvesting and uprooting 25% faster. Melee damage 8."},
	Res.BOW: {"slot": Slot.HANDS, "skill": Skill.HUNTING, "hit": 0.1, "range": 2.0, "shot": 14.0, "look": Held.BOW,
		"info": "Hunting: +10% to hit, 2 more tiles of range, aims with the better of Hunting and Ranged. Shoots in a fight (damage 14)."},
	Res.SWORD: {"slot": Slot.HANDS, "skill": Skill.MELEE, "damage": 15.0, "look": Held.SWORD, "info": "A weapon. Melee damage 15."},
	Res.LEATHER_ARMOR: {"slot": Slot.BODY, "armor": 2, "outdoor_stress": 0.75, "look": Look.LEATHER_ARMOR, "info": "Light. 25% less stress working outdoors."},
	Res.LEATHER_HOOD: {"slot": Slot.HEAD, "armor": 1, "hit": 0.05, "look": Look.HOOD, "tint": Color("8a5a34"), "info": "Blends in: +5% to hit when hunting."},
	Res.HELMET: {"slot": Slot.HEAD, "armor": 3, "time": {Job.MINE: 0.9}, "look": Look.HELMET, "info": "Safe from falling rocks: mining 10% faster."},
	Res.CHAINMAIL: {"slot": Slot.BODY, "armor": 5, "slow": 1.1, "look": Look.CHAINMAIL, "info": "Heavy: all work 10% slower."},
	Res.DAGGER: {"slot": Slot.HANDS, "skill": Skill.LOCKPICKING, "damage": 10.0, "look": Held.DAGGER,
		"info": "A burglar's knife. Melee damage 10."},
}
const KIT_ARMOR := {Look.SHIELD: 3}  # protezione del corredo degli avventurieri (vedi gear_sum)
# Produzione (vedi try_craft): [prodotto, mobile, abilità, ingredienti, secondi a livello 5]. Il mobile dentro una stanza
# del tipo STATION_ROOM. Si fanno lingotti finché ce ne sono meno di INGOT_STOCK, e i pezzi che mancano perché ogni
# colono abbia pieni i suoi slot (vedi gear_wanted); per uno slot, il primo in elenco di cui ci sono gli ingredienti.
# Come in cucina: tempo e rischio di rovinarlo (ingredienti persi, vedi burn_chance) secondo livello e comfort
const RECIPES := [
	[Res.INGOT, Build.FURNACE, Skill.SMITHING, {Res.IRON: 1, Res.COAL: 1}, 6.0],
	[Res.LEATHER_ARMOR, Build.WORKBENCH, Skill.TAILORING, {Res.HIDE: 4}, 20.0],
	[Res.LEATHER_HOOD, Build.WORKBENCH, Skill.TAILORING, {Res.HIDE: 2}, 12.0],
	[Res.BOW, Build.WORKBENCH, Skill.RANGED, {Res.WOOD: 3, Res.HIDE: 1}, 15.0],  # l'arco lo fa chi lo sa usare
	[Res.PICKAXE, Build.ANVIL, Skill.SMITHING, {Res.INGOT: 2, Res.WOOD: 2}, 15.0],
	[Res.AXE, Build.ANVIL, Skill.SMITHING, {Res.INGOT: 2, Res.WOOD: 2}, 15.0],
	[Res.SICKLE, Build.ANVIL, Skill.SMITHING, {Res.INGOT: 1, Res.WOOD: 1}, 10.0],
	[Res.HELMET, Build.ANVIL, Skill.SMITHING, {Res.INGOT: 3}, 20.0],
	[Res.CHAINMAIL, Build.ANVIL, Skill.SMITHING, {Res.INGOT: 6}, 30.0],
	[Res.SWORD, Build.ANVIL, Skill.SMITHING, {Res.INGOT: 3, Res.WOOD: 1}, 20.0],
]
const STATION_ROOM := {Build.FURNACE: RoomKind.FORGE, Build.ANVIL: RoomKind.FORGE, Build.WORKBENCH: RoomKind.WORKSHOP}
const INGOT_STOCK := 10
enum Order { NONE, CHOP, MINE, UPROOT, BUILD, ERASE, DEMOLISH, HARVEST, FISH, HUNT }  # cosa segna il trascinamento del mouse
const ORDER_COLORS := [Color.TRANSPARENT, Color.ORANGE, Color("8fd3ff"), Color("9be36a"), Color("e6e2d0"),
	Color("ff5a5a"), Color("c83030"), Color("d84a6a"), Color("6ab0e0"), Color("c87a3a")]  # selezione e segni, per Order
# tasti in HUD/Tools/Row dopo Structures e Furniture, uno alla volta (ButtonGroup "Orders"): vedi toggle_order
const ORDER_TOOLS := {Order.DEMOLISH: "Destroy", Order.MINE: "Mine", Order.CHOP: "Chop", Order.UPROOT: "Uproot",
	Order.HARVEST: "Harvest", Order.FISH: "Fish", Order.HUNT: "Hunt"}
const ORDER_ICONS := {Order.CHOP: preload("res://art/icon_chop.png"), Order.MINE: preload("res://art/icon_mine.png"),
	Order.UPROOT: preload("res://art/icon_uproot.png"), Order.HARVEST: preload("res://art/icon_harvest.png"),
	Order.FISH: preload("res://art/icon_fishing.png"), Order.HUNT: preload("res://art/icon_hunting.png")}  # le stesse dei tasti: piccole e velate sopra ciò che è segnato
enum RoomKind { NONE, WAREHOUSE, BEDROOM, DORMITORY, KITCHEN, FORGE, WORKSHOP, INN }  # tipo di stanza, scelto dal cartello
# categoria del tipo: lavoro (niente proprietari, gli si assegnano dei lavoratori), residenza (può avere dei proprietari),
# servizio (comune a tutti, con uno scopo preciso: magazzino, locanda). Senza tipo: nessuna, né proprietari né lavoratori
enum RoomClass { NONE, WORK, RESIDENCE, SERVICE }
const ROOM_CLASS := {
	RoomKind.WAREHOUSE: RoomClass.SERVICE,
	RoomKind.BEDROOM: RoomClass.RESIDENCE,
	RoomKind.DORMITORY: RoomClass.RESIDENCE,
	RoomKind.KITCHEN: RoomClass.WORK,
	RoomKind.FORGE: RoomClass.WORK,
	RoomKind.WORKSHOP: RoomClass.WORK,
	RoomKind.INN: RoomClass.SERVICE,
}
# titolo della lista di coloni da spuntare nel popup del cartello, per RoomClass (le altre non ce l'hanno)
const ROOM_PEOPLE := {RoomClass.WORK: "Workers", RoomClass.RESIDENCE: "Owners"}
enum Build { WALL, FLOOR, DOOR, PATH, BED, TABLE, CHAIR, LAMP, CAMPFIRE, FURNACE, ANVIL, WORKBENCH,  # porta e mobili si attraversano
	FLOWER_BED, PLANTER, BENCH, BANNER, LANTERN, FOUNTAIN, STATUE,  # decorazioni: vedi SPLENDOR
	NOTICE_BOARD,  # la bacheca degli incarichi, nella locanda (vedi open_board)
	CHALICE, OLD_BANNER, BUST, CROWN }  # cimeli: decorazioni fatte con l'oggetto trovato nelle rovine (vedi RELICS)
# materiale per casella; per i mobili, per pezzo
const BUILD_COST := {Build.WALL: 5, Build.FLOOR: 2, Build.DOOR: 5, Build.PATH: 1, Build.BED: 10, Build.TABLE: 10, Build.CHAIR: 3,
	Build.LAMP: 3, Build.CAMPFIRE: 5, Build.FURNACE: 20, Build.ANVIL: 10, Build.WORKBENCH: 15, Build.FLOWER_BED: 3, Build.PLANTER: 5,
	Build.BENCH: 6, Build.BANNER: 4, Build.LANTERN: 4, Build.FOUNTAIN: 30, Build.STATUE: 40, Build.NOTICE_BOARD: 8,
	Build.CHALICE: 1, Build.OLD_BANNER: 1, Build.BUST: 1, Build.CROWN: 1}
# caselle occupate dai mobili come sono disegnati; girati di un quarto si scambiano larghezza e altezza (vedi piece_rect)
const FURNITURE := {Build.BED: Vector2i(2, 1), Build.TABLE: Vector2i(2, 2), Build.CHAIR: Vector2i.ONE, Build.LAMP: Vector2i.ONE,
	Build.CAMPFIRE: Vector2i.ONE, Build.FURNACE: Vector2i.ONE, Build.ANVIL: Vector2i.ONE, Build.WORKBENCH: Vector2i.ONE,
	Build.FLOWER_BED: Vector2i.ONE, Build.PLANTER: Vector2i.ONE, Build.BENCH: Vector2i(2, 1), Build.BANNER: Vector2i.ONE,
	Build.LANTERN: Vector2i.ONE, Build.FOUNTAIN: Vector2i(2, 2), Build.STATUE: Vector2i(2, 2), Build.NOTICE_BOARD: Vector2i.ONE,
	Build.CHALICE: Vector2i.ONE, Build.OLD_BANNER: Vector2i.ONE, Build.BUST: Vector2i.ONE, Build.CROWN: Vector2i.ONE}
# mobili animati: secondi per fotogramma; i fotogrammi stanno nelle colonne dei quarti di giro (sono simmetrici)
const ANIMATED := {Build.CAMPFIRE: 0.15, Build.BANNER: 0.3, Build.FOUNTAIN: 0.2}
const ANY_MATERIAL := [Build.WALL, Build.FLOOR]  # di legno o di pietra
const PAVING := [Build.FLOOR, Build.PATH]  # a terra: si calpestano, ci stanno sopra i mobili, l'erba ci sborda sopra
# materiale fisso; il resto solo di legno
# i cimeli: la decorazione si fa con l'oggetto trovato nelle rovine, uno a pezzo
const RELICS := {Build.CHALICE: Res.CHALICE, Build.OLD_BANNER: Res.OLD_BANNER, Build.BUST: Res.BUST, Build.CROWN: Res.CROWN}
const BUILD_RES := {Build.PATH: Res.STONE, Build.FURNACE: Res.STONE, Build.ANVIL: Res.IRON, Build.PLANTER: Res.STONE, Build.FOUNTAIN: Res.STONE,
	Build.STATUE: Res.STONE, Build.CHALICE: Res.CHALICE, Build.OLD_BANNER: Res.OLD_BANNER, Build.BUST: Res.BUST, Build.CROWN: Res.CROWN}
# mobili che servono perché il cartello lasci scegliere il tipo di stanza: tipo -> {mobile: almeno quanti}
# ponytail: la cucina accetterà anche la stufa, quando ci sarà: allora "uno tra" invece di "tutti"
const ROOM_NEEDS := {
	RoomKind.BEDROOM: {Build.BED: 1},
	RoomKind.DORMITORY: {Build.BED: 2},
	RoomKind.KITCHEN: {Build.CAMPFIRE: 1},
	RoomKind.FORGE: {Build.FURNACE: 1, Build.ANVIL: 1},
	RoomKind.WORKSHOP: {Build.WORKBENCH: 1},
	RoomKind.INN: {Build.BED: 1, Build.TABLE: 1, Build.NOTICE_BOARD: 1},
}
# lente delle stanze (tasto col cartello in basso): le stanze finite velate col colore del loro tipo, per RoomKind
const ROOM_COLORS := [Color("e6e2d0"), Color("c9a23b"), Color("3b8fd3"), Color("8a5ad3"), Color("e0703a"), Color("d33b3b"),
	Color("3bb08a"), Color("d38a3b")]
# comfort di una stanza, 0-COMFORT_MAX: lo danno i mobili (per pezzo) e il pavimento (tutto se copre la stanza intera),
# per il materiale. A metà né bonus né malus; fuori dalle stanze è 0. Vedi room_comfort e comfort_of
const COMFORT_MAX := 10
const COMFORT := {Build.FLOOR: 1.0, Build.BED: 1.0, Build.TABLE: 1.0, Build.CHAIR: 0.5, Build.LAMP: 0.5, Build.CAMPFIRE: 0.5,
	Build.BENCH: 0.5}
const COMFORT_MATERIAL := {Res.STONE: 1.5}  # il resto vale 1
const COMFORT_EFFECT := 0.2  # a comfort 0 un'attività richiede il 20% di tempo in più, al massimo il 20% in meno
# splendore della colonia: lo danno le decorazioni finite, dentro e fuori dalle stanze (vedi colony_splendor).
# ponytail: per ora solo il totale in alto; poi terrà felici i coloni e sbloccherà cose (strade, feste: vedi GDD)
const SPLENDOR := {Build.FLOWER_BED: 1, Build.PLANTER: 1, Build.BENCH: 1, Build.BANNER: 2, Build.LANTERN: 1,
	Build.FOUNTAIN: 6, Build.STATUE: 8, Build.CHALICE: 3, Build.OLD_BANNER: 4, Build.BUST: 5, Build.CROWN: 6}
const SPLENDOR_COLOR := Color("e8c34a")
const ROOM_SPACE := 6        # caselle a testa: chi ne ha meno (stanza piena di gente) ha il comfort in proporzione
# suggerimento dei pulsanti di costruzione (vedi build_tip): sotto nome e costo il comfort, poi la descrizione colorata
const TIP := preload("res://tip_button.gd")  # suggerimento fatto di Control: pulsanti di costruzione, figurine
const BUILD_INFO_COLOR := Color("d9c48a")
const BUILD_INFO := {
	Build.WALL: "Blocks the way. Walls with a door around an area make a room.",
	Build.FLOOR: "Paves the ground. Furniture can stand on it.",
	Build.DOOR: "Colonists walk through it. A room needs one to be entered.",
	Build.PATH: "A trodden earth path with pebbles. Grass grows over its edges.",
	Build.BED: "A place to sleep. A bedroom needs one, a dormitory two.",
	Build.TABLE: "Where colonists eat and work.",
	Build.CHAIR: "Put it at a table, turned to face it.",
	Build.LAMP: "Lights up at night.",
	Build.CAMPFIRE: "A wood fire inside a ring of stones. Burns day and night. A kitchen needs one.",
	Build.FURNACE: "A stone furnace. A forge needs one, and an anvil. Smelts iron and coal into ingots.",
	Build.ANVIL: "An iron anvil on a stump. A forge needs one, and a furnace. Tools and metal armor are made here.",
	Build.WORKBENCH: "A sturdy bench. A workshop needs one. Leather armor and bows are made here.",
	Build.FLOWER_BED: "A wooden box of soil and flowers.",
	Build.PLANTER: "A stone urn overflowing with flowers.",
	Build.BENCH: "A wooden bench to rest along the roads.",
	Build.BANNER: "The royal banner, red and gold, waving in the wind.",
	Build.LANTERN: "A lantern on a post. Lights up the roads at night.",
	Build.FOUNTAIN: "A stone basin with a jet of water. The pride of the square.",
	Build.STATUE: "The king in stone, hands on his sword, on a gilded plinth.",
	Build.NOTICE_BOARD: "Notices pinned to a board. An inn needs one, a bed and a table. Click it to hire adventurers.",
	Build.CHALICE: "A silver chalice set with a ruby, from a forgotten altar. Only adventurers find these, in ruins.",
	Build.OLD_BANNER: "A torn banner of a fallen house. Only adventurers find these, in ruins.",
	Build.BUST: "The stone face of a king nobody remembers. Only adventurers find these, in ruins.",
	Build.CROWN: "A jeweled crown on a velvet cushion. Only adventurers find these, in ruins.",
}
enum Facing { DOWN, LEFT, RIGHT, UP }  # righe del foglio
enum TreeKind { OAK, PINE, BIRCH }     # colonne del foglio alberi
const TREE_LOGS := {TreeKind.OAK: 28, TreeKind.PINE: 35, TreeKind.BIRCH: 20}  # tronchi di un albero intero

# fogli 96x64 generati da tools/make_sprites.py; quelli con più voci le hanno una sotto l'altra (vedi figure_layers)
const COLONIST_BASE := preload("res://art/colonist_base.png")
const COLONIST_HAIR := preload("res://art/colonist_hair.png")
const COLONIST_TUNIC := preload("res://art/colonist_tunic.png")
const COLONIST_CAPE := preload("res://art/colonist_cape.png")
const COLONIST_HAIR_STYLES := preload("res://art/colonist_hair_styles.png")  # capelli lunghi, treccia, barba
const COLONIST_GEAR := preload("res://art/colonist_gear.png")    # armature, copricapi, corredo: Look
const COLONIST_HANDS := preload("res://art/colonist_hands.png")  # quello che tiene in mano: Held
const WALK_CYCLE := [0, 1, 0, 2]  # colonne del foglio: fermo, passo A, fermo, passo B
const WORK_CYCLE := [3, 3, 4]     # carica, carica, colpo: per ogni lavoro a tempo (taglio, scavo, costruzione)
const SWING_TIME := 0.6           # secondi per colpo
const IDLE_CYCLE := [0, 0, 5]     # fermo, fermo, respiro: chi non ha niente da fare
const BREATH_TIME := 2.0          # secondi per respiro
const LOOK_TIME := 3.0            # secondi, in media, tra un'occhiata e l'altra di chi è fermo
const TREES := preload("res://art/trees.png")  # 16x32 ciascuno: la chioma sale nella casella sopra
const PLANTS := preload("res://art/plants.png")  # 16x16: erbaccia, cespuglio, cespuglio con le bacche
const BOULDERS := {  # massi: dimensione in caselle -> sprite, dal più grande (ordine usato in generate_map)
	Vector2i(2, 2): preload("res://art/rock_2x2.png"),
	Vector2i(2, 1): preload("res://art/rock_2x1.png"),
	Vector2i(1, 1): preload("res://art/rock_1x1.png"),
}
const ORE_ROCKS := {Res.IRON: preload("res://art/rock_iron.png"), Res.COAL: preload("res://art/rock_coal.png")}  # massi 1x1
# 128x448, righe: mobili nell'ordine di Build; colonne: quarti di giro in senso orario, ognuno in un riquadro 32x32
const FURNITURE_SHEET := preload("res://art/furniture.png")
const FURNITURE_NIGHT := preload("res://art/furniture_night.png")  # abat-jour e lampioni accesi
const FURNITURE_GLOW := preload("res://art/furniture_glow.png")    # solo le luci accese, per `lights`
const SIGN := preload("res://art/sign.png")  # sul muro accanto alla porta d'ingresso di una stanza finita
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
	Res.VEG: preload("res://art/icon_veg.png"),
	Res.IRON: preload("res://art/icon_iron.png"),
	Res.COAL: preload("res://art/icon_coal.png"),
	Res.MEAL: preload("res://art/icon_meal.png"),
	Res.FINE_MEAL: preload("res://art/icon_fine_meal.png"),
	Res.MEAT: preload("res://art/icon_meat.png"),
	Res.FISH: preload("res://art/icon_fish.png"),
	Res.HIDE: preload("res://art/icon_hide.png"),
	Res.INGOT: preload("res://art/icon_ingot.png"),
	Res.PICKAXE: preload("res://art/icon_mine.png"),
	Res.AXE: preload("res://art/icon_chop.png"),
	Res.SICKLE: preload("res://art/icon_sickle.png"),
	Res.BOW: preload("res://art/icon_hunting.png"),
	Res.LEATHER_ARMOR: preload("res://art/icon_leather_armor.png"),
	Res.LEATHER_HOOD: preload("res://art/icon_leather_hood.png"),
	Res.HELMET: preload("res://art/icon_helmet.png"),
	Res.CHAINMAIL: preload("res://art/icon_chainmail.png"),
	Res.SWORD: preload("res://art/icon_sword.png"),
	Res.GOLD: preload("res://art/icon_gold.png"),
	Res.DAGGER: preload("res://art/icon_dagger.png"),
	Res.CHALICE: preload("res://art/icon_chalice.png"),
	Res.OLD_BANNER: preload("res://art/icon_old_banner.png"),
	Res.BUST: preload("res://art/icon_bust.png"),
	Res.CROWN: preload("res://art/icon_crown.png"),
}
# 256x128, righe: muri di legno, muri di pietra (colonna = lati collegati, vedi WALL_LINKS), pavimenti (colonna = Res,
# poi il sentiero), porte (di fronte, di lato), erba sui pavimenti (lati, angoli, due varianti); vedi structure_src e draw_grass_over
const STRUCTURES := preload("res://art/structures.png")
const WALL_LINKS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]  # bit 1, 2, 4, 8 della colonna dei muri
# scheda del colono, vedi open_sheet
enum Skill { GATHERING, MINING, WOODCUTTING, CONSTRUCTION, SMITHING, TAILORING, COOKING, FISHING, HUNTING, MELEE, RANGED, RESEARCH,
	LOCKPICKING }  # scassinare: per ora solo gli scassinatori (vedi HEROES)
const SKILL_MAX := 10       # livelli 0-10 (si parte da 0): al massimo, nella scheda, compare la stellina
const CORPSE_SHADE := Color(0.6, 0.6, 0.65)  # i morti, smorti
# raccolta: [abilità, secondi per colpo a livello 5 (vedi gather_time), quantità per colpo, risorsa]; i massi con la
# vena danno il minerale (vedi ores). 1 punto esperienza nell'abilità a raccolta finita (albero abbattuto, masso
# scavato, cespuglio spogliato), non a colpo
const GATHER := {
	Job.CHOP: [Skill.WOODCUTTING, 10.0, 5, Res.WOOD],
	Job.MINE: [Skill.MINING, 15.0, 5, Res.STONE],
	Job.HARVEST: [Skill.GATHERING, 5.0, 1, Res.VEG],  # solo i cespugli segnati con "Harvest" (vedi harvest_marks)
	Job.FISH: [Skill.FISHING, 10.0, 1, Res.FISH],      # un lancio; il pesce solo con catch_chance (vedi fish_marks)
}
const STAR := preload("res://art/icon_star.png")
const SKILLS_SHEET := preload("res://art/skills.png")  # icone 8x8, colonne nell'ordine di Skill
const MAX_HP := 100
# Routine: ogni ora del giorno, da mezzanotte, è sonno (S), lavoro (W) o tempo libero (F), vedi routine_of.
# Base: dorme 22-6, colazione alle 6, lavora 7-12 e 13-18 con il pranzo in mezzo, la sera è libera.
# Nelle ore di lavoro si lavora al più WORK_HOURS ore (per giornata, da quando ci si alza): poi è tempo libero
enum Act { SLEEP, WORK, FREE }
const ROUTINE := "SSSSSSFWWWWWFWWWWWFFFFSS"
const ROUTINE_LETTERS := "SWF"  # nell'ordine di Act
const ROUTINE_COLORS := [Color("3b5ea3"), Color("e0703a"), Color("7db644")]  # caselle delle ore nella scheda, per Act
const ROUTINE_NAMES := ["Sleep", "Work", "Free time"]
const WORK_HOURS := 8.0
const RELAX_HOURS := 1.0     # una pausa (al fuoco da campo o a passeggio), poi si rivaluta: vedi relax
const RELAX_REACH := 6       # caselle: quanto lontano va a passeggiare
const SNACK := 60.0          # nel tempo libero mangia già sotto questa soglia di cibo: ai pasti
const RISE := 80.0           # finite le ore di sonno si alza con almeno questo riposo (la pennichella non dura ore)
# talenti: cambiano la routine e i ritmi dei bisogni (vedi TRAIT_FX); colonne di TRAITS_SHEET, 16x16 ciascuno
enum Trait { GLUTTON, SLEEPWALKER, HOTHEAD, LAZY, WORKAHOLIC, EARLY_BIRD, NIGHT_OWL, SLEEPYHEAD, TIRELESS, FUN_LOVING,
	ASCETIC, SMALL_APPETITE, EASYGOING, NAPPER, RESTLESS }
const TRAITS_SHEET := preload("res://art/traits.png")
const TRAIT_INFO := {  # suggerimento col mouse sopra il talento: com'è, poi cosa cambia
	Trait.GLUTTON: "Always thinking about the next meal.\nGets hungry 50% faster, eats at half hunger and snacks in free time.\nDouble joy from meals, hates raw food.",
	Trait.SLEEPWALKER: "Sometimes wanders off in their sleep.\nMay get up at night and sleep wherever they end up.",
	Trait.HOTHEAD: "Loses their temper easily.\nStress from work +50%. At 90 storms off for two hours.",
	Trait.LAZY: "Would rather be anywhere else.\nWorks at most 6 hours a day.",
	Trait.WORKAHOLIC: "Lives for the job.\nWorks up to 12 hours a day, free time too. Gets bored half as fast.",
	Trait.EARLY_BIRD: "Up before the rooster.\nWhole day two hours earlier: sleeps 20-4.",
	Trait.NIGHT_OWL: "Comes alive after dark.\nSleeps by day (10-18), works by night.",
	Trait.SLEEPYHEAD: "Hard to get out of bed.\nNeeds 10 hours of sleep: sleeps until 8.",
	Trait.TIRELESS: "Six hours of sleep are plenty.\nSleeps 0-6, gets tired 25% slower.",
	Trait.FUN_LOVING: "Work can wait, fun can't.\nGets bored twice as fast. Stops work at 17.",
	Trait.ASCETIC: "Wants nothing but the essentials.\nNever needs fun.",
	Trait.SMALL_APPETITE: "Eats like a sparrow.\nGets hungry 40% slower, never snacks.",
	Trait.EASYGOING: "Nothing ruffles them.\nHalf the stress from work.",
	Trait.NAPPER: "A nap after lunch, every day.\nSleeps 13-14, goes to bed at 23.",
	Trait.RESTLESS: "Can't keep at one thing for long.\nAfter 2 hours of work in a row, takes an hour off.",
}
# condizioni: effetti a tempo, con un'icona 16x16 nella scheda (colonne di CONDITIONS_SHEET nell'ordine di Cond).
# Dati: [giorni, tempo di lavoro x, stress da lavoro x, felicità +, descrizione]. Vedi add_cond, work_factor, update_needs
enum Cond { POISONED, WELL_FED, FEASTED, AT_TABLE, ATE_RAW, MOURNING }
const CONDITIONS_SHEET := preload("res://art/conditions.png")
const COND_INFO := {
	Cond.POISONED: [1.0, 1.5, 1.0, -20.0, "Ate raw food that was going bad. Works slowly."],
	Cond.WELL_FED: [0.5, 0.9, 0.75, 5.0, "Had a cooked meal. Works faster, less stress."],
	Cond.FEASTED: [0.5, 0.8, 0.5, 10.0, "Had a fine meal. Works much faster, much less stress."],
	Cond.AT_TABLE: [0.5, 1.0, 1.0, 5.0, "Ate sitting at a table."],
	Cond.ATE_RAW: [0.5, 1.0, 1.0, -10.0, "A glutton forced to eat raw food."],
	Cond.MOURNING: [3.0, 1.0, 1.25, -15.0, "A fellow colonist has died."],
}
const GLUTTON_MOOD := 2.0  # il goloso: tanta felicità in più (o in meno) da quello che mangia
const FOOD_CONDS := [Cond.WELL_FED, Cond.FEASTED, Cond.AT_TABLE, Cond.ATE_RAW]
# Effetti dei talenti, vedi fx. "hours": ore della routine base cambiate (prima di spostarla); "shift": ore di cui si
# sposta tutta la giornata; "overtime": lavora anche nel tempo libero; "work": ore di lavoro al giorno.
# Ritmi, si moltiplicano tra talenti: "food" fame, "rest" stanchezza, "fun" noia, "stress" stress dal lavoro,
# "sleep" ore di sonno per riposarsi del tutto. "snack": soglia di cibo per mangiare nel tempo libero (0: mai);
# "tantrum": stress a cui si arrabbia e se ne va (vedi tantrum); "sleepwalk": probabilità all'ora di alzarsi nel sonno;
# "streak": ore di lavoro di fila prima di una pausa
const TRAIT_FX := {
	Trait.GLUTTON: {"food": 1.5, "snack": 85.0},
	Trait.SLEEPWALKER: {"sleepwalk": 0.1},
	Trait.HOTHEAD: {"stress": 1.5, "tantrum": 90.0},
	Trait.LAZY: {"work": 6.0},
	Trait.WORKAHOLIC: {"work": 12.0, "overtime": true, "fun": 0.5},
	Trait.EARLY_BIRD: {"shift": -2},
	Trait.NIGHT_OWL: {"shift": 12},
	Trait.SLEEPYHEAD: {"hours": {6: "S", 7: "S"}, "sleep": 10.0 / 8},
	Trait.TIRELESS: {"hours": {22: "F", 23: "F"}, "sleep": 6.0 / 8, "rest": 0.75},
	Trait.FUN_LOVING: {"hours": {17: "F"}, "fun": 2.0},
	Trait.ASCETIC: {"fun": 0.0},
	Trait.SMALL_APPETITE: {"food": 0.6, "snack": 0.0},
	Trait.EASYGOING: {"stress": 0.5},
	Trait.NAPPER: {"hours": {13: "S", 22: "F"}},
	Trait.RESTLESS: {"streak": 2.0},
}
const FX_RATES := ["food", "rest", "fun", "stress", "sleep"]  # questi si moltiplicano; gli altri vale l'ultimo talento
const TRAIT_CLASH := [  # mai insieme nello stesso colono
	[Trait.GLUTTON, Trait.SMALL_APPETITE], [Trait.LAZY, Trait.WORKAHOLIC], [Trait.EARLY_BIRD, Trait.NIGHT_OWL],
	[Trait.SLEEPYHEAD, Trait.TIRELESS], [Trait.FUN_LOVING, Trait.ASCETIC], [Trait.HOTHEAD, Trait.EASYGOING],
]
const TANTRUM_HOURS := 2.0   # quanto dura la sfuriata dell'iracondo; intanto lo stress scende TANTRUM_VENT volte più in fretta
const TANTRUM_VENT := 4.0
const TANTRUM_REACH := 8     # caselle: quanto lontano va a sbollire
const SLEEPWALK_REACH := 5   # caselle: quanto lontano va il sonnambulo
# bisogni, barre 0-NEED_MAX nella scheda: 100 = sazio, riposato, divertito, comodo, felice; lo stress al contrario,
# 100 = al limite. Ritmi "al giorno" di gioco
enum Need { FOOD, REST, FUN, COMFORT, HAPPINESS, STRESS }
const NEED_MAX := 100.0
const NEED_LOW := 30.0      # affamato: va a mangiare dei vegetali; stanco: cerca un letto libero
const EXHAUSTED := 10.0     # stremato: lascia il lavoro e dorme dove si trova
const FOOD_DROP := 90.0     # al giorno
const REST_DROP := 100.0    # al giorno, da sveglio
const SLEEP_TIME := 8.0 / 24  # giorni di sonno per riposarsi del tutto, a comfort medio (vedi comfort_time)
const STRESS_WORK := 30.0   # al giorno, lavorando: sale
const STRESS_RELIEF := 60.0 # al giorno, dormendo, mangiando o senza niente da fare: scende
const STRESS_ICON := preload("res://art/icon_stress.png")  # 8x8, accanto al nome nella scheda
const GLUTTON_HUNGER := 50.0  # il goloso va a mangiare già qui, invece che sotto NEED_LOW
const FUN_DROP := 120.0     # al giorno, da sveglio e senza svago: scende
const FUN_GAIN := 300.0     # al giorno, svagandosi (vedi relax): sale
const MOOD_SPEED := 50.0    # al giorno: la felicità va verso la media di cibo, riposo, divertimento, comfort e calma
# barra: stremato, basso, a posto; tingono BAR_FILL, grigia (85%) nel mezzo e bianca sopra: lì risultano più chiari
const NEED_COLORS := [Color("d34432"), Color("f6a332"), Color("7db644")]
const BAR_FILL := preload("res://art/bar_fill.png")  # bianca: la tinge NEED_COLORS; vedi bar_style
const BAR_BACK := preload("res://art/bar_back.png")
const ARROW := preload("res://art/icon_arrow.png")  # a destra della barra; a sinistra è specchiata
const TREND_DOWN := Color("ff6a4a")  # freccia a sinistra accesa: il bisogno scende
const TREND_UP := Color("9be36a")    # freccia a destra accesa: sale
const TREND_OFF := Color(1, 1, 1, 0.12)
enum Sex { MALE, FEMALE }
const SEX_NAMES := ["Male", "Female"]
const SEX_ICONS := {Sex.MALE: preload("res://art/icon_male.png"), Sex.FEMALE: preload("res://art/icon_female.png")}
const FIRST_NAMES := {
	Sex.MALE: ["Aldo", "Corrado", "Folco", "Ilario", "Odo", "Ugo", "Bertrand", "Gualtiero"],
	Sex.FEMALE: ["Bertha", "Edda", "Gisella", "Matilde", "Rosalind", "Wilma", "Adelaide", "Ottavia"],
}
# acconciatura: la calotta di colonist_hair ce l'hanno tutti; LONG e BRAID aggiungono la riga omonima di colonist_hair_styles
enum Hair { SHORT, LONG, BRAID }
const HAIR_STYLES := {Sex.MALE: [Hair.SHORT], Sex.FEMALE: [Hair.LONG, Hair.BRAID]}
const BEARD := 2           # riga della barba in colonist_hair_styles
const BEARD_CHANCE := 0.5  # uomini con la barba
const NICKNAMES := ["Badger", "Crow", "Lefty", "Moss", "Pebble", "Red", "Stub", "Thistle"]
const LAST_NAMES := ["Ashdown", "Barrow", "Cooper", "Fenwick", "Hale", "Marsh", "Thatcher", "Woodward"]


class Colonist:
	var sex := Sex.MALE
	var hair_style := Hair.SHORT
	var beard := false
	var first_name := ""
	var nickname := ""            # facoltativo: non tutti ce l'hanno
	var last_name := ""
	var hp := float(MAX_HP)
	var downed := false           # a 0 punti ferita: resta a terra finché non torna a GET_UP
	var skills := []              # livello 0-SKILL_MAX per Skill: tutti partono da 0
	var xp := []                  # punti esperienza per Skill: 1 per raccolta finita (vedi GATHER)
	var needs := []               # 0-NEED_MAX per Need, vedi update_needs
	var trend := []               # per Need: -1 scende, 0 fermo, 1 sale (le frecce della scheda)
	var traits := []              # Trait
	var conds := {}               # Cond -> `clock` a cui finisce
	var pos: Vector2
	var tunic: Color
	var cape: Color
	var hair: Color
	var facing := Facing.DOWN
	var walked := 0.0             # pixel percorsi, scandisce i passi dell'animazione
	var idle := 0.0               # secondi fermo senza lavoro, scandisce il respiro
	var look_again := 0.0         # secondi prima di cercare di nuovo un lavoro, se l'ultima volta non ne ha trovati
	var path: Array[Vector2i] = []
	var job := Job.NONE
	var target := Vector2i.ZERO   # albero, masso (cella d'origine), mucchio, cella di magazzino o progetto
	var dest := Vector2i.ZERO     # HAUL: cella di magazzino dove si scarica; BUILD: dove stare a costruire
	var carry_res := Res.WOOD
	var carrying := 0
	var carry_days := 0.0         # cibo in mano: giorni prima che marcisca (vedi fresh)
	var prey = null               # HUNT: l'Animal che insegue
	var gear := {}                # Slot -> Res: quello che indossa o ha in mano (vedi GEAR)
	var recipe := 0               # CRAFT: indice in RECIPES
	var fetched := {}             # CRAFT: Res -> quantità già portata alla postazione
	var work_left := 0.0          # secondi: del colpo, della costruzione o, a svago e in sfuriata, del tempo che resta
	var work_total := 0.0         # 0 se non è un lavoro a tempo (niente barra né colpi)
	var worked := 0.0             # ore lavorate nella sua giornata, che comincia quando si alza (vedi update_routine)
	var workday := 0              # la giornata a cui si riferisce `worked`
	var streak := 0.0             # ore di lavoro di fila, senza pause né pasti
	var pause_until := 0.0        # `clock` fino a cui non lavora: è in pausa (vedi "streak" in TRAIT_FX)
	var hour := -1                # ultima ora vista, per accorgersi di quando scocca la successiva
	var died := 0.0               # `clock` della morte (vedi corpses)
	# avventurieri (vedi HEROES): per i coloni hero è NONE e il resto non conta
	var hero := Hero.NONE
	var level := 0                # 1-HERO_LEVEL_MAX
	var trips := 0                # spedizioni tornate
	var stay_until := 0.0         # `clock` fino a cui aspetta alla locanda che qualcuno lo ingaggi
	var errand := Errand.NONE     # dove va col Job.TRAVEL (vedi travel)
	var hired := false            # ingaggiato: va alla rovina, ci è, o ne torna
	var loot := {}                # Res -> quantità che riporta dalla rovina e lascia alla locanda
	var kit := []                 # Look del corredo: scudo, faretra, maschera, sacca
	var hood_tint = null          # Color del cappuccio, se non è di cuoio
	var gifts := []               # Gift: i talenti da avventuriero


# Animale selvatico: gira da solo per la mappa, fuori dalle stanze (vedi update_animal); si caccia (vedi try_hunt).
class Animal:
	var kind := Beast.RABBIT
	var pos: Vector2
	var path: Array[Vector2i] = []
	var damage := 0.0             # danni presi: con BEASTS[kind]["hp"] è abbattuto
	var target = null             # lupo: il Colonist che insegue
	var bite_left := 0.0          # lupo: secondi al prossimo morso
	var repath := 0.0             # lupo: secondi prima di poter rifare il percorso
	var leave_at := INF           # lupo: `clock` da cui se ne va, se non insegue nessuno
	var rest := 0.0               # secondi prima del prossimo giro
	var fleeing := false
	var left := false             # guarda a sinistra (lo sprite si specchia)
	var walked := 0.0             # pixel percorsi, scandisce il passo
	var marked := false           # da cacciare
	var hunter = null             # il Colonist che lo insegue
	var blocked := 0.0            # `clock` fino a cui nessuno ci arriva: lo si lascia stare


# Zona chiusa da muri (o roccia, acqua alta) con almeno una porta: una struttura finita.
class Room:
	var cells := {}               # caselle dentro, senza muri né porte
	var door := Vector2i.ZERO     # porta d'ingresso
	var sign := Vector2i.ZERO     # muro accanto alla porta col cartello (fuori davanti alla porta, se non ha muri)
	var name := ""
	var kind := RoomKind.NONE
	var owners: Array[Colonist] = []  # residenze: scelti nel popup del cartello, anche più d'uno; solo loro ci entrano
	var workers: Array[Colonist] = [] # stanze di lavoro: chi ci lavora, scelti allo stesso modo; l'ingresso resta libero
	# ponytail: i lavoratori non cambiano ancora niente; con cucina e forgia solo loro ne faranno i lavori
	var banned := false               # nessuno ci entra, nemmeno i proprietari



var astar := AStarGrid2D.new()
var rocks := {}             # cella -> true (non attraversabile)
var boulders := {}          # cella in alto a sinistra -> dimensione del masso che copre quelle rocce
var ores := {}              # cella -> Res.IRON o Res.COAL: massi 1x1 che scavati danno il minerale invece della pietra
var water := {}             # cella -> Ground.SHALLOW (si guada) o Ground.DEEP (non si attraversa)
var ground_texture: ImageTexture  # tutto il terreno già disegnato, vedi bake_ground
var trees := {}             # cella -> TreeKind (attraversabile), in ordine di riga: serve a _draw
var stock := {}             # albero, masso (cella d'origine) o cespuglio -> quanto resta da raccogliere; se manca, full_stock
var bushes := {}            # cella -> `clock` da cui ha le bacche (attraversabile): raccolte, il cespuglio resta
var weeds := {}             # cella -> true: erbacce (attraversabili)
var chop_marks := {}        # cella -> true: alberi da tagliare
var mine_marks := {}        # cella d'origine -> true: massi da scavare
var uproot_marks := {}      # cella -> true: erbacce e cespugli da estirpare
var harvest_marks := {}     # cella -> true: cespugli da cui raccogliere le bacche, ogni volta che maturano
var fish_marks := {}        # cella d'acqua -> true: punti di pesca
var fish_spots := {}        # cella d'acqua -> `clock` da cui ci sono di nuovo pesci (se manca, ci sono)
var animals: Array[Animal] = []
var wild := RandomNumberGenerator.new()  # tutto il caso degli animali: non sposta quello del resto della partita
var next_animal := ANIMAL_RESPAWN  # `clock` del prossimo arrivo
var threats := true         # false nei test: niente branchi di lupi
var next_pack := WOLF_FIRST # `clock` del prossimo branco
var deaths := true          # false nei test: a 0 punti ferita si resta a terra, nessuno muore
var corpses: Array[Colonist] = []  # morti: restano a terra CORPSE_DAYS (vedi die)
var fallen := false         # sono morti tutti i coloni
var guests: Array[Colonist] = []   # avventurieri sulla mappa: alla locanda, per strada, di ritorno (vedi update_guests)
var next_guest := GUEST_EVERY      # `clock` del prossimo arrivo alla locanda
var ruins: Array[Ruin] = []
var expeditions: Array[Expedition] = []
var chronicle: PackedStringArray = []  # diari delle spedizioni e morti, dal più vecchio (vedi note)
var board_key := ""         # quello che mostra la bacheca: se cambia, la si rifà (vedi fill_board)
var board_pick: Array[Colonist] = []  # spuntati alla bacheca per la prossima spedizione
var items := {}  # risorsa -> (cella -> quantità a terra; nel magazzino = stoccata): un dizionario per Res, vedi _init  # risorsa -> (cella -> quantità a terra; nel magazzino = stoccata)
var fresh := {}             # cella -> giorni (a terra fuori) prima che il mucchio di cibo marcisca, vedi spoil
var stockpile := {}         # cella -> true: dentro le stanze di tipo magazzino, vedi update_stockpile
var rooms: Array[Room] = []  # stanze finite, vedi update_rooms
var rooms_made := 0         # per i nomi di default
var editing: Room           # la stanza aperta nel popup del cartello
var shown: Colonist         # il colono nella scheda: le barre dei bisogni lo seguono
var lens_owners := []       # [centro, proprietari o lavoratori] per stanza delle figurine sulla lente, vedi place_owners
var needs_rate := 1.0       # 0 nei test: i bisogni restano fermi e non cambiano i lavori
var routines := true        # false nei test: niente orari né ore massime, chi è libero prende il primo lavoro
var start_rooms := true     # false nei test: mappa di sempre, senza stanze né scorte di partenza (va messo prima di _ready)
var reserved := {}          # cella -> Colonist che la sta usando
var unreachable := {}       # cella -> `clock` da cui riprovare ad arrivarci, vedi path_to_nearest
var draft := {}             # cella -> [Build, Res]: progetto in preparazione, i coloni lo ignorano fino a "Build"
var blueprints := {}        # cella -> [Build, Res]: da costruire
var built := {}             # cella -> [Build, Res]: i muri sono solidi, i pavimenti si calpestano
# mobili, come draft / blueprints / built ma nella casella in alto a sinistra -> [Build, Res, quarti di giro]:
# stanno anche sopra i pavimenti, si attraversano
var furniture_draft := {}
var furniture_plans := {}
var furniture := {}
var colonists: Array[Colonist] = []
var order := Order.NONE
var build_kind := Build.WALL  # cosa e con cosa costruisce l'ordine BUILD (scelti nella barra in alto)
var build_res := Res.WOOD
var build_turn := 0         # quarti di giro in senso orario del prossimo mobile (E / R)
var drag_start = null       # cella d'inizio della selezione, o null
var drag_end := Vector2i.ZERO
var clock := 8.0 / 24       # giorni passati: la parte intera conta i giorni, quella decimale è l'ora
var sky := CanvasModulate.new()   # tinge il mondo secondo SKY
var sky_colors := Gradient.new()
var flat := Node2D.new()          # pavimenti, progetti, mucchi: stanno a terra, le ombre ci cadono sopra
var shadows := CanvasGroup.new()  # fonde le sagome: dove si sovrappongono non scuriscono il doppio
var casters := Node2D.new()       # dentro `shadows`: ci si disegnano le sagome
var feet := {}                    # [texture, rettangolo] -> base della sagoma, vedi foot_of
# lenti: sopra il mondo e sotto l'interfaccia (HUD è al livello 2), in un livello a parte così la notte non le scurisce
var lens := CanvasLayer.new()
var lens_canvas := Node2D.new()   # ci disegna draw_lens
# luci accese di notte: come le lenti, in un livello che la notte non scurisce; ci disegna draw_lights
var lights := CanvasLayer.new()
var lights_canvas := Node2D.new()

@onready var camera: Camera2D = $Camera2D
@onready var stored_label: Label = $HUD/TopBar/Row/Stored  # risorse in tutti i magazzini, sommate: il dettaglio è in Resources
@onready var colonists_label: Label = $HUD/TopBar/Row/Colonists
@onready var beds_label: Label = $HUD/TopBar/Row/Beds
@onready var splendor_label: Label = $HUD/TopBar/Row/Splendor
@onready var info_label: Label = $HUD/TopBar/Row/Info
@onready var fullscreen: Button = $HUD/TopBar/Row/Fullscreen
@onready var build_bar: Control = $HUD/BuildBar
@onready var furniture_bar: Control = $HUD/FurnitureBar
@onready var materials: Control = $HUD/BuildBar/Row/Materials
@onready var actions: Control = $HUD/Actions  # in basso al centro: "Build" e la X rossa
@onready var confirm: Button = $HUD/Actions/Confirm
@onready var erase: Button = $HUD/Actions/Erase
@onready var material_group: ButtonGroup = $HUD/BuildBar/Row/Materials/Wood.button_group
@onready var kind_group: ButtonGroup = $HUD/BuildBar/Row/Wall.button_group  # anche dei mobili
@onready var select_button: Button = $HUD/Tools/Row/Select  # la freccia, prima a sinistra: vedi select_tool
@onready var structures_button: Button = $HUD/Tools/Row/Structures
@onready var furniture_button: Button = $HUD/Tools/Row/Furniture
@onready var order_group: ButtonGroup = $HUD/Tools/Row/Destroy.button_group  # Destroy, Mine, Chop, Uproot
@onready var room_popup: Control = $HUD/RoomPopup  # pannello al centro
@onready var room_name: LineEdit = $HUD/RoomPopup/Box/Name
@onready var room_kind: OptionButton = $HUD/RoomPopup/Box/Kind  # solo i tipi possibili, vedi refresh_room
@onready var room_owners: Control = $HUD/RoomPopup/Box/Owners/List  # una casella da spuntare per colono: proprietari o lavoratori
@onready var jobs_panel: Control = $HUD/JobsPanel  # a destra, si apre col tasto Jobs in basso: vedi job_list
@onready var jobs_list: Label = $HUD/JobsPanel/Box/List
@onready var resources_panel: Control = $HUD/ResourcesPanel  # stesso posto: vedi update_resources
@onready var resources_list: Control = $HUD/ResourcesPanel/Box/List  # una riga per Res: icona, nome, quantità
@onready var sheet_panel: Control = $HUD/ColonistSheet  # a sinistra, si apre cliccando un colono: vedi open_sheet
@onready var object_sheet: Control = $HUD/ObjectSheet  # in basso a destra: la casella sotto il mouse, vedi show_tip
@onready var sheet_needs: GridContainer = $HUD/ColonistSheet/Box/Needs  # 4 colonne: nome, freccia giù, barra, freccia su


# Rovina fuori dalla mappa (vedi RUINS): le stanze ripulite restano ripulite
class Ruin:
	var kind := RuinKind.TOWER
	var cleared := 0


# Spedizione: il gruppo va al bordo della mappa, parte (lì si decide com'è andata, vedi explore) e torna a back_at
class Expedition:
	var party: Array[Colonist] = []  # chi è partito; quelli morti nella rovina li toglie explore
	var ruin: Ruin
	var edge := Vector2i(-1, -1)  # dove è uscito il primo: gli altri escono lì, e tornano da lì
	var left_at := -1.0           # `clock` della partenza; -1 finché vanno verso il bordo
	var due := INF                # `clock` del ritorno previsto: viaggio e tutte le stanze che restavano
	var back_at := INF            # `clock` del ritorno, o di quando la si dà per persa
	var lost := false             # non torna nessuno
	var lines: PackedStringArray = []  # il diario, una riga per stanza
	var loot := {}                # Res -> quantità trovate, monete comprese
	var maps := []                # RuinKind delle mappe trovate: le rovine si conoscono al ritorno
	var food := 0.0               # provviste, in giorni a testa (1 = un giorno per uno), vedi eat_on_trip


func _init() -> void:
	for res in Res.values():
		items[res] = {}


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
	for i in COLONIST_COUNT:
		var c := Colonist.new()
		c.pos = center(MAP_SIZE / 2 + Vector2i(i - 1, 0))
		c.tunic = TUNIC_COLORS[i % TUNIC_COLORS.size()]
		dress(c)
		c.skills = Skill.values().map(func(_s): return 0)
		c.xp = Skill.values().map(func(_s): return 0)
		# sfalsati: non dormono tutti insieme; lo stress parte basso
		c.needs = Need.values().map(func(n): return randf_range(0, 40) if n == Need.STRESS else randf_range(60, NEED_MAX))
		c.trend = c.needs.map(func(_v): return 0.0)
		var pool := Trait.values()
		pool.shuffle()
		var count := randi_range(0, 2)
		for t in pool:  # a caso, ma niente talenti in contrasto (vedi TRAIT_CLASH)
			if c.traits.size() < count and not c.traits.any(func(o): return clash(o, t)):
				c.traits.append(t)
		colonists.append(c)
	camera.position = center(MAP_SIZE / 2)
	fullscreen.pressed.connect(toggle_fullscreen)
	$HUD/TopBar/Row/Options.pressed.connect(get_tree().quit)  # ponytail: per ora chiude il gioco, poi aprirà le opzioni
	structures_button.toggled.connect(toggle_build.bind(build_bar))
	furniture_button.toggled.connect(toggle_build.bind(furniture_bar))
	for o in ORDER_TOOLS:
		get_node("HUD/Tools/Row/" + ORDER_TOOLS[o]).toggled.connect(toggle_order.bind(o))
	select_button.toggled.connect(select_tool.unbind(1))
	for button in [structures_button, furniture_button] + order_group.get_buttons():
		button.toggled.connect(sync_select.unbind(1))
	room_name.text_changed.connect(func(text): editing.name = text)
	room_kind.item_selected.connect(func(index): set_room_kind(room_kind.get_item_id(index)))
	$HUD/RoomPopup/Box/Banned.toggled.connect(func(on):
		editing.banned = on
		recheck_access())
	lens.follow_viewport_enabled = true  # segue la telecamera come il mondo
	lens.layer = 1
	lens.visible = false
	lights.follow_viewport_enabled = true
	lights.layer = 1
	lights.add_child(lights_canvas)
	add_child(lights)
	lights_canvas.draw.connect(draw_lights)
	lens.add_child(lens_canvas)
	add_child(lens)
	lens_canvas.draw.connect(draw_lens)
	$HUD/Tools/Row/RoomsLens.toggled.connect(lens.set_visible)
	$HUD/RoomPopup/Box/Ok.pressed.connect(room_popup.hide)
	for kind in Build.values():  # un pulsante per tipo, con lo stesso nome: Wall, Floor, ... Lamp
		var bar := furniture_bar if FURNITURE.has(kind) else build_bar
		var button: Button = bar.get_node("Row/" + Build.keys()[kind].capitalize())
		button.set_script(TIP)
		button.set("make_tip", build_tip.bind(kind))
		button.tooltip_text = Build.keys()[kind].capitalize()  # Godot lo mostra da sé col mouse sopra, via build_tip
		button.pressed.connect(choose_kind.bind(kind))
	$HUD/FurnitureBar/Row/Turn/Left.pressed.connect(turn.bind(-1))
	$HUD/FurnitureBar/Row/Turn/Right.pressed.connect(turn.bind(1))
	$HUD/BuildBar/Row/Materials/Wood.pressed.connect(choose_res.bind(Res.WOOD))
	$HUD/BuildBar/Row/Materials/Stone.pressed.connect(choose_res.bind(Res.STONE))
	confirm.pressed.connect(confirm_build)
	erase.toggled.connect(toggle_erase)
	$HUD/Tools/Row/Jobs.toggled.connect(jobs_panel.set_visible)
	$HUD/Tools/Row/Resources.toggled.connect(resources_panel.set_visible)
	jobs_panel.hidden.connect($HUD/Tools/Row/Jobs.set_pressed_no_signal.bind(false))  # chiusa con la X: tasto su
	resources_panel.hidden.connect($HUD/Tools/Row/Resources.set_pressed_no_signal.bind(false))
	for res in Res.values():
		var row := HBoxContainer.new()
		row.add_child(ui_icon(ICONS[res], Rect2(), Vector2(32, 32)))
		for text in [Res.keys()[res].capitalize(), ""]:  # nome, quantità
			var label := Label.new()
			label.text = text
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if text == "" else HORIZONTAL_ALIGNMENT_LEFT
			row.add_child(label)
		resources_list.add_child(row)
	ruins.append(Ruin.new())  # per ora solo la torre
	$HUD/BoardPanel/Box/ChronicleButton.pressed.connect(open_chronicle)
	for window in [room_popup, jobs_panel, resources_panel, sheet_panel, $HUD/BoardPanel, $HUD/ReportPanel, $HUD/ChroniclePanel]:  # X in alto a destra, si trascinano
		window.get_node("Box/Head/Close").pressed.connect(window.hide)
		window.gui_input.connect(drag_window.bind(window))
		window.visibility_changed.connect(window.move_to_front, CONNECT_DEFERRED)  # l'ultima aperta sta sopra


# finestre: col tasto sinistro si portano sopra le altre e si trascinano, senza uscire dallo schermo
func drag_window(event: InputEvent, window: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			window.move_to_front()
		window.accept_event()  # se no il clic passa alla mappa
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		window.position = (window.position + event.relative).clamp(Vector2.ZERO, get_viewport_rect().size - window.size)
		window.accept_event()


func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen.text = "Fullscreen" if full else "Window"


# tasto "Select" (freccia): nessuno strumento, il clic sulla mappa apre le schede. Premuto chiude quello aperto;
# resta premuto finché non se ne sceglie un altro e torna su da solo quando si chiude l'ultimo (vedi sync_select)
func select_tool() -> void:
	for button in [structures_button, furniture_button, order_group.get_pressed_button()]:
		if button:
			button.button_pressed = false
	sync_select()  # cliccato già premuto si spegnerebbe: lo riaccende


func sync_select() -> void:
	select_button.set_pressed_no_signal(not (structures_button.button_pressed or furniture_button.button_pressed
		or order_group.get_pressed_button()))


# tasti "Structures" (sega e martello) e "Furniture" (lampada) in basso a sinistra, uno alla volta: sopra compare
# la sua barra (strutture e materiale, o mobili e frecce per girarli), al centro "Build" e la X per cancellare.
# Passando dall'uno all'altro il progetto resta (es. un letto sul pavimento appena disegnato); chiudendo si scarta
func toggle_build(on: bool, bar: Control) -> void:
	bar.visible = on
	if on:
		reset_choice()  # il tipo scelto nell'altra barra qui non c'è
		var other: Button = furniture_button if bar == build_bar else structures_button
		other.button_pressed = false
		var tool := order_group.get_pressed_button()
		if tool:
			tool.button_pressed = false
	actions.visible = structures_button.button_pressed or furniture_button.button_pressed
	if not actions.visible:
		draft.clear()  # chiudere senza confermare scarta il progetto
		furniture_draft.clear()
		reset_choice()


# nessun tipo scelto: il trascinamento non disegna progetti finché non se ne sceglie uno
func reset_choice() -> void:
	for group in [kind_group, material_group]:
		var pressed: BaseButton = group.get_pressed_button()
		if pressed:
			pressed.button_pressed = false
	materials.visible = false
	erase.button_pressed = false
	if order in [Order.BUILD, Order.ERASE]:
		order = Order.NONE


func choose_kind(kind: Build) -> void:
	build_kind = kind
	materials.visible = kind in ANY_MATERIAL
	erase.button_pressed = false
	if not materials.visible:  # porta e mobili: materiale fisso, niente scelta (il tasto segna solo "tipo scelto")
		$HUD/BuildBar/Row/Materials/Wood.button_pressed = true
		choose_res(BUILD_RES.get(kind, Res.WOOD))


# nome in alto a sinistra, a destra i materiali in colonna (muri e pavimenti: legno o pietra, per casella; il resto
# il suo materiale, per pezzo); sotto il comfort che dà, una riga e la descrizione colorata
func build_tip(kind: Build) -> Control:
	var box := VBoxContainer.new()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	var title := Label.new()
	title.text = Build.keys()[kind].capitalize()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var costs := VBoxContainer.new()
	for res in [Res.WOOD, Res.STONE] if kind in ANY_MATERIAL else [BUILD_RES.get(kind, Res.WOOD)]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		var amount := Label.new()
		amount.text = "%s%d%s" % ["or " if res == Res.STONE and kind in ANY_MATERIAL else "", BUILD_COST[kind], "" if FURNITURE.has(kind) else "/tile"]
		row.add_child(amount)
		row.add_child(ui_icon(ICONS[res], Rect2(), Vector2(16, 16)))
		costs.add_child(row)
	head.add_child(title)
	head.add_child(costs)
	box.add_child(head)
	if COMFORT.has(kind):  # chi non dà comfort salta la sezione
		var bonus := Label.new()
		bonus.text = "+%s room comfort" % str(COMFORT[kind]).trim_suffix(".0")
		if kind == Build.FLOOR:
			bonus.text += " paving it all, x%s in stone" % COMFORT_MATERIAL[Res.STONE]
		bonus.add_theme_color_override("font_color", TREND_UP)
		box.add_child(bonus)
	if SPLENDOR.has(kind):
		var splendor := Label.new()
		splendor.text = "+%d colony splendor" % SPLENDOR[kind]
		splendor.add_theme_color_override("font_color", SPLENDOR_COLOR)
		box.add_child(splendor)
	box.add_child(HSeparator.new())
	var info := Label.new()
	info.text = BUILD_INFO[kind]
	info.add_theme_color_override("font_color", BUILD_INFO_COLOR)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # le frasi lunghe vanno a capo invece di allargare il riquadro
	info.custom_minimum_size.x = 240
	box.add_child(info)
	return box


# E / R e le frecce nella barra: gira il prossimo mobile di un quarto, in senso antiorario o orario
func turn(by: int) -> void:
	build_turn = posmod(build_turn + by, 4)


func choose_res(res: Res) -> void:
	build_res = res
	erase.button_pressed = false
	order = Order.BUILD  # da qui il trascinamento disegna il progetto


# X rossa: finché è premuta il trascinamento cancella caselle del progetto
func toggle_erase(on: bool) -> void:
	if on:
		order = Order.ERASE
	elif order == Order.ERASE:
		order = Order.BUILD if material_group.get_pressed_button() else Order.NONE


# tasti "Destroy", "Mine", "Chop", "Uproot", "Harvest" dopo "Furniture": finché uno è premuto, trascinando o cliccando
# si abbatte quello che è costruito, si segnano massi da scavare, alberi da tagliare, erbacce e cespugli da estirpare,
# cespugli da cui raccogliere le bacche (ogni volta che maturano, finché il segno resta)
func toggle_order(on: bool, which: Order) -> void:
	if on:
		structures_button.button_pressed = false
		furniture_button.button_pressed = false
		order = which
	elif order == which:
		order = Order.NONE


# cartello di una stanza: popup con nome, comfort, tipo, divieto e, secondo la categoria del tipo, proprietari
# (residenze) o lavoratori (stanze di lavoro)
func open_room(room: Room) -> void:
	editing = room
	room_name.text = room.name
	$HUD/RoomPopup/Box/Banned.set_pressed_no_signal(room.banned)
	fill_people()
	refresh_room()
	room_popup.show()
	room_popup.reset_size()  # si stringe se prima c'erano più righe


# lista di coloni da spuntare nel popup: proprietari o lavoratori della stanza aperta; nascosta per le altre categorie
func fill_people() -> void:
	var title: String = ROOM_PEOPLE.get(room_class(editing), "")
	var section: Control = $HUD/RoomPopup/Box/Owners
	section.visible = title != ""
	section.get_node("Title").text = title
	for child in room_owners.get_children():
		child.free()
	if title == "":
		return
	for c in colonists:
		var box := CheckBox.new()
		box.text = full_name(c)
		box.focus_mode = Control.FOCUS_NONE
		box.button_pressed = c in people_of(editing)
		box.toggled.connect(toggle_owner.bind(c))
		room_owners.add_child(box)


# comfort della stanza nel popup, e nella tendina solo i tipi di cui ci sono i mobili (vedi ROOM_NEEDS): l'id della
# voce è il RoomKind. La si rifà solo quando cambiano, se no si chiuderebbe mentre la si guarda
func refresh_room() -> void:
	$HUD/RoomPopup/Box/Comfort.text = "Comfort: %d / %d" % [room_comfort(editing), COMFORT_MAX]
	var kinds := RoomKind.values().filter(func(k): return room_meets(editing, k))
	if kinds != range(room_kind.item_count).map(room_kind.get_item_id):
		room_kind.clear()
		for kind in kinds:
			room_kind.add_item(RoomKind.keys()[kind].capitalize(), kind)
	room_kind.select(room_kind.get_item_index(editing.kind))


# spunta nel popup: proprietario di una residenza o lavoratore di una stanza di lavoro
func toggle_owner(on: bool, c: Colonist) -> void:
	var list := people_of(editing)
	if on:
		list.append(c)
	else:
		list.erase(c)
	recheck_access()


func room_class(room: Room) -> RoomClass:
	return ROOM_CLASS.get(room.kind, RoomClass.NONE)


# chi si spunta nel popup e compare sulla lente: proprietari (residenze), lavoratori (lavoro), nessuno per le altre
func people_of(room: Room) -> Array[Colonist]:
	match room_class(room):
		RoomClass.RESIDENCE: return room.owners
		RoomClass.WORK: return room.workers
	var nobody: Array[Colonist] = []
	return nobody


# scheda del colono, a sinistra: si aggiorna mentre è aperta (vedi _process)
func open_sheet(c: Colonist) -> void:
	fill_sheet($HUD/ColonistSheet/Box, c)
	shown = c
	sheet_panel.show()
	sheet_panel.move_to_front()  # se era già aperta, sotto un'altra


# suggerimento sulle figurine dei proprietari: la scheda di `c` com'è adesso, senza la X.
# Copia quella a sinistra: fill_sheet ne rifà tutte le righe, così le barre non ne condividono la tinta
func colonist_tip(c: Colonist) -> Control:
	var box: Control = $HUD/ColonistSheet/Box.duplicate()
	fill_sheet(box, c)
	box.get_node("Head/Close").hide()
	return box


# riempie `box` (HUD/ColonistSheet/Box o una sua copia) col colono `c`: nome, sesso, salute, bisogni (nome,
# freccia giù, barra, freccia su), abilità (stellina al massimo) e sotto i talenti, col suggerimento
func fill_sheet(box: Control, c: Colonist) -> void:
	var needs_grid: Control = box.get_node("Needs")
	var skills_grid: Control = box.get_node("Skills")  # due abilità per riga, ognuna: icona, nome, livello, stellina
	var traits_box: Control = box.get_node("Traits/Icons")  # solo icone: il nome è nel suggerimento
	box.get_node("Head/Name").text = full_name(c)
	box.get_node("Sex/Icon").texture = SEX_ICONS[c.sex]
	box.get_node("Sex/Label").text = SEX_NAMES[c.sex]
	box.get_node("Hero").visible = c.hero != Hero.NONE
	box.get_node("Hero").text = "%s, fee %d gold, %d expedition%s" % [hero_name(c), fee(c), c.trips, "" if c.trips == 1 else "s"] \
		if c.hero != Hero.NONE else ""
	box.get_node("Health").text = health_text(c)
	for child in needs_grid.get_children() + skills_grid.get_children() + traits_box.get_children():
		child.free()
	var back := bar_style(BAR_BACK)
	for n in Need.values():  # i valori li aggiorna update_need_bars
		var label := Label.new()
		label.text = Need.keys()[n].capitalize()
		var bar := ProgressBar.new()
		bar.max_value = NEED_MAX
		bar.step = 0.0  # se no arrotonda a scatti di 1
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(120, 12)  # alta quanto BAR_FILL
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("background", back)
		bar.add_theme_stylebox_override("fill", bar_style(BAR_FILL))  # una per barra: la tinta segue il valore
		var down := ui_icon(ARROW, Rect2(), Vector2(8, 14))
		down.flip_h = true
		var head: Control = label
		if n == Need.STRESS:  # con la sua icona davanti al nome
			head = HBoxContainer.new()
			head.add_child(ui_icon(STRESS_ICON, Rect2(), Vector2(16, 16)))
			head.add_child(label)
		for node in [head, down, bar, ui_icon(ARROW, Rect2(), Vector2(8, 14))]:
			needs_grid.add_child(node)
	for s in Skill.values():
		var skill := Label.new()
		skill.text = Skill.keys()[s].capitalize()
		skill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var level := Label.new()
		level.text = str(c.skills[s])
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		level.tooltip_text = "%d XP" % c.xp[s]
		level.mouse_filter = Control.MOUSE_FILTER_PASS  # se no il suggerimento non compare
		var star := ui_icon(STAR if c.skills[s] == SKILL_MAX else null, Rect2(), Vector2(18, 18))  # vuota, tiene la colonna
		for node in [ui_icon(SKILLS_SHEET, Rect2(s * 8, 0, 8, 8), Vector2(16, 16)), skill, level, star]:
			skills_grid.add_child(node)
	for t in c.traits:
		var icon := ui_icon(TRAITS_SHEET, Rect2(tile_rect(t, 0)), Vector2(32, 32))
		icon.tooltip_text = "%s\n%s" % [Trait.keys()[t].capitalize(), TRAIT_INFO[t]]
		traits_box.add_child(icon)
	for g in c.gifts:  # degli avventurieri
		var icon := ui_icon(HERO_TRAITS_SHEET, Rect2(tile_rect(g, 0)), Vector2(32, 32))
		icon.tooltip_text = "%s\n%s" % [Gift.keys()[g].capitalize(), GIFT_INFO[g]]
		traits_box.add_child(icon)
	traits_box.get_parent().visible = not (c.traits.is_empty() and c.gifts.is_empty())  # col titolo "Traits"
	var hours: Control = box.get_node("Routine/Hours")  # una casella per ora, colorata secondo la routine
	for child in hours.get_children():
		child.free()
	for h in 24:
		var cell := ColorRect.new()
		cell.custom_minimum_size = Vector2(8, 12)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS  # se no il suggerimento non compare
		hours.add_child(cell)
	for child in box.get_node("Conditions/Icons").get_children():  # da rifare: magari era la scheda di un altro
		child.free()
	box.get_node("Conditions/Icons").set_meta("conds", [])
	update_need_bars(needs_grid, c)
	update_routine_row(box.get_node("Routine"), c)
	update_conds(box, c)
	update_gear(box, c)


func health_text(c: Colonist) -> String:
	return "Health: %d / %d%s" % [ceili(c.hp), MAX_HP, "  (downed)" if c.downed else ""]


# slot dell'equipaggiamento: l'icona del pezzo, col mouse sopra nome, protezione ed effetto; vuoto, la sagoma dello slot.
# Sopra gli slot la protezione totale
func update_gear(box: Control, c: Colonist) -> void:
	var slots: Control = box.get_node("Equipment/Slots")
	for slot in Slot.values():
		var icon: TextureRect = slots.get_child(slot)
		if not icon.has_meta("empty"):
			icon.set_meta("empty", icon.texture)
		var g = c.gear.get(slot)
		icon.texture = ICONS[g] if g != null else icon.get_meta("empty")
		icon.tooltip_text = Slot.keys()[slot].capitalize() if g == null else "%s\n%s%s" % [Res.keys()[g].capitalize(),
			"Armor %d. " % GEAR[g]["armor"] if GEAR[g].has("armor") else "", GEAR[g]["info"]]
	box.get_node("Equipment/Title").text = "Equipment" + ("  (armor %d)" % gear_sum(c, "armor") if gear_sum(c, "armor") > 0 else "")


# condizioni di `c` sotto i talenti, solo icone come loro: col mouse sopra nome, effetto e quanto manca. Le icone si
# rifanno solo quando cambiano le condizioni (se no il suggerimento sparirebbe), il tempo che manca a ogni chiamata
func update_conds(box: Control, c: Colonist) -> void:
	var icons: Control = box.get_node("Conditions/Icons")
	var now := c.conds.keys()
	now.sort()
	if icons.get_meta("conds", []) != now:
		icons.set_meta("conds", now)
		for child in icons.get_children():
			child.free()
		for k in now:
			var icon := ui_icon(CONDITIONS_SHEET, Rect2(tile_rect(k, 0)), Vector2(32, 32))
			icon.mouse_filter = Control.MOUSE_FILTER_PASS
			icons.add_child(icon)
	for i in now.size():
		icons.get_child(i).tooltip_text = "%s\n%s\n%d h left" % [Cond.keys()[now[i]].capitalize(), COND_INFO[now[i]][4],
			ceili((c.conds[now[i]] - clock) * 24)]
	icons.get_parent().visible = not now.is_empty()  # col titolo "Conditions"


# riga della routine nella scheda: le ore colorate (vedi ROUTINE_COLORS), l'ora attuale piena e le altre velate,
# sotto le ore lavorate oggi. Si aggiorna mentre la scheda è aperta: i talenti possono cambiare, e l'ora scorre
func update_routine_row(row: Control, c: Colonist) -> void:
	var day := routine_of(c)
	var now := hour_now()
	for h in 24:
		var cell: ColorRect = row.get_node("Hours").get_child(h)
		cell.color = ROUTINE_COLORS[day[h]]
		cell.modulate.a = 1.0 if h == now else 0.45
		cell.tooltip_text = "%02d:00  %s" % [h, ROUTINE_NAMES[day[h]]]
	row.get_node("Worked").text = "Worked today: %.1f / %s h" % [c.worked, str(fx(c, "work", WORK_HOURS)).trim_suffix(".0")]


# barre dei bisogni di `c` nella griglia `needs_grid` della scheda: rossa da stremato, arancio sotto NEED_LOW, verde
# se a posto. Lo stress va al contrario: rosso quando è alto, e la freccia è verde quando scende
func update_need_bars(needs_grid: Control, c: Colonist) -> void:
	for n in Need.values():
		var bar: ProgressBar = needs_grid.get_child(n * 4 + 2)
		var value: float = c.needs[n]
		var good := NEED_MAX - value if n == Need.STRESS else value
		var trend: Array = [TREND_UP, TREND_DOWN] if n == Need.STRESS else [TREND_DOWN, TREND_UP]  # sinistra, destra
		bar.value = value
		bar.tooltip_text = "%d / %d" % [value, NEED_MAX]
		bar.get_theme_stylebox("fill").modulate_color = NEED_COLORS[0 if good <= EXHAUSTED else (1 if good < NEED_LOW else 2)]
		needs_grid.get_child(n * 4 + 1).modulate = trend[0] if c.trend[n] < 0 else TREND_OFF
		needs_grid.get_child(n * 4 + 3).modulate = trend[1] if c.trend[n] > 0 else TREND_OFF


# barra a pixel (BAR_FILL, BAR_BACK): angoli e bordi restano, il mezzo si allunga
func bar_style(tex: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.set_texture_margin_all(4)
	return style


# icona della scheda: il pezzo `region` di `tex` (tutta se vuoto), ingrandita a `size` senza deformarla
func ui_icon(tex: Texture2D, region: Rect2, size: Vector2) -> TextureRect:
	if region.has_area():
		var piece := AtlasTexture.new()
		piece.atlas = tex
		piece.region = region
		tex = piece
	var icon := TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon


# sesso a caso, e secondo il sesso nome (uno che nessuno sulla mappa ha già, se ce n'è) e acconciatura; colori del
# mantello e dei capelli
func dress(c: Colonist) -> void:
	c.sex = Sex.values().pick_random()
	c.hair_style = HAIR_STYLES[c.sex].pick_random()
	c.beard = c.sex == Sex.MALE and randf() < BEARD_CHANCE
	c.cape = CAPE_COLORS.pick_random()
	c.hair = HAIR_COLORS.pick_random()
	var taken := people().map(func(o): return o.first_name)
	var free: Array = FIRST_NAMES[c.sex].filter(func(n): return n not in taken)
	c.first_name = (free if not free.is_empty() else FIRST_NAMES[c.sex]).pick_random()
	c.nickname = NICKNAMES.pick_random() if randf() < 0.5 else ""
	c.last_name = LAST_NAMES.pick_random()


func full_name(c: Colonist) -> String:
	return "%s \"%s\" %s" % [c.first_name, c.nickname, c.last_name] if c.nickname else "%s %s" % [c.first_name, c.last_name]


# colono sotto `point` (pixel del mondo); se si sovrappongono, quello col centro più vicino
func colonist_at(point: Vector2) -> Colonist:
	var near := people().filter(func(c): return c.pos.distance_to(point) < TILE / 2.0)
	near.sort_custom(func(a, b): return a.pos.distance_to(point) < b.pos.distance_to(point))
	return near[0] if not near.is_empty() else null


func set_room_kind(kind: int) -> void:
	var before := room_class(editing)
	retype(editing, kind as RoomKind)
	if room_class(editing) != before:  # proprietari al posto dei lavoratori, o nessuno
		fill_people()
		room_popup.reset_size()
	update_stockpile()
	recheck_access()


# cambia il tipo di `room`: proprietari e lavoratori restano solo se la nuova categoria li prevede
func retype(room: Room, kind: RoomKind) -> void:
	room.kind = kind
	if room_class(room) != RoomClass.RESIDENCE:
		room.owners.clear()
	if room_class(room) != RoomClass.WORK:
		room.workers.clear()


# suggerimento in basso a destra: cosa c'è in `cell`, nascosto se non c'è niente. _process lo chiama ogni fotogramma
func show_tip(cell: Vector2i) -> void:
	var about := describe(cell)
	object_sheet.visible = not about.is_empty()
	if object_sheet.visible:
		$HUD/ObjectSheet/Box/Name.text = about[0]
		$HUD/ObjectSheet/Box/Info.text = about[1]
		$HUD/ObjectSheet/Box/Info.visible = about[1] != ""
		object_sheet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)  # si stringe nell'angolo


# [titolo, testo] del suggerimento per l'oggetto in `cell`, [] se non c'è niente. Gli alberi valgono anche sulla
# chioma, nella casella sopra; tra più cose nella stessa casella vince quella disegnata sopra.
func describe(cell: Vector2i) -> Array:
	for a in animals:
		if cell_of(a.pos) == cell:
			var lines := PackedStringArray()
			if hostile(a):
				lines.append("Hostile")
			if a.damage > 0:
				lines.append("Health: %d / %d" % [BEASTS[a.kind]["hp"] - a.damage, BEASTS[a.kind]["hp"]])
			if a.marked:
				lines.append("Marked: hunt")
			return [Beast.keys()[a.kind].capitalize(), "\n".join(lines)]
	if fish_marks.has(cell):
		return ["Fishing spot", "Fish: %d / %d" % [stock.get(cell, FISH_PER_SPOT), FISH_PER_SPOT] if fish_spots.get(cell, 0.0) <= clock
			else "Fish back in %.1f days" % (fish_spots[cell] - clock)]
	for t in [cell, cell + Vector2i.DOWN]:
		if trees.has(t):
			return [TreeKind.keys()[trees[t]].capitalize(), "Logs left: %d / %d%s" % [stock.get(t, full_stock(t)), full_stock(t),
				"\nMarked: chop" if chop_marks.has(t) else ""]]
	for origin in boulders:
		if Rect2i(origin, boulders[origin]).has_point(cell):
			var res: Res = ores.get(origin, Res.STONE)
			return ["Boulder" if res == Res.STONE else "%s vein" % Res.keys()[res].capitalize(), "%s left: %d / %d%s" % [
				Res.keys()[res].capitalize(), stock.get(origin, full_stock(origin)), full_stock(origin),
				"\nMarked: mine" if mine_marks.has(origin) else ""]]
	var uproot := "\nMarked: uproot" if uproot_marks.has(cell) else ("\nMarked: harvest" if harvest_marks.has(cell) else "")
	if bushes.has(cell):
		var ripe: bool = bushes[cell] <= clock
		return ["Bush", ("Berries: %d / %d" % [stock.get(cell, BERRIES_PER_BUSH), BERRIES_PER_BUSH] if ripe
			else "Berries in %.1f days" % (bushes[cell] - clock)) + uproot]
	if weeds.has(cell):
		return ["Weed", uproot.strip_edges()]
	for res in items:
		if items[res].has(cell):
			var about := "%d / %d" % [items[res][cell], STACK_MAX[res]]
			if fresh.has(cell):  # cibo: quanto è fresco e quando marcisce, dove si trova adesso
				var part: float = fresh[cell] / SHELF_LIFE[res]
				about += "\n%s, rots in %.1f days" % [FRESH_WORDS.filter(func(w): return part > w[0] or w[0] == 0.0)[0][1],
					fresh[cell] / spoil_rate(cell)]
			return ["%s pile" % Res.keys()[res].capitalize(), about]
	for origin in pieces_at(furniture, cell):
		return [Build.keys()[furniture[origin][0]].capitalize(), ""]
	if built.has(cell):
		return [Build.keys()[built[cell][0]].capitalize(), Res.keys()[built[cell][1]].capitalize()]
	return []


# tasto "Build": il progetto diventa lavoro per i coloni liberi
func confirm_build() -> void:
	for cell in draft:
		if can_build(cell, draft[cell][0]):  # nel frattempo può esserci finita sopra della roba
			blueprints[cell] = draft[cell]
	draft.clear()
	var pieces := furniture_draft.duplicate()
	furniture_draft.clear()  # se no ogni mobile troverebbe occupato il suo stesso posto
	for origin in pieces:
		if cells_in(piece_rect(origin, pieces[origin])).all(func(k): return can_build(k, pieces[origin][0])):
			furniture_plans[origin] = pieces[origin]


# finestra "Jobs": lavori in attesa per tipo, nell'ordine in cui i coloni li scelgono (vedi find_work)
func job_list() -> String:
	var lines := PackedStringArray()
	if not chop_marks.is_empty():
		lines.append("Chop trees: %d" % chop_marks.size())
	if not mine_marks.is_empty():
		lines.append("Mine boulders: %d" % mine_marks.size())
	if not uproot_marks.is_empty():
		lines.append("Uproot plants: %d" % uproot_marks.size())
	if not harvest_ready().is_empty():
		lines.append("Harvest bushes: %d" % harvest_ready().size())
	if not fishable().is_empty():
		lines.append("Fish spots: %d" % fishable().size())
	var hunted := animals.filter(func(a): return a.marked)
	if not hunted.is_empty():
		lines.append("Hunt animals: %d" % hunted.size())
	if meals_wanted() > 0 and not kitchen_fires().is_empty():
		lines.append("Cook meals: %d" % meals_wanted())
	for r in RECIPES:  # solo quello che manca e che ha una postazione
		if gear_wanted(r[0]) > 0 and not stations(r[1]).is_empty():
			lines.append("Make %s: %d" % [Res.keys()[r[0]].capitalize().to_lower(), gear_wanted(r[0])])
	for plans in [blueprints, furniture_plans]:  # prima le strutture (per casella), poi i mobili (per pezzo)
		var counts := {}  # "wall (wood)" -> quanti
		for plan in plans.values():
			var what := "%s (%s)" % [Build.keys()[plan[0]].to_lower(), Res.keys()[plan[1]].to_lower()]
			counts[what] = counts.get(what, 0) + 1
		for what in counts:
			lines.append("Build %s: %d" % [what, counts[what]])
	for res in Res.values():
		var piles: Array = items[res].keys().filter(func(cell): return not stockpile.has(cell))
		if not piles.is_empty() and not stockpile.is_empty():  # senza magazzino nessuno trasporta
			lines.append("Haul %s: %d piles" % [Res.keys()[res].to_lower(), piles.size()])
	return "\n".join(lines) if not lines.is_empty() else "Nothing to do"


# finestra "Resources": quanto c'è in tutti i magazzini insieme, solo le risorse presenti
func update_resources() -> void:
	var amounts := Res.values().map(stored)
	for res in Res.values():
		var row: Control = resources_list.get_child(res)
		row.visible = amounts[res] > 0
		row.get_child(2).text = str(amounts[res])
	$HUD/ResourcesPanel/Box/Empty.visible = amounts.max() == 0
	resources_panel.reset_size()  # si stringe se una risorsa finisce


func generate_map() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.08
	var lakes := FastNoiseLite.new()
	lakes.seed = noise.seed + 1
	lakes.frequency = 0.04
	# stanze di partenza: centro a 8 caselle dalla radura, muri a 3 dal centro, più un giro di prato attorno
	var starts: Array = START_ROOMS if start_rooms else []
	var room_rects := starts.map(func(d): return Rect2i(MAP_SIZE / 2 + d * 8 - Vector2i(4, 4), Vector2i(9, 9)))
	for y in MAP_SIZE.y:  # per righe, così `trees` resta ordinato dall'alto in basso
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			if (cell - MAP_SIZE / 2).length() < 4 or room_rects.any(func(r): return r.has_point(cell)):
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
			elif n < -0.05 and randf() < 0.1:  # cespugli nel sottobosco e ai margini, con le bacche già mature
				bushes[cell] = 0.0
			elif randf() < 0.03:  # erbacce sparse nei prati
				weeds[cell] = true

	for cell in water:  # l'acqua alta non tocca mai la riva, neanche in diagonale: in mezzo c'è sempre quella bassa
		if water[cell] == Ground.DEEP and not (EDGE_SIDES + EDGE_CORNERS).all(func(d): return water.has(cell + d)):
			water[cell] = Ground.SHALLOW
		if water[cell] == Ground.DEEP:
			astar.set_point_solid(cell)
		else:
			astar.set_point_weight_scale(cell, SHALLOW_COST)

	# vene nella roccia, a macchie: carbone dove il rumore è alto, ferro dove è basso; ogni casella è un masso 1x1
	var veins := FastNoiseLite.new()
	veins.seed = noise.seed + 2
	veins.frequency = 0.15
	for cell in rocks:
		var v := veins.get_noise_2d(cell.x, cell.y)
		if absf(v) > ORE_VEIN:
			ores[cell] = Res.COAL if v > 0 else Res.IRON

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
			if size == Vector2i.ONE or (randf() < 0.7 and cells.all(func(k): return rocks.has(k) and not covered.has(k) and not ores.has(k))):
				for k in cells:
					covered[k] = true
				boulders[cell] = size
				break

	for d in starts:  # muri di legno, la porta in mezzo al lato che guarda fuori
		var mid: Vector2i = MAP_SIZE / 2 + d * 8
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var k := mid + Vector2i(dx, dy)
				if k == mid + d * 3:
					built[k] = [Build.DOOR, Res.WOOD]
				elif maxi(absi(dx), absi(dy)) == 3:
					built[k] = [Build.WALL, Res.WOOD]
					astar.set_point_solid(k)
	update_rooms()
	wild.seed = noise.seed + 3
	for kind in BEASTS:
		for i in BEASTS[kind]["start"]:
			spawn_animal(kind)
	if start_rooms:  # ponytail: scorta di debug, da togliere (o DEBUG_STASH a 0) quando si gioca sul serio
		var first: Vector2i = MAP_SIZE / 2 + START_ROOMS[0] * 8
		for res in STASH:  # un mucchio per risorsa lungo la riga di mezzo, il resto si allarga accanto
			drop(res, first + Vector2i(res - 2, 0), DEBUG_STASH)
		drop(Res.GOLD, first + Vector2i(0, 1), START_GOLD)
		rooms.filter(func(r): return r.cells.has(first))[0].kind = RoomKind.WAREHOUSE
		update_stockpile()
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
	stored_label.text = str(Res.values().map(stored).reduce(func(a, b): return a + b, 0))
	colonists_label.text = str(colonists.size())
	beds_label.text = str(furniture.values().filter(func(plan): return plan[0] == Build.BED).size())  # solo quelli finiti
	splendor_label.text = str(colony_splendor())
	confirm.disabled = draft.is_empty() and furniture_draft.is_empty()
	if jobs_panel.visible:
		jobs_list.text = job_list()
	if resources_panel.visible:
		update_resources()
	if $HUD/BoardPanel.visible:
		fill_board()
	if $HUD/ChroniclePanel.visible and $HUD/ChroniclePanel/Box/Scroll/Text.get_meta("pages", -1) != chronicle.size():
		fill_chronicle()
	if get_viewport().gui_get_hovered_control():  # mouse sull'interfaccia: niente suggerimento
		object_sheet.hide()
	else:
		show_tip(cell_of(get_global_mouse_position()))
	if room_popup.visible:  # mobili finiti mentre è aperto; stanza abbattuta: si chiude
		if editing in rooms:
			refresh_room()
		else:
			room_popup.hide()
	if sheet_panel.visible:
		update_need_bars(sheet_needs, shown)
		update_conds($HUD/ColonistSheet/Box, shown)
		update_gear($HUD/ColonistSheet/Box, shown)
		$HUD/ColonistSheet/Box/Health.text = health_text(shown)
		update_routine_row($HUD/ColonistSheet/Box/Routine, shown)
	var t := fmod(clock, 1.0)
	var wolves := animals.filter(hostile).size()
	info_label.text = ("WOLVES: %d    " % wolves if wolves > 0 else "") \
		+ ("EXPEDITION: %d    " % expeditions.size() if not expeditions.is_empty() else "") + "Day %d  %02d:%02d    Order: %s    Speed: %dx  (Space = pause, 1-3)" \
		% [int(clock) + 1, int(t * 24), int(t * 1440) % 60, Order.keys()[order].capitalize(), Engine.time_scale]
	sky.color = sky_colors.sample(t)
	var shade := SHADOW_ALPHA * clampf(sun_height() * 4, 0, 1)  # sfuma all'alba e al tramonto, zero di notte
	shadows.self_modulate = Color(0, 0, 0, shade)
	shadows.visible = shade > 0
	queue_redraw()
	flat.queue_redraw()
	casters.queue_redraw()
	lights_canvas.queue_redraw()
	if lens.visible:
		lens_canvas.queue_redraw()
		place_owners()


func tick(delta: float) -> void:
	clock += delta / DAY_LENGTH
	spoil(delta / DAY_LENGTH)
	for c in people():
		if c.died == 0.0:  # morto durante il giro
			update_colonist(c, delta)
	update_guests()
	update_expeditions()
	for c in corpses.duplicate():
		if clock >= c.died + CORPSE_DAYS:
			corpses.erase(c)
	for a in animals.duplicate():  # un cacciatore può abbatterne uno durante il giro
		update_animal(a, delta)
	if clock >= next_animal:
		next_animal = clock + ANIMAL_RESPAWN
		if animals.size() < ANIMALS_MAX:
			var prey := BEASTS.keys().filter(func(k): return not BEASTS[k].get("hostile", false))
			spawn_animal(prey[wild.randi() % prey.size()])
	if threats and clock >= next_pack:
		next_pack = clock + WOLF_EVERY
		spawn_pack()


func update_colonist(c: Colonist, delta: float) -> void:
	update_needs(c, delta)
	if c.downed:  # a terra: si cura piano (vedi update_needs), poi si rialza
		c.downed = c.hp < GET_UP
		return
	if react(c):
		return
	if routines:
		update_routine(c, delta)
	c.idle = c.idle + delta if c.job in [Job.NONE, Job.RELAX, Job.TANTRUM] and c.path.is_empty() else 0.0
	if c.idle > LOOK_TIME and randf() < delta / LOOK_TIME:  # si guarda attorno, a caso: niente coloni sincronizzati
		c.facing = Facing.values().pick_random()
	if c.job in [Job.HUNT, Job.FIGHT]:
		track_prey(c)
	if not c.path.is_empty():  # anche senza lavoro: chi è libero può dover uscire da una stanza che si chiude
		var goal := center(c.path[0])
		var d := goal - c.pos
		face(c, d)
		c.walked += minf(d.length(), SPEED * TILE * delta)
		c.pos = c.pos.move_toward(goal, SPEED * TILE * delta)
		if c.pos == goal:
			c.path.pop_front()
		return
	if c.job == Job.NONE:  # chi non ha trovato niente riprova ogni LOOK_AGAIN secondi, non a ogni tick
		c.look_again -= delta
		if c.look_again <= 0:
			find_job(c)
			if c.job == Job.NONE and c.path.is_empty():
				c.look_again = LOOK_AGAIN
		return
	match c.job:
		Job.CHOP, Job.MINE, Job.HARVEST, Job.FISH:  # raccolta, vedi GATHER: un colpo ogni gather_time, il raccolto cade ai piedi
			var cells := work_cells(c.job, c.target)
			sort_by_distance(cells, c.pos)
			face(c, center(cells[0]) - c.pos)  # verso il bersaglio, così il colpo va a segno
			c.work_left -= delta
			if c.work_left > 0:
				return
			var gather: Array = GATHER[c.job]
			var res: Res = ores.get(c.target, gather[3])
			var left: int = stock.get(c.target, full_stock(c.target))
			var got := mini(left, gather[2])
			if c.job == Job.FISH:
				c.xp[Skill.FISHING] += 1  # la pesca a lancio, anche a vuoto; il resto della raccolta a raccolta finita
				if randf() >= catch_chance(c.skills[Skill.FISHING]):
					got = 0  # niente all'amo: si rilancia
			stock[c.target] = left - got
			var here := cell_of(c.pos)
			drop(res, here, got)
			if left > got:
				c.work_left = gather_time(c, c.job)  # colpo successivo
				c.work_total = c.work_left
				return
			stock.erase(c.target)
			if c.job != Job.FISH:
				c.xp[gather[0]] += 1  # raccolta finita
			match c.job:  # finito: albero e masso spariscono, il cespuglio rifà le bacche
				Job.CHOP:
					trees.erase(c.target)
					chop_marks.erase(c.target)
				Job.MINE:
					for cell in cells:
						rocks.erase(cell)
						astar.set_point_solid(cell, false)
					boulders.erase(c.target)
					ores.erase(c.target)
					mine_marks.erase(c.target)
					update_rooms()  # la roccia poteva chiudere una stanza
				Job.HARVEST:
					bushes[c.target] = clock + BERRY_REGROW
				Job.FISH:
					fish_spots[c.target] = clock + FISH_REGROW
			end_job(c)
			try_haul(c, res, [here])  # porta subito via quello che ha prodotto
		Job.UPROOT:
			face(c, center(c.target) - c.pos)
			c.work_left -= delta
			if c.work_left <= 0:
				bushes.erase(c.target)
				weeds.erase(c.target)
				uproot_marks.erase(c.target)
				harvest_marks.erase(c.target)
				end_job(c)
		Job.HAUL:
			var ground: Dictionary = items[c.carry_res]
			if c.target != c.dest:  # arrivato al mucchio: carica
				var to_dest := path_to_nearest(c, [c.dest])
				if to_dest.is_empty() or not ground.has(c.target):  # o il mucchio è marcito per strada
					end_job(c)  # posto occupato o irraggiungibile: riprova più tardi, intanto fa altro
					return
				var space: int = STACK_MAX[c.carry_res] - ground.get(c.dest, 0)
				pick_up(c, c.carry_res, c.target, mini(mini(ground[c.target], CARRY_MAX), space))
				reserved.erase(c.target)
				c.target = c.dest
				c.path = to_dest
			else:                   # arrivato nel magazzino: scarica
				add_item(c.carry_res, c.dest, c.carrying, c.carry_days)
				c.carrying = 0
				end_job(c)
		Job.BUILD, Job.FURNISH:
			var plans := plans_of(c.job)
			var plan: Array = plans[c.target]
			if c.carrying == 0:     # arrivato al mucchio (a terra o in magazzino): prende il materiale e va al cantiere
				var here := cell_of(c.pos)
				var cost: int = BUILD_COST[plan[0]]
				if items[plan[1]].get(here, 0) < cost:
					end_job(c)
					return
				add_item(plan[1], here, -cost)
				reserved.erase(here)
				c.carrying = cost
				c.path = path_of(c, here, c.dest)
				if c.path.is_empty():  # cantiere in una stanza dove nel frattempo non entra più: rimette giù il materiale
					quit_job(c)
				return
			var cells := cells_in(piece_rect(c.target, plan))
			sort_by_distance(cells, c.pos)
			face(c, center(cells[0]) - c.pos)  # verso la casella più vicina: un mobile può prenderne più di una
			c.work_left = maxf(c.work_left - delta, 0.0)
			if c.work_left == 0 and (plan[0] != Build.WALL or ready_to_close(c)):
				if c.job == Job.BUILD:
					build(c.target)
				else:
					furniture[c.target] = plan
					plans.erase(c.target)
				c.carrying = 0
				c.xp[Skill.CONSTRUCTION] += 1
				end_job(c)
		Job.SLEEP:  # a letto o per terra (vedi update_needs): nelle ore di sonno resta giù anche riposato, poi si alza
			# appena ha riposato abbastanza (senza routine solo del tutto). Chi ha dormito poco recupera nelle ore dopo
			if c.needs[Need.REST] >= (RISE if routines else NEED_MAX) and not (routines and activity(c) == Act.SLEEP):
				end_job(c)
		Job.EAT:  # al mucchio ne prende uno (carry_res) e lo mangia a una sedia accanto a un tavolo, se ce n'è una vicina; se no lì
			if c.carrying == 0:
				if not items[c.carry_res].has(c.target):  # mangiato da altri o marcito
					end_job(c)
					return
				pick_up(c, c.carry_res, c.target, 1)
				reserved.erase(c.target)
				var near := seats().filter(func(s): return is_free(s) and center(s).distance_to(c.pos) <= SEAT_RANGE * TILE)
				var to_seat := path_to_nearest(c, near)
				if not to_seat.is_empty():
					c.target = to_seat.back()
					reserved[c.target] = c
					c.path = to_seat
					return
			eat(c)
			end_job(c)
		Job.EQUIP:  # al mucchio: prende il pezzo (carry_res) e lo indossa
			if items[c.carry_res].has(c.target):
				add_item(c.carry_res, c.target, -1)
				c.gear[GEAR[c.carry_res]["slot"]] = c.carry_res
			end_job(c)
		Job.CRAFT:
			craft(c, delta)
		Job.HUNT:  # a tiro (vedi track_prey): mira e tira; colpito o mancato l'animale scappa, abbattuto lascia la carne
			var a: Animal = c.prey
			var dist := c.pos.distance_to(a.pos) / TILE
			if dist > hunt_range(c):  # scappato: lo insegue di nuovo
				chase(c)
				c.work_left = c.work_total
				return
			face(c, a.pos - c.pos)
			c.work_left -= delta
			if c.work_left > 0:
				return
			c.xp[Skill.HUNTING] += 1
			if has_bow(c):
				c.xp[Skill.RANGED] += 1
			c.work_left = c.work_total
			if randf() < hit_chance(hunt_level(c), dist) + gear_sum(c, "hit"):
				wound(a, GEAR[Res.BOW]["shot"] if has_bow(c) else SHOT_DAMAGE, c)
			else:
				startle(a, c)
		Job.FIGHT:  # a portata (vedi track_prey): con l'arco tira, se no colpisce con quello che ha in mano
			var foe: Animal = c.prey
			var dist := c.pos.distance_to(foe.pos) / TILE
			if dist > reach(c):  # si è allontanato: lo insegue
				chase(c)
				c.work_left = c.work_total
				return
			face(c, foe.pos - c.pos)
			c.work_left -= delta
			if c.work_left > 0:
				return
			c.work_left = c.work_total
			if has_bow(c):
				c.xp[Skill.RANGED] += 1
				if randf() < hit_chance(c.skills[Skill.RANGED], dist) + gear_sum(c, "hit"):
					wound(foe, GEAR[Res.BOW]["shot"], c)
			else:
				c.xp[Skill.MELEE] += 1
				if randf() < melee_chance(c.skills[Skill.MELEE]):
					wound(foe, melee_damage(c), c)
		Job.FLEE:  # arrivato al riparo (vedi react)
			end_job(c)
		Job.COOK:  # come BUILD: al mucchio prende il crudo (carry_res), poi al fuoco da campo (target) lo cucina stando in dest
			if furniture.get(c.target, [-1])[0] != Build.CAMPFIRE or not kitchen_fires().has(c.target):
				quit_job(c)  # fuoco abbattuto, o la stanza non è più una cucina: rimette giù il crudo
				return
			if c.carrying == 0:
				var here := cell_of(c.pos)
				if items[c.carry_res].get(here, 0) < COOK_RAW:
					end_job(c)
					return
				pick_up(c, c.carry_res, here, COOK_RAW)
				reserved.erase(here)
				c.path = path_of(c, here, c.dest)
				if c.path.is_empty():
					quit_job(c)
				return
			face(c, center(c.target) - c.pos)
			c.work_left = maxf(c.work_left - delta, 0.0)
			if c.work_left == 0:
				c.carrying = 0
				c.xp[Skill.COOKING] += 1
				var comfort := room_comfort(room_at(c.target))
				var roll := randf()
				var here := cell_of(c.pos)
				end_job(c)
				if roll >= burn_chance(c.skills[Skill.COOKING], comfort):  # bruciato: il crudo è perso, niente pasto
					var meal: Res = Res.FINE_MEAL if roll >= 1.0 - fine_chance(c.skills[Skill.COOKING], comfort) else Res.MEAL
					drop(meal, here, 1)
					try_haul(c, meal, [here])  # lo porta subito in magazzino
		Job.RELAX, Job.TANTRUM:  # arrivato al fuoco, in fondo alla passeggiata o a sbollire: resta lì finché non è ora
			c.work_left -= delta
			if c.work_left <= 0:
				end_job(c)
		Job.TRAVEL:  # avventuriero arrivato alla locanda o al bordo della mappa
			arrive(c)


# La giornata di `c` secondo la sua routine: conta le ore lavorate (la giornata comincia quando si alza, vedi
# wake_hour) e quelle di fila. Chi lavora quando non dovrebbe (fuori orario, ore finite, in pausa) molla il lavoro
# appena ha le mani libere; allo scoccare di ogni ora anche per un bisogno urgente che si può soddisfare.
func update_routine(c: Colonist, delta: float) -> void:
	var workday := floori(clock - wake_hour(routine_of(c)) / 24.0)
	if workday != c.workday:
		c.workday = workday
		c.worked = 0.0
	var hours := delta / DAY_LENGTH * 24
	if c.job in WORK_JOBS:
		c.worked += hours
		c.streak += hours
	elif c.job != Job.NONE:  # a letto, a tavola o a svagarsi; NONE dura un attimo tra un lavoro e l'altro
		c.streak = 0.0
	if c.streak >= fx(c, "streak", INF):  # l'irrequieto si prende una pausa
		c.streak = 0.0
		c.pause_until = clock + RELAX_HOURS / 24
	var now := hour_now()
	var new_hour := now != c.hour
	c.hour = now
	if c.job in WORK_JOBS and c.carrying == 0 and (not may_work(c) or (new_hour and urgent(c))):
		quit_job(c)


# può prendere un lavoro? Nelle ore di lavoro della sua routine, se non ha già fatto le sue ore e non è in pausa
func may_work(c: Colonist) -> bool:
	return not routines or (activity(c) == Act.WORK and c.worked < fx(c, "work", WORK_HOURS) and clock >= c.pause_until)


# Bisogno urgente da soddisfare anche nelle ore di lavoro: fame se c'è da mangiare, sonno se c'è un letto libero, noia.
# Solo controlli veloci, niente percorsi: se poi non ci arriva, find_job gli ridà un lavoro e riprova all'ora dopo
func urgent(c: Colonist) -> bool:
	return (c.needs[Need.FOOD] < NEED_LOW and (MEALS + RAW_FOOD).any(func(r): return not items[r].is_empty())) \
		or (c.needs[Need.REST] < NEED_LOW and not free_beds(c).is_empty()) or c.needs[Need.FUN] < NEED_LOW


func hour_now() -> int:
	return int(fmod(clock, 1.0) * 24)


# cosa dice la routine di `c` per quest'ora: Act
func activity(c: Colonist) -> int:
	return routine_of(c)[hour_now()]


# Routine di `c`, un Act per ora da mezzanotte: ROUTINE con le ore cambiate dai talenti, poi spostata come dicono
# i talenti; chi fa gli straordinari lavora anche nel tempo libero.
# ponytail: si rifà a ogni domanda (più volte per tick): tenerla nel colono se i coloni diventano tanti
func routine_of(c: Colonist) -> Array:
	var letters := []
	for h in 24:
		letters.append(ROUTINE[h])
	for t in c.traits:
		var changed: Dictionary = TRAIT_FX[t].get("hours", {})
		for h in changed:
			letters[h] = changed[h]
	var shift: int = fx(c, "shift", 0)
	var overtime: bool = fx(c, "overtime", false)
	var day := []
	for h in 24:
		var act := ROUTINE_LETTERS.find(letters[posmod(h - shift, 24)])
		day.append(Act.WORK if overtime and act == Act.FREE else act)
	return day


# Ora in cui si finisce il sonno più lungo della routine `day` (non la pennichella): lì comincia la giornata
func wake_hour(day: Array) -> int:
	var wake := 0
	var longest := 0
	for h in 24:
		if day[h] == Act.SLEEP or day[h - 1] != Act.SLEEP:  # day[-1]: le 23
			continue
		var length := 1
		while length < 24 and day[h - 1 - length] == Act.SLEEP:
			length += 1
		if length > longest:
			wake = h
			longest = length
	return wake


# Effetto `key` dei talenti di `c` (vedi TRAIT_FX), `base` se nessuno dei suoi ce l'ha: i ritmi (FX_RATES) si
# moltiplicano, per il resto vale l'ultimo talento che lo cambia
func fx(c: Colonist, key: String, base: Variant) -> Variant:
	var value = base
	for t in c.traits:
		if TRAIT_FX[t].has(key):
			value = value * TRAIT_FX[t][key] if key in FX_RATES else TRAIT_FX[t][key]
	return value


func clash(a: Trait, b: Trait) -> bool:
	return TRAIT_CLASH.any(func(pair): return a in pair and b in pair)


# Bisogni che calano col tempo, ognuno al ritmo cambiato dai talenti (vedi fx). Chi dorme si riposa del tutto in
# SLEEP_TIME, più o meno secondo il comfort di dove dorme (vedi comfort_of: per terra fuori è 0, il 20% in più), e
# il suo comfort va verso quello del posto. Il divertimento sale svagandosi (vedi relax) e scende da svegli.
# Lo stress sale lavorando e scende a riposo. Sotto EXHAUSTED di riposo il colono molla tutto e crolla dove si trova;
# sotto NEED_LOW ci pensa find_job. L'iracondo troppo stressato se ne va a sbollire; il sonnambulo a volte si alza.
# Le condizioni (vedi Cond) finite spariscono; quelle in corso cambiano lo stress da lavoro e la felicità.
# ponytail: il comfort non cambia ancora i lavori; la felicità segue la media degli altri, più le condizioni
func update_needs(c: Colonist, delta: float) -> void:
	var day := delta / DAY_LENGTH * needs_rate
	var before: Array = c.needs.duplicate()
	for k in c.conds.keys():
		if c.conds[k] <= clock:
			c.conds.erase(k)
	var heal := DOWNED_REGEN if c.downed else HP_REGEN * (2.0 if c.job == Job.SLEEP else 1.0)
	c.hp = minf(c.hp + heal * day, MAX_HP)
	var asleep := c.job == Job.SLEEP and c.path.is_empty()
	c.needs[Need.FOOD] -= FOOD_DROP * fx(c, "food", 1.0) * day
	if asleep:
		var comfort := comfort_of(c)
		var gain: float = NEED_MAX / (SLEEP_TIME * fx(c, "sleep", 1.0)) * day / comfort_time(comfort)
		c.needs[Need.REST] += gain
		c.needs[Need.COMFORT] = move_toward(c.needs[Need.COMFORT], NEED_MAX * comfort / COMFORT_MAX, gain)
	else:
		c.needs[Need.REST] -= REST_DROP * fx(c, "rest", 1.0) * day
	if c.job == Job.RELAX:
		c.needs[Need.FUN] += FUN_GAIN * day
	elif not asleep:
		c.needs[Need.FUN] -= FUN_DROP * fx(c, "fun", 1.0) * day
	if fx(c, "fun", 1.0) == 0:  # non gli serve: sempre a posto
		c.needs[Need.FUN] = NEED_MAX
	if c.job not in [Job.NONE, Job.SLEEP, Job.EAT, Job.RELAX, Job.TANTRUM]:  # lavori, ma anche combattere e scappare
		c.needs[Need.STRESS] += STRESS_WORK * fx(c, "stress", 1.0) * cond_product(c, 2) * outdoor_stress(c) * day
	else:
		c.needs[Need.STRESS] -= STRESS_RELIEF * (TANTRUM_VENT if c.job == Job.TANTRUM else 1.0) * day
	var mood: float = (c.needs[Need.FOOD] + c.needs[Need.REST] + c.needs[Need.FUN] + c.needs[Need.COMFORT]
		+ NEED_MAX - c.needs[Need.STRESS]) / 5.0
	mood = clampf(mood + mood_bonus(c), 0.0, NEED_MAX)
	c.needs[Need.HAPPINESS] = move_toward(c.needs[Need.HAPPINESS], mood, MOOD_SPEED * day)
	c.needs = c.needs.map(func(v): return clampf(v, 0.0, NEED_MAX))
	if day > 0:  # in pausa le frecce restano com'erano; il pasto (vedi EAT) è uno scatto, non conta
		c.trend = Need.values().map(func(n): return signf(c.needs[n] - before[n]))
	if c.needs[Need.REST] <= EXHAUSTED and c.job != Job.SLEEP:
		quit_job(c)
		var here: Array[Vector2i] = []
		start_job(c, Job.SLEEP, here, cell_of(c.pos), 0.0)
	elif c.needs[Need.STRESS] >= fx(c, "tantrum", INF) and c.job not in [Job.SLEEP, Job.TANTRUM]:
		tantrum(c)
	elif asleep and randf() < fx(c, "sleepwalk", 0.0) * day * 24:  # probabilità all'ora
		sleepwalk(c)


# L'iracondo molla tutto e se ne va a passi pesanti poco lontano, a sbollire per TANTRUM_HOURS: niente lavoro
func tantrum(c: Colonist) -> void:
	quit_job(c)
	var path := stroll(c, TANTRUM_REACH)
	start_job(c, Job.TANTRUM, path, path.back() if not path.is_empty() else cell_of(c.pos), 0.0)
	c.work_left = TANTRUM_HOURS * DAY_LENGTH / 24


# Il sonnambulo si alza dormendo, cammina fino a una casella lì vicino e ci continua a dormire (per terra):
# lascia libero il letto
func sleepwalk(c: Colonist) -> void:
	var path := stroll(c, SLEEPWALK_REACH)
	if path.is_empty():
		return
	if reserved.get(c.target) == c:
		reserved.erase(c.target)
	c.target = path.back()
	reserved[c.target] = c
	c.path = path


func in_bed(c: Colonist) -> bool:
	return c.job == Job.SLEEP and not pieces_at(furniture, cell_of(c.pos)).filter(func(o): return furniture[o][0] == Build.BED).is_empty()


# Splendore della colonia: la somma delle decorazioni finite (SPLENDOR), ovunque stiano, e degli avventurieri famosi.
func colony_splendor() -> int:
	return furniture.values().map(func(plan): return SPLENDOR.get(plan[0], 0)).reduce(func(a, b): return a + b, 0) \
		+ guests.reduce(func(n, g): return n + gift(g, "splendor", 0), 0)  # gli avventurieri famosi


# Comfort dove sta il colono: quello della stanza, in proporzione se ha meno di ROOM_SPACE caselle a testa; fuori 0.
# ponytail: "a testa" conta chi è nella stanza in quel momento, sveglio o no
func comfort_of(c: Colonist) -> int:
	var here := cell_of(c.pos)
	for room in rooms:
		if room.cells.has(here):
			var people := colonists.filter(func(o): return room.cells.has(cell_of(o.pos))).size()
			return floori(room_comfort(room) * minf(1.0, float(room.cells.size()) / people / ROOM_SPACE))
	return 0


# 0-COMFORT_MAX: i mobili dentro la stanza, per pezzo, e il pavimento, per la parte di stanza che copre; per materiale
# ponytail: scorre mobili e caselle a ogni domanda (anche per ogni colono che dorme, a ogni tick); tenerlo nella Room
# e ricalcolarlo quando cambiano mobili o pavimenti se le stanze diventano tante
func room_comfort(room: Room) -> int:
	var sum := 0.0
	for origin in furniture:
		if room.cells.has(origin):
			sum += COMFORT.get(furniture[origin][0], 0.0) * COMFORT_MATERIAL.get(furniture[origin][1], 1.0)
	for cell in room.cells:
		if built.get(cell, [-1])[0] == Build.FLOOR:
			sum += COMFORT[Build.FLOOR] * COMFORT_MATERIAL.get(built[cell][1], 1.0) / room.cells.size()
	return mini(floori(sum + 0.001), COMFORT_MAX)  # + 0.001: tre terzi di pavimento fanno 1, non 0.999


# Quanto tempo richiede un'attività col comfort `comfort`, rispetto al normale: 1 a metà, 1 ± COMFORT_EFFECT agli estremi.
# Vale per il sonno e per cucinare (dove sotto metà fa anche bruciare i pasti, vedi burn_chance).
# ponytail: con la forgia allungherà anche quel lavoro
func comfort_time(comfort: int) -> float:
	var mid := COMFORT_MAX / 2.0
	return 1.0 + COMFORT_EFFECT * (mid - comfort) / mid


# la stanza ha i mobili che servono per il tipo `kind`? (vedi ROOM_NEEDS; i tipi senza requisiti sì)
func room_meets(room: Room, kind: RoomKind) -> bool:
	var needs: Dictionary = ROOM_NEEDS.get(kind, {})
	var inside: Array = furniture.keys().filter(func(o): return room.cells.has(o)).map(func(o): return furniture[o][0])
	return needs.keys().all(func(b): return inside.count(b) >= needs[b])


# Il prossimo lavoro di `c`, secondo i bisogni e la sua routine (vedi routine_of):
# stanco cerca un letto libero (se non c'è lavora finché crolla); affamato va a mangiare, nel tempo libero anche solo
# per uno spuntino (vedi SNACK); nelle ore di sonno va a letto, e se non ce n'è uno libero dorme per terra dove si
# trova; annoiato si svaga anche nelle ore di lavoro. Poi lavora, se può (vedi may_work); se no si svaga, e se non
# c'è niente da fare resta fermo
func find_job(c: Colonist) -> void:
	var act: int = activity(c) if routines else Act.WORK
	if c.needs[Need.REST] < NEED_LOW and go_to_bed(c):
		return
	if c.errand != Errand.NONE:  # avventuriero per strada, interrotto: riprende la strada
		travel(c)
		return
	var peckish: bool = act == Act.FREE and c.needs[Need.FOOD] < fx(c, "snack", SNACK)
	if c.needs[Need.FOOD] < (GLUTTON_HUNGER if Trait.GLUTTON in c.traits else NEED_LOW) or peckish:
		for res in MEALS + RAW_FOOD:  # prima i pasti, il crudo solo se non ce ne sono
			var to_food := path_to_nearest(c, items[res].keys().filter(func(cell): return is_free(cell)))
			if not to_food.is_empty():
				start_job(c, Job.EAT, to_food, to_food.back(), 0.0)
				c.carry_res = res
				return
	if act == Act.SLEEP:
		if not go_to_bed(c):
			var stay: Array[Vector2i] = []
			start_job(c, Job.SLEEP, stay, cell_of(c.pos), 0.0)
		return
	if routines and c.needs[Need.FUN] < NEED_LOW:
		relax(c)
		return
	if c.hero != Hero.NONE:  # gli avventurieri non lavorano: aspettano svagandosi
		relax(c)
		return
	if may_work(c):
		if find_work(c):
			return
	elif routines:  # tempo libero, ore di lavoro già fatte o in pausa
		relax(c)
		return

	var here := cell_of(c.pos)
	if stockpile.has(here):  # senza lavoro dentro il magazzino: si fa da parte, se no blocca chi scarica
		var aside := []
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var s: Vector2i = here + Vector2i(dx, dy)
				if astar.is_in_boundsv(s) and not astar.is_point_solid(s) and not trees.has(s) and not stockpile.has(s):
					aside.append(s)
		c.path = path_to_nearest(c, aside)


# va a dormire nel letto libero più vicino dove può arrivare; false se non ce n'è
func go_to_bed(c: Colonist) -> bool:
	var to_bed := path_to_nearest(c, free_beds(c))
	if to_bed.is_empty():
		return false
	start_job(c, Job.SLEEP, to_bed, to_bed.back(), 0.0)
	return true


# Svago per `hours` ore: attorno a un fuoco da campo, se ce n'è uno dove può arrivare, se no a passeggio lì vicino.
# Il divertimento sale (vedi update_needs); finito, find_job decide di nuovo
func relax(c: Colonist, hours := RELAX_HOURS) -> void:
	var around_fire := []
	for origin in furniture:
		if furniture[origin][0] == Build.CAMPFIRE:
			for d in EDGE_SIDES + EDGE_CORNERS:
				var k: Vector2i = origin + d
				if astar.is_in_boundsv(k) and not astar.is_point_solid(k) and not stockpile.has(k):
					around_fire.append(k)
	var path := path_to_nearest(c, around_fire)
	if path.is_empty():
		path = stroll(c, RELAX_REACH)
	start_job(c, Job.RELAX, path, path.back() if not path.is_empty() else cell_of(c.pos), 0.0)
	c.work_left = hours * DAY_LENGTH / 24


# Percorso di `c` verso una casella a caso entro `reach` caselle, sul prato (niente alberi, acqua, magazzino), dove
# nessun altro si ferma e dove lui entra; [] se non ne trova una a portata di passi
func stroll(c: Colonist, reach: int) -> Array[Vector2i]:
	var here := cell_of(c.pos)
	var taken := claimed(c)
	taken.merge(closed_cells(c))
	var spots := []
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var s: Vector2i = here + Vector2i(dx, dy)
			if s != here and astar.is_in_boundsv(s) and not astar.is_point_solid(s) and not water.has(s) \
					and not trees.has(s) and not stockpile.has(s) and not taken.has(s):
				spots.append(s)
	spots.shuffle()
	for spot in spots.slice(0, 3):  # poche prove: ogni percorso costa
		var path := path_of(c, here, spot)
		if not path.is_empty() and path.size() <= reach * 2:  # non un giro lunghissimo attorno a un muro
			return path
	var none: Array[Vector2i] = []
	return none


# Avvia il lavoro libero più vicino, in ordine fisso finché non c'è la tabella delle priorità: prendere
# l'equipaggiamento, cucinare, forgiare e cucire, tagliare, scavare, estirpare, raccogliere, pescare, cacciare,
# costruire, trasportare. false se non ce n'è
func find_work(c: Colonist) -> bool:
	if try_equip(c) or try_cook(c) or try_craft(c) or try_work(c, Job.CHOP, chop_marks.keys(), TREE_SIDES, gather_time(c, Job.CHOP)) \
			or try_work(c, Job.MINE, mine_marks.keys(), SIDES, gather_time(c, Job.MINE)) \
			or try_work(c, Job.UPROOT, uproot_marks.keys(), SIDES, UPROOT_TIME * work_factor(c, Job.UPROOT)) \
			or try_work(c, Job.HARVEST, harvest_ready(), SIDES, gather_time(c, Job.HARVEST)) \
			or try_work(c, Job.FISH, fishable(), SIDES, gather_time(c, Job.FISH)) or try_hunt(c):
		return true

	for job in [Job.BUILD, Job.FURNISH]:  # prima le strutture, poi i mobili
		var plans := plans_of(job)
		var stands := {}  # casella libera accanto a un progetto per cui c'è un mucchio di materiale -> progetto
		for cell in plans:
			if is_free(cell) and not sources(plans[cell]).is_empty():
				add_stands(stands, cells_in(piece_rect(cell, plans[cell])), cell, SIDES)
		var path := path_to_nearest(c, stands.keys())
		var to_source := [] if path.is_empty() else path_to_nearest(c, sources(plans[stands[path.back()]]))
		if not to_source.is_empty():  # prima al mucchio a prendere il materiale, poi al cantiere
			start_job(c, job, to_source, stands[path.back()], BUILD_TIME * skill_time(c.skills[Skill.CONSTRUCTION]) * work_factor(c, job))
			c.dest = path.back()
			c.carry_res = plans[c.target][1]
			reserved[to_source.back()] = c  # intanto nessun altro prende da quel mucchio
			return true

	for res in Res.values():
		if try_haul(c, res, items[res].keys().filter(func(cell): return not stockpile.has(cell) and is_free(cell))):
			return true
	return false


# Lavoro a tempo `job` (tagliare, scavare, estirpare, raccogliere) sul bersaglio libero più vicino tra `targets`,
# stando su una casella libera accanto a uno dei lati `sides`; `time` per colpo. false se non ce n'è.
func try_work(c: Colonist, job: Job, targets: Array, sides: Array, time: float) -> bool:
	var stands := {}  # casella libera accanto a un bersaglio -> bersaglio (per i massi, la cella d'origine)
	for t in targets:
		if is_free(t):
			add_stands(stands, work_cells(job, t), t, sides)
	var path := path_to_nearest(c, stands.keys())
	if path.is_empty():
		return false
	var target: Vector2i = stands[path.back()]
	start_job(c, job, path, target, time)
	return true


func work_cells(job: Job, target: Vector2i) -> Array:
	return boulder_cells(target) if job == Job.MINE else [target]


# secondi per colpo di `c` nel lavoro di raccolta `job`: quelli di GATHER a livello 5, 1.5 volte tanto a livello 0,
# la metà a livello 10; più o meno secondo le condizioni (vedi work_factor)
func gather_time(c: Colonist, job: Job) -> float:
	return GATHER[job][1] * skill_time(c.skills[GATHER[job][0]]) * work_factor(c, job)


# tempo di un lavoro a livello `level` rispetto al livello 5: 1.4 a livello 1, la metà a livello 10
func skill_time(level: int) -> float:
	return 1.5 - level / 10.0


# quanto tempo richiede il lavoro `job` a `c` per le sue condizioni (meno se ben nutrito, di più se intossicato) e per
# quello che ha addosso (vedi GEAR: "time" per quel lavoro, "slow" per tutti)
func work_factor(c: Colonist, job := Job.NONE) -> float:
	var f := cond_product(c, 1)
	for g in c.gear.values():
		f *= GEAR[g].get("time", {}).get(job, 1.0) * GEAR[g].get("slow", 1.0)
	return f


# stress da lavoro x fuori dalle stanze, per quello che `c` ha addosso (vedi GEAR "outdoor_stress"); dentro 1
func outdoor_stress(c: Colonist) -> float:
	var f := 1.0
	if room_at(cell_of(c.pos)) == null:
		for g in c.gear.values():
			f *= GEAR[g].get("outdoor_stress", 1.0)
	return f


# somma di `key` per quello che `c` ha addosso (es. "armor", "hit", "range")
func gear_sum(c: Colonist, key: String) -> float:
	var sum := 0.0
	for g in c.gear.values():
		sum += GEAR[g].get(key, 0.0)
	if key == "armor":
		for k in c.kit:
			sum += KIT_ARMOR.get(k, 0)
	return sum


# prodotto della colonna `col` di COND_INFO per le condizioni di `c` (1 tempo di lavoro, 2 stress da lavoro)
func cond_product(c: Colonist, col: int) -> float:
	var f := 1.0
	for k in c.conds:
		f *= COND_INFO[k][col]
	return f


# felicità in più (o in meno) per le condizioni di `c`: quelle del cibo contano il doppio per il goloso
func mood_bonus(c: Colonist) -> float:
	var sum := 0.0
	for k in c.conds:
		sum += COND_INFO[k][3] * (GLUTTON_MOOD if k in FOOD_CONDS and Trait.GLUTTON in c.traits else 1.0)
	return sum


func add_cond(c: Colonist, k: Cond) -> void:
	c.conds[k] = clock + COND_INFO[k][0]


# `c` mangia quello che ha in mano (carry_res): sazia secondo FOOD. Il crudo può intossicare (e il goloso lo mangia
# malvolentieri); un pasto dà il suo bonus, che prende il posto di quello del pasto prima. Seduto al tavolo, un bonus in più
func eat(c: Colonist) -> void:
	var res := c.carry_res
	c.needs[Need.FOOD] = minf(c.needs[Need.FOOD] + FOOD[res], NEED_MAX)
	c.carrying = 0
	if res in RAW_FOOD:
		if randf() < poison_chance(res, c.carry_days):
			add_cond(c, Cond.POISONED)
		if Trait.GLUTTON in c.traits:
			add_cond(c, Cond.ATE_RAW)
	else:
		c.conds.erase(Cond.WELL_FED)
		c.conds.erase(Cond.FEASTED)
		add_cond(c, Cond.FEASTED if res == Res.FINE_MEAL else Cond.WELL_FED)
	if seats().has(cell_of(c.pos)):
		add_cond(c, Cond.AT_TABLE)


# probabilità di intossicarsi mangiando crudo `res` a cui restano `days` giorni prima di marcire
func poison_chance(res: Res, days: float) -> float:
	return lerpf(POISON[res][1], POISON[res][0], clampf(days / SHELF_LIFE[res], 0.0, 1.0))


# sedie accanto a un tavolo (di lato, non in diagonale): lì si mangia meglio
func seats() -> Array:
	var tables := furniture.keys().filter(func(o): return furniture[o][0] == Build.TABLE) \
		.map(func(o): return cells_in(piece_rect(o, furniture[o])))
	return furniture.keys().filter(func(o): return furniture[o][0] == Build.CHAIR \
		and tables.any(func(t): return SIDES.any(func(s): return t.has(o + s))))


# fuochi da campo dentro le stanze di tipo cucina
func kitchen_fires() -> Array:
	var kitchens := rooms.filter(func(r): return r.kind == RoomKind.KITCHEN)
	return furniture.keys().filter(func(o): return furniture[o][0] == Build.CAMPFIRE \
		and kitchens.any(func(r): return r.cells.has(o)))


func room_at(cell: Vector2i) -> Room:
	for room in rooms:
		if room.cells.has(cell):
			return room
	return null


# pasti che mancano perché ce ne siano MEALS_PER_COLONIST a testa: contano quelli a terra, in mano e sul fuoco
func meals_wanted() -> int:
	var have: int = MEALS.reduce(func(sum, r): return sum + total(r), 0)
	have += colonists.filter(func(o): return o.job == Job.COOK).size()
	return maxi(MEALS_PER_COLONIST * colonists.size() - have, 0)


# Cucinare, se mancano pasti: dal mucchio di crudo più vicino con almeno COOK_RAW (a terra o in magazzino)
# a una casella libera accanto a un fuoco da campo libero, dentro la cucina. false se non si può.
# ponytail: la scorta è automatica; quando ci sarà la tabella delle priorità, il cartello della cucina potrà dire quanti
func try_cook(c: Colonist) -> bool:
	if meals_wanted() == 0:
		return false
	var stands := {}  # casella accanto a un fuoco, dentro la sua cucina -> fuoco
	for fire in kitchen_fires().filter(func(f): return is_free(f)):
		var room := room_at(fire)
		var around := {}
		add_stands(around, [fire], fire, SIDES)
		for s in around:
			if room.cells.has(s):
				stands[s] = fire
	var path := path_to_nearest(c, stands.keys())
	if path.is_empty():
		return false
	var raw := {}  # mucchio -> crudo
	for res in RAW_FOOD:
		for cell in items[res]:
			if items[res][cell] >= COOK_RAW and is_free(cell):
				raw[cell] = res
	var to_source := path_to_nearest(c, raw.keys())
	if to_source.is_empty():
		return false
	var fire: Vector2i = stands[path.back()]
	start_job(c, Job.COOK, to_source, fire, cook_time(c, room_comfort(room_at(fire))))
	c.dest = path.back()
	c.carry_res = raw[to_source.back()]
	reserved[to_source.back()] = c  # intanto nessun altro prende da quel mucchio
	return true


# secondi per un pasto: COOK_TIME a livello 5, secondo il comfort della cucina e le condizioni del cuoco
func cook_time(c: Colonist, comfort: int) -> float:
	return COOK_TIME * skill_time(c.skills[Skill.COOKING]) * comfort_time(comfort) * work_factor(c, Job.COOK)


func burn_chance(level: int, comfort: int) -> float:
	return clampf(BURN_PER_LEVEL * (6 - level) + BURN_PER_COMFORT * (5 - comfort), 0.0, 1.0)


func fine_chance(level: int, comfort: int) -> float:
	return clampf(FINE_PER_LEVEL * (level - 5) + FINE_PER_COMFORT * (comfort - 5), 0.0, 1.0)


# --- Equipaggiamento e produzione ---

# l'attrezzo da mani che `c` vuole: quello della sua abilità migliore tra quelle degli attrezzi
func wanted_tool(c: Colonist) -> Res:
	var tools := GEAR.keys().filter(func(g): return GEAR[g]["slot"] == Slot.HANDS)
	var best: Res = tools[0]
	for g in tools:
		if c.skills[GEAR[g]["skill"]] > c.skills[GEAR[best]["skill"]]:
			best = g
	return best


# pezzi che `c` metterebbe nello slot `slot` se lo ha vuoto: nelle mani solo il suo attrezzo, se no tutti quelli dello slot
func fits(c: Colonist, slot: Slot) -> Array:
	if c.gear.has(slot):
		return []
	if slot == Slot.HANDS:
		return [wanted_tool(c)]
	return GEAR.keys().filter(func(g): return GEAR[g]["slot"] == slot)


# Slot vuoto e il pezzo giusto in un mucchio libero: va a prenderlo (Job.EQUIP). false se non c'è niente da mettere
func try_equip(c: Colonist) -> bool:
	for slot in Slot.values():
		for g in fits(c, slot):
			var path := path_to_nearest(c, items[g].keys().filter(func(cell): return is_free(cell)))
			if not path.is_empty():
				start_job(c, Job.EQUIP, path, path.back(), 0.0)
				c.carry_res = g
				return true
	return false


# Quanti `res` mancano. Lingotti: fino a INGOT_STOCK. Equipaggiamento: i coloni con lo slot vuoto che lo prenderebbero
# (per le mani: chi vuole proprio quell'attrezzo; se no tutti), meno quelli già fatti e in lavorazione per lo stesso slot
func gear_wanted(res: Res) -> int:
	var making := func(r): return colonists.filter(func(o): return o.job == Job.CRAFT and RECIPES[o.recipe][0] == r).size()
	if res == Res.INGOT:
		return INGOT_STOCK - total(Res.INGOT) - making.call(Res.INGOT)
	var slot: Slot = GEAR[res]["slot"]
	var same: Array = [res] if slot == Slot.HANDS else GEAR.keys().filter(func(g): return GEAR[g]["slot"] == slot)
	var want := colonists.filter(func(o): return res in fits(o, slot)).size()
	for g in same:
		want -= total(g) + making.call(g)
	return want


# mobili `kind` (fornace, incudine, banco) dentro una stanza del tipo giusto (STATION_ROOM)
func stations(kind: Build) -> Array:
	return furniture.keys().filter(func(o): return furniture[o][0] == kind \
		and room_at(o) != null and room_at(o).kind == STATION_ROOM[kind])


# Produzione: la prima ricetta che serve (vedi gear_wanted), con la postazione libera e tutti gli ingredienti nei mucchi
# liberi. Il colono va a prendere un ingrediente alla volta e lo porta alla postazione (vedi craft). false se niente
func try_craft(c: Colonist) -> bool:
	for i in RECIPES.size():
		var r: Array = RECIPES[i]
		var free_stations := stations(r[1]).filter(func(st): return is_free(st))  # prima il controllo che costa meno
		if free_stations.is_empty() or gear_wanted(r[0]) <= 0 or not r[3].keys().all(func(res): return available(res) >= r[3][res]):
			continue
		var stands := {}  # casella accanto a una postazione libera, nella sua stanza -> postazione
		for station in free_stations:
			var around := {}
			add_stands(around, [station], station, SIDES)
			for s in around:
				if room_at(station).cells.has(s):
					stands[s] = station
		var path := path_to_nearest(c, stands.keys())
		if path.is_empty():
			continue
		var station: Vector2i = stands[path.back()]
		start_job(c, Job.CRAFT, [], station, r[4] * skill_time(c.skills[r[2]]) * comfort_time(room_comfort(room_at(station)))
			* work_factor(c, Job.CRAFT))
		c.recipe = i
		c.dest = path.back()
		c.path = path  # prima alla postazione, poi da lì a prendere gli ingredienti (vedi craft)
		return true
	return false


# quanto `res` c'è nei mucchi liberi
func available(res: Res) -> int:
	var sum := 0
	for cell in items[res]:
		if is_free(cell):
			sum += items[res][cell]
	return sum


# Un passo di Job.CRAFT, a percorso finito. Arrivato a un mucchio: prende quello che manca di quell'ingrediente e torna.
# Alla postazione (dest): posa quello che ha in mano; se manca ancora qualcosa va a prenderlo, se no lavora. Finito,
# l'oggetto cade ai suoi piedi (o è rovinato: ingredienti persi), +1 punto esperienza
func craft(c: Colonist, delta: float) -> void:
	var r: Array = RECIPES[c.recipe]
	if not stations(r[1]).has(c.target):
		quit_job(c)  # postazione abbattuta, o la stanza ha cambiato tipo: lascia giù quello che aveva
		return
	var here := cell_of(c.pos)
	if here != c.dest:  # a un mucchio
		reserved.erase(here)
		var take := mini(mini(items[c.carry_res].get(here, 0), r[3][c.carry_res] - c.fetched.get(c.carry_res, 0)), CARRY_MAX)
		if take <= 0:
			quit_job(c)
			return
		pick_up(c, c.carry_res, here, take)
		c.path = path_of(c, here, c.dest)
		if c.path.is_empty():
			quit_job(c)
		return
	if c.carrying > 0:
		c.fetched[c.carry_res] = c.fetched.get(c.carry_res, 0) + c.carrying
		c.carrying = 0
	for res in r[3]:
		if c.fetched.get(res, 0) < r[3][res]:
			var to := path_to_nearest(c, items[res].keys().filter(func(cell): return cell != c.dest and is_free(cell)))
			if to.is_empty():
				quit_job(c)
				return
			c.carry_res = res
			c.path = to
			reserved[to.back()] = c
			return
	face(c, center(c.target) - c.pos)
	c.work_left = maxf(c.work_left - delta, 0.0)
	if c.work_left > 0:
		return
	c.fetched.clear()
	c.xp[r[2]] += 1
	end_job(c)
	if randf() >= burn_chance(c.skills[r[2]], room_comfort(room_at(c.target))):
		drop(r[0], here, 1)
		try_haul(c, r[0], [here])


# --- Combattimento ---

func hostile(a: Animal) -> bool:
	return BEASTS[a.kind].get("hostile", false)


func has_bow(c: Colonist) -> bool:
	return c.gear.get(Slot.HANDS) == Res.BOW


# caselle da cui colpisce: a caccia o con l'arco quelle di tiro, se no corpo a corpo
func reach(c: Colonist) -> float:
	return hunt_range(c) if c.job == Job.HUNT or has_bow(c) else MELEE_RANGE


func melee_chance(level: int) -> float:
	return clampf(MELEE_BASE + MELEE_PER_LEVEL * (level - 5), 0.05, 0.95)


# danno corpo a corpo: quello dell'attrezzo o dell'arma in mano, se no a mani nude
func melee_damage(c: Colonist) -> float:
	var g = c.gear.get(Slot.HANDS)
	return GEAR[g].get("damage", FIST_DAMAGE) if g != null else FIST_DAMAGE


# quanto danno passa la protezione di `c`: -ARMOR_BLOCK per punto, al massimo -ARMOR_MAX
func armor_factor(c: Colonist) -> float:
	return 1.0 - minf(ARMOR_BLOCK * gear_sum(c, "armor"), ARMOR_MAX)


# secondi tra un colpo e l'altro in combattimento
func attack_time(c: Colonist) -> float:
	if has_bow(c):
		return SHOOT_TIME * skill_time(c.skills[Skill.RANGED]) * work_factor(c, Job.FIGHT)
	return MELEE_TIME * skill_time(c.skills[Skill.MELEE]) * work_factor(c, Job.FIGHT)


# il lupo più vicino a `c` entro ALERT caselle (tranne quelli che per un po' non si raggiungono, vedi chase)
func nearest_foe(c: Colonist) -> Animal:
	var best: Animal = null
	for a in animals:
		if hostile(a) and a.blocked <= clock and a.pos.distance_to(c.pos) <= ALERT * TILE \
				and (best == null or a.pos.distance_squared_to(c.pos) < best.pos.distance_squared_to(c.pos)):
			best = a
	return best


# Un lupo vicino: chi sta bene lascia quello che fa e combatte (Job.FIGHT, contro il più vicino); chi è ferito (sotto
# FLEE_HP) corre nella stanza più vicina dove può entrare (Job.FLEE) e lì aspetta, senza altri lavori, che il pericolo
# passi; se nessuna stanza è raggiungibile combatte. true se oggi non deve fare altro (al riparo, ad aspettare)
func react(c: Colonist) -> bool:
	var foe := nearest_foe(c)
	if foe == null:
		return false
	if c.hp < FLEE_HP:
		if room_at(cell_of(c.pos)) != null:
			if c.job == Job.SLEEP:
				return false  # dorme al sicuro
			if c.job != Job.NONE:
				quit_job(c)
			c.path.clear()
			return true
		if c.job == Job.FLEE:
			return false
		var shut := closed_cells(c)
		var safe := []
		for room in rooms:
			safe.append_array(room.cells.keys().filter(func(k): return not shut.has(k)))
		var path := path_to_nearest(c, safe)
		if not path.is_empty():
			quit_job(c)
			c.job = Job.FLEE
			c.path = path
			return false
	if c.job == Job.FIGHT:
		return false
	quit_job(c)
	c.job = Job.FIGHT
	c.prey = foe
	c.work_total = attack_time(c)
	c.work_left = c.work_total
	chase(c)
	return false


# Colpito: danno all'animale. Abbattuto lascia carne e pelle; se no il lupo se la prende con chi l'ha colpito, gli
# altri scappano
func wound(a: Animal, damage: float, by: Colonist) -> void:
	a.damage += damage
	if a.damage >= BEASTS[a.kind]["hp"]:
		kill(a, by)
	else:
		startle(a, by)


# preso di mira (colpito o mancato): il lupo attacca chi ha tirato, gli altri animali scappano
func startle(a: Animal, by: Colonist) -> void:
	if hostile(a):
		a.target = by
	else:
		flee(a, by.pos)


# abbattuto: carne e pelle a terra; chi lo cacciava o lo combatteva è libero, chi l'ha abbattuto porta la carne in magazzino
func kill(a: Animal, by: Colonist) -> void:
	var spot := cell_of(a.pos)
	animals.erase(a)
	for o in people():
		if o.prey == a:
			end_job(o)
	drop(Res.MEAT, spot, BEASTS[a.kind]["meat"])
	drop(Res.HIDE, spot, BEASTS[a.kind]["hide"])  # accanto: un mucchio per risorsa
	try_haul(by, Res.MEAT, [spot])


# Lupo: insegue il colono (o l'avventuriero) più vicino che vede, fuori dalle stanze e in piedi; se non c'è nessuno
# in piedi, chi è a terra fuori (vedi exposed). A portata lo morde. Senza nessuno da inseguire gira come gli altri
# animali, e dopo WOLF_STAY se ne va. true se il giro di update_animal è finito qui
func update_wolf(a: Animal, delta: float) -> bool:
	a.bite_left = maxf(a.bite_left - delta, 0.0)
	a.repath -= delta
	var standing := people().filter(func(c): return fair_game(a, c))
	if not fair_game(a, a.target) and not (standing.is_empty() and exposed(a, a.target)):
		a.target = null
		var prey: Array = standing if not standing.is_empty() else people().filter(func(c): return exposed(a, c))
		for c in prey:  # in piedi; se non c'è nessuno, chi è a terra
			if a.target == null or c.pos.distance_to(a.pos) < a.target.pos.distance_to(a.pos):
				a.target = c
		a.path.clear()
	var t: Colonist = a.target
	if t == null:
		if clock >= a.leave_at:
			animals.erase(a)
			return true
		return false
	if t.pos.distance_to(a.pos) <= BITE_RANGE * TILE:
		a.path.clear()
		a.left = t.pos.x < a.pos.x
		if a.bite_left == 0.0:
			a.bite_left = BITE_TIME
			bite(a, t)
		return true
	if a.repath <= 0 and (a.path.is_empty() or center(a.path.back()).distance_to(t.pos) > 1.5 * TILE):
		a.repath = 0.5
		a.path = beast_path(cell_of(a.pos), cell_of(t.pos))
	move_animal(a, delta)
	return true


# il lupo `a` può inseguire `c`: in piedi, fuori dalle stanze, entro WOLF_SIGHT
func fair_game(a: Animal, c) -> bool:
	return c != null and (c in colonists or c in guests) and not c.downed and room_at(cell_of(c.pos)) == null \
		and c.pos.distance_to(a.pos) <= WOLF_SIGHT * TILE


# Morso: a segno secondo la mischia di chi è morso; il danno lo riduce la protezione. Fa salire lo stress; a 0 punti
# ferita il colono resta a terra e lascia il lavoro, o muore (vedi death_chance). Chi è già a terra non si difende:
# il morso lo uccide
func bite(a: Animal, c: Colonist) -> void:
	if c.downed:
		a.target = null
		die(c, "was killed by wolves.")
		return
	if randf() >= BITE_HIT - DODGE_PER_LEVEL * c.skills[Skill.MELEE]:
		return
	c.hp -= BEASTS[a.kind]["bite"] * armor_factor(c)
	c.needs[Need.STRESS] = minf(c.needs[Need.STRESS] + HIT_STRESS, NEED_MAX)
	if c.hp <= 0:
		c.hp = 0.0
		a.target = null
		if deaths and randf() < death_chance(c):
			die(c, "was killed by wolves.")
			return
		c.downed = true
		quit_job(c)


# percorso di un animale che non passa dalle stanze: per la ricerca le si riempie come fossero muro
func beast_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var shut := []
	for room in rooms:
		shut.append_array(room.cells.keys().filter(func(k): return not astar.is_point_solid(k)))
	for k in shut:
		astar.set_point_solid(k)
	var path := astar.get_id_path(from, to) if not astar.is_point_solid(from) and not astar.is_point_solid(to) else ([] as Array[Vector2i])
	for k in shut:
		astar.set_point_solid(k, false)
	return path


# Un branco di lupi entra da un bordo della mappa, a caso; se ne va dopo WOLF_STAY se non trova nessuno
func spawn_pack() -> void:
	for attempt in 50:
		var t := wild.randi() % MAP_SIZE.x
		var cell: Vector2i = [Vector2i(t, 0), Vector2i(t, MAP_SIZE.y - 1), Vector2i(0, t), Vector2i(MAP_SIZE.x - 1, t)][wild.randi() % 4]
		if not roams(cell):
			continue
		for i in wild.randi_range(PACK[0], PACK[1]):
			var near := cell + Vector2i(wild.randi_range(-2, 2), wild.randi_range(-2, 2))
			var a := add_animal(Beast.WOLF, near if roams(near) else cell)
			a.leave_at = clock + WOLF_STAY
		return


# --- Morte ---

# probabilità che il colpo che butta a terra `c` lo uccida: meno con più protezione
func death_chance(c: Colonist) -> float:
	return maxf(DEATH_BASE - DEATH_PER_ARMOR * gear_sum(c, "armor"), DEATH_MIN)


# `c` muore: lascia a terra quello che porta, l'equipaggiamento e il bottino; il corpo resta CORPSE_DAYS. Se era un
# colono gli altri prendono il lutto; morti tutti, la colonia è caduta
func die(c: Colonist, why: String) -> void:
	quit_job(c)
	var here := cell_of(c.pos)
	for g in c.gear.values():
		drop(g, here, 1)
	for res in c.loot:
		drop(res, here, c.loot[res])
	c.gear.clear()
	c.loot.clear()
	c.downed = true
	c.hp = 0.0
	c.died = clock
	corpses.append(c)
	var was_colonist := c in colonists
	colonists.erase(c)
	guests.erase(c)
	for room in rooms:
		room.owners.erase(c)
		room.workers.erase(c)
	for a in animals:
		if a.target == c:
			a.target = null
	for exp in expeditions.duplicate():  # ingaggiato e morto prima di partire: gli altri partono senza di lui
		if exp.left_at < 0 and c in exp.party:
			exp.party.erase(c)
			if exp.party.is_empty():
				expeditions.erase(exp)
			else:
				leave_if_ready(exp)
	if was_colonist:
		for o in colonists:
			add_cond(o, Cond.MOURNING)
	if shown == c:
		sheet_panel.hide()
	note("Day %d: %s %s" % [int(clock) + 1, full_name(c), why])
	if was_colonist and colonists.is_empty():
		fallen = true
		$HUD/Fallen.show()


# il lupo `a` può finire `c`: a terra, fuori dalle stanze, entro WOLF_SIGHT (solo se nessuno è in piedi, vedi update_wolf)
func exposed(a: Animal, c) -> bool:
	return deaths and c != null and (c in colonists or c in guests) and c.downed and room_at(cell_of(c.pos)) == null \
		and c.pos.distance_to(a.pos) <= WOLF_SIGHT * TILE


# --- Avventurieri (vedi HEROES) ---

# coloni e avventurieri sulla mappa
func people() -> Array[Colonist]:
	var all: Array[Colonist] = colonists.duplicate()
	all.append_array(guests)
	return all


func is_inn(room: Room) -> bool:
	return room != null and room.kind == RoomKind.INN


# letti liberi per `c`: agli avventurieri quelli della locanda, ai coloni tutti gli altri
func free_beds(c: Colonist) -> Array:
	return furniture.keys().filter(func(o): return furniture[o][0] == Build.BED and is_free(o) \
		and is_inn(room_at(o)) == (c.hero != Hero.NONE))


func inn_beds() -> int:
	return furniture.keys().filter(func(o): return furniture[o][0] == Build.BED and is_inn(room_at(o))).size()


# avventuriero `kind` di livello `level`, col suo nome, aspetto, abilità ed equipaggiamento
func new_hero(kind: Hero, level: int) -> Colonist:
	var c := Colonist.new()
	dress(c)
	var data: Dictionary = HEROES[kind]
	c.hero = kind
	c.tunic = data["tunic"]
	c.cape = data["cape"]
	c.hood_tint = data.get("hood")
	c.kit = data["kit"].duplicate()
	c.skills = Skill.values().map(func(_s): return 0)
	c.xp = Skill.values().map(func(_s): return 0)
	c.needs = Need.values().map(func(n): return 0.0 if n == Need.STRESS else NEED_MAX * 0.8)
	c.trend = c.needs.map(func(_v): return 0.0)
	c.gifts = [Gift.values().pick_random()]
	if randf() < HERO_TRAIT_CHANCE:
		c.traits = [Trait.values().pick_random()]
	set_level(c, level)
	return c


# livello di `c`: abilità della classe e, dal livello HEAVY_LEVEL, l'armatura pesante
func set_level(c: Colonist, level: int) -> void:
	var data: Dictionary = HEROES[c.hero]
	c.level = level
	for skill in data["skills"]:
		c.skills[skill] = mini(data["skills"][skill] * level, SKILL_MAX)
	c.gear = data["gear"].duplicate()
	if data.has("heavy") and level >= HEAVY_LEVEL:
		c.gear[Slot.BODY] = data["heavy"]


func fee(c: Colonist) -> int:
	return roundi((FEE_BASE + FEE_PER_LEVEL * c.level) * gift(c, "fee", 1.0))


# effetto `key` dei talenti di `c` (vedi GIFT_FX), `base` se non ce l'ha
func gift(c: Colonist, key: String, base: Variant) -> Variant:
	for g in c.gifts:
		if GIFT_FX[g].has(key):
			return GIFT_FX[g][key]
	return base


# effetto `key` per tutto il gruppo `party`, se qualcuno ha il talento; se no `base`
func party_gift(party: Array, key: String, base: Variant) -> Variant:
	for c in party:
		var v = gift(c, key, null)
		if v != null:
			return v
	return base


func hero_name(c: Colonist) -> String:
	return "%s, level %d" % [Hero.keys()[c.hero].capitalize(), c.level]


func gift_names(c: Colonist) -> String:
	return ", ".join(c.gifts.map(func(g): return Gift.keys()[g].capitalize()))


# caselle del bordo della mappa dove si cammina: da lì arrivano e se ne vanno gli avventurieri
func border_cells() -> Array:
	var cells := []
	for t in MAP_SIZE.x:
		for cell in [Vector2i(t, 0), Vector2i(t, MAP_SIZE.y - 1), Vector2i(0, t), Vector2i(MAP_SIZE.x - 1, t)]:
			if roams(cell):
				cells.append(cell)
	return cells


# Arrivi alla locanda: ogni GUEST_EVERY giorni circa, se c'è un letto della locanda per lui (contando chi è in
# spedizione); se non c'è, il prossimo arriva GUEST_EVERY dopo che si è liberato. Chi aspetta da GUEST_STAY giorni
# senza che nessuno lo ingaggi se ne va
func update_guests() -> void:
	var away: int = expeditions.reduce(func(n, exp): return n + exp.party.filter(func(g): return g not in guests).size(), 0)
	if inn_beds() <= guests.size() + away:
		next_guest = maxf(next_guest, clock + GUEST_EVERY)
	elif clock >= next_guest:
		next_guest = clock + GUEST_EVERY + randf_range(-GUEST_JITTER, GUEST_JITTER)
		var edges := border_cells()
		if not edges.is_empty():
			var level := clampi(1 + colony_splendor() / SPLENDOR_PER_LEVEL + randi_range(-1, 1), 1, HERO_LEVEL_MAX)
			var g := new_hero(Hero.values().slice(1).pick_random(), level)
			g.pos = center(edges.pick_random())
			g.errand = Errand.ARRIVE
			guests.append(g)
			travel(g)
	for g in guests:
		if not g.hired and g.errand == Errand.NONE and clock >= g.stay_until:
			g.errand = Errand.LEAVE
			quit_job(g)
			travel(g)


# `c` si avvia dove lo porta la sua commissione: alla locanda, o al bordo della mappa più vicino (in spedizione,
# dove è uscito il primo del gruppo). Se non ci arriva arriva lo stesso (vedi arrive): via dalla mappa, o resta dov'è
func travel(c: Colonist) -> void:
	var goals := []
	var exp := trip_of(c)
	if c.errand in [Errand.ARRIVE, Errand.RETURN]:
		for room in rooms:
			if is_inn(room):
				goals.append_array(room.cells.keys().filter(func(k): return not astar.is_point_solid(k)))
	elif c.errand == Errand.DEPART and exp != null and exp.edge.x >= 0:
		goals = [exp.edge]
	else:
		goals = border_cells()
	var path := path_to_nearest(c, goals)
	start_job(c, Job.TRAVEL, path, path.back() if not path.is_empty() else cell_of(c.pos), 0.0)


# `c` è arrivato dove andava (Job.TRAVEL): alla locanda aspetta (e di ritorno lascia lì il bottino), al bordo esce
# dalla mappa: per sempre, o per la spedizione (che parte quando è uscito tutto il gruppo)
func arrive(c: Colonist) -> void:
	end_job(c)
	match c.errand:
		Errand.ARRIVE:
			c.stay_until = clock + GUEST_STAY
		Errand.RETURN:
			c.stay_until = clock + GUEST_REST
			c.hired = false
			for res in c.loot:
				drop(res, cell_of(c.pos), c.loot[res])
			c.loot.clear()
		Errand.LEAVE:
			guests.erase(c)
		Errand.DEPART:
			guests.erase(c)
			var exp := trip_of(c)
			if exp != null:
				if exp.edge.x < 0:
					exp.edge = cell_of(c.pos)
				leave_if_ready(exp)
	c.errand = Errand.NONE


# la spedizione di `c` che non è ancora tornata, o null
func trip_of(c: Colonist) -> Expedition:
	for exp in expeditions:
		if c in exp.party:
			return exp
	return null


# fuori dalla mappa tutto il gruppo: si parte
func leave_if_ready(exp: Expedition) -> void:
	if exp.left_at < 0 and exp.party.all(func(g): return g not in guests):
		depart(exp)


func explored(ruin: Ruin) -> bool:
	return ruin.cleared >= RUINS[ruin.kind]["rooms"]


# giorni di viaggio (andata) del gruppo `party` alla rovina: meno con una guida
func travel_days(ruin: Ruin, party: Array) -> float:
	return RUINS[ruin.kind]["travel"] * party_gift(party, "travel", 1.0)


# giorni per andare alla rovina, esplorare le stanze che restano e tornare
func trip_days(ruin: Ruin, party: Array) -> float:
	return 2 * travel_days(ruin, party) + ROOM_DAYS * (RUINS[ruin.kind]["rooms"] - ruin.cleared)


# provviste che servono al gruppo `party` per tutto il viaggio: una a testa per giorno (meno, con chi trova da mangiare)
func provisions(party: Array, ruin: Ruin) -> int:
	return ceili(party.size() * trip_days(ruin, party) * party_gift(party, "food", 1.0) - 0.001)


func food_stored() -> int:
	return (MEALS + RAW_FOOD).reduce(func(n, r): return n + stored(r), 0)


# Manda il gruppo `party` (dalla locanda, al più MAX_PARTY) alla rovina `ruin`: paga dal magazzino la somma delle
# paghe e prende le provviste che servono, prima i pasti poi il crudo (quelle che ci sono: le altre le pagheranno
# con la fame). Vanno al bordo della mappa. false se non si può
func send(party: Array, ruin: Ruin) -> bool:
	var cost: int = party.reduce(func(n, g): return n + fee(g), 0)
	if party.is_empty() or party.size() > MAX_PARTY or ruin not in ruins or explored(ruin) or stored(Res.GOLD) < cost \
			or party.any(func(g): return g.hired or g not in guests):
		return false
	take_stored(Res.GOLD, cost)
	var exp := Expedition.new()
	exp.ruin = ruin
	var want := provisions(party, ruin)
	for res in MEALS + RAW_FOOD:
		var n := mini(stored(res), want - int(exp.food))
		take_stored(res, n)
		exp.food += n
	for g in party:
		exp.party.append(g)
		g.hired = true
		g.errand = Errand.DEPART
		quit_job(g)
		travel(g)
	expeditions.append(exp)
	board_pick.clear()
	note("Day %d: %s hired for the %s, for %d gold and %d of %d provisions." % [int(clock) + 1,
		", ".join(party.map(func(g): return "%s (%s)" % [full_name(g), hero_name(g)])), RUINS[ruin.kind]["name"], cost,
		exp.food, want])
	return true


# toglie `amount` di `res` dai magazzini (un pagamento): da un mucchio dopo l'altro, anche da quelli che qualcuno sta
# andando a prendere (il trasporto si accorge che il mucchio è calato, vedi Job.HAUL)
func take_stored(res: Res, amount: int) -> void:
	for cell in items[res].keys():
		if amount > 0 and stockpile.has(cell):
			var n := mini(items[res][cell], amount)
			add_item(res, cell, -n)
			amount -= n


# Il gruppo esce dalla mappa: com'è andata nella rovina si decide adesso (vedi explore), si saprà al ritorno
func depart(exp: Expedition) -> void:
	var travel := travel_days(exp.ruin, exp.party)
	exp.left_at = clock
	exp.due = clock + trip_days(exp.ruin, exp.party)
	var days := explore(exp, travel)
	exp.back_at = clock + (exp.due - clock) * LOST_AFTER if exp.lost else clock + 2 * travel + days


# Esplora la rovina di `exp` dalla prima stanza non ancora ripulita, una ogni ROOM_DAYS (vedi Chamber): scrive il
# diario, ferisce e uccide, raccoglie bottino e mappe, mangia le provviste (vedi eat_on_trip). L'ultima stanza è il
# tesoro col suo guardiano: se resta chiuso, la stanza resta da fare. Il gruppo torna indietro finite le stanze, se
# qualcuno è sotto TURN_BACK, se le provviste non bastano per un'altra stanza e il ritorno, o se una frana chiude la
# strada. `travel`: giorni di viaggio, ad andare e a tornare. Restituisce i giorni passati nella rovina.
# I talenti (vedi GIFT_FX) cambiano trappole, mostri, forzieri, cure e soglie
func explore(exp: Expedition, travel: float) -> float:
	var data: Dictionary = RUINS[exp.ruin.kind]
	var danger: int = data["danger"]
	var days := 0.0
	var start: float = exp.left_at + travel
	exp.lines.append(("Day %d: the party reaches the %s. %s" % [int(start) + 1, data["name"], eat_on_trip(exp, travel)]).strip_edges())
	while exp.ruin.cleared < data["rooms"] and not exp.party.is_empty():
		var last: bool = exp.ruin.cleared == data["rooms"] - 1
		var room := "Day %d, room %d: " % [int(start + days) + 1, exp.ruin.cleared + 1]
		days += ROOM_DAYS
		var kind: int = Chamber.CHEST if last else pick_chamber()
		var opened := true
		if last:
			room += "the guardian of the treasure. %s " % fight_monsters(exp, MONSTER_POWER * danger * 2)
		match kind:
			Chamber.EMPTY:
				room += "empty."
			Chamber.TRAP:
				var picker := best_at(exp.party, Skill.LOCKPICKING)
				if randf() < TRAP_DISARM + TRAP_PER_LEVEL * picker.skills[Skill.LOCKPICKING] + party_gift(exp.party, "disarm", 0.0):
					room += "%s disarms a trap." % picker.first_name
				else:
					var lured := exp.party.filter(func(c): return gift(c, "lure", false))
					var victim: Colonist = lured[0] if not lured.is_empty() else exp.party.pick_random()
					var hurt := roundf(TRAP_HURT * danger * gift(victim, "hurt", 1.0))
					victim.hp -= hurt
					room += "a trap hurts %s (-%d)." % [victim.first_name, hurt]
			Chamber.MONSTERS:
				if randf() < party_gift(exp.party, "sneak", 0.0):
					room += "monsters, but the party slips past them."
				else:
					room += "monsters! " + fight_monsters(exp, MONSTER_POWER * danger)
			Chamber.CHEST:
				var chest := open_chest(exp, data, last)
				room += chest[0]
				opened = chest[1]
			Chamber.COLLAPSE:
				room += "a collapse blocks the way."
		exp.lines.append((room + " " + eat_on_trip(exp, ROOM_DAYS)).strip_edges())
		for c in exp.party.duplicate():  # a 0 punti ferita: muore, o lo riportano gli altri (da solo, nessuno)
			if c.hp <= 0:
				var medic := exp.party.any(func(o): return o != c and o.hp > 0 and gift(o, "carry", false))
				if exp.party.size() == 1 or (not medic and randf() < FALL_DEATH):
					exp.party.erase(c)
					c.died = clock
					exp.lines.append("%s falls and dies." % c.first_name)
					note("Day %d: %s died in the %s." % [int(start + days) + 1, full_name(c), data["name"]])
				else:
					c.hp = CARRIED_HP
					exp.lines.append("%s falls; the others carry them." % c.first_name)
		if exp.party.is_empty():
			exp.lost = true
			break
		var heal: float = party_gift(exp.party, "heal", 0.0)
		for c in exp.party:  # il medico cura tutti dopo ogni stanza
			c.hp = minf(c.hp + heal, MAX_HP)
		if kind == Chamber.COLLAPSE:
			exp.lines.append("The party turns back.")
			break
		if not opened and last:
			exp.lines.append("The treasure stays locked: the party turns back.")
			break
		exp.ruin.cleared += 1
		if explored(exp.ruin):
			break
		var weak := exp.party.filter(func(c): return c.hp < gift(c, "turn_back", TURN_BACK))
		if not weak.is_empty():
			exp.lines.append("%s is wounded: the party turns back." % weak[0].first_name)
			break
		if exp.food < exp.party.size() * (travel + ROOM_DAYS) * party_gift(exp.party, "food", 1.0) - 0.001:
			exp.lines.append("Provisions are running low: the party turns back.")
			break
	if explored(exp.ruin):
		exp.lines.append("The %s has nothing left to explore." % data["name"])
	if not exp.lost:  # il ritorno: affamati, ma a casa ci arrivano
		var hunger := eat_on_trip(exp, travel)
		if hunger != "":
			exp.lines.append("On the way home: " + hunger.to_lower())
		for c in exp.party:
			c.hp = maxf(c.hp, 1.0)
	return days


# Provviste per `days` giorni di tutto il gruppo; quello che manca lo si paga in punti ferita, HUNGER_HURT al giorno.
# Il testo per il diario, vuoto se hanno mangiato
func eat_on_trip(exp: Expedition, days: float) -> String:
	var need: float = days * exp.party.size() * party_gift(exp.party, "food", 1.0)
	var eaten := minf(exp.food, need)
	exp.food -= eaten
	if eaten >= need - 0.001:
		return ""
	var hurt: float = HUNGER_HURT * (need - eaten) / exp.party.size() / party_gift(exp.party, "food", 1.0)
	for c in exp.party:
		c.hp -= hurt
	return "No food left: hunger (-%d each)." % roundi(hurt)


func pick_chamber() -> int:
	var roll := randi_range(1, CHAMBER_ODDS.values().reduce(func(a, b): return a + b, 0))
	for kind in CHAMBER_ODDS:
		roll -= CHAMBER_ODDS[kind]
		if roll <= 0:
			return kind
	return Chamber.EMPTY


func best_at(party: Array[Colonist], skill: Skill) -> Colonist:
	var best := party[0]
	for c in party:
		if c.skills[skill] > best.skills[skill]:
			best = c
	return best


# Mostri di forza `power` contro il gruppo: in media ognuno prende MONSTER_HURT x mostri / forza media del gruppo
# (meno, con un arciere), chi più chi meno secondo "hurt" della classe, meno la sua protezione. Il testo per il diario
func fight_monsters(exp: Expedition, power: float) -> String:
	var strength := 0.0
	var weights := 0.0
	var cover := 1.0
	for c in exp.party:
		strength += c.skills[HEROES[c.hero]["weapon"]] * gift(c, "weapon", 1.0) + gear_sum(c, "armor")
		weights += HEROES[c.hero]["hurt"]
		cover = minf(cover, HEROES[c.hero].get("cover", 1.0))
	var hurt := MONSTER_HURT * power * exp.party.size() / maxf(strength, 1.0) * cover
	var wounds := PackedStringArray()
	for c in exp.party:
		var taken := roundf(hurt * exp.party.size() * HEROES[c.hero]["hurt"] / weights * armor_factor(c) * gift(c, "hurt", 1.0))
		c.hp -= taken
		wounds.append("%s -%d" % [c.first_name, taken])
		c.xp[HEROES[c.hero]["weapon"]] += 1
	return ", ".join(wounds) + "."


# Forziere: chiuso (LOCKED) lo apre solo il migliore a scassinare, se ne sa abbastanza; dentro monete e un oggetto
# della rovina, di più con la sacca dello scassinatore. Il tesoro (`last`) ha la mappa della rovina dopo; gli altri,
# a volte, quella di una rovina che non si conosce. [testo per il diario, aperto]
func open_chest(exp: Expedition, data: Dictionary, last: bool) -> Array:
	var picker := best_at(exp.party, Skill.LOCKPICKING)
	if randf() < LOCKED and picker.skills[Skill.LOCKPICKING] < LOCK_PER_DANGER * data["danger"]:
		return ["a locked chest nobody can open.", false]
	var haul := 1.0
	for c in exp.party:
		haul = maxf(haul, HEROES[c.hero].get("haul", 1.0))
	var gold := roundi(randi_range(data["gold"][0], data["gold"][1]) * haul * (TREASURE_GOLD if last else 1))
	exp.loot[Res.GOLD] = exp.loot.get(Res.GOLD, 0) + gold
	var found := {}  # Res -> quantità in questo forziere
	for i in 1 + party_gift(exp.party, "finds", 0):  # col fortunato un oggetto in più
		var find: Array = data["finds"].pick_random()
		found[find[0]] = found.get(find[0], 0) + roundi(find[1] * haul)
	for res in found:
		exp.loot[res] = exp.loot.get(res, 0) + found[res]
	var text := "a chest: %d gold, %s" % [gold, ", ".join(found.keys().map(func(r): return "%d %s" % [found[r], res_name(r)]))]
	var unknown := RuinKind.values().filter(func(k): return not ruins.any(func(r): return r.kind == k) and k not in exp.maps)
	var map = null
	if last and exp.ruin.kind + 1 in unknown:
		map = exp.ruin.kind + 1
	elif not unknown.is_empty() and randf() < MAP_CHANCE * party_gift(exp.party, "maps", 1.0):
		map = unknown.pick_random()
	if map != null:
		exp.maps.append(map)
		text += " and a map to the %s" % RUINS[map]["name"]
	return [text + ".", true]


# Ritorni: a back_at il gruppo rientra dal bordo da cui era uscito e va alla locanda col bottino (meno la quota
# delle monete, che si tengono); le mappe fanno conoscere le loro rovine; ognuno sale di livello ogni TRIPS_PER_LEVEL
# spedizioni. Una spedizione persa: solo il diario (le mappe sono perse con loro)
func update_expeditions() -> void:
	for exp in expeditions.duplicate():
		if exp.left_at < 0 or clock < exp.back_at:
			continue
		expeditions.erase(exp)
		var name: String = RUINS[exp.ruin.kind]["name"]
		if exp.lost:
			exp.lines.append("Nobody came back from the %s." % name)
			report("Lost in the %s" % name, exp.lines)
			continue
		var gold: int = exp.loot.get(Res.GOLD, 0)
		var shares: float = exp.party.reduce(func(n, g): return n + gift(g, "share", SHARE), 0.0) / exp.party.size()
		var kept := floori(gold * shares)  # la quota: ognuno la sua parte (il leale niente)
		if gold > 0:
			exp.loot[Res.GOLD] = gold - kept
		var brought := PackedStringArray()
		for res in exp.loot:
			if exp.loot[res] > 0:
				brought.append("%d %s" % [exp.loot[res], res_name(res)])
		exp.lines.append("Back home with %s%s." % [", ".join(brought) if not brought.is_empty() else "nothing",
			"; they keep %d gold" % kept if kept > 0 else ""])
		for kind in exp.maps:
			if not ruins.any(func(r): return r.kind == kind):
				var found := Ruin.new()
				found.kind = kind
				ruins.append(found)
				exp.lines.append("New on the notice board: the %s." % RUINS[kind]["name"])
		ruins.sort_custom(func(a, b): return a.kind < b.kind)
		for g in exp.party:
			g.trips += 1
			if g.trips % gift(g, "trips", TRIPS_PER_LEVEL) == 0 and g.level < HERO_LEVEL_MAX:
				set_level(g, g.level + 1)
				exp.lines.append("%s is now level %d." % [g.first_name, g.level])
			g.pos = center(exp.edge)
			g.errand = Errand.RETURN
			guests.append(g)
			travel(g)
		exp.party[0].loot = exp.loot  # lo porta il primo, lo lascia alla locanda (vedi arrive)
		report("Back from the %s" % name, exp.lines)


# nome di una risorsa nei testi: "leather armor"
func res_name(res: Res) -> String:
	return Res.keys()[res].capitalize().to_lower()


# una riga nella cronaca
func note(text: String) -> void:
	chronicle.append(text)


# diario di una spedizione: nella cronaca e in una finestra al centro
func report(title: String, lines: PackedStringArray) -> void:
	note(title + "\n" + "\n".join(lines))
	$HUD/ReportPanel/Box/Head/Title.text = title
	$HUD/ReportPanel/Box/Text.text = "\n".join(lines)
	$HUD/ReportPanel.show()
	$HUD/ReportPanel.reset_size()


# --- Bacheca ---

func open_board() -> void:
	board_key = ""
	fill_board()
	$HUD/BoardPanel.show()


# Finestra della bacheca: oro e provviste nei magazzini, chi aspetta alla locanda (da spuntare per la spedizione, al
# più MAX_PARTY), le rovine conosciute (ognuna col tasto per mandarci gli spuntati: paghe e provviste), le spedizioni
# in corso e il titolo dell'ultima pagina della cronaca (tutta col tasto Chronicle). Si rifà solo quando cambia
# qualcosa, se no i tasti non si premono
func fill_board() -> void:
	var waiting := guests.filter(func(g): return not g.hired and g.errand != Errand.LEAVE)
	for g in board_pick.duplicate():
		if g not in waiting:
			board_pick.erase(g)
	var key := str([stored(Res.GOLD), food_stored(), waiting, board_pick, ruins.map(func(r): return r.cleared),
		expeditions.map(func(exp): return exp.left_at), chronicle.size()])
	if key == board_key:
		return
	board_key = key
	var box: Control = $HUD/BoardPanel/Box
	box.get_node("Gold").text = "Gold: %d    Provisions (meals, raw food): %d" % [stored(Res.GOLD), food_stored()]
	var list: Control = box.get_node("Heroes")
	for child in list.get_children() + box.get_node("Ruins").get_children():
		child.free()
	for g in waiting:
		var row := HBoxContainer.new()
		var icon := Control.new()
		icon.custom_minimum_size = Vector2.ONE * TILE * 2
		icon.set_script(TIP)
		icon.set("make_tip", colonist_tip.bind(g))
		icon.tooltip_text = full_name(g)
		icon.draw.connect(draw_figure.bind(icon, Rect2(Vector2.ZERO, Vector2.ONE * TILE * 2), Rect2(0, 0, TILE, TILE), g))
		row.add_child(icon)
		var label := Label.new()
		label.text = "%s\n%s, %s, %d gold" % [full_name(g), hero_name(g), gift_names(g), fee(g)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var pick := CheckBox.new()
		pick.text = "Pick"
		pick.focus_mode = Control.FOCUS_NONE
		pick.button_pressed = g in board_pick
		pick.disabled = g not in board_pick and board_pick.size() >= MAX_PARTY
		pick.toggled.connect(toggle_pick.bind(g))
		row.add_child(pick)
		list.add_child(row)
	if waiting.is_empty():
		var nobody := Label.new()
		nobody.text = "Nobody is waiting at the inn." if inn_beds() > 0 else "Nobody will come without an inn: a room with a bed, a table and this board."
		nobody.autowrap_mode = TextServer.AUTOWRAP_WORD
		list.add_child(nobody)
	var cost: int = board_pick.reduce(func(n, g): return n + fee(g), 0)
	for ruin in ruins:
		var data: Dictionary = RUINS[ruin.kind]
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s (danger %d): %s" % [data["name"], data["danger"],
			"explored" if explored(ruin) else "rooms %d / %d" % [ruin.cleared, data["rooms"]]]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if not explored(ruin):
			var food := provisions(board_pick, ruin)
			var send_button := Button.new()
			send_button.text = "Send: %d gold, %d food" % [cost, food] if not board_pick.is_empty() else "Send"
			send_button.focus_mode = Control.FOCUS_NONE
			send_button.disabled = board_pick.is_empty() or stored(Res.GOLD) < cost
			send_button.tooltip_text = "Pick who goes" if board_pick.is_empty() else ("Not enough gold" if stored(Res.GOLD) < cost
				else ("Only %d of %d provisions: they will go hungry" % [food_stored(), food] if food_stored() < food
				else "%d days there and back" % ceili(trip_days(ruin, board_pick))))
			send_button.pressed.connect(func(): send(board_pick.duplicate(), ruin))
			row.add_child(send_button)
		box.get_node("Ruins").add_child(row)
	box.get_node("Away").text = "\n".join(expeditions.map(func(exp): return "%s: %s" % [", ".join(exp.party.map(func(c): return c.first_name)),
		"on the way out" if exp.left_at < 0 else "at the %s, due back by day %d" % [RUINS[exp.ruin.kind]["name"], int(exp.due) + 1]]))
	box.get_node("Away").visible = not expeditions.is_empty()
	box.get_node("Chronicle").text = "Last: " + chronicle[-1].get_slice("\n", 0) if not chronicle.is_empty() else ""  # il resto nella cronaca
	box.get_node("Chronicle").visible = not chronicle.is_empty()
	box.get_node("ChronicleButton").text = "Chronicle (%d)" % chronicle.size()
	$HUD/BoardPanel.reset_size()


# Cronaca: tutto quello che è successo (ingaggi, diari delle spedizioni, morti), dal più recente
func open_chronicle() -> void:
	fill_chronicle()
	$HUD/ChroniclePanel.show()


func fill_chronicle() -> void:
	var text: Label = $HUD/ChroniclePanel/Box/Scroll/Text
	var pages := chronicle.duplicate()
	pages.reverse()
	text.text = "\n\n".join(pages) if not pages.is_empty() else "Nothing worth telling has happened yet."
	text.set_meta("pages", chronicle.size())


func toggle_pick(on: bool, g: Colonist) -> void:
	if on and g not in board_pick and board_pick.size() < MAX_PARTY:
		board_pick.append(g)
	elif not on:
		board_pick.erase(g)


# --- Pesca e caccia ---

# punti di pesca segnati dove ci sono pesci
func fishable() -> Array:
	return fish_marks.keys().filter(func(k): return fish_spots.get(k, 0.0) <= clock)


func catch_chance(level: int) -> float:
	return CATCH_BASE + CATCH_PER_LEVEL * level


# livello con cui mira: con l'arco il migliore tra caccia e armi a distanza
func hunt_level(c: Colonist) -> int:
	if has_bow(c):
		return maxi(c.skills[Skill.HUNTING], c.skills[Skill.RANGED])
	return c.skills[Skill.HUNTING]


func hunt_range(c: Colonist) -> float:
	return HUNT_RANGE + gear_sum(c, "range")


func hit_chance(level: int, tiles: float) -> float:
	return clampf(HIT_BASE + HIT_PER_LEVEL * level - HIT_PER_TILE * tiles, 0.05, 0.95)


# Caccia: l'animale segnato più vicino che nessuno insegue già. Il cacciatore va verso di lui finché non è a tiro
# (vedi track_prey), poi tira (vedi Job.HUNT). false se non ce n'è o non ci si arriva.
func try_hunt(c: Colonist) -> bool:
	var prey := animals.filter(func(a): return a.marked and a.hunter == null and a.blocked <= clock)
	if prey.is_empty():
		return false
	prey.sort_custom(func(a, b): return a.pos.distance_squared_to(c.pos) < b.pos.distance_squared_to(c.pos))
	c.job = Job.HUNT
	c.prey = prey[0]
	prey[0].hunter = c
	c.work_total = AIM_TIME * skill_time(hunt_level(c)) * work_factor(c, Job.HUNT)
	c.work_left = c.work_total
	chase(c)
	return c.job == Job.HUNT


# percorso del cacciatore fino alla preda; se non ci arriva la lascia stare per un po' e molla il lavoro
func chase(c: Colonist) -> void:
	var a: Animal = c.prey
	c.target = cell_of(a.pos)
	c.path = path_of(c, cell_of(c.pos), c.target)
	if c.path.is_empty():
		a.blocked = clock + RETRY_AFTER / DAY_LENGTH
		quit_job(c)


# Mentre cammina chi caccia o combatte segue l'animale: appena è a portata (con un po' di margine) finisce il passo e si
# ferma a mirare; se l'animale si è allontanato dalla fine del percorso, lo rifà. Sparito (o, a caccia, non più
# segnato): lascia perdere
func track_prey(c: Colonist) -> void:
	var a: Animal = c.prey
	if a == null or a not in animals or (c.job == Job.HUNT and not a.marked):
		quit_job(c)
		return
	if c.path.is_empty():
		return
	if c.pos.distance_to(a.pos) <= reach(c) * TILE * 0.8:
		c.path = [c.path[0]]
	elif center(c.path.back()).distance_to(a.pos) > 2 * TILE:
		chase(c)


func spawn_animal(kind: Beast) -> void:
	for attempt in 50:
		var cell := Vector2i(wild.randi() % MAP_SIZE.x, wild.randi() % MAP_SIZE.y)
		if (cell - MAP_SIZE / 2).length() > WILD_RADIUS and roams(cell):
			add_animal(kind, cell)
			return


func add_animal(kind: Beast, cell: Vector2i) -> Animal:
	var a := Animal.new()
	a.kind = kind
	a.pos = center(cell)
	a.rest = wild.randf_range(WANDER_REST[0], WANDER_REST[1])
	animals.append(a)
	return a


# un animale ci può andare: prato o bosco, niente acqua, roccia, muri o stanze
func roams(cell: Vector2i) -> bool:
	return astar.is_in_boundsv(cell) and not astar.is_point_solid(cell) and not water.has(cell) \
		and not built.has(cell) and not rooms.any(func(r): return r.cells.has(cell))


# Animale: cammina lungo il suo percorso (più veloce se scappa), poi sta fermo un po' e riparte per un giro qui vicino.
# I lupi invece inseguono i coloni (vedi update_wolf)
func update_animal(a: Animal, delta: float) -> void:
	if hostile(a) and update_wolf(a, delta):
		return
	if move_animal(a, delta):
		return
	a.fleeing = false
	a.rest -= delta
	if a.rest > 0:
		return
	a.rest = wild.randf_range(WANDER_REST[0], WANDER_REST[1])
	a.path = roam_path(a, WANDER, Vector2.INF)


# un passo lungo il percorso; false se non ne ha
func move_animal(a: Animal, delta: float) -> bool:
	if a.path.is_empty():
		return false
	var goal := center(a.path[0])
	var d := goal - a.pos
	if d.x != 0:
		a.left = d.x < 0
	var step: float = BEASTS[a.kind]["speed"] * (FLEE_SPEED if a.fleeing else 1.0) * TILE * delta
	a.walked += minf(d.length(), step)
	a.pos = a.pos.move_toward(goal, step)
	if a.pos == goal:
		a.path.pop_front()
	return true


# scappa da `from` (pixel), lontano FLEE caselle
func flee(a: Animal, from: Vector2) -> void:
	a.path = roam_path(a, FLEE, from)
	a.fleeing = not a.path.is_empty()


# Percorso verso una casella a caso entro `radius` dove l'animale può stare; se `away` è un punto, la più lontana da lì
# tra alcune a caso. Vuoto se non ne trova
func roam_path(a: Animal, radius: int, away: Vector2) -> Array[Vector2i]:
	var here := cell_of(a.pos)
	var best := here
	var none: Array[Vector2i] = []
	for attempt in 8:
		var cell := here + Vector2i(wild.randi_range(-radius, radius), wild.randi_range(-radius, radius))
		if not roams(cell):
			continue
		if away == Vector2.INF:
			best = cell
			break
		if center(cell).distance_to(away) > center(best).distance_to(away):
			best = cell
	if best == here or not astar.is_in_boundsv(here):
		return none
	var path := astar.get_id_path(here, best)
	return path if path.size() <= radius * 3 else none  # niente giri lunghissimi attorno a laghi e rocce


# quanto c'è da raccogliere in `target` intatto: tronchi dell'albero, pietra (o minerale) del masso, bacche del cespuglio
func full_stock(target: Vector2i) -> int:
	if trees.has(target):
		return TREE_LOGS[trees[target]]
	if boulders.has(target):
		return STONE_PER_CELL * boulder_cells(target).size()
	if water.has(target):
		return FISH_PER_SPOT
	return BERRIES_PER_BUSH


# cespugli con le bacche mature, non segnati da estirpare
func ripe_bushes() -> Array:
	return bushes.keys().filter(func(b): return bushes[b] <= clock and not uproot_marks.has(b))


# cespugli segnati da raccogliere che hanno le bacche
func harvest_ready() -> Array:
	return ripe_bushes().filter(func(b): return harvest_marks.has(b))


# progetti su cui lavora `job`: strutture (una casella) o mobili
func plans_of(job: Job) -> Dictionary:
	return furniture_plans if job == Job.FURNISH else blueprints


# mucchi (a terra o in magazzino) da cui prendere il materiale per `plan`, non prenotati da altri
func sources(plan: Array) -> Array:
	var ground: Dictionary = items[plan[1]]
	return ground.keys().filter(func(cell): return ground[cell] >= BUILD_COST[plan[0]] and is_free(cell))


# avvia il trasporto del mucchio di `res` più vicino tra `piles`; false se non c'è posto o strada
func try_haul(c: Colonist, res: Res, piles: Array) -> bool:
	# drop può aver fatto traboccare tutto sulle caselle accanto (es. bacche su un mucchio di legna): lì non c'è niente
	piles = piles.filter(func(cell): return items[res].has(cell))
	if piles.is_empty():
		return false  # prima questo: guardare il magazzino costa di più
	var shut := closed_cells(c)
	var dests := dest_cells(res).filter(func(cell): return not shut.has(cell))
	if dests.is_empty():
		return false  # magazzino pieno per questa risorsa, o dove lui non entra
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
	c.dest = dests[0]  # se non ci si arriva, al mucchio il lavoro si annulla (vedi HAUL)
	reserved[c.dest] = c
	return true


func add_stands(stands: Dictionary, cells: Array, target: Vector2i, sides: Array) -> void:
	for cell in cells:
		for side in sides:
			var s: Vector2i = cell + side
			if astar.is_in_boundsv(s) and not astar.is_point_solid(s) and not trees.has(s) \
					and blueprints.get(s, [-1])[0] != Build.WALL and not cells.has(s):
				stands[s] = target  # non sopra un albero, né sopra un muro da fare (diventerà solido), né sul lavoro stesso


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
	if c.prey and c.prey.hunter == c:
		c.prey.hunter = null
	c.prey = null
	c.job = Job.NONE


# Percorso di `c` verso la casella più vicina tra `cells` dove nessun altro colono è fermo o sta andando:
# ci si può passare attraverso, ma non fermarsi in due sulla stessa casella.
func path_to_nearest(c: Colonist, cells: Array) -> Array[Vector2i]:
	# ponytail: "più vicino" in linea d'aria e un percorso per candidato; passare a distanza di percorso se i coloni fanno giri assurdi
	# una casella irraggiungibile costa una ricerca su tutta la mappa: la si salta per RETRY_AFTER secondi
	# ponytail: vale per tutti i coloni, anche quando la strada la chiude una stanza vietata solo a lui (vedi path_of);
	# con gruppi separati di coloni servirà tenerla per zona (componenti connesse)
	var taken := claimed(c)
	taken.merge(closed_cells(c))  # né dentro le stanze dove non entra, neanche quella dove si trova
	cells = cells.filter(func(cell): return not taken.has(cell))
	sort_by_distance(cells, c.pos)
	var misses := 0
	for cell in cells:
		if unreachable.get(cell, -1.0) > clock:
			continue
		var path := path_of(c, cell_of(c.pos), cell)
		if not path.is_empty():
			return path
		unreachable[cell] = clock + RETRY_AFTER / DAY_LENGTH
		misses += 1
		if misses == 3:
			break  # le altre ai prossimi tick: niente scatti
	return []


# Percorso di `c` da `from` a `to` che non passa dalle stanze dove non entra: per la ricerca le si riempie come
# fossero muro. Da quella dove si trova può uscire.
func path_of(c: Colonist, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var shut := closed_cells(c, from).keys().filter(func(k): return not astar.is_point_solid(k))
	for k in shut:
		astar.set_point_solid(k)
	var path := astar.get_id_path(from, to)
	for k in shut:
		astar.set_point_solid(k, false)
	return path


# Caselle delle stanze dove `c` non entra: bandite, o con dei proprietari e lui non tra questi.
# Tranne la stanza che contiene `inside`, se c'è.
func closed_cells(c: Colonist, inside := Vector2i(-1, -1)) -> Dictionary:
	var cells := {}
	for room in rooms:
		if (room.banned or not (room.owners.is_empty() or c in room.owners)) and not room.cells.has(inside):
			cells.merge(room.cells)
	return cells


# Cambiati proprietari o divieto: chi sta, o andrebbe, dove ora non entra molla il lavoro (e lo rimette giù);
# chi è dentro esce col prossimo lavoro.
func recheck_access() -> void:
	for o in people():
		var shut := closed_cells(o)
		if shut.has(cell_of(o.pos)) or o.path.any(func(k): return shut.has(k)):
			quit_job(o)


# Caselle dove gli altri coloni si fermeranno: fine del percorso (o dove sono, se fermi) e il cantiere di chi costruisce.
func claimed(except: Colonist) -> Dictionary:
	var cells := {}
	for o in people():
		if o != except:
			cells[cell_of(o.pos) if o.path.is_empty() else o.path.back()] = true
			if o.job in [Job.BUILD, Job.FURNISH, Job.COOK, Job.CRAFT]:
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
		return is_free(cell) and items[res].get(cell, 0) < STACK_MAX[res])


# Aggiunge (o toglie, se negativo) `amount` di `res` al mucchio in `cell`. Il cibo che arriva (fresco, se `days` è
# negativo) si mescola a quello che c'è: il mucchio prende la media dei giorni che restano, pesata sulle quantità
func add_item(res: Res, cell: Vector2i, amount: int, days := -1.0) -> void:
	var ground: Dictionary = items[res]
	var had: int = ground.get(cell, 0)
	ground[cell] = had + amount
	if SHELF_LIFE.has(res) and amount > 0:
		var incoming: float = SHELF_LIFE[res] if days < 0 else days
		fresh[cell] = (fresh.get(cell, 0.0) * had + incoming * amount) / ground[cell]
	if ground[cell] <= 0:
		ground.erase(cell)
		fresh.erase(cell)


# `c` prende in mano `amount` di `res` dal mucchio in `cell`, col suo stato di freschezza
func pick_up(c: Colonist, res: Res, cell: Vector2i, amount: int) -> void:
	c.carry_days = fresh.get(cell, 0.0)
	add_item(res, cell, -amount)
	c.carry_res = res
	c.carrying = amount


# Il cibo a terra invecchia di `days` giorni, a metà velocità in magazzino (vedi spoil_rate); finiti, il mucchio marcisce
# e sparisce. Chi ci stava andando lo trova vuoto e lascia perdere.
# ponytail: quello in mano non invecchia (lo si tiene poco); il marcio non lascia niente: se serve un mucchio da buttare
func spoil(days: float) -> void:
	for cell in fresh.keys():
		fresh[cell] -= days * spoil_rate(cell)
		if fresh[cell] <= 0:
			for res in SHELF_LIFE:
				items[res].erase(cell)
			fresh.erase(cell)


func spoil_rate(cell: Vector2i) -> float:
	return SPOIL_STORED if stockpile.has(cell) else 1.0


# Posa a terra `amount` di `res` su `cell`; oltre STACK_MAX il resto va sulle caselle più vicine dove ci sta
# (niente alberi, acqua, altre risorse), come si allarga una macchia.
func drop(res: Res, cell: Vector2i, amount: int, days := -1.0) -> void:
	var todo := [cell]
	var seen := {cell: true}
	while amount > 0 and not todo.is_empty():
		var k: Vector2i = todo.pop_front()
		if not trees.has(k) and not water.has(k) and items.keys().all(func(r): return r == res or not items[r].has(k)):
			var put := mini(amount, STACK_MAX[res] - items[res].get(k, 0))
			if put > 0:
				add_item(res, k, put, days)
				amount -= put
		for side in SIDES:
			var next: Vector2i = k + side
			if not seen.has(next) and astar.is_in_boundsv(next) and not astar.is_point_solid(next):
				seen[next] = true
				todo.append(next)


func boulder_cells(origin: Vector2i) -> Array[Vector2i]:
	return cells_in(Rect2i(origin, boulders[origin]))


func cells_in(rect: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy in rect.size.y:
		for dx in rect.size.x:
			cells.append(rect.position + Vector2i(dx, dy))
	return cells


# caselle di `plan` con l'angolo in alto a sinistra su `origin`: una per le strutture, FURNITURE per i mobili
func piece_rect(origin: Vector2i, plan: Array) -> Rect2i:
	var size: Vector2i = FURNITURE.get(plan[0], Vector2i.ONE)
	return Rect2i(origin, Vector2i(size.y, size.x) if plan.size() > 2 and plan[2] % 2 else size)


# origini dei mobili di `layer` che coprono `cell`
# ponytail: scorre tutti i mobili a ogni domanda; un indice casella -> mobile se diventano centinaia
func pieces_at(layer: Dictionary, cell: Vector2i) -> Array:
	return layer.keys().filter(func(origin): return piece_rect(origin, layer[origin]).has_point(cell))


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
		Order.UPROOT:  # un cespuglio da estirpare non si raccoglie più
			for cell in bushes.keys() + weeds.keys():
				if rect.has_point(cell):
					uproot_marks[cell] = true
					harvest_marks.erase(cell)
		Order.HARVEST:  # e viceversa: si cambia idea
			for cell in bushes:
				if rect.has_point(cell):
					harvest_marks[cell] = true
					uproot_marks.erase(cell)
		Order.FISH:
			for cell in water:
				if rect.has_point(cell):
					fish_marks[cell] = true
		Order.HUNT:  # una casella di margine: si muovono
			for a in animals:
				if rect.grow(1).has_point(cell_of(a.pos)):
					a.marked = true
		Order.BUILD:  # nel progetto; i muri solo sul bordo del rettangolo: trascinando si disegna una stanza
			if FURNITURE.has(build_kind):  # un mobile per volta, girato di build_turn, dall'angolo del rettangolo
				var plan := [build_kind, build_res, build_turn]
				if cells_in(piece_rect(rect.position, plan)).all(func(k): return can_build(k, build_kind)):
					furniture_draft[rect.position] = plan
				return
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					var edge: bool = x in [rect.position.x, rect.end.x - 1] or y in [rect.position.y, rect.end.y - 1]
					if can_build(Vector2i(x, y), build_kind) and (edge or build_kind != Build.WALL):
						draft[Vector2i(x, y)] = [build_kind, build_res]  # sovrascrive: ripassando si cambia idea
		Order.ERASE:
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					erase_plan(Vector2i(x, y))
		Order.DEMOLISH:  # subito, senza recuperare il materiale
			for cell in built.keys().filter(func(k): return rect.has_point(k)):
				if built[cell][0] == Build.WALL:
					astar.set_point_solid(cell, false)
				built.erase(cell)
			for origin in furniture.keys().filter(func(o): return rect.intersects(piece_rect(o, furniture[o]))):
				furniture.erase(origin)
			update_rooms()


# toglie la casella dal progetto, anche già confermato, coi mobili che la coprono
func erase_plan(cell: Vector2i) -> void:
	draft.erase(cell)
	if blueprints.erase(cell):
		drop_job(cell, Job.BUILD)
	for origin in pieces_at(furniture_draft, cell):
		furniture_draft.erase(origin)
	for origin in pieces_at(furniture_plans, cell):
		furniture_plans.erase(origin)
		drop_job(origin, Job.FURNISH)


# chi stava facendo `job` su `target` lascia a terra il materiale e torna libero
func drop_job(target: Vector2i, job: Job) -> void:
	var c: Colonist = reserved.get(target)
	if c and c.job == job and c.target == target:  # strutture e mobili possono stare sulla stessa casella
		quit_job(c)


# lascia il lavoro a metà: quello che ha in mano finisce a terra, i trasportatori lo riportano in magazzino
func quit_job(c: Colonist) -> void:
	drop(c.carry_res, cell_of(c.pos), c.carrying, c.carry_days)
	c.carrying = 0
	for res in c.fetched:  # anche gli ingredienti già portati alla postazione
		drop(res, cell_of(c.pos), c.fetched[res])
	c.fetched.clear()
	c.path.clear()
	end_job(c)


# niente acqua, alberi, erbacce e cespugli (si estirpano), roccia, edifici o roba a terra; i mobili vanno anche
# sopra i pavimenti (pure in progetto), ma non sopra un altro mobile, e i muri e le porte non vanno sopra i mobili
func can_build(cell: Vector2i, kind := Build.FLOOR) -> bool:
	if not (astar.is_in_boundsv(cell) and not astar.is_point_solid(cell) and not water.has(cell) and not trees.has(cell) \
			and not bushes.has(cell) and not weeds.has(cell) and items.values().all(func(ground): return not ground.has(cell))):
		return false
	var furnished := [furniture, furniture_plans, furniture_draft].any(func(l): return not pieces_at(l, cell).is_empty())
	if FURNITURE.has(kind):
		return not furnished and [built, blueprints, draft].all(func(l): return l.get(cell, [Build.FLOOR])[0] in PAVING)
	return not built.has(cell) and not blueprints.has(cell) and (kind in PAVING or not furnished)


func build(cell: Vector2i) -> void:
	built[cell] = blueprints[cell]
	blueprints.erase(cell)
	if built[cell][0] == Build.WALL:
		astar.set_point_solid(cell)
		# ponytail: se non resta strada il colono lavora da dov'è; annullarne il lavoro se capita spesso
		for o in colonists:
			if cell_of(o.pos) == cell:  # ci stava passando sopra: esce dal lato libero più vicino, poi riprende la strada
				var out: Array = SIDES.map(func(d): return cell + d).filter(func(k): return astar.is_in_boundsv(k) and not astar.is_point_solid(k))
				if out.is_empty():
					continue
				sort_by_distance(out, o.pos)
				var after: Array[Vector2i] = [] if o.path.is_empty() else path_of(o, out[0], o.path.back())
				o.path.assign([out[0]] + after.slice(1))
			elif o.path.has(cell):  # chi doveva passare di qui cerca un'altra strada
				o.path = path_of(o, cell_of(o.pos), o.path.back())
	if built[cell][0] not in PAVING:
		update_rooms()


# Un muro non chiude nessuno in una sacca senza uscita (stanza senza porta): chi ci resterebbe ed è libero esce,
# chi lavora finisce prima; il costruttore, se è dalla parte chiusa, gira dall'altra. Né chiude fuori un lavoro
# che si fa solo da dentro: aspetta che sia finito.
func ready_to_close(c: Colonist) -> bool:
	astar.set_point_solid(c.target)  # prova: come sarebbe a muro finito
	var zones := []                  # zone distinte attorno al muro: la più grande è "fuori"
	for side in SIDES:
		var s: Vector2i = c.target + side
		if astar.is_in_boundsv(s) and not astar.is_point_solid(s) and not zones.any(func(z): return z.has(s)):
			zones.append(flood(s, false))
	astar.set_point_solid(c.target, false)
	if zones.is_empty():
		return true
	zones.sort_custom(func(a, b): return a.size() > b.size())
	var pockets := {}                # zone piccole che il muro stacca da quella più grande
	for zone in zones.slice(1):
		if zone.size() < ROOM_MAX:   # due zone grandi sono di solito la stessa, vista da lati lontani
			pockets.merge(zone)
	var cut := colonists.filter(func(o): return pockets.has(cell_of(o.pos)) or cell_of(o.pos) == c.target)
	var outside: Dictionary = zones[0]
	if c in cut:  # dalla parte che resta chiusa: gira dall'altra, anche sopra un muro da fare (aspetterà che si liberi)
		var to := path_to_nearest(c, SIDES.map(func(s): return c.target + s).filter(func(s): return outside.has(s)))
		if not to.is_empty():
			c.dest = to.back()
			c.path = to  # passa dal varco ancora aperto
		return false
	# progetti che si fanno solo dalla sacca (il pavimento dentro, un muro che fuori ha la roccia): chiudendo ora
	# resterebbero a metà per sempre. Prima quelli: li fa un altro colono, passando dal varco
	# ponytail: con un colono solo l'attesa non finisce; allora lasciare questo muro e prendere quegli altri
	for b in blueprints:
		var stands := {}
		add_stands(stands, [b], b, SIDES)
		if b != c.target and not stands.is_empty() and stands.keys().all(func(s): return pockets.has(s)):
			return false
	if cut.is_empty():
		return true
	for o in cut:
		if o.job == Job.NONE and o.path.is_empty():
			o.path = path_to_nearest(o, outside.keys())
	return false


# Caselle raggiungibili da `start` a passi in orizzontale e verticale, fino a ROOM_MAX.
# Con `doors_close` le porte fanno da muro: serve a trovare le stanze.
func flood(start: Vector2i, doors_close: bool) -> Dictionary:
	var cells := {start: true}
	var todo := [start]
	while not todo.is_empty() and cells.size() < ROOM_MAX:
		var cell: Vector2i = todo.pop_back()
		for side in SIDES:
			var next: Vector2i = cell + side
			if not cells.has(next) and astar.is_in_boundsv(next) and not astar.is_point_solid(next) \
					and not (doors_close and built.get(next, [-1])[0] == Build.DOOR):
				cells[next] = true
				todo.append(next)
	return cells


# Ritrova le stanze dopo che è cambiato un muro, una porta o la roccia. Una stanza che c'era già
# (stessa casella in alto a sinistra) tiene nome e tipo.
func update_rooms() -> void:
	var old := {}
	for room in rooms:
		old[room.cells.keys().min()] = room
	rooms.clear()
	var seen := {}
	for door in built:
		if built[door][0] != Build.DOOR:
			continue
		for side in SIDES:
			var inside: Vector2i = door + side
			var front: Vector2i = door - side
			if seen.has(inside) or not astar.is_in_boundsv(inside) or astar.is_point_solid(inside) \
					or built.get(inside, [-1])[0] == Build.DOOR:
				continue
			var cells := flood(inside, true)
			seen.merge(cells)
			if cells.size() >= ROOM_MAX or cells.has(front) or not astar.is_in_boundsv(front) or astar.is_point_solid(front):
				continue  # aperta sul mondo, o la porta non dà fuori
			var room: Room = old.get(cells.keys().min())
			if room == null:
				room = Room.new()
				rooms_made += 1
				room.name = "Structure%d" % rooms_made
			room.cells = cells
			room.door = door
			# cartello sul muro accanto alla porta: a destra o sotto, se no dall'altra parte; senza muri, fuori davanti
			var across := Vector2i(absi(side.y), absi(side.x))
			var walls := [door + across, door - across].filter(func(k): return built.get(k, [-1])[0] == Build.WALL)
			room.sign = walls[0] if not walls.is_empty() else front
			if not room_meets(room, room.kind):  # abbattuto un mobile che serviva: torna senza tipo, e senza proprietari
				retype(room, RoomKind.NONE)
			rooms.append(room)
	update_stockpile()


func update_stockpile() -> void:
	stockpile.clear()
	for room in rooms:
		if room.kind == RoomKind.WAREHOUSE:
			stockpile.merge(room.cells)


func total(res: Res) -> int:
	var sum := 0
	for amount in items[res].values():
		sum += amount
	for c in colonists:
		if c.carry_res == res:
			sum += c.carrying
		sum += c.fetched.get(res, 0)
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
				var signed := rooms.filter(func(r): return r.sign == cell)
				if event.pressed and order == Order.NONE:  # senza un'azione scelta il clic non segna niente: apre le schede
					var picked := colonist_at(get_global_mouse_position())
					var boards := pieces_at(furniture, cell).filter(func(o): return furniture[o][0] == Build.NOTICE_BOARD)
					if picked:
						open_sheet(picked)
					elif not boards.is_empty():
						open_board()
					elif not signed.is_empty():
						open_room(signed[0])
					else:
						sheet_panel.hide()  # clic altrove: la scheda si chiude
				elif event.pressed:
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
			KEY_E: turn(-1)
			KEY_R: turn(1)


func zoom_by(factor: float) -> void:
	camera.zoom = (camera.zoom * factor).clamp(Vector2.ONE * 0.5, Vector2.ONE * 8)


func selection_rect() -> Rect2i:
	if order == Order.BUILD and FURNITURE.has(build_kind):  # un mobile: dove si lascia il tasto, grande quanto lui
		return piece_rect(drag_end, [build_kind, build_res, build_turn])
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


# Pezzo di STRUCTURES per `plan` in `cell`: muri e porte si collegano a muri e porte vicini in `layers`.
func structure_src(cell: Vector2i, plan: Array, layers: Array) -> Rect2i:
	var links := 0
	for i in 4:
		var next: Vector2i = cell + WALL_LINKS[i]
		if layers.any(func(l): return l.has(next) and l[next][0] not in PAVING):
			links |= 1 << i
	match plan[0]:
		Build.WALL: return tile_rect(links, plan[1])
		Build.FLOOR: return tile_rect(plan[1], 2)
		Build.PATH: return tile_rect(2, 2)
		_: return tile_rect(1 if links & 5 and not links & 10 else 0, 3)  # porta: di lato se ha muri solo sopra e sotto


func draw_flat() -> void:  # sotto le ombre: il terreno lo disegna lo Sprite2D di bake_ground
	for cell in weeds:  # basse: niente ombra
		flat.draw_texture_rect_region(PLANTS, tile_rect(cell.x, cell.y), tile_rect(0, 0))
	for cell in built:
		if built[cell][0] in PAVING:
			flat.draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), structure_src(cell, built[cell], [built]))
			draw_grass_over(cell)
	var plans := [built, blueprints, draft]  # i progetti si collegano anche ai muri già fatti
	for cell in blueprints:  # in trasparenza
		flat.draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), structure_src(cell, blueprints[cell], plans),
			Color(1, 1, 1, 0.4))
	for cell in draft:  # velati d'azzurro, da confermare
		flat.draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), structure_src(cell, draft[cell], plans),
			Color(1, 1, 1, 0.6))
		flat.draw_rect(tile_rect(cell.x, cell.y), Color(0.55, 0.8, 1, 0.45))
	draw_pieces(flat, FURNITURE_SHEET, furniture_plans, Color(1, 1, 1, 0.4))  # i mobili come le strutture, sopra
	draw_pieces(flat, FURNITURE_SHEET, furniture_draft, Color(1, 1, 1, 0.6))
	for origin in furniture_draft:
		flat.draw_rect(piece_rects(origin, furniture_draft[origin])[0], Color(0.55, 0.8, 1, 0.45))
	for res in items:  # più roba = icona più grande
		for cell in items[res]:
			var side: float = 8.0 + 8.0 * mini(items[res][cell], STACK_MAX[res]) / STACK_MAX[res]
			flat.draw_texture_rect(ICONS[res], Rect2(center(cell) - Vector2.ONE * side / 2, Vector2.ONE * side), false)


# L'erba dei prati vicini sborda sul pavimento in `cell`, così non finisce di netto: lati, e angoli se nessun lato
# li copre già (come i bordi del terreno). Non contro muri, porte o altri pavimenti, né verso ghiaia e acqua.
func draw_grass_over(cell: Vector2i) -> void:
	var row := 4 + 2 * ((cell.x + cell.y) % 2)  # due varianti a scacchiera: lungo un bordo non si ripete lo stesso disegno
	for i in 4:
		if is_lawn(cell + EDGE_SIDES[i]):
			flat.draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), tile_rect(i, row))
		var d: Vector2i = EDGE_CORNERS[i]
		if is_lawn(cell + d) and not is_lawn(cell + Vector2i(d.x, 0)) and not is_lawn(cell + Vector2i(0, d.y)):
			flat.draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), tile_rect(i, row + 1))


func is_lawn(cell: Vector2i) -> bool:
	return astar.is_in_boundsv(cell) and ground_of(cell) == Ground.GRASS and not built.has(cell)


# Le sagome di ciò che sta in piedi, coricate a terra dalla parte opposta al sole; il colore lo dà `shadows`.
func draw_shadows() -> void:
	for cell in built:
		if built[cell][0] not in PAVING:
			cast(STRUCTURES, Rect2(tile_rect(cell.x, cell.y)), Rect2(structure_src(cell, built[cell], [built])))
	for cell in boulders:
		var rock := boulder_tex(cell)
		cast(rock, Rect2(Vector2(cell) * TILE, rock.get_size()), Rect2(Vector2.ZERO, rock.get_size()))
	for cell in bushes:
		cast(PLANTS, Rect2(tile_rect(cell.x, cell.y)), Rect2(tile_rect(1, 0)))
	for origin in furniture:
		var r := piece_rects(origin, furniture[origin])
		cast(FURNITURE_SHEET, r[0], r[1])
	for cell in trees:
		cast(TREES, Rect2(Vector2(cell.x, cell.y - 1) * TILE, Vector2(1, 2) * TILE), Rect2(Vector2(trees[cell], 0) * TILE, Vector2(1, 2) * TILE))
	for a in animals:
		cast(ANIMALS, Rect2((a.pos - Vector2.ONE * TILE / 2.0).round(), Vector2.ONE * TILE), animal_src(a))
	for c in people():
		var dst := Rect2((c.pos - Vector2.ONE * TILE / 2.0).round(), Vector2.ONE * TILE)
		var src := Rect2(Vector2(frame_of(c), c.facing) * TILE, Vector2.ONE * TILE)
		var foot := foot_of(COLONIST_BASE, src)  # tutti i livelli toccano terra dove toccano i piedi
		for layer in figure_layers(c):
			cast(layer[0], dst, layer_src(src, layer), foot)


# Disegna `src` di `tex` dov'è `dst`, ma coricato a terra da dove tocca terra (`ground`, in pixel dalla cima di `src`;
# se manca, dove la sagoma finisce): ogni pixel d'altezza va di sun_shadow.
func cast(tex: Texture2D, dst: Rect2, src: Rect2, ground := -1) -> void:
	var foot := Vector2(dst.get_center().x, dst.position.y + (ground if ground >= 0 else foot_of(tex, src)))
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
	for cell in built:  # muri e porte, dentro le loro caselle come i massi
		if built[cell][0] not in PAVING:
			draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), structure_src(cell, built[cell], [built]))
	for cell in boulders:  # stanno dentro le loro caselle: niente ordine per righe
		draw_texture(boulder_tex(cell), Vector2(cell) * TILE)
	for cell in bushes:  # bassi, dentro la loro casella come i massi; con le bacche se sono mature
		draw_texture_rect_region(PLANTS, tile_rect(cell.x, cell.y), tile_rect(2 if bushes[cell] <= clock else 1, 0))
	draw_pieces(self, FURNITURE_NIGHT if sun_height() < 0 else FURNITURE_SHEET, furniture)
	for room in rooms:  # cartelli: si cliccano per nome e tipo della stanza
		draw_texture(SIGN, Vector2(room.sign) * TILE)

	# alberi e coloni dall'alto in basso: chi sta più giù copre chi gli sta dietro
	# ponytail: si affida a `trees` già in ordine di riga; se gli alberi ricrescono, ordinarli o passare a nodi con y_sort
	for c in corpses:  # sdraiati e smorti, sotto chi è in piedi
		draw_set_transform(c.pos.round(), PI / 2)
		draw_figure(self, Rect2(-Vector2.ONE * TILE / 2.0, Vector2.ONE * TILE), Rect2(0, 0, TILE, TILE), c, CORPSE_SHADE)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	var queue: Array = people() + animals  # anche gli animali
	queue.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for cell in trees:
		while not queue.is_empty() and queue[0].pos.y < center(cell).y:
			draw_creature(queue.pop_front())
		draw_texture_rect_region(TREES, Rect2(Vector2(cell.x, cell.y - 1) * TILE, Vector2(1, 2) * TILE),
			Rect2(Vector2(trees[cell], 0) * TILE, Vector2(1, 2) * TILE))
	for c in queue:
		draw_creature(c)

	for cell in chop_marks:
		draw_mark(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), Order.CHOP)
	for origin in mine_marks:
		draw_mark(Rect2(Vector2(origin) * TILE, Vector2(boulders[origin]) * TILE), Order.MINE)
	for cell in uproot_marks:
		draw_mark(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), Order.UPROOT)
	for cell in harvest_marks:
		draw_mark(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), Order.HARVEST)
	for cell in fish_marks:
		draw_mark(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), Order.FISH)
	for a in animals:
		if a.marked:
			draw_mark(Rect2(a.pos - Vector2(TILE / 2.0, TILE * 1.25), Vector2.ONE * TILE), Order.HUNT)  # sopra la testa
	for c in people():
		if is_working(c):  # barra di avanzamento del lavoro
			draw_rect(Rect2(c.pos + Vector2(-6, -11), Vector2(12 * (1 - c.work_left / c.work_total), 2)), Color.YELLOW)
	if order == Order.BUILD and FURNITURE.has(build_kind):  # il prossimo mobile sotto il mouse, rosso se non ci sta
		var at := cell_of(get_global_mouse_position())
		var plan := [build_kind, build_res, build_turn]
		var fits := cells_in(piece_rect(at, plan)).all(func(k): return can_build(k, build_kind))
		draw_pieces(self, FURNITURE_SHEET, {at: plan}, Color(1, 1, 1, 0.6) if fits else Color(1, 0.3, 0.3, 0.6))
	if drag_start != null:
		var r := selection_rect()
		draw_rect(Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE), ORDER_COLORS[order], false, 1.0)


# Segno di un ordine: la sua icona a mezza misura, velata, al centro
func draw_mark(rect: Rect2, kind: Order) -> void:
	draw_texture_rect(ORDER_ICONS[kind], Rect2(rect.get_center() - Vector2.ONE * TILE / 4, Vector2.ONE * TILE / 2),
		false, Color(1, 1, 1, 0.6))


# Lente delle stanze: ogni stanza finita velata col colore del suo tipo, il tipo scritto in mezzo (senza tipo, niente)
# di notte, sopra il mondo scurito, i pixel accesi di abat-jour e lampioni (il resto di FURNITURE_GLOW è vuoto)
# ponytail: un colono che passa davanti a un lampione ci finisce sotto, la luce resta sopra
func draw_lights() -> void:
	if sun_height() < 0:
		draw_pieces(lights_canvas, FURNITURE_GLOW, furniture)


func draw_lens() -> void:
	var font := info_label.get_theme_font("font")
	for room in rooms:
		for cell in room.cells:
			lens_canvas.draw_rect(tile_rect(cell.x, cell.y), Color(ROOM_COLORS[room.kind], 0.35))
		var mid := room_mid(room)
		if room.kind != RoomKind.NONE:
			lens_canvas.draw_string(font, mid + Vector2(-TILE * 4, 4), RoomKind.keys()[room.kind].capitalize(),
				HORIZONTAL_ALIGNMENT_CENTER, TILE * 8, 12)


# Sotto il tipo, sulla lente, le figurine dei proprietari (o dei lavoratori): col mouse sopra, la loro scheda (vedi colonist_tip).
# Sono Control, se no niente suggerimento; si rifanno solo quando cambiano, se no il suggerimento sparirebbe
func place_owners() -> void:
	var now := rooms.map(func(r): return [room_mid(r), people_of(r).duplicate()])
	if now == lens_owners:
		return
	lens_owners = now
	for child in lens_canvas.get_children():
		child.free()
	for room in now:
		var owners: Array = room[1]
		for i in owners.size():
			var icon := Control.new()
			icon.set_script(TIP)
			icon.set("make_tip", colonist_tip.bind(owners[i]))
			icon.tooltip_text = full_name(owners[i])  # se vuoto il suggerimento non compare
			icon.mouse_filter = Control.MOUSE_FILTER_PASS
			icon.size = Vector2.ONE * TILE
			icon.position = room[0] + Vector2((i - owners.size() / 2.0) * TILE, 6)
			icon.draw.connect(draw_figure.bind(icon, Rect2(0, 0, TILE, TILE), Rect2(0, 0, TILE, TILE), owners[i]))
			lens_canvas.add_child(icon)


func room_mid(room: Room) -> Vector2:
	var mid := Vector2.ZERO
	for cell in room.cells:
		mid += center(cell)
	return mid / room.cells.size()


# Mobile `plan` in `origin`: [rettangolo nel mondo, rettangolo in FURNITURE_SHEET].
func piece_rects(origin: Vector2i, plan: Array) -> Array[Rect2]:
	var size := Vector2(piece_rect(origin, plan).size * TILE)
	var col: int = int(clock * DAY_LENGTH / ANIMATED[plan[0]]) % 4 if ANIMATED.has(plan[0]) else plan[2]  # fiamma, stoffa, acqua
	return [Rect2(Vector2(origin * TILE), size), Rect2(Vector2(col, plan[0] - Build.BED) * 32, size)]


# sprite del masso in `origin`: con le vene, se è di ferro o di carbone
func boulder_tex(origin: Vector2i) -> Texture2D:
	return ORE_ROCKS[ores[origin]] if ores.has(origin) else BOULDERS[boulders[origin]]


func draw_pieces(canvas: CanvasItem, sheet: Texture2D, layer: Dictionary, tint := Color.WHITE) -> void:
	for origin in layer:
		var r := piece_rects(origin, layer[origin])
		canvas.draw_texture_rect_region(sheet, r[0], r[1], tint)


func draw_creature(who) -> void:
	if who is Animal:
		draw_animal(who)
	else:
		draw_colonist(who)


# animale nel foglio ANIMALS, specchiato se guarda a sinistra
func draw_animal(a: Animal) -> void:
	var at := (a.pos - Vector2.ONE * TILE / 2.0).round()
	if a.left:
		draw_set_transform(at + Vector2(TILE, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect_region(ANIMALS, Rect2(Vector2.ZERO, Vector2.ONE * TILE), animal_src(a))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		draw_texture_rect_region(ANIMALS, Rect2(at, Vector2.ONE * TILE), animal_src(a))
	if a.damage > 0:
		draw_health(a.pos, 1.0 - a.damage / BEASTS[a.kind]["hp"])


# barretta della salute sopra la testa (sopra quella del lavoro): rossa sotto, verde quanto resta
func draw_health(pos: Vector2, part: float) -> void:
	draw_rect(Rect2(pos + Vector2(-6, -14), Vector2(12, 2)), Color("6e1f1f"))
	draw_rect(Rect2(pos + Vector2(-6, -14), Vector2(12 * clampf(part, 0.0, 1.0), 2)), Color("7db644"))


# fotogramma: fermo, o il passo alternato mentre cammina
func animal_src(a: Animal) -> Rect2:
	var step := 0 if a.path.is_empty() else int(a.walked / (TILE / 2.0)) % 2
	return Rect2(Vector2(step, a.kind) * TILE, Vector2.ONE * TILE)


func draw_colonist(c: Colonist) -> void:
	var at := (c.pos - Vector2.ONE * TILE / 2.0).round()  # allineato ai pixel
	var src := Rect2(Vector2(frame_of(c), c.facing) * TILE, Vector2.ONE * TILE)
	if c.downed:  # sdraiato, girato di un quarto
		draw_set_transform(c.pos.round(), PI / 2)
		draw_figure(self, Rect2(-Vector2.ONE * TILE / 2.0, Vector2.ONE * TILE), Rect2(0, 0, TILE, TILE), c)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		draw_figure(self, Rect2(at, Vector2.ONE * TILE), src, c)
	if c.hp < MAX_HP:
		draw_health(c.pos, c.hp / MAX_HP)
	if c.carrying > 0:
		draw_texture_rect(ICONS[c.carry_res], Rect2(at + Vector2(8, 6), Vector2(8, 8)), false)
	if c.job == Job.SLEEP and c.path.is_empty():  # ponytail: niente sprite sdraiato, solo una "z" che sale
		draw_string(ThemeDB.fallback_font, at + Vector2(11, 2 - fmod(clock * DAY_LENGTH, 2.0) * 2), "z",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	elif c.job == Job.TANTRUM:  # sfuriata: un punto esclamativo rosso che sobbalza
		draw_string(ThemeDB.fallback_font, at + Vector2(11, 3 - absf(sin(clock * DAY_LENGTH * 6)) * 2), "!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("ff5a5a"))


# il colono `c` (il fotogramma `src` dei fogli) in `dst` di `canvas`, un livello sull'altro (vedi figure_layers)
func draw_figure(canvas: CanvasItem, dst: Rect2, src: Rect2, c: Colonist, shade := Color.WHITE) -> void:
	for layer in figure_layers(c):
		canvas.draw_texture_rect_region(layer[0], dst, layer_src(src, layer), layer[2] * shade)


# Livelli dello sprite di `c`, dal basso: [foglio, voce del foglio (i 96x64 uno sotto l'altro), tinta].
# Corpo, maglia e mantello; l'armatura sopra la maglia; capelli, acconciatura e barba; il copricapo sopra i capelli;
# il corredo degli avventurieri; per ultimo quello che ha in mano (a mani vuote, nei lavori, un attrezzo qualunque)
func figure_layers(c: Colonist) -> Array:
	var layers := [[COLONIST_BASE, 0, Color.WHITE], [COLONIST_TUNIC, 0, c.tunic], [COLONIST_CAPE, 0, c.cape]]
	var body = c.gear.get(Slot.BODY)
	if body != null:
		layers.append([COLONIST_GEAR, GEAR[body]["look"], GEAR[body].get("tint", Color.WHITE)])
	layers.append([COLONIST_HAIR, 0, c.hair])
	if c.hair_style != Hair.SHORT:
		layers.append([COLONIST_HAIR_STYLES, c.hair_style - 1, c.hair])  # LONG -> 0, BRAID -> 1
	if c.beard:
		layers.append([COLONIST_HAIR_STYLES, BEARD, c.hair])
	var head = c.gear.get(Slot.HEAD)
	if head != null:
		var tint: Color = c.hood_tint if c.hood_tint != null and GEAR[head]["look"] == Look.HOOD else GEAR[head].get("tint", Color.WHITE)
		layers.append([COLONIST_GEAR, GEAR[head]["look"], tint])
	for k in c.kit:  # corredo degli avventurieri
		layers.append([COLONIST_GEAR, k, Color.WHITE])
	var hands = c.gear.get(Slot.HANDS)
	layers.append([COLONIST_HANDS, GEAR[hands]["look"] if hands != null else Held.TOOL, Color.WHITE])
	return layers


# il fotogramma `src` nella voce del foglio di `layer` (ogni voce: 4 direzioni, alte una casella)
func layer_src(src: Rect2, layer: Array) -> Rect2:
	return Rect2(src.position + Vector2(0, layer[1] * 4 * TILE), src.size)


func frame_of(c: Colonist) -> int:
	if not c.path.is_empty():
		return WALK_CYCLE[int(c.walked / (TILE / 2.0)) % WALK_CYCLE.size()]
	if is_working(c):
		return WORK_CYCLE[int((c.work_total - c.work_left) / SWING_TIME * WORK_CYCLE.size()) % WORK_CYCLE.size()]
	return IDLE_CYCLE[int(c.idle / BREATH_TIME * IDLE_CYCLE.size()) % IDLE_CYCLE.size()]


func center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2.ONE * TILE / 2.0


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i((pos / TILE).floor())
