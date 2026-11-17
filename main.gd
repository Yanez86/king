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
	RELAX, TANTRUM, TRAVEL, STUDY, GOVERN, PROTEST }
const WORK_JOBS := [Job.CHOP, Job.MINE, Job.UPROOT, Job.HAUL, Job.BUILD, Job.FURNISH, Job.HARVEST, Job.COOK, Job.FISH,
	Job.HUNT, Job.CRAFT, Job.STUDY, Job.GOVERN]  # contano come ore di lavoro
# VEG: vegetali, dalle bacche dei cespugli; IRON, COAL: dai massi con le vene; MEAL, FINE_MEAL: pasti, dalla cucina;
# MEAT, HIDE: carne e pelle, dagli animali cacciati; FISH: pesce, dai punti di pesca; INGOT: lingotti, dalla fornace;
# FLAX: lino, dai fiori (vedi flax); BOWSTRING: corda d'arco, dal filatoio;
# da PICKAXE in poi: equipaggiamento (vedi GEAR), dalla forgia e dai banchi (vedi RECIPES); GOLD: monete, per
# ingaggiare gli avventurieri (vedi send); DAGGER: il pugnale degli scassinatori, non si fabbrica; da CHALICE in poi
# i cimeli, dalle rovine: si piazzano come decorazioni (vedi RELICS); NOTEBOOK, TOME, CODEX: i libri, dalle rovine, che
# le ricerche di livello II, III e IV consumano (vedi BOOKS); HARDTACK: gallette, provviste per le spedizioni che non
# marciscono e non si mangiano a casa (vedi send); SMOKED_MEAT, SMOKED_FISH: affumicati al fuoco, crudi che durano
# quattro volte tanto; SHIELD: lo scudo tondo, nel suo slot (vedi GEAR); STEEL: acciaio, per attrezzi e spade (vedi
# steel); PARCHMENT, INK: pergamena e inchiostro, per copiare i quaderni allo scrittoio (vedi COPY_STUDY)
enum Res { WOOD, STONE, VEG, IRON, COAL, MEAL, FINE_MEAL, MEAT, FISH, HIDE, INGOT, FLAX, BOWSTRING,
	PICKAXE, AXE, SICKLE, BOW, LEATHER_ARMOR, LEATHER_HOOD, HELMET, CHAINMAIL, SWORD, GOLD, DAGGER,
	CHALICE, OLD_BANNER, BUST, CROWN, NOTEBOOK, TOME, CODEX, HARDTACK, SMOKED_MEAT, SMOKED_FISH, SHIELD,
	STEEL, PARCHMENT, INK }
const STACK_MAX := {Res.WOOD: 100, Res.STONE: 50, Res.VEG: 50, Res.IRON: 50, Res.COAL: 50, Res.MEAL: 20, Res.FINE_MEAL: 20,
	Res.MEAT: 50, Res.FISH: 50, Res.HIDE: 50, Res.INGOT: 50, Res.FLAX: 50, Res.BOWSTRING: 50, Res.PICKAXE: 10, Res.AXE: 10, Res.SICKLE: 10, Res.BOW: 10,
	Res.LEATHER_ARMOR: 10, Res.LEATHER_HOOD: 10, Res.HELMET: 10, Res.CHAINMAIL: 10, Res.SWORD: 10, Res.GOLD: 100, Res.DAGGER: 10,
	Res.CHALICE: 5, Res.OLD_BANNER: 5, Res.BUST: 5, Res.CROWN: 5, Res.NOTEBOOK: 10, Res.TOME: 10, Res.CODEX: 10, Res.HARDTACK: 50, Res.SMOKED_MEAT: 50, Res.SMOKED_FISH: 50, Res.SHIELD: 10, Res.STEEL: 50, Res.PARCHMENT: 50, Res.INK: 20}  # quantità massima per mucchio (casella)
const MEALS := [Res.FINE_MEAL, Res.MEAL]  # cotti: chi ha fame li prende in quest'ordine, poi il crudo
const RAW_FOOD := [Res.VEG, Res.FISH, Res.MEAT, Res.SMOKED_FISH, Res.SMOKED_MEAT]  # crudo: si cucina, o si mangia in quest'ordine se non ci sono pasti
const STASH := [Res.WOOD, Res.STONE, Res.VEG, Res.IRON, Res.COAL, Res.FLAX]  # scorta di debug: il resto si produce
const START_GOLD := 60      # monete nel magazzino all'inizio
const COIN := "[img=center]res://art/icon_coin.png[/img]"  # una moneta 16x16 nei testi ricchi (vedi coins)
# Tipo di ogni oggetto: la sua icona 16x16 (art/kind_*.png, per le monete la moneta) sta davanti al nome, ovunque
# (vedi item_name, item_title, kind_icon)
enum ItemKind { MATERIAL, FOOD, TOOL, WEAPON, ARMOR, COINS, RELIC, BOOK }
const KIND_NAMES := ["Material", "Food", "Tool", "Weapon", "Armor", "Coins", "Relic", "Book"]
const KIND_ICONS := {
	ItemKind.MATERIAL: preload("res://art/kind_material.png"), ItemKind.FOOD: preload("res://art/kind_food.png"),
	ItemKind.TOOL: preload("res://art/kind_tool.png"), ItemKind.WEAPON: preload("res://art/kind_weapon.png"),
	ItemKind.ARMOR: preload("res://art/kind_armor.png"), ItemKind.COINS: preload("res://art/icon_coin.png"),
	ItemKind.RELIC: preload("res://art/kind_relic.png"), ItemKind.BOOK: preload("res://art/kind_book.png"),
}
const ITEM_KIND := {
	Res.WOOD: ItemKind.MATERIAL, Res.STONE: ItemKind.MATERIAL, Res.IRON: ItemKind.MATERIAL, Res.COAL: ItemKind.MATERIAL,
	Res.HIDE: ItemKind.MATERIAL, Res.INGOT: ItemKind.MATERIAL, Res.FLAX: ItemKind.MATERIAL,
	Res.BOWSTRING: ItemKind.MATERIAL,
	Res.VEG: ItemKind.FOOD, Res.MEAL: ItemKind.FOOD, Res.FINE_MEAL: ItemKind.FOOD, Res.MEAT: ItemKind.FOOD, Res.FISH: ItemKind.FOOD,
	Res.PICKAXE: ItemKind.TOOL, Res.AXE: ItemKind.TOOL, Res.SICKLE: ItemKind.TOOL,
	Res.BOW: ItemKind.WEAPON, Res.SWORD: ItemKind.WEAPON, Res.DAGGER: ItemKind.WEAPON,
	Res.LEATHER_ARMOR: ItemKind.ARMOR, Res.LEATHER_HOOD: ItemKind.ARMOR, Res.HELMET: ItemKind.ARMOR, Res.CHAINMAIL: ItemKind.ARMOR,
	Res.GOLD: ItemKind.COINS,
	Res.CHALICE: ItemKind.RELIC, Res.OLD_BANNER: ItemKind.RELIC, Res.BUST: ItemKind.RELIC, Res.CROWN: ItemKind.RELIC,
	Res.NOTEBOOK: ItemKind.BOOK, Res.TOME: ItemKind.BOOK, Res.CODEX: ItemKind.BOOK, Res.HARDTACK: ItemKind.FOOD,
	Res.SMOKED_MEAT: ItemKind.FOOD, Res.SMOKED_FISH: ItemKind.FOOD, Res.SHIELD: ItemKind.ARMOR,
	Res.STEEL: ItemKind.MATERIAL, Res.PARCHMENT: ItemKind.MATERIAL, Res.INK: ItemKind.MATERIAL,
}
# cibo: quanto sazia (vedi eat) e in quanti giorni marcisce a terra fuori (vedi spoil); in magazzino ci mette il doppio.
# Il crudo sazia meno e può intossicare (vedi poison_chance), i pasti no e danno un bonus (vedi Cond)
const FOOD := {Res.VEG: 35.0, Res.FISH: 30.0, Res.MEAT: 40.0, Res.MEAL: 100.0, Res.FINE_MEAL: 100.0,
	Res.SMOKED_FISH: 30.0, Res.SMOKED_MEAT: 40.0}
const SHELF_LIFE := {Res.VEG: 3.0, Res.FISH: 1.5, Res.MEAT: 2.0, Res.MEAL: 3.0, Res.FINE_MEAL: 3.0,
	Res.SMOKED_FISH: 6.0, Res.SMOKED_MEAT: 8.0}  # affumicati: quattro volte il fresco
const SPOIL_STORED := 0.5   # in magazzino il cibo marcisce a metà velocità
const SPOIL_PANTRY := 1.0 / 3  # in dispensa a un terzo: dura il triplo che fuori
# probabilità di intossicarsi mangiando crudo: [appena preso, quasi marcio], in mezzo in proporzione
const POISON := {Res.VEG: [0.05, 0.4], Res.FISH: [0.1, 0.5], Res.MEAT: [0.15, 0.6], Res.SMOKED_FISH: [0.05, 0.5],
	Res.SMOKED_MEAT: [0.05, 0.6]}
const FRESH_WORDS := [[0.5, "Fresh"], [0.2, "Stale"], [0.0, "Almost rotten"]]  # sopra quale parte della durata, nel suggerimento
# cucinare (vedi try_cook): 2 crudi dello stesso mucchio (vegetali, pesce o carne) -> 1 pasto al fuoco da campo di una
# cucina, finché in giro ci sono meno pasti di quanti chiede il menu del fuoco (all'inizio MEALS_PER_COLONIST a testa)
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
# caccia (vedi try_hunt): animali che girano per la mappa; quelli segnati con "Hunt" li insegue un cacciatore con l'arco,
# che tira da al più HUNT_RANGE caselle. Ogni tiro: AIM_TIME a livello 5, colpisce con probabilità hit_chance; la freccia
# vola (vedi shoot) e, arrivata, l'animale scappa
enum Beast { RABBIT, DEER, WOLF }  # righe di ANIMALS
# "hp": danni per abbatterlo; "speed": caselle al secondo; "start": quanti all'inizio; i lupi ("hostile") arrivano in
# branco (vedi spawn_pack) e mordono ("bite": danno); "shadow": larghezza in pixel dell'ovale d'ombra sotto le zampe
const BEASTS := {
	Beast.RABBIT: {"hp": 10, "meat": 3, "hide": 1, "speed": 2.0, "start": 6, "shadow": 10},
	Beast.DEER: {"hp": 20, "meat": 10, "hide": 3, "speed": 1.5, "start": 3, "shadow": 12},
	Beast.WOLF: {"hp": 30, "meat": 5, "hide": 2, "speed": 3.0, "start": 0, "hostile": true, "bite": 8.0, "shadow": 12},
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
const ARROW_SPEED := 20.0   # caselle al secondo
const ARROW_ARC := 0.1      # altezza della parabola, per pixel di tiro
# combattimento (vedi react, Job.FIGHT, update_wolf): i lupi arrivano in branco dal bordo della mappa e inseguono i coloni
# fuori dalle stanze; chi sta bene combatte, chi è ferito scappa al chiuso. A 0 punti ferita si resta a terra, o si
# muore (vedi die): coi lupi, con le probabilità di DEATH_BASE; a terra, il primo morso uccide
const WOLF_FIRST := 4.0     # giorno del primo branco, contato da 0 (il quinto; vedi threats)
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
	Gift.SCHOLAR: {"trips": 1, "books": 2.0},
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
	Gift.SCHOLAR: "Learns from everything.\nGoes up a level after every expedition. The party finds books twice as often.",
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
# forziere (da-a), "finds" un oggetto per forziere, a caso tra questi [risorsa, quantità]; "books" il libro che c'è al
# posto dell'oggetto, una volta su BOOK_CHANCE (sempre, con "always"), a caso tra questi; "treasure" i libri che ci sono
# in più nel tesoro. In quest'ordine: all'inizio si conosce la prima, il tesoro di ognuna ha la mappa della successiva
# (e a volte un forziere qualunque, MAP_CHANCE)
enum RuinKind { TOWER, MINE, CRYPT, FORT, MONASTERY }
const RUINS := {
	RuinKind.TOWER: {"name": "Ruined tower", "danger": 1, "rooms": 3, "travel": 0.5, "gold": [10, 25],
		"finds": [[Res.WOOD, 10], [Res.STONE, 10], [Res.IRON, 5]], "books": [Res.NOTEBOOK], "treasure": [Res.NOTEBOOK, Res.NOTEBOOK]},
	RuinKind.MINE: {"name": "Abandoned mine", "danger": 2, "rooms": 5, "travel": 1.0, "gold": [20, 45],
		"finds": [[Res.IRON, 10], [Res.COAL, 10], [Res.INGOT, 4], [Res.PICKAXE, 1]], "books": [Res.NOTEBOOK],
		"treasure": [Res.NOTEBOOK, Res.NOTEBOOK]},
	RuinKind.CRYPT: {"name": "Crypt", "danger": 3, "rooms": 6, "travel": 1.0, "gold": [35, 70],
		"finds": [[Res.SWORD, 1], [Res.HELMET, 1], [Res.LEATHER_ARMOR, 1], [Res.INGOT, 6], [Res.CHALICE, 1], [Res.BUST, 1]],
		"books": [Res.NOTEBOOK, Res.TOME], "treasure": [Res.TOME]},
	RuinKind.FORT: {"name": "Ruined fort", "danger": 4, "rooms": 8, "travel": 2.0, "gold": [60, 120],
		"finds": [[Res.CHAINMAIL, 1], [Res.SWORD, 2], [Res.HELMET, 1], [Res.INGOT, 10], [Res.OLD_BANNER, 1], [Res.CROWN, 1]],
		"books": [Res.TOME, Res.TOME, Res.TOME, Res.CODEX], "treasure": [Res.CODEX]},
	RuinKind.MONASTERY: {"name": "Buried monastery", "danger": 3, "rooms": 6, "travel": 1.5, "gold": [5, 20],
		"finds": [], "books": [Res.NOTEBOOK, Res.NOTEBOOK, Res.TOME, Res.CODEX], "always": true, "treasure": [Res.TOME, Res.CODEX]},
}
const BOOK_CHANCE := 0.35   # un libro al posto dell'oggetto del forziere (lo studioso del gruppo la raddoppia)
const MAP_CHANCE := 0.15    # in un forziere qualunque, la mappa di una rovina che ancora non si conosce
const TREASURE_GOLD := 3    # il tesoro dell'ultima stanza: monete di tanti forzieri
const MAX_PARTY := 4        # avventurieri per spedizione
const HUNGER_HURT := 20.0   # punti ferita al giorno, a testa, senza provviste
enum Chamber { EMPTY, TRAP, MONSTERS, CHEST, COLLAPSE }  # cosa c'è in una stanza della rovina (vedi explore)
const CHAMBER_NAMES := ["an empty room", "a trap", "monsters", "a chest", "a collapse"]  # per Chamber, sulla bacheca
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
enum Slot { HANDS, BODY, HEAD, SHIELD }  # come HUD/ColonistSheet/Box/Equipment/Slots
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
		"info": "Needed to hunt. Aims with the better of Hunting and Ranged, +10% to hit, 2 more tiles of range. Shoots in a fight (damage 14)."},
	Res.SWORD: {"slot": Slot.HANDS, "skill": Skill.MELEE, "damage": 15.0, "look": Held.SWORD, "info": "A weapon. Melee damage 15."},
	Res.LEATHER_ARMOR: {"slot": Slot.BODY, "armor": 2, "outdoor_stress": 0.75, "look": Look.LEATHER_ARMOR, "info": "Light. 25% less stress working outdoors."},
	Res.LEATHER_HOOD: {"slot": Slot.HEAD, "armor": 1, "hit": 0.05, "look": Look.HOOD, "tint": Color("8a5a34"), "info": "Blends in: +5% to hit when hunting."},
	Res.HELMET: {"slot": Slot.HEAD, "armor": 3, "time": {Job.MINE: 0.9}, "look": Look.HELMET, "info": "Safe from falling rocks: mining 10% faster."},
	Res.CHAINMAIL: {"slot": Slot.BODY, "armor": 5, "slow": 1.1, "look": Look.CHAINMAIL, "info": "Heavy: all work 10% slower."},
	Res.SHIELD: {"slot": Slot.SHIELD, "armor": 3, "look": Look.SHIELD, "info": "Round, iron-rimmed: armor 3, only with a sword or a dagger."},
	Res.DAGGER: {"slot": Slot.HANDS, "skill": Skill.LOCKPICKING, "damage": 10.0, "look": Held.DAGGER,
		"info": "A burglar's knife. Melee damage 10."},
}
const KIT_ARMOR := {Look.SHIELD: 3}  # protezione del corredo degli avventurieri (vedi gear_sum)
# Produzione (vedi try_craft): [prodotto, mobile, abilità, ingredienti, secondi a livello 5, pezzi (se no 1)]. Il mobile dentro una stanza
# del tipo STATION_ROOM. Si fa ogni prodotto finché ce ne sono meno di quanti chiede il menu della postazione (vedi keep,
# open_craft), e i pezzi che mancano perché ogni colono abbia pieni i suoi slot (vedi gear_wanted); per uno slot, il
# primo in elenco di cui ci sono gli ingredienti.
# Come in cucina: tempo e rischio di rovinarlo (ingredienti persi, vedi burn_chance) secondo livello e comfort
const RECIPES := [
	[Res.INGOT, Build.FURNACE, Skill.SMITHING, {Res.IRON: 1, Res.COAL: 1}, 6.0],
	[Res.BOWSTRING, Build.SPINNING_WHEEL, Skill.TAILORING, {Res.FLAX: 2}, 8.0],  # filare il lino: lavoro da sarto
	[Res.LEATHER_ARMOR, Build.WORKBENCH, Skill.TAILORING, {Res.HIDE: 4}, 20.0],
	[Res.LEATHER_HOOD, Build.WORKBENCH, Skill.TAILORING, {Res.HIDE: 2}, 12.0],
	[Res.BOW, Build.CARPENTER_BENCH, Skill.RANGED, {Res.WOOD: 3, Res.BOWSTRING: 1}, 15.0],  # l'arco lo fa chi lo sa usare
	[Res.PICKAXE, Build.ANVIL, Skill.SMITHING, {Res.INGOT: 2, Res.WOOD: 2}, 15.0],
	[Res.AXE, Build.ANVIL, Skill.SMITHING, {Res.INGOT: 2, Res.WOOD: 2}, 15.0],
	[Res.SICKLE, Build.ANVIL, Skill.SMITHING, {Res.INGOT: 1, Res.WOOD: 1}, 10.0],
	[Res.HELMET, Build.ANVIL, Skill.SMITHING, {Res.INGOT: 3}, 20.0],
	[Res.CHAINMAIL, Build.ANVIL, Skill.SMITHING, {Res.INGOT: 6}, 30.0],
	[Res.SWORD, Build.ANVIL, Skill.SMITHING, {Res.INGOT: 3, Res.WOOD: 1}, 20.0],
	[Res.SHIELD, Build.ANVIL, Skill.SMITHING, {Res.WOOD: 3, Res.INGOT: 1}, 15.0],
	[Res.STEEL, Build.FURNACE, Skill.SMITHING, {Res.INGOT: 2, Res.COAL: 2}, 12.0],
	[Res.PARCHMENT, Build.WORKBENCH, Skill.TAILORING, {Res.HIDE: 1}, 10.0, 2],  # pelle raschiata e tesa
	[Res.INK, Build.WORKBENCH, Skill.RESEARCH, {Res.COAL: 1, Res.VEG: 1}, 8.0, 2],  # nerofumo e succo di bacche
	[Res.NOTEBOOK, Build.DESK, Skill.RESEARCH, {Res.PARCHMENT: 3, Res.INK: 1}, 30.0],  # una copia: anche COPY_STUDY
	[Res.COAL, Build.FURNACE, Skill.SMITHING, {Res.WOOD: 5}, 10.0, 2],  # carbonaia: legna cotta piano, senza aria
	[Res.HARDTACK, Build.CAMPFIRE, Skill.COOKING, {Res.VEG: 2}, 10.0],  # gallette
	[Res.SMOKED_MEAT, Build.CAMPFIRE, Skill.COOKING, {Res.MEAT: 1}, 8.0],  # affumicati
	[Res.SMOKED_FISH, Build.CAMPFIRE, Skill.COOKING, {Res.FISH: 1}, 8.0],
]
const STATION_ROOM := {Build.CAMPFIRE: RoomKind.KITCHEN, Build.FURNACE: RoomKind.FORGE, Build.ANVIL: RoomKind.FORGE, Build.WORKBENCH: RoomKind.WORKSHOP,
	Build.SPINNING_WHEEL: RoomKind.WORKSHOP, Build.CARPENTER_BENCH: RoomKind.CARPENTRY, Build.DESK: RoomKind.STUDY}
const STOCK := {Res.INGOT: 10, Res.BOWSTRING: 2, Res.MEAL: MEALS_PER_COLONIST * COLONIST_COUNT, Res.COAL: 5}  # scorte di partenza, vedi keep
enum Order { NONE, CHOP, MINE, UPROOT, BUILD, ERASE, DEMOLISH, HARVEST, FISH, HUNT }  # cosa segna il trascinamento del mouse
const ORDER_COLORS := [Color.TRANSPARENT, Color.ORANGE, Color("8fd3ff"), Color("9be36a"), Color("e6e2d0"),
	Color("ff5a5a"), Color("c83030"), Color("d84a6a"), Color("6ab0e0"), Color("c87a3a")]  # selezione e segni, per Order
# tasti in HUD/Tools/Row dopo Build, uno alla volta (ButtonGroup "Orders"): vedi toggle_order
const ORDER_TOOLS := {Order.DEMOLISH: "Destroy", Order.MINE: "Mine", Order.CHOP: "Chop", Order.UPROOT: "Uproot",
	Order.HARVEST: "Harvest", Order.FISH: "Fish", Order.HUNT: "Hunt"}
const ORDER_ICONS := {Order.CHOP: preload("res://art/icon_chop.png"), Order.MINE: preload("res://art/icon_mine.png"),
	Order.UPROOT: preload("res://art/icon_uproot.png"), Order.HARVEST: preload("res://art/icon_harvest.png"),
	Order.FISH: preload("res://art/icon_fishing.png"), Order.HUNT: preload("res://art/icon_hunting.png")}  # le stesse dei tasti: piccole e velate sopra ciò che è segnato
enum RoomKind { NONE, WAREHOUSE, BEDROOM, DORMITORY, KITCHEN, FORGE, WORKSHOP, CARPENTRY, INN, STUDY, THRONE_ROOM, PANTRY }  # tipo di stanza, scelto dal cartello
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
	RoomKind.CARPENTRY: RoomClass.WORK,
	RoomKind.INN: RoomClass.SERVICE,
	RoomKind.STUDY: RoomClass.WORK,
	RoomKind.THRONE_ROOM: RoomClass.WORK,  # un solo lavoratore possibile: il sovrano (vedi fill_people)
	RoomKind.PANTRY: RoomClass.SERVICE,  # un magazzino solo per il cibo, che ci dura di più (vedi spoil_rate)
}
# titolo della lista di coloni da spuntare nel popup del cartello, per RoomClass (le altre non ce l'hanno)
const ROOM_PEOPLE := {RoomClass.WORK: "Workers", RoomClass.RESIDENCE: "Owners"}
enum Build { WALL, FLOOR, DOOR, PATH, BED, TABLE, CHAIR, LAMP, CAMPFIRE, FURNACE, ANVIL, WORKBENCH,  # porta e mobili si attraversano
	SPINNING_WHEEL, CARPENTER_BENCH,
	FLOWER_BED, PLANTER, BENCH, BANNER, LANTERN, FOUNTAIN, STATUE,  # decorazioni: vedi SPLENDOR
	NOTICE_BOARD,  # la bacheca degli incarichi, nella locanda (vedi open_board)
	CHALICE, OLD_BANNER, BUST, CROWN,  # cimeli: decorazioni fatte con l'oggetto trovato nelle rovine (vedi RELICS)
	DESK, BOOKSHELF, THRONE,  # ricerca: scrittoio e libreria nello studio, trono nella sala del trono (vedi SEAT_ROOM)
	DUMMY,  # il fantoccio: ci si allena nel tempo libero (vedi relax)
	WATCHTOWER,  # la torre di guardia con la campana: lupi visti da lontano, l'arciere lassù tira meglio (vedi TOWER)
	CANOPY_BED, RUG, WARDROBE,  # arredo fine: il baldacchino è un letto (vedi BEDS), tappeto e armadio danno comfort
	ROAD,  # strada lastricata: ci si cammina più svelti (vedi ROAD_SPEED)
	PALISADE, GATE }  # palizzata e cancello: i lupi non passano; non fanno stanze (vedi update_rooms, beast_path)
# materiale per casella; per i mobili, per pezzo
const BUILD_COST := {Build.WALL: 5, Build.FLOOR: 2, Build.DOOR: 5, Build.PATH: 1, Build.BED: 10, Build.TABLE: 10, Build.CHAIR: 3,
	Build.LAMP: 3, Build.CAMPFIRE: 5, Build.FURNACE: 20, Build.ANVIL: 10, Build.WORKBENCH: 15, Build.SPINNING_WHEEL: 10,
	Build.CARPENTER_BENCH: 15, Build.FLOWER_BED: 3, Build.PLANTER: 5,
	Build.BENCH: 6, Build.BANNER: 4, Build.LANTERN: 4, Build.FOUNTAIN: 30, Build.STATUE: 40, Build.NOTICE_BOARD: 8,
	Build.CHALICE: 1, Build.OLD_BANNER: 1, Build.BUST: 1, Build.CROWN: 1, Build.DESK: 10, Build.BOOKSHELF: 12, Build.THRONE: 12, Build.ROAD: 2, Build.DUMMY: 6, Build.WATCHTOWER: 20,
	Build.CANOPY_BED: 20, Build.RUG: 4, Build.WARDROBE: 12,
	Build.PALISADE: 4, Build.GATE: 6}
# caselle occupate dai mobili come sono disegnati; girati di un quarto si scambiano larghezza e altezza (vedi piece_rect)
const FURNITURE := {Build.BED: Vector2i(2, 1), Build.TABLE: Vector2i(2, 2), Build.CHAIR: Vector2i.ONE, Build.LAMP: Vector2i.ONE,
	Build.CAMPFIRE: Vector2i.ONE, Build.FURNACE: Vector2i.ONE, Build.ANVIL: Vector2i.ONE, Build.WORKBENCH: Vector2i.ONE,
	Build.SPINNING_WHEEL: Vector2i.ONE, Build.CARPENTER_BENCH: Vector2i.ONE,
	Build.FLOWER_BED: Vector2i.ONE, Build.PLANTER: Vector2i.ONE, Build.BENCH: Vector2i(2, 1), Build.BANNER: Vector2i.ONE,
	Build.LANTERN: Vector2i.ONE, Build.FOUNTAIN: Vector2i(2, 2), Build.STATUE: Vector2i(2, 2), Build.NOTICE_BOARD: Vector2i.ONE,
	Build.CHALICE: Vector2i.ONE, Build.OLD_BANNER: Vector2i.ONE, Build.BUST: Vector2i.ONE, Build.CROWN: Vector2i.ONE,
	Build.DESK: Vector2i.ONE, Build.BOOKSHELF: Vector2i.ONE, Build.THRONE: Vector2i.ONE, Build.DUMMY: Vector2i.ONE,
	Build.WATCHTOWER: Vector2i.ONE, Build.CANOPY_BED: Vector2i(2, 1), Build.RUG: Vector2i(2, 1), Build.WARDROBE: Vector2i.ONE}
# mobili animati: secondi per fotogramma; i fotogrammi stanno nelle colonne dei quarti di giro (sono simmetrici)
const ANIMATED := {Build.CAMPFIRE: 0.15, Build.BANNER: 0.3, Build.FOUNTAIN: 0.2}
const ANY_MATERIAL := [Build.WALL, Build.FLOOR]  # di legno o di pietra
const BARRIERS := [Build.WALL, Build.PALISADE]  # solidi: si fanno solo lungo il bordo del riquadro, chiudono la strada
const PAVING := [Build.FLOOR, Build.PATH, Build.ROAD]  # a terra: si calpestano, ci stanno sopra i mobili, l'erba ci sborda sopra
# materiale fisso; il resto solo di legno
# i cimeli: la decorazione si fa con l'oggetto trovato nelle rovine, uno a pezzo
const RELICS := {Build.CHALICE: Res.CHALICE, Build.OLD_BANNER: Res.OLD_BANNER, Build.BUST: Res.BUST, Build.CROWN: Res.CROWN}
const BUILD_RES := {Build.PATH: Res.STONE, Build.ROAD: Res.STONE, Build.RUG: Res.HIDE, Build.FURNACE: Res.STONE, Build.ANVIL: Res.IRON, Build.PLANTER: Res.STONE, Build.FOUNTAIN: Res.STONE,
	Build.STATUE: Res.STONE, Build.CHALICE: Res.CHALICE, Build.OLD_BANNER: Res.OLD_BANNER, Build.BUST: Res.BUST, Build.CROWN: Res.CROWN}
# mobili che servono perché il cartello lasci scegliere il tipo di stanza: tipo -> {mobile: almeno quanti}
# ponytail: la cucina accetterà anche la stufa, quando ci sarà: allora "uno tra" invece di "tutti"
const ROOM_NEEDS := {
	RoomKind.BEDROOM: {Build.BED: 1},
	RoomKind.DORMITORY: {Build.BED: 2},
	RoomKind.KITCHEN: {Build.CAMPFIRE: 1},
	RoomKind.FORGE: {Build.FURNACE: 1, Build.ANVIL: 1},
	RoomKind.WORKSHOP: {Build.WORKBENCH: 1},
	RoomKind.CARPENTRY: {Build.CARPENTER_BENCH: 1},
	RoomKind.INN: {Build.BED: 1, Build.TABLE: 1, Build.NOTICE_BOARD: 1},
	RoomKind.STUDY: {Build.DESK: 1},
	RoomKind.THRONE_ROOM: {Build.THRONE: 1},
}
# lente delle stanze (tasto col cartello in basso): le stanze finite velate col colore del loro tipo, per RoomKind
const ROOM_COLORS := [Color("e6e2d0"), Color("c9a23b"), Color("3b8fd3"), Color("8a5ad3"), Color("e0703a"), Color("d33b3b"),
	Color("3bb08a"), Color("9be36a"), Color("d38a3b"), Color("6a9ae0"), Color("c48ad8"), Color("8fd8e8")]
# comfort di una stanza, 0-COMFORT_MAX: lo danno i mobili (per pezzo) e il pavimento (tutto se copre la stanza intera),
# per il materiale. A metà né bonus né malus; fuori dalle stanze è 0. Vedi room_comfort e comfort_of
const COMFORT_MAX := 10
const BEDS := [Build.BED, Build.CANOPY_BED]  # ci si dorme; per le camere il baldacchino vale un letto (vedi room_meets)
const COMFORT := {Build.CANOPY_BED: 2.0, Build.RUG: 1.0, Build.WARDROBE: 1.0, Build.FLOOR: 1.0, Build.BED: 1.0, Build.TABLE: 1.0, Build.CHAIR: 0.5, Build.LAMP: 0.5, Build.CAMPFIRE: 0.5,
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
# menù delle opzioni (Esc o ingranaggio), tab Keybindings: tasti di partenza dei comandi della barra in basso, per
# nome del pulsante in HUD/Tools/Row (quelli che non ci sono partono senza). Cambiati, si salvano: vedi bind_key
const DEFAULT_KEYS := {"Select": KEY_Q, "Build": KEY_B, "Destroy": KEY_X, "Mine": KEY_M, "Chop": KEY_C, "Uproot": KEY_U,
	"Harvest": KEY_H, "Fish": KEY_F, "Hunt": KEY_T, "Jobs": KEY_J, "Resources": KEY_I, "Knowledge": KEY_K, "Laws": KEY_G,
	"RoomsLens": KEY_L}
const FIXED_KEYS := [KEY_SPACE, KEY_1, KEY_2, KEY_3, KEY_E, KEY_R, KEY_ESCAPE]  # velocità, giro dei mobili, menù
const MODIFIER_KEYS := [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]  # da soli non sono un tasto
const TIP := preload("res://tip_button.gd")  # suggerimento fatto di Control: pulsanti di costruzione, figurine
const BUILD_INFO_COLOR := Color("d9c48a")
const BUILD_INFO := {
	Build.WALL: "Blocks the way. Walls with a door around an area make a room.",
	Build.FLOOR: "Paves the ground. Furniture can stand on it.",
	Build.DOOR: "Colonists walk through it. A room needs one to be entered.",
	Build.PATH: "A trodden earth path with pebbles. Grass grows over its edges.",
	Build.ROAD: "Stone slabs, fitted tight. Walking on them is 25% faster.",
	Build.PALISADE: "Sharpened stakes. Wolves cannot get through; it does not make a room.",
	Build.GATE: "A gate in the palisade: colonists and guests pass, wolves do not.",
	Build.BED: "A place to sleep. A bedroom needs one, a dormitory two.",
	Build.TABLE: "Where colonists eat and work.",
	Build.CHAIR: "Put it at a table, turned to face it.",
	Build.LAMP: "Lights up at night.",
	Build.CAMPFIRE: "A wood fire inside a ring of stones. Burns day and night. A kitchen needs one.",
	Build.FURNACE: "A stone furnace. A forge needs one, and an anvil. Smelts iron and coal into ingots.",
	Build.ANVIL: "An iron anvil on a stump. A forge needs one, and a furnace. Tools and metal armor are made here.",
	Build.WORKBENCH: "A sturdy bench. A workshop needs one. Leather armor is made here.",
	Build.SPINNING_WHEEL: "Spins flax into bowstrings. Works in a workshop.",
	Build.CARPENTER_BENCH: "A bench with a vise and a saw. A carpentry needs one. Bows are made here.",
	Build.FLOWER_BED: "A wooden box of soil and flowers.",
	Build.PLANTER: "A stone urn overflowing with flowers.",
	Build.BENCH: "A wooden bench to rest along the roads.",
	Build.BANNER: "The banner of your house, waving in the wind.",
	Build.LANTERN: "A lantern on a post. Lights up the roads at night.",
	Build.FOUNTAIN: "A stone basin with a jet of water. The pride of the square.",
	Build.STATUE: "The king in stone, hands on his sword, on a gilded plinth.",
	Build.NOTICE_BOARD: "Notices pinned to a board. An inn needs one, a bed and a table. Click it to hire adventurers.",
	Build.CHALICE: "A silver chalice set with a ruby, from a forgotten altar. Only adventurers find these, in ruins.",
	Build.OLD_BANNER: "A torn banner of a fallen house. Only adventurers find these, in ruins.",
	Build.BUST: "The stone face of a king nobody remembers. Only adventurers find these, in ruins.",
	Build.CROWN: "A jeweled crown on a velvet cushion. Only adventurers find these, in ruins.",
	Build.DESK: "An open book and a candle. A study needs one: colonists write study here, one at a time.",
	Build.BOOKSHELF: "Shelves of books. +10% study in the room, up to three.",
	Build.THRONE: "Where the ruler governs. A throne room needs one: the ruler gathers authority here.",
	Build.WATCHTOWER: "A wooden lookout with a bell: wolves are seen 20 tiles away. An archer standing on it shoots 2 tiles farther, +15% to hit.",
	Build.CANOPY_BED: "A bed fit for a ruler, under a purple canopy. Sleeps like a bed, with twice the comfort.",
	Build.RUG: "A rug of tanned hides. +1 comfort.",
	Build.WARDROBE: "An oak wardrobe. +1 comfort.",
	Build.DUMMY: "A straw dummy on a post. In their free time colonists train here: fun, and melee experience.",
}
enum Facing { DOWN, LEFT, RIGHT, UP }  # righe del foglio
enum TreeKind { OAK, PINE, BIRCH }     # colonne del foglio alberi
const TREE_LOGS := {TreeKind.OAK: 28, TreeKind.PINE: 35, TreeKind.BIRCH: 20}  # tronchi di un albero intero

# fogli 128x64 generati da tools/make_sprites.py; quelli con più voci le hanno una sotto l'altra (vedi figure_layers)
const COLONIST_BASE := preload("res://art/colonist_base.png")
const COLONIST_HAIR := preload("res://art/colonist_hair.png")
const COLONIST_TUNIC := preload("res://art/colonist_tunic.png")
const COLONIST_CAPE := preload("res://art/colonist_cape.png")
const COLONIST_HAIR_STYLES := preload("res://art/colonist_hair_styles.png")  # capelli lunghi, treccia, barba
const COLONIST_GEAR := preload("res://art/colonist_gear.png")    # armature, copricapi, corredo: Look
const COLONIST_HANDS := preload("res://art/colonist_hands.png")  # quello che tiene in mano: Held
const WALK_CYCLE := [0, 1, 0, 2]  # colonne del foglio: fermo, passo A, fermo, passo B
const WORK_CYCLE := [3, 3, 4]     # carica, carica, colpo: per ogni lavoro a tempo (taglio, scavo, costruzione)
const BOW_LOOSE := 6              # arco con la corda lenta: appena scoccato, poi lo tende (BOW_DRAW) fino al tiro
const BOW_DRAW := 7
const BOW_LOOSE_PART := 0.25      # parte del tempo di mira con la corda ancora lenta
const SWING_TIME := 0.6           # secondi per colpo
const IDLE_CYCLE := [0, 0, 5]     # fermo, fermo, respiro: chi non ha niente da fare
const BREATH_TIME := 2.0          # secondi per respiro
const LOOK_TIME := 3.0            # secondi, in media, tra un'occhiata e l'altra di chi è fermo
const TREES := preload("res://art/trees.png")  # 16x32 ciascuno: la chioma sale nella casella sopra
const PLANTS := preload("res://art/plants.png")  # 16x16: erbaccia, cespuglio, cespuglio con le bacche, lino, lino in fiore
const BOULDERS := {  # massi: dimensione in caselle -> sprite, dal più grande (ordine usato in generate_map)
	Vector2i(2, 2): preload("res://art/rock_2x2.png"),
	Vector2i(2, 1): preload("res://art/rock_2x1.png"),
	Vector2i(1, 1): preload("res://art/rock_1x1.png"),
}
const ORE_ROCKS := {Res.IRON: preload("res://art/rock_iron.png"), Res.COAL: preload("res://art/rock_coal.png")}  # massi 1x1
# 128x544, righe: mobili nell'ordine di Build; colonne: quarti di giro in senso orario, ognuno in un riquadro 32x32
const FURNITURE_SHEET := preload("res://art/furniture.png")
const FURNITURE_NIGHT := preload("res://art/furniture_night.png")  # abat-jour e lampioni accesi
const FURNITURE_GLOW := preload("res://art/furniture_glow.png")    # solo le luci accese, per `lights`
const SIGN := preload("res://art/sign.png")  # sul muro accanto alla porta d'ingresso di una stanza finita
const DAY_LENGTH := 240.0   # secondi per giorno a velocità 1x
const NIGHT := Color(0.25, 0.28, 0.5)
# luce sul mondo nelle 24 ore (0 = mezzanotte, 0.5 = mezzogiorno); l'interfaccia non cambia
const SKY := {0.0: NIGHT, 0.21: NIGHT, 0.25: Color(1.0, 0.7, 0.6), 0.31: Color.WHITE,
	0.69: Color.WHITE, 0.75: Color(1.0, 0.62, 0.45), 0.79: NIGHT, 1.0: NIGHT}
# Ombre col sole sempre a picco: ognuna sta sotto chi la fa e non si muove con l'ora. Mobili, alberi, rocce e cespugli
# ce l'hanno disegnata nello sprite (la "z" di tools/make_sprites.py); a coloni, animali e muri la aggiunge draw_shadows.
const SHADOW := Color("1f1a2460")  # come la "z" degli sprite, così tutte le ombre hanno lo stesso colore
const SHADOW_WIDTH := 10    # pixel: ovale sotto i piedi dei coloni (gli animali hanno il loro in BEASTS)
const SHADOW_WALL := 2      # righe d'ombra sotto muri e porte, dove sotto non c'è un altro muro
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
	Res.FLAX: preload("res://art/icon_flax.png"),
	Res.BOWSTRING: preload("res://art/icon_bowstring.png"),
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
	Res.NOTEBOOK: preload("res://art/icon_notebook.png"),
	Res.TOME: preload("res://art/icon_tome.png"),
	Res.CODEX: preload("res://art/icon_codex.png"),
	Res.HARDTACK: preload("res://art/icon_hardtack.png"),
	Res.SMOKED_MEAT: preload("res://art/icon_smoked_meat.png"),
	Res.SMOKED_FISH: preload("res://art/icon_smoked_fish.png"),
	Res.SHIELD: preload("res://art/icon_shield.png"),
	Res.STEEL: preload("res://art/icon_steel.png"),
	Res.PARCHMENT: preload("res://art/icon_parchment.png"),
	Res.INK: preload("res://art/icon_ink.png"),
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
enum Cond { POISONED, WELL_FED, FEASTED, AT_TABLE, ATE_RAW, MOURNING, FESTIVE, PILLORIED, HEARD }
const CONDITIONS_SHEET := preload("res://art/conditions.png")
const COND_INFO := {
	Cond.POISONED: [1.0, 1.5, 1.0, -20.0, "Ate raw food that was going bad. Works slowly."],
	Cond.WELL_FED: [0.5, 0.9, 0.75, 5.0, "Had a cooked meal. Works faster, less stress."],
	Cond.FEASTED: [0.5, 0.8, 0.5, 10.0, "Had a fine meal. Works much faster, much less stress."],
	Cond.AT_TABLE: [0.5, 1.0, 1.0, 5.0, "Ate sitting at a table."],
	Cond.ATE_RAW: [0.5, 1.0, 1.0, -10.0, "A glutton forced to eat raw food."],
	Cond.MOURNING: [3.0, 1.0, 1.25, -15.0, "A fellow colonist has died."],
	Cond.FESTIVE: [3.0, 1.0, 1.0, 10.0, "Celebrated the harvest feast."],
	Cond.PILLORIED: [1.0, 1.0, 1.0, -10.0, "Put in the stocks for a tantrum or a protest."],
	Cond.HEARD: [0.5, 1.0, 1.0, 10.0, "The ruler listened to their complaint."],
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
# punti abilità che un talento costa al sovrano, nella creazione: i pregi costano, i difetti ne danno; gli altri niente
const TRAIT_COST := {Trait.WORKAHOLIC: 2, Trait.TIRELESS: 2, Trait.EASYGOING: 2, Trait.ASCETIC: 2, Trait.SMALL_APPETITE: 2,
	Trait.LAZY: -2, Trait.HOTHEAD: -2, Trait.SLEEPYHEAD: -2, Trait.RESTLESS: -2, Trait.SLEEPWALKER: -2, Trait.GLUTTON: -2,
	Trait.FUN_LOVING: -2}
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
# Il sovrano (GDD 4.3): il primo colono, lo crea il giocatore (vedi creation.gd) coi RULER_POINTS punti abilità, al
# massimo RULER_SKILL_CAP per abilità. Senza (nei test) è uno a caso
const COLONY_NAMES := ["Valbruna", "Ashford", "Roccalta", "Greywater", "Montalto", "Fernhill", "Pietrabianca", "Oakmere"]
const RULER_POINTS := 12
const RULER_SKILL_CAP := 3
const RULER_TRAITS := 2     # talenti che si scelgono al massimo, mai due in contrasto (vedi TRAIT_CLASH)
# Titolo (GDD 4.3), indice di TITLES: signoria, baronia, contea, regno. È della casata e cresce, mai cala, quando lo
# splendore della colonia arriva a "splendor" (vedi tick, rise): cambiano il nome del reame, il titolo del sovrano (per
# Sex), la corona sullo stemma (vedi arms_texture), i sigilli delle leggi e l'autorità di ogni giorno (AUTHORITY_DAILY
# a titolo). Le leggi di una fascia ("tier" in LAWS) si codificano da quel titolo in su.
# ponytail: soglie provvisorie, e solo lo splendore: anche il numero di coloni quando la colonia potrà crescere
const TITLES := [
	{"realm": "Lordship", "ruler": ["Lord", "Lady"], "splendor": 0, "seals": 2},
	{"realm": "Barony", "ruler": ["Baron", "Baroness"], "splendor": 15, "seals": 3},
	{"realm": "County", "ruler": ["Count", "Countess"], "splendor": 35, "seals": 4},
	{"realm": "Kingdom", "ruler": ["King", "Queen"], "splendor": 60, "seals": 5},
]
const CROWN_IMG := "[img=center]res://art/icon_crown.png[/img]"
# Stemma della casata (GDD 4.3.2): {"shape", "division", "field", "field2", "ordinary", "ordinary_tincture", "charge",
# "charge_tincture"}: indici di queste liste (pezza e figura: 0 nessuna; gli smalti di Tincture). Lo compongono
# arms_texture (scudo 16x16) e banner_texture (il drappo dello stendardo): partizioni e pezze sono formule (vedi
# divided, on_ordinary), così vanno bene a ogni misura; forme e figure stanno in ARMS_SHEET
enum Tincture { OR, ARGENT, GULES, AZURE, VERT, SABLE, PURPURE }  # oro, argento (metalli); rosso, azzurro, verde, nero, porpora
const TINCTURE_COLORS := [Color("e8c040"), Color("ece8dc"), Color("b8302c"), Color("2f5cb0"), Color("3a8a3e"),
	Color("2a2630"), Color("7a3c8e")]
const METALS := [Tincture.OR, Tincture.ARGENT]
enum Shape { HEATER, SAMNITE, ROUND, LOZENGE }  # francese antico, sannitico, tondo, a losanga
enum Division { PLAIN, PALE, FESS, BEND, BEND_SINISTER, QUARTERLY, SALTIRE }  # pieno, partito, troncato, trinciato, tagliato, inquartato, in decusse
enum Ordinary { NONE, CHIEF, BASE, PALE, FESS, BEND, CROSS, SALTIRE, CHEVRON, BORDURE }  # capo, campagna, palo, fascia, banda, croce, decusse, scaglione, bordura
enum Charge { NONE, STAR, CRESCENT, FLEUR, ROSE, TOWER, CROWN, SWORD, KEY, TREE, EAGLE }
# passano dal centro, sotto la figura 8x8 che è più larga: col dado, niente figura
const CENTRAL := [Ordinary.PALE, Ordinary.FESS, Ordinary.BEND, Ordinary.CROSS, Ordinary.SALTIRE, Ordinary.CHEVRON]
# 80x35: forme 16x16 (bordo scuro, campo chiaro) in alto; figure 8x8 (per lo scudo) sotto; figure 5x5 (stendardo); in
# fondo le corone dei titoli
const ARMS_SHEET := preload("res://art/arms.png")
const ARMS_CROWN_Y := 29    # in ARMS_SHEET le corone 16x6 dei titoli (baronia, contea, regno), sotto le figure
const CROWN_RISE := 5       # di quanto la corona alza lo stemma: la sua ultima riga sta sul bordo dello scudo
const BANNER_DRAPE := preload("res://art/banner_drape.png")  # 64x16: il drappo nei 4 fotogrammi, chiaro e in ombra
const BANNER_SHADE := 0.75  # la piega in ombra del drappo
static var sheet_images := {}  # Texture2D -> Image, letta una volta: lo stemma si ricompone a ogni scelta (vedi image_of)


# --- Ricerca (GDD 4.7): il sapere (le ricerche) e le leggi ---
# Studio: allo scrittoio di una stanza Studio si scrivono pagine, una ogni PAGE_TIME a livello 5 di ricerca (vedi
# skill_time, comfort_time): ognuna +1 punto nel mucchio comune dello studio e +1 esperienza. Di notte (DARK_FROM-DARK_TO)
# senza un abat-jour nella stanza ci vuole NIGHT_STUDY volte tanto; ogni libreria nella stanza toglie SHELF_BONUS
# (al più SHELVES_MAX). Studiano prima i lavoratori della stanza, poi chi non ha altro da fare (vedi find_work)
const PAGE_TIME := 2.5
const DARK_FROM := 19
const DARK_TO := 6
const NIGHT_STUDY := 1.5
const SHELF_BONUS := 0.1
const SHELVES_MAX := 3
const SEAT_ROOM := {Build.DESK: RoomKind.STUDY, Build.THRONE: RoomKind.THRONE_ROOM}  # dove si studia e si governa
const STUDY_ICON := preload("res://art/icon_study.png")
const AUTHORITY_ICON := preload("res://art/icon_authority.png")
const BOOKS := [Res.NOTEBOOK, Res.TOME, Res.CODEX]  # il libro che consuma una ricerca di livello II, III, IV
# Erudito errante (GDD 4.7.2): con una locanda, ogni SCHOLAR_EVERY giorni (± SCHOLAR_JITTER) passa per un giorno; vende
# 1-2 libri (quaderni, a volte un tomo; mai codici) a BOOK_PRICE e ne compra uno a metà prezzo. Si tratta nella
# finestra Knowledge (vedi fill_knowledge). ponytail: un evento, non una figura che arriva alla locanda; e paga solo in
# monete (il GDD vuole anche il granaio)
const SCHOLAR_EVERY := 10.0
const SCHOLAR_JITTER := 2.0
const SCHOLAR_TOME := 0.25  # per ogni libro in vendita, la volta che è un tomo
const BOOK_PRICE := {Res.NOTEBOOK: 40, Res.TOME: 120, Res.CODEX: 300}
enum Branch { LAND, FIRE, STONE, IRON, ROAD, LORE }  # rami dell'albero, colonne di BRANCHES_SHEET
const BRANCHES_SHEET := preload("res://art/branches.png")
# Ricerche (colonne di TECHS_SHEET nell'ordine di Tech): "tier" livello 1-4, dal 2 costa anche un libro (BOOKS);
# "cost" punti studio; "needs" le ricerche che vengono prima. Sbloccano mobili ("builds"), ricette (i prodotti in
# "makes"), materiali da costruzione ("materials") e tipi di stanza ("rooms"). Quello che nessuna ricerca nomina c'è
# dall'inizio. Gli effetti senza oggetto (passo, viaggi) li guardano le funzioni che li nominano.
# ponytail: solo i nodi che hanno già qualcosa da sbloccare; gli altri dell'albero del GDD arrivano con le loro cose
enum Tech { FORGE, TAILORING, HUNTING, INN, MASONRY, DECOR, LANTERNS, IRON_ARMS, BOOKSHELF, CHAINMAIL, FOUNTAIN, STATUARY,
	CHARCOAL, COLD_STORE, PAVED_ROAD, DRY_RATIONS, CARTOGRAPHY, PALISADE, TRAINING_DUMMY, SMOKEHOUSE, RENOWNED_INN, WATCHTOWER,
	SHIELD, LENDING_ARMORY, STEEL, SCRIPTORIUM, FINE_FURNITURE }
const TECHS_SHEET := preload("res://art/techs.png")
const TECHS := {
	Tech.FORGE: {"branch": Branch.FIRE, "tier": 1, "cost": 60, "builds": [Build.FURNACE, Build.ANVIL],
		"makes": [Res.INGOT, Res.PICKAXE, Res.AXE, Res.SICKLE], "info": "Furnace, anvil and the forge: ingots and the first tools."},
	Tech.TAILORING: {"branch": Branch.FIRE, "tier": 1, "cost": 50, "builds": [Build.WORKBENCH],
		"makes": [Res.LEATHER_ARMOR, Res.LEATHER_HOOD], "info": "The workbench and the workshop: leather armor and hoods."},
	Tech.HUNTING: {"branch": Branch.LAND, "tier": 1, "cost": 50, "builds": [Build.SPINNING_WHEEL, Build.CARPENTER_BENCH],
		"makes": [Res.BOWSTRING, Res.BOW], "info": "Spinning wheel, carpenter bench and carpentry: bowstrings and bows."},
	Tech.INN: {"branch": Branch.ROAD, "tier": 1, "cost": 40, "builds": [Build.NOTICE_BOARD],
		"info": "The notice board and the inn: adventurers come and go to the ruins. Books come from there."},
	Tech.MASONRY: {"branch": Branch.STONE, "tier": 1, "cost": 60, "materials": [Res.STONE],
		"info": "Stone walls and floors: more comfort."},
	Tech.DECOR: {"branch": Branch.STONE, "tier": 1, "cost": 40, "builds": [Build.FLOWER_BED, Build.PLANTER, Build.BENCH],
		"info": "Flower bed, planter and bench: the first splendor."},
	Tech.LANTERNS: {"branch": Branch.LORE, "tier": 1, "cost": 40, "builds": [Build.LAMP, Build.LANTERN],
		"info": "Lamp and lantern: light at night. In the dark, study takes half as long again."},
	Tech.IRON_ARMS: {"branch": Branch.IRON, "tier": 1, "cost": 80, "needs": [Tech.FORGE], "makes": [Res.SWORD, Res.HELMET],
		"info": "At the anvil: sword and helmet."},
	Tech.BOOKSHELF: {"branch": Branch.LORE, "tier": 1, "cost": 60, "builds": [Build.BOOKSHELF],
		"info": "Bookshelves: +10% study in the room, up to three."},
	Tech.CHAINMAIL: {"branch": Branch.IRON, "tier": 2, "cost": 300, "needs": [Tech.IRON_ARMS], "makes": [Res.CHAINMAIL],
		"info": "At the anvil: chainmail."},
	Tech.FOUNTAIN: {"branch": Branch.STONE, "tier": 2, "cost": 250, "needs": [Tech.DECOR], "builds": [Build.FOUNTAIN],
		"info": "The fountain, the pride of the square."},
	Tech.STATUARY: {"branch": Branch.STONE, "tier": 3, "cost": 500, "needs": [Tech.FINE_FURNITURE], "builds": [Build.STATUE],
		"info": "The king in stone, on a gilded plinth."},
	Tech.CHARCOAL: {"branch": Branch.FIRE, "tier": 1, "cost": 80, "makes": [Res.COAL],
		"info": "At the furnace, 5 wood make 2 coal: coal not only from the veins."},
	Tech.COLD_STORE: {"branch": Branch.LAND, "tier": 1, "cost": 100, "rooms": [RoomKind.PANTRY],
		"info": "The pantry, a cool room only for food: it keeps three times as long as outside (twice in a warehouse)."},
	Tech.PAVED_ROAD: {"branch": Branch.STONE, "tier": 1, "cost": 60, "builds": [Build.ROAD],
		"info": "Stone slabs: walking on them is 25% faster, and colonists choose them."},
	Tech.DRY_RATIONS: {"branch": Branch.ROAD, "tier": 1, "cost": 80, "makes": [Res.HARDTACK],
		"info": "At the campfire, hardtack from 2 vegetables: worth 2 provisions on an expedition, and it never spoils."},
	Tech.CARTOGRAPHY: {"branch": Branch.ROAD, "tier": 1, "cost": 80, "needs": [Tech.INN],
		"info": "The notice board shows the next room of every ruin. The way to the ruins is 25% shorter."},
	Tech.PALISADE: {"branch": Branch.IRON, "tier": 1, "cost": 80, "builds": [Build.PALISADE, Build.GATE],
		"info": "Palisade and gate: wolves cannot get through."},
	Tech.TRAINING_DUMMY: {"branch": Branch.IRON, "tier": 1, "cost": 60, "builds": [Build.DUMMY],
		"info": "The training dummy: in their free time colonists train there, for fun and melee experience."},
	Tech.SMOKEHOUSE: {"branch": Branch.LAND, "tier": 2, "cost": 200, "needs": [Tech.HUNTING],
		"makes": [Res.SMOKED_MEAT, Res.SMOKED_FISH], "info": "At the campfire, smoked meat and fish: they keep four times as long."},
	Tech.RENOWNED_INN: {"branch": Branch.ROAD, "tier": 2, "cost": 250, "needs": [Tech.INN],
		"info": "Adventurers come every day and a half and wait 5 days. On the notice board, ask for a class: the next one is that."},
	Tech.SHIELD: {"branch": Branch.IRON, "tier": 2, "cost": 250, "needs": [Tech.TRAINING_DUMMY], "makes": [Res.SHIELD],
		"info": "At the anvil, the round shield: armor 3 for whoever fights with a sword or a dagger."},
	Tech.LENDING_ARMORY: {"branch": Branch.ROAD, "tier": 2, "cost": 250, "needs": [Tech.DRY_RATIONS],
		"info": "Adventurers borrow better armor, helmets and shields from the warehouses for an expedition, and bring them back (unless they die)."},
	Tech.STEEL: {"branch": Branch.FIRE, "tier": 2, "cost": 300, "needs": [Tech.FORGE], "makes": [Res.STEEL],
		"info": "At the furnace, steel from 2 ingots and 2 coal. Tools and swords are made of steel: tools 40% faster, swords damage 20."},
	Tech.SCRIPTORIUM: {"branch": Branch.LORE, "tier": 2, "cost": 250, "needs": [Tech.BOOKSHELF], "makes": [Res.PARCHMENT, Res.INK, Res.NOTEBOOK],
		"info": "Parchment (from hides) and ink (coal and berries) at the workbench; at the desk notebooks are copied: 3 parchment, 1 ink, 150 study."},
	Tech.FINE_FURNITURE: {"branch": Branch.STONE, "tier": 2, "cost": 250, "needs": [Tech.MASONRY], "builds": [Build.CANOPY_BED, Build.RUG, Build.WARDROBE],
		"info": "Canopy bed, rug and wardrobe: the ruler's fine chamber."},
	Tech.WATCHTOWER: {"branch": Branch.IRON, "tier": 2, "cost": 300, "needs": [Tech.PALISADE], "builds": [Build.WATCHTOWER],
		"info": "The watchtower and its bell: wolves are seen 20 tiles away. An archer up there shoots 2 tiles farther, +15% to hit."},
}
const ROAD_SPEED := 1.25    # sulla strada lastricata si va più svelti
const MAPPED_TRAVEL := 0.75 # con la cartografia, giorni di viaggio x
const HARDTACK_FOOD := 2    # provviste che vale una galletta
# Autorità: il sovrano la raccoglie governando dal trono (Job.GOVERN, in una sala del trono), AUTHORITY_PER_HOUR all'ora,
# di più se è sereno e di meno se è cupo (RULER_MOODS: da quanta felicità, quanto); in più ogni giorno AUTHORITY_DAILY
# per titolo (signoria 1, regno 4) e uno ogni SPLENDOR_PER_AUTHORITY di splendore. Si spende per codificare le leggi,
# una volta, e per promulgarle (ENACT_COST) su un sigillo libero: tante leggi in vigore insieme quanti i "seals" del titolo
const AUTHORITY_PER_HOUR := 1.0
const RULER_MOODS := [[70.0, 1.25], [30.0, 0.5]]  # sopra la prima soglia governa meglio, sotto la seconda peggio
const AUTHORITY_DAILY := 1.0
const SPLENDOR_PER_AUTHORITY := 20
const ENACT_COST := 10.0
const REVOKE_WAIT := 3.0    # giorni prima di poter ripromulgare una legge revocata
enum Law { EXEMPTION, TITHE, LOOT_TAX, LODGING_TAX, LONG_SHIFTS, SHORT_DAY, DAY_OF_REST, CURFEW, HARVEST_FEAST, TALLAGE, TRIBUTE, OPEN_GRANARY,
	TOLL, NIGHT_WATCH, MILITIA,
	HARSH_PUNISHMENT, CLEMENCY, HUNTING_RESERVE, COURT }
const LAWS_SHEET := preload("res://art/laws.png")  # colonne nell'ordine di Law
enum LawKind { TREASURY, WORK, ORDER, CROWN, FEASTS }
# Leggi: "kind" categoria; "cost" autorità per codificarla; "tier" il titolo che serve (di TITLES, se no la signoria);
# "group" in vigore una sola dello stesso gruppo; "needs" la ricerca che serve; "after" la legge da codificare prima.
# "mood": felicità di chi è in colonia finché è in vigore (vedi law_mood): "all" a tutti i coloni, un Trait al posto di
# "all" a chi ce l'ha, "guests" agli avventurieri, "ruler" al sovrano, "hunters" a chi ha l'arco (vedi law_mood_of).
# Le altre cose le fanno le funzioni che le nominano.
# ponytail: solo le leggi che usano cose che ci sono già; le altre del GDD arrivano coi loro sistemi
const LAWS := {
	Law.EXEMPTION: {"kind": LawKind.TREASURY, "cost": 30, "group": "taxes", "mood": {"all": 5.0}, "info": "No tithe: the granary stays empty."},
	Law.TITHE: {"kind": LawKind.TREASURY, "cost": 40, "group": "taxes", "mood": {"all": -3.0},
		"info": "One piece in ten of what is gathered, hunted, fished, cooked and made goes to the crown's granary."},
	Law.TALLAGE: {"kind": LawKind.TREASURY, "tier": 1, "cost": 100, "group": "taxes", "after": Law.TITHE, "mood": {"all": -8.0},
		"info": "One piece in five of what is gathered, hunted, fished, cooked and made goes to the crown's granary."},
	Law.LOOT_TAX: {"kind": LawKind.TREASURY, "cost": 40, "needs": Tech.INN, "mood": {"guests": -5.0},
		"info": "Adventurers keep 20% of the gold they find, not 30%. A quarter fewer come, and the greedy stay away."},
	Law.LODGING_TAX: {"kind": LawKind.TREASURY, "cost": 30, "needs": Tech.INN, "mood": {"guests": -3.0},
		"info": "Every adventurer waiting at the inn pays a coin a night, and stays a day less."},
	Law.OPEN_GRANARY: {"kind": LawKind.TREASURY, "tier": 1, "cost": 60, "after": Law.TITHE, "mood": {"all": 4.0},
		"info": "With no food left in the warehouses, the granary feeds the colony. Every new season, a meal for everyone."},
	Law.TOLL: {"kind": LawKind.TREASURY, "tier": 1, "cost": 80, "needs": Tech.PALISADE, "mood": {"guests": -3.0},
		"info": "Every adventurer coming in pays 2 coins at the gate. A fifth fewer come."},
	Law.TRIBUTE: {"kind": LawKind.TREASURY, "tier": 2, "cost": 150, "mood": {"all": -4.0},
		"info": "The colonists' loyalty is the crown's: +1 authority a day for each of them."},
	Law.LONG_SHIFTS: {"kind": LawKind.WORK, "cost": 40, "group": "shifts",
		"mood": {"all": -5.0, Trait.WORKAHOLIC: 3.0, Trait.LAZY: -10.0, Trait.FUN_LOVING: -10.0, Trait.RESTLESS: -10.0},
		"info": "Up to 10 hours of work a day (the lazy 7). Stress from work +25%."},
	Law.SHORT_DAY: {"kind": LawKind.WORK, "cost": 40, "group": "shifts", "mood": {"all": 8.0, Trait.WORKAHOLIC: -5.0},
		"info": "At most 6 hours of work a day. Stress from work -25%."},
	Law.DAY_OF_REST: {"kind": LawKind.WORK, "cost": 30, "mood": {"all": 6.0, Trait.WORKAHOLIC: -5.0, Trait.ASCETIC: 0.0},
		"info": "Every seventh day nobody works but the cooks: the rest is free time."},
	Law.NIGHT_WATCH: {"kind": LawKind.WORK, "tier": 1, "cost": 80, "needs": Tech.PALISADE,
		"mood": {Trait.NIGHT_OWL: 5.0, Trait.SLEEPYHEAD: -5.0},
		"info": "A colonist keeps watch at night (a night owl first, or someone who sleeps by day): wolves are seen as soon as they come."},
	Law.MILITIA: {"kind": LawKind.ORDER, "cost": 50, "needs": Tech.TRAINING_DUMMY, "mood": {"all": -3.0, Trait.HOTHEAD: 3.0},
		"info": "An hour a day of free time at the training dummy. Colonists flee only under 30 health, not 40."},
	Law.HARSH_PUNISHMENT: {"kind": LawKind.ORDER, "tier": 1, "cost": 80, "group": "justice", "mood": {"all": -2.0, Trait.HOTHEAD: -10.0},
		"info": "Tantrums and protests end in the stocks (-10 happiness for a day), and protests cost no authority. Hotheads, afraid, storm off a third less often."},
	Law.CLEMENCY: {"kind": LawKind.ORDER, "tier": 1, "cost": 80, "group": "justice", "mood": {"all": 3.0, Trait.HOTHEAD: 5.0},
		"info": "Tantrums last an hour. The ruler listens to whoever protests: an hour, no authority lost, +10 happiness for half a day."},
	Law.HUNTING_RESERVE: {"kind": LawKind.ORDER, "tier": 1, "cost": 100, "mood": {"all": -3.0, "hunters": 3.0},
		"info": "Twice as many deer, hunted only by the ruler and by those who carry a bow. +3 authority for every deer the ruler takes."},
	Law.COURT: {"kind": LawKind.CROWN, "tier": 1, "cost": 100, "mood": {"ruler": 5.0},
		"info": "The ruler no longer works: only governs, and audiences give 50% more authority."},
	Law.CURFEW: {"kind": LawKind.ORDER, "cost": 40, "mood": {"all": -2.0, Trait.FUN_LOVING: -10.0, Trait.EARLY_BIRD: 3.0},
		"info": "From 21 everyone goes to bed: no evenings at the campfire, fewer targets for the wolves."},
	Law.HARVEST_FEAST: {"kind": LawKind.FEASTS, "cost": 40,
		"info": "The last day of every season is a feast: nobody works but the cooks. Then +10 happiness for 3 days, +5 authority."},
}
const SHIFTS := {Law.LONG_SHIFTS: [10.0, 1.25], Law.SHORT_DAY: [6.0, 0.75]}  # ore di lavoro al giorno, stress da lavoro x
const TAXES := {Law.TITHE: 0.1, Law.TALLAGE: 0.2}  # parte di quello che si produce che va al granaio della corona (vedi produce)
const LOOT_SHARE := 0.2     # quota delle monete degli avventurieri con la gabella sul bottino (se no SHARE)
const LOOT_TAX_WAIT := 4.0 / 3  # con la gabella: giorni tra un arrivo e l'altro x
const REST_EVERY := 7       # riposo festivo: l'ultimo giorno di ogni tanti
const SEASON_DAYS := 10     # ponytail: finché non ci sono le stagioni, la festa del raccolto è l'ultimo giorno di ogni tanti
const FEAST_AUTHORITY := 5.0
const TOLL := 2             # monete del pedaggio, per avventuriero che arriva
const TOLL_WAIT := 1.25     # col pedaggio: giorni tra un arrivo e l'altro x (un quinto in meno)
const MILITIA_FLEE := 30.0  # con la milizia si scappa sotto questi punti ferita (se no FLEE_HP)
const HARSH_STRESS := 2.0 / 3  # con le pene severe, stress dal lavoro x per l'iracondo: sfuriate un terzo meno spesso
const CLEMENT_HOURS := 1.0  # con la clemenza sfuriate e proteste durano tanto
const COURT_AUDIENCE := 1.5 # con la corte, autorità dall'udienza x
const RESERVE_AUTHORITY := 3.0  # riserva di caccia: per ogni cervo abbattuto dal sovrano
const TRAIN_HIT := 2.5      # secondi per colpo al fantoccio: +1 esperienza in mischia
const STEEL_GEAR := [Res.PICKAXE, Res.AXE, Res.SICKLE, Res.SWORD]  # con l'acciaio: si fanno d'acciaio, e rendono di più
const STEEL_TIME := 0.6     # attrezzo d'acciaio: tempo del suo lavoro x (quelli di ferro 0.75)
const STEEL_SWORD := 20.0   # danno della spada d'acciaio
const COPY_STUDY := 150.0   # punti studio di una copia di un quaderno allo scrittoio, oltre a pergamena e inchiostro
const TOWER_SIGHT := 20     # caselle: con una torre di guardia (e la sua campana) i lupi si vedono da qui (se no ALERT)
const TOWER := {"range": 2.0, "hit": 0.15}  # all'arciere sulla torre, in più (vedi gear_sum)
const RENOWNED_GUESTS := [1.5, 5.0]  # con la locanda rinomata: giorni tra un arrivo e l'altro, giorni che aspettano
# Eventi (GDD 4.7.4): autorità data o tolta una volta (mai sotto zero, vedi gain)
const TREASURE_AUTHORITY := 5.0  # spedizione tornata col tesoro dell'ultima stanza
const RELIC_AUTHORITY := 3.0     # cimelio posato
const DEATH_AUTHORITY := -5.0    # colono morto
const UNHAPPY := 20.0            # all'alba, -1 autorità per ogni colono sotto questa felicità
# Protesta (GDD 4.7.5): un colono sotto UNHAPPY di felicità che disapprova almeno PROTEST_LAWS leggi in vigore molla
# il lavoro e va a lamentarsi nella sala del trono per PROTEST_HOURS; una volta al giorno al più. Toglie autorità
const PROTEST_LAWS := 2
const PROTEST_HOURS := 2.0
const PROTEST_AUTHORITY := -5.0
# All'inizio, su ogni mappa, un'arma abbandonata accanto ai resti di un bivacco, tra FOUND_WEAPON_REACH caselle dalla radura
const FOUND_WEAPONS := [Res.SWORD, Res.AXE, Res.BOW]
const FOUND_WEAPON_REACH := [15, 25]


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
	var drilled := -1             # il giorno dell'ultima ora di milizia al fantoccio (vedi relax)
	var protested := -1           # il giorno dell'ultima protesta (vedi protest)
	var lent := {}                # Slot -> il suo pezzo (o null) al posto del quale porta quello prestato (vedi lend)
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


# Freccia in volo, vedi shoot e fly
class Arrow:
	var pos: Vector2
	var from: Vector2
	var prey                      # l'Animal a cui è tirata
	var by                        # il Colonist che l'ha tirata
	var damage := 0.0             # 0: tiro mancato, finisce in `miss`
	var miss: Vector2


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
var flax := {}              # cella -> true: i cespugli che sono lino; in fiore (le "bacche") danno il lino
var weeds := {}             # cella -> true: erbacce (attraversabili)
var chop_marks := {}        # cella -> true: alberi da tagliare
var mine_marks := {}        # cella d'origine -> true: massi da scavare
var uproot_marks := {}      # cella -> true: erbacce e cespugli da estirpare
var harvest_marks := {}     # cella -> true: cespugli da cui raccogliere le bacche, ogni volta che maturano
var fish_marks := {}        # cella d'acqua -> true: punti di pesca
var fish_spots := {}        # cella d'acqua -> `clock` da cui ci sono di nuovo pesci (se manca, ci sono)
var animals: Array[Animal] = []
var arrows: Array[Arrow] = []  # in volo, vedi shoot
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
var study := 0.0            # punti studio: il mucchio comune, scritto allo scrittoio (vedi Job.STUDY), speso nelle ricerche
var researched := {}        # Tech -> true: le ricerche fatte (vedi research)
var authority := 0.0        # raccolta dal sovrano sul trono (vedi Job.GOVERN), spesa nelle leggi
var codified := {}          # Law -> true: si può promulgare (vedi codify)
var enacted: Array = []     # Law in vigore, al più i sigilli del titolo (vedi enact)
var rank := 0               # il titolo, indice di TITLES: cresce con lo splendore (vedi rise)
var revoked := {}           # Law -> `clock` da cui si può ripromulgare
var granary := {}           # Res -> quantità: il granaio della corona, riempito dalla decima (vedi produce)
var tithe_owed := {}        # Res -> parte di pezzo dovuta alla decima, che si accumula finché non fa un pezzo intero
var today := 0              # il giorno visto per ultimo: cambiato, è l'alba di uno nuovo (vedi new_day)
var hour := 0               # lo stesso per l'ora (vedi new_hour)
var knowledge_key := ""     # quello che mostra la finestra Knowledge: se cambia, la si rifà (vedi fill_knowledge)
var next_scholar := SCHOLAR_EVERY  # `clock` del prossimo passaggio dell'erudito (vedi update_scholar)
var scholar_until := -1.0   # `clock` fino a cui l'erudito è alla locanda
var scholar_books: Array = []  # Res che ha ancora da vendere
var scholar_bought := false # ha già comprato il suo libro, a questo passaggio
var wanted_hero := Hero.NONE  # l'avviso sulla bacheca (locanda rinomata): la classe di chi arriva; NONE chiunque
var laws_key := ""          # lo stesso per la finestra Laws
var items := {}  # risorsa -> (cella -> quantità a terra; nel magazzino = stoccata): un dizionario per Res, vedi _init  # risorsa -> (cella -> quantità a terra; nel magazzino = stoccata)
var fresh := {}             # cella -> giorni (a terra fuori) prima che il mucchio di cibo marcisca, vedi spoil
var stockpile := {}         # cella -> true: dentro le stanze di tipo magazzino o dispensa, vedi update_stockpile
var pantry := {}            # cella -> true: le caselle di stockpile nelle dispense, solo per il cibo
var rooms: Array[Room] = []  # stanze finite, vedi update_rooms
var rooms_made := 0         # per i nomi di default
var editing: Room           # la stanza aperta nel popup del cartello
var keep := STOCK.duplicate()  # prodotto -> quanti tenerne (a terra, in magazzino, in mano): si cambia nel menu della postazione
var crafting := Vector2i(-1, -1)  # la postazione aperta nel menu, vedi open_craft
var shown: Colonist         # il colono nella scheda: le barre dei bisogni lo seguono
var lens_owners := []       # [centro, proprietari o lavoratori] per stanza delle figurine sulla lente, vedi place_owners
var needs_rate := 1.0       # 0 nei test: i bisogni restano fermi e non cambiano i lavori
var routines := true        # false nei test: niente orari né ore massime, chi è libero prende il primo lavoro
var start_rooms := true     # false nei test: mappa di sempre, senza stanze né scorte di partenza (va messo prima di _ready)
var settings_file := "user://settings.cfg"  # "" nei test: tasti di partenza, niente da leggere né da salvare
var hotkeys := {}           # nome del pulsante in HUD/Tools/Row -> Key, KEY_NONE se non ne ha: vedi bind_key
var tool_names := {}        # nome del pulsante in HUD/Tools/Row -> suggerimento senza il tasto
var rebinding := ""         # comando che aspetta il suo nuovo tasto, vedi capture_key
var resume_speed := 1.0     # velocità a cui riprende il gioco chiudendo il menù delle opzioni
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
static var setup := {}      # nuova partita, da creation.gd: {"colony": nome, "ruler": Colonist.proprietà -> valore}
var ruler: Colonist         # il sovrano, vedi RULER_POINTS
var realm := ""             # nome della colonia
var arms := {}              # stemma della casata, vedi Tincture
var arms_tex: ImageTexture  # lo scudo 16x16: barra in alto, scheda del sovrano
var banner_tex: ImageTexture  # il drappo degli stendardi, sopra quello rosso del foglio dei mobili
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
var shadows := CanvasGroup.new()  # fonde le ombre: dove si sovrappongono non scuriscono il doppio
var casters := Node2D.new()       # dentro `shadows`: ci si disegnano le ombre, in bianco (il colore è SHADOW)
var feet := {}                    # [texture, rettangolo] -> riga dei piedi, vedi foot_of
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
@onready var realm_button: Button = $HUD/TopBar/Row/Realm  # nome del reame: apre la scheda del sovrano
@onready var fullscreen: Button = $HUD/TopBar/Row/Fullscreen
@onready var categories: Control = $HUD/Categories  # si apre col tasto Build: una categoria per barra di costruzione
@onready var build_bar: Control = $HUD/BuildBar  # sopra le categorie: quella scelta
@onready var furniture_bar: Control = $HUD/FurnitureBar
@onready var materials: Control = $HUD/BuildBar/Row/Materials
@onready var actions: Control = $HUD/Actions  # in basso al centro: "Build" e la X rossa
@onready var confirm: Button = $HUD/Actions/Confirm
@onready var erase: Button = $HUD/Actions/Erase
@onready var material_group: ButtonGroup = $HUD/BuildBar/Row/Materials/Wood.button_group
@onready var kind_group: ButtonGroup = $HUD/BuildBar/Row/Wall.button_group  # anche dei mobili
@onready var select_button: Button = $HUD/Tools/Row/Select  # la freccia, prima a sinistra: vedi select_tool
@onready var build_button: Button = $HUD/Tools/Row/Build  # sega e martello: apre le categorie, vedi toggle_build
@onready var structures_button: Button = $HUD/Categories/Row/Structures
@onready var furniture_button: Button = $HUD/Categories/Row/Furniture
@onready var category_group: ButtonGroup = structures_button.button_group
@onready var order_group: ButtonGroup = $HUD/Tools/Row/Destroy.button_group  # Destroy, Mine, Chop, Uproot
@onready var room_popup: Control = $HUD/RoomPopup  # pannello al centro
@onready var room_name: LineEdit = $HUD/RoomPopup/Box/Name
@onready var room_kind: OptionButton = $HUD/RoomPopup/Box/Kind  # solo i tipi possibili, vedi refresh_room
@onready var room_owners: Control = $HUD/RoomPopup/Box/Owners/List  # una casella da spuntare per colono: proprietari o lavoratori
@onready var craft_popup: Control = $HUD/CraftPopup  # menu della postazione cliccata, vedi open_craft
@onready var jobs_panel: Control = $HUD/JobsPanel  # a destra, si apre col tasto Jobs in basso: vedi job_list
@onready var jobs_list: RichTextLabel = $HUD/JobsPanel/Box/List  # testo ricco: le monete con l'icona
@onready var resources_panel: Control = $HUD/ResourcesPanel  # stesso posto: vedi update_resources
@onready var resources_list: Control = $HUD/ResourcesPanel/Box/List  # una riga per Res: icona, nome, quantità
@onready var sheet_panel: Control = $HUD/ColonistSheet  # a sinistra, si apre cliccando un colono: vedi open_sheet
@onready var object_sheet: Control = $HUD/ObjectSheet  # in basso a destra: la casella sotto il mouse, vedi show_tip
@onready var sheet_needs: GridContainer = $HUD/ColonistSheet/Box/Needs  # 4 colonne: nome, freccia giù, barra, freccia su
@onready var hotbar: Control = $HUD/Tools/Row
@onready var options: Control = $HUD/Options  # velo su tutto lo schermo con la finestra al centro: vedi toggle_options
@onready var key_list: GridContainer = $HUD/Options/Window/Box/Body/Pages/Keybindings/List  # icona, nome, tasto


# Rovina fuori dalla mappa (vedi RUINS): le stanze ripulite restano ripulite
class Ruin:
	var kind := RuinKind.TOWER
	var cleared := 0
	var next := -1  # Chamber della prossima stanza, una volta vista (vedi next_chamber); -1 da scoprire


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
	var treasure := false         # ha aperto il tesoro dell'ultima stanza: al ritorno, autorità


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
	shadows.self_modulate = SHADOW
	flat.draw.connect(draw_flat)
	casters.draw.connect(draw_shadows)
	add_child(sky)
	for i in COLONIST_COUNT:
		var c := Colonist.new()
		c.pos = center(MAP_SIZE / 2 + Vector2i(i - 1, 0))
		c.tunic = TUNIC_COLORS[i % TUNIC_COLORS.size()]
		dress(c, people().map(func(o): return o.first_name))
		c.skills = Skill.values().map(func(_s): return 0)
		c.xp = Skill.values().map(func(_s): return 0)
		var made: Dictionary = setup.get("ruler", {}) if i == 0 else {}
		for key in made:  # il sovrano, come l'ha fatto il giocatore: gli altri evitano il suo nome
			c.set(key, made[key])
		# sfalsati: non dormono tutti insieme; lo stress parte basso
		c.needs = Need.values().map(func(n): return randf_range(0, 40) if n == Need.STRESS else randf_range(60, NEED_MAX))
		c.trend = c.needs.map(func(_v): return 0.0)
		var pool := Trait.values()
		pool.shuffle()
		var count := 0 if not made.is_empty() else randi_range(0, 2)  # il sovrano ha quelli scelti dal giocatore
		for t in pool:  # a caso, ma niente talenti in contrasto (vedi TRAIT_CLASH)
			if c.traits.size() < count and not c.traits.any(func(o): return clash(o, t)):
				c.traits.append(t)
		colonists.append(c)
	ruler = colonists[0]
	realm = setup.get("colony", COLONY_NAMES.pick_random())
	arms = setup.get("arms", random_arms())
	banner_tex = banner_texture(arms)
	show_title()
	realm_button.pressed.connect(func(): open_sheet(ruler))
	camera.position = center(MAP_SIZE / 2)
	fullscreen.pressed.connect(toggle_fullscreen)
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:  # passato a schermo intero dal titolo
		fullscreen.text = "Window"
	$HUD/TopBar/Row/Options.pressed.connect(toggle_options)
	setup_options()
	build_button.toggled.connect(toggle_build)
	structures_button.toggled.connect(toggle_category.bind(build_bar))
	furniture_button.toggled.connect(toggle_category.bind(furniture_bar))
	for o in ORDER_TOOLS:
		get_node("HUD/Tools/Row/" + ORDER_TOOLS[o]).toggled.connect(toggle_order.bind(o))
	select_button.toggled.connect(select_tool.unbind(1))
	for button in [build_button] + order_group.get_buttons():
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
	for name in ["Knowledge", "Laws"]:  # le finestre della ricerca, al centro: si rifanno aprendole (vedi fill_knowledge)
		var panel: Control = get_node("HUD/%sPanel" % name)
		get_node("HUD/Tools/Row/" + name).toggled.connect(func(on):
			knowledge_key = ""
			laws_key = ""
			panel.visible = on
			if on:  # rifatta subito e messa al centro: dopo resta dove la si trascina
				if name == "Knowledge":
					fill_knowledge()
				else:
					fill_laws()
				panel.position = ((get_viewport_rect().size - panel.size) / 2).floor())
		panel.hidden.connect(get_node("HUD/Tools/Row/" + name).set_pressed_no_signal.bind(false))
	for res in Res.values():
		var row := HBoxContainer.new()
		row.visible = false  # solo le risorse che ci sono, vedi update_resources
		row.add_child(ui_icon(ICONS[res], Rect2(), Vector2(32, 32)))
		var kind := ui_icon(KIND_ICONS[ITEM_KIND[res]], Rect2(), Vector2(16, 16))  # il tipo, prima del nome
		kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kind.tooltip_text = KIND_NAMES[ITEM_KIND[res]]
		row.add_child(kind)
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
	for window in [room_popup, craft_popup, jobs_panel, resources_panel, sheet_panel, $HUD/BoardPanel, $HUD/ReportPanel, $HUD/ChroniclePanel,
			$HUD/KnowledgePanel, $HUD/LawsPanel]:  # X in alto a destra, si trascinano
		window.get_node("Box/Head/Close").pressed.connect(window.hide)
		window.gui_input.connect(drag_window.bind(window))
		window.visibility_changed.connect(window.move_to_front, CONNECT_DEFERRED)  # l'ultima aperta sta sopra
	if not start_rooms:  # nei test tutto studiato: le prove della ricerca sono in test_research
		for t in Tech.values():
			researched[t] = true
	refresh_unlocks()


# menù delle opzioni: a sinistra le tab, icone (una per pagina, con lo stesso nome); le pagine stanno in un
# TabContainer senza linguette, grande quanto la più grande, così la finestra non cambia misura passando dall'una
# all'altra. Keybindings: una riga per comando della barra in basso, nell'ordine dei pulsanti. Game: menù principale,
# carica, esci dal gioco
func setup_options() -> void:
	var window: Control = options.get_node("Window")
	window.get_node("Box/Head/Close").pressed.connect(options.hide)
	window.gui_input.connect(drag_window.bind(window))
	options.visibility_changed.connect(options_toggled)
	var pages: TabContainer = window.get_node("Box/Body/Pages")
	for tab in window.get_node("Box/Body/Tabs").get_children():
		tab.toggled.connect(show_page.bind(pages.get_node(NodePath(tab.name))))
	pages.get_node("Keybindings/Reset").pressed.connect(reset_keys)
	# ponytail: menù principale e salvataggi non ci sono ancora: "Main menu" e "Load game" restano spenti
	pages.get_node("Game/Quit").pressed.connect(get_tree().quit)
	for button in hotbar.get_children():
		if not button is Button:
			continue
		tool_names[String(button.name)] = button.tooltip_text
		key_list.add_child(ui_icon(button.icon, Rect2(), Vector2(32, 32)))
		var label := Label.new()
		label.text = button.tooltip_text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_list.add_child(label)
		var key := Button.new()
		key.name = button.name
		key.custom_minimum_size = Vector2(120, 32)
		key.focus_mode = Control.FOCUS_NONE
		key.toggle_mode = true  # premuto finché aspetta il tasto nuovo
		key.pressed.connect(start_rebind.bind(String(button.name)))
		key_list.add_child(key)
	load_keys()


# tab del menù delle opzioni: la sua pagina al posto di quella aperta
func show_page(on: bool, page: Control) -> void:
	if on:
		page.get_parent().current_tab = page.get_index()


# Esc o ingranaggio in alto a destra: apre o chiude il menù delle opzioni
func toggle_options() -> void:
	options.visible = not options.visible


# aperto il menù il gioco si ferma; chiuso (anche con la X) riprende alla velocità di prima
func options_toggled() -> void:
	if options.visible:
		resume_speed = Engine.time_scale
		Engine.time_scale = 0.0
		options.move_to_front()  # sopra le finestre aperte dopo
	else:
		Engine.time_scale = resume_speed
		rebinding = ""
		show_keys()


# tasti di partenza, poi quelli salvati
func load_keys() -> void:
	for name in tool_names:
		hotkeys[name] = DEFAULT_KEYS.get(name, KEY_NONE)
	var config := ConfigFile.new()
	if settings_file != "" and config.load(settings_file) == OK and config.has_section("keys"):
		for name in config.get_section_keys("keys"):
			if tool_names.has(name):  # comandi tolti dalla barra: si ignorano
				bind_key(name, config.get_value("keys", name), false)
	show_keys()


func reset_keys() -> void:
	for name in tool_names:
		hotkeys[name] = DEFAULT_KEYS.get(name, KEY_NONE)
	rebinding = ""
	save_keys()
	show_keys()


# lega il comando al tasto, tolto a chi lo aveva (un tasto, un comando); KEY_NONE: nessun tasto
func bind_key(name: String, key: Key, save := true) -> void:
	for other in hotkeys:
		if hotkeys[other] == key:
			hotkeys[other] = KEY_NONE
	hotkeys[name] = key
	if save:
		save_keys()
	show_keys()


func save_keys() -> void:
	if settings_file == "":
		return
	var config := ConfigFile.new()
	config.load(settings_file)  # tiene le altre sezioni, se ci sono
	for name in hotkeys:
		config.set_value("keys", name, hotkeys[name])
	config.save(settings_file)


# il tasto di ogni comando, nella sua riga del menù e tra parentesi nel suggerimento del pulsante in basso
func show_keys() -> void:
	for name in hotkeys:
		var key: Key = hotkeys[name]
		hotbar.get_node(NodePath(name)).tooltip_text = tool_names[name] + ("" if key == KEY_NONE else " (%s)" % OS.get_keycode_string(key))
		var button: Button = key_list.get_node(NodePath(name))
		button.text = "Press a key" if name == rebinding else "-" if key == KEY_NONE else OS.get_keycode_string(key)
		button.set_pressed_no_signal(name == rebinding)


# clic sul tasto di un comando nel menù: aspetta il nuovo, vedi capture_key
func start_rebind(name: String) -> void:
	rebinding = name
	show_keys()


# tasto premuto mentre un comando aspetta il suo: Esc annulla, Canc e Backspace lo tolgono; quelli fissi (velocità,
# giro dei mobili) e i modificatori da soli non si prendono, si resta in attesa
func capture_key(key: Key) -> void:
	if key in MODIFIER_KEYS or (key in FIXED_KEYS and key != KEY_ESCAPE):
		return
	var name := rebinding
	rebinding = ""
	if key == KEY_ESCAPE:
		show_keys()
	elif key in [KEY_DELETE, KEY_BACKSPACE]:
		bind_key(name, KEY_NONE)
	else:
		bind_key(name, key)


# tasto di un comando della barra in basso: come cliccarne il pulsante
func press_hotkey(key: Key) -> bool:
	var name = hotkeys.find_key(key)
	if key == KEY_NONE or name == null:
		return false
	var button: Button = hotbar.get_node(NodePath(name))
	button.button_pressed = not button.button_pressed
	return true


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
	for button in [build_button, order_group.get_pressed_button()]:
		if button:
			button.button_pressed = false
	sync_select()  # cliccato già premuto si spegnerebbe: lo riaccende


func sync_select() -> void:
	select_button.set_pressed_no_signal(not (build_button.button_pressed or order_group.get_pressed_button()))


# tasto "Build" (sega e martello) in basso a sinistra: sopra compaiono le categorie di costruzione, ancora nessuna
# scelta. Chiuderlo chiude anche la categoria aperta e scarta il progetto non confermato
func toggle_build(on: bool) -> void:
	categories.visible = on
	if on:
		var tool := order_group.get_pressed_button()
		if tool:
			tool.button_pressed = false
		return
	var open := category_group.get_pressed_button()
	if open:
		open.button_pressed = false  # nasconde la sua barra e "Build" al centro
	draft.clear()  # chiudere senza confermare scarta il progetto
	furniture_draft.clear()
	reset_choice()


# categorie "Structures" (muro) e "Furniture" (lampada), una alla volta: sopra compare la sua barra (strutture e
# materiale, o mobili e frecce per girarli), al centro "Build" e la X per cancellare. Passando dall'una all'altra
# il progetto resta (es. un letto sul pavimento appena disegnato)
func toggle_category(on: bool, bar: Control) -> void:
	bar.visible = on
	if on:
		reset_choice()  # il tipo scelto nell'altra barra qui non c'è
	actions.visible = category_group.get_pressed_button() != null


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


# tasti "Destroy", "Mine", "Chop", "Uproot", "Harvest" dopo "Build": finché uno è premuto, trascinando o cliccando
# si abbatte quello che è costruito, si segnano massi da scavare, alberi da tagliare, erbacce e cespugli da estirpare,
# cespugli da cui raccogliere le bacche (ogni volta che maturano, finché il segno resta)
func toggle_order(on: bool, which: Order) -> void:
	if on:
		build_button.button_pressed = false
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
	for c in [ruler] if editing.kind == RoomKind.THRONE_ROOM else colonists:
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


# menu della postazione `origin` (fuoco da campo, fornace, incudine, banchi): una riga per ricetta, con gli ingredienti
# e quanti tenerne (vedi keep). Al fuoco i pasti, da 2 crudi uguali qualsiasi. Fuori dalla sua stanza lo dice: lì non si lavora
func open_craft(origin: Vector2i) -> void:
	crafting = origin
	var kind: Build = furniture[origin][0]
	var box: Control = $HUD/CraftPopup/Box
	box.get_node("Head/Title").text = Build.keys()[kind].capitalize()
	box.get_node("Room").text = "Works only in a %s" % RoomKind.keys()[STATION_ROOM[kind]].capitalize().to_lower()
	box.get_node("Room").visible = not stations(kind).has(origin)
	var list := box.get_node("List")
	for child in list.get_children():
		child.free()
	var rows := RECIPES.filter(func(r): return r[1] == kind and unlocked("makes", r[0])).map(func(r): return [r[0], needs_of(r), "+"])  # [prodotto, ingredienti, tra uno e l'altro]
	if kind == Build.CAMPFIRE:
		var raw := {}
		for res in RAW_FOOD:
			raw[res] = COOK_RAW
		rows.push_front([Res.MEAL, raw, "or"])
	for r in rows:
		var row := HBoxContainer.new()
		row.add_child(ui_icon(ICONS[r[0]], Rect2(), Vector2(32, 32)))
		var label := Label.new()
		label.text = Res.keys()[r[0]].capitalize()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size.x = 110
		label.tooltip_text = GEAR[r[0]]["info"] if GEAR.has(r[0]) else ""
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(label)
		for res in r[1]:
			if res != r[1].keys()[0]:
				var between := Label.new()
				between.text = r[2]
				row.add_child(between)
			var amount := Label.new()
			amount.text = str(r[1][res])
			row.add_child(amount)
			row.add_child(ui_icon(ICONS[res], Rect2(), Vector2(16, 16)))
		var count := SpinBox.new()
		count.prefix = "Keep"
		count.custom_minimum_size.x = 100  # se no taglia la scritta
		count.value = keep.get(r[0], 0)
		count.tooltip_text = "Made until there are this many" + (", besides what colonists need to wear" if GEAR.has(r[0]) else "")
		count.value_changed.connect(func(v): keep[r[0]] = int(v))
		row.add_child(count)
		list.add_child(row)
	craft_popup.show()
	craft_popup.reset_size()


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
	box.get_node("Head/Arms").visible = c == ruler  # lo stemma lo mette show_title
	box.get_node("Hero").visible = c.hero != Hero.NONE or c == ruler
	box.get_node("Hero").text = "%s, fee %s, %d expedition%s" % [hero_name(c), coins(fee(c)), c.trips, "" if c.trips == 1 else "s"] \
		if c.hero != Hero.NONE else ("%s %s of %s" % [CROWN_IMG, TITLES[rank]["ruler"][c.sex], realm] if c == ruler else "")
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
		if icon.get_script() == null:
			icon.set_script(TIP)
		icon.set("make_tip", gear_tip.bind(g) if g != null else Callable())
	box.get_node("Equipment/Title").text = "Equipment" + ("  (armor %d)" % gear_sum(c, "armor") if gear_sum(c, "armor") > 0 else "")


# suggerimento di un pezzo dell'equipaggiamento: tipo e nome, poi protezione ed effetto (come tooltip_text)
func gear_tip(g: Res) -> Control:
	var text := rich("%s\n%s%s" % [item_title(g), "Armor %d. " % GEAR[g]["armor"] if GEAR[g].has("armor") else "", GEAR[g]["info"]])
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 260
	return text


# condizioni di `c` sotto i talenti, solo icone come loro: col mouse sopra nome, effetto e quanto manca. Le icone si
# rifanno solo quando cambiano le condizioni (se no il suggerimento sparirebbe), il tempo che manca a ogni chiamata
# condizioni nella scheda: quelle a tempo, poi le leggi in vigore che gli piacciono o no (vedi law_mood_of)
func update_conds(box: Control, c: Colonist) -> void:
	var icons: Control = box.get_node("Conditions/Icons")
	var now := c.conds.keys()
	now.sort()
	var laws := enacted.filter(func(law): return law_mood_of(c, law) != 0.0)
	if icons.get_meta("conds", []) != [now, laws]:
		icons.set_meta("conds", [now, laws])
		for child in icons.get_children():
			child.free()
		for k in now:
			icons.add_child(ui_icon(CONDITIONS_SHEET, Rect2(tile_rect(k, 0)), Vector2(32, 32)))
		for law in laws:
			icons.add_child(ui_icon(LAWS_SHEET, Rect2(tile_rect(law, 0)), Vector2(32, 32)))
		for icon in icons.get_children():
			icon.mouse_filter = Control.MOUSE_FILTER_PASS
	for i in now.size():
		icons.get_child(i).tooltip_text = "%s\n%s\n%d h left" % [Cond.keys()[now[i]].capitalize(), COND_INFO[now[i]][4],
			ceili((c.conds[now[i]] - clock) * 24)]
	for i in laws.size():
		var mood := law_mood_of(c, laws[i])
		icons.get_child(now.size() + i).tooltip_text = "%s: %s\n%s happiness while it is in force" % [
			"Approves" if mood > 0 else "Disapproves", law_name(laws[i]), signed(mood)]
	icons.get_parent().visible = not (now.is_empty() and laws.is_empty())  # col titolo "Conditions"


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
	row.get_node("Worked").text = "Worked today: %.1f / %s h" % [c.worked, str(work_hours(c)).trim_suffix(".0")]


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
static func ui_icon(tex: Texture2D, region: Rect2, size: Vector2) -> TextureRect:
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


# sesso a caso, e secondo il sesso nome (uno che non è tra i `taken`, se ce n'è) e acconciatura; colori del mantello
# e dei capelli
static func dress(c: Colonist, taken := []) -> void:
	c.sex = Sex.values().pick_random()
	c.hair_style = HAIR_STYLES[c.sex].pick_random()
	c.beard = c.sex == Sex.MALE and randf() < BEARD_CHANCE
	c.cape = CAPE_COLORS.pick_random()
	c.hair = HAIR_COLORS.pick_random()
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
		var crop := "Flax" if flax.has(cell) else "Berries"
		return ["Flax" if flax.has(cell) else "Bush", ("%s: %d / %d" % [crop, stock.get(cell, BERRIES_PER_BUSH), BERRIES_PER_BUSH]
			if ripe else "%s in %.1f days" % [crop, bushes[cell] - clock]) + uproot]
	if weeds.has(cell):
		return ["Weed", uproot.strip_edges()]
	for res in items:
		if items[res].has(cell):
			var about := "%d / %d" % [items[res][cell], STACK_MAX[res]]
			if fresh.has(cell):  # cibo: quanto è fresco e quando marcisce, dove si trova adesso
				var part: float = fresh[cell] / SHELF_LIFE[res]
				about += "\n%s, rots in %.1f days" % [FRESH_WORDS.filter(func(w): return part > w[0] or w[0] == 0.0)[0][1],
					fresh[cell] / spoil_rate(cell)]
			return ["%s pile" % item_title(res), about]
	for origin in pieces_at(furniture, cell):
		var kind: Build = furniture[origin][0]
		return [Build.keys()[kind].capitalize(), {Build.DESK: "Click: knowledge", Build.THRONE: "Click: laws"}.get(kind,
			"Click: what to make" if STATION_ROOM.has(kind) else "")]
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
		lines.append("Hunt animals: %d%s" % [hunted.size(), "" if colonists.any(has_bow) or available(Res.BOW) > 0 else " (needs a bow)"])
	if meals_wanted() > 0 and not kitchen_fires().is_empty():
		lines.append("Cook meals: %d" % meals_wanted())
	for r in RECIPES:  # solo quello che manca, che si sa fare e che ha una postazione
		if unlocked("makes", r[0]) and gear_wanted(r[0]) > 0 and not stations(r[1]).is_empty():
			lines.append("Make %s: %d" % [item_name(r[0]), gear_wanted(r[0])])
	for plans in [blueprints, furniture_plans]:  # prima le strutture (per casella), poi i mobili (per pezzo)
		var counts := {}  # "wall (wood)" -> quanti
		for plan in plans.values():
			var what := "%s (%s)" % [Build.keys()[plan[0]].capitalize().to_lower(), item_name(plan[1])]
			counts[what] = counts.get(what, 0) + 1
		for what in counts:
			lines.append("Build %s: %d" % [what, counts[what]])
	for res in Res.values():
		var piles: Array = items[res].keys().filter(func(cell): return not stockpile.has(cell))
		if not piles.is_empty() and not stockpile.is_empty():  # senza magazzino nessuno trasporta
			lines.append("Haul %s: %d pile%s" % [item_name(res), piles.size(), "" if piles.size() == 1 else "s"])
	return "\n".join(lines) if not lines.is_empty() else "Nothing to do"


# finestra "Resources": quanto c'è in tutti i magazzini insieme, solo le risorse presenti
func update_resources() -> void:
	var amounts := Res.values().map(stored)
	for res in Res.values():
		var row: Control = resources_list.get_child(res)
		row.visible = amounts[res] > 0
		row.get_child(-1).text = str(amounts[res])  # la quantità, in fondo alla riga
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
			elif randf() < 0.01:  # lino sparso nei prati, già in fiore
				bushes[cell] = 0.0
				flax[cell] = true
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
		for i in STASH.size():  # un mucchio per risorsa, cinque per riga dalla riga di mezzo, il resto si allarga accanto
			drop(STASH[i], first + Vector2i(i % 5 - 2, i / 5), DEBUG_STASH)
		drop(Res.GOLD, first + Vector2i(0, 1), START_GOLD)
		var spots := []  # l'arma abbandonata: sul prato, né troppo vicino né troppo lontano dalla radura
		for cell in cells_in(Rect2i(MAP_SIZE / 2 - Vector2i.ONE * FOUND_WEAPON_REACH[1], Vector2i.ONE * FOUND_WEAPON_REACH[1] * 2)):
			var far := Vector2(cell - MAP_SIZE / 2).length()
			if far >= FOUND_WEAPON_REACH[0] and far <= FOUND_WEAPON_REACH[1] and can_build(cell, Build.FLOOR):
				spots.append(cell)
		if not spots.is_empty():
			drop(FOUND_WEAPONS.pick_random(), spots.pick_random(), 1)
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
	beds_label.text = str(furniture.values().filter(func(plan): return plan[0] in BEDS).size())  # solo quelli finiti
	splendor_label.text = str(colony_splendor())
	confirm.disabled = draft.is_empty() and furniture_draft.is_empty()
	if jobs_panel.visible:
		jobs_list.text = job_list()
	if resources_panel.visible:
		update_resources()
	if $HUD/BoardPanel.visible:
		fill_board()
	if $HUD/KnowledgePanel.visible:
		fill_knowledge()
	if $HUD/LawsPanel.visible:
		fill_laws()
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
	if craft_popup.visible and not furniture.has(crafting):  # postazione abbattuta: si chiude
		craft_popup.hide()
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
	var splendor := colony_splendor()
	authority += (AUTHORITY_DAILY * (rank + 1) + floorf(splendor / float(SPLENDOR_PER_AUTHORITY))
		+ (colonists.size() if enacted.has(Law.TRIBUTE) else 0)) * delta / DAY_LENGTH
	while rank < TITLES.size() - 1 and splendor >= TITLES[rank + 1]["splendor"]:
		rise()
	if int(clock) != today:
		today = int(clock)
		new_day()
	if int(clock * 24) != hour:
		hour = int(clock * 24)
		new_hour()
	for c in people():
		if c.died == 0.0:  # morto durante il giro
			update_colonist(c, delta)
	for arrow in arrows.duplicate():  # una freccia può abbattere un animale
		fly(arrow, delta)
	update_guests()
	update_expeditions()
	update_scholar()
	for c in corpses.duplicate():
		if clock >= c.died + CORPSE_DAYS:
			corpses.erase(c)
	for a in animals.duplicate():  # un cacciatore può abbatterne uno durante il giro
		update_animal(a, delta)
	if clock >= next_animal:
		next_animal = clock + ANIMAL_RESPAWN
		if animals.size() < ANIMALS_MAX:
			var prey := BEASTS.keys().filter(func(k): return not BEASTS[k].get("hostile", false))
			if enacted.has(Law.HUNTING_RESERVE):  # riserva di caccia: cervi doppi
				prey.append(Beast.DEER)
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
	c.idle = c.idle + delta if c.job in [Job.NONE, Job.RELAX, Job.TANTRUM, Job.PROTEST] and c.path.is_empty() else 0.0
	if c.idle > LOOK_TIME and randf() < delta / LOOK_TIME:  # si guarda attorno, a caso: niente coloni sincronizzati
		c.facing = Facing.values().pick_random()
	if c.job in [Job.HUNT, Job.FIGHT]:
		track_prey(c)
	if not c.path.is_empty():  # anche senza lavoro: chi è libero può dover uscire da una stanza che si chiude
		var goal := center(c.path[0])
		var d := goal - c.pos
		face(c, d)
		var step := SPEED * TILE * delta * (ROAD_SPEED if built.get(cell_of(c.pos), [-1])[0] == Build.ROAD else 1.0)
		c.walked += minf(d.length(), step)
		c.pos = c.pos.move_toward(goal, step)
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
			var res: Res = Res.FLAX if flax.has(c.target) else ores.get(c.target, gather[3])
			var left: int = stock.get(c.target, full_stock(c.target))
			var got := mini(left, gather[2])
			if c.job == Job.FISH:
				c.xp[Skill.FISHING] += 1  # la pesca a lancio, anche a vuoto; il resto della raccolta a raccolta finita
				if randf() >= catch_chance(c.skills[Skill.FISHING]):
					got = 0  # niente all'amo: si rilancia
			stock[c.target] = left - got
			var here := cell_of(c.pos)
			produce(res, here, got)
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
				flax.erase(c.target)
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
			if c.work_left == 0 and (plan[0] not in BARRIERS or ready_to_close(c)):
				if c.job == Job.BUILD:
					build(c.target)
				else:
					furniture[c.target] = plan
					plans.erase(c.target)
					if RELICS.has(plan[0]):
						gain(RELIC_AUTHORITY)
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
		Job.EQUIP:  # al mucchio: prende il pezzo (carry_res) e lo indossa; quello che aveva in quello slot lo posa lì
			if items[c.carry_res].has(c.target):
				var slot: Slot = GEAR[c.carry_res]["slot"]
				add_item(c.carry_res, c.target, -1)
				if c.gear.has(slot):
					drop(c.gear[slot], c.target, 1)
				c.gear[slot] = c.carry_res
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
			c.xp[Skill.RANGED] += 1
			c.work_left = c.work_total
			shoot(c, a, randf() < hit_chance(hunt_level(c), dist) + gear_sum(c, "hit"))
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
				shoot(c, foe, randf() < hit_chance(c.skills[Skill.RANGED], dist) + gear_sum(c, "hit"))
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
					produce(meal, here, 1)
					try_haul(c, meal, [here])  # lo porta subito in magazzino
		Job.RELAX, Job.TANTRUM, Job.PROTEST:  # al fuoco, in fondo alla passeggiata, a sbollire, a protestare: resta lì finché non è ora
			var before := c.work_left
			c.work_left -= delta
			if c.work_total > 0:  # al fantoccio (vedi relax): un colpo ogni TRAIN_HIT, +1 esperienza in mischia
				if furniture.get(c.target, [-1])[0] != Build.DUMMY:
					end_job(c)  # fantoccio abbattuto
					return
				face(c, center(c.target) - c.pos)
				if floori((c.work_total - c.work_left) / TRAIN_HIT) > floori((c.work_total - before) / TRAIN_HIT):
					c.xp[Skill.MELEE] += 1
			if c.work_left <= 0:
				end_job(c)
		Job.TRAVEL:  # avventuriero arrivato alla locanda o al bordo della mappa
			arrive(c)
		Job.STUDY, Job.GOVERN:  # allo scrittoio una pagina, sul trono un'ora di udienza; poi chi non ci lavora rivaluta
			var seat: Build = Build.DESK if c.job == Job.STUDY else Build.THRONE
			if furniture.get(c.target, [-1])[0] != seat or room_at(c.target) == null or room_at(c.target).kind != SEAT_ROOM[seat]:
				end_job(c)  # mobile abbattuto, o la stanza ha cambiato tipo
				return
			face(c, center(c.target) - c.pos)
			c.work_left -= delta
			if c.work_left > 0:
				return
			if c.job == Job.STUDY:
				study += 1
				c.xp[Skill.RESEARCH] += 1
			else:
				authority += govern_rate(c)
			if c in room_at(c.target).workers:  # il lavoratore della stanza resta seduto: la pagina dopo, l'ora dopo
				c.work_left = page_time(c, room_at(c.target)) if c.job == Job.STUDY else DAY_LENGTH / 24
				c.work_total = c.work_left
				return
			end_job(c)


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
	return not routines or (activity(c) == Act.WORK and c.worked < work_hours(c) and clock >= c.pause_until)


# ore di lavoro al giorno di `c`: quelle dei talenti, cambiate dai turni (vedi SHIFTS). Coi turni lunghi chi ne fa
# meno del normale (il pigro) ne fa una in più, chi ne fa di più (lo stacanovista) resta com'è
func work_hours(c: Colonist) -> float:
	var hours: float = fx(c, "work", WORK_HOURS)
	if enacted.has(Law.LONG_SHIFTS):
		return hours + 1.0 if hours < WORK_HOURS else maxf(hours, SHIFTS[Law.LONG_SHIFTS][0])
	if enacted.has(Law.SHORT_DAY):
		return minf(hours, SHIFTS[Law.SHORT_DAY][0])
	return hours


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
	if c == watchman() and Trait.NIGHT_OWL not in c.traits:  # di guardia: dorme di giorno, come un nottambulo
		shift = TRAIT_FX[Trait.NIGHT_OWL]["shift"]
	var overtime: bool = fx(c, "overtime", false)
	var day := []
	for h in 24:
		var act := ROUTINE_LETTERS.find(letters[posmod(h - shift, 24)])
		day.append(Act.WORK if overtime and act == Act.FREE else act)
	if enacted.has(Law.CURFEW):  # dalle 21 a letto, chi a quell'ora sarebbe libero
		for h in range(21, 24):
			if day[h] == Act.FREE:
				day[h] = Act.SLEEP
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


static func clash(a: Trait, b: Trait) -> bool:
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
	if c.job not in [Job.NONE, Job.SLEEP, Job.EAT, Job.RELAX, Job.TANTRUM, Job.PROTEST]:  # lavori, ma anche combattere e scappare
		c.needs[Need.STRESS] += STRESS_WORK * fx(c, "stress", 1.0) * cond_product(c, 2) * outdoor_stress(c) * shift_stress() * day \
			* (HARSH_STRESS if enacted.has(Law.HARSH_PUNISHMENT) and Trait.HOTHEAD in c.traits else 1.0)
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
	c.work_left = (CLEMENT_HOURS if enacted.has(Law.CLEMENCY) else TANTRUM_HOURS) * DAY_LENGTH / 24
	if enacted.has(Law.HARSH_PUNISHMENT):
		add_cond(c, Cond.PILLORIED)


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
	return c.job == Job.SLEEP and not pieces_at(furniture, cell_of(c.pos)).filter(func(o): return furniture[o][0] in BEDS).is_empty()


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


# la stanza ha i mobili che servono per il tipo `kind`? (vedi ROOM_NEEDS; i tipi senza requisiti sì). Alcuni tipi
# vogliono una ricerca ("rooms" in TECHS)
func room_meets(room: Room, kind: RoomKind) -> bool:
	if not unlocked("rooms", kind):
		return false
	var needs: Dictionary = ROOM_NEEDS.get(kind, {})
	var inside: Array = furniture.keys().filter(func(o): return room.cells.has(o)) \
		.map(func(o): return Build.BED if furniture[o][0] == Build.CANOPY_BED else furniture[o][0])
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
		if routines and holiday():  # festa: chi non cucina si svaga
			relax(c)
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


# Svago per `hours` ore: attorno a un fuoco da campo o a un fantoccio libero (il più vicino dove può arrivare), se no
# a passeggio lì vicino. Al fantoccio si allena: colpi, ed esperienza in mischia (vedi Job.RELAX). Con la milizia la
# prima ora libera del giorno è al fantoccio, se ce n'è uno. Il divertimento sale (vedi update_needs); finito,
# find_job decide di nuovo
func relax(c: Colonist, hours := RELAX_HOURS) -> void:
	var spots := {}  # casella dove stare -> fantoccio, o la casella stessa (fuoco da campo)
	var drill := enacted.has(Law.MILITIA) and c.drilled != today
	for origin in furniture:
		if furniture[origin][0] == Build.CAMPFIRE and not drill:
			for d in EDGE_SIDES + EDGE_CORNERS:
				var k: Vector2i = origin + d
				if astar.is_in_boundsv(k) and not astar.is_point_solid(k) and not stockpile.has(k):
					spots[k] = k
		elif furniture[origin][0] == Build.DUMMY and is_free(origin):
			for d in SIDES:
				var k: Vector2i = origin + d
				if astar.is_in_boundsv(k) and not astar.is_point_solid(k) and not stockpile.has(k) and is_free(k):
					spots[k] = origin
	var path := path_to_nearest(c, spots.keys())
	if path.is_empty() and drill:  # niente fantoccio a portata: la milizia aspetta, svago come sempre
		c.drilled = today
		relax(c, hours)
		return
	if path.is_empty():
		path = stroll(c, RELAX_REACH)
	var dummy: Vector2i = spots.get(path.back(), Vector2i(-1, -1)) if not path.is_empty() else Vector2i(-1, -1)
	if dummy != Vector2i(-1, -1) and dummy != path.back():  # al fantoccio: lo si prenota, e i colpi hanno il loro ritmo
		start_job(c, Job.RELAX, path, dummy, hours * DAY_LENGTH / 24)
		c.dest = path.back()
		if drill:
			c.drilled = today
		return
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
	if c == ruler and enacted.has(Law.COURT):  # a corte il sovrano governa e basta
		return try_equip(c) or try_seat(c, Build.THRONE, false)
	if routines and holiday():  # riposo festivo, festa del raccolto: si cucina e basta
		return try_equip(c) or try_cook(c)
	if try_equip(c) or try_seat(c, Build.THRONE, true) or try_seat(c, Build.DESK, true) or try_cook(c) or try_craft(c) \
			or try_work(c, Job.CHOP, chop_marks.keys(), TREE_SIDES, gather_time(c, Job.CHOP)) \
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
	return try_seat(c, Build.THRONE, false) or try_seat(c, Build.DESK, false)  # niente da fare: governa, studia


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
		f *= (STEEL_TIME if steel(g) and GEAR[g].get("time", {}).has(job) else GEAR[g].get("time", {}).get(job, 1.0)) * GEAR[g].get("slow", 1.0)
	return f


# stress da lavoro x fuori dalle stanze, per quello che `c` ha addosso (vedi GEAR "outdoor_stress"); dentro 1
func outdoor_stress(c: Colonist) -> float:
	var f := 1.0
	if room_at(cell_of(c.pos)) == null:
		for g in c.gear.values():
			f *= GEAR[g].get("outdoor_stress", 1.0)
	return f


# somma di `key` per quello che `c` ha addosso (es. "armor", "hit", "range"); con l'arco sulla torre, di più; lo
# scudo conta solo con la spada o il pugnale in mano
func gear_sum(c: Colonist, key: String) -> float:
	var sum: float = TOWER.get(key, 0.0) if has_bow(c) and furniture.get(cell_of(c.pos), [-1])[0] == Build.WATCHTOWER else 0.0
	for g in c.gear.values():
		if g != Res.SHIELD or shielded(c):
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
	return sum + law_mood(c)


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
	return stations(Build.CAMPFIRE)


func room_at(cell: Vector2i) -> Room:
	for room in rooms:
		if room.cells.has(cell):
			return room
	return null


# pasti che mancano perché ce ne siano quanti chiede il menu del fuoco (vedi keep): contano quelli a terra, in mano e sul fuoco
func meals_wanted() -> int:
	var have: int = MEALS.reduce(func(sum, r): return sum + total(r), 0)
	have += colonists.filter(func(o): return o.job == Job.COOK).size()
	return maxi(keep[Res.MEAL] - have, 0)


# Cucinare, se mancano pasti: dal mucchio di crudo più vicino con almeno COOK_RAW (a terra o in magazzino)
# a una casella libera accanto a un fuoco da campo libero, dentro la cucina. false se non si può.
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
	if c.gear.has(slot) or (slot == Slot.SHIELD and not shielded(c)):
		return []
	if slot == Slot.HANDS:
		return [wanted_tool(c)]
	return GEAR.keys().filter(func(g): return GEAR[g]["slot"] == slot)


# Slot vuoto e il pezzo giusto in un mucchio libero: va a prenderlo (Job.EQUIP). false se non c'è niente da mettere
func try_equip(c: Colonist) -> bool:
	for slot in Slot.values():
		for g in fits(c, slot):
			if take(c, g):
				return true
	return false


# va a prendere il pezzo `g` dal mucchio libero più vicino (Job.EQUIP); false se non ce n'è
func take(c: Colonist, g: Res) -> bool:
	var path := path_to_nearest(c, items[g].keys().filter(func(cell): return is_free(cell)))
	if path.is_empty():
		return false
	start_job(c, Job.EQUIP, path, path.back(), 0.0)
	c.carry_res = g
	return true


# Quanti `res` mancano: fino a quanti chiede il menu (vedi keep), contando anche quelli in lavorazione. Equipaggiamento,
# se sono di più: i coloni con lo slot vuoto che lo prenderebbero (per le mani: chi vuole proprio quell'attrezzo; se no
# tutti), meno quelli già fatti e in lavorazione per lo stesso slot.
# Almeno un arco se ci sono animali da cacciare e nessuno ce l'ha: chi va a caccia se lo prende (vedi try_hunt)
func gear_wanted(res: Res) -> int:
	var making := func(r): return colonists.filter(func(o): return o.job == Job.CRAFT and RECIPES[o.recipe][0] == r).size()
	var spare: int = keep.get(res, 0) - total(res) - making.call(res)
	if not GEAR.has(res):
		return spare
	var slot: Slot = GEAR[res]["slot"]
	var same: Array = [res] if slot == Slot.HANDS else GEAR.keys().filter(func(g): return GEAR[g]["slot"] == slot)
	var want := colonists.filter(func(o): return res in fits(o, slot)).size()
	if res == Res.BOW and animals.any(func(a): return a.marked) and not colonists.any(has_bow):
		want = maxi(want, 1)
	for g in same:
		want -= total(g) + making.call(g)
	return maxi(want, spare)


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
		if free_stations.is_empty() or not unlocked("makes", r[0]) or gear_wanted(r[0]) <= 0 \
				or not needs_of(r).keys().all(func(res): return available(res) >= needs_of(r)[res]) \
				or (r[0] == Res.NOTEBOOK and study < COPY_STUDY):
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
		if r[0] == Res.NOTEBOOK:  # la copia: lo studio si spende subito (ponytail: perso se la si molla a metà)
			study -= COPY_STUDY
		c.dest = path.back()
		c.path = path  # prima alla postazione, poi da lì a prendere gli ingredienti (vedi craft)
		return true
	return false


# Ingredienti della ricetta `r`: con l'acciaio attrezzi e spade vogliono acciaio al posto dei lingotti
func needs_of(r: Array) -> Dictionary:
	if not (researched.has(Tech.STEEL) and r[0] in STEEL_GEAR and r[3].has(Res.INGOT)):
		return r[3]
	var swapped: Dictionary = r[3].duplicate()
	swapped[Res.STEEL] = swapped[Res.INGOT]
	swapped.erase(Res.INGOT)
	return swapped


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
		var take := mini(mini(items[c.carry_res].get(here, 0), needs_of(r)[c.carry_res] - c.fetched.get(c.carry_res, 0)), CARRY_MAX)
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
	for res in needs_of(r):
		if c.fetched.get(res, 0) < needs_of(r)[res]:
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
		produce(r[0], here, r[5] if r.size() > 5 else 1)
		try_haul(c, r[0], [here])


# --- Combattimento ---

func hostile(a: Animal) -> bool:
	return BEASTS[a.kind].get("hostile", false)


# con l'acciaio, attrezzi e spade sono d'acciaio (ponytail: anche quelli fatti prima, come ritemprati)
func steel(g) -> bool:
	return g in STEEL_GEAR and researched.has(Tech.STEEL)


# in mano un'arma con cui lo scudo serve: spada o pugnale
func shielded(c: Colonist) -> bool:
	return c.gear.get(Slot.HANDS) in [Res.SWORD, Res.DAGGER]


func has_bow(c: Colonist) -> bool:
	return c.gear.get(Slot.HANDS) == Res.BOW


# caselle da cui colpisce: con l'arco quelle di tiro, se no corpo a corpo
func reach(c: Colonist) -> float:
	return hunt_range(c) if has_bow(c) else MELEE_RANGE


func melee_chance(level: int) -> float:
	return clampf(MELEE_BASE + MELEE_PER_LEVEL * (level - 5), 0.05, 0.95)


# danno corpo a corpo: quello dell'attrezzo o dell'arma in mano, se no a mani nude
func melee_damage(c: Colonist) -> float:
	var g = c.gear.get(Slot.HANDS)
	if g == Res.SWORD and steel(g):
		return STEEL_SWORD
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
	var sight: float = INF if on_watch() else (TOWER_SIGHT if towers() > 0 else ALERT) * TILE  # di guardia, appena entrano
	for a in animals:
		if hostile(a) and a.blocked <= clock and a.pos.distance_to(c.pos) <= sight \
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
	if c.hp < flee_hp():
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


# Scocca una freccia da `c` verso `a`: se va a segno (`hit`) lo insegue, se no finisce un po' più in là, di lato.
# Il colpo (o lo spavento) arriva con la freccia, vedi fly
func shoot(c: Colonist, a: Animal, hit: bool) -> void:
	var arrow := Arrow.new()
	var dir := c.pos.direction_to(a.pos)
	arrow.from = c.pos + dir * 5  # dall'arco, davanti al colono
	arrow.pos = arrow.from
	arrow.prey = a
	arrow.by = c
	arrow.damage = GEAR[Res.BOW]["shot"] if hit else 0.0
	arrow.miss = a.pos + dir * TILE + dir.orthogonal() * randf_range(-1.0, 1.0) * TILE
	arrows.append(arrow)


# Un passo della freccia; arrivata colpisce o spaventa l'animale, se c'è ancora (abbattuto da altri: finisce dov'era)
func fly(arrow: Arrow, delta: float) -> void:
	var goal: Vector2 = arrow.prey.pos if arrow.damage > 0 and arrow.prey in animals else arrow.miss
	arrow.pos = arrow.pos.move_toward(goal, ARROW_SPEED * TILE * delta)
	if arrow.pos != goal:
		return
	arrows.erase(arrow)
	if arrow.prey in animals:
		if arrow.damage > 0:
			wound(arrow.prey, arrow.damage, arrow.by)
		else:
			startle(arrow.prey, arrow.by)


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
	produce(Res.MEAT, spot, BEASTS[a.kind]["meat"])
	produce(Res.HIDE, spot, BEASTS[a.kind]["hide"])  # accanto: un mucchio per risorsa
	if a.kind == Beast.DEER and by == ruler and enacted.has(Law.HUNTING_RESERVE):
		gain(RESERVE_AUTHORITY)
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


# percorso di un animale che non passa dalle stanze né dai cancelli: per la ricerca li si riempie come fossero muro
func beast_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var shut := built.keys().filter(func(k): return built[k][0] == Build.GATE)
	for room in rooms:
		shut.append_array(room.cells.keys().filter(func(k): return not astar.is_point_solid(k)))
	for k in shut:
		astar.set_point_solid(k)
	var path := astar.get_id_path(from, to) if not astar.is_point_solid(from) and not astar.is_point_solid(to) else ([] as Array[Vector2i])
	for k in shut:
		astar.set_point_solid(k, false)
	return path


# sotto quanti punti ferita si scappa invece di combattere: con la milizia meno
func flee_hp() -> float:
	return MILITIA_FLEE if enacted.has(Law.MILITIA) else FLEE_HP


# quanti `res` tenere (vedi keep): dal menu delle postazioni, o per i quaderni dalla finestra Knowledge
func set_keep(value: float, res: Res) -> void:
	keep[res] = int(value)


# L'erudito arriva se c'è una locanda (se no riprova domani) e resta un giorno, poi riparte con quello che non ha venduto
func update_scholar() -> void:
	if scholar_until >= 0 and clock >= scholar_until:
		scholar_until = -1.0
		scholar_books.clear()
		knowledge_key = ""
	if clock < next_scholar:
		return
	if not rooms.any(is_inn):
		next_scholar = clock + 1.0
		return
	next_scholar = clock + SCHOLAR_EVERY + randf_range(-SCHOLAR_JITTER, SCHOLAR_JITTER)
	scholar_until = clock + 1.0
	scholar_bought = false
	scholar_books.clear()
	for i in randi_range(1, 2):
		scholar_books.append(Res.TOME if randf() < SCHOLAR_TOME else Res.NOTEBOOK)
	knowledge_key = ""
	note("Day %d: a wandering scholar stops at the inn, with %s to sell (see Knowledge)." % [int(clock) + 1,
		", ".join(scholar_books.map(func(b): return "a " + res_name(b)))])


# compra dall'erudito il libro `i` della sua lista: monete dal magazzino, il libro in magazzino. false se non si può
func buy_book(i: int) -> bool:
	if i >= scholar_books.size() or stored(Res.GOLD) < BOOK_PRICE[scholar_books[i]]:
		return false
	var book: Res = scholar_books[i]
	take_stored(Res.GOLD, BOOK_PRICE[book])
	store(book, 1)
	scholar_books.remove_at(i)
	knowledge_key = ""
	return true


# vende all'erudito un libro `book` del magazzino, a metà prezzo; uno solo a passaggio. false se non si può
func sell_book(book: Res) -> bool:
	if scholar_until < 0 or scholar_bought or stored(book) == 0:
		return false
	take_stored(book, 1)
	store(Res.GOLD, BOOK_PRICE[book] / 2)
	scholar_bought = true
	knowledge_key = ""
	return true


# posa `amount` di `res` in magazzino, dove ci sta (vedi dest_cells); pieno, accanto alla prima casella
func store(res: Res, amount: int) -> void:
	var cells := dest_cells(res)
	drop(res, cells[0] if not cells.is_empty() else stockpile.keys()[0], amount)


# torri di guardia finite
func towers() -> int:
	return furniture.values().filter(func(plan): return plan[0] == Build.WATCHTOWER).size()


# Turno di guardia (legge): veglia di notte un nottambulo, se c'è, se no il primo colono che non è il sovrano (che
# allora dorme di giorno, vedi routine_of); null senza la legge o senza nessuno
func watchman() -> Colonist:
	if not enacted.has(Law.NIGHT_WATCH):
		return null
	var awake := colonists.filter(func(o): return not o.downed)
	for o in awake:
		if Trait.NIGHT_OWL in o.traits:
			return o
	for o in awake:
		if o != ruler:
			return o
	return null


# la guardia è sveglia, di notte: i lupi si vedono da tutta la mappa (vedi nearest_foe)
func on_watch() -> bool:
	var h := int(fmod(clock, 1.0) * 24)
	var w := watchman()
	return w != null and (h >= DARK_FROM or h < DARK_TO) and w.job != Job.SLEEP


# Pedaggio (legge): chi arriva paga TOLL monete al cancello più vicino, posate lì; senza cancello niente
func pay_toll(g: Colonist) -> void:
	var gates := built.keys().filter(func(k): return built[k][0] == Build.GATE)
	if enacted.has(Law.TOLL) and not gates.is_empty():
		sort_by_distance(gates, g.pos)
		drop(Res.GOLD, gates[0], TOLL)


# Un branco di lupi entra da un bordo della mappa, a caso; se ne va dopo WOLF_STAY se non trova nessuno. La guardia lo vede
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
		if on_watch():
			note("Day %d, night: the watch sees wolves coming." % (int(clock) + 1))
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
		gain(DEATH_AUTHORITY)
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
	return furniture.keys().filter(func(o): return furniture[o][0] in BEDS and is_free(o) \
		and is_inn(room_at(o)) == (c.hero != Hero.NONE))


func inn_beds() -> int:
	return furniture.keys().filter(func(o): return furniture[o][0] in BEDS and is_inn(room_at(o))).size()


# avventuriero `kind` di livello `level`, col suo nome, aspetto, abilità ed equipaggiamento
func new_hero(kind: Hero, level: int) -> Colonist:
	var c := Colonist.new()
	dress(c, people().map(func(o): return o.first_name))
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
		var every: float = RENOWNED_GUESTS[0] if researched.has(Tech.RENOWNED_INN) else GUEST_EVERY
		next_guest = clock + (every + randf_range(-GUEST_JITTER, GUEST_JITTER)) * (LOOT_TAX_WAIT if enacted.has(Law.LOOT_TAX) else 1.0) \
			* (TOLL_WAIT if enacted.has(Law.TOLL) else 1.0)
		var edges := border_cells()
		if not edges.is_empty():
			var level := clampi(1 + colony_splendor() / SPLENDOR_PER_LEVEL + randi_range(-1, 1), 1, HERO_LEVEL_MAX)
			var g := new_hero(wanted_hero if wanted_hero != Hero.NONE and researched.has(Tech.RENOWNED_INN) else Hero.values().slice(1).pick_random(), level)
			while enacted.has(Law.LOOT_TAX) and Gift.GREEDY in g.gifts:  # con la gabella gli avidi non vengono
				g.gifts = [Gift.values().pick_random()]
			g.pos = center(edges.pick_random())
			pay_toll(g)
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
			c.stay_until = clock + (RENOWNED_GUESTS[1] if researched.has(Tech.RENOWNED_INN) else GUEST_STAY) - (1.0 if enacted.has(Law.LODGING_TAX) else 0.0)
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
	return RUINS[ruin.kind]["travel"] * party_gift(party, "travel", 1.0) * (MAPPED_TRAVEL if researched.has(Tech.CARTOGRAPHY) else 1.0)


# giorni per andare alla rovina, esplorare le stanze che restano e tornare
func trip_days(ruin: Ruin, party: Array) -> float:
	return 2 * travel_days(ruin, party) + ROOM_DAYS * (RUINS[ruin.kind]["rooms"] - ruin.cleared)


# provviste che servono al gruppo `party` per tutto il viaggio: una a testa per giorno (meno, con chi trova da mangiare)
func provisions(party: Array, ruin: Ruin) -> int:
	return ceili(party.size() * trip_days(ruin, party) * party_gift(party, "food", 1.0) - 0.001)


func food_stored() -> int:
	return (MEALS + RAW_FOOD).reduce(func(n, r): return n + stored(r) + granary.get(r, 0), 0) + stored(Res.HARDTACK) * HARDTACK_FOOD


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
	exp.food += from_granary(want)  # prima dal granaio della corona, poi le gallette
	var biscuits := mini(stored(Res.HARDTACK), ceili((want - exp.food) / HARDTACK_FOOD))
	take_stored(Res.HARDTACK, biscuits)
	exp.food += biscuits * HARDTACK_FOOD
	for res in MEALS + RAW_FOOD:
		var n := mini(stored(res), want - int(exp.food))
		take_stored(res, n)
		exp.food += n
	var loans := PackedStringArray()
	for g in party:
		if researched.has(Tech.LENDING_ARMORY):
			loans.append_array(lend(g))
		exp.party.append(g)
		g.hired = true
		g.errand = Errand.DEPART
		quit_job(g)
		travel(g)
	expeditions.append(exp)
	board_pick.clear()
	note("Day %d: %s hired for the %s, for %s and %d of %d provisions." % [int(clock) + 1,
		", ".join(party.map(func(g): return "%s (%s)" % [full_name(g), hero_name(g)])), RUINS[ruin.kind]["name"], coins(cost),
		exp.food, want] + (" The armory lends: %s." % ", ".join(loans) if not loans.is_empty() else ""))
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
		var kind: int = Chamber.CHEST if last else next_chamber(exp.ruin)
		exp.ruin.next = -1
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
		exp.treasure = last
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


# la prossima stanza di `ruin`: pescata la prima volta che la si guarda (la cartografia la mostra sulla bacheca), poi
# resta quella finché la si esplora
func next_chamber(ruin: Ruin) -> int:
	if ruin.next < 0:
		ruin.next = pick_chamber()
	return ruin.next


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
		if data.get("always", false) or randf() < BOOK_CHANCE * party_gift(exp.party, "books", 1.0):  # un libro al posto dell'oggetto
			var book: Res = data["books"].pick_random()
			found[book] = found.get(book, 0) + 1
			continue
		var find: Array = data["finds"].pick_random()
		found[find[0]] = found.get(find[0], 0) + roundi(find[1] * haul)
	if last:  # il tesoro: i suoi libri
		for book in data["treasure"]:
			found[book] = found.get(book, 0) + 1
	for res in found:
		exp.loot[res] = exp.loot.get(res, 0) + found[res]
	var text := "a chest: %s, %s" % [coins(gold), ", ".join(found.keys().map(func(r): return amount_text(r, found[r])))]
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
		var share := LOOT_SHARE if enacted.has(Law.LOOT_TAX) else SHARE
		var shares: float = exp.party.reduce(func(n, g): return n + gift(g, "share", share), 0.0) / exp.party.size()
		var kept := floori(gold * shares)  # la quota: ognuno la sua parte (il leale niente)
		if gold > 0:
			exp.loot[Res.GOLD] = gold - kept
		var brought := PackedStringArray()
		for res in exp.loot:
			if exp.loot[res] > 0:
				brought.append(amount_text(res, exp.loot[res]))
		exp.lines.append("Back home with %s%s." % [", ".join(brought) if not brought.is_empty() else "nothing",
			"; they keep %s" % coins(kept) if kept > 0 else ""])
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
		if exp.treasure:
			gain(TREASURE_AUTHORITY)
			exp.lines.append("The treasure of the %s: %s authority for the crown." % [name, signed(TREASURE_AUTHORITY)])
		for g in exp.party:
			give_back(g)
		exp.party[0].loot = exp.loot  # lo porta il primo, lo lascia alla locanda (vedi arrive)
		report("Back from the %s" % name, exp.lines)


# nome di una risorsa nei testi: "leather armor"; le monete con la loro icona (vedi coins)
func res_name(res: Res) -> String:
	return Res.keys()[res].capitalize().to_lower()


# `n` monete: il numero e l'icona, per i testi ricchi (RichTextLabel con bbcode: bacheca, diario, cronaca, scheda)
func coins(n: int) -> String:
	return "%d %s" % [n, COIN]


# quantità di una risorsa in un testo ricco: le monete con l'icona, il resto col suo nome (e l'icona del tipo)
func amount_text(res: Res, n: int) -> String:
	return coins(n) if res == Res.GOLD else "%d %s" % [n, item_name(res)]


# l'icona del tipo di `res`, per i testi ricchi
func kind_icon(res: Res) -> String:
	return "[img=center]%s[/img]" % KIND_ICONS[ITEM_KIND[res]].resource_path


# nome di un oggetto nei testi ricchi, minuscolo: l'icona del tipo e il nome ("leather armor"); le monete solo l'icona
func item_name(res: Res) -> String:
	return COIN if res == Res.GOLD else "%s %s" % [kind_icon(res), res_name(res)]


# nome di un oggetto come titolo: l'icona del tipo e il nome ("Leather Armor")
func item_title(res: Res) -> String:
	return "%s %s" % [kind_icon(res), Res.keys()[res].capitalize()]


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
	var notice: OptionButton = box.get_node("Notice/Class")
	box.get_node("Notice").visible = researched.has(Tech.RENOWNED_INN)
	if notice.item_count == 0:
		for kind in Hero.values():
			notice.add_item("Anyone" if kind == Hero.NONE else Hero.keys()[kind].capitalize(), kind)
		notice.item_selected.connect(func(i): wanted_hero = notice.get_item_id(i))
	notice.select(notice.get_item_index(wanted_hero))
	box.get_node("Gold").text = "%s    %d %s provisions (meals, raw food, hardtack)" % [coins(stored(Res.GOLD)), food_stored(),
		"[img=center]%s[/img]" % KIND_ICONS[ItemKind.FOOD].resource_path]
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
		var label := rich("%s\n%s, %s, %s" % [full_name(g), hero_name(g), gift_names(g), coins(fee(g))])
		label.custom_minimum_size.x = 280
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
		row.add_theme_constant_override("separation", 16)
		var label := Label.new()
		label.text = "%s, danger %d: %s" % [data["name"], data["danger"],
			"explored" if explored(ruin) else "rooms %d / %d" % [ruin.cleared, data["rooms"]]]
		if researched.has(Tech.CARTOGRAPHY) and not explored(ruin):
			label.text += ", next: %s" % ("the treasure" if ruin.cleared == data["rooms"] - 1 else CHAMBER_NAMES[next_chamber(ruin)])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if not explored(ruin):
			var food := provisions(board_pick, ruin)
			if not board_pick.is_empty():  # quanto costa mandarci gli spuntati
				var price := rich("%s, %d [img=center]%s[/img]" % [coins(cost), food, KIND_ICONS[ItemKind.FOOD].resource_path])
				price.custom_minimum_size.x = 110
				price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(price)
			var send_button := Button.new()
			send_button.text = "Send"
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
	var text: RichTextLabel = $HUD/ChroniclePanel/Box/Scroll/Text
	var pages := chronicle.duplicate()
	pages.reverse()
	text.text = "\n\n".join(pages) if not pages.is_empty() else "Nothing worth telling has happened yet."
	text.set_meta("pages", chronicle.size())


# testo ricco (con le icone delle monete, vedi coins) su una riga, alto quanto serve
func rich(text: String) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text = text
	return label


func toggle_pick(on: bool, g: Colonist) -> void:
	if on and g not in board_pick and board_pick.size() < MAX_PARTY:
		board_pick.append(g)
	elif not on:
		board_pick.erase(g)


# --- Ricerca: il sapere ---

# Pulsanti di costruzione e pietra: si vedono solo quelli che nessuna ricerca chiede o che le ricerche fatte sbloccano
func refresh_unlocks() -> void:
	for kind in Build.values():
		var bar := furniture_bar if FURNITURE.has(kind) else build_bar
		bar.get_node("Row/" + Build.keys()[kind].capitalize()).visible = unlocked("builds", kind)
	$HUD/BuildBar/Row/Materials/Stone.visible = unlocked("materials", Res.STONE)


# la ricerca che sblocca `value` nella lista `key` di TECHS ("builds", "makes", "materials"); -1 se c'è dall'inizio
func tech_for(key: String, value: int) -> int:
	for t in TECHS:
		if value in TECHS[t].get(key, []):
			return t
	return -1


func unlocked(key: String, value: int) -> bool:
	var t := tech_for(key, value)
	return t < 0 or researched.has(t)


func tech_name(t: Tech) -> String:
	return Tech.keys()[t].capitalize()


# perché `t` non si può studiare adesso, "" se si può: già fatta, le ricerche prima, i punti studio, il libro in magazzino
func research_block(t: Tech) -> String:
	var data: Dictionary = TECHS[t]
	if researched.has(t):
		return "Studied"
	for n in data.get("needs", []):
		if not researched.has(n):
			return "First: %s" % tech_name(n)
	if study < data["cost"]:
		return "%d more study" % ceili(data["cost"] - study)
	if data["tier"] > 1 and stored(BOOKS[data["tier"] - 2]) < 1:
		return "Needs a %s in a warehouse" % res_name(BOOKS[data["tier"] - 2])
	return ""


# Studia `t`: toglie i punti dal mucchio dello studio e il libro dal magazzino, e sblocca quello che dice TECHS.
# false se non si può (vedi research_block)
func research(t: Tech) -> bool:
	if research_block(t) != "":
		return false
	var data: Dictionary = TECHS[t]
	study -= data["cost"]
	if data["tier"] > 1:
		take_stored(BOOKS[data["tier"] - 2], 1)
	researched[t] = true
	refresh_unlocks()
	knowledge_key = ""
	return true


# cosa sblocca `t`, per il suggerimento: mobili, oggetti, materiali e le leggi che la chiedono
func unlocks_text(t: Tech) -> String:
	var data: Dictionary = TECHS[t]
	var names: Array = data.get("builds", []).map(func(b): return Build.keys()[b].capitalize()) \
		+ data.get("makes", []).map(func(r): return Res.keys()[r].capitalize()) \
		+ data.get("materials", []).map(func(r): return "%s walls and floors" % Res.keys()[r].capitalize()) \
		+ data.get("rooms", []).map(func(k): return "the %s room" % RoomKind.keys()[k].capitalize().to_lower()) \
		+ LAWS.keys().filter(func(law): return LAWS[law].get("needs", -1) == t).map(func(law): return "the law %s" % law_name(law))
	return "Unlocks: " + ", ".join(names)


# Allo scrittoio (studiare) o sul trono (governare: solo il sovrano), se ce n'è uno libero dentro una stanza del tipo
# giusto (vedi SEAT_ROOM): con `mine` solo nelle stanze dove `c` è tra i lavoratori. false se non ce n'è
func try_seat(c: Colonist, kind: Build, mine: bool) -> bool:
	if kind == Build.THRONE and c != ruler:
		return false
	var stands := {}  # casella accanto a un mobile libero, nella sua stanza -> mobile
	for o in furniture:
		var room := room_at(o)
		if furniture[o][0] != kind or not is_free(o) or room == null or room.kind != SEAT_ROOM[kind] or (mine and c not in room.workers):
			continue
		var around := {}
		add_stands(around, [o], o, SIDES)
		for k in around:
			if room.cells.has(k):
				stands[k] = o
	var path := path_to_nearest(c, stands.keys())
	if path.is_empty():
		return false
	var seat: Vector2i = stands[path.back()]
	if kind == Build.DESK:
		start_job(c, Job.STUDY, path, seat, page_time(c, room_at(seat)))
	else:
		start_job(c, Job.GOVERN, path, seat, DAY_LENGTH / 24)
	c.dest = path.back()
	return true


# secondi per una pagina di studio di `c` nella stanza `room`: PAGE_TIME a livello 5, secondo il comfort e le condizioni;
# di notte senza un abat-jour di più, con le librerie di meno
func page_time(c: Colonist, room: Room) -> float:
	var inside: Array = furniture.keys().filter(func(o): return room.cells.has(o)).map(func(o): return furniture[o][0])
	var t := PAGE_TIME * skill_time(c.skills[Skill.RESEARCH]) * comfort_time(room_comfort(room)) * work_factor(c, Job.STUDY)
	var hour := hour_now()
	if (hour >= DARK_FROM or hour < DARK_TO) and Build.LAMP not in inside:
		t *= NIGHT_STUDY
	return t * (1.0 - SHELF_BONUS * mini(inside.count(Build.BOOKSHELF), SHELVES_MAX))


# autorità di un'ora d'udienza del sovrano `c`: di più se è sereno, di meno se è cupo (vedi RULER_MOODS)
func govern_rate(c: Colonist) -> float:
	var happy: float = c.needs[Need.HAPPINESS]
	var rate := AUTHORITY_PER_HOUR * (COURT_AUDIENCE if enacted.has(Law.COURT) else 1.0)
	if happy >= RULER_MOODS[0][0]:
		return rate * RULER_MOODS[0][1]
	if happy <= RULER_MOODS[1][0]:
		return rate * RULER_MOODS[1][1]
	return rate


# --- Ricerca: le leggi ---

func law_name(law: Law) -> String:
	return Law.keys()[law].capitalize()


func signed(v: float) -> String:
	return ("+%d" if v > 0 else "%d") % roundi(v)


# felicità che la legge `law` dà a `c` finché è in vigore (vedi "mood" in LAWS): agli avventurieri la loro, ai coloni
# quella del primo talento che ne ha una, se no quella di tutti
func law_mood_of(c: Colonist, law: Law) -> float:
	var mood: Dictionary = LAWS[law].get("mood", {})
	if c.hero != Hero.NONE:
		return mood.get("guests", 0.0)
	if c == ruler and mood.has("ruler"):
		return mood["ruler"]
	if has_bow(c) and mood.has("hunters"):
		return mood["hunters"]
	for t in c.traits:
		if mood.has(t):
			return mood[t]
	return mood.get("all", 0.0)


func law_mood(c: Colonist) -> float:
	return enacted.reduce(func(sum, law): return sum + law_mood_of(c, law), 0.0)


# stress da lavoro x dei turni in vigore (vedi SHIFTS)
func shift_stress() -> float:
	for law in SHIFTS:
		if enacted.has(law):
			return SHIFTS[law][1]
	return 1.0


# oggi è festa (riposo festivo, festa del raccolto): si cucina e basta, gli altri si svagano (vedi find_work)
func holiday() -> bool:
	var day := int(clock)
	return (enacted.has(Law.DAY_OF_REST) and day % REST_EVERY == REST_EVERY - 1) \
		or (enacted.has(Law.HARVEST_FEAST) and day % SEASON_DAYS == SEASON_DAYS - 1)


# All'alba di ogni giorno (a mezzanotte): la tassa di soggiorno di chi aspetta alla locanda, una moneta lì dov'è;
# chi è scontento toglie autorità. A stagione nuova: finita la festa del raccolto, la sua felicità e la sua autorità;
# col granaio aperto un pasto a tutti, un pezzo del granaio a testa finché ce n'è
func new_day() -> void:
	if enacted.has(Law.LODGING_TAX):
		for g in guests:
			if not g.hired and g.errand == Errand.NONE:
				drop(Res.GOLD, cell_of(g.pos), 1)
	gain(-colonists.filter(func(c): return c.needs[Need.HAPPINESS] < UNHAPPY).size())
	if posmod(today - 1, SEASON_DAYS) != SEASON_DAYS - 1:
		return
	if enacted.has(Law.HARVEST_FEAST):
		for c in colonists:
			add_cond(c, Cond.FESTIVE)
		gain(FEAST_AUTHORITY)
	if enacted.has(Law.OPEN_GRANARY):
		for c in colonists:
			if from_granary(1) == 0:
				break
			c.needs[Need.FOOD] = NEED_MAX
			c.conds.erase(Cond.FEASTED)
			add_cond(c, Cond.WELL_FED)


# A ogni ora: le proteste (vedi protest); col granaio aperto, se nei magazzini non c'è più cibo il granaio ne manda un pezzo a colono, che si
# posa in magazzino dove ci sta (vedi dest_cells; pieno, resta nel granaio) e si mangia come gli altri.
# ponytail: un'ora di attesa al più; un giorno di scorta alla volta
func new_hour() -> void:
	for c in colonists:
		if c != ruler and c.needs[Need.HAPPINESS] < UNHAPPY and c.protested != today and not c.downed \
				and c.job not in [Job.SLEEP, Job.FIGHT, Job.FLEE, Job.TANTRUM, Job.PROTEST] \
				and enacted.filter(func(law): return law_mood_of(c, law) < 0).size() >= PROTEST_LAWS:
			protest(c)
	if not enacted.has(Law.OPEN_GRANARY) or (MEALS + RAW_FOOD).any(func(r): return stored(r) > 0):
		return
	var left := colonists.size()
	for res in MEALS + RAW_FOOD:
		var dests := dest_cells(res)
		var n := mini(granary.get(res, 0), left)
		if n > 0 and not dests.is_empty():
			granary[res] -= n
			left -= n
			drop(res, dests[0], n)


# `c` molla tutto e va nella sala del trono più vicina (se non ce n'è, lì attorno) a lamentarsi delle leggi che non gli
# piacciono, per PROTEST_HOURS; nella cronaca. Costa autorità, se non c'è una legge della giustizia: con le pene severe
# finisce alla gogna, con la clemenza il sovrano lo ascolta (e dura meno)
func protest(c: Colonist) -> void:
	quit_job(c)
	c.protested = today
	var hall := []
	for room in rooms:
		if room.kind == RoomKind.THRONE_ROOM:
			hall.append_array(room.cells.keys().filter(func(k): return not astar.is_point_solid(k) and is_free(k)))
	var path := path_to_nearest(c, hall)
	if path.is_empty():
		path = stroll(c, TANTRUM_REACH)
	start_job(c, Job.PROTEST, path, path.back() if not path.is_empty() else cell_of(c.pos), 0.0)
	c.work_left = (CLEMENT_HOURS if enacted.has(Law.CLEMENCY) else PROTEST_HOURS) * DAY_LENGTH / 24
	var how := ""
	if enacted.has(Law.HARSH_PUNISHMENT):  # alla gogna: niente autorità persa, ma un giorno di umiliazione
		add_cond(c, Cond.PILLORIED)
		how = ": into the stocks"
	elif enacted.has(Law.CLEMENCY):  # il sovrano lo ascolta
		add_cond(c, Cond.HEARD)
		how = ": the ruler listens"
	else:
		gain(PROTEST_AUTHORITY)
	note("Day %d: %s protests in the throne room against %s%s." % [int(clock) + 1, full_name(c),
		" and ".join(enacted.filter(func(law): return law_mood_of(c, law) < 0).map(law_name)), how])


# Armeria di prestito: per la spedizione `g` prende dal magazzino l'armatura e l'elmo che proteggono più dei suoi, e lo
# scudo se tira di spada o di pugnale e non ne ha uno nel corredo. Tiene da parte i suoi (vedi give_back). I prestiti, per la cronaca
func lend(g: Colonist) -> PackedStringArray:
	var out := PackedStringArray()
	for slot in [Slot.BODY, Slot.HEAD, Slot.SHIELD]:
		if slot == Slot.SHIELD and (not shielded(g) or Look.SHIELD in g.kit):
			continue
		var own = g.gear.get(slot)
		var best = own
		for piece in GEAR.keys().filter(func(p): return GEAR[p]["slot"] == slot and stored(p) > 0):
			if best == null or GEAR[piece].get("armor", 0) > GEAR[best].get("armor", 0):
				best = piece
		if best != own:
			take_stored(best, 1)
			g.lent[slot] = own
			g.gear[slot] = best
			out.append("%s to %s" % [res_name(best), g.first_name])
	return out


# tornato dalla spedizione: i pezzi prestati in magazzino, i suoi di nuovo addosso
func give_back(g: Colonist) -> void:
	for slot in g.lent:
		store(g.gear[slot], 1)
		if g.lent[slot] == null:
			g.gear.erase(slot)
		else:
			g.gear[slot] = g.lent[slot]
	g.lent.clear()


# toglie dal granaio fino a `n` pezzi di cibo, prima i pasti; quanti ne ha tolti
func from_granary(n: int) -> int:
	var taken := 0
	for res in MEALS + RAW_FOOD:
		var k := mini(granary.get(res, 0), n - taken)
		granary[res] = granary.get(res, 0) - k
		taken += k
	return taken


# autorità dagli eventi (vedi TREASURE_AUTHORITY), mai sotto zero
func gain(amount: float) -> void:
	authority = maxf(authority + amount, 0.0)


# il nome del reame col titolo: "Barony of Valbruna"
func realm_name() -> String:
	return "%s of %s" % [TITLES[rank]["realm"], realm]


# Il titolo, dove si vede: nella barra in alto il reame e lo stemma con la corona (anche nella scheda del sovrano, al
# doppio come lo scudo: la corona lo fa più alto)
func show_title() -> void:
	arms_tex = arms_texture(arms, rank)
	for icon in [$HUD/TopBar/Row/RealmIcon, $HUD/ColonistSheet/Box/Head/Arms]:
		icon.texture = arms_tex
		icon.custom_minimum_size = arms_tex.get_size() * 2
	realm_button.text = realm_name()
	realm_button.tooltip_text = "%s %s" % [TITLES[rank]["ruler"][ruler.sex], full_name(ruler)]


# Lo splendore è arrivato al titolo dopo: sale (mai giù). Nella cronaca e in una finestra al centro, coi sigilli in più
func rise() -> void:
	var was := realm_name()
	rank += 1
	show_title()
	laws_key = ""
	report(realm_name(), ["Day %d: the %s is now the %s." % [int(clock) + 1, was, realm_name()],
		"%s %s. Seals: %d. Authority every day: +%d." % [TITLES[rank]["ruler"][ruler.sex], full_name(ruler),
		TITLES[rank]["seals"], AUTHORITY_DAILY * (rank + 1)]])


# Posa a terra `amount` di `res` appena prodotto (raccolto, cacciato, pescato, cucinato, fatto). Con la decima (o la
# taglia) una parte va al granaio della corona: TAXES di ogni pezzo, che si accumula finché non fa un pezzo intero.
# ponytail: il granaio è un conto, non una stanza, e niente ci marcisce; una stanza vera quando servirà vederlo
func produce(res: Res, cell: Vector2i, amount: int) -> void:
	for law in TAXES:
		if enacted.has(law) and amount > 0:
			tithe_owed[res] = tithe_owed.get(res, 0.0) + amount * TAXES[law]
			var due := mini(floori(tithe_owed[res] + 0.001), amount)
			tithe_owed[res] -= due
			granary[res] = granary.get(res, 0) + due
			amount -= due
	drop(res, cell, amount)


# perché la legge `law` non si può codificare adesso, "" se si può
func codify_block(law: Law) -> String:
	if codified.has(law):
		return "Codified"
	if LAWS[law].get("tier", 0) > rank:
		return "Needs a %s" % TITLES[LAWS[law]["tier"]]["realm"].to_lower()
	if LAWS[law].has("after") and not codified.has(LAWS[law]["after"]):
		return "First: %s" % law_name(LAWS[law]["after"])
	if LAWS[law].has("needs") and not researched.has(LAWS[law]["needs"]):
		return "Needs the research %s" % tech_name(LAWS[law]["needs"])
	if authority < LAWS[law]["cost"]:
		return "%d more authority" % ceili(LAWS[law]["cost"] - authority)
	return ""


# codifica `law` (una volta per sempre): poi si può promulgare. false se non si può
func codify(law: Law) -> bool:
	if codify_block(law) != "":
		return false
	authority -= LAWS[law]["cost"]
	codified[law] = true
	laws_key = ""
	return true


# la legge in vigore dello stesso gruppo di `law`, di cui la nuova prenderebbe il posto; null se non c'è
func rival(law: Law) -> Variant:
	for other in enacted:
		if other != law and LAWS[law].has("group") and LAWS[other].get("group") == LAWS[law]["group"]:
			return other
	return null


# perché `law` non si può promulgare adesso, "" se si può
func enact_block(law: Law) -> String:
	if not codified.has(law):
		return "Not codified yet"
	if enacted.has(law):
		return "In force"
	if revoked.get(law, 0.0) > clock:
		return "Revoked: again in %.1f days" % (revoked[law] - clock)
	if authority < ENACT_COST:
		return "%d more authority" % ceili(ENACT_COST - authority)
	if rival(law) == null and enacted.size() >= TITLES[rank]["seals"]:
		return "No free seal: revoke a law first"
	return ""


# Promulga `law` su un sigillo libero, o al posto di quella in vigore del suo gruppo (che si revoca): ENACT_COST autorità
func enact(law: Law) -> bool:
	if enact_block(law) != "":
		return false
	var other = rival(law)
	if other != null:
		revoke(other)
	authority -= ENACT_COST
	enacted.append(law)
	laws_key = ""
	return true


# revoca `law`: gratis, ma per REVOKE_WAIT giorni non si ripromulga
func revoke(law: Law) -> void:
	if enacted.has(law):
		enacted.erase(law)
		revoked[law] = clock + REVOKE_WAIT
		laws_key = ""


# suggerimento di una legge: cosa fa, a chi piace e a chi no, cosa serve
func law_tip(law: Law) -> String:
	var mood: Dictionary = LAWS[law].get("mood", {})
	var who := mood.keys().map(func(k): return "%s %s" % [{"all": "everyone", "guests": "adventurers", "ruler": "the ruler",
		"hunters": "bow carriers"}.get(k,
		Trait.keys()[k].capitalize().to_lower() if k is int else ""), signed(mood[k])])
	return LAWS[law]["info"] + ("\nHappiness: " + ", ".join(who) if not who.is_empty() else "") \
		+ ("\nNeeds a %s" % TITLES[LAWS[law]["tier"]]["realm"].to_lower() if LAWS[law].get("tier", 0) > 0 else "") \
		+ ("\nAfter %s" % law_name(LAWS[law]["after"]) if LAWS[law].has("after") else "") \
		+ ("\nNeeds the research %s" % tech_name(LAWS[law]["needs"]) if LAWS[law].has("needs") else "")


# Finestra Knowledge (tasto in basso, o clic su uno scrittoio): studio e libri, poi l'albero, una riga per ramo e una
# colonna per livello. Ogni ricerca è un pulsante: col mouse sopra cosa sblocca e cosa manca, cliccato la studia.
# Si rifà solo quando cambia qualcosa, se no i pulsanti non si premono
func fill_knowledge() -> void:
	var key := str([floori(study), BOOKS.map(stored), researched.keys(), scholar_until, scholar_books, scholar_bought, stored(Res.GOLD)])
	if key == knowledge_key:
		return
	knowledge_key = key
	var box: Control = $HUD/KnowledgePanel/Box
	box.get_node("Study").text = "%d [img=center]%s[/img] study    %s" % [floori(study), STUDY_ICON.resource_path,
		"   ".join(BOOKS.map(func(b): return "%d [img=center]%s[/img]" % [stored(b), ICONS[b].resource_path]))]
	box.get_node("Hint").visible = not rooms.any(func(r): return r.kind == RoomKind.STUDY)
	fill_scholar(box.get_node("Scholar"))
	var copies: SpinBox = box.get_node("Copies/Keep")  # lo scriptorium: quanti quaderni tenere, copiandoli allo scrittoio
	box.get_node("Copies").visible = researched.has(Tech.SCRIPTORIUM)
	if not copies.value_changed.is_connected(set_keep):
		copies.value_changed.connect(set_keep.bind(Res.NOTEBOOK))
	copies.set_value_no_signal(keep.get(Res.NOTEBOOK, 0))
	var grid: GridContainer = box.get_node("Scroll/Tree")
	for child in grid.get_children():
		child.free()
	grid.add_child(Control.new())
	for tier in range(1, 5):  # in testa i livelli, col libro che chiedono
		grid.add_child(rich(["I", "II", "III", "IV"][tier - 1] + ("" if tier == 1 else " [img=center]%s[/img]" % ICONS[BOOKS[tier - 2]].resource_path)))
	for branch in Branch.values():
		var techs := TECHS.keys().filter(func(t): return TECHS[t]["branch"] == branch)
		if techs.is_empty():
			continue
		var label := HBoxContainer.new()
		label.add_child(ui_icon(BRANCHES_SHEET, Rect2(tile_rect(branch, 0)), Vector2(32, 32)))
		var title := Label.new()
		title.text = Branch.keys()[branch].capitalize()
		label.add_child(title)
		grid.add_child(label)
		for tier in range(1, 5):
			var cell := VBoxContainer.new()
			for t in techs:
				if TECHS[t]["tier"] == tier:
					cell.add_child(tech_button(t))
			grid.add_child(cell)
	$HUD/KnowledgePanel.reset_size()


# L'erudito alla locanda, finché c'è: i libri che vende (Buy, col prezzo) e quelli del magazzino che comprerebbe
# (Sell, a metà prezzo, uno solo a passaggio)
func fill_scholar(row: Control) -> void:
	for child in row.get_children():
		child.free()
	row.visible = scholar_until >= 0
	if not row.visible:
		return
	row.add_child(rich("A wandering scholar at the inn, until day %d:" % (int(scholar_until) + 1)))
	for i in scholar_books.size():
		var book: Res = scholar_books[i]
		var buy := Button.new()
		buy.focus_mode = Control.FOCUS_NONE
		buy.text = "Buy %s: %d" % [res_name(book), BOOK_PRICE[book]]
		buy.icon = KIND_ICONS[ItemKind.COINS]  # la moneta dopo il numero, come nei testi
		buy.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		buy.disabled = stored(Res.GOLD) < BOOK_PRICE[book]
		buy.tooltip_text = "Not enough gold in the warehouses" if buy.disabled else "Paid from the warehouses"
		buy.pressed.connect(buy_book.bind(i))
		row.add_child(buy)
	for book in BOOKS:
		if stored(book) > 0 and not scholar_bought:
			var sell := Button.new()
			sell.focus_mode = Control.FOCUS_NONE
			sell.text = "Sell a %s: %d" % [res_name(book), BOOK_PRICE[book] / 2]
			sell.icon = KIND_ICONS[ItemKind.COINS]
			sell.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			sell.tooltip_text = "He buys one book, at half price"
			sell.pressed.connect(sell_book.bind(book))
			row.add_child(sell)


# pulsante di una ricerca: icona, nome e costo; dorato se fatta, velato se mancano le ricerche prima
func tech_button(t: Tech) -> Button:
	var data: Dictionary = TECHS[t]
	var button := Button.new()
	var icon := AtlasTexture.new()
	icon.atlas = TECHS_SHEET
	icon.region = Rect2(tile_rect(t, 0))
	button.icon = icon
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 32)
	button.custom_minimum_size = Vector2(190, 44)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	var cost := "%d study%s" % [data["cost"], "" if data["tier"] == 1 else " + 1 " + res_name(BOOKS[data["tier"] - 2])]
	button.text = "%s\n%s" % [tech_name(t), "studied" if researched.has(t) else cost]
	var block := research_block(t)
	button.disabled = block != ""
	if researched.has(t):
		button.modulate = SPLENDOR_COLOR.lightened(0.4)
	elif data.get("needs", []).any(func(n): return not researched.has(n)):
		button.modulate = Color(1, 1, 1, 0.5)
	button.tooltip_text = "%s\n%s%s" % [data["info"], unlocks_text(t), "" if block in ["", "Studied"] else "\n" + block]
	button.pressed.connect(research.bind(t))
	return button


# Finestra Laws (tasto in basso, o clic sul trono): autorità, sigilli e granaio; poi le leggi per categoria, ognuna col
# suo pulsante (codifica, promulga, revoca). Col mouse sopra cosa fa e a chi piace. Si rifà quando cambia qualcosa
func fill_laws() -> void:
	var thrones := rooms.filter(func(r): return r.kind == RoomKind.THRONE_ROOM).size()
	var splendor := colony_splendor()
	var key := str([floori(authority), codified.keys(), enacted, revoked, granary, researched.keys(), thrones, floori(clock), rank, splendor])
	if key == laws_key:
		return
	laws_key = key
	var box: Control = $HUD/LawsPanel/Box
	var stock := granary.keys().filter(func(r): return granary[r] > 0).map(func(r): return amount_text(r, granary[r]))
	var next := "" if rank == TITLES.size() - 1 else ": a %s at %d splendor (now %d)" % [TITLES[rank + 1]["realm"].to_lower(),
		TITLES[rank + 1]["splendor"], splendor]
	box.get_node("Authority").text = "%s%s\n%d [img=center]%s[/img] authority    Seals: %d / %d\nGranary: %s" % [realm_name(), next,
		floori(authority), AUTHORITY_ICON.resource_path, enacted.size(), TITLES[rank]["seals"], ", ".join(stock) if not stock.is_empty() else "empty"]
	box.get_node("Hint").visible = thrones == 0
	var list: Control = box.get_node("Scroll/List")
	for child in list.get_children():
		child.free()
	for kind in LawKind.values():
		var title := Label.new()
		title.text = LawKind.keys()[kind].capitalize()
		title.add_theme_color_override("font_color", BUILD_INFO_COLOR)
		list.add_child(title)
		for law in LAWS:
			if LAWS[law]["kind"] != kind:
				continue
			var row := HBoxContainer.new()
			var icon := ui_icon(LAWS_SHEET, Rect2(tile_rect(law, 0)), Vector2(32, 32))
			icon.tooltip_text = law_tip(law)
			row.add_child(icon)
			var name := Label.new()
			name.text = law_name(law)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name.custom_minimum_size.x = 200
			name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			name.tooltip_text = law_tip(law)
			name.mouse_filter = Control.MOUSE_FILTER_PASS
			if enacted.has(law):
				name.add_theme_color_override("font_color", SPLENDOR_COLOR)
			row.add_child(name)
			var button := Button.new()
			button.focus_mode = Control.FOCUS_NONE
			button.custom_minimum_size.x = 140
			if enacted.has(law):
				button.text = "Revoke"
				button.tooltip_text = "Free; then it cannot be enacted again for %d days" % REVOKE_WAIT
				button.pressed.connect(revoke.bind(law))
			elif codified.has(law):
				var block := enact_block(law)
				var other = rival(law)
				button.text = "Enact (%d)" % ENACT_COST
				button.disabled = block != ""
				button.tooltip_text = block if block != "" else ("Takes the place of %s" % law_name(other) if other != null else "Takes a seal")
				button.pressed.connect(enact.bind(law))
			else:
				var block := codify_block(law)
				button.text = "Codify (%d)" % LAWS[law]["cost"]
				button.disabled = block != ""
				button.tooltip_text = block if block != "" else "Once codified, it can be enacted"
				button.pressed.connect(codify.bind(law))
			row.add_child(button)
			list.add_child(row)
	$HUD/LawsPanel.reset_size()


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


# Caccia, solo con l'arco: l'animale segnato più vicino che nessuno insegue già. Il cacciatore va verso di lui finché
# non è a tiro (vedi track_prey), poi tira (vedi Job.HUNT). Senza arco va a prenderne uno, se ce n'è uno libero, e posa
# quello che aveva in mano. false se non c'è niente da cacciare, nessun arco o non ci si arriva.
func try_hunt(c: Colonist) -> bool:
	var prey := animals.filter(func(a): return a.marked and a.hunter == null and a.blocked <= clock \
		and not (a.kind == Beast.DEER and enacted.has(Law.HUNTING_RESERVE) and c != ruler and not has_bow(c)))  # riserva
	if prey.is_empty():
		return false
	if not has_bow(c):
		return take(c, Res.BOW)
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
	# prima la dispensa (c'è solo per il cibo), poi le pile già iniziate della stessa risorsa, poi la più vicina
	# ponytail: una prenotazione = un colono per cella, quindi coloni in parallelo lasciano qualche pila a metà;
	# prenotare lo spazio (quantità) invece della cella se il magazzino si riempie troppo presto
	var from := center(c.target)
	dests.sort_custom(func(a, b): return [not pantry.has(a), not items[res].has(a), center(a).distance_squared_to(from)] \
		< [not pantry.has(b), not items[res].has(b), center(b).distance_squared_to(from)])  # il cibo prima in dispensa
	c.dest = dests[0]  # se non ci si arriva, al mucchio il lavoro si annulla (vedi HAUL)
	reserved[c.dest] = c
	return true


func add_stands(stands: Dictionary, cells: Array, target: Vector2i, sides: Array) -> void:
	for cell in cells:
		for side in sides:
			var s: Vector2i = cell + side
			if astar.is_in_boundsv(s) and not astar.is_point_solid(s) and not trees.has(s) \
					and blueprints.get(s, [-1])[0] not in BARRIERS and not cells.has(s):
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
			if o.job in [Job.BUILD, Job.FURNISH, Job.COOK, Job.CRAFT, Job.STUDY, Job.GOVERN]:
				cells[o.dest] = true
	return cells


func sort_by_distance(cells: Array, from: Vector2) -> void:
	cells.sort_custom(func(a, b): return center(a).distance_squared_to(from) < center(b).distance_squared_to(from))


func is_free(cell: Vector2i) -> bool:
	return not reserved.has(cell)


# celle di magazzino che possono ricevere `res`: libere, vuote o con la stessa risorsa non piena
func dest_cells(res: Res) -> Array:
	return stockpile.keys().filter(func(cell):
		if pantry.has(cell) and not SHELF_LIFE.has(res):  # in dispensa solo quello che marcisce
			return false
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
	return SPOIL_PANTRY if pantry.has(cell) else (SPOIL_STORED if stockpile.has(cell) else 1.0)


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
					if can_build(Vector2i(x, y), build_kind) and (edge or build_kind not in BARRIERS):
						draft[Vector2i(x, y)] = [build_kind, build_res]  # sovrascrive: ripassando si cambia idea
		Order.ERASE:
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					erase_plan(Vector2i(x, y))
		Order.DEMOLISH:  # subito, senza recuperare il materiale
			for cell in built.keys().filter(func(k): return rect.has_point(k)):
				if built[cell][0] in BARRIERS:
					astar.set_point_solid(cell, false)
				if built[cell][0] == Build.ROAD:
					astar.set_point_weight_scale(cell, 1.0)
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
	if built[cell][0] == Build.ROAD:  # la strada si preferisce, come si va più svelti
		astar.set_point_weight_scale(cell, 1.0 / ROAD_SPEED)
	if built[cell][0] in BARRIERS:
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
			if cells.size() >= ROOM_MAX or cells.has(front) or not astar.is_in_boundsv(front) or astar.is_point_solid(front) \
					or cells.keys().any(func(k): return SIDES.any(func(d): return built.get(k + d, [-1])[0] == Build.PALISADE)):
				continue  # aperta sul mondo, la porta non dà fuori, o è un cortile chiuso dalla palizzata
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
	pantry.clear()
	for room in rooms:
		if room.kind in [RoomKind.WAREHOUSE, RoomKind.PANTRY]:
			stockpile.merge(room.cells)
		if room.kind == RoomKind.PANTRY:
			pantry.merge(room.cells)


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
					var seats := pieces_at(furniture, cell).filter(func(o): return SEAT_ROOM.has(furniture[o][0]))
					if picked:
						open_sheet(picked)
					elif not boards.is_empty():
						open_board()
					elif not seats.is_empty():  # scrittoio: il sapere; trono: le leggi
						var tool: Button = get_node("HUD/Tools/Row/" + ("Knowledge" if furniture[seats[0]][0] == Build.DESK else "Laws"))
						tool.button_pressed = true
					elif not signed.is_empty():
						open_room(signed[0])
					elif pieces_at(furniture, cell).any(func(o): return STATION_ROOM.has(furniture[o][0])):
						open_craft(pieces_at(furniture, cell)[0])
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
	elif event is InputEventKey and event.pressed and rebinding != "":
		if not event.echo:
			capture_key(event.keycode)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not event.echo:
			toggle_options()
	elif event is InputEventKey and event.pressed and not options.visible:  # col menù aperto il gioco è fermo
		if not event.echo and not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed) and press_hotkey(event.keycode):
			return
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
	return sin((fmod(clock, 1.0) - 0.25) * TAU)


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
		Build.ROAD: return tile_rect(3, 2)
		Build.PALISADE: return tile_rect(links, 8)
		_: return tile_rect(1 if links & 5 and not links & 10 else 0, 3 if plan[0] == Build.DOOR else 9)  # porta, cancello: di lato se ha muri solo sopra e sotto


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


# Le ombre che gli sprite non hanno già, col sole a picco (vedi SHADOW): una striscia sotto muri e porte, un ovale
# sotto i piedi di coloni e animali. In bianco: il colore lo dà `shadows`, sotto tutto ciò che sta in piedi.
func draw_shadows() -> void:
	for cell in built:
		if built[cell][0] not in PAVING and built.get(cell + Vector2i.DOWN, [Build.FLOOR])[0] in PAVING:
			casters.draw_rect(Rect2(Vector2(cell.x, cell.y + 1) * TILE, Vector2(TILE, SHADOW_WALL)), Color.WHITE)
	for a in animals:  # sulla riga più bassa delle zampe; l'ovale è simmetrico, va bene anche specchiato
		draw_blob(a.pos + Vector2(0, foot_of(ANIMALS, animal_src(a)) - 1 - TILE / 2.0), BEASTS[a.kind]["shadow"])
	for c in people():
		if c.downed:  # sdraiato (vedi draw_colonist): l'ovale sporge appena sotto il fianco
			draw_blob(c.pos + Vector2(0, 5), TILE - 2)
		else:  # i piedi della posa da fermo: l'ovale non balla coi passi e coi colpi
			var src := Rect2(Vector2(0, c.facing) * TILE, Vector2.ONE * TILE)
			draw_blob(c.pos + Vector2(0, foot_of(COLONIST_BASE, src) - 1 - TILE / 2.0), SHADOW_WIDTH)


# `mid` come il centro degli sprite: arrotondato, così l'ovale sta sugli stessi pixel di chi lo fa.
func draw_blob(mid: Vector2, width: int) -> void:
	for row in blob(Vector2i(mid.round()), width):
		casters.draw_rect(row, Color.WHITE)


# Ovale d'ombra alto 3 pixel e largo `width`, centrato in `mid` (riga di mezzo, tra due colonne se `width` è pari):
# una riga di pixel per rettangolo, accorciata ai lati come un'ellisse, così resta netta e allineata ai pixel.
func blob(mid: Vector2i, width: int) -> Array[Rect2i]:
	var rows: Array[Rect2i] = []
	for j in 3:
		var dy: float = (j + 0.5) / 3.0 * 2.0 - 1.0  # da -1 in cima a 1 in fondo
		var inset: int = roundi(width / 2.0 * (1.0 - sqrt(1.0 - dy * dy)))
		rows.append(Rect2i(mid.x - floori(width / 2.0) + inset, mid.y - 1 + j, width - 2 * inset, 1))
	return rows


# Dove lo sprite tocca terra, in pixel dalla cima di `src`: sotto l'ultima riga con pixel pieni.
# Le ombre semitrasparenti già disegnate negli sprite e i bordi vuoti non contano.
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
	for cell in bushes:  # bassi, dentro la loro casella come i massi; con le bacche (o i fiori) se sono maturi
		draw_texture_rect_region(PLANTS, tile_rect(cell.x, cell.y), tile_rect(plant_col(cell) + (1 if bushes[cell] <= clock else 0), 0))
	draw_pieces(self, FURNITURE_NIGHT if sun_height() < 0 else FURNITURE_SHEET, furniture)
	for origin in furniture:  # stendardi: sopra il drappo rosso, quello della casata (stesso fotogramma)
		if furniture[origin][0] == Build.BANNER:
			var r := piece_rects(origin, furniture[origin])
			draw_texture_rect_region(banner_tex, r[0], Rect2(r[1].position.x / 32 * TILE, 0, TILE, TILE))
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
	for arrow in arrows:  # sopra tutto: volano
		draw_arrow(arrow)

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


# colonna di PLANTS del cespuglio (o del lino) in `cell` senza bacche (fiori); quella dopo è con
func plant_col(cell: Vector2i) -> int:
	return 3 if flax.has(cell) else 1


# Freccia in volo: asticella di legno con la punta di ferro e le penne, su una parabola bassa (la sua ombra resta a
# terra); inclinata come sale e scende
func draw_arrow(arrow: Arrow) -> void:
	var goal: Vector2 = arrow.prey.pos if arrow.damage > 0 and arrow.prey in animals else arrow.miss
	var done := arrow.from.distance_to(arrow.pos)
	var length := done + arrow.pos.distance_to(goal)
	var f := done / length if length > 0 else 1.0
	var lift := Vector2(0, -sin(PI * f) * ARROW_ARC * length)
	var dir := (arrow.from.direction_to(goal) * length + Vector2(0, -PI * cos(PI * f) * ARROW_ARC * length)).normalized()
	var tip := arrow.pos + lift
	draw_line(arrow.pos - dir * 6, arrow.pos, Color(0, 0, 0, 0.25), 1.0)
	draw_line(tip - dir * 6, tip, Color("7a5434"), 1.0)
	draw_line(tip - dir * 6, tip - dir * 4, Color("e8e4d8"), 1.0)
	draw_rect(Rect2(tip - Vector2.ONE * 0.5, Vector2.ONE), Color("d0d0d8"))


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
	elif c.job in [Job.TANTRUM, Job.PROTEST]:  # sfuriata, protesta: un punto esclamativo, rosso o giallo, che sobbalza
		draw_string(ThemeDB.fallback_font, at + Vector2(11, 3 - absf(sin(clock * DAY_LENGTH * 6)) * 2), "!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("ff5a5a") if c.job == Job.TANTRUM else SPLENDOR_COLOR)


# ---- Stemma della casata (vedi Tincture) ----

static func image_of(tex: Texture2D) -> Image:
	if not sheet_images.has(tex):
		sheet_images[tex] = tex.get_image()
	return sheet_images[tex]


# Partizione: true dove il campo ha il secondo smalto. (px, py): pixel dal centro del campo
static func divided(division: int, px: float, py: float) -> bool:
	match division:
		Division.PALE: return px > 0
		Division.FESS: return py > 0
		Division.BEND: return py > px
		Division.BEND_SINISTER: return py > -px
		Division.QUARTERLY: return (px > 0) != (py > 0)
		Division.SALTIRE: return absf(px) > absf(py)
	return false


# Pezza: true dove c'è, in un campo `w` x `h`; `edge`: il pixel tocca il bordo (la bordura)
static func on_ordinary(ordinary: int, px: float, py: float, w: float, h: float, edge: bool) -> bool:
	var s := minf(w, h)
	match ordinary:
		Ordinary.CHIEF: return py < -h / 4  # sopra la figura, che sta al centro
		Ordinary.BASE: return py > h / 4
		Ordinary.PALE: return absf(px) < s / 6
		Ordinary.FESS: return absf(py) < s / 6
		Ordinary.BEND: return absf(px - py) < s / 4
		Ordinary.CROSS: return absf(px) < s / 8 or absf(py) < s / 8
		Ordinary.SALTIRE: return absf(px - py) < s / 5 or absf(px + py) < s / 5
		Ordinary.CHEVRON: return absf(py - absf(px) + s / 8) < s / 7
		Ordinary.BORDURE: return edge
	return false


static func tincture_at(a: Dictionary, px: float, py: float, w: float, h: float, edge: bool) -> Color:
	var t: int = a.field2 if divided(a.division, px, py) else a.field
	return TINCTURE_COLORS[a.ordinary_tincture if on_ordinary(a.ordinary, px, py, w, h, edge) else t]


# Lo scudo 16x16: la forma, il campo (partizione e pezza) e la figura 8x8 al centro
static func arms_texture(a: Dictionary, crown := 0) -> ImageTexture:
	var sheet := image_of(ARMS_SHEET)
	var field := func(x: int, y: int) -> bool:  # dentro lo scudo, non sul bordo scuro
		if x < 0 or y < 0 or x >= 16 or y >= 16:
			return false
		var m := sheet.get_pixel(a.shape * 16 + x, y)
		return m.a > 0 and m.r > 0.5
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			if not field.call(x, y):
				img.set_pixel(x, y, sheet.get_pixel(a.shape * 16 + x, y))  # il bordo, o niente
				continue
			var edge := range(-1, 2).any(func(dx): return range(-1, 2).any(func(dy): return not field.call(x + dx, y + dy)))
			var color := tincture_at(a, x - 7.5, y - 7.5, 14.0, 14.0, edge)
			if a.charge != Charge.NONE and x >= 4 and y >= 4 and x < 12 and y < 12 \
					and sheet.get_pixel((a.charge - 1) * 8 + x - 4, 16 + y - 4).a > 0:
				color = TINCTURE_COLORS[a.charge_tincture]
			img.set_pixel(x, y, color)
	if crown > 0:  # la corona del titolo sopra lo scudo, con l'ultima riga sul suo bordo: 16x21
		var crowned := Image.create(16, 16 + CROWN_RISE, false, Image.FORMAT_RGBA8)
		crowned.blit_rect(img, Rect2i(0, 0, 16, 16), Vector2i(0, CROWN_RISE))
		crowned.blend_rect(sheet, Rect2i((crown - 1) * 16, ARMS_CROWN_Y, 16, CROWN_RISE + 1), Vector2i.ZERO)
		img = crowned
	return ImageTexture.create_from_image(img)


# Il drappo degli stendardi, 64x16 come BANNER_DRAPE: in ogni fotogramma il campo, la pezza e la figura 5x5,
# ombreggiati dalle pieghe. Si disegna sopra il drappo rosso del foglio dei mobili
static func banner_texture(a: Dictionary) -> ImageTexture:
	var drape := image_of(BANNER_DRAPE)
	var sheet := image_of(ARMS_SHEET)
	var img := Image.create(drape.get_width(), TILE, false, Image.FORMAT_RGBA8)
	for f in drape.get_width() / TILE:
		var cells: Array[Vector2i] = []
		for y in TILE:
			for x in TILE:
				if drape.get_pixel(f * TILE + x, y).a > 0:
					cells.append(Vector2i(x, y))
		var box := Rect2i(cells[0], Vector2i.ONE)
		for cell in cells:
			box = box.expand(cell + Vector2i.ONE)
		var mid := Vector2(box.position) + Vector2(box.size - Vector2i.ONE) / 2.0
		var corner := Vector2i((mid - Vector2.ONE * 2).floor())  # della figura 5x5
		for cell in cells:
			var edge := SIDES.any(func(d): return not cells.has(cell + d))
			var color := tincture_at(a, cell.x - mid.x, cell.y - mid.y, box.size.x, box.size.y, edge)
			var c := cell - corner
			if a.charge != Charge.NONE and c.x >= 0 and c.y >= 0 and c.x < 5 and c.y < 5 \
					and sheet.get_pixel((a.charge - 1) * 5 + c.x, 24 + c.y).a > 0:
				color = TINCTURE_COLORS[a.charge_tincture]
			if drape.get_pixel(f * TILE + cell.x, cell.y).r < 0.8:
				color = color.darkened(1.0 - BANNER_SHADE)
			img.set_pixelv(Vector2i(f * TILE, 0) + cell, color)
	return ImageTexture.create_from_image(img)


# Uno stemma a caso che rispetta la regola degli smalti (metallo su colore, colore su metallo): un campo partito
# resta senza pezza né figura; su un campo pieno pezza e figura hanno l'altro smalto, la figura solo se la pezza non
# passa dal centro (CENTRAL)
static func random_arms() -> Dictionary:
	var metal: int = METALS.pick_random()
	var colour: int = Tincture.values().filter(func(t): return t not in METALS).pick_random()
	var field := metal if randf() < 0.5 else colour
	var other := colour if field == metal else metal
	var a := {"shape": randi() % Shape.size(), "division": Division.PLAIN, "field": field, "field2": other,
		"ordinary": Ordinary.NONE, "ordinary_tincture": other, "charge": Charge.NONE, "charge_tincture": other}
	if randf() < 0.4:
		a.division = randi_range(1, Division.size() - 1)
		return a
	if randf() < 0.6:
		a.ordinary = randi_range(1, Ordinary.size() - 1)
	if a.ordinary not in CENTRAL and (randf() < 0.8 or a.ordinary == Ordinary.NONE):
		a.charge = randi_range(1, Charge.size() - 1)
	return a

# il colono `c` (il fotogramma `src` dei fogli) in `dst` di `canvas`, un livello sull'altro (vedi figure_layers)
static func draw_figure(canvas: CanvasItem, dst: Rect2, src: Rect2, c: Colonist, shade := Color.WHITE) -> void:
	for layer in figure_layers(c):
		canvas.draw_texture_rect_region(layer[0], dst, layer_src(src, layer), layer[2] * shade)


# Livelli dello sprite di `c`, dal basso: [foglio, voce del foglio (i 96x64 uno sotto l'altro), tinta].
# Corpo, maglia e mantello; l'armatura sopra la maglia; capelli, acconciatura e barba; il copricapo sopra i capelli;
# il corredo degli avventurieri; per ultimo quello che ha in mano (a mani vuote, nei lavori, un attrezzo qualunque)
static func figure_layers(c: Colonist) -> Array:
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
	for k in c.kit + ([Look.SHIELD] if c.gear.has(Slot.SHIELD) else []):  # corredo degli avventurieri, lo scudo
		layers.append([COLONIST_GEAR, k, Color.WHITE])
	var hands = c.gear.get(Slot.HANDS)
	layers.append([COLONIST_HANDS, GEAR[hands]["look"] if hands != null else Held.TOOL, Color.WHITE])
	return layers


# il fotogramma `src` nella voce del foglio di `layer` (ogni voce: 4 direzioni, alte una casella)
static func layer_src(src: Rect2, layer: Array) -> Rect2:
	return Rect2(src.position + Vector2(0, layer[1] * 4 * TILE), src.size)


func frame_of(c: Colonist) -> int:
	if not c.path.is_empty():
		return WALK_CYCLE[int(c.walked / (TILE / 2.0)) % WALK_CYCLE.size()]
	if is_working(c) and c.job in [Job.HUNT, Job.FIGHT] and has_bow(c):  # tende l'arco, mira e scocca (vedi Job.HUNT)
		return BOW_LOOSE if c.work_left > c.work_total * (1.0 - BOW_LOOSE_PART) else BOW_DRAW
	if is_working(c):
		return WORK_CYCLE[int((c.work_total - c.work_left) / SWING_TIME * WORK_CYCLE.size()) % WORK_CYCLE.size()]
	return IDLE_CYCLE[int(c.idle / BREATH_TIME * IDLE_CYCLE.size()) % IDLE_CYCLE.size()]


func center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2.ONE * TILE / 2.0


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i((pos / TILE).floor())
