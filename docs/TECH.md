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
- Solo automatici, locali, più colonie (vedi GDD 4.7). `saves.gd`: una cartella per colonia in `user://saves/`, con
  `autosave_1.save` (il più recente), `_2` e `_3`. Un file è un dizionario scritto con `store_var` e compresso (zstd):
  `version`, `info` (per l'elenco del titolo), `state`. Si scrive su un file temporaneo e solo dopo si fanno scorrere
  gli altri: un crash a metà non rovina l'ultimo salvataggio buono.
- Binario di Godot e non JSON: tiene da solo `Vector2i`, `Color` e `INF`, con meno codice.
- `main.gd`, `save_state` / `load_state`: gli enum si salvano per nome (aggiungere una voce in mezzo non rompe i vecchi
  salvataggi), i riferimenti tra oggetti (proprietari delle stanze, lupi che inseguono) come indici dei coloni. Non si
  salvano i lavori a metà; si ricostruiscono pathfinding, stanze, magazzini e il terreno disegnato (dal seme della
  mappa e dalla roccia iniziale, `gravel`, così torna identico).
- Quando cambia il formato di `state`: aumentare `Saves.VERSION` e convertire i vecchi in `load_state`.
- Un salvataggio pesa ~17 KB e richiede pochi millisecondi (vedi `tests/test_save.gd`).
- Cloud, due opzioni:
  - **Steam Cloud**, se il gioco finisce su Steam (100 $ una tantum): quasi zero lavoro.
  - **Supabase** (piano gratuito): login + upload/download del file via REST (`HTTPRequest`). Indipendente da Steam.
- Decisione rimandata a dopo l'MVP; basta sincronizzare la cartella `user://saves/`.

## macOS
- Per uso personale l'export funziona senza firma (primo avvio: tasto destro → Apri).
- Per distribuirlo ad altri serve account Apple Developer (99 $/anno) per firma e notarizzazione. Rimandato.

## Grafica
- Sprite attuali: disegnati come griglie di caratteri in `tools/make_sprites.py` → PNG in `art/` (`python3 tools/make_sprites.py`). Le parti bianche (capelli, maglia) vengono tinte in gioco per ogni colono.
- Logo, splash e schermata del titolo: `tools/make_splash.py` (usa gli sprite di `make_sprites.py`) → `art/title_scene.png` (scena di notte, 16 fotogrammi uno sotto l'altro), `art/title_logo.png`, prove di splash in `art/splash/`. Il gioco parte da `title.tscn` (menu), "New Game" apre `main.tscn`.
- Editor: Aseprite (a pagamento, o compilabile gratis) o LibreSprite/Pixelorama (gratuiti).
- All'inizio: asset pack gratuiti/segnaposto (itch.io, Kenney) per non bloccarsi sulla grafica.
- Palette limitata fissa (es. una palette da Lospec) per coerenza.

## Versionamento
- Git + GitHub (`Yanez86/king`).
- Git LFS se gli asset binari crescono molto (non necessario ora).
