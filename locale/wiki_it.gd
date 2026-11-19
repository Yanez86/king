# Wiki del gioco in italiano: le pagine di wiki.gd, tradotte, nello stesso ordine (vedi pages in wiki.gd). I numeri
# vengono da main.gd: se cambiano là, vanno cambiati qui e in wiki.gd.
const PAGES := [
	["Le basi", """[color=#e8c34a]La tua signoria[/color]
King è un gestionale di colonia medievale. Sei il sovrano di una piccola signoria, ma non muovi mai nessuno a mano: segni gli alberi da tagliare e i massi da scavare, progetti gli edifici, scegli cosa producono le postazioni e promulghi le leggi. I coloni scelgono da soli i lavori, seguendo i loro bisogni e la loro routine quotidiana.

[color=#e8c34a]L'inizio[/color]
• Il tuo sovrano, creato nella pagina della nuova partita, e tre coloni stanno in una radura. Non c'è ancora niente di costruito: né stanze né magazzino.
• Accanto a loro, 60 [img=center]res://art/icon_coin.png[/img] sono a terra nell'erba: costruisci un magazzino e i trasportatori ce le portano (si spende solo quello che è in magazzino).
• Un'arma abbandonata (una spada, un'ascia o un arco) giace nell'erba a 15–25 caselle dalla radura.
• Dal giorno 5 arrivano i lupi (vedi Combattimento e lupi).
• Se muoiono tutti i coloni, la colonia è caduta.

[color=#e8c34a]Il tempo[/color]
• La stagione, la data e l'ora sono nella barra in alto. La partita comincia alle 8:00 del Giorno della Corona dell'anno 1; a velocità normale un giorno dura 4 minuti, un'ora 10 secondi.
• L'anno ha 365 giorni: il Giorno della Corona (Capodanno), poi quattro stagioni di tre mesi da 30 giorni, ognuna chiusa da un giorno di festa fuori dai mesi. Primavera: Disgelo, Semina, Fioritura, poi la Festa dei Fiori. Estate: Solleone, Fienagione, Maturazione, poi la Festa della Falce. Autunno: Mietitura, Foglie morte, Nebbie, poi la Festa del Focolare. Inverno: Gelo, Neve alta, Notte lunga, poi la Festa delle Candele.
• La notte dura dalle 18:00 alle 6:00: si accendono abat-jour e lampioni.
• I pulsanti della velocità in alto a destra: pausa, 1x, 2x, 3x. Oppure i tasti: Spazio mette in pausa (e dalla pausa torna a 1x), 1, 2 e 3 scelgono la velocità. Anche il menu delle opzioni mette in pausa.
• I tempi di questa wiki sono in secondi a 1x, per chi lavora con l'abilità a livello 5 (vedi Abilità).

[color=#e8c34a]La barra in alto[/color]
Il tuo stemma e il nome del tuo reame (clic: la scheda del sovrano), gli oggetti nei magazzini, i coloni, i letti e lo splendore; poi LUPI e SPEDIZIONI quando ce ne sono, la stagione, la data, l'ora e l'ordine che stai dando."""],

	["Comandi", """[color=#e8c34a]Visuale[/color]
• Trascina col tasto destro del mouse per spostare la visuale; la rotella fa lo zoom.
• Sul trackpad due dita spostano la visuale e pizzicando fai lo zoom.

[color=#e8c34a]Mouse[/color]
• Con Seleziona (la freccia), il clic sinistro apre le cose: la scheda di un colono, il cartello di una stanza, il menu di una postazione, la bacheca, uno scrittoio (Conoscenza) o un trono (Leggi). Un clic altrove chiude la scheda.
• Con un ordine scelto (Costruisci, Distruggi, Scava...), trascina un rettangolo col tasto sinistro per segnare l'area.
• Il riquadro in basso a destra dice cosa c'è sotto il mouse: i tronchi rimasti in un albero, quanto è fresco un mucchio di cibo e così via.
• Le finestre si possono trascinare; la X le chiude.

[color=#e8c34a]La barra in basso[/color]
Un tasto fa come un clic sul suo pulsante (premilo di nuovo per chiudere).
[table=4]
[cell]Seleziona[/cell][cell]Q[/cell][cell]Costruisci[/cell][cell]B[/cell]
[cell]Distruggi[/cell][cell]X[/cell][cell]Scava[/cell][cell]M[/cell]
[cell]Taglia[/cell][cell]C[/cell][cell]Estirpa[/cell][cell]U[/cell]
[cell]Raccogli[/cell][cell]H[/cell][cell]Orto[/cell][cell]P[/cell]
[cell]Pesca[/cell][cell]F[/cell][cell]Caccia[/cell][cell]T[/cell]
[cell]Lavori[/cell][cell]J[/cell][cell]Risorse[/cell][cell]I[/cell]
[cell]Conoscenza[/cell][cell]K[/cell][cell]Leggi[/cell][cell]G[/cell]
[cell]Vista stanze[/cell][cell]L[/cell][cell]Vista calore[/cell][cell]N[/cell]
[cell]Lente della terra[/cell][cell]O[/cell][cell]Tagliare il ghiaccio[/cell][cell]Y[/cell]
[cell]Tetti[/cell][cell]V[/cell][cell]Wiki[/cell][cell]F1[/cell]
[/table]
• Lavori: chi fa cosa per primo (vedi Coloni), e il lavoro in attesa. Risorse: cosa c'è nei magazzini.

[color=#e8c34a]Tasti fissi[/color]
• Spazio: pausa; 1, 2, 3: velocità.
• E e R: girano a sinistra o a destra il prossimo mobile.
• Esc: le opzioni (anche l'ingranaggio in alto a destra).

[color=#e8c34a]Opzioni[/color]
• Sistema: la lingua, carica un'altra colonia, torna al menu principale, esci dal gioco. Video: misura della finestra e schermo intero (anche il pulsante dello schermo in alto a destra).
• Tasti: clicca il tasto di un comando, poi premi quello nuovo. Esc annulla, Canc o Backspace lo lasciano senza tasto, Ripristina rimette quelli di partenza. Spazio, 1-3, E, R ed Esc non si possono assegnare. I tuoi tasti vengono salvati.

[color=#e8c34a]Salvataggio[/color]
• La partita si salva da sé: appena fondata la colonia, a ogni alba (le 6:00), e quando torni al menu principale, esci o chiudi la finestra. In alto compare "Salvato". Non si salva a mano: una colonia è una storia sola.
• Ogni colonia tiene i suoi ultimi 3 salvataggi; se il più recente è rovinato, si usa quello prima.
• Sulla schermata del titolo, Continua riprende la colonia giocata per ultima e Colonie le elenca tutte, col reame, la data, il sovrano e i coloni. Carica partita nelle opzioni fa lo stesso durante una partita (prima si salva questa); Elimina cancella una colonia con tutti i suoi salvataggi e chiede due volte.
• Una colonia caricata parte in pausa: Spazio per andare avanti. Una colonia caduta non si salva: Continua ti riporta alla sua ultima alba."""],

	["Coloni", """Clicca un colono per aprire la sua scheda: salute, bisogni (le frecce mostrano se ognuno sale o scende), abilità, talenti, condizioni, equipaggiamento e le 24 ore della sua routine.

[color=#e8c34a]Bisogni[/color]
Vanno tutti da 0 a 100.
• Cibo: -90 al giorno. Sotto 30 i coloni vanno a mangiare (vedi Cibo e cucina).
• Riposo: -100 al giorno da svegli. Sotto 30 cercano un letto libero; a 10 mollano tutto e dormono dove si trovano. 8 ore di sonno lo riempiono, a comfort 5.
• Svago: -120 al giorno da svegli. Sotto 30 si prendono una pausa, anche nelle ore di lavoro: un'ora attorno a un fuoco da campo, o una passeggiata lì vicino.
• Comfort: nel sonno va verso il comfort del posto dove sono sdraiati (vedi Stanze); all'aperto è 0.
• Stress: +30 al giorno lavorando (anche combattendo e scappando), +5 per ogni morso di lupo; -60 al giorno dormendo, mangiando, svagandosi o senza far niente. Il massimo è 100.
• Felicità: va verso la media di cibo, riposo, svago, comfort e calma (100 meno lo stress), più o meno condizioni e leggi. La felicità del sovrano decide quanta autorità raccoglie.

[color=#e8c34a]Routine[/color]
Ogni ora è sonno, lavoro o tempo libero. La giornata solita: sonno 22–6, colazione alle 6, lavoro 7–12 e 13–18 col pranzo in mezzo, sera libera, e al massimo 8 ore di lavoro. Talenti e leggi la cambiano.
• Ore di sonno: a letto, o per terra se non c'è un letto libero. Restano giù anche quando sono riposati, poi si alzano con almeno 80 di riposo.
• Ore di lavoro: prendono i lavori. Finito il turno o finite le loro ore, smettono appena hanno le mani libere. A ogni ora si fermano anche per un bisogno urgente: fame (se c'è cibo), stanchezza (se c'è un letto libero), noia.
• Tempo libero: uno spuntino se il cibo è sotto 60, poi si svagano.

[color=#e8c34a]Priorità[/color]
La tabella in cima a Lavori (J): una riga per colono, una colonna per tipo di lavoro (passa sopra le icone). Ogni casella va da 1 (prima) a 4 (per ultimo), o – per mai; clic per dopo, clic destro per prima. All'inizio è tutto 3.
• Un colono prende il lavoro col numero migliore che ha qualcosa da fare; a numeri uguali, quello più a sinistra; di ogni tipo di lavoro, il più vicino.
• Le colonne: cucinare, produrre (forgia, banco da lavoro, filatoio, banco del falegname), tagliare, scavare (e tagliare il ghiaccio), raccogliere (cespugli, lino, estirpare), coltivare, pescare, cacciare, costruire (e arredare, riparare i tetti), trasportare, governare (solo il sovrano), studiare.
• Prima della tabella: prendere l'equipaggiamento; il sovrano al trono e i lavoratori dello studio ai loro scrittoi, se li hai spuntati sul cartello. Un tetto in fiamme viene prima di tutto, per tutti.

[color=#e8c34a]Salute[/color]
• 0–100; risale di 30 al giorno (60 dormendo). Una barretta sopra la testa mostra i feriti.
• A 0 un colono è a terra: sdraiato, non fa niente e risale di 40 al giorno. A 30 si rialza.
• I morti restano a terra per un giorno; il loro equipaggiamento cade lì accanto e gli altri sono in lutto per 3 giorni.

[color=#e8c34a]Età[/color]
• La scheda dice l'età di ogni colono, accanto al sesso. Il ritmo della vita si sceglie nella pagina della nuova partita: Veloce, un anno di vita a stagione, quattro volte più in fretta del calendario, così passano le generazioni (i figli crescono in 4 anni); o Reale, un anno all'anno, come il calendario (16 anni per crescere, una gravidanza di 9 mesi veri). I numeri qui sotto sono in anni di vita, qualunque sia il ritmo.
• Il sovrano parte tra 20 e 30 anni, gli altri coloni e gli avventurieri tra 18 e 40.
• Dai 60 anni, a ogni compleanno si può morire di vecchiaia: il 4% a 60, il 24% a 70, il 44% a 80.

[color=#e8c34a]Nuovi coloni[/color]
La colonia cresce coi figli (vedi Il sovrano e la casata), con gli avventurieri che restano (vedi Avventurieri) e coi viandanti. Lo splendore attira gente; una colonia affollata ne attira meno.
• I viandanti arrivano un gruppo alla volta, dal giorno 10: in media ogni 30 giorni, diviso (1 + splendore / 20); sopra 8 coloni l'attesa raddoppia ogni 4 coloni in più (il doppio a 12, il quadruplo a 16). A 15 di splendore uno ogni 17 giorni circa.
• Da soli (70%), una coppia sposata (15%) o una famiglia (15%: un genitore o una coppia, con un figlio di 4–11 anni). Gli adulti hanno 16–45 anni, 4 punti abilità e 0–2 talenti; un gruppo su quattro porta un attrezzo (piccone, ascia, falcetto o arco).
• Entrano dal bordo della mappa, vanno nella sala del trono (o a un fuoco, o nella radura) e chiedono di restare: Accogli o Manda via. Chiusa la finestra, la domanda aspetta sulla loro scheda (Rispondi…) per 2 giorni, poi se ne vanno. Intanto non lavorano, mangiano dai tuoi magazzini e dormono alla locanda (o per terra).
• Accolti, sono coloni, Forestieri per 5 giorni (-5 felicità, lavorano il 10% più piano). Una famiglia resta tale: la coppia è sposata, il figlio ha i suoi genitori."""],

	["Abilità", """Tredici abilità, con livelli da 0 a 10 (una stellina al 10). I coloni partono da 0; il tuo sovrano ha 12 punti nella pagina della nuova partita.

[color=#e8c34a]Velocità[/color]
Un lavoro dura 1,5 volte tanto a livello 0, il tempo normale a livello 5 e la metà a livello 10 (1,4 a livello 1, 1,3 a livello 2...). Quasi tutti i lavori dipendono anche dalle condizioni, e sonno, cucina, lavorazioni e studio dal comfort della stanza.

[color=#e8c34a]Cosa fa ogni abilità[/color]
[table=2]
[cell]Raccogliere[/cell][cell]raccolta da cespugli e lino, l'orto[/cell]
[cell]Estrarre[/cell][cell]scavare i massi[/cell]
[cell]Tagliare legna[/cell][cell]abbattere gli alberi[/cell]
[cell]Costruire[/cell][cell]costruzione: 2 s a casella o a pezzo[/cell]
[cell]Forgiare[/cell][cell]alla fornace e all'incudine[/cell]
[cell]Cucire[/cell][cell]filatoio e banco da lavoro[/cell]
[cell]Cucinare[/cell][cell]pasti: velocità, bruciati, squisiti[/cell]
[cell]Pescare[/cell][cell]lanciare e prendere pesci[/cell]
[cell]Cacciare[/cell][cell]mirare e colpire la selvaggina[/cell]
[cell]Mischia[/cell][cell]colpi in combattimento; schivare i morsi[/cell]
[cell]Tiro[/cell][cell]tiri con l'arco; fare archi[/cell]
[cell]Ricerca[/cell][cell]scrivere pagine di studio[/cell]
[cell]Scassinare[/cell][cell]solo avventurieri: trappole, serrature[/cell]
[/table]
Con l'arco un cacciatore mira col migliore tra Cacciare e Tiro. A una postazione un livello basso rovina più oggetti, al fuoco da campo brucia più pasti.

[color=#e8c34a]Esperienza[/color]
+1 XP (passa il mouse sul livello per vederla) per ogni albero abbattuto, masso scavato o cespuglio spogliato, ogni lancio, pezzo costruito, pasto cucinato, oggetto fatto, pagina scritta, tiro o colpo. Un tiro di caccia conta per Cacciare e per Tiro. Per ora l'esperienza viene solo contata: non fa ancora salire i livelli."""],

	["Talenti", """I coloni hanno 0–2 talenti, mai due in contrasto. Passa il mouse su un talento nella scheda per vederne l'effetto.
[table=3]
[cell][color=#d9c48a]Talento[/color][/cell][cell][color=#d9c48a]Effetto[/color][/cell][cell][color=#d9c48a]Sovrano[/color][/cell]
[cell]Goloso[/cell][cell]fame +50%, mangia a 50[/cell][cell]+2[/cell]
[cell]Sonnambulo[/cell][cell]cammina nel sonno[/cell][cell]+2[/cell]
[cell]Iracondo[/cell][cell]stress dal lavoro +50%, sfuriate[/cell][cell]+2[/cell]
[cell]Pigro[/cell][cell]lavora al più 6 ore[/cell][cell]+2[/cell]
[cell]Stacanovista[/cell][cell]fino a 12 ore, anche nel tempo libero[/cell][cell]-2[/cell]
[cell]Mattiniero[/cell][cell]tutto 2 ore prima: dorme 20–4[/cell][cell]0[/cell]
[cell]Nottambulo[/cell][cell]dorme 10–18, lavora di notte[/cell][cell]0[/cell]
[cell]Dormiglione[/cell][cell]dorme 10 ore, fino alle 8[/cell][cell]+2[/cell]
[cell]Instancabile[/cell][cell]dorme 0–6, si stanca il 25% più piano[/cell][cell]-2[/cell]
[cell]Festaiolo[/cell][cell]si annoia il doppio, smette alle 17[/cell][cell]+2[/cell]
[cell]Asceta[/cell][cell]non ha mai bisogno di svago[/cell][cell]-2[/cell]
[cell]Di poco appetito[/cell][cell]fame -40%, niente spuntini[/cell][cell]-2[/cell]
[cell]Tranquillo[/cell][cell]metà dello stress dal lavoro[/cell][cell]-2[/cell]
[cell]Pennichella[/cell][cell]pisolino 13–14, a letto alle 23[/cell][cell]0[/cell]
[cell]Irrequieto[/cell][cell]un'ora di pausa dopo 2 di lavoro[/cell][cell]+2[/cell]
[/table]
Sovrano: i punti abilità che il talento dà (+2) o costa (-2) nella pagina della nuova partita.

[color=#e8c34a]Dettagli[/color]
• Goloso: nel tempo libero fa uno spuntino sotto 85 di cibo, sente il doppio le condizioni del cibo e detesta il cibo crudo (Mangiato crudo).
• Sonnambulo: a ogni ora di sonno, 1 probabilità su 10 di camminare per qualche casella e dormire lì, per terra.
• Iracondo: a 90 di stress se ne va a sbollire per due ore, e intanto lo stress cala quattro volte più in fretta.
• Stacanovista: in più si annoia la metà.

[color=#e8c34a]Mai insieme[/color]
Goloso e Di poco appetito, Pigro e Stacanovista, Mattiniero e Nottambulo, Dormiglione e Instancabile, Festaiolo e Asceta, Iracondo e Tranquillo."""],

	["Condizioni", """Effetti che durano un po', mostrati come icone sotto i talenti nella scheda (col mouse sopra: cosa fanno e le ore che mancano).
[table=4]
[cell][color=#d9c48a]Condizione[/color][/cell][cell][color=#d9c48a]Durata[/color][/cell][cell][color=#d9c48a]Lavoro[/color][/cell][cell][color=#d9c48a]Felicità[/color][/cell]
[cell]Intossicato[/cell][cell]1 giorno[/cell][cell]50% più lento[/cell][cell]-20[/cell]
[cell]Ben nutrito[/cell][cell]½ giorno[/cell][cell]10% più veloce[/cell][cell]+5[/cell]
[cell]Lauto pasto[/cell][cell]½ giorno[/cell][cell]20% più veloce[/cell][cell]+10[/cell]
[cell]Mangiato al tavolo[/cell][cell]½ giorno[/cell][cell]–[/cell][cell]+5[/cell]
[cell]Mangiato crudo[/cell][cell]½ giorno[/cell][cell]–[/cell][cell]-10[/cell]
[cell]Lutto[/cell][cell]3 giorni[/cell][cell]–[/cell][cell]-15[/cell]
[cell]In festa[/cell][cell]3 giorni[/cell][cell]–[/cell][cell]+10[/cell]
[cell]Nozze[/cell][cell]2 giorni[/cell][cell]–[/cell][cell]+10[/cell]
[cell]Incinta[/cell][cell]¾ d'anno di vita[/cell][cell]20% più piano alla fine[/cell][cell]–[/cell]
[cell]Lutto regale[/cell][cell]7 giorni[/cell][cell]–[/cell][cell]-20[/cell]
[cell]Incoronazione[/cell][cell]2 giorni[/cell][cell]–[/cell][cell]+10[/cell]
[cell]Forestiero[/cell][cell]5 giorni[/cell][cell]10% più lento[/cell][cell]-5[/cell]
[/table]
• Intossicato: dal cibo crudo, tanto più probabile quanto più è vicino a marcire.
• Ben nutrito: dopo un pasto; stress dal lavoro -25%. Lauto pasto: dopo un pasto squisito; stress dal lavoro -50%. Un pasto nuovo sostituisce la condizione di quello prima.
• Mangiato al tavolo: ha mangiato seduto su una sedia accanto a un tavolo.
• Mangiato crudo: un goloso che ha dovuto mangiare cibo crudo. Il goloso sente il doppio Ben nutrito, Lauto pasto, Mangiato al tavolo e Mangiato crudo.
• Lutto: è morto un colono; stress dal lavoro +25%.
• In festa: dopo un giorno di festa, con la legge Festa del raccolto (vedi Leggi).
• Nozze: tutti, quando il sovrano si sposa.
• Incinta: nell'ultimo terzo lavora il 20% più piano.
• Lutto regale: è morto il sovrano, al posto del Lutto; stress dal lavoro +25%. Incoronazione: tutti, quando il nuovo sovrano è incoronato.
• Forestiero: chi è venuto da fuori ed è rimasto, avventuriero o viandante (vedi Avventurieri).
Qui compaiono anche le leggi in vigore che a un colono piacciono o non piacciono, con la loro icona."""],

	["Il sovrano e la casata", """[color=#e8c34a]Nuova partita[/color]
Prima della mappa vengono due pagine.
• La tua casata: il nome della casata (il cognome del tuo sovrano), il nome della colonia, il ritmo della vita (vedi Coloni, Età) e lo stemma: forma, partizione, campo e secondo campo, pezza e figura, ognuna col suo smalto. I dadi tirano a sorte un nome o uno stemma intero.
• Il tuo sovrano: nome, un soprannome facoltativo, sesso, capelli e il loro colore, la barba (solo per gli uomini), maglia e mantello (seguono i primi due smalti dello stemma finché non li scegli), fino a 2 talenti non in contrasto e 12 punti abilità, al massimo 3 in un'abilità (niente Scassinare).
• I talenti spostano punti: i difetti ne danno 2 (Goloso, Sonnambulo, Iracondo, Pigro, Dormiglione, Festaiolo, Irrequieto), i pregi ne costano 2 (Stacanovista, Instancabile, Asceta, Di poco appetito, Tranquillo); Mattiniero, Nottambulo e Pennichella sono gratis.
Gli altri due coloni vengono a caso: abilità a 0, 0–2 talenti.

[color=#e8c34a]In partita[/color] [img=center]res://art/icon_crown.png[/img]
• Il sovrano è il primo colono e vive come gli altri: bisogni, routine, lavoro, combattimenti. Può morire.
• Titolo: Signore o Signora. La barra in alto mostra "Signoria di" e il nome della tua colonia, accanto al tuo stemma: cliccaci sopra per la scheda del sovrano. Sugli stendardi sventola il tuo stemma.
• Solo il sovrano governa: su un trono, in una sala del trono, raccoglie autorità per le leggi (vedi Leggi). Un sovrano sereno (70 o più) ne raccoglie il 25% in più, uno cupo (30 o meno) la metà.
• Il titolo cresce con la colonia, non cala mai e passa all'erede. Vuole sia lo splendore sia i coloni (contano i figli e chi è in spedizione; i neonati e gli avventurieri no):
[table=5]
[cell][color=#d9c48a]Titolo[/color][/cell][cell][color=#d9c48a]Splendore[/color][/cell][cell][color=#d9c48a]Coloni[/color][/cell][cell][color=#d9c48a]Sigilli[/color][/cell][cell][color=#d9c48a]Autorità al giorno[/color][/cell]
[cell]Signoria[/cell][cell]–[/cell][cell]–[/cell][cell]2[/cell][cell]+1[/cell]
[cell]Baronia[/cell][cell]15[/cell][cell]6[/cell][cell]3[/cell][cell]+2[/cell]
[cell]Contea[/cell][cell]35[/cell][cell]10[/cell][cell]4[/cell][cell]+3[/cell]
[cell]Regno[/cell][cell]60[/cell][cell]15[/cell][cell]5[/cell][cell]+4[/cell]
[/table]
Lo annunciano una finestra e la cronaca; cambiano il nome del reame, il titolo del sovrano e la corona sullo stemma. La finestra delle leggi dice cosa serve per il titolo dopo.

[color=#e8c34a]Matrimonio[/color]
• Un sovrano adulto (16 anni o più) senza coniuge vivo si può sposare: "Combina un matrimonio…" nella scheda del sovrano elenca i coloni adulti dell'altro sesso senza coniuge. Chi ha meno di 50 di felicità dice di no, e l'elenco dice perché.
• Le nozze: tutti prendono Nozze (+10 felicità per 2 giorni), +10 autorità, e la cronaca lo racconta. Ognuno dei due sposi entra nelle stanze dell'altro. La scheda mostra il coniuge, con una croce quando è morto: un sovrano vedovo si può risposare.
• Dai alla coppia una stanza con due letti: i figli verranno dal dividerla.
• Pretendenti: finché il sovrano si può sposare e c'è una locanda, ogni 20 giorni circa arriva alla locanda una persona dell'altro sesso di un'altra casata, col suo stemma e la dote (20–80 monete, a volte un quaderno, lingotti o acciaio). Aspetta 5 giorni e dice sempre di sì: sposata, diventa un colono e la dote resta in colonia. Dorme nei letti della locanda e non lavora.

[color=#e8c34a]Figli[/color] [img=center]res://art/baby.png[/img]
• Una coppia sposata che dorme nella stessa stanza può avere un figlio: l'1% a notte, finché lei ha da 16 a 40 anni (dai 35 la metà). Resta Incinta per tre quarti d'anno di vita (68 giorni col ritmo veloce, 274 con quello reale), e nell'ultimo terzo lavora più piano; poi per un anno di vita niente altri figli.
• La cronaca racconta la nascita e una finestra chiede il nome (il dado ne tira uno). Il figlio prende il cognome e i colori della casata, i capelli di un genitore e ognuno dei loro talenti al 50% (al più due, mai in contrasto).
• Fino a 3 anni è un neonato: non è ancora un colono. Dorme in una culla (Casa, 4 legna), prima quelle dei genitori, o la madre lo tiene in braccio.
• Dai 4 è un bambino: raccoglie e trasporta e basta, a metà velocità, non prende armi né armature e scappa sempre dai lupi. Si vede più piccolo.
• Dai 12 è un ragazzo: tutto tranne costruire, scavare, tagliare e cacciare.
• A 16 anni raggiunge la maggiore età: ogni lavoro, e a qualche ragazzo cresce la barba.
• La scheda dei genitori elenca i figli, quella dei figli i genitori.

[color=#e8c34a]Successione[/color]
• Quando il sovrano muore, la corona va al primo figlio vivo, maschio o femmina; senza figli al coniuge vivo, poi a un fratello o a una sorella.
• Tutti prendono il Lutto regale per 7 giorni; poi l'erede è incoronato: Incoronazione per tutti e +20 autorità.
• Un erede sotto i 16 anni aspetta con un reggente: un genitore vivo, se no l'adulto con più abilità. Il reggente governa e il suo titolo è Reggente; la scheda dell'erede dice "Erede di". Al sedicesimo compleanno l'erede è incoronato. Se il reggente muore ne arriva un altro; se muore l'erede, il prossimo della linea.
• "La casata…" nella scheda di un colono apre l'albero genealogico: i sovrani in ordine, divisi per casata, ognuno con gli anni di regno, il coniuge e i figli (i morti con la croce), e il reggente se c'è.
• Non resta nessuno: la casata è finita. Una finestra chiede chi regnerà tra gli adulti (intanto quello con più abilità): comincia la sua casata, col suo cognome e uno stemma nuovo. Il titolo resta al reame."""],

	["Costruire", """[color=#e8c34a]Come costruire[/color] [img=center]res://art/icon_wood.png[/img] [img=center]res://art/icon_stone.png[/img]
• Premi Costruisci, scegli Strutture o una delle cinque categorie dei mobili (Casa; Fuoco e calore; Mestieri e provviste; Corte e difesa; Decorazioni, coi cimeli), poi un pezzo: col mouse sopra il suo pulsante vedi il costo e il comfort o lo splendore che dà.
• Muri e pavimenti si fanno con legna o pietra (la pietra dopo la ricerca Muratura). Porte, mobili e decorazioni hanno il loro materiale.
• Trascina sulla mappa: il progetto si vede in blu. I muri vanno solo lungo il bordo del rettangolo, così con un solo trascinamento tracci il contorno di una stanza; pavimenti, sentieri e porte lo riempiono. Disegnare sopra il tuo progetto non ancora confermato lo sostituisce: è così che metti una porta in un muro che stai progettando.
• I mobili si mettono un pezzo alla volta, dove rilasci il tasto. E e R (o le frecce nella barra) girano il pezzo; l'anteprima è rossa dove non ci sta.
• Premi Costruisci in basso al centro per confermare: solo allora i coloni cominciano. La X rossa cancella caselle dal progetto, anche quelle confermate. Se chiudi Costruisci senza confermare, il progetto si butta via.
• Il costruttore va a prendere il materiale da un mucchio (a terra o in un magazzino) e ci mette 2 s a casella o a pezzo. Un pezzo di due materiali (abat-jour, lampione) vuole un viaggio per ciascuno: quello già portato aspetta al cantiere, e torna a terra se annulli il progetto.
• Distruggi (X): trascina sopra strutture e mobili per buttarli giù subito. Il materiale si perde.
• I pezzi che non hai ancora ricercato non hanno un pulsante.

[color=#e8c34a]Dove[/color]
Non sull'acqua, sugli alberi, sulla roccia, sui cespugli o sulle erbacce (prima estirpali), né sugli oggetti a terra. I mobili stanno sulla terra nuda, sui pavimenti e sui sentieri, mai su altri mobili; muri e porte mai sui mobili.

[color=#e8c34a]Strutture[/color]
[table=3]
[cell]Muro[/cell][cell]5 legna o pietra a casella[/cell][cell]blocca il passaggio[/cell]
[cell]Pavimento[/cell][cell]2 legna o pietra a casella[/cell][cell]comfort della stanza[/cell]
[cell]Porta[/cell][cell]5 legna[/cell][cell]ogni stanza ne ha bisogno[/cell]
[cell]Sentiero[/cell][cell]1 pietra a casella[/cell][cell]terra battuta[/cell]
[cell]Intonaco[/cell][cell]1 pietra a casella[/cell][cell]su un muro di legno: isola di più[/cell]
[/table]

[color=#e8c34a]Mobili[/color]
[table=3]
[cell][color=#d9c48a]Pezzo[/color][/cell][cell][color=#d9c48a]Costo[/color][/cell][cell][color=#d9c48a]Ricerca[/color][/cell]
[cell]Letto (2x1)[/cell][cell]10 legna[/cell][cell]–[/cell]
[cell]Tavolo (2x2)[/cell][cell]10 legna[/cell][cell]–[/cell]
[cell]Sedia[/cell][cell]3 legna[/cell][cell]–[/cell]
[cell]Fuoco da campo[/cell][cell]5 legna[/cell][cell]–[/cell]
[cell]Scrittoio[/cell][cell]10 legna[/cell][cell]–[/cell]
[cell]Trono[/cell][cell]12 legna[/cell][cell]–[/cell]
[cell]Abat-jour[/cell][cell]2 legna, 1 carbone[/cell][cell]Lanterne[/cell]
[cell]Fornace[/cell][cell]20 pietra[/cell][cell]Forgia[/cell]
[cell]Incudine[/cell][cell]10 ferro[/cell][cell]Forgia[/cell]
[cell]Banco da lavoro[/cell][cell]15 legna[/cell][cell]Sartoria[/cell]
[cell]Filatoio[/cell][cell]10 legna[/cell][cell]Caccia[/cell]
[cell]Banco del falegname[/cell][cell]15 legna[/cell][cell]Caccia[/cell]
[cell]Bacheca[/cell][cell]8 legna[/cell][cell]Locanda[/cell]
[cell]Libreria[/cell][cell]12 legna[/cell][cell]Libreria[/cell]
[cell]Focolare[/cell][cell]15 pietra[/cell][cell]Muratura[/cell]
[cell]Pelli alle pareti[/cell][cell]2 pelli[/cell][cell]Caccia[/cell]
[cell]Portiera[/cell][cell]2 pelli[/cell][cell]Caccia[/cell]
[cell]Arazzo[/cell][cell]4 lino[/cell][cell]Telaio[/cell]
[cell]Stufa a olle[/cell][cell]20 pietra[/cell][cell]Stufa a olle[/cell]
[cell]Fossa del ghiaccio (2x2)[/cell][cell]20 pietra[/cell][cell]Ghiacciaia[/cell]
[cell]Cumulo del compost[/cell][cell]6 legna[/cell][cell]Concimazione[/cell]
[cell]Culla[/cell][cell]4 legna[/cell][cell]–[/cell]
[/table]
Focolare, pelli, arazzo e stufa a olle vanno addossati a un muro alle loro spalle, la portiera a una porta: girali verso di lui. Decorazioni: vedi Splendore."""],

	["Stanze", """Una stanza è un'area chiusa da muri (contano anche la roccia e l'acqua profonda) con almeno una porta verso l'esterno, di meno di 400 caselle. Quando è finita, sul muro accanto alla porta compare un cartello: cliccalo per dare un nome alla stanza, vederne il comfort, sceglierne il tipo, bandirla e spuntarne i proprietari o i lavoratori.

[color=#e8c34a]Tipi[/color]
L'elenco mostra solo i tipi i cui mobili sono dentro. Se togli quei mobili la stanza perde il tipo, e con lui i proprietari o i lavoratori.
[table=3]
[cell][color=#d9c48a]Tipo[/color][/cell][cell][color=#d9c48a]Serve[/color][/cell][cell][color=#d9c48a]Categoria[/color][/cell]
[cell]Magazzino[/cell][cell]niente[/cell][cell]servizio[/cell]
[cell]Camera[/cell][cell]1 letto[/cell][cell]residenza[/cell]
[cell]Dormitorio[/cell][cell]2 letti[/cell][cell]residenza[/cell]
[cell]Cucina[/cell][cell]fuoco da campo o focolare[/cell][cell]lavoro[/cell]
[cell]Forgia[/cell][cell]fornace, incudine[/cell][cell]lavoro[/cell]
[cell]Laboratorio[/cell][cell]banco da lavoro[/cell][cell]lavoro[/cell]
[cell]Falegnameria[/cell][cell]banco del falegname[/cell][cell]lavoro[/cell]
[cell]Locanda[/cell][cell]letto, tavolo, bacheca[/cell][cell]servizio[/cell]
[cell]Studio[/cell][cell]scrittoio[/cell][cell]lavoro[/cell]
[cell]Sala del trono[/cell][cell]trono[/cell][cell]lavoro[/cell]
[cell]Ghiacciaia[/cell][cell]fossa del ghiaccio; muri di pietra, nessun fuoco[/cell][cell]servizio[/cell]
[/table]
• Residenza: può avere dei proprietari. Se ne ha, è chiusa a tutti gli altri, anche solo per passarci.
• Lavoro: può avere dei lavoratori. Per ora contano in uno studio (studiano prima di qualunque altro lavoro) e in una sala del trono (solo il sovrano).
• Servizio: in comune per tutti.
• Vietata: non entra nessuno, nemmeno i proprietari.
• Le postazioni funzionano solo nella loro stanza: il fuoco da campo in una cucina, fornace e incudine in una forgia, banco da lavoro e filatoio in un laboratorio, il banco del falegname in una falegnameria.
• I coloni dormono in qualunque letto tranne quelli di una locanda, che sono per gli avventurieri.

[color=#e8c34a]Magazzini[/color]
I trasportatori portano gli oggetti sparsi nei magazzini, 10 alla volta; senza magazzino nessuno trasporta. Conta come immagazzinato solo quello che è in un magazzino: la barra in alto, Risorse, le monete che paghi, i libri per la ricerca. Una casella tiene un solo tipo di oggetto: 100 legna o monete, 50 per la maggior parte dei materiali e del cibo crudo, 20 pasti, 10 strumenti, armi, armature o libri, 5 cimeli. Dentro, il cibo marcisce a metà velocità, e al freddo ancora più piano (vedi Tetti e calore).

[color=#e8c34a]Comfort[/color]
0–10, mostrato sul cartello. Letto e tavolo +1; sedia, abat-jour, fuoco da campo, focolare e panca +0,5; un pavimento +1 se copre tutta la stanza (metà stanza, mezzo punto); la pietra conta 1,5 volte. All'aperto è 0.
A 5 non cambia niente. Sotto, sonno, cucina, lavorazioni e studio durano di più (20% a 0); sopra, di meno (20% a 10). Con poco comfort, inoltre, i pasti bruciano e gli oggetti si rovinano più spesso. Con meno di 6 caselle per ogni persona nella stanza, il comfort cala in proporzione.

[color=#e8c34a]Vista stanze[/color]
La Vista stanze (L) tinge ogni stanza col colore del suo tipo e mostra i proprietari o i lavoratori: passaci sopra col mouse per la loro scheda."""],

	["Tetti e calore", """[color=#e8c34a]Tetti[/color]
• Ogni stanza finita ha il suo tetto, sopra i muri e le porte; V li toglie tutti per guardare dentro. I tetti hanno un'altezza: salgono sopra la stanza e possono nascondere fino a tre caselle dietro. Una stanza a L ha due tetti. Il colmo corre lungo il lato lungo: un tetto più alto che largo lo ha da nord a sud e il timpano sopra il muro davanti; uno largo da est a ovest, con un piccolo timpano sopra la porta se la casa è larga almeno 7 caselle e profonda 4.
• Coi tetti, il muro davanti è una facciata alta: graticcio sul legno, pietra a corsi sulla pietra, una finestra ogni due caselle, la porta ad arco.
• Chi passa dietro una casa si vede da un buco tondo nel tetto; chi è dentro resta coperto, tranne il colono di cui è aperta la scheda.
• I tetti seguono i muri: scandole sui muri di legno, coppi su quelli di pietra (la maggioranza dei muri della stanza; le porte contano come legno).
• La neve si posa sui tetti come per terra, ma il calore che esce da una stanza calda la scioglie, prima attorno ai comignoli. Bagnati i tetti sono più scuri, dalle gronde gocciola quando piove e sotto lo zero pendono i ghiaccioli.

[color=#e8c34a]Usura e riparazioni[/color]
• Ogni casella di tetto si consuma col tempo, le scandole il doppio dei coppi: prima i licheni, poi tegole smosse e muschio, alla fine un buco con le travi a vista. Senza temporali una casella di scandole dura circa un anno, una di coppi due.
• I temporali strappano le tegole, e la cronaca lo dice; la neve pesante su un tetto largo che non la scioglie può sfondarlo.
• Sotto un buco piove e nevica, fa freddo come fuori e il cibo marcisce come all'aperto.
• Le caselle consumate sono un lavoro dei costruttori (Riparare): 1 legna per le scandole, 1 pietra per i coppi, 3 s ciascuna.

[color=#e8c34a]Temperatura[/color]
• Sotto un tetto una stanza va dalla temperatura di fuori verso i 15 °C (5 °C nei magazzini e nelle dispense, 0 °C in una ghiacciaia col ghiaccio) di quanto isolano i suoi muri: legno e porte 50%, legno intonacato 60%, pietra 70%, roccia 85%. Le pelli alle pareti (+5% ciascuna, fino a 3), la portiera (+10%) e gli arazzi (+5% ciascuno, fino a 3) aggiungono, fino al 90%.
• I fuochi scaldano: fuoco da campo +8 °C, focolare +12, fornace +15, stufa a olle +10. Focolare e fornace passano metà del loro calore alla stanza dietro il muro di legno che hanno alle spalle; la pietra lo ferma. La stufa a olle lo passa tutto, anche attraverso la pietra.
• D'estate una fontana toglie 3 °C alla sua stanza quando fuori ce ne sono più di 20.
• Sotto i 12 °C, ogni 4 °C tolgono un punto di comfort. Le tende del letto a baldacchino tengono 4 °C in più a chi ci dorme.
• Il cartello della stanza mostra i gradi; col mouse sopra, il conto.

[color=#e8c34a]Vista calore[/color]
La vista calore (N) colora le stanze secondo la temperatura: rosso il caldo, giallo il fresco senza malus, poi un blu per ogni punto di comfort che il freddo toglie, bianco sotto lo zero (lì il cibo non marcisce). Mostra i gradi e il malus di ogni stanza, quanto scalda ogni fuoco, una freccia dove il calore passa un muro e una croce dove la pietra lo ferma. Col mouse sopra una stanza, il conto. Si accende da sola quando piazzi un fuoco, un pezzo che isola o l'intonaco.

[color=#e8c34a]Focolare e comignoli[/color]
• Il focolare (Muratura, 15 pietra) va contro un muro e fa quello che fa il fuoco da campo: la cucina vuole l'uno o l'altro, le stesse ricette, i coloni ci si radunano attorno. Al fuoco da campo, dove il fumo resta, si affumica un quarto più in fretta.
• Focolari e fornaci hanno un comignolo di pietra sul muro alle spalle, un fuoco da campo sotto un tetto uno sfiatatoio di legno. Il fumo sale da lì: rado se il fuoco è solo acceso, più fitto mentre si cucina, scuro dalla fornace, denso mentre si affumica.

[color=#e8c34a]Il cibo e il freddo[/color]
• Il cibo marcisce in proporzione alla temperatura: al ritmo pieno a 15 °C, il doppio a 30 °C, per niente a 0 °C o meno. Un magazzino lo dimezza, una dispensa o una ghiacciaia lo riduce a un terzo.
• La ghiacciaia (ricerca Ghiacciaia): muri di pietra o roccia, nessun fuoco, una fossa del ghiaccio. Segna l'acqua con l'ordine Ghiaccio (Y): quando gela i coloni tagliano i blocchi (Estrarre) finché nelle fosse c'è posto, e i trasportatori ce li portano. Finché c'è ghiaccio la stanza va verso 0 °C. Il ghiaccio si scioglie col calore che passa i muri, e prima sotto un buco nel tetto.

[color=#e8c34a]Incendio[/color]
• Un fuoco da campo sotto un tetto di scandole può dargli fuoco (2% al giorno), e così un fulmine nel temporale. Una casella brucia per 4 ore e diventa un buco; intanto il fuoco passa alle scandole accanto, anche di altri tetti. I coppi non bruciano.
• Al fuoco tutti lasciano il resto: prendono un secchio all'acqua e lo gettano, 2 ore di fuoco in meno ciascuno."""],

	["Cibo e cucina", """[color=#e8c34a]Mangiare[/color]
• I coloni affamati (sotto 30 di cibo; il goloso a 50) prendono il cibo più vicino: prima i pasti squisiti, poi i pasti, il crudo solo quando non ce ne sono (vegetali, pesce, carne, affumicati, poi rape, cavoli e fave, che durano di più). Nel tempo libero fanno anche uno spuntino sotto 60.
• Se entro 20 caselle c'è una sedia libera accanto a un tavolo, portano lì il cibo e mangiano seduti: +5 felicità (Mangiato al tavolo).

[color=#e8c34a]Cibo[/color]
[table=4]
[cell][color=#d9c48a]Cibo[/color][/cell][cell][color=#d9c48a]Sazia[/color][/cell][cell][color=#d9c48a]Dura[/color][/cell][cell][color=#d9c48a]Intossica[/color][/cell]
[cell][img=center]res://art/icon_veg.png[/img] Vegetali[/cell][cell]35[/cell][cell]3 giorni[/cell][cell]5–40%[/cell]
[cell][img=center]res://art/icon_fish.png[/img] Pesce[/cell][cell]30[/cell][cell]1,5 giorni[/cell][cell]10–50%[/cell]
[cell][img=center]res://art/icon_meat.png[/img] Carne[/cell][cell]40[/cell][cell]2 giorni[/cell][cell]15–60%[/cell]
[cell][img=center]res://art/icon_turnip.png[/img] Rapa[/cell][cell]35[/cell][cell]10 giorni[/cell][cell]2–30%[/cell]
[cell][img=center]res://art/icon_cabbage.png[/img] Cavolo[/cell][cell]35[/cell][cell]14 giorni[/cell][cell]2–30%[/cell]
[cell][img=center]res://art/icon_beans.png[/img] Fave[/cell][cell]40[/cell][cell]60 giorni[/cell][cell]1–15%[/cell]
[cell][img=center]res://art/icon_meal.png[/img] Pasto[/cell][cell]100[/cell][cell]3 giorni[/cell][cell]–[/cell]
[cell][img=center]res://art/icon_fine_meal.png[/img] Pasto squisito[/cell][cell]100[/cell][cell]3 giorni[/cell][cell]–[/cell]
[/table]
• Dura: a terra all'aperto a 15 °C; in un magazzino il doppio. Col caldo marcisce prima, col freddo dopo, sotto lo zero per niente (vedi Tetti e calore). Poi il mucchio marcisce e sparisce. I mucchi che si mescolano prendono la freschezza media. Col mouse sopra un mucchio: Fresco, Non più fresco o Quasi marcio, e i giorni che restano.
• Chi mangia crudo può restare Intossicato: la probabilità è minima quando il cibo è fresco, massima quando è quasi marcio.
• Un pasto dà Ben nutrito, un pasto squisito Lauto pasto (vedi Condizioni).

[color=#e8c34a]Cucinare[/color]
• A un fuoco da campo o a un focolare dentro una cucina. Il cuoco prende 2 crudi da un mucchio (vegetali, pesce o carne), cucina per 8 s e porta il pasto in un magazzino.
• Clicca il fuoco da campo: Tieni N pasti (8 all'inizio, 2 a testa). I cuochi cucinano finché ci sono meno pasti di così, contando quelli a terra, nei magazzini e in mano.
• Bruciato, e il cibo è perso: 6% per ogni livello di Cucinare sotto il 6, più 3% per ogni punto di comfort della cucina sotto 5 (meno, sopra). A livello 0 in una cucina con comfort 5: 36%.
• Pasto squisito: 5% per ogni livello sopra il 5, più 2% per ogni punto di comfort sopra 5 (meno, sotto): 25% a livello 10.
• Il tempo dipende anche dal comfort della cucina e dalle condizioni del cuoco."""],

	["Raccolta", """Segna cosa prendere con gli ordini della barra in basso, trascinando un rettangolo; le cose segnate portano un'icona tenue. Quello che si raccoglie cade ai piedi del lavoratore, che a lavoro finito lo porta in un magazzino.

[color=#e8c34a]Taglia (C)[/color] [img=center]res://art/icon_wood.png[/img]
Alberi: quercia 28 legna, pino 35, betulla 20. Un colpo ogni 10 s ne dà 5.

[color=#e8c34a]Scava (M)[/color] [img=center]res://art/icon_stone.png[/img]
Massi di 1x1, 2x1 o 2x2 caselle, 5 pietra a casella. Un colpo ogni 15 s ne dà 5. Le vene di ferro e di carbone sono massi 1x1 (col mouse sopra: "Vena di ferro", "Vena di carbone") che danno 5 ferro o 5 carbone al posto della pietra.

[color=#e8c34a]Estirpa (U)[/color]
Erbacce, cespugli e lino se ne vanno in 1,5 s. Toglili prima di costruirci sopra.

[color=#e8c34a]Raccogli (H)[/color] [img=center]res://art/icon_veg.png[/img] [img=center]res://art/icon_flax.png[/img]
Cespugli e lino. Un cespuglio maturo ha 5 bacche (vegetali), il lino in fiore 5 lino, colti uno ogni 5 s. Ricrescono in 2 giorni e il segno resta: si raccolgono ogni volta. Segnare Estirpa toglie il segno di Raccogli, e viceversa.

[color=#e8c34a]Orto (P)[/color] [img=center]res://art/icon_veg.png[/img]
• Dopo la ricerca Orto. Trascina sul prato libero, fuori dalle stanze, per fare le caselle dell'orto: prima vanno tolte erbacce e cespugli, e sull'orto non si costruisce. Rape e cavoli crescono a file alterne.
• Un colono semina una casella in 4 s (Raccogliere, come ogni tempo di lavoro). Le rape maturano in 60 giorni, i cavoli in 90, le fave in 100; poi la casella si risemina. Su terra media una casella dà 30 rape, 45 cavoli o 20 fave.
• Rape e cavoli si conservano molto più delle bacche, le fave secche più di tutto: il cibo dell'inverno (vedi Cibo).

[color=#e8c34a]Campi e rotazione[/color]
• Le caselle d'orto che si toccano fanno un campo, col cartello sulla casella in alto a sinistra. Clicca il campo: il suo nome, la sua timeline di quest'anno, cosa cresce l'anno prossimo, l'ultimo raccolto; "Pianifica i campi…" apre la pianificazione.
• La pianificazione è un grafico dell'anno, una riga per campo: ogni coltura è una barra lunga quanto cresce, seminata nel suo giorno. A righe la terra fredda prima del tardo Disgelo; in azzurro l'inverno. Clic su uno spazio vuoto per aggiungere una coltura: comincia subito dopo quella prima, e quelle che non finirebbero prima dell'inverno (o della coltura dopo) sono spente. Clic su una coltura per cambiarla o toglierla, sul nome di un campo per le rotazioni pronte (rape ogni anno; la classica: cavoli, poi rape, poi fave, poi un anno a maggese) e per il ciclo, da uno a quattro anni. ◀ ▶ mostrano gli anni dopo.
• A Capodanno ogni campo passa all'anno dopo del suo ciclo. Un colono semina una coltura nel suo giorno, appena la casella è libera e la terra tiepida; una coltura che non farebbe più in tempo a maturare prima dell'inverno si salta. Quello che è già seminato finisce di crescere; le caselle nuove accanto a un campo ne prendono il piano. Senza piano, rape, quante ne stanno nell'anno.

[color=#e8c34a]La terra[/color]
• Ogni casella ha la sua fertilità, che non si vede. È più ricca vicino all'acqua e più povera accanto alla roccia; abbattere un albero lascia l'humus. Più la terra è ricca, più il raccolto è grande.
• Ogni raccolto stanca la terra: i cavoli di più, le rape meno, mentre le fave la restituiscono. A Capodanno l'orto si riposa, e una casella senza raccolti per tutto l'anno (a maggese) si riprende molto.
• La stessa coltura due volte di fila su una casella rende un quarto in meno, dalla terza volta la metà: si alternano.
• Gli indizi: su terra povera le piante crescono smorte e giallastre; il cartello dice l'ultimo raccolto a casella; alla Festa del focolare la cronaca fa il bilancio del raccolto dell'anno, con quello dell'anno prima.
• I contadini imparano: un colono con almeno 5 in Raccogliere riconosce la terra delle caselle che semina o raccoglie, e il cartello dice cosa ne pensano i contadini (povera, media, ricca).
• Le ricerche la mostrano: il Saggio del terreno dà la lente della terra (O), povera, media o ricca su ogni casella, e la fascia sui cartelli; l'Almanacco agrario cinque fasce, e se un campo diventa più ricco o più povero di un anno fa; il Catasto i numeri esatti (sulla lente, da vicino) e il prossimo raccolto di ogni campo.
• Si comincia a seminare quando la terra è tiepida (6 °C di media del giorno, dal tardo Disgelo) e solo se il raccolto matura prima dell'inverno: i cavoli non si seminano negli ultimi 90 giorni prima dell'inverno, le rape negli ultimi 60. Il primo giorno d'inverno il gelo si prende quello che è ancora nei campi.
• Distruggi (X) toglie l'orto.

[color=#e8c34a]Concimi[/color] [img=center]res://art/icon_compost.png[/img]
• Dopo la ricerca Concimazione (Terra I, 80, dopo l'Orto). Costruisci un cumulo del compost (6 legna): da allora il cibo marcio e le erbacce estirpate diventano marcio [img=center]res://art/icon_rot.png[/img], che chi trasporta porta al cumulo; lasciato fuori sparisce nella terra in 5 giorni. Nel cumulo, in 10 giorni ogni 4 marci fanno un compost.
• La carbonaia lascia ogni volta una cenere [img=center]res://art/icon_ash.png[/img].
• I contadini concimano: da 15 giorni prima della semina di una casella ci spargono un compost (+15 di fertilità), o una cenere quando il compost è finito (+5). Una volta per semina. Togli la spunta a "Concimare prima della semina" sul cartello di un campo per saltarlo.
• Il sovescio: una coltura della pianificazione, 60 giorni. Fave che non si raccolgono ma si interrano in fiore: niente cibo, ma +20 di fertilità, il doppio delle fave che si mangiano.

[color=#e8c34a]Pesca (F)[/color] [img=center]res://art/icon_fish.png[/img]
Segna caselle d'acqua. Il pescatore si mette accanto (anche nell'acqua bassa) e lancia ogni 10 s: un pesce il 30% delle volte, +6% per ogni livello di Pescare. Un punto di pesca ha 4 pesci, poi è vuoto per un giorno; il segno resta.

[color=#e8c34a]Caccia (T)[/color] [img=center]res://art/icon_meat.png[/img] [img=center]res://art/icon_hide.png[/img]
• Trascina sopra gli animali per segnarli. Per cacciare serve un arco: un cacciatore che non ce l'ha va a prendere un arco libero e posa quello che aveva in mano. Se non ce n'è nessuno, se ne fa uno, appena si possono fare (Lavori dice "serve un arco").
• Il cacciatore tira da non più di 8 caselle, mirando 4 s a tiro. A segno: 30%, +5% a livello, -5% per ogni casella di distanza; poi +10% per l'arco e +5% per un cappuccio di cuoio.
• Una freccia fa 14 danni. Colpito o mancato, l'animale scappa di 8 caselle a velocità doppia, e il cacciatore lo segue. Abbattuto, lascia carne e pelle.
[table=4]
[cell][color=#d9c48a]Animale[/color][/cell][cell][color=#d9c48a]Salute[/color][/cell][cell][color=#d9c48a]Carne, pelle[/color][/cell][cell][color=#d9c48a]Velocità[/color][/cell]
[cell]Coniglio[/cell][cell]10[/cell][cell]3, 1[/cell][cell]2 caselle/s[/cell]
[cell]Cervo[/cell][cell]20[/cell][cell]10, 3[/cell][cell]1,5 caselle/s[/cell]
[cell]Lupo[/cell][cell]30[/cell][cell]5, 2[/cell][cell]3 caselle/s[/cell]
[/table]
Gli animali girano fuori dalle stanze e dall'acqua e nascono a più di 15 caselle dalla radura: all'inizio 6 conigli e 3 cervi, poi uno nuovo ogni mezza giornata finché sono meno di 12. Un lupo segnato, se gli si tira, attacca il cacciatore."""],

	["Lavorazioni ed equipaggiamento", """[color=#e8c34a]Postazioni[/color]
Clicca una postazione per il suo menu: una riga per ogni ricetta che conosci, coi suoi ingredienti e Tieni N. Si fa finché in giro ce ne sono meno di N (a terra, nei magazzini, in mano, in lavorazione); la Scorta vale per tutte le postazioni dello stesso tipo. L'equipaggiamento si fa anche per i coloni con uno slot vuoto, e un arco quando ci sono animali segnati e nessuno ne ha uno. All'inizio: Scorta 10 lingotti, 2 corde d'arco, 8 pasti, 0 per il resto.
L'artigiano porta gli ingredienti uno alla volta, poi lavora. Il tempo dipende da abilità, comfort della stanza e condizioni; un oggetto può rovinarsi, e gli ingredienti vanno persi, tanto spesso quanto brucia un pasto.
[table=4]
[cell][color=#d9c48a]Oggetto[/color][/cell][cell][color=#d9c48a]Postazione[/color][/cell][cell][color=#d9c48a]Ingredienti[/color][/cell][cell][color=#d9c48a]Tempo[/color][/cell]
[cell]Lingotto[/cell][cell]fornace[/cell][cell]1 ferro, 1 carbone[/cell][cell]6 s[/cell]
[cell]Corda d'arco[/cell][cell]filatoio[/cell][cell]2 lino[/cell][cell]8 s[/cell]
[cell]Armatura di cuoio[/cell][cell]banco da lavoro[/cell][cell]4 pelli[/cell][cell]20 s[/cell]
[cell]Cappuccio di cuoio[/cell][cell]banco da lavoro[/cell][cell]2 pelli[/cell][cell]12 s[/cell]
[cell]Arco[/cell][cell]banco del falegname[/cell][cell]3 legna, 1 corda d'arco[/cell][cell]15 s[/cell]
[cell]Piccone[/cell][cell]incudine[/cell][cell]2 lingotti, 2 legna[/cell][cell]15 s[/cell]
[cell]Ascia[/cell][cell]incudine[/cell][cell]2 lingotti, 2 legna[/cell][cell]15 s[/cell]
[cell]Falcetto[/cell][cell]incudine[/cell][cell]1 lingotto, 1 legna[/cell][cell]10 s[/cell]
[cell]Elmo[/cell][cell]incudine[/cell][cell]3 lingotti[/cell][cell]20 s[/cell]
[cell]Cotta di maglia[/cell][cell]incudine[/cell][cell]6 lingotti[/cell][cell]30 s[/cell]
[cell]Spada[/cell][cell]incudine[/cell][cell]3 lingotti, 1 legna[/cell][cell]20 s[/cell]
[/table]
Abilità: Forgiare a fornace e incudine, Cucire a filatoio e banco da lavoro, Tiro al banco del falegname.

[color=#e8c34a]Equipaggiamento[/color]
Tre slot: mani, corpo, testa. Un colono con uno slot vuoto va da sé a prendere un pezzo, prima di ogni altro lavoro. In mano vuole l'attrezzo della sua abilità migliore tra Estrarre, Tagliare legna, Raccogliere, Cacciare e Mischia. Nessuno cambia un pezzo con uno migliore; solo chi caccia lo cambia con un arco.
[table=4]
[cell][color=#d9c48a]Pezzo[/color][/cell][cell][color=#d9c48a]Slot[/color][/cell][cell][color=#d9c48a]Protezione[/color][/cell][cell][color=#d9c48a]Effetto[/color][/cell]
[cell]Piccone[/cell][cell]mani[/cell][cell]–[/cell][cell]scavo 25% più rapido[/cell]
[cell]Ascia[/cell][cell]mani[/cell][cell]–[/cell][cell]taglio 25% più rapido[/cell]
[cell]Falcetto[/cell][cell]mani[/cell][cell]–[/cell][cell]raccolta ed estirpazione 25% più rapide[/cell]
[cell]Arco[/cell][cell]mani[/cell][cell]–[/cell][cell]per cacciare; tira in combattimento[/cell]
[cell]Spada[/cell][cell]mani[/cell][cell]–[/cell][cell]danno in mischia 15[/cell]
[cell]Armatura di cuoio[/cell][cell]corpo[/cell][cell]2[/cell][cell]-25% stress all'aperto[/cell]
[cell]Cotta di maglia[/cell][cell]corpo[/cell][cell]5[/cell][cell]ogni lavoro 10% più lento[/cell]
[cell]Cappuccio di cuoio[/cell][cell]testa[/cell][cell]1[/cell][cell]+5% a segno con l'arco[/cell]
[cell]Elmo[/cell][cell]testa[/cell][cell]3[/cell][cell]scavo 10% più rapido[/cell]
[/table]
Anche gli attrezzi colpiscono: piccone 10, ascia 12, falcetto 8, mani nude 5. Protezione: vedi Combattimento e lupi."""],

	["Combattimento e lupi", """[color=#e8c34a]Lupi[/color]
• Il primo branco arriva il giorno 5, poi uno ogni 3 giorni: 2–3 lupi da un bordo della mappa. Fiutano la colonia da 70 caselle di distanza. La barra in alto mostra LUPI finché sono in giro.
• Inseguono il colono o l'avventuriero in piedi più vicino che sta fuori dalle stanze: i muri proteggono, i lupi non entrano mai. Se fuori non c'è nessuno in piedi, se la prendono con chi è a terra all'aperto.
• Un morso ogni 1,5 s fa 8 danni e va a segno il 70% delle volte, -3% per ogni livello di Mischia della vittima. Ogni morso dà anche +5 stress.
• Un branco senza nessuno da inseguire se ne va dopo un giorno.

[color=#e8c34a]Difendersi[/color]
• Un colono con un lupo entro 12 caselle lascia tutto e combatte contro il più vicino. Sotto 40 punti ferita invece corre nella stanza più vicina dove può entrare e lì aspetta; se non ce n'è una a portata, combatte.
• Mischia: un colpo ogni 1,5 s, a segno il 50% delle volte, +5% per ogni livello di Mischia sopra il 5 (meno, sotto). Il danno è quello di ciò che ha in mano: spada 15, ascia 12, piccone 10, pugnale 10, falcetto 8, mani nude 5.
• Arco: un tiro ogni 2 s da non più di 8 caselle, mirato come quello di un cacciatore, ma solo con Tiro; 14 danni. Colpito o mancato, il lupo si rivolta contro chi ha tirato.
• Protezione: -6% di danno per ogni punto, al massimo -80%. Cotta di maglia ed elmo (8 punti) tolgono il 48%.
• Un lupo morto lascia 5 carne e 2 pelli.

[color=#e8c34a]A terra e morti[/color]
• A 0 punti ferita un colono cade. Il morso che lo manda a terra uccide il 25% delle volte, -3% per ogni punto di protezione (almeno il 5%).
• A terra guarisce 40 al giorno e si rialza a 30. Un lupo che lo trova all'aperto, senza nessun altro in piedi, lo uccide al primo morso.
• I morti lasciano cadere il loro equipaggiamento; il corpo resta per un giorno. Gli altri coloni portano il lutto per 3 giorni (Lutto). Se muoiono tutti i coloni, la colonia è caduta."""],

	["Splendore", """Lo splendore è la somma di tutte le decorazioni finite sulla mappa, dentro o fuori dalle stanze, più 5 per ogni avventuriero famoso presente. Il totale è nella barra in alto.
Per ora fa due cose:
• Gli avventurieri arrivano più forti: livello 1, +1 ogni 10 di splendore, ±1 a caso (da 1 a 5).
• +1 autorità al giorno ogni 20 di splendore.
[table=4]
[cell][color=#d9c48a]Decorazione[/color][/cell][cell][color=#d9c48a]Splendore[/color][/cell][cell][color=#d9c48a]Costo[/color][/cell][cell][color=#d9c48a]Ricerca[/color][/cell]
[cell]Aiuola[/cell][cell]1[/cell][cell]3 legna[/cell][cell]Decorazioni[/cell]
[cell]Fioriera[/cell][cell]1[/cell][cell]5 pietra[/cell][cell]Decorazioni[/cell]
[cell]Panca[/cell][cell]1[/cell][cell]6 legna[/cell][cell]Decorazioni[/cell]
[cell]Lampione[/cell][cell]1[/cell][cell]3 legna, 1 carbone[/cell][cell]Lanterne[/cell]
[cell]Stendardo[/cell][cell]2[/cell][cell]4 legna[/cell][cell]–[/cell]
[cell]Fontana[/cell][cell]6[/cell][cell]30 pietra[/cell][cell]Fontana[/cell]
[cell]Statua[/cell][cell]8[/cell][cell]40 pietra[/cell][cell]Statuaria[/cell]
[cell]Calice[/cell][cell]3[/cell][cell]il cimelio[/cell][cell]–[/cell]
[cell]Stendardo antico[/cell][cell]4[/cell][cell]il cimelio[/cell][cell]–[/cell]
[cell]Busto[/cell][cell]5[/cell][cell]il cimelio[/cell][cell]–[/cell]
[cell]Corona[/cell][cell]6[/cell][cell]il cimelio[/cell][cell]–[/cell]
[/table]
• La panca (2x1) dà anche +0,5 di comfort alla stanza. Il lampione illumina le strade di notte. Lo stendardo sventola lo stemma della tua casata. Fontana e statua occupano 2x2 caselle.
• I cimeli li trovano solo gli avventurieri, nelle rovine. Arrivano a casa come oggetti: costruiscili dalla barra dei mobili, un cimelio per ogni pezzo."""],

	["Avventurieri", """[color=#e8c34a]La locanda[/color]
• La ricerca Locanda sblocca la bacheca. Una stanza con un letto, un tavolo e una bacheca può diventare una locanda.
• Ogni letto della locanda ospita un avventuriero. I letti della locanda sono solo loro, e loro non dormono altrove: senza un letto libero alla locanda, per terra.

[color=#e8c34a]Arrivi[/color]
• Ogni 2 giorni circa (±½) ne arriva uno dal bordo della mappa, se c'è un letto libero alla locanda (i letti di chi è via contano come occupati).
• Livello: 1, +1 ogni 10 di splendore, ±1 a caso, da 1 a 5.
• Aspettano 3 giorni che qualcuno li ingaggi, poi se ne vanno. Tornati da una spedizione riposano 2 giorni, e si possono ingaggiare di nuovo.
• Non lavorano: mangiano il tuo cibo, si svagano e combattono i lupi come i coloni (possono morire). Clicca su uno di loro per la sua scheda: classe, livello, paga, spedizioni.

[color=#e8c34a]Classi[/color]
• Guerriero: Mischia 2 a livello. Spada, scudo (+3 protezione), armatura di cuoio (cotta di maglia dal livello 3), elmo. Nelle rovine prende una parte doppia delle ferite.
• Arciere: Tiro 2 a livello. Arco, faretra, armatura e cappuccio di cuoio. Tira per primo: tutto il gruppo prende il 25% di ferite in meno; lui ne prende mezza parte.
• Scassinatore: Scassinare 2 a livello, Mischia 1 a livello. Pugnale, maschera, sacca, armatura e cappuccio di cuoio. Disinnesca le trappole e apre i forzieri chiusi; con la sacca porta a casa il 50% in più.

[color=#e8c34a]Paga[/color] [img=center]res://art/icon_coin.png[/img]
Ingaggiarli costa 10 monete, +5 a livello (15–35), pagate dai tuoi magazzini quando li mandi. Tornati a casa tengono il 30% delle monete trovate. +1 livello ogni 2 spedizioni tornate, fino a 5.

[color=#e8c34a]I loro talenti[/color]
Uno a testa, e 3 volte su 10 anche un talento dei coloni.
[table=2]
[cell]Avido[/cell][cell]chiede il 25% in più[/cell]
[cell]Leale[/cell][cell]non tiene la quota delle monete[/cell]
[cell]Temerario[/cell][cell]il gruppo torna indietro per lui sotto 20[/cell]
[cell]Codardo[/cell][cell]il gruppo torna indietro quando lui è sotto 60[/cell]
[cell]Fortunato[/cell][cell]un oggetto in più in ogni forziere[/cell]
[cell]Cartografo[/cell][cell]trova mappe 3 volte più spesso[/cell]
[cell]Iettato[/cell][cell]ogni trappola colpisce lui; chiede il 25% in meno[/cell]
[cell]Berserker[/cell][cell]l'arma conta doppio; +50% di ferite[/cell]
[cell]Robusto[/cell][cell]un terzo di ferite in meno[/cell]
[cell]Furtivo[/cell][cell]evita i mostri 1 volta su 4[/cell]
[cell]Medico[/cell][cell]+6 punti ferita a tutti dopo ogni stanza[/cell]
[cell]Raccoglitore[/cell][cell]il gruppo mangia un terzo in meno[/cell]
[cell]Guida[/cell][cell]il viaggio dura la metà[/cell]
[cell]Occhio di lince[/cell][cell]+30% a disinnescare le trappole[/cell]
[cell]Studioso[/cell][cell]un livello a ogni viaggio; libri il doppio delle volte[/cell]
[cell]Famoso[/cell][cell]+5 splendore finché è sulla mappa[/cell]
[/table]
Con un medico in piedi, chi cade viene riportato a casa. La furtività non funziona col guardiano del tesoro.

[color=#e8c34a]Chi resta[/color]
• Un avventuriero tornato alla locanda dalla sua terza spedizione, con almeno 60 di felicità, chiede di restare come colono. Una finestra te lo chiede: Accogli o No. Chiusa, la domanda aspetta sulla sua scheda (Rispondi…) finché è alla locanda; ingaggiato, la ritira.
• Se gli dici di no, lo richiede dopo altre 3 spedizioni.
• Accolto, diventa un colono: lavora, ha le sue priorità e dorme nei letti dei coloni. Tiene abilità, talenti ed equipaggiamento, che ora è della colonia: lo scudo del guerriero diventa uno scudo vero nel suo slot, lo scassinatore si toglie maschera e sacca, l'arciere tiene la faretra. Il famoso dà ancora splendore; gli altri talenti da avventuriero contano solo in spedizione. La scheda dice "Un tempo guerriero, livello 3".
• Per 5 giorni è Forestiero: -5 felicità, lavora il 10% più piano."""],

	["Rovine e spedizioni", """[color=#e8c34a]La bacheca[/color]
Cliccala: le monete e le provviste in magazzino, chi aspetta alla locanda (Scegli, fino a 4), le rovine che conosci, le spedizioni in corso e l'ultima pagina della cronaca. Ogni rovina ha il suo pulsante Manda, con le paghe e le provviste che servono; col mouse sopra, i giorni del viaggio.

[color=#e8c34a]Spedizioni[/color]
• Provviste: una a testa per ogni giorno del viaggio (andata, ½ giorno per ogni stanza che resta, ritorno), prima dal granaio della corona, poi dai magazzini, i pasti prima del crudo. Se non bastano, il gruppo parte lo stesso e patisce la fame: -20 punti ferita al giorno a testa.
• Vanno a piedi fino al bordo della mappa ed escono insieme; la barra in alto mostra SPEDIZIONI. Com'è andata lo leggi nel loro diario quando tornano (e nella Cronaca, con ingaggi e morti).
• Nella rovina, una stanza ogni ½ giorno: vuota (25%), una trappola (20%), mostri (35%), un forziere (15%) o un crollo (5%: tornano indietro).
• Mostri: forza 5 per ogni punto di pericolo. Più il gruppo è debole (abilità d'arma più protezione di ognuno), più le ferite sono profonde; poi la protezione di ognuno le attenua.
• Trappole: il migliore a scassinare ne disinnesca una il 20% delle volte, +8% a livello; se no, qualcuno prende 15 danni per ogni punto di pericolo.
• Forzieri: monete e uno degli oggetti della rovina o, il 35% delle volte, un libro. Metà sono chiusi a chiave, e si aprono solo con Scassinare almeno 2 per ogni punto di pericolo.
• L'ultima stanza è il tesoro, col suo guardiano (forza doppia): il triplo delle monete, i suoi libri e la mappa della rovina successiva. Se resta chiuso, quella stanza resta per la volta dopo.
• Tornano indietro quando qualcuno scende sotto 40 punti ferita, quando le provviste non bastano per un'altra stanza e il ritorno, o dopo un crollo.
• A 0 punti ferita si muore una volta su due; se no gli altri lo riportano a casa con 5 punti ferita (da solo, muore). Se cadono tutti la spedizione è persa: lo saprai quando sarà passato il doppio del tempo previsto.
• Tornati a casa, vanno alla locanda e lì lasciano il bottino ai tuoi trasportatori, tolta la loro quota delle monete.
• Le stanze ripulite restano ripulite: il gruppo dopo riparte da lì. Una rovina senza più stanze è esplorata.

[color=#e8c34a]Rovine[/color]
All'inizio conosci solo la torre. Ogni tesoro contiene la mappa della rovina successiva, e qualunque forziere può (15%) contenere la mappa di una che non conosci ancora. Il viaggio è indicato per la sola andata.
[table=4]
[cell][color=#d9c48a]Rovina[/color][/cell][cell][color=#d9c48a]Pericolo[/color][/cell][cell][color=#d9c48a]Stanze[/color][/cell][cell][color=#d9c48a]Viaggio[/color][/cell]
[cell]Torre diroccata[/cell][cell]1[/cell][cell]3[/cell][cell]½ giorno[/cell]
[cell]Miniera abbandonata[/cell][cell]2[/cell][cell]5[/cell][cell]1 giorno[/cell]
[cell]Cripta[/cell][cell]3[/cell][cell]6[/cell][cell]1 giorno[/cell]
[cell]Forte in rovina[/cell][cell]4[/cell][cell]8[/cell][cell]2 giorni[/cell]
[cell]Monastero sepolto[/cell][cell]3[/cell][cell]6[/cell][cell]1½ giorni[/cell]
[/table]
Monete in un forziere, il suo oggetto, il suo libro, e i libri del tesoro:
• Torre: 10–25; 10 legna, 10 pietra o 5 ferro; quaderni; 2 quaderni.
• Miniera: 20–45; 10 ferro, 10 carbone, 4 lingotti o un piccone; quaderni; 2 quaderni.
• Cripta: 35–70; una spada, un elmo, un'armatura di cuoio, 6 lingotti, il calice o il busto; quaderni o tomi; un tomo.
• Forte: 60–120; una cotta di maglia, 2 spade, un elmo, 10 lingotti, lo stendardo antico o la corona; tomi, 1 su 4 un codice; un codice.
• Monastero: 5–20; sempre un libro: metà quaderni, un quarto tomi, un quarto codici; un tomo e un codice."""],

	["Conoscenza", """[color=#e8c34a]Studio[/color] [img=center]res://art/icon_study.png[/img]
• Una stanza con uno scrittoio può diventare uno studio; lo scrittoio non richiede ricerche. Un colono allo scrittoio scrive pagine: ogni pagina è +1 studio per la riserva comune della colonia e +1 XP in Ricerca.
• Una pagina richiede 2,5 s, più o meno secondo il comfort della stanza e le condizioni. Dalle 19:00 alle 6:00, senza un abat-jour nella stanza, ci vuole il 50% in più; ogni libreria nella stanza toglie il 10% (fino a 3).
• I lavoratori dello studio studiano prima di ogni altro lavoro e restano allo scrittoio per tutto il turno. Gli altri scrivono una pagina solo quando non c'è altro da fare.

[color=#e8c34a]La finestra Conoscenza[/color]
Premi K o clicca uno scrittoio: il tuo studio e i libri nei tuoi magazzini, poi l'albero, una riga per ogni ramo e una colonna per ogni livello. Col mouse sopra una ricerca vedi cosa sblocca e cosa manca; cliccala per studiarla subito. Consuma lo studio e, dal livello II, un libro da un magazzino:
• Livello II: un quaderno [img=center]res://art/icon_notebook.png[/img]. Livello III: un tomo [img=center]res://art/icon_tome.png[/img]. Livello IV: un codice [img=center]res://art/icon_codex.png[/img].
I libri vengono solo dalle rovine (vedi Rovine e spedizioni). Non ci sono ancora ricerche di livello IV.
Quello che non hai studiato non ha il pulsante per costruirlo, e le sue ricette non compaiono alle postazioni. Dall'inizio hai muri e pavimenti di legno, porte, sentieri, letti, tavoli, sedie, fuochi da campo, stendardi, scrittoi, troni, cimeli e pasti.

[color=#e8c34a]L'albero[/color]
• [color=#d9c48a]Orto[/color] (Terra I, 80): le caselle dell'orto e i campi con la loro rotazione; rape in 60 giorni, cavoli in 90, fave in 100.
• [color=#d9c48a]Concimazione[/color] (Terra I, 80, dopo l'Orto): il cumulo del compost, il marcio e la cenere, concimare, il sovescio.
• [color=#d9c48a]Saggio del terreno[/color] (Terra I, 60, dopo l'Orto): la lente della terra, in tre fasce.
• [color=#d9c48a]Almanacco agrario[/color] (Terra II, 250 e un quaderno, dopo il Saggio): cinque fasce, e la tendenza di ogni campo.
• [color=#d9c48a]Catasto[/color] (Terra III, 450 e un tomo, dopo l'Almanacco): i numeri della terra e il prossimo raccolto.
• [color=#d9c48a]Caccia[/color] (Terra I, 50): filatoio e banco del falegname; corde d'arco e archi; pelli alle pareti e portiere.
• [color=#d9c48a]Ghiacciaia[/color] (Terra II, 250 e un quaderno, dopo Dispensa fredda): la ghiacciaia, la fossa del ghiaccio, il taglio del ghiaccio.
• [color=#d9c48a]Forgia[/color] (Fuoco I, 60): fornace e incudine; lingotti, piccone, ascia, falcetto.
• [color=#d9c48a]Sartoria[/color] (Fuoco I, 50): banco da lavoro; armatura e cappuccio di cuoio.
• [color=#d9c48a]Telaio[/color] (Fuoco II, 200 e un quaderno, dopo Sartoria): l'arazzo.
• [color=#d9c48a]Stufa a olle[/color] (Fuoco II, 300 e un quaderno, dopo Carbonaia e Muratura): la stufa a olle.
• [color=#d9c48a]Muratura[/color] (Pietra I, 60): muri e pavimenti di pietra; il focolare; l'intonaco.
• [color=#d9c48a]Decorazioni[/color] (Pietra I, 40): aiuola, fioriera, panca.
• [color=#d9c48a]Fontana[/color] (Pietra II, 250 e un quaderno, dopo Decorazioni): la fontana.
• [color=#d9c48a]Statuaria[/color] (Pietra III, 500 e un tomo, dopo Muratura): la statua.
• [color=#d9c48a]Armi di ferro[/color] (Ferro I, 80, dopo Forgia): spada ed elmo.
• [color=#d9c48a]Cotta di maglia[/color] (Ferro II, 300 e un quaderno, dopo Armi di ferro): la cotta di maglia.
• [color=#d9c48a]Locanda[/color] (Strada I, 40): la bacheca; le leggi Gabella sul bottino e Tassa di soggiorno.
• [color=#d9c48a]Libreria[/color] (Sapere I, 60): la libreria.
• [color=#d9c48a]Lanterne[/color] (Sapere I, 40): abat-jour e lampione."""],

	["Leggi", """[color=#e8c34a]Autorità[/color] [img=center]res://art/icon_authority.png[/img]
• La raccoglie solo il sovrano, tenendo udienza su un trono in una sala del trono: +1 all'ora, il 25% in più con felicità 70 o più, la metà con 30 o meno. Conta come lavoro.
• Il sovrano va al trono prima di tutto se lo spunti come lavoratore della sala del trono; se no, solo quando non ha altro da fare.
• Ogni giorno +1 per il titolo (Signoria) e +1 ogni 20 di splendore; +5 per ogni festa del raccolto.

[color=#e8c34a]La finestra Leggi[/color]
Premi G o clicca il trono: autorità, sigilli, il granaio della corona, poi le leggi per categoria. Col mouse sopra una legge vedi cosa fa e a chi piace.
• Codifica una legge una volta sola, pagandone il costo in autorità. Poi, con Promulga, la metti in vigore: 10 autorità e un sigillo libero. Una Signoria ha 2 sigilli.
• Le leggi dello stesso gruppo (tasse, turni, giustizia, accoglienza) si escludono a vicenda: promulgarne una sostituisce l'altra.
• Revocare è gratis, ma la legge non si può promulgare di nuovo per 3 giorni.
• Ogni legge in vigore cambia la felicità dei coloni (alcuni talenti la sentono in modo diverso) o degli avventurieri. Compare tra le condizioni nella scheda.
• Il granaio della corona lo riempie la Decima, e lì dentro non marcisce niente. Le provviste delle spedizioni si prendono prima da lì.

[color=#d9c48a]Tesoro[/color]
• Esenzione (30, tasse): niente decima, il granaio resta vuoto. Tutti +5.
• Decima (40, tasse): un pezzo su dieci di tutto ciò che si raccoglie, si pesca, si caccia, si cucina e si fa va al granaio. Tutti -3.
• Gabella sul bottino (40, ricerca Locanda): gli avventurieri tengono il 20% delle monete, non il 30%; ne arriva un quarto in meno, e mai gli avidi. Avventurieri -5.
• Tassa di soggiorno (30, ricerca Locanda): ogni avventuriero che aspetta alla locanda lascia una moneta a notte, e aspetta un giorno in meno. Avventurieri -3.
[color=#d9c48a]Lavoro[/color]
• Turni lunghi (40, turni): fino a 10 ore di lavoro al giorno (il pigro 7, lo stacanovista sempre 12); stress da lavoro +25%. Tutti -5, stacanovista +3; pigro, festaiolo e irrequieto -10.
• Giornata corta (40, turni): al massimo 6 ore di lavoro; stress da lavoro -25%. Tutti +8, stacanovista -5.
• Riposo festivo (30): nei giorni 7, 14, 21... non lavora nessuno tranne i cuochi. Tutti +6, stacanovista -5, asceta 0.
[color=#d9c48a]Ordine[/color]
• Coprifuoco (40): dalle 21:00 il tempo libero diventa sonno. Tutti -2, festaiolo -10, mattiniero +3.
[color=#d9c48a]Popolo[/color]
• Porte chiuse (30, accoglienza): nessuno chiede di restare, né avventurieri né viandanti (vedi Coloni, Nuovi coloni). Tutti +5.
• Porte aperte (40, accoglienza): gli avventurieri chiedono di restare dopo 2 spedizioni, i viandanti vengono il doppio delle volte; chi arriva è Forestiero per 10 giorni, non 5. Forestieri -5.
• Giuramento (80, una baronia): chi resta va nella sala del trono e sta un'ora in ginocchio, poi giura fedeltà: 10 autorità, e non è forestiero (senza sala del trono giura dove si trova; senza l'autorità resta forestiero). Chi ha giurato +5.
[color=#d9c48a]Feste[/color]
• Festa del raccolto (40): nei cinque giorni di festa del calendario (vedi Il tempo, in Le basi) non lavora nessuno tranne i cuochi. Il giorno dopo ogni colono è In festa (+10 felicità per 3 giorni) e ricevi 5 autorità."""],
]
