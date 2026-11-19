# King — Game Design Document

> Stato: bozza v0.1 — 2026-11-15
> Cose da fare, sistema per sistema: [DA_FARE.md](DA_FARE.md).

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
- Ogni colono ha una tabella colono × lavoro con priorità 1–4 (o disattivato) ✓: in cima alla finestra Jobs, una riga
  per colono e una colonna per lavoro (cucinare, produrre, tagliare, scavare e tagliare il ghiaccio, raccogliere ed
  estirpare, coltivare, pescare, cacciare, costruire arredare e riparare, trasportare, governare solo il sovrano,
  studiare); clic per dopo (1 → 4 → mai), clic destro per prima.
- All'inizio tutto 3: i coloni vanno nell'ordine delle colonne, come prima della tabella.
- Il colono sceglie il lavoro disponibile con priorità più alta; a pari priorità quello più a sinistra; di un lavoro
  il più vicino. Prima della tabella: prendere l'equipaggiamento, e chi è spuntato su sala del trono o studio ci
  governa e ci studia; un tetto in fiamme viene prima di tutto.

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
- **Scheda** (clic sul colono): nome, soprannome (facoltativo), cognome, sesso, punti ferita, abilità (ognuna con un'icona 8×8), talenti (solo icone, il nome col mouse sopra), equipaggiamento (4 slot: mani, corpo, testa, scudo). Poi bisogni, relazioni.
- **Abitanti** (clic sul numero dei coloni in alto, o sulla sua icona; deciso il 2026-11-19): una finestra con tutti,
  gruppo per gruppo, ognuno nel suo riquadro (con la striscia del colore del gruppo a sinistra): figurina grande, nome
  (cliccato apre la scheda) e chi è, sesso, età e cosa sta facendo adesso
  (si aggiorna da sé). I gruppi: **coloni** (prima il sovrano, poi i neonati), **forestieri** (i nuovi coloni ancora
  forestieri, con quanto manca; i viandanti; i pretendenti), **alla locanda** (gli avventurieri, con classe, livello,
  paga e quando se ne vanno), **in spedizione** (ogni gruppo con la rovina e il giorno del ritorno; finché non tornano
  la colonia non sa come va). Il numero in alto conta anche i coloni in spedizione.

### 4.2.1 Nuovi coloni: chi resta e chi arriva
Decisa il 2026-11-19. Numeri da tarare. La colonia cresce in tre modi: i figli (4.3.3), gli avventurieri che restano e
i viandanti. Il valore della colonia (lo splendore) attira gente; i tanti coloni la frenano, senza un tetto fisso.
- **L'avventuriero che resta**: tornato alla locanda dalla sua terza spedizione (dalla seconda con Porte aperte, 4.7.7),
  se la sua felicità è almeno 60 chiede di restare come colono. Una finestra lo chiede al giocatore: **Accogli** o
  **No**; chiusa con la X, la domanda resta sulla sua scheda finché è alla locanda (ingaggiato, la ritira). Rifiutato,
  lo richiede dopo altre 3 spedizioni.
  - Accolto, diventa un colono: tiene nome, età, aspetto, abilità (quelle della classe), talenti (anche quelli da
    avventuriero: il Famoso dà ancora splendore, gli altri contano solo in spedizione, vedi Compagnia della corona in
    4.7.3) e il suo equipaggiamento, che ora è della colonia. Lo scudo del guerriero diventa uno scudo vero, nel suo
    slot; lo scassinatore si toglie maschera e sacca (la faretra resta all'arciere). Lavora, ha le sue priorità, dorme
    nei letti dei coloni. Nella scheda: "Un tempo guerriero, livello 3".
- **Viandanti**: gente di passaggio che chiede di restare. Arrivano dal bordo della mappa e vanno nella sala del trono
  (se no a un fuoco, se no alla radura); lì una finestra chiede: **Accogli** o **Manda via** (se ne vanno). Aspettano la
  risposta 2 giorni (la domanda resta sulla loro scheda), poi se ne vanno da sé. Intanto non lavorano: si svagano,
  mangiano dal magazzino, dormono alla locanda o per terra.
  - Chi: una persona sola (70%), una coppia sposata (15%) o una famiglia (15%: un genitore, o una coppia, con un figlio
    di 4–11 anni). Gli adulti tra 16 e 45 anni, 4 punti abilità a caso (al più 3 per abilità) e 0–2 talenti; i figli
    né abilità né talenti. Una famiglia ha lo stesso cognome. Uno su quattro porta un attrezzo (piccone, ascia, falcetto
    o arco).
  - Quanti: dal giorno 10, in media uno ogni 30 giorni ÷ (1 + splendore / 20); sopra 8 coloni l'attesa raddoppia ogni
    4 coloni in più (×2 a 12, ×4 a 16). Per esempio: senza splendore 30 giorni; a 15 di splendore 17; a 60 di
    splendore e 15 coloni 25. ±30% a caso. Con Porte aperte la metà, con Porte chiuse non ne arrivano. Uno alla volta:
    l'attesa del prossimo comincia quando questo ha avuto la risposta o se n'è andato.
  - Per ora un evento fatto a mano, come l'erudito errante: da portare nel narratore (4.6).
- **Forestiero** (condizione, con la sua icona): chi resta, avventuriero o viandante, lo è per 5 giorni (10 con Porte
  aperte): non conosce ancora la colonia, −5 felicità e +10% tempo di lavoro. Col Giuramento (4.7.7) giura davanti al
  trono e non lo è. I figli nati in colonia e i pretendenti sposati non lo sono.
- **Ordine di lavoro**: (1) l'avventuriero che chiede di restare, la finestra della domanda, il forestiero; (2) i
  viandanti, soli o in famiglia; (3) le leggi dell'Accoglienza (Porte chiuse, Porte aperte, Giuramento, 4.7.7); (4) il
  titolo che sale anche col numero dei coloni (4.3); (5) la Compagnia della corona (4.7.3): i coloni in spedizione con
  gli avventurieri (vedi 4.4.4).
- **Stato**: fatte le fasi 1–5 il 2026-11-19 (test in `tests/test_newcomers.gd`). Ospiti (`visitor`) sono avventurieri,
  pretendenti e viandanti: non lavorano e dormono alla locanda. Le domande in attesa si salvano e, caricata la partita,
  la finestra si riapre. Chi giura va nella sala del trono prima di ogni altra cosa. Il contatore dei coloni nella barra
  in alto conta anche chi è in spedizione. Da tarare: l'attesa dei viandanti e quante volte chiedono di restare gli
  avventurieri.

### 4.3 Il re e la dinastia
- Il **sovrano** (re solo alla fine, vedi Titolo) è un colono come gli altri: lavori e priorità, bisogni, routine, abilità che
  crescono, equipaggiamento, combattimento. In più lo crea il giocatore a inizio partita (vedi 4.3.1) e il suo stato
  influisce sugli altri coloni.
- **Titolo**: cresce con la colonia, e con lui il nome del reame e la corona sullo stemma (vedi 4.3.2); non cala mai.
  Soglie provvisorie: lo splendore della colonia **e** il numero dei coloni, tutti e due (deciso il 2026-11-19;
  contano i figli e chi è in spedizione, non gli avventurieri né i neonati).
  È della casata: l'erede lo eredita. Il gioco si chiama King: diventare re è l'arco della partita.

  | Titolo | Reame | Corona sullo stemma | Splendore | Coloni | Sigilli (4.7.5) |
  |---|---|---|---|---|---|
  | Signore / Signora | Signoria di … | nessuna | — | — | 2 |
  | Barone / Baronessa | Baronia di … | cerchio | 15 | 6 | 3 |
  | Conte / Contessa | Contea di … | corona a punte | 35 | 10 | 4 |
  | Re / Regina | Regno di … | corona reale | 60 | 15 | 5 |

  Quando sale, una finestra al centro (e la cronaca) lo annuncia coi sigilli e l'autorità di ogni giorno.

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
- Età, matrimonio, figli e successione: vedi 4.3.3. Intrighi e vassalli fuori scope.

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
**Stato**: fatte le fasi 1, 2 e 6, e della 5 i talenti a punti (nella pagina del sovrano, col costo sul pulsante). "New Game" apre la pagina (creation.gd), "Start" la partita: il sovrano è il primo colono,
coi talenti scelti; in alto a sinistra la corona e "Lordship of …", che apre la sua scheda, dove sotto il
nome c'è "Lord/Lady of …". Senza la pagina (nei test) sovrano, colonia e stemma vengono a caso.
Fase 2: la pagina è divisa in due, "Your House" (nomi e stemma) e "Your Ruler"; stemma con 4 forme (francese antico,
sannitico, tondo, losanga), 7 partizioni, i 7 smalti, 9 pezze (capo, campagna, palo, fascia, banda, croce, decusse,
scaglione, bordura), 10 figure (stella, crescente, giglio, rosa, torre, corona, spada, chiave, albero, aquila).
Ogni pulsante mostra lo stemma com'è con quella scelta. Maglia e mantello seguono i primi due smalti finché non li si
sceglie (dagli smalti). Il dado rispetta la regola degli smalti: campo partito senza pezza né figura, niente figura
sulle pezze che passano dal centro. Lo stemma sta nella barra in alto (al posto della corona), nella scheda del
sovrano davanti al nome e sul drappo degli stendardi (ombreggiato dalle pieghe che ondeggiano).
Fase 6: il titolo sale con lo splendore (soglie sopra); la corona (16x6, in fondo a art/arms.png) sta sopra lo scudo
nella barra in alto e nella scheda del sovrano, che con lei diventano più alti; "Barony of …", "Baron …".

### 4.3.3 Dinastia: età, matrimonio, figli, successione
Decisa il 2026-11-19. Numeri da tarare.
- **Età**: ogni persona ha un'età (nella scheda, accanto al sesso). Il **ritmo della vita** si sceglie nella nuova
  partita (pagina della casata): **veloce**, un anno a stagione (91 giorni), quattro volte il calendario, così in una
  partita lunga passano le generazioni; o **reale**, un anno all'anno, come i tempi veri dell'orto (deciso il
  2026-11-19). I numeri qui sotto sono in anni di vita. Il sovrano parte tra 20 e 30 anni, gli
  altri coloni e gli avventurieri tra 18 e 40.
- **Vecchiaia**: dai 60 anni, a ogni compleanno muore con probabilità (età − 58) × 2%: 4% a 60, 24% a 70, 44% a 80.
- **Matrimonio**: dalla scheda del sovrano, "Combina un matrimonio": una persona adulta dell'altro sesso, non sposata.
  - Tra i **coloni**: accetta se la sua felicità è almeno 50.
  - **Pretendenti di altre casate**: finché il sovrano è adulto e non sposato, ogni 20 giorni circa ne arriva uno alla
    locanda (se c'è) e aspetta 5 giorni; ha il suo stemma, l'età (16–30), qualche talento e abilità, e la **dote**
    (monete, a volte un oggetto). Sposato, diventa un colono.
  - Le nozze: *nozze* a tutti (+10 felicità per 2 giorni), +10 autorità; la cronaca lo scrive. Il coniuge tiene il suo
    cognome; i figli prendono quello della casata.
- **Figli**: una coppia sposata che dorme nella stessa stanza può averne. Ogni notte l'1% (la donna tra 16 e 40 anni;
  dai 35 la metà). La gravidanza dura tre quarti d'anno di vita (68 giorni col ritmo veloce, 274 con quello reale;
  *incinta*: nell'ultimo terzo +20% tempo di lavoro), poi per un anno di vita niente. Alla nascita il giocatore sceglie il nome (col dado); i capelli da
  uno dei genitori (la pelle quando ci sarà); ogni talento dei genitori passa al 50%, al più due, mai in contrasto.
  - **Neonato** (0–3 anni): sta nella culla (mobile nuovo, in Casa, 4 legna) della stanza dei genitori; non lavora.
  - **Bambino** (4–11): aiuta a raccogliere e a trasportare, a metà velocità; niente armi né armature; scappa
    sempre dai lupi. Bambini e ragazzi si vedono più piccoli.
  - **Ragazzo** (12–15): i lavori leggeri (non costruire, scavare, tagliare, cacciare); poi esperienza doppia,
    quando ci saranno le soglie di livello (4.2).
  - **Adulto** (16).
- **Successione**: alla morte del sovrano eredita il **primo figlio vivo, maschio o femmina**; senza figli il coniuge,
  poi un fratello o una sorella. Se non c'è nessuno, la colonia sceglie un nuovo sovrano tra i coloni adulti (lo indica
  il giocatore) e nasce una nuova casata, col suo stemma; il titolo resta al reame.
  - **Lutto regale**: 7 giorni (al posto del lutto), −20 felicità, +25% stress da lavoro.
  - **Reggenza**: se l'erede ha meno di 16 anni regna un reggente (il coniuge del sovrano morto, se no il colono adulto
    con più abilità): governa sul trono come il sovrano; a 16 anni l'erede è incoronato.
  - **Incoronazione**: finito il lutto (o la reggenza), 2 giorni a tutti +10 felicità; +20 autorità. Si sceglie lo stile
    di regno del nuovo sovrano (quando ci sarà, 4.3).
  - Titolo e stemma passano all'erede.
- **La casata**: una finestra con l'albero genealogico (sovrani, coniugi, figli), gli anni di regno e gli epiteti.
- **Ordine di lavoro**: (1) età e vecchiaia; (2) matrimonio coi coloni; (3) gravidanza, nascita e crescita; (4)
  successione, reggenza, lutto regale e incoronazione; (5) pretendenti di altre casate con la dote; (6) la finestra
  della casata.
- **Stato**: fatte le fasi 1–6 (test in `tests/test_dynasty.gd`); gli epiteti con la fase 8 di 4.3. A 16 anni la maggiore età, nella cronaca; ai
  maschi, forse, la barba. La casata nuova ha uno stemma a caso (poi: l'editor dello stemma in partita); lo stile di
  regno all'incoronazione quando ci sarà.

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
- **Oro**: monete, in magazzino (mucchi da 100). All'inizio 60, a terra nella radura (si spendono quando sono in un magazzino); poi si trovano nelle rovine (vedi 4.4.4). Servono a pagare
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
- **Costruire**: il tasto Build apre le categorie: Strutture (muri, pavimenti, porte, strade, palizzata, intonaco) e
  cinque categorie di mobili, perché una barra sola con tutte le ricerche non stava nello schermo (decise il
  2026-11-19): Casa (letti, armadio, tavolo, sedia, tappeto, abat-jour), Fuoco e calore (fuoco da campo, focolare, stufa
  a olle, pelli alle pareti, portiera, arazzo), Mestieri e provviste (fornace, incudine, banchi, filatoio, scrittoio,
  libreria, fossa del ghiaccio, cumulo del compost), Corte e difesa (trono, bacheca, fantoccio, torre di guardia),
  Decorazioni (le decorazioni e i cimeli). Un mobile nuovo va nella sua categoria, che resta sotto i 1280 pixel.
- **Stanze**: zona chiusa da muri con una porta; il cartello sul muro accanto alla porta apre nome e tipo.
  Tipi: magazzino; camera (1 letto); dormitorio (2 letti); cucina (fuoco da campo o focolare, poi anche stufa); forgia (fornace e incudine);
  laboratorio (banco da lavoro); falegnameria (banco del falegname); ghiacciaia (fossa del ghiaccio, muri di pietra:
  vedi 4.4.5).
  Un tipo si sceglie solo se ci sono i mobili (gli altri non compaiono); tolti, la stanza torna senza tipo.
  Ogni tipo ha una categoria:
  - **lavoro** (cucina, forgia, laboratorio, falegnameria): niente proprietari, ma le si assegnano dei lavoratori (per ora senza effetto; poi
    solo loro ne faranno i lavori). L'ingresso resta libero.
  - **residenza** (camera, dormitorio): può avere uno o più proprietari tra i coloni; un colono entra (anche solo per
    passarci) solo nelle residenze sue o senza proprietari.
  - **servizio** (magazzino): stanze comuni con uno scopo preciso, né proprietari né lavoratori.
  Cambiando tipo (o tornando senza) proprietari e lavoratori che la nuova categoria non prevede si perdono.
  Una stanza **bandita** è vietata a tutti, anche ai proprietari.
- **Lenti**: evidenziano cose sulla mappa, una alla volta. Prima: la lente delle stanze, ogni stanza finita velata col
  colore del suo tipo, sotto il tipo i proprietari o i lavoratori (col mouse sopra, la loro scheda). Poi la lente del
  calore (vedi 4.4.5).
- **Comfort della stanza** (0–10): mobili per pezzo e pavimento, secondo il materiale (pietra ×1,5). A 5 nessun effetto;
  a 0 (anche fuori dalle stanze) le attività durano il 20% in più, a 10 il 20% in meno. Per ora vale per il sonno
  (8 ore a comfort 5) e per cucinare, dove cambia anche la probabilità di bruciare il pasto o farlo squisito.
  Sotto le 6 caselle a testa il comfort cala in proporzione.
- **Tetti**: ogni stanza finita ha il suo, da sé, sopra la stanza e i suoi muri; un pulsante (V) li toglie per guardare dentro.
  Chi passa dietro un edificio si vede da un buco nel tetto; chi è dentro resta coperto, tranne il colono scelto.
  Materiale, forma, degrado e comignoli: vedi 4.4.5.
- **Freddo e pioggia** tolgono comfort, anche sotto lo 0: −1 ogni 4 °C sotto i 12 °C; fuori, sotto la pioggia, −2.
  La temperatura fuori la danno le stagioni (vedi 4.5), ±5 °C tra mezzanotte e mezzogiorno, e il tempo: pioggia −3,
  nebbia −2, temporale −5, neve −2.
  Sotto un tetto la temperatura va a metà strada verso 15 °C e non piove; ogni fuoco da campo della stanza la alza di 8 °C;
  ogni punto di protezione addosso vale un grado. Da svegli, al freddo o sotto la pioggia, il comfort cala di un punto
  all'ora per ogni punto tolto; risale solo dormendo. Nelle stanze fredde anche lavorare, cucinare e studiare va più piano.
  Focolare e fornace, calore attraverso i muri, isolamento secondo i muri e la lente del calore: vedi 4.4.5.

### 4.4.1 Cibo e cucina
- **Freschezza**: ogni mucchio di cibo ha i giorni che gli restano (mescolando due mucchi, la media pesata).
  A terra fuori il cibo dura 3 giorni, in magazzino il doppio; poi marcisce e sparisce. Il suggerimento sul mucchio
  dice "Fresh / Stale / Almost rotten" e fra quanti giorni marcisce. Col freddo marcisce più piano: sotto i 15 °C in
  proporzione ai gradi, sotto lo zero per niente (gela, "frozen: it keeps"); un magazzino senza fuoco fa da dispensa. Stanze senza gente più
  fredde, caldo che fa marcire, cantine e ghiacciaia: vedi 4.4.5.
  Con un cumulo del compost il cibo marcito diventa marcio da portarci (vedi Concimi naturali, sotto).
- **Crudo**: si può mangiare, ma sazia poco e può intossicare (dal crudo appena preso a quello quasi marcio):

  | Crudo | Sazia | Dura (fuori / magazzino) | Intossica |
  |---|---|---|---|
  | Vegetali (raccolta) | 35 | 3 / 6 giorni | 5% → 40% |
  | Pesce (pesca) | 30 | 1,5 / 3 giorni | 10% → 50% |
  | Carne (caccia) | 40 | 2 / 4 giorni | 15% → 60% |
  | Rape (orto) | 35 | 10 / 20 giorni | 2% → 30% |
  | Cavoli (orto) | 35 | 14 / 28 giorni | 2% → 30% |

- **Pasti**: 2 crudi dello stesso mucchio (vegetali, pesce o carne) → 1 pasto, che sazia 100 e dà *ben nutrito*. Non intossica.
  Chi ha fame prende prima un pasto squisito, poi un pasto, il crudo solo se non ce ne sono (vegetali, pesce, carne).
  Se entro 20 caselle c'è una sedia libera accanto a un tavolo, lo porta lì e lo mangia seduto (*mangiato al tavolo*).
- **Cucinare** (abilità cucinare): in una stanza di tipo cucina, accanto al fuoco da campo. Il cuoco prende 2 crudi dal
  mucchio più vicino, cucina, il pasto cade ai suoi piedi e lo porta in magazzino. Si cucina finché in giro
  (a terra, in magazzino, in mano) ci sono meno pasti di quanti ne chiede il menu del fuoco (vedi 4.4.2; all'inizio
  2 a colono, 8); nella finestra Jobs: "Cook meals: N". Poi: altre ricette (stufato, conserve).
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
- Ordine dei lavori: vedi la tabella delle priorità (4.1).
- Poi: animali che si difendono; stufato (vegetali + carne o pesce), conserve per l'inverno.
- **Raccogliere** (tasto "Harvest", cestino, dopo "Uproot"): si segnano i cespugli; i coloni ne raccolgono le bacche ogni
  volta che maturano (5 ogni 2 giorni), finché il segno resta, e le portano in magazzino. Segnare "Uproot" toglie il segno e viceversa.
  - **Lino**: ciuffi coi fiori azzurri sparsi nei prati (circa 1 casella su 100). Si segna e si raccoglie come i cespugli
    (abilità raccogliere): in fiore dà 5 lino, poi rifiorisce in 2 giorni. Non si mangia: si fila in corde d'arco.
  Un colono mangia circa 2 vegetali al giorno se cucinati, 2,6 crudi; un cespuglio ne dà 2,5: 1–2 cespugli a testa.
- **Coltivare** (ricerca Orto, tasto "Garden", P): si trascina sul prato libero, fuori dalle stanze, e le caselle
  diventano orto (terra lavorata); erbacce e cespugli si estirpano prima, sull'orto non si costruisce, Distruggi lo
  toglie. Rape e cavoli a file alterne. Tempi veri: il contadino (abilità raccogliere) semina una casella in 4 s a
  livello 5; le rape maturano in 60 giorni (30 a casella), i cavoli in 90 (45 a casella); cadono ai suoi piedi, le porta
  in magazzino e risemina. +1 punto esperienza per semina e per raccolto. Rape e cavoli sono cibi a sé: si mangiano e si
  cucinano come il crudo, ma durano 10 e 14 giorni fuori (il doppio in magazzino, il triplo in dispensa, al gelo per
  sempre), così il raccolto arriva fino all'inverno. Si semina quando la terra è tiepida (6 °C di media del giorno, dal
  tardo Disgelo) e solo se il raccolto matura prima dell'inverno (i cavoli non negli ultimi 90 giorni, le rape negli
  ultimi 60); il primo giorno d'inverno il gelo si prende quello che è rimasto nei campi (lo dice la cronaca).
  Una casella dà mezzo pasto crudo al giorno: 4 caselle a testa, fuori dall'inverno; l'inverno si passa con le scorte.
  Numeri da tarare.
- **Fertilità e rotazione dei campi** (decise il 2026-11-18; numeri da tarare):
  - **Fertilità**, per casella, 0–100, nascosta. Viene dalla mappa: tra 30 e 80, +10 entro 3 caselle dall'acqua, −15
    accanto alla roccia; abbattere un albero lascia l'humus, +15 a quella casella. La resa del raccolto è quella base
    (30 rape, 45 cavoli) per 0,4 + fertilità/100: a 60 la base, a 100 +40%, a 20 −40%. Ogni raccolto la consuma
    secondo la coltura; a Capodanno ogni casella d'orto ne riprende 5 (il riposo dell'inverno), 25 in più se l'anno
    prima non ha dato raccolti (maggese).

    | Coltura | Matura in | A casella | Fertilità a raccolto | Dura (fuori) |
    |---|---|---|---|---|
    | Rape | 60 giorni | 30 | −8 | 10 giorni |
    | Cavoli | 90 giorni | 45 | −15 | 14 giorni |
    | Fave (secche) | 100 giorni | 20 | +10 | 60 giorni: il cibo dell'inverno; saziano 40 |
    | Maggese | — | — | +25 l'anno dopo | — |
    | Sovescio (fave interrate) | 60 giorni | — | +20 | — |

  - **Campi**: le caselle d'orto che si toccano fanno un campo ("Campo 1", 2… dall'alto in basso), col suo cartello
    (un paletto nella casella più in alto a sinistra). Cliccandolo: il nome, le caselle, la sua timeline di quest'anno,
    le colture dell'anno prossimo, l'ultimo raccolto, la terra (se la si conosce) e "Pianifica i campi…".
  - **Pianificazione, a gantt** (decisa il 2026-11-18): una finestra con l'anno in orizzontale (stagioni e mesi in
    testa, la linea di oggi) e una riga per campo. Il piano di un campo ha un ciclo da 1 a 4 anni; per ogni anno le
    colture una dopo l'altra, ognuna dal suo giorno: sono barre lunghe quanto crescono (rape 60 giorni, cavoli 90, fave
    100), colorate per coltura. A righe la terra fredda prima del giorno 22, in azzurro l'inverno (dal giorno 274): circa
    250 giorni utili, per esempio rape + rape + cavoli. Clic su uno spazio vuoto: una coltura, attaccata a quella prima;
    quelle che non finirebbero prima dell'inverno o della coltura dopo sono spente, col perché. Clic su una coltura:
    cambiarla o toglierla. Clic sul nome: rotazioni pronte (rape ogni anno; la classica: cavoli, cavoli, rape → rape ×4 →
    fave, fave → maggese) e il ciclo; gli anni nuovi del ciclo sono a maggese, da riempire. ◀ ▶ mostrano fino a 3 anni
    dopo. A Capodanno ogni campo passa all'anno dopo del suo ciclo. Il contadino semina una coltura dal suo giorno, appena
    la casella è libera e la terra è tiepida; una coltura che non farebbe più in tempo a maturare si salta. Quello che è
    già seminato finisce di crescere; le caselle nuove accanto a un campo ne prendono il piano. Senza piano, rape quante
    ne stanno (4).
  - **Terra stanca**: la stessa coltura due volte di fila sulla stessa casella (anche nello stesso anno) rende −25%,
    dalla terza volta −50%.
  - **Indizi senza ricerche**: su terra povera le piante sono smorte (più è povera, più sono gialle); il cartello dice
    l'ultimo raccolto a casella; alla Festa del focolare (fine autunno) la cronaca fa il bilancio dell'anno per
    coltura, a casella, con quello dell'anno prima.
  - **Il contadino impara**: chi ha almeno 5 in Raccogliere riconosce la terra delle caselle che lavora (seminare o
    raccogliere): il cartello dice "secondo i contadini" povera, media o ricca, anche senza ricerche.
  - **Ricerche** (ramo Terra, dopo l'Orto): Saggio del terreno (I, 60): la lente della terra (tasto O) in tre fasce,
    povera sotto 40, media, ricca da 70; il cartello dice la fascia del campo. Almanacco agrario (II, 250, dopo il
    Saggio): cinque fasce e se la terra sale o scende rispetto a un anno prima. Catasto (III, 450, dopo l'Almanacco):
    i numeri esatti, sulla lente e sul cartello, e la previsione del prossimo raccolto.
  - **Ordine di lavoro**: (1) fertilità, resa, campi col cartello, indizi, bilancio; (2) fave, piano di rotazione,
    maggese, terra stanca; (3) le tre ricerche, la lente, il contadino che impara.
  - **Concimi naturali** (decisi il 2026-11-19): la ricerca Concimazione (Terra I, 80, dopo l'Orto) dà il cumulo del
    compost (mobile 1×1, 6 legna). Se ce n'è uno, il cibo che marcisce e le erbacce estirpate diventano **marcio**, che
    i trasportatori portano al cumulo (nel cumulo solo lui, anche dai magazzini); lasciato fuori sparisce nella terra
    in 5 giorni. Nel cumulo, in 10 giorni ogni 4 marci fanno un **compost** (+15 di fertilità). La carbonaia lascia
    una **cenere** a infornata (+5). Il contadino (lavoro Concimare, nella colonna Coltivare) da 15 giorni prima della
    semina di una casella ci sparge un concime, prima il compost poi la cenere: una volta per semina, nei campi che lo
    vogliono (spunta "Concimare prima della semina" sul cartello). Il **sovescio** è una coltura della pianificazione:
    fave che non si raccolgono, si interrano in fiore dopo 60 giorni, +20 di fertilità e niente cibo (fuori dal
    bilancio dell'anno).
  - **Stato**: fatte le fasi 1–3, la pianificazione a gantt e i concimi (test in `tests/test_food.gd`; la cenere in
    `tests/test_gear.gd`).
  - Poi: letame con la stalla, quando ci saranno gli animali da allevare.

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
  All'inizio: pasti 8 (2 a testa), lingotti 10, corde d'arco 2, equipaggiamento 0.
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
- **Chi resta**: un avventuriero contento dopo 3 spedizioni chiede di **restare come colono** (vedi 4.2.1).
- **Coloni in spedizione** (ricerca Compagnia della corona, 4.7.3): sulla bacheca, sotto chi aspetta alla locanda, i
  coloni che possono partire (adulti, non il sovrano né il reggente, non a terra né incinte); si spuntano come gli
  avventurieri, ma nel gruppo ci vuole almeno un avventuriero. Non hanno paga né quota. Nella rovina combattono con la
  loro abilità migliore tra armi da mischia e a distanza (chi era avventuriero, con la sua classe) e prendono la parte
  media dei colpi; +1 esperienza nell'arma per ogni stanza coi mostri. Fuori dalla mappa non lavorano. Chi muore nella
  rovina, la colonia lo sa al ritorno (o quando la spedizione si dà per persa): lutto e −5 autorità, come per ogni
  colono morto. Al ritorno escono dal bordo e tornano al lavoro; il bottino lo porta un avventuriero alla locanda.
- Poi: vene d'oro e commercio; una rovina sulla mappa da esplorare davvero.
- **Ordine di lavoro**: (1) locanda e bacheca, oro, un avventuriero alla volta, solo la torre, bottino in risorse che
  esistono già; (2) classi, talenti, gruppi, provviste, diario; (3) altre rovine, mappe, cimeli, effetto dello splendore;
  (4) il resto.
- **Stato**: fatte le fasi 1, 2 e 3; della 4 chi resta (4.2.1) e i coloni in spedizione (Compagnia della corona).
  Simulazioni (500 spedizioni per caso, provviste piene, rovina intatta): alla torre non muore nessuno, ma mandarci
  gente di livello alto costa più di quello che rende; nelle rovine profonde chi va da solo non torna una volta su
  cinque, un gruppo di livello 1 al forte perde in media un uomo ogni 9 spedizioni e torna presto; un gruppo del livello
  giusto ci guadagna (cripta, tre di livello 3: 147 monete a casa per 75 di paghe; forte, quattro di livello 5: 268
  per 140); coi talenti a caso i numeri restano questi, più o meno. Manca il resto di "Poi": vene d'oro e commercio,
  una rovina sulla mappa.

### 4.4.5 Tetti, calore e conservazione
Deciso il 2026-11-18. I tetti cambiano aspetto col materiale e si consumano; i fuochi scaldano anche attraverso i muri
di legno, la pietra isola; il caldo e il freddo decidono quanto dura il cibo, fino alla ghiacciaia. Numeri da tarare.

- **Materiale del tetto** ✓: segue i muri dell'edificio. Muri di legno → scandole; muri di pietra → coppi, il segno della
  Muratura. Muri misti: decide la maggioranza dei muri dell'edificio (le porte contano come legno). Un tetto è tutto
  dello stesso materiale. Tetti e facciate non sono sprite: roofs.gd li calcola dal rettangolo, con la proiezione del
  gioco (un punto alto z sta z pixel più su), coi coppi di toni diversi e qualche ciuffo di muschio.
- **Forma** ✓: un tetto per stanza, sopra la stanza e i suoi muri; una stanza a L si spezza in rettangoli, ognuno col suo
  tetto a due falde. Un muro in comune sta sotto i tetti di tutte e due le stanze: si vede quello davanti. Una leggera
  differenza di tinta tra un tetto e l'altro. Il colmo corre lungo il lato lungo: negli edifici più larghi che profondi da
  est a ovest, la falda dietro appena visibile, e un timpano sopra la porta se l'edificio è largo almeno 7 caselle e
  profondo 4; negli altri da nord a sud, col timpano in facciata. Il tetto ha un'altezza vera: sale sopra la stanza
  e copre fino a tre caselle dietro.
- **Facciata** ✓: coi tetti il muro in fondo è alto 24 pixel invece di 10 (sale sulla casella sopra, che è sotto il
  tetto): graticcio di travi e intonaco su uno zoccolo di pietra sul legno, pietra a corsi sulla pietra, una finestra
  ogni due caselle, porte ad arco; i timpani a graticcio coi puntoni a V, o di pietra. Coi tetti tolti (V) i muri
  restano gli sprite di sempre.
- **Chi sta dietro** ✓: attorno a coloni, avventurieri e animali che un tetto copre da davanti, un buco rotondo nel tetto
  col bordo a scacchi; chi è dentro una stanza resta coperto, tranne il colono scelto (con la scheda aperta). Gli
  edifici si disegnano in ordine di riga con alberi e coloni: chi passa davanti a una facciata la copre.
- **Neve e pioggia sui tetti**: la neve si scioglie secondo la temperatura della stanza sotto, prima sui tetti delle
  stanze calde e attorno ai comignoli: si vede a colpo d'occhio dove si sta al caldo. Sotto la pioggia il tetto è più
  scuro e gocciola dalla gronda; col gelo, ghiaccioli.
- **Degrado, per casella**: ogni casella di tetto ha il suo stato, in tre stadi: integra; tegole (o scandole) smosse e
  muschio; buco con le travi a vista. Lo consumano il tempo (poco), i temporali (molto: strappano il tetto in caselle a
  caso) e la neve pesante sui tetti larghi e freddi; le scandole si consumano il doppio dei coppi. I tetti vecchi
  prendono muschio e licheni anche se integri. I danni arrivano a ondate col meteo, non come manutenzione continua:
  senza temporali un tetto regge un anno.
  Un buco è una casella non più coperta: ci piove e nevica dentro (malus della pioggia, pozzanghere), ha la temperatura
  di fuori e il cibo che ci sta sotto marcisce come fuori.
- **Riparare** (abilità costruzione): il lavoro si mette in coda da sé per le caselle danneggiate, come un progetto;
  1 legna (scandole) o 1 pietra (coppi) a casella. Nella cronaca: "Temporale: il tetto della Cucina ha perso delle
  tegole".
- **Fuochi e calore**: ogni fuoco scalda la sua stanza. Focolare e fornace, girati contro un muro di legno, passano
  metà del calore alla stanza dall'altra parte, se tra le due c'è un muro solo (due file di muri non lo passano); la
  pietra e la roccia non lo fanno passare. Conta il muro dietro il fuoco, casella per casella: al massimo due stanze per
  fuoco. Il popup della stanza dice da dove viene il calore ("+6 °C dal focolare della Cucina").

  | Fuoco | Nella sua stanza | Dietro un muro di legno | Rischio d'incendio |
  |---|---|---|---|
  | Fuoco da campo | +8 °C (come oggi) | — (il calore sale dal foro nel tetto) | sotto un tetto di scandole |
  | Focolare | +12 °C | +6 °C | no |
  | Fornace | +15 °C | +7,5 °C | no |

- **Focolare** (ricerca Muratura): 1×1, di pietra, addossato a un muro (girato verso il muro). Fa quello che fa il fuoco
  da campo: la cucina chiede l'uno o l'altro; ci si cucina e ci si fanno gallette e affumicati; nel tempo libero ci si
  sta attorno, il ritrovo al chiuso d'inverno. Comfort 0,5 come il fuoco da campo.
- **Fuoco da campo**: resta com'è, senza malus per il fumo. In cambio carne e pesce affumicati ci vengono il 25% più
  svelti che al focolare: lì il fumo serve.
- **Comignoli**: sul tetto, sopra il muro dietro il focolare (a cavallo dei due tetti se il muro è in comune). La
  fornace ha il suo, incorporato: sopra il muro se ci è addossata, se no sopra di lei. Il fuoco da campo sotto un tetto
  ha un foro (sfiatatoio). Il fumo esce da lì e non più dal punto del fuoco, anche dalla fornace, che oggi non fuma; più
  fitto quando si cucina o si forgia; chiaro in cucina, scuro alla forgia, denso all'affumicatura. Dall'alto si vede
  quali stanze lavorano. Coi tetti tolti (V) la canna si vede sul focolare stesso.
- **Isolamento**: sotto un tetto la temperatura va verso quella della stanza (15 °C) di quanto isolano i muri: la media
  dei muri che la chiudono, legno e porte 50% (come oggi), pietra 70%, roccia 85%; più i pezzi che isolano, fino al 90%.
  Isola nei due sensi: d'inverno tiene il caldo, d'estate il fresco.

  | Pezzo | Ricerca | Costo | Effetto |
  |---|---|---|---|
  | Pelli alle pareti | Caccia | 2 pelli, 1×1 contro un muro | +5% ciascuna, fino a 3 per stanza |
  | Portiera (tenda di pelle sulla porta) | Caccia | 2 pelli | +10%: la porta è il punto debole |
  | Intonaco | Muratura | 1 pietra (calce) a casella di muro | i muri di legno valgono 60%; diventano bianchi |
  | Arazzo | Telaio | 4 lino (la tela verrà col resto del Telaio), 1×1 contro un muro | +5% e 2 di splendore |
  | Stufa a olle | Stufa a olle | pietra, 1×1 contro un muro | +10 °C alla sua stanza e a quella dietro, anche attraverso la pietra, come nelle stube alpine |
  | Letto a baldacchino (c'è già) | Arredo fine ✓ | — | le tende: chi ci dorme ha 4 °C in più |

  Le pelli servono già per armature, cappucci, tappeti e pergamena: isolare le contende, e la caccia vale di più.
- **Stanze senza gente**: magazzino e dispensa vanno verso 5 °C invece che 15. Oggi d'inverno un magazzino è più caldo
  di fuori e il cibo ci marcisce prima; con la pietra che isola, una dispensa di pietra sarebbe ancora peggio. Così la
  pietra le tiene fresche d'estate e fredde d'inverno.
  Da tenere d'occhio: quanto dura il cibo in un magazzino e in una dispensa, di legno e di pietra, d'estate e d'inverno,
  rispetto a oggi. Se conservare diventa troppo facile, o legno e pietra non fanno differenza, si cambiano i 5 °C.
- **Il caldo fa marcire**: sopra i 15 °C il cibo marcisce più in fretta, il doppio a 30 °C. L'estate diventa la
  stagione difficile per il cibo, come l'inverno per il freddo; per questo rinfrescare serve.
- **Niente malus per il caldo**: il caldo non toglie comfort, la stagione ostile resta l'inverno. Rinfrescare serve al
  cibo, non ai coloni; la forgia d'estate resta una stanza come le altre.
- **Rinfrescare**: come nel Medioevo, muri spessi di pietra (sopra); stanze chiuse dalla roccia della mappa, le cantine
  (la roccia isola all'85%); la fontana in una stanza toglie 3 °C quando fuori fa più di 20 °C; l'intonaco bianco.
  Poi: l'ombra degli alberi accanto ai muri, le imposte con le finestre (Vetreria).
- **Ghiacciaia** (ricerca Ghiacciaia): come le neviere e le ghiacciaie di pietra, in parte interrate, riempite d'inverno
  e buone fino all'estate. Stanza di servizio come la dispensa, solo per il cibo; muri solo di pietra o roccia, nessun
  fuoco. Dentro la fossa del ghiaccio (2×2: il ghiaccio sotto la paglia).
  **Tagliare il ghiaccio**: ordine sull'acqua gelata, d'inverno, segnato come la pesca; i blocchi di ghiaccio (nuovo
  materiale) si portano nella fossa. Finché nella fossa c'è ghiaccio la stanza va verso 0 °C invece che 15, di quanto
  isolano i muri: a metà estate (23 °C fuori) circa 7 °C coi muri di pietra, 3,5 °C nella roccia; d'inverno sotto lo
  zero. Il cibo ci dura come in dispensa, e in più per il freddo (vedi 4.4.1). Il ghiaccio si scioglie ogni giorno in
  proporzione al caldo che entra: i gradi sopra lo zero fuori × (1 − isolamento); una casella di tetto bucata lo
  scioglie prima. D'inverno si taglia il ghiaccio, d'estate il cibo si conserva: l'inverno ha un lavoro che rende.
  Poi: spalare la neve per riempire la fossa; il sorbetto (ghiaccio e miele, con Apicoltura) per il Banchetto reale.
- **Lente del calore**: la seconda lente, accanto a quella delle stanze, col suo pulsante e tasto (liberi N, O, Y).
  Ogni casella coperta colorata per temperatura, a scalini come il comfort: sopra i 12 °C una tinta calda, sotto ma
  senza malus una gialla, poi più fredda per ogni punto di comfort tolto (−1, −2, −3); sotto lo zero una tinta di
  ghiaccio (lì il cibo non marcisce). I buchi nei tetti si
  vedono da soli, come macchie fredde. Al centro della stanza gradi e malus ("9 °C · −1"); sopra ogni fuoco il suo
  calore (+8, +12, +15); dal focolare e dalla fornace una freccia attraverso il muro col calore che passa, o una ✕ se il
  muro è di pietra. Fuori nessuna tinta, solo i gradi in un angolo. Col mouse sopra una stanza, il conto: fuori,
  isolamento dei muri, fuochi, calore dai muri, totale. Piazzando un fuoco o un pezzo che isola la lente si accende da
  sola, con l'anteprima della freccia.
- **Incendio** (non è del narratore, vedi 4.6): parte da un fuoco da campo sotto un tetto di scandole (ogni giorno una
  piccola probabilità) o da un fulmine nel temporale su un tetto di scandole. Si allarga alle caselle di scandole
  accanto, anche di un altro edificio; i coppi non bruciano. I coloni fanno la catena dei secchi dall'acqua più vicina;
  le caselle bruciate restano buchi da riparare.
- **Sopra le falde** ✓: neve sciolta dal calore, tetto bagnato, licheni, tegole smosse, buchi, fuoco e comignoli si
  stendono sulle falde alla loro altezza; gocce e ghiaccioli pendono dal bordo davanti.
- Poi: il buco nel tetto anche sotto il mouse; tra due edifici accostati un vero compluvio (oggi il tetto più in basso
  copre l'altro); di notte la luce delle stanze dalle finestre
  e dagli abbaini (Vetreria); tetti di rango per sala del trono e palazzo (torrette, stendardo coi colori della
  casata); banderuola che segna il vento; nidi di cicogna sui comignoli in primavera; un terzo tipo di muro
  (incannucciato) col tetto di paglia; la pioggia dai buchi che rovina i libri dello studio.
- **Ordine di lavoro** (4.4.5): (1) focolare, comignoli e fumo, fornace che scalda, calore attraverso i muri di legno,
  pietra e roccia che isolano, stanze senza gente più fredde, affumicati più svelti al fuoco da campo; (2) lente del
  calore; (3) tetti: uno per edificio, colmo sul lato lungo, scandole e coppi dai muri, neve che si scioglie sulle
  stanze calde, tetto bagnato; (4) degrado per casella e Riparare; (5) isolamento: pelli alle pareti, portiera, intonaco,
  letto a baldacchino che scalda, poi arazzo e stufa a olle con le loro ricerche; (6) conservazione: caldo che fa
  marcire, cantine nella roccia, fontana che rinfresca, ghiacciaia; (7) incendio.
- **Stato**: fatte le fasi 1–7 (test in `tests/test_heat.gd`), coi tetti con l'altezza e la facciata di roofs.gd. Il
  tasto della lente del calore è N, quello del ghiaccio Y. Fuori la lente non colora niente: i gradi di fuori sono già
  nella barra in alto (previsioni).

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

### 4.5.1 Salvataggio
- Solo automatico, solo locale (il cloud dopo l'MVP, vedi docs/TECH.md): una colonia è una storia sola, niente
  salvataggi a mano. Si salva appena fondata la colonia, a ogni alba (le 6:00), tornando al menu principale, uscendo e
  chiudendo la finestra. In alto compare "Salvato".
- Ogni colonia ha la sua cartella con gli ultimi 3 salvataggi a rotazione: se il più recente è rovinato si usa quello
  prima (una rete di sicurezza, non un modo di tornare indietro).
- Dal titolo: **Continua** (la colonia giocata per ultima) e **Colonie** (l'elenco, dalla più recente: reame, data,
  sovrano, coloni, quando è stata salvata; si possono eliminare, con tutti i loro salvataggi). Lo stesso elenco da
  Carica partita nelle opzioni, salvata prima la colonia di adesso.
- Una colonia caricata riparte in pausa, esattamente com'era: coloni a metà lavoro, spedizioni in viaggio, meteo.
- Una colonia caduta non si salva: Continua la riporta all'ultima alba.

### 4.6 Eventi casuali: il narratore
Deciso il 2026-11-19. Numeri da tarare. Un **narratore** solo (niente carattere da scegliere nella nuova partita).
- **Un dado al giorno**: a mezzanotte il narratore guarda gli eventi possibili quel giorno e ne sceglie al più uno. Ogni
  evento ha una fetta grande quanto è frequente: "in media ogni 10 giorni" è una fetta di 1/10. Un solo tiro per tutte
  le fette: ognuno tiene il suo ritmo, ma due eventi non vengono mai lo stesso giorno (se le fette insieme passano
  l'intero, si stringono in proporzione). L'evento scelto avviene alla sua ora; se a quell'ora non si può più (la locanda
  abbattuta), quel giorno non succede niente.
- **Ogni evento è una riga di una tabella** (`narrator.gd`, come il meteo in `atmosphere.gd`): tipo (minaccia, visita,
  fortuna, sfortuna), da che giorno, le condizioni (stagione, una stanza, una legge), ogni quanti giorni in media (anche
  secondo lo stato della colonia), la pausa minima tra due uguali, l'ora, l'effetto (una funzione) e i testi (tradotti
  nel `.po`, come tutti gli altri).
- **Il respiro**: dopo una minaccia o una sfortuna, 3 giorni senza minacce né sfortune (la **tregua**); niente minacce
  mentre un colono è a terra o i lupi sono ancora sulla mappa. Quando la colonia è in difficoltà (il cibo in magazzino
  basta per meno di 3 giorni, o la felicità media è sotto 40) le fortune hanno la fetta doppia.
- Ogni evento lo racconta la cronaca, e il calendario lo segna nel suo giorno.
- **Restano fuori**: l'incendio (4.4.5), che viene da dove si mette il fuoco e dai temporali: si può evitare, non lo
  decide il narratore; i pretendenti (4.3.3), il ritmo della dinastia.
- **Gli eventi**:

| Evento | Tipo | Quando | In media ogni | Cosa fa |
|---|---|---|---|---|
| Viandanti | visita | dal giorno 10; uno alla volta; non con Porte chiuse | 30 giorni ÷ (1 + splendore / 20), ×2 ogni 4 coloni sopra 8; la metà con Porte aperte | come in 4.2.1; pausa 5 giorni dalla risposta (o da quando se ne sono andati) |
| Erudito errante | visita | con una locanda | 10 giorni, pausa 5 | un giorno alla locanda, vende 1–2 libri (4.7.2) |
| Branco di lupi | minaccia | dal giorno 5, di notte | 4 giorni | 2–3 lupi, uno in più ogni 5 coloni |
| Ondata di freddo | minaccia | la media del giorno sotto 8 °C | 33 giorni | la decide il meteo 2 giorni e mezzo prima, perché le previsioni la vedano (4.5); rispetta la tregua e la fa partire |
| Raccolto abbondante | fortuna | estate e autunno, con l'orto seminato | 40 giorni, pausa 30 | per 10 giorni i campi raccolti rendono il 50% in più |
| Branco di cervi | fortuna | non d'inverno | 25 giorni | 4–6 cervi arrivano dal bordo della mappa; dopo 2 giorni quelli rimasti se ne vanno |
| Ispirazione | fortuna | un colono adulto contento (felicità almeno 60) | 15 giorni | lui, per un giorno: **Ispirato** (condizione), lavora il 25% più in fretta, +5 felicità |
| Dono del pellegrino | fortuna | con una sala del trono | 30 giorni | un pellegrino arriva dal bordo, va al trono, lascia 20–40 monete e se ne va; +5 autorità |
| Topi nel magazzino | sfortuna | almeno 20 di cibo crudo nei magazzini | 25 giorni, pausa 15 | un quarto del cibo crudo del magazzino che ne ha di più va perso |
| Ladro di notte | sfortuna | dal giorno 15, almeno 20 monete in magazzino; di notte | 30 giorni | col Turno di guardia e chi fa la guardia sveglio lo prendono: +5 autorità; se no sparisce un quarto delle monete (al più 50) |
| Febbre | sfortuna | dal giorno 10; d'inverno ogni 10 giorni | 20 giorni | un colono a caso: **Febbre** (condizione) per 3 giorni, lavora il 50% più lento, si stanca il doppio, −10 felicità; non si attacca. Poi la cura il medico (Medicina, 4.7.3) |

- **Ordine di lavoro**: (1) il narratore e la tabella, con dentro viandanti ed erudito errante (gli stessi ritmi di
  oggi), la cronaca e il salvataggio; (2) le minacce: il branco di lupi nel narratore, la tregua, il branco che cresce
  coi coloni, l'ondata di freddo che chiede al narratore; (3) le fortune: raccolto abbondante, branco di cervi,
  ispirazione, dono del pellegrino; (4) le sfortune: topi nel magazzino, ladro di notte, febbre.

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
  Nel gioco (per ora un evento, non una figura alla locanda): ogni 10 giorni ±2, se c'è una locanda; vende quaderni e,
  una volta su quattro, un tomo (mai codici); compra un libro a metà prezzo (il codice vale 300, ne paga 150). Si
  tratta nella finestra Knowledge, sotto lo studio, e paga solo in monete.
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

  L'albero intero (50 ricerche) vuole circa 15.800 punti: con tre studiosi bravi 100 giorni. Si sceglie, non si finisce.
- **Dall'inizio**, senza ricerca: muro e pavimento di legno, porta, sentiero, letto, tavolo, sedia, fuoco da campo,
  stendardo, scrittoio, trono; il pasto; tagliare, scavare, estirpare, raccogliere, pescare, costruire, distruggere, e
  cacciare con un arco; stanze magazzino, camera, dormitorio, cucina, studio, sala del trono. Tutto il resto, anche
  quello che c'era già (in corsivo qui sotto), sta in un nodo dell'albero. Materie prime, cibo crudo, monete e cimeli
  non cambiano.
- **L'albero**: sei rami, ognuno con una linea maestra dal livello I al IV e due linee corte. ✓ = c'è nel gioco.

  | Ramo | Ricerca | Liv. | Studio | Richiede | Sblocca |
  |---|---|---|---|---|---|
  | Terra | Orto ✓ | I | 80 | — | zona orto e lavoro Coltivare: rape in 60 giorni e cavoli in 90, niente d'inverno |
  | | Forno di pietra | II | 300 | Orto | forno 2x1: pane (2 vegetali → 3, sazia 60, dura 8 giorni), stufato |
  | | Saggio del terreno ✓ | I | 60 | Orto | la lente della terra (O) in tre fasce; la fascia sul cartello del campo |
  | | Almanacco agrario ✓ | II | 250 | Saggio del terreno | cinque fasce; se un campo sale o scende rispetto a un anno prima |
  | | Catasto ✓ | III | 450 | Almanacco agrario | i numeri della terra e il prossimo raccolto di ogni campo |
  | | Concimazione ✓ | I | 80 | Orto | cumulo del compost, marcio e cenere, lavoro Concimare, il sovescio |
  | | Apicoltura | III | 450 | Forno di pietra | arnia accanto alle aiuole: miele (non marcisce), cera (candele: si studia di notte) |
  | | Banchetto reale | IV | 1000 | Apicoltura | il banchetto al forno: +15 felicità per 3 giorni, +20 autorità |
  | | Caccia ✓ | I | 50 | — | *filatoio, corda d'arco, banco del falegname, falegnameria, arco, pelli alle pareti, portiera* (vedi 4.4.5) |
  | | Affumicatoio ✓ | II | 200 | Caccia | al fuoco: carne e pesce affumicati durano quattro volte tanto (scorta 0 dal menu); si mangiano e si cucinano come il crudo |
  | | Dispensa fredda ✓ | I | 100 | — | stanza dispensa, solo per il cibo, che ci va per primo: dura il triplo che fuori (in magazzino il doppio) |
  | | Ghiacciaia ✓ | II | 250 | Dispensa fredda | *ghiacciaia* (muri di pietra o roccia), *fossa del ghiaccio*; Tagliare il ghiaccio d'inverno: col ghiaccio la stanza va verso 0 °C (vedi 4.4.5) |
  | Fuoco | Forgia ✓ | I | 60 | — | *fornace, incudine, forgia, lingotto, piccone, ascia, falcetto* |
  | | Acciaio ✓ | II | 300 | Forgia | acciaio (2 lingotti + 2 carbone, alla fornace): attrezzi e spade si fanno d'acciaio; attrezzi −40% tempo, spada danno 20 (anche quelli di prima, ritemprati) |
  | | Vetreria | III | 500 | Acciaio | vetro: finestre (+1 comfort), occhiali (studiare e cucire −20%) |
  | | Altoforno | IV | 1100 | Vetreria | lingotti e acciaio tre alla volta, con metà carbone |
  | | Sartoria ✓ | I | 50 | — | *banco da lavoro, laboratorio, armatura e cappuccio di cuoio* |
  | | Telaio ✓ | II | 200 | Sartoria | *arazzo* (isola la stanza, splendore: vedi 4.4.5); poi la tela: mantello imbottito (freddo), bende |
  | | Carbonaia ✓ | I | 80 | — | alla fornace 5 legna → 2 carbone (scorta 5 dal menu): il carbone non solo dalle vene |
  | | Stufa a olle ✓ | II | 300 | Carbonaia, Muratura | *stufa a olle* contro un muro: +10 °C alla sua stanza e a quella dietro, anche attraverso la pietra (vedi 4.4.5) |
  | Pietra | Muratura ✓ | I | 60 | — | *muri e pavimenti di pietra, focolare col comignolo, intonaco* (vedi 4.4.5) |
  | | Arredo fine ✓ | II | 250 | Muratura | letto a baldacchino (un letto, comfort 2), tappeto di pelli, armadio (comfort 1): la camera signorile del sovrano |
  | | Statuaria ✓ | III | 500 | Arredo fine | *statua del re*; poi i memoriali dei caduti (lutto un giorno in meno) |
  | | Palazzo ✓ | IV | 1200 | Statuaria | la sala del trono diventa palazzo: udienza +50%, +10 splendore (se ce n'è una) |
  | | Decorazioni ✓ | I | 40 | — | *aiuola, fioriera, panca* |
  | | Fontana ✓ | II | 250 | Decorazioni | *fontana* |
  | | Strada lastricata ✓ | I | 60 | — | lastre di pietra (2 a casella): si cammina il 25% più svelti, e i coloni le scelgono |
  | | Ponte | II | 200 | Strada lastricata | si attraversa l'acqua alta, si pesca dal ponte |
  | Ferro | Palizzata ✓ | I | 80 | — | palizzata e cancello: i lupi non passano; un recinto non è una stanza |
  | | Torre di guardia ✓ | II | 300 | Palizzata | lupi visti a 20 caselle da tutti (la campana); arciere in torre +2 caselle, +15% (lassù non ci sale ancora da sé) |
  | | Balestra | III | 500 | Torre di guardia | danno 22, un tiro ogni 4 s, +15% a segno |
  | | Armatura a piastre | IV | 1200 | Balestra, Cotta di maglia, Acciaio | protezione 7, +15% tempo |
  | | Armi di ferro ✓ | I | 80 | Forgia | *spada, elmo* |
  | | Cotta di maglia ✓ | II | 300 | Armi di ferro | *cotta di maglia* |
  | | Fantoccio ✓ | I | 60 | — | allenamento nel tempo libero: svago e +1 esperienza in mischia a colpo (uno ogni 2,5 s) |
  | | Scudo ✓ | II | 250 | Fantoccio | scudo tondo all'incudine (3 legna, 1 lingotto), nel suo slot: +3 protezione con spada o pugnale |
  | Strada | Locanda ✓ | I | 40 | — | *bacheca degli incarichi, locanda, ingaggi e spedizioni* |
  | | Locanda rinomata ✓ | II | 250 | Locanda | arrivi ogni giorno e mezzo, restano 5 giorni; avviso per la classe (sulla bacheca) |
  | | Compagnia della corona ✓ | III | 500 | Locanda rinomata | i coloni partono con gli avventurieri (vedi 4.4.4) |
  | | Mappa del Re Dimenticato | IV | 1000 | Compagnia, Cartografia | la Cittadella: pericolo 5, 10 stanze, 3 giorni |
  | | Provviste secche ✓ | I | 80 | — | gallette al fuoco (2 vegetali, scorta 0 dal menu): valgono 2 provviste, non marciscono, a casa non si mangiano |
  | | Armeria di prestito ✓ | II | 250 | Provviste secche | si presta l'equipaggiamento agli avventurieri: armatura, elmo e scudo migliori dei loro, dal magazzino; tornano con loro (morti, persi) |
  | | Cartografia ✓ | I | 80 | Locanda | sulla bacheca la prossima stanza di ogni rovina; viaggio −25% |
  | Sapere | Libreria ✓ | I | 60 | — | libreria: −10% tempo a pagina nella stanza, fino a 3 |
  | | Scriptorium ✓ | II | 250 | Libreria | pergamena (1 pelle → 2) e inchiostro (carbone e bacche → 2) al banco da lavoro: allo scrittoio si copiano i quaderni (3 pergamene, 1 inchiostro, 150 studio; quanti tenerne nella finestra Knowledge) |
  | | Astronomia ✓ | III | 500 | Scriptorium | le previsioni del tempo arrivano un giorno più in là (poi: sfera armillare, stagioni un giorno prima) |
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
- **Protesta** ✓: un colono sotto 20 di felicità che disapprova almeno due leggi molla il lavoro per 2 ore e va a
  lamentarsi nella sala del trono (senza, lì attorno); −5 autorità; una volta al giorno al più, il sovrano no. Con
  Pene severe finisce alla gogna; con Clemenza il sovrano lo ascolta (vedi 4.7.7).

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
| | Taglia ✓ | baronia | 100 | Tasse, dopo Decima | un pezzo su cinque al granaio | tutti −8 |
| | Pedaggio ✓ | baronia | 80 | Palizzata | 2 monete da chi entra dal cancello o dal ponte (posate al cancello più vicino); un quinto in meno di arrivi | avventurieri −3 |
| | Granaio aperto ✓ | baronia | 60 | dopo Decima | senza cibo in magazzino si mangia dal granaio; una volta a stagione un pasto a tutti | tutti +4 |
| | Tributo ✓ | contea | 150 | — | +1 autorità al giorno a colono | tutti −4 |
| Lavoro | Turni lunghi ✓ | signoria | 40 | Turni | 10 ore di lavoro (il pigro 7, lo stacanovista resta a 12); stress +25% | tutti −5; stacanovista +3; pigro, festaiolo, irrequieto −10 |
| | Giornata corta ✓ | signoria | 40 | Turni | al più 6 ore; stress −25% | tutti +8; stacanovista −5 |
| | Riposo festivo ✓ | signoria | 30 | — | ogni settimo giorno si cucina e basta | tutti +6; stacanovista −5; asceta 0 |
| | Corvée | baronia | 80 | — | 2 ore di tempo libero ai cantieri della corona, che vanno il 25% più svelti | tutti −6; stacanovista 0 |
| | Turno di guardia ✓ | baronia | 80 | Palizzata | un colono veglia di notte (prima i nottambuli, se no il primo che non è il sovrano, che dorme di giorno): lupi visti al bordo, cioè da tutti e da tutta la mappa | nottambulo +5; dormiglione −5 |
| | Corporazioni | contea | 150 | — | nelle stanze di lavoro lavorano solo i lavoratori, il 20% più svelti | lavoratori +5; gli altri −2 |
| Ordine | Coprifuoco ✓ | signoria | 40 | — | dalle 21 tutti a letto: niente sere al fuoco, meno prede per i lupi | tutti −2; festaiolo −10; mattiniero +3 |
| | Milizia ✓ | signoria | 50 | Fantoccio | un'ora al giorno al fantoccio (la prima di tempo libero); si scappa sotto 30 punti ferita | tutti −3; iracondo +3 |
| | Pene severe ✓ | baronia | 80 | Giustizia | gogna per sfuriate e proteste (−10 felicità per un giorno; la protesta non toglie autorità); sfuriate un terzo meno spesso (l'iracondo si stressa un terzo meno) | tutti −2; iracondo −10 |
| | Clemenza ✓ | baronia | 80 | Giustizia | sfuriate di un'ora; il sovrano ascolta chi protesta (un'ora, +10 felicità per mezza giornata, niente autorità persa) | tutti +3; iracondo +5 |
| | Riserva di caccia ✓ | baronia | 100 | — | cervi doppi, solo del sovrano e dei cacciatori (chi ha l'arco); +3 autorità a cervo del sovrano | cacciatori +3; gli altri −3 |
| | Legge marziale | contea | 150 | — | con nemici in vista nessuno scappa sopra 20 punti ferita; +10% a segno | tutti −5 |
| Popolo | Porte chiuse ✓ | signoria | 30 | Accoglienza | nessuno chiede di restare: gli avventurieri non lo chiedono, i viandanti non vengono | tutti +5 |
| | Porte aperte ✓ | signoria | 40 | Accoglienza | un avventuriero chiede di restare dopo 2 spedizioni, i viandanti il doppio; forestieri per 10 giorni (vedi 4.2.1) | forestieri −5 |
| | Giuramento ✓ | baronia | 80 | — | chi resta va al trono e giura (un'ora, 10 autorità; senza trono dove si trova, senza autorità resta forestiero): non è forestiero | chi ha giurato +5 |
| | Padrinato | baronia | 100 | — | un padrino: +50% esperienza per 10 giorni lavorandogli vicino | padrino e figlioccio +3 |
| | Matrimoni misti | contea | 150 | — | coloni e avventurieri si sposano; l'avventuriero resta come colono | avventurieri +5 |
| | Scuola | contea | 180 | Scriptorium | un'ora allo scrittoio per figli e forestieri; i figli crescono con 3 punti abilità in più | figli e forestieri +3 |
| | Carta delle libertà | regno | 300 | Corona finale | leggi del Popolo ×1,5; Taglia, Corvée, Coprifuoco e Pene severe non si promulgano più | tutti +10 |
| Corona | Primogenitura | dall'inizio | — | Successione | regna il primo figlio | — |
| | Corte ✓ | baronia | 100 | — | il sovrano non lavora più: udienza +50%, il suo sguardo a 12 caselle (quando ci sarà lo sguardo, 4.3) | sovrano +5 |
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
- Il sovrano e 3 coloni (a caso) in una radura al centro della mappa, senza niente di costruito: né stanze né magazzino.
  Accanto a loro le 60 monete di partenza, a terra; il resto si raccoglie. (Le tre stanzette di legno e il magazzino con
  la scorta di prova non ci sono più.)
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
**Stato**: fatte le fasi 1–4; della 5 una parte dei nodi, l'erudito errante e la protesta. Nel gioco: scrittoio,
libreria e trono; stanze Studio e Sala del trono; lavori Studiare e Governare; studio e autorità (nelle finestre
Knowledge e Laws, tasti K e G, o clic su scrittoio e trono; tutte e due scorrono); i tre libri, nei forzieri e nei
tesori, col monastero; le 38 ricerche segnate ✓; le 22 leggi segnate ✓; il titolo cresce con lo splendore e i coloni (4.3) e dà i
sigilli (2–5), le fasce delle leggi e l'autorità di ogni giorno; gli eventi d'autorità del 4.7.4 tranne
l'incoronazione (manca la successione), mai sotto zero. Il granaio è un conto, non una stanza, e niente ci marcisce;
paga le provviste, poi (Granaio aperto) l'ora senza cibo in magazzino e il pasto di ogni stagione; la festa del
raccolto è nei cinque giorni di festa del calendario (4.5), il pasto del granaio l'alba dopo. Le spedizioni prendono
prima dal granaio, poi le gallette, poi pasti e crudo. Manca il resto, e i contatori di studio e autorità nella barra
in alto (ora c'è posto: data, ora e meteo sono in una targhetta sotto la barra).

## 5. Scope

### MVP (primo traguardo giocabile) ✓
Mappa, 3–5 coloni, tagliare/estrarre/costruire/cucinare, priorità, fame/riposo/freddo,
una stagione invernale, salvataggio locale, inglese + italiano. Raggiunto il 2026-11-18, con la tabella delle priorità
(4.1) e l'orto (4.4.1).

### Dopo l'MVP (in ordine)
1. Catene produttive e attrezzi
2. Re, matrimonio, figli, successione
3. Narratore ed eventi
4. Salvataggio cloud
5. Umore, relazioni, più talenti
6. Avventurieri e rovine (vedi 4.4.4)
7. Ricerca: il sapere e le leggi (vedi 4.7)
8. Tetti, calore e conservazione (vedi 4.4.5)

### Fuori scope (per ora)
Combattimento tattico (oggi i coloni si difendono da soli, vedi 4.4.3), livelli verticali, commercio/diplomazia, mod.

## 6. Domande aperte
- Dimensione dei tile: 16×16 o 32×32?
- Condizione di sconfitta: oggi la partita finisce solo quando muoiono tutti i coloni (finita la dinastia ne nasce
  una nuova, 4.3.3). Basta così?
- Nome definitivo del gioco.
