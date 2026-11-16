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

enum Job { NONE, CHOP, MINE, UPROOT, HAUL, BUILD, FURNISH, HARVEST, SLEEP, EAT }
enum Res { WOOD, STONE, VEG, IRON, COAL }  # VEG: vegetali, dalle bacche dei cespugli; IRON, COAL: dai massi con le vene
const STACK_MAX := {Res.WOOD: 100, Res.STONE: 50, Res.VEG: 50, Res.IRON: 50, Res.COAL: 50}  # quantità massima per mucchio (casella)
enum Order { NONE, CHOP, MINE, UPROOT, BUILD, ERASE, DEMOLISH }  # cosa segna il trascinamento del mouse
const ORDER_COLORS := [Color.TRANSPARENT, Color.ORANGE, Color("8fd3ff"), Color("9be36a"), Color("e6e2d0"),
	Color("ff5a5a"), Color("c83030")]  # selezione e segni, per Order
# tasti in HUD/Tools/Row dopo Structures e Furniture, uno alla volta (ButtonGroup "Orders"): vedi toggle_order
const ORDER_TOOLS := {Order.DEMOLISH: "Destroy", Order.MINE: "Mine", Order.CHOP: "Chop", Order.UPROOT: "Uproot"}
const ORDER_ICONS := {Order.CHOP: preload("res://art/icon_chop.png"), Order.MINE: preload("res://art/icon_mine.png"),
	Order.UPROOT: preload("res://art/icon_uproot.png")}  # le stesse dei tasti: piccole e velate sopra ciò che è segnato
enum RoomKind { NONE, WAREHOUSE, BEDROOM, DORMITORY, KITCHEN, FORGE }  # tipo di stanza, scelto dal cartello
enum Build { WALL, FLOOR, DOOR, BED, TABLE, CHAIR, TORCH, CAMPFIRE, FURNACE, ANVIL }  # porta e mobili si attraversano
# materiale per casella; per i mobili, per pezzo. Un numero: del materiale del progetto; se no risorsa -> quantità (vedi cost_of)
const BUILD_COST := {Build.WALL: 5, Build.FLOOR: 2, Build.DOOR: 5, Build.BED: 10, Build.TABLE: 10, Build.CHAIR: 3,
	Build.TORCH: {Res.WOOD: 1, Res.COAL: 1}, Build.CAMPFIRE: 5, Build.FURNACE: 20, Build.ANVIL: 10}
# caselle occupate dai mobili come sono disegnati; girati di un quarto si scambiano larghezza e altezza (vedi piece_rect)
const FURNITURE := {Build.BED: Vector2i(2, 1), Build.TABLE: Vector2i(2, 2), Build.CHAIR: Vector2i.ONE, Build.TORCH: Vector2i.ONE,
	Build.CAMPFIRE: Vector2i.ONE, Build.FURNACE: Vector2i.ONE, Build.ANVIL: Vector2i.ONE}
const FLAME_TIME := 0.15    # secondi per fotogramma della fiamma: chi fa luce usa le colonne dei quarti di giro
# mobili che fanno luce: raggio in caselle. La luce si vede col buio e la fermano i muri (vedi update_lights)
const LIGHTS := {Build.TORCH: 5, Build.CAMPFIRE: 6, Build.FURNACE: 3}
const LIGHT_COLOR := Color("ffb060")
const ANY_MATERIAL := [Build.WALL, Build.FLOOR]  # di legno o di pietra
const BUILD_RES := {Build.FURNACE: Res.STONE, Build.ANVIL: Res.IRON}  # materiale fisso; il resto solo di legno
# mobili che servono perché il cartello lasci scegliere il tipo di stanza: tipo -> {mobile: almeno quanti}
# ponytail: la cucina accetterà anche la stufa, quando ci sarà: allora "uno tra" invece di "tutti"
const ROOM_NEEDS := {
	RoomKind.BEDROOM: {Build.BED: 1},
	RoomKind.DORMITORY: {Build.BED: 2},
	RoomKind.KITCHEN: {Build.CAMPFIRE: 1},
	RoomKind.FORGE: {Build.FURNACE: 1, Build.ANVIL: 1},
}
# lente delle stanze (tasto col cartello in basso): le stanze finite velate col colore del loro tipo, per RoomKind
const ROOM_COLORS := [Color("e6e2d0"), Color("c9a23b"), Color("3b8fd3"), Color("8a5ad3"), Color("e0703a"), Color("d33b3b")]
# comfort di una stanza, 0-COMFORT_MAX: lo danno i mobili (per pezzo) e il pavimento (tutto se copre la stanza intera),
# per il materiale. A metà né bonus né malus; fuori dalle stanze è 0. Vedi room_comfort e comfort_of
const COMFORT_MAX := 10
const COMFORT := {Build.FLOOR: 1.0, Build.BED: 1.0, Build.TABLE: 1.0, Build.CHAIR: 0.5, Build.TORCH: 0.5, Build.CAMPFIRE: 0.5}
const COMFORT_MATERIAL := {Res.STONE: 1.5}  # il resto vale 1
const COMFORT_EFFECT := 0.2  # a comfort 0 un'attività richiede il 20% di tempo in più, al massimo il 20% in meno
const ROOM_SPACE := 6        # caselle a testa: chi ne ha meno (stanza piena di gente) ha il comfort in proporzione
# suggerimento dei pulsanti di costruzione (vedi build_tip): sotto nome e costo il comfort, poi la descrizione colorata
const TIP := preload("res://tip_button.gd")  # suggerimento fatto di Control: pulsanti di costruzione, figurine
const BUILD_INFO_COLOR := Color("d9c48a")
const BUILD_INFO := {
	Build.WALL: "Blocks the way. Walls with a door around an area make a room.",
	Build.FLOOR: "Paves the ground. Furniture can stand on it.",
	Build.DOOR: "Colonists walk through it. A room needs one to be entered.",
	Build.BED: "A place to sleep. A bedroom needs one, a dormitory two.",
	Build.TABLE: "Where colonists eat and work.",
	Build.CHAIR: "Put it at a table, turned to face it.",
	Build.TORCH: "A wooden torch with a coal head. Lights up its surroundings; walls stop the light.",
	Build.CAMPFIRE: "A wood fire inside a ring of stones. Burns day and night. A kitchen needs one.",
	Build.FURNACE: "A stone furnace. A forge needs one, and an anvil.",
	Build.ANVIL: "An iron anvil on a stump. A forge needs one, and a furnace.",
}
enum Facing { DOWN, LEFT, RIGHT, UP }  # righe del foglio
enum TreeKind { OAK, PINE, BIRCH }     # colonne del foglio alberi
const TREE_LOGS := {TreeKind.OAK: 28, TreeKind.PINE: 35, TreeKind.BIRCH: 20}  # tronchi di un albero intero

# fogli 96x64 generati da tools/make_sprites.py
const COLONIST_BASE := preload("res://art/colonist_base.png")
const COLONIST_HAIR := preload("res://art/colonist_hair.png")
const COLONIST_TUNIC := preload("res://art/colonist_tunic.png")
const COLONIST_CAPE := preload("res://art/colonist_cape.png")
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
# 128x160, righe: mobili nell'ordine di Build; colonne: quarti di giro in senso orario, ognuno in un riquadro 32x32
const FURNITURE_SHEET := preload("res://art/furniture.png")
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
}
# 256x64, righe: muri di legno, muri di pietra (colonna = lati collegati, vedi WALL_LINKS), pavimenti (colonna = Res),
# porte (di fronte, di lato); vedi structure_src
const STRUCTURES := preload("res://art/structures.png")
const WALL_LINKS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]  # bit 1, 2, 4, 8 della colonna dei muri
# scheda del colono, vedi open_sheet
enum Skill { GATHERING, MINING, WOODCUTTING, CONSTRUCTION, COOKING, FISHING, HUNTING, MELEE, RANGED, RESEARCH }
const SKILL_MAX := 10       # livelli 1-10: al massimo, nella scheda, compare la stellina
# raccolta: [abilità, secondi per colpo a livello 5 (vedi gather_time), quantità per colpo, risorsa]; i massi con la
# vena danno il minerale (vedi ores). Ogni colpo dà 1 punto esperienza nell'abilità
const GATHER := {
	Job.CHOP: [Skill.WOODCUTTING, 10.0, 5, Res.WOOD],
	Job.MINE: [Skill.MINING, 15.0, 5, Res.STONE],
	Job.HARVEST: [Skill.GATHERING, 5.0, 1, Res.VEG],  # ponytail: nessuno la avvia (senza ordini si resta fermi), la useranno le routine
}
const STAR := preload("res://art/icon_star.png")
const SKILLS_SHEET := preload("res://art/skills.png")  # icone 8x8, colonne nell'ordine di Skill
const MAX_HP := 100
# talenti: per ora senza effetto, poi cambieranno alcune routine dei coloni; colonne di TRAITS_SHEET, 16x16 ciascuno
enum Trait { GLUTTON, SLEEPWALKER, HOTHEAD }
const TRAITS_SHEET := preload("res://art/traits.png")
const TRAIT_INFO := {  # suggerimento col mouse sopra il talento
	Trait.GLUTTON: "Always thinking about the next meal.",
	Trait.SLEEPWALKER: "Sometimes wanders off in their sleep.",
	Trait.HOTHEAD: "Loses their temper easily.",
}
# bisogni, barre 0-NEED_MAX nella scheda: 100 = sazio, riposato, comodo, felice; lo stress al contrario, 100 = al limite.
# Ritmi "al giorno" di gioco
enum Need { FOOD, REST, COMFORT, HAPPINESS, STRESS }
const NEED_MAX := 100.0
const NEED_LOW := 30.0      # affamato: va a mangiare dei vegetali; stanco: cerca un letto libero
const EXHAUSTED := 10.0     # stremato: lascia il lavoro e dorme dove si trova
const FOOD_DROP := 90.0     # al giorno
const REST_DROP := 100.0    # al giorno, da sveglio
const SLEEP_TIME := 8.0 / 24  # giorni di sonno per riposarsi del tutto, a comfort medio (vedi comfort_time)
const STRESS_WORK := 30.0   # al giorno, lavorando: sale
const STRESS_RELIEF := 60.0 # al giorno, dormendo, mangiando o senza niente da fare: scende
const STRESS_ICON := preload("res://art/icon_stress.png")  # 8x8, accanto al nome nella scheda
const FOOD_PER_VEG := 50.0  # un vegetale mangiato
const MOOD_SPEED := 50.0    # al giorno: la felicità va verso la media di cibo, riposo, comfort e calma (stress al contrario)
# barra: stremato, basso, a posto; tingono BAR_FILL, grigia (85%) nel mezzo e bianca sopra: lì risultano più chiari
const NEED_COLORS := [Color("d34432"), Color("f6a332"), Color("7db644")]
const BAR_FILL := preload("res://art/bar_fill.png")  # bianca: la tinge NEED_COLORS; vedi bar_style
const BAR_BACK := preload("res://art/bar_back.png")
const ARROW := preload("res://art/icon_arrow.png")  # a destra della barra; a sinistra è specchiata
const TREND_DOWN := Color("ff6a4a")  # freccia a sinistra accesa: il bisogno scende
const TREND_UP := Color("9be36a")    # freccia a destra accesa: sale
const TREND_OFF := Color(1, 1, 1, 0.12)
const FIRST_NAMES := ["Aldo", "Bertha", "Corrado", "Edda", "Folco", "Gisella", "Ilario", "Matilde", "Odo", "Rosalind", "Ugo", "Wilma"]
const NICKNAMES := ["Badger", "Crow", "Lefty", "Moss", "Pebble", "Red", "Stub", "Thistle"]
const LAST_NAMES := ["Ashdown", "Barrow", "Cooper", "Fenwick", "Hale", "Marsh", "Thatcher", "Woodward"]


class Colonist:
	var first_name := ""
	var nickname := ""            # facoltativo: non tutti ce l'hanno
	var last_name := ""
	var hp := MAX_HP
	var skills := []              # livello 1-SKILL_MAX per Skill
	var xp := []                  # punti esperienza per Skill: 1 per colpo d'ascia
	var needs := []               # 0-NEED_MAX per Need, vedi update_needs
	var trend := []               # per Need: -1 scende, 0 fermo, 1 sale (le frecce della scheda)
	var traits := []              # Trait
	var pos: Vector2
	var tunic: Color
	var cape: Color
	var hair: Color
	var facing := Facing.DOWN
	var walked := 0.0             # pixel percorsi, scandisce i passi dell'animazione
	var idle := 0.0               # secondi fermo senza lavoro, scandisce il respiro
	var path: Array[Vector2i] = []
	var job := Job.NONE
	var target := Vector2i.ZERO   # albero, masso (cella d'origine), mucchio, cella di magazzino o progetto
	var dest := Vector2i.ZERO     # HAUL: cella di magazzino dove si scarica; BUILD: dove stare a costruire
	var carry_res := Res.WOOD
	var carrying := 0
	var work_left := 0.0
	var work_total := 0.0


# Zona chiusa da muri (o roccia, acqua alta) con almeno una porta: una struttura finita.
class Room:
	var cells := {}               # caselle dentro, senza muri né porte
	var door := Vector2i.ZERO     # porta d'ingresso
	var sign := Vector2i.ZERO     # muro accanto alla porta col cartello (fuori davanti alla porta, se non ha muri)
	var name := ""
	var kind := RoomKind.NONE
	var owners: Array[Colonist] = []  # scelti nel popup del cartello, anche più d'uno: solo loro ci entrano
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
var items := {Res.WOOD: {}, Res.STONE: {}, Res.VEG: {}, Res.IRON: {}, Res.COAL: {}}  # risorsa -> (cella -> quantità a terra; nel magazzino = stoccata)
var stockpile := {}         # cella -> true: dentro le stanze di tipo magazzino, vedi update_stockpile
var rooms: Array[Room] = []  # stanze finite, vedi update_rooms
var rooms_made := 0         # per i nomi di default
var editing: Room           # la stanza aperta nel popup del cartello
var shown: Colonist         # il colono nella scheda: le barre dei bisogni lo seguono
var lens_owners := []       # [centro, proprietari] per stanza delle figurine sulla lente, vedi place_owners
var needs_rate := 1.0       # 0 nei test: i bisogni restano fermi e non cambiano i lavori
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
var delivered := {}         # [Job, cella d'origine] -> {Res: quantità} già al cantiere, per chi vuole più materiali
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
var lights := Node2D.new()        # una PointLight2D per mobile in LIGHTS, vedi update_lights
var occluders := Node2D.new()     # LightOccluder2D sui lati dei muri: fermano la luce
var light_texture := GradientTexture2D.new()  # chiazza tonda che sfuma, la stessa per tutte le luci
var wall_sides := []              # OccluderPolygon2D per lato della casella, come WALL_LINKS
var flat := Node2D.new()          # pavimenti, progetti, mucchi: stanno a terra, le ombre ci cadono sopra
var shadows := CanvasGroup.new()  # fonde le sagome: dove si sovrappongono non scuriscono il doppio
var casters := Node2D.new()       # dentro `shadows`: ci si disegnano le sagome
var feet := {}                    # [texture, rettangolo] -> base della sagoma, vedi foot_of
# lenti: sopra il mondo e sotto l'interfaccia (HUD è al livello 2), in un livello a parte così la notte non le scurisce
var lens := CanvasLayer.new()
var lens_canvas := Node2D.new()   # ci disegna draw_lens

@onready var camera: Camera2D = $Camera2D
@onready var stored_label: Label = $HUD/TopBar/Row/Stored  # risorse in tutti i magazzini, sommate: il dettaglio è in Resources
@onready var colonists_label: Label = $HUD/TopBar/Row/Colonists
@onready var beds_label: Label = $HUD/TopBar/Row/Beds
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
@onready var room_owners: Control = $HUD/RoomPopup/Box/Owners/List  # una casella da spuntare per colono
@onready var jobs_panel: Control = $HUD/JobsPanel  # a destra, si apre col tasto Jobs in basso: vedi job_list
@onready var jobs_list: Label = $HUD/JobsPanel/Box/List
@onready var resources_panel: Control = $HUD/ResourcesPanel  # stesso posto: vedi update_resources
@onready var resources_list: Control = $HUD/ResourcesPanel/Box/List  # una riga per Res: icona, nome, quantità
@onready var sheet_panel: Control = $HUD/ColonistSheet  # a sinistra, si apre cliccando un colono: vedi open_sheet
@onready var object_sheet: Control = $HUD/ObjectSheet  # in basso a destra: la casella sotto il mouse, vedi show_tip
@onready var sheet_needs: GridContainer = $HUD/ColonistSheet/Box/Needs  # 4 colonne: nome, freccia giù, barra, freccia su


func _ready() -> void:
	astar.region = Rect2i(Vector2i.ZERO, MAP_SIZE)
	astar.cell_size = Vector2.ONE * TILE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2.ONE / 2
	light_texture.fill_to = Vector2(0.5, 0)
	light_texture.gradient = Gradient.new()
	light_texture.gradient.colors = PackedColorArray([Color.WHITE, Color.TRANSPARENT])
	var corners := [Vector2.ZERO, Vector2(TILE, 0), Vector2.ONE * TILE, Vector2(0, TILE)]  # in senso orario
	for i in corners.size():
		var side := OccluderPolygon2D.new()
		side.closed = false
		side.cull_mode = OccluderPolygon2D.CULL_COUNTER_CLOCKWISE  # il lato verso la luce non fa ombra: il muro s'illumina
		side.polygon = PackedVector2Array([corners[i], corners[(i + 1) % corners.size()]])
		wall_sides.append(side)
	add_child(lights)
	add_child(occluders)
	generate_map()  # chiama update_lights: luci e lati dei muri vanno preparati prima
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
		c.cape = CAPE_COLORS.pick_random()
		c.hair = HAIR_COLORS.pick_random()
		c.first_name = FIRST_NAMES.pick_random()
		c.nickname = NICKNAMES.pick_random() if randf() < 0.5 else ""
		c.last_name = LAST_NAMES.pick_random()
		c.skills = Skill.values().map(func(_s): return randi_range(1, SKILL_MAX))
		c.xp = Skill.values().map(func(_s): return 0)
		# sfalsati: non dormono tutti insieme; lo stress parte basso
		c.needs = Need.values().map(func(n): return randf_range(0, 40) if n == Need.STRESS else randf_range(60, NEED_MAX))
		c.trend = c.needs.map(func(_v): return 0.0)
		c.traits = Trait.values()
		c.traits.shuffle()
		c.traits = c.traits.slice(0, randi_range(0, 2))
		colonists.append(c)
	camera.position = center(MAP_SIZE / 2)
	fullscreen.pressed.connect(toggle_fullscreen)
	var debug: PopupMenu = $HUD/TopBar/Row/Debug.get_popup()  # opzioni per provare il gioco: una voce per id
	debug.add_item("Advance 12 hours", 0)
	debug.id_pressed.connect(debug_pressed)
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
	lens.add_child(lens_canvas)
	add_child(lens)
	lens_canvas.draw.connect(draw_lens)
	$HUD/Tools/Row/RoomsLens.toggled.connect(lens.set_visible)
	$HUD/RoomPopup/Box/Ok.pressed.connect(room_popup.hide)
	for kind in Build.values():  # un pulsante per tipo, con lo stesso nome: Wall, Floor, ... Torch
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
	for window in [room_popup, jobs_panel, resources_panel, sheet_panel]:  # X in alto a destra, si trascinano
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


# tasti "Structures" (sega e martello) e "Furniture" (torcia) in basso a sinistra, uno alla volta: sopra compare
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
	var cost := cost_of([kind, BUILD_RES.get(kind, Res.WOOD)])
	if kind in ANY_MATERIAL:
		cost[Res.STONE] = cost[Res.WOOD]
	for res in cost:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		var amount := Label.new()
		amount.text = "%s%d%s" % ["or " if kind in ANY_MATERIAL and res == Res.STONE else "", cost[res],
			"" if FURNITURE.has(kind) else "/tile"]
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


# tasti "Destroy", "Mine", "Chop", "Uproot" dopo "Furniture": finché uno è premuto, trascinando o cliccando si
# abbatte quello che è costruito, si segnano massi da scavare, alberi da tagliare, erbacce e cespugli da estirpare
func toggle_order(on: bool, which: Order) -> void:
	if on:
		structures_button.button_pressed = false
		furniture_button.button_pressed = false
		order = which
	elif order == which:
		order = Order.NONE


# cartello di una stanza: popup con nome, comfort, tipo, divieto e proprietari
func open_room(room: Room) -> void:
	editing = room
	room_name.text = room.name
	for child in room_owners.get_children():
		child.free()
	for c in colonists:
		var box := CheckBox.new()
		box.text = full_name(c)
		box.focus_mode = Control.FOCUS_NONE
		box.button_pressed = c in room.owners
		box.toggled.connect(toggle_owner.bind(c))
		room_owners.add_child(box)
	$HUD/RoomPopup/Box/Banned.set_pressed_no_signal(room.banned)
	refresh_room()
	room_popup.show()
	room_popup.reset_size()  # si stringe se prima c'erano più righe


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


func toggle_owner(on: bool, c: Colonist) -> void:
	if on:
		editing.owners.append(c)
	else:
		editing.owners.erase(c)
	recheck_access()


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


# riempie `box` (HUD/ColonistSheet/Box o una sua copia) col colono `c`: nome, salute, bisogni (nome,
# freccia giù, barra, freccia su), abilità (stellina al massimo) e sotto i talenti, col suggerimento
func fill_sheet(box: Control, c: Colonist) -> void:
	var needs_grid: Control = box.get_node("Needs")
	var skills_grid: Control = box.get_node("Skills")  # 4 colonne: icona, nome, livello, stellina
	var traits_box: Control = box.get_node("Traits/Icons")  # solo icone: il nome è nel suggerimento
	box.get_node("Head/Name").text = full_name(c)
	box.get_node("Health").text = "Health: %d / %d" % [c.hp, MAX_HP]
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
	traits_box.get_parent().visible = not c.traits.is_empty()  # col titolo "Traits"
	update_need_bars(needs_grid, c)


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


func full_name(c: Colonist) -> String:
	return "%s \"%s\" %s" % [c.first_name, c.nickname, c.last_name] if c.nickname else "%s %s" % [c.first_name, c.last_name]


# colono sotto `point` (pixel del mondo); se si sovrappongono, quello col centro più vicino
func colonist_at(point: Vector2) -> Colonist:
	var near := colonists.filter(func(c): return c.pos.distance_to(point) < TILE / 2.0)
	near.sort_custom(func(a, b): return a.pos.distance_to(point) < b.pos.distance_to(point))
	return near[0] if not near.is_empty() else null


func set_room_kind(kind: int) -> void:
	editing.kind = kind
	update_stockpile()


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
	var uproot := "\nMarked: uproot" if uproot_marks.has(cell) else ""
	if bushes.has(cell):
		var ripe: bool = bushes[cell] <= clock
		return ["Bush", ("Berries: %d / %d" % [stock.get(cell, BERRIES_PER_BUSH), BERRIES_PER_BUSH] if ripe
			else "Berries in %.1f days" % (bushes[cell] - clock)) + uproot]
	if weeds.has(cell):
		return ["Weed", uproot.strip_edges()]
	for res in items:
		if items[res].has(cell):
			return ["%s pile" % Res.keys()[res].capitalize(), "%d / %d" % [items[res][cell], STACK_MAX[res]]]
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


# finestra "Jobs": lavori in attesa per tipo, nell'ordine in cui i coloni li scelgono (vedi find_job)
func job_list() -> String:
	var lines := PackedStringArray()
	if not chop_marks.is_empty():
		lines.append("Chop trees: %d" % chop_marks.size())
	if not mine_marks.is_empty():
		lines.append("Mine boulders: %d" % mine_marks.size())
	if not uproot_marks.is_empty():
		lines.append("Uproot plants: %d" % uproot_marks.size())
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
	if start_rooms:  # ponytail: scorta di debug, da togliere (o DEBUG_STASH a 0) quando si gioca sul serio
		var first: Vector2i = MAP_SIZE / 2 + START_ROOMS[0] * 8
		for res in Res.values():  # un mucchio per risorsa lungo la riga di mezzo, il resto si allarga accanto
			drop(res, first + Vector2i(res - 2, 0), DEBUG_STASH)
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
	confirm.disabled = draft.is_empty() and furniture_draft.is_empty()
	if jobs_panel.visible:
		jobs_list.text = job_list()
	if resources_panel.visible:
		update_resources()
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
	var t := fmod(clock, 1.0)
	info_label.text = "Day %d  %02d:%02d    Order: %s    Speed: %dx  (Space = pause, 1-3)" \
		% [int(clock) + 1, int(t * 24), int(t * 1440) % 60, Order.keys()[order].capitalize(), Engine.time_scale]
	sky.color = sky_colors.sample(t)
	lights.visible = sky.color.get_luminance() < 0.99
	for light in lights.get_children():  # più è buio, più si vedono
		light.energy = 1.0 - sky.color.get_luminance()
	var shade := SHADOW_ALPHA * clampf(sun_height() * 4, 0, 1)  # sfuma all'alba e al tramonto, zero di notte
	shadows.self_modulate = Color(0, 0, 0, shade)
	shadows.visible = shade > 0
	queue_redraw()
	flat.queue_redraw()
	casters.queue_redraw()
	if lens.visible:
		lens_canvas.queue_redraw()
		place_owners()


func debug_pressed(id: int) -> void:  # le voci del menu Debug, vedi _ready
	match id:
		0:
			advance(0.5)


func advance(days: float) -> void:  # debug: simula, non salta, così bisogni e lavori vanno avanti davvero
	for i in roundi(days * DAY_LENGTH / 0.05):
		tick(0.05)


func tick(delta: float) -> void:
	clock += delta / DAY_LENGTH
	for c in colonists:
		update_colonist(c, delta)


func update_colonist(c: Colonist, delta: float) -> void:
	update_needs(c, delta)
	c.idle = c.idle + delta if c.job == Job.NONE and c.path.is_empty() else 0.0
	if c.idle > LOOK_TIME and randf() < delta / LOOK_TIME:  # si guarda attorno, a caso: niente coloni sincronizzati
		c.facing = Facing.values().pick_random()
	if not c.path.is_empty():  # anche senza lavoro: chi è libero può dover uscire da una stanza che si chiude
		var goal := center(c.path[0])
		var d := goal - c.pos
		face(c, d)
		c.walked += minf(d.length(), SPEED * TILE * delta)
		c.pos = c.pos.move_toward(goal, SPEED * TILE * delta)
		if c.pos == goal:
			c.path.pop_front()
		return
	if c.job == Job.NONE:
		find_job(c)
		return
	match c.job:
		Job.CHOP, Job.MINE, Job.HARVEST:  # raccolta, vedi GATHER: un colpo ogni gather_time, il raccolto cade ai piedi
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
			stock[c.target] = left - got
			var here := cell_of(c.pos)
			drop(res, here, got)
			c.xp[gather[0]] += 1
			if left > got:
				c.work_left = gather_time(c, c.job)  # colpo successivo
				c.work_total = c.work_left
				return
			stock.erase(c.target)
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
			end_job(c)
			try_haul(c, res, [here])  # porta subito via quello che ha prodotto
		Job.UPROOT:
			face(c, center(c.target) - c.pos)
			c.work_left -= delta
			if c.work_left <= 0:
				bushes.erase(c.target)
				weeds.erase(c.target)
				uproot_marks.erase(c.target)
				end_job(c)
		Job.HAUL:
			var ground: Dictionary = items[c.carry_res]
			if c.target != c.dest:  # arrivato al mucchio: carica
				var to_dest := path_to_nearest(c, [c.dest])
				if to_dest.is_empty():
					end_job(c)  # posto occupato o irraggiungibile: riprova più tardi, intanto fa altro
					return
				var space: int = STACK_MAX[c.carry_res] - ground.get(c.dest, 0)
				c.carrying = mini(mini(ground[c.target], CARRY_MAX), space)
				add_item(c.carry_res, c.target, -c.carrying)
				reserved.erase(c.target)
				c.target = c.dest
				c.path = to_dest
			else:                   # arrivato nel magazzino: scarica
				add_item(c.carry_res, c.dest, c.carrying)
				c.carrying = 0
				end_job(c)
		Job.BUILD, Job.FURNISH:
			var plans := plans_of(c.job)
			var plan: Array = plans[c.target]
			if c.carrying == 0:     # arrivato al mucchio (a terra o in magazzino): prende il materiale e va al cantiere
				var here := cell_of(c.pos)
				var cost: int = missing(c.job, c.target).get(c.carry_res, 0)
				if cost == 0 or items[c.carry_res].get(here, 0) < cost:
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
			if c.work_left == 0 and (plan[0] != Build.WALL or ready_to_close(c)):
				if c.job == Job.BUILD:
					build(c.target)
				else:
					furniture[c.target] = plan
					plans.erase(c.target)
					update_lights()
				delivered.erase([c.job, c.target])
				c.carrying = 0
				end_job(c)
		Job.SLEEP:  # a letto o per terra (vedi update_needs), finché non è riposato del tutto
			if c.needs[Need.REST] >= NEED_MAX:
				end_job(c)
		Job.EAT:  # arrivato al mucchio di vegetali: ne mangia uno
			if items[Res.VEG].has(c.target):
				add_item(Res.VEG, c.target, -1)
				c.needs[Need.FOOD] = minf(c.needs[Need.FOOD] + FOOD_PER_VEG, NEED_MAX)
			end_job(c)


# Bisogni che calano col tempo. Chi dorme si riposa del tutto in SLEEP_TIME, più o meno secondo il comfort di dove
# dorme (vedi comfort_of: per terra fuori è 0, il 20% in più), e il suo comfort va verso quello del posto.
# Lo stress sale lavorando e scende a riposo. Sotto EXHAUSTED di riposo il colono molla tutto e crolla dove si trova;
# sotto NEED_LOW ci pensa find_job.
# ponytail: comfort e stress non cambiano ancora i lavori; la felicità segue solo la media degli altri
func update_needs(c: Colonist, delta: float) -> void:
	var day := delta / DAY_LENGTH * needs_rate
	var before: Array = c.needs.duplicate()
	c.needs[Need.FOOD] -= FOOD_DROP * day
	if c.job == Job.SLEEP and c.path.is_empty():
		var comfort := comfort_of(c)
		var gain := NEED_MAX / SLEEP_TIME * day / comfort_time(comfort)
		c.needs[Need.REST] += gain
		c.needs[Need.COMFORT] = move_toward(c.needs[Need.COMFORT], NEED_MAX * comfort / COMFORT_MAX, gain)
	else:
		c.needs[Need.REST] -= REST_DROP * day
	c.needs[Need.STRESS] += (STRESS_WORK if c.job not in [Job.NONE, Job.SLEEP, Job.EAT] else -STRESS_RELIEF) * day
	var mood: float = (c.needs[Need.FOOD] + c.needs[Need.REST] + c.needs[Need.COMFORT] + NEED_MAX - c.needs[Need.STRESS]) / 4.0
	c.needs[Need.HAPPINESS] = move_toward(c.needs[Need.HAPPINESS], mood, MOOD_SPEED * day)
	c.needs = c.needs.map(func(v): return clampf(v, 0.0, NEED_MAX))
	if day > 0:  # in pausa le frecce restano com'erano; il pasto (vedi EAT) è uno scatto, non conta
		c.trend = Need.values().map(func(n): return signf(c.needs[n] - before[n]))
	if c.needs[Need.REST] <= EXHAUSTED and c.job != Job.SLEEP:
		quit_job(c)
		var here: Array[Vector2i] = []
		start_job(c, Job.SLEEP, here, cell_of(c.pos), 0.0)


func in_bed(c: Colonist) -> bool:
	return c.job == Job.SLEEP and not pieces_at(furniture, cell_of(c.pos)).filter(func(o): return furniture[o][0] == Build.BED).is_empty()


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
# ponytail: per ora vale solo per il sonno; con cucina e forgia allungherà anche il lavoro, e sotto metà potrà
# rovinare il prodotto
func comfort_time(comfort: int) -> float:
	var mid := COMFORT_MAX / 2.0
	return 1.0 + COMFORT_EFFECT * (mid - comfort) / mid


# la stanza ha i mobili che servono per il tipo `kind`? (vedi ROOM_NEEDS; i tipi senza requisiti sì)
func room_meets(room: Room, kind: RoomKind) -> bool:
	var needs: Dictionary = ROOM_NEEDS.get(kind, {})
	var inside: Array = furniture.keys().filter(func(o): return room.cells.has(o)).map(func(o): return furniture[o][0])
	return needs.keys().all(func(b): return inside.count(b) >= needs[b])


func find_job(c: Colonist) -> void:
	# prima i bisogni: stanco cerca un letto libero (se non c'è lavora finché crolla), affamato va a mangiare
	if c.needs[Need.REST] < NEED_LOW:
		var beds := furniture.keys().filter(func(o): return furniture[o][0] == Build.BED and is_free(o))
		var to_bed := path_to_nearest(c, beds)
		if not to_bed.is_empty():
			start_job(c, Job.SLEEP, to_bed, to_bed.back(), 0.0)
			return
	if c.needs[Need.FOOD] < NEED_LOW:
		var to_food := path_to_nearest(c, items[Res.VEG].keys().filter(func(cell): return is_free(cell)))
		if not to_food.is_empty():
			start_job(c, Job.EAT, to_food, to_food.back(), 0.0)
			return

	# ordine fisso finché non c'è la tabella delle priorità: tagliare, scavare, estirpare, costruire, trasportare, raccogliere
	if try_work(c, Job.CHOP, chop_marks.keys(), TREE_SIDES, gather_time(c, Job.CHOP)) \
			or try_work(c, Job.MINE, mine_marks.keys(), SIDES, gather_time(c, Job.MINE)) \
			or try_work(c, Job.UPROOT, uproot_marks.keys(), SIDES, UPROOT_TIME):
		return

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
			start_job(c, job, to_source, stands[path.back()], BUILD_TIME)
			c.dest = path.back()
			c.carry_res = piles[to_source.back()]
			reserved[to_source.back()] = c  # intanto nessun altro prende da quel mucchio
			return

	for res in Res.values():
		if try_haul(c, res, items[res].keys().filter(func(cell): return not stockpile.has(cell) and is_free(cell))):
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


# secondi per colpo di `c` nel lavoro di raccolta `job`: quelli di GATHER a livello 5, 1.4 volte tanto a livello 1,
# la metà a livello 10
func gather_time(c: Colonist, job: Job) -> float:
	return GATHER[job][1] * (1.5 - c.skills[GATHER[job][0]] / 10.0)


# quanto c'è da raccogliere in `target` intatto: tronchi dell'albero, pietra (o minerale) del masso, bacche del cespuglio
func full_stock(target: Vector2i) -> int:
	if trees.has(target):
		return TREE_LOGS[trees[target]]
	if boulders.has(target):
		return STONE_PER_CELL * boulder_cells(target).size()
	return BERRIES_PER_BUSH


# cespugli con le bacche mature, non segnati da estirpare
func ripe_bushes() -> Array:
	return bushes.keys().filter(func(b): return bushes[b] <= clock and not uproot_marks.has(b))


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
	var shut := closed_cells(c)
	var dests := dest_cells(res).filter(func(cell): return not shut.has(cell))
	if dests.is_empty():
		return false  # magazzino pieno per questa risorsa, o dove lui non entra
	# drop può aver fatto traboccare tutto sulle caselle accanto (es. bacche su un mucchio di legna): lì non c'è niente
	var path := path_to_nearest(c, piles.filter(func(cell): return items[res].has(cell)))
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
	for o in colonists:
		var shut := closed_cells(o)
		if shut.has(cell_of(o.pos)) or o.path.any(func(k): return shut.has(k)):
			quit_job(o)


# Caselle dove gli altri coloni si fermeranno: fine del percorso (o dove sono, se fermi) e il cantiere di chi costruisce.
func claimed(except: Colonist) -> Dictionary:
	var cells := {}
	for o in colonists:
		if o != except:
			cells[cell_of(o.pos) if o.path.is_empty() else o.path.back()] = true
			if o.job in [Job.BUILD, Job.FURNISH]:
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


func add_item(res: Res, cell: Vector2i, amount: int) -> void:
	var ground: Dictionary = items[res]
	ground[cell] = ground.get(cell, 0) + amount
	if ground[cell] <= 0:
		ground.erase(cell)


# Posa a terra `amount` di `res` su `cell`; oltre STACK_MAX il resto va sulle caselle più vicine dove ci sta
# (niente alberi, acqua, altre risorse), come si allarga una macchia.
func drop(res: Res, cell: Vector2i, amount: int) -> void:
	var todo := [cell]
	var seen := {cell: true}
	while amount > 0 and not todo.is_empty():
		var k: Vector2i = todo.pop_front()
		if not trees.has(k) and not water.has(k) and items.keys().all(func(r): return r == res or not items[r].has(k)):
			var put := mini(amount, STACK_MAX[res] - items[res].get(k, 0))
			if put > 0:
				add_item(res, k, put)
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
		Order.UPROOT:
			for cell in bushes.keys() + weeds.keys():
				if rect.has_point(cell):
					uproot_marks[cell] = true
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
		var got: Dictionary = delivered.get([Job.FURNISH, origin], {})
		for res in got:  # il materiale già portato torna a terra
			drop(res, origin, got[res])
		delivered.erase([Job.FURNISH, origin])


# chi stava facendo `job` su `target` lascia a terra il materiale e torna libero
func drop_job(target: Vector2i, job: Job) -> void:
	var c: Colonist = reserved.get(target)
	if c and c.job == job and c.target == target:  # strutture e mobili possono stare sulla stessa casella
		quit_job(c)


# lascia il lavoro a metà: quello che ha in mano finisce a terra, i trasportatori lo riportano in magazzino
func quit_job(c: Colonist) -> void:
	drop(c.carry_res, cell_of(c.pos), c.carrying)
	c.carrying = 0
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
		return not furnished and [built, blueprints, draft].all(func(l): return l.get(cell, [Build.FLOOR])[0] == Build.FLOOR)
	return not built.has(cell) and not blueprints.has(cell) and (kind == Build.FLOOR or not furnished)


func build(cell: Vector2i) -> void:
	built[cell] = blueprints[cell]
	blueprints.erase(cell)
	if built[cell][0] == Build.WALL:
		astar.set_point_solid(cell)
		# ponytail: se non resta strada il colono lavora da dov'è; annullarne il lavoro se capita spesso
		for o in colonists:  # chi doveva passare di qui cerca un'altra strada
			if o.path.has(cell):
				o.path = path_of(o, cell_of(o.pos), o.path.back())
	if built[cell][0] != Build.FLOOR:
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
			if not room_meets(room, room.kind):  # abbattuto un mobile che serviva: torna senza tipo
				room.kind = RoomKind.NONE
			rooms.append(room)
	update_stockpile()
	update_lights()  # i muri fermano la luce


# Luci dei mobili in LIGHTS e muri che le fermano: si rifanno quando cambiano i muri o i mobili.
func update_lights() -> void:
	for node in lights.get_children() + occluders.get_children():
		node.free()
	for origin in furniture:
		var kind: Build = furniture[origin][0]
		if LIGHTS.has(kind):
			var light := PointLight2D.new()
			light.texture = light_texture
			light.texture_scale = LIGHTS[kind] * 2.0 * TILE / light_texture.get_width()
			light.color = LIGHT_COLOR
			light.shadow_enabled = true
			light.position = center(origin)
			lights.add_child(light)
	for cell in built:  # solo i lati liberi: quelli tra due muri farebbero ombre a triangolo sul muro accanto
		for i in WALL_LINKS.size():
			if built[cell][0] == Build.WALL and built.get(cell + WALL_LINKS[i], [-1])[0] != Build.WALL:
				var wall := LightOccluder2D.new()
				wall.occluder = wall_sides[i]
				wall.position = Vector2(cell * TILE)
				occluders.add_child(wall)


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
					if picked:
						open_sheet(picked)
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
		if layers.any(func(l): return l.has(next) and l[next][0] != Build.FLOOR):
			links |= 1 << i
	match plan[0]:
		Build.WALL: return tile_rect(links, plan[1])
		Build.FLOOR: return tile_rect(plan[1], 2)
		_: return tile_rect(1 if links & 5 and not links & 10 else 0, 3)  # porta: di lato se ha muri solo sopra e sotto


func draw_flat() -> void:  # sotto le ombre: il terreno lo disegna lo Sprite2D di bake_ground
	for cell in weeds:  # basse: niente ombra
		flat.draw_texture_rect_region(PLANTS, tile_rect(cell.x, cell.y), tile_rect(0, 0))
	for cell in built:
		if built[cell][0] == Build.FLOOR:
			flat.draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), structure_src(cell, built[cell], [built]))
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


# Le sagome di ciò che sta in piedi, coricate a terra dalla parte opposta al sole; il colore lo dà `shadows`.
func draw_shadows() -> void:
	for cell in built:
		if built[cell][0] != Build.FLOOR:
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
	for c in colonists:
		var dst := Rect2((c.pos - Vector2.ONE * TILE / 2.0).round(), Vector2.ONE * TILE)
		var src := Rect2(Vector2(frame_of(c), c.facing) * TILE, Vector2.ONE * TILE)
		for sheet in [COLONIST_BASE, COLONIST_HAIR, COLONIST_TUNIC, COLONIST_CAPE]:
			cast(sheet, dst, src)


# Disegna `src` di `tex` dov'è `dst`, ma coricato a terra da dove tocca terra: ogni pixel d'altezza va di sun_shadow.
func cast(tex: Texture2D, dst: Rect2, src: Rect2) -> void:
	var foot := Vector2(dst.get_center().x, dst.position.y + foot_of(tex, src))
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
		if built[cell][0] != Build.FLOOR:
			draw_texture_rect_region(STRUCTURES, tile_rect(cell.x, cell.y), structure_src(cell, built[cell], [built]))
	for cell in boulders:  # stanno dentro le loro caselle: niente ordine per righe
		draw_texture(boulder_tex(cell), Vector2(cell) * TILE)
	for cell in bushes:  # bassi, dentro la loro casella come i massi; con le bacche se sono mature
		draw_texture_rect_region(PLANTS, tile_rect(cell.x, cell.y), tile_rect(2 if bushes[cell] <= clock else 1, 0))
	draw_pieces(self, FURNITURE_SHEET, furniture)
	for room in rooms:  # cartelli: si cliccano per nome e tipo della stanza
		draw_texture(SIGN, Vector2(room.sign) * TILE)

	# alberi e coloni dall'alto in basso: chi sta più giù copre chi gli sta dietro
	# ponytail: si affida a `trees` già in ordine di riga; se gli alberi ricrescono, ordinarli o passare a nodi con y_sort
	var queue := colonists.duplicate()
	queue.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for cell in trees:
		while not queue.is_empty() and queue[0].pos.y < center(cell).y:
			draw_colonist(queue.pop_front())
		draw_texture_rect_region(TREES, Rect2(Vector2(cell.x, cell.y - 1) * TILE, Vector2(1, 2) * TILE),
			Rect2(Vector2(trees[cell], 0) * TILE, Vector2(1, 2) * TILE))
	for c in queue:
		draw_colonist(c)

	for cell in chop_marks:
		draw_mark(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), Order.CHOP)
	for origin in mine_marks:
		draw_mark(Rect2(Vector2(origin) * TILE, Vector2(boulders[origin]) * TILE), Order.MINE)
	for cell in uproot_marks:
		draw_mark(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), Order.UPROOT)
	for c in colonists:
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
func draw_lens() -> void:
	var font := info_label.get_theme_font("font")
	for room in rooms:
		for cell in room.cells:
			lens_canvas.draw_rect(tile_rect(cell.x, cell.y), Color(ROOM_COLORS[room.kind], 0.35))
		var mid := room_mid(room)
		if room.kind != RoomKind.NONE:
			lens_canvas.draw_string(font, mid + Vector2(-TILE * 4, 4), RoomKind.keys()[room.kind].capitalize(),
				HORIZONTAL_ALIGNMENT_CENTER, TILE * 8, 12)


# Sotto il tipo, sulla lente, le figurine dei proprietari: col mouse sopra, la loro scheda (vedi colonist_tip).
# Sono Control, se no niente suggerimento; si rifanno solo quando cambiano, se no il suggerimento sparirebbe
func place_owners() -> void:
	var now := rooms.map(func(r): return [room_mid(r), r.owners.duplicate()])
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
	var col: int = int(clock * DAY_LENGTH / FLAME_TIME) % 4 if LIGHTS.has(plan[0]) else plan[2]  # la fiamma guizza
	return [Rect2(Vector2(origin * TILE), size), Rect2(Vector2(col, plan[0] - Build.BED) * 32, size)]


# sprite del masso in `origin`: con le vene, se è di ferro o di carbone
func boulder_tex(origin: Vector2i) -> Texture2D:
	return ORE_ROCKS[ores[origin]] if ores.has(origin) else BOULDERS[boulders[origin]]


func draw_pieces(canvas: CanvasItem, sheet: Texture2D, layer: Dictionary, tint := Color.WHITE) -> void:
	for origin in layer:
		var r := piece_rects(origin, layer[origin])
		canvas.draw_texture_rect_region(sheet, r[0], r[1], tint)


func draw_colonist(c: Colonist) -> void:
	var at := (c.pos - Vector2.ONE * TILE / 2.0).round()  # allineato ai pixel
	var src := Rect2(Vector2(frame_of(c), c.facing) * TILE, Vector2.ONE * TILE)
	draw_figure(self, Rect2(at, Vector2.ONE * TILE), src, c)
	if c.carrying > 0:
		draw_texture_rect(ICONS[c.carry_res], Rect2(at + Vector2(8, 6), Vector2(8, 8)), false)
	if c.job == Job.SLEEP and c.path.is_empty():  # ponytail: niente sprite sdraiato, solo una "z" che sale
		draw_string(ThemeDB.fallback_font, at + Vector2(11, 2 - fmod(clock * DAY_LENGTH, 2.0) * 2), "z",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8)


# il colono `c` (il fotogramma `src` dei fogli) in `dst` di `canvas`: corpo, poi capelli, maglia e mantello tinti
func draw_figure(canvas: CanvasItem, dst: Rect2, src: Rect2, c: Colonist) -> void:
	canvas.draw_texture_rect_region(COLONIST_BASE, dst, src)
	canvas.draw_texture_rect_region(COLONIST_HAIR, dst, src, c.hair)
	canvas.draw_texture_rect_region(COLONIST_TUNIC, dst, src, c.tunic)
	canvas.draw_texture_rect_region(COLONIST_CAPE, dst, src, c.cape)


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
