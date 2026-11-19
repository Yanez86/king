extends Node2D

const MAP_SIZE := Vector2i(100, 100)
const TILE := 16            # pixel per tile
const SPEED := 4.0          # tile al secondo
const STONE_PER_CELL := 5   # pietra (o ferro, carbone) in un masso, per casella (un 2x2 ne ha 20): vedi full_stock
const ORE_VEIN := 0.35      # soglia del rumore delle vene: più alta, meno minerale nella roccia (vedi generate_map)
const UPROOT_TIME := 1.5    # secondi per estirpare un'erbaccia o un cespuglio
const BERRIES_PER_BUSH := 5 # bacche (vegetali) su un cespuglio maturo
const BERRY_REGROW := 2.0   # giorni prima che il cespuglio rifaccia le bacche
# Orto (Tech.GARDEN): caselle di prato segnate con "Garden" (vedi garden). Le caselle che si toccano fanno un campo,
# col suo cartello (vedi update_fields, open_field): la coltura di ogni anno la dice il piano di rotazione (vedi plans).
# Il contadino (abilità raccogliere) semina, e coi tempi veri (CROP_DAYS) raccoglie CROP_YIELD a casella secondo la
# fertilità (vedi soil, crop_yield): a 60, mezzo crudo a casella al giorno. Si semina quando la terra è tiepida
# (SOW_TEMP, la media del giorno) e solo se il raccolto matura prima dell'inverno; il primo giorno d'inverno il gelo si
# prende quello che è rimasto nei campi
const CROP_DAYS := [60.0, 90.0, 100.0, 60.0]  # per Crop: giorni dalla semina al raccolto
const CROP_YIELD := [30, 45, 20, 0]     # per Crop: quanti a casella, a fertilità 60; il sovescio niente: si interra
const CROP_RES := [Res.TURNIP, Res.CABBAGE, Res.BEANS, -1]
const CROP_ICON := [Res.TURNIP, Res.CABBAGE, Res.BEANS, Res.BEANS]  # nella pianificazione
const CROP_SOIL := [-8, -15, 10, 20]    # per Crop: fertilità a raccolto (le fave, legumi, la restituiscono; interrate di più)
const SOW_TEMP := 6.0       # gradi, la media del giorno: dal tardo Disgelo (vedi atmosphere.mean_temperature)
# Fertilità per casella, 0-100, nascosta (vedi soil): dalla mappa tra SOIL_RANGE, più ricca vicino all'acqua, più povera
# accanto alla roccia; un albero abbattuto lascia l'humus. La resa va per 0,4 + fertilità/100. A Capodanno ogni casella
# d'orto si riposa (SOIL_WINTER), di più dopo un anno a maggese, senza raccolti (SOIL_FALLOW)
const SOIL_RANGE := [30.0, 80.0]
const SOIL_WATER := 10      # entro 3 caselle dall'acqua
const SOIL_ROCK := -15      # accanto alla roccia
const SOIL_HUMUS := 15      # abbattuto un albero, a quella casella
const SOIL_WINTER := 5
const SOIL_FALLOW := 25
const TIRED := [1.0, 0.75, 0.5]  # resa con la stessa coltura per la 1a, 2a, 3a (o più) volta di fila sulla stessa casella
const SOIL_EYE := 5         # da questo livello di raccogliere il contadino riconosce la terra che lavora (soil_known)
const SOIL_PALE := Color(0.85, 0.8, 0.45)  # le piante su terra povera: smorte, verso il giallo (vedi draw_garden)
# Piano dei campi (vedi plans, la pianificazione a gantt in draw_plan): per ogni anno del ciclo, da 1 a PLAN_YEARS, le
# colture una dopo l'altra, ognuna dal suo giorno dell'anno (da SOW_FROM, quando di solito la terra è tiepida), tutte
# finite prima dell'inverno. Un anno senza colture è a maggese. Senza piano, DEFAULT_PLAN
const SOW_FROM := 22
const CROP_NAMES := ["Turnips", "Cabbages", "Beans", "Green manure"]
const CROP_COLORS := [Color("8e5aa8"), Color("6f9e3c"), Color("8a6a44"), Color("4f8f78")]
# Concimazione (Tech.MANURING): se c'è un cumulo del compost, il cibo che marcisce e le erbacce estirpate diventano
# marcio (Res.ROT), che fuori dal cumulo sparisce nella terra in pochi giorni (SHELF_LIFE); al cumulo, in COMPOST_DAYS giorni ogni
# ROT_PER_COMPOST diventano un compost. La carbonaia lascia la cenere. Il contadino (lavoro Concimare, colonna Coltivare)
# sparge un concime (MANURE_SOIL, prima il compost) su una casella d'orto che si semina entro MANURE_AHEAD giorni: una
# volta per semina, nei campi che lo vogliono. Il sovescio è una coltura (Crop.GREEN): fave che non si raccolgono, si
# interrano in fiore
const COMPOST_DAYS := 10.0
const ROT_PER_COMPOST := 4
const MANURE_SOIL := {Res.COMPOST: 15, Res.ASH: 5}
const MANURE_AHEAD := 15    # giorni prima della semina
const MANURE_TIME := 3.0    # secondi per spargerlo, a livello 5 (vedi skill_time)
const DEFAULT_PLAN := [[[Crop.TURNIP, 22], [Crop.TURNIP, 82], [Crop.TURNIP, 142], [Crop.TURNIP, 202]]]  # rape, quante ne stanno
const CLASSIC_PLAN := [[[Crop.CABBAGE, 22], [Crop.CABBAGE, 112], [Crop.TURNIP, 202]],
	[[Crop.TURNIP, 22], [Crop.TURNIP, 82], [Crop.TURNIP, 142], [Crop.TURNIP, 202]], [[Crop.BEANS, 22], [Crop.BEANS, 122]], []]
const PLAN_YEARS := 4
const PLAN_DAY := 2.0       # pixel per giorno nella pianificazione
const PLAN_NAME := 200      # pixel: la colonna coi nomi dei campi
const PLAN_AXIS := 36       # pixel: stagioni e mesi in testa
const PLAN_ROW := 40        # pixel: una riga per campo
const PLAN_COLD := Color(0.63, 0.75, 0.86, 0.22)   # prima di SOW_FROM: la terra fredda, a righe
const PLAN_WINTER := Color(0.47, 0.55, 0.75, 0.3)  # l'inverno
# Ricerche della terra: Saggio del terreno, la lente (vedi draw_soil_lens) in tre fasce; Almanacco agrario cinque fasce e
# la tendenza (rispetto a soil_year_ago, oltre SOIL_TREND); Catasto i numeri e la previsione. Fasce: sotto ogni soglia
const SOIL_BANDS := [[40, 70], [20, 40, 60, 80]]
const SOIL_WORDS := [["Poor", "Average", "Rich"], ["Very poor", "Poor", "Average", "Good", "Rich"]]
const SOIL_COLORS := [Color("b0502e"), Color("d08a3a"), Color("d8c24a"), Color("8fb84a"), Color("3f9a3a")]  # dalla più povera
const SOIL_TREND := 3       # punti di fertilità in un anno: sotto, la terra "regge"
const FARM_TIME := 4.0      # secondi per seminare o raccogliere una casella, a livello 5 (vedi skill_time)
const CARRY_MAX := 10       # quantità massima trasportata per viaggio, di una risorsa sola
const BUILD_TIME := 2.0     # secondi per costruire una casella
const LOOK_AGAIN := 0.5     # secondi tra una ricerca di lavoro e l'altra, per chi non ne trova
const RETRY_AFTER := 10.0   # secondi di gioco prima di riprovare a raggiungere una casella irraggiungibile
const COLONIST_COUNT := 3   # coloni all'inizio, oltre al sovrano: nella radura, senza niente di costruito
const TEST_PEOPLE := 3      # nei test (game_start false): il sovrano e due coloni, quelli su cui sono fatte le prove
const ROOM_MAX := 400       # caselle: una zona chiusa più grande non è una stanza, è il mondo fuori
const TUNIC_COLORS := [Color("a33b3b"), Color("3b5ea3"), Color("c9a23b"), Color("6e3ba3"), Color("d8d0c0")]
const CAPE_COLORS := [Color("2f4a6e"), Color("6e2f2f"), Color("5a3b6e"), Color("4a4a4a"), Color("7a5a2f")]
const HAIR_COLORS := [Color("3b2a1e"), Color("d9b35b"), Color("a8462f"), Color("8b5a2b"), Color("2a2a2a")]
const SIDES := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const TREE_SIDES := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]  # da sopra la chioma coprirebbe chi taglia

enum Job { NONE, CHOP, MINE, UPROOT, HAUL, BUILD, FURNISH, HARVEST, SLEEP, EAT, COOK, FISH, HUNT, EQUIP, CRAFT, FIGHT, FLEE,
	RELAX, TANTRUM, TRAVEL, STUDY, GOVERN, PROTEST, REPAIR, CUT_ICE, DOUSE, FARM, FERTILIZE, OATH }
const WORK_JOBS := [Job.CHOP, Job.MINE, Job.UPROOT, Job.HAUL, Job.BUILD, Job.FURNISH, Job.HARVEST, Job.COOK, Job.FISH,
	Job.HUNT, Job.CRAFT, Job.STUDY, Job.GOVERN, Job.REPAIR, Job.CUT_ICE, Job.FARM, Job.FERTILIZE]  # contano come ore di lavoro
# Tabella delle priorità (in cima alla finestra Jobs): per colono e per lavoro da 1 (prima) a PRIORITY_LEVELS (dopo),
# 0 mai. Si prende il lavoro disponibile con la priorità più alta; a pari priorità nell'ordine di Work, e di un lavoro
# il più vicino (vedi find_work). All'inizio tutto PRIORITY_DEFAULT: l'ordine di Work
enum Work { COOK, CRAFT, CHOP, MINE, GATHER, FARM, FISH, HUNT, BUILD, HAUL, GOVERN, STUDY }
const PRIORITY_DEFAULT := 3
const PRIORITY_LEVELS := 4
const WORK_ICONS := [preload("res://art/icon_meal.png"), preload("res://art/icon_ingot.png"), preload("res://art/icon_chop.png"),
	preload("res://art/icon_mine.png"), preload("res://art/icon_harvest.png"), preload("res://art/icon_garden.png"),
	preload("res://art/icon_fishing.png"), preload("res://art/icon_hunting.png"), preload("res://art/icon_build.png"),
	preload("res://art/icon_resources.png"), preload("res://art/icon_authority.png"), preload("res://art/icon_study.png")]
const WORK_INFO := ["Cooking meals at the campfire or the hearth.", "Forge, workbench, spinning wheel, carpenter's bench, furnace.",
	"Felling the marked trees.", "Mining the marked boulders, cutting ice.", "Picking bushes and flax, uprooting.",
	"Sowing, harvesting and fertilizing the garden.", "Fishing at the marked water.", "Hunting the marked animals.",
	"Building, furnishing, repairing roofs.", "Carrying things into the warehouses.",
	"Governing from the throne: only the ruler.", "Studying at a desk."]
const PRIORITY_COLORS := [Color("c86450"), Color("e8c34a"), Color("e6e2d0"), Color("b0aca0"), Color("8a8678")]  # mai, poi 1-4
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
	STEEL, PARCHMENT, INK, ICE, TURNIP, CABBAGE, BEANS, ROT, COMPOST, ASH }  # ICE: blocchi tagliati dall'acqua gelata, per la
	# ghiacciaia (vedi Order.ICE); TURNIP, CABBAGE, BEANS: dall'orto (vedi garden), si conservano a lungo, le fave secche più
	# di tutto; ROT, COMPOST, ASH: i concimi (vedi Tech.MANURING)
const STACK_MAX := {Res.WOOD: 100, Res.STONE: 50, Res.VEG: 50, Res.TURNIP: 50, Res.CABBAGE: 50, Res.BEANS: 50, Res.ROT: 40, Res.COMPOST: 30, Res.ASH: 30, Res.IRON: 50, Res.COAL: 50, Res.MEAL: 20, Res.FINE_MEAL: 20,
	Res.MEAT: 50, Res.FISH: 50, Res.HIDE: 50, Res.INGOT: 50, Res.FLAX: 50, Res.BOWSTRING: 50, Res.PICKAXE: 10, Res.AXE: 10, Res.SICKLE: 10, Res.BOW: 10,
	Res.LEATHER_ARMOR: 10, Res.LEATHER_HOOD: 10, Res.HELMET: 10, Res.CHAINMAIL: 10, Res.SWORD: 10, Res.GOLD: 100, Res.DAGGER: 10,
	Res.CHALICE: 5, Res.OLD_BANNER: 5, Res.BUST: 5, Res.CROWN: 5, Res.NOTEBOOK: 10, Res.TOME: 10, Res.CODEX: 10, Res.HARDTACK: 50, Res.SMOKED_MEAT: 50, Res.SMOKED_FISH: 50, Res.SHIELD: 10, Res.STEEL: 50, Res.PARCHMENT: 50, Res.INK: 20, Res.ICE: 50}  # quantità massima per mucchio (casella)
const MEALS := [Res.FINE_MEAL, Res.MEAL]  # cotti: chi ha fame li prende in quest'ordine, poi il crudo
const RAW_FOOD := [Res.VEG, Res.FISH, Res.MEAT, Res.SMOKED_FISH, Res.SMOKED_MEAT, Res.TURNIP, Res.CABBAGE, Res.BEANS]  # crudo: si cucina, o si mangia in quest'ordine se non ci sono pasti (prima quello che dura meno)
const START_GOLD := 60      # monete all'inizio, a terra nella radura: le si spende quando sono in un magazzino
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
	Res.VEG: ItemKind.FOOD, Res.TURNIP: ItemKind.FOOD, Res.CABBAGE: ItemKind.FOOD, Res.BEANS: ItemKind.FOOD, Res.MEAL: ItemKind.FOOD, Res.FINE_MEAL: ItemKind.FOOD, Res.MEAT: ItemKind.FOOD, Res.FISH: ItemKind.FOOD,
	Res.PICKAXE: ItemKind.TOOL, Res.AXE: ItemKind.TOOL, Res.SICKLE: ItemKind.TOOL,
	Res.BOW: ItemKind.WEAPON, Res.SWORD: ItemKind.WEAPON, Res.DAGGER: ItemKind.WEAPON,
	Res.LEATHER_ARMOR: ItemKind.ARMOR, Res.LEATHER_HOOD: ItemKind.ARMOR, Res.HELMET: ItemKind.ARMOR, Res.CHAINMAIL: ItemKind.ARMOR,
	Res.GOLD: ItemKind.COINS,
	Res.CHALICE: ItemKind.RELIC, Res.OLD_BANNER: ItemKind.RELIC, Res.BUST: ItemKind.RELIC, Res.CROWN: ItemKind.RELIC,
	Res.NOTEBOOK: ItemKind.BOOK, Res.TOME: ItemKind.BOOK, Res.CODEX: ItemKind.BOOK, Res.HARDTACK: ItemKind.FOOD,
	Res.SMOKED_MEAT: ItemKind.FOOD, Res.SMOKED_FISH: ItemKind.FOOD, Res.SHIELD: ItemKind.ARMOR,
	Res.STEEL: ItemKind.MATERIAL, Res.PARCHMENT: ItemKind.MATERIAL, Res.INK: ItemKind.MATERIAL, Res.ICE: ItemKind.MATERIAL,
	Res.ROT: ItemKind.MATERIAL, Res.COMPOST: ItemKind.MATERIAL, Res.ASH: ItemKind.MATERIAL,
}
# cibo: quanto sazia (vedi eat) e in quanti giorni marcisce a terra fuori (vedi spoil); in magazzino ci mette il doppio.
# Il crudo sazia meno e può intossicare (vedi poison_chance), i pasti no e danno un bonus (vedi Cond)
const FOOD := {Res.VEG: 35.0, Res.TURNIP: 35.0, Res.CABBAGE: 35.0, Res.BEANS: 40.0, Res.FISH: 30.0, Res.MEAT: 40.0, Res.MEAL: 100.0, Res.FINE_MEAL: 100.0,
	Res.SMOKED_FISH: 30.0, Res.SMOKED_MEAT: 40.0}
const SHELF_LIFE := {Res.VEG: 3.0, Res.FISH: 1.5, Res.MEAT: 2.0, Res.MEAL: 3.0, Res.FINE_MEAL: 3.0,
	Res.SMOKED_FISH: 6.0, Res.SMOKED_MEAT: 8.0, Res.TURNIP: 10.0, Res.CABBAGE: 14.0, Res.BEANS: 60.0,
	Res.ROT: 5.0}  # il marcio, fuori dal cumulo del compost, sparisce nella terra  # affumicati: quattro volte il fresco
const SPOIL_STORED := 0.5   # in magazzino il cibo marcisce a metà velocità
const SPOIL_PANTRY := 1.0 / 3  # in dispensa a un terzo: dura il triplo che fuori
# probabilità di intossicarsi mangiando crudo: [appena preso, quasi marcio], in mezzo in proporzione
const POISON := {Res.VEG: [0.05, 0.4], Res.FISH: [0.1, 0.5], Res.MEAT: [0.15, 0.6], Res.SMOKED_FISH: [0.05, 0.5],
	Res.SMOKED_MEAT: [0.05, 0.6], Res.TURNIP: [0.02, 0.3], Res.CABBAGE: [0.02, 0.3],
	Res.BEANS: [0.01, 0.15]}
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
enum Errand { NONE, ARRIVE, LEAVE, DEPART, RETURN, VISIT }  # VISIT: il viandante, al trono (vedi visit_cells)
# cosa sta facendo chi ha questo lavoro, nell'elenco degli abitanti (vedi doing; tradotti col contesto "doing")
const DOING := {Job.CHOP: "Chopping a tree", Job.MINE: "Mining", Job.UPROOT: "Uprooting", Job.HARVEST: "Harvesting",
	Job.EAT: "Eating", Job.COOK: "Cooking", Job.FISH: "Fishing", Job.HUNT: "Hunting", Job.EQUIP: "Fetching gear",
	Job.FIGHT: "Fighting", Job.FLEE: "Fleeing", Job.TANTRUM: "Storming off in a rage", Job.STUDY: "Studying",
	Job.GOVERN: "Holding audience", Job.PROTEST: "Protesting in the throne room", Job.REPAIR: "Repairing a roof",
	Job.CUT_ICE: "Cutting ice", Job.DOUSE: "Putting out a fire", Job.FARM: "Tending the garden",
	Job.FERTILIZE: "Fertilizing the garden", Job.OATH: "Swearing loyalty before the throne"}
const CENSUS_COLUMNS := [280, 120, 250]  # px: chi è, l'età, cosa fa; uguali in tutti i riquadri dell'elenco, così si allineano
const CENSUS_FONT := [18, 18, 22]  # dimensioni del testo nell'elenco: sotto il nome, nome età e cosa fa, titoli dei
# gruppi. Più grandi del 16 del tema, per leggerlo meglio (il font è nitido del tutto solo a 11 e 22: un suo pixel è 1/11)
const CENSUS_CARD := Color(0.17, 0.15, 0.2, 0.92)  # fondo dei riquadri
const CENSUS_BORDER := Color("6b5236")             # bordo, color legno
const CENSUS_DIM := Color(0.75, 0.72, 0.68)        # chi è, sotto il nome
# il colore di ogni gruppo: coloni, forestieri, alla locanda, in spedizione
const CENSUS_ACCENTS := [Color("e8c34a"), Color("8fbf4f"), Color("6a9ad8"), Color("d8784a")]
const ERRAND_DOING := {Errand.ARRIVE: "Coming to the inn", Errand.LEAVE: "Leaving", Errand.DEPART: "Setting out on an expedition",
	Errand.RETURN: "Back from an expedition: to the inn", Errand.VISIT: "Coming to ask to stay"}
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
# Chi resta (GDD 4.2.1): l'avventuriero tornato alla locanda con almeno STAY_HAPPY di felicità, STAY_TRIPS spedizioni
# dopo l'ultima volta che gli hanno detto di no (all'inizio: dopo le prime STAY_TRIPS), chiede di restare come colono
# (vedi ask, welcome). Chi resta è forestiero (Cond.FOREIGNER) per FOREIGNER_DAYS giorni
const STAY_TRIPS := 3
const STAY_HAPPY := 60.0
const FOREIGNER_DAYS := 5.0
# Viandanti (GDD 4.2.1): uno alla volta, dal giorno WANDERER_FROM, in media ogni WANDERER_EVERY giorni diviso
# (1 + splendore / WANDERER_SPLENDOR); sopra CROWD coloni l'attesa raddoppia ogni CROWD_DOUBLE coloni in più; ±
# WANDERER_JITTER (vedi wander_wait). Una persona sola, una coppia sposata o una famiglia (WANDERER_GROUPS): adulti di
# WANDERER_AGE anni con WANDERER_SKILLS punti abilità (al più 3 per abilità), i figli di WANDERER_CHILD; uno su
# WANDERER_TOOL porta un attrezzo. Vanno nella sala del trono (se no a un fuoco, se no nella radura), chiedono di restare
# e aspettano la risposta WANDERER_WAIT giorni
const WANDERER_FROM := 10.0
const WANDERER_EVERY := 30.0
const WANDERER_SPLENDOR := 20.0
const CROWD := 8
const CROWD_DOUBLE := 4.0
const WANDERER_JITTER := 0.3
const WANDERER_GROUPS := [0.7, 0.15, 0.15]  # solo, coppia, famiglia (un genitore o una coppia, con un figlio)
const WANDERER_AGE := [16, 45]
const WANDERER_CHILD := [4, 11]
const WANDERER_SKILLS := 4
const WANDERER_TOOL := 0.25
const WANDERER_TOOLS := [Res.PICKAXE, Res.AXE, Res.SICKLE, Res.BOW]
const WANDERER_WAIT := 2.0
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
const SMOKED := [Res.SMOKED_MEAT, Res.SMOKED_FISH]
const SMOKE_TIME := 0.75     # affumicare al fuoco da campo, dove il fumo resta: tempo x (al focolare va su per la canna)
const STATION_ROOM := {Build.CAMPFIRE: RoomKind.KITCHEN, Build.HEARTH: RoomKind.KITCHEN, Build.FURNACE: RoomKind.FORGE, Build.ANVIL: RoomKind.FORGE, Build.WORKBENCH: RoomKind.WORKSHOP,
	Build.SPINNING_WHEEL: RoomKind.WORKSHOP, Build.CARPENTER_BENCH: RoomKind.CARPENTRY, Build.DESK: RoomKind.STUDY}
const STOCK := {Res.INGOT: 10, Res.BOWSTRING: 2, Res.COAL: 5}  # scorte di partenza, vedi keep; i pasti MEALS_PER_COLONIST a testa
enum Order { NONE, CHOP, MINE, UPROOT, BUILD, ERASE, DEMOLISH, HARVEST, FISH, HUNT, ICE, GARDEN }  # cosa segna il trascinamento del mouse
const ORDER_COLORS := [Color.TRANSPARENT, Color.ORANGE, Color("8fd3ff"), Color("9be36a"), Color("e6e2d0"),
	Color("ff5a5a"), Color("c83030"), Color("d84a6a"), Color("6ab0e0"), Color("c87a3a"), Color("bfe6f2"), Color("c8a46a")]  # selezione e segni, per Order
# tasti in HUD/Tools/Row dopo Build, uno alla volta (ButtonGroup "Orders"): vedi toggle_order
const ORDER_TOOLS := {Order.DEMOLISH: "Destroy", Order.MINE: "Mine", Order.CHOP: "Chop", Order.UPROOT: "Uproot",
	Order.HARVEST: "Harvest", Order.GARDEN: "Garden", Order.FISH: "Fish", Order.HUNT: "Hunt", Order.ICE: "Ice"}
const ORDER_ICONS := {Order.CHOP: preload("res://art/icon_chop.png"), Order.MINE: preload("res://art/icon_mine.png"),
	Order.UPROOT: preload("res://art/icon_uproot.png"), Order.HARVEST: preload("res://art/icon_harvest.png"),
	Order.FISH: preload("res://art/icon_fishing.png"), Order.HUNT: preload("res://art/icon_hunting.png"),
	Order.ICE: preload("res://art/icon_ice.png"), Order.GARDEN: preload("res://art/icon_garden.png")}  # le stesse dei tasti: piccole e velate sopra ciò che è segnato
enum RoomKind { NONE, WAREHOUSE, BEDROOM, DORMITORY, KITCHEN, FORGE, WORKSHOP, CARPENTRY, INN, STUDY, THRONE_ROOM, PANTRY, ICEHOUSE }  # tipo di stanza, scelto dal cartello
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
	RoomKind.ICEHOUSE: RoomClass.SERVICE,  # una dispensa di pietra col ghiaccio: col freddo il cibo non marcisce (vedi room_base)
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
	HEARTH,  # il focolare di pietra contro un muro: fa quello che fa il fuoco da campo (vedi ROLE), scalda di più (HEAT)
	WALL_HIDES, DOOR_CURTAIN, TAPESTRY, TILED_STOVE,  # isolano la stanza (INSULATES); la stufa a olle scalda due stanze
	ICE_PIT,  # la fossa del ghiaccio, nella ghiacciaia: ci si portano i blocchi (vedi dest_cells)
	ROAD,  # strada lastricata: ci si cammina più svelti (vedi ROAD_SPEED)
	PALISADE, GATE,  # palizzata e cancello: i lupi non passano; non fanno stanze (vedi update_rooms, beast_path)
	PLASTER,  # intonaco su un muro di legno già fatto: isola di più (PLASTER_INSULATION), diventa bianco (vedi plastered)
	COMPOST_HEAP,  # il cumulo del compost: ci si porta il marcio, che diventa compost (vedi make_compost)
	CRADLE }  # la culla: ci dorme un neonato, invece di stare in braccio (vedi place_babies)
# materiale per casella; per i mobili, per pezzo. Un numero: del materiale del progetto; se no risorsa -> quantità, e
# ogni viaggio porta tutta una risorsa (vedi cost_of, delivered)
const BUILD_COST := {Build.WALL: 5, Build.FLOOR: 2, Build.DOOR: 5, Build.PATH: 1, Build.BED: 10, Build.TABLE: 10, Build.CHAIR: 3,
	Build.LAMP: {Res.WOOD: 2, Res.COAL: 1}, Build.CAMPFIRE: 5, Build.FURNACE: 20, Build.ANVIL: 10, Build.WORKBENCH: 15, Build.SPINNING_WHEEL: 10,
	Build.CARPENTER_BENCH: 15, Build.FLOWER_BED: 3, Build.PLANTER: 5,
	Build.BENCH: 6, Build.BANNER: 4, Build.LANTERN: {Res.WOOD: 3, Res.COAL: 1}, Build.FOUNTAIN: 30, Build.STATUE: 40, Build.NOTICE_BOARD: 8,
	Build.CHALICE: 1, Build.OLD_BANNER: 1, Build.BUST: 1, Build.CROWN: 1, Build.DESK: 10, Build.BOOKSHELF: 12, Build.THRONE: 12, Build.ROAD: 2, Build.DUMMY: 6, Build.WATCHTOWER: 20,
	Build.CANOPY_BED: 20, Build.RUG: 4, Build.WARDROBE: 12, Build.HEARTH: 15,
	Build.WALL_HIDES: 2, Build.DOOR_CURTAIN: 2, Build.TAPESTRY: 4, Build.TILED_STOVE: 20, Build.ICE_PIT: 20, Build.COMPOST_HEAP: 6, Build.CRADLE: 4,
	Build.PALISADE: 4, Build.GATE: 6, Build.PLASTER: 1}
# caselle occupate dai mobili come sono disegnati; girati di un quarto si scambiano larghezza e altezza (vedi piece_rect)
const FURNITURE := {Build.BED: Vector2i(2, 1), Build.TABLE: Vector2i(2, 2), Build.CHAIR: Vector2i.ONE, Build.LAMP: Vector2i.ONE,
	Build.CAMPFIRE: Vector2i.ONE, Build.FURNACE: Vector2i.ONE, Build.ANVIL: Vector2i.ONE, Build.WORKBENCH: Vector2i.ONE,
	Build.SPINNING_WHEEL: Vector2i.ONE, Build.CARPENTER_BENCH: Vector2i.ONE,
	Build.FLOWER_BED: Vector2i.ONE, Build.PLANTER: Vector2i.ONE, Build.BENCH: Vector2i(2, 1), Build.BANNER: Vector2i.ONE,
	Build.LANTERN: Vector2i.ONE, Build.FOUNTAIN: Vector2i(2, 2), Build.STATUE: Vector2i(2, 2), Build.NOTICE_BOARD: Vector2i.ONE,
	Build.CHALICE: Vector2i.ONE, Build.OLD_BANNER: Vector2i.ONE, Build.BUST: Vector2i.ONE, Build.CROWN: Vector2i.ONE,
	Build.DESK: Vector2i.ONE, Build.BOOKSHELF: Vector2i.ONE, Build.THRONE: Vector2i.ONE, Build.DUMMY: Vector2i.ONE,
	Build.WATCHTOWER: Vector2i.ONE, Build.CANOPY_BED: Vector2i(2, 1), Build.RUG: Vector2i(2, 1), Build.WARDROBE: Vector2i.ONE,
	Build.HEARTH: Vector2i.ONE, Build.WALL_HIDES: Vector2i.ONE, Build.DOOR_CURTAIN: Vector2i.ONE, Build.TAPESTRY: Vector2i.ONE,
	Build.TILED_STOVE: Vector2i.ONE, Build.ICE_PIT: Vector2i(2, 2), Build.COMPOST_HEAP: Vector2i.ONE,
	Build.CRADLE: Vector2i.ONE}
# mobili animati: secondi per fotogramma; i fotogrammi stanno nelle colonne dei quarti di giro (sono simmetrici)
const ANIMATED := {Build.CAMPFIRE: 0.15, Build.BANNER: 0.3, Build.FOUNTAIN: 0.2}
const ANY_MATERIAL := [Build.WALL, Build.FLOOR]  # di legno o di pietra
const BARRIERS := [Build.WALL, Build.PALISADE]  # solidi: si fanno solo lungo il bordo del riquadro, chiudono la strada
const PAVING := [Build.FLOOR, Build.PATH, Build.ROAD]  # a terra: si calpestano, ci stanno sopra i mobili, l'erba ci sborda sopra
# materiale fisso; il resto solo di legno
# i cimeli: la decorazione si fa con l'oggetto trovato nelle rovine, uno a pezzo
const RELICS := {Build.CHALICE: Res.CHALICE, Build.OLD_BANNER: Res.OLD_BANNER, Build.BUST: Res.BUST, Build.CROWN: Res.CROWN}
const BUILD_RES := {Build.PATH: Res.STONE, Build.ROAD: Res.STONE, Build.RUG: Res.HIDE, Build.FURNACE: Res.STONE, Build.HEARTH: Res.STONE,
	Build.WALL_HIDES: Res.HIDE, Build.DOOR_CURTAIN: Res.HIDE, Build.TAPESTRY: Res.FLAX, Build.TILED_STOVE: Res.STONE, Build.PLASTER: Res.STONE,
	Build.ICE_PIT: Res.STONE, Build.ANVIL: Res.IRON, Build.PLANTER: Res.STONE, Build.FOUNTAIN: Res.STONE,
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
	RoomKind.ICEHOUSE: {Build.ICE_PIT: 1},  # e solo muri di pietra o roccia, nessun fuoco (vedi room_meets)
}
# lente delle stanze (tasto col cartello in basso): le stanze finite velate col colore del loro tipo, per RoomKind
const ROOM_COLORS := [Color("e6e2d0"), Color("c9a23b"), Color("3b8fd3"), Color("8a5ad3"), Color("e0703a"), Color("d33b3b"),
	Color("3bb08a"), Color("9be36a"), Color("d38a3b"), Color("6a9ae0"), Color("c48ad8"), Color("8fd8e8"), Color("dff2fa")]
# comfort di una stanza, 0-COMFORT_MAX: lo danno i mobili (per pezzo) e il pavimento (tutto se copre la stanza intera),
# per il materiale. A metà né bonus né malus; fuori dalle stanze è 0. Vedi room_comfort e comfort_of
const COMFORT_MAX := 10
const BEDS := [Build.BED, Build.CANOPY_BED]  # ci si dorme; per le camere il baldacchino vale un letto (vedi room_meets)
# mobili che fanno le veci di un altro: per i tipi di stanza (ROOM_NEEDS), le ricette (RECIPES) e lo svago attorno al fuoco
const ROLE := {Build.CANOPY_BED: Build.BED, Build.HEARTH: Build.CAMPFIRE}
const COMFORT := {Build.CANOPY_BED: 2.0, Build.RUG: 1.0, Build.WARDROBE: 1.0, Build.FLOOR: 1.0, Build.BED: 1.0, Build.TABLE: 1.0, Build.CHAIR: 0.5, Build.LAMP: 0.5, Build.CAMPFIRE: 0.5, Build.HEARTH: 0.5,
	Build.BENCH: 0.5}
const COMFORT_MATERIAL := {Res.STONE: 1.5}  # il resto vale 1
const COMFORT_EFFECT := 0.2  # a comfort 0 un'attività richiede il 20% di tempo in più, al massimo il 20% in meno
# Freddo e pioggia tolgono comfort, anche sotto lo 0 (vedi weather_comfort): -1 ogni COLD_STEP gradi sotto COLD_FROM;
# fuori, sotto la pioggia, fino a -WET_COMFORT. Sotto un tetto non piove e la temperatura va verso quella della stanza
# (ROOM_TEMP; STORE_TEMP dove non vive nessuno) di quanto isolano i muri (WALL_INSULATION, in media); ogni fuoco della
# stanza la alza di HEAT, e focolare e fornace ne passano THROUGH_WALL alla stanza dietro il muro di legno che hanno
# alle spalle (vedi temperature_at). Ogni punto di protezione addosso vale un grado. Da svegli il comfort cala di
# DISCOMFORT_DROP al giorno per ogni punto tolto; risale solo dormendo. Il caldo non toglie comfort
const COLD_FROM := 12.0
const COLD_STEP := 4.0
const WET_COMFORT := 2.0
const ROOM_TEMP := 15.0
const STORE_TEMP := 5.0      # magazzino e dispensa: senza gente, vanno verso il fresco (vedi STORES)
const STORES := [RoomKind.WAREHOUSE, RoomKind.PANTRY, RoomKind.ICEHOUSE]
const WALL_INSULATION := {Res.WOOD: 0.5, Res.STONE: 0.7}  # per materiale; le porte contano come legno
const ROCK_INSULATION := 0.85  # la roccia della mappa che chiude una stanza: la cantina
const INSULATION_MAX := 0.9
const FIRE_HEAT := 8.0       # il fuoco da campo
# gradi in più nella stanza del fuoco; ponytail: uguale in ogni stanza, secondo le caselle se le stanze si fanno grandi
const HEAT := {Build.CAMPFIRE: FIRE_HEAT, Build.HEARTH: 12.0, Build.FURNACE: 15.0, Build.TILED_STOVE: 10.0}
const THROUGH_WALL := 0.5    # parte del calore di focolare e fornace che passa il muro di legno alle loro spalle
# fuochi che passano il muro alle spalle -> parte del calore; la stufa a olle tutto, anche attraverso la pietra
const THROUGH := {Build.HEARTH: THROUGH_WALL, Build.FURNACE: THROUGH_WALL, Build.TILED_STOVE: 1.0}
const THROUGH_STONE := [Build.TILED_STOVE]
const BACKS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]  # le spalle di un mobile, per quarto di giro
const AGAINST := {Build.HEARTH: [Build.WALL], Build.WALL_HIDES: [Build.WALL], Build.TAPESTRY: [Build.WALL],
	Build.TILED_STOVE: [Build.WALL], Build.DOOR_CURTAIN: [Build.DOOR]}  # mobili da addossare: quello che vogliono alle spalle (vedi backed)
# pezzi che isolano la stanza dove stanno: [quanto in più, al massimo quanti ne contano]; l'intonaco porta i muri di
# legno a PLASTER_INSULATION; le tende del baldacchino scaldano chi ci dorme (BED_WARMTH gradi)
const INSULATES := {Build.WALL_HIDES: [0.05, 3], Build.DOOR_CURTAIN: [0.1, 1], Build.TAPESTRY: [0.05, 3]}
const PLASTER_INSULATION := 0.6
const BED_WARMTH := {Build.CANOPY_BED: 4.0}
# Ghiacciaia (RoomKind.ICEHOUSE): finché nella fossa c'è ghiaccio la stanza va verso ICE_TEMP; il ghiaccio si scioglie,
# ogni giorno, di ICE_MELT blocchi per ogni grado sopra lo zero fuori che passa i muri (1 - isolamento), più ICE_HOLE_MELT
# per ogni buco nel tetto. Si taglia sull'acqua gelata segnata con "Ice", ICE_PER_SPOT blocchi a punto prima di cambiare
const ICE_TEMP := 0.0
const ICE_MELT := 0.4
const ICE_HOLE_MELT := 1.0
const ICE_PER_SPOT := 10
const COLD_WALLS := [Res.STONE]  # la ghiacciaia vuole muri così (o la roccia)
# la fontana in una stanza toglie FOUNTAIN_COOL gradi quando fuori ce ne sono più di FOUNTAIN_FROM
const FOUNTAIN_COOL := 3.0
const FOUNTAIN_FROM := 20.0
const DISCOMFORT_DROP := 24.0  # uno all'ora per punto
# splendore della colonia: lo danno le decorazioni finite, dentro e fuori dalle stanze (vedi colony_splendor).
# ponytail: per ora solo il totale in alto; poi terrà felici i coloni e sbloccherà cose (strade, feste: vedi GDD)
const SPLENDOR := {Build.FLOWER_BED: 1, Build.PLANTER: 1, Build.BENCH: 1, Build.BANNER: 2, Build.LANTERN: 1,
	Build.FOUNTAIN: 6, Build.STATUE: 8, Build.TAPESTRY: 2, Build.CHALICE: 3, Build.OLD_BANNER: 4, Build.BUST: 5, Build.CROWN: 6}
const SPLENDOR_COLOR := Color("e8c34a")
const HEAT_COLOR := Color("f2a03a")
# lente del calore: sopra COLD_FROM, sotto ma senza malus, poi per punti di comfort tolti dal freddo (1, 2, 3 e più)
const HEAT_SCALE := [Color("e8442a"), Color("e8c34a"), Color("8ad0e8"), Color("4a8ae0"), Color("3a3ab0")]
const FROST_COLOR := Color("eef8ff")  # sotto lo zero: il cibo non marcisce
const BLOCKED_COLOR := Color("d84a3a")  # la ✕ sul muro di pietra che il calore non passa
const ROOM_SPACE := 6        # caselle a testa: chi ne ha meno (stanza piena di gente) ha il comfort in proporzione
# suggerimento dei pulsanti di costruzione (vedi build_tip): sotto nome e costo il comfort, poi la descrizione colorata
# menù delle opzioni (Esc o ingranaggio), tab Keybindings: tasti di partenza dei comandi della barra in basso, per
# nome del pulsante in HUD/Tools/Row (quelli che non ci sono partono senza). Cambiati, si salvano: vedi bind_key
const DEFAULT_KEYS := {"Select": KEY_Q, "Build": KEY_B, "Destroy": KEY_X, "Mine": KEY_M, "Chop": KEY_C, "Uproot": KEY_U,
	"Harvest": KEY_H, "Garden": KEY_P, "Fish": KEY_F, "Hunt": KEY_T, "Ice": KEY_Y, "Jobs": KEY_J, "Resources": KEY_I, "Knowledge": KEY_K, "Laws": KEY_G,
	"RoomsLens": KEY_L, "HeatLens": KEY_N, "SoilLens": KEY_O, "Roofs": KEY_V, "Wiki": KEY_F1}
const SPEEDS := {"Pause": 0.0, "Play": 1.0, "Fast": 2.0, "Fastest": 3.0}  # pulsanti in alto a destra, come Space e 1-3
# tab Video delle opzioni: misure della finestra, solo quelle che stanno nello schermo (la prima sempre)
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
# tab System delle opzioni: lingue, col nome nella loro lingua; i testi tradotti sono in locale/<lingua>.po (vedi named)
const LANGUAGES := {"en": "English", "it": "Italiano"}
const WIKI := preload("res://wiki.gd")  # pagine della finestra Wiki: [titolo, testo ricco], tradotte (vedi WIKI.pages)
const FIXED_KEYS := [KEY_SPACE, KEY_1, KEY_2, KEY_3, KEY_E, KEY_R, KEY_ESCAPE]  # velocità, giro dei mobili, menù
# Salvataggi automatici (vedi saves.gd, game_state, restore): una cartella per colonia, coi suoi ultimi SAVES.FILES.
# Si salva fondando la colonia, all'alba (AUTOSAVE_HOUR), tornando al titolo, uscendo e chiudendo la finestra; niente
# salvataggi a mano. Si riprende dal titolo (Continue, Colonies) e dal menù (Load game)
const SAVES := preload("res://saves.gd")
const SAVE_LIST := preload("res://save_list.gd")
# le variabili della partita che si salvano, così come sono (gli oggetti dentro li impacchetta SAVES.Packer); il resto
# si rifà da queste (vedi restore) o è interfaccia. Una variabile nuova dello stato del gioco va aggiunta qui
const SAVED := ["game_id", "map_seed", "ground_cols", "gravel", "clock", "today", "hour", "rocks", "boulders", "ores", "water",
	"trees", "stock", "bushes", "flax", "weeds", "chop_marks", "mine_marks", "uproot_marks", "harvest_marks", "fish_marks",
	"fish_spots", "items", "fresh", "draft", "blueprints", "built", "furniture_draft", "furniture_plans", "furniture",
	"rooms", "rooms_made", "keep", "reserved", "unreachable", "colonists", "ruler", "realm", "arms", "rank", "corpses",
	"fallen", "animals", "arrows", "next_animal", "next_pack", "guests", "next_guest", "ruins", "expeditions",
	"chronicle", "chronicle_days", "board_pick", "study", "researched", "authority", "codified", "enacted", "revoked",
	"granary", "tithe_owed", "next_scholar", "scholar_until", "scholar_books", "scholar_bought", "wanted_hero", "ice_marks", "garden", "sown", "plans", "slot_done", "soil", "soil_year_ago", "soil_known", "compost_since", "manured", "no_manure", "babies",
	"house_name", "regent_for", "coronation_at", "reigns", "next_suitor", "pace", "tired", "last_yield",
	"harvests", "wear", "plastered", "burning",
	"fire_noted", "storm_noted", "delivered", "requests", "next_wanderer"]
const TOAST_TIME := 2000    # millisecondi: "Saved" in alto, poi sparisce (vedi show_toast)
const AUTOSAVE_HOUR := 6    # all'alba, quando i coloni si alzano: il salvataggio di ogni giorno
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
	Build.CAMPFIRE: "A wood fire inside a ring of stones. Burns day and night and warms the room. A kitchen needs one, or a hearth. Smoking is faster here.",
	Build.FURNACE: "A stone furnace. A forge needs one, and an anvil. Smelts iron and coal into ingots. Half its heat goes through a wooden wall at its back.",
	Build.WALL_HIDES: "Hides nailed to a wall, against the draughts. Hang it against a wall.",
	Build.DOOR_CURTAIN: "A heavy leather curtain in front of a door, where the cold gets in. Hang it against a door.",
	Build.TAPESTRY: "Purple linen with a golden lozenge: warmth and splendor. Hang it against a wall.",
	Build.TILED_STOVE: "Glazed green tiles around a slow fire, against a wall: it warms its room and the one behind the wall all the same, through stone too.",
	Build.PLASTER: "Lime plaster over a wooden wall: it keeps the heat in better, and turns the wall white.",
	Build.ICE_PIT: "A stone pit lined with straw, for blocks of ice. An icehouse needs one, stone walls and no fire: while it holds ice, the room tends to 0 °C.",
	Build.COMPOST_HEAP: "Rotten food and uprooted weeds are brought here: in 10 days every 4 become compost, to fertilize the garden.",
	Build.CRADLE: "A rocking cradle. A baby sleeps here instead of in their parents' arms.",
	Build.HEARTH: "A stone fireplace with a chimney, set against a wall. Cooks and warms like a campfire, more. Half its heat goes through a wooden wall at its back, none through stone.",
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
const CROPS := preload("res://art/crops.png")  # 16x16: terra lavorata, poi per Crop germoglio, pianta, matura (vedi draw_garden)
const FIELD_SIGN := preload("res://art/field_sign.png")  # il paletto col cartello di un campo (vedi field_signs)
enum Crop { TURNIP, CABBAGE, BEANS, GREEN }
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
const ROOFS := preload("res://roofs.gd")  # i tetti con la loro facciata, calcolati per ogni rettangolo: vedi update_roofs
const CHIMNEYS := preload("res://art/chimneys.png")  # 32x16: comignolo di pietra, sfiatatoio di legno (vedi chimney_of)
enum Chimney { NONE = -1, STONE, VENT }  # colonne di CHIMNEYS
const OUTLINE := Color("1f1a24")             # contorno, come la "o" degli sprite
const ROOF_TINT := 0.08      # differenza di luce, al massimo, tra un tetto e l'altro
const ROOF_WEAR := preload("res://art/roof_wear.png")  # 48x16: licheni, tegole smosse e muschio, buco (vedi wear)
# Usura dei tetti, per casella (vedi wear_roofs): da LICHEN i licheni, da WORN tegole smosse e muschio (e la si
# ripara), da 1 un buco: lì il tetto non c'è più. Senza temporali una casella arriva al buco in ROOF_LIFE giorni, più o
# meno (ROOF_SPREAD) secondo la casella; un'ora di temporale strappa un tetto con probabilità STORM_TEAR, in 1-3
# caselle, STORM_DAMAGE di usura ciascuna; la neve oltre SNOW_LOAD sui tetti di almeno SNOW_LOAD_AREA caselle che non
# la sciolgono (roof_snow) ne sfonda una con probabilità SNOW_LOAD_HIT all'ora. Le scandole si consumano il doppio
const LICHEN := 0.25
const WORN := 0.5
const ROOF_LIFE := {Res.STONE: 730.0, Res.WOOD: 365.0}
const ROOF_SPREAD := 0.5
const STORM_TEAR := 0.08
const STORM_DAMAGE := [0.3, 0.7]
const SNOW_LOAD := 0.7
const SNOW_LOAD_AREA := 30
const SNOW_LOAD_HIT := 0.02
const REPAIR_TIME := 3.0     # secondi per casella a livello 5 (Job.REPAIR)
const REPAIR_COST := 1       # legna per le scandole, pietra per i coppi
# Incendio (vedi ignite_roofs, burn): ogni giorno un fuoco da campo sotto un tetto di scandole lo accende con
# probabilità FIRE_DAILY; ogni ora di temporale un fulmine colpisce un tetto di scandole con probabilità LIGHTNING_HIT.
# Una casella brucia per BURN_HOURS ore, poi è un buco; intanto il fuoco passa alle scandole accanto (anche di un altro
# tetto) con probabilità FIRE_SPREAD all'ora. I coppi non bruciano. I coloni portano secchi d'acqua (Job.DOUSE):
# riempirlo e gettarlo BUCKET_TIME secondi, ognuno toglie DOUSE_HOURS ore al fuoco; spento, resta FIRE_SCAR di usura
const FIRE_DAILY := 0.02
const LIGHTNING_HIT := 0.01
const BURN_HOURS := 4.0
const FIRE_SPREAD := 0.2
const BUCKET_TIME := 2.0
const DOUSE_HOURS := 2.0
const FIRE_SCAR := 0.3
const BUCKET := preload("res://art/icon_bucket.png")
const ROOF_MELT := 10.0      # gradi di calore che passa il tetto e ci sciolgono tutta la neve (vedi roof_snow)
const CHIMNEY_SNOW := 0.3    # attorno ai comignoli resta questa parte della neve
const WET_ROOF := 0.25       # quanto scurisce il tetto bagnato (atmosphere.wet)
const DRIP_COLOR := Color("a8c8e0")
const FIRE_COLORS := [Color("d8562f"), Color("f2a03a"), Color("ffe6a0")]  # brace, fiamma, cuore (come gli sprite)
const ICE_COLOR := Color("e8f4ff")
const DAY_LENGTH := 240.0   # secondi per giorno a velocità 1x
# Calendario: l'anno si apre col Capodanno (NEW_YEAR), poi quattro stagioni di 3 mesi da MONTH_DAYS giorni, ognuna
# chiusa da un giorno di festa fuori dai mesi (FEASTS): 1 + 4 × 91 = 365 giorni. Il giorno 0 di `clock` è il Capodanno
# dell'anno 1 (vedi date, season, feast)
const MONTH_DAYS := 30
const SEASON_DAYS := 3 * MONTH_DAYS + 1
const YEAR_DAYS := 1 + 4 * SEASON_DAYS
# Età (vedi age_of): col ritmo veloce (Pace.FAST) si invecchia di un anno a stagione, quattro volte il calendario, così
# passano le generazioni; con quello reale (Pace.REAL) di un anno all'anno. Si sceglie nella nuova partita.
# All'arrivo il sovrano ha RULER_AGE anni, gli altri ADULT_AGE; dai OLD_AGE, a ogni compleanno si muore con
# probabilità (età - OLD_AGE + 2) × OLD_AGE_RISK: 4% a 60, 24% a 70, 44% a 80
enum Pace { FAST, REAL }  # il ritmo della vita, scelto nella nuova partita (vedi life_year)
const LIFE_YEARS := [YEAR_DAYS / 4.0, float(YEAR_DAYS)]  # per Pace: giorni per un anno di vita
const RULER_AGE := [20, 30]
const ADULT_AGE := [18, 40]
const OLD_AGE := 60
const OLD_AGE_RISK := 0.02
# Matrimonio (vedi marry): il sovrano adulto e non sposato sposa una persona adulta dell'altro sesso; un colono
# accetta se ha almeno MARRY_HAPPY di felicità. Le nozze: Cond.WEDDING a tutti, WEDDING_AUTHORITY
const ADULT := 16
const MARRY_HAPPY := 50.0
const WEDDING_AUTHORITY := 10
# Figli (vedi conceive, give_birth): una coppia sposata che dorme nella stessa stanza, ogni notte CONCEIVE_CHANCE (la
# donna in FERTILE_AGE, da LATE_FERTILE la metà). La gravidanza dura PREGNANCY anni di vita (nell'ultimo terzo il lavoro
# PREGNANT_SLOW), poi per un anno niente. Ogni talento dei genitori passa al figlio con TRAIT_INHERIT, al più due.
# Fino a CHILD_AGE è un neonato (in `babies`: nella culla o in braccio), poi un bambino, da YOUTH_AGE un ragazzo, da
# ADULT un adulto
const CONCEIVE_CHANCE := 0.01
const CONCEIVE_HOUR := 2
const FERTILE_AGE := [16, 40]
const LATE_FERTILE := 35
const PREGNANCY := 0.75       # anni di vita (vedi pregnancy)
const PREGNANT_SLOW := 1.2
const TRAIT_INHERIT := 0.5
const CHILD_AGE := 4
const YOUTH_AGE := 12
const CHILD_WORK := [Work.GATHER, Work.HAUL]  # i bambini aiutano solo qui, a metà velocità (CHILD_SLOW)
const YOUTH_BANNED := [Work.BUILD, Work.MINE, Work.CHOP, Work.HUNT]  # i lavori pesanti, che i ragazzi non fanno
const CHILD_SLOW := 2.0
const CHILD_SIZE := [0.7, 0.85]  # bambini e ragazzi, più piccoli degli adulti (vedi draw_colonist)
const BABY := preload("res://art/baby.png")
# Successione (vedi succeed): alla morte del sovrano il primo figlio vivo, poi il coniuge, poi un fratello o una sorella;
# se non c'è nessuno, una casata nuova tra i coloni adulti (vedi found_house). Lutto regale per ROYAL_MOURNING_DAYS,
# poi l'incoronazione (CORONATION_AUTHORITY). Un erede minorenne aspetta i 16 anni: intanto regna un reggente
const ROYAL_MOURNING_DAYS := 7.0
const CORONATION_AUTHORITY := 20
# Pretendenti (vedi update_suitors): finché il sovrano può sposarsi e c'è una locanda, ogni SUITOR_EVERY giorni circa
# arriva una persona dell'altro sesso di un'altra casata, col suo stemma e la dote; aspetta SUITOR_STAY giorni. Sposata
# diventa un colono e la dote resta a terra, dove si trova
const SUITOR_EVERY := 20.0
const SUITOR_JITTER := 4.0
const SUITOR_STAY := 5.0
const SUITOR_AGE := [16, 30]
const SUITOR_SKILLS := 6       # punti abilità, al più 3 per abilità
const DOWRY_GOLD := [20, 80]
const DOWRY_ITEM_CHANCE := 0.3
const DOWRY_ITEMS := [[Res.NOTEBOOK, 1], [Res.INGOT, 5], [Res.STEEL, 2]]
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const WINTER := 3  # in SEASONS: niente bacche né lino (vedi new_day)
const MONTHS := ["Thaw", "Sowing", "Blossom", "Highsun", "Haying", "Ripening", "Reaping", "Leaffall", "Mists",
	"Frost", "Deepsnow", "Longnight"]
const NEW_YEAR := "Crown Day"
const FEASTS := ["Flower Feast", "Sickle Feast", "Hearth Feast", "Candle Feast"]  # a fine primavera, estate, autunno, inverno
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
	Res.TURNIP: preload("res://art/icon_turnip.png"),
	Res.CABBAGE: preload("res://art/icon_cabbage.png"),
	Res.BEANS: preload("res://art/icon_beans.png"),
	Res.ROT: preload("res://art/icon_rot.png"),
	Res.COMPOST: preload("res://art/icon_compost.png"),
	Res.ASH: preload("res://art/icon_ash.png"),
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
	Res.ICE: preload("res://art/icon_ice_block.png"),
}
# 256x128, righe: muri di legno, muri di pietra (colonna = lati collegati, vedi WALL_LINKS), pavimenti (colonna = Res,
# poi il sentiero), porte (di fronte, di lato), erba sui pavimenti (lati, angoli, due varianti); vedi structure_src e draw_grass_over
const STRUCTURES := preload("res://art/structures.png")
const PLASTER_ROW := 10      # in STRUCTURES: i muri di legno intonacati
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
	Job.CUT_ICE: [Skill.MINING, 8.0, 2, Res.ICE],      # sull'acqua gelata segnata con "Ice" (vedi ice_marks)
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
enum Cond { POISONED, WELL_FED, FEASTED, AT_TABLE, ATE_RAW, MOURNING, FESTIVE, PILLORIED, HEARD, WEDDING, PREGNANT,
	ROYAL_MOURNING, CORONATION, FOREIGNER }
const CONDITIONS_SHEET := preload("res://art/conditions.png")
const COND_INFO := {
	Cond.POISONED: [1.0, 1.5, 1.0, -20.0, "Ate raw food that was going bad. Works slowly."],
	Cond.WELL_FED: [0.5, 0.9, 0.75, 5.0, "Had a cooked meal. Works faster, less stress."],
	Cond.FEASTED: [0.5, 0.8, 0.5, 10.0, "Had a fine meal. Works much faster, much less stress."],
	Cond.AT_TABLE: [0.5, 1.0, 1.0, 5.0, "Ate sitting at a table."],
	Cond.ATE_RAW: [0.5, 1.0, 1.0, -10.0, "A glutton forced to eat raw food."],
	Cond.MOURNING: [3.0, 1.0, 1.25, -15.0, "A fellow colonist has died."],
	Cond.FESTIVE: [3.0, 1.0, 1.0, 10.0, "Celebrated a feast."],
	Cond.PILLORIED: [1.0, 1.0, 1.0, -10.0, "Put in the stocks for a tantrum or a protest."],
	Cond.HEARD: [0.5, 1.0, 1.0, 10.0, "The ruler listened to their complaint."],
	Cond.WEDDING: [2.0, 1.0, 1.0, 10.0, "Celebrated the ruler's wedding."],
	Cond.PREGNANT: [0.0, 1.0, 1.0, 0.0, "Expecting a child. In the last months works more slowly."],  # fino al parto (due)
	Cond.ROYAL_MOURNING: [ROYAL_MOURNING_DAYS, 1.0, 1.25, -20.0, "The ruler has died."],
	Cond.CORONATION: [2.0, 1.0, 1.0, 10.0, "Celebrated the coronation of the new ruler."],
	Cond.FOREIGNER: [FOREIGNER_DAYS, 1.1, 1.0, -5.0, "New to the colony: doesn't know its ways yet. Works a little slower."],
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
# splendore della colonia arriva a "splendor" e i coloni a "colonists", tutti e due (vedi colony_size, tick, rise):
# cambiano il nome del reame, il titolo del sovrano (per
# Sex), la corona sullo stemma (vedi arms_texture), i sigilli delle leggi e l'autorità di ogni giorno (AUTHORITY_DAILY
# a titolo). Le leggi di una fascia ("tier" in LAWS) si codificano da quel titolo in su.
# ponytail: soglie provvisorie
const TITLES := [
	{"realm": "Lordship", "ruler": ["Lord", "Lady"], "splendor": 0, "colonists": 0, "seals": 2},
	{"realm": "Barony", "ruler": ["Baron", "Baroness"], "splendor": 15, "colonists": 6, "seals": 3},
	{"realm": "County", "ruler": ["Count", "Countess"], "splendor": 35, "colonists": 10, "seals": 4},
	{"realm": "Kingdom", "ruler": ["King", "Queen"], "splendor": 60, "colonists": 15, "seals": 5},
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
	ASTRONOMY, CHARCOAL, COLD_STORE, PAVED_ROAD, DRY_RATIONS, CARTOGRAPHY, PALISADE, TRAINING_DUMMY, SMOKEHOUSE, RENOWNED_INN,
	WATCHTOWER, SHIELD, LENDING_ARMORY, STEEL, SCRIPTORIUM, FINE_FURNITURE, PALACE, LOOM, TILED_STOVE, ICEHOUSE, GARDEN,
	SOIL_SURVEY, ALMANAC, LAND_REGISTER, MANURING, CROWN_COMPANY }
const TECHS_SHEET := preload("res://art/techs.png")
const TECHS := {
	Tech.FORGE: {"branch": Branch.FIRE, "tier": 1, "cost": 60, "builds": [Build.FURNACE, Build.ANVIL],
		"makes": [Res.INGOT, Res.PICKAXE, Res.AXE, Res.SICKLE], "info": "Furnace, anvil and the forge: ingots and the first tools."},
	Tech.TAILORING: {"branch": Branch.FIRE, "tier": 1, "cost": 50, "builds": [Build.WORKBENCH],
		"makes": [Res.LEATHER_ARMOR, Res.LEATHER_HOOD], "info": "The workbench and the workshop: leather armor and hoods."},
	Tech.HUNTING: {"branch": Branch.LAND, "tier": 1, "cost": 50, "builds": [Build.SPINNING_WHEEL, Build.CARPENTER_BENCH,
		Build.WALL_HIDES, Build.DOOR_CURTAIN], "makes": [Res.BOWSTRING, Res.BOW],
		"info": "Spinning wheel, carpenter bench and carpentry: bowstrings and bows. Hides on the walls and curtains at the doors keep rooms warmer."},
	Tech.INN: {"branch": Branch.ROAD, "tier": 1, "cost": 40, "builds": [Build.NOTICE_BOARD],
		"info": "The notice board and the inn: adventurers come and go to the ruins. Books come from there."},
	Tech.MASONRY: {"branch": Branch.STONE, "tier": 1, "cost": 60, "materials": [Res.STONE], "builds": [Build.HEARTH, Build.PLASTER],
		"info": "Stone walls and floors: more comfort, and they keep the heat in. The hearth, with its chimney. Plaster for wooden walls."},
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
	Tech.ASTRONOMY: {"branch": Branch.LORE, "tier": 3, "cost": 500, "needs": [Tech.SCRIPTORIUM],
		"info": "Reading the sky: the weather forecast reaches one more day."},
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
	Tech.CROWN_COMPANY: {"branch": Branch.ROAD, "tier": 3, "cost": 500, "needs": [Tech.RENOWNED_INN],
		"info": "Colonists go along with the adventurers: pick them on the notice board, with at least one adventurer. They ask no fee and keep no share."},
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
	Tech.PALACE: {"branch": Branch.STONE, "tier": 4, "cost": 1200, "needs": [Tech.STATUARY],
		"info": "The throne room becomes a palace: audiences give 50% more authority, +10 splendor."},
	Tech.ICEHOUSE: {"branch": Branch.LAND, "tier": 2, "cost": 250, "needs": [Tech.COLD_STORE], "rooms": [RoomKind.ICEHOUSE],
		"builds": [Build.ICE_PIT], "info": "The icehouse: stone walls, a pit of ice cut from the frozen water in winter. While the ice lasts, food barely spoils."},
	Tech.GARDEN: {"branch": Branch.LAND, "tier": 1, "cost": 80, "orders": [Order.GARDEN],
		"info": "The garden: mark plots on open grass. Colonists sow turnips (60 days), cabbages (90) and broad beans (100); each field follows its rotation. Nothing grows in winter."},
	Tech.MANURING: {"branch": Branch.LAND, "tier": 1, "cost": 80, "needs": [Tech.GARDEN], "builds": [Build.COMPOST_HEAP],
		"info": "Manuring: rotten food and weeds go to the compost heap, the charcoal kiln leaves ash, and colonists fertilize the garden before sowing. Green manure: beans ploughed in."},
	Tech.SOIL_SURVEY: {"branch": Branch.LAND, "tier": 1, "cost": 60, "needs": [Tech.GARDEN],
		"info": "The soil lens (O): how fertile every tile is, poor, average or rich. A field's sign says it too."},
	Tech.ALMANAC: {"branch": Branch.LAND, "tier": 2, "cost": 250, "needs": [Tech.SOIL_SURVEY],
		"info": "The farmer's almanac: the soil in five bands, and on the signs whether a field is growing richer or poorer than a year ago."},
	Tech.LAND_REGISTER: {"branch": Branch.LAND, "tier": 3, "cost": 450, "needs": [Tech.ALMANAC],
		"info": "The land register: the soil's exact numbers on the lens and the signs, and the next harvest of every field."},
	Tech.LOOM: {"branch": Branch.FIRE, "tier": 2, "cost": 200, "needs": [Tech.TAILORING], "builds": [Build.TAPESTRY],
		"info": "Woven linen: tapestries for the walls, warmth and splendor."},
	Tech.TILED_STOVE: {"branch": Branch.FIRE, "tier": 2, "cost": 300, "needs": [Tech.CHARCOAL, Tech.MASONRY], "builds": [Build.TILED_STOVE],
		"info": "The tiled stove, against a wall: +10 °C to its room and to the one behind, through stone too."},
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
	HARSH_PUNISHMENT, CLEMENCY, HUNTING_RESERVE, COURT, CLOSED_GATES, OPEN_GATES, OATH }
const LAWS_SHEET := preload("res://art/laws.png")  # colonne nell'ordine di Law
enum LawKind { TREASURY, WORK, ORDER, PEOPLE, CROWN, FEASTS }
# Leggi: "kind" categoria; "cost" autorità per codificarla; "tier" il titolo che serve (di TITLES, se no la signoria);
# "group" in vigore una sola dello stesso gruppo; "needs" la ricerca che serve; "after" la legge da codificare prima.
# "mood": felicità di chi è in colonia finché è in vigore (vedi law_mood): "all" a tutti i coloni, un Trait al posto di
# "all" a chi ce l'ha, "guests" agli avventurieri, "ruler" al sovrano, "hunters" a chi ha l'arco, "foreigners" ai
# forestieri, "sworn" a chi ha giurato (vedi law_mood_of).
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
	Law.CLOSED_GATES: {"kind": LawKind.PEOPLE, "cost": 30, "group": "welcome", "mood": {"all": 5.0},
		"info": "Nobody asks to stay: adventurers don't ask, and no wanderers come."},
	Law.OPEN_GATES: {"kind": LawKind.PEOPLE, "cost": 40, "group": "welcome", "mood": {"foreigners": -5.0},
		"info": "Adventurers ask to stay after 2 expeditions, and wanderers come twice as often. Newcomers are foreigners for 10 days, not 5."},
	Law.OATH: {"kind": LawKind.PEOPLE, "tier": 1, "cost": 80, "mood": {"sworn": 5.0},
		"info": "Whoever stays swears loyalty before the throne (an hour, 10 authority) and is no foreigner. Without enough authority they stay a foreigner."},
	Law.HARVEST_FEAST: {"kind": LawKind.FEASTS, "cost": 40,
		"info": "The five feast days of the calendar are holidays: nobody works but the cooks. Then +10 happiness for 3 days, +5 authority."},
}
const SHIFTS := {Law.LONG_SHIFTS: [10.0, 1.25], Law.SHORT_DAY: [6.0, 0.75]}  # ore di lavoro al giorno, stress da lavoro x
const TAXES := {Law.TITHE: 0.1, Law.TALLAGE: 0.2}  # parte di quello che si produce che va al granaio della corona (vedi produce)
const LOOT_SHARE := 0.2     # quota delle monete degli avventurieri con la gabella sul bottino (se no SHARE)
const LOOT_TAX_WAIT := 4.0 / 3  # con la gabella: giorni tra un arrivo e l'altro x
const REST_EVERY := 7       # riposo festivo: l'ultimo giorno di ogni tanti
const FEAST_AUTHORITY := 5.0
const TOLL := 2             # monete del pedaggio, per avventuriero che arriva
const TOLL_WAIT := 1.25     # col pedaggio: giorni tra un arrivo e l'altro x (un quinto in meno)
const MILITIA_FLEE := 30.0  # con la milizia si scappa sotto questi punti ferita (se no FLEE_HP)
const HARSH_STRESS := 2.0 / 3  # con le pene severe, stress dal lavoro x per l'iracondo: sfuriate un terzo meno spesso
const CLEMENT_HOURS := 1.0  # con la clemenza sfuriate e proteste durano tanto
const COURT_AUDIENCE := 1.5 # con la corte, autorità dall'udienza x
const OPEN_STAY_TRIPS := 2  # con le porte aperte: spedizioni dopo le quali un avventuriero chiede di restare
const OPEN_WANDERERS := 0.5 # con le porte aperte: attesa dei viandanti x
const OPEN_FOREIGNER_DAYS := 10.0  # con le porte aperte: giorni da forestiero
const OATH_AUTHORITY := 10.0  # il giuramento davanti al trono: la corona spende questa autorità (vedi swear)
const OATH_HOURS := 1.0
const PALACE := [1.5, 10]   # col palazzo (e una sala del trono): autorità dall'udienza x, splendore in più
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
	var priorities := []          # per Work: 1 (prima) - PRIORITY_LEVELS, 0 mai; quelli che mancano PRIORITY_DEFAULT (vedi priority)
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
	var loadout := {}             # Slot -> Res scelto nella scheda, null: niente; slot che manca: automatico (vedi fits)
	var recipe := 0               # CRAFT: indice in RECIPES
	var fetched := {}             # CRAFT: Res -> quantità già portata alla postazione
	var bucket := false           # DOUSE: ha il secchio pieno
	var work_left := 0.0          # secondi: del colpo, della costruzione o, a svago e in sfuriata, del tempo che resta
	var work_total := 0.0         # 0 se non è un lavoro a tempo (niente barra né colpi)
	var worked := 0.0             # ore lavorate nella sua giornata, che comincia quando si alza (vedi update_routine)
	var workday := 0              # la giornata a cui si riferisce `worked`
	var streak := 0.0             # ore di lavoro di fila, senza pause né pasti
	var pause_until := 0.0        # `clock` fino a cui non lavora: è in pausa (vedi "streak" in TRAIT_FX)
	var hour := -1                # ultima ora vista, per accorgersi di quando scocca la successiva
	var died := 0.0               # `clock` della morte (vedi corpses)
	var born := INF               # `clock` della nascita (vedi age_of); INF: da dare, salvataggio di prima delle età
	var spouse = null             # Colonist: il coniuge, anche morto (vedi married)
	var mother = null             # Colonist: i genitori, anche morti (vedi give_birth)
	var father = null
	var due := 0.0                # incinta: `clock` del parto; 0 se no (vedi conceive)
	var fertile_from := 0.0       # `clock` da cui può restare incinta di nuovo: un anno dopo il parto
	var cradle := Vector2i(-1, -1)  # neonato: la culla dove sta; (-1, -1) in braccio (vedi place_babies)
	var suitor := false           # pretendente alla locanda, finché non si sposa o se ne va (vedi update_suitors)
	var dowry := {}               # Res -> quantità: la dote del pretendente
	var house_arms := {}          # lo stemma della sua casata, se è di un'altra (pretendenti)
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
	var refused_at := 0           # le spedizioni che aveva quando gli hanno detto di no l'ultima volta (vedi wants_to_stay)
	var former := Hero.NONE       # rimasto come colono: la classe che aveva (vedi welcome)
	var wanderer := false         # viandante, finché non resta o se ne va (vedi update_wanderers)
	var fellows := []             # il viandante: il suo gruppo, lui compreso (la famiglia); chiedono insieme
	var oath := false             # deve andare a giurare davanti al trono (vedi try_oath)
	var sworn := false            # ha giurato (Law.OATH)


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
	var thaw := 0.0                   # ghiacciaia: il ghiaccio sciolto che non fa ancora un blocco (vedi melt_ice)



# Un tetto: un rettangolo di caselle sopra una stanza e i suoi muri (una stanza a L ne ha più d'uno, vedi rectangles)
class Roof:
	var rect := Rect2i()
	var vertical := false     # colmo da nord a sud: il rettangolo non è più largo che alto (vedi ROOFS.bake)
	var material := 0         # Res.WOOD scandole, Res.STONE coppi: la maggioranza dei muri della stanza (roof_material)
	var tint := Color.WHITE   # una leggera differenza tra un tetto e l'altro
	var room: Room
	var look := {}            # com'è fatto, da roofs.gd: falde, facciata e timpani, la neve, la forma (vedi update_roofs)


var astar := AStarGrid2D.new()
var rocks := {}             # cella -> true (non attraversabile)
var boulders := {}          # cella in alto a sinistra -> dimensione del masso che copre quelle rocce
var ores := {}              # cella -> Res.IRON o Res.COAL: massi 1x1 che scavati danno il minerale invece della pietra
var water := {}             # cella -> Ground.SHALLOW (si guada) o Ground.DEEP (non si attraversa)
var ground_texture: ImageTexture  # tutto il terreno già disegnato, vedi bake_ground
var map_seed := 0           # del rumore della mappa: col salvataggio, rifà le chiazze di erba sassosa (vedi ground_noise)
var ground_cols := PackedByteArray()  # per casella, riga per riga: la variante del terreno (colonna di GROUND, vedi bake_ground)
var gravel := {}            # cella -> true: la roccia com'era all'inizio; il terreno disegnato resta ghiaia anche dove si scava
var delivered := {}         # [Job, cella d'origine] -> {Res: quantità} già al cantiere, per chi vuole più materiali
var game_id := ""           # la cartella dei salvataggi della colonia (vedi SAVES.create); vuota: non si salva
var autosave_due := false   # è l'alba: si salva finito il tick (vedi _process)
var save_list               # la pagina dei salvataggi nel menù delle opzioni (save_list.gd), dopo Load game
var toast := Label.new()    # in alto al centro: "Saved"; resta fino a toast_until (millisecondi di Time.get_ticks_msec)
var toast_until := 0
var water_fx: ShaderMaterial      # anima l'acqua del terreno, e la fa gelare (vedi water.gdshader e atmosphere.gd)
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
var ice_marks := {}         # cella d'acqua -> true: dove si taglia il ghiaccio, quando gela
var garden := {}            # casella dell'orto -> `clock` della semina, o -1 se è da seminare (vedi CROP_DAYS)
var sown := {}              # casella seminata -> Crop
var plans := {}             # casella dell'orto -> [anno di partenza, [[[Crop, giorno], ...] per anno del ciclo]] (vedi plan_of)
var slot_done := {}         # casella -> [anno, indice]: l'ultima coltura del piano seminata quest'anno (vedi next_slot)
var soil := PackedByteArray()  # per casella, riga per riga: la fertilità 0-100 (vedi make_soil, soil_at)
var soil_year_ago := PackedByteArray()  # la stessa all'ultimo Capodanno: l'Almanacco agrario dice se sale o scende
var soil_known := {}        # casella -> true: un contadino bravo (SOIL_EYE) l'ha lavorata e ne sa la terra
var compost_since := {}     # casella di un cumulo del compost -> `clock` da cui ci matura il marcio (vedi make_compost)
var manured := {}           # casella d'orto -> true: già concimata per la prossima semina
var babies: Array[Colonist] = []  # i neonati, fino a CHILD_AGE: non sono ancora coloni (vedi give_birth, place_babies)
var naming = null           # Colonist: il neonato a cui la finestra della nascita dà il nome
var pace := Pace.FAST       # il ritmo della vita, scelto nella nuova partita: si invecchia di un anno a stagione o all'anno
var house_name := ""        # la casata che regna: il cognome dei suoi, che i figli prendono (vedi found_house)
var regent_for = null       # Colonist: l'erede minorenne per cui `ruler` regna da reggente; null se no
var coronation_at := 0.0    # `clock` dell'incoronazione di `ruler`, finito il lutto regale; 0 se non ce n'è una in attesa
var reigns := []            # [sovrano, `clock` d'inizio, di fine (-1 finché regna), casata]: i sovrani, in ordine
var founding_line := -1     # la voce della cronaca della casata nuova, che cambia se il giocatore sceglie un altro
var founding_from := ""     # la casata finita, per quella voce
var next_suitor := 0.0      # `clock` del prossimo pretendente alla locanda; 0: da fissare (vedi update_suitors)
var next_wanderer := 0.0    # `clock` del prossimo viandante; 0: da fissare (vedi update_wanderers)
var naming_line := -1       # la voce della cronaca della sua nascita, che cambia col nome
var no_manure := {}         # casella d'orto -> true: il suo campo non si concima (dal cartello)
var tired := {}             # casella -> [Crop, quante volte di fila]: l'ultimo raccolto (vedi tired_count)
var last_yield := {}        # casella -> [anno, Crop, quanti]: l'ultimo raccolto, per il cartello del campo
var harvests := {}          # anno -> {Crop: [quanti, raccolti]}: il bilancio dell'anno (vedi note_harvests)
var field_signs: Array[Vector2i] = []  # il cartello di ogni campo, nella sua casella più in alto a sinistra (vedi update_fields)
var field_popup := PanelContainer.new()  # il cartello di un campo aperto (vedi open_field)
var soil_lens := CanvasLayer.new()  # la lente della terra (Saggio del terreno): la fertilità a colori (vedi draw_soil_lens)
var soil_canvas := Node2D.new()
var editing_field := Vector2i.ZERO  # una casella del campo aperto
var plan_panel := PanelContainer.new()  # la pianificazione dei campi, a gantt (vedi open_plan)
var plan_chart := Control.new()  # ci disegna draw_plan; i clic li prende plan_input
var plan_menu := PopupMenu.new()  # aggiungi, cambia, togli una coltura; le rotazioni pronte (vedi plan_input)
var plan_year := 0          # l'anno che mostra la pianificazione: quello di adesso più questo, fino a PLAN_YEARS - 1
var plan_click := []        # dove si è cliccato: [cartello del campo, anno del ciclo, coltura (indice) o -1, giorno d'inizio]
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
var chronicle_days: PackedInt32Array = []  # il giorno di ogni voce di chronicle: il calendario la segna lì
var board_key := ""         # quello che mostra la bacheca: se cambia, la si rifà (vedi fill_board)
var board_pick: Array[Colonist] = []  # spuntati alla bacheca per la prossima spedizione
var requests := []          # chi chiede di restare e aspetta la risposta: un Array di Colonist per domanda (vedi ask)
var asking := []            # la domanda nella finestra (una di requests)
var census_key := ""        # chi mostra l'elenco degli abitanti e dove: se cambia, lo si rifà (vedi fill_census)
var census_rows := []       # [Colonist, Label]: la colonna "cosa fa" di ogni riga, aggiornata a ogni fotogramma
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
var roofed := {}            # casella sotto un tetto (stanze coi loro muri e porte) -> il suo Roof; vedi update_roofs
var roofs: Array[Roof] = []  # i tetti, uno per rettangolo di stanza (vedi rectangles)
var wear := {}              # casella di tetto -> usura, da 0 (vedi WORN; da 1 un buco)
var plastered := {}         # muro di legno intonacato -> true (vedi Build.PLASTER)
var burning := {}           # casella di tetto che brucia -> ore che le restano (vedi burn)
var fire_risk := true       # false nei test: niente incendi a caso (le prove dell'incendio sono in test_heat)
var fire_noted := {}        # stanza -> giorno in cui la cronaca ha detto che il suo tetto brucia
var roof_stamp := 0         # cambia quando si apre o si chiude un buco: atmosphere rifà la maschera della neve
var storm_noted := {}       # stanza -> giorno in cui la cronaca ha detto del temporale che ne ha strappato il tetto
var roofs_shown := true     # il pulsante Roofs li toglie, per guardare dentro
var roofs_drawn: Array[Roof] = []  # gli stessi tetti nell'ordine in cui si disegnano: dal piede della facciata più in alto
var shown_roof := {}        # casella sotto un tetto -> il tetto che ci si vede sopra (su un muro in comune, quello davanti)
var warm_cells := {}        # caselle attorno ai comignoli, rifatte a ogni _draw (vedi draw_house)
var roof_chimneys := {}     # Roof -> i comignoli che ci stanno sopra (vedi chimney_of), rifatti a ogni _draw
var made_roofs := {}        # i dati di un tetto -> com'è fatto (Roof.look): a ogni muro nuovo si rifanno solo quelli cambiati
var hole_masks: Array[Image] = [ROOFS.hole_mask(0), ROOFS.hole_mask(1)]  # i buchi per vedere dietro i tetti, vedi cut_holes
var hole_clear := Image.create_empty(ROOFS.HOLE_DITHER * 2, ROOFS.HOLE_DITHER * 2, false, Image.FORMAT_RGBA8)
var atmosphere := preload("res://atmosphere.gd").new()  # luci, fuochi, nuvole, meteo; neve e pozzanghere a terra
var forecast_strip = preload("res://forecast.gd").new()  # in alto accanto alla data: il meteo di adesso e le previsioni
var calendar = preload("res://calendar.gd").new()  # si apre cliccando la data: un mese per pagina, coi suoi eventi
var rooms_made := 0         # per i nomi di default
var editing: Room           # la stanza aperta nel popup del cartello
var keep := STOCK.duplicate()  # prodotto -> quanti tenerne (a terra, in magazzino, in mano): si cambia nel menu della postazione
var crafting := Vector2i(-1, -1)  # la postazione aperta nel menu, vedi open_craft
var shown: Colonist         # il colono nella scheda: le barre dei bisogni lo seguono
var gear_menu := PopupMenu.new()  # clic su uno slot della scheda: Auto, Empty o un pezzo (vedi open_gear_menu)
var marriage_menu := PopupMenu.new()  # "Arrange a marriage…": chi il sovrano può sposare (vedi open_marriage_menu)
var gear_slot := Slot.HANDS       # lo slot del menu aperto
var lens_owners := []       # [centro, proprietari o lavoratori] per stanza delle figurine sulla lente, vedi place_owners
var needs_rate := 1.0       # 0 nei test: i bisogni restano fermi e non cambiano i lavori
var routines := true        # false nei test: niente orari né ore massime, chi è libero prende il primo lavoro
var game_start := true      # false nei test: TEST_PEOPLE coloni, niente monete né arma a terra, tutto studiato (prima di _ready)
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
static var setup := {}      # nuova partita, da creation.gd: {"colony": nome, "ruler": Colonist.proprietà -> valore, "pace": Pace}
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
var heat_lens := CanvasLayer.new()  # la lente del calore: si accende anche da sola, piazzando un fuoco (vedi previewing_heat)
var heat_canvas := Node2D.new()     # ci disegna draw_heat_lens
# luci accese di notte: come le lenti, in un livello che la notte non scurisce; ci disegna draw_lights
var lights := CanvasLayer.new()
var lights_canvas := Node2D.new()

@onready var camera: Camera2D = $Camera2D
@onready var stored_label: Label = $HUD/TopBar/Row/Stored  # risorse in tutti i magazzini, sommate: il dettaglio è in Resources
@onready var colonists_label: Button = $HUD/TopBar/Row/Colonists  # cliccato: l'elenco degli abitanti (vedi fill_census)
@onready var beds_label: Label = $HUD/TopBar/Row/Beds
@onready var splendor_label: Label = $HUD/TopBar/Row/Splendor
@onready var info_label: Label = $HUD/TopBar/Row/Info
@onready var realm_button: Button = $HUD/TopBar/Row/Realm  # nome del reame: apre la scheda del sovrano
@onready var video: Control = $HUD/Options/Window/Box/Body/Pages/Video  # risoluzione e schermo intero
@onready var categories: Control = $HUD/Categories  # si apre col tasto Build: una categoria per barra di costruzione
@onready var build_bar: Control = $HUD/BuildBar  # sopra le categorie: quella scelta
@onready var furniture_bar: Control = $HUD/FurnitureBar
@onready var materials: Control = $HUD/BuildBar/Row/Materials
@onready var actions: Control = $HUD/Actions  # in alto al centro, sotto la barra: "Build" e la X rossa
@onready var confirm: Button = $HUD/Actions/Confirm
@onready var erase: Button = $HUD/Actions/Erase
@onready var material_group: ButtonGroup = $HUD/BuildBar/Row/Materials/Wood.button_group
@onready var kind_group: ButtonGroup = $HUD/BuildBar/Row/Wall.button_group  # anche dei mobili
@onready var select_button: Button = $HUD/Tools/Row/Select  # la freccia, prima a sinistra: vedi select_tool
@onready var build_button: Button = $HUD/Tools/Row/Build  # sega e martello: apre le categorie, vedi toggle_build
@onready var structures_button: Button = $HUD/Categories/Row/Structures
# categorie dei mobili, accanto a Structures: ognuna mostra il suo gruppo della barra dei mobili (stesso nome, in
# main.tscn), così la barra non esce dallo schermo: casa, fuoco e calore, mestieri e provviste, corte e difesa, decorazioni
const FURNITURE_GROUPS := ["Home", "Fire", "Crafts", "Court", "Decor"]
var kind_buttons := {}  # Build -> il suo pulsante, nella barra delle strutture o in un gruppo di quella dei mobili
@onready var category_group: ButtonGroup = structures_button.button_group
@onready var order_group: ButtonGroup = $HUD/Tools/Row/Destroy.button_group  # Destroy, Mine, Chop, Uproot
@onready var room_popup: Control = $HUD/RoomPopup  # pannello al centro
@onready var room_name: LineEdit = $HUD/RoomPopup/Box/Name
@onready var room_kind: OptionButton = $HUD/RoomPopup/Box/Kind  # solo i tipi possibili, vedi refresh_room
@onready var room_owners: Control = $HUD/RoomPopup/Box/Owners/List  # una casella da spuntare per colono: proprietari o lavoratori
@onready var craft_popup: Control = $HUD/CraftPopup  # menu della postazione cliccata, vedi open_craft
@onready var jobs_panel: Control = $HUD/JobsPanel  # a destra, si apre col tasto Jobs in basso: vedi job_list
@onready var jobs_list: RichTextLabel = $HUD/JobsPanel/Box/List  # testo ricco: le monete con l'icona
var priority_grid := GridContainer.new()  # in cima alla finestra Jobs: la tabella delle priorità (vedi refresh_priorities)
var priorities_key := ""    # coloni, sovrano e lingua con cui è fatta la tabella: se cambiano, la si rifà
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
	var dead: Array[Colonist] = []  # i coloni morti nella rovina (Compagnia della corona): la colonia lo sa al ritorno
	var left: Array[Colonist] = []  # chi è partito, vivi e morti: così lo sa la colonia finché non tornano (vedi census_groups)


func _init() -> void:
	for res in Res.values():
		items[res] = {}


func _ready() -> void:
	var state: Dictionary = SAVES.pending  # una partita salvata da riprendere (vedi load_game), se no una nuova
	SAVES.pending = {}
	if state.is_empty():  # colonia nuova: la sua cartella, dalla pagina della nuova partita (nei test nessuna)
		game_id = SAVES.founding
	SAVES.founding = ""
	astar.region = Rect2i(Vector2i.ZERO, MAP_SIZE)
	astar.cell_size = Vector2.ONE * TILE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	if state.is_empty():
		generate_map()
	else:
		restore(state)
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
	if state.is_empty():
		new_people()
	banner_tex = banner_texture(arms)
	show_title()
	realm_button.pressed.connect(func(): open_sheet(ruler))
	colonists_label.pressed.connect(toggle_census)
	$HUD/TopBar/Row/ColonistsIcon.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			toggle_census())
	camera.position = center(MAP_SIZE / 2)
	for name in SPEEDS:
		get_node("HUD/TopBar/Row/" + name).pressed.connect(func(): Engine.time_scale = SPEEDS[name])
	$HUD/TopBar/Row/Screen.pressed.connect(func():
		set_fullscreen(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN))
	$HUD/TopBar/Row/Options.pressed.connect(toggle_options)
	var debug: PopupMenu = $HUD/TopBar/Row/Debug.get_popup()  # per provare il gioco: una voce per id (vedi debug_pressed)
	debug.add_item("Advance 12 hours", 0)
	debug.id_pressed.connect(debug_pressed)
	setup_options()
	build_button.toggled.connect(toggle_build)
	structures_button.toggled.connect(toggle_category.bind(build_bar))
	for group in FURNITURE_GROUPS:
		get_node("HUD/Categories/Row/" + group).toggled.connect(toggle_furniture.bind(furniture_bar.get_node("Row/" + group)))
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
	heat_lens.follow_viewport_enabled = true
	heat_lens.layer = 1
	heat_lens.visible = false
	heat_lens.add_child(heat_canvas)
	add_child(heat_lens)
	heat_canvas.draw.connect(draw_heat_lens)
	soil_lens.follow_viewport_enabled = true
	soil_lens.layer = 1
	soil_lens.visible = false
	soil_lens.add_child(soil_canvas)
	add_child(soil_lens)
	soil_canvas.draw.connect(draw_soil_lens)
	add_child(atmosphere)  # dopo `lights` e `flat`, che usa
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.position.y = 72  # sotto la barra in alto
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_theme_color_override("font_outline_color", Color(0.12, 0.1, 0.14))
	toast.add_theme_constant_override("outline_size", 8)
	toast.hide()
	$HUD.add_child(toast)
	forecast_strip.main = self
	$HUD/TopBar/Row.add_child(forecast_strip)
	$HUD/TopBar/Row.move_child(forecast_strip, info_label.get_index() + 1)
	calendar.main = self
	$HUD.add_child(calendar)
	info_label.mouse_filter = Control.MOUSE_FILTER_STOP  # la data apre il calendario
	info_label.tooltip_text = "Calendar"
	info_label.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			calendar.visible = not calendar.visible)
	for name in ["RoomsLens", "HeatLens", "SoilLens"]:  # una lente alla volta
		get_node("HUD/Tools/Row/" + name).toggled.connect(func(on):
			if on:
				for other in ["RoomsLens", "HeatLens", "SoilLens"]:
					if other != name:
						get_node("HUD/Tools/Row/" + other).button_pressed = false)
	$HUD/Tools/Row/RoomsLens.toggled.connect(func(on): lens.visible = on)
	$HUD/Tools/Row/SoilLens.toggled.connect(func(on): soil_lens.visible = on)
	$HUD/Tools/Row/Roofs.toggled.connect(func(on): roofs_shown = not on)
	$HUD/RoomPopup/Box/Ok.pressed.connect(room_popup.hide)
	for kind in Build.values():  # un pulsante per tipo, con lo stesso nome: Wall, Floor, ... Lamp
		var bar := furniture_bar if FURNITURE.has(kind) else build_bar
		var button: Button = bar.find_child(Build.keys()[kind].capitalize(), true, false)
		kind_buttons[kind] = button
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
	var jobs_box: Control = jobs_panel.get_node("Box")
	priority_grid.columns = Work.size() + 1
	priority_grid.add_theme_constant_override("h_separation", 2)
	priority_grid.add_theme_constant_override("v_separation", 0)
	jobs_box.add_child(priority_grid)
	jobs_box.move_child(priority_grid, jobs_list.get_index())
	var hint := Label.new()
	hint.name = "PriorityHint"
	hint.text = "1 first, 4 last, – never. Click: later; right click: sooner."
	hint.add_theme_color_override("font_color", Color(0.85, 0.77, 0.54))
	hint.add_theme_font_size_override("font_size", 12)
	jobs_box.add_child(hint)
	jobs_box.move_child(hint, jobs_list.get_index())
	var line := HSeparator.new()
	jobs_box.add_child(line)
	jobs_box.move_child(line, jobs_list.get_index())
	$HUD/Tools/Row/Resources.toggled.connect(resources_panel.set_visible)
	jobs_panel.hidden.connect($HUD/Tools/Row/Jobs.set_pressed_no_signal.bind(false))  # chiusa con la X: tasto su
	resources_panel.hidden.connect($HUD/Tools/Row/Resources.set_pressed_no_signal.bind(false))
	var topics: ItemList = $HUD/WikiPanel/Box/Body/Topics
	topics.item_selected.connect(func(i): $HUD/WikiPanel/Box/Body/Text.text = WIKI.pages()[i][1])
	fill_wiki()
	$HUD/Tools/Row/Wiki.toggled.connect($HUD/WikiPanel.set_visible)
	$HUD/WikiPanel.hidden.connect($HUD/Tools/Row/Wiki.set_pressed_no_signal.bind(false))
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
		for text in [named(Res, res, "item"), ""]:  # nome, quantità
			var label := Label.new()
			label.text = text
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if text == "" else HORIZONTAL_ALIGNMENT_LEFT
			row.add_child(label)
		resources_list.add_child(row)
	if state.is_empty():
		ruins.append(Ruin.new())  # per ora solo la torre
	$HUD.add_child(gear_menu)
	gear_menu.id_pressed.connect(choose_gear)
	$HUD.add_child(marriage_menu)
	$HUD/BirthPanel/Box/Row/Name.text_changed.connect(name_child)
	$HUD/BirthPanel/Box/Row/Dice.pressed.connect(roll_child_name)
	$HUD/BirthPanel/Box/Ok.pressed.connect($HUD/BirthPanel.hide)
	$HUD/RequestPanel/Box/Row/Yes.pressed.connect(answer.bind(true))
	$HUD/RequestPanel/Box/Row/No.pressed.connect(answer.bind(false))
	$HUD/ColonistSheet/Box/Family/Request.pressed.connect(func(): show_request(request_of(shown)))
	marriage_menu.id_pressed.connect(marriage_pressed)
	$HUD/ColonistSheet/Box/Family/Marry.pressed.connect(open_marriage_menu)
	$HUD/ColonistSheet/Box/Family/House.pressed.connect(open_house)
	for slot in Slot.values():
		var icon: Control = $HUD/ColonistSheet/Box/Equipment/Slots.get_child(slot)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP  # il clic non trascina la finestra
		icon.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
					and shown.hero == Hero.NONE:
				open_gear_menu(slot))
	$HUD/BoardPanel/Box/ChronicleButton.pressed.connect(open_chronicle)
	build_field_popup()
	build_plan_panel()
	for window in [room_popup, field_popup, plan_panel, craft_popup, jobs_panel, resources_panel, sheet_panel, $HUD/BoardPanel, $HUD/ReportPanel, $HUD/ChroniclePanel,
			$HUD/KnowledgePanel, $HUD/LawsPanel, $HUD/WikiPanel, $HUD/BirthPanel, $HUD/SuccessionPanel, $HUD/HousePanel,
			$HUD/RequestPanel, $HUD/CensusPanel]:  # X in alto a destra, si trascinano
		window.get_node("Box/Head/Close").pressed.connect(window.hide)
		window.gui_input.connect(drag_window.bind(window))
		window.visibility_changed.connect(window.move_to_front, CONNECT_DEFERRED)  # l'ultima aperta sta sopra
	if not game_start:  # nei test tutto studiato: le prove della ricerca sono in test_research
		for t in Tech.values():
			researched[t] = true
	fire_risk = game_start
	refresh_unlocks()
	if not state.is_empty():
		resume(state)
	else:
		autosave()  # appena fondata, il primo giorno (l'alba è già passata): compare subito tra le colonie del titolo


# Partita nuova: il sovrano (come l'ha fatto il giocatore nella pagina della nuova partita, vedi setup) e gli altri
# coloni nella radura, a caso; il nome del reame e lo stemma
func new_people() -> void:
	pace = setup.get("pace", Pace.FAST)
	var heads := COLONIST_COUNT + 1 if game_start else TEST_PEOPLE  # il primo è il sovrano
	for i in heads:
		var c := Colonist.new()
		c.pos = center(MAP_SIZE / 2 + Vector2i(i - 1, 0))
		c.tunic = TUNIC_COLORS[i % TUNIC_COLORS.size()]
		dress(c, people().map(func(o): return o.first_name))
		c.skills = Skill.values().map(func(_s): return 0)
		c.xp = Skill.values().map(func(_s): return 0)
		var made: Dictionary = setup.get("ruler", {}) if i == 0 else {}
		for key in made:  # il sovrano, come l'ha fatto il giocatore: gli altri evitano il suo nome
			c.set(key, made[key])
		give_age(c, RULER_AGE if i == 0 else ADULT_AGE)
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
	house_name = ruler.last_name
	reigns = [[ruler, clock, -1.0, house_name]]
	keep[Res.MEAL] = MEALS_PER_COLONIST * colonists.size()
	realm = setup.get("colony", COLONY_NAMES.pick_random())
	arms = setup.get("arms", random_arms())


# menù delle opzioni: a sinistra le tab, icone (una per pagina, con lo stesso nome); le pagine stanno in un
# TabContainer senza linguette, grande quanto la più grande, così la finestra non cambia misura passando dall'una
# all'altra. System: lingua, salva, carica (la pagina dei salvataggi, vedi open_saves), menù principale, esci dal gioco.
# Video: risoluzione e schermo intero. Audio: vuota.
# Keybindings: icona, nome e tasto per comando della barra in basso, due per riga, nell'ordine dei pulsanti
func setup_options() -> void:
	var window: Control = options.get_node("Window")
	window.get_node("Box/Head/Close").pressed.connect(options.hide)
	window.gui_input.connect(drag_window.bind(window))
	options.visibility_changed.connect(options_toggled)
	var pages: TabContainer = window.get_node("Box/Body/Pages")
	for tab in window.get_node("Box/Body/Tabs").get_children():
		tab.toggled.connect(show_page.bind(pages.get_node(NodePath(tab.name))))
	pages.get_node("Keybindings/Reset").pressed.connect(reset_keys)
	# ponytail: risoluzione e schermo intero non si salvano ancora: si riparte dalla finestra di partenza
	var sizes: OptionButton = video.get_node("Resolution/Sizes")
	var screen := DisplayServer.screen_get_size()
	for i in RESOLUTIONS.size():
		if i == 0 or (RESOLUTIONS[i].x <= screen.x and RESOLUTIONS[i].y <= screen.y):
			sizes.add_item("%d x %d" % [RESOLUTIONS[i].x, RESOLUTIONS[i].y])
	sizes.item_selected.connect(func(i): set_resolution(RESOLUTIONS[i]))
	video.get_node("Fullscreen").toggled.connect(set_fullscreen)
	pages.get_node("System/Load").pressed.connect(open_saves)
	pages.get_node("System/MainMenu").pressed.connect(go_to.bind("res://title.tscn"))
	pages.get_node("System/Quit").pressed.connect(quit_game)
	save_list = SAVE_LIST.new()  # una pagina senza tab: ci si arriva da Load game, Back torna a System
	save_list.name = "Saves"
	save_list.keyboard = false
	save_list.current = game_id  # quella che si gioca non si cancella da qui
	pages.add_child(save_list)
	save_list.chosen.connect(load_game)
	save_list.closed.connect(func(): pages.current_tab = 0)
	var languages: OptionButton = pages.get_node("System/Language/Languages")
	for code in LANGUAGES:
		languages.add_item(LANGUAGES[code])
	# all'inizio quella del sistema (o salvata, vedi title.gd); se non c'è, l'inglese
	languages.select(maxi(0, LANGUAGES.keys().find(TranslationServer.get_locale().get_slice("_", 0))))
	languages.item_selected.connect(func(i): set_language(LANGUAGES.keys()[i]))
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


# --- Salvataggio (vedi SAVES) ---

# le classi interne i cui oggetti stanno nel salvataggio (vedi SAVES.Packer): l'ordine conta, è nei file
func saved_classes() -> Array:
	return [Colonist, Animal, Arrow, Room, Ruin, Expedition]


# Tutto lo stato della partita, pronto per store_var: le variabili di SAVED (gli oggetti impacchettati in "objects"),
# il caso degli animali, il meteo e dove guarda la telecamera
func game_state() -> Dictionary:
	var packer := SAVES.Packer.new(saved_classes())
	var fields := {}
	for name in SAVED:
		fields[name] = packer.pack(get(name))
	return {"main": fields, "objects": packer.fields(), "wild": [wild.seed, wild.state], "weather": atmosphere.saved(),
		"camera": [camera.position, camera.zoom]}


# quello che l'elenco dei salvataggi mostra, nella lingua di adesso
func header() -> Dictionary:
	var t := fmod(clock, 1.0)
	return {"title": realm_name(), "ruler": full_name(ruler), "people": colonists.size(), "day": int(clock),
		"date": "%s %02d:%02d" % [date(int(clock)), int(t * 24), int(t * 1440) % 60], "saved": Time.get_unix_time_from_system()}


# Salva la colonia nella sua cartella (vedi SAVES.write): il salvataggio più recente, gli altri scorrono. Non si
# salva senza cartella (nei test) né una colonia caduta: si riprende dall'ultima alba. OK, o l'errore
func save_game() -> Error:
	if game_id == "" or fallen:
		return ERR_UNAVAILABLE
	return SAVES.write(game_id, header(), game_state())


# le voci del menu Debug, in alto (vedi _ready)
func debug_pressed(id: int) -> void:
	match id:
		0:
			advance(0.5)


# debug: `days` giorni simulati, non saltati, così bisogni e lavori vanno avanti davvero
func advance(days: float) -> void:
	for i in roundi(days * DAY_LENGTH / 0.05):
		tick(0.05)


# il salvataggio automatico; lo dice in alto (`quiet`: solo se non riesce, uscendo non lo si vedrebbe)
func autosave(quiet := false) -> void:
	if game_id == "" or fallen:
		return
	var err := save_game()
	if err != OK:
		show_toast(tr("Could not save the game (%s).") % error_string(err))
	elif not quiet:
		show_toast(tr("Saved"))


# Quit game nel menù: salva ed esce
func quit_game() -> void:
	autosave(true)
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:  # chiusura della finestra: salva prima che il gioco esca
		autosave(true)


# Rimette lo stato salvato (in _ready, al posto di generate_map) e rifà quello che ne discende: la griglia dei
# percorsi, tetti e magazzini, il terreno disegnato. Meteo e telecamera dopo, in resume
func restore(state: Dictionary) -> void:
	var unpacker := SAVES.Unpacker.new(saved_classes(), state["objects"])
	for name in state["main"]:
		SAVES.Unpacker.put(self, name, unpacker.unpack(state["main"][name]))
	for c in unpacker.objects[saved_classes().find(Colonist)]:  # di prima delle età: adulti, a caso
		if c.born == INF:
			give_age(c, RULER_AGE if c == ruler else ADULT_AGE)
	if house_name == "" and ruler != null:  # di prima della successione
		house_name = ruler.last_name
		reigns = [[ruler, 0.0, -1.0, house_name]]
	for res in Res.values():  # un oggetto nuovo, che il salvataggio non conosceva: nessuno a terra
		if not items.has(res):
			items[res] = {}
	wild.seed = state["wild"][0]
	wild.state = state["wild"][1]  # dopo il seme, che lo azzera
	if soil.size() != MAP_SIZE.x * MAP_SIZE.y:  # un salvataggio di prima della fertilità
		make_soil()
	for k in plans.keys():  # di prima della pianificazione (una coltura per anno): rape, quante ne stanno
		if plans[k][1].any(func(year): return year is int):
			plans[k] = [plans[k][0], DEFAULT_PLAN.duplicate(true)]
	for k in tired.keys():
		if tired[k].size() == 3:
			tired[k] = [tired[k][0], tired[k][2]]
	update_fields()
	rebuild_grid()
	update_roofs()
	update_stockpile()
	bake_ground(ground_noise(map_seed))


# la griglia dei percorsi da quello che c'è sulla mappa, come la lasciano generate_map, build e mark: roccia e acqua
# alta solide, l'acqua bassa lenta, muri e palizzate solidi, le strade svelte (il ghiaccio lo rimette resume)
func rebuild_grid() -> void:
	for cell in rocks:
		astar.set_point_solid(cell)
	for cell in water:
		if water[cell] == Ground.DEEP:
			astar.set_point_solid(cell)
		else:
			astar.set_point_weight_scale(cell, SHALLOW_COST)
	for cell in built:
		if built[cell][0] in BARRIERS:
			astar.set_point_solid(cell)
		elif built[cell][0] == Build.ROAD:
			astar.set_point_weight_scale(cell, 1.0 / ROAD_SPEED)


# finito _ready di una partita caricata: il meteo (e l'acqua gelata), la telecamera; si riparte in pausa
func resume(state: Dictionary) -> void:
	atmosphere.restore(state["weather"])
	if atmosphere.frozen:
		freeze_water(true)
	camera.position = state["camera"][0]
	camera.zoom = state["camera"][1]
	if fallen:
		$HUD/Fallen.show()
	if not requests.is_empty():  # chi aspettava la risposta la chiede di nuovo
		show_request(requests[0])
	Engine.time_scale = 0.0


# tab System, Load game: la pagina coi salvataggi, riletti dal disco
func open_saves() -> void:
	save_list.refresh()
	options.get_node("Window/Box/Body/Pages").current_tab = save_list.get_index()


# la colonia scelta nell'elenco: salvata questa, la scena si rifà da capo e _ready la prende al posto di una nuova
func load_game(state: Dictionary) -> void:
	SAVES.pending = state
	go_to("res://main.tscn")


# un'altra scena (il titolo, o un'altra colonia), salvata prima questa; il menù delle opzioni aveva fermato il gioco
func go_to(scene: String) -> void:
	autosave(true)
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(scene)


func show_toast(text: String) -> void:
	toast.text = text
	toast_until = Time.get_ticks_msec() + TOAST_TIME


# tab del menù delle opzioni: la sua pagina al posto di quella aperta
func show_page(on: bool, page: Control) -> void:
	if on:
		page.get_parent().current_tab = page.get_index()


# Esc o ingranaggio in alto a destra: apre o chiude il menù delle opzioni
func toggle_options() -> void:
	options.visible = not options.visible


# aperto il menù il gioco si ferma e si parte sempre da System; chiuso (anche con la X) riprende alla velocità di prima
func options_toggled() -> void:
	if options.visible:
		resume_speed = Engine.time_scale
		Engine.time_scale = 0.0
		options.move_to_front()  # sopra le finestre aperte dopo
		options.get_node("Window/Box/Body/Tabs/System").button_pressed = true
		options.get_node("Window/Box/Body/Pages").current_tab = 0  # anche dalla pagina dei salvataggi
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN  # anche dal tasto in alto
		video.get_node("Fullscreen").set_pressed_no_signal(full)
		video.get_node("Resolution/Sizes").disabled = full
		video.get_node("Resolution/Sizes").select(RESOLUTIONS.find(DisplayServer.window_get_size()))  # -1: misura a mano
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
			# comandi tolti dalla barra, e tasti diventati fissi dopo: si ignorano
			if tool_names.has(name) and config.get_value("keys", name) not in FIXED_KEYS:
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
		hotbar.get_node(NodePath(name)).tooltip_text = tr(tool_names[name]) + ("" if key == KEY_NONE else " (%s)" % OS.get_keycode_string(key))
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


# schermo in alto a destra o tab Video; a schermo intero la risoluzione non si sceglie
func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	video.get_node("Resolution/Sizes").disabled = on  # il cambio di modo può arrivare dopo: non rileggerlo


# tab System: i testi con una traduzione cambiano subito (quelli composti nel codice al prossimo aggiornamento: le
# finestre che si rifanno solo se cambia qualcosa si rifanno ora); la scelta resta per la prossima volta (la rilegge
# title.gd)
func set_language(code: String) -> void:
	TranslationServer.set_locale(code)
	board_key = ""
	knowledge_key = ""
	laws_key = ""
	census_key = ""
	fill_wiki()
	show_title()  # il nome del reame in alto
	if settings_file == "":
		return
	var config := ConfigFile.new()
	config.load(settings_file)  # tiene le altre sezioni
	config.set_value("game", "language", code)
	config.save(settings_file)


# finestra Wiki: gli argomenti nella lingua del gioco, aperta sulla pagina che si stava leggendo (all'inizio la prima)
func fill_wiki() -> void:
	var topics: ItemList = $HUD/WikiPanel/Box/Body/Topics
	var page := maxi(0, topics.get_selected_items()[0] if topics.is_anything_selected() else 0)
	topics.clear()
	for p in WIKI.pages():
		topics.add_item(p[0])
	topics.select(page)
	topics.item_selected.emit(page)


# nome da mostrare per il valore di un enum, tradotto (locale/<lingua>.po): Res.LEATHER_ARMOR -> "Leather Armor",
# in italiano "Armatura di cuoio". `context` separa le parole uguali con sensi diversi: "item" per gli oggetti (Res:
# Fish è il pesce, non il pescare), "skill" per le abilità, "branch" per i rami della ricerca, "division" per le
# partizioni dello stemma, "heraldry" per pezze e figure
static func named(names: Dictionary, value: int, context := "") -> String:
	return String(TranslationServer.translate(names.keys()[value].capitalize(), context))


# tab Video: la finestra prende la misura scelta e si rimette al centro dello schermo
func set_resolution(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	var screen := DisplayServer.screen_get_usable_rect()
	DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


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


# categorie "Structures" (muro) e quelle dei mobili (FURNITURE_GROUPS), una alla volta: sopra compare la sua barra
# (strutture e materiale, o il gruppo di mobili e le frecce per girarli), al centro "Build" e la X per cancellare.
# Passando dall'una all'altra il progetto resta (es. un letto sul pavimento appena disegnato)
func toggle_category(on: bool, bar: Control) -> void:
	bar.visible = on
	if on:
		reset_choice()  # il tipo scelto nell'altra barra qui non c'è
	actions.visible = category_group.get_pressed_button() != null


# una categoria dei mobili: la barra dei mobili col solo gruppo `group`
func toggle_furniture(on: bool, group: Control) -> void:
	if on:
		for other in FURNITURE_GROUPS:
			furniture_bar.get_node("Row/" + other).visible = other == group.name
		furniture_bar.reset_size()  # stretta come il gruppo, non come il più lungo
	toggle_category(on, furniture_bar)


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
# i suoi materiali, per pezzo); sotto il comfort che dà, una riga e la descrizione colorata
func build_tip(kind: Build) -> Control:
	var box := VBoxContainer.new()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	var title := Label.new()
	title.text = named(Build, kind)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var costs := VBoxContainer.new()
	var cost := cost_of([kind, BUILD_RES.get(kind, Res.WOOD)])
	if kind in ANY_MATERIAL:
		cost[Res.STONE] = cost[Res.WOOD]
	for res in cost:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		var amount := Label.new()
		amount.text = "%s%d%s" % [tr("or ") if res == Res.STONE and kind in ANY_MATERIAL else "", cost[res], "" if FURNITURE.has(kind) else tr("/tile")]
		row.add_child(amount)
		row.add_child(ui_icon(ICONS[res], Rect2(), Vector2(16, 16)))
		costs.add_child(row)
	head.add_child(title)
	head.add_child(costs)
	box.add_child(head)
	if COMFORT.has(kind):  # chi non dà comfort salta la sezione
		var bonus := Label.new()
		bonus.text = tr("+%s room comfort") % str(COMFORT[kind]).trim_suffix(".0")
		if kind == Build.FLOOR:
			bonus.text += tr(" paving it all, x%s in stone") % COMFORT_MATERIAL[Res.STONE]
		bonus.add_theme_color_override("font_color", TREND_UP)
		box.add_child(bonus)
	if HEAT.has(kind):
		var heat := Label.new()
		heat.text = tr("+%d °C in the room") % HEAT[kind]
		if kind in THROUGH_STONE:
			heat.text += tr(", +%s °C behind a wall, even of stone") % str(HEAT[kind] * THROUGH[kind]).trim_suffix(".0")
		elif THROUGH.has(kind):
			heat.text += tr(", +%s °C behind a wooden wall") % str(HEAT[kind] * THROUGH[kind]).trim_suffix(".0")
		heat.add_theme_color_override("font_color", HEAT_COLOR)
		box.add_child(heat)
	if INSULATES.has(kind):
		var keeps := Label.new()
		keeps.text = tr("+%d%% room insulation") % roundi(INSULATES[kind][0] * 100)
		keeps.add_theme_color_override("font_color", HEAT_COLOR)
		box.add_child(keeps)
	if SPLENDOR.has(kind):
		var splendor := Label.new()
		splendor.text = tr("+%d colony splendor") % SPLENDOR[kind]
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


# Il cartello di un campo (vedi open_field), come gli altri popup: titolo (il nome del campo) e X; quante caselle; la
# sua timeline di quest'anno (vedi draw_plan_row); l'anno prossimo, l'ultimo raccolto, la terra; "Plan the fields…"
func build_field_popup() -> void:
	field_popup.name = "FieldPopup"
	field_popup.visible = false
	field_popup.custom_minimum_size = Vector2(380, 0)
	field_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	field_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	field_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := popup_frame(field_popup, "Field")
	var size_label := Label.new()
	size_label.name = "Size"
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(size_label)
	var this_year := Label.new()
	this_year.text = "This year"
	this_year.add_theme_color_override("font_color", BUILD_INFO_COLOR)
	box.add_child(this_year)
	var mini := Control.new()
	mini.name = "Mini"
	mini.custom_minimum_size = Vector2(360, 28)
	mini.draw.connect(func(): draw_plan_row(mini, field_of(editing_field).min(), year_of(today), Rect2(Vector2.ZERO, mini.size), false))
	box.add_child(mini)
	for name in ["Next", "Last", "Soil"]:
		var label := Label.new()
		label.name = name
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(360, 0)  # andando a capo, senza una larghezza sarebbe una lettera per riga
		box.add_child(label)
	var manure := CheckBox.new()
	manure.name = "Manure"
	manure.text = "Fertilize before sowing"
	manure.focus_mode = Control.FOCUS_NONE
	manure.toggled.connect(func(on):
		for k in field_of(editing_field):
			if on:
				no_manure.erase(k)
			else:
				no_manure[k] = true)
	box.add_child(manure)
	var plan := Button.new()
	plan.name = "Plan"
	plan.text = "Plan the fields…"
	plan.focus_mode = Control.FOCUS_NONE
	plan.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plan.pressed.connect(func():
		field_popup.hide()
		open_plan())
	box.add_child(plan)
	$HUD.add_child(field_popup)


# una finestra come gli altri popup: Box, Head col titolo `title` e la X (che la chiude, vedi _ready); ritorna Box
func popup_frame(window: PanelContainer, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 8)
	window.add_child(box)
	var head := HBoxContainer.new()
	head.name = "Head"
	box.add_child(head)
	var label := Label.new()
	label.name = "Title"
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(label)
	var close: Button = $HUD/RoomPopup/Box/Head/Close.duplicate()
	close.name = "Close"
	head.add_child(close)
	return box


func open_field(cell: Vector2i) -> void:
	editing_field = cell
	refresh_field()
	field_popup.show()
	field_popup.reset_size()


# Il campo aperto: il nome, quante caselle, la timeline di quest'anno, le colture dell'anno prossimo, l'ultimo
# raccolto a casella, e la terra se la si conosce (vedi soil_words)
func refresh_field() -> void:
	var field := field_of(editing_field)
	if field.is_empty():
		field_popup.hide()
		return
	var box: Control = field_popup.get_node("Box")
	var y := year_of(today)
	var sign_cell: Vector2i = field.min()
	box.get_node("Head/Title").text = field_name(sign_cell)
	box.get_node("Size").text = tr_n("%d plot", "%d plots", field.size()) % field.size()
	box.get_node("Mini").queue_redraw()
	box.get_node("Next").text = tr("Next year: %s.") % crops_words(slots_of(sign_cell, y + 1))
	var latest := -1
	for k in field:
		latest = maxi(latest, last_yield.get(k, [-1])[0])
	var last := field.filter(func(k): return last_yield.get(k, [-1])[0] == latest and latest >= 0).map(func(k): return last_yield[k])
	if last.is_empty():
		box.get_node("Last").text = tr("No harvest yet.")
	else:
		var crop: int = last[-1][1]
		var same := last.filter(func(e): return e[1] == crop)
		var avg := roundi(same.reduce(func(n, e): return n + e[2], 0) / float(same.size()))
		box.get_node("Last").text = tr("Last: green manure, ploughed in.") if CROP_YIELD[crop] == 0 \
			else tr("Last harvest: %s, %d a plot.") % [tr(CROP_NAMES[crop]).to_lower(), avg]
	box.get_node("Soil").text = soil_words(field)
	box.get_node("Soil").visible = box.get_node("Soil").text != ""
	box.get_node("Manure").visible = researched.has(Tech.MANURING)
	box.get_node("Manure").set_pressed_no_signal(not no_manure.has(sign_cell))


# le colture `slots` in parole: "turnips, turnips, cabbages", o "fallow"
func crops_words(slots: Array) -> String:
	if slots.is_empty():
		return tr("fallow")
	return ", ".join(slots.map(func(slot): return tr(CROP_NAMES[slot[0]]).to_lower()))


# Quello che si sa della terra del campo `field`: col Catasto i numeri, la tendenza e il prossimo raccolto; con
# l'Almanacco cinque fasce e la tendenza; col Saggio tre fasce; senza ricerche, quello che dicono i contadini delle
# caselle che hanno lavorato (vedi learn_soil); se no niente
func soil_words(field: Array) -> String:
	var now := mean_soil(field, soil)
	var trend := now - mean_soil(field, soil_year_ago)
	var going: String = tr("rising") if trend > SOIL_TREND else (tr("falling") if trend < -SOIL_TREND else tr("steady"))
	if researched.has(Tech.LAND_REGISTER):
		var crops := field.map(crop_of).filter(func(c): return c >= 0)
		var next := tr("Fallow this year.") if crops.is_empty() else tr("Next harvest: about %d a plot.") \
			% roundi(field.filter(func(k): return crop_of(k) >= 0).reduce(func(n, k): return n + crop_yield(k, crop_of(k)), 0) / float(crops.size()))
		return tr("Soil: %d, %s.") % [roundi(now), going] + "\n" + next
	if researched.has(Tech.ALMANAC):
		return tr("Soil: %s, %s.") % [tr(soil_word(now, 1)).to_lower(), going]
	if researched.has(Tech.SOIL_SURVEY):
		return tr("Soil: %s.") % tr(soil_word(now, 0)).to_lower()
	var known := field.filter(func(k): return soil_known.has(k))
	if not known.is_empty():
		return tr("The farmers say the soil is %s.") % tr(soil_word(mean_soil(known, soil), 0)).to_lower()
	return ""


# la fertilità media delle caselle `cells` in `values` (soil, o soil_year_ago)
func mean_soil(cells: Array, values: PackedByteArray) -> float:
	if cells.is_empty() or values.size() != soil.size():
		return 0.0
	return cells.reduce(func(n, k): return n + values[k.y * MAP_SIZE.x + k.x], 0) / float(cells.size())


# la fascia di `f` (0: tre fasce, 1: cinque, vedi SOIL_BANDS)
func soil_band(f: float, scale: int) -> int:
	var band := 0
	for edge in SOIL_BANDS[scale]:
		if f >= edge:
			band += 1
	return band


func soil_word(f: float, scale: int) -> String:
	return SOIL_WORDS[scale][soil_band(f, scale)]


# Lente della terra: le caselle che si vedono, fuori da acqua e roccia, col colore della loro fascia (tre col Saggio,
# cinque con l'Almanacco); col Catasto, da vicino, il numero
func draw_soil_lens() -> void:
	var half := get_viewport_rect().size / camera.zoom / 2
	var view := Rect2i(cell_of(camera.position - half) - Vector2i.ONE, Vector2i((half * 2 / TILE).ceil()) + Vector2i(3, 3))
	view = view.intersection(Rect2i(Vector2i.ZERO, MAP_SIZE))
	var scale := 1 if researched.has(Tech.ALMANAC) else 0
	var numbers := researched.has(Tech.LAND_REGISTER) and camera.zoom.x >= 2.5
	var font := info_label.get_theme_font("font")
	for cell in cells_in(view):
		if water.has(cell) or rocks.has(cell):
			continue
		var f := soil_at(cell)
		var band := soil_band(f, scale)
		var tint: Color = SOIL_COLORS[band * 2 if scale == 0 else band]  # tre fasce: povera, media, ricca
		soil_canvas.draw_rect(tile_rect(cell.x, cell.y), Color(tint, 0.45))
		if numbers:
			lens_text_on(soil_canvas, Vector2(cell * TILE) + Vector2(0, 11), str(f), font)


# --- Pianificazione dei campi, a gantt ---
# Una finestra (vedi open_plan) con l'anno in orizzontale (stagioni e mesi in testa) e una riga per campo: le colture del
# suo piano sono barre lunghe quanto crescono, colorate per coltura; a righe la terra fredda prima di SOW_FROM, in
# azzurro l'inverno; la linea gialla è oggi. ◀ ▶ mostrano gli anni dopo, fino a PLAN_YEARS - 1. Clic su uno spazio
# vuoto: una coltura, attaccata a quella prima; su una coltura: cambiarla o toglierla; sul nome: le rotazioni pronte e
# il ciclo, da 1 a PLAN_YEARS anni (vedi plan_input)
func build_plan_panel() -> void:
	plan_panel.name = "PlanPanel"
	plan_panel.visible = false
	plan_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	plan_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plan_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := popup_frame(plan_panel, "Field planning")
	var nav := HBoxContainer.new()
	nav.name = "Nav"
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 14)
	for step in [-1, 1]:
		var arrow := Button.new()
		arrow.name = "Prev" if step < 0 else "Next"
		arrow.text = "◀" if step < 0 else "▶"
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.pressed.connect(func():
			plan_year = clampi(plan_year + step, 0, PLAN_YEARS - 1)
			refresh_plan())
		nav.add_child(arrow)
	var year_label := Label.new()
	year_label.name = "Year"
	year_label.add_theme_color_override("font_color", Color("e8c34a"))
	nav.add_child(year_label)
	nav.move_child(year_label, 1)
	box.add_child(nav)
	plan_chart.name = "Chart"
	plan_chart.mouse_filter = Control.MOUSE_FILTER_STOP
	plan_chart.draw.connect(draw_plan)
	plan_chart.gui_input.connect(plan_input)
	box.add_child(plan_chart)
	var legend := Label.new()
	legend.name = "Legend"
	legend.text = "Striped: the soil is still cold, no sowing. Blue: winter, nothing grows. Click an empty spot to add a crop, a crop to change it, a field's name for ready rotations."
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.custom_minimum_size = Vector2(PLAN_NAME + YEAR_DAYS * PLAN_DAY, 0)
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", Color("b0aca0"))
	box.add_child(legend)
	plan_menu.id_pressed.connect(plan_menu_pressed)
	plan_panel.add_child(plan_menu)
	$HUD.add_child(plan_panel)


func open_plan() -> void:
	plan_year = 0
	refresh_plan()
	plan_panel.show()
	plan_panel.reset_size()


# l'anno mostrato e le frecce; la misura del gantt, una riga per campo
func refresh_plan() -> void:
	var nav: Control = plan_panel.get_node("Box/Nav")
	nav.get_node("Year").text = tr("Year %d") % (year_of(today) + plan_year + 1) + (tr(" · this year") if plan_year == 0 else "")
	nav.get_node("Prev").disabled = plan_year == 0
	nav.get_node("Next").disabled = plan_year == PLAN_YEARS - 1
	plan_chart.custom_minimum_size = Vector2(PLAN_NAME + YEAR_DAYS * PLAN_DAY, PLAN_AXIS + maxi(field_signs.size(), 1) * PLAN_ROW + 18)
	plan_chart.queue_redraw()
	plan_panel.reset_size()


func draw_plan() -> void:
	var font := info_label.get_theme_font("font")
	var x0 := float(PLAN_NAME)
	var tall := PLAN_AXIS + maxi(field_signs.size(), 1) * PLAN_ROW
	for season_i in SEASONS.size():  # in testa stagioni e mesi; una riga a ogni stagione
		var sx := x0 + (1 + season_i * SEASON_DAYS) * PLAN_DAY
		plan_chart.draw_line(Vector2(sx, 0), Vector2(sx, tall), Color(1, 1, 1, 0.12))
		plan_chart.draw_string(font, Vector2(sx, 13), tr(SEASONS[season_i]), HORIZONTAL_ALIGNMENT_CENTER,
			SEASON_DAYS * PLAN_DAY, 13, Color("d9c48a"))
		for m in 3:
			plan_chart.draw_string(font, Vector2(sx + m * MONTH_DAYS * PLAN_DAY, 29), tr(MONTHS[season_i * 3 + m]).left(3),
				HORIZONTAL_ALIGNMENT_CENTER, MONTH_DAYS * PLAN_DAY, 11, Color("b0aca0"))
	if field_signs.is_empty():
		plan_chart.draw_string(font, Vector2(0, PLAN_AXIS + 24), tr("No fields yet: mark garden plots with Garden (P)."),
			HORIZONTAL_ALIGNMENT_CENTER, x0 + YEAR_DAYS * PLAN_DAY, 14, Color("b0aca0"))
	var y := year_of(today) + plan_year
	for r in field_signs.size():
		var sign_cell: Vector2i = field_signs[r]
		var top := PLAN_AXIS + r * PLAN_ROW
		var cycle: int = plan_of(sign_cell)[1].size()
		var sub: String = tr_n("%d plot", "%d plots", field_of(sign_cell).size()) % field_of(sign_cell).size() + " · " + (tr("every year")
			if cycle == 1 else tr("%d-year cycle, year %d") % [cycle, plan_index(sign_cell, y) + 1])
		plan_chart.draw_string(font, Vector2(4, top + 17), field_name(sign_cell), HORIZONTAL_ALIGNMENT_LEFT, x0 - 8, 15, Color("e6e2d0"))
		plan_chart.draw_string(font, Vector2(4, top + 32), sub, HORIZONTAL_ALIGNMENT_LEFT, x0 - 8, 11, Color("b0aca0"))
		draw_plan_row(plan_chart, sign_cell, y, Rect2(x0, top + 4, YEAR_DAYS * PLAN_DAY, PLAN_ROW - 8), true)
	if plan_year == 0:
		var tx := x0 + (clock - year_start()) * PLAN_DAY
		plan_chart.draw_string(font, Vector2(tx - 100, tall + 14), "▲ " + tr("today, %s") % day_name(today),
			HORIZONTAL_ALIGNMENT_CENTER, 200, 11, Color("e8c34a"))


# Una riga del gantt in `r` su `canvas`: le colture del piano del campo di `sign_cell` nell'anno `y`; a righe la terra
# fredda, in azzurro l'inverno, la linea gialla di oggi. `labels`: icona e nome sulle barre, "fallow" se non ce ne sono
func draw_plan_row(canvas: Control, sign_cell: Vector2i, y: int, r: Rect2, labels: bool) -> void:
	var font := info_label.get_theme_font("font")
	var px := r.size.x / YEAR_DAYS
	canvas.draw_rect(r, Color(1, 1, 1, 0.05))
	var cold := Rect2(r.position, Vector2(SOW_FROM * px, r.size.y))
	canvas.draw_rect(cold, Color(PLAN_COLD, PLAN_COLD.a * 0.5))
	for k in range(0, int(cold.size.x + cold.size.y), 6):  # righe in diagonale, tagliate al riquadro
		var a := Vector2(cold.position.x + k, cold.position.y)
		var t0 := clampf((a.x - cold.end.x) / cold.size.y, 0.0, 1.0)
		var t1 := clampf((a.x - cold.position.x) / cold.size.y, 0.0, 1.0)
		canvas.draw_line(a + Vector2(-cold.size.y, cold.size.y) * t0, a + Vector2(-cold.size.y, cold.size.y) * t1, PLAN_COLD, 2.0)
	canvas.draw_rect(Rect2(r.position.x + winter_day() * px, r.position.y, (YEAR_DAYS - winter_day()) * px, r.size.y), PLAN_WINTER)
	if field_of(sign_cell).is_empty():
		return
	var slots := slots_of(sign_cell, y)
	if slots.is_empty() and labels:
		canvas.draw_string(font, Vector2(r.position.x, r.position.y + r.size.y / 2 + 5), tr("Fallow: the soil rests"),
			HORIZONTAL_ALIGNMENT_CENTER, winter_day() * px, 13, Color("b0aca0"))
	for slot in slots:
		var bar := Rect2(r.position.x + slot[1] * px, r.position.y, CROP_DAYS[slot[0]] * px, r.size.y)
		canvas.draw_rect(bar, CROP_COLORS[slot[0]])
		canvas.draw_rect(bar, OUTLINE, false, 2.0)
		var icon := minf(16, r.size.y - 4)
		canvas.draw_texture_rect(ICONS[CROP_ICON[slot[0]]], Rect2(bar.position + Vector2(3, (r.size.y - icon) / 2), Vector2.ONE * icon), false)
		if labels:
			canvas.draw_string(font, Vector2(bar.position.x + icon + 6, bar.position.y + r.size.y / 2 + 5), tr(CROP_NAMES[slot[0]]),
				HORIZONTAL_ALIGNMENT_LEFT, bar.size.x - icon - 8, 13, Color.WHITE)
	if y == year_of(today):
		var tx := r.position.x + (clock - year_start()) * px
		canvas.draw_line(Vector2(tx, r.position.y - 2), Vector2(tx, r.end.y + 2), Color("e8c34a"), 2.0)


# Clic nel gantt: sul nome di un campo le rotazioni pronte e il ciclo; su una coltura cambiarla o toglierla; nel vuoto
# una coltura nuova, attaccata a quella prima (vedi slot_room): quelle che non ci stanno sono spente, col perché
func plan_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var row: int = floori((event.position.y - PLAN_AXIS) / PLAN_ROW)
	if event.position.y < PLAN_AXIS or row < 0 or row >= field_signs.size():
		return
	var sign_cell: Vector2i = field_signs[row]
	var y := year_of(today) + plan_year
	var slots := slots_of(sign_cell, y)
	plan_menu.clear()
	plan_click = [sign_cell, plan_index(sign_cell, y), -1, 0]
	if event.position.x < PLAN_NAME:
		plan_menu.add_item(tr("Every year: turnips"), 100)
		plan_menu.add_item(tr("Classic rotation, 4 years, from this one"), 101)
		plan_menu.add_separator()
		for n in range(1, PLAN_YEARS + 1):
			plan_menu.add_radio_check_item(tr("Every year") if n == 1 else tr("A %d-year cycle") % n, 110 + n)
			plan_menu.set_item_checked(plan_menu.get_item_count() - 1, plan_of(sign_cell)[1].size() == n)
		plan_menu.add_separator()
		plan_menu.add_item(tr("Leave this year fallow"), 120)
	else:
		var day: float = (event.position.x - PLAN_NAME) / PLAN_DAY
		var at := slots.find_custom(func(slot): return slot[1] <= day and day < slot[1] + CROP_DAYS[slot[0]])
		var room := slot_room(slots, day)
		if at >= 0:  # su una coltura: al suo posto un'altra che ci stia, o via
			plan_click[2] = at
			room = slot_room(slots.slice(0, at) + slots.slice(at + 1), slots[at][1])
			room[0] = slots[at][1]
		plan_click[3] = room[0]
		for crop in Crop.values():
			if crop == Crop.GREEN and not researched.has(Tech.MANURING):
				continue
			var end: int = room[0] + int(CROP_DAYS[crop])
			var text := "%s: %s" % [tr(CROP_NAMES[crop]), tr("%d days: %s – %s") % [CROP_DAYS[crop], day_name(room[0]), day_name(end)]]
			if end > room[1]:
				text = "%s: %s" % [tr(CROP_NAMES[crop]), tr("doesn't end before winter") if room[1] == winter_day() else tr("no room before the next crop")]
			plan_menu.add_icon_item(ICONS[CROP_ICON[crop]], text, (200 if at >= 0 else 300) + crop)
			plan_menu.set_item_disabled(plan_menu.get_item_count() - 1, end > room[1] or (at >= 0 and slots[at][0] == crop))
		if at >= 0:
			plan_menu.add_separator()
			plan_menu.add_item(tr("Remove"), 210)
	plan_menu.reset_size()
	plan_menu.position = Vector2i(get_viewport().get_mouse_position())
	plan_menu.popup()


# la voce scelta nel menu del gantt, sul campo e l'anno del ciclo di plan_click
func plan_menu_pressed(id: int) -> void:
	var sign_cell: Vector2i = plan_click[0]
	var at: int = plan_click[1]
	var plan: Array = plan_of(sign_cell).duplicate(true)
	if id == 100:
		plan = [year_of(today), DEFAULT_PLAN.duplicate(true)]
	elif id == 101:
		plan = [year_of(today) + plan_year, CLASSIC_PLAN.duplicate(true)]
	elif id > 110 and id <= 110 + PLAN_YEARS:  # il ciclo: gli anni nuovi a maggese, da riempire
		var years: Array = plan[1]
		while years.size() < id - 110:
			years.append([])
		years.resize(id - 110)
	elif id == 120:
		plan[1][at] = []
	elif id >= 200 and id < 200 + Crop.size():
		plan[1][at][plan_click[2]][0] = id - 200
	elif id == 210:
		plan[1][at].remove_at(plan_click[2])
	elif id >= 300 and id < 300 + Crop.size():
		plan[1][at].append([id - 300, plan_click[3]])
		plan[1][at].sort_custom(func(a, b): return a[1] < b[1])
	set_field_plan(sign_cell, plan)


# `plan` diventa il piano di tutte le caselle del campo di `sign_cell`
func set_field_plan(sign_cell: Vector2i, plan: Array) -> void:
	for k in field_of(sign_cell):
		plans[k] = plan.duplicate(true)
	refresh_plan()
	if field_popup.visible:
		refresh_field()


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
	$HUD/RoomPopup/Box/Comfort.text = tr("Comfort: %d / %d    %d°C") \
		% [room_comfort(editing), COMFORT_MAX, roundi(temperature_at(editing.cells.keys()[0]))]
	$HUD/RoomPopup/Box/Comfort.tooltip_text = "\n".join(heat_lines(editing))
	var kinds := RoomKind.values().filter(func(k): return room_meets(editing, k))
	if kinds != range(room_kind.item_count).map(room_kind.get_item_id):
		room_kind.clear()
		for kind in kinds:
			room_kind.add_item(named(RoomKind, kind), kind)
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
	var kind: Build = role(furniture[origin][0])  # il focolare fa le ricette del fuoco da campo
	var box: Control = $HUD/CraftPopup/Box
	box.get_node("Head/Title").text = named(Build, furniture[origin][0])
	box.get_node("Room").text = tr("Works only in a %s") % named(RoomKind, STATION_ROOM[kind]).to_lower()
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
		label.text = named(Res, r[0], "item")
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
		count.prefix = tr("Keep")  # il prefisso non si traduce da sé
		count.custom_minimum_size.x = 100  # se no taglia la scritta
		count.value = keep.get(r[0], 0)
		count.tooltip_text = tr("Made until there are this many") + (tr(", besides what colonists need to wear") if GEAR.has(r[0]) else "")
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
	box.get_node("Sex/Label").text = tr("%s, %d years old") % [tr(SEX_NAMES[c.sex]), age_of(c)]
	box.get_node("Family/Spouse").visible = c.spouse != null
	if c.spouse != null:  # la croce: vedovo
		box.get_node("Family/Spouse").text = tr("Spouse: %s") % full_name(c.spouse) + (" †" if c.spouse.died > 0.0 else "")
	box.get_node("Family/Marry").visible = c == ruler and can_marry() and box == $HUD/ColonistSheet/Box
	box.get_node("Family/House").visible = c in colonists and box == $HUD/ColonistSheet/Box
	var kin: Array = children_of(c).map(func(o): return "%s (%d)" % [o.first_name, age_of(o)] + (" †" if o.died > 0.0 else ""))
	box.get_node("Kin").visible = not kin.is_empty() or c.mother != null
	box.get_node("Kin").text = tr("Children: %s") % ", ".join(kin) if not kin.is_empty() else (tr("Parents: %s and %s") \
		% [full_name(c.mother), full_name(c.father)] if c.father != null else tr("Mother: %s") % full_name(c.mother)) \
		if c.mother != null else ""
	box.get_node("Head/Arms").visible = c == ruler or c.suitor  # quello della casata lo mette show_title
	if c.suitor:
		box.get_node("Head/Arms").texture = arms_texture(c.house_arms)
	elif c == ruler:
		box.get_node("Head/Arms").texture = arms_tex
	var asks := not request_of(c).is_empty()
	box.get_node("Hero").visible = c.hero != Hero.NONE or c == ruler or c == regent_for or c.suitor or c.former != Hero.NONE or asks
	box.get_node("Hero").text = (tr_n("%s, fee %s, %d expedition", "%s, fee %s, %d expeditions", c.trips) % [hero_name(c), coins(fee(c)), c.trips] \
		if c.hero != Hero.NONE else (tr("%s %s of %s") % [CROWN_IMG, ruler_title(c), realm] if c == ruler
		else (tr("%s Heir of %s") % [CROWN_IMG, realm] if c == regent_for
		else (tr("Suitor from the house of %s. Dowry: %s.") % [c.last_name, dowry_words(c)] if c.suitor
		else (tr_n("Once a %s, level %d, %d expedition", "Once a %s, level %d, %d expeditions", c.trips)
			% [named(Hero, c.former).to_lower(), c.level, c.trips] if c.former != Hero.NONE else ""))))) \
		+ ("\n" + tr("Asks to stay in the colony.") if asks else "")
	box.get_node("Family/Request").visible = asks and box == $HUD/ColonistSheet/Box
	box.get_node("Health").text = health_text(c)
	for child in needs_grid.get_children() + skills_grid.get_children() + traits_box.get_children():
		child.free()
	var back := bar_style(BAR_BACK)
	for n in Need.values():  # i valori li aggiorna update_need_bars
		var label := Label.new()
		label.text = named(Need, n)
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
		skill.text = named(Skill, s, "skill")
		skill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var level := Label.new()
		level.text = str(c.skills[s])
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		level.tooltip_text = tr("%d XP") % c.xp[s]
		level.mouse_filter = Control.MOUSE_FILTER_PASS  # se no il suggerimento non compare
		var star := ui_icon(STAR if c.skills[s] == SKILL_MAX else null, Rect2(), Vector2(18, 18))  # vuota, tiene la colonna
		for node in [ui_icon(SKILLS_SHEET, Rect2(s * 8, 0, 8, 8), Vector2(16, 16)), skill, level, star]:
			skills_grid.add_child(node)
	for t in c.traits:
		var icon := ui_icon(TRAITS_SHEET, Rect2(tile_rect(t, 0)), Vector2(32, 32))
		icon.tooltip_text = "%s\n%s" % [named(Trait, t), tr(TRAIT_INFO[t])]
		traits_box.add_child(icon)
	for g in c.gifts:  # degli avventurieri
		var icon := ui_icon(HERO_TRAITS_SHEET, Rect2(tile_rect(g, 0)), Vector2(32, 32))
		icon.tooltip_text = "%s\n%s" % [named(Gift, g), tr(GIFT_INFO[g])]
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
	return tr("Health: %d / %d%s") % [ceili(c.hp), MAX_HP, tr("  (downed)") if c.downed else ""]


# slot dell'equipaggiamento: l'icona del pezzo, col mouse sopra nome, protezione ed effetto; vuoto, la sagoma dello slot.
# Sotto, la scelta del giocatore (vedi gear_choice); uno slot scelto a mano ha un puntino d'oro in alto a destra.
# Sopra gli slot la protezione totale
func update_gear(box: Control, c: Colonist) -> void:
	var slots: Control = box.get_node("Equipment/Slots")
	for slot in Slot.values():
		var icon: TextureRect = slots.get_child(slot)
		if not icon.has_meta("empty"):
			icon.set_meta("empty", icon.texture)
			var pin := ColorRect.new()
			pin.name = "Pin"
			pin.color = SPLENDOR_COLOR
			pin.size = Vector2(6, 6)
			pin.position = Vector2(icon.custom_minimum_size.x - 6, 0)
			pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.add_child(pin)
		icon.get_node("Pin").visible = c.loadout.has(slot)
		icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if c.hero == Hero.NONE else Control.CURSOR_ARROW
		var g = c.gear.get(slot)
		var choice := gear_choice(c, slot)
		icon.texture = ICONS[g] if g != null else icon.get_meta("empty")
		icon.tooltip_text = (named(Slot, slot) if g == null else "%s\n%s%s" % [named(Res, g, "item"),
			tr("Armor %d. ") % GEAR[g]["armor"] if GEAR[g].has("armor") else "", tr(GEAR[g]["info"])]) + choice
		if icon.get_script() == null:
			icon.set_script(TIP)
		icon.set("make_tip", gear_tip.bind(g, choice) if g != null else Callable())
	box.get_node("Equipment/Title").text = tr("Equipment") + (tr("  (armor %d)") % gear_sum(c, "armor") if gear_sum(c, "armor") > 0 else "")


# riga del suggerimento dello slot sulla scelta: automatico, o cosa ha scelto il giocatore e se non ce l'ha ancora addosso.
# Gli avventurieri hanno il loro equipaggiamento: niente scelta
func gear_choice(c: Colonist, slot: Slot) -> String:
	if c.hero != Hero.NONE:
		return ""
	if not c.loadout.has(slot):
		return tr("\nAuto. Click to choose.")
	var g = c.loadout[slot]
	return tr("\nChosen: %s%s. Click to change.") % [tr("nothing") if g == null else res_name(g), "" if c.gear.get(slot) == g else tr(" (on the way)")]


# Menu dello slot `slot` di `shown`: Auto (lo sceglie da sé, vedi fits), Empty (niente) e i pezzi che ci vanno, con
# quanti ce ne sono liberi; spuntato quello scelto. Uno che non c'è si fa (vedi gear_wanted)
func open_gear_menu(slot: Slot) -> void:
	gear_slot = slot
	gear_menu.clear()
	gear_menu.add_radio_check_item("Auto", 0)
	gear_menu.set_item_checked(0, not shown.loadout.has(slot))
	gear_menu.add_radio_check_item("Empty", 1)
	gear_menu.set_item_checked(1, shown.loadout.has(slot) and shown.loadout[slot] == null)
	gear_menu.add_separator()
	for g in GEAR:
		if GEAR[g]["slot"] == slot:
			gear_menu.add_icon_radio_check_item(ICONS[g], "%s  x%d" % [named(Res, g, "item"), available(g)], 2 + g)
			var i := gear_menu.get_item_index(2 + g)
			gear_menu.set_item_checked(i, shown.loadout.get(slot) == g)
			gear_menu.set_item_tooltip(i, GEAR[g]["info"])
	gear_menu.position = Vector2i(get_viewport().get_mouse_position())
	gear_menu.popup()


func choose_gear(id: int) -> void:
	if id == 0:
		shown.loadout.erase(gear_slot)
	else:
		shown.loadout[gear_slot] = null if id == 1 else id - 2


# suggerimento di un pezzo dell'equipaggiamento: tipo e nome, poi protezione ed effetto (come tooltip_text), poi `choice`
func gear_tip(g: Res, choice := "") -> Control:
	var text := rich("%s\n%s%s%s" % [item_title(g), tr("Armor %d. ") % GEAR[g]["armor"] if GEAR[g].has("armor") else "", tr(GEAR[g]["info"]), choice])
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
		icons.get_child(i).tooltip_text = tr("%s\n%s\n%d h left") % [named(Cond, now[i]), tr(COND_INFO[now[i]][4]),
			ceili((c.conds[now[i]] - clock) * 24)]
	for i in laws.size():
		var mood := law_mood_of(c, laws[i])
		icons.get_child(now.size() + i).tooltip_text = tr("%s: %s\n%s happiness while it is in force") % [
			tr("Approves") if mood > 0 else tr("Disapproves"), law_name(laws[i]), signed(mood)]
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
		cell.tooltip_text = "%02d:00  %s" % [h, tr(ROUTINE_NAMES[day[h]])]
	row.get_node("Worked").text = tr("Worked today: %.1f / %s h") % [c.worked, str(work_hours(c)).trim_suffix(".0")]


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
	return "%s \"%s\" %s" % [c.first_name, tr(c.nickname), c.last_name] if c.nickname else "%s %s" % [c.first_name, c.last_name]


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
	if burning.has(cell):
		return [tr("Fire!"), tr("The roof is burning: %.1f hours to burn through") % burning[cell]]
	if heat_lens.visible and room_at(cell) != null:  # lente del calore: il conto dei gradi della stanza
		return [room_at(cell).name, "\n".join(heat_lines(room_at(cell)))]
	for a in animals:
		if cell_of(a.pos) == cell:
			var lines := PackedStringArray()
			if hostile(a):
				lines.append(tr("Hostile"))
			if a.damage > 0:
				lines.append(tr("Health: %d / %d") % [BEASTS[a.kind]["hp"] - a.damage, BEASTS[a.kind]["hp"]])
			if a.marked:
				lines.append(tr("Marked: hunt"))
			return [named(Beast, a.kind), "\n".join(lines)]
	if ice_marks.has(cell):
		return [tr("Ice cutting spot"), tr("Frozen: cut ice") if atmosphere.frozen else tr("Not frozen yet")]
	if fish_marks.has(cell) and atmosphere.frozen:
		return [tr("Fishing spot"), tr("Frozen: no fishing until it thaws")]
	if fish_marks.has(cell):
		return [tr("Fishing spot"), tr("Fish: %d / %d") % [stock.get(cell, FISH_PER_SPOT), FISH_PER_SPOT] if fish_spots.get(cell, 0.0) <= clock
			else tr("Fish back in %.1f days") % (fish_spots[cell] - clock)]
	for t in [cell, cell + Vector2i.DOWN]:
		if trees.has(t):
			return [named(TreeKind, trees[t]), tr("Logs left: %d / %d%s") % [stock.get(t, full_stock(t)), full_stock(t),
				tr("\nMarked: chop") if chop_marks.has(t) else ""]]
	for origin in boulders:
		if Rect2i(origin, boulders[origin]).has_point(cell):
			var res: Res = ores.get(origin, Res.STONE)
			# la vena tutta da tradurre ("Iron vein", "Coal vein"): in italiano il nome va minuscolo, in inglese no
			return [tr("Boulder") if res == Res.STONE else tr("%s vein" % Res.keys()[res].capitalize()), tr("%s left: %d / %d%s") % [
				named(Res, res, "item"), stock.get(origin, full_stock(origin)), full_stock(origin),
				tr("\nMarked: mine") if mine_marks.has(origin) else ""]]
	var uproot := tr("\nMarked: uproot") if uproot_marks.has(cell) else (tr("\nMarked: harvest") if harvest_marks.has(cell) else "")
	if bushes.has(cell):
		var ripe: bool = bushes[cell] <= clock
		var crop := tr("Flax") if flax.has(cell) else tr("Berries")
		return [tr("Flax") if flax.has(cell) else tr("Bush"), ("%s: %d / %d" % [crop, stock.get(cell, BERRIES_PER_BUSH), BERRIES_PER_BUSH]
			if ripe else tr("%s in %.1f days") % [crop, bushes[cell] - clock]) + uproot]
	if weeds.has(cell):
		return [tr("Weed"), uproot.strip_edges()]
	for res in items:
		if items[res].has(cell):
			var about := "%d / %d" % [items[res][cell], STACK_MAX[res]]
			if res == Res.ROT:  # nel cumulo matura, fuori sparisce nella terra
				var rate := spoil_rate(cell)
				about += "\n" + (tr("compost in %.1f days") % maxf(COMPOST_DAYS - (clock - compost_since.get(cell, clock)), 0.0)
					if heap_cells().has(cell) else tr("seeps into the ground in %.1f days") % (fresh.get(cell, 0.0) / maxf(rate, 0.01)))
			elif fresh.has(cell):  # cibo: quanto è fresco e quando marcisce, dove si trova adesso
				var part: float = fresh[cell] / SHELF_LIFE[res]
				var rate := spoil_rate(cell)
				about += "\n%s, %s" % [tr(FRESH_WORDS.filter(func(w): return part > w[0] or w[0] == 0.0)[0][1]),
					tr("frozen: it keeps") if rate == 0 else tr("rots in %.1f days") % (fresh[cell] / rate)]
			return [tr("%s pile") % item_title(res), about]
	for origin in pieces_at(furniture, cell):
		var kind: Build = furniture[origin][0]
		return [named(Build, kind), {Build.DESK: tr("Click: knowledge"), Build.THRONE: tr("Click: laws")}.get(kind,
			tr("Click: what to make") if STATION_ROOM.has(kind) else "")]
	if built.has(cell):
		return [named(Build, built[cell][0]), named(Res, built[cell][1], "item")]
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


# Tabella delle priorità in cima alla finestra Jobs: in testa le icone dei lavori (Work), poi una riga per colono col
# nome e un tasto per lavoro, 1-4 o – per mai: clic per farlo dopo (1, 2, 3, 4, mai, di nuovo 1), clic destro per
# farlo prima. Governare solo il sovrano. Si rifà quando cambiano i coloni, il sovrano o la lingua
func refresh_priorities() -> void:
	var key := str(colonists) + str(ruler) + TranslationServer.get_locale() + str(colonists.map(stage_of))  # anche quando un bambino cresce
	if key != priorities_key:
		priorities_key = key
		for child in priority_grid.get_children():
			priority_grid.remove_child(child)
			child.queue_free()
		priority_grid.add_child(Control.new())  # sopra i nomi
		for w in Work.values():
			var icon := ui_icon(WORK_ICONS[w], Rect2(), Vector2(16, 16))
			icon.tooltip_text = "%s\n%s" % [named(Work, w, "work"), tr(WORK_INFO[w])]
			icon.mouse_filter = Control.MOUSE_FILTER_STOP  # il suggerimento
			priority_grid.add_child(icon)
		for c in colonists:
			var label := Label.new()
			label.text = c.first_name
			priority_grid.add_child(label)
			for w in Work.values():
				if (w == Work.GOVERN and c != ruler) or not can_do(c, w):  # governa solo il sovrano; i giovani non tutto
					priority_grid.add_child(Control.new())
					continue
				var cell := Button.new()
				cell.flat = true
				cell.focus_mode = Control.FOCUS_NONE
				cell.custom_minimum_size = Vector2(22, 22)
				cell.tooltip_text = "%s: %s" % [c.first_name, named(Work, w, "work")]
				cell.pressed.connect(step_priority.bind(c, w, 1))
				cell.gui_input.connect(priority_click.bind(c, w))
				priority_grid.add_child(cell)
	var i := Work.size() + 1  # dopo la riga delle icone
	for c in colonists:
		i += 1  # il nome
		for w in Work.values():
			var cell: Control = priority_grid.get_child(i)
			i += 1
			if cell is Button:
				var p := priority(c, w)
				cell.text = str(p) if p > 0 else "–"
				for state in ["font_color", "font_hover_color", "font_pressed_color"]:
					cell.add_theme_color_override(state, PRIORITY_COLORS[p])


# un passo nel giro delle priorità di `c` per il lavoro `w`: avanti (1 dopo, 4, mai, 1) o indietro
func step_priority(c: Colonist, w: Work, step: int) -> void:
	var cycle := range(1, PRIORITY_LEVELS + 1) + [0]
	set_priority(c, w, cycle[posmod(cycle.find(priority(c, w)) + step, cycle.size())])
	refresh_priorities()


func priority_click(event: InputEvent, c: Colonist, w: Work) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		step_priority(c, w, -1)


# finestra "Jobs": lavori in attesa per tipo (vedi find_work)
func job_list() -> String:
	var lines := PackedStringArray()
	if not chop_marks.is_empty():
		lines.append(tr("Chop trees: %d") % chop_marks.size())
	if not mine_marks.is_empty():
		lines.append(tr("Mine boulders: %d") % mine_marks.size())
	if not uproot_marks.is_empty():
		lines.append(tr("Uproot plants: %d") % uproot_marks.size())
	if not harvest_ready().is_empty():
		lines.append(tr("Harvest bushes: %d") % harvest_ready().size())
	if not farm_ready().is_empty():
		lines.append(tr_n("Tend the garden: %d plot", "Tend the garden: %d plots", farm_ready().size()) % farm_ready().size())
	if not manure_ready().is_empty() and MANURE_SOIL.keys().any(func(r): return not items[r].is_empty()):
		lines.append(tr_n("Fertilize the garden: %d plot", "Fertilize the garden: %d plots", manure_ready().size()) % manure_ready().size())
	if not fishable().is_empty():
		lines.append(tr("Fish spots: %d") % fishable().size())
	if not ice_ready().is_empty():
		lines.append(tr("Cut ice: %d spots") % ice_ready().size())
	var hunted := animals.filter(func(a): return a.marked)
	if not hunted.is_empty():
		lines.append(tr("Hunt animals: %d%s") % [hunted.size(), "" if colonists.any(has_bow) or available(Res.BOW) > 0 else tr(" (needs a bow)")])
	if meals_wanted() > 0 and not kitchen_fires().is_empty():
		lines.append(tr("Cook meals: %d") % meals_wanted())
	for r in RECIPES:  # solo quello che manca, che si sa fare e che ha una postazione
		if unlocked("makes", r[0]) and gear_wanted(r[0]) > 0 and not stations(r[1]).is_empty():
			lines.append(tr("Make %s: %d") % [item_name(r[0]), gear_wanted(r[0])])
	if not burning.is_empty():
		lines.append(tr("Put out the fire: %d tiles") % burning.size())
	if not roof_repairs().is_empty():
		lines.append(tr("Repair roofs: %d") % roof_repairs().size())
	for plans in [blueprints, furniture_plans]:  # prima le strutture (per casella), poi i mobili (per pezzo)
		var counts := {}  # "wall (wood)" -> quanti
		for plan in plans.values():
			var what := "%s (%s)" % [named(Build, plan[0]).to_lower(), item_name(plan[1])]
			counts[what] = counts.get(what, 0) + 1
		for what in counts:
			lines.append(tr("Build %s: %d") % [what, counts[what]])
	for res in Res.values():
		var piles: Array = items[res].keys().filter(func(cell): return not stockpile.has(cell))
		if not piles.is_empty() and not stockpile.is_empty():  # senza magazzino nessuno trasporta
			lines.append(tr_n("Haul %s: %d pile", "Haul %s: %d piles", piles.size()) % [item_name(res), piles.size()])
	return "\n".join(lines) if not lines.is_empty() else tr("Nothing to do")


# finestra "Resources": quanto c'è in tutti i magazzini insieme, solo le risorse presenti
func update_resources() -> void:
	var amounts := Res.values().map(stored)
	for res in Res.values():
		var row: Control = resources_list.get_child(res)
		row.visible = amounts[res] > 0
		row.get_child(-2).text = named(Res, res, "item")  # il nome, nella lingua di adesso
		row.get_child(-1).text = str(amounts[res])  # la quantità, in fondo alla riga
	$HUD/ResourcesPanel/Box/Empty.visible = amounts.max() == 0
	resources_panel.reset_size()  # si stringe se una risorsa finisce


func generate_map() -> void:
	var noise := ground_noise(randi())
	map_seed = noise.seed
	var lakes := FastNoiseLite.new()
	lakes.seed = noise.seed + 1
	lakes.frequency = 0.04
	for y in MAP_SIZE.y:  # per righe, così `trees` resta ordinato dall'alto in basso
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			if (cell - MAP_SIZE / 2).length() < 4:
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

	wild.seed = noise.seed + 3
	for kind in BEASTS:
		for i in BEASTS[kind]["start"]:
			spawn_animal(kind)
	if game_start:  # niente di costruito: le monete a terra nella radura, due caselle sotto i coloni
		drop(Res.GOLD, MAP_SIZE / 2 + Vector2i(0, 2), START_GOLD)
		var spots := []  # l'arma abbandonata: sul prato, né troppo vicino né troppo lontano dalla radura
		for cell in cells_in(Rect2i(MAP_SIZE / 2 - Vector2i.ONE * FOUND_WEAPON_REACH[1], Vector2i.ONE * FOUND_WEAPON_REACH[1] * 2)):
			var far := Vector2(cell - MAP_SIZE / 2).length()
			if far >= FOUND_WEAPON_REACH[0] and far <= FOUND_WEAPON_REACH[1] and can_build(cell, Build.FLOOR):
				spots.append(cell)
		if not spots.is_empty():
			drop(FOUND_WEAPONS.pick_random(), spots.pick_random(), 1)
	make_soil()
	gravel = rocks.duplicate()
	bake_ground(noise)


# il rumore della mappa (roccia, alberi, erba sassosa): lo stesso `from`, le stesse chiazze
func ground_noise(from: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = from
	noise.frequency = 0.08
	return noise


# Disegna il terreno una volta sola in un'unica immagine, che _draw mostra come una texture. Le varianti delle caselle
# sono a caso la prima volta, poi quelle di ground_cols; la roccia è quella di partenza (`gravel`): una partita
# caricata si rivede uguale, anche dove si è scavato.
# ponytail: si fa solo alla generazione; quando il terreno cambierà (scavi, ponti) ridisegnare le caselle toccate
func bake_ground(noise: FastNoiseLite) -> void:
	var sheet := GROUND.get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	var img := Image.create_empty(MAP_SIZE.x * TILE, MAP_SIZE.y * TILE, false, Image.FORMAT_RGBA8)
	var fresh_cols := ground_cols.size() != MAP_SIZE.x * MAP_SIZE.y
	if fresh_cols:
		ground_cols.resize(MAP_SIZE.x * MAP_SIZE.y)
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			var own := ground_of(cell, gravel)
			var row := Ground.STONY_GRASS if own == Ground.GRASS and noise.get_noise_2d(x, y) > 0.15 else own
			if fresh_cols:
				ground_cols[y * MAP_SIZE.x + x] = randi() % 4
			img.blit_rect(sheet, tile_rect(ground_cols[y * MAP_SIZE.x + x], row), cell * TILE)
			for i in 4:  # i vicini "più alti" sbordano su questa casella: lati, e angoli se nessun lato li copre già
				var side := edge_row(own, cell + EDGE_SIDES[i], gravel)
				if side >= 0:
					img.blend_rect(sheet, tile_rect(i, side), cell * TILE)
				var d: Vector2i = EDGE_CORNERS[i]
				var corner := edge_row(own, cell + d, gravel)
				if corner >= 0 and edge_row(own, cell + Vector2i(d.x, 0), gravel) != corner \
						and edge_row(own, cell + Vector2i(0, d.y), gravel) != corner:
					img.blend_rect(sheet, tile_rect(i, corner + 3), cell * TILE)
	ground_texture = ImageTexture.create_from_image(img)
	water_fx = ShaderMaterial.new()
	water_fx.shader = WATER_SHADER
	water_fx.set_shader_parameter("shallow", sheet.get_pixel(0, Ground.SHALLOW * TILE))  # colori base dell'acqua
	water_fx.set_shader_parameter("deep", sheet.get_pixel(0, Ground.DEEP * TILE))
	var sprite := Sprite2D.new()
	sprite.texture = ground_texture
	sprite.centered = false
	sprite.show_behind_parent = true  # sotto a tutto quello che disegna _draw
	sprite.material = water_fx
	add_child(sprite)


# `rock`: la roccia da guardare; quella di adesso, o per il terreno disegnato quella di partenza (`gravel`)
func ground_of(cell: Vector2i, rock := rocks) -> int:
	if water.has(cell):
		return water[cell]
	return Ground.GRAVEL if rock.has(cell) else Ground.GRASS


# Riga del bordo che la casella `next` disegna su una casella di terreno `own`, -1 se nessuno.
func edge_row(own: int, next: Vector2i, rock := rocks) -> int:
	if not astar.is_in_boundsv(next):
		return -1
	var other := ground_of(next, rock)
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
	if autosave_due:
		autosave_due = false
		autosave()
	toast.visible = Time.get_ticks_msec() < toast_until
	toast.modulate.a = clampf((toast_until - Time.get_ticks_msec()) / 500.0, 0.0, 1.0)  # sparisce nell'ultimo mezzo secondo
	stored_label.text = str(Res.values().map(stored).reduce(func(a, b): return a + b, 0))
	colonists_label.text = str(colony_size())  # anche chi è in spedizione: conta per il titolo
	beds_label.text = str(furniture.values().filter(func(plan): return plan[0] in BEDS).size())  # solo quelli finiti
	splendor_label.text = str(colony_splendor())
	confirm.disabled = draft.is_empty() and furniture_draft.is_empty()
	if jobs_panel.visible:
		refresh_priorities()
		jobs_list.text = job_list()
	if resources_panel.visible:
		update_resources()
	if $HUD/BoardPanel.visible:
		fill_board()
	if $HUD/CensusPanel.visible:
		fill_census()
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
	for name in SPEEDS:  # premuto quello della velocità attuale, anche cambiata coi tasti
		get_node("HUD/TopBar/Row/" + name).set_pressed_no_signal(Engine.time_scale == SPEEDS[name])
	var t := fmod(clock, 1.0)
	var wolves := animals.filter(hostile).size()
	info_label.text = (tr("WOLVES: %d    ") % wolves if wolves > 0 else "") \
		+ (tr("EXPEDITION: %d    ") % expeditions.size() if not expeditions.is_empty() else "") + tr("%s, %s  %02d:%02d    Order: %s") \
		% [tr(SEASONS[season(int(clock))]), date(int(clock)), int(t * 24), int(t * 1440) % 60, named(Order, order)]
	sky.color = sky_colors.sample(t)
	queue_redraw()
	flat.queue_redraw()
	casters.queue_redraw()
	lights_canvas.queue_redraw()
	if lens.visible:
		lens_canvas.queue_redraw()
		place_owners()
	heat_lens.visible = $HUD/Tools/Row/HeatLens.button_pressed or previewing_heat()
	if heat_lens.visible:
		heat_canvas.queue_redraw()
	if soil_lens.visible:
		soil_canvas.queue_redraw()
	if plan_panel.visible:  # la linea di oggi va avanti
		plan_chart.queue_redraw()


func tick(delta: float) -> void:
	clock += delta / DAY_LENGTH
	spoil(delta / DAY_LENGTH)
	burn(delta)
	var splendor := colony_splendor()
	authority += (AUTHORITY_DAILY * (rank + 1) + floorf(splendor / float(SPLENDOR_PER_AUTHORITY))
		+ (colonists.size() if enacted.has(Law.TRIBUTE) else 0)) * delta / DAY_LENGTH
	while rank < TITLES.size() - 1 and splendor >= TITLES[rank + 1]["splendor"] and colony_size() >= TITLES[rank + 1]["colonists"]:
		rise()
	if int(clock) != today:
		today = int(clock)
		new_day()
	if int(clock * 24) != hour:
		hour = int(clock * 24)
		new_hour()
		autosave_due = autosave_due or hour % 24 == AUTOSAVE_HOUR
	for c in people():
		if c.died == 0.0:  # morto durante il giro
			update_colonist(c, delta)
	for arrow in arrows.duplicate():  # una freccia può abbattere un animale
		fly(arrow, delta)
	update_guests()
	update_suitors()
	update_wanderers()
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
		Job.CHOP, Job.MINE, Job.HARVEST, Job.FISH, Job.CUT_ICE:  # raccolta, vedi GATHER: un colpo ogni gather_time, il raccolto cade ai piedi
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
					add_soil(c.target, SOIL_HUMUS)  # l'humus del bosco
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
		Job.FARM:  # accanto alla casella dell'orto (target): raccoglie quello che è maturo, o semina
			face(c, center(c.target) - c.pos)
			c.work_left -= delta
			if c.work_left > 0:
				return
			var crop := crop_of(c.target)
			if ripe(c.target):
				var here := cell_of(c.pos)
				var amount := crop_yield(c.target, crop)
				if CROP_RES[crop] >= 0:  # il sovescio non si raccoglie: si interra
					produce(CROP_RES[crop], here, amount)
				harvested(c.target, crop, amount)
				learn_soil(c, c.target)
				c.xp[Skill.GATHERING] += 1
				end_job(c)
				if CROP_RES[crop] >= 0:
					try_haul(c, CROP_RES[crop], [here])  # porta subito via il raccolto
				return
			if sowable(c.target):
				manured.erase(c.target)
				slot_done[c.target] = [year_of(today), next_slot(c.target)]
				garden[c.target] = clock
				sown[c.target] = crop
				learn_soil(c, c.target)
				c.xp[Skill.GATHERING] += 1
			end_job(c)
		Job.FERTILIZE:  # come riparare: al mucchio prende un concime (carry_res), poi accanto alla casella (target) lo sparge
			if garden.get(c.target, 0.0) >= 0 or manured.has(c.target):
				quit_job(c)  # seminata intanto, o già concimata, o non è più orto
				return
			if c.carrying == 0:
				var here := cell_of(c.pos)
				if items[c.carry_res].get(here, 0) < 1:
					end_job(c)
					return
				add_item(c.carry_res, here, -1)
				reserved.erase(here)
				c.carrying = 1
				c.path = path_of(c, here, c.dest)
				if c.path.is_empty():
					quit_job(c)
				return
			face(c, center(c.target) - c.pos)
			c.work_left = maxf(c.work_left - delta, 0.0)
			if c.work_left == 0:
				add_soil(c.target, MANURE_SOIL[c.carry_res])
				manured[c.target] = true
				c.carrying = 0
				c.xp[Skill.GATHERING] += 1
				end_job(c)
		Job.UPROOT:
			face(c, center(c.target) - c.pos)
			c.work_left -= delta
			if c.work_left <= 0:
				bushes.erase(c.target)
				flax.erase(c.target)
				weeds.erase(c.target)
				uproot_marks.erase(c.target)
				harvest_marks.erase(c.target)
				if composting():  # al cumulo del compost
					drop(Res.ROT, c.target, 1)
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
				var cost: int = missing(c.job, c.target).get(c.carry_res, 0)
				if cost == 0 or items[c.carry_res].get(here, 0) < cost:  # già portato da un altro, o il mucchio non basta
					end_job(c)
					return
				add_item(c.carry_res, here, -cost)
				reserved.erase(here)
				c.carrying = cost
				c.path = path_of(c, here, c.dest)
				if c.path.is_empty():  # cantiere in una stanza dove nel frattempo non entra più: rimette giù il materiale
					quit_job(c)
				return
			if missing(c.job, c.target).size() > 1:  # manca altro materiale: lascia questo al cantiere, poi si vedrà
				var key := [c.job, c.target]
				delivered[key] = delivered.get(key, {}).merged({c.carry_res: c.carrying})
				c.carrying = 0
				end_job(c)
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
				delivered.erase([c.job, c.target])
				c.carrying = 0
				c.xp[Skill.CONSTRUCTION] += 1
				end_job(c)
		Job.DOUSE:  # all'acqua riempie il secchio, poi accanto al fuoco (target) lo getta
			if not burning.has(c.target):
				end_job(c)  # spento, o bruciato del tutto: find_job ne cerca un altro
				return
			c.work_left = maxf(c.work_left - delta, 0.0)
			if c.work_left > 0:
				if c.bucket:
					face(c, center(c.target) - c.pos)
				return
			c.work_left = BUCKET_TIME
			if not c.bucket:
				c.bucket = true
				c.path = path_of(c, cell_of(c.pos), c.dest)
				if c.path.is_empty():
					end_job(c)
				return
			c.bucket = false
			burning[c.target] -= DOUSE_HOURS
			if burning[c.target] <= 0:
				burning.erase(c.target)
				wear[c.target] = wear.get(c.target, 0.0) + FIRE_SCAR
				if burning.is_empty():
					note(tr("%s: the fire is out.") % date(today))
			end_job(c)
		Job.REPAIR:  # come BUILD: al mucchio prende il materiale (carry_res), poi accanto alla casella (target) la ripara
			if wear.get(c.target, 0.0) < WORN or not roofed.has(c.target):
				quit_job(c)  # già riparata, o la stanza non c'è più
				return
			if c.carrying == 0:
				var here := cell_of(c.pos)
				if items[c.carry_res].get(here, 0) < REPAIR_COST:
					end_job(c)
					return
				add_item(c.carry_res, here, -REPAIR_COST)
				reserved.erase(here)
				c.carrying = REPAIR_COST
				c.path = path_of(c, here, c.dest)
				if c.path.is_empty():
					quit_job(c)
				return
			face(c, center(c.target) - c.pos)
			c.work_left = maxf(c.work_left - delta, 0.0)
			if c.work_left == 0:
				if holed(c.target):
					roof_stamp += 1
				wear.erase(c.target)
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
			if role(furniture.get(c.target, [-1])[0]) != Build.CAMPFIRE or not kitchen_fires().has(c.target):
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
		Job.OATH:  # davanti al trono, in ginocchio: finita l'ora, giura
			c.work_left -= delta
			if c.work_left <= 0:
				end_job(c)
				swear(c)
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
# Da svegli freddo e pioggia fanno calare il comfort (vedi weather_comfort): un tetto e un fuoco lo salvano.
# La felicità segue la media degli altri, più le condizioni
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
		c.needs[Need.COMFORT] += DISCOMFORT_DROP * weather_comfort(cell_of(c.pos), gear_sum(c, "armor")) * day
	if c.job == Job.RELAX:
		c.needs[Need.FUN] += FUN_GAIN * day
	elif not asleep:
		c.needs[Need.FUN] -= FUN_DROP * fx(c, "fun", 1.0) * day
	if fx(c, "fun", 1.0) == 0:  # non gli serve: sempre a posto
		c.needs[Need.FUN] = NEED_MAX
	if c.job not in [Job.NONE, Job.SLEEP, Job.EAT, Job.RELAX, Job.TANTRUM, Job.PROTEST, Job.OATH]:  # lavori, ma anche combattere e scappare
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


# gradi in più per chi dorme in un letto con le tende (BED_WARMTH)
func bed_warmth(c: Colonist) -> float:
	if not in_bed(c):
		return 0.0
	var beds := pieces_at(furniture, cell_of(c.pos)).filter(func(o): return furniture[o][0] in BEDS)
	return BED_WARMTH.get(furniture[beds[0]][0], 0.0)


func in_bed(c: Colonist) -> bool:
	return c.job == Job.SLEEP and not pieces_at(furniture, cell_of(c.pos)).filter(func(o): return furniture[o][0] in BEDS).is_empty()


# Splendore della colonia: la somma delle decorazioni finite (SPLENDOR), ovunque stiano, e degli avventurieri famosi.
func colony_splendor() -> int:
	return (PALACE[1] if researched.has(Tech.PALACE) and rooms.any(func(r): return r.kind == RoomKind.THRONE_ROOM) else 0) \
		+ furniture.values().map(func(plan): return SPLENDOR.get(plan[0], 0)).reduce(func(a, b): return a + b, 0) \
		+ people().reduce(func(n, g): return n + gift(g, "splendor", 0), 0)  # i famosi: avventurieri, anche rimasti


# Comfort dove sta il colono: i mobili della stanza, in proporzione se ha meno di ROOM_SPACE caselle a testa (fuori 0),
# meno freddo e pioggia (vedi weather_comfort), con la sua protezione addosso.
# ponytail: "a testa" conta chi è nella stanza in quel momento, sveglio o no
func comfort_of(c: Colonist) -> int:
	var here := cell_of(c.pos)
	var weather := weather_comfort(here, gear_sum(c, "armor") + bed_warmth(c))
	for room in rooms:
		if room.cells.has(here):
			var people := colonists.filter(func(o): return room.cells.has(cell_of(o.pos))).size()
			return floori(furnishing(room) * minf(1.0, float(room.cells.size()) / people / ROOM_SPACE)) + weather
	return weather


# comfort per chi lavora nella stanza: i mobili, meno il freddo che ci fa
func room_comfort(room: Room) -> int:
	return furnishing(room) + weather_comfort(room.cells.keys()[0])


# Comfort tolto (0 o meno) da freddo e pioggia in `cell` a chi ha `warmth` punti di protezione addosso (vedi COLD_FROM)
func weather_comfort(cell: Vector2i, warmth := 0.0) -> int:
	var cold := cold_malus(temperature_at(cell) + warmth)
	var wet := 0 if sheltered(cell) else roundi(WET_COMFORT * atmosphere.raining())
	return -(cold + wet)


# Gradi in `cell`: fuori come dice il tempo (vedi atmosphere.temperature). Sotto un tetto verso la temperatura della
# stanza (room_base) di quanto isolano i muri (insulation), più il calore dei fuochi (heat_sources). Senza clima (nelle
# prove) sempre ROOM_TEMP. `memo` (stanza -> gradi) risparmia i conti a chi chiede tante caselle insieme
func temperature_at(cell: Vector2i, memo := {}) -> float:
	var t: float = atmosphere.temperature()
	if not atmosphere.climate:
		return ROOM_TEMP
	if not sheltered(cell):
		return t
	var room := room_at(cell)
	if room == null:  # un muro o una porta sotto il tetto
		return lerpf(t, ROOM_TEMP, WALL_INSULATION[Res.WOOD])
	if not memo.has(room):
		memo[room] = room_temperature(room)
	return memo[room]


# i gradi della stanza sotto il suo tetto: verso room_base di quanto isola, più i fuochi
func room_temperature(room: Room) -> float:
	if not atmosphere.climate:
		return ROOM_TEMP
	var t := lerpf(atmosphere.temperature(), room_base(room), insulation(room))
	for source in heat_sources(room):
		t += source[1]
	return t


# punti di comfort che il freddo toglie a `t` gradi: uno ogni COLD_STEP sotto COLD_FROM (vedi weather_comfort)
func cold_malus(t: float) -> int:
	return maxi(0, floori((COLD_FROM - t) / COLD_STEP))


# la temperatura verso cui va la stanza: ROOM_TEMP dove si vive, STORE_TEMP nei magazzini e nelle dispense
func room_base(room: Room) -> float:
	if room.kind == RoomKind.ICEHOUSE and room_ice(room) > 0:
		return ICE_TEMP
	return STORE_TEMP if room.kind in STORES else ROOM_TEMP


# blocchi di ghiaccio nelle fosse della stanza
func room_ice(room: Room) -> int:
	var sum := 0
	for cell in pit_cells():
		if room.cells.has(cell):
			sum += items[Res.ICE].get(cell, 0)
	return sum


# caselle delle fosse del ghiaccio dentro le ghiacciaie: solo lì va il ghiaccio (vedi dest_cells)
func pit_cells() -> Dictionary:
	var cells := {}
	for origin in furniture:
		if furniture[origin][0] == Build.ICE_PIT and room_at(origin) != null and room_at(origin).kind == RoomKind.ICEHOUSE:
			for k in cells_in(piece_rect(origin, furniture[origin])):
				cells[k] = true
	return cells


# Un'ora della ghiacciaia: il ghiaccio si scioglie col caldo che entra (vedi ICE_MELT) e dai buchi nel tetto
func melt_ice() -> void:
	var pits := pit_cells()
	for room in rooms:
		if room.kind != RoomKind.ICEHOUSE:
			continue
		var piles := pits.keys().filter(func(k): return room.cells.has(k) and items[Res.ICE].has(k))
		if piles.is_empty():
			room.thaw = 0.0
			continue
		var outside: float = atmosphere.temperature() if atmosphere.climate else ROOM_TEMP
		var holes := room.cells.keys().filter(holed).size()
		room.thaw += (maxf(outside, 0.0) * (1.0 - insulation(room)) * ICE_MELT + holes * ICE_HOLE_MELT) / 24.0
		while room.thaw >= 1.0 and not piles.is_empty():
			add_item(Res.ICE, piles[0], -1)
			room.thaw -= 1.0
			if not items[Res.ICE].has(piles[0]):
				piles.pop_front()


# posto libero nelle fosse, meno il ghiaccio già tagliato che aspetta di esserci portato
func ice_space() -> int:
	var room_left := 0
	var pits := pit_cells()
	for k in pits:
		room_left += STACK_MAX[Res.ICE] - items[Res.ICE].get(k, 0)
	return room_left - (total(Res.ICE) - pits.keys().reduce(func(n, k): return n + items[Res.ICE].get(k, 0), 0))


# caselle dell'orto dove c'è da fare: mature da raccogliere, o vuote da seminare secondo il piano (sowable)
func farm_ready() -> Array:
	return garden.keys().filter(func(k): return sowable(k) or ripe(k))


# caselle d'orto da concimare: vuote, non ancora concimate per la prossima semina, in un campo che si concima, con la
# prossima coltura del piano entro MANURE_AHEAD giorni (o già arrivata)
func manure_ready() -> Array:
	if not researched.has(Tech.MANURING):
		return []
	var day := clock - year_start()
	return garden.keys().filter(func(k):
		if garden[k] >= 0 or manured.has(k) or no_manure.has(k):
			return false
		var i := next_slot(k)
		return i >= 0 and slots_of(k, year_of(today))[i][1] - day <= MANURE_AHEAD)


# Concimare: accanto alla casella da concimare più vicina, passando dal mucchio di concime più vicino (prima il compost,
# poi la cenere). false se non ce n'è
func try_fertilize(c: Colonist) -> bool:
	var plots := manure_ready().filter(func(k): return is_free(k))
	if plots.is_empty():
		return false
	var stands := {}
	for k in plots:
		add_stands(stands, [k], k, SIDES)
	var path := path_to_nearest(c, stands.keys())
	if path.is_empty():
		return false
	for res in MANURE_SOIL:
		var to_pile := path_to_nearest(c, items[res].keys().filter(func(k): return is_free(k)))
		if not to_pile.is_empty():
			start_job(c, Job.FERTILIZE, to_pile, stands[path.back()], MANURE_TIME * skill_time(c.skills[Skill.GATHERING]) * work_factor(c, Job.FERTILIZE))
			c.dest = path.back()
			c.carry_res = res
			reserved[to_pile.back()] = c
			return true
	return false


# quello che cresce in `cell` è maturo
func ripe(cell: Vector2i) -> bool:
	return garden.get(cell, -1.0) >= 0 and crop_of(cell) >= 0 and clock - garden[cell] >= CROP_DAYS[crop_of(cell)]


# Raccolto `amount` di `crop` in `cell`: la terra ne paga il prezzo (CROP_SOIL); si segnano gli anni di fila con la
# stessa coltura, l'ultimo raccolto per il cartello e il bilancio dell'anno; la casella torna da seminare
func harvested(cell: Vector2i, crop: Crop, amount: int) -> void:
	var y := year_of(today)
	tired[cell] = [crop, tired_count(cell, crop)]
	add_soil(cell, CROP_SOIL[crop])
	last_yield[cell] = [y, crop, amount]
	if CROP_YIELD[crop] > 0:  # nel bilancio solo quello che si mangia
		var book: Dictionary = harvests.get(y, {})
		var sum: Array = book.get(crop, [0, 0])
		book[crop] = [sum[0] + amount, sum[1] + 1]
		harvests[y] = book
	garden[cell] = -1.0
	sown.erase(cell)


# quante volte di fila sarebbe `crop` in `cell`, raccogliendolo adesso (vedi TIRED)
func tired_count(cell: Vector2i, crop: Crop) -> int:
	var rec: Array = tired.get(cell, [-1, 0])
	return rec[1] + 1 if rec[0] == crop else 1


# quanti ne dà `crop` in `cell`: la base per 0,4 + fertilità/100, meno la terra stanca; almeno uno
func crop_yield(cell: Vector2i, crop: Crop) -> int:
	if CROP_YIELD[crop] == 0:  # il sovescio: si interra
		return 0
	var f: float = (0.4 + soil_at(cell) / 100.0) * TIRED[mini(tired_count(cell, crop), TIRED.size()) - 1]
	return maxi(1, roundi(CROP_YIELD[crop] * f))


# chi è bravo a raccogliere (SOIL_EYE) lavorando una casella ne riconosce la terra
func learn_soil(c: Colonist, cell: Vector2i) -> void:
	if c.skills[Skill.GATHERING] >= SOIL_EYE:
		soil_known[cell] = true


# Fertilità di partenza di ogni casella: il rumore della mappa tra SOIL_RANGE, più l'acqua vicina, meno la roccia
func make_soil() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = map_seed + 5
	noise.frequency = 0.06
	var wet := {}
	for w in water:
		for k in cells_in(Rect2i(w - Vector2i(3, 3), Vector2i(7, 7))):
			wet[k] = true
	soil.resize(MAP_SIZE.x * MAP_SIZE.y)
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			var f := lerpf(SOIL_RANGE[0], SOIL_RANGE[1], clampf(0.5 + noise.get_noise_2d(x, y), 0.0, 1.0))
			if wet.has(cell):
				f += SOIL_WATER
			if cells_in(Rect2i(cell - Vector2i.ONE, Vector2i(3, 3))).any(func(k): return rocks.has(k) and k != cell):
				f += SOIL_ROCK
			soil[y * MAP_SIZE.x + x] = clampi(roundi(f), 0, 100)
	soil_year_ago = soil.duplicate()


func soil_at(cell: Vector2i) -> int:
	return soil[cell.y * MAP_SIZE.x + cell.x]


func add_soil(cell: Vector2i, amount: int) -> void:
	var i := cell.y * MAP_SIZE.x + cell.x
	soil[i] = clampi(soil[i] + amount, 0, 100)


# l'anno del giorno `day`, da 0
@warning_ignore("integer_division")
func year_of(day: int) -> int:
	return day / YEAR_DAYS


# il piano di `cell` (vedi plans); senza, DEFAULT_PLAN
func plan_of(cell: Vector2i) -> Array:
	return plans.get(cell, [0, DEFAULT_PLAN])


# l'anno del ciclo del piano di `cell` nell'anno `y`
func plan_index(cell: Vector2i, y: int) -> int:
	var plan := plan_of(cell)
	return posmod(y - plan[0], plan[1].size())


# le colture del piano di `cell` nell'anno `y`: [[Crop, giorno dell'anno], ...], in ordine
func slots_of(cell: Vector2i, y: int) -> Array:
	return plan_of(cell)[1][plan_index(cell, y)]


# il primo giorno d'inverno, contato dall'inizio dell'anno (il Capodanno è il giorno 0)
func winter_day() -> int:
	return 1 + WINTER * SEASON_DAYS


# il Capodanno dell'anno di oggi, come `clock`
func year_start() -> int:
	return today - posmod(today, YEAR_DAYS)


# la prossima coltura del piano da seminare in `cell` quest'anno, indice in slots_of; -1 se non ce n'è più. Quelle che
# non farebbero più in tempo a maturare prima dell'inverno si saltano
func next_slot(cell: Vector2i) -> int:
	var y := year_of(today)
	var slots := slots_of(cell, y)
	var done: Array = slot_done.get(cell, [-1, -1])
	var i: int = done[1] + 1 if done[0] == y else 0
	while i < slots.size():
		if year_start() + winter_day() - clock >= CROP_DAYS[slots[i][0]]:
			return i
		i += 1
	return -1


# in `cell` si semina adesso: è libera, la sua prossima coltura del piano è arrivata al suo giorno e la terra è tiepida
func sowable(cell: Vector2i) -> bool:
	var i := next_slot(cell)
	if garden.get(cell, 0.0) >= 0 or i < 0:
		return false
	var slot: Array = slots_of(cell, year_of(today))[i]
	return clock - year_start() >= slot[1] and sowing_season(slot[0])


# dove andrebbe una coltura cliccando il giorno `day` fra le colture `slots`: [giorno d'inizio, giorno entro cui deve
# finire]. Attaccata a quella prima (o da SOW_FROM), prima di quella dopo e dell'inverno
func slot_room(slots: Array, day: float) -> Array:
	var start := SOW_FROM
	var limit := winter_day()
	for slot in slots:
		if slot[1] <= day:
			start = maxi(start, slot[1] + int(CROP_DAYS[slot[0]]))
		else:
			limit = mini(limit, slot[1])
	return [start, limit]


# il nome di `day` nell'anno, senza l'anno: "3 Thaw", la festa, il Capodanno
@warning_ignore("integer_division")
func day_name(day: int) -> String:
	var d := posmod(day, YEAR_DAYS) - 1
	var r := posmod(d, SEASON_DAYS)
	return tr(NEW_YEAR) if d < 0 else tr(FEASTS[d / SEASON_DAYS]) if feast(day) \
		else "%d %s" % [r % MONTH_DAYS + 1, tr(MONTHS[d / SEASON_DAYS * 3 + r / MONTH_DAYS])]


# si semina `crop` se la terra è tiepida (SOW_TEMP) e se matura prima dell'inverno: fuori dall'inverno, e almeno
# CROP_DAYS giorni prima del suo inizio
func sowing_season(crop: Crop) -> bool:
	var winter := today - posmod(today, YEAR_DAYS) + 1 + WINTER * SEASON_DAYS  # il primo giorno d'inverno di quest'anno
	var warm: bool = not atmosphere.climate or atmosphere.mean_temperature() >= SOW_TEMP
	return warm and season(today) != WINTER and winter - clock >= CROP_DAYS[crop]


# sul prato libero, fuori dalle stanze: ci si può fare l'orto
func can_plant(cell: Vector2i) -> bool:
	return not garden.has(cell) and can_build(cell, Build.WALL) and ground_of(cell) == Ground.GRASS and not roofed.has(cell)


# quello che cresce in `cell`, o la prossima coltura del piano da seminarci; -1 se quest'anno non c'è più niente
func crop_of(cell: Vector2i) -> int:
	if sown.has(cell):
		return sown[cell]
	var i := next_slot(cell)
	return slots_of(cell, year_of(today))[i][0] if i >= 0 else -1


# I campi: le caselle d'orto che si toccano. Il cartello sta nella più in alto a sinistra; le caselle senza piano
# prendono quello del loro campo
func update_fields() -> void:
	field_signs.clear()
	var seen := {}
	for cell in garden:
		if seen.has(cell):
			continue
		var field := field_of(cell)
		for k in field:
			seen[k] = true
		field_signs.append(field.min())
		var planned := field.filter(func(k): return plans.has(k))
		if not planned.is_empty():
			var plan: Array = plans[planned.min()]
			for k in field:
				if not plans.has(k):
					plans[k] = plan.duplicate(true)
		if field.any(func(k): return no_manure.has(k)):
			for k in field:
				no_manure[k] = true
	field_signs.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))


# "Field 3": i campi contati dall'alto in basso (vedi update_fields)
func field_name(sign_cell: Vector2i) -> String:
	return tr("Field %d") % (field_signs.find(sign_cell) + 1)


# le caselle del campo di `cell`
func field_of(cell: Vector2i) -> Array:
	var out := {}
	var todo := [cell]
	while not todo.is_empty():
		var k: Vector2i = todo.pop_back()
		if out.has(k) or not garden.has(k):
			continue
		out[k] = true
		for side in SIDES:
			todo.append(k + side)
	return out.keys()


# acqua segnata dove tagliare il ghiaccio: solo se è gelata e se nelle fosse c'è posto
func ice_ready() -> Array:
	if not atmosphere.frozen or ice_space() <= 0:
		return []
	return ice_marks.keys()


# Quanto isola la stanza, 0..INSULATION_MAX: la media di quello che la chiude, casella per casella (muri per materiale,
# porte come legno, roccia). Una stanza fatta solo di dati, senza muri attorno, come il legno
func insulation(room: Room) -> float:
	var walls := room_walls(room)
	if walls.is_empty():
		return WALL_INSULATION[Res.WOOD]
	var sum := 0.0
	for k in walls:
		sum += walls[k]
	var pieces := {}  # pelli, portiere, arazzi nella stanza
	for origin in furniture:
		if INSULATES.has(furniture[origin][0]) and room.cells.has(origin):
			pieces[furniture[origin][0]] = pieces.get(furniture[origin][0], 0) + 1
	var extra := 0.0
	for kind in pieces:
		extra += INSULATES[kind][0] * mini(pieces[kind], INSULATES[kind][1])
	return minf(sum / walls.size() + extra, INSULATION_MAX)


# caselle attorno alla stanza (di lato) che la chiudono -> quanto isolano
func room_walls(room: Room) -> Dictionary:
	var walls := {}
	for cell in room.cells:
		for side in SIDES:
			var k: Vector2i = cell + side
			if room.cells.has(k) or walls.has(k):
				continue
			var b: Array = built.get(k, [-1, -1])
			if b[0] == Build.WALL:
				walls[k] = PLASTER_INSULATION if plastered.has(k) and b[1] == Res.WOOD else WALL_INSULATION[b[1]]
			elif b[0] == Build.DOOR:
				walls[k] = WALL_INSULATION[Res.WOOD]
			elif rocks.has(k):
				walls[k] = ROCK_INSULATION
	return walls


# I fuochi che scaldano la stanza: [mobile, gradi], quelli dentro per intero, quelli dietro un muro (vedi heat_through)
# per THROUGH_WALL
func heat_sources(room: Room) -> Array:
	var out := []
	for origin in furniture:
		var kind: int = furniture[origin][0]
		if not HEAT.has(kind):
			continue
		if room.cells.has(origin):
			out.append([origin, HEAT[kind]])
		elif THROUGH.has(kind) and heat_through(origin) == room:
			out.append([origin, HEAT[kind] * THROUGH[kind]])
	if atmosphere.climate and atmosphere.temperature() > FOUNTAIN_FROM:  # d'estate la fontana rinfresca
		for origin in furniture:
			if furniture[origin][0] == Build.FOUNTAIN and room.cells.has(origin):
				out.append([origin, -FOUNTAIN_COOL])
	return out


# La stanza dall'altra parte del muro di legno alle spalle del fuoco in `origin` (vedi BACKS), che ne prende una parte
# del calore (THROUGH); null se dietro non c'è un muro di legno (per la stufa a olle anche di pietra) con una stanza
# diversa oltre
func heat_through(origin: Vector2i) -> Room:
	var p := passage(origin, furniture[origin])
	return p[1] if not p.is_empty() and p[2] else null


# Il muro alle spalle del mobile `plan` in `origin`, se oltre c'è un'altra stanza: [muro, stanza oltre, il calore passa
# (il muro è di legno)]; [] se dietro non c'è un muro o oltre non c'è una stanza diversa
func passage(origin: Vector2i, plan: Array) -> Array:
	var back := back_of(plan)
	var wall: Array = built.get(origin + back, [-1, -1])
	var other := room_at(origin + back * 2)
	if wall[0] != Build.WALL or other == null or other == room_at(origin):
		return []
	return [origin + back, other, wall[1] == Res.WOOD or plan[0] in THROUGH_STONE]


# la direzione delle spalle del mobile `plan` (girato di plan[2] quarti)
func back_of(plan: Array) -> Vector2i:
	return BACKS[plan[2] if plan.size() > 2 else 0]


# il mobile `plan` in `origin` ha alle spalle quello che vuole (AGAINST), costruito o in progetto? Gli altri sempre
func backed(origin: Vector2i, plan: Array) -> bool:
	if not AGAINST.has(plan[0]):
		return true
	var behind: Vector2i = origin + back_of(plan)
	return [built, blueprints, draft].any(func(l): return l.get(behind, [-1])[0] in AGAINST[plan[0]])


# il mobile `plan` sta in `origin`: caselle libere (can_build) e, se va addossato, quello che vuole alle spalle
func piece_fits(origin: Vector2i, plan: Array) -> bool:
	return cells_in(piece_rect(origin, plan)).all(func(k): return can_build(k, plan[0])) and backed(origin, plan)


# Il conto dei gradi della stanza, una riga per voce: fuori, i muri, i fuochi (quelli di un'altra stanza col suo nome),
# il totale. Per il cartello e la lente del calore
func heat_lines(room: Room) -> Array:
	var outside: float = atmosphere.temperature() if atmosphere.climate else ROOM_TEMP
	var lines := [tr("Outside: %d °C") % roundi(outside),
		tr("Walls keep %d%% toward %d °C") % [roundi(insulation(room) * 100), roundi(room_base(room))]]
	for source in heat_sources(room):
		var from := room_at(source[0])
		var name := named(Build, furniture[source[0]][0])
		lines.append(("%s: %s%s °C" % [name if from == room or from == null else tr("%s of %s") % [name, from.name],
			"+" if source[1] >= 0 else "−", str(snappedf(absf(source[1]), 0.5)).trim_suffix(".0")]))
	lines.append(tr("Total: %d °C") % roundi(room_temperature(room)))
	return lines


# la stanza può tenere il ghiaccio: chiusa solo da muri di pietra (COLD_WALLS), roccia e porte, senza fuochi dentro
func cold_room(room: Room) -> bool:
	for k in room_walls(room):
		var b: Array = built.get(k, [-1, -1])
		if b[0] == Build.WALL and b[1] not in COLD_WALLS:
			return false
	return not furniture.keys().any(func(o): return HEAT.has(furniture[o][0]) and room.cells.has(o))


# il tipo che il mobile fa le veci di (ROLE), o se stesso
func role(kind: int) -> int:
	return ROLE.get(kind, kind)


# dentro una stanza o sotto il suo tetto (muri e porte), dove il tetto non ha un buco
func sheltered(cell: Vector2i) -> bool:
	return (roofed.has(cell) or room_at(cell) != null) and not holed(cell)


# 0-COMFORT_MAX: i mobili dentro la stanza, per pezzo, e il pavimento, per la parte di stanza che copre; per materiale
# ponytail: scorre mobili e caselle a ogni domanda (anche per ogni colono che dorme, a ogni tick); tenerlo nella Room
# e ricalcolarlo quando cambiano mobili o pavimenti se le stanze diventano tante
func furnishing(room: Room) -> int:
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
	if kind == RoomKind.ICEHOUSE and not cold_room(room):
		return false
	var needs: Dictionary = ROOM_NEEDS.get(kind, {})
	var inside: Array = furniture.keys().filter(func(o): return room.cells.has(o)) \
		.map(func(o): return role(furniture[o][0]))
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
	if c.oath and try_oath(c):  # chi resta, col giuramento: prima di tutto al trono
		return
	if not visitor(c) and try_douse(c):  # un tetto brucia: tutti col secchio (i coloni)
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
	if visitor(c):  # avventurieri, pretendenti e viandanti non lavorano: aspettano svagandosi
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


# Svago per `hours` ore: attorno a un fuoco da campo (o a un focolare) o a un fantoccio libero (il più vicino dove può arrivare), se no
# a passeggio lì vicino. Al fantoccio si allena: colpi, ed esperienza in mischia (vedi Job.RELAX). Con la milizia la
# prima ora libera del giorno è al fantoccio, se ce n'è uno. Il divertimento sale (vedi update_needs); finito,
# find_job decide di nuovo
func relax(c: Colonist, hours := RELAX_HOURS) -> void:
	var spots := {}  # casella dove stare -> fantoccio, o la casella stessa (fuoco da campo)
	var drill := enacted.has(Law.MILITIA) and c.drilled != today
	for origin in furniture:
		if role(furniture[origin][0]) == Build.CAMPFIRE and not drill:
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


# Avvia il lavoro da fare per primo secondo la tabella delle priorità (vedi Work): prima di tutto l'equipaggiamento; poi
# chi lavora in una sala del trono o in uno studio (scelto dal cartello) ci governa e ci studia; poi i lavori dalla
# priorità 1 alla PRIORITY_LEVELS, a pari priorità nell'ordine di Work, e di ognuno il più vicino. false se non ce n'è
func find_work(c: Colonist) -> bool:
	if c == ruler and enacted.has(Law.COURT):  # a corte il sovrano governa e basta
		return try_equip(c) or try_seat(c, Build.THRONE, false)
	if routines and holiday():  # riposo festivo, festa del raccolto: si cucina e basta
		return try_equip(c) or (priority(c, Work.COOK) > 0 and try_cook(c))
	if try_equip(c) or (priority(c, Work.GOVERN) > 0 and try_seat(c, Build.THRONE, true)) \
			or (priority(c, Work.STUDY) > 0 and try_seat(c, Build.DESK, true)):
		return true
	for level in range(1, PRIORITY_LEVELS + 1):
		for w in Work.values():
			if priority(c, w) == level and try_work_kind(c, w):
				return true
	return false


# la priorità di `c` per il lavoro `w`: 1 (prima) - PRIORITY_LEVELS, 0 mai (anche quando è troppo giovane, vedi can_do)
func priority(c: Colonist, w: Work) -> int:
	if not can_do(c, w):
		return 0
	return c.priorities[w] if w < c.priorities.size() else PRIORITY_DEFAULT


# 0 bambino, 1 ragazzo, 2 adulto (i neonati non sono coloni: stanno in `babies`)
func stage_of(c: Colonist) -> int:
	var years := age_of(c)
	return 0 if years < YOUTH_AGE else (1 if years < ADULT else 2)


# `c` ha l'età per il lavoro `w`: i bambini solo CHILD_WORK, i ragazzi tutto tranne YOUTH_BANNED
func can_do(c: Colonist, w: Work) -> bool:
	var years := age_of(c)
	return w in CHILD_WORK if years < YOUTH_AGE else (w not in YOUTH_BANNED if years < ADULT else true)


func set_priority(c: Colonist, w: Work, level: int) -> void:
	while c.priorities.size() < Work.size():
		c.priorities.append(PRIORITY_DEFAULT)
	c.priorities[w] = level


# Avvia un lavoro del tipo `w` (una colonna della tabella delle priorità), il più vicino; false se non ce n'è
func try_work_kind(c: Colonist, w: Work) -> bool:
	match w:
		Work.COOK:
			return try_cook(c)
		Work.CRAFT:
			return try_craft(c)
		Work.CHOP:
			return try_work(c, Job.CHOP, chop_marks.keys(), TREE_SIDES, gather_time(c, Job.CHOP))
		Work.MINE:
			return try_work(c, Job.MINE, mine_marks.keys(), SIDES, gather_time(c, Job.MINE)) \
				or try_work(c, Job.CUT_ICE, ice_ready(), SIDES, gather_time(c, Job.CUT_ICE))
		Work.GATHER:
			return try_work(c, Job.UPROOT, uproot_marks.keys(), SIDES, UPROOT_TIME * work_factor(c, Job.UPROOT)) \
				or try_work(c, Job.HARVEST, harvest_ready(), SIDES, gather_time(c, Job.HARVEST))
		Work.FARM:
			return try_work(c, Job.FARM, farm_ready(), SIDES, FARM_TIME * skill_time(c.skills[Skill.GATHERING]) * work_factor(c, Job.FARM)) \
				or try_fertilize(c)
		Work.FISH:
			return try_work(c, Job.FISH, fishable(), SIDES, gather_time(c, Job.FISH))
		Work.HUNT:
			return try_hunt(c)
		Work.BUILD:
			return try_build(c) or try_repair(c)
		Work.HAUL:  # il marcio anche dai magazzini, al cumulo del compost
			var heaps := heap_cells()
			for res in Res.values():
				var loose := func(cell): return is_free(cell) and (not heaps.has(cell) if res == Res.ROT else (not stockpile.has(cell) or heaps.has(cell)))
				if try_haul(c, res, items[res].keys().filter(loose)):
					return true
		Work.GOVERN:
			return try_seat(c, Build.THRONE, false)
		Work.STUDY:
			return try_seat(c, Build.DESK, false)
	return false


# Costruire: prima le strutture, poi i mobili; al mucchio a prendere il materiale, poi al cantiere più vicino
func try_build(c: Colonist) -> bool:
	for job in [Job.BUILD, Job.FURNISH]:  # prima le strutture, poi i mobili
		var plans := plans_of(job)
		var stands := {}  # casella libera accanto a un progetto per cui c'è un mucchio di materiale -> progetto
		for cell in plans:
			if is_free(cell) and not sources(job, cell).is_empty():
				add_stands(stands, cells_in(piece_rect(cell, plans[cell])), cell, SIDES)
		var path := path_to_nearest(c, stands.keys())
		var piles := {} if path.is_empty() else sources(job, stands[path.back()])
		var to_source := path_to_nearest(c, piles.keys())
		if not to_source.is_empty():  # prima al mucchio a prendere il materiale, poi al cantiere
			start_job(c, job, to_source, stands[path.back()], BUILD_TIME * skill_time(c.skills[Skill.CONSTRUCTION]) * work_factor(c, job))
			c.dest = path.back()
			c.carry_res = piles[to_source.back()]
			reserved[to_source.back()] = c  # intanto nessun altro prende da quel mucchio
			return true
	return false


# Riparare un tetto: la casella consumata (da WORN) più vicina, con un mucchio del suo materiale (legna per le
# scandole, pietra per i coppi): come costruire, prima al mucchio e poi accanto alla casella. false se non si può
func try_repair(c: Colonist) -> bool:
	var damaged := roof_repairs().filter(func(k): return is_free(k))
	if damaged.is_empty():
		return false
	var stands := {}
	for cell in damaged:
		add_stands(stands, [cell], cell, SIDES)
	var path := path_to_nearest(c, stands.keys())
	if path.is_empty():
		return false
	var target: Vector2i = stands[path.back()]
	var res: Res = roofed[target].material
	var to_source := path_to_nearest(c, items[res].keys().filter(func(k): return items[res][k] >= REPAIR_COST and is_free(k)))
	if to_source.is_empty():
		return false
	start_job(c, Job.REPAIR, to_source, target, REPAIR_TIME * skill_time(c.skills[Skill.CONSTRUCTION]) * work_factor(c, Job.REPAIR))
	c.dest = path.back()
	c.carry_res = res
	reserved[to_source.back()] = c
	return true


# caselle di tetto da riparare: tegole smosse o buchi
func roof_repairs() -> Array:
	return wear.keys().filter(func(k): return wear[k] >= WORN and roofed.has(k))


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
	if age_of(c) < YOUTH_AGE:
		f *= CHILD_SLOW
	if c.due > 0.0 and c.due - clock < pregnancy() / 3.0:  # gli ultimi mesi
		f *= PREGNANT_SLOW
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


func add_cond(c: Colonist, k: Cond, days := -1.0) -> void:  # `days`: se no quelli di COND_INFO
	c.conds[k] = clock + (days if days >= 0.0 else COND_INFO[k][0])


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


# fuochi da campo e focolari dentro le stanze di tipo cucina
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


# Pezzi che `c` metterebbe nello slot `slot`. Scelto nella scheda (loadout): quel pezzo, se non ce l'ha già addosso;
# niente se ha scelto "Empty". Automatico, solo se lo ha vuoto: nelle mani il suo attrezzo, se no tutti quelli dello slot
func fits(c: Colonist, slot: Slot) -> Array:
	if c.loadout.has(slot):
		var g = c.loadout[slot]
		return [] if g == null or c.gear.get(slot) == g else [g]
	if c.gear.has(slot) or (slot == Slot.SHIELD and not shielded(c)):
		return []
	if slot == Slot.HANDS:
		return [wanted_tool(c)]
	return GEAR.keys().filter(func(g): return GEAR[g]["slot"] == slot)


# Slot da riempire (vedi fits) e il pezzo giusto in un mucchio libero: va a prenderlo (Job.EQUIP) e posa lì quello che
# aveva. Scelto "Empty": se lo toglie e lo posa ai suoi piedi, poi si porta in magazzino come ogni mucchio.
# false se non c'è niente da mettere
func try_equip(c: Colonist) -> bool:
	if age_of(c) < YOUTH_AGE:  # i bambini non prendono armi né armature
		return false
	for slot in Slot.values():
		if c.loadout.has(slot) and c.loadout[slot] == null and c.gear.has(slot):
			drop(c.gear[slot], cell_of(c.pos), 1)
			c.gear.erase(slot)
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
# se sono di più: i coloni in automatico con lo slot vuoto che lo prenderebbero (per le mani: chi vuole proprio
# quell'attrezzo; se no tutti), meno quelli già fatti e in lavorazione per lo stesso slot; oppure chi l'ha scelto nella
# scheda e non ce l'ha, meno quelli già fatti e in lavorazione (ognuno conta solo il suo pezzo).
# Almeno un arco se ci sono animali da cacciare e nessuno ce l'ha: chi va a caccia se lo prende (vedi try_hunt)
func gear_wanted(res: Res) -> int:
	var making := func(r): return colonists.filter(func(o): return o.job == Job.CRAFT and RECIPES[o.recipe][0] == r).size()
	var spare: int = keep.get(res, 0) - total(res) - making.call(res)
	if not GEAR.has(res):
		return spare
	var slot: Slot = GEAR[res]["slot"]
	var same: Array = [res] if slot == Slot.HANDS else GEAR.keys().filter(func(g): return GEAR[g]["slot"] == slot)
	var want := colonists.filter(func(o): return not o.loadout.has(slot) and res in fits(o, slot)).size()
	if res == Res.BOW and animals.any(func(a): return a.marked) and not colonists.any(has_bow):
		want = maxi(want, 1)
	for g in same:
		want -= total(g) + making.call(g)
	var chosen := colonists.filter(func(o): return o.loadout.has(slot) and res in fits(o, slot)).size()
	return maxi(maxi(want, spare), chosen - total(res) - making.call(res))


# mobili `kind` (fornace, incudine, banco; per il fuoco da campo anche il focolare, vedi ROLE) dentro una stanza del
# tipo giusto (STATION_ROOM)
func stations(kind: Build) -> Array:
	return furniture.keys().filter(func(o): return role(furniture[o][0]) == kind \
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
			* work_factor(c, Job.CRAFT) * (SMOKE_TIME if r[0] in SMOKED and furniture[station][0] == Build.CAMPFIRE else 1.0))
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
		if r[0] == Res.COAL and r[3].has(Res.WOOD) and researched.has(Tech.MANURING):  # la carbonaia lascia la cenere
			drop(Res.ASH, here, 1)
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
	if c.hp < flee_hp() or age_of(c) < YOUTH_AGE:  # i bambini scappano sempre
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
		die(c, tr("was killed by wolves."))
		return
	if randf() >= BITE_HIT - DODGE_PER_LEVEL * c.skills[Skill.MELEE]:
		return
	c.hp -= BEASTS[a.kind]["bite"] * armor_factor(c)
	c.needs[Need.STRESS] = minf(c.needs[Need.STRESS] + HIT_STRESS, NEED_MAX)
	if c.hp <= 0:
		c.hp = 0.0
		a.target = null
		if deaths and randf() < death_chance(c):
			die(c, tr("was killed by wolves."))
			return
		c.downed = true
		quit_job(c)


# percorso di un animale che non passa dalle stanze, dai cancelli né dalle porte (anche quella di un recinto, che non è
# una stanza): per la ricerca li si riempie come fossero muro
func beast_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var shut := built.keys().filter(func(k): return built[k][0] in [Build.GATE, Build.DOOR])
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
	note(tr("Day %d: a wandering scholar stops at the inn, with %s to sell (see Knowledge).") % [int(clock) + 1,
		", ".join(scholar_books.map(func(b): return tr("a %s", "book") % res_name(b)))])


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


# posa `amount` di `res` in magazzino, dove ci sta (vedi dest_cells); pieno, accanto alla prima casella; senza
# magazzini (si parte senza, o sono stati abbattuti) a terra su `near`
func store(res: Res, amount: int, near := MAP_SIZE / 2) -> void:
	var cells := dest_cells(res)
	drop(res, cells[0] if not cells.is_empty() else (stockpile.keys()[0] if not stockpile.is_empty() else near), amount)


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
			note(tr("Day %d, night: the watch sees wolves coming.") % (int(clock) + 1))
		return


# --- Morte ---

# probabilità che il colpo che butta a terra `c` lo uccida: meno con più protezione
func death_chance(c: Colonist) -> float:
	return maxf(DEATH_BASE - DEATH_PER_ARMOR * gear_sum(c, "armor"), DEATH_MIN)


# `c` muore: lascia a terra quello che porta, l'equipaggiamento e il bottino; il corpo resta CORPSE_DAYS. Se era un
# colono gli altri prendono il lutto; morti tutti, la colonia è caduta. `away`: un colono della compagnia morto in una
# rovina, che la colonia viene a sapere adesso: il corpo e quello che portava restano là
func die(c: Colonist, why: String, away := false) -> void:
	if not away:
		quit_job(c)
		var here := cell_of(c.pos)
		for g in c.gear.values():
			drop(g, here, 1)
		for res in c.loot:
			drop(res, here, c.loot[res])
		corpses.append(c)
	c.gear.clear()
	c.loot.clear()
	c.downed = true
	c.hp = 0.0
	c.died = clock
	var was_colonist := c in colonists or away
	withdraw(c)
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
			exp.left.erase(c)
			if exp.party.is_empty():
				expeditions.erase(exp)
			else:
				leave_if_ready(exp)
	if was_colonist:
		gain(DEATH_AUTHORITY)
		for o in colonists:  # il sovrano: il lutto regale, al posto del lutto
			add_cond(o, Cond.ROYAL_MOURNING if c == ruler and regent_for == null else Cond.MOURNING)
	if shown == c:
		sheet_panel.hide()
	note("%s: %s %s" % [date(int(clock)), full_name(c), why])
	if was_colonist and colony_size() == 0:  # chi è in spedizione tiene in vita la colonia
		fallen = true
		$HUD/Fallen.show()
	elif c == ruler:
		succeed(c)
	elif c == regent_for:
		heir_died()


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


# letti liberi per `c`: agli ospiti (vedi visitor) quelli della locanda, ai coloni tutti gli altri
func free_beds(c: Colonist) -> Array:
	return furniture.keys().filter(func(o): return furniture[o][0] in BEDS and is_free(o) \
		and is_inn(room_at(o)) == visitor(c))


# ospite, non colono: avventuriero, pretendente o viandante. Non lavora, dorme alla locanda
func visitor(c: Colonist) -> bool:
	return c.hero != Hero.NONE or c.suitor or c.wanderer


func inn_beds() -> int:
	return furniture.keys().filter(func(o): return furniture[o][0] in BEDS and is_inn(room_at(o))).size()


# avventuriero `kind` di livello `level`, col suo nome, aspetto, abilità ed equipaggiamento
# sposato, col coniuge vivo
func married(c: Colonist) -> bool:
	return c.spouse != null and c.spouse.died == 0.0


# il sovrano si può sposare: è in colonia, adulto, senza coniuge vivo
func can_marry() -> bool:
	return ruler in colonists and regent_for == null and age_of(ruler) >= ADULT and not married(ruler)


# chi il sovrano può sposare: i coloni adulti dell'altro sesso senza coniuge vivo, ognuno con il perché no ("" se
# accetta)
func suitors() -> Array:
	var out := []
	for o in colonists:
		if o != ruler and o.sex != ruler.sex and age_of(o) >= ADULT and not married(o):
			out.append([o, "" if o.needs[Need.HAPPINESS] >= MARRY_HAPPY else tr("not happy enough")])
	for g in guests:  # i pretendenti arrivati alla locanda accettano sempre
		if g.suitor and g.errand == Errand.NONE:
			out.append([g, ""])
	return out


# le nozze di `a` e `b`: a tutti Cond.WEDDING, autorità, la cronaca; ognuno entra nelle stanze dell'altro
func marry(a: Colonist, b: Colonist) -> void:
	for o in [a, b]:
		if o.suitor:  # il pretendente diventa un colono; la dote resta dove si trova
			o.suitor = false
			guests.erase(o)
			board_pick.erase(o)
			colonists.append(o)
			for res in o.dowry:
				drop(res, cell_of(o.pos), o.dowry[res])
			if not o.dowry.is_empty():
				note(tr("%s: %s brings a dowry: %s.") % [date(today), full_name(o), dowry_words(o)])
	for g in guests:  # gli altri pretendenti se ne vanno
		if g.suitor:
			g.stay_until = clock
	a.spouse = b
	b.spouse = a
	for c in colonists:
		add_cond(c, Cond.WEDDING)
	gain(WEDDING_AUTHORITY)
	for room in rooms:
		for pair in [[a, b], [b, a]]:
			if room.owners.has(pair[0]) and not room.owners.has(pair[1]):
				room.owners.append(pair[1])
	note(tr("%s: %s married %s.") % [date(today), full_name(a), full_name(b)])


# "Arrange a marriage…" nella scheda del sovrano: chi può sposare; chi non accetta è spento, col perché
func open_marriage_menu() -> void:
	marriage_menu.clear()
	var options := suitors()
	for i in options.size():
		var o: Colonist = options[i][0]
		marriage_menu.add_item(tr("%s, %d years old") % [full_name(o), age_of(o)]
			+ (" – " + options[i][1] if options[i][1] != "" else "")
			+ (" – " + tr("dowry: %s") % dowry_words(o, false) if o.suitor else ""), people().find(o))
		marriage_menu.set_item_disabled(i, options[i][1] != "")
	if options.is_empty():
		marriage_menu.add_item(tr("Nobody to marry."), -1)
		marriage_menu.set_item_disabled(0, true)
	var button: Control = $HUD/ColonistSheet/Box/Family/Marry
	marriage_menu.popup(Rect2i(button.get_screen_position() + Vector2(0, button.size.y), Vector2i.ZERO))


func marriage_pressed(id: int) -> void:
	if id >= 0 and can_marry():
		marry(ruler, people()[id])
		open_sheet(ruler)


# Di notte (CONCEIVE_HOUR), una donna sposata che dorme nella stessa stanza del marito può restare incinta: in età
# (FERTILE_AGE, da LATE_FERTILE la metà), non già incinta, passato un anno dall'ultimo parto
func conceive(c: Colonist) -> void:
	var years := age_of(c)
	if c.sex != Sex.FEMALE or not married(c) or c.spouse not in colonists or c.due > 0.0 or clock < c.fertile_from \
			or years < FERTILE_AGE[0] or years > FERTILE_AGE[1]:
		return
	var room := room_at(cell_of(c.pos))
	if c.job != Job.SLEEP or c.spouse.job != Job.SLEEP or room == null or room != room_at(cell_of(c.spouse.pos)):
		return
	if randf() < CONCEIVE_CHANCE * (0.5 if years >= LATE_FERTILE else 1.0):
		c.due = clock + pregnancy()
		c.conds[Cond.PREGNANT] = c.due


# Il parto: un neonato in `babies`, figlio di `mother` e del marito. Il cognome e i colori della casata (se uno dei
# due è della casata del sovrano, se no del padre); capelli da uno dei due; ogni loro talento al TRAIT_INHERIT, al più
# due, mai in contrasto. La cronaca lo scrive, la finestra della nascita chiede il nome
func give_birth(mother: Colonist) -> void:
	var father = mother.spouse
	var parents: Array = [mother] + ([father] if father != null else [])
	var house: Colonist = parents[-1]  # il genitore della casata del sovrano, se c'è; se no il padre
	for p in parents:
		if p.last_name == house_name:
			house = p
			break
	var child := Colonist.new()
	dress(child, people().map(func(o): return o.first_name) + babies.map(func(o): return o.first_name))
	child.nickname = ""
	child.beard = false  # la barba, forse, da adulto (vedi new_day)
	child.last_name = house.last_name
	child.tunic = house.tunic
	child.cape = house.cape
	child.hair = parents.pick_random().hair
	child.born = clock
	child.mother = mother
	child.father = father
	var pool: Array = []
	for p in parents:
		pool.append_array(p.traits.filter(func(t): return t not in pool))
	pool.shuffle()
	for t in pool:
		if child.traits.size() < 2 and randf() < TRAIT_INHERIT and not child.traits.any(func(o): return clash(o, t)):
			child.traits.append(t)
	child.skills = Skill.values().map(func(_s): return 0)
	child.xp = Skill.values().map(func(_s): return 0)
	child.needs = Need.values().map(func(n): return 0.0 if n == Need.STRESS else NEED_MAX * 0.8)
	child.trend = child.needs.map(func(_v): return 0.0)
	child.pos = mother.pos
	mother.due = 0.0
	mother.conds.erase(Cond.PREGNANT)
	mother.fertile_from = clock + life_year()
	babies.append(child)
	place_babies()
	note(birth_line(child))
	naming = child
	naming_line = chronicle.size() - 1
	var panel: Control = $HUD/BirthPanel
	var what := tr("a boy") if child.sex == Sex.MALE else tr("a girl")
	panel.get_node("Box/Text").text = tr("%s and %s have a child: %s.") % [full_name(mother), full_name(father), what] \
		if father != null else tr("%s has a child: %s.") % [full_name(mother), what]
	panel.get_node("Box/Row/Name").text = child.first_name
	panel.show()
	panel.reset_size()


# la voce della cronaca per la nascita di `child`
func birth_line(child: Colonist) -> String:
	return tr("%s: %s is born, child of %s and %s.") % [date(int(child.born)), full_name(child), full_name(child.mother),
		full_name(child.father)] if child.father != null else tr("%s: %s is born, child of %s.") % [date(int(child.born)),
		full_name(child), full_name(child.mother)]


# il nome del neonato, dalla finestra della nascita (vuoto: resta quello di prima); cambia anche la cronaca
func name_child(text: String) -> void:
	if naming == null or text.strip_edges() == "":
		return
	naming.first_name = text.strip_edges()
	if naming_line >= 0 and naming_line < chronicle.size():
		chronicle[naming_line] = birth_line(naming)


func roll_child_name() -> void:
	if naming == null:
		return
	var taken: Array = people().map(func(o): return o.first_name) + babies.map(func(o): return o.first_name)
	var free: Array = FIRST_NAMES[naming.sex].filter(func(n): return n not in taken)
	$HUD/BirthPanel/Box/Row/Name.text = (free if not free.is_empty() else FIRST_NAMES[naming.sex]).pick_random()
	name_child($HUD/BirthPanel/Box/Row/Name.text)


# Ogni neonato in una culla libera (prima quelle nelle stanze dei genitori, i più piccoli per primi); chi resta senza
# sta in braccio (vedi carrier_of)
func place_babies() -> void:
	var cradles: Array = furniture.keys().filter(func(k): return furniture[k][0] == Build.CRADLE)
	var order := babies.duplicate()
	order.sort_custom(func(a, b): return a.born > b.born)
	for b in order:
		b.cradle = Vector2i(-1, -1)
	for b in order:
		var mine := cradles.filter(func(k): return room_at(k) != null and [b.mother, b.father].any(func(p): return p in room_at(k).owners))
		var pick: Array = mine if not mine.is_empty() else cradles
		if not pick.is_empty():
			b.cradle = pick[0]
			cradles.erase(pick[0])


# chi tiene in braccio il neonato `b` senza culla: la madre, se no il padre, se no il primo adulto della colonia
func carrier_of(b: Colonist):
	for p in [b.mother, b.father]:
		if p != null and p in colonists:
			return p
	for c in colonists:
		if age_of(c) >= ADULT:
			return c
	return null


# i figli di `c`, vivi o morti, neonati compresi, dal più grande
func children_of(c: Colonist) -> Array:
	var all: Array = []
	for o in colonists + babies + corpses + away_colonists():  # anche chi è in spedizione
		if (o.mother == c or o.father == c) and o not in all:
			all.append(o)
	all.sort_custom(func(a, b): return a.born < b.born)
	return all


# il titolo di `c` come sovrano: Signore, Barone... o Reggente
func ruler_title(c: Colonist) -> String:
	return tr("Regent") if c == ruler and regent_for != null else tr(TITLES[rank]["ruler"][c.sex])


# chi eredita da `monarch`, nell'ordine: i figli vivi dal più grande, il coniuge vivo, i fratelli e le sorelle vivi
func line_of(monarch: Colonist) -> Array:
	var away := away_colonists()
	var alive := func(o): return o.died == 0.0 and (o in colonists or o in babies or o in away)
	var line: Array = children_of(monarch).filter(alive)
	if married(monarch) and alive.call(monarch.spouse):
		line.append(monarch.spouse)
	for parent in [monarch.mother, monarch.father]:
		if parent != null:
			for o in children_of(parent):
				if o != monarch and o not in line and alive.call(o):
					line.append(o)
	return line


# chi regna per l'erede minorenne `heir`: un genitore adulto, se no l'adulto con più abilità; null se non ci sono adulti
func regent_of(heir: Colonist):
	var adults: Array = colonists.filter(func(o): return o != heir and age_of(o) >= ADULT)
	for p in [heir.mother, heir.father]:
		if p in adults:
			return p
	adults.sort_custom(func(a, b): return a.skills.reduce(func(n, v): return n + v, 0) > b.skills.reduce(func(n, v): return n + v, 0))
	return adults.front() if not adults.is_empty() else null


# Il sovrano `dead` è morto (o il reggente): chi viene dopo. Un erede adulto regna subito e finito il lutto regale è
# incoronato; uno minorenne aspetta i 16 anni con un reggente; nessuno: la colonia sceglie una casata nuova
func succeed(dead: Colonist) -> void:
	if regent_for != null:  # è morto il reggente: un altro, per lo stesso erede
		var regent = regent_of(regent_for)
		if regent == null:
			begin_reign(regent_for)
			coronation_at = clock + ROYAL_MOURNING_DAYS
		else:
			ruler = regent
			note(tr("%s: %s is regent for %s.") % [date(today), full_name(ruler), full_name(regent_for)])
		show_title()
		return
	if not reigns.is_empty() and reigns[-1][0] == dead:
		reigns[-1][2] = clock
	var line := line_of(dead)
	if line.is_empty():
		choose_house()
		return
	var heir: Colonist = line[0]
	var regent = regent_of(heir) if age_of(heir) < ADULT else null
	if regent == null:
		begin_reign(heir)
		coronation_at = clock + ROYAL_MOURNING_DAYS
		note(tr("%s: %s inherits the crown.") % [date(today), full_name(heir)])
	else:
		regent_for = heir
		ruler = regent
		note(tr("%s: %s inherits the crown; until they come of age, %s is regent.") % [date(today), full_name(heir), full_name(regent)])
	show_title()


# L'erede minorenne è morto durante la reggenza: il prossimo della linea del sovrano di prima; se non ce n'è, il
# reggente fonda una casata nuova
func heir_died() -> void:
	regent_for = null
	var line: Array = line_of(reigns[-1][0]) if not reigns.is_empty() else []
	if line.is_empty():
		found_house(ruler)
	elif age_of(line[0]) >= ADULT:
		begin_reign(line[0])
		coronation()
	else:
		regent_for = line[0]
		note(tr("%s: %s inherits the crown; until they come of age, %s is regent.") % [date(today), full_name(regent_for), full_name(ruler)])
	show_title()


func begin_reign(c: Colonist) -> void:
	ruler = c
	regent_for = null
	reigns.append([c, clock, -1.0, house_name])


# L'incoronazione di `ruler`: festa per tutti, autorità, una finestra e la cronaca
func coronation() -> void:
	coronation_at = 0.0
	for o in colonists:
		add_cond(o, Cond.CORONATION)
	gain(CORONATION_AUTHORITY)
	show_title()
	report(tr("Coronation"), [tr("%s: coronation of %s, %s of %s.") % [date(today), full_name(ruler), ruler_title(ruler), realm]])


# Nessun erede: la colonia sceglie il sovrano di una casata nuova tra gli adulti. Intanto regna il primo (quello con
# più abilità); la finestra lascia sceglierne un altro
func choose_house() -> void:
	var everyone: Array = colonists + away_colonists()  # anche chi è in spedizione
	var adults: Array = everyone.filter(func(o): return age_of(o) >= ADULT)
	if adults.is_empty():
		adults = everyone
	adults.sort_custom(func(a, b): return a.skills.reduce(func(n, v): return n + v, 0) > b.skills.reduce(func(n, v): return n + v, 0))
	var old := house_name
	found_house(adults[0])
	var panel: Control = $HUD/SuccessionPanel
	panel.get_node("Box/Text").text = tr("The house of %s has no heirs. Choose who will rule: their house begins.") % old
	var list: Control = panel.get_node("Box/List")
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for c in adults:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.text = tr("%s, %d years old") % [full_name(c), age_of(c)]
		button.pressed.connect(func():
			pick_founder(c)
			panel.hide())
		list.add_child(button)
	panel.show()
	panel.reset_size()


# il sovrano della casata nuova è `c` invece di quello scelto prima
func pick_founder(c: Colonist) -> void:
	if c == ruler:
		return
	ruler = c
	house_name = c.last_name
	reigns[-1][0] = c
	reigns[-1][3] = house_name
	if founding_line >= 0 and founding_line < chronicle.size():
		chronicle[founding_line] = founding_text(c)
	show_title()


# Una casata nuova: `c` regna col suo cognome, uno stemma nuovo; incoronato finito il lutto regale
func found_house(c: Colonist) -> void:
	founding_from = house_name
	house_name = c.last_name
	begin_reign(c)
	arms = random_arms()
	coronation_at = clock + ROYAL_MOURNING_DAYS
	note(founding_text(c))
	founding_line = chronicle.size() - 1
	show_title()


func founding_text(c: Colonist) -> String:
	return tr("%s: the house of %s has no heirs. %s begins the house of %s.") % [date(today), founding_from, full_name(c), c.last_name]


# La finestra della casata: i sovrani in ordine, divisi per casata, ognuno con gli anni di regno, il coniuge e i figli
# (vivi e morti, con l'età); per ultimo il reggente, se c'è
func open_house() -> void:
	$HUD/HousePanel/Box/Head/Title.text = tr("The House of %s") % house_name
	$HUD/HousePanel/Box/Scroll/Text.text = house_text()
	$HUD/HousePanel.show()
	$HUD/HousePanel.reset_size()


func house_text() -> String:
	var lines := []
	var shown := ""
	for reign in reigns:
		var c: Colonist = reign[0]
		var house: String = reign[3] if reign.size() > 3 else c.last_name
		if house != shown:
			shown = house
			lines.append("[color=#e8c34a]%s[/color]" % tr("The House of %s") % house)
		var end: float = reign[2]
		var years := "%d – %s" % [year_of(int(reign[1])) + 1, str(year_of(int(end)) + 1) if end >= 0.0 else tr("today")]
		lines.append("%s %s%s, %s (%s)" % [CROWN_IMG, full_name(c), " †" if c.died > 0.0 else "", tr("Year %s") % years,
			tr("%d years old") % age_of(c) if c.died == 0.0 else tr("died at %d") % floori((c.died - c.born) / life_year())])
		if c.spouse != null:
			lines.append("    " + tr("Spouse: %s") % full_name(c.spouse) + (" †" if c.spouse.died > 0.0 else ""))
		var kids: Array = children_of(c).map(func(o): return "%s (%d)" % [o.first_name, age_of(o) if o.died == 0.0
			else floori((o.died - o.born) / life_year())] + (" †" if o.died > 0.0 else ""))
		if not kids.is_empty():
			lines.append("    " + tr("Children: %s") % ", ".join(kids))
	if regent_for != null:
		lines.append(tr("%s is regent for %s.") % [full_name(ruler), full_name(regent_for)])
	return "\n".join(lines)


# la dote di `c` a parole: monete (con la monetina, se `rich`) e oggetti
func dowry_words(c: Colonist, rich := true) -> String:
	var parts := []
	for res in c.dowry:
		parts.append((coins(c.dowry[res]) if rich else tr("%d coins") % c.dowry[res]) if res == Res.GOLD
			else "%d %s" % [c.dowry[res], item_title(res).to_lower()])
	return ", ".join(parts)


# I pretendenti: finché il sovrano può sposarsi e c'è una locanda, ogni SUITOR_EVERY giorni circa ne arriva uno dal
# bordo della mappa, come gli avventurieri; aspetta SUITOR_STAY giorni, poi se ne va (vedi update_guests)
func update_suitors() -> void:
	if next_suitor == 0.0:
		next_suitor = clock + SUITOR_EVERY
	if clock < next_suitor:
		return
	next_suitor = clock + SUITOR_EVERY + randf_range(-SUITOR_JITTER, SUITOR_JITTER)
	var edges := border_cells()
	if not can_marry() or not rooms.any(is_inn) or guests.any(func(g): return g.suitor) or edges.is_empty():
		return
	var c := new_suitor(Sex.FEMALE if ruler.sex == Sex.MALE else Sex.MALE)
	c.pos = center(edges.pick_random())
	c.errand = Errand.ARRIVE
	guests.append(c)
	travel(c)
	note(tr("%s: %s, of the house of %s, is coming to the inn to ask for the hand of %s.") % [date(today), full_name(c), c.last_name,
		full_name(ruler)])


# un pretendente del sesso `sex`, di un'altra casata: età, qualche abilità e talento, lo stemma (e i colori), la dote
func new_suitor(sex: Sex) -> Colonist:
	var c := Colonist.new()
	var taken: Array = people().map(func(o): return o.first_name)
	dress(c, taken)
	c.sex = sex
	c.hair_style = HAIR_STYLES[sex].pick_random()
	c.beard = sex == Sex.MALE and randf() < BEARD_CHANCE
	var free: Array = FIRST_NAMES[sex].filter(func(n): return n not in taken)
	c.first_name = (free if not free.is_empty() else FIRST_NAMES[sex]).pick_random()
	c.nickname = ""
	c.last_name = LAST_NAMES.filter(func(n): return n != house_name).pick_random()
	give_age(c, SUITOR_AGE)
	c.skills = Skill.values().map(func(_s): return 0)
	for i in SUITOR_SKILLS:
		var open: Array = Skill.values().filter(func(k): return c.skills[k] < 3)
		c.skills[open.pick_random()] += 1
	c.xp = Skill.values().map(func(_s): return 0)
	c.needs = Need.values().map(func(n): return 0.0 if n == Need.STRESS else NEED_MAX * 0.8)
	c.trend = c.needs.map(func(_v): return 0.0)
	var pool := Trait.values()
	pool.shuffle()
	for t in pool.slice(0, randi_range(0, 2)):
		if not c.traits.any(func(o): return clash(o, t)):
			c.traits.append(t)
	c.house_arms = random_arms()
	c.tunic = TINCTURE_COLORS[c.house_arms.field]
	c.cape = TINCTURE_COLORS[c.house_arms.field2]
	c.dowry = {Res.GOLD: randi_range(DOWRY_GOLD[0], DOWRY_GOLD[1])}
	if randf() < DOWRY_ITEM_CHANCE:
		var item: Array = DOWRY_ITEMS.pick_random()
		c.dowry[item[0]] = item[1]
	c.suitor = true
	return c


# giorni per un anno di vita: una stagione col ritmo veloce, un anno di calendario con quello reale (Pace)
func life_year() -> float:
	return LIFE_YEARS[pace]


# giorni di gravidanza: tre quarti d'anno di vita
func pregnancy() -> float:
	return PREGNANCY * life_year()


# gli anni di `c`, compiuti: uno ogni life_year() giorni
func age_of(c: Colonist) -> int:
	if c.born == INF:  # senza nascita (fatto a mano, nelle prove): adulto
		return ADULT_AGE[0]
	return floori((clock - c.born) / life_year())


# un'età a caso tra `ages[0]` e `ages[1]` anni (compresi), con un giorno di nascita a caso
func give_age(c: Colonist, ages: Array) -> void:
	c.born = clock - randf_range(ages[0], ages[1] + 1) * life_year()


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
	give_age(c, ADULT_AGE)
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


func fee(c: Colonist) -> int:  # i coloni della compagnia niente
	return 0 if c.hero == Hero.NONE else roundi((FEE_BASE + FEE_PER_LEVEL * c.level) * gift(c, "fee", 1.0))


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
	return tr("%s, level %d") % [named(Hero, c.hero), c.level]


func gift_names(c: Colonist) -> String:
	return ", ".join(c.gifts.map(func(g): return named(Gift, g)))


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
	var away: int = expeditions.reduce(func(n, exp): return n + exp.party.filter(func(g): return g.hero != Hero.NONE and g not in guests).size(), 0)
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
			if g.wanderer:  # nessuna risposta: il viandante se ne va, con la sua famiglia
				send_away(g.fellows)
				continue
			withdraw(g)  # se aspettava la risposta, non aspetta più
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
	elif c.errand == Errand.VISIT:
		goals = visit_cells()
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
			c.stay_until = clock + (SUITOR_STAY if c.suitor else (RENOWNED_GUESTS[1] if researched.has(Tech.RENOWNED_INN) else GUEST_STAY)
				- (1.0 if enacted.has(Law.LODGING_TAX) else 0.0))
		Errand.RETURN:  # alla locanda; il colono di ritorno ci lascia il bottino e torna al lavoro
			c.hired = false
			for res in c.loot:
				drop(res, cell_of(c.pos), c.loot[res])
			c.loot.clear()
			if c.hero != Hero.NONE:
				c.stay_until = clock + GUEST_REST
				if wants_to_stay(c) and request_of(c).is_empty():
					ask([c])
		Errand.LEAVE:
			guests.erase(c)
			c.fellows = []  # via il riferimento al gruppo (che contiene lui): se ne va per sempre
		Errand.VISIT:  # il viandante arrivato: col primo del gruppo comincia l'attesa della risposta
			if request_of(c).is_empty() and c.stay_until == 0.0:
				for o in c.fellows:
					o.stay_until = clock + WANDERER_WAIT
				ask(c.fellows)
		Errand.DEPART:
			guests.erase(c)
			colonists.erase(c)  # il colono della compagnia: fuori dalla mappa (vedi colony_size)
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
	if exp.left_at < 0 and exp.party.all(func(g): return g not in guests and g not in colonists):
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
			or party.any(func(g): return g.hired or (g not in guests and g not in volunteers())) \
			or not party.any(func(g): return g.hero != Hero.NONE):
		return false
	take_stored(Res.GOLD, cost)
	var exp := Expedition.new()
	exp.ruin = ruin
	exp.left.assign(party)
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
		withdraw(g)  # ingaggiato: non chiede più di restare
		if researched.has(Tech.LENDING_ARMORY) and g.hero != Hero.NONE:
			loans.append_array(lend(g))
		exp.party.append(g)
		g.hired = true
		g.errand = Errand.DEPART
		quit_job(g)
		travel(g)
	expeditions.append(exp)
	board_pick.clear()
	note(tr("%s: %s hired for the %s, for %s and %d of %d provisions.") % [date(int(clock)),
		", ".join(party.map(func(g): return "%s (%s)" % [full_name(g), hero_name(g) if g.hero != Hero.NONE else tr("colonist")])),
		tr(RUINS[ruin.kind]["name"]), coins(cost),
		exp.food, want] + (tr(" The armory lends: %s.") % ", ".join(loans) if not loans.is_empty() else ""))
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
	exp.lines.append((tr("%s: the party reaches the %s. %s") % [date(int(start)), tr(data["name"]), eat_on_trip(exp, travel)]).strip_edges())
	while exp.ruin.cleared < data["rooms"] and not exp.party.is_empty():
		var last: bool = exp.ruin.cleared == data["rooms"] - 1
		var room := tr("%s, room %d: ") % [date(int(start + days)), exp.ruin.cleared + 1]
		days += ROOM_DAYS
		var kind: int = Chamber.CHEST if last else next_chamber(exp.ruin)
		exp.ruin.next = -1
		var opened := true
		if last:
			room += tr("the guardian of the treasure. %s ") % fight_monsters(exp, MONSTER_POWER * danger * 2)
		match kind:
			Chamber.EMPTY:
				room += tr("empty.")
			Chamber.TRAP:
				var picker := best_at(exp.party, Skill.LOCKPICKING)
				if randf() < TRAP_DISARM + TRAP_PER_LEVEL * picker.skills[Skill.LOCKPICKING] + party_gift(exp.party, "disarm", 0.0):
					room += tr("%s disarms a trap.") % picker.first_name
				else:
					var lured := exp.party.filter(func(c): return gift(c, "lure", false))
					var victim: Colonist = lured[0] if not lured.is_empty() else exp.party.pick_random()
					var hurt := roundf(TRAP_HURT * danger * gift(victim, "hurt", 1.0))
					victim.hp -= hurt
					room += tr("a trap hurts %s (-%d).") % [victim.first_name, hurt]
			Chamber.MONSTERS:
				if randf() < party_gift(exp.party, "sneak", 0.0):
					room += tr("monsters, but the party slips past them.")
				else:
					room += tr("monsters! ") + fight_monsters(exp, MONSTER_POWER * danger)
			Chamber.CHEST:
				var chest := open_chest(exp, data, last)
				room += chest[0]
				opened = chest[1]
			Chamber.COLLAPSE:
				room += tr("a collapse blocks the way.")
		exp.lines.append((room + " " + eat_on_trip(exp, ROOM_DAYS)).strip_edges())
		for c in exp.party.duplicate():  # a 0 punti ferita: muore, o lo riportano gli altri (da solo, nessuno)
			if c.hp <= 0:
				var medic := exp.party.any(func(o): return o != c and o.hp > 0 and gift(o, "carry", false))
				if exp.party.size() == 1 or (not medic and randf() < FALL_DEATH):
					exp.party.erase(c)
					exp.lines.append(tr("%s falls and dies.") % c.first_name)
					if c.hero == Hero.NONE:  # un colono: la colonia lo saprà al ritorno (vedi died_away)
						exp.dead.append(c)
						continue
					c.died = clock
					note(tr("%s: %s died in the %s.") % [date(int(start + days)), full_name(c), tr(data["name"])], int(start + days))
				else:
					c.hp = CARRIED_HP
					exp.lines.append(tr("%s falls; the others carry them.") % c.first_name)
		if exp.party.is_empty():
			exp.lost = true
			break
		var heal: float = party_gift(exp.party, "heal", 0.0)
		for c in exp.party:  # il medico cura tutti dopo ogni stanza
			c.hp = minf(c.hp + heal, MAX_HP)
		if kind == Chamber.COLLAPSE:
			exp.lines.append(tr("The party turns back."))
			break
		if not opened and last:
			exp.lines.append(tr("The treasure stays locked: the party turns back."))
			break
		exp.ruin.cleared += 1
		exp.treasure = last
		if explored(exp.ruin):
			break
		var weak := exp.party.filter(func(c): return c.hp < gift(c, "turn_back", TURN_BACK))
		if not weak.is_empty():
			exp.lines.append(tr("%s is wounded: the party turns back.") % weak[0].first_name)
			break
		if exp.food < exp.party.size() * (travel + ROOM_DAYS) * party_gift(exp.party, "food", 1.0) - 0.001:
			exp.lines.append(tr("Provisions are running low: the party turns back."))
			break
	if explored(exp.ruin):
		exp.lines.append(tr("The %s has nothing left to explore.") % tr(data["name"]))
	if not exp.lost:  # il ritorno: affamati, ma a casa ci arrivano
		var hunger := eat_on_trip(exp, travel)
		if hunger != "":
			exp.lines.append(tr("On the way home: ") + hunger.to_lower())
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
	return tr("No food left: hunger (-%d each).") % roundi(hurt)


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
		strength += c.skills[role_of(c)["weapon"]] * gift(c, "weapon", 1.0) + gear_sum(c, "armor")
		weights += role_of(c)["hurt"]
		cover = minf(cover, role_of(c).get("cover", 1.0))
	var hurt := MONSTER_HURT * power * exp.party.size() / maxf(strength, 1.0) * cover
	var wounds := PackedStringArray()
	for c in exp.party:
		var taken := roundf(hurt * exp.party.size() * role_of(c)["hurt"] / weights * armor_factor(c) * gift(c, "hurt", 1.0))
		c.hp -= taken
		wounds.append("%s -%d" % [c.first_name, taken])
		c.xp[role_of(c)["weapon"]] += 1
	return ", ".join(wounds) + "."


# Forziere: chiuso (LOCKED) lo apre solo il migliore a scassinare, se ne sa abbastanza; dentro monete e un oggetto
# della rovina, di più con la sacca dello scassinatore. Il tesoro (`last`) ha la mappa della rovina dopo; gli altri,
# a volte, quella di una rovina che non si conosce. [testo per il diario, aperto]
func open_chest(exp: Expedition, data: Dictionary, last: bool) -> Array:
	var picker := best_at(exp.party, Skill.LOCKPICKING)
	if randf() < LOCKED and picker.skills[Skill.LOCKPICKING] < LOCK_PER_DANGER * data["danger"]:
		return [tr("a locked chest nobody can open."), false]
	var haul := 1.0
	for c in exp.party:
		haul = maxf(haul, role_of(c).get("haul", 1.0))
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
	var text := tr("a chest: %s, %s") % [coins(gold), ", ".join(found.keys().map(func(r): return amount_text(r, found[r])))]
	var unknown := RuinKind.values().filter(func(k): return not ruins.any(func(r): return r.kind == k) and k not in exp.maps)
	var map = null
	if last and exp.ruin.kind + 1 in unknown:
		map = exp.ruin.kind + 1
	elif not unknown.is_empty() and randf() < MAP_CHANCE * party_gift(exp.party, "maps", 1.0):
		map = unknown.pick_random()
	if map != null:
		exp.maps.append(map)
		text += tr(" and a map to the %s") % tr(RUINS[map]["name"])
	return [text + ".", true]


# Ritorni: a back_at il gruppo rientra dal bordo da cui era uscito e va alla locanda col bottino (meno la quota
# delle monete, che si tengono); le mappe fanno conoscere le loro rovine; ognuno sale di livello ogni TRIPS_PER_LEVEL
# spedizioni. Una spedizione persa: solo il diario (le mappe sono perse con loro)
func update_expeditions() -> void:
	for exp in expeditions.duplicate():
		if exp.left_at < 0 or clock < exp.back_at:
			continue
		expeditions.erase(exp)
		var name: String = tr(RUINS[exp.ruin.kind]["name"])
		if exp.lost:
			exp.lines.append(tr("Nobody came back from the %s.") % name)
			report(tr("Lost in the %s") % name, exp.lines)
			for c in exp.dead:  # i coloni della compagnia: la colonia lo sa adesso
				die(c, tr("died in the %s.") % name, true)
			continue
		var gold: int = exp.loot.get(Res.GOLD, 0)
		var share := LOOT_SHARE if enacted.has(Law.LOOT_TAX) else SHARE
		var shares: float = exp.party.reduce(func(n, g): return n + (gift(g, "share", share) if g.hero != Hero.NONE else 0.0), 0.0) \
			/ exp.party.size()
		var kept := floori(gold * shares)  # la quota: ognuno la sua parte (il leale niente, i coloni niente)
		if gold > 0:
			exp.loot[Res.GOLD] = gold - kept
		var brought := PackedStringArray()
		for res in exp.loot:
			if exp.loot[res] > 0:
				brought.append(amount_text(res, exp.loot[res]))
		exp.lines.append(tr("Back home with %s%s.") % [", ".join(brought) if not brought.is_empty() else tr("nothing", "loot"),
			tr("; they keep %s") % coins(kept) if kept > 0 else ""])
		for kind in exp.maps:
			if not ruins.any(func(r): return r.kind == kind):
				var found := Ruin.new()
				found.kind = kind
				ruins.append(found)
				exp.lines.append(tr("New on the notice board: the %s.") % tr(RUINS[kind]["name"]))
		ruins.sort_custom(func(a, b): return a.kind < b.kind)
		for g in exp.party:
			g.trips += 1
			if g.hero != Hero.NONE and g.trips % gift(g, "trips", TRIPS_PER_LEVEL) == 0 and g.level < HERO_LEVEL_MAX:
				set_level(g, g.level + 1)
				exp.lines.append(tr("%s is now level %d.") % [g.first_name, g.level])
			g.pos = center(exp.edge)
			g.errand = Errand.RETURN
			if g.hero != Hero.NONE:
				guests.append(g)
			else:  # il colono della compagnia: di nuovo in colonia, passa dalla locanda e torna al lavoro
				colonists.append(g)
			travel(g)
		if exp.treasure:
			gain(TREASURE_AUTHORITY)
			exp.lines.append(tr("The treasure of the %s: %s authority for the crown.") % [name, signed(TREASURE_AUTHORITY)])
		for g in exp.party:
			give_back(g)
		var heroes: Array = exp.party.filter(func(g): return g.hero != Hero.NONE)
		(heroes[0] if not heroes.is_empty() else exp.party[0]).loot = exp.loot  # lo porta un avventuriero alla locanda (vedi arrive)
		report(tr("Back from the %s") % name, exp.lines)
		for c in exp.dead:
			die(c, tr("died in the %s.") % name, true)


# --- Chi resta (GDD 4.2.1): la domanda, la finestra, il forestiero ---

# spedizioni dopo le quali un avventuriero chiede di restare
func stay_trips() -> int:
	return OPEN_STAY_TRIPS if enacted.has(Law.OPEN_GATES) else STAY_TRIPS


# l'avventuriero `g`, appena tornato alla locanda, chiede di restare: è contento, e ha fatto abbastanza spedizioni
# dall'ultima volta che gli hanno detto di no
func wants_to_stay(g: Colonist) -> bool:
	return g.hero != Hero.NONE and not g.suitor and g.trips - g.refused_at >= stay_trips() \
		and g.needs[Need.HAPPINESS] >= STAY_HAPPY and not enacted.has(Law.CLOSED_GATES)


# la domanda in cui c'è `c`, [] se non aspetta una risposta
func request_of(c: Colonist) -> Array:
	for group in requests:
		if c in group:
			return group
	return []


# `group` chiede di restare: aspetta in coda la risposta; la finestra si apre, se non ne mostra già un'altra
func ask(group: Array) -> void:
	requests.append(group)
	if not $HUD/RequestPanel.visible:
		show_request(group)


# `c` non aspetta più la risposta (se ne va, è ingaggiato, è morto): via la sua domanda, e la finestra se la mostrava
func withdraw(c: Colonist) -> void:
	var group := request_of(c)
	if group.is_empty():
		return
	requests.erase(group)
	if group == asking:
		asking = []
		$HUD/RequestPanel.hide()
		if not requests.is_empty():
			show_request(requests[0])


# La finestra della domanda `group`: chi è (le figurine, col mouse sopra la scheda), cosa chiede, Accogli e No
func show_request(group: Array) -> void:
	asking = group
	var panel: Control = $HUD/RequestPanel
	var c: Colonist = group[0]
	var people_row: Control = panel.get_node("Box/People")
	for child in people_row.get_children():
		child.free()
	for o in group:
		people_row.add_child(figure_icon(o))
	var days := foreigner_days()
	var tools := PackedStringArray()
	for o in group:
		if c.wanderer and o.gear.has(Slot.HANDS):
			tools.append(res_name(o.gear[Slot.HANDS]))
	panel.get_node("Box/Text").text = (tr_n("%s (%s), back from %d expedition, asks to stay in the colony.",
		"%s (%s), back from %d expeditions, asks to stay in the colony.", c.trips) % [full_name(c), hero_name(c), c.trips] \
		if not c.wanderer else tr_n("A wanderer asks to stay in the colony: %s.", "Wanderers ask to stay in the colony: %s.", group.size())
		% names_list(group.map(func(o): return tr("%s, %d years old") % [full_name(o), age_of(o)]))
		+ (" " + tr("They bring: %s.") % ", ".join(tools) if not tools.is_empty() else "")) \
		+ "\n" + tr("Welcomed, they work like the others and keep their gear. For %d days they are a foreigner: -5 happiness, work 10%% slower.") % days
	panel.get_node("Box/Row/Yes").text = "Welcome"
	panel.get_node("Box/Row/No").text = "Send away" if c.wanderer else "No"
	panel.get_node("Box/Row/No").tooltip_text = tr("They leave.") if c.wanderer else tr("They will ask again after %d more expeditions.") % stay_trips()
	panel.show()
	panel.reset_size()


# la risposta alla domanda nella finestra: sì, accolti; no, vedi refuse. Poi la prossima domanda, se ce n'è una
func answer(yes: bool) -> void:
	var group := asking
	asking = []
	$HUD/RequestPanel.hide()
	if group in requests:
		requests.erase(group)
		if yes:
			welcome(group)
		else:
			refuse(group)
	if sheet_panel.visible and shown in group:  # via il pulsante della risposta
		open_sheet(shown)
	if not requests.is_empty():
		show_request(requests[0])


# giorni da forestiero di chi resta
func foreigner_days() -> float:
	return OPEN_FOREIGNER_DAYS if enacted.has(Law.OPEN_GATES) else FOREIGNER_DAYS


# Accolti: diventano coloni, forestieri per un po'. L'avventuriero ricorda la classe; lo scudo del corredo diventa uno
# scudo vero, nel suo slot; maschera e sacca dello scassinatore si tolgono. Il suo equipaggiamento è della colonia
func welcome(group: Array) -> void:
	for c in group:
		if c.hero != Hero.NONE:
			c.former = c.hero
			c.hero = Hero.NONE
			if Look.SHIELD in c.kit:
				c.kit.erase(Look.SHIELD)
				if not c.gear.has(Slot.SHIELD):
					c.gear[Slot.SHIELD] = Res.SHIELD
			c.kit.erase(Look.MASK)
			c.kit.erase(Look.PACK)
		c.wanderer = false
		c.fellows = []
		c.stay_until = 0.0
		c.errand = Errand.NONE
		guests.erase(c)
		board_pick.erase(c)
		if c not in colonists:
			colonists.append(c)
		quit_job(c)
		add_cond(c, Cond.FOREIGNER, foreigner_days())
		c.oath = enacted.has(Law.OATH)  # col giuramento: prima di tutto, al trono (vedi try_oath)
	note(tr_n("%s: %s stays in the colony.", "%s: %s stay in the colony.", group.size()) % [date(today), names_list(group.map(full_name))])
	board_key = ""


# No: l'avventuriero lo richiederà dopo altre stay_trips() spedizioni; i viandanti se ne vanno
func refuse(group: Array) -> void:
	for c in group:
		c.refused_at = c.trips
	if group[0].wanderer:
		send_away(group)


# "Anna, Berto and Carla": i nomi uno dopo l'altro, l'ultimo con "and"
func names_list(names: Array) -> String:
	return names[0] if names.size() == 1 else tr("%s and %s") % [", ".join(names.slice(0, -1)), names[-1]]


# --- Viandanti (GDD 4.2.1) ---

# giorni di attesa, in media, prima del prossimo viandante: lo splendore attira, i tanti coloni frenano
func wander_wait() -> float:
	return WANDERER_EVERY / (1.0 + colony_splendor() / WANDERER_SPLENDOR) \
		* pow(2.0, maxi(colonists.size() - CROWD, 0) / CROWD_DOUBLE) * (OPEN_WANDERERS if enacted.has(Law.OPEN_GATES) else 1.0)


# Uno alla volta: con un viandante sulla mappa l'attesa del prossimo si ferma, e riparte da capo quando è rimasto o
# se n'è andato. Arriva da un bordo con il suo gruppo e va dove chiederà di restare (vedi visit_cells, arrive)
func update_wanderers() -> void:
	if guests.any(func(g): return g.wanderer):
		next_wanderer = 0.0
		return
	if next_wanderer == 0.0:
		next_wanderer = maxf(clock + wander_wait() * randf_range(1.0 - WANDERER_JITTER, 1.0 + WANDERER_JITTER), WANDERER_FROM)
	if clock < next_wanderer:
		return
	next_wanderer = 0.0
	if not enacted.has(Law.CLOSED_GATES):  # con le porte chiuse non viene nessuno
		come(wanderer_group())


# i viandanti `group` arrivano insieme da un bordo e vanno a chiedere di restare (vedi visit_cells, arrive)
func come(group: Array) -> void:
	var edges := border_cells()
	if edges.is_empty():
		return
	var start: Vector2i = edges.pick_random()
	for c in group:
		c.pos = center(start)
		c.errand = Errand.VISIT
		guests.append(c)
		travel(c)
	note(tr_n("%s: %s, a wanderer, is coming to ask to stay.", "%s: %s, wanderers, are coming to ask to stay.", group.size())
		% [date(today), names_list(group.map(full_name))])


# Un gruppo di viandanti, `kind` di WANDERER_GROUPS (se no a caso): uno solo, una coppia sposata, o un genitore (o una
# coppia) con un figlio, tutti col cognome del primo. Uno su WANDERER_TOOL porta un attrezzo
func wanderer_group(kind := -1) -> Array:
	if kind < 0:
		var roll := randf()
		kind = 0 if roll < WANDERER_GROUPS[0] else (1 if roll < WANDERER_GROUPS[0] + WANDERER_GROUPS[1] else 2)
	var child_age := randi_range(WANDERER_CHILD[0], WANDERER_CHILD[1])
	var ages: Array = WANDERER_AGE if kind < 2 else [maxi(WANDERER_AGE[0], child_age + ADULT + 2), WANDERER_AGE[1]]
	var first := new_wanderer(Sex.values().pick_random(), ages, true)
	var group := [first]
	if kind == 1 or (kind == 2 and randf() < 0.5):  # la coppia, sposata
		var other := new_wanderer(Sex.FEMALE if first.sex == Sex.MALE else Sex.MALE, ages, true)
		other.last_name = first.last_name
		first.spouse = other
		other.spouse = first
		group.append(other)
	if kind == 2:
		var child := new_wanderer(Sex.values().pick_random(), [child_age, child_age], false)
		child.last_name = first.last_name
		for parent in group:
			if parent.sex == Sex.FEMALE:
				child.mother = parent
			else:
				child.father = parent
		child.hair = group.pick_random().hair
		group.append(child)
	if randf() < WANDERER_TOOL:
		first.gear[Slot.HANDS] = WANDERER_TOOLS.pick_random()
	for c in group:
		c.fellows = group
	return group


# un viandante del sesso `sex`, di `ages` anni; `skilled`: con qualche punto abilità e talento (gli adulti)
func new_wanderer(sex: Sex, ages: Array, skilled: bool) -> Colonist:
	var c := Colonist.new()
	var taken: Array = people().map(func(o): return o.first_name)
	dress(c, taken)
	c.sex = sex
	c.hair_style = HAIR_STYLES[sex].pick_random()
	c.beard = sex == Sex.MALE and skilled and randf() < BEARD_CHANCE
	var free: Array = FIRST_NAMES[sex].filter(func(n): return n not in taken)
	c.first_name = (free if not free.is_empty() else FIRST_NAMES[sex]).pick_random()
	c.last_name = LAST_NAMES.filter(func(n): return n != house_name).pick_random()
	c.tunic = TUNIC_COLORS.pick_random()
	give_age(c, ages)
	c.skills = Skill.values().map(func(_s): return 0)
	c.xp = Skill.values().map(func(_s): return 0)
	if skilled:
		for i in WANDERER_SKILLS:
			var open: Array = Skill.values().filter(func(k): return c.skills[k] < 3 and k != Skill.LOCKPICKING)
			c.skills[open.pick_random()] += 1
		var pool := Trait.values()
		pool.shuffle()
		for t in pool.slice(0, randi_range(0, 2)):
			if not c.traits.any(func(o): return clash(o, t)):
				c.traits.append(t)
	c.needs = Need.values().map(func(n): return 0.0 if n == Need.STRESS else NEED_MAX * 0.8)
	c.trend = c.needs.map(func(_v): return 0.0)
	c.wanderer = true
	return c


# dove vanno i viandanti a chiedere: la sala del trono; se non c'è, attorno a un fuoco; se no la radura al centro
func visit_cells() -> Array:
	var goals := []
	for room in rooms:
		if room.kind == RoomKind.THRONE_ROOM:
			goals.append_array(room.cells.keys().filter(func(k): return not astar.is_point_solid(k)))
	if goals.is_empty():
		for origin in furniture:
			if role(furniture[origin][0]) == Build.CAMPFIRE:
				for d in EDGE_SIDES + EDGE_CORNERS:
					var k: Vector2i = origin + d
					if astar.is_in_boundsv(k) and not astar.is_point_solid(k):
						goals.append(k)
	if goals.is_empty():
		var mid: Vector2i = MAP_SIZE / 2
		for k in cells_in(Rect2i(mid - Vector2i(3, 3), Vector2i(7, 7))):
			if not astar.is_point_solid(k) and not water.has(k):
				goals.append(k)
	return goals


# Il giuramento (Law.OATH): chi è appena rimasto va nella sala del trono e ci resta in ginocchio OATH_HOURS, poi giura
# (vedi swear). Senza sala del trono giura dove si trova. Revocata la legge, niente giuramento. false se non va
func try_oath(c: Colonist) -> bool:
	if not enacted.has(Law.OATH):
		c.oath = false
		return false
	var hall := []
	for room in rooms:
		if room.kind == RoomKind.THRONE_ROOM:
			hall.append_array(room.cells.keys().filter(func(k): return not astar.is_point_solid(k) and is_free(k)))
	var path := path_to_nearest(c, hall)
	if hall.is_empty() or path.is_empty():
		swear(c)
		return false
	start_job(c, Job.OATH, path, path.back(), 0.0)
	c.work_left = OATH_HOURS * DAY_LENGTH / 24
	return true


# `c` giura fedeltà alla corona: se c'è abbastanza autorità non è più forestiero; se no resta forestiero. Nella cronaca
func swear(c: Colonist) -> void:
	c.oath = false
	if authority < OATH_AUTHORITY:
		note(tr("%s: %s cannot swear loyalty: the crown lacks the authority.") % [date(today), full_name(c)])
		return
	gain(-OATH_AUTHORITY)
	c.conds.erase(Cond.FOREIGNER)
	c.sworn = true
	note(tr("%s: %s swears loyalty to the crown.") % [date(today), full_name(c)])


# I viandanti `group` se ne vanno: non aspettano più la risposta, via dal bordo più vicino
func send_away(group: Array) -> void:
	for c in group:
		withdraw(c)
		if c in guests:
			c.errand = Errand.LEAVE
			quit_job(c)
			travel(c)


# nome di una risorsa nei testi: "leather armor"; le monete con la loro icona (vedi coins)
func res_name(res: Res) -> String:
	return named(Res, res, "item").to_lower()


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
	return "%s %s" % [kind_icon(res), named(Res, res, "item")]


# una riga nella cronaca
func note(text: String, day := -1) -> void:  # segnata sul calendario nel giorno `day` (se manca, oggi)
	chronicle.append(text)
	chronicle_days.append(day if day >= 0 else int(clock))


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
	var waiting := guests.filter(func(g): return g.hero != Hero.NONE and not g.hired and g.errand != Errand.LEAVE)
	var company := volunteers()  # Compagnia della corona: i coloni che possono andare con loro
	for g in board_pick.duplicate():
		if g not in waiting and g not in company:
			board_pick.erase(g)
	var key := str([stored(Res.GOLD), food_stored(), waiting, company, board_pick, ruins.map(func(r): return r.cleared),
		expeditions.map(func(exp): return exp.left_at), chronicle.size()])
	if key == board_key:
		return
	board_key = key
	var box: Control = $HUD/BoardPanel/Box
	var notice: OptionButton = box.get_node("Notice/Class")
	box.get_node("Notice").visible = researched.has(Tech.RENOWNED_INN)
	if notice.item_count == 0:
		for kind in Hero.values():  # in inglese: le voci si traducono da sole, anche cambiando lingua
			notice.add_item("Anyone" if kind == Hero.NONE else Hero.keys()[kind].capitalize(), kind)
		notice.item_selected.connect(func(i): wanted_hero = notice.get_item_id(i))
	notice.select(notice.get_item_index(wanted_hero))
	box.get_node("Gold").text = tr("%s    %d %s provisions (meals, raw food, hardtack)") % [coins(stored(Res.GOLD)), food_stored(),
		"[img=center]%s[/img]" % KIND_ICONS[ItemKind.FOOD].resource_path]
	var list: Control = box.get_node("Heroes")
	var crew: Control = box.get_node("Company/List")
	for child in list.get_children() + box.get_node("Ruins").get_children() + crew.get_children():
		child.free()
	for g in waiting:
		list.add_child(pick_row(g, "%s\n%s, %s, %s" % [full_name(g), hero_name(g), gift_names(g), coins(fee(g))]))
	if waiting.is_empty():
		var nobody := Label.new()
		nobody.text = "Nobody is waiting at the inn." if inn_beds() > 0 else "Nobody will come without an inn: a room with a bed, a table and this board."
		nobody.autowrap_mode = TextServer.AUTOWRAP_WORD
		list.add_child(nobody)
	box.get_node("Company").visible = researched.has(Tech.CROWN_COMPANY)
	for c in company:
		crew.add_child(pick_row(c, "%s\n%s" % [full_name(c), tr("Melee %d, ranged %d, armor %d") % [c.skills[Skill.MELEE],
			c.skills[Skill.RANGED], gear_sum(c, "armor")]]))
	if company.is_empty():
		var nobody := Label.new()
		nobody.text = "Nobody can go: adults only, not the ruler, nobody downed or pregnant."
		nobody.autowrap_mode = TextServer.AUTOWRAP_WORD
		crew.add_child(nobody)
	var cost: int = board_pick.reduce(func(n, g): return n + fee(g), 0)
	var anyone := board_pick.any(func(g): return g.hero != Hero.NONE)  # ci vuole almeno un avventuriero
	for ruin in ruins:
		var data: Dictionary = RUINS[ruin.kind]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var label := Label.new()
		label.text = tr("%s, danger %d: %s") % [tr(data["name"]), data["danger"],
			tr("explored") if explored(ruin) else tr("rooms %d / %d") % [ruin.cleared, data["rooms"]]]
		if researched.has(Tech.CARTOGRAPHY) and not explored(ruin):
			label.text += tr(", next: %s") % (tr("the treasure") if ruin.cleared == data["rooms"] - 1 else tr(CHAMBER_NAMES[next_chamber(ruin)]))
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
			send_button.disabled = board_pick.is_empty() or stored(Res.GOLD) < cost or not anyone
			send_button.tooltip_text = "Pick who goes" if board_pick.is_empty() else ("At least one adventurer must go" if not anyone
				else "Not enough gold" if stored(Res.GOLD) < cost
				else (tr("Only %d of %d provisions: they will go hungry") % [food_stored(), food] if food_stored() < food
				else tr("%d days there and back") % ceili(trip_days(ruin, board_pick))))
			send_button.pressed.connect(func(): send(board_pick.duplicate(), ruin))
			row.add_child(send_button)
		box.get_node("Ruins").add_child(row)
	box.get_node("Away").text = "\n".join(expeditions.map(func(exp): return "%s: %s" % [", ".join(exp.party.map(func(c): return c.first_name)),
		tr("on the way out") if exp.left_at < 0 else tr("at the %s, due back by day %d") % [tr(RUINS[exp.ruin.kind]["name"]), int(exp.due) + 1]]))
	box.get_node("Away").visible = not expeditions.is_empty()
	box.get_node("Chronicle").text = tr("Last: ") + chronicle[-1].get_slice("\n", 0) if not chronicle.is_empty() else ""  # il resto nella cronaca
	box.get_node("Chronicle").visible = not chronicle.is_empty()
	box.get_node("ChronicleButton").text = tr("Chronicle (%d)") % chronicle.size()
	$HUD/BoardPanel.reset_size()


# una riga della bacheca: la figurina di `g`, il testo, la casella per spuntarlo per la prossima spedizione
func pick_row(g: Colonist, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(figure_icon(g))
	var label := rich(text)
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
	return row


# la figurina di `c`, ingrandita `scale` volte (di solito al doppio), di fronte; col mouse sopra la sua scheda
# (bacheca, finestra della domanda, elenco degli abitanti)
func figure_icon(c: Colonist, scale := 2) -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = Vector2.ONE * TILE * scale
	icon.set_script(TIP)
	icon.set("make_tip", colonist_tip.bind(c))
	icon.tooltip_text = full_name(c)
	icon.draw.connect(draw_figure.bind(icon, Rect2(Vector2.ZERO, Vector2.ONE * TILE * scale), Rect2(0, 0, TILE, TILE), c))
	return icon


# --- Abitanti: chi c'è, chi arriva, chi è fuori ---

func toggle_census() -> void:
	$HUD/CensusPanel.visible = not $HUD/CensusPanel.visible
	if $HUD/CensusPanel.visible:
		census_key = ""
		fill_census()


# Chi va in ogni gruppo dell'elenco: i coloni (e i neonati), i forestieri (i coloni appena arrivati, i viandanti, i
# pretendenti), gli avventurieri alla locanda, e per ogni spedizione chi è partito (o sta partendo). Ognuno una volta sola
func census_groups() -> Dictionary:
	var trips := []
	var away := []
	for exp in expeditions:
		var members: Array = exp.left if not exp.left.is_empty() else exp.party + exp.dead  # di prima di `left`
		trips.append([exp, members])
		away.append_array(members)
	var home: Array = colonists.filter(func(c): return c not in away)
	var settled: Array = home.filter(func(c): return not c.conds.has(Cond.FOREIGNER))
	if ruler in settled:  # il sovrano per primo, anche dopo una successione
		settled.erase(ruler)
		settled.push_front(ruler)
	return {"colonists": settled + babies,
		"strangers": home.filter(func(c): return c.conds.has(Cond.FOREIGNER)) + guests.filter(func(g): return g.wanderer or g.suitor),
		"inn": guests.filter(func(g): return g.hero != Hero.NONE and g not in away), "trips": trips}


# Finestra degli abitanti (clic sul numero dei coloni in alto): un gruppo sotto l'altro, ognuno col suo titolo e quanti
# sono; per riga la figurina (col mouse sopra la scheda), il nome (cliccato apre la scheda), sesso ed età, cosa fa.
# Si rifà solo quando qualcuno cambia gruppo; cosa fa ognuno si aggiorna a ogni fotogramma
func fill_census() -> void:
	var groups := census_groups()
	var key := str([groups, groups["trips"].map(func(t): return t[0].left_at), ruler])
	if key == census_key:
		for row in census_rows:
			row[1].text = census_doing(row[0])
		return
	census_key = key
	census_rows.clear()
	var list: Control = $HUD/CensusPanel/Box/Scroll/List
	for child in list.get_children():
		child.free()
	var settled: Array = groups["colonists"]
	census_section(list, tr("Colonists (%d)") % settled.size(), settled, CENSUS_ACCENTS[0], "")
	census_section(list, tr("Foreigners (%d)") % groups["strangers"].size(), groups["strangers"], CENSUS_ACCENTS[1], tr("No foreigners."))
	census_section(list, tr("At the inn (%d)") % groups["inn"].size(), groups["inn"], CENSUS_ACCENTS[2], tr("Nobody at the inn."))
	var away: int = groups["trips"].reduce(func(n, t): return n + t[1].size(), 0)
	census_section(list, tr("On expeditions (%d)") % away, [], CENSUS_ACCENTS[3], tr("Nobody away.") if groups["trips"].is_empty() else "")
	for trip in groups["trips"]:
		var exp: Expedition = trip[0]
		var where := tr(RUINS[exp.ruin.kind]["name"])
		census_section(list, tr("Setting out for the %s") % where if exp.left_at < 0
			else tr("At the %s, due back by day %d") % [where, int(exp.due) + 1], trip[1], CENSUS_ACCENTS[3], "", true)
	$HUD/CensusPanel.reset_size()


# un gruppo dell'elenco: il titolo, poi un riquadro per persona (vedi census_card). `accent`: il colore del gruppo, sul
# titolo e sulla striscia a sinistra dei riquadri; `nobody`: il testo se non c'è nessuno; `sub`: un sottogruppo, la
# spedizione, col titolo più piccolo
func census_section(list: Control, title: String, people_of: Array, accent: Color, nobody: String, sub := false) -> void:
	var head := Label.new()
	head.text = title
	head.add_theme_color_override("font_color", accent.lightened(0.25) if sub else accent)
	head.add_theme_font_size_override("font_size", CENSUS_FONT[1] if sub else CENSUS_FONT[2])
	list.add_child(head)
	if people_of.is_empty():
		if nobody != "":
			var none := Label.new()
			none.text = nobody
			none.add_theme_color_override("font_color", CENSUS_DIM)
			list.add_child(none)
		return
	for c in people_of:
		list.add_child(census_card(c, accent))


# Il riquadro di `c` nell'elenco degli abitanti: fondo scuro, bordo di legno, a sinistra la striscia del gruppo. Dentro
# la figurina grande (col mouse sopra la scheda), il nome (cliccato apre la scheda) e sotto chi è; sesso ed età; cosa fa
# (si aggiorna a ogni fotogramma, vedi census_rows). Le colonne hanno la stessa larghezza in tutti i riquadri
func census_card(c: Colonist, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CENSUS_CARD
	style.border_color = CENSUS_BORDER
	style.set_border_width_all(2)
	style.border_width_left = 6
	style.set_content_margin_all(6)
	style.content_margin_left = 10
	card.add_theme_stylebox_override("panel", style)
	card.draw.connect(func():  # la striscia del gruppo, sopra il bordo di sinistra
		card.draw_rect(Rect2(0, 0, 6, card.size.y), accent))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var face: Control = ui_icon(BABY, Rect2(), Vector2(48, 48)) if c in babies else figure_icon(c, 3)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 2)
	who.custom_minimum_size.x = CENSUS_COLUMNS[0]
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name := Button.new()
	name.flat = true
	name.focus_mode = Control.FOCUS_NONE
	name.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.text = full_name(c)
	name.tooltip_text = "Open the sheet"
	name.add_theme_font_size_override("font_size", CENSUS_FONT[1])
	if c == ruler:
		name.icon = ICONS[Res.CROWN]
	name.pressed.connect(open_sheet.bind(c))
	who.add_child(name)
	var role := census_role(c)
	if role != "":
		var label := rich(role)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size.x = CENSUS_COLUMNS[0]
		label.add_theme_color_override("default_color", CENSUS_DIM)
		label.add_theme_font_size_override("normal_font_size", CENSUS_FONT[0])
		who.add_child(label)
	row.add_child(who)
	var sex := HBoxContainer.new()
	sex.custom_minimum_size.x = CENSUS_COLUMNS[1]
	sex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sex.add_child(ui_icon(SEX_ICONS[c.sex], Rect2(), Vector2(16, 16)))
	var age := Label.new()
	age.text = tr("%d years old") % age_of(c)
	age.add_theme_font_size_override("font_size", CENSUS_FONT[1])
	sex.add_child(age)
	row.add_child(sex)
	var now := Label.new()
	now.text = census_doing(c)
	now.custom_minimum_size.x = CENSUS_COLUMNS[2]
	now.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	now.autowrap_mode = TextServer.AUTOWRAP_WORD
	now.add_theme_font_size_override("font_size", CENSUS_FONT[1])
	row.add_child(now)
	census_rows.append([c, now])
	return card


# sotto il nome, chi è: il titolo del sovrano, l'erede, chi era avventuriero, il viandante, il pretendente,
# l'avventuriero con livello, paga e spedizioni, il colono in spedizione
func census_role(c: Colonist) -> String:
	if c in babies:
		return tr("Baby")
	if c.hero != Hero.NONE:
		return tr_n("%s, fee %s, %d expedition", "%s, fee %s, %d expeditions", c.trips) % [hero_name(c), coins(fee(c)), c.trips]
	if c == ruler:
		return tr("%s of %s") % [ruler_title(c), realm]
	if c == regent_for:
		return tr("Heir to the crown")
	if c.wanderer:
		return tr("Wanderer")
	if c.suitor:
		return tr("Suitor from the house of %s") % c.last_name
	if c.former != Hero.NONE:
		return tr("Once a %s") % named(Hero, c.former).to_lower()
	return ""


# cosa fa `c` nell'elenco, con quanto manca: da forestiero, all'attesa della risposta, alla partenza dalla locanda
func census_doing(c: Colonist) -> String:
	var text := doing(c)
	if c.conds.has(Cond.FOREIGNER):
		text += "\n" + tr("Foreigner for %.1f more days") % maxf(c.conds[Cond.FOREIGNER] - clock, 0.0)
	if c in guests and not c.hired and c.errand == Errand.NONE and c.stay_until > 0.0:
		text += "\n" + tr("Leaves in %.1f days") % maxf(c.stay_until - clock, 0.0)
	return text


# cosa sta facendo `c`, in poche parole: il neonato in culla o in braccio, a terra, il lavoro, la strada che fa, il
# sonno; senza lavoro, se aspetta (gli ospiti), se è il suo tempo libero
func doing(c: Colonist) -> String:
	if c in babies:
		var near = carrier_of(c)
		return tr("In the cradle", "doing") if c.cradle.x >= 0 else (tr("Carried by %s", "doing") % near.first_name if near != null else tr("In arms", "doing"))
	if c not in people():  # in spedizione: com'è andata la colonia lo sa al ritorno
		var exp := trip_of(c)
		return tr("Away on the expedition", "doing") if exp != null and exp.left_at >= 0 else tr("Away", "doing")
	if c.downed:
		return tr("Downed", "doing")
	match c.job:
		Job.TRAVEL:
			return tr(ERRAND_DOING.get(c.errand, "Walking"), "doing")
		Job.SLEEP:
			return tr("Sleeping", "doing") if in_bed(c) else tr("Sleeping on the ground", "doing")
		Job.HAUL:
			return tr("Hauling %s", "doing") % res_name(c.carry_res)
		Job.CRAFT:
			return tr("Making %s", "doing") % res_name(RECIPES[c.recipe][0])
		Job.BUILD, Job.FURNISH:
			var plan = plans_of(c.job).get(c.target)
			return tr("Building %s", "doing") % named(Build, plan[0]).to_lower() if plan != null else tr("Building", "doing")
		Job.RELAX:
			return tr("Training at the dummy", "doing") if c.work_total > 0 else tr("Relaxing", "doing")
		Job.NONE:
			if not request_of(c).is_empty():
				return tr("Waiting for your answer", "doing")
			if visitor(c):
				return tr("Waiting", "doing")
			return tr("Free time", "doing") if routines and activity(c) == Act.FREE else tr("Looking for something to do", "doing")
	return tr(DOING.get(c.job, "Busy"), "doing")


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
		kind_buttons[kind].visible = unlocked("builds", kind)
	$HUD/BuildBar/Row/Materials/Stone.visible = unlocked("materials", Res.STONE)
	$HUD/Tools/Row/Ice.visible = unlocked("rooms", RoomKind.ICEHOUSE)  # col tasto del ghiaccio, la ghiacciaia
	$HUD/Tools/Row/Garden.visible = unlocked("orders", Order.GARDEN)
	$HUD/Tools/Row/SoilLens.visible = researched.has(Tech.SOIL_SURVEY)
	if not researched.has(Tech.SOIL_SURVEY):
		$HUD/Tools/Row/SoilLens.button_pressed = false


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
	return named(Tech, t)


# perché `t` non si può studiare adesso, "" se si può: già fatta, le ricerche prima, i punti studio, il libro in magazzino
func research_block(t: Tech) -> String:
	var data: Dictionary = TECHS[t]
	if researched.has(t):
		return tr("Studied")
	for n in data.get("needs", []):
		if not researched.has(n):
			return tr("First: %s") % tech_name(n)
	if study < data["cost"]:
		return tr("%d more study") % ceili(data["cost"] - study)
	if data["tier"] > 1 and stored(BOOKS[data["tier"] - 2]) < 1:
		return tr("Needs a %s in a warehouse") % res_name(BOOKS[data["tier"] - 2])
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
	var names: Array = data.get("builds", []).map(func(b): return named(Build, b)) \
		+ data.get("makes", []).map(func(r): return named(Res, r, "item")) \
		+ data.get("materials", []).map(func(r): return tr("%s walls and floors") % named(Res, r, "item")) \
		+ data.get("rooms", []).map(func(k): return tr("the %s room") % named(RoomKind, k).to_lower()) \
		+ LAWS.keys().filter(func(law): return LAWS[law].get("needs", -1) == t).map(func(law): return tr("the law %s") % law_name(law))
	return tr("Unlocks: ") + ", ".join(names)


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
	var rate := AUTHORITY_PER_HOUR * (COURT_AUDIENCE if enacted.has(Law.COURT) else 1.0) * (PALACE[0] if researched.has(Tech.PALACE) else 1.0)
	if happy >= RULER_MOODS[0][0]:
		return rate * RULER_MOODS[0][1]
	if happy <= RULER_MOODS[1][0]:
		return rate * RULER_MOODS[1][1]
	return rate


# --- Ricerca: le leggi ---

func law_name(law: Law) -> String:
	return named(Law, law)


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
	if c.conds.has(Cond.FOREIGNER) and mood.has("foreigners"):
		return mood["foreigners"]
	if c.sworn and mood.has("sworn"):
		return mood["sworn"]
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


# La data del giorno `day` (contato da 0, come `clock`): "3 Thaw, Year 1", o la festa: "Flower Feast, Year 1"
@warning_ignore("integer_division")
func date(day: int) -> String:
	return tr("%s, Year %d") % [day_name(day), day / YEAR_DAYS + 1]


# La stagione del giorno `day`, indice di SEASONS: la festa è della stagione che chiude, il Capodanno della primavera
@warning_ignore("integer_division")
func season(day: int) -> int:
	return maxi(posmod(day, YEAR_DAYS) - 1, 0) / SEASON_DAYS


# il giorno `day` è fuori dai mesi: il Capodanno o la festa a fine stagione
func feast(day: int) -> bool:
	var d := posmod(day, YEAR_DAYS) - 1
	return d < 0 or d % SEASON_DAYS == 3 * MONTH_DAYS


# oggi è festa (riposo festivo, festa del raccolto): si cucina e basta, gli altri si svagano (vedi find_work)
func holiday() -> bool:
	var day := int(clock)
	return (enacted.has(Law.DAY_OF_REST) and day % REST_EVERY == REST_EVERY - 1) \
		or (enacted.has(Law.HARVEST_FEAST) and feast(day))


# Alla Festa del focolare, nella cronaca, i raccolti dell'anno a casella per coltura, con quelli dell'anno prima
func note_harvests() -> void:
	var y := year_of(today)
	var book: Dictionary = harvests.get(y, {})
	if book.is_empty():
		return
	var before: Dictionary = harvests.get(y - 1, {})
	var parts := PackedStringArray()
	for crop in Crop.values():
		if book.has(crop):
			var part: String = tr("%s %d a plot") % [tr(CROP_NAMES[crop]).to_lower(), roundi(float(book[crop][0]) / book[crop][1])]
			if before.has(crop):
				part += tr(" (last year %d)") % roundi(float(before[crop][0]) / before[crop][1])
			parts.append(part)
	note(tr("%s: the harvest of the year: %s.") % [date(today), ", ".join(parts)])


# All'alba di ogni giorno (a mezzanotte): la tassa di soggiorno di chi aspetta alla locanda, una moneta lì dov'è;
# chi è scontento toglie autorità. D'inverno niente raccolti: i cespugli perdono bacche e fiori di lino e li rifanno
# BERRY_REGROW giorni dopo Capodanno, nell'orto il gelo si prende quello che c'era. Finito un giorno di festa del calendario: la felicità e l'autorità della festa del
# raccolto; col granaio aperto un pasto a tutti, un pezzo del granaio a testa finché ce n'è
func new_day() -> void:
	for b in babies.duplicate():  # a CHILD_AGE il neonato diventa un bambino della colonia, accanto a chi lo teneva
		if age_of(b) >= CHILD_AGE:
			var near = carrier_of(b)
			if b.cradle.x >= 0 and furniture.get(b.cradle, [-1])[0] == Build.CRADLE:
				b.pos = center(b.cradle)
			elif near != null:
				b.pos = near.pos
			b.cradle = Vector2i(-1, -1)
			b.needs = Need.values().map(func(n): return 0.0 if n == Need.STRESS else NEED_MAX * 0.8)
			babies.erase(b)
			colonists.append(b)
	for c in colonists.duplicate():  # i compleanni: la maggiore età; dai OLD_AGE si può morire di vecchiaia
		var years := age_of(c)
		if years <= floori((today - 1 - c.born) / life_year()):
			continue
		if years == ADULT:
			c.beard = c.sex == Sex.MALE and randf() < BEARD_CHANCE
			if c.mother != null:
				note(tr("%s: %s comes of age.") % [date(today), full_name(c)])
			if c == regent_for:  # finisce la reggenza
				begin_reign(c)
				coronation()
		if years >= OLD_AGE and deaths and randf() < (years - OLD_AGE + 2) * OLD_AGE_RISK:
			die(c, tr("died of old age, at %d.") % years)
	if posmod(today, YEAR_DAYS) == 0 and today > 0:  # Capodanno: la terra dell'orto si riposa, di più dopo un anno senza raccolti
		for cell in garden:
			add_soil(cell, SOIL_WINTER + (SOIL_FALLOW if last_yield.get(cell, [-1])[0] < year_of(today) - 1 else 0))
		soil_year_ago = soil.duplicate()
	if feast(today) and season(today) == WINTER - 1:  # la Festa del focolare: il bilancio dei raccolti dell'anno
		note_harvests()
	if season(today) == WINTER:
		var spring: float = today - posmod(today, YEAR_DAYS) + YEAR_DAYS + BERRY_REGROW
		for cell in bushes:
			bushes[cell] = maxf(bushes[cell], spring)
		var frozen := garden.keys().filter(func(k): return garden[k] >= 0)
		for cell in frozen:  # il gelo si prende quello che è rimasto nei campi
			garden[cell] = -1.0
			sown.erase(cell)
		if not frozen.is_empty():
			note(tr_n("%s: the frost took %d plot of the garden.", "%s: the frost took %d plots of the garden.", frozen.size())
				% [date(today), frozen.size()])
	if enacted.has(Law.LODGING_TAX):
		for g in guests:
			if not g.wanderer and not g.hired and g.errand == Errand.NONE:  # i viandanti non hanno monete
				drop(Res.GOLD, cell_of(g.pos), 1)
	gain(-colonists.filter(func(c): return c.needs[Need.HAPPINESS] < UNHAPPY).size())
	if not feast(today - 1):
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
	make_compost()
	for c in colonists.duplicate():  # i parti, poi di notte il concepimento
		if c.due > 0.0 and clock >= c.due:
			give_birth(c)
	if hour % 24 == CONCEIVE_HOUR:
		for c in colonists:
			conceive(c)
	if coronation_at > 0.0 and clock >= coronation_at:  # finito il lutto regale
		coronation()
	place_babies()
	wear_roofs()
	melt_ice()
	ignite_roofs()
	for c in colonists:
		if c != ruler and c.needs[Need.HAPPINESS] < UNHAPPY and c.protested != today and not c.downed \
				and c.job not in [Job.SLEEP, Job.FIGHT, Job.FLEE, Job.TANTRUM, Job.PROTEST, Job.OATH] \
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
		how = tr(": into the stocks")
	elif enacted.has(Law.CLEMENCY):  # il sovrano lo ascolta
		add_cond(c, Cond.HEARD)
		how = tr(": the ruler listens")
	else:
		gain(PROTEST_AUTHORITY)
	note(tr("Day %d: %s protests in the throne room against %s%s.") % [int(clock) + 1, full_name(c),
		tr(" and ").join(enacted.filter(func(law): return law_mood_of(c, law) < 0).map(law_name)), how])


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
			out.append(tr("%s to %s") % [res_name(best), g.first_name])
	return out


# tornato dalla spedizione: i pezzi prestati in magazzino, i suoi di nuovo addosso
func give_back(g: Colonist) -> void:
	for slot in g.lent:
		store(g.gear[slot], 1, cell_of(g.pos))
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
	return tr("%s of %s") % [tr(TITLES[rank]["realm"]), realm]


# Il titolo, dove si vede: nella barra in alto il reame e lo stemma con la corona (anche nella scheda del sovrano, al
# doppio come lo scudo: la corona lo fa più alto)
func show_title() -> void:
	arms_tex = arms_texture(arms, rank)
	for icon in [$HUD/TopBar/Row/RealmIcon, $HUD/ColonistSheet/Box/Head/Arms]:
		icon.texture = arms_tex
		icon.custom_minimum_size = arms_tex.get_size() * 2
	realm_button.text = realm_name()
	realm_button.tooltip_text = "%s %s" % [ruler_title(ruler), full_name(ruler)]


# i coloni che contano per il titolo: quelli in colonia, figli compresi, e quelli in spedizione (non i neonati, che
# stanno in `babies`, né gli avventurieri)
func colony_size() -> int:
	return colonists.size() + away_colonists().size()


# i coloni fuori dalla mappa con la compagnia della corona: anche quelli morti nella rovina, finché non si sa
func away_colonists() -> Array:
	var out := []
	for exp in expeditions:
		out.append_array((exp.party + exp.dead).filter(func(c): return c.hero == Hero.NONE and c not in colonists))
	return out


# Compagnia della corona: i coloni che possono partire con gli avventurieri (adulti, non il sovrano né il reggente, non
# a terra né incinte, non già in viaggio o col giuramento da fare)
func volunteers() -> Array:
	if not researched.has(Tech.CROWN_COMPANY):
		return []
	return colonists.filter(func(c): return c != ruler and c != regent_for and age_of(c) >= ADULT and not c.downed \
		and c.due == 0.0 and not c.hired and c.errand == Errand.NONE and not c.oath)


# nella rovina: l'abilità con cui combatte, quanti colpi prende, e per l'avventuriero il resto della classe (HEROES).
# Chi era avventuriero combatte come la sua classe di un tempo; gli altri coloni con la migliore tra mischia e distanza
func role_of(c: Colonist) -> Dictionary:
	if c.hero != Hero.NONE:
		return HEROES[c.hero]
	if c.former != Hero.NONE:
		return {"weapon": HEROES[c.former]["weapon"], "hurt": HEROES[c.former]["hurt"]}
	return {"weapon": Skill.MELEE if c.skills[Skill.MELEE] >= c.skills[Skill.RANGED] else Skill.RANGED, "hurt": 1.0}


# Lo splendore e i coloni sono arrivati al titolo dopo: sale (mai giù). Nella cronaca e in una finestra al centro, coi sigilli in più
func rise() -> void:
	var was := realm_name()
	rank += 1
	show_title()
	laws_key = ""
	report(realm_name(), [tr("Day %d: the %s is now the %s.") % [int(clock) + 1, was, realm_name()],
		tr("%s %s. Seals: %d. Authority every day: +%d.") % [ruler_title(ruler), full_name(ruler),
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
		return tr("Codified")
	if LAWS[law].get("tier", 0) > rank:
		return tr("Needs a %s") % tr(TITLES[LAWS[law]["tier"]]["realm"]).to_lower()
	if LAWS[law].has("after") and not codified.has(LAWS[law]["after"]):
		return tr("First: %s") % law_name(LAWS[law]["after"])
	if LAWS[law].has("needs") and not researched.has(LAWS[law]["needs"]):
		return tr("Needs the research %s") % tech_name(LAWS[law]["needs"])
	if authority < LAWS[law]["cost"]:
		return tr("%d more authority") % ceili(LAWS[law]["cost"] - authority)
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
		return tr("Not codified yet")
	if enacted.has(law):
		return tr("In force")
	if revoked.get(law, 0.0) > clock:
		return tr("Revoked: again in %.1f days") % (revoked[law] - clock)
	if authority < ENACT_COST:
		return tr("%d more authority") % ceili(ENACT_COST - authority)
	if rival(law) == null and enacted.size() >= TITLES[rank]["seals"]:
		return tr("No free seal: revoke a law first")
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
	var who := mood.keys().map(func(k): return "%s %s" % [{"all": tr("everyone"), "guests": tr("adventurers"), "ruler": tr("the ruler"),
		"hunters": tr("bow carriers"), "foreigners": tr("foreigners"), "sworn": tr("the sworn")}.get(k,
		named(Trait, k).to_lower() if k is int else ""), signed(mood[k])])
	return tr(LAWS[law]["info"]) + (tr("\nHappiness: ") + ", ".join(who) if not who.is_empty() else "") \
		+ (tr("\nNeeds a %s") % tr(TITLES[LAWS[law]["tier"]]["realm"]).to_lower() if LAWS[law].get("tier", 0) > 0 else "") \
		+ (tr("\nAfter %s") % law_name(LAWS[law]["after"]) if LAWS[law].has("after") else "") \
		+ (tr("\nNeeds the research %s") % tech_name(LAWS[law]["needs"]) if LAWS[law].has("needs") else "")


# Finestra Knowledge (tasto in basso, o clic su uno scrittoio): studio e libri, poi l'albero, una riga per ramo e una
# colonna per livello. Ogni ricerca è un pulsante: col mouse sopra cosa sblocca e cosa manca, cliccato la studia.
# Si rifà solo quando cambia qualcosa, se no i pulsanti non si premono
func fill_knowledge() -> void:
	var key := str([floori(study), BOOKS.map(stored), researched.keys(), scholar_until, scholar_books, scholar_bought, stored(Res.GOLD)])
	if key == knowledge_key:
		return
	knowledge_key = key
	var box: Control = $HUD/KnowledgePanel/Box
	box.get_node("Study").text = tr("%d [img=center]%s[/img] study    %s") % [floori(study), STUDY_ICON.resource_path,
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
		title.text = named(Branch, branch, "branch")
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
	row.add_child(rich(tr("A wandering scholar at the inn, until day %d:") % (int(scholar_until) + 1)))
	for i in scholar_books.size():
		var book: Res = scholar_books[i]
		var buy := Button.new()
		buy.focus_mode = Control.FOCUS_NONE
		buy.text = tr("Buy %s: %d") % [res_name(book), BOOK_PRICE[book]]
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
			sell.text = tr("Sell a %s: %d") % [res_name(book), BOOK_PRICE[book] / 2]
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
	var cost := tr("%d study%s") % [data["cost"], "" if data["tier"] == 1 else " + 1 " + res_name(BOOKS[data["tier"] - 2])]
	button.text = "%s\n%s" % [tech_name(t), tr("studied") if researched.has(t) else cost]
	var block := research_block(t)
	button.disabled = block != ""
	if researched.has(t):
		button.modulate = SPLENDOR_COLOR.lightened(0.4)
	elif data.get("needs", []).any(func(n): return not researched.has(n)):
		button.modulate = Color(1, 1, 1, 0.5)
	button.tooltip_text = "%s\n%s%s" % [tr(data["info"]), unlocks_text(t), "" if block in ["", tr("Studied")] else "\n" + block]
	button.pressed.connect(research.bind(t))
	return button


# Finestra Laws (tasto in basso, o clic sul trono): autorità, sigilli e granaio; poi le leggi per categoria, ognuna col
# suo pulsante (codifica, promulga, revoca). Col mouse sopra cosa fa e a chi piace. Si rifà quando cambia qualcosa
func fill_laws() -> void:
	var thrones := rooms.filter(func(r): return r.kind == RoomKind.THRONE_ROOM).size()
	var splendor := colony_splendor()
	var key := str([floori(authority), codified.keys(), enacted, revoked, granary, researched.keys(), thrones, floori(clock), rank, splendor, colony_size()])
	if key == laws_key:
		return
	laws_key = key
	var box: Control = $HUD/LawsPanel/Box
	var stock := granary.keys().filter(func(r): return granary[r] > 0).map(func(r): return amount_text(r, granary[r]))
	var next := "" if rank == TITLES.size() - 1 else tr(": a %s at %d splendor and %d colonists (now %d and %d)") % [
		tr(TITLES[rank + 1]["realm"]).to_lower(), TITLES[rank + 1]["splendor"], TITLES[rank + 1]["colonists"], splendor, colony_size()]
	box.get_node("Authority").text = tr("%s%s\n%d [img=center]%s[/img] authority    Seals: %d / %d\nGranary: %s") % [realm_name(), next,
		floori(authority), AUTHORITY_ICON.resource_path, enacted.size(), TITLES[rank]["seals"], ", ".join(stock) if not stock.is_empty() else tr("empty")]
	box.get_node("Hint").visible = thrones == 0
	var list: Control = box.get_node("Scroll/List")
	for child in list.get_children():
		child.free()
	for kind in LawKind.values():
		var title := Label.new()
		title.text = named(LawKind, kind)
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
				button.tooltip_text = tr("Free; then it cannot be enacted again for %d days") % REVOKE_WAIT
				button.pressed.connect(revoke.bind(law))
			elif codified.has(law):
				var block := enact_block(law)
				var other = rival(law)
				button.text = tr("Enact (%d)") % ENACT_COST
				button.disabled = block != ""
				button.tooltip_text = block if block != "" else (tr("Takes the place of %s") % law_name(other) if other != null else "Takes a seal")
				button.pressed.connect(enact.bind(law))
			else:
				var block := codify_block(law)
				button.text = tr("Codify (%d)") % LAWS[law]["cost"]
				button.disabled = block != ""
				button.tooltip_text = block if block != "" else "Once codified, it can be enacted"
				button.pressed.connect(codify.bind(law))
			row.add_child(button)
			list.add_child(row)
	$HUD/LawsPanel.reset_size()


# --- Pesca e caccia ---

# punti di pesca segnati dove ci sono pesci
func fishable() -> Array:
	if atmosphere.frozen:  # sotto il ghiaccio niente pesca
		return []
	return fish_marks.keys().filter(func(k): return fish_spots.get(k, 0.0) <= clock)


# L'acqua gela o sgela (vedi atmosphere.gd): gelata, l'acqua alta regge e quella bassa non rallenta più; non si pesca
# (vedi fishable). Sgelata, chi sta sull'acqua alta torna a riva e chi doveva passarci cerca un'altra strada
func freeze_water(on: bool) -> void:
	for cell in water:
		if water[cell] == Ground.DEEP:
			astar.set_point_solid(cell, not on)
		else:
			astar.set_point_weight_scale(cell, 1.0 if on else SHALLOW_COST)
	if on:
		return
	for o in people() + animals:
		var here := cell_of(o.pos)
		if water.get(here) == Ground.DEEP:  # ponytail: a riva d'un colpo; a nuoto se capita di vederlo
			var shore := []
			var reach := 1
			while shore.is_empty():  # la riva più vicina, in quadrati sempre più grandi
				shore = cells_in(Rect2i(here - Vector2i.ONE * reach, Vector2i.ONE * (2 * reach + 1))) \
					.filter(func(k): return astar.is_in_boundsv(k) and not astar.is_point_solid(k))
				reach += 1
			sort_by_distance(shore, o.pos)
			o.pos = center(shore[0])
			o.path.clear()
		elif o.path.any(func(k): return water.get(k) == Ground.DEEP):
			if o is Colonist:
				o.path = path_of(o, here, o.path.back())
			else:
				o.path.clear()


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
# quello che aveva in mano; non chi ha le mani scelte nella scheda. false se non c'è niente da cacciare, nessun arco
# o non ci si arriva.
func try_hunt(c: Colonist) -> bool:
	var prey := animals.filter(func(a): return a.marked and a.hunter == null and a.blocked <= clock \
		and not (a.kind == Beast.DEER and enacted.has(Law.HUNTING_RESERVE) and c != ruler and not has_bow(c)))  # riserva
	if prey.is_empty():
		return false
	if not has_bow(c):
		return not c.loadout.has(Slot.HANDS) and take(c, Res.BOW)
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
		return ICE_PER_SPOT if atmosphere.frozen else FISH_PER_SPOT
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


# mucchi (a terra o in magazzino), non prenotati da altri, da cui prendere un materiale che manca al progetto in
# `origin` di `job`: cella del mucchio -> risorsa
func sources(job: Job, origin: Vector2i) -> Dictionary:
	var found := {}
	var need := missing(job, origin)
	for res in need:
		for cell in items[res]:
			if items[res][cell] >= need[res] and is_free(cell):
				found[cell] = res
	return found


# materiale che serve a `plan`: risorsa -> quantità
func cost_of(plan: Array) -> Dictionary:
	var cost = BUILD_COST[plan[0]]
	return cost.duplicate() if cost is Dictionary else {plan[1]: cost}


# materiale che manca al progetto in `origin` di `job`: ogni viaggio porta tutto quello di una risorsa
func missing(job: Job, origin: Vector2i) -> Dictionary:
	var need := cost_of(plans_of(job)[origin])
	for res in delivered.get([job, origin], {}):
		need.erase(res)
	return need


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
			if o.job in [Job.BUILD, Job.FURNISH, Job.COOK, Job.CRAFT, Job.STUDY, Job.GOVERN, Job.REPAIR, Job.FERTILIZE]:
				cells[o.dest] = true
	return cells


func sort_by_distance(cells: Array, from: Vector2) -> void:
	cells.sort_custom(func(a, b): return center(a).distance_squared_to(from) < center(b).distance_squared_to(from))


func is_free(cell: Vector2i) -> bool:
	return not reserved.has(cell)


# celle di magazzino che possono ricevere `res`: libere, vuote o con la stessa risorsa non piena
func dest_cells(res: Res) -> Array:
	var pits := pit_cells()
	var heaps := heap_cells()
	if res == Res.ROT:  # il marcio solo nei cumuli del compost, e nei cumuli solo lui
		return heaps.keys().filter(func(cell): return (is_free(cell) and items[Res.ROT].get(cell, 0) < STACK_MAX[Res.ROT]
			and items.keys().all(func(r): return r == Res.ROT or not items[r].has(cell))))
	return stockpile.keys().filter(func(cell):
		if heaps.has(cell):
			return false
		if (res == Res.ICE) != pits.has(cell):  # il ghiaccio solo nelle fosse, e nelle fosse solo lui
			return false
		if pantry.has(cell) and not SHELF_LIFE.has(res) and res != Res.ICE:  # in dispensa solo quello che marcisce
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


# Il cibo a terra invecchia di `days` giorni, più piano in magazzino e al freddo (vedi spoil_rate); finiti, il mucchio marcisce
# e sparisce. Chi ci stava andando lo trova vuoto e lascia perdere.
# ponytail: quello in mano non invecchia (lo si tiene poco); il marcio non lascia niente: se serve un mucchio da buttare
func spoil(days: float) -> void:
	var memo := {}  # stanza -> gradi: tanti mucchi nella stessa stanza
	var heaps := heap_cells()
	for cell in fresh.keys():
		if heaps.has(cell):  # nel cumulo il marcio non sparisce: diventa compost (vedi make_compost)
			continue
		fresh[cell] -= days * spoil_rate(cell, memo)
		if fresh[cell] <= 0:
			var rotten := 0
			for res in SHELF_LIFE:
				if res != Res.ROT:
					rotten += items[res].get(cell, 0)
				items[res].erase(cell)
			fresh.erase(cell)
			if rotten > 0 and composting():  # il cibo marcio va al cumulo
				drop(Res.ROT, cell, rotten)


# c'è dove fare il compost: allora il cibo marcio e le erbacce estirpate diventano marcio da portarci (senza cumulo
# spariscono come prima, e non ingombrano)
func composting() -> bool:
	return researched.has(Tech.MANURING) and furniture.values().any(func(f): return f[0] == Build.COMPOST_HEAP)


# i cumuli del compost (una casella ciascuno)
func heap_cells() -> Dictionary:
	var cells := {}
	for origin in furniture:
		if furniture[origin][0] == Build.COMPOST_HEAP:
			cells[origin] = true
	return cells


# Un'ora nei cumuli del compost: il marcio arrivato comincia a maturare; dopo COMPOST_DAYS ogni ROT_PER_COMPOST diventano
# un compost, accanto al cumulo; quello che avanza ricomincia
@warning_ignore("integer_division")
func make_compost() -> void:
	for cell in heap_cells():
		if not items[Res.ROT].has(cell):
			compost_since.erase(cell)
		elif not compost_since.has(cell):
			compost_since[cell] = clock
		elif clock - compost_since[cell] >= COMPOST_DAYS:
			var made: int = items[Res.ROT][cell] / ROT_PER_COMPOST
			if made > 0:
				add_item(Res.ROT, cell, -made * ROT_PER_COMPOST)
				drop(Res.COMPOST, cell, made)
			compost_since.erase(cell)


# quanto in fretta marcisce il cibo in `cell`: a metà in magazzino; in proporzione ai gradi, al ritmo pieno a ROOM_TEMP
# (il doppio al doppio dei gradi: il caldo fa marcire), sotto lo zero per niente (gela). Un magazzino freddo è una
# dispensa; il fuoco la scalda
func spoil_rate(cell: Vector2i, memo := {}) -> float:
	var warm := maxf(temperature_at(cell, memo), 0.0) / ROOM_TEMP
	if holed(cell):  # sotto un buco nel tetto come fuori
		return warm
	return (SPOIL_PANTRY if pantry.has(cell) else (SPOIL_STORED if stockpile.has(cell) else 1.0)) * warm


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
		Order.ICE:
			for cell in water:
				if rect.has_point(cell):
					ice_marks[cell] = true
		Order.GARDEN:  # sul prato libero, fuori dalle stanze; le piante prima si estirpano
			for cell in cells_in(rect):
				if can_plant(cell):
					garden[cell] = -1.0
			update_fields()
		Order.HUNT:  # una casella di margine: si muovono
			for a in animals:
				if rect.grow(1).has_point(cell_of(a.pos)):
					a.marked = true
		Order.BUILD:  # nel progetto; i muri solo sul bordo del rettangolo: trascinando si disegna una stanza
			if FURNITURE.has(build_kind):  # un mobile per volta, girato di build_turn, dall'angolo del rettangolo
				var plan := [build_kind, build_res, build_turn]
				if piece_fits(rect.position, plan):
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
		Order.DEMOLISH:  # subito, senza recuperare il materiale; anche l'orto, con quello che ci cresce
			for cell in garden.keys().filter(func(k): return rect.has_point(k)):
				garden.erase(cell)
				sown.erase(cell)
				plans.erase(cell)
				manured.erase(cell)
				no_manure.erase(cell)
				drop_job(cell, Job.FARM)
			update_fields()
			for cell in built.keys().filter(func(k): return rect.has_point(k)):
				if built[cell][0] in BARRIERS:
					astar.set_point_solid(cell, false)
				if built[cell][0] == Build.ROAD:
					astar.set_point_weight_scale(cell, 1.0)
				built.erase(cell)
				plastered.erase(cell)
			for origin in furniture.keys().filter(func(o): return rect.intersects(piece_rect(o, furniture[o]))):
				furniture.erase(origin)
			update_rooms()


# toglie la casella dal progetto, anche già confermato, coi mobili che la coprono
func erase_plan(cell: Vector2i) -> void:
	draft.erase(cell)
	if blueprints.erase(cell):
		drop_job(cell, Job.BUILD)
		give_back_delivered(Job.BUILD, cell)
	for origin in pieces_at(furniture_draft, cell):
		furniture_draft.erase(origin)
	for origin in pieces_at(furniture_plans, cell):
		furniture_plans.erase(origin)
		drop_job(origin, Job.FURNISH)
		give_back_delivered(Job.FURNISH, origin)


# progetto tolto: il materiale già portato al cantiere torna a terra, i trasportatori lo riportano in magazzino
func give_back_delivered(job: Job, origin: Vector2i) -> void:
	var got: Dictionary = delivered.get([job, origin], {})
	for res in got:
		drop(res, origin, got[res])
	delivered.erase([job, origin])


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
	if kind == Build.PLASTER:  # sopra un muro di legno già fatto, non ancora intonacato
		return built.get(cell, [-1, -1]) == [Build.WALL, Res.WOOD] and not plastered.has(cell) and not blueprints.has(cell)
	if not (astar.is_in_boundsv(cell) and not astar.is_point_solid(cell) and not water.has(cell) and not trees.has(cell) \
			and not bushes.has(cell) and not weeds.has(cell) and not garden.has(cell) \
			and items.values().all(func(ground): return not ground.has(cell))):
		return false
	var furnished := [furniture, furniture_plans, furniture_draft].any(func(l): return not pieces_at(l, cell).is_empty())
	if FURNITURE.has(kind):
		return not furnished and [built, blueprints, draft].all(func(l): return l.get(cell, [Build.FLOOR])[0] in PAVING)
	return not built.has(cell) and not blueprints.has(cell) and (kind in PAVING or not furnished)


func build(cell: Vector2i) -> void:
	if blueprints[cell][0] == Build.PLASTER:  # il muro resta quello che è, intonacato
		blueprints.erase(cell)
		if built.get(cell, [-1])[0] == Build.WALL:
			plastered[cell] = true
		return
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
				room.name = tr("Structure%d") % rooms_made
			room.cells = cells
			room.door = door
			# cartello sul muro accanto alla porta: a destra o sotto, se no dall'altra parte; senza muri, fuori davanti
			var across := Vector2i(absi(side.y), absi(side.x))
			var walls := [door + across, door - across].filter(func(k): return built.get(k, [-1])[0] == Build.WALL)
			room.sign = walls[0] if not walls.is_empty() else front
			if not room_meets(room, room.kind):  # abbattuto un mobile che serviva: torna senza tipo, e senza proprietari
				retype(room, RoomKind.NONE)
			rooms.append(room)
	update_roofs()
	update_stockpile()


# Tetti da soli, come le stanze: sopra ogni stanza e i muri e le porte che la toccano, anche di sbieco, in rettangoli
# (una stanza a L ne fa due). Ogni rettangolo ha il suo tetto con la facciata, fatto da roofs.gd (Roof.look): il colmo
# lungo il lato lungo, scandole o coppi secondo i muri della stanza (roof_material), finestre e porta in facciata, il
# timpano; quelli che non cambiano non si rifanno.
func update_roofs() -> void:
	var cover := {}  # nuovo ogni volta: atmosphere.gd se ne accorge e rifà la maschera della neve
	var made: Array[Roof] = []
	for room in rooms:
		var cells := {}  # un muro in comune lo coprono i tetti di tutte e due le stanze (vedi draw_house)
		for cell in room.cells:
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var k: Vector2i = cell + Vector2i(dx, dy)
					if room.cells.has(k) or built.get(k, [Build.FLOOR])[0] not in PAVING:
						cells[k] = true
		var spot: int = absi(hash(room.cells.keys().min()))
		var shade := 1.0 - ROOF_TINT * (spot % 5) / 4.0
		for rect in rectangles(cells):
			var roof := Roof.new()
			roof.rect = rect
			roof.material = roof_material(room)
			roof.tint = Color(shade, shade * (1.0 - ROOF_TINT / 4.0 * (spot / 5 % 3)), shade)
			roof.room = room
			roof.look = roof_look(rect, room, roof.material)
			roof.vertical = not roof.look["along_x"]
			for k in cells_in(rect):
				if not cover.has(k):  # per i conti basta un tetto; il muro in comune va alla prima stanza
					cover[k] = roof
			made.append(roof)
	made.sort_custom(func(a, b): return a.rect.position.y < b.rect.position.y)  # sopra il muro in comune quello più a sud
	roofs = made
	var used := {}  # quelli che non ci sono più si buttano
	for roof in roofs:
		used[roof.look["key"]] = roof.look
	made_roofs = used
	roofs_drawn = roofs.duplicate()
	roofs_drawn.sort_custom(func(a, b): return a.look["base"] < b.look["base"])
	shown_roof = {}
	for roof in roofs_drawn:  # quello disegnato dopo copre l'altro
		for k in cells_in(roof.rect):
			shown_roof[k] = roof
	roofed = cover
	for k in wear.keys():  # stanza abbattuta: la sua usura se ne va col tetto
		if not cover.has(k):
			wear.erase(k)


# Un'ora di usura dei tetti (vedi LICHEN): il tempo, i temporali, la neve pesante. Un temporale che strappa un tetto
# finisce nella cronaca, una volta al giorno per stanza
func wear_roofs() -> void:
	var holes := holes_count()
	for cell in roofed:
		var spread := 1.0 - ROOF_SPREAD + ROOF_SPREAD * 2.0 * (absi(hash(cell)) % 100) / 100.0
		wear[cell] = wear.get(cell, 0.0) + spread / ROOF_LIFE[roofed[cell].material] / 24.0
	for roof in roofs:
		var tear := 0
		if atmosphere.climate and atmosphere.weather == atmosphere.Weather.STORM \
				and randf() < STORM_TEAR * atmosphere.weather_strength:
			tear = randi_range(1, 3)
		elif atmosphere.climate and atmosphere.snow > SNOW_LOAD and roof.rect.get_area() >= SNOW_LOAD_AREA \
				and roof_snow(roof) > 0.5 and randf() < SNOW_LOAD_HIT:
			tear = 1
		for i in tear:
			var cell := roof.rect.position + Vector2i(randi() % roof.rect.size.x, randi() % roof.rect.size.y)
			wear[cell] = wear.get(cell, 0.0) + randf_range(STORM_DAMAGE[0], STORM_DAMAGE[1]) * (2.0 if roof.material == Res.WOOD else 1.0)
		if tear > 0 and atmosphere.weather == atmosphere.Weather.STORM and storm_noted.get(roof.room) != today:
			storm_noted[roof.room] = today
			note(tr("%s: the storm tore tiles off the roof of %s.") % [date(today), roof.room.name])
	if holes_count() != holes:
		roof_stamp += 1


func holes_count() -> int:
	return wear.keys().filter(func(k): return wear[k] >= 1.0).size()


# in `cell` il tetto ha un buco: ci piove e nevica dentro, fa i gradi di fuori
func holed(cell: Vector2i) -> bool:
	return wear.get(cell, 0.0) >= 1.0


# Un'ora: i fuochi da campo sotto le scandole e i fulmini dei temporali possono accendere un tetto (vedi FIRE_DAILY)
func ignite_roofs() -> void:
	if not fire_risk:
		return
	for origin in furniture:
		if furniture[origin][0] == Build.CAMPFIRE and flammable(origin) and randf() < FIRE_DAILY / 24.0:
			ignite(origin)
	if atmosphere.climate and atmosphere.weather == atmosphere.Weather.STORM:
		for roof in roofs:
			if roof.material == Res.WOOD and randf() < LIGHTNING_HIT * atmosphere.weather_strength:
				ignite(roof.rect.position + Vector2i(randi() % roof.rect.size.x, randi() % roof.rect.size.y))


# sotto `cell` c'è un tetto di scandole che può bruciare: non già in fiamme, non già un buco
func flammable(cell: Vector2i) -> bool:
	return roofed.has(cell) and roofed[cell].material == Res.WOOD and not burning.has(cell) and not holed(cell)


# Il tetto in `cell` prende fuoco: nella cronaca (una volta al giorno per stanza); chi dorme si sveglia e chi lavora
# molla il lavoro, per spegnerlo
func ignite(cell: Vector2i) -> void:
	if not flammable(cell):
		return
	burning[cell] = BURN_HOURS
	var room: Room = roofed[cell].room
	if fire_noted.get(room) != today:
		fire_noted[room] = today
		note(tr("%s: fire! The roof of %s is burning.") % [date(today), room.name])
	for c in colonists:
		if c.job == Job.SLEEP and not c.downed and c.needs[Need.REST] > EXHAUSTED:
			end_job(c)
		elif c.job in WORK_JOBS:
			quit_job(c)


# Il fuoco va avanti di `delta` secondi: ogni casella brucia (finita, è un buco) e passa alle scandole accanto
func burn(delta: float) -> void:
	if burning.is_empty():
		return
	var hours := delta / DAY_LENGTH * 24.0
	for cell in burning.keys():
		if not roofed.has(cell):  # la stanza non c'è più
			burning.erase(cell)
			continue
		burning[cell] -= hours
		for side in SIDES:
			if flammable(cell + side) and randf() < FIRE_SPREAD * hours:
				ignite(cell + side)
		if burning[cell] <= 0:
			burning.erase(cell)
			wear[cell] = maxf(wear.get(cell, 0.0), 1.0 + FIRE_SCAR)
			roof_stamp += 1
	if burning.is_empty():
		note(tr("%s: the fire is out.") % date(today))


# Un secchio d'acqua sul fuoco più vicino: dall'acqua (riva o acqua bassa), poi accanto alla casella che brucia (vedi
# Job.DOUSE). Prima di tutto il resto, per tutti i coloni. false se non c'è fuoco o non ci si arriva
func try_douse(c: Colonist) -> bool:
	if burning.is_empty():
		return false
	var stands := {}
	for cell in burning:
		add_stands(stands, [cell], cell, SIDES)
	var to_fire := path_to_nearest(c, stands.keys())
	if to_fire.is_empty():
		return false
	c.job = Job.DOUSE
	c.target = stands[to_fire.back()]
	c.dest = to_fire.back()
	c.work_left = BUCKET_TIME
	c.work_total = BUCKET_TIME
	if c.bucket:
		c.path = to_fire
		return true
	var to_water := path_to_nearest(c, water_stands())
	if to_water.is_empty():
		c.job = Job.NONE
		return false
	c.path = to_water
	return true


# dove si riempie un secchio: l'acqua bassa e le caselle accanto all'acqua
func water_stands() -> Array:
	var out := {}
	for w in water:
		if not astar.is_point_solid(w):
			out[w] = true
		for side in SIDES:
			var k: Vector2i = w + side
			if astar.is_in_boundsv(k) and not astar.is_point_solid(k) and not water.has(k):
				out[k] = true
	return out.keys()


# Le caselle `cells` in rettangoli: dall'alto a sinistra, ognuno largo quanto la sua prima riga e giù finché le righe
# sono piene. Una stanza rettangolare coi suoi muri è un rettangolo solo, una a L due
func rectangles(cells: Dictionary) -> Array[Rect2i]:
	var left := cells.duplicate()
	var order := cells.keys()
	order.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var out: Array[Rect2i] = []
	for start in order:
		if not left.has(start):
			continue
		var w := 1
		while left.has(start + Vector2i(w, 0)):
			w += 1
		var h := 1
		while range(w).all(func(dx): return left.has(start + Vector2i(dx, h))):
			h += 1
		var rect := Rect2i(start, Vector2i(w, h))
		for k in cells_in(rect):
			left.erase(k)
		out.append(rect)
	return out


# il materiale del tetto: quello della maggioranza dei muri della stanza (le porte contano come legno), alla pari legno
func roof_material(room: Room) -> Res:
	var stone := 0
	var wood := 0
	for k in room_walls(room):
		var b: Array = built.get(k, [-1, -1])
		if b[0] == Build.WALL and b[1] == Res.STONE:
			stone += 1
		elif b[0] in [Build.WALL, Build.DOOR]:
			wood += 1
	return Res.STONE if stone > wood else Res.WOOD


# com'è fatto il tetto sul rettangolo `rect` della stanza `room` (vedi ROOFS.bake): la fila in fondo fa la facciata,
# lì niente finestra dov'è il cartello. Da made_roofs se c'è già
func roof_look(rect: Rect2i, room: Room, material: int) -> Dictionary:
	var front := []
	for x in range(rect.position.x, rect.end.x):
		var plan: Array = built.get(Vector2i(x, rect.end.y - 1), [Build.FLOOR])
		if plan[0] in [Build.DOOR, Build.GATE]:
			front.append(ROOFS.Front.DOOR)
		elif plan[0] in [Build.WALL, Build.PALISADE]:
			front.append(ROOFS.Front.STONE if plan[1] == Res.STONE else ROOFS.Front.WOOD)
		else:
			front.append(ROOFS.Front.NONE)
	var sign_col := room.sign.x - rect.position.x if room.sign.y == rect.end.y - 1 and rect.has_point(room.sign) else -1
	var mat: int = ROOFS.Mat.COPPI if material == Res.STONE else ROOFS.Mat.SHINGLE
	var key := str([rect, front, sign_col, mat])
	if made_roofs.has(key):
		return made_roofs[key]
	var look: Dictionary = ROOFS.new().bake(rect, front, sign_col, mat)
	look["key"] = key
	look["tex"] = ImageTexture.create_from_image(look["image"])
	look["snow_tex"] = ImageTexture.create_from_image(look["snowy"])
	look["cut"] = ""
	made_roofs[key] = look
	return look


# 0..1, quanta della neve di fuori resta sul tetto: il calore che sale dalla stanza (quanto è più calda di fuori, per
# quanto poco isola) la scioglie; ROOF_MELT gradi di calore che passa la sciolgono tutta
func roof_snow(roof: Roof) -> float:
	if roof.room == null or not atmosphere.climate:
		return 1.0
	var leak := (room_temperature(roof.room) - atmosphere.temperature()) * (1.0 - insulation(roof.room))
	return clampf(1.0 - leak / ROOF_MELT, 0.0, 1.0)


func update_stockpile() -> void:
	stockpile.clear()
	pantry.clear()
	for room in rooms:
		if room.kind in [RoomKind.WAREHOUSE, RoomKind.PANTRY, RoomKind.ICEHOUSE]:
			stockpile.merge(room.cells)
		if room.kind in [RoomKind.PANTRY, RoomKind.ICEHOUSE]:  # la ghiacciaia è una dispensa
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

# trascinare col destro sposta la telecamera prima che l'interfaccia prenda il mouse: anche sopra le finestre e col
# menù delle opzioni aperto (rotella e due dita passano già quando la finestra sotto non ha niente da scorrere)
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		camera.position -= event.relative / camera.zoom


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
					elif garden.has(cell):
						open_field(cell)
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
		Build.WALL: return tile_rect(links, PLASTER_ROW if plastered.has(cell) and plan[1] == Res.WOOD else plan[1])
		Build.PLASTER: return tile_rect(links, PLASTER_ROW)
		Build.FLOOR: return tile_rect(plan[1], 2)
		Build.PATH: return tile_rect(2, 2)
		Build.ROAD: return tile_rect(3, 2)
		Build.PALISADE: return tile_rect(links, 8)
		_: return tile_rect(1 if links & 5 and not links & 10 else 0, 3 if plan[0] == Build.DOOR else 9)  # porta, cancello: di lato se ha muri solo sopra e sotto


func draw_flat() -> void:  # sotto le ombre: il terreno lo disegna lo Sprite2D di bake_ground
	for cell in weeds:  # basse: niente ombra
		flat.draw_texture_rect_region(PLANTS, tile_rect(cell.x, cell.y), tile_rect(0, 0))
	draw_garden()
	for cell in built:
		if built[cell][0] in PAVING:
			flat.draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), structure_src(cell, built[cell], [built]))
			draw_grass_over(cell)
	var plans := [built, blueprints, draft]  # i progetti si collegano anche ai muri già fatti
	for cell in blueprints:  # in trasparenza (l'intonaco sopra il muro, vedi _draw)
		if blueprints[cell][0] == Build.PLASTER:
			continue
		flat.draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), structure_src(cell, blueprints[cell], plans),
			Color(1, 1, 1, 0.4))
	for cell in draft:  # velati d'azzurro, da confermare
		if draft[cell][0] == Build.PLASTER:
			continue
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


# L'orto: la terra lavorata, e quello che ci cresce: germoglio nel primo terzo, poi la pianta, poi matura
func draw_garden() -> void:
	for cell in garden:
		var r := Rect2(tile_rect(cell.x, cell.y))
		flat.draw_texture_rect_region(CROPS, r, tile_rect(0, 0))
		if garden[cell] >= 0:
			var grown: float = (clock - garden[cell]) / CROP_DAYS[crop_of(cell)]
			var stage := 2 if grown >= 1.0 else (1 if grown >= 1.0 / 3.0 else 0)
			var poor := clampf((50.0 - soil_at(cell)) / 50.0, 0.0, 1.0)  # su terra povera, smorte
			var crop := crop_of(cell)  # il sovescio: fave, che si interrano in fiore
			var frame := 1 + mini(crop, Crop.BEANS) * 3 + (mini(stage, 1) if crop == Crop.GREEN else stage)
			flat.draw_texture_rect_region(CROPS, r, tile_rect(frame, 0), Color.WHITE.lerp(SOIL_PALE, poor))


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
	for layer in [blueprints, draft]:  # l'intonaco in progetto, sopra il suo muro
		for cell in layer:
			if layer[cell][0] == Build.PLASTER:
				draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), structure_src(cell, layer[cell], [built]),
					Color(1, 1, 1, 0.5 if layer == blueprints else 0.7))
				if layer == draft:
					draw_rect(tile_rect(cell.x, cell.y), Color(0.55, 0.8, 1, 0.45))
	for cell in boulders:  # stanno dentro le loro caselle: niente ordine per righe
		draw_texture(boulder_tex(cell), Vector2(cell) * TILE)
	for cell in bushes:  # bassi, dentro la loro casella come i massi; con le bacche (o i fiori) se sono maturi
		draw_texture_rect_region(PLANTS, tile_rect(cell.x, cell.y), tile_rect(plant_col(cell) + (1 if bushes[cell] <= clock else 0), 0))
	draw_pieces(self, FURNITURE_NIGHT if sun_height() < 0 else FURNITURE_SHEET, furniture)
	for b in babies:  # nella culla
		if b.cradle.x >= 0 and furniture.get(b.cradle, [-1])[0] == Build.CRADLE:
			draw_texture_rect(BABY, tile_rect(b.cradle.x, b.cradle.y), false)
	for origin in furniture:  # stendardi: sopra il drappo rosso, quello della casata (stesso fotogramma)
		if furniture[origin][0] == Build.BANNER:
			var r := piece_rects(origin, furniture[origin])
			draw_texture_rect_region(banner_tex, r[0], Rect2(r[1].position.x / 32 * TILE, 0, TILE, TILE))
	for room in rooms:  # cartelli: si cliccano per nome e tipo della stanza
		draw_texture(SIGN, Vector2(room.sign) * TILE)
	for cell in field_signs:  # e quelli dei campi: coltura e rotazione
		draw_texture(FIELD_SIGN, Vector2(cell) * TILE + Vector2(0, -6))

	# alberi, coloni e tetti dall'alto in basso: chi sta più giù copre chi gli sta dietro
	# ponytail: si affida a `trees` già in ordine di riga; se gli alberi ricrescono, ordinarli o passare a nodi con y_sort
	for c in corpses:  # sdraiati e smorti, sotto chi è in piedi
		draw_set_transform(c.pos.round(), PI / 2)
		draw_figure(self, Rect2(-Vector2.ONE * TILE / 2.0, Vector2.ONE * TILE), Rect2(0, 0, TILE, TILE), c, CORPSE_SHADE)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	var queue: Array = people() + animals  # anche gli animali
	queue.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	var houses: Array = roofs_drawn if roofs_shown else []
	var holes := roof_holes(queue) if roofs_shown else {}
	warm_cells.clear()  # attorno ai comignoli la neve sui tetti si scioglie prima (vedi draw_house)
	roof_chimneys.clear()
	for origin in furniture:
		if HEAT.has(furniture[origin][0]) and chimney_of(origin)[1] != Chimney.NONE:
			var chimney := chimney_of(origin)
			var under: Roof = shown_roof[chimney[0]]
			roof_chimneys[under] = roof_chimneys.get(under, []) + [chimney]
			for k in cells_in(Rect2i(chimney[0] - Vector2i.ONE, Vector2i(3, 3))):
				warm_cells[k] = true
	var next := [0, 0]  # il prossimo da disegnare in `queue` e in `houses`
	for cell in trees:
		draw_upto(center(cell).y, queue, houses, holes, next)
		draw_texture_rect_region(TREES, Rect2(Vector2(cell.x, cell.y - 1) * TILE, Vector2(1, 2) * TILE),
			Rect2(Vector2(trees[cell], 0) * TILE, Vector2(1, 2) * TILE))
	draw_upto(INF, queue, houses, holes, next)
	for arrow in arrows:  # sopra tutto: volano
		draw_arrow(arrow)
	if roofs_shown:  # di nuovo i cartelli: restano sopra i tetti e si cliccano
		for room in rooms:
			draw_texture(SIGN, Vector2(room.sign) * TILE)
	draw_fire()

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
	for cell in ice_marks:
		draw_mark(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), Order.ICE)
	for a in animals:
		if a.marked:
			draw_mark(Rect2(a.pos - Vector2(TILE / 2.0, TILE * 1.25), Vector2.ONE * TILE), Order.HUNT)  # sopra la testa
	for c in people():
		if is_working(c):  # barra di avanzamento del lavoro
			draw_rect(Rect2(c.pos + Vector2(-6, -11), Vector2(12 * (1 - c.work_left / c.work_total), 2)), Color.YELLOW)
	if order == Order.BUILD and FURNITURE.has(build_kind):  # il prossimo mobile sotto il mouse, rosso se non ci sta
		var at := cell_of(get_global_mouse_position())
		var plan := [build_kind, build_res, build_turn]
		var fits := piece_fits(at, plan)
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
		var lit := furniture.duplicate()
		if roofs_shown:  # sotto i tetti non si vedono
			for origin in furniture:
				if roofed.has(origin):
					lit.erase(origin)
		draw_pieces(lights_canvas, FURNITURE_GLOW, lit)


# Le caselle di tetto in fiamme coi tetti tolti: annerite a terra, con le lingue di fuoco (coi tetti, vedi draw_house)
func draw_fire() -> void:
	if roofs_shown:
		return
	for cell in burning:
		var r := Rect2(tile_rect(cell.x, cell.y))
		draw_rect(r, Color(OUTLINE, 0.35))
		draw_flames(Vector2(r.position.x, r.end.y - 2), cell)


# tre lingue di fuoco che guizzano, larghe una casella, col piede sulla riga `foot.y` da `foot.x`
func draw_flames(foot: Vector2, cell: Vector2i) -> void:
	var seconds := clock * DAY_LENGTH
	for i in 3:
		var x := foot.x + 3 + i * 5
		var flick := sin(seconds * 9.0 + i * 2.1 + cell.x) * 2.0
		var tall := 9.0 + flick + (2.0 if i == 1 else 0.0)
		for layer in [[FIRE_COLORS[0], 0.0], [FIRE_COLORS[1], 2.0], [FIRE_COLORS[2], 4.5]]:
			var h: float = tall - layer[1]
			draw_colored_polygon(PackedVector2Array([Vector2(x - 2.5 + layer[1] / 3, foot.y), Vector2(x + 2.5 - layer[1] / 3, foot.y),
				Vector2(x + flick / 2, foot.y - h)]), layer[0])


# Dove esce il fumo del fuoco in `origin`: [casella, Chimney]. Focolare e fornace col comignolo di pietra sul muro alle
# loro spalle (se no sopra di loro); il fuoco da campo da uno sfiatatoio sopra di lui. Senza tetto lì, niente comignolo
func chimney_of(origin: Vector2i) -> Array:
	var plan: Array = furniture[origin]
	var cell := origin
	if plan[0] != Build.CAMPFIRE and built.get(origin + back_of(plan), [-1])[0] == Build.WALL:
		cell = origin + back_of(plan)
	if not roofed.has(cell):
		return [cell, Chimney.NONE]
	return [cell, Chimney.VENT if plan[0] == Build.CAMPFIRE else Chimney.STONE]


# il punto da cui sale il fumo del fuoco in `origin`: la cima del comignolo, lo sfiatatoio, o il fuoco all'aperto
func smoke_at(origin: Vector2i) -> Vector2:
	var chimney := chimney_of(origin)
	if chimney[1] == Chimney.NONE or not roofs_shown:
		return center(origin) + Vector2(0, -6)
	return chimney_spot(chimney, shown_roof[chimney[0]]) + (Vector2(8, 3) if chimney[1] == Chimney.STONE else Vector2(8, 9))


# l'angolo in alto a sinistra dello sprite del comignolo `chimney` (vedi chimney_of), in piedi sul tetto `roof` sopra
# la sua casella
func chimney_spot(chimney: Array, roof: Roof) -> Vector2:
	var cell: Vector2i = chimney[0]
	return Vector2(cell.x * TILE, ROOFS.on_roof(roof.look, center(cell)).y + 4 - TILE)


# quanto si usa il fuoco in `origin`: 0 acceso e basta, 1 ci si cucina o si forgia, 2 si affumica (vedi atmosphere)
func fire_use(origin: Vector2i) -> int:
	var use := 0
	for c in colonists:
		if c.target == origin and c.job in [Job.COOK, Job.CRAFT] and cell_of(c.pos) == c.dest:
			use = 2 if c.job == Job.CRAFT and RECIPES[c.recipe][0] in SMOKED else maxi(use, 1)
	return use


# Coloni, animali e tetti (con la facciata) più in alto di `limit`, dall'alto in basso: un tetto copre chi gli sta
# dietro, chi gli passa davanti copre lui. `next` dice a che punto si è in `queue` e in `houses`, e va avanti.
func draw_upto(limit: float, queue: Array, houses: Array, holes: Dictionary, next: Array) -> void:
	while true:
		var who: float = queue[next[0]].pos.y if next[0] < queue.size() else INF
		var house: float = houses[next[1]].look["base"] if next[1] < houses.size() else INF
		if minf(who, house) >= limit:
			return
		if house <= who:  # chi sta proprio sul piede della facciata le passa davanti
			draw_house(houses[next[1]], holes.get(houses[next[1]], []))
			next[1] += 1
		else:
			draw_creature(queue[next[0]])
			next[0] += 1


# Il tetto `roof` con la sua facciata (Roof.look), coi buchi `cut` per vedere chi c'è dietro (vedi roof_holes): con la
# sua tinta, più scuro bagnato; innevato quanto la neve a terra, meno quanto la stanza sotto la scioglie (roof_snow) e
# attorno ai comignoli (warm_cells). Sopra, stesi sulle falde: l'usura (licheni, tegole smosse, il buco), il fuoco, i
# comignoli; dal bordo davanti le gocce se piove e i ghiaccioli sotto lo zero.
func draw_house(roof: Roof, cut: Array) -> void:
	var look := roof.look
	var key := str(cut)
	if key != look["cut"]:  # i buchi sono cambiati: si rifanno le texture
		look["cut"] = key
		look["tex"].update(cut_holes(look["image"], cut, look["origin"]))
		look["snow_tex"].update(cut_holes(look["snowy"], cut, look["origin"]))
	var white: float = atmosphere.snow * roof_snow(roof) if atmosphere.snow > 0 else 0.0
	var tint := roof.tint * Color.WHITE.lerp(OUTLINE, WET_ROOF * atmosphere.wet * (1.0 - white))
	draw_texture(look["tex"], Vector2(look["origin"]), tint)
	var mine := cells_in(roof.rect).filter(func(k): return shown_roof.get(k) == roof)  # un muro in comune: il tetto davanti
	if white > 0:
		draw_texture(look["snow_tex"], Vector2(look["origin"]), Color(1, 1, 1, white))
		for cell in mine:
			if warm_cells.has(cell):  # sopra la neve, di nuovo il tetto: ne resta CHIMNEY_SNOW
				draw_roof_patch(look, Rect2(tile_rect(cell.x, cell.y)), Color(tint, 1.0 - CHIMNEY_SNOW))
	for cell in mine:
		var r := Rect2(tile_rect(cell.x, cell.y))
		var worn: float = wear.get(cell, 0.0)
		if worn >= LICHEN:
			var stage := 2 if worn >= 1.0 else (1 if worn >= WORN else 0)
			draw_texture_rect_region(ROOF_WEAR, on_roof_rect(look, r), Rect2(stage * TILE, 0, TILE, TILE))
		if burning.has(cell):
			draw_on_roof(look, r, null, Rect2(), Color(OUTLINE, 0.35))  # annerita
			draw_flames(ROOFS.on_roof(look, Vector2(r.position.x + TILE / 2.0, r.end.y - 2)) - Vector2(TILE / 2.0, 0), cell)
	for chimney in roof_chimneys.get(roof, []):
		draw_texture_rect_region(CHIMNEYS, Rect2(chimney_spot(chimney, roof), Vector2.ONE * TILE),
			Rect2(chimney[1] * TILE, 0, TILE, TILE))
	var rain: float = atmosphere.raining()
	var icy: bool = atmosphere.climate and atmosphere.temperature() < 0.0
	if rain <= 0 and not icy:
		return
	var seconds := clock * DAY_LENGTH
	var front: float = look["eaves"].end.y
	var edge := func(x: float) -> float: return front - ROOFS.lift(look, Vector2(x, front)) + look["thick"]
	for col in range(roof.rect.position.x, roof.rect.end.x):
		var spot: int = absi(hash(Vector2i(col, roof.rect.end.y - 1)))
		if rain > 0:  # gocce dal bordo
			for i in 2:
				var x: float = col * TILE + (spot >> (i * 4)) % 14 + 1
				var fall := fmod(seconds * 30.0 + x * 7.0, 12.0)
				draw_rect(Rect2(x, edge.call(x) + fall, 1, 2), Color(DRIP_COLOR, rain * (1.0 - fall / 12.0)))
		if icy:  # ghiaccioli
			for i in 3:
				var x: float = col * TILE + 2 + i * 5 + (spot >> i) % 2
				var y: float = edge.call(x + 1)
				var length := 2 + (spot >> (i + 2)) % 3
				draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 2, y), Vector2(x + 1, y + length)]), ICE_COLOR)


# il rettangolo a terra `ground` spezzato sul colmo del tetto `look`: da una parte e dall'altra la falda è piana
func roof_pieces(look: Dictionary, ground: Rect2) -> Array[Rect2]:
	var mid: float = look["mid"]
	if look["along_x"] and ground.position.y < mid and ground.end.y > mid:
		return [Rect2(ground.position, Vector2(ground.size.x, mid - ground.position.y)),
			Rect2(ground.position.x, mid, ground.size.x, ground.end.y - mid)]
	if not look["along_x"] and ground.position.x < mid and ground.end.x > mid:
		return [Rect2(ground.position, Vector2(mid - ground.position.x, ground.size.y)),
			Rect2(mid, ground.position.y, ground.end.x - mid, ground.size.y)]
	return [ground]


# La regione `src` di `texture` (senza texture, solo `color`) stesa sul tetto `look` sopra il rettangolo a terra
# `ground`: ogni pezzo piano (roof_pieces) diventa il quadrilatero che si vede a schermo
func draw_on_roof(look: Dictionary, ground: Rect2, texture: Texture2D, src := Rect2(), color := Color.WHITE) -> void:
	for piece in roof_pieces(look, ground):
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for corner: Vector2 in [piece.position, Vector2(piece.end.x, piece.position.y), piece.end, Vector2(piece.position.x, piece.end.y)]:
			pts.append(ROOFS.on_roof(look, corner))
			if texture:
				uvs.append((src.position + (corner - ground.position) / ground.size * src.size) / texture.get_size())
		if texture:
			draw_colored_polygon(pts, color, uvs, texture)
		else:
			draw_colored_polygon(pts, color)


# Dove disegnare sul tetto `look` lo sprite della casella a terra `r`: grande com'è (i pixel del tetto non si stirano),
# centrato dove si vede il centro della casella; più basso solo dove la falda a schermo è più corta (quella dietro)
func on_roof_rect(look: Dictionary, r: Rect2) -> Rect2:
	var mid := r.get_center()
	var top := ROOFS.on_roof(look, Vector2(mid.x, r.position.y)).y
	var bottom := ROOFS.on_roof(look, Vector2(mid.x, r.end.y)).y
	var tall := minf(bottom - top, r.size.y)
	return Rect2(r.position.x, ROOFS.on_roof(look, mid).y - tall / 2.0, r.size.x, tall)


# il tetto `look` stesso, solo sopra il rettangolo a terra `ground`, tinto `color`
func draw_roof_patch(look: Dictionary, ground: Rect2, color: Color) -> void:
	var size: Vector2 = look["tex"].get_size()
	for piece in roof_pieces(look, ground):
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for corner: Vector2 in [piece.position, Vector2(piece.end.x, piece.position.y), piece.end, Vector2(piece.position.x, piece.end.y)]:
			var p := ROOFS.on_roof(look, corner)
			pts.append(p)
			uvs.append((p - Vector2(look["origin"])) / size)
		draw_colored_polygon(pts, color, uvs, look["tex"])


# Buchi nei tetti: attorno a chi sta dietro un edificio (coloni, avventurieri, animali), e attorno al colono scelto
# anche se è dentro; gli altri dentro restano coperti. Roof -> centri dei buchi, in pixel.
func roof_holes(queue: Array) -> Dictionary:
	var holes := {}
	var chosen: Colonist = shown if sheet_panel.visible else null
	for c in queue:
		if c != chosen and roofed.has(cell_of(c.pos)):
			continue
		var at := Vector2i((c.pos + Vector2(0, 1)).round())  # il centro della figura
		for roof in roofs:
			if roof.look["base"] > c.pos.y and roof_covers(roof.look, at):
				if not holes.has(roof):
					holes[roof] = []
				holes[roof].append(at)
	return holes


# il tetto `look` copre la figura col centro in `at`?
func roof_covers(look: Dictionary, at: Vector2i) -> bool:
	var img: Image = look["image"]
	for d in [Vector2i.ZERO, Vector2i(0, -5), Vector2i(0, 5), Vector2i(-4, 0), Vector2i(4, 0)]:
		var p: Vector2i = at + d - look["origin"]
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and img.get_pixelv(p).a > 0.5:
			return true
	return false


# una copia di `src` (che sta nel mondo da `origin`) coi buchi attorno ai punti `cut`
func cut_holes(src: Image, cut: Array, origin: Vector2i) -> Image:
	if cut.is_empty():
		return src
	var img := Image.new()
	img.copy_from(src)
	var r: int = ROOFS.HOLE_DITHER
	for at: Vector2i in cut:
		img.blit_rect_mask(hole_clear, hole_masks[posmod(at.x + at.y, 2)], Rect2i(0, 0, r * 2, r * 2), at - Vector2i(r, r) - origin)
	return img


func draw_lens() -> void:
	var font := info_label.get_theme_font("font")
	for room in rooms:
		for cell in room.cells:
			lens_canvas.draw_rect(tile_rect(cell.x, cell.y), Color(ROOM_COLORS[room.kind], 0.35))
		var mid := room_mid(room)
		if room.kind != RoomKind.NONE:
			lens_canvas.draw_string(font, mid + Vector2(-TILE * 4, 4), named(RoomKind, room.kind),
				HORIZONTAL_ALIGNMENT_CENTER, TILE * 8, 12)


# un numero piccolo, centrato in una casella, sulla lente `canvas`
func lens_text_on(canvas: Node2D, at: Vector2, text: String, font: Font) -> void:
	canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, TILE, 8, 2, Color(OUTLINE, 0.8))
	canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, TILE, 8, Color.WHITE)


# Lente del calore: ogni casella delle stanze colorata coi suoi gradi (HEAT_SCALE: quanto comfort toglie il freddo;
# sotto lo zero FROST_COLOR), al centro i gradi e il malus; sopra ogni fuoco quanto scalda, e dove passa il muro alle
# sue spalle una freccia col calore che va oltre, o una ✕ se il muro è di pietra. Piazzando un fuoco, la sua anteprima
func draw_heat_lens() -> void:
	var memo := {}
	for room in rooms:
		for cell in room.cells:
			heat_canvas.draw_rect(tile_rect(cell.x, cell.y), Color(heat_color(temperature_at(cell, memo)), 0.6))
		var t := room_temperature(room)
		var malus := cold_malus(t)
		lens_text(room_mid(room) + Vector2(-TILE * 4, 4), "%d °C" % roundi(t) + (" · −%d" % malus if malus > 0 else ""),
			TILE * 8, 12, Color.WHITE)
	for origin in furniture:
		var kind: int = furniture[origin][0]
		if HEAT.has(kind):
			lens_text(center(origin) + Vector2(-TILE, -TILE / 2.0 - 2), "+%d" % HEAT[kind], TILE * 2, 10, HEAT_COLOR)
			if THROUGH.has(kind):
				draw_passage(origin, furniture[origin])
	if previewing_heat() and THROUGH.has(build_kind):
		draw_passage(cell_of(get_global_mouse_position()), [build_kind, build_res, build_turn])


# sulla lente del calore: la freccia del calore che passa il muro alle spalle del fuoco, o la ✕ sul muro di pietra
func draw_passage(origin: Vector2i, plan: Array) -> void:
	var p := passage(origin, plan)
	if p.is_empty():
		return
	var to := center(p[0] + back_of(plan))
	if not p[2]:
		var x := center(p[0])
		heat_canvas.draw_line(x - Vector2(4, 4), x + Vector2(4, 4), BLOCKED_COLOR, 2.0)
		heat_canvas.draw_line(x + Vector2(-4, 4), x + Vector2(4, -4), BLOCKED_COLOR, 2.0)
		return
	var from := center(origin)
	var dir := (to - from).normalized()
	heat_canvas.draw_line(from + dir * 4, to, HEAT_COLOR, 2.0)
	heat_canvas.draw_colored_polygon(PackedVector2Array([to + dir * 3, to - dir * 3 + dir.orthogonal() * 4,
		to - dir * 3 - dir.orthogonal() * 4]), HEAT_COLOR)
	lens_text(to + Vector2(-TILE, TILE - 2), "+%s" % str(HEAT[plan[0]] * THROUGH[plan[0]]).trim_suffix(".0"), TILE * 2, 10, HEAT_COLOR)


# scritta centrata nella larghezza `width`, col contorno: si legge sopra ogni colore
func lens_text(at: Vector2, text: String, width: int, size: int, color: Color) -> void:
	var font := info_label.get_theme_font("font")
	heat_canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 4, OUTLINE)
	heat_canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


# il colore della lente per `t` gradi: sotto lo zero il ghiaccio, sopra COLD_FROM il caldo, in mezzo per quanto
# comfort toglie il freddo
func heat_color(t: float) -> Color:
	if t <= 0.0:
		return FROST_COLOR
	return HEAT_SCALE[0] if t >= COLD_FROM else HEAT_SCALE[mini(cold_malus(t) + 1, HEAT_SCALE.size() - 1)]


# si sta piazzando un mobile che scalda o isola, o si intonaca: la lente del calore si accende da sola, con l'anteprima
func previewing_heat() -> bool:
	return order == Order.BUILD and (HEAT.has(build_kind) or INSULATES.has(build_kind) or build_kind == Build.PLASTER)


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
	var years := age_of(c)
	var side: float = TILE * (CHILD_SIZE[0] if years < YOUTH_AGE else (CHILD_SIZE[1] if years < ADULT else 1.0))
	if c.downed:  # sdraiato, girato di un quarto
		draw_set_transform(c.pos.round(), PI / 2)
		draw_figure(self, Rect2(-Vector2.ONE * side / 2.0, Vector2.ONE * side), Rect2(0, 0, TILE, TILE), c)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	else:  # i giovani più piccoli, coi piedi dove li avrebbe un adulto
		draw_figure(self, Rect2((c.pos + Vector2(-side / 2.0, TILE / 2.0 - side)).round(), Vector2.ONE * side), src, c)
	if c.hp < MAX_HP:
		draw_health(c.pos, c.hp / MAX_HP)
	for b in babies:  # in braccio, senza culla
		if (b.cradle.x < 0 or furniture.get(b.cradle, [-1])[0] != Build.CRADLE) and carrier_of(b) == c:
			draw_texture_rect(BABY, Rect2(at + Vector2(0, 5), Vector2(10, 10)), false)
	if c.carrying > 0:
		draw_texture_rect(ICONS[c.carry_res], Rect2(at + Vector2(8, 6), Vector2(8, 8)), false)
	elif c.bucket:
		draw_texture_rect(BUCKET, Rect2(at + Vector2(8, 6), Vector2(8, 8)), false)
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
