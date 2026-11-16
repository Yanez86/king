# King — Game Design Document

> Stato: bozza v0.1 — 2026-11-15

## 1. Visione

Gestionale/colonia in pixel art, vista dall'alto, per PC e Mac.
Il giocatore è il **re** di un piccolo reame medievale: non controlla mai direttamente
i coloni né il re, ma decide **cosa** va fatto e con **quale priorità**.
Le storie emergono da coloni con abilità e talenti, stagioni ostili, eventi casuali
e una **dinastia** che continua dopo la morte del re.

Riferimenti: RimWorld (lavori, talenti, narratore), Going Medieval (ambientazione, freddo),
Anno (catene produttive), Crusader Kings (dinastia), Dwarf Fortress (storie emergenti).

## 2. Vincoli

- Sviluppatore singolo, poca esperienza → **scope minimo, iterazioni piccole**.
- Piattaforme: Windows, macOS.
- Lingue: inglese (base), italiano; nuove lingue aggiungibili senza toccare il codice.
- Salvataggio cloud.
- Progetto personale, nessuna monetizzazione.

## 3. Ciclo di gioco

1. Osservi la colonia (tempo in pausa / 1× / 2× / 3×).
2. Dai ordini: designi aree da tagliare/scavare, piazzi progetti di edifici, imposti ricette.
3. I coloni scelgono da soli il lavoro in base alle priorità.
4. Le risorse diventano beni (catene produttive), i beni migliorano coloni e strutture.
5. Eventi e stagioni mettono alla prova la colonia → reagisci → ripeti.

## 4. Sistemi

### 4.1 Lavori e priorità
- Tipi di lavoro (MVP): Costruire, Tagliare legna, Estrarre, Raccogliere/Trasportare, Cucinare, Produrre (artigianato), Coltivare.
- Ogni colono ha una tabella colono × lavoro con priorità 1–4 (o disattivato).
- Default sensati, modificabili dal giocatore.
- Il colono sceglie il lavoro disponibile con priorità più alta, poi il più vicino.

### 4.2 Coloni
- **Bisogni**: fame, riposo, comfort, felicità; calore in seguito.
- **Stress** (0–100, con icona): sale lavorando, scende dormendo o a riposo; abbassa la felicità. Altri effetti in seguito.
- **Abilità** (livelli 1–10, al 10 una stellina): raccogliere, estrarre, tagliare legna, costruire, cucinare, pescare, cacciare, armi da mischia, armi a distanza, ricerca (lista provvisoria). Velocità e qualità del lavoro; crescono con l'uso.
- **Talenti**: modificano alcune routine dei coloni, ognuno con un'icona 16×16 (es. "Robusto": +resistenza al freddo; "Pigro": −velocità lavoro; "Pirofobo": rifiuta di cucinare). Primi: goloso, sonnambulo, iracondo.
  Il **goloso** va a mangiare già a fame 50 (gli altri a 30), si gode il doppio i bonus dei pasti e si lamenta se mangia crudo; sonnambulo e iracondo ancora senza effetto.
- **Condizioni**: effetti a tempo, con un'icona 16×16 nella scheda sotto i talenti (col mouse sopra: nome, effetto, ore che mancano).
  Cambiano tempo di lavoro, stress da lavoro e felicità:

  | Condizione | Durata | Lavoro | Stress da lavoro | Felicità |
  |---|---|---|---|---|
  | Intossicato (crudo andato a male) | 1 giorno | +50% tempo | — | −20 |
  | Ben nutrito (pasto) | ½ giorno | −10% tempo | −25% | +5 |
  | Pasto squisito | ½ giorno | −20% tempo | −50% | +10 |
  | Mangiato al tavolo | ½ giorno | — | — | +5 |
  | Mangiato crudo (solo il goloso) | ½ giorno | — | — | −10 |

  Ben nutrito e pasto squisito si escludono: vale l'ultimo pasto. Poi: malattie dal narratore, perdita di punti ferita.
- **Scheda** (clic sul colono): nome, soprannome (facoltativo), cognome, punti ferita, abilità (ognuna con un'icona 8×8), talenti (solo icone, il nome col mouse sopra), equipaggiamento (3 slot: mani, corpo, testa). Poi bisogni, relazioni.

### 4.3 Il re e la dinastia
- Il re è un colono speciale: lavora poco, il suo stato dà bonus/malus al reame.
- Può sposarsi, avere figli; i figli crescono e ereditano parte dei talenti.
- Alla morte del re: successione all'erede (regola semplice: primogenito). Nessun erede → game over (o fine della dinastia).
- MVP: solo matrimonio, figli, successione. Intrighi/vassalli fuori scope.

### 4.4 Risorse ed edifici
- Materie prime: legname, pietra, ferro, carbone, oro, cibo crudo. Ferro e carbone vengono dalle vene nella roccia (massi 1x1).
- Catene MVP:
  - Legname → assi (banco da falegname)
  - Ferro grezzo → lingotti (fornace) → attrezzi (fucina)
  - Cibo crudo → pasto (cucina, vedi 4.4.1)
- Attrezzi equipaggiati = bonus all'abilità corrispondente.
- Edifici MVP: muri, porte, tetto, letto, focolare, cucina, magazzino (zona), banco da lavoro, fornace, fucina.
- Stanze chiuse con tetto proteggono da pioggia e freddo; il focolare scalda.
- **Stanze**: zona chiusa da muri con una porta; il cartello sul muro accanto alla porta apre nome e tipo.
  Tipi: magazzino; camera (1 letto); dormitorio (2 letti); cucina (fuoco da campo, poi anche stufa); forgia (fornace e incudine).
  Un tipo si sceglie solo se ci sono i mobili (gli altri non compaiono); tolti, la stanza torna senza tipo.
  Ogni stanza può avere uno o più proprietari tra i coloni: un colono entra (anche solo per passarci) solo nelle
  stanze sue o senza proprietari. Una stanza **bandita** è vietata a tutti, anche ai proprietari.
- **Lenti**: evidenziano cose sulla mappa. Prima: la lente delle stanze, ogni stanza finita velata col colore del suo tipo,
  sotto il tipo i proprietari (col mouse sopra, la loro scheda).
- **Comfort della stanza** (0–10): mobili per pezzo e pavimento, secondo il materiale (pietra ×1,5). A 5 nessun effetto;
  a 0 (anche fuori dalle stanze) le attività durano il 20% in più, a 10 il 20% in meno. Per ora vale per il sonno
  (8 ore a comfort 5) e per cucinare, dove cambia anche la probabilità di bruciare il pasto o farlo squisito.
  Sotto le 6 caselle a testa il comfort cala in proporzione.

### 4.4.1 Cibo e cucina
- **Freschezza**: ogni mucchio di cibo ha i giorni che gli restano (mescolando due mucchi, la media pesata).
  A terra fuori il cibo dura 3 giorni, in magazzino il doppio; poi marcisce e sparisce. Il suggerimento sul mucchio
  dice "Fresh / Stale / Almost rotten" e fra quanti giorni marcisce. Poi: dispensa fredda e inverno (più lento), marcio da buttare.
- **Crudo** (vegetali): sazia 35. Può intossicare: 5% appena raccolto, fino al 40% quasi marcio.
- **Pasti**: 2 vegetali → 1 pasto, che sazia 100 e dà *ben nutrito*. Non intossica.
  Chi ha fame prende prima un pasto squisito, poi un pasto, il crudo solo se non ce ne sono.
  Se entro 20 caselle c'è una sedia libera accanto a un tavolo, lo porta lì e lo mangia seduto (*mangiato al tavolo*).
- **Cucinare** (abilità cucinare): in una stanza di tipo cucina, accanto al fuoco da campo. Il cuoco prende 2 vegetali dal
  mucchio più vicino, cucina, il pasto cade ai suoi piedi e lo porta in magazzino. Si cucina finché in giro
  (a terra, in magazzino, in mano) ci sono meno di 2 pasti a colono; nella finestra Jobs: "Cook meals: N".
  Poi: ricette e quantità impostabili dal cartello della cucina.
  - Tempo: 8 s a livello 5 (×1,4 a livello 1, ×0,5 a livello 10), secondo il comfort della cucina (±20%) e le condizioni del cuoco.
  - +1 punto esperienza per pasto.
  - **Bruciato** (vegetali persi): 6% per livello sotto il 6 (30% a livello 1), +3% per punto di comfort della cucina sotto 5 (sopra lo abbassa).
  - **Squisito**: 5% per livello sopra il 5 (25% a livello 10), +2% per punto di comfort sopra 5. Dà *pasto squisito*.
- Poi: carne e pesce (caccia, pesca), stufato, conserve per l'inverno.
- **Raccogliere** (tasto "Harvest", cestino, dopo "Uproot"): si segnano i cespugli; i coloni ne raccolgono le bacche ogni
  volta che maturano (5 ogni 2 giorni), finché il segno resta, e le portano in magazzino. Segnare "Uproot" toglie il segno e viceversa.
  Un colono mangia circa 2 vegetali al giorno se cucinati, 2,6 crudi; un cespuglio ne dà 2,5: 1–2 cespugli a testa.

### 4.5 Mondo e tempo
- Mappa a tile, singolo livello, ~100×100.
- Ciclo giorno/notte, quattro stagioni; inverno = freddo e niente raccolti.
- Meteo semplice: sereno, pioggia, neve, ondata di freddo.

### 4.6 Eventi casuali
- Un "narratore" pesca eventi con probabilità che dipende dallo stato della colonia.
- Ogni evento è un file di dati (condizioni, peso, effetti, testi localizzati).
- Lista da definire. Esempi segnaposto: arrivo di un viandante, malattia, incendio, ondata di freddo, raccolto abbondante.

## 5. Scope

### MVP (primo traguardo giocabile)
Mappa, 3–5 coloni, tagliare/estrarre/costruire/cucinare, priorità, fame/riposo/freddo,
una stagione invernale, salvataggio locale, inglese + italiano.

### Dopo l'MVP (in ordine)
1. Catene produttive e attrezzi
2. Re, matrimonio, figli, successione
3. Narratore ed eventi
4. Salvataggio cloud
5. Umore, relazioni, più talenti

### Fuori scope (per ora)
Combattimento tattico, livelli verticali, commercio/diplomazia, mod.

## 6. Domande aperte
- Dimensione dei tile: 16×16 o 32×32?
- Condizione di sconfitta oltre alla fine della dinastia?
- Lista degli eventi.
- Nome definitivo del gioco.
