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
  Tempo di un lavoro: ×1,5 a livello 0, ×1 a livello 5, ×0,5 a livello 10. Ricerca: studiare allo scrittoio (vedi 4.7).
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
- Il **sovrano** (re solo alla fine, vedi Titolo) è un colono come gli altri: lavori e priorità, bisogni, routine, abilità che
  crescono, equipaggiamento, combattimento. In più lo crea il giocatore a inizio partita (vedi 4.3.1) e il suo stato
  influisce sugli altri coloni.
- **Titolo**: cresce con la colonia, e con lui il nome del reame e la corona sullo stemma (vedi 4.3.2). Soglie da definire
  (splendore, numero di coloni). È della casata: l'erede lo eredita. Il gioco si chiama King: diventare re è l'arco della partita.

  | Titolo | Reame | Corona sullo stemma |
  |---|---|---|
  | Signore / Signora | Signoria di … | nessuna |
  | Barone / Baronessa | Baronia di … | cerchio |
  | Conte / Contessa | Contea di … | corona a punte |
  | Re / Regina | Regno di … | corona reale |

- **Influenza sugli altri coloni**: condizioni come in 4.2, con l'icona nella scheda (numeri provvisori):

  | Condizione | Quando, durata | Lavoro | Stress da lavoro | Felicità |
  |---|---|---|---|---|
  | Sovrano sereno | felicità del sovrano ≥ 70, finché dura | — | — | +5 |
  | Sovrano cupo | felicità del sovrano ≤ 30, finché dura | — | +15% | −5 |
  | Sotto lo sguardo del sovrano | entro 8 caselle da lui, finché dura | −10% tempo | — (pigro e irrequieto: +25%) | — |
  | Lutto regale | è morto il sovrano, 7 giorni (invece del lutto) | — | +25% | −20 |
  | Incoronazione | il nuovo sovrano, finito il lutto regale, 2 giorni | — | — | +10 |

  Quando lo stress del sovrano arriva a 90, chi è entro 8 caselle prende subito +10 stress.
- **In battaglia**: chi è entro 8 caselle dal sovrano scappa solo sotto 20 punti ferita (non 40), come il Temerario.
  Se il sovrano è a terra, i coloni in piedi entro 12 caselle lasciano tutto e vanno a difenderlo (combattono il nemico più vicino a lui).
- **Stile di regno**: uno, scelto alla creazione; vale per tutta la colonia finché regna. All'incoronazione il giocatore
  ne sceglie uno per l'erede.

  | Stile | Effetto |
  |---|---|
  | Condottiero | +10% a segno in combattimento |
  | Costruttore | costruire −15% tempo |
  | Mecenate | +25% splendore dalle decorazioni |
  | Padre del popolo | +5 felicità a tutti |
  | Tesoriere | paga degli avventurieri −15% |
  | Saggio | +20% punti esperienza a tutti |

- **Epiteto**: alla morte la cronaca gli dà un soprannome secondo il regno, per esempio "il Costruttore" (più edifici finiti),
  "il Lupo" (più lupi abbattuti), "il Breve" (meno di 10 giorni). Lista da definire.
- Può sposarsi, avere figli; i figli crescono, prendono il cognome della casata e ereditano parte dei talenti.
- Alla morte del sovrano: successione all'erede (regola semplice: primogenito). Nessun erede → game over (o fine della dinastia).
- MVP: solo matrimonio, figli, successione. Intrighi/vassalli fuori scope.

### 4.3.1 Nuova partita: casata e sovrano
Quattro pagine, in quest'ordine (lo stemma prima del sovrano, perché gli dà i colori). Accanto a ogni nome un dado che
pesca dalle liste dei nomi.
1. **Casata**: nome della casata (è il cognome del sovrano e dei figli), nome della colonia (nel nome del reame:
   "Signoria di Valbruna"), motto facoltativo (sul cartiglio dello stemma).
2. **Stemma**: vedi 4.3.2.
3. **Sovrano**:
   - Nome, soprannome facoltativo, sesso.
   - **Abilità**: 12 punti da dare, al massimo 3 per abilità (almeno quattro abilità); il resto con l'esperienza.
     Gli altri coloni partono da 0.
   - **Talenti**: fino a 2 tra quelli dei coloni (4.2), mai due in contrasto. I difetti danno 2 punti abilità in più
     (pigro, iracondo, dormiglione, irrequieto, sonnambulo, goloso, festaiolo), i pregi ne costano 2 (stacanovista,
     instancabile, tranquillo, asceta, di poco appetito), gli altri niente (mattiniero, nottambulo, pennichella).
   - **Stile di regno**: vedi 4.3.
   - **Aspetto** (i livelli di 4.2): tono della pelle (3–4, livello tinto nuovo; poi anche per gli altri coloni); capelli
     (calotta, lunghi, treccia, per tutti e due i sessi) e il loro colore; barba; colore di maglia e mantello (all'inizio
     i primi due smalti dello stemma; finché non c'è lo stemma, le tinte dei coloni); la barba solo agli uomini; l'insegna sopra i capelli, la corona del titolo (sotto un copricapo non si vede).
     Anteprima grande, girabile nelle quattro direzioni.
4. **Riepilogo**: casata, stemma, sovrano e gli altri coloni di partenza (a caso, come ora), ognuno col suo dado per
   ritirarlo (nome, sesso, aspetto, talenti), più un dado per tutti. Poi "Start".

### 4.3.2 Stemma
Lo stemma della casata si compone a livelli, uno sull'altro, come lo sprite dei coloni. **Palette chiusa**: solo gli
smalti dell'araldica, che tingono anche mantello e stendardi.

| Livello | Scelte |
|---|---|
| Forma | sannitico, francese antico (a punta), a mandorla, tondo, a testa di cavallo, a losanga |
| Partizione del campo | pieno, partito, troncato, trinciato, tagliato, inquartato, inquartato in decusse, interzato in palo, gheronato |
| Linea di partizione | dritta, dentata, ondata, merlata, nebulosa |
| Smalti | metalli: oro, argento; colori: rosso, azzurro, verde, nero, porpora |
| Pellicce e motivi (al posto di uno smalto pieno, in una parte del campo o nella pezza) | ermellino, vaio (coi loro colori); palato, fasciato, bandato, scaccato, losangato (due smalti a scelta); seminato di gigli, stelle o crescenti |
| Pezza (sopra il campo) | capo, campagna, palo, fascia, banda, croce, decusse, scaglione, pergola, bordura |
| Figura | leone, aquila, lupo, orso, cervo, cinghiale, drago, grifone; torre, spada, chiave, ascia, martello, corona, spiga, albero; giglio, rosa, stella, crescente, sole |
| Disposizione della figura | una al centro, tre (2 e 1), in capo; uno smalto per la figura |
| Ornamenti | corona del titolo (non si sceglie, vedi 4.3), elmo e cimiero, svolazzi, motto sul cartiglio |

- **Editor**: anteprima grande e, accanto, a 32 e a 16 px (come si vedrà sulla mappa); una scheda per livello, ogni scelta
  con la sua miniatura. Dado per tutto e lucchetto per ogni livello (il dado ritira solo quelli aperti). Annulla.
- **Regola degli smalti**: mai colore su colore né metallo su metallo. Se la si rompe, un avviso (disattivabile), non un
  divieto; il dado la rispetta.
- **Blasonatura**: sotto lo scudo il testo che lo descrive, composto a chiavi e tradotto come il resto:
  «D'azzurro, alla torre d'argento; al capo d'oro.»
- **Dove si vede**: lo stendardo (oggi drappo rosso con la corona) col drappo dello stemma, che sventola come ora;
  il mantello del sovrano; la barra in alto, accanto al nome del reame; la scheda del sovrano; l'intestazione della
  cronaca e dei diari; i salvataggi.
- **Disegno**: lo scudo è di 16x16 (2x nella barra e nella scheda, 8x nella pagina della casata). Partizioni e pezze
  sono formule sul campo, così vanno bene a ogni misura (scudo e drappo); forme e figure sono maschere disegnate a mano
  (tools/make_sprites.py, art/arms.png), le figure senza bordo, in due misure: 8x8 al centro dello scudo, 5x5 sul
  drappo dello stendardo (largo 7). Capo e campagna prendono un quarto del campo, così non toccano la figura.
  Poi: una versione a 32 px, con gli animali (leone, lupo, orso…), che a 8 px non si leggono.
- Poi: lo stendardo antico dei cimeli (4.4.4) con uno stemma a caso e il nome della casata caduta ("Stendardo dei
  Valdora"); il matrimonio unisce i due stemmi (partito); l'erede porta il lambello finché non regna; le casate finite
  in una "Sala delle casate" nel menu.

**Ordine di lavoro** (4.3–4.3.2): (1) una pagina sola: nome, casata, sesso, colonia, capelli, barba, colori, 12 punti
abilità; (2) stemma base: 4 forme, 6 partizioni, i 7 smalti, 6 pezze, una decina di figure, dado; sullo stendardo,
nella barra in alto e nella scheda; (3) sovrano sereno e cupo, lutto regale, incoronazione; (4) riepilogo coi coloni di
partenza; (5) talenti a punti e stile di regno; (6) titolo che cresce e corona sullo stemma; (7) linee, pellicce, motivi,
ornamenti, motto, blasonatura; (8) presenza, difesa del sovrano, epiteti; (9) il resto di "Poi".
**Stato**: fatte le fasi 1 e 2, e della 5 i talenti a punti (nella pagina del sovrano, col costo sul pulsante). "New Game" apre la pagina (creation.gd), "Start" la partita: il sovrano è il primo colono,
coi talenti scelti; in alto a sinistra la corona e "Lordship of …", che apre la sua scheda, dove sotto il
nome c'è "Lord/Lady of …". Senza la pagina (nei test) sovrano, colonia e stemma vengono a caso.
Fase 2: la pagina è divisa in due, "Your House" (nomi e stemma) e "Your Ruler"; stemma con 4 forme (francese antico,
sannitico, tondo, losanga), 7 partizioni, i 7 smalti, 9 pezze (capo, campagna, palo, fascia, banda, croce, decusse,
scaglione, bordura), 10 figure (stella, crescente, giglio, rosa, torre, corona, spada, chiave, albero, aquila).
Ogni pulsante mostra lo stemma com'è con quella scelta. Maglia e mantello seguono i primi due smalti finché non li si
sceglie (dagli smalti). Il dado rispetta la regola degli smalti: campo partito senza pezza né figura, niente figura
sulle pezze che passano dal centro. Lo stemma sta nella barra in alto (al posto della corona), nella scheda del
sovrano davanti al nome e sul drappo degli stendardi (ombreggiato dalle pieghe che ondeggiano).

### 4.4 Risorse ed edifici
- Materie prime: legname, pietra, ferro, carbone, oro, cibo crudo. Ferro e carbone vengono dalle vene nella roccia (massi 1x1).
- **Tipi di oggetto**: ogni oggetto ha un tipo, con una piccola icona 16×16 che sta sempre davanti al suo nome (elenco
  delle risorse, riquadro del mucchio, suggerimenti dell'equipaggiamento, finestra Jobs, diari e cronaca):

  | Tipo | Icona | Oggetti |
  |---|---|---|
  | Materiale | cassa | legname, pietra, ferro, carbone, pelli, lingotti |
  | Cibo | mela | vegetali, carne, pesce, pasti, pasti squisiti |
  | Strumento | martello | piccone, ascia, falcetto |
  | Arma | spada | arco, spada, pugnale |
  | Armatura | scudo | armatura di cuoio, cotta di maglia, cappuccio, elmo |
  | Monete | moneta | oro (nei testi c'è solo la moneta, dopo il numero) |
  | Cimelio | gemma | calice, stendardo antico, busto, corona |
  | Libro | quaderno | quaderno azzurro, tomo rosso, codice di porpora (vedi 4.7.2) |
- **Oro**: monete, in magazzino (mucchi da 100). All'inizio 60; poi si trovano nelle rovine (vedi 4.4.4). Servono a pagare
  gli avventurieri. Nei testi (bacheca, scheda, diari, cronaca, finestra Jobs) al posto della parola c'è una monetina
  16×16 dopo il numero. Poi: vene d'oro nella roccia, commercio.
- Catene MVP:
  - Legname → assi (banco del falegname)
  - Lino → corda d'arco (filatoio) → arco, con la legna (banco del falegname)
  - Ferro grezzo → lingotti (fornace) → attrezzi (fucina)
  - Cibo crudo → pasto (cucina, vedi 4.4.1)
- Attrezzi equipaggiati = bonus all'abilità corrispondente.
- Edifici MVP: muri, porte, tetto, letto, focolare, cucina, magazzino (zona), banco da lavoro, fornace, fucina.
- Stanze chiuse con tetto proteggono da pioggia e freddo; il focolare scalda.
- **Stanze**: zona chiusa da muri con una porta; il cartello sul muro accanto alla porta apre nome e tipo.
  Tipi: magazzino; camera (1 letto); dormitorio (2 letti); cucina (fuoco da campo, poi anche stufa); forgia (fornace e incudine);
  laboratorio (banco da lavoro); falegnameria (banco del falegname).
  Un tipo si sceglie solo se ci sono i mobili (gli altri non compaiono); tolti, la stanza torna senza tipo.
  Ogni tipo ha una categoria:
  - **lavoro** (cucina, forgia, laboratorio, falegnameria): niente proprietari, ma le si assegnano dei lavoratori (per ora senza effetto; poi
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
- **Tetti**: ogni stanza finita ha il suo, da sé, sopra la stanza e i suoi muri; un pulsante (V) li toglie per guardare dentro.
- **Freddo e pioggia** tolgono comfort, anche sotto lo 0: −1 ogni 4 °C sotto i 12 °C; fuori, sotto la pioggia, −2.
  La temperatura fuori la danno le stagioni (vedi 4.5), ±5 °C tra mezzanotte e mezzogiorno, e il tempo: pioggia −3,
  nebbia −2, temporale −5, neve −2.
  Sotto un tetto la temperatura va a metà strada verso 15 °C e non piove; ogni fuoco da campo della stanza la alza di 8 °C;
  ogni punto di protezione addosso vale un grado. Da svegli, al freddo o sotto la pioggia, il comfort cala di un punto
  all'ora per ogni punto tolto; risale solo dormendo. Nelle stanze fredde anche lavorare, cucinare e studiare va più piano.

### 4.4.1 Cibo e cucina
- **Freschezza**: ogni mucchio di cibo ha i giorni che gli restano (mescolando due mucchi, la media pesata).
  A terra fuori il cibo dura 3 giorni, in magazzino il doppio; poi marcisce e sparisce. Il suggerimento sul mucchio
  dice "Fresh / Stale / Almost rotten" e fra quanti giorni marcisce. Col freddo marcisce più piano: sotto i 15 °C in
  proporzione ai gradi, sotto lo zero per niente (gela, "frozen: it keeps"); un magazzino senza fuoco fa da dispensa.
  Poi: marcio da buttare.
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
  (a terra, in magazzino, in mano) ci sono meno pasti di quanti ne chiede il menu del fuoco (vedi 4.4.2; all'inizio
  2 a colono, 6); nella finestra Jobs: "Cook meals: N". Poi: altre ricette (stufato, conserve).
  - Tempo: 8 s a livello 5 (×1,5 a livello 0, ×0,5 a livello 10), secondo il comfort della cucina (±20%) e le condizioni del cuoco.
  - +1 punto esperienza per pasto.
  - **Bruciato** (vegetali persi): 6% per livello sotto il 6 (36% a livello 0), +3% per punto di comfort della cucina sotto 5 (sopra lo abbassa).
  - **Squisito**: 5% per livello sopra il 5 (25% a livello 10), +2% per punto di comfort sopra 5. Dà *pasto squisito*.
- **Pescare** (abilità pescare, tasto "Fish", canna): si segnano caselle d'acqua. Il pescatore sta accanto (anche nell'acqua
  bassa) e lancia: 10 s a lancio a livello 5, un pesce con probabilità 30% + 6% per livello (30% a livello 0, 90% a 10).
  +1 punto esperienza per lancio, anche a vuoto. Ogni punto ha 4 pesci, poi si svuota per 1 giorno; il segno resta.
- **Cacciare** (abilità cacciare, tasto "Hunt"): sulla mappa girano animali selvatici, mai nelle stanze né in acqua.
  Si segnano trascinando sopra di loro. Si caccia **solo con l'arco**: chi non ce l'ha va a prenderne uno libero e posa lì
  quello che aveva in mano; se non ce ne sono se ne fa uno (vedi 4.4.2) e la finestra Jobs dice "(needs a bow)".
  Il cacciatore li insegue e tira da al più 8 caselle (6 + 2 dell'arco): un tiro ogni 4 s a livello 5;
  colpisce con probabilità 30% + 5% per livello − 5% per casella di distanza (5–95%). Colpito o mancato, l'animale scappa
  di 8 caselle e il cacciatore lo rincorre. +1 punto esperienza per tiro. Abbattuto, lascia la carne.
  - **Animazione**: mirando tende l'arco (fotogramma a corda lenta subito dopo il tiro, per un quarto del tempo di mira,
    poi a corda tesa con la freccia incoccata), per le quattro direzioni. Al tiro parte una freccia (20 caselle/s, su una
    parabola bassa, con l'ombra a terra): se va a segno insegue l'animale, se no finisce un po' più in là, di lato.
    Il colpo, o lo spavento, arriva con la freccia. Vale anche in combattimento.

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
  - **Lino**: ciuffi coi fiori azzurri sparsi nei prati (circa 1 casella su 100). Si segna e si raccoglie come i cespugli
    (abilità raccogliere): in fiore dà 5 lino, poi rifiorisce in 2 giorni. Non si mangia: si fila in corde d'arco.
  Un colono mangia circa 2 vegetali al giorno se cucinati, 2,6 crudi; un cespuglio ne dà 2,5: 1–2 cespugli a testa.

### 4.4.2 Forgia, sartoria ed equipaggiamento
- **Stanze**: forgia (fornace e incudine), laboratorio (banco da lavoro, 15 legna; ci lavora anche il filatoio, 10 legna),
  falegnameria (banco del falegname, 15 legna).
- **Ricette** (si fanno da sé, come in cucina; il produttore va a prendere gli ingredienti uno alla volta e li porta alla
  postazione; tempo secondo livello, comfort della stanza e condizioni; rovinato come il cibo bruciato, ingredienti persi):

  | Oggetto | Dove | Abilità | Ingredienti | Secondi (liv. 5) |
  |---|---|---|---|---|
  | Lingotto | fornace | forgiare | 1 ferro + 1 carbone | 6 |
  | Corda d'arco | filatoio | cucire (filare) | 2 lino | 8 |
  | Armatura di cuoio | banco da lavoro | cucire | 4 pelli | 20 |
  | Cappuccio di cuoio | banco da lavoro | cucire | 2 pelli | 12 |
  | Arco | banco del falegname | armi a distanza | 3 legna + 1 corda d'arco | 15 |
  | Piccone, ascia | incudine | forgiare | 2 lingotti + 2 legna | 15 |
  | Spada | incudine | forgiare | 3 lingotti + 1 legna | 20 |
  | Falcetto | incudine | forgiare | 1 lingotto + 1 legna | 10 |
  | Elmo | incudine | forgiare | 3 lingotti | 20 |
  | Cotta di maglia | incudine | forgiare | 6 lingotti | 30 |

- **Menu della postazione**: clic su fuoco da campo, fornace, incudine, banco da lavoro, filatoio o banco del falegname
  (senza strumenti scelti) apre il suo menu: una riga per ricetta con icona, nome (col mouse sopra l'effetto del pezzo),
  ingredienti e **"Keep N"**, quanti tenerne. Si fa finché in giro (a terra, in magazzino, in mano, in lavorazione) ce
  ne sono meno; vale per tutte le postazioni dello stesso tipo. Fuori dalla sua stanza il menu lo dice, in rosso.
  Al fuoco da campo i pasti, da 2 crudi uguali qualsiasi. Il suggerimento sul mobile dice "Click: what to make".
  All'inizio: pasti 6, lingotti 10, corde d'arco 2, equipaggiamento 0.
- Equipaggiamento: oltre ai "Keep", quanto manca perché ogni colono abbia pieni i suoi slot; per corpo e testa il primo
  in elenco di cui ci sono gli ingredienti (prima il cuoio, poi il metallo). Almeno un arco se ci sono animali segnati e
  nessuno ne ha uno. "Keep" per un pezzo = quanti tenerne di scorta, oltre a quelli indossati. Un pezzo scelto nella
  scheda (vedi sotto) si fa per chi l'ha scelto e non ce l'ha, contando solo quelli uguali già fatti.
  Poi: ordini "fanne N" e "per sempre", sospendere una ricetta, qualità degli oggetti, cambiare un pezzo con uno migliore.
- **Pelli**: dagli animali cacciati, 1 dal coniglio, 3 dal cervo. Non marciscono.
- **Equipaggiamento** (3 slot: mani, corpo, testa): ogni colono con uno slot vuoto va a prendere in magazzino il pezzo
  giusto. Nelle mani l'attrezzo della sua abilità migliore tra estrarre, tagliare legna, raccogliere e cacciare.
  - **Scelta dalla scheda**: clic su uno slot apre un menu: *Auto* (all'inizio, come sopra), *Empty* (niente) e i pezzi
    di quello slot, ognuno con quanti ce ne sono liberi; spuntato quello scelto. È un ordine: appena è libero il colono va
    a prendere il pezzo scelto e posa lì quello che aveva; con *Empty* se lo toglie e lo lascia ai suoi piedi, poi si
    porta in magazzino. Se il pezzo non c'è si fa (vedi sopra). Uno slot scelto a mano ha un puntino d'oro in alto a
    destra; il suggerimento dice "Auto" o la scelta, e "(on the way)" finché non ce l'ha addosso. Chi ha le mani scelte
    non va a prendersi l'arco per cacciare. Gli avventurieri hanno il loro equipaggiamento: per loro niente menu.
  Ogni armatura ha una **protezione** (per combattimento e freddo, che verranno); i **bonus** li dà solo il pezzo che li ha:

  | Pezzo | Slot | Protezione | Effetto |
  |---|---|---|---|
  | Piccone | mani | — | scavare −25% tempo |
  | Ascia | mani | — | tagliare −25% tempo |
  | Falcetto | mani | — | raccogliere ed estirpare −25% tempo |
  | Arco | mani | — | serve per cacciare: +10% a segno, +2 caselle di tiro, mira col migliore tra cacciare e armi a distanza (+1 esperienza in entrambe); in combattimento tira (danno 14) |
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
- **Lupi**: dal giorno 5 (poi ogni 3 giorni) un branco di 2–3 lupi entra da un bordo della mappa e punta alla colonia.
  Inseguono il colono in piedi più vicino che sta **fuori dalle stanze** (nelle stanze non entrano: i muri proteggono) e lo
  mordono (danno 8, ogni 1,5 s; a segno 70% − 3% per livello di mischia di chi è morso; ogni morso +5 stress).
  Senza nessuno da inseguire, dopo un giorno se ne vanno. Abbattuti lasciano 5 carne e 2 pelli. Nella barra in alto "WOLVES: n".
- **Coloni**: con un lupo entro 12 caselle lasciano tutto e combattono contro il più vicino. Chi è sotto 40 punti ferita
  invece scappa nella stanza più vicina dove può entrare e lì aspetta (niente lavori) finché il pericolo non passa; se non
  ce n'è, combatte.
  - Corpo a corpo: un colpo ogni 1,5 s a livello 5 (abilità armi da mischia), a segno 50% + 5% per livello sopra il 5;
    danno dell'arma o dell'attrezzo in mano (spada 15, ascia 12, piccone 10, falcetto 8, mani nude 5). +1 esperienza a colpo.
  - Con l'arco: tira da lontano (fino a 8 caselle), un tiro ogni 2 s a livello 5 (armi a distanza), a segno come a caccia;
    danno 14. +1 esperienza a tiro. La freccia vola come a caccia: anche mancato, il lupo se la prende con chi ha tirato.
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
  | Studioso | libro | sale di livello dopo ogni spedizione (non ogni 2); il gruppo trova libri il doppio delle volte |
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
  | Monastero sepolto | 3 | 6 | 1½ giorni | 5–20 | sempre un libro (vedi 4.7.2) |

  All'inizio si conosce solo la torre. Il **tesoro** dell'ultima stanza di ogni rovina ha il triplo delle monete, i suoi
  libri (vedi 4.7.2) e la **mappa** della rovina dopo (in quest'ordine: il forte porta al monastero); a volte (15%) un forziere qualunque ha la mappa di una rovina che non
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
- Calendario: 365 giorni. Capodanno (Crown Day), poi quattro stagioni di 3 mesi da 30 giorni, ognuna chiusa da un giorno
  di festa fuori dai mesi (91 giorni a stagione). Primavera: Thaw, Sowing, Blossom, Flower Feast; estate: Highsun, Haying,
  Ripening, Sickle Feast; autunno: Reaping, Leaffall, Mists, Hearth Feast; inverno: Frost, Deepsnow, Longnight, Candle
  Feast. La partita comincia a Capodanno dell'anno 1. **Stato**: fatto il calendario (barra in alto e diario); le stagioni
  cambiano la temperatura (sotto); d'inverno niente raccolti: i cespugli perdono bacche e fiori di lino al primo giorno
  d'inverno e li rifanno 2 giorni dopo Capodanno.
- **Temperatura**: la media del giorno sale e scende con l'anno senza salti: 23 °C a metà estate, −1 °C a metà inverno,
  2 °C a Capodanno (il disgelo); vedi il comfort (4.3).
- **Finestra del calendario** ✓: si apre cliccando la data in alto; una pagina per mese (il Capodanno sulla prima
  dell'anno, la festa della stagione in fondo al suo terzo mese), che si sfoglia. Oggi è evidenziato, i giorni passati
  più spenti; sui giorni i segni di feste e Capodanno, giorni di riposo (con la legge), voci della cronaca (morti,
  spedizioni, ondate di freddo: ognuna nel suo giorno) e scadenze (ritorno previsto delle spedizioni, leggi revocate che
  si possono ripromulgare); col mouse sopra, il dettaglio.
- **Meteo** ✓: sereno, pioggia, nebbia, temporale (lampi), neve; cambia ogni 6–20 ore, sereno quasi una volta su due.
  È deciso in anticipo per due giorni e mezzo, ondate di freddo comprese: le previsioni lo leggono.
- **Previsioni** ✓: in alto, accanto alla data, una striscia col tempo e i gradi di adesso, le icone delle prossime
  quattro fasce di sei ore e quelle degli avvisi (col mouse sopra, il testo). Cliccata apre il pannello: adesso, una
  riga per fascia (tempo, gradi più bassi e più alti) per 24 ore, un giorno in più con la ricerca Astronomia, e gli
  avvisi: ondata di freddo (in corso, fino a quando; in arrivo, fra quante ore), gelata (fra quante ore si va sotto lo
  zero e fin dove), acqua che gela, gelata o che sgela, temporale.
- **Acqua che gela** ✓: sotto lo zero gela, tanto più in fretta quanto fa freddo (a −5 °C in un giorno), e sgela allo
  stesso modo; si vede ghiacciare a chiazze. Gelata del tutto regge: si cammina sull'acqua alta, quella bassa non
  rallenta, non si pesca, la neve ci si posa. Torna acqua quando è sciolta a metà: chi sta sull'acqua alta torna a riva.
  Quando la media del giorno è sotto i 3 °C pioggia e temporali vengono giù come neve: da fine autunno ai primi giorni di
  primavera. La neve si posa per terra e sui tetti; sotto lo zero resta, sopra si scioglie (a 10 °C in 12 ore) in
  pozzanghere, che riempie anche la pioggia e che si asciugano in 8 ore.
- **Ondata di freddo** ✓: quando la media del giorno è sotto gli 8 °C (da metà autunno al disgelo), ogni giorno una
  volta su 33 arriva e per 2–4 giorni fa 10 °C in meno (mezza giornata per arrivare e per andarsene); la annunciano le
  previsioni (vedi sotto) e, quando arriva, la cronaca. Col freddo che porta, pioggia e temporali vengono giù come neve.

### 4.6 Eventi casuali
- Un "narratore" pesca eventi con probabilità che dipende dallo stato della colonia.
- Ogni evento è un file di dati (condizioni, peso, effetti, testi localizzati).
- Lista da definire. Esempi segnaposto: arrivo di un viandante, malattia, incendio, ondata di freddo, raccolto abbondante.

### 4.7 Ricerca: il sapere e le leggi
Due ricerche. Il **sapere** (le ricerche) si paga in **studio**, che i coloni scrivono allo scrittoio, e in **libri** che
gli avventurieri riportano dalle rovine. Le **leggi** si pagano in **autorità**, che il sovrano raccoglie sul trono, e
si mettono in vigore sui **sigilli** che il titolo concede. Il sapere viene da fuori, la legge viene dal trono.

#### 4.7.1 Lo studio
- **Scrittoio** (1x1, 10 legna) e nuovo tipo di stanza **Studio** (lavoro): almeno uno scrittoio. Ci sono dall'inizio.
- Lavoro **Studiare** (abilità ricerca): allo scrittoio il colono scrive pagine, **una pagina un punto studio** e +1
  esperienza. 2,5 s a pagina a livello 5 (×1,5 a livello 0, ×0,5 a 10), secondo comfort e condizioni: in un turno di
  8 ore circa 21 punti a livello 0, 32 a livello 5, 64 a livello 10.
- Studiano prima i **lavoratori** della stanza, che restano seduti fino a fine turno; poi chi non ha altro da fare
  (una pagina, poi rivaluta).
- **Luce**: dalle 19 alle 6, senza un abat-jour nella stanza, +50% tempo. Ogni **libreria** nella stanza −10%, fino a 3.
- Lo studio va in un **mucchio comune**, non a una ricerca precisa: si accumula sempre e si spende quando il re decide.
- Il sovrano può partire con 3 punti in ricerca (4.3.1): un re studioso è una scelta d'apertura.

#### 4.7.2 I libri
- Tipo di oggetto **Libro** (icona: il quaderno), mucchi da 10, non marcisce. Una ricerca di livello II, III o IV ne
  consuma uno. I tre si riconoscono dal colore, dalla sagoma e dalle fasce d'oro sul dorso (una, due, tre):

  | Libro | Livello | Da dove |
  |---|---|---|
  | Quaderno azzurro (sottile) | II | torre, miniera, cripta; poi si copia (Scriptorium), l'erudito lo vende a 40 monete |
  | Tomo rosso (spesso, col fermaglio) | III | cripta, forte, monastero; poi si rilega (Biblioteca reale), raro dall'erudito (120) |
  | Codice di porpora (grande, con la gemma) | IV | solo dalle rovine profonde: forte, monastero, cittadella |

- **Nelle rovine**: in ogni forziere, il 35% delle volte un libro al posto dell'oggetto (con lo **Studioso** il doppio);
  il **tesoro** ha sempre i suoi libri, oltre a monete e mappa.

  | Rovina | Libro nel forziere | Nel tesoro |
  |---|---|---|
  | Torre diroccata, miniera abbandonata | quaderno | 2 quaderni |
  | Cripta | quaderno o tomo, metà e metà | 1 tomo |
  | Forte in rovina | tomo; uno su quattro codice | 1 codice |
  | Monastero sepolto | sempre: quaderno 50%, tomo 25%, codice 25% | 1 tomo e 1 codice |
  | Cittadella del Re Dimenticato (dalla ricerca) | tomo o codice | 1 codice e la Corona antica |

- **Monastero sepolto**: rovina nuova, pericolo 3, 6 stanze, un giorno e mezzo di viaggio; forzieri poveri di monete
  (5–20) e sempre con un libro. La sua mappa è nel tesoro del forte.
- **Erudito errante** (evento del narratore): se c'è una locanda, ogni 10 giorni circa passa per un giorno; vende 1–2
  libri o ne compra uno a metà prezzo. È il ponte tra oro e sapere.
- **Bilancio**: ripulite le rovine si trovano circa 5 quaderni, 3–4 tomi e 2–3 codici; le ricerche ne chiedono 14, 6 e
  6. I quaderni si copiano, i tomi bastano per metà, i codici per due o tre capolavori: il livello IV è una scelta, a
  meno di partire per la Cittadella.

#### 4.7.3 Le ricerche
- Finestra **Knowledge** (tasto in basso, K, o clic su uno scrittoio): lo studio e i libri in magazzino, poi l'albero,
  una riga per ramo e una colonna per livello. Una ricerca si studia se ci sono quelle prima, i punti e (dal livello II)
  il libro in magazzino: **Studia** la sblocca subito, consumando punti e libro.

  | Livello | Studio | Libro | Uno studioso a livello 5 |
  |---|---|---|---|
  | I | 40–100 | — | 1–3 giorni |
  | II | 200–300 | quaderno azzurro | 6–9 giorni |
  | III | 450–500 | tomo rosso | 14–16 giorni |
  | IV | 1000–1200 | codice di porpora | 31–38 giorni |

  L'albero intero (44 ricerche) vuole circa 14.500 punti: con tre studiosi bravi 95 giorni. Si sceglie, non si finisce.
- **Dall'inizio**, senza ricerca: muro e pavimento di legno, porta, sentiero, letto, tavolo, sedia, fuoco da campo,
  stendardo, scrittoio, trono; il pasto; tagliare, scavare, estirpare, raccogliere, pescare, costruire, distruggere, e
  cacciare con un arco; stanze magazzino, camera, dormitorio, cucina, studio, sala del trono. Tutto il resto, anche
  quello che c'era già (in corsivo qui sotto), sta in un nodo dell'albero. Materie prime, cibo crudo, monete e cimeli
  non cambiano.
- **L'albero**: sei rami, ognuno con una linea maestra dal livello I al IV e due linee corte. ✓ = c'è nel gioco.

  | Ramo | Ricerca | Liv. | Studio | Richiede | Sblocca |
  |---|---|---|---|---|---|
  | Terra | Orto | I | 80 | — | zona orto e lavoro Coltivare: rape e cavoli ogni 3 giorni, niente d'inverno |
  | | Forno di pietra | II | 300 | Orto | forno 2x1: pane (2 vegetali → 3, sazia 60, dura 8 giorni), stufato |
  | | Apicoltura | III | 450 | Forno di pietra | arnia accanto alle aiuole: miele (non marcisce), cera (candele: si studia di notte) |
  | | Banchetto reale | IV | 1000 | Apicoltura | il banchetto al forno: +15 felicità per 3 giorni, +20 autorità |
  | | Caccia ✓ | I | 50 | — | *filatoio, corda d'arco, banco del falegname, falegnameria, arco* |
  | | Affumicatoio | II | 200 | Caccia | carne e pesce affumicati durano quattro volte tanto |
  | | Dispensa fredda | I | 100 | — | stanza dispensa: il cibo dura il triplo |
  | Fuoco | Forgia ✓ | I | 60 | — | *fornace, incudine, forgia, lingotto, piccone, ascia, falcetto* |
  | | Acciaio | II | 300 | Forgia | acciaio (2 lingotti + 2 carbone): attrezzi −40% tempo, spada danno 20 |
  | | Vetreria | III | 500 | Acciaio | vetro: finestre (+1 comfort), occhiali (studiare e cucire −20%) |
  | | Altoforno | IV | 1100 | Vetreria | lingotti e acciaio tre alla volta, con metà carbone |
  | | Sartoria ✓ | I | 50 | — | *banco da lavoro, laboratorio, armatura e cappuccio di cuoio* |
  | | Telaio | II | 200 | Sartoria | tela: mantello imbottito (freddo), bende |
  | | Carbonaia | I | 80 | — | 5 legna → 2 carbone: il carbone non solo dalle vene |
  | Pietra | Muratura ✓ | I | 60 | — | *muri e pavimenti di pietra*; poi il camino |
  | | Arredo fine | II | 250 | Muratura | letto a baldacchino, tappeto, armadio: la camera signorile del sovrano |
  | | Statuaria ✓ | III | 500 | Arredo fine | *statua del re*; poi i memoriali dei caduti (lutto un giorno in meno) |
  | | Palazzo | IV | 1200 | Statuaria | la sala del trono diventa palazzo: udienza +50%, +10 splendore |
  | | Decorazioni ✓ | I | 40 | — | *aiuola, fioriera, panca* |
  | | Fontana ✓ | II | 250 | Decorazioni | *fontana* |
  | | Strada lastricata | I | 60 | — | lastre di pietra: si cammina il 25% più svelti |
  | | Ponte | II | 200 | Strada lastricata | si attraversa l'acqua alta, si pesca dal ponte |
  | Ferro | Palizzata | I | 80 | — | palizzata e cancello: i lupi non passano |
  | | Torre di guardia | II | 300 | Palizzata | lupi visti a 20 caselle; arciere in torre +2 caselle, +15%; campana |
  | | Balestra | III | 500 | Torre di guardia | danno 22, un tiro ogni 4 s, +15% a segno |
  | | Armatura a piastre | IV | 1200 | Balestra, Cotta di maglia, Acciaio | protezione 7, +15% tempo |
  | | Armi di ferro ✓ | I | 80 | Forgia | *spada, elmo* |
  | | Cotta di maglia ✓ | II | 300 | Armi di ferro | *cotta di maglia* |
  | | Fantoccio | I | 60 | — | allenamento nel tempo libero: svago e esperienza in mischia |
  | | Scudo | II | 250 | Fantoccio | scudo tondo: +3 protezione con spada o pugnale |
  | Strada | Locanda ✓ | I | 40 | — | *bacheca degli incarichi, locanda, ingaggi e spedizioni* |
  | | Locanda rinomata | II | 250 | Locanda | arrivi ogni giorno e mezzo, restano 5 giorni; avviso per la classe |
  | | Compagnia della corona | III | 500 | Locanda rinomata | i coloni partono con gli avventurieri |
  | | Mappa del Re Dimenticato | IV | 1000 | Compagnia, Cartografia | la Cittadella: pericolo 5, 10 stanze, 3 giorni |
  | | Provviste secche | I | 80 | — | gallette: valgono 2 provviste, non marciscono |
  | | Armeria di prestito | II | 250 | Provviste secche | si presta l'equipaggiamento agli avventurieri |
  | | Cartografia | I | 80 | Locanda | stanze rimaste e la prossima; viaggio −25% |
  | Sapere | Libreria ✓ | I | 60 | — | libreria: −10% tempo a pagina nella stanza, fino a 3 |
  | | Scriptorium | II | 250 | Libreria | pergamena e inchiostro: si copiano i quaderni (3 pergamene, 1 inchiostro, 150 studio) |
  | | Astronomia ✓ | III | 500 | Librerie (per ora: lo Scriptorium non c'è) | le previsioni del tempo arrivano un giorno più in là |
  | | Biblioteca reale | IV | 1200 | Astronomia | si rilegano i tomi (2 quaderni + 400 studio); +2 autorità al giorno |
  | | Erboristeria | I | 100 | — | erbe medicinali, unguento (+30 punti ferita) |
  | | Medicina | II | 300 | Erboristeria | infermeria e medico: cura chi è a terra |
  | | Lanterne ✓ | I | 40 | — | *abat-jour, lampione* |

#### 4.7.4 L'autorità
- **Trono** (1x1, 12 legna) e nuovo tipo di stanza **Sala del trono** (lavoro: si spunta solo il sovrano). Ci sono
  dall'inizio.
- Lavoro **Governare**, solo del sovrano: sul trono tiene udienza, **+1 autorità all'ora** (×1,25 se la sua felicità
  è almeno 70, ×0,5 se è al più 30). Governa prima se è lavoratore della sala del trono, se no quando non ha altro da
  fare. Il costo vero è il suo tempo.
- **Ogni giorno**: +1 per titolo (signoria 1, baronia 2, contea 3, regno 4) e +1 ogni 20 di splendore.
- **Eventi**: festa del raccolto +5. Poi: incoronazione +20, spedizione tornata col tesoro +5, cimelio posato +3;
  colono morto −5, ogni colono sotto 20 di felicità −1 al giorno.

#### 4.7.5 Codificare, promulgare, revocare
- Finestra **Laws** (tasto in basso, G, o clic sul trono): autorità, sigilli, granaio, poi le leggi per categoria.
- **Codificare** è la ricerca civica: una volta sola, con autorità. Serve il titolo della fascia della legge e a volte
  una ricerca.
- **Promulgare** costa 10 autorità e prende un **sigillo**: signoria 2, baronia 3, contea 4, regno 5. La successione ha
  un posto suo (Primogenitura, in vigore dall'inizio).
- Le leggi dello stesso **gruppo** si escludono (Tasse, Turni, Giustizia, Accoglienza, Successione, Corona finale):
  promulgarne una revoca quella in vigore.
- **Revocare** è gratis, ma per 3 giorni la legge non si ripromulga.
- **Consenso**: ogni legge in vigore cambia la felicità di chi è in colonia secondo i talenti (agli avventurieri la
  loro). Sulla scheda sta tra le condizioni, con l'icona della legge (col mouse sopra: approva o disapprova, quanto).
- **Protesta** (poi): un colono sotto 20 di felicità che disapprova almeno due leggi molla il lavoro per 2 ore e va a
  lamentarsi nella sala del trono; −5 autorità. Con Pene severe finisce alla gogna; con Clemenza il sovrano lo ascolta.

#### 4.7.6 Le tasse
I coloni non hanno monete: l'oro viene dalle rovine e va agli avventurieri. Le tasse non lo fanno nascere dal nulla:
1. **In natura** (Decima, Taglia): una parte di quello che si produce va al **granaio della corona**. Il granaio paga
   per primo le provviste delle spedizioni; poi le feste, metà paga degli avventurieri in viveri, l'erudito, le carestie
   (Granaio aperto). È una riserva: più è pieno più la colonia regge, ma intanto quel cibo non lo mangia nessuno.
2. **In lavoro** (Corvée): ore della routine ai cantieri della corona, una quarta casella colorata.
3. **Su chi viene da fuori** (Gabella sul bottino, Tassa di soggiorno, Pedaggio): le monete le pagano avventurieri e
   viandanti; ne arrivano di meno.
4. **In fedeltà** (Tributo, in contea): la felicità dei coloni diventa autorità.

#### 4.7.7 Il libro delle leggi
Quattro fasce, una per titolo; sei categorie. ✓ = c'è nel gioco.

| Categoria | Legge | Fascia | Costo | Gruppo, richiede | Effetto | Felicità |
|---|---|---|---|---|---|---|
| Tesoro | Esenzione ✓ | signoria | 30 | Tasse | niente decima | tutti +5 |
| | Decima ✓ | signoria | 40 | Tasse | un pezzo su dieci di quello che si raccoglie, caccia, pesca, cucina e fa va al granaio | tutti −3 |
| | Gabella sul bottino ✓ | signoria | 40 | Locanda | quota degli avventurieri 20% (non 30); un quarto in meno di arrivi, niente avidi | avventurieri −5 |
| | Tassa di soggiorno ✓ | signoria | 30 | Locanda | una moneta a notte da chi aspetta alla locanda; resta un giorno in meno | avventurieri −3 |
| | Taglia | baronia | 100 | Tasse, dopo Decima | un pezzo su cinque al granaio | tutti −8 |
| | Pedaggio | baronia | 80 | Palizzata | 2 monete da chi entra dal cancello o dal ponte; un quinto in meno di arrivi | avventurieri −3 |
| | Granaio aperto | baronia | 60 | dopo Decima | senza cibo in magazzino si mangia dal granaio; una volta a stagione un pasto a tutti | tutti +4 |
| | Tributo | contea | 150 | — | +1 autorità al giorno a colono | tutti −4 |
| Lavoro | Turni lunghi ✓ | signoria | 40 | Turni | 10 ore di lavoro (il pigro 7, lo stacanovista resta a 12); stress +25% | tutti −5; stacanovista +3; pigro, festaiolo, irrequieto −10 |
| | Giornata corta ✓ | signoria | 40 | Turni | al più 6 ore; stress −25% | tutti +8; stacanovista −5 |
| | Riposo festivo ✓ | signoria | 30 | — | ogni settimo giorno si cucina e basta | tutti +6; stacanovista −5; asceta 0 |
| | Corvée | baronia | 80 | — | 2 ore di tempo libero ai cantieri della corona, che vanno il 25% più svelti | tutti −6; stacanovista 0 |
| | Turno di guardia | baronia | 80 | Palizzata | un colono veglia di notte (prima i nottambuli): lupi visti al bordo | nottambulo +5; dormiglione −5 |
| | Corporazioni | contea | 150 | — | nelle stanze di lavoro lavorano solo i lavoratori, il 20% più svelti | lavoratori +5; gli altri −2 |
| Ordine | Coprifuoco ✓ | signoria | 40 | — | dalle 21 tutti a letto: niente sere al fuoco, meno prede per i lupi | tutti −2; festaiolo −10; mattiniero +3 |
| | Milizia | signoria | 50 | Fantoccio | un'ora al giorno al fantoccio; si scappa sotto 30 punti ferita | tutti −3; iracondo +3 |
| | Pene severe | baronia | 80 | Giustizia | gogna per sfuriate e proteste; sfuriate un terzo meno spesso | tutti −2; iracondo −10 |
| | Clemenza | baronia | 80 | Giustizia | sfuriate di un'ora; il sovrano ascolta chi protesta | tutti +3; iracondo +5 |
| | Riserva di caccia | baronia | 100 | — | cervi doppi, solo del sovrano e dei cacciatori; +3 autorità a cervo del sovrano | cacciatori +3; gli altri −3 |
| | Legge marziale | contea | 150 | — | con nemici in vista nessuno scappa sopra 20 punti ferita; +10% a segno | tutti −5 |
| Popolo | Porte chiuse | signoria | 30 | Accoglienza | nessuno chiede di restare | tutti +5 |
| | Porte aperte | signoria | 40 | Accoglienza | un avventuriero chiede di restare dopo 2 spedizioni, i viandanti il doppio; forestieri per 10 giorni | forestieri −5 |
| | Giuramento | baronia | 80 | — | chi arriva giura davanti al trono (10 autorità): non è forestiero | nuovi coloni +5 |
| | Padrinato | baronia | 100 | — | un padrino: +50% esperienza per 10 giorni lavorandogli vicino | padrino e figlioccio +3 |
| | Matrimoni misti | contea | 150 | — | coloni e avventurieri si sposano; l'avventuriero resta come colono | avventurieri +5 |
| | Scuola | contea | 180 | Scriptorium | un'ora allo scrittoio per figli e forestieri; i figli crescono con 3 punti abilità in più | figli e forestieri +3 |
| | Carta delle libertà | regno | 300 | Corona finale | leggi del Popolo ×1,5; Taglia, Corvée, Coprifuoco e Pene severe non si promulgano più | tutti +10 |
| Corona | Primogenitura | dall'inizio | — | Successione | regna il primo figlio | — |
| | Corte | baronia | 100 | — | il sovrano non lavora più: udienza +50%, il suo sguardo a 12 caselle | sovrano +5 |
| | Guardia del corpo | baronia | 80 | Scudo | una guardia segue il sovrano; finché è in piedi il sovrano a terra non viene finito | la guardia +3 |
| | Successione elettiva | contea | 150 | Successione | la colonia sceglie l'erede tra coniuge e figli; lutto regale 4 giorni | tutti +2 |
| | Assolutismo | regno | 300 | Corona finale | le leggi non danno più né approvazione né disapprovazione; udienza +100% | — |
| Feste | Festa del raccolto ✓ | signoria | 40 | — | i cinque giorni di festa del calendario si cucina e basta; poi +10 felicità per 3 giorni, +5 autorità | — |
| | Funerali | signoria | 30 | cimitero | due ore di funerale: lutto di 2 giorni, −10 | — |
| | Torneo | baronia | 100 | Fantoccio | gare a stagione; quel giorno gli avventurieri arrivano di un livello in più | tutti +3; iracondo +5 |
| | Cronista di corte | baronia | 80 | Scriptorium | +1 autorità per spedizione raccontata, epiteti più ricchi | il cronista +3 |
| | Mecenatismo | contea | 150 | — | decorazioni +25% splendore (Mecenate +50%); 2 monete al giorno agli artisti | tutti +2 |
| | Calendario delle feste | contea | 180 | Astronomia | feste annunciate (+3 nei due giorni prima), ×1,5, un giorno in più a stagione | festaiolo +5 |

#### 4.7.8 All'inizio della partita
- I lupi arrivano dal giorno 5 (vedi 4.4.3).
- Su ogni mappa c'è sempre un'**arma abbandonata**: a caso tra spada, ascia e arco, a 15–25 caselle dalla radura, sul
  prato. Si raccoglie come ogni oggetto a terra e la prende chi la sa usare. Con l'arco si caccia già (l'ordine Caccia c'è
  sempre, serve un arco); la ricerca Caccia serve a farne altri. Poi: i resti del bivacco accanto.

**Ordine di lavoro** (4.7): (1) scrittoio, studio, Studiare, mucchio di studio, finestra Knowledge coi nodi di livello I
che raccolgono quello che c'è già, lupi dal giorno 5, arma abbandonata; (2) libri nei forzieri e nei tesori, Studioso,
monastero, livello II e III di quello che c'è già (cotta, fontana, statua); (3) trono, Governare, autorità, finestra
Laws, le leggi di signoria che usano cose che esistono, consenso sulla scheda; (4) granaio e decima, titolo che cresce
(4.3, fase 6) con sigilli e fasce; (5) il resto dell'albero un nodo alla volta, erudito errante, protesta; (6) livello
IV, regno, leggi finali, cittadella.
**Stato**: fatte le fasi 1–3 e della 4 la decima. Nel gioco: scrittoio, libreria e trono; stanze Studio e Sala del trono;
lavori Studiare e Governare; studio e autorità (nelle finestre Knowledge e Laws, tasti K e G, o clic su scrittoio e
trono); i tre libri, nei forzieri e nei tesori, col monastero; le 12 ricerche segnate ✓ (Statuaria per ora dopo
Muratura, finché non c'è Arredo fine); le 9 leggi segnate ✓, con 2 sigilli (il titolo non cresce ancora). Il granaio è
un conto, non una stanza, e niente ci marcisce; la festa del raccolto è nei cinque giorni di festa del calendario (4.5).
Manca il resto, e i contatori di studio e autorità nella barra in alto (a 1280 di larghezza non ci stanno).

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
7. Ricerca: il sapere e le leggi (vedi 4.7)

### Fuori scope (per ora)
Combattimento tattico (oggi i coloni si difendono da soli, vedi 4.4.3), livelli verticali, commercio/diplomazia, mod.

## 6. Domande aperte
- Dimensione dei tile: 16×16 o 32×32?
- Condizione di sconfitta oltre alla fine della dinastia?
- Lista degli eventi.
- Nome definitivo del gioco.
