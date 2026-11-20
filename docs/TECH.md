# King — Scelte tecniche

> Stato: bozza v0.1 — 2026-11-15

## Motore: Godot 4 + GDScript
- Gratuito, open source, nessuna royalty.
- Ottimo per 2D pixel art (TileMap, filtro "nearest", snap ai pixel).
- Export nativo per Windows e macOS.
- GDScript è simile a Python: la scelta più accessibile per chi ha poca esperienza.
- Molte risorse di apprendimento (documentazione ufficiale, tutorial).

## Localizzazione
- Sistema integrato di Godot (`TranslationServer`) con file gettext: `locale/<lingua>.po` (per ora `locale/it.po`),
  che Godot carica così com'è, senza importarlo. Ogni voce: `msgid` il testo inglese come lo usa il gioco, `msgstr` la
  traduzione; `msgctxt` separa le parole uguali con sensi diversi, `msgid_plural` e `msgstr[n]` i plurali (`tr_n`).
- I Control traducono da soli testi e suggerimenti che combaciano per intero (anche quelli messi dal codice, e
  seguono il cambio di lingua). Il testo composto nel codice (numeri, nomi, frasi a pezzi, `draw_string`) passa da
  `tr()`, il modello prima di riempirlo: `tr("Health: %d / %d") % [...]`. I segnaposto restano nello stesso ordine
  (il `%` di GDScript è posizionale): se l'italiano vuole un altro ordine, si gira la frase.
- I nomi degli enum (oggetti, mobili, abilità, talenti, leggi, ricerche...) li dà `named(Enum, valore, contesto)` in
  `main.gd`: il nome inglese è `Enum.keys()[valore].capitalize()`. Contesti: `item` per gli oggetti (Fish: il pesce;
  senza contesto è il pescare, il tasto in basso), `skill`, `branch`, `division` e `heraldry` per lo stemma.
- La wiki in gioco è a parte: `wiki.gd` in inglese, `locale/wiki_<lingua>.gd` tradotta, con le stesse pagine nello
  stesso ordine (vedi `pages` in `wiki.gd`).
- Lingua: tab System delle opzioni, salvata in `user://settings.cfg`; la applica la schermata del titolo. Senza
  scelta, quella del sistema. Cambiandola, le finestre composte si rifanno (vedi `set_language`); le righe già scritte
  nella cronaca restano nella lingua di quando sono state scritte.
- Inglese = lingua base, italiano = prima traduzione. Nuova lingua = nuovo `.po` (e la sua wiki), aggiunto in
  Project Settings → Localization e in `LANGUAGES` di `main.gd`.
- Controllo: `python3 tools/check_translations.py` elenca i testi senza traduzione (quelli in `tr()`, nelle scene e i
  nomi di `named`), i segnaposto o i tag BBCode diversi e le traduzioni che un Control ritradurrebbe.
- I test girano in inglese (`TranslationServer.set_locale("en")` all'inizio): confrontano i testi inglesi.

## Architettura (principi, non codice)
- **Simulazione separata dalla grafica**: lo stato del gioco (mappa, coloni, oggetti) è solo dati; la grafica lo legge e lo mostra.
- **Tick fisso** (es. 10 al secondo a 1×); la velocità di gioco cambia quanti tick per secondo.
- **Contenuti come dati**: edifici, oggetti, ricette, abilità, talenti, ricerche, leggi ed eventi sono tabelle di
  costanti (dizionari), una riga per cosa: quasi tutto in `main.gd`, il meteo in `atmosphere.gd`, gli eventi del
  narratore in `narrator.gd`. Niente file `.tres`: le tabelle si leggono e si confrontano meglio, e la wiki le legge
  da lì (`tools/make_wiki.py`). Gli effetti sono funzioni, la tabella dice quale.
- Pathfinding: `AStarGrid2D` integrato in Godot.

## Salvataggio
- Una cartella per colonia, `user://saves/<reame>_<secondi>/` (la sceglie `SAVES.create` nella pagina della nuova
  partita; in `main.gd` è `game_id`), con al più `SAVES.FILES` (3) file: `autosave_1.save` il più recente, poi 2 e 3. Ogni
  file è compresso (zstd, `FileAccess.open_compressed`); dentro due valori di `store_var`, uno dopo l'altro:
  l'**intestazione** (reame, sovrano, data, coloni, ora del salvataggio, `version`), che l'elenco legge da sola, e lo
  **stato**. Si scrive in `writing.tmp` e solo se è andato tutto bene i file scorrono (1 -> 2 -> 3, il 3 esce) e il nuovo
  diventa l'1: un salvataggio a metà non rovina quello di prima. Caricando, se l'1 non si legge si prova il 2, poi il 3.
  Si legge con `get_var` senza oggetti: un file non può far girare codice. Il codice è in `saves.gd` (file, elenco,
  impacchettamento) e `save_list.gd` (l'elenco delle colonie, nel titolo e nelle opzioni).
- **Cosa si salva**: le variabili di `main.gd` elencate in `SAVED`, così come sono (dizionari con `Vector2i`, colori,
  enum come interi, `INF`...), più il caso degli animali (`wild`: seme e stato), il meteo (`SAVED` di `atmosphere.gd`), il
  narratore (`SAVED` di `narrator.gd`: l'evento di oggi che aspetta la sua ora, le pause) e la telecamera. Gli oggetti delle classi interne (Colonist, Animal, Arrow, Room, Ruin, Expedition) li impacchetta
  `SAVES.Packer`: ognuno diventa un dizionario coi suoi campi (tutte le variabili dello script, da sole: un campo nuovo
  si salva senza toccare niente), e i riferimenti tra loro (`ruler`, proprietari delle stanze, `reserved`, prede...)
  diventano `{"@": classe, "#": indice}`, così dopo il caricamento sono di nuovo lo stesso oggetto.
- **Cosa si rifà** (`restore`, `resume`): la griglia dei percorsi (`rebuild_grid`: roccia, acqua, muri, strade, ghiaccio),
  tetti e magazzini (`update_roofs`, `update_stockpile`), il terreno disegnato (dal seme della mappa, `map_seed`, dalle
  varianti delle caselle, `ground_cols`, e dalla roccia di partenza, `gravel`: dove si è scavato resta ghiaia), i fuochi e le luci (da sé), le finestre.
- **Una variabile nuova dello stato della partita in `main.gd` va aggiunta a `SAVED`** (in `atmosphere.gd` e
  `narrator.gd` al loro `SAVED`); quelle delle classi interne no. Un campo che non c'è più nel salvataggio si ignora, uno nuovo resta al valore
  di partenza. Se cambia il senso dei dati (per esempio un valore nuovo in mezzo a un enum) si alza `SAVES.VERSION` e si
  converte in `restore`: un salvataggio di una versione più nuova non si carica.
- Quando (`autosave`): fondata la colonia (fine di `_ready`), all'alba (`AUTOSAVE_HOUR`, finito il tick), tornando al
  titolo o caricando un'altra colonia (`go_to`), con Quit game e chiudendo la finestra (`NOTIFICATION_WM_CLOSE_REQUEST`).
  Niente salvataggi a mano. Senza cartella non si salva: nei test, o aprendo `main.tscn` da sola (i test che provano i
  salvataggi usano un'altra cartella, `SAVES.dir`). Una colonia caduta non si salva. Si carica dal titolo (Continue,
  Colonies) e dalle opzioni (Load game): `SAVES.pending` porta lo stato letto a `main.tscn`, che in `_ready` lo rimette
  al posto di una partita nuova. Una partita caricata parte in pausa.
- Cloud, due opzioni:
  - **Steam Cloud**, se il gioco finisce su Steam (100 $ una tantum): quasi zero lavoro.
  - **Supabase** (piano gratuito): login + upload/download del file via REST (`HTTPRequest`). Indipendente da Steam.
- Decisione rimandata a dopo l'MVP; il formato a file unico funziona con entrambe.

## macOS
- Per uso personale l'export funziona senza firma (primo avvio: tasto destro → Apri).
- Per distribuirlo ad altri serve account Apple Developer (99 $/anno) per firma e notarizzazione. Rimandato.

## Grafica
- Sprite attuali: disegnati come griglie di caratteri in `tools/make_sprites.py` → PNG in `art/` (`python3 tools/make_sprites.py`). Le parti bianche (capelli, maglia) vengono tinte in gioco per ogni colono.
- Logo, splash e schermata del titolo: `tools/make_splash.py` (usa gli sprite di `make_sprites.py`) → `art/title_scene.png` (scena di notte, 16 fotogrammi uno sotto l'altro), `art/title_logo.png`, prove di splash in `art/splash/`. Il gioco parte da `title.tscn` (menu), "New Game" apre `main.tscn`.
- Personaggi: fogli 96×64 (4 direzioni × 6 fotogrammi) disegnati uno sull'altro, nell'ordine di `figure_layers` in `main.gd`
  (corpo, maglia, mantello, armatura, capelli, acconciatura, barba, copricapo, oggetto in mano). I fogli con più voci
  (`colonist_hair_styles`, `colonist_gear`, `colonist_hands`) le hanno una sotto l'altra, 64 px ciascuna. Elmo, cappuccio
  e armature sono ricavati dai capelli e dalla tunica del corpo, così seguono ogni fotogramma; acconciature, corredo e
  oggetti in mano sono timbri dentro il fotogramma. Si tingono in gioco capelli, maglia, mantello e cappuccio.
- Editor: Aseprite (a pagamento, o compilabile gratis) o LibreSprite/Pixelorama (gratuiti).
- All'inizio: asset pack gratuiti/segnaposto (itch.io, Kenney) per non bloccarsi sulla grafica.
- Palette limitata fissa (es. una palette da Lospec) per coerenza.
- Testo: PixelifySans (`fonts/`), senza antialiasing, a **22** in tutto il tema (`theme.tres`, `default_font_size`). Il
  font è disegnato su una griglia di 11 pixel per em: è nitido solo a 11, 22, 33, 44... A 22 lo resta anche con la
  finestra ingrandita a 1920×1080 (33) e 2560×1440 (44); a 16, come prima, un suo pixel diventava 1,45 pixel di schermo e
  i tratti uscivano di spessori diversi. Le grandezze scelte a mano (titolo 44, nuova partita 33, gantt dei campi 22)
  stanno su quella griglia. L'interfaccia è pensata per 1280×720: la scheda del colono è a due colonne (`columns.gd`),
  la barra in alto ci sta di misura (numeri senza larghezza fissa, Debug come tab delle opzioni, Wiki accanto
  all'ingranaggio): con nomi lunghi o gli allarmi la data si accorcia coi puntini.

## Interfaccia: barre, menu, segni e progetto
Deciso il 2026-11-20 (bozzetti provati sulle schermate). Le idee: in basso a sinistra le azioni sulla mappa, a sinistra
le finestre in un menu che scompare, in basso a destra il tempo, in alto le informazioni.
- **La velocità** (pausa, 1×, 2×, 3×) in basso a destra, in un pannello suo; Spazio, 1, 2, 3 restano. Il riquadro con
  quello che c'è sotto il mouse, che stava in quell'angolo, sale sopra il pannello.
- **La barra in basso**: Seleziona · Costruisci · Ordini · Distruggi | Viste. **Ordini** apre la sua barra, come
  Costruisci apre le categorie: Taglia, Scava, Estirpa, Raccogli, Orto, Pesca, Caccia, Ghiaccio (Orto e Ghiaccio quando
  la ricerca li sblocca). **Viste** apre la sua: Stanze, Calore, Terra, Tetti. I tasti restano tutti (C, M, U, H, P, F,
  T, Y; L, N, O, V): scelgono direttamente e aprono la barra. Un triangolino d'oro nell'angolo del tasto dice che apre
  una barra.
- **In costruzione non si danno ordini**: il tasto Ordini è spento (col mouse sopra: prima chiudi la costruzione) e i
  suoi tasti rapidi non fanno niente. Distruggi resta: abbattere fa parte del rifare. Seleziona, Distruggi, Esc o di
  nuovo Costruisci chiudono la costruzione. Le Viste, il menu e la velocità restano.
- **Il menu a scomparsa a sinistra**: chiuso, una linguetta sul bordo sinistro sotto la barra in alto; con un clic o
  con Tab scivola fuori: Lavori (J), Risorse (I), Abitanti (A), Conoscenza (K, con uno studio), Leggi (G, con una sala del
  trono), Cronaca (D), ognuna con icona, nome e tasto. Scelta una finestra si richiude. La finestra aperta in oro; un
  pallino d'oro dove c'è qualcosa da fare (una ricerca da studiare subito, una legge da codificare o promulgare,
  qualcuno che chiede di restare, voci nuove nella cronaca), e sulla linguetta a menu chiuso. Il numero dei coloni in
  alto apre ancora gli abitanti, la data il calendario. In alto a destra restano Wiki, Schermo e Opzioni.
- **Esc**: chiude prima quello che è aperto (la costruzione, l'ordine scelto, il menu), poi le opzioni.
- **I segni di raccolta**: niente più icona velata. L'oggetto segnato ha un contorno di 1 pixel nel colore del suo
  ordine (arancio tagliare, azzurro scavare, rosa raccogliere, giallo estirpare, rosso aranciato cacciare; prima
  estirpare era verde chiaro e sul prato spariva), che segue la sua sagoma e si disegna con lui (chi gli passa davanti
  lo copre). Gli animali da cacciare hanno il contorno sulla loro sagoma; pesca e ghiaccio, caselle d'acqua senza un
  oggetto, una cornice del colore dell'ordine. I contorni sono fogli fatti da `tools/make_sprites.py`, come le sagome.
- **Il progetto in blu** (quello posato in costruzione e non ancora confermato) **resta**: uscendo dalla costruzione e
  nel salvataggio. Finché c'è, in alto al centro la **targa del progetto**: cosa c'è (23 muri, 1 porta, 1 letto), quanto
  costa (in rosso quello che in magazzino non basta), Costruisci (diventa lavoro), Modifica (riapre la costruzione, solo
  da fuori), Scarta (via tutto il blu: il primo clic chiede conferma). In costruzione il **clic destro** su un pezzo lo
  toglie dal progetto, anche già confermato ma non costruito (il materiale portato torna in magazzino); per un'area la
  **gomma** (il tasto che prima era la X rossa) o Maiusc + trascinamento. Il destro trascinato resta per spostare la
  telecamera.
- **Ordine di lavoro**: (1) barre e menu (velocità, Ordini e Viste, gli ordini spenti in costruzione, il menu a
  sinistra, Esc); (2) i segni a contorno; (3) il progetto in blu che resta, la targa, il clic destro e la gomma.
- **Stato**: fatta la fase 1 il 2026-11-20 (prove in `tests/test_options.gd`). I tasti dei comandi stanno in barre
  diverse (`TOOL_BARS`): il codice e le prove li trovano per nome con `tool()`, non per percorso. La barra delle Viste
  si apre accanto a quella in basso, alla sua altezza (sopra c'è il posto di Ordini e delle categorie di
  Costruisci). Ordini e Viste non hanno un tasto rapido loro (lo hanno i loro comandi), ma si può dare nelle opzioni.
  Fatta la fase 2 lo stesso giorno (prove dei fogli in `tests/test_jobs.gd`): i fogli dei contorni hanno ogni riquadro
  largo un pixel in più per lato (se no il contorno di uno sprite che tocca il bordo, come la quercia, resta tagliato),
  e `draw_outline` li disegna un pixel più grandi, tinti col colore dell'ordine, subito dopo lo sprite. La caccia è
  passata a un rosso aranciato (`ff6a40`): il marrone di prima sul coniglio non si vedeva.
  Fatta la fase 3 lo stesso giorno (prove in `tests/test_jobs.gd`, il salvataggio in `tests/test_saves.gd`): chiudere la
  costruzione non scarta più `draft` e `furniture_draft` (che si salvavano già). La targa è `$HUD/Actions`, rifatta da
  `update_plate` solo quando cambia quello che dice; in costruzione senza progetto dice come si toglie. Il clic
  destro conta se lo si lascia entro 4 pixel da dove lo si è premuto (se no era la telecamera) e toglie prima il
  mobile, poi la struttura (`erase_piece`); la gomma e Maiusc usano `erase_area`. Il clic sulla mappa prende il punto
  dall'evento (`map_point`), non dal mouse: le prove possono così cliccare e trascinare sulla mappa (`map_click`).

## Interfaccia: la produzione
Deciso il 2026-11-20 (bozzetti provati sulle schermate). L'idea: della produzione si deve vedere, senza andarlo a
cercare, quanto c'è, quanto se ne vuole, chi lo sta facendo e perché una cosa non si fa. Quattro pezzi con gli stessi
segni: il riquadro dell'icona, le tacche (una per pezzo: piena quello che c'è, a metà quello in lavorazione, vuota
quello che manca) e quattro colori (oro si vuole, arancio si sta facendo, rosso è fermo, verde è a posto).
- **Il menu della postazione** (clic su una postazione, come ora). In testa il suo disegno, il nome, la stanza col
  comfort e chi ci lavora adesso; la riga rossa di quando non lavora (fuori dalla sua stanza, la ruota ferma) resta.
  Poi una riga per oggetto, con le colonne allineate: il riquadro con l'icona, il tipo e il nome (col mouse sopra
  l'effetto del pezzo); **Ci vuole**, gli ingredienti con le icone grandi, in rosso quello che nei mucchi liberi non
  basta; **Ce ne sono**, le tacche e «2 / 4», quanti ce ne sono su quanti se ne vogliono (verde se è a posto, «non si
  fa» se non se ne vogliono); **Coloni**, quanti lo prenderebbero (solo l'equipaggiamento: oggi si sommano a «Keep»
  senza farsi vedere, e non si capisce perché si fa un elmo con la scorta a 0); **Scorta**, quanti tenerne, con − e +
  al posto di «Keep N». Sotto la riga, solo quando c'è qualcosa da dire: chi lo sta facendo, con la barra e i secondi
  che mancano, o in rosso perché è fermo («servono 6 lingotti, liberi ce ne sono 3»). Il pasto dice «2 crudi uguali»
  e sotto i crudi che ci sono. Si aggiorna mentre è aperto.
- **La finestra Produzione**, nel menu a sinistra dopo le Risorse (tasto S: E e R girano i mobili), con due schede.
  - **Officine**: un riquadro per tipo di postazione costruita, col suo disegno, il nome e la stanza: chi ci lavora e
    a che punto è (figurina, oggetto, barra), «Poi» gli oggetti che mancano (icona e quanti; in rosso quelli fermi,
    col perché), oppure «Libera» o «Niente da fare». Il bordo: arancio se ci si lavora, rosso se è ferma. In alto il
    conto: al lavoro, in coda, ferme. Clic sul riquadro: il menu della postazione.
  - **Catene**: dalle materie prime agli oggetti, a fasce (cucina, grano, metallo, filo e legno, cuoio e carte) come i
    rami della Conoscenza. Un riquadro per bene (icona, nome, quanti ce ne sono, con la scorta se ne ha una) e, davanti
    a ogni bene che si fa, il riquadro della postazione che lo fa; gli oggetti finiti di una stessa postazione stanno
    insieme, solo icone. I collegamenti hanno il colore dello stato: oro si vuole e si può, arancio si sta facendo,
    rosso è fermo, grigio non è chiesto. Si vedono solo le ricette sbloccate.
- **Sulla mappa**: sopra la postazione dove si lavora un fumetto con l'oggetto e la barra (al posto della barretta
  gialla sulla testa di chi lavora); sopra quella che ha qualcosa da fare e non può, un fumetto rosso con quello che
  manca e il punto esclamativo. Le postazioni libere niente. Col mouse sopra, il riquadro in basso a destra dice chi
  lavora e a cosa, e cosa viene dopo.
- **Il perché** (`make_block`): la postazione non lavora; il quaderno senza abbastanza studio; un ingrediente che nei
  mucchi liberi non basta (il primo che manca, con quanto ce n'è). Se non manca niente e nessuno lo fa, è in coda: lo
  farà il primo che ha tempo.
- **Ordine di lavoro**: (1) il menu della postazione; (2) la finestra Produzione con le Officine; (3) le Catene; (4) i
  fumetti sulla mappa e il riquadro col mouse sopra.
- **Stato**: fatta la fase 1 il 2026-11-20 (prove in `tests/test_gear.gd`, il pasto in `tests/test_food.gd`). Il menu
  si fa una volta (`open_craft`, una riga per oggetto da `craft_row`) e `refresh_craft` lo aggiorna a ogni fotogramma;
  lo rifà da capo solo se cambiano gli oggetti o il banchetto (`craft_signature`). Lo stato di un oggetto è
  `make_state` (quanti ce ne sono, chi lo fa, quanti ne mancano, quanti coloni lo chiedono: `gear_asked`), il perché
  `make_block`. Le celle di una riga hanno il nome della loro colonna (`CRAFT_COLUMNS`): `open_craft` le allarga uguali
  e ci mette sopra i titoli; la colonna dei coloni c'è solo dove si fa equipaggiamento. Le parti fisse della finestra
  le aggiunge `setup_craft_popup`, dopo che la finestra del pascolo se n'è fatta una copia (resta com'era, con «Keep»).
  Di quello che non si vuole si vede solo quanti ce ne sono, senza tacche; oltre 12 pezzi le tacche sono una barra.
  Fatta la fase 2 lo stesso giorno (prove in `tests/test_gear.gd`, il menu e il tasto in `tests/test_options.gd`). La
  finestra è fatta nel codice (`build_production_panel`), il suo tasto sta in `main.tscn` con gli altri del menu; l'icona
  (`icon_production`, l'incudine col martello) viene da `tools/make_sprites.py`. Un riquadro per tipo di postazione
  (`STATION_ORDER`: una ricetta su una postazione nuova la vuole lì dentro, lo controlla la prova), solo quelle
  costruite, anche fuori dalla loro stanza (`shop_state`, `shop_card`). `fill_shops` rifà i riquadri solo se è cambiato
  qualcosa, e guarda ogni 6 fotogrammi; le barre di chi lavora si aggiornano a ogni fotogramma (`production_bars`). Dei
  lavoratori si vedono i primi due, degli oggetti che mancano i primi 8. Per ora una scheda sola: le Catene con la fase 3.

## Versionamento
- Git + GitHub (`Yanez86/king`).
- Git LFS se gli asset binari crescono molto (non necessario ora).
- Wiki delle meccaniche su GitHub Pages (https://yanez86.github.io/king/, da `main` → `/docs`): `python3 tools/make_wiki.py`
  rigenera `docs/index.html` (italiano, da `locale/wiki_it.gd`) e `docs/en.html` (inglese, da `wiki.gd`), con le
  costanti di `main.gd`, `atmosphere.gd` e `narrator.gd`. Le icone sono quelle del gioco, ritagliate dai PNG di `art/` (pulsanti di
  `main.tscn`, fogli `*_SHEET`), davanti ai nomi delle cose nelle tabelle e negli elenchi; la sezione "Da sviluppare"
  viene dal GDD (fasi degli "Ordine di lavoro" non ancora fatte, i "Poi:", ricerche e leggi senza ✓). Va rifatta e
  committata quando cambiano il gioco o il GDD.
