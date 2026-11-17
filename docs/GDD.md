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
- **Stress** (0–100, con icona): sale lavorando (e combattendo), scende dormendo o a riposo; abbassa la felicità. Altri effetti in seguito.
- **Routine**: ogni ora del giorno è sonno, lavoro o tempo libero (nella scheda, 24 caselle colorate).
  Base: dorme 22–6, colazione alle 6, lavora 7–12 e 13–18, sera libera; lavora al più 8 ore al giorno, poi è libero.
  - Sonno: nelle sue ore va a letto (o per terra, se non ci sono letti liberi) e resta giù anche riposato; dopo si alza con almeno 80 di riposo.
  - Lavoro: a fine turno, o finite le ore, molla il lavoro appena ha le mani libere.
  - Tempo libero: mangia anche senza fame (sotto 60), poi si svaga: attorno al fuoco da campo, se no a passeggio.
  - Sempre: stanco va a letto, affamato mangia, annoiato si prende una pausa (controllato a ogni ora).
- **Abilità** (livelli 0–10, al 10 una stellina; tutti i coloni partono da 0): raccogliere, estrarre, tagliare legna, costruire, forgiare, cucire, cucinare, pescare, cacciare, armi da mischia, armi a distanza, ricerca (lista provvisoria). Velocità e qualità del lavoro; crescono con l'uso.
  Nella raccolta (tagliare, estrarre, raccogliere) 1 punto esperienza a raccolta finita (albero abbattuto, masso scavato, cespuglio spogliato), non a colpo; negli altri lavori +1 per pezzo costruito, lancio, tiro o oggetto fatto. Soglie di livello da definire.
  Tempo di un lavoro: ×1,5 a livello 0, ×1 a livello 5, ×0,5 a livello 10. Ricerca ancora senza effetto.
- **Punti ferita** (0–100): si curano da soli, 30 al giorno (60 dormendo). A 0 il colono resta **a terra** (sdraiato,
  non fa niente) e si cura di 40 al giorno; a 30 si rialza. Sopra la testa, una barretta se è ferito.
- **Morte**: coloni e avventurieri possono morire.
  - Il colpo che butta a terra uccide con probabilità 25% − 3% per punto di protezione (al minimo 5%: con cotta ed elmo).
  - A terra si è indifesi: un nemico che non ha nessuno in piedi da inseguire attacca chi è a terra, e il primo colpo uccide.
  - Il corpo resta dove è caduto per un giorno, poi sparisce; l'equipaggiamento cade a terra lì accanto e si riporta in
    magazzino. Gli altri coloni prendono *lutto* (vedi Condizioni).
  - Il re che muore lascia la corona all'erede (vedi 4.3). Se muoiono tutti i coloni, la partita finisce.
  - Poi: tombe e cimitero, funerali, medico che cura chi è a terra.
- **Sesso**: uomo o donna, a caso (metà e metà); il nome viene dalla lista del suo sesso. Nella scheda, sotto il nome,
  l'icona (♂ azzurro, ♀ rosa) e la parola. Per ora non cambia abilità né bisogni; servirà alla dinastia (matrimonio, figli, 4.3).
- **Aspetto**: lo sprite è fatto di livelli, uno sull'altro:
  1. corpo; maglia e mantello, tinti col colore del colono;
  2. l'armatura, sopra la maglia: cuoio marrone con le cuciture, cotta di maglia grigia a scacchi;
  3. i capelli, tinti: tutti una calotta; in più le donne li hanno lunghi fino alle spalle o la treccia, metà degli uomini la barba;
  4. il copricapo, sopra i capelli: elmo d'acciaio col nasale (sotto escono i capelli dei lati), o cappuccio di cuoio che scende
     sulle spalle (la treccia e i capelli lunghi escono fuori);
  5. quello che tiene in mano (vedi 4.4.2).

  Gli avventurieri hanno lo stesso sprite, col corredo della loro classe (vedi 4.4.4).
- **Talenti**: modificano la routine e i ritmi dei bisogni, ognuno con un'icona 16×16 (un quadratino in rilievo col simbolo al centro).
  Ogni colono ne ha 0–2, mai due in contrasto (goloso/di poco appetito, pigro/stacanovista, mattiniero/nottambulo,
  dormiglione/instancabile, festaiolo/asceta, iracondo/tranquillo).
  - Goloso: fame +50%, va a mangiare già a fame 50 (gli altri a 30) e nel tempo libero già sotto 85; si gode il doppio
    i bonus dei pasti e si lamenta se mangia crudo.
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
- **Condizioni**: effetti a tempo, con un'icona 16×16 nella scheda sotto i talenti (col mouse sopra: nome, effetto, ore che mancano).
  Cambiano tempo di lavoro, stress da lavoro e felicità:

  | Condizione | Durata | Lavoro | Stress da lavoro | Felicità |
  |---|---|---|---|---|
  | Intossicato (crudo andato a male) | 1 giorno | +50% tempo | — | −20 |
  | Ben nutrito (pasto) | ½ giorno | −10% tempo | −25% | +5 |
  | Pasto squisito | ½ giorno | −20% tempo | −50% | +10 |
  | Mangiato al tavolo | ½ giorno | — | — | +5 |
  | Mangiato crudo (solo il goloso) | ½ giorno | — | — | −10 |
  | Lutto (è morto un colono) | 3 giorni | — | +25% | −15 |

  Ben nutrito e pasto squisito si escludono: vale l'ultimo pasto. Poi: malattie dal narratore, perdita di punti ferita.
- **Scheda** (clic sul colono): nome, soprannome (facoltativo), cognome, sesso, punti ferita, abilità (ognuna con un'icona 8×8), talenti (solo icone, il nome col mouse sopra), equipaggiamento (3 slot: mani, corpo, testa). Poi bisogni, relazioni.

### 4.3 Il re e la dinastia
- Il re è un colono speciale: lavora poco, il suo stato dà bonus/malus al reame.
- Può sposarsi, avere figli; i figli crescono e ereditano parte dei talenti.
- Alla morte del re: successione all'erede (regola semplice: primogenito). Nessun erede → game over (o fine della dinastia).
- MVP: solo matrimonio, figli, successione. Intrighi/vassalli fuori scope.

### 4.4 Risorse ed edifici
- Materie prime: legname, pietra, ferro, carbone, oro, cibo crudo. Ferro e carbone vengono dalle vene nella roccia (massi 1x1).
- **Oro**: monete, in magazzino (mucchi da 100). All'inizio 60; poi si trovano nelle rovine (vedi 4.4.4). Servono a pagare
  gli avventurieri. Poi: vene d'oro nella roccia, commercio.
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
  Ogni tipo ha una categoria:
  - **lavoro** (cucina, forgia): niente proprietari, ma le si assegnano dei lavoratori (per ora senza effetto; poi
    solo loro ne faranno i lavori). L'ingresso resta libero.
  - **residenza** (camera, dormitorio): può avere uno o più proprietari tra i coloni; un colono entra (anche solo per
    passarci) solo nelle residenze sue o senza proprietari.
  - **servizio** (magazzino): stanze comuni con uno scopo preciso, né proprietari né lavoratori.
  Cambiando tipo (o tornando senza) proprietari e lavoratori che la nuova categoria non prevede si perdono.
  Una stanza **bandita** è vietata a tutti, anche ai proprietari.
- **Lenti**: evidenziano cose sulla mappa. Prima: la lente delle stanze, ogni stanza finita velata col colore del suo tipo,
  sotto il tipo i proprietari o i lavoratori (col mouse sopra, la loro scheda).
- **Comfort della stanza** (0–10): mobili per pezzo e pavimento, secondo il materiale (pietra ×1,5). A 5 nessun effetto;
  a 0 (anche fuori dalle stanze) le attività durano il 20% in più, a 10 il 20% in meno. Per ora vale per il sonno
  (8 ore a comfort 5) e per cucinare, dove cambia anche la probabilità di bruciare il pasto o farlo squisito.
  Sotto le 6 caselle a testa il comfort cala in proporzione.

### 4.4.1 Cibo e cucina
- **Freschezza**: ogni mucchio di cibo ha i giorni che gli restano (mescolando due mucchi, la media pesata).
  A terra fuori il cibo dura 3 giorni, in magazzino il doppio; poi marcisce e sparisce. Il suggerimento sul mucchio
  dice "Fresh / Stale / Almost rotten" e fra quanti giorni marcisce. Poi: dispensa fredda e inverno (più lento), marcio da buttare.
- **Crudo**: si può mangiare, ma sazia poco e può intossicare (dal crudo appena preso a quello quasi marcio):

  | Crudo | Sazia | Dura (fuori / magazzino) | Intossica |
  |---|---|---|---|
  | Vegetali (raccolta) | 35 | 3 / 6 giorni | 5% → 40% |
  | Pesce (pesca) | 30 | 1,5 / 3 giorni | 10% → 50% |
  | Carne (caccia) | 40 | 2 / 4 giorni | 15% → 60% |

- **Pasti**: 2 crudi dello stesso mucchio (vegetali, pesce o carne) → 1 pasto, che sazia 100 e dà *ben nutrito*. Non intossica.
  Chi ha fame prende prima un pasto squisito, poi un pasto, il crudo solo se non ce ne sono (vegetali, pesce, carne).
  Se entro 20 caselle c'è una sedia libera accanto a un tavolo, lo porta lì e lo mangia seduto (*mangiato al tavolo*).
- **Cucinare** (abilità cucinare): in una stanza di tipo cucina, accanto al fuoco da campo. Il cuoco prende 2 crudi dal
  mucchio più vicino, cucina, il pasto cade ai suoi piedi e lo porta in magazzino. Si cucina finché in giro
  (a terra, in magazzino, in mano) ci sono meno di 2 pasti a colono; nella finestra Jobs: "Cook meals: N".
  Poi: ricette e quantità impostabili dal cartello della cucina.
  - Tempo: 8 s a livello 5 (×1,5 a livello 0, ×0,5 a livello 10), secondo il comfort della cucina (±20%) e le condizioni del cuoco.
  - +1 punto esperienza per pasto.
  - **Bruciato** (vegetali persi): 6% per livello sotto il 6 (36% a livello 0), +3% per punto di comfort della cucina sotto 5 (sopra lo abbassa).
  - **Squisito**: 5% per livello sopra il 5 (25% a livello 10), +2% per punto di comfort sopra 5. Dà *pasto squisito*.
- **Pescare** (abilità pescare, tasto "Fish", canna): si segnano caselle d'acqua. Il pescatore sta accanto (anche nell'acqua
  bassa) e lancia: 10 s a lancio a livello 5, un pesce con probabilità 30% + 6% per livello (30% a livello 0, 90% a 10).
  +1 punto esperienza per lancio, anche a vuoto. Ogni punto ha 4 pesci, poi si svuota per 1 giorno; il segno resta.
- **Cacciare** (abilità cacciare, tasto "Hunt", arco): sulla mappa girano animali selvatici, mai nelle stanze né in acqua.
  Si segnano trascinando sopra di loro. Il cacciatore li insegue e tira da al più 6 caselle: un tiro ogni 4 s a livello 5;
  colpisce con probabilità 30% + 5% per livello − 5% per casella di distanza (5–95%). Colpito o mancato, l'animale scappa
  di 8 caselle e il cacciatore lo rincorre. +1 punto esperienza per tiro. Abbattuto, lascia la carne.

  | Animale | Colpi | Carne | Velocità | All'inizio |
  |---|---|---|---|---|
  | Coniglio | 1 | 3 | 2 caselle/s | 6 |
  | Cervo | 2 | 10 | 1,5 caselle/s | 3 |

  Nascono a più di 15 caselle dalla radura; ogni mezza giornata ne arriva uno nuovo, fino a 12.
- Ordine dei lavori finché non c'è la tabella delle priorità: prendere l'equipaggiamento, cucinare, forgiare e cucire,
  tagliare, scavare, estirpare, raccogliere, pescare, cacciare, costruire, trasportare.
- Poi: animali che si difendono; stufato (vegetali + carne o pesce), conserve per l'inverno.
- **Raccogliere** (tasto "Harvest", cestino, dopo "Uproot"): si segnano i cespugli; i coloni ne raccolgono le bacche ogni
  volta che maturano (5 ogni 2 giorni), finché il segno resta, e le portano in magazzino. Segnare "Uproot" toglie il segno e viceversa.
  Un colono mangia circa 2 vegetali al giorno se cucinati, 2,6 crudi; un cespuglio ne dà 2,5: 1–2 cespugli a testa.

### 4.4.2 Forgia, sartoria ed equipaggiamento
- **Stanze**: forgia (fornace e incudine), laboratorio (banco da lavoro, 15 legna).
- **Ricette** (si fanno da sé, come in cucina; il produttore va a prendere gli ingredienti uno alla volta e li porta alla
  postazione; tempo secondo livello, comfort della stanza e condizioni; rovinato come il cibo bruciato, ingredienti persi):

  | Oggetto | Dove | Abilità | Ingredienti | Secondi (liv. 5) |
  |---|---|---|---|---|
  | Lingotto | fornace | forgiare | 1 ferro + 1 carbone | 6 |
  | Armatura di cuoio | banco | cucire | 4 pelli | 20 |
  | Cappuccio di cuoio | banco | cucire | 2 pelli | 12 |
  | Arco | banco | armi a distanza | 3 legna + 1 pelle | 15 |
  | Piccone, ascia | incudine | forgiare | 2 lingotti + 2 legna | 15 |
  | Spada | incudine | forgiare | 3 lingotti + 1 legna | 20 |
  | Falcetto | incudine | forgiare | 1 lingotto + 1 legna | 10 |
  | Elmo | incudine | forgiare | 3 lingotti | 20 |
  | Cotta di maglia | incudine | forgiare | 6 lingotti | 30 |

  Lingotti: finché ce ne sono meno di 10. Equipaggiamento: quanto manca perché ogni colono abbia pieni i suoi slot; per
  corpo e testa il primo in elenco di cui ci sono gli ingredienti (prima il cuoio, poi il metallo).
  Poi: ordinazioni dal cartello, qualità degli oggetti, cambiare un pezzo con uno migliore.
- **Pelli**: dagli animali cacciati, 1 dal coniglio, 3 dal cervo. Non marciscono.
- **Equipaggiamento** (3 slot: mani, corpo, testa): ogni colono con uno slot vuoto va a prendere in magazzino il pezzo
  giusto. Nelle mani l'attrezzo della sua abilità migliore tra estrarre, tagliare legna, raccogliere e cacciare.
  Ogni armatura ha una **protezione** (per combattimento e freddo, che verranno); i **bonus** li dà solo il pezzo che li ha:

  | Pezzo | Slot | Protezione | Effetto |
  |---|---|---|---|
  | Piccone | mani | — | scavare −25% tempo |
  | Ascia | mani | — | tagliare −25% tempo |
  | Falcetto | mani | — | raccogliere ed estirpare −25% tempo |
  | Arco | mani | — | caccia: +10% a segno, +2 caselle di tiro, mira col migliore tra cacciare e armi a distanza (+1 esperienza in entrambe); in combattimento tira (danno 14) |
  | Spada | mani | — | arma: danno 15 corpo a corpo (la prende chi è più bravo in mischia) |
  | Armatura di cuoio | corpo | 2 | −25% stress lavorando fuori dalle stanze |
  | Cotta di maglia | corpo | 5 | pesante: ogni lavoro +10% tempo |
  | Cappuccio di cuoio | testa | 1 | caccia: +5% a segno |
  | Elmo | testa | 3 | scavare −10% tempo |

  Nella scheda gli slot mostrano i pezzi (col mouse sopra nome, protezione, effetto), il titolo la protezione totale.
- **Si vede addosso** (vedi Aspetto in 4.2): armatura e copricapo sempre. In mano: nei colpi (taglio, scavo, costruzione,
  cucina, combattimento) il pezzo che ha, ognuno col suo disegno (piccone, ascia, falcetto, spada, arco); a mani vuote un
  attrezzo qualunque. Da fermo e camminando la spada sta al fianco e l'arco sulla schiena; gli attrezzi non si vedono.

### 4.4.3 Combattimento
- **Lupi**: dal giorno 3 (poi ogni 3 giorni) un branco di 2–3 lupi entra da un bordo della mappa e punta alla colonia.
  Inseguono il colono in piedi più vicino che sta **fuori dalle stanze** (nelle stanze non entrano: i muri proteggono) e lo
  mordono (danno 8, ogni 1,5 s; a segno 70% − 3% per livello di mischia di chi è morso; ogni morso +5 stress).
  Senza nessuno da inseguire, dopo un giorno se ne vanno. Abbattuti lasciano 5 carne e 2 pelli. Nella barra in alto "WOLVES: n".
- **Coloni**: con un lupo entro 12 caselle lasciano tutto e combattono contro il più vicino. Chi è sotto 40 punti ferita
  invece scappa nella stanza più vicina dove può entrare e lì aspetta (niente lavori) finché il pericolo non passa; se non
  ce n'è, combatte.
  - Corpo a corpo: un colpo ogni 1,5 s a livello 5 (abilità armi da mischia), a segno 50% + 5% per livello sopra il 5;
    danno dell'arma o dell'attrezzo in mano (spada 15, ascia 12, piccone 10, falcetto 8, mani nude 5). +1 esperienza a colpo.
  - Con l'arco: tira da lontano (fino a 8 caselle), un tiro ogni 2 s a livello 5 (armi a distanza), a segno come a caccia;
    danno 14. +1 esperienza a tiro.
  - **Protezione**: −6% di danno per punto (cotta ed elmo, 8 punti: −48%), al massimo −80%.
- Un lupo segnato da cacciare, colpito o mancato, attacca il cacciatore invece di scappare.
- Si muore: vedi Morte in 4.2. Un lupo senza nessuno in piedi da inseguire morde chi è a terra.
- Poi: predoni (umani), funerali, medico e cure, animali che fuggono o si difendono, ordini di combattimento dati dal re.

- **Splendore** della colonia (termine provvisorio; alternative: decoro, prestigio, lustro): tiene felici i coloni e
  sblocca cose. Lo danno le decorazioni finite, ovunque stiano (il totale in alto). Primo effetto: attira avventurieri
  più forti (vedi 4.4.4).
  Decorazioni (+splendore): aiuola 1, fioriera di pietra 1, panca 1 (anche +0,5 comfort), lampione 1 (si accende di
  notte), stendardo 2 (sventola), fontana 6 (2x2, zampilla), statua del re 8 (2x2).
  Poi: strade che collegano le case, alberi piantati, feste.
- **Sentiero**: pavimento di terra battuta e sassolini (1 pietra a casella); i mobili ci stanno sopra.
  Su tutti i pavimenti l'erba dei prati vicini sborda, frastagliata, così non finiscono di netto; contro muri, porte
  e altri pavimenti il bordo resta netto. Poi: i sentieri che collegano le case danno splendore.

### 4.4.4 Avventurieri e rovine
Il re non manda i suoi coloni (per ora non possono partire): **ingaggia avventurieri**, li paga in **oro** e li manda
a esplorare **rovine fuori dalla mappa**. Non si controllano: si sceglie chi, dove e con quante provviste; il resto lo
racconta il diario al ritorno.

- **Locanda**: nuovo tipo di stanza, categoria servizio. Mobili: almeno 1 letto, 1 tavolo e la **bacheca degli incarichi**
  (mobile nuovo, 8 legna; cliccata apre la finestra degli ingaggi). Tanti letti, tanti avventurieri in attesa.
  I letti della locanda sono solo degli avventurieri, e gli avventurieri dormono solo lì (se no per terra).
- **Arrivi**: con una locanda e un letto libero, ogni 2 giorni circa (±½) arriva un avventuriero da un bordo della mappa,
  va alla locanda e resta 3 giorni; se nessuno lo ingaggia, se ne va. Livello: 1 + 1 ogni 10 punti di **splendore**
  (±1 a caso, da 1 a 5); da 20 punti di splendore, una volta su quattro ne arrivano due insieme.
- **In colonia** non lavorano e non hanno priorità: mangiano dal magazzino, dormono nei letti della locanda, si svagano
  come i coloni (nelle ore di lavoro anche). Se arrivano i lupi combattono con le regole di 4.4.3, e possono morire.
- **Scheda** come quella dei coloni (nome, sesso, punti ferita, talenti, equipaggiamento), più classe, livello, paga e
  spedizioni fatte. Le abilità sono solo quelle della classe, a 2 × livello (lo scassinatore anche armi da mischia, a
  1 × livello).
- **Classi**:

  | Classe | Abilità | Porta | Nella rovina |
  |---|---|---|---|
  | Guerriero | armi da mischia | spada, scudo (+3 protezione), cotta di maglia (cuoio sotto il livello 3), elmo | prende il doppio dei colpi |
  | Arciere | armi a distanza | arco, faretra, armatura e cappuccio di cuoio | tira per primo: −25% danni al gruppo; prende metà dei colpi |
  | Scassinatore | scassinare (nuova) | pugnale (danno 10), maschera, sacca, armatura di cuoio | disinnesca le trappole, apre i forzieri chiusi; con la sacca +50% di bottino |

  Scudo, faretra, maschera, sacca e pugnale per ora li hanno solo gli avventurieri: non si fabbricano.
- **Aspetto**: lo sprite dei coloni (sesso, capelli, tinte; vedi 4.2) con il corredo della classe sopra.
  Guerriero: cotta, elmo, scudo tondo di legno sul braccio (da dietro sulla schiena), spada al fianco.
  Arciere: cappuccio (verde), armatura di cuoio, arco e faretra sulla schiena (da davanti spuntano le penne).
  Scassinatore: cappuccio scuro, fazzoletto sul naso e sulla bocca, sacco sulla schiena, pugnale alla cintura; maglia e
  mantello scuri.
- **Talenti**: uno a testa, a caso, con la sua icona 16×16 (nella scheda accanto a quelli dei coloni, il nome anche
  sulla bacheca). In più, tre volte su dieci, uno dei talenti dei coloni (bisogni e routine).

  | Talento | Icona | Effetto |
  |---|---|---|
  | Avido | sacco di monete | paga +25% |
  | Leale | cuore | non prende la quota delle monete |
  | Temerario | fiamma | il gruppo torna per lui solo sotto 20 punti ferita (non 40) |
  | Codardo | bandiera bianca | il gruppo torna appena lui scende sotto 60 |
  | Fortunato | quadrifoglio | un oggetto in più in ogni forziere del gruppo |
  | Cartografo | mappa | il gruppo trova mappe tre volte più spesso |
  | Iettato | gatto nero | ogni trappola colpisce lui; paga −25% |
  | Berserker | ascia insanguinata | la sua arma conta doppio nella forza del gruppo, ma prende il 50% di ferite in più |
  | Robusto | zampa d'orso | un terzo di ferite in meno (mostri e trappole) |
  | Furtivo | figura incappucciata | il gruppo evita i mostri una volta su quattro (non il guardiano) |
  | Medico | croce rossa | dopo ogni stanza tutti +6 punti ferita; chi cade non muore mai, lo riportano a casa (se non è solo) |
  | Raccoglitore | fungo | il gruppo mangia un terzo in meno |
  | Guida | stivale | il viaggio dura la metà |
  | Occhio di lince | occhio | +30% a disinnescare le trappole |
  | Studioso | libro | sale di livello dopo ogni spedizione (non ogni 2) |
  | Famoso | stella | +5 splendore finché è sulla mappa (alla locanda, o di passaggio) |
- **Paga, in oro**: all'ingaggio 10 + 5 × livello monete (15–35), prese dal magazzino; al ritorno la **quota**: il 30%
  delle monete trovate. Senza abbastanza oro non si ingaggia. A chi muore non si paga la quota.
- **Rovine**: fuori dalla mappa, in un elenco sulla bacheca; si raggiungono a piedi.

  | Rovina | Pericolo | Stanze | Viaggio (andata) | Forziere: monete | Forziere: un oggetto tra |
  |---|---|---|---|---|---|
  | Torre diroccata | 1 | 3 | ½ giorno | 10–25 | 10 legna, 10 pietra, 5 ferro |
  | Miniera abbandonata | 2 | 5 | 1 giorno | 20–45 | 10 ferro, 10 carbone, 4 lingotti, un piccone |
  | Cripta | 3 | 6 | 1 giorno | 35–70 | una spada, un elmo, un'armatura di cuoio, 6 lingotti |
  | Forte in rovina | 4 | 8 | 2 giorni | 60–120 | una cotta di maglia, 2 spade, un elmo, 10 lingotti |

  All'inizio si conosce solo la torre. Il **tesoro** dell'ultima stanza di ogni rovina ha il triplo delle monete e la
  **mappa** della rovina dopo (in quest'ordine); a volte (15%) un forziere qualunque ha la mappa di una rovina che non
  si conosce ancora. Le mappe le portano a casa: si conoscono al ritorno (e si perdono con una spedizione persa).
  Le stanze ripulite restano ripulite: la spedizione dopo riparte da lì. Finite le stanze, la rovina è esaurita.
- **Spedizione** (dalla bacheca): si spuntano 1–4 avventurieri tra chi aspetta alla locanda; ogni rovina ha il suo tasto
  "Send", con la somma delle paghe e le provviste che servono: una a testa per ogni giorno del viaggio intero (andata,
  ½ giorno per ogni stanza che resta, ritorno), prese dal magazzino, prima i pasti poi il crudo. Se non bastano partono
  con quelle che ci sono (il tasto avvisa). Ognuno va al bordo più vicino; il primo che esce fissa il punto, gli altri
  escono lì, e si parte quando sono usciti tutti. Nella barra in alto "EXPEDITION: n".
- **Nella rovina** (calcolato alla partenza, non si vede): una stanza ogni ½ giorno, a caso tra vuota (25%), trappola
  (20%), mostri (35%), forziere (15%) e crollo (5%: si torna indietro). L'ultima stanza è il tesoro col suo guardiano
  (mostri, forza doppia); se il tesoro resta chiuso, quella stanza resta da fare.
  - Mostri: forza 5 × pericolo; forza del gruppo = somma dei livelli d'arma + protezione. In media ognuno perde
    20 × forza dei mostri / forza media del gruppo punti ferita (−25% con un arciere): il guerriero il doppio della
    media, l'arciere la metà; poi la protezione di ognuno (−6% a punto, come in 4.4.3).
  - Trappola: la disinnesca il migliore a scassinare, con probabilità 20% + 8% per livello; se no 15 × pericolo danni a uno a caso.
  - Forziere: monete e un oggetto della rovina; una volta su due è chiuso e si apre solo con scassinare almeno
    2 × pericolo.
  - Provviste: ogni ½ giorno se ne mangia ½ a testa; quando mancano, la fame costa 20 punti ferita al giorno a testa.
    Nel ritorno si patisce la fame lo stesso, ma a casa ci si arriva.
  - Dopo ogni stanza il gruppo decide: torna se qualcuno è sotto la sua soglia (40 punti ferita; vedi Temerario e Codardo)
    o se le provviste non bastano per un'altra stanza e il ritorno.
  - A 0 punti ferita si muore una volta su due; se no gli altri lo riportano a casa (con 5 punti ferita, si cura in
    colonia). Se cadono tutti, la spedizione è **persa**: non torna nessuno, e nemmeno il bottino.
- **Ritorno**: rientrano dal bordo, portano bottino e feriti in magazzino e alla locanda, prendono la quota e restano
  2 giorni; intanto si possono ingaggiare di nuovo. +1 livello ogni 2 spedizioni tornate (al massimo 5).
- **Diario**: al ritorno (o quando la spedizione si dà per persa: il doppio del tempo previsto) una finestra la racconta,
  una riga per stanza. Per esempio: «Giorno 12 – Bruna disinnesca una trappola nella cripta. Oddo cade sotto le spade
  degli scheletri. Tornano con 14 monete e un calice d'argento.» I diari restano in una **cronaca** da rileggere
  (sulla bacheca l'ultima pagina e il tasto "Chronicle": tutto, dal più recente; ci sono anche ingaggi e morti).
  Frasi a chiave, tradotte come il resto.
- **Cimeli**: si trovano solo nei forzieri delle rovine e arrivano in magazzino come oggetti; nella barra dei mobili
  (dopo le decorazioni) diventano decorazioni da piazzare, fatte col cimelio stesso (uno a pezzo), e danno splendore,
  che attira avventurieri più forti.

  | Cimelio | Dove | Splendore |
  |---|---|---|
  | Calice d'argento (col rubino) | cripta | 3 |
  | Stendardo antico (strappato, d'una casata caduta) | forte | 4 |
  | Busto di pietra (un re dimenticato) | cripta | 5 |
  | Corona (su un cuscino di velluto) | forte | 6 |
- Poi: un avventuriero contento dopo 3 spedizioni chiede di **restare come colono** (il primo modo di avere più coloni);
  coloni in spedizione; prestare equipaggiamento agli avventurieri; vene d'oro e commercio; una rovina sulla mappa da
  esplorare davvero.
- **Ordine di lavoro**: (1) locanda e bacheca, oro, un avventuriero alla volta, solo la torre, bottino in risorse che
  esistono già; (2) classi, talenti, gruppi, provviste, diario; (3) altre rovine, mappe, cimeli, effetto dello splendore;
  (4) il resto.
- **Stato**: fatte le fasi 1, 2 e 3.
  Simulazioni (500 spedizioni per caso, provviste piene, rovina intatta): alla torre non muore nessuno, ma mandarci
  gente di livello alto costa più di quello che rende; nelle rovine profonde chi va da solo non torna una volta su
  cinque, un gruppo di livello 1 al forte perde in media un uomo ogni 9 spedizioni e torna presto; un gruppo del livello
  giusto ci guadagna (cripta, tre di livello 3: 147 monete a casa per 75 di paghe; forte, quattro di livello 5: 268
  per 140); coi talenti a caso i numeri restano questi, più o meno. Manca il resto di "Poi".

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
6. Avventurieri e rovine (vedi 4.4.4)

### Fuori scope (per ora)
Combattimento tattico (oggi i coloni si difendono da soli, vedi 4.4.3), livelli verticali, commercio/diplomazia, mod.

## 6. Domande aperte
- Dimensione dei tile: 16×16 o 32×32?
- Condizione di sconfitta oltre alla fine della dinastia?
- Lista degli eventi.
- Nome definitivo del gioco.
