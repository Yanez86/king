# King — Scelte tecniche

> Stato: bozza v0.1 — 2026-11-15

## Motore: Godot 4 + GDScript
- Gratuito, open source, nessuna royalty.
- Ottimo per 2D pixel art (TileMap, filtro "nearest", snap ai pixel).
- Export nativo per Windows e macOS.
- GDScript è simile a Python: la scelta più accessibile per chi ha poca esperienza.
- Molte risorse di apprendimento (documentazione ufficiale, tutorial).

## Localizzazione
- Sistema integrato di Godot (`TranslationServer`) con un file CSV: una colonna per lingua.
- Tutto il testo nel codice e nei dati è una chiave (es. `JOB_COOK`), mai testo diretto.
- Inglese = lingua base, italiano = prima traduzione. Nuova lingua = nuova colonna.

## Architettura (principi, non codice)
- **Simulazione separata dalla grafica**: lo stato del gioco (mappa, coloni, oggetti) è solo dati; la grafica lo legge e lo mostra.
- **Tick fisso** (es. 10 al secondo a 1×); la velocità di gioco cambia quanti tick per secondo.
- **Contenuti come dati**: edifici, oggetti, ricette, abilità, talenti, eventi definiti in file di risorse Godot (`.tres`), non nel codice.
- Pathfinding: `AStarGrid2D` integrato in Godot.

## Salvataggio
- Un unico file per partita: lo stato serializzato (JSON o binario di Godot), compresso.
- Prima versione: solo salvataggio locale.
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
