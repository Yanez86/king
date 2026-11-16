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
- **Bisogni**: fame, riposo, divertimento, comfort, felicità; calore in seguito. Il divertimento scende da svegli e sale svagandosi.
- **Stress** (0–100, con icona): sale lavorando, scende dormendo o a riposo; abbassa la felicità. Altri effetti in seguito.
- **Routine**: ogni ora del giorno è sonno, lavoro o tempo libero (nella scheda, 24 caselle colorate).
  Base: dorme 22–6, colazione alle 6, lavora 7–12 e 13–18, sera libera; lavora al più 8 ore al giorno, poi è libero.
  - Sonno: nelle sue ore va a letto (o per terra, se non ci sono letti liberi) e resta giù anche riposato; dopo si alza con almeno 80 di riposo.
  - Lavoro: a fine turno, o finite le ore, molla il lavoro appena ha le mani libere.
  - Tempo libero: mangia anche senza fame (sotto 60), poi si svaga: attorno al fuoco da campo, se no a passeggio.
  - Sempre: stanco va a letto, affamato mangia, annoiato si prende una pausa (controllato a ogni ora).
- **Abilità** (livelli 1–10, al 10 una stellina): raccogliere, estrarre, tagliare legna, costruire, cucinare, pescare, cacciare, armi da mischia, armi a distanza, ricerca (lista provvisoria). Velocità e qualità del lavoro; crescono con l'uso.
- **Talenti**: modificano la routine e i ritmi dei bisogni, ognuno con un'icona 16×16 (un quadratino in rilievo col simbolo al centro).
  Ogni colono ne ha 0–2, mai due in contrasto (goloso/di poco appetito, pigro/stacanovista, mattiniero/nottambulo,
  dormiglione/instancabile, festaiolo/asceta, iracondo/tranquillo).
  - Goloso: fame +50%, mangia nel tempo libero già sotto 85.
  - Sonnambulo: a volte di notte si alza dormendo e si riaddormenta dove capita, per terra.
  - Iracondo: stress dal lavoro +50%; a 90 molla tutto e se ne va a sbollire per due ore.
  - Pigro: lavora al più 6 ore al giorno.
  - Stacanovista: lavora fino a 12 ore, anche nel tempo libero; si annoia la metà.
  - Mattiniero: tutta la giornata due ore prima (dorme 20–4).
  - Nottambulo: dorme di giorno (10–18), lavora di notte.
  - Dormiglione: gli servono 10 ore di sonno, dorme fino alle 8.
  - Instancabile: gli bastano 6 ore (dorme 0–6), si stanca il 25% più piano.
  - Festaiolo: si annoia il doppio, smette di lavorare alle 17.
  - Asceta: non ha bisogno di svago.
  - Di poco appetito: fame −40%, niente spuntini.
  - Tranquillo: metà dello stress dal lavoro.
  - Pennichella: dorme 13–14 e va a letto alle 23.
  - Irrequieto: dopo 2 ore di lavoro di fila si prende un'ora di pausa.
  - In seguito, altri: "Robusto" (+resistenza al freddo), "Pirofobo" (rifiuta di cucinare).
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
  - Cibo crudo → pasto (cucina)
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
  (8 ore a comfort 5). Sotto le 6 caselle a testa il comfort cala in proporzione. Poi: rischio di rovinare il prodotto.

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
