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
- **Contenuti come dati**: edifici, oggetti, ricette, abilità, talenti, eventi definiti in file di risorse Godot (`.tres`), non nel codice.
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
  enum come interi, `INF`...), più il caso degli animali (`wild`: seme e stato), il meteo (`SAVED` di `atmosphere.gd`) e
  la telecamera. Gli oggetti delle classi interne (Colonist, Animal, Arrow, Room, Ruin, Expedition) li impacchetta
  `SAVES.Packer`: ognuno diventa un dizionario coi suoi campi (tutte le variabili dello script, da sole: un campo nuovo
  si salva senza toccare niente), e i riferimenti tra loro (`ruler`, proprietari delle stanze, `reserved`, prede...)
  diventano `{"@": classe, "#": indice}`, così dopo il caricamento sono di nuovo lo stesso oggetto.
- **Cosa si rifà** (`restore`, `resume`): la griglia dei percorsi (`rebuild_grid`: roccia, acqua, muri, strade, ghiaccio),
  tetti e magazzini (`update_roofs`, `update_stockpile`), il terreno disegnato (dal seme della mappa, `map_seed`, dalle
  varianti delle caselle, `ground_cols`, e dalla roccia di partenza, `gravel`: dove si è scavato resta ghiaia), i fuochi e le luci (da sé), le finestre.
- **Una variabile nuova dello stato della partita in `main.gd` va aggiunta a `SAVED`** (in `atmosphere.gd` al suo
  `SAVED`); quelle delle classi interne no. Un campo che non c'è più nel salvataggio si ignora, uno nuovo resta al valore
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

## Versionamento
- Git + GitHub (`Yanez86/king`).
- Git LFS se gli asset binari crescono molto (non necessario ora).
- Wiki delle meccaniche su GitHub Pages (https://yanez86.github.io/king/, da `main` → `/docs`): `python3 tools/make_wiki.py`
  rigenera `docs/index.html` (italiano, da `locale/wiki_it.gd`) e `docs/en.html` (inglese, da `wiki.gd`), con le
  costanti di `main.gd` e `atmosphere.gd`. Le icone sono quelle del gioco, ritagliate dai PNG di `art/` (pulsanti di
  `main.tscn`, fogli `*_SHEET`), davanti ai nomi delle cose nelle tabelle e negli elenchi; la sezione "Da sviluppare"
  viene dal GDD (fasi degli "Ordine di lavoro" non ancora fatte, i "Poi:", ricerche e leggi senza ✓). Va rifatta e
  committata quando cambiano il gioco o il GDD.
