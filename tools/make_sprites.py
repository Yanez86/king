#!/usr/bin/env python3
"""Sprite disegnati come griglie di caratteri -> PNG in art/.
Esegui dalla cartella del progetto: python3 tools/make_sprites.py
"""
import struct
import zlib
from pathlib import Path

PALETTE = {
    "o": "1f1a24",                 # contorno
    "e": "1f1a24",                 # occhi
    "s": "e8b796", "S": "c98e6f",  # pelle, ombra
    "p": "4d4a5e", "P": "3a3848",  # calzamaglia, gamba lontana
    "b": "5b3a24",                 # stivali
    "l": "3b2a1e",                 # cintura
    "g": "e8c34a",                 # oro: fibbia, fermaglio
    # bianco/grigio: in gioco vengono tinti col colore del colono (modulate)
    "h": "ffffff", "H": "b0b0b0",  # capelli, ombra
    "t": "ffffff", "T": "b0b0b0",  # tunica, ombra
    "k": "ffffff", "K": "b0b0b0",  # mantello, ombra
    # alberi
    "y": "8fbf4f", "L": "5a9440", "m": "386b33", "d": "24452a",  # foglie quercia: luce -> ombra
    "q": "4f8a4a", "N": "2f6b45", "n": "1f4a36",                 # aghi pino
    "a": "b5d36a", "A": "7fae45", "v": "4e7d35",                 # foglie betulla
    "w": "7a5434", "W": "53381f",                                # corteccia, ombra
    "x": "e8e4d8", "X": "a8a49a",                                # corteccia betulla
    "z": "1f1a2460",                                             # ombra a terra (semitrasparente)
    # icone risorse
    "c": "d6ad6e", "C": "a87a45",                                # legno tagliato: venatura, anelli
    "u": "d0d0d8", "r": "9a99a6", "R": "6e6c7c", "i": "4a4858",  # pietra: luce -> ombra
    "G": "7a9a45", "M": "4f6b30",                                # muschio sulle rocce
    "V": "4f4b42", "Z": "3b3832",                                # ghiaia: base, ombra (i sassolini usano la pietra dei massi)
    ",": "4a7a3a", "-": "528544", ";": "345c2e",                 # erba: base, chiazza chiara, ombra
    "^": "66994a", "!": "86b556",                                # fili d'erba, punta al sole
    "*": "e8cf6a", "+": "e6e2d0",                                # fiorellini gialli e bianchi
    # acqua: increspature e luccichii li anima water.gdshader sui colori base ~ e #
    "~": "3f8394", ":": "37737f", "0": "d6ecec",                 # acqua bassa: base, fondale, schiuma della riva
    "#": "2c5470", "@": "244660",                                # acqua alta: base, più fondo
    "&": "5e5340", "$": "463e30",                                # riva: terra bagnata, ombra
    # magazzino (usa anche contorno, legno, pietra, casse e ombra qui sopra)
    "B": "9a6b40",                                               # assi: luce
    "F": "c8693f", "f": "a5502f", "D": "7a3826",                 # tegole: luce -> ombra
    "E": "34465a", "Q": "6a8aa8",                                # vetro, riflesso
    "Y": "8a8270",                                               # lanterna spenta
    "1": "9a6b40", "2": "7a5434", "3": "53381f",                 # assi che di notte prendono luce
    "j": "d84a3a", "J": "9a2a24",                                # rosso dell'icona "cancella": luce, ombra
    "I": "e8d6a0", "U": "c4ab70",                                # paralume dell'abat-jour spento: luce, ombra
    "%": "1f1a24cc",                                             # fondo dei popup (80%)
    "[": "d8d8d8", "]": "909090",                             # barre dei bisogni: base e ombra (sotto la luce h), tinte in gioco
    "4": "c98a52", "5": "8a4a2e",                                # ferro nella roccia: ruggine, ombra
    "6": "35313d", "7": "6e6a80",                                # carbone, riflesso
    "8": "ffe6a0", "9": "f2a03a", "=": "d8562f",                 # fuoco: cuore, fiamma, brace
    "<": "a87a2e",                                               # oro in ombra (cornice del tasto scelto)
    "(": "8f7550", ")": "6e5a3e", "_": "a8916a",                 # terra battuta del sentiero: base, ombra, luce
    "?": "e87aa0", "/": "7a8ae0",                                # fiori rosa e azzurri (aiuole, fioriere)
    "{": "4d4862", "}": "6f6a88", "|": "322e42",                 # quadratino dei talenti: fondo, luce, ombra
    "à": "2f5cb0", "á": "6a9ae0",                                # azzurro dell'araldica (libri, stemma), luce
    "è": "7a3c8e", "é": "a866bc",                                # porpora, luce
}

NIGHT_TINT = (0.40, 0.44, 0.62)  # di notte ogni colore si scurisce e vira al blu...
NIGHT_LIGHTS = {                 # ...tranne le luci
    "E": "f2b84a", "Q": "ffe6a0", "Y": "fff0b0",                 # finestre accese, lanterna
    "1": "c8904a", "2": "a06a36", "3": "7a4e28",                 # assi illuminate
    "I": "ffe6a0", "U": "f2b84a",                                # abat-jour acceso
}

# file -> caratteri che finiscono in quel livello
LAYERS = {
    "colonist_base": "oesSpPblg",
    "colonist_hair": "hH",
    "colonist_tunic": "tT",
    "colonist_cape": "kK",
}

# Ogni blocco: 16 righe, fotogrammi affiancati -> fermo, passo A, passo B, carica, colpo.
# Carica e colpo: azione generica per ogni lavoro (taglio, scavo, costruzione); nel colpo il busto si abbassa di 1px.
# Le mani sono vuote: quello che tengono (attrezzo, arma) è un livello a parte, vedi HANDS.
DOWN = """
................ ................ ................ ................ ................
.....oooooo..... .....oooooo..... .....oooooo..... .....oooooo..... ................
....ohhhhhho.... ....ohhhhhho.... ....ohhhhhho.... ....ohhhhhho.... .....oooooo.....
...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho... ....ohhhhhho....
...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhho...
...oHhhhsssHo... ...oHhhhsssHo... ...oHhhhsssHo... ...oHhhhsssHo... ...ohhhhhhhHo...
...oHsessesHo... ...oHsessesHo... ...oHsessesHo... ...oHsessesHoooo ...oHhhhsssHo...
....oSssssSo.... ....oSssssSo.... ....oSssssSo.... ....oSssssSo.oso ...oHsessesHo...
..okkkkggkkkko.. ..okkkkggkkkko.. ..okkkkggkkkko.. ..okkkkggkkkkoso ....oSssssSo....
..oKtTttttTtKo.. ..oKtTttttTtKo.. ..oKtTttttTtKo.. ..oKtTttttTtKoo. ..okkkkggkkkko..
..oKtTttttTtKo.. ..oKtTttttTtKo.. ..oKtTttttTtKo.. ..oKtTttttTtKo.. ..oKtTtsstTtKo..
..oKsllggllsKo.. ..oKsllggllsKo.. ..oKsllggllsKo.. ..oKtllgglltKo.. ..oKtllgglltKo..
..oKottttttoKo.. ..oKottttttoKo.. ..oKottttttoKo.. ..oKottttttoKo.. ..oKottttttoKo..
...oopPooPpoo... ...oopPoobboo... ...oobbooPpoo... ...oopPooPpoo... ...oopPooPpoo...
....obboobbo.... ....obbooooo.... ....ooooobbo.... ....obboobbo.... ....obboobbo....
....ooo..ooo.... ....ooo......... .........ooo.... ....ooo..ooo.... ....ooo..ooo....
"""

UP = """
................ ................ ................ ................ ................
.....oooooo..... .....oooooo..... .....oooooo..... .....oooooo..... ................
....ohhhhhho.... ....ohhhhhho.... ....ohhhhhho.... ....ohhhhhho.... .....oooooo.....
...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho... ....ohhhhhho....
...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho...
...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhho...
...oHhhhhhhHo... ...oHhhhhhhHo... ...oHhhhhhhHo... ...oHhhhhhhHoooo ...ohhhhhhhHo...
....oHHHHHHo.... ....oHHHHHHo.... ....oHHHHHHo.... ....oHHHHHHo.oso ...oHhhhhhhHo...
..okkkkkkkkkko.. ..okkkkkkkkkko.. ..okkkkkkkkkko.. ..okkkkkkkkkkoso ....oHHHHHHo....
..oKkkkkkkkkKo.. ..oKkkkkkkkkKo.. ..oKkkkkkkkkKo.. ..oKkkkkkkkkKoo. ..okkkkkkkkkko..
..oKkkKkkKkkKo.. ..oKkkKkkKkkKo.. ..oKkkKkkKkkKo.. ..oKkkKkkKkkKo.. ..oKkkkkkkkkKo..
..oKkkKkkKkkKo.. ..oKkkKkkKkkKo.. ..oKkkKkkKkkKo.. ..oKkkKkkKkkKo.. ..oskkKkkKkkKo..
..oKKkKkkKkKKo.. ..oKKkKkkKkKKo.. ..oKKkKkkKkKKo.. ..oKKkKkkKkKKo.. ..oKKkKkkKkKKo..
...oopPooPpoo... ...oopPoobboo... ...oobbooPpoo... ...oopPooPpoo... ...oopPooPpoo...
....obboobbo.... ....obbooooo.... ....ooooobbo.... ....obboobbo.... ....obboobbo....
....ooo..ooo.... ....ooo......... .........ooo.... ....ooo..ooo.... ....ooo..ooo....
"""

LEFT = """
................ ................ ................ ................ ................
.....oooooo..... .....oooooo..... .....oooooo..... .....oooooo..... ................
....ohhhhhho.... ....ohhhhhho.... ....ohhhhhho.... ....ohhhhhho.... .....oooooo.....
...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho... ....ohhhhhho....
...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhho...
...ohssshhhHo... ...ohssshhhHo... ...ohssshhhHo... ...ohssshhhHo... ...ohhhhhhhHo...
...osessShhHo... ...osessShhHo... ...osessShhHo... ...osessShhHooo. ...ohssshhhHo...
....ossSsHHo.... ....ossSsHHo.... ....ossSsHHo.... ....ossSsHHooso. ...osessShhHo...
....ogkkkkkko... ....ogkkkkkko... ....ogkkkkkko... ....ogkkkkkkoso. ....ossSsHHo....
....otTttTkko... ....ottTttkko... ....otttTtkko... ....otTttTkkoo.. ....ogkkkkkko...
....otTttTkKo... ....ottTttkKo... ....otttTtkKo... ....otTttTkKo... ...ossTttTkKo...
....oglsslkKo... ....ogllsskKo... ....osslllkKo... ....ogllllkKo... ....ogllllkKo...
....ottootkKKo.. ....otttookKKo.. ....oootttkKKo.. ....ottootkKKo.. ....ottootkKKo..
.....oppPoooo... ...oppoPPoooo... ...oPPoppoooo... .....oppPoooo... .....oppPoooo...
....obbbbo...... ..obbbobbo...... ..obbbobbo...... ....obbbbo...... ....obbbbo......
....oooooo...... ..oooooooo...... ..oooooooo...... ....oooooo...... ....oooooo......
"""

# Arco, stessi blocchi -> corda lenta (appena scoccato), teso con la freccia incoccata. Di fronte lo tiene di traverso
# davanti alla pancia e la freccia punta in giù; di spalle spuntano solo i flettenti e la punta sopra la testa.
BOW_DOWN = """
................ ................
.....oooooo..... .....oooooo.....
....ohhhhhho.... ....ohhhhhho....
...ohhhhhhhho... ...ohhhhhhhho...
...ohhhhhhhHo... ...ohhhhhhhHo...
...oHhhhsssHo... ...oHhhhsssHo...
...oHsessesHo... ...oHsessesHo...
....oSssssSo.... ....oSsossSo....
..okkkkggkkkko.. ..okkkxcsxkkko..
.ooKtTttttTtKoo. .ooKxxtcttxxKoo.
owxxxxxxxxxxxxwo owxxtTtcttTtxxwo
.owKslsggllsKwo. .owKsllcgllsKwo.
..owwwtsstwwwo.. ..owwwwcswwwwo..
...oooooooooo... ...oooocoooooo..
....obboobbo.... ....obbuobbo....
....ooo..ooo.... ....ooo..ooo....
"""

BOW_LEFT = """
................ ................
.....oooooo..... .....oooooo.....
....ohhhhhho.... ....ohhhhhho....
...ohhhhhhhho... ...ohhhhhhhho...
...ohhhhhhhHo... ...ohhhhhhhHo...
..oohssshhhHo... ..oohssshhhHo...
.owosessShhHo... .owxsessShhHo...
owx.ossSsHHo.... ow.xossSsHHo....
owx.ogkkkkkko... ow..xgkkkkkko...
owx.otTttTkko... uccccsTttTkko...
owstotTttTkKo... owstotTttTkKo...
owx.oglsslkKo... ow.xoglsslkKo...
.ow.ottootkKKo.. .owxottootkKKo..
..o..oppPoooo... ..o..oppPoooo...
....obbbbo...... ....obbbbo......
....oooooo...... ....oooooo......
"""

BOW_UP = """
................ .......u........
.....oooooo..... .....oooooo.....
....ohhhhhho.... ....ohhhhhho....
...ohhhhhhhho... ...ohhhhhhhho...
...ohhhhhhhho... .o.ohhhhhhhho.o.
...ohhhhhhhHo... .woohhhhhhhHoow.
.o.oHhhhhhhHo.o. .owoHhhhhhhHowo.
.wo.oHHHHHHo.ow. ..oxoHHHHHHoxo..
.owkkkkkkkkkkwo. ..ooxskkkksxoo..
..oxxskkkksxxo.. ..oKkkkkkkkkKo..
..oKkkKkkKkkKo.. ..oKkkKkkKkkKo..
..oKkkKkkKkkKo.. ..oKkkKkkKkkKo..
..oKKkKkkKkKKo.. ..oKKkKkkKkKKo..
...oopPooPpoo... ...oopPooPpoo...
....obboobbo.... ....obboobbo....
....ooo..ooo.... ....ooo..ooo....
"""

# ---- Livelli sopra il colono (stesso foglio 128x64 di sheet) ----
# Ogni disegno è fatto di timbri (colonna, riga, righe) dentro il fotogramma 16x16: "." è trasparente, quello che
# esce dal fotogramma si taglia. Le righe di un timbro sono separate da spazi o a capo.

# Acconciature, tinte col colore dei capelli (bianco/grigio): si aggiungono alla calotta di capelli di sheet().
# Per direzione (giù, sinistra, su) il fotogramma da fermo; negli altri si sposta col busto (vedi still_sheet).
HAIR_STYLES = {
    "long": {   # lunghi fino alle spalle
        "down": [(2, 7, ".oH......Ho. ohH......Hho ohH......Hho .oo......oo.")],
        "left": [(8, 7, "...Ho .hhHo ..hHo ..oo.")],
        "up": [(3, 7, "ohhhhhhhho ohhhhhhhho oHhhhhhhHo .oHhhhhHo. ..oooooo..")],
    },
    "braid": {  # treccia sulla schiena
        "down": [],
        "left": [(11, 7, "Hho. ohHo .oho .oHo .oho ..o.")],
        "up": [(6, 7, ".hh. ohHo oHho ohHo oHho .oo.")],
    },
    "beard": {
        "down": [(5, 6, "H....H HhhhhH ..hH")],
        "left": [(6, 6, "..H hhH h..")],
        "up": [],
    },
}

# Corredo degli avventurieri: come le acconciature, ma coi suoi colori.
KIT = {
    "shield": {  # scudo tondo di legno, bordo e borchia di ferro: sul braccio, dietro la schiena da su
        "down": [(0, 8, ".oooo. oRwwRo owwuwo owuuwo oRwwRo .oooo.")],
        "left": [(5, 8, ".oooo. oRwwRo owwuwo owuuwo oRwwRo .oooo.")],
        "up": [(5, 8, ".oooo. oRwwRo owwuwo owuuwo oRwwRo .oooo.")],
    },
    "quiver": {  # faretra sulla spalla destra: da giù se ne vedono le penne
        "down": [(1, 5, ".o.. oxo. oxo.")],
        "left": [(12, 4, ".o. oxo oxo owo owo oWo oWo oWo .o.")],
        "up": [(10, 5, ".o.o. oxoxo owwwo owWWo owWWo owWWo owWWo .ooo.")],
    },
    "mask": {  # fazzoletto scuro sul naso e sulla bocca, annodato dietro
        "down": [(5, 6, "6.66.6 666666")],
        "left": [(4, 6, "6.666 .6666")],
        "up": [(4, 6, "66666666")],
    },
    "pack": {  # sacco sulla schiena, da giù le cinghie
        "down": [(4, 8, "l......l l......l l......l")],
        "left": [(10, 7, "..ooo. .occco .occCo .ocCCo .oCCCo ..ooo.")],
        "up": [(4, 7, "..oooo.. .occcco. occcccCo occccCCo occcCCCo .oCCCCo. ..oooo..")],
    },
}

# In mano. Pose: "down_raise" (carica, anche da su), "down_strike", "left_raise", "left_strike", "up_strike" (colpo);
# "*_rest": nei fotogrammi senza lavoro (fermo, passo, respiro), per chi lo porta al fianco o sulla schiena.
# La mano che tiene: carica giù (14, 7), di lato (13, 7); colpo giù (7-8, 10), di lato (4-5, 10), su (3, 11).
# Senza niente in mano, nei lavori il colono usa un attrezzo qualunque ("tool"). Ordine = colonist_hands.png
HANDS = {
    "tool": {
        "down_raise": [(12, 0, "oooo ouro orRo .owo .owo .owo .owo")],
        "down_strike": [(5, 11, ".owWo. .owWo. ourrRo orRRRo oooooo")],
        "left_raise": [(11, 0, "ooooo ourro orRRo .owoo .owo. .owo. .owo.")],
        "left_strike": [(0, 8, "ooo. ouoo orww oRoo ooo.")],
        "up_strike": [(0, 9, "ooo ouo orw oRo ooo")],
    },
    "pickaxe": {
        "down_raise": [(10, 0, ".ooooo ouuurr .Roowr ...owo ...owo ...owo ...owo")],
        "down_strike": [(3, 11, ".o.owWo.o. oR.owWo.Ro oruuuuuuro .oooooooo.")],
        "left_raise": [(9, 0, ".ooooo. oruuuro oRoowoR .o.owoo ...owo. ...owo. ...owo.")],
        "left_strike": [(0, 7, "ooo. oRo. ouoo orww ouoo oRo. ooo.")],
        "up_strike": [(0, 8, "ooo oRo ouo orw ouo oRo ooo")],
    },
    "axe": {
        "down_raise": [(11, 0, ".oooo ouuwo orRwo .oowo ..owo ..owo ..owo")],
        "down_strike": [(3, 11, "...owWo .ooowWo ouuuwWo orrRooo .ooo...")],
        "left_raise": [(10, 0, ".oooo ouuwo orRwo .oowo ..owo ..owo ..owo")],
        "left_strike": [(0, 8, "ooo. ouoo ouww orRo oRo. oo..")],
        "up_strike": [(0, 9, "ooo ouo ouw oro oRo ooo")],
    },
    "sickle": {
        "down_raise": [(11, 1, ".ooo. ouuro ouowo oroWo .o.wo ...wo")],
        "down_strike": [(3, 11, "...owWo .o.owWo ouo.oro ourruRo .oooooo")],
        "left_raise": [(10, 0, ".ooo. ouuro ouowo oroWo .o.wo ...wo ...wo")],
        "left_strike": [(0, 7, ".oo. oruo ouoo ouww ooo.")],
        "up_strike": [(0, 8, ".oo oru ouo ouw ooo")],
    },
    "sword": {
        "down_raise": [(13, 0, ".o. ouo ouo ouo ouo oro g<g")],
        "down_strike": [(5, 11, "og<<go .ouro. .ouro. .ouro. ..oo..")],
        "left_raise": [(12, 0, ".o. ouo ouo ouo ouo oro g<g")],
        "left_strike": [(0, 9, "ooog uur< ooog")],
        "up_strike": [(0, 10, "oog ur< oog")],
        "down_rest": [(12, 8, ".o. ogo obo g<g obo obo .o.")],
        "left_rest": [(8, 9, ".o..... obo.... .ogo... ..olo.. ...olo. ....ogo .....o.")],
        "up_rest": [(1, 8, ".o. ogo obo g<g obo obo .o.")],
    },
    "bow": {  # legno chiaro, corda "+"; da fermo sulla schiena
        "down_raise": [(13, 0, ".o. .Co .+C .+C .+C .+C .+C ... ... .+C .+C .+C .+C .Co .o.")],
        "down_strike": [(2, 10, ".o........o. oC++++++++Co .oCCCCCCCCo. ..oooooooo..")],
        "left_raise": [(12, 0, ".o. .Co .+C .+C .+C .+C .+C ... ... .+C .+C .+C .+C .Co .o.")],
        "left_strike": [(0, 3, "..o. .oCo oC+. oC+. oC+. oC+. oC+. oC+. oC+. oC+. oC+. .oCo ..o.")],
        "up_strike": [(0, 4, "..o. .oCo oC+. oC+. oC+. oC+. oC+. oC+. oC+. oC+. oC+. .oCo")],
        "down_rest": [(1, 4, ".o. oCo oCo oCo"), (12, 11, ".o. oCo oCo .o.")],
        "left_rest": [(11, 4, ".o.. oCo. .+Co .+Co .+Co .+Co .+Co .+Co .+Co .+Co oCo. .o..")],
        "up_rest": [(4, 6, ".oo.. o+Co. o+oCo o+oCo o+oCo o+oCo o+oCo o+Co. .oo..")],
    },
    "dagger": {  # degli scassinatori
        "down_raise": [(13, 2, ".o. ouo ouo oro g<g")],
        "down_strike": [(6, 11, "g<<g ouro .oo.")],
        "left_raise": [(12, 2, ".o. ouo ouo oro g<g")],
        "left_strike": [(0, 9, ".oog our< .oog")],
        "up_strike": [(0, 10, ".og ou< .og")],
        "down_rest": [(12, 10, ".g. obo obo .o.")],
        "left_rest": [(8, 10, ".g. obo obo .o.")],
        "up_rest": [(2, 10, ".g. obo obo .o.")],
    },
}
BROW = 5  # riga della fronte nel fotogramma da fermo: sopra, l'elmo; sotto, i capelli restano fuori
# il cappuccio scende ai lati della faccia e sulle spalle; di lato fa la punta dietro
HOOD_MANTLE = {
    "down": [(3, 7, "oK......Ko"), (3, 8, "kkK....Kkk")],
    "left": [(10, 0, ".o.. .ko. .kKo"), (7, 8, "kkkK")],
    "up": [(4, 8, "kkkkkkkk")],
}
ON_THE_BACK = {"bow"}  # da fermo: si alzano e si abbassano col respiro; il resto sta al fianco
# copricapi e armature: ricavati dai capelli e dalla tunica di sheet() (vedi helmet, hood, armor)
GEAR_LAYERS = ["leather_armor", "chainmail", "helmet", "hood", "shield", "quiver", "mask", "pack"]  # = colonist_gear.png

TREES_HEIGHT = 32  # il tronco sta nella sua casella, la chioma sale in quella sopra

# Varianti affiancate -> quercia, pino, betulla. Alla base l'ombra della chioma col sole a picco: un ovale
# largo quasi quanto la chioma, centrato sul piede del tronco.
TREES = """
................ ................ ................
................ .......oo....... ................
.....oooooo..... ......oqNo...... ................
....oyyyLLmo.... ......oqno...... ................
...oyyLLLLmmo... .....oqqNno..... ................
..oyyLLLLLmmmo.. .....oqNnno..... ................
.oyLLLyLLLmmmmo. ....oqqNNnno.... ......oooo......
.oyLLyyLLmmmmmo. ...oqNNNnnnno... ....ooaaAAoo....
oyLLLLLLLmmmmmdo ...ooqqNNnnoo... ...oaaaAAAAvo...
oLLLLLLmmmmmmddo ...oqqNNNnnno... ..oaaAAAAAvvvo..
oLLLLdmmmmLmmddo ..oqqNNNNnnnno.. ..oaAAAaAAvvvo..
oLLLdmmmmLLLmddo .oqNNNNNnnnnnno. .oaAAAAAAAvvvvo.
.omLmmmmmLmdddo. ..ooqqNNnnnnoo.. .oAAAAaAAvvvvvo.
ommmmmmdmmmmdddo ..oqqNNNNnnnno.. .oAAAAAAvvvvvvo.
ommLmmddmmmddddo .oqqNNNNNnnnnno. .ovAAAAvvvvvvvo.
omLLmmmmmmmddddo oqqNNNNNNnnnnnno .ovvAvvvvvvvvvo.
ommmdmmmmmdddddo oooqqNNNNnnnnooo ..ovvvvvvvvvvo..
odmmmmmmmddddddo .oqqNNNNNnnnnno. ..ovvvvxXvvvvo..
.oddmmmmmdddddo. oqqNNNNNNnnnnnno ...ooooxXoooo...
..odddmmdddddo.. oqNNNNNnnnnnnnno ......oxXo......
...oddddddddo... .onnnnnnnnnnnno. ......oxXo......
....ooWWWWoo.... ..ooooowWooooo.. ......oxoo......
.....owwWWo..... ......owWo...... ......oxXo......
.....owWwWo..... ......owWo...... ......oxXo......
.....owwWWo..... ......owWo...... ......ooXo......
.....owwWWo..... ......owWo...... ......oxXo......
.....owwWWo..... ......owWo...... ......oxXo......
...zowwwWWWoz... ...zzowwWWozz... ....zoxxXXoz....
.zzzoooooooozzz. .zzzzoooooozzzz. ..zzzoooooozzz..
.zzzzzzzzzzzzzz. .zzzzzzzzzzzzzz. ..zzzzzzzzzzzz..
...zzzzzzzzzz... ...zzzzzzzzzz... ....zzzzzzzz....
................ ................ ................
"""


# Icone 16x16 per la barra risorse dell'HUD -> legno, pietra, vegetali (bacche). Base allineata sulla riga 14.
ICONS = """
................ ................ ................
......oooo...... ................ ................
.....owwwWo..... ................ ..........oo....
....owccccWo.... ......ooooo..... .........oLLo...
....owcCCcWo.... .....ouurrRoo... ........oLLmo...
....owcCCcWo.... ....ouurrrRRRo.. ......oWLmoo....
....owccccWo.... ...ourrrrRRRRo.. ......oWo.......
..ooooWWWWoooo.. ...ourrrRRRRio.. .....o+jjo......
.owwwWoooowwwWo. ...orrrRRRRiio.. .....ojjjo......
owccccWoowccccWo ..ooooRRRRiiio.. .....ojjJo......
owcCCcWoowcCCcWo .ouurRoRiiiooo.. ...oooooooo.....
owcCCcWoowcCCcWo ourrrRRoooourRo. ..o+jjoo+jjo....
owccccWoowccccWo orrrRRio.ourrRio ..ojjjoojjjo....
.oWWWWo..oWWWWo. oRRRRiio.orRRiio ..ojjJoojjJo....
..oooo....oooo.. .oooooo...ooooo. ...ooo..ooo.....
................ ................ ................
"""

# Icone 16x16 dei minerali, come ICONS -> ferro (pezzo di roccia con le pepite), carbone (tre pezzi).
ORE_ICONS = """
................ ................
................ ................
................ ................
................ ................
................ ................
......oooo...... ................
....oouu45oo.... ......oooo......
...ouuur55rRo... .....o7766o.....
..ourrrrrrR45o.. .....o7666o.....
..orr45rrRR55o.. .ooooo6666ooooo.
..oRr55RRRRRio.. .o77666oo77666o.
..oRRRRR45Riio.. .o76666oo76666o.
..oiRRRR55iiio.. .o66666oo66666o.
...oiiiiiiiio... ..o666o..o666o..
....oooooooo.... ...ooo....ooo...
................ ................
"""

# Pasti 16x16, come ICONS -> pasto (ciotola di legno con lo stufato e il vapore), pasto squisito (con le stelline d'oro).
MEALS = """
................ ...........g....
.....x....x..... ..g.......ggg...
......x....x.... .ggg.......g....
.....x....x..... ..g.............
......x....x.... ................
................ ................
..oooooooooooo.. ..oooooooooooo..
.ofF9fLfFf9LfFo. .ofF9fLfFf9LfFo.
.oFfLf9FfFLf9fo. .oFfLf9FfFLf9fo.
..owwwwwwwwwwo.. ..owwggggggwwo..
..owcwwwwwwwWo.. ..owcwwwwwwwWo..
...owwwwwwwWo... ...owwwwwwwWo...
....oWWWWWWo.... ....oWWWWWWo....
.....oooooo..... .....oooooo.....
................ ................
................ ................
"""

# Condizioni 16x16 nella scheda del colono (come Cond in main.gd) -> intossicato (faccia verde), ben nutrito (ciotola
# piena col cucchiaio), pasto squisito (ciotola con la stella), mangiato al tavolo (tavolo apparecchiato), mangiato
# crudo (bacca col segno rosso).
CONDITIONS = """
................ ..........oo.... .......o........ ................ ......jj....jj.. ................
.....oooooo..... .........oxo.... ......ogo....... ................ .......jj..jj... ................
...ooGGGGGGoo... ........oxo..... ....oogggoo..... ......oooo...... ........jjjj.... .....oooooo.....
..oGGGGGGGGGGo.. .......oxo...... ....oggggUo..... .....oxxxxo..... .........jj..... ....oruuuuRo....
..oGooGGGGooGo.. ......oxo....... .....ogggo...... ....oxXXXXxo.... ........jjjj.... ...oruuouuuRo...
.oGGGoGGGGoGGGo. ..oooooxoooooo.. .....ogoUo...... ....oxxxxxxo.... .......jj..jj... ...oruooouuRo...
.oGGGGGGGGGGGGo. .ofF9fLxFf9LfFo. ..oooooooooooo.. .....oooooo..... ......jj.oooojj. ...oruuouuuRo...
.oGGGGGGGGGGGGo. .oFfLf9FfFLf9fo. .ofF9fLfFf9LfFo. .oooooooooooooo. ........oyyLLo.. ...oruuouuuRo...
.oGGGoooooGGGGo. ..owwwwwwwwwwo.. .oFfLf9FfFLf9fo. .owwwwwwwwwwwwo. .......oyLL+jmo. ...oruuuuuuRo...
.oGGoGGGGGoGGGo. ..owcwwwwwwwWo.. ..owwwwwwwwwwo.. .oWWWWWWWWWWWWo. .......oyL+jJmo. ...orrrrrrrRo...
..oGGGGGGGGGGo.. ...owwwwwwwWo... ..owcwwwwwwwWo.. ..ow.o....ow.o.. .......oLLjJmmo. ..oooooooooooo..
..oMGGGGGGGGMo.. ....oWWWWWWo.... ...owwwwwwwWo... ..ow.o....ow.o.. .......oLmmmmdo. ..o,^,,,,,^,,o..
...ooMMMMMMoo... .....oooooo..... ....oWWWWWWo.... ..ow.o....ow.o.. ........oddddo.. ...oooooooooo...
.....oooooo..... ................ .....oooooo..... ..oo.o....oo.o.. .........oooo... ................
................ ................ ................ ................ ................ ................
................ ................ ................ ................ ................ ................
"""

# Condizione delle nozze (Cond.WEDDING): due anelli d'oro intrecciati.
WEDDING = """
................
................
........oooo....
.......ooIggoo..
....ooogIggggoo.
..ooggoggoooggo.
.oogIgogoo..ogo.
.ogIooogoo..ogo.
.ogo..oggoooggo.
.ogo..oggggggoo.
.oggooogggggoo..
.ooggggggooo....
..oogggoo.......
....oooo........
................
................
"""

# Condizione "forestiero" (Cond.FOREIGNER): il fagotto rosso a pois di chi viene da fuori, sul bastone.
FOREIGNER = """
................
..........oooo..
.........ojjjjo.
........ojxjjxJo
........ojjjjjJo
........ojjxjJJo
.........oJJJJo.
........owooo...
.......owo......
......owo.......
.....owo........
....owo.........
...owo..........
..owo...........
..oo............
................
"""

# Condizione "ispirato" (Cond.INSPIRED, un evento del narratore): una stella a quattro punte che brilla, e una piccola.
INSPIRED = """
.............o..
............oIo.
.......o...ooIoo
......oIo.oII8<<
......oIo..oo<oo
......oIo...o<o.
.....oIIIo...o..
..oooIIIg<ooo...
.oIIIII8<<<<<o..
..oooIg<<<ooo...
.....o<<<o......
......o<o.......
......o<o.......
......o<o.......
.......o........
................
"""

# Condizione "febbre" (Cond.FEVER, un evento del narratore): la faccia rossa, gli occhi chiusi, il panno bagnato sulla
# fronte e una goccia di sudore.
FEVER = """
................
.....oooooo.....
...ooxxxxxxoo...
..oxxxxxxxxxXo..
..oXXXXXXXXXXo..
.ojjjjjjjjjjjjo.
.ojooojjjjooojo.
.ojjjjjjjjjjQjo.
.ojjjjjjjjjjQjo.
.ojjjojojojjEjo.
..ojjjjjjjjjjo..
..oJjjjjjjjjJo..
...ooJJJJJJoo...
.....oooooo.....
................
................
"""

# L'armadio dei rimedi (Build.MEDICINE_CHEST): un mobiletto di legno con l'anta bianca e la croce rossa; con un letto
# fa di una stanza un'infermeria.
MEDICINE_CHEST = """
................
................
..oooooooooooo..
..oBBBBBBBBBBo..
..oooooooooooo..
..oBwwwwwwwwWo..
..oBwxxxxxxwWo..
..oBwxxjJxxwWo..
..oBwxjjjJxwWo..
..oBwxJJJJxwWo..
..oBwxxjJxxwWo..
..oBwxxxxxxwWo..
..oBwwwwwwwwWo..
..oooooooooooo..
..oWo......oWo..
...zzzzzzzzzz...
"""

# Icona 16x16 del lavoro Curare (Work.DOCTOR): la croce rossa, bordata di bianco.
DOCTOR_ICON = """
................
.....oooooo.....
.....oxxxxo.....
.....oxjJxo.....
.....oxjJxo.....
.oooooxjJxooooo.
.oxxxxxjJxxxxxo.
.oxjjjjjjjjjjxo.
.oxJJJJJJJJJJxo.
.oxxxxxjJxxxxxo.
.oooooxjJxooooo.
.....oxjJxo.....
.....oxjJxo.....
.....oxxxxo.....
.....oooooo.....
................
"""

# Condizione "medicato" (Cond.TREATED): un rotolo di bende, il capo svolto con la croce rossa.
TREATED = """
................
................
...oooooo.......
..oxxxxxxo......
.oxxXXXXxxo.....
.oxXoooXXxo.....
.oxXo.oXXxo.....
.oxXoooXXxo.....
.oxxXXXXxxooooo.
..oxxxxxxxxxxxxo
...oooooxxxjxxxo
........oxjjjxo.
........oxxjxxo.
.........ooooo..
................
................
"""

# La tomba (Build.GRAVE, 1x2): la fossa aperta o il tumulo di terra, con la croce di legno alla testa. Quattro colonne
# nel foglio dei mobili: aperta in piedi (16x32, la croce in alto), aperta coricata (32x16, la croce a sinistra), poi
# le stesse col tumulo (vedi piece_rects in main.gd: la colonna dice anche se c'è qualcuno sepolto)
GRAVE_CROSS = ["..oooo..", "..owWo..", "ooowWooo", "owwwwwwo", "oWWWWWWo", "ooowWooo", "..owWo..", "..owWo..", "..owWo.."]


def grave_pit(w, h, filled):
    """la fossa (o il tumulo) w x h: il bordo scuro, gli angoli tondi; dentro la terra"""
    rows = []
    for y in range(h):
        if y in (0, h - 1):
            rows.append(".." + "o" * (w - 4) + "..")
            continue
        line = ""
        for x in range(w):
            corner = y in (1, h - 2) and x in (0, w - 1)
            if corner:
                line += "."
            elif x in (0, w - 1) or (y in (1, h - 2) and x in (1, w - 2)):
                line += "o"
            elif filled:  # il tumulo: terra smossa, chiara in alto e a sinistra, in ombra a destra e in basso, qualche zolla
                if y <= 2 or x <= 2:
                    line += "_"
                elif x >= w - 3 or y >= h - 3:
                    line += ")"
                else:
                    line += ")" if (x * 7 + y * 3) % 11 == 0 else "("
            elif x in (1, w - 2) or y in (1, h - 2):  # la fossa: un orlo di terra, poi il buco in ombra
                line += "("
            else:
                line += "o" if y <= 3 else ("&" if y >= h - 4 else "$")
        rows.append(line)
    return rows


def grave(filled, upright):
    w, h = (16, 32) if upright else (32, 16)
    grid = [["."] * w for _ in range(h)]
    def paint(block, x0, y0):
        for y, line in enumerate(block):
            for x, ch in enumerate(line):
                if ch != ".":
                    grid[y0 + y][x0 + x] = ch
    if upright:
        paint(grave_pit(12, 20, filled), 2, 9)
        paint(["z" * 10], 3, 29)
        paint(GRAVE_CROSS, 4, 0)
    else:
        paint(grave_pit(22, 12, filled), 8, 2)
        paint(["z" * 20], 9, 14)
        paint(GRAVE_CROSS, 0, 3)
    return ["".join(row) for row in grid]


# Il memoriale dei caduti (Build.MEMORIAL, con la Statuaria): una stele di pietra sul suo basamento, la croce e le righe
# dei nomi incise.
MEMORIAL = """
................
......oooo......
.....ouuuuo.....
....ouuuuuro....
....ouuRuuro....
....ouRRRuro....
....ouuRuuro....
....ouuRuuro....
....ouRRRRro....
....ouuuuuro....
....ouRRRRro....
....ouuuuuro....
..oooooooooooo..
..ouuuuuuuurro..
..oooooooooooo..
...zzzzzzzzzz...
"""

# Condizione "ultimo saluto" (Cond.FAREWELL, la legge Funerali): una candela accesa sul suo piattino d'ottone.
FAREWELL = """
................
.......o........
......o9o.......
.....o989o......
.....o989o......
......o8o.......
.......o........
......oWo.......
.....oxxXo......
.....oxxXo......
.....oxxXo......
.....oxxXo......
...oooxxXooo....
...ogggggg<o....
....oooooooo....
................
"""

# La culla (Build.CRADLE): cassa di legno a dondolo, il lino dentro. Il neonato in fasce (BABY) ci si disegna sopra,
# o in braccio, piccolo; è anche l'icona della condizione "incinta" (Cond.PREGNANT).
CRADLE = """
................
................
................
..oooooooooooo..
.oBBBBBBBBBBBBo.
.oBwwwwwwwwwwBo.
.oBwxxxxxxxxwBo.
.oBwxxxxxxxxwBo.
.oBwxxxxxxxxwBo.
.oBwwwwwwwwwwBo.
.oWWWWWWWWWWWWo.
..oooooooooooo..
.oWo........oWo.
..oWWWWWWWWWWo..
...oooooooooo...
................
"""

BABY = """
................
................
................
................
......oooo......
.....osssso.....
.....oseseo.....
.....ossSso.....
....oxxxxxxo....
...oxxXxxxxxo...
...oxxxxXxxxo...
...oxxxxxxXxo...
....oxxxxxxo....
.....oooooo.....
................
................
"""

# Piante 16x16 -> erbaccia, cespuglio, cespuglio con le bacche, lino, lino in fiore (azzurro: si raccoglie), erbe
# medicinali, erbe in fiore (bianche: si raccolgono).
# Si attraversano, ma non ci si costruisce sopra.
PLANTS = """
................ ................ ................ ................ ................ ................ ................
................ ................ ................ ................ ................ ................ ................
................ ................ ................ ................ ......o......... ................ ................
................ ......oooo...... ......oooo...... ................ .....o/o...o.... ................ ................
..........o..... ....ooyyLLoo.... ....ooyyLLoo.... ......o......... ....o/*/o.o/o... ................ ................
.........o+o.... ...oyyLLLLmmo... ...oyyLL+jmmo... .....oAo...o.... ..o..o/o.o/*/o.. ................ ................
........o+++o... ..oyLLLyLLmmmo.. ..oyLLLyjJmmmo.. ..o...A...oAo... .o/o..A...o/o... ................ ......o...o.....
.........o+o.... ..oyLLyyLLmmmo.. ..oyLLyyLLmmmo.. .oAo..A....A.... o/*/o.A....A.o.. ......o...o..... .....o+o.o+o....
..........v..... .oyLLLLLLmmmmdo. .oyL+jLLLmm+jdo. ..A..oAo...A.o.. .o/o.oAo...Ao/o. .....oao.oao.... ....o+*+o+*+o...
..o.......v..o.. .oLLLLLmmmLmmdo. .oLLjJLmmmLjJdo. ..A...A.A..AoAo. ..A.o/*/o..o/*/o ..o..oAo.oAo.o.. ..o..o+o.o+o.o..
.oAo...o..v.oAo. oLLLmmmmLLLmmddo oLLLmmmmLLLmmddo ...A..A.A.A..A.. ...A.o/oA.A..o/o .oao.oAooAo.oao. .o*o.oAooAo.o*o.
.oAAo.oAo.v.oAAo oLLmmmmmmLmmdddo oL+jmmm+jLmm+jdo ...A..A.A.A.A... ...A..A.A.A..A.. .oAAooAAAAoooAo. .oAAooAAAAoooAo.
..oAAooAAovoAAo. omLmmmmmmmmddddo omjJmmmjJmmdjJdo ....A.A.AA..A... ....A.A.AA..A... ..oAAAaAAAAAAo.. ..oAAAaAAAAAAo..
...oAAvAAvvAAvo. .oddmmmmmdddddo. .oddmmmmmdddddo. ....A.AAA..A.... ....A.AAA..A.... ..ooAAAvAAvAoo.. ..ooAAAvAAvAoo..
..ooAvvvvvvvvoo. ..oooddddddooo.. ..oooddddddooo.. ....ooAvvvAoo... ....ooAvvvAoo... ....ooAvvvAoo... ....ooAvvvAoo...
....zzoooooozz.. ..zzzoooooozzz.. ..zzzoooooozzz.. ....zzoooooozz.. ....zzoooooozz.. ....zzoooooozz.. ....zzoooooozz..
"""

# Orto 16x16 (vedi garden in main.gd) -> terra lavorata a solchi, poi rape e cavoli: germoglio, che cresce, maturo.
# Le piante si disegnano sopra la terra; la rapa matura mostra la radice bianca e viola. Le mature sono anche le icone
# di rapa e cavolo raccolti (icon_turnip, icon_cabbage).
CROPS = """
)((()((()((()((( ................ ................ ......o..o...... ................ ................ ....oooooooo....
&)&&&)&&&)&&&)&) ................ ................ .....oyo.oyo.... ................ ................ ..ooaaaAAaaaoo..
&&&&&&r&&&&&&&&& ................ ......o..o...... ..o..oyLooLyo... ................ ................ .oaaAAaaaaAAaao.
$$$$$$$$$$$$$$$$ ................ .....oyo.oyo.... .oyo.oLyLLyLo.o. ................ ................ oaAAaaAAAAaaAAao
((()((()((()(()( ................ ..o..oyLooLyo... .oyLooLLyyLLooyo ................ ................ oaAaAAvAAvAAaAao
&&)&&&)&&&)&&&)& ................ .oyo.oLyLLyLo.o. ..oLLoLLLLLLoLLo ................ .....oooooo..... oaAAvAAaaAAvAAao
&&&&&&&&&&&&r&&& ................ .oyLooLLyyLLooyo ...oLLmLLLLmLLo. ................ ...ooaaAAaaoo... oAAvAAaaaaAAvAAo
$$$$$$$$$$$$$$$$ ................ ..oLLoLLLLLLoLLo ....ooommmmooo.. ................ ..oaaAAaaAAaao.. oAvAAaaAAaaAAvAo
)((()((()((()((( ......o..o...... ...oLLmLLLLmLLo. .....oéééé+o.... ......oooo...... ..oaAAvAAvAAao.. oAvAAAaaaaAAAvAo
&)&&&)&&&)&&&)&) .....oyooyo..... ....ooommmmooo.. ....oéèéé+++o... .....oaAAao..... ..oAAvAAAAvAAo.. .oAvvAAAAAAvvAo.
&&&r&&&&&&&&&&&& .....oyLLyo..... ......oooo...... ....oèèéé+++o... .....oAvvAo..... ...oAAvvvvAAo... ..oAvvvvvvvvAo..
$$$$$$$$$$$$$$$$ ......oLLo...... ................ ....oèèè++++o... ......oooo...... ....oooooooo.... ...oooooooooo...
((()((()((()(()( .......oo....... ................ .....oèè+++o.... ................ ................ ................
&&)&&&)&&&)&&&)& ................ ................ ......oooo...... ................ ................ ................
&&&&&&&&&&&&&&&& ................ ................ ................ ................ ................ ................
$$$$$$$$$$$$$$$$ ................ ................ ................ ................ ................ ................
"""

# Fave 16x16, come le altre colture di CROPS (vedi garden in main.gd) -> germoglio, pianta coi fiori bianchi e neri,
# matura: secca, coi baccelli scuri. La matura è anche l'icona delle fave secche (icon_beans).
BEANS = """
................ ......o.o....... ......o.o.......
................ .....oyoyo...... .....oWoWo......
................ ..o..oLyLo..o... ..o..owWwo..o...
................ .oyo..oLo..oyo.. .oWo..oWo..oWo..
................ .oLLo.oLo.oLLo.. .owwo.owo.owwo..
................ ..oLLooLooLLo... ..owwooWoowwo...
................ ...oo+oLo+oo.... ...oo6oWo6oo....
................ ....o+oLoo+o.... ...o66oWo66o....
.......o.o...... ...o+ooLo.o+o... ...o6ooWooo6o...
......oyoyo..... ..oLLooLooLLo... ..o66ooWoo66o...
......oLyLo..... ..oyLLoLoLLyo... ..o6iooWooi6o...
.......oLo...... ...ooooLoooo.... ...oooowoooo....
.......oLo...... ......oLo....... ......oWo.......
........o....... .......o........ .......o........
................ ................ ................
................ ................ ................
"""

# Paletto 16x16 col cartello di un campo dell'orto (vedi field_signs in main.gd): si clicca per coltura e rotazione.
FIELD_SIGN = """
................
................
..oooooooooooo..
..oBBBBBBBBBBo..
..oBcWWcWWWcWo..
..oBccccccccWo..
..oBcWWWcWWcWo..
..oWWWWWWWWWWo..
..oooooowooooo..
.......owo......
.......owo......
.......owo......
.......owo......
.......owo......
......zzozz.....
................
"""

# Icona 16x16 della lente della terra (tasto "Soil lens"): una zolla a strati, chiara, media e scura, con la lente sopra.
SOIL_ICON = """
................
.......oooo.....
......o0000o....
.....o00uu00o...
.....o0u0000o...
.....o000000o...
......o0000oo...
..oooooooooRio..
.o(((((((((oRio.
o___________oRo.
o(((((((((((o.o.
o)))))))))))o...
o$$$$$$$$$$$o...
.ooooooooooo....
................
................
"""

# Ricerche 12x12 della terra, come TECH_SYMBOLS: saggio del terreno (la paletta nella zolla), almanacco agrario (il libro
# col sole e la spiga), catasto (la mappa dei campi a riquadri)
TECH_SOIL = """
.......ooo.. ............ ............
......ouuo.. ..oooooooo.. .oooooooooo.
.....ouuo... .o9988899o.. .o_(_(o,-,o.
....ouRo.... .o898g898o.. .o(_(_o-,-o.
...owwo..... .o889g988o.. .ooooooooo..
..owwo...... .oggggggggo. .o,-,o_(_(o.
.ooooooooo.. .o8888888go. .o-,-o(_(_o.
o(((((((((o. .o8888888go. .oooooooooo.
o_________o. .ooooooooogo .o_(_o,-,-o.
o)))))))))o. ..oooooooooo .o(_(o-,-,o.
.ooooooooo.. ............ .oooooooooo.
............ ............ ............
"""

# Cumulo del compost 16x16 (vedi Build.COMPOST_HEAP in main.gd): un recinto basso di assi con dentro terra scura,
# paglia e qualche avanzo verde. Uguale girato.
COMPOST_HEAP = """
................
................
................
................
..o..o..o..o..o.
.owooWoowooWoowo
.ow)$$)$$G$$)wWo
.ow$$_$$$$_$$wWo
.oW$$)$MG$$)$wWo
.ow)$$$$$_$$$wWo
.owwwwwwwwwwwwWo
.oWWWWWWWWWWWWWo
.oooooooooooooo.
..zzzzzzzzzzzzz.
................
................
"""

# Icone 16x16 dei concimi -> marcio (avanzi andati a male, verdastri, con le mosche), compost (terra scura e
# grumosa), cenere (un mucchietto grigio)
MANURE_ICONS = """
................ ................ ................
....o.......o... ................ ................
...ooo.....o.o.. ................ ................
....o...o....... ................ ................
.......ooo...... ......oooo...... ................
....oooooooo.... ....oo$$)$oo.... ......oooo......
...oGMGM$$MGo... ...o$)$$$_$$o... ....oorurRoo....
..oMG$$GMG$$Mo.. ..o$$_$$)$$$$o.. ...oruuRrrRro...
..o$$MG$$$GM$o.. .o)$$$$$$_$)$$o. ..oruRrurRrRRo..
.o$GM$$MG$$M$$o. .o$_$)$$$$$$$_o. .orRrurRrRRrRio.
.oMG$$G$M$$GMMo. o$$$$$_$)$$$$$$o .oRrRrRrRRiRRio.
.ooooooooooooo.. oooooooooooooooo .oooooooooooooo.
................ ................ ................
................ ................ ................
................ ................ ................
................ ................ ................
"""

# Ricerca 12x12 della concimazione, come TECH_SYMBOLS: il cumulo del compost con un germoglio
# Compagnia della corona: la corona sulla bisaccia di chi parte
TECH_BARRACKS = """
.o........o.
ouo......ouo
.ouo....ouo.
..ouo..ouo..
...ouoouo...
....ouuo....
....ouuo....
..oouoouoo..
.oguo..ougo.
..ogo..ogo..
.olo....olo.
ogo......ogo
"""

TECH_COMPANY = """
.o...oo...o.
o8o.o88o.o8o
ogooogggoogo
oggggggggg<o
oooooooooooo
..oooooooo..
.owwwwwwwwo.
.oWWWgWWWWo.
.owwwwwwwwo.
.owwwwwwwWo.
.oWWWWWWWWo.
..oooooooo..
"""

# Erboristeria (Tech.HERBALISM): il mortaio di pietra col pestello, e una foglia
TECH_HERBALISM = """
.........oo.
..o.....owo.
.oao...owo..
oaAAo.owo...
oAAvoowo....
.ovvoowo....
oooooowooooo
ouuuuuWuuuro
ourrrrrrrrRo
.orrrrrrrRo.
..oRRRRRRo..
...oooooo...
"""

# Medicina (Tech.MEDICINE): il libro rosso del medico, con la croce bianca
TECH_MEDICINE = """
............
.oooooooooo.
.oJjjjjjjjo.
.oJjjxxjjjo.
.oJjjxxjjjo.
.oJxxxxxxjo.
.oJxxxxxxjo.
.oJjjxxjjjo.
.oJjjxxjjjo.
.oJjjjjjjjo.
.oxxxxxxxxo.
.oooooooooo.
"""

TECH_MANURE = """
.....o.o....
....oyoyo...
....oyLyo...
.....oLo....
.o..o.L.o..o
owoowooowoow
ow)$$G$$)$wo
ow$$_$$$$_wo
ow)$M$G$$$wo
owwwwwwwwwwo
oooooooooooo
............
"""

# Icona 16x16 dell'orto (tasto "Garden"): un germoglio su un cumulo di terra lavorata.
GARDEN_ICON = """
................
................
................
.....o...o......
....oyo.oyo.....
....oyLooLyo....
.....oLyyLo.....
......oLLo......
......oLLo......
....oooLLooo....
...o(((((((o....
..o&)&&&)&&&o...
.o&&&&r&&&&&&o..
.o$$$$$$$$$$$o..
..ooooooooooo...
................
"""

# Ricerca 12x12 dell'orto, come le altre in TECH_SYMBOLS: una rapa
TECH_GARDEN = """
...o..o.....
..oyooyo....
..oyLLyo....
...oLLo.....
..oéééé+o...
.oéèéé+++o..
.oèèéé+++o..
.oèèè++++o..
..oèè+++o...
...oo+oo....
.....o......
............
"""

# Icona 16x16 dell'azione "raccogli" (dopo "estirpa"): cestino di vimini pieno di bacche.
HARVEST_ICON = """
................
................
.....oooooo.....
....o......o....
...o...oo...o...
..o...ojjo...o..
.oo.ojjJojjo.oo.
ojjoojJooojJojjo
ojJjjooLLojjojJo
oooooooooooooooo
owcwcwcwcwcwcwco
.oCwCwCwCwCwCwo.
.owcwcwcwcwcwco.
..oCwCwCwCwCwo..
...oooooooooo...
................
"""

# Icone 16x16 dei cibi crudi di caccia e pesca, come ICONS -> carne (coscia con l'osso), pesce.
RAW_ICONS = """
................ ................
................ ................
.......oooo..... ................
.....oojjjjoo... ................
....ojjjjjjjJo.. .........ooo....
...ojjsjjjjjJJo. .oo....oouuuo...
...ojssjjjjjJJo. oRRo.oouuuuuuoo.
...ojjjjjjjJJJo. oRrRoouurruuueuo
...ojjjjjjJJJJo. .oRrrrrrrrrruuuo
....oJjjjJJJJo.. oRrRooRRrrrrrrro
.....oJJJJJJo... oRRo.ooRRRRRRoo.
.....oxxooooo... .oo....ooRRoo...
....oxxXo....... .........oo.....
...oxxXo........ ................
..oxXXo......... ................
..ooo........... ................
"""

# Icone 16x16 delle azioni "pesca" (canna con la lenza) e "caccia" (arco con la freccia), dopo "raccogli".
FISHING_ICON = """
................
............owWo
...........owWo.
..........owWox.
.........owWo.x.
........owWo..x.
.......owWo...x.
......owWo....x.
.....owWo.....x.
....owWo......x.
...owWo.......x.
..owWo.......ux.
.owWo.......uu..
oWWo............
oWo.............
.o..............
"""

HUNTING_ICON = """
................
.......oox......
.....oowox......
....owwo.x......
...owwo..x......
...owo...x......
..owwo...x......
..owo....x....o.
jjjjrrrrrrrrrruo
..owo....x....o.
..owwo...x......
...owo...x......
...owwo..x......
....owwo.x......
.....oowox......
.......oox......
"""

# Animali 16x16, di profilo verso destra (a sinistra si specchiano) -> righe: coniglio, cervo, lupo; colonne: fermo, passo.
ANIMALS = """
................ ................
................ ................
................ ................
................ ................
..........oo.o.. ...........oo.o.
.........ocCoCo. ..........ocCoCo
.........ocCoCo. ..........ocCoCo
..........occo.. ...........occo.
....ooooooccco.. ...oooooooocccco
...occccccccecoo ..occcccccccceco
..xoccccccccccoo .xocccccccccccoo
.xxocccccccccCo. xxoccccccccccco.
..ocCcccccccCCo. .ooCCoooooooCCo.
...oCCooooCCo... oCCo.......oCCo.
....oo....oo.... oo..........oo..
................ ................
...........C.C.. ...........C.C..
...........CoC.. ...........CoC..
............CC.. ............CC..
...........owwo. ...........owwo.
..........owwwwo ..........owwwwo
..........owewWo ..........owewWo
...........owwco ...........owwco
.ooooooooooowwo. .ooooooooooowwo.
owwwwwwwwwwwwwo. owwwwwwwwwwwwwo.
oxwwwwwwwwwwwWo. oxwwwwwwwwwwwWo.
.owccccccccccWo. .owccccccccccWo.
..oWWooooooWWo.. ..oWWooooooWWo..
..owo......owo.. .owo......owo...
..owo......owo.. owo......owo....
..oWo......oWo.. oWo......oWo....
..oo.......oo... oo.......oo.....
................ ................
................ ................
................ ................
................ ................
...........o.o.. ...........o.o..
..........oRoRo. ..........oRoRo.
..........orrrRo ..........orrrRo
oo........oreruo oo........oreruo
orooooooooorrRoo orooooooooorrRoo
.oorrrrrrrrrrRo. .oorrrrrrrrrrRo.
..orrrrrrrrrRRo. ..orrrrrrrrrRRo.
..ouuuuuuuurRRo. ..ouuuuuuuurRRo.
..oRRooooooRRo.. ..oRRooooooRRo..
..oRo......oRo.. .oRo......oRo...
..oRo......oRo.. oRo......oRo....
..oo.......oo... oo.......oo.....
"""

# Oggetti 16x16 di forgia e sartoria -> pelle, lingotto, falcetto, armatura di cuoio, cappuccio di cuoio, elmo, cotta
# di maglia. Piccone, ascia e arco usano le icone delle azioni "scava", "taglia" e "caccia".
ITEMS = """
................ ................ ................ ................ ................ ................ ................
.oo..........oo. ................ ......oooo...... ...ooo....ooo... ................ ................ ...ooo....ooo...
.occoooooooocco. ................ ....ooxxxXoo.... ..oCCCoooocCCo.. .....oooooo..... .......oo....... ..ourRoooourRo..
..occcccccccCo.. ................ ...oxXooooxXo... .oCccCCCCCCccCo. ....oCcccccoo... .....oouuoo..... .ourururururRro.
..occcCcccccco.. ................ ..oxXo....oXo... .oCcccccccccccCo ...oCccccccCCo.. ....ouuuurRo.... .orururururuRRo.
.occcccccCccccco ....oooooooo.... ..oxo......oo... .oCcccoccoccccCo ..oCcccccccccCo. ...ouuurrrRRo... .oruooruruooRRo.
.occCcccccccccCo ...ouuuuuuuRo... .oxXo........... .ooCccccgcccccoo ..oCccooooocCCo. ...ourrrrrRRo... .oo.oururuo.ooo.
..occccccCccco.. ..ouuuuuuuRRRo.. .oxXo........... ..oCccccccccCo.. ..oCco.....oCCo. ..ourrrrrrrRRo.. ...ourururuRo...
..occccccccccCo. .orrrrrrrrRRRio. .oxXo......o.... ..oCccccgcccCo.. ..oCco.....oCCo. ..orrrrrrrRRRo.. ...orururuRRo...
.occcCcccccccco. .orrrrrrrrRRiio. ..oxXo....owo... ..oCccccccccCo.. ..oCco.....oCCo. ..oRRoooooRRio.. ...ourururuRo...
.occcccccCccccco .oRRRRRRRRRiio.. ...oxXooooWwo... ..oCccccgcccCo.. ..oCcco...occCo. ..oRo.oRo.oRio.. ...orururuRRo...
..occccccccccCo. ..oooooooooooo.. ....ooXXXowo.... ..ollllllgllllo. ..oCcccoooccCCo. ..oRo.oRo.oRio.. ...ourururuRo...
.occooooooooocco ................ ......oooowo.... ..oCccccccccCo.. ...oCcccccccCo.. ..oio.oio.oiio.. ...orururuRRo...
.oo...........oo ................ .........owWo... ..oCCCCCCCCCCo.. ....ooooooooo... ..ooo.ooo.oooo.. ...oRRRRRRRRo...
................ ................ .........oWWo... ..oooooooooooo.. ................ ................ ...oooooooooo...
................ ................ ..........oo.... ................ ................ ................ ................
"""

# Spada 16x16, dall'incudine: arma per le armi da mischia.
SWORD = """
................
.............oo.
............ouuo
...........ouuro
..........ouuro.
.........ouuro..
........ouuro...
.......ouuro....
..oo..ouuro.....
..ogoouuro......
...oggrro.......
...oogoo........
..owoogo........
.owo..oo........
owo.............
oo..............
"""

# Bacheca degli incarichi 16x16 (locanda): avvisi appuntati su un'asse, su due pali.
NOTICE_BOARD = """
................
.oooooooooooooo.
.oBBBBBBBBBBBBo.
.oBwj++wwj++wWo.
.oBw+++ww+++wWo.
.oBw+++ww+++wWo.
.oBwwwwww+++wWo.
.oBw++jwwwwwwWo.
.oBw+++wwwwwwWo.
.oWWWWWWWWWWWWo.
.oooooooooooooo.
...owo....owo...
...owo....owo...
...oWo....oWo...
...oozzzzzzoo...
................
"""

# Monete d'oro 16x16, come ICONS: due pile.
GOLD = """
................
................
................
..oooooo........
.og88gg<o.......
.ogggg<<o.......
.o<<<<<<ooooooo.
.og<g<g<og88gg<o
.o<<<<<<ogggg<<o
.og<g<g<o<<<<<<o
.o<<<<<<og<g<g<o
.og<g<g<o<<<<<<o
.o<<<<<<oooooooo
.oooooooo.......
................
................
"""

# Pugnale 16x16, come SWORD ma corto, col manico di cuoio (degli scassinatori).
DAGGER = """
................
................
................
................
................
................
.............oo.
...........ouuro
......oo..ouuro.
......ogoouuro..
.......oggrro...
.......oogoo....
......oboogo....
.....obo..oo....
....obo.........
....oo..........
"""

# Cimeli 16x16, dalle rovine: calice d'argento, stendardo antico, busto di pietra, corona su un cuscino.
# Sono decorazioni (righe in fondo al foglio dei mobili) e oggetti in magazzino (icone)
CHALICE = """
................
....oooooooo....
...ouxuuuuurro..
..ouxuuuuuuurRo.
..ouxuuujuuurRo.
..ouuuuuuuuurRo.
...ouuuuuuurRo..
....oouuurRoo...
......ourRo.....
.......oRo......
.......oro......
......ouuro.....
.....ouuurRo....
....oruuuurRRo..
....oooooooooo..
....zzzzzzzzzz..
"""

OLD_BANNER = """
..ooo...........
..ogo...........
..owoooooooooo..
..ow//////////o.
..ow///gg/////o.
..ow//gggg////o.
..ow///gg/////o.
..ow//////////o.
..ow/}//////}/o.
..ow//o///o//o..
..ow/o.o/o.o/o..
..owo...o...o...
..ow............
..ow............
..oW............
.zzzz...........
"""

BUST = """
................
.....oooooo.....
....ouuuuuro....
....ouRuuRro....
....ouuuuuro....
....ouuruurRo...
.....oruurRo....
....ooouurRooo..
..oouuuuuuurRRoo
..ouuuuuuuurrRRo
..orrrrrrrrrRRRo
..oooooooooooooo
....orrrrrrRio..
....orrrrrrRio..
...oooooooooooo.
...zzzzzzzzzzzz.
"""

CROWN = """
................
................
..o....o....o...
.ojo..ogo..o/o..
.ogoooogooooogo.
.og8ggggg8gggg<o
.og8gjgg/gjggg<o
.og<<<<<<<<<<<<o
.oooooooooooooo.
oJjjjjjjjjjjjjJo
ojjjjjjjjjjjjjjo
oJjjjjjjjjjjjjJo
.oJJJJJJJJJJJJo.
.oooooooooooooo.
..zzzzzzzzzzzz..
................
"""

# Banco da lavoro 16x16 (sartoria): un pezzo di pelle e l'ago sul piano.
WORKBENCH = """
................
................
................
................
...ooooooo..o...
..ocCcCcCco.ox..
..oCcCcCcCooxo..
.oooooooooooooo.
.owwwwwwwwwwwWo.
.oWWWWWWWWWWWWo.
.oooooooooooooo.
..owo......owo..
..owo......owo..
..oWo......oWo..
..ooozzzzzzooo..
................
"""

# Filatoio 16x16 (corde d'arco dal lino): la rocca col lino a sinistra, la ruota coi raggi sulla panca.
SPINNING_WHEEL = """
................
.oo.....oooo....
oxXo..oowWwwoo..
oxxXo.ow.W..wo..
.oXo.ow..W...wo.
..wo.owWWoWWWwo.
..wo.ow..W...wo.
..wo..ow.W..wo..
..wo..oowWwwoo..
..wo....oooo....
..wo.....ow.....
.oooooooooooooo.
.owwwwwwwwwwwWo.
.oooooooooooooo.
..owo......owo..
..ooozzzzzzooo..
"""

# Banco del falegname 16x16 (archi): una sega su un'asse, la morsa di ferro sulla gamba sinistra.
CARPENTER_BENCH = """
................
................
................
....ooooooo.....
...ouuuuuuuoooo.
..orurururuowwWo
...oooooooooooo.
.oocCcCcCcCcCoo.
.owwwwwwwwwwwWo.
.oWWWWWWWWWWWWo.
.oooooooooooooo.
.orro......owo..
.oRRo......owo..
..owo......oWo..
..ooozzzzzzooo..
................
"""

# Icona 16x16 del lino: un mazzo di steli coi fiori azzurri, legato in mezzo.
FLAX_ICON = """
................
...o....o.......
..o/o..o/o..o...
.o/*/oo/*/oo/o..
..o/o..o/o.o/*/o
...Ao..oAo..o/o.
....A..A...Ao...
.....A.A..A.....
.....A.A.A......
.....oxxxo......
.....oXxXo......
....A.A.A.A.....
...A..A.A..A....
..A...A..A..A...
.oo..oo..oo..oo.
................
"""

# Icona 16x16 delle erbe medicinali (Res.HERBS): un mazzetto di rametti a foglie tonde, coi fiorellini bianchi.
HERBS_ICON = """
................
...o....o.......
..o+o..oao..o...
.o+*+ooaAaooao..
..o+o.oaAao.oAo.
...Ao..oAo..oAo.
....A..A...Ao...
.....A.A..A.....
.....A.A.A......
.....oxxxo......
.....oXxXo......
....A.A.A.A.....
...A..A.A..A....
..A...A..A..A...
.oo..oo..oo..oo.
................
"""

# Icona 16x16 dell'unguento (Res.OINTMENT): un vasetto di coccio aperto, pieno di unguento verde.
OINTMENT_ICON = """
................
................
................
....oooooooo....
...oGGGGGGGMo...
...occcccccCo...
....oCCCCCCo....
..occcccccccCo..
..occccccccCCo..
..occcccccCCCo..
..oCccccccCCCo..
...oCCCCCCCCo...
....oooooooo....
....zzzzzzzz....
................
................
"""

# Icona 16x16 della corda d'arco: una matassa di filo di lino, col capo che pende.
BOWSTRING_ICON = """
................
......oooo......
....ooxxxxoo....
...oxxXooXxxo...
..oxXoo..ooXxo..
..oxo.oooo.oxo..
.oxo.oxxxxo.oxo.
.oxo.oxooxo.oxo.
.oxo.oxooxo.oxo.
.oxo.oXxxXo.oxo.
..oxo.oooo.oxo..
..oxXoo..ooXxo..
...oxxXooXxxoxo.
....ooxxxxoo.oxo
......oooo....oo
................
"""

# Icone 16x16 delle azioni accanto a "distruggi" -> scava (piccone), taglia (ascia), estirpa (pianta con le radici).
def orders_icon():
    """Icona 16x16 del tasto Ordini: un piccone e un'ascia incrociati, i manici di legno, i ferri in alto; il contorno
    scuro attorno a tutto"""
    g = [["."] * 16 for _ in range(16)]
    for t in range(10):  # i manici: il piccone da in basso a destra in su a sinistra, l'ascia al contrario
        g[13 - t][12 - t], g[13 - t][13 - t] = "w", "W"
        g[13 - t][2 + t], g[13 - t][3 + t] = "w", "W"
    for k in range(6):  # il ferro del piccone, di traverso sulla cima del suo manico
        g[6 - k][k] = "u"
        if k < 5:
            g[6 - k][k + 1] = "r"
    for y, xs in ((1, range(10, 13)), (2, range(9, 14)), (3, range(9, 14)), (4, range(10, 13))):  # la lama dell'ascia
        for x in xs:
            g[y][x] = "u" if x < 12 else "R"
    for y in range(16):  # il contorno
        for x in range(16):
            if g[y][x] == "." and any(0 <= y + dy < 16 and 0 <= x + dx < 16 and g[y + dy][x + dx] not in ".o"
                                     for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g[y][x] = "o"
    return ["".join(r) for r in g]


def views_icon():
    """Icona 16x16 del tasto Viste: un occhio, il bianco, l'iride azzurra con la pupilla e il riflesso"""
    rows = []
    for y in range(16):
        line = ""
        for x in range(16):
            ex, ey = (x - 7.5) / 7.5, (y - 7.5) / 4.6  # la mandorla dell'occhio
            r = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
            if ex * ex + ey * ey > 1.0:
                inside_ring = ((x - 7.5) / 8.5) ** 2 + ((y - 7.5) / 5.6) ** 2 <= 1.0
                line += "o" if inside_ring else "."
            elif r < 1.2:
                line += "o"  # la pupilla
            elif r < 3.2:
                line += "u" if (x, y) == (6, 6) else "à"  # l'iride, col riflesso
            else:
                line += "+" if y < 8 else "x"
        rows.append(line)
    return rows


MINE_ICON = """
................
...ooooooo......
..ouuuuurrroo...
.ouroooooowRRo..
.oro....owwoRRo.
..o....owWo.oRo.
......owWo...oRo
.....owWo....oRo
....owWo......o.
...owWo.........
..owWo..........
.owWo...........
owWo............
oWo.............
.o..............
................
"""

CHOP_ICON = """
.......ooo......
......ouuro...oo
.....ouurrRoowWo
....ouurrRRowWo.
...ouurrRRowWo..
....oroRRowWo...
.....o.oowWo....
.......owWo.....
......owWo......
.....owWo.......
....owWo........
...owWo.........
..owWo..........
.owWo...........
owWo............
.oo.............
"""

UPROOT_ICON = """
................
..oo........oo..
.oAAo......oAAo.
.oAAAo....oAAvo.
..oAAvo..ovAvo..
...oAvvoovvAo...
....oovvvvoo....
......ovvo......
.....oowwoo.....
....owwwwWWo....
...owwwwwWWWo...
...owwwwWWWWo...
....ooWWWWoo....
.....C..C..C....
....C...C...C...
................
"""

# Icona "costruisci" 15x15, mostrata a 30x30: sega davanti, martello dietro.
CANCEL_ICON = """
................
................
..ooo......ooo..
.ojjjo....ojjjo.
.ojjjjo..ojjjjo.
..ojjjjoojjjjo..
...ojjjjjjjjo...
....ojjjjjjo....
....ojjjjjjo....
...ojjjjjjjjo...
..ojjjjJJjjjjo..
.ojjjjJooJjjjjo.
.ojjjJo..oJjjjo.
.oJJJo....oJJJo.
..ooo......ooo..
................
"""

# Icona "distruggi" 15x15, mostrata a 30x30: muro di mattoni che crolla.
DESTROY_ICON = """
..........oFFo.
.........oofDo.
........oFoooo.
.ooooo.o.o..ofo
oFFFFFoFo....o.
offfffoffo.....
.oooooooooo....
oFFoFFooFoFooo.
offoffoofoffffo
.oooooo.oooooo.
oFFFFFoooFFFoFo
offfffofooffofo
.oooooooo.oooo.
oFFoFFFFFoFFFFo
.oo.ooooo.oooo.
"""

# Usura di una casella di tetto (vedi draw_wear in main.gd), sopra coppi o scandole: licheni (vecchio ma integro),
# tegole smosse e muschio, il buco con le travi a vista
ROOF_WEAR = """
................ ................ ................
..+.........G... ..GG.......oo... ....oo.ooo......
................ .GMG......oGGo.. ...o666666o.....
......+......... ..G.......oMGo.. ..o6w66w666o....
.............+.. ..........oooo.. .o66w66w6666o...
...G............ ....oo.......... .oWWWWWWWWWWWo..
................ ...oGGoo....G... .o66w66w66w6o...
..........G..... ...oMMGo...GMG.. .o66w66w66w66o..
................ ....ooo.....G... o666w66w66w666o.
.....+.......... ................ oWWWWWWWWWWWWWo.
................ ..G.....oooo.... .o66w66w66w66o..
.............G.. .GMG...oGGMGo... ..o6w66w66w6o...
...+............ ..G....oMMMGo... ...oo66w66oo....
................ ........oooo.... .....oooooo.....
.........+...... ................ ................
................ ................ ................
"""

# Cartello 16x16 appeso al muro accanto alla porta di una stanza finita: cliccandolo si cambiano nome e tipo.
SIGN = """
................
................
................
................
................
..oooooooooooo..
..oBBBBBBBBBBo..
..oBgccccccgWo..
..oBcWWcWWWcWo..
..oBccccccccWo..
..oBcWWWcWWcWo..
..oBccccccccWo..
..oWWWWWWWWWWo..
..oooooooooooo..
...zzzzzzzzzzz..
................
"""

BUILD_ICON = """
.........o.....
........ouo....
.......oRruo...
........oRruo..
........ooRruo.
.......ocwoRruo
......ocwo.oRro
.....ocwo...oo.
.ooooooooooooo.
ouuuuuuuuowwwWo
orrrrrrrrrwooWo
oRRRRRRRRRwwWWo
orororororooooo
cooo.o.o.o.....
wo.............
"""

# Muri -> legno, pietra. Si collegano ai vicini (vedi wall): la cima si ripete in ogni direzione,
# la facciata (sotto la cima, righe 6-15) in orizzontale. Bordi e contorni li mette wall.
WALL_TOPS = """
cccccccccccccccc uuuuuuuruuuuuuur
ccccCccccccccccc uuuuuuuruuuuuuur
cccccccccccccccc uuuuuuuruuuuuuur
CCCCCCCCCCCCCCCC rrrrrrrrrrrrrrrr
cccccccccccccccc uuuruuuuuuuruuuu
cccccccccccCcccc uuuruuuuuuuruuuu
cccccccccccccccc uuuruuuuuuuruuuu
CCCCCCCCCCCCCCCC rrrrrrrrrrrrrrrr
cccccccccccccccc uuuuuuuruuuuuuur
ccCccccccccccccc uuuuuuuruuuuuuur
cccccccccccccccc uuuuuuuruuuuuuur
CCCCCCCCCCCCCCCC rrrrrrrrrrrrrrrr
cccccccccccccccc uuuruuuuuuuruuuu
cccccccCcccccccc uuuruuuuuuuruuuu
cccccccccccccccc uuuruuuuuuuruuuu
CCCCCCCCCCCCCCCC rrrrrrrrrrrrrrrr
"""

WALL_FRONTS = """
BwwWBwwWBwwWBwwW uuuuuuuRuuuuuuuR
BwwWBwwWBwwWBwwW rrrrrrrRrrrrrrrR
BlwWBwwWBlwWBwwW RRRRRRRRRRRRRRRR
BwwWBwwWBwwWBwwW uuuRuuuuuuuRuuuu
BwwWBwwWBwwWBwwW rrrRrrrrrrrRrrrr
BwwWBlwWBwwWBlwW RRRRRRRRRRRRRRRR
BwwWBwwWBwwWBwwW uuuuuuuRuuuuuuuR
BwwWBwwWBwwWBwwW rrrrrrrRrrrrrrrR
WWWWWWWWWWWWWWWW iiiiiiiiiiiiiiii
oooooooooooooooo oooooooooooooooo
"""

# Muro di legno intonacato (vedi Build.PLASTER in main.gd): la cima resta di assi, la facciata bianca a graticcio
PLASTER_FRONT = """
WWWWWWWWWWWWWWWW
WxxxxWxxxxxWxxxx
WxxxxWxxxxxWxxxx
WXxxxWXxxxxWXxxx
WWWWWWWWWWWWWWWW
WxxxxWxxxxxWxxxx
WxxxxWxxxxxWxxxx
WXxxxWXxxxxWXxxx
WWWWWWWWWWWWWWWW
oooooooooooooooo
"""

# Porta di legno -> di fronte (in un muro orizzontale), di lato (in un muro verticale, vista dall'alto).
DOORS = """
oooooooooooooooo occcccccccccccco
ccccCccccccccccc oCCCCCCCCCCCCCCo
cccccccccccccccc oooooooooooooooo
CCCCCCCCCCCCCCCC oZZZZZoBwWoZZZZo
cccccccccccccccc oZZZZZoBwWoZZZZo
oooooooooooooooo oZZZZZoBwWoZZZZo
WWoBwwBwwBwwBoWW oZZZZZoBwWoZZZZo
WWoBwwBwwBwwBoWW oZZZZZoBwgoZZZZo
WWoWWWWWWWWWWoWW oZZZZZoBwWoZZZZo
WWoBwwBwwBwwBoWW oZZZZZoBwWoZZZZo
WWoBwwBwwBwwgoWW oZZZZZoBwWoZZZZo
WWoBwwBwwBwwBoWW oZZZZZoBwWoZZZZo
WWoWWWWWWWWWWoWW oZZZZZoBwWoZZZZo
WWoBwwBwwBwwBoWW oooooooooooooooo
WWoBwwBwwBwwBoWW occcccccccccccco
oooooooooooooooo oCCCCCCCCCCCCCCo
"""

# Pavimenti: si ripetono senza giunte visibili tra caselle vicine.
FLOORS = """
BBBBBBBBBBBWBBBB urrrrrrRurrrrrrR ((((((((((())((( urrrrrrRiurrrrRi
BBBwBBBBBBBWBBBB rrrrrrrRrrrrrrrR ((__((_r(((((((( rrrrrrrRirrrrrRi
BBBBBBBBBBBWBBwB rrrrrrrRrrrrRrrR ((((((()(((ur((( rrrrrrrRirrrrrRi
WWWWWWWWWWWWWWWW rrRrrrrRrrrrrrrR (_ur(((((((R)((( rrrrrrrRirrrrrRi
BBBBWBBBBBBBBBBB rrrrrrrRrrrrrrrR ()R)(((((())(((( rrrrrrrRirrrrrRi
BBBBWBBBBBwBBBBB rrrrrrrRrrrrrrrR (((((r(((((((((( RRRRRRRRiRRRRRRi
BwBBWBBBBBBBBBBB rrrrrrrRrrrrrrrR ((((()(((ur((((( iiiiiiiiiiiiiiii
WWWWWWWWWWWWWWWW RRRRRRRRRRRRRRRR ((_((_(((R)(((r( rrRiurrrrrRiurrr
BBBBBBBBWBBBBBBB rrrRurrrrrrRurrr (r(((((((((((()( rrRirrrrrrRirrrr
BBBBBBBBWBBBBwBB rrrRrrrrrrrRrrrr ()(__(ur(((((((( rrRirrrrrrRirrrr
BBBwBBBBWBBBBBBB rrrRrrrrrRrRrrrr )()(((R)((((()() rrRirrrrrrRirrrr
WWWWWWWWWWWWWWWW rrrRrrrrrrrRrrrr ((((((_((((((()) rrRirrrrrrRirrrr
BBBBBBBBBBBBBBWB rRrRrrrrrrrRrrrr (_(((((((((((ur( rrRirrrrrrRirrrr
BBBBBwBBBBBBBBWB rrrRrrrrrrrRrrrr (((ur((((((((R)( rrRirrrrrrRirrrr
BBBBBBBBBBBBBBWB rrrRrrrrrrrRrrrr (((R)(((()r((((_ RRRiRRRRRRRiRRRR
WWWWWWWWWWWWWWWW RRRRRRRRRRRRRRRR (((__(((__)((((( iiiiiiiiiiiiiiii
"""

# Rocce: massi da 1x1, 2x1 e 2x2 caselle, disegnati dentro il loro ingombro.
ROCK_1X1 = """
................
................
......oooo......
....oouurroo....
...ouuurrrrRo...
..ouurrrrirrRo..
.ourrrrrirrRRRo.
.orrrrrrrrRRRio.
.oRrrrrrrRRRRio.
.oRRRRRRRRRRiio.
.oiRRRRRRRRiiio.
.oiiRRRRRiiiiio.
..oiiiiiiiiiio..
...oooooooooo...
..zzzzzzzzzzzz..
................
"""

# Massi 1x1 con dentro il ferro (pepite di ruggine) e il carbone (vene nere): si scavano come gli altri
ROCK_IRON = """
................
................
......oooo......
....oouurroo....
...ouu45rrrRo...
..ouuu55rirrRo..
.ourrrrrirr45Ro.
.orr45rrrrR55io.
.oRr55rrrRRRRio.
.oRRRRRR45RRiio.
.oiRRRRR55Riiio.
.oiiR45RRiiiiio.
..oii55iiiiiio..
...oooooooooo...
..zzzzzzzzzzzz..
................
"""

ROCK_COAL = """
................
................
......oooo......
....oouurroo....
...ouuu76rrRo...
..ouuu666irrRo..
.ourrrr66rr76Ro.
.orr76rrrrR666o.
.oRr666rrRRR66o.
.oRRR66RR76Riio.
.oiRRRRR666iiio.
.oiiRRRRR66iiio.
..oiiiiiiiiiio..
...oooooooooo...
..zzzzzzzzzzzz..
................
"""

ROCK_2X1 = """
................................
................................
.......oooooo...................
.....oouuurrroo.................
....ouuurrrrrrRo...oooooo.......
...ouurrrrirrrRRooouurrrRoo.....
..ourrrrrirrrrRRRourrrrrRRRo....
.orrrrrrrrrRRRRRiirrrrrrRRRRio..
oRRrrrrrrrRRRRRiiiRrrrrrrRRRiio.
oRRRRRRRRRRRRRiiiiRRRRRRRRRiiio.
oiRRRRRRRRRRiiiiiiRRRRRRRRiiiio.
oiiRRRRRRRRiiiiiiiiRRRRRRiiiiio.
.oiiiiiiiiiiiiiiiiiiiiiiiiiiio..
..ooooooooooooooooooooooooooo...
..zzzzzzzzzzzzzzzzzzzzzzzzzzzz..
................................
"""

ROCK_2X2 = """
................................
................................
..........oooooooooooo..........
........ooGGGGGGMMMuuroo........
......ooGGGGGGGGMMMMuurroo......
.....oMGGGGGGMMMMMuuuurrrro.....
....oMGGMMMMMuuuuuurrrrrrrRo....
...oMGMuuuuuuuuuurrrrrrrrRRio...
..oMGMuuuuuuuuurrrrrrrrRRRiio...
..oMMuuuuuuuurrrrrrrrrRRRRiiio..
.orMruuuuurrrrrrrrrrrRRRRiiiio..
.orrrrrrrrrrrrrrrrrrrrRRRiiiiio.
.oRRRRRRRRRRRRRRRRRRRRiiiiiiiio.
.orRRRRRRRRRRRRRRRRRRiiiiiiiiio.
.orrRRRRRRRiRRRRRRRRRiiiiiiiiio.
.orRRRRRRRRRiRRRRRRRRiiiiRiiiio.
.orRRRRRRRRRiiRRRRRRiiiiRRiiiio.
.oRRRRRRRRRRRiRRRRRRiiiiiiiiiio.
.oRRRRRRRRRRRRiRRRRRiiiiiiiiiio.
.oRRRRRRRRRRRRRRRRRiiiiiiiiiiio.
.oRRRRRRRRRRRRRRRRRiiiiiiiiiiio.
.oiRRRRRRRRRRRRRRRiiiiiiiiiiiio.
.oiRRRRRRRRRRRRRRiiiiiiiiiiiiio.
.oiiRRRRRRRRRRRRRiiiiiiiiiiiiio.
.oiiiRRRRRRRRRRRiiiiiiiiiiiiiio.
..oiiiRRRRRRRRRiiiiiiiiiiiiiiio.
..oiiiiiiiiiiiiiiiiiiiiiiiiiio..
...oiiiiiiiiiiiiiiiiiiiiiiiio...
....oooooooooooooooooooooooo....
...zzzzzzzzzzzzzzzzzzzzzzzzzzz..
......zzzzzzzzzzzzzzzzzzzzz.....
................................
"""

# Magazzino 64x32 (4x2 caselle): tetto di tegole, portone, finestre, lanterna, casse e botte.
# Una sola griglia: la versione notturna cambia solo palette (vedi NIGHT_TINT / NIGHT_LIGHTS).
WAREHOUSE = """
.....oooooooooooooooooooooooooooooooooooooooooooooooooooooo.....
....oBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBo....
....oWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWo....
...oFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFfDo...
...oFfDfffffDfffffDfffffDfffffDfffffDfffffDfffffDfffffDffffDo...
...oDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDo...
..oFFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFfDo..
..oFfffffDfffffDfffffDfffffDfffffDfffffDfffffDfffffDfffffDffDo..
..oDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDo..
.oFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFfDo.
.oFfffDfffffDfffffDfffffDfffffDfffffDfffffDfffffDfffffDffffffDo.
.oDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDo.
oFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFFFDFFFfDo
oFfDfffffDfffffDfffffDfffffDfffffDfffffDfffffDfffffDfffffDffffDo
oDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDo
oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
.olllllllllllllllllllllllllllllllllllllllllllllllllllllllllllloz
.ollBwwWBwwWBwwWBwwWBwwWllllllllllllllllBww3o2wWBwwWBwwWBwwWlloz
.ollBwlllllllllWBooooooollBBBBBBBBBBBBllBw2ooo2WBlllllllllwWlloz
.ollBwlQEElQEElWBoCcccCollwwWwwWBwWwwWllB22oYo23BlQEElQEElwWlloz
.ollBwlEEElEEElWBoCcccColliiiiiiiiiiiillB22oYo23BlEEElEEElwWlloz
.ollBwlllllllllWBoCCCCCollwwWwBBBBWwwWllB22ooo23BlllllllllwWlloz
.ollBwlQEElQEElWBoCcccCollwwWBBWBBBwwWllBw23122WBlQEElQEElwWlloz
.ollBwlEEElEEElWBoCcccCollwwBBiWBiBBwWllBwoooooWBlEEElEEElwWlloz
.ollBBB1111111BBoooooooollwBBwwWBwWBBWllBoBwwwWoBB1111111BBWlloz
.ollBWWWWWWWWWWWoCcccCoWllBBWwwWBwWwBBllBoiiiiioWWWWWWWWWWWWlloz
.ollBwwWBwwWBwwWoCcccCoWlliiiiiiiiiiiillBoBwwwWoBwwWBwwWBwwWlloz
.orrrriurrrriurroCCCCCorllwwWwwWBwWwwWllroBwwwWoiurrrriurrrriuoz
.oRiRRRRRiRRRRRioCcccCoRllwwWwwWBwWwwWllRoiiiiioRRRiRRRRRiRRRRoz
.ooooooooooooooooCcccCooooooooooooooooooooBwwwWooooooooooooooooz
..zzzzzzzzzzzzzzooooooozzzzzzzzzzzzzzzzzzzooooozzzzzzzzzzzzzzzzz
....zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz.
"""

# Mobili, disegnati dentro il loro ingombro come le rocce.
# Letto 2x1: testiera a sinistra, cuscino e lenzuolo rimboccato (corteccia di betulla), coperta trapuntata rossa.
BED = """
................................
.ooo............................
occco...........................
oBwWooooooooooooooooooooooooooo.
oBwWoxXXXXXXxxXjjjjjjjjjjjjjjjo.
oBwWoxXxxxxXxxXjjjjjJjjjjJjjjjo.
oBwWoxXxxxxXxxXjjjjjJjjjjJjjjjo.
oBwWoxXxxxxXxxXJJJJJJJJJJJJJJJo.
oBwWoxXxxxxXxxXjjjjjJjjjjJjjjjo.
oBwWoxXXXXXXxxXjjjjjJjjjjJjjjjo.
oBwWoxxxxxxxxxXjjjjjJjjjjJjjjjo.
oBwWoXXXXXXXXXXJJJJJJJJJJJJJJJo.
oBwWoBBBBBBBBBBBBBBBBBBBBBBBBBo.
oBwWowwwwwwwwwwwwwwwwwwwwwwwwWo.
oooooooooooooooooooooooooooooooz
..zzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
"""

# Tavolo 2x2: piano di assi chiare (venature e giunte sfalsate), bordo, gambe davanti con l'ombra sotto.
TABLE = """
................................
................................
.oooooooooooooooooooooooooooooo.
.occccccccccCccccccccccccccccco.
.occcCCCccccCcccccccCCCccccccco.
.occccccccccCccccccccccccccccco.
.oCCCCCCCCCCCCCCCCCCCCCCCCCCCCo.
.occccccccccccccccccccCccccccco.
.occcccccCCCccccccccccCcccCCcco.
.occccccccccccccccccccCccccccco.
.oCCCCCCCCCCCCCCCCCCCCCCCCCCCCo.
.occccccCccccccccccccccccccccco.
.occccccCcccccCCCcccccccCCCccco.
.occccccCccccccccccccccccccccco.
.oCCCCCCCCCCCCCCCCCCCCCCCCCCCCo.
.occccccccccccccccCccccccccccco.
.occCCCcccccccccccCccccCCCcccco.
.occccccccccccccccCccccccccccco.
.oCCCCCCCCCCCCCCCCCCCCCCCCCCCCo.
.occccccccccccccccccccccccCccco.
.occccccccCCCccccCCCccccccCccco.
.occccccccccccccccccccccccCccco.
.oBBBBBBBBBBBBBBBBBBBBBBBBBBBBo.
.oWWWWWWWWWWWWWWWWWWWWWWWWWWWWo.
.oooooooooooooooooooooooooooooo.
..owWozzzzzzzzzzzzzzzzzzzzowWo..
..owWozzzzzzzzzzzzzzzzzzzzowWo..
..owWozzzzzzzzzzzzzzzzzzzzowWo..
..owWozzzzzzzzzzzzzzzzzzzzowWo..
..oooozzzzzzzzzzzzzzzzzzzzoooo..
..zzzzzzzzzzzzzzzzzzzzzzzzzzzz..
................................
"""

# Sedia 1x1: schienale dietro, chi si siede guarda in giù.
CHAIR = """
................
...oooooooooo...
...oBBBBBBBBo...
...owwwwwwwWo...
...oWWWWWWWWo...
...oooooooooo...
...occcccccCo...
...ocCCccccCo...
...occcccccCo...
...oBBBBBBBBo...
...oWWWWWWWWo...
...oooooooooo...
...owozzzzowo...
...owozzzzowo...
...ooozzzzooo...
...zzzzzzzzzz...
"""

# Abat-jour 1x1: paralume, stelo d'ottone, base di legno. Di notte il paralume si accende (vedi NIGHT_LIGHTS).
LAMP = """
................
................
......oooo......
.....oIIIUo.....
.....oIIIUo.....
....oIIIIIUo....
....oIIIIIUo....
...oIIIIIIIUo...
...oUUUUUUUUo...
...oooooooooo...
......oggo......
......oggo......
.....ooggoo.....
....owwwwwWo....
....oooooooo....
...zzzzzzzzzz...
"""

# Fuoco da campo 1x1: cerchio di pietre, legna incrociata, fiamma. Rotondo: al posto dei quarti di giro, 4 fotogrammi
# della fiamma che guizza (vedi piece_rects in main.gd).
CAMPFIRE = """
................ ................ ................ ................
.......9........ ........9....... ......9......... ........9.......
.......99...9... ...9....99...... ......99..9..... ...9...99.......
......989...9... ...9...989...... ..9...989.99.... ...99.989....9..
....9.9889.99... ...99.9889..9... ..99.98899.9.... ....9.98899.99..
....998889999... ....998888999... ...9988889999... ....99888899....
....98888889.... ....98888889.... ....98888889.... ....98888889....
...=98888889=... ...=98888889=... ...=98888889=... ...=98888889=...
...=98888889=... ...=98888889=... ...=98888889=... ...=98888889=...
..ouo988889ouo.. ..ouo988889ouo.. ..ouo988889ouo.. ..ouo988889ouo..
.ourR=w99w=Rruo. .ourR=w99w=Rruo. .ourR=w99w=Rruo. .ourR=w99w=Rruo.
.oRio=WwwW=oiRo. .oRio=WwwW=oiRo. .oRio=WwwW=oiRo. .oRio=WwwW=oiRo.
.oiouuouuouuoio. .oiouuouuouuoio. .oiouuouuouuoio. .oiouuouuouuoio.
..ooRRoRRoRRoo.. ..ooRRoRRoRRoo.. ..ooRRoRRoRRoo.. ..ooRRoRRoRRoo..
...oooooooooo... ...oooooooooo... ...oooooooooo... ...oooooooooo...
..zzzzzzzzzzzz.. ..zzzzzzzzzzzz.. ..zzzzzzzzzzzz.. ..zzzzzzzzzzzz..
"""

# Fornace 1x1: cupola di pietra con la bocca accesa.
FURNACE = """
................
.....oooooo.....
....ouuuurRo....
...ourrrrrRRo...
...orrrrrrrRo...
..ourroooorRRo..
..orro9889oRRo..
..orro8888oRio..
..orro=99=oRio..
..orRooooooRio..
..oRRRRRRRRiio..
..oiRiRiRiRiio..
..oiiiiiiiiiio..
..oooooooooooo..
.zzzzzzzzzzzzzz.
................
"""

# Incudine 1x1 di ferro su un ceppo: il corno a sinistra (girata di un quarto, a destra).
ANVIL = """
................
................
................
................
...ooooooooooo..
.oouuuuuuuuuuRo.
orrrrrrrrrrrRRo.
.oooorrrrrrRRoo.
.....oRRRRio....
.....oiRRiio....
....oiiiiiiio...
...owwwwwwwwWo..
...owcwwwwcwWo..
...oWWWWWWWWWo..
...ooooooooooo..
..zzzzzzzzzzzz..
"""

# Letto girato: testiera in alto (vista di fronte), coperta che scende verso i piedi.
BED_UP = """
.oooooooooooooo.
.occcccccccccco.
.oBBBBBBBBBBBBo.
.owwwwwwwwwwwWo.
.owwwwwwwwwwwWo.
.oWWWWWWWWWWWWo.
.oooooooooooooo.
.oxxxxxxxxxxxxo.
.oxXXXXXXXXXXxo.
.oxXxxxxxxxxXxo.
.oxXxxxxxxxxXxo.
.oxXXXXXXXXXXxo.
.oxxxxxxxxxxxxo.
.oxxxxxxxxxxxxo.
.oXXXXXXXXXXXXo.
.ojjjjJjjjJjjjo.
.ojjjjJjjjJjjjo.
.ojjjjJjjjJjjjo.
.oJJJJJJJJJJJJo.
.ojjjjJjjjJjjjo.
.ojjjjJjjjJjjjo.
.ojjjjJjjjJjjjo.
.oJJJJJJJJJJJJo.
.ojjjjJjjjJjjjo.
.ojjjjJjjjJjjjo.
.ojjjjJjjjJjjjo.
.oJJJJJJJJJJJJo.
.oooooooooooooo.
.oBBBBBBBBBBBBo.
.owwwwwwwwwwwWo.
.oooooooooooooo.
..zzzzzzzzzzzzzz
"""

# Letto girato coi piedi in alto: la testiera sta davanti e copre il bordo del materasso.
BED_DOWN = """
................
.oooooooooooooo.
.ojjjjJjjjJjjjo.
.ojjjjJjjjJjjjo.
.ojjjjJjjjJjjjo.
.oJJJJJJJJJJJJo.
.ojjjjJjjjJjjjo.
.ojjjjJjjjJjjjo.
.ojjjjJjjjJjjjo.
.oJJJJJJJJJJJJo.
.ojjjjJjjjJjjjo.
.ojjjjJjjjJjjjo.
.ojjjjJjjjJjjjo.
.oXXXXXXXXXXXXo.
.oxxxxxxxxxxxxo.
.oxxxxxxxxxxxxo.
.oxXXXXXXXXXXxo.
.oxXxxxxxxxxXxo.
.oxXxxxxxxxxXxo.
.oxXXXXXXXXXXxo.
.oxxxxxxxxxxxxo.
.oooooooooooooo.
.occcccccccccco.
.oBBBBBBBBBBBBo.
.owwwwwwwwwwwWo.
.owwwwwwwwwwwWo.
.owwwwwwwwwwwWo.
.oWWWWWWWWWWWWo.
.oooooooooooooo.
..zzzzzzzzzzzzzz
................
................
"""

# Sedia girata a sinistra: schienale a destra, visto di taglio.
CHAIR_LEFT = """
.........oooo...
.........oBWo...
.........oBWo...
.........oBWo...
.........oBWo...
...oooooooBWo...
...occcccoBWo...
...ocCCccoBWo...
...occcccoBWo...
...oBBBBBBBBo...
...oWWWWWWWWo...
...oooooooooo...
...owozzzzowo...
...owozzzzowo...
...ooozzzzooo...
...zzzzzzzzzz...
"""

# Sedia girata in su: lo schienale sta davanti e copre il bordo del sedile.
CHAIR_UP = """
................
................
...oooooooooo...
...occcccccCo...
...ocCCccccCo...
...occcccccCo...
...oooooooooo...
...oBBBBBBBBo...
...owwwwwwwWo...
...owwwwwwwWo...
...oWWWWWWWWo...
...oooooooooo...
...owozzzzowo...
...owozzzzowo...
...ooozzzzooo...
...zzzzzzzzzz...
"""

# Decorazioni: danno splendore alla colonia (vedi SPLENDOR in main.gd).
# Aiuola 1x1: cassetta di assi con la terra e fiori di quattro colori.
FLOWER_BED = """
................
...?.....+......
..?g?...+g+.....
...?..*..+../...
...L.*b*.L./g/..
.ooLoo*ooLyo/oo.
.oBLyBLBBLBBLBo.
.oBL&yL&&L&yLwo.
.oBL$&L&$L&&Lwo.
.oBL&&L&&L&&Lwo.
.oBwwwwwwwwwwwo.
.oooooooooooooo.
.owwWwwwWwwwWWo.
.oWWWWWWWWWWWWo.
.oooooooooooooo.
..zzzzzzzzzzzzz.
"""

# Fioriera 1x1: vaso di pietra con fiori e foglie che ricadono.
PLANTER = """
........?.......
.....j.?g?.*....
....jgj.?.*b*...
.....j.LLL.*....
.....L.Ly.LL....
...oLyLoomLyo...
..omLuuuuuuLmo..
..mRRRRRRRRRim..
...orrrrrrRio...
...orrRrrrRio...
...orrrrrrRio...
....oRRRRRio....
.....oiiiio.....
....orrrrRRo....
....oooooooo....
...zzzzzzzzzz...
"""

# Panca 2x1 senza schienale, simmetrica: girata di mezzo giro non cambia.
BENCH = """
................................
................................
................................
................................
................................
..oooooooooooooooooooooooooooo..
..occcccccccccCccccccccccccCco..
..ocCCcccccccCccccccccCCCcccCo..
..oCCCCCCCCCCCCCCCCCCCCCCCCCCo..
..occccccCcccccccccccccCcccCco..
..oBBBBBBBBBBBBBBBBBBBBBBBBBBo..
..oWWWWWWWWWWWWWWWWWWWWWWWWWWo..
..oooooooooooooooooooooooooooo..
...owWozzzzzzzzzzzzzzzzzzowWo...
...ooooozzzzzzzzzzzzzzzzooooo...
....zzzzzzzzzzzzzzzzzzzzzzzz....
"""

# Panca girata di un quarto: il sedile lungo verso il basso, le gambe davanti.
BENCH_SIDE = """
................
................
....oooooooo....
....occcccco....
....occcccco....
....occCccco....
....occcccco....
....occcccco....
....occcccco....
....occcccco....
....oCCCCCCo....
....occcccco....
....occcccco....
....occCccco....
....occcccco....
....occcccco....
....occcccco....
....occcccco....
....oCCCCCCo....
....occcccco....
....occcccco....
....occCccco....
....occcccco....
....occcccco....
....occcccco....
....occcccco....
....oCCCCCCo....
....oBBBBBBo....
....oWWWWWWo....
....oooooooo....
....owzzzzwo....
....oozzzzoo....
"""

# Stendardo 1x1: asta, drappo rosso con la corona. Simmetrico: al posto dei quarti di giro, 4 fotogrammi
# della stoffa che ondeggia (vedi ANIMATED in main.gd). Sulla mappa il drappo ha i colori della casata: vedi
# banner_drape e banner_texture in main.gd.
BANNER = """
..ogo........... ..ogo........... ..ogo........... ..ogo...........
..owooooooooo... ..owooooooooo... ..owooooooooo... ..owooooooooo...
..owojjjJjjjo... ..owojjJjjjJo... ..owojJjjjJjo... ..owoJjjjJjjo...
..owojjjJjjjo... ..owojjJjjjJo... ..owojJjjjJjo... ..owoJjjjJjjo...
..owojgjgjgjo... ..owojgJgjgJo... ..owojgjgjgjo... ..owoJgjgJgjo...
..owojgggggjo... ..owojgggggJo... ..owojgggggjo... ..owoJgggggjo...
..owojjjJjjjo... ..owojjJjjjJo... ..owojJjjjJjo... ..owoJjjjJjjo...
..owojjjJjjjo... ..owojjJjjjJo... ..owojJjjjJjo... ..owoJjjjJjjo...
..owojjjJjjjo... ..owojjJjjjJo... ..owojJjjjJjo... ..owoJjjjJjjo...
..owojjjJjjjo... ..owojjJjjjJo... ..owojJjjjJjo... ..owoJjjjJjjo...
..owojjjojjjo... ..owojjJjjjJo... ..owojJjjjJjo... ..owoJjjoJjjo...
..owojjo.jjo.... ..owojooojoo.... ..owooojoooj.... ..owoojj.ojj....
..owooo..oo..... ..owoo...o...... ..owo..o...o.... ..owo.oo..oo....
.ooWoo.......... .ooWoo.......... .ooWoo.......... .ooWoo..........
.orrRo.......... .orrRo.......... .orrRo.......... .orrRo..........
.zzzzzzz........ .zzzzzzz........ .zzzzzzz........ .zzzzzzz........
"""

# Lampione 1x1: lanterna su un palo, per le strade. Di notte si accende (E, Q, Y in NIGHT_LIGHTS).
LANTERN = """
......oooo......
.....oggggo.....
....oooooooo....
....oEQYYEEo....
....oEYYYYEo....
....oEEYYEEo....
....oooooooo....
.....oggggo.....
......owWo......
......owWo......
......owWo......
......owWo......
......owWo......
....oorrrRoo....
....oooooooo....
...zzzzzzzzzz...
"""

# Fontana 2x2 (generata in tools, poi ritoccata): vasca di pietra, colonna con la coppa, zampillo.
# 4 fotogrammi: gocce che ricadono e cerchi nell'acqua.
FOUNTAIN = """
...............00............... ...............00............... ...............00............... ...............00...............
...............00............... ...............00............... ...............00............... ...............00...............
..............0000.............. ...............00............... ..............0000.............. ...............00...............
...............0~............... .............0.0~.0............. ...............0~............... .............0.0~.0.............
.............0.0~.0............. ...............0~............... .............0.0~.0............. ...............0~...............
...............0~............... ............0..0~..0............ ...............0~............... ............0..0~..0............
..........ooooo0~oooo........... ..........ooooo0~oooo........... ..........ooooo0~oooo........... ..........ooooo0~oooo...........
.......ooouo~~~~~~~~oooo........ .......ooouo~~~~~~~~oooo........ .......ooouo~~~~~~~~oooo........ .......ooouo~~~~~~~~oooo........
.....oouuuuoooooooooorrroo...... .....oouuuuoooooooooorrroo...... .....oouuuuoooooooooorrroo...... .....oouuuuoooooooooorrroo......
...oouuuuRRouurrrrrroRrrrroo.... ...oouuuuRRouurrrrrroRrrrroo.... ...oouuuuRRouurrrrrroRrrrroo.... ...oouuuuRRouurrrrrroRrrrroo....
..ouuuuRR:::oRRRRRRo::RRrrrro... ..ouuuuRR:::oRRRRRRo::RRrrrro... ..ouuuuRR:::oRRRRRRo::RRrrrro... ..ouuuuRR:::oRRRRRRo::RRrrrro...
.ouuuR::::::::ouro:::::::Rrrro.. .ouuuR::::::::ouro:::::::Rrrro.. .ouuuR::::::::ouro:::::::Rrrro.. .ouuuR::::::::ouro:::::::Rrrro..
.ouuR~~0~~~~~~ouro~~~~~~~~Rrro.. .ouuR~~~~~~~~~ouro~~~~~~~~Rrro.. .ouuR~~~~0~~~~ouro~~~~~~~~Rrro.. .ouuR~~~~~~~~~ouro~~~~~~~~Rrro..
ouuR~~~~~~~~~~ouro~~~~~~~~~Rrro. ouuR~~~~0~~~~~ouro~~~~~~~~~Rrro. ouuR~~~~~~~~~~ouro~~~~~~~~~Rrro. ouuR~~~~~~0~~~ouro~~~~~~~~~Rrro.
ouuR~~~~~~~~~~ouro~~~~~~~~~Rrro. ouuR~~~~~~~~~~ouro~~~~~~~~~Rrro. ouuR~~~~~~~~~~ouro~~~~~~~~~Rrro. ouuR~~~~~~~~~~ouro~~~~~~~~~Rrro.
ouur:~~~~0~~~~ouro~~~~~~~~:rrro. ouur:~~~~~~0~~ouro~~~~~~~~:rrro. ouur:~~~~0~~~~ouro~~~~~~~~:rrro. ouur:~~~~~~0~~ouro~~~~~~~~:rrro.
ouur::~~~~~~~~ouRo~~~~~~~::rrro. ouur::~~~~~~~~ouRo~~~0~~~::rrro. ouur::~~~~~~~~ouRo~~~~~~~::rrro. ouur::~~~~~~~~ouRo~0~~~~~::rrro.
orrrr::::~~~~~~~~~~~~~0:::rrrio. orrrr::::~~~~~~~~~~~~~::::rrrio. orrrr::::~~~~~~~~~~~0~::::rrrio. orrrr::::~~~~~~~~~~~~~::::rrrio.
oRRRRr:::::::~~~~~:::::::rRRRio. oRRRRr:::::::~~~~~:::::::rRRRio. oRRRRr:::::::~~~~~:::::::rRRRio. oRRRRr:::::::~~~~~:::::::rRRRio.
orrrrrrrr:::::::::::::rrrrrriio. orrrrrrrr:::::::::::::rrrrrriio. orrrrrrrr:::::::::::::rrrrrriio. orrrrrrrr:::::::::::::rrrrrriio.
orrrrrrrrrrrr:::::rrrrrrrriiiio. orrrrrrrrrrrr:::::rrrrrrrriiiio. orrrrrrrrrrrr:::::rrrrrrrriiiio. orrrrrrrrrrrr:::::rrrrrrrriiiio.
oRRRRRRRRRRRRrrrrrRRRRRRiiiiiio. oRRRRRRRRRRRRrrrrrRRRRRRiiiiiio. oRRRRRRRRRRRRrrrrrRRRRRRiiiiiio. oRRRRRRRRRRRRrrrrrRRRRRRiiiiiio.
orrrrrrrrrrrrrrrrrrrrRRRiiiiiio. orrrrrrrrrrrrrrrrrrrrRRRiiiiiio. orrrrrrrrrrrrrrrrrrrrRRRiiiiiio. orrrrrrrrrrrrrrrrrrrrRRRiiiiiio.
.orrrrrrrrrrrrrrrRRRRRRRiiiiioz. .orrrrrrrrrrrrrrrRRRRRRRiiiiioz. .orrrrrrrrrrrrrrrRRRRRRRiiiiioz. .orrrrrrrrrrrrrrrRRRRRRRiiiiioz.
.oRRRRRRRRRRRRRRRiiiiiiiiiiiio.. .oRRRRRRRRRRRRRRRiiiiiiiiiiiio.. .oRRRRRRRRRRRRRRRiiiiiiiiiiiio.. .oRRRRRRRRRRRRRRRiiiiiiiiiiiio..
..orrrrrrrrrrrrrrRRRRRRRiiiioz.. ..orrrrrrrrrrrrrrRRRRRRRiiiioz.. ..orrrrrrrrrrrrrrRRRRRRRiiiioz.. ..orrrrrrrrrrrrrrRRRRRRRiiiioz..
..zoorrrrrrrrrrrrRRRRRRRiiooz... ..zoorrrrrrrrrrrrRRRRRRRiiooz... ..zoorrrrrrrrrrrrRRRRRRRiiooz... ..zoorrrrrrrrrrrrRRRRRRRiiooz...
...zzooRRRRRRRRRRiiiiiiioozz.... ...zzooRRRRRRRRRRiiiiiiioozz.... ...zzooRRRRRRRRRRiiiiiiioozz.... ...zzooRRRRRRRRRRiiiiiiioozz....
.....zzooorrrrrrrRRRRooozz...... .....zzooorrrrrrrRRRRooozz...... .....zzooorrrrrrrRRRRooozz...... .....zzooorrrrrrrRRRRooozz......
.......zzzooooooooooozzz........ .......zzzooooooooooozzz........ .......zzzooooooooooozzz........ .......zzzooooooooooozzz........
..........zzzzzzzzzzz........... ..........zzzzzzzzzzz........... ..........zzzzzzzzzzz........... ..........zzzzzzzzzzz...........
................................ ................................ ................................ ................................
"""

# Statua del re 2x2 su un piedistallo con la targa d'oro, le mani sulla spada.
STATUE = """
................................
.............og.g.go............
.............ogggggo............
.............ouuuurRo...........
.............ouiuiRRo...........
.............ouuuurRo...........
..............ourRRo............
...........ooouuurRRooo.........
..........ouuuuuurrRRRo.........
..........ouuuurrrrRRRo.........
..........ourroggogRRRo.........
..........ourrrouoRRRRo.........
..........ourrrouoRRRio.........
..........ourrrouoRRRio.........
.........ourrrrouoRRRRio........
.........ourrrrrorRRRRio........
.........orrrrrrrRRRRRio........
........orrrrrrrRRRRRRio........
........oooooooooooooooo........
......oooooooooooooooooooo......
......ouuuuuuuuuuuuuuuurRo......
......oooooooooooooooooooo......
.......orrrrrrrrrrrrrrrRo.......
.......orRRRRRRRRRRRRRRio.......
.......orR<gggggggggg<Rio.......
.......orR<<<<<<<<<<<<Rio.......
.......orRRRRRRRRRRRRRRio.......
.......orrrrrrrrrrrrrrRRo.......
......oooooooooooooooooooo......
......ouuuuuuuuuuuuuuuuRRo......
......oooooooooooooooooooo......
.......zzzzzzzzzzzzzzzzzzzz.....
"""

# Cornice dei popup (9 slice, margini 4px): luce in alto a sinistra, ombra in basso a destra,
# filo scuro interno = pannello incassato. Il centro si allunga.
WOOD_FRAME = """
ooooooooo
oCCCCCCwo
oCwwwwwWo
oCwoooWWo
oCwo%oWWo
oCwoooWWo
oCwwwwwWo
owWWWWWWo
ooooooooo
"""

# Icona "attività in coda": tavoletta di legno con fermaglio d'oro e foglio con l'elenco.
JOBS_ICON = """
................
......oooo......
.ooooogggggoooo.
.oBBBoggggoBBWo.
.oBxxxooooxxxWo.
.oBxRRxRRRRxxWo.
.oBxxxxxxxxxxWo.
.oBxRRxRRRxxxWo.
.oBxxxxxxxxxxWo.
.oBxRRxRRRRxxWo.
.oBxxxxxxxxxxWo.
.oBxRRxRRxxxxWo.
.oBxxxxxxxxxxWo.
.oBXXXXXXXXXXWo.
.oWWWWWWWWWWWWo.
..oooooooooooo..
"""

# Icona "seleziona" 16x16, prima in basso a sinistra: la freccia del mouse.
SELECT_ICON = """
................
.oo.............
.oxo............
.oxxo...........
.oxxXo..........
.oxxxXo.........
.oxxxxXo........
.oxxxxxXo.......
.oxxxxxxXo......
.oxxxxxXXXo.....
.oxxXoooooo.....
.oxXoXXo........
.oXo.oxXo.......
.oo..oxXo.......
.o....oXXo......
.......ooo......
"""

# Cornice d'oro del tasto premuto (9 slice, margini 7px, raddoppiata): nodi ad anello negli angoli e un rametto
# verso l'interno; luce in alto a sinistra, ombra in basso a destra. Il centro (riga e colonna 7) si allunga.
SELECTED_FRAME = """
.ooo.......ooo.
og8gooooooog8go
o8ogggggggggo<o
ogg8ooooooo8<<o
.ogo8o%%%o8o<o.
.ogoog%%%goo<o.
.ogo%%%%%%%o<o.
.ogo%%%%%%%o<o.
.ogo%%%%%%%o<o.
.ogoog%%%<oo<o.
.ogo8o%%%o<o<o.
ogg8ooooooo<<<o
o8o<<<<<<<<<o<o
og<<ooooooo<<<o
.ooo.......ooo.
"""

# Icona "risorse" 16x16, accanto a "Jobs": cassa con legna, pietra e bacche.
RESOURCES_ICON = """
................
................
.....oooo.......
....owwwwo.oooo.
...owcCcWoouurRo
...owCcCWoourRRo
.ooowcCcWojjoRRo
ojjoowwWojjJooo.
ojJoooooooJooo..
oooooooooooooooo
oBBBBBBBBBBBBBWo
owwwwwwwwwwwwwWo
oWWWWWWWWWWWWWWo
oBBBBBBBBBBBBBWo
owwwwwwwwwwwwwWo
oooooooooooooooo
"""

# Icona "coloni" 16x16 nella barra in alto: una faccina.
COLONISTS_ICON = """
................
.....oooooo.....
...oowwwwwwoo...
..owwwwwwwwwWo..
.owwwwwwwwwwwWo.
.owwssssssssWWo.
.owsssssssssSWo.
.owssessssesSWo.
.owssessssesSWo.
.oSsssssssssSSo.
..oSsossssosSo..
..oSssoooossSo..
...oSssssssSo...
....ooSSSSoo....
......oooo......
................
"""

# Icona "opzioni" 16x16 in alto a destra: ingranaggio di pietra, luce in alto a sinistra (il foro al contrario).
OPTIONS_ICON = """
......oooo......
...ooouuuuooo...
..ouuouuuuorro..
.ouuuouuuuorrro.
.ouuuuuuurrrrro.
.ooouuRRrrrrooo.
ouuuuRoooorrRRRo
ouuuuRo..orRRRRo
ouuuuro..ouRRRRo
ouuurroooouRRRRo
.ooorrrruuRRooo.
.orrrrrRRRRRRRo.
.orrroRRRRoRRRo.
..orroRRRRoRRo..
...oooRRRRooo...
......oooo......
"""

# Icona "tasti" 16x16, tab Keybindings del menù delle opzioni: tastiera di pietra (tasti chiari con l'ombra sotto, la
# seconda fila sfalsata, la barra spaziatrice) e davanti, in basso a destra, il mouse con la rotella.
KEYBINDINGS_ICON = """
................
.oooooooooooo...
oRRRRRRRRRRRRo..
oRuuiuuiuuiuuo..
oRrrirrirrirro..
oRiiiiiiiiiiio..
oRiuuiuuiuuiio..
oRirrirrirooooo.
oRiiiiiiioxxoxxo
oRuuiuuuuoxxRxXo
oRrrirrrroxxRxXo
oRiiiiiiioXXoXXo
.oooooooooxxxxXo
.........oxxxxXo
.........oXxxXXo
..........ooooo.
"""

# Icona "partita" 16x16, tab Game del menù delle opzioni (menù principale, carica, esci): porta di legno spalancata
# verso chi guarda, e nel vano la luce di fuori.
GAME_ICON = """
................
.oo...ooooooooo.
.oBoo.oWWWWWWWo.
.oBwwooW88888Wo.
.oBwWwoW88888Wo.
.oBwWwoW88888Wo.
.oBwWwoW88888Wo.
.oBwWwoW88888Wo.
.oBgWwoW88888Wo.
.oBwWwoW88888Wo.
.oBwWwoW88888Wo.
.oBwWwoW88888Wo.
.oBwWwoW88888Wo.
.oBwwooW88888Wo.
.oBoo.oW88888Wo.
.oo...ooooooooo.
"""

# Velocità 16x16, in alto a destra (come Space e 1-3): pausa, 1x, 2x, 3x. Simboli color pergamena, ombra in basso.
SPEED_ICONS = """
................ ................ ................ ................
..ooooo..ooooo.. ...oo........... oo......oo...... ................
..oxxXo..oxxXo.. ...oxoo......... oxo.....oxo..... ................
..oxxXo..oxxXo.. ...oxxxoo....... oxxo....oxxo.... oo...oo...oo....
..oxxXo..oxxXo.. ...oxxxxxoo..... oxxxo...oxxxo... oxo..oxo..oxo...
..oxxXo..oxxXo.. ...oxxxxxxxoo... oxxxxo..oxxxxo.. oxxo.oxxo.oxxo..
..oxxXo..oxxXo.. ...oxxxxxxxxXoo. oxxxxxo.oxxxxxo. oxxxooxxxooxxxo.
..oxxXo..oxxXo.. ...oxxxxxxxxxXXo oxxxxxXooxxxxxXo oxxxXoxxxXoxxxXo
..oxxXo..oxxXo.. ...oxxxxxxxxXXXo oxxxxXXooxxxxXXo oxxXXoxxXXoxxXXo
..oxxXo..oxxXo.. ...oxxxxxxxXXoo. oxxxxXo.oxxxxXo. oxxXooxxXooxxXo.
..oxxXo..oxxXo.. ...oxxxxxXXoo... oxxxXo..oxxxXo.. oxXo.oxXo.oxXo..
..oxxXo..oxxXo.. ...oxxxXXoo..... oxxXo...oxxXo... oXo..oXo..oXo...
..oxxXo..oxxXo.. ...oxXXoo....... oxXo....oxXo.... oo...oo...oo....
..oXXXo..oXXXo.. ...oXoo......... oXo.....oXo..... ................
..ooooo..ooooo.. ...oo........... oo......oo...... ................
................ ................ ................ ................
"""

# Schermo 16x16, in alto a destra (schermo intero / finestra) e tab Video delle opzioni: monitor di pietra col vetro
# scuro e un riflesso, sul suo piede. ponytail: icona provvisoria
SCREEN_ICON = """
................
.oooooooooooooo.
.ouuuuuuuuuuuro.
.ouEEEEEEEEEQRo.
.ouEEEEEEEEQERo.
.ouEEEEEEEQEERo.
.ouEEEEEEEEEERo.
.ouEEEEEEEEEERo.
.ouEEEEEEEEEERo.
.ouEEEEEEEEEERo.
.orRRRRRRRRRRRo.
.oooooooooooooo.
......orRo......
....ooorRooo....
....orrrRRRo....
....oooooooo....
"""

# Coleottero 16x16, tab Debug delle opzioni (per provare il gioco): guscio rosso diviso a metà, testa di pietra.
DEBUG_ICON = """
................
....o......o....
.....o....o.....
......oooo......
.....oRRRRo.....
.....oiiiio.....
.o.oojjoojjoo.o.
..oojjjoojjjoo..
...ojjjoojjjo...
.oooJjjoojjJooo.
...oJjjoojjJo...
..ooJjjoojjJoo..
.o..oJjoojJo..o.
.....oJooJo.....
......oooo......
................
"""

# Altoparlante 16x16, tab Audio delle opzioni: cassa di pietra e due onde.
AUDIO_ICON = """
................
................
......oo........
.....oro....x...
....orRo.....x..
oooorRRo.x....x.
ouurRRRo..x...x.
ourRRRRo..x...x.
ourRRRRo..x...x.
ouurRRRo..x...x.
oooorRRo.x....x.
....orRo.....x..
.....oro....x...
......oo........
................
................
"""

# Wiki 16x16, nella barra in basso: pergamena arrotolata col punto di domanda.
WIKI_ICON = """
................
.oooooooooooooo.
oUIIIIIIIIIIIIUo
.oUUUUUUUUUUUUo.
..oIIIIIIIIIUo..
..oIIIoooIIIUo..
..oIIoIIIoIIUo..
..oIIIIIIoIIUo..
..oIIIIIoIIIUo..
..oIIIIoIIIIUo..
..oIIIIIIIIIUo..
..oIIIIoIIIIUo..
.oooooooooooooo.
oUIIIIIIIIIIIIUo
.oUUUUUUUUUUUUo.
..oooooooooooo..
"""

# Meteo 16x16 (striscia in alto e previsioni, vedi forecast.gd), nell'ordine: sereno di giorno, sereno di notte,
# pioggia, neve, nebbia, temporale; poi gli avvisi: ondata di freddo, gelata, acqua gelata
WEATHER_ICONS = """
.......gg....... ................ ................ ................ ................ ................ ................ ................ ................
.......gg....... .......o........ ........oooo.... ........oooo.... ................ ........oooo.... .......oo....... .......oo....... ................
..g..........g.. .....ooIo....... .......ouuuuo... .......ouuuuo... ...oooooooooo... .......orrrro... ......ouuo...... ...o.oo00oo.o... ................
...g...oo...g... ....oIIo........ ....ooouuuuuuo.. ....ooouuuuuuo.. ..ouuuuuuuuuuo.. ....ooorrrrrro.. ......ouuo.oo... ..oQo0o00o0oQo.. ..oooooooooooo..
.....ooggoo..... ...oIIIo........ ...ouuuuuuuuuuo. ...ouuuuuuuuuuo. ..orrrrrrrrrro.. ...orrrrrrrrrro. ......ouuo...... ...oQoo00ooQo... .o000000000000o.
....og**gggo.... ..oIIIo......... ..ouuuuuuuuuuuo. ..ouuuuuuuuuuuo. ...oooooooooo... ..orrrrrrrrrrro. ......ouuo.oo... ..o0oQo00oQo0o.. o000h000000h000o
....o****ggo.... ..oIIIIo........ .ouuuuuuuuuuuuuo .ouuuuuuuuuuuuuo .oooooooooo..... .orrrrrrrrrrrrro ......o~uo...... ..ooooQ00Qoooo.. o0000hh000h0000o
gg.og****ggUo.gg .oIIIIIo........ .ouuuuuuuuuuuuuo .ouuuuuuuuuuuuuo ouuuuuuuuuuo.... .orrrrrrrrrrrrro ......o~uo.oo... .o000000000000o. o000000h0000000o
gg.ogg***gUUo.gg .oIIIIIIo....... .orrrrrrrrrrrrro .orrrrrrrrrrrrro orrrrrrrrrro.... .oRRRRRRRRRRRRRo ......o~uo...... .o000000000000o. oQQQQQQhhhQQQQQo
....oggggUUo.... ..oIIIIUUoooo... .orrrrrrrrrrrrro .orrrrrrrrrrrrro .oooooooooo..... .oRRRRRRRRRRRRRo ......o~uo...... ..ooooQ00Qoooo.. oQQQQQhQQQhQQQQo
....ogggUUUo.... ..oIIIUUUUUUUo.. ..ooooooooooroo. ..ooooooooooroo. ....oooooooooo.. ..ooooooo*ooRoo. ......o~~o...... ..o0oQo00oQo0o.. oQQQQQhQQQQhQQQo
.....ooUUoo..... ...oIUUUUUUUo... ............o... .........h..o... ...ouuuuuuuuuuo. .......o*o..o... .....o~0~~o..... ...oQoo00ooQo... oQQQQQQQQQQQQQQo
...g...oo...g... ....oUUUUUUo.... ....Q...Q...Q... ....h...h0h..... ...orrrrrrrrrro. ......o***o..... .....o~0~~o..... ..oQo0o00o0oQo.. .oQQQQQQQQQQQQo.
..g..........g.. .....ooUUoo..... ...Q...Q...Q.... ...h0h...h..h... ....oooooooooo.. .......o*o...... .....o~~~~o..... ...o.oo00oo.o... ..oooooooooooo..
.......gg....... .......oo....... ................ ....h..h...h0h.. ................ ......o*o....... ......o~~o...... .......oo....... ................
.......gg....... ................ .....QQ..QQ..... ......h0h...h... ................ .....o*o........ .......oo....... ................ ................
"""

# Avviso dei lupi 16x16 (forecast.gd, dopo WEATHER_ICONS): l'impronta di una zampa, quando il narratore ha annunciato
# un branco per la notte
WOLF_ALERT = """
................
.....oo..oo.....
....orRoorRo....
....orRoorRo....
.oo..oo..oo..oo.
orRo........orRo
orRo..oooo..orRo
.oo..orrrRo..oo.
....orrrrrRo....
...orrrrrrrRo...
...orrrrrrrRo...
...orrrrrrrRo...
....oRRooRRo....
.....oo..oo.....
................
................
"""

# Ricerca Astronomia 12x12: la sfera armillare
TECH_ASTRONOMY = """
....oooo....
...oggggo.o.
..ogoooogoUo
.ogoooooogo.
.ogo~~~~Ugo.
ogoo~~~~oogo
.ogo~~~~ogo.
.ogUooooogo.
oUogoooogo..
.o.oggggo...
...ooUUoo...
..oUUUUUUo..
"""

# Pulsante della lente del calore: un termometro, il bulbo rosso
HEAT_ICON = """
................
.......oo.......
......oxxo......
......oxXo......
......oxXo..oo..
......oxXo......
......ojXo..oo..
......ojXo......
......ojJo..oo..
......ojJo......
.....ojjjJo.....
....ojjjjjJo....
....ojjxjjJo....
....oJjjjJJo....
.....oJJJJo.....
......oooo......
"""

# Pulsante dei tetti: il tetto sollevato dalla casa, per guardarci dentro
ROOFS_ICON = """
................
.......oo.......
......oFFo......
.....oFFFFo.....
....oFFFFFFo....
...oFFDFFDFFo...
..oDDDDDDDDDDo..
..oooooooooooo..
................
..oooooooooooo..
..oBBBBBBBBBBo..
..oBwwoooowwBo..
..oBwwoWWowwBo..
..oBwwoWWowwBo..
..oBwwoWWowwBo..
..oooooooooooo..
"""


# Talenti, nella scheda del colono (come Trait in main.gd): simboli 12x12, 5 per blocco, che badge() mette al
# centro di un quadratino 16x16 in rilievo. Il punto lascia vedere il fondo del quadratino.
# -> goloso (cosciotto), sonnambulo (luna e Zz), iracondo (faccia rossa), pigro (lumaca), stacanovista (martello e sudore)
TRAITS_1 = """
......oooo.. ...oooo..... ..oooooooo.. .........x.x ......oooo..
....ooFFFFo. .ooIIIo..... .ojjjjjjjjo. .........o.o .....ouuuro.
...oFsFFFFfo .oIIIo.xxxx. ojoojjjjoojo ........oXXo ....ouuurrRo
..oFsFFFFffo oIIIo....x.. ojjjoojoojjo ..oooo..oeXo .Q..orrrRRRo
..oFFFFFfffo oIIo....x... ojjjjjjjjjJo .oCcccoooXXo .QQ.oorRRoo.
..oFFFFffDDo oIIo...xxxx. ojjxojjoxjJo oCcoooCcoXXo oQEo.owoo...
..ofFFffDDo. oIIIo....... ojjjjjjjjjJo oCcoCcoCoXXo .oo.owo.....
...offDDDo.. oIIIIo..xxx. ojjoooooojJo oCcoCooCoXXo ...owo......
...oxooo.... .oUIIIo..x.. ojoxxxxxxoJo oCCcooCCoXXo ..owo.......
..oxXo...... .oUUIIIoxxx. .ojoooooojo. .oCCCCCooXXo .owo........
.ooxXo...... ..ooUUUUo... ..oJJJJJJo.. oxxxxxxxxxXo owo.........
oxxXXo...... ....oooo.... ...oooooo... .oooooooooo. oo..........
"""

# -> mattiniero (sole che sorge), nottambulo (gufo), dormiglione (berretto da notte), instancabile (candela),
# festaiolo (boccale)
TRAITS_2 = """
.....99..... .oo......oo. ........oxo. .....o...... ..oooooo....
.9...99...9. .oWo....oWo. .....ooooxo. ....o9o..... .oxxhxxxo...
..9......9.. .oWWooooWWo. ...ooQQQEo.. ....o89o.... oxxxxxxxXo..
............ owwwwwwwwwwo ..oQQQQQEo.. ...o988o.... oXxXxxXXXooo
....oooo.... owooowwooowo .oQQQQQEEo.. ....o8o..... .ocCcCcCCo.o
..oo8888oo.. oog8goog8goo .oxxxxxxxxo. ....ooo..... .oRRRRRRRo.o
.o88ggggg9o. oogeg..geg.o .osssssssSo. ...oxxxXo... .ocCcCcCCo.o
.o8gggggg9o. owoooCCooowo .osoossoosSo ...oxxxXo... .ocCcCcCCo.o
o8gggggggg9o .owwwoowwwo. .ossssssssSo ...oxxXXo... .ocCcCcCCooo
o8ggggggg99o .owcwcwcwwo. .osssooossSo ..ooxxXXoo.. .oRRRRRRRo..
oooooooooooo ..owwcwcwo.. ..oSsssssSo. .oCccccccCo. .ocCcCcCCo..
............ ...oooooo... ...oooooo... ..oooooooo.. ..ooooooo...
"""

# -> asceta (cappuccio), di poco appetito (ciotola con una bacca), tranquillo (sassi in equilibrio), amante della
# pennichella (sole e Zz), irrequieto (clessidra)
TRAITS_3 = """
....oooo.... ............ ....ooo..... ........xxxx .oooooooooo.
...owwwwo... ............ ...ouuro.... ..........x. .owwwwwwwWo.
..owwwwwwo.. ............ ...orRRo.... .........x.. .oooooooooo.
.owwooooWwo. .....oo..... ..oooooo.... ...9.9..xxxx ..oQccccQo..
.owoSSSSoWo. ....ojJo.... .ouuurrRo... .9.oooo.9... ...oQccQo...
owwoSoSoSoWo ....oJJo.... .orrrRRRo... ..o8888o.... ....oQco....
owoSSSSSSoWo oooooooooooo ..oooooooo.. 9o8gggg8o9.. ....ocQo....
owoSSoooSoWo occcccccccCo .ouuuurrrRo. .o8gggg9o... ...oQ.cQo...
owwoSSSSoWWo .oCcccccCCo. ourrrrRRRRo. 9o8ggg99o9.. ..oQ.ccQQo..
owwwooooWWWo .oCCccCCCWo. oRRRRRRRRRo. ..o9999o.... .oooooooooo.
.owwwwwWWWo. ..oWCCCWWo.. .oooooooooo. .9.oooo.9... .owwwwwwwWo.
..oooooooo.. ...oooooo... ............ ...9..9..... .oooooooooo.
"""

# Stellina 9x9 accanto a un'abilità al livello massimo.
STAR = """
....o....
...ogo...
ooogggooo
oggggggUo
.ogggggo.
..ogggo..
.oggUggo.
.ogo.oUo.
.oo...oo.
"""

# Barre dei bisogni 6x6 -> riempimento (bianco: in gioco si tinge col colore del valore) e fondo incavato; angoli
# smussati, luce sopra e ombra sotto. Raddoppiate come la cornice: si allungano nel mezzo (StyleBoxTexture).
BAR_FILL = """
.oooo.
oohhoo
o[[[[o
o[[[[o
oo]]oo
.oooo.
"""

BAR_BACK = """
.oooo.
ooZZoo
oVVVVo
oVVVVo
ooVVoo
.oooo.
"""

# Freccina 4x7 a destra della barra (a sinistra è specchiata): si accende, tinta, se il bisogno sale (scende).
ARROW = """
x...
xx..
xxx.
xxxx
xxX.
xX..
X...
"""

# Abilità 8x8, nella scheda del colono (come Skill in main.gd) -> raccogliere, estrarre, tagliare legna, costruire,
# forgiare, cucire, cucinare, pescare, cacciare, armi da mischia, armi a distanza, ricerca, scassinare, medicina (la
# croce rossa).
SKILLS = """
....oLo. .ooooo.. .oo..oo. oooooo.. ........ ......oo .x..x... ........ .ww..ww. .....ooo .oo..... .oooo... ....ooo. ..oooo..
...oLo.. ouurrRo. ouuooRwo ouurrRo. .ooooooo .....ouo ..x..x.. ..ooo..o .ww..ww. ....oxxo owwo..o. oQQEEo.. ...og8go ..ojJo..
.oo.oo.. .oooowRo ouurRwo. oRRRRRo. orrrrrRo ..j.ouo. oooooooo .oQQQooQ ........ ...oxXXo o.owoox. oQEEEo.. ...og.go ooojJooo
ojjoojjo ...owooR ourRwoo. oooowoo. .ooorRo. .j.ouo.. oiiiiiio oQeQQQQo w..ww..w o.oxXXo. o..oxxxo oEEEEo.. ..oog<o. ojjjjjjo
ojJoojJo ..owo.oo .oowRo.. ...owo.. ...oRo.. j.ouo... orrrrrRo oQQQQooQ ..wwww.. ogoXXo.. o..owoX. .oooowo. .ogoo... oJJjJJJo
.oojjoo. .owo.... ..owo... ...owo.. ..oiiio. .ouo.j.. .orrrRo. .oEEEo.o .wwwwww. .ogXo... o.owo.o. ....owo. og<go... ooojJooo
..ojJo.. owo..... .owo.... ...owo.. .oiiiiio ouo.j... .oRRRRo. ..ooo... .wwwwww. owogo... owwo.... .....owo o<o..... ..ojJo..
...oo... oo...... owo..... ...ooo.. .ooooooo oo.j.... ..oooo.. ........ ..w..w.. ooo.o... .oo..... ......oo oo...... ..oooo..
"""

# Talenti degli avventurieri 12x12, nei quadratini come i talenti (vedi badge), nell'ordine di Gift in main.gd:
# greedy, loyal, reckless, coward, lucky, cartographer, jinxed, berserker, stout, stealthy, medic, forager, pathfinder, keen_eyed, scholar, famous
HERO_TRAITS_1 = """
....oooo.... ............ ......o..... .oo.........
....o<<o.... .oooo..oooo. .....o9o.... .owoooooooo.
.....oo..... oj+jjoojjjJo .....o99o... .ow++++++++o
...oggggo... oj+jjjjjjjJo ....o9=9o.o. .ow++++++++o
..og8ggg<o.. ojjjjjjjjjJo ...o9==99o9o .ow+++++++Uo
.og8gg<gg<o. ojjjjjjjjJJo ..o99=889o9o .ow++++++UUo
.og8g<<<g<o. .ojjjjjjjJo. ..o9=8889=9o .owoooooooo.
.og8gg<gg<o. ..ojjjjjJo.. .o9=88888=9o .owo........
.oggg<<<g<o. ...ojjjJo... .o9=88888=o. .owo........
..og<<<<<o.. ....ojJo.... .o9==888=9o. .owo........
...ooooooo.. .....oo..... ..oo999999o. .oWo........
............ ............ ....oooooo.. .ooo........
"""

HERO_TRAITS_2 = """
............ ............ ............ .ooo....ooo.
..ooo..ooo.. .oooooooooo. .o.......o.. oujro..orjuo
.oyLLooyLLo. oUIIIIIIIIUo .oo.....oo.. ouurrooorruo
.oLLLooLLLo. .oI(IIIjIjo. .o7o...o7o.. ourrRowoRrro
..ooLLLLoo.. .oII(IIIjIo. .o77ooo77o.. ourRRowoRRro
..ooLLLLoo.. .oIII(IjIjo. .o7777777o.. .oRRowwoRRo.
.oyLLooyLLo. .oIIII(IIIo. .o7g777g7o.. ..ooowwooo..
.oLLLooLLLo. .oI(II(IIIo. .o7g777g7o.. .....owo....
..ooo..ooo.. .oII((IIIIo. .o7777777o.. .....owo....
.....om..... oUIIIIIIIIUo ..o77677o... .....owo....
......om.... .oooooooooo. ...ooooo.... .....oWo....
.......o.... ............ ............ .....ooo....
"""

HERO_TRAITS_3 = """
............ ....oooo.... ............ ............
..oo.oo.oo.. ...o7777o... .oooooooooo. ...oooooo...
.oCCoCCoCCo. ..o777777o.. .o++++++++o. ..oj+jjj+jo.
.oCCoCCoCCo. .o77666677o. .o+++jj+++o. .oj+jjjjjjJo
..oo.oo.oo.. .o76666667o. .o+++jj+++o. .ojjjj+jjjJo
...oooooo... .o76g66g67o. .o+jjjjjj+o. .oJJJJJJJJJo
..oCCCCCCo.. .o76666667o. .o+jjjjjj+o. ..ooo++ooo..
.oCcCCCCCCo. .o77666677o. .o+++jj+++o. ....o++o....
.oCcCCCCCCo. .o77777777o. .o+++jj+++o. ....o++o....
.oCCCCCCCCo. o7777777777o .o++++++++o. ....o+Uo....
..oCCCCCCo.. o7777777777o .oooooooooo. ...o+++Uo...
...oooooo... oooooooooooo ............ ...oooooo...
"""

HERO_TRAITS_4 = """
............ ............ ............ .....oo.....
...oooo..... ............ ..oooooooo.. ....o88o....
...oCCo..... ...oooooo... .ojjjjjjjjo. ....o8go....
...oCCo..... ..o++++++o.. .ojgggggjjo. ooooo8ggoooo
...oCCo..... .o++oQQo++o. .ojjjjjjjjo. o8888ggggg<o
...oCCo..... o+++QEEQ+++o .ojjgggjjjo. .o88gggggg<o
...oCCCooo.. o+++QEEQ+++o .ojjjjjjjjo. ..ogggggg<o.
...oCCCCCCo. .o++oQQo++o. .ojjjjjjjjo. ..ogg<<gg<o.
..oCCCCCCCCo ..o++++++o.. .oJ++++++Jo. .og<<oo<<g<o
..oWWWWWWWWo ...oooooo... .oJ++++++Jo. .og<o..og<o.
..oooooooooo ............ ..oooooooo.. og<o....o<<o
............ ............ ............ ooo......ooo
"""

# Stress 8x8, accanto alla sua barra nella scheda del colono: un fulmine.
# Tipi di oggetto 8x8 (raddoppiati), davanti al nome di ogni oggetto: materiale (cassa), cibo (mela), strumento
# (martello), arma (spada), armatura (scudo), cimelio (gemma); per le monete la moneta (COIN)
ITEM_KINDS = {
    "material": ['oooooooo', 'ocCCCCwo', 'oCcCCwCo', 'oCCcwCCo', 'oCCwcCCo', 'oCwCCcCo', 'owCCCCco', 'oooooooo'],
    "food": ['....oo..', '...owo..', '.oooooo.', 'oj+jjjJo', 'ojjjjjJo', 'ojjjjJJo', '.ojJJJo.', '..oooo..'],
    "tool": ['.ooooo..', 'ouuurRo.', 'orrrRRo.', '.oowoo..', '...owo..', '...owo..', '...owo..', '...ooo..'],
    "weapon": ['......oo', '.....oxo', '....oxXo', '.o.oxXo.', '.ogoXo..', '..ogo...', '.owogo..', '.oo.oo..'],
    "armor": ['oooooooo', 'ourrrrRo', 'orjjjjRo', 'orjggjRo', 'orjjjjRo', '.orjjRo.', '..orRo..', '...oo...'],
    "relic": ['..oooo..', '.o+//Qo.', 'o+////Qo', 'oooooooo', '.o//QQo.', '..o/Qo..', '...oo...', '........'],
    "book": ['.oooooo.', 'oáààààào', 'oáàggàào', 'oáààààào', 'oáààààào', 'oáààààào', 'oxxxxxxo', '.oooooo.'],
}

# Moneta 8x8 (raddoppiata), dentro i testi al posto della parola "gold": diari, bacheca, scheda.
COIN = """
..oooo..
.og88go.
og8gg<<o
o8g<<g<o
og8<<g<o
ogg<g<<o
.o<<<<o.
..oooo..
"""

SEX_ICONS = """
....//// ..???...
......// .?...?..
....././ .?...?..
.////... .?...?..
/.../... ..???...
/.../... ...?....
/.../... .?????..
.///.... ...?....
"""  # maschio, femmina (nella scheda)

STRESS_ICON = """
....ooo.
...ojJo.
..ojJo..
.ojjjjo.
.oojJoo.
..ojJo..
..ojo...
..oo....
"""

# Slot vuoti dell'equipaggiamento 16x16, sotto i talenti -> mani, corpo, testa: incavo con la sagoma di cosa ci va.
EQUIPMENT = """
oooooooooooooooo oooooooooooooooo oooooooooooooooo oooooooooooooooo
oiiiiiiiiiiiiiiR oiiiiiiiiiiiiiiR oiiiiiiiiiiiiiiR oiiiiiiiiiiiiiiR
oiiiiRiRiRiiiiiR oiiiiiiiiiiiiiiR oiiiiiiiiiiiiiiR oiiiiiRRRRiiiiiR
oiiiiRiRiRiiiiiR oiiiRRRiiRRRiiiR oiiiiiRRRRiiiiiR oiiiiRRRRRRiiiiR
oiiiiRiRiRiRiiiR oiiRRRRRRRRRRiiR oiiiiRRRRRRiiiiR oiiiRRRRRRRRiiiR
oiiiiRiRiRiRiiiR oiRRRRRRRRRRRRiR oiiiRRRRRRRRiiiR oiiRRRRRRRRRRiiR
oiiiiRRRRRiRiiiR oiRRRRRRRRRRRRiR oiiiRRRRRRRRiiiR oiiRRRRRRRRRRiiR
oiiiiRRRRRRRiiiR oiiiRRRRRRRRiiiR oiiRRRRRRRRRRiiR oiiRRRRRRRRRRiiR
oiiiiRRRRRRiiiiR oiiiRRRRRRRRiiiR oiiiRRiRRiRRiiiR oiiRRRRRRRRRRiiR
oiiiiRRRRRRiiiiR oiiiRRRRRRRRiiiR oiiiRRiRRiRRiiiR oiiRRRRRRRRRRiiR
oiiiiiRRRRiiiiiR oiiiRRRRRRRRiiiR oiiiRRiiiiRRiiiR oiiiRRRRRRRRiiiR
oiiiiiRRRRiiiiiR oiiiRRRRRRRRiiiR oiiiiRiiiiRiiiiR oiiiiRRRRRRiiiiR
oiiiiiRRRRiiiiiR oiiiRRRRRRRRiiiR oiiiiiiiiiiiiiiR oiiiiiRRRRiiiiiR
oiiiiiiiiiiiiiiR oiiiiiiiiiiiiiiR oiiiiiiiiiiiiiiR oiiiiiiiiiiiiiiR
oiiiiiiiiiiiiiiR oiiiiiiiiiiiiiiR oiiiiiiiiiiiiiiR oiiiiiiiiiiiiiiR
oRRRRRRRRRRRRRRR oRRRRRRRRRRRRRRR oRRRRRRRRRRRRRRR oRRRRRRRRRRRRRRR
"""

# Icona "ruota" 16x16, in senso orario (quella antioraria è lo specchio).
# Icona 16x16 del dado (a caso, nella creazione della partita): la faccia del cinque, ombra in basso.
DICE_ICON = """
................
..oooooooooooo..
.oxxxxxxxxxxxxo.
.oxooxxxxxxooxo.
.oxooxxxxxxooxo.
.oxxxxxxxxxxxxo.
.oxxxxxxxxxxxxo.
.oxxxxxooxxxxxo.
.oxxxxxooxxxxxo.
.oxxxxxxxxxxxxo.
.oxxxxxxxxxxxxo.
.oxooxxxxxxooxo.
.oxooxxxxxxooxo.
.oXXXXXXXXXXXXo.
..oooooooooooo..
................
"""

ROTATE_ICON = """
................
........o.......
.......ouo......
....oooouuo.....
...ouuuuuuuo....
..ouuuuuuuuo....
..ouuuoouuo.....
..ouuo.ouo......
..ouuo..o..oo...
..ouuo....ouuo..
..ouuo....ouuo..
..ouuuoooouuuo..
..ouuuuuuuuuuo..
...ouuuuuuuuo...
....oooooooo....
................
"""


# Terreno: caselle 16x16 che si accostano in qualsiasi ordine (niente sul bordo che debba continuare).
# In gioco una variante a caso per casella, così non si vede la ripetizione.
GRASS = """
,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,,
,,,,,,,,,,,;,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,, ,,,,!,,,,,,,,,,, ,,,,,,,,,--,,,,, ,,,,,,,,,,*,,,,,
,,^,!,^,,,,,,,,, ,,,^;^,,,,,,;,,, ,,,,,,,,----^,,, ,,,,,,,,,,;,,,,,
,,,^!^,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,;,,,,,---,,,, ,,,+,,,,,,,,,,,,
,,,;;;,,,,,,!,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,;,,,,,,,,,,,,
,,,,,,,,,,,^;^,, ,,,,,,,^,!,^,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,, ,,,,,,,,^!^,,,,, ,,,,,,,,,;,,,,,, ,,,,,,,,,,,,,,,,
,;,,,--,,,,,,,,, ,,,,,,,,;;;,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,^,!,^,,,,
,,,,----,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,!,,,,,,,,,,, ,,,,,,,,^!^,,,,,
,,,,,--^,,,,,,,, ,,;,,,,,,,,,,,,, ,,,^;^,,,,,,,,,, ,,,,,,,,;;;,,,,,
,,,,,,,,,^,!,^,, ,,,,,,,,,,,,,!,, ,,,,,,,,,,,,;,,, ,^,,,,,,,,,,,,,,
,,,,,,,,,,^!^,,, ,---,,,,,,,,^;^, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,--,,,
,,^,,,,,,,;;;,,, ,----,^,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,---,,,
,,,,,,,,,,,,,,,, ,,--,,,,,,,,,,,, ,,,,,,,,,,^,,,,, ,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,,
"""

# Erba vicino alle rocce: sassolini e chiazze di ghiaia, fa da passaggio verso GRAVEL.
STONY_GRASS = """
,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,,
,,,rRR,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,rR,,, ,,,,VVV,,,,,,,,,
,,,RRi,,,,,,!,,, ,,,,,,,,VVV,,,,, ,,,R,,,,,,,;;,,, ,,,VVrRV,,,,!,,,
,,,,;;,,,,,^;^,, ,,,,,,,VVrRVV,,, ,,,;,,,,,,,,,,,, ,,VVVZZVV,,^;^,,
,,,,,,,,,,,,,,,, ,,,,,,,VVRiVV,,, ,,,,,,,,,,,,,,,, ,,,VRVVV,,,,,,,,
,,,,,,,,,,,,,,,, ,,,,,,,,VZZV,,,, ,,,,,,^,!,^,,,,, ,,,,VV,,,,,,,,,,
,,,,,,,,,,,,,,,, ,,!,,,,,,,,,,,,, ,,,,,,,^!^,,,,,, ,,,,,,,,,,,,,,,,
,;,,,,,,rR,,,,,, ,^;^,,,,,,,,,,,, ,,,,,,,;;;,,,R,, ,,,,,,,,,,rR,,,,
,,,,,,,,;;,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,;,, ,,,,,,,,,,;;,,,,
,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,rRR,,,,,,,,,,, ,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,, ,,,,,,,,,,,,rR,, ,,RRi,,,,,,,,,,, ,,,,,,,,,,,,,,,,
,,,,!,,,,,,,,,,, ,,,,,,R,,,,,;;,, ,,,;;,,,,,,R,,,, ,,,,!,,,,,,,,,,,
,,,^;^,,,,,,,R,, ,,,,,,;,,,,,,,,, ,,,,,,,,,,,;,,,, ,,,^;^,,,R,,,,,,
,,,,,,,,,,,,,;,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,;,,,,,,
,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,, ,,,,,,,,,,,,,,,,
"""

# Ghiaia sotto le rocce: i massi ci stanno sopra, la roccia si legge come blocco unico.
GRAVEL = """
VVVVVVVVVVVVVVVV VVVVVVVVVVVVVVVV VVVVVVVVVVVVVVVV VVVVVVVVVVVVVVVV
VVVVVVVVVVVRVVVV VVVVVRVVVVVVVVVV VVVVVVVVVVVVVVVV VVVVVVVVVVVVVVVV
VVrRVVVVVVVZVVVV VVVVVZVVVVVVVVVV VVVrRVVVVVVVVVVV VVVVVVVVVVVRVVVV
VRRRZVVVVVZVVVVV VVVVVVVVVVVrRVVV VVRRRZVVVVVVRVVV VVVVRVVVVVVZVVVV
VVZZVVVVVVVVVVVV VVRVVVVVVVRRRZVV VVVZZVVVVVVVZVVV VVVVZVVVVVVVVVVV
VVVVVVVVrRVVVVVV VVVVVVVVVVVZZVVV VVVVVVVVVVVVVVVV VVVVVVVVVrRVVVVV
VZVVVVVRRRZVVVVV VVVVVVVVVVVVVVVV VVVVVVVVVVVVVVVV VVVVVVVVRRRZVVVV
VVVVVVVVZZVVVVZV VVVVVrRVVVVVVVVV VVVVVVVVVRVVVVVV VRVVVVVVVZZVVVVV
VVVVVVVVVVVVVVVV VVVVRRRZVVVVVRVV VVVVVVVVVZVVV!VV VZVVVVVVVVVVVVVV
VVVRVVVVVVVVrRVV VVVVVZZVVVVVVZVV VVVVVVVVVVVV^;^V VVVVVVVVVVVVVVVV
VVVZVVVVVVVRRRZV VVVVVVVVVVVVVVVV VVVRVVVVVVVVVVVV VVVVVVVVVVVVVRVV
VVVVVVVVZVVVZZVV VRVVVVVVVVVVVVVV VVVZVVVVVVVVVVVV VVVVVrRVVVVVVZVV
VVVVVVRVVVVVVVVV VZVVVVVVVRVVVVVV VVVVVVVVrRVVVVVV VVVVRRRZVVVVVVVV
VVVVVVZVVVVVVVVV VVVVVVVVVZVVVVVV VVVVVVVRRRZVVVVV VVVVVZZVVVVVVVVV
VRVVVVVVVVVVVRVV VVVVVVVVVVVVVVRV VVVVVVVVZZVVVVVV VVVVVVVVVVRVVVVV
VZVVVVVVVVVVVZVV VVVVVVVVVVVVVVVV VVVVVVVVVVVVVVVV VVVVVVVVVVZVVVVV
"""

# Bordi: lato col vicino sopra, angolo col vicino in alto a sinistra (solo in diagonale); gli altri si ruotano.
# Erba che sborda sulla ghiaia.
# Erba che sborda sui pavimenti (anche sul sentiero) dove la casella vicina è prato senza costruzioni, frastagliata e
# con qualche ciuffo staccato: lato col prato sopra, angolo col prato in alto a sinistra, poi una seconda variante
# di entrambi (le caselle le alternano). Girati dagli altri lati come i bordi del terreno.
FLOOR_EDGE = """
,,,,,,,,,,,,,,,, ,,,,,........... ,,,,,,,,,,,,,,,, ,,,,,...........
,,;-,,;,,,-,;,-, ,,,,;........... ,-,;,,-,,;,,-,;, ,,,,;...........
;;.,,,.;;,,;.;,; ,,,;.!.......... ;,,.;,,;;.;,,;.; ,,;;............
...;,;...,;...;. ,;;..^.......... .;;..,;....,;... ;,..!...........
....;..!.;...... ;....;.......... ...!.;.....;...! .;..^...........
.!.....^.....!.. ..!............. ...^.....!.....^ ....;...........
.^.....;.....^.. ..^............. ...;.....^.....; .!..............
.;...........;.. ..;............. .........;...... .^..............
................ ................ ................ .;..............
................ ................ ................ ................
................ ................ ................ ................
................ ................ ................ ................
................ ................ ................ ................
................ ................ ................ ................
................ ................ ................ ................
................ ................ ................ ................
"""

GRASS_EDGE = """
,,,,,,,,,,,,,,,, ,,;.............
;;,,,,,;;,,,,;;; ,;..............
.^;;,;;.^;,,;..^ ;...............
....;.....;;.... ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
"""

SHALLOW = """
~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~
~~~~~~~~~~~~:~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~
~~~~~~~~~~~::~~~ ~~~:~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~ ~~:::~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~ ~~~:~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~:~~~ ~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~:~~~~~~
~~~:~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~::~~~~~~
~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~:~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~
"""

DEEP = """
################ ################ ################ ################
################ ################ ################ ################
################ ################ ################ ################
################ ################ ################ ################
################ ################ ################ ################
##########@@#### ################ ################ ################
#########@@@@### ##@@############ ################ ################
##########@@#### #@@@@########### ################ ################
################ ##@@############ ################ ################
################ ################ ################ ####@@##########
################ ################ ################ ###@@@@#########
################ ################ ################ ####@@##########
################ ################ ##########@@#### ################
################ ################ #########@@@#### ################
################ ################ ################ ################
################ ################ ################ ################
"""

# Riva: terra bagnata e schiuma sull'acqua, con qualche ciuffo che sporge.
SHORE = """
,&&&&&,&&&&&&,&, ,&$0............
$$&&&&$$&&&&$$$$ &$0.............
0.$&&$00$$&$0.00 $0..............
..0$$0..0.$0.... 0...............
...0......0..... ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
"""

# Acqua bassa che scende in quella alta.
SHALLOW_EDGE = """
~~~~~~~~~~~~~~~~ ~~:.............
:~~~~~::~~~~~::: ~:..............
.::~~:..:~~~:... :...............
...::....:::.... ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
................ ................
"""


# --- Ricerca (GDD 4.7): sapere e leggi ---

# Scrittoio 1x1 (stanza Studio): un libro aperto sul piano, la candela sul piattino a destra.
DESK = """
................
.............9..
............989.
ooooo.ooooo.o8o.
oxxxxoxxxxo.oxo.
oxRRxoxRRXo.oxo.
oxxxxoxxxXoogg<o
oxRRxoxRRXoBBBBo
ooooooooooowwwwo
owwwwwwwwwwwwwWo
oooooooooooooooo
oWWWWWWWWWWWWWWo
owozzzzzzzzzzowo
owozzzzzzzzzzowo
ooozzzzzzzzzzooo
.zzzzzzzzzzzzzz.
"""

# Libreria 1x1: scaffale di legno con file di libri colorati (+studio nella stanza).
BOOKSHELF = """
................
.oooooooooooooo.
.oBBBBBBBBBBBBo.
.owjáàWWgWJWWWo.
.owjáàWLgèJWWWo.
.owjáàWLgèJWWWo.
.owjáàWLgèJLLWo.
.owBBBBBBBBBBWo.
.owéèWWWLmàWWWo.
.owéèWgWLmàjWWo.
.owéèjgWLmàjWWo.
.owéèjgWLmàjWWo.
.owBBBBBBBBBBWo.
.oWWWWWWWWWWWWo.
.oooooooooooooo.
.zzzzzzzzzzzzzz.
"""

# Trono 1x1 (sala del trono): legno scuro, schienale alto coi pomoli d'oro, cuscino rosso.
THRONE = """
...oo......oo...
..og<o....og<o..
..owWoooooowWo..
..owWojjjJowWo..
..owWojg<JowWo..
..owWojjjJowWo..
..owWojjJJowWo..
ooowWoJJJJowWooo
owwwWjjjjjjwWwWo
oWWWWJJJJJJWWWWo
oooooooooooooooo
..owWWWWWWWWWo..
..owozzzzzzowo..
..owozzzzzzowo..
..ooozzzzzzooo..
.zzzzzzzzzzzzzz.
"""

# Fantoccio 16x16: testa di sacco, braccia di legno, corpo di paglia sul palo
DUMMY = """
......oooo......
.....occcCo.....
.....occcCo.....
......oooo......
..oooo*CC*oooo..
..owwo****owWo..
..oooo****oooo..
.....o****o.....
.....o*CC*o.....
.....o****o.....
.....o*CC*o.....
......oooo......
.......wW.......
.......wW.......
......owWo......
....zzzzzzzz....
"""

# La caserma (Tech.BARRACKS, GDD 4.4.6), 16x16. Rastrelliera (Build.WEAPON_RACK): due montanti e due traverse, tre
# spade dritte. Bersaglio (Build.TARGET): un paglione a cerchi, rosso e bianco, sul cavalletto. Banco degli scassi
# (Build.LOCK_BENCH): un banco di legno con tre lucchetti d'ottone.
WEAPON_RACK = """
....o...o...o...
...ouo.ouo.ouo..
...ouo.ouo.ouo..
.o.ouo.ouo.ouoo.
owoouo.ouo.ouoWo
owoouooouooouoWo
owwwwwwwwwwwwwwo
owooroooroooroWo
owooro.oro.oroWo
owogggogggogggWo
owoolo.olo.oloWo
owoolo.olo.oloWo
owoogooogooogoWo
oWWWWWWWWWWWWWWo
owooooooooooooWo
.o.zzzzzzzzzzzo.
"""

TARGET = """
.....oooooo.....
....o******o....
...o**jjjj**o...
..o**jjjjjj**o..
..o*jjxxxxjj*o..
.o**jxxjjxxj**o.
.o**jxjjjjxj**o.
.o**jxxjjxxj**o.
..o*jjxxxxjj*o..
..o**jjjjjj**o..
...o**jjjj**o...
...ow******Wo...
...owooooooWo...
..owo......oWo..
..owo......oWo..
..zzzzzzzzzzzzz.
"""

LOCK_BENCH = """
................
....o...o...o...
...oRo.oRo.oRo..
..oRoRoRoRoRoRo.
..oRoRoRoRoRoRo.
..ogggogggogggo.
..ogogogogogogo.
.oogggogggogggo.
owwwwwwwwwwwwwwo
oWWWWWWWWWWWWWWo
.oWooooooooooWo.
.oWo........oWo.
.oWo........oWo.
.oWo........oWo.
.oWo........oWo.
..zzzzzzzzzzzzz.
"""

# Torre di guardia 16x16: la tettoia, la campana, la piattaforma e la scala
WATCHTOWER = """
.......oo.......
......oFFo......
.....oFFfFo.....
....oFFffFFo....
...oFFfffffDo...
..oooooooooooo..
..ow...gg...Wo..
..ow..g88g..Wo..
..ow...<<...Wo..
..oBBBBBBBBBBo..
..oWWWWWWWWWWo..
..ow.o....o.Wo..
..ow.oBBBBo.Wo..
..ow.o....o.Wo..
..ow.oBBBBo.Wo..
.zzzzzzzzzzzzzz.
"""

# Libri 16x16, come ICONS -> quaderno azzurro (sottile, una fascia), tomo rosso (spesso, due fasce, fermaglio),
# codice di porpora (grande, tre fasce, angoli d'oro e gemma): si riconoscono anche dalla sagoma
BOOK_ICONS = """
................ ................ ................
................ ................ .oooooooooooooo.
................ ..oooooooooooo.. .oéèggééééggxXo.
...oooooooooo... ..ojJjjjjjjxXo.. .oéègèèèèèègxXo.
...oáEáááááxo... ..ojJjjjjjjxXo.. .og<èèèèèèèèxXo.
...oáEáààààxo... ..og<jjjjjjxXo.. .oéèèèèèèèèèxXo.
...oáEáààààxo... ..ojJjjjjjjxXo.. .oéèèèèggèèèxXo.
...oáEáààààxo... ..ojJjjjouuuuo.. .og<èèg+jgèèxXo.
...og<áààààxo... ..ojJjjjorrrRo.. .oéèèègjJ<èèxXo.
...oáEáààààxo... ..ojJjjjjjjxXo.. .oéèèèè<<èèèxXo.
...oáEáààààxo... ..og<jjjjjjxXo.. .og<èèèèèèèèxXo.
...oáEáààààxo... ..ojJjjjjjjxXo.. .oéèèèèèèèèèxXo.
...oáEáààààxo... ..ojJjjjjjjxXo.. .oéègèèèèèègxXo.
...oEEEEEEEXo... ..oJJJJJJJJXXo.. .oèèg<èèèèg<XXo.
...oooooooooo... ..oooooooooooo.. .oooooooooooooo.
................ ................ ................
"""

# Studio 16x16 (il mucchio comune e il tasto Knowledge): foglio con le righe, penna d'oca nel calamaio.
STUDY_ICON = """
................
.............oo.
............oxo.
.ooooooooo.oxXo.
.oIIIIIIUo.oxXo.
.oIRRRRIUooxXo..
.oIIIIIIUooxXo..
.oIRRRIIUooXo...
.oIIIIIIUo.o....
.oIRRRRIUoooo...
.oIIIIIIUo7i6o..
.oIRRIIIo7iii6o.
.oIIIIIIo7iii6o.
.oUUUUUUo66666o.
.oooooooooooooo.
................
"""

# Autorità 16x16 (e il tasto Laws): sigillo di ceralacca con la corona impressa e il nastro.
AUTHORITY_ICON = """
................
.....oooooo.....
...oojjjjjjoo...
..ojjjjjjjjjjo..
.ojjjgjggjgjjJo.
.ojjjggggggjjJo.
ojjjjggggg<jjJJo
.ojjj<<<<<<jjJo.
.ojjjjjjjjjjJJo.
..ojjjjjjjjJJo..
...ooJJJJJJoo...
.....oáooáo.....
....oáào.oáào...
...oáào...oáào..
...ooo.....ooo..
................
"""

# Scudo tondo 16x16: legno col bordo e la borchia di ferro
SHIELD_ICON = """
................
.....oooooo.....
...oorrrrrroo...
..orrccccccRRo..
..orccccccccRo..
.orcccccccccCRo.
.orccccuuccccRo.
.orcccuurRccCRo.
.orccccrRRccCRo.
.orcccccccccCRo.
..orcccccccCRo..
..oRRcccccCRRo..
...ooRRRRRRoo...
.....oooooo.....
....zzzzzzzz....
................
"""

# Pergamena (il rotolo scritto), inchiostro (il calamaio con la penna), 16x16
PARCHMENT_ICON = """
................
................
...oooooooooo...
..oIIIIIIIIIIo..
..oUUUUUUUUUUo..
...oIIIIIIIIo...
...oIoooooIIo...
...oIIIIIIIIo...
...oIooooIIIo...
...oIIIIIIIIo...
...oIoooooIIo...
...oIIIIIIIIo...
..oIIIIIIIIIIo..
..oUUUUUUUUUUo..
...oooooooooo...
....zzzzzzzz....
"""
INK_ICON = """
..........o.....
.........oxo....
........oxXo....
.......oxXo.....
......oxXo......
......oXo.......
.....oooooo.....
......o66o......
....oo6666oo....
...o66666667o...
...o66666666o...
...o66666666o...
...o66666666o...
....oooooooo....
....zzzzzzzz....
................
"""

# Focolare 1x1 di pietra, addossato al muro che ha dietro (vedi BACKS in main.gd): di fronte (il muro in alto, la
# canna che ci sale), di lato (il muro a destra; a sinistra è lo specchio), da dietro (il muro in basso: la canna
# scende verso di lui, la bocca accesa guarda in su)
HEARTH = """
....oooooooo.... ..........oooo.. ................
....ourrrrRo.... ..........ouRo.. ................
....orrrrrRo.... ..........orRo.. ...oooooooooo...
..oooooooooooo.. .....oooooorRo.. ...o66989966o...
..ouuuuuuuuuRo.. .....ouuuuuuRo.. ...o69888896o...
..oRRRRRRRRRio.. .....oRRRRRRio.. ...o=wWWWWw=o...
..orRooooooRio.. .....o66oRRRio.. ..oooooooooooo..
..orRo6966oRio.. ....9o96oRRRio.. ..ouuuuuuuuuRo..
..orRo9896oRio.. ...98o89oRRRio.. ..orrrrrrrrrRo..
..orRo8889oRio.. ....9o88oRRRio.. ..oRRRRRRRRRio..
..orRo=88=oRio.. .....o=8oRRRio.. ..ooooorrRoooo..
..orRowWWwoRio.. .....owWoRRRio.. .......orRo.....
..oiiiiiiiiiio.. .....oiiiiiiio.. .......orRo.....
..oooooooooooo.. .....ooooooooo.. .......orRo.....
.zzzzzzzzzzzzzz. ....zzzzzzzzzz.. .......orRo.....
................ ................ .......orRo.....
"""

# Pelli alle pareti 1x1, appese al muro alle spalle (di fronte: il muro in alto; di lato: a destra; da dietro: in basso)
WALL_HIDES = """
..oooooooooooo.. ................ ................
.occcccccccccco. ............oooo ................
.occCccccccCcco. ............occo ................
.occcccccccccco. ...........ocCco ................
..occcCcccccco.. ...........occco ................
..occccccccCco.. ...........occCo ................
...occcccccco... ...........occco ................
...occCccccco... ...........ocCco ................
....occcccco.... ...........occco ................
.....oooooo..... ............occo ................
................ ............oCco ................
................ ............occo ..oooooooooooo..
................ .............oco .occcCcccccCcco.
................ .............ooo .occcccccccccco.
................ ................ .occccccCccccco.
................ ................ .oooooooooooooo.
"""

# Portiera 1x1: una tenda di pelle su un'asta, davanti alla porta che ha alle spalle (di lato come le pelli)
DOOR_CURTAIN = """
.oooooooooooooo. ................
.oBBBBBBBBBBBBo. ................
.oooooooooooooo. ................
.ocCccCcCccCcCo. ................
.ocCccCcCccCcCo. ................
.ocCccCcCccCcCo. ................
.ocCccCcCccCcCo. ................
.ocCccCcCccCcCo. ................
.ocCccCcCccCcCo. ................
.owCwwCwCwwCwCo. ................
.oooooooooooooo. ................
................ .oooooooooooooo.
................ .oBBBBBBBBBBBBo.
................ .oooooooooooooo.
................ .ocCccCcCccCcCo.
................ .oooooooooooooo.
"""

# Arazzo 1x1: tela di porpora con la cornice d'oro e una losanga, appesa al muro alle spalle (come le pelli)
TAPESTRY = """
.oooooooooooooo. ................ ................
.oggggggggggggo. ............oooo ................
.ogèèèèèèèèèègo. ............ogèo ................
.ogèéèèèèèèéègo. ............ogèo ................
.ogèèèèggèèèègo. ............ogèo ................
.ogèèèggggèèègo. ............ogèo ................
.ogèèèèggèèèègo. ............ogèo ................
.ogèéèèèèèèéègo. ............ogèo ................
.ogèèèèèèèèèègo. ............ogèo ................
.oggggggggggggo. ............ogèo ................
.oooooooooooooo. ............ogèo ................
..o.o.o..o.o.o.. ............oooo .oooooooooooooo.
................ ................ .oggggggggggggo.
................ ................ .ogèèèèggèèèègo.
................ ................ .oggggggggggggo.
................ ................ .oooooooooooooo.
"""

# Stufa a olle 1x1: un blocco di piastrelle verdi smaltate su una base di pietra, la bocca accesa. Uguale girata
TILED_STOVE = """
...oooooooooo...
...oLLLLLLLLo...
..oooooooooooo..
..oLmLmLmLmLmo..
..omLmLmLmLmLo..
..oLmLmLmLmLmo..
..omLmLmLmLmLo..
..oLmLmLmLmLmo..
..omLmoooomLmo..
..oLmLo98oLmLo..
..omLmo=8omLmo..
..oLmLmLmLmLmo..
..oiiiiiiiiiio..
..oooooooooooo..
.zzzzzzzzzzzzzz.
................
"""

# Blocco di ghiaccio 16x16 (l'oggetto), tagliato dall'acqua gelata (vedi Order.ICE in main.gd); l'icona del tasto è lo
# stesso blocco con la sega
ICE_BLOCK = """
................
................
.....ooooooo....
....ohhhhhhuo...
...ohhhhhhuQo...
..ooooooooQQo...
..o000000oQQo...
..o0h0000oQQo...
..o0000h0oQQo...
..o000000oQQo...
..o0h0000oQo....
..o000000oo.....
..ooooooooo.....
...zzzzzzzz.....
................
................
"""
# Secchio d'acqua 16x16: lo porta chi spegne un incendio (vedi Job.DOUSE in main.gd)
BUCKET = """
................
................
....oooooooo....
...o........o...
..o..........o..
..oooooooooooo..
..o~~~~~~~~~~o..
..oBwwWBwwWBwo..
...oBwWBwwWBo...
...oBwWBwwWBo...
...oWWWWWWWWo...
...oBwWBwwWBo...
....oBwWBwWo....
....oooooooo....
................
................
"""

ICE_SAW = {(3, 12): "o", (4, 11): "o", (5, 10): "o", (6, 9): "o", (2, 13): "w", (1, 14): "w", (0, 15): "W"}


def ice_pit():
    """Fossa del ghiaccio 32x32 (2x2): un bordo di pietra e uno di paglia, vuota in mezzo: dentro si vedono i blocchi
    (i mucchi di ghiaccio sotto il mobile, vedi draw_flat in main.gd). Uguale girata."""
    rows = []
    for y in range(32):
        row = []
        for x in range(32):
            d = min(x, y, 31 - x, 30 - y)  # l'ultima riga è l'ombra
            if y == 31:
                row.append("z" if 1 <= x <= 30 else ".")
            elif d == 0:
                row.append("o")
            elif d <= 2:
                row.append("urR"[(x + y) % 3] if d == 1 else "R")
            elif d == 3:
                row.append("o")
            elif d <= 5:
                row.append("cC"[(x * 3 + y) % 2])
            else:
                row.append(".")
        rows.append("".join(row))
    return rows


# Sopra i tetti (vedi draw_roofs in main.gd), 16x16 ciascuno: il comignolo di pietra di focolari e fornaci, lo
# sfiatatoio di legno sopra un fuoco da campo sotto un tetto. Il fumo esce dalla cima.
CHIMNEYS = """
................ ................
................ ................
.....oooooo..... ................
.....ouuuRo..... ................
.....orrrRo..... ................
.....orrRRo..... ................
.....oRRRio..... ................
.....orrrRo..... ................
.....oRRRio..... ......oooo......
.....orrRRo..... .....owwwWo.....
.....oRRRio..... ....owwwwwWo....
.....oiiiio..... ...owwwwwwwWo...
.....oooooo..... ...oooooooooo...
................ ....oooooooo....
................ ................
................ ................
"""

# Arredo fine: armadio 16x16, tappeto di pelli 32x16 (di lato, girato); il baldacchino è il letto in porpora e oro
WARDROBE = """
................
..oooooooooooo..
..oBBBBBBBBBWo..
..oooooooooooo..
..oBwwWooBwwWo..
..oBwwWooBwwWo..
..oBwwWooBwwWo..
..oBwwgoogwwWo..
..oBwwWooBwwWo..
..oBwwWooBwwWo..
..oBwwWooBwwWo..
..oBwwWooBwwWo..
..oooooooooooo..
..oWo......oWo..
..ooo......ooo..
...zzzzzzzzzz...
"""
RUG = """
................................
................................
..oooooooooooooooooooooooooooo..
..ojjjjjjjjjjjjjjjjjjjjjjjjjjo..
..ojggggggggggggggggggggggggjo..
..ojgJJJJJJJJJJJJJJJJJJJJJJgjo..
..ojgJjjjjjjjjggggjjjjjjjjJgjo..
..ojgJjjjjjjjgg88ggjjjjjjjJgjo..
..ojgJjjjjjjjgg88ggjjjjjjjJgjo..
..ojgJjjjjjjjjggggjjjjjjjjJgjo..
..ojgJJJJJJJJJJJJJJJJJJJJJJgjo..
..ojggggggggggggggggggggggggjo..
..ojjjjjjjjjjjjjjjjjjjjjjjjjjo..
..oooooooooooooooooooooooooooo..
................................
................................
"""

# Galletta 16x16: biscotto secco, coi buchi
HARDTACK_ICON = """
................
................
..oooooooooooo..
..occcccccccCo..
..occcccccccCo..
..occwccwccwCo..
..occcccccccCo..
..occcccccccCo..
..occwccwccwCo..
..occcccccccCo..
..occcccccccCo..
..occwccwccwCo..
..oCCCCCCCCCCo..
..oooooooooooo..
...zzzzzzzzzz...
................
"""

# Ricerche 12x12, nei quadratini come i talenti (vedi badge), nell'ordine di Tech in main.gd:
# forgia, sartoria, caccia, locanda, muratura (camino), decorazioni, lanterne, armi di ferro, libreria, cotta di maglia,
# fontana, statuaria

TECH_SYMBOLS_1 = """
..........9. .........oXo ............ ooooooooooo.
.ooo.....9g9 ........oxoj ......ooX... ouRRRRRRRRo.
ouuRo.....9. .......oxo.j ....oowoX... ooooooooooo.
orRRoooooo.. ......oxo..j ...owwo.X... ..o......o..
oRRRwwwwwWo. .ooooooxo.j. ..owwo..X... .oooooooooo.
oooooooooooo occcccCxCCoj ..owo...X.o. .owoxx+owWo.
ouuuuuuuuuRo occcCCCCCCoj jjjrrrrrrruo .owog8gooWo.
.orrrrrrrRRo ocjCjCjCjCo. ..owo...X.o. .owog8<owoo.
..oooorRRoo. occCCCCCCCo. ..owwo..X... .owog<<ooWo.
....oRRRio.. ocCCCCCCCWo. ...owwo.X... .owoooooWWo.
...oiiiiiio. .oWWWWWWWWo. ....oowoX... .oWWWWWWWWo.
...oooooooo. ..oooooooo.. ......ooX... .oooooooooo.
"""

TECH_SYMBOLS_2 = """
....oooo.... .........?.. .....oo..... ..........o.
....ourRo... ..j.....?g?. ....oggo.... .........ouo
....ourRo... .jgj../..?.. ..oooooooo.. .........ouo
..oooooooo.. ..j../g/.L.. ..oQ8998Eo.. ..oooo...ouo
.ouuuurrrRo. ..L...../L.. ..oQ9889Eo.. .ouuurRo.ouo
ouuuurrrrRRo ooLoooLooLoo ..oE9999Eo.. ouurrrRRoouo
oooooooooooo o&&&&&&&&&&o ..oooooooo.. orrrrrRRoouo
ouro6666oRio oBBBBBBBBBWo ....ogg<o... orrrrRRRoouo
ouro6986oRio owwwwwwwwwWo ....owWo.... oRRoooRRoggg
ouro9889oRio owcwwwwwwcWo ....owWo.... oRooRooRoowo
ourowwwWoRio oWWWWWWWWWWo ...orrRRo... oiooiooioowo
oooooooooooo oooooooooooo ...oooooo... ooo.o.oooogo
"""

TECH_SYMBOLS_3 = """
............ .oooo..oooo. .....áá..... ...oooo.....
...oooo..... ouurRooruuRo ....á00á.... ..ouurRo.o..
ooooéèo..... oururururuRo ...á.áá.á... ..ourrRooxo.
oáàoéèooooo. orururururRo ..á..áá..á.. ..orrRRooxo.
og<og<oLojjo oruoururouRo ..á.oooo.á.. ...oRRo.oRo.
oáàoéèoLojJo ooooruruoooo .á..oRRo..á. .ouurrrRowo.
oáàoéèoLmojJ ...ouruRo... oooooooooooo ourrrrrRRwo.
og<og<og<ojJ ...oruRRo... o~~~~~~~~~:o ooooooooowo.
oáàoéèoLmojJ ...ouruRo... ouuuuuuuuuRo ..ouurRo.oo.
oooooooooooo ...oruRRo... orrrrrrrrrRo ..orrRRo....
ocCCCCCCCCwo ...oRRRRo... .oRRRRRRRRo. .ouurrrRRo..
oooooooooooo ...oooooo... ..oooooooo.. .oooooooooo.
"""

# Ricerche del livello I che usano cose che ci sono già: carbonaia (il cumulo che fuma), dispensa fredda (il fiocco di
# neve), strada lastricata (le lastre), provviste secche (le gallette), cartografia (la mappa con la croce)
TECH_SYMBOLS_4 = """
.....xX..... .....00..... oooooooooooo ............ .oooooooooo.
....xX...... ..0..00..0.. ourrRourrrRo ............ oIIIIIIIIIUo
.....xX..... ...0.00.0... orrrRorrrrRo ..oooooooo.. oIoIIIIIIIUo
......X..... ....0000.... oRRRRoRRRRRo .occwccwcCo. oIIoIIIIIIUo
.....oo..... .0..0000..0. oooooooooooo .occcccccCo. oIIIIoIIIIUo
....o(_o.... 000000000000 ourrrrRourRo .oCCCCCCCCo. oIIIIIIoIIUo
...o((_(o... 000000000000 orrrrrRorrRo oooooooooooo oIIIIIIjIjUo
..o((6((_o.. .0..0000..0. oRRRRRRoRRRo occwccwccwCo oIIIIIIIjIUo
.o((((6(((o. ....0000.... oooooooooooo occcccccccCo oIIIIIIjIjUo
o(((6((((6(o ...0.00.0... ourRourrrrRo occwccwccwCo oIIIIIIIIIUo
o))))))))))o ..0..00..0.. oRRRoRRRRRRo oCCCCCCCCCCo oUUUUUUUUUUo
oooooooooooo .....00..... oooooooooooo oooooooooooo .oooooooooo.
"""

# Ricerche del ferro: palizzata (i pali appuntiti), fantoccio
TECH_SYMBOLS_5 = """
.o...o...o.. ....oooo....
oBo.oBo.oBo. ...occcCo...
oBwooBwooBwo ....oooo....
oBwWoBwWoBwo oooo*CC*oooo
oBwWoBwWoBwo owwo****owWo
oBwWoBwWoBwo oooo****oooo
oBwWoBwWoBwo ...o*CC*o...
oBwWoBwWoBwo ...o****o...
oBwWoBwWoBwo ....oooo....
oBwWoBwWoBwo .....wW.....
oBwWoBwWoBwo .....wW.....
oooooooooooo ....owWo....
"""

# Ricerche di livello II: affumicatoio (il prosciutto nel fumo), locanda rinomata (l'insegna con la stella), torre di
# guardia
TECH_SYMBOLS_6 = """
..X..X..X... oooooooooooo .....oo.....
.X..X..X.... ..o......o.. ....oFFo....
..X..X..X... ..o......o.. ...oFFfFo...
.....o...... .oooooooooo. ..oFFffFFo..
....owo..... .occccccccCo .oooooooooo.
...owwWo.... .occcc8cccCo .ow..gg..Wo.
..owwwwWo... .occ88888cCo .ow.g88g.Wo.
..owwwwWWo.. .occc888ccCo .oBBBBBBBBo.
..owwwWWWo.. .occ8ccc8cCo .ow.oBBo.Wo.
...oWWWWo... .occccccccCo .ow.o..o.Wo.
....oxxo.... .oCCCCCCCCCo .ow.oBBo.Wo.
.....oo..... .oooooooooo. .ow.o..o.Wo.
"""

# Ricerche di livello II: scudo, armeria di prestito (la rastrelliera con la spada e l'elmo)
TECH_SYMBOLS_7 = """
...oooooo... oooooooooooo
..orrrrrRo.. oWWWWWWWWWWo
.orccccccRo. oooooooooooo
orcccccccCRo ..o.....oo..
orccuuccccRo .oro...orro.
orcuurRcccRo .oro..orrrRo
orccrRRcccRo .oro..orrrRo
orcccccccCRo .oro..oRRRRo
.orcccccCRo. ooooo.oRooRo
.oRRcccCRRo. .ogo...o..o.
..ooRRRRoo.. .owo........
....oooo.... ..o.........
"""

# Ricerche di livello II: acciaio (il lingotto azzurro che sfavilla), scriptorium (la penna sulla pergamena), arredo
# fine (il baldacchino)
TECH_SYMBOLS_8 = """
........*... ........o... oooooooooooo
.......*.*.. .......oxo.. oééééééééééo
........*... ......oxXo.. oèèèèèèèèèèo
...oooooo... .....oxXo... og.o....o.go
..o00000Qo.. ....oxXo.... og.o....o.go
.o0QQQQQEEo. .oooooooooo. ogoxxxxxxogo
oQQQQQQQQEEo .oIIIIIIIUo. ogoxxxxxxogo
oEEEEEEEEEEo .oIoooooIUo. ogoééééééogo
oooooooooooo .oIIIIIIIUo. ogoèèèèèèogo
............ .oIooooIIUo. ogoooooooogo
............ .oUUUUUUUUo. og<<<<<<<<go
............ .oooooooooo. oooooooooooo
"""

# Palazzo: le torri dorate col portone
TECH_SYMBOLS_9 = """
..o......o..
.o8o....o8o.
oggo.oo.oggo
oggooggoogg<
ogggggggggg<
og<gg<<gg<g<
oggggoogggg<
og<gojjogg<<
oggggjjgggg<
oggggjjgggg<
o<<<<<<<<<<<
oooooooooooo
"""

# telaio (la tela a righe, con la frangia), stufa a olle (le piastrelle verdi, la bocca accesa), ghiacciaia (la cupola
# di ghiaccio con la porta)
TECH_SYMBOLS_10 = """
............ ............ ............
.oooooooooo. .oooooooooo. ....oooo....
.oèèèèèèèèo. .oLmLmLmLmo. ..oohhhhoo..
.oggggggggo. .omLmLmLmLo. .ohhhhhhhho.
.oèèèèèèèèo. .oLmLmLmLmo. .ohuuhhuuho.
.oèéèéèéèéo. .omLmLmLmLo. ohhhhhhhhhho
.oggggggggo. .oLmoooomLo. ohuuhoouuhho
.oèèèèèèèèo. .omLo98oLmo. ohhhho66ohho
.oèéèéèéèéo. .oLmo=8omLo. ohuuho66ouho
.oggggggggo. .oiiiiiiiio. oooooo66oooo
.oooooooooo. .oooooooooo. ............
..o.o.o.o... ............ ............
"""

# Leggi 12x12, nei quadratini color pergamena (vedi badge), nell'ordine di Law in main.gd: esenzione, decima, gabella sul
# bottino, tassa di soggiorno, turni lunghi, giornata corta, riposo festivo, coprifuoco, festa del raccolto. Sulla scheda
# dei coloni sono anche le condizioni "approva / disapprova"

LAW_SYMBOLS_1 = """
....oooo.... ...o.oo.o... ...oo..oo...
...occCWo... ..ogo8gogo.. ...o_oo(o...
....oCWo.... ..og8ggg<o.. ....o_(o....
...oyLLmo... ..o<<<<<<o.. ...owwwWo...
..ocLCCmwo.. .oooooooooo. ..o_(((()o..
.ocCLCCmCwo. occCcCcCcCco .o_(((((()o.
.ocCCCCCCwo. .ocCcCcCcCo. o_(((oo(())o
occCCCCCCCwo ..oojjjJoo.. o_((ojjo())o
ocCCCCCCCwwo ..ocCcCcCo.. o_((ojJo())o
.oCCCCCCwwo. .ocCcCcCcCo. o((((oo()))o
..owwwwwwo.. oCWCWCWCWCWo .o))))))))o.
...oooooo... oooooooooooo ..oooooooo..
"""

LAW_SYMBOLS_2 = """
............ ............ ............
.......oooo. ooooooo..o.. ooooooo.ooo.
......o8gg<o occccWo.ojo. occccWo.oLo.
......og8g<o oooooooojjJo ooooooo.oLo.
......ogg<<o .oxg<o.oojoo .oxg<o..oLo.
....oo.oooo. ..ogo...ojo. ..ogo...oLo.
oooosSoooooo ..ogo...ojo. ..ogo...oLo.
oààossssssso .o8g<o..ojo. .o8g<o.ooLoo
oààossssssSo ooooooo.ojo. ooooooooyLmo
oààoSSSSSSo. oCCCCWo.ojo. oCCCCWo.omo.
oooooooooo.. ooooooo.ooo. ooooooo..o..
............ ............ ............
"""

LAW_SYMBOLS_3 = """
..oRo..oRo.. ......o..... ............
.oooooooooo. .....oro.... .........o..
.oCCCCCCCWo. ....oro..... ..o...oooLo.
.oooooooooo. .....oro.... .oco.oc+jjo.
.oxXxXxXxXo. ....oio..... ocoooccjjJo.
.oxxxxxxxxo. ...oooooo... oCocWCcJJJo.
.oxXjjjxXxo. ...oxxxXo... oCCCWCc**9o.
.oxxjXjxxxo. ...oxxxXo... .owCWCCéèéo.
.oxXjjjxXxo. ...oxxXXo... ..owWwCèéèo.
.oxxxxxxxxo. .oooooooooo. ...oowCoèo..
.oXXXXXXXXo. .og8ggggg<o. .....owoo...
.oooooooooo. ..oooooooo.. ......o.....
"""

# Leggi di baronia e contea: taglia (il sacco del granaio con la moneta), tributo (il cuore fedele con la corona),
# granaio aperto (il granaio con le porte aperte e il grano)
LAW_SYMBOLS_4 = """
....oooo.... ............ .....oo.....
...oCcCCo... ...o.oo.o... ....oFFo....
....oCCo.... ..o8og8o8o.. ...oFFfFo...
..oocccCoo.. ..og8gg8<o.. ..oFFffFFo..
.occcccccCo. ..ogjgg<<o.. .oFFfffffFo.
occcoooooCCo ..oooooooo.. oooooooooooo
occco8g<oCCo .oojjoojjoo. .owwoooowWo.
occcog<<oCCo ojjjjjjjjjJo .owwo**owWo.
occcoooooCCo ojjjjjjjjjJo .owwo**owWo.
.occcccccCo. .ojjjjjjjJo. .owwo**owWo.
.oCCCCCCCCo. ..ojjjjjJo.. .owwo**owWo.
..oooooooo.. ...ojjJJo... .oooooooooo.
"""

# Leggi della palizzata e del fantoccio: pedaggio (la moneta sul cancello), turno di guardia (la luna e le stelle),
# milizia (i bastoni incrociati e lo scudo)
LAW_SYMBOLS_5 = """
....oooo.... ....oooo.... w..........w
...o88g<o... ..oo888o.... .w........w.
...o8g<<o... .o888oo..*.. ..w......w..
...og<<<o... .o88o....... ...woooow...
....oooo.... o88o........ ...ojjjjo...
............ o88o........ ...ojggjo...
.o..o..o..o. o88o........ ...ojggjo...
oBooBooBooBo o888o.....*. ...ojjjjo...
WWWWWWWWWWWW .o888oo..... ...woooow...
oBwoBwoBwoBw ..oo888ooo.. ..w......w..
WWWWWWWWWWWW ....ooooo... .w........w.
oooooooooooo ............ w..........w
"""

# Giustizia, caccia e corte: pene severe (la gogna), clemenza (il sovrano ascolta), riserva di caccia (il cervo), corte
# (la corona sul cuscino). Gogna e ascolto sono anche le condizioni di chi ci passa (vedi conditions)
LAW_SYMBOLS_6 = """
............ ..oooooooo.. .o.o....o.o. ............
.....oo..... .oxxxxxxxxo. .owo....owo. .o...oo...o.
.....wW..... oxxgxgxgxxXo ..owo..owo.. o8o.o88o.o8o
oooooooooooo oxxgggggxxXo ...owoowo... ogooogggoogo
occcccccccCo oxxg8g8gxxXo ....owwo.... oggggggggg<o
ocoocoocooCo oxxgggggxxXo ...ocCCco... ogjgg8ggjg<o
ocoocoocooCo .oxxxxxxxXo. ..occccCCo.. og<<<<<<<<<o
oCCCCCCCCCCo ..ooxooooo.. ..ococcoCo.. oooooooooooo
oooooooooooo ...oxo...... ...occcCo... .oJjjjjjjJo.
.....wW..... ...oo....... ...occcCo... .oJJJJJJJJo.
.....wW..... ............ ....oCCo.... .oooooooooo.
....owWo.... ............ .....oo..... ............
"""

# Accoglienza (GDD 4.2.1): porte chiuse (il cancello sbarrato tra i pilastri), porte aperte (i battenti aperti, la strada
# che entra), giuramento (la mano alzata)
# Funerali (Law.FUNERALS): la croce sul tumulo, con un fiore
LAW_FUNERALS = """
....oooo....
....owWo....
..ooowWooo..
..owwwwwWo..
..oWWWWWWo..
..ooowWooo..
....owWo....
....owWo....
..ooowWooo..
.o((((((()o.
o((?((((())o
oooooooooooo
"""

LAW_SYMBOLS_7 = """
............ ............ ....o.o.o...
ooo......ooo ooo......ooo ...osososo..
orooooooooro orow....woro ...osososo..
orowwWwwWoro orow....woro ...osososo..
orowwWwwWoro orow.cc.woro .o.osososo..
orojjjjjjoro orow.cc.woro osoosssssSo.
oroJJJJJJoro orow.cc.woro ossssssssSo.
orowwWwwWoro orow.cc.woro .osssssssSo.
orowwWwwWoro orow.cc.woro ..ossssssSo.
orowwWwwWoro orowcccCworo ...ossssSo..
orooooooooro oroocccCooro ...ojjjjJo..
ooo......ooo oooccccCCooo ...oooooo...
"""

# Rami dell'albero del sapere 12x12, nei quadratini: terra (spiga), fuoco (fiamma), pietra (mattoni), ferro (spada e
# scudo), strada (rosa dei venti), sapere (lucerna)

BRANCH_SYMBOLS_1 = """
.o..o..o.... ......oo.... ............
..o.o.o..... .....o=o.... oooooooooooo
..oo8oo..... ....o=9o.... ouuurouuuuro
.o8go8go.... ...o=99=o... orrrRorrrrRo
.og<og<o.... ..o=9989=o.. oooooooooooo
..o8go8go... ..o=9889=o.. ourouuurouro
..og<og<o... .o=988899=o. orRorrrRorRo
...o8go8go.. .o=988889=o. oooooooooooo
...og<og<o.. .o=988889=o. ouuurouuuuro
....ooo<oo.. .o=988889=o. orrrRorrrrRo
.......o<o.. ..o=9999=o.. oooooooooooo
........oo.. ...oooooo... ............
"""

BRANCH_SYMBOLS_2 = """
.....oo..... .....o...... .......o....
....ouro.... ....ojo..... ......o9o...
.oooouroooo. ...ojjJo.... ......o89o..
.ojjjurjjJo. ..oojjJoo... .....o9889o.
.ojjjurjjJo. .ouu8ggRRo.. .....o9889o.
.ojjjurjjJo. ouuugo<RRRo. ......o==o..
o8gggggggg<o .oRRg<<RRo.. ..oooooooooo
.oojjwWJJoo. ..oouRRoo... oo8ggggggg<o
..oojwWJoo.. ...ouRRo.... o.ogggggg<<o
....owWo.... ....oRo..... oooo<<<<<<o.
....o8<o.... .....o...... ....oooooo..
.....oo..... ............ ............
"""

# Condizione "festa" (dopo la festa del raccolto): due calici che brindano, 12x12 al centro della casella 16x16.
FEAST_SYMBOL = """
............
.....oo.....
....ojJo....
oooooooooooo
ojjjJoojjjJo
o8gg<oo8gg<o
.og<o..og<o.
..oo....oo..
..oo....oo..
.o8<o..o8<o.
.oooo..oooo.
............
"""


def frames(block, height=16, count=3, width=16):
    """Blocco di testo -> lista di fotogrammi, ognuno `height` righe da `width` caratteri."""
    rows = [line.split() for line in block.strip().splitlines()]
    assert len(rows) == height, f"servono {height} righe, ce ne sono {len(rows)}"
    for i, r in enumerate(rows):
        assert len(r) == count and all(len(f) == width for f in r), f"riga {i}: {r}"
    return [[r[i] for r in rows] for i in range(count)]


def art(block, width, height):
    rows = block.strip().splitlines()
    assert len(rows) == height, f"servono {height} righe, ce ne sono {len(rows)}"
    for i, r in enumerate(rows):
        assert len(r) == width, f"riga {i}: {len(r)} caratteri invece di {width}"
    return rows


def badge(symbol, fill="{", light="}", shadow="|"):
    """Talento 16x16: quadratino col contorno, luce in alto a sinistra e ombra in basso a destra (in rilievo,
    al contrario degli slot dell'equipaggiamento), e il simbolo 12x12 al centro. Le leggi lo hanno color pergamena."""
    inner = [light * 13 + shadow] + [light + fill * 12 + shadow] * 12 + [light + shadow * 13]
    rows = ["o" * 16] + ["o" + line + "o" for line in inner] + ["o" * 16]
    for y, line in enumerate(symbol):
        rows[y + 2] = rows[y + 2][:2] + "".join(ch if ch != "." else rows[y + 2][x + 2] for x, ch in enumerate(line)) + rows[y + 2][14:]
    return rows


def side_by_side(fs):
    return ["".join(f[y] for f in fs) for y in range(len(fs[0]))]


def breath(f):
    """Fermo che espira: testa e spalle scendono di 1px (sparisce la prima riga del busto), mani e gambe restano."""
    return ["." * 16] + f[:9] + f[10:]


def sheet():
    """Coloni, foglio 128x64. Righe: giù, sinistra, destra (specchio), su.
    Colonne: fermo, passo A, passo B, carica, colpo, respiro (ricavato dal fermo), arco a corda lenta, arco teso."""
    down, left, up = ([*fs, breath(fs[0]), *bow_frames(bow, False)]
                      for fs, bow in ((frames(b, count=5), bow) for b, bow in ((DOWN, BOW_DOWN), (LEFT, BOW_LEFT), (UP, BOW_UP))))
    right = [mirror(f) for f in left]
    return [row for fs in (down, left, right, up) for row in side_by_side(fs)]


BOW_CHARS = "wxcu"  # in BOW_*: legno dell'arco, corda, freccia, punta -> stanno in mano (vedi hand_sheet)


def bow_frames(block, held):
    """I due fotogrammi dell'arco di un blocco BOW_*: held=True solo arco e freccia (in mano), False il colono."""
    return [["".join(ch if (ch in BOW_CHARS) == held else "." for ch in line) for line in f] for f in frames(block, count=2)]


def stamp(parts):
    """Fotogramma 16x16 trasparente coi timbri (colonna, riga, righe) sopra."""
    grid = [["."] * 16 for _ in range(16)]
    for x, y, rows in parts:
        for dy, line in enumerate(rows.split()):
            for dx, ch in enumerate(line):
                if ch != "." and 0 <= x + dx < 16 and 0 <= y + dy < 16:
                    grid[y + dy][x + dx] = ch
    return ["".join(r) for r in grid]


def figure_sheet(down, left, up):
    """Un livello sopra il colono, foglio 128x64 come sheet(): per direzione i suoi 8 fotogrammi (destra = sinistra specchiata)."""
    return [row for fs in (down, left, [mirror(f) for f in left], up) for row in side_by_side(fs)]


def still_sheet(poses):
    """Livello che segue il busto: il fotogramma da fermo di ogni direzione, nel colpo e nel respiro si abbassa come il busto
    (con l'arco no)."""
    def eight(parts):
        f = stamp(parts)
        return [f] * 4 + [breath(f)] * 2 + [f] * 2
    return figure_sheet(eight(poses["down"]), eight(poses["left"]), eight(poses["up"]))


def hand_sheet(name):
    """Quello che il colono tiene: in carica e colpo la sua posa, negli altri fotogrammi al fianco o sulla schiena.
    L'arco, negli ultimi due (corda lenta, teso), come lo disegnano BOW_*."""
    poses, back = HANDS[name], name in ON_THE_BACK
    get = lambda pose: stamp(poses.get(pose, []))
    def eight(rest, strike, bow, raise_=None):
        f = get(rest)
        aim = bow_frames(bow, True) if name == "bow" else [f, f]
        return [f] * 3 + [get(raise_ or "down_raise"), get(strike), breath(f) if back else f, *aim]
    return figure_sheet(eight("down_rest", "down_strike", BOW_DOWN), eight("left_rest", "left_strike", BOW_LEFT, "left_raise"),
                        eight("up_rest", "up_strike", BOW_UP))


def derived(grid, recolor):
    """Livello ricavato da sheet(): recolor(carattere, x, y nel fotogramma, colonna del fotogramma, direzione) -> carattere."""
    return ["".join(recolor(ch, x % 16, y % 16, x // 16, y // 16) for x, ch in enumerate(line))
            for y, line in enumerate(grid)]


def helmet(grid):
    """Elmo d'acciaio: i capelli fino alla fronte (l'ultima riga fa da bordo, più scura), luce sul colmo; da davanti un nasale."""
    def recolor(ch, x, y, frame, side):
        top = BROW + (1 if frame in (4, 5) else 0)  # nel colpo e nel respiro la testa è 1px più giù
        if side == 0 and x == 8 and y in (top, top + 1) and ch in "sS":
            return "R"  # nasale
        if ch not in "hH" or y > top:
            return "."
        if y == top or ch == "H":
            return "R"
        return "u" if grid[y - 1 + 16 * side][x + 16 * frame] not in "hH" else "r"  # sul bordo in alto prende luce
    return derived(grid, recolor)


def hood(grid):
    """Cappuccio, tinto in gioco (bianco/grigio): copre i capelli, più scuro attorno alla faccia, e scende sulle spalle
    (HOOD_MANTLE)."""
    def recolor(ch, x, y, frame, side):
        if ch not in "hH":
            return "."
        row, col = y + 16 * side, x + 16 * frame
        face = any(grid[row + dy][col + dx] in "sSe" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                   if 0 <= x + dx < 16 and 0 <= y + dy < 16)
        return "K" if face or ch == "H" else "k"
    mantle = still_sheet(HOOD_MANTLE)
    return [''.join(m if m != "." else h for h, m in zip(line, over))
            for line, over in zip(derived(grid, recolor), mantle)]


def armor(grid, kind):
    """Armatura sopra la tunica: cuoio (marrone con le cuciture) o cotta di maglia (anelli chiari e scuri a scacchi)."""
    def recolor(ch, x, y, frame, side):
        if ch not in "tT":
            return "."
        if kind == "chainmail":
            return ("r" if (x + y) % 2 else "R") if ch == "t" else ("R" if (x + y) % 2 else "i")
        return ("B" if ch == "t" else "w") if (x + y) % 4 else "W"
    return derived(grid, recolor)


def gear_sheets(grid):
    """colonist_gear.png: un foglio 128x64 per livello di GEAR_LAYERS, uno sotto l'altro."""
    made = {"leather_armor": armor(grid, "leather"), "chainmail": armor(grid, "chainmail"),
            "helmet": helmet(grid), "hood": hood(grid)} | {name: still_sheet(KIT[name]) for name in KIT}
    return [line for name in GEAR_LAYERS for line in made[name]]


def rotate(grid):
    """90° in senso orario."""
    return ["".join(row[i] for row in reversed(grid)) for i in range(len(grid[0]))]


def turns(grid):
    """Un pezzo e le sue rotazioni di 90° in senso orario."""
    out = [grid]
    for _ in range(3):
        out.append(rotate(out[-1]))
    return out


def wall(top, front, links):
    """Muro per i lati collegati `links`: bit 1 su, 2 destra, 4 giù, 8 sinistra (come WALL_LINKS in main.gd).
    Collegato in giù si vede solo la cima: la facciata è quella del muro più in basso."""
    up, right, down, left = (links >> i & 1 for i in range(4))
    rows = [list(line) for line in (top if down else top[:5] + ["o" * 16] + front)]
    if not up:
        rows[0] = list("o" * 16)
    for y, row in enumerate(rows):
        for x, linked in ((0, left), (15, right)):
            # di fianco a una cima che scende c'è la facciata del vicino: serve il bordo anche se collegati
            if not linked or (down and y >= 5):
                row[x] = "o"
    return ["".join(r) for r in rows]


def palisade(links):
    """Palizzata per i lati collegati `links` (come wall): pali di 4 pixel (bordo, luce, legno, ombra), appuntiti in
    cima se sopra non continua, chiusi in fondo se sotto non continua, col bordo ai lati liberi."""
    up, right, down, left = (links >> i & 1 for i in range(4))
    rows = []
    for y in range(16):
        tip = "" if up else {0: ".o..", 1: "oBo.", 2: "oBwo"}.get(y, "")
        rows.append(list((tip or "oBwW") * 4))
    if not down:
        rows[15] = list("o" * 16)
    if not right:
        for row in rows:
            if row[15] != ".":
                row[15] = "o"
    return ["".join(r) for r in rows]


def gate():
    """Cancello nella palizzata, di fronte: assi strette appuntite, due traverse scure, il paletto d'oro."""
    rows = []
    for y in range(16):
        row = []
        for x in range(15):
            k, i = divmod(x, 3)
            if y == 0:
                row.append("o" if i == 1 else ".")
            elif y == 1:
                row.append("oBo"[i])
            elif y in (5, 11):
                row.append("W" if i else "o")
            else:
                row.append("oBw"[i])
        row.append("o" if y else ".")
        rows.append(row)
    rows[8][13] = "g"
    rows[15] = list("o" * 16)
    return ["".join(r) for r in rows]


def structures_sheet():
    """Costruzioni, foglio 256x176. Righe: muri di legno, muri di pietra (colonna = lati collegati, vedi wall),
    pavimenti (legno, pietra, sentiero, strada lastricata), porte (di fronte, di lato), erba che sborda sui pavimenti: lati (prato
    sopra, a destra, sotto, a sinistra) e angoli (prato in alto a sx, alto a dx, basso a dx, basso a sx), due varianti;
    la palizzata (colonna = lati collegati, vedi palisade), il cancello (di fronte, di lato); i muri di legno intonacati."""
    tops, fronts = frames(WALL_TOPS, count=2), frames(WALL_FRONTS, height=10, count=2)
    rows = [[wall(tops[m], fronts[m], links) for links in range(16)] for m in range(2)]
    edges = frames(FLOOR_EDGE, count=4)  # lato, angolo, lato, angolo
    rows += [frames(FLOORS, count=4), frames(DOORS, count=2)] + [turns(e) for e in edges]
    rows += [[palisade(links) for links in range(16)], [gate(), frames(DOORS, count=2)[1]]]  # cancello di lato: come la porta
    rows += [[wall(tops[0], art(PLASTER_FRONT, 16, 10), links) for links in range(16)]]  # muri di legno intonacati
    empty = ["." * 16] * 16
    return [line for fs in rows for line in side_by_side(fs + [empty] * (16 - len(fs)))]


def ground_sheet():
    """Terreno, foglio 64x176. Righe: erba, erba sassosa, ghiaia, acqua bassa, acqua alta (4 varianti);
    poi i lati (vicino su, destra, giù, sinistra) e gli angoli (vicino in alto a sx, alto a dx, basso a dx,
    basso a sx) di: erba sulla ghiaia, riva, acqua bassa su quella alta."""
    rows = [frames(b, count=4) for b in (GRASS, STONY_GRASS, GRAVEL, SHALLOW, DEEP)]
    edges = [frames(b, count=2) for b in (GRASS_EDGE, SHORE, SHALLOW_EDGE)]  # [lato, angolo]
    rows += [turns(side) for side, _ in edges] + [turns(corner) for _, corner in edges]
    return [line for fs in rows for line in side_by_side(fs)]


def mirror(grid):
    return [line[::-1] for line in grid]


def double(grid):
    """Ogni pixel 2x2: per l'interfaccia, che non passa dallo zoom della camera."""
    return ["".join(ch * 2 for ch in line) for line in grid for _ in range(2)]


# ---- Stemma della casata (vedi arms_texture in main.gd) ----
# Forme dello scudo 16x16, nell'ordine di Shape: bordo scuro, dentro "x" (il campo, colorato in gioco).
ARMS_SHAPES = """
oooooooooooooooo oooooooooooooooo .....oooooo..... .......oo.......
o##############o o##############o ...oo######oo... ......o##o......
o##############o o##############o ..o##########o.. .....o####o.....
o##############o o##############o .o############o. ....o######o....
o##############o o##############o .o############o. ...o########o...
o##############o o##############o o##############o ..o##########o..
o##############o o##############o o##############o .o############o.
o##############o o##############o o##############o o##############o
.o############o. o##############o o##############o o##############o
.o############o. o##############o o##############o .o############o.
..o##########o.. o##############o o##############o ..o##########o..
..o##########o.. o##############o .o############o. ...o########o...
...o########o... .o############o. .o############o. ....o######o....
....o######o.... ..oo########oo.. ..o##########o.. .....o####o.....
.....oo##oo..... ....ooo##ooo.... ...oo######oo... ......o##o......
.......oo....... .......oo....... .....oooooo..... .......oo.......
"""

# Figure 8x8 (al centro dello scudo), nell'ordine di Charge: stella, crescente, giglio, rosa, torre, corona, spada,
# chiave, albero, aquila. Senza bordo: le stacca il campo (metallo su colore, colore su metallo).
ARMS_CHARGES = """
...##... ........ ...##... ..####.. #.#..#.# ........ ...##... ..####.. ..####.. ...##...
...##... #......# ..####.. .#.##.#. ######## #..##..# ...##... .##..##. .######. #..##..#
######## ##....## #..##..# ###..### .######. ##.##.## ...##... .##..##. ######## ##.##.##
.######. ###..### ##.##.## ##.##.## .##..##. ######## ...##... ..####.. ######## ########
..####.. .######. ######## ###..### .######. ######## ######## ...##... .######. .######.
.##..##. ..####.. ..####.. .#.##.#. .######. .######. ...##... ...##... ...##... ...##...
##....## ........ ...##... ..####.. .##..##. ........ ...##... ...####. ...##... ..#..#..
........ ........ ..####.. ........ .##..##. ........ ..####.. ...###.. .######. .#....#.
"""

# Le stesse figure 5x5, per il drappo dello stendardo (largo 7).
ARMS_SMALL = """
..#.. ..... ..#.. .###. #.#.# ..... ..#.. .###. .###. ..#..
##### #...# #.#.# ##.## ##### #.#.# ..#.. .#.#. ##### #.#.#
.###. ##.## ##### #.#.# .###. ##### ##### .###. ##### #####
.#.#. .###. ..#.. ##.## .###. ##### ..#.. ..#.. ..#.. .###.
#...# ..... .###. .###. .#.#. ..... .###. ..##. .###. .#.#.
"""

# Corone dei titoli 16x6, sopra lo scudo (l'ultima riga sul suo bordo): baronia (cerchio), contea (a punte), regno
# (corona reale, con la croce). La signoria non ne ha.
ARMS_CROWNS = """
................ ................ .......oo.......
................ ..o....oo....o.. ..o..o88<<o..o..
................ .o8o..o8<o..o8o. .o8o.oo8<oo.o8o.
.oooooooooooooo. .og<oog88goog<o. .og<oog8<goog<o.
.og8gjgg8gàgg<o. .og8gjgg8gjgg<o. .ogjg8gàg8gjg<o.
.oooooooooooooo. .oooooooooooooo. .oooooooooooooo.
"""


def arms_sheet():
    """Stemmi, foglio 80x35: in alto le forme (16x16), sotto le figure 8x8, poi quelle 5x5, in fondo le corone 16x6.
    "x" chiaro: da colorare."""
    pad = lambda rows: [line.replace("#", "x").ljust(80, ".") for line in rows]
    return (pad(side_by_side(frames(ARMS_SHAPES, count=4))) + pad(side_by_side(frames(ARMS_CHARGES, 8, 10, 8)))
            + pad(side_by_side(frames(ARMS_SMALL, 5, 10, 5))) + pad(side_by_side(frames(ARMS_CROWNS, 6, 3, 16))))


def banner_drape():
    """Il drappo dello stendardo nei 4 fotogrammi di BANNER, 64x16: "x" la stoffa alla luce, "X" in ombra (la piega che
    ondeggia). La corona ("g" dentro il drappo) è stoffa: sopra ci va lo stemma."""
    def cloth(ch, x):
        return "x" if ch == "j" or (ch == "g" and x >= 5) else ("X" if ch == "J" else ".")
    return side_by_side([["".join(cloth(ch, x) for x, ch in enumerate(line)) for line in f] for f in frames(BANNER, count=4)])


def furniture_sheet():
    """Mobili, foglio 128x1152. Righe: letto, tavolo, sedia, abat-jour, fuoco da campo, fornace, incudine, banco da lavoro,
    filatoio, banco del falegname, poi le decorazioni: aiuola, fioriera, panca, stendardo, lampione, fontana, statua;
    la bacheca; i cimeli: calice, stendardo antico, busto, corona; scrittoio, libreria, trono, fantoccio, torre di guardia, baldacchino, tappeto, armadio, focolare, pelli alle pareti, portiera, arazzo, stufa a olle, fossa del ghiaccio, quattro righe vuote (le strutture che vengono dopo
    in Build), il cumulo del compost, la culla; la rastrelliera, il bersaglio e il banco degli scassi (come Build in main.gd);
    colonne: quarti di giro in senso orario (per fuoco, stendardo e fontana, fotogrammi), ognuno in alto a sinistra nel suo riquadro 32x32."""
    bed, chair, chair_left = art(BED, 32, 16), art(CHAIR, 16, 16), art(CHAIR_LEFT, 16, 16)
    table, lamp, anvil = art(TABLE, 32, 32), art(LAMP, 16, 16), art(ANVIL, 16, 16)
    workbench, wheel, carpenter = art(WORKBENCH, 16, 16), art(SPINNING_WHEEL, 16, 16), art(CARPENTER_BENCH, 16, 16)
    bench, bench_side = art(BENCH, 32, 16), art(BENCH_SIDE, 16, 32)
    canopy = lambda f: [line.translate(str.maketrans("jJBw", "éèg<")) for line in f]  # il letto in porpora e oro
    rug = art(RUG, 32, 16)
    rug_side = ["".join(row[x] for row in rug) for x in range(32)]  # girato di un quarto: righe e colonne scambiate
    rows = [[bed, art(BED_UP, 16, 32), mirror(bed), art(BED_DOWN, 16, 32)],
            [table] * 4,  # simmetrici: girarli non cambia il disegno
            [chair, chair_left, art(CHAIR_UP, 16, 16), mirror(chair_left)],
            [lamp] * 4,
            frames(CAMPFIRE, count=4),
            [art(FURNACE, 16, 16)] * 4,
            [anvil, mirror(anvil)] * 2,
            [workbench, mirror(workbench)] * 2,
            [wheel, mirror(wheel)] * 2,
            [carpenter, mirror(carpenter)] * 2,
            [art(FLOWER_BED, 16, 16)] * 4,
            [art(PLANTER, 16, 16)] * 4,
            [bench, bench_side] * 2,
            frames(BANNER, count=4),
            [art(LANTERN, 16, 16)] * 4,
            frames(FOUNTAIN, height=32, count=4, width=32),
            [art(STATUE, 32, 32)] * 4,
            [art(NOTICE_BOARD, 16, 16)] * 4] + [[art(r, 16, 16)] * 4 for r in (CHALICE, OLD_BANNER, BUST, CROWN)] \
        + [[art(DESK, 16, 16), mirror(art(DESK, 16, 16))] * 2, [art(BOOKSHELF, 16, 16)] * 4, [art(THRONE, 16, 16)] * 4,
           [art(DUMMY, 16, 16)] * 4, [art(WATCHTOWER, 16, 16)] * 4,
           [canopy(f) for f in (bed, art(BED_UP, 16, 32), mirror(bed), art(BED_DOWN, 16, 32))],
           [rug, rug_side, rug, rug_side], [art(WARDROBE, 16, 16)] * 4,
           (lambda h: [h[0], h[1], h[2], mirror(h[1])])(frames(HEARTH)),
           (lambda h: [h[0], h[1], h[2], mirror(h[1])])(frames(WALL_HIDES)),
           (lambda h, c: [c[0], h[1], c[1], mirror(h[1])])(frames(WALL_HIDES), frames(DOOR_CURTAIN, count=2)),
           (lambda h: [h[0], h[1], h[2], mirror(h[1])])(frames(TAPESTRY)),
           [art(TILED_STOVE, 16, 16)] * 4, [ice_pit()] * 4]
    rows += [[]] * 4  # strada, palizzata, cancello, intonaco: strutture, non mobili
    rows += [[art(COMPOST_HEAP, 16, 16)] * 4]
    rows += [[art(CRADLE, 16, 16)] * 4]  # dopo, come Build in main.gd
    rows += [[art(f, 16, 16)] * 4 for f in (WEAPON_RACK, TARGET, LOCK_BENCH)]  # la caserma
    rows += [[art(MEDICINE_CHEST, 16, 16)] * 4]
    rows += [[grave(False, True), grave(False, False), grave(True, True), grave(True, False)]]
    rows += [[art(MEMORIAL, 16, 16)] * 4]
    slot = lambda g: [line.ljust(32, ".") for line in g] + ["." * 32] * (32 - len(g))
    return [line for row in rows for line in side_by_side([slot(g) for g in (row or [[]] * 4)])]


def trees_sheet():
    """Alberi, foglio 48x32: quercia, pino, betulla."""
    return side_by_side(frames(TREES, TREES_HEIGHT))


def write_png(path, rows):
    """rows: righe di pixel (r, g, b, a)."""
    raw = b"".join(b"\0" + bytes(v for px in row for v in px) for row in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    header = struct.pack(">IIBBBBB", len(rows[0]), len(rows), 8, 6, 0, 0, 0)  # 8 bit RGBA
    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
                           + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def rgba(ch, palette=PALETTE):
    c = bytes.fromhex(palette[ch])
    return tuple(c) + (255,) * (4 - len(c))  # RRGGBB o RRGGBBAA


def night_palette():
    def tint(h):
        return "".join(f"{round(int(h[i:i + 2], 16) * t):02x}" for i, t in zip((0, 2, 4), NIGHT_TINT)) + h[6:]
    return {ch: tint(h) for ch, h in PALETTE.items()} | NIGHT_LIGHTS


def pixels(grid, chars=None, palette=PALETTE):
    """chars = caratteri da tenere (None = tutti)."""
    return [[rgba(ch, palette) if ch != "." and (chars is None or ch in chars) else (0, 0, 0, 0) for ch in line]
            for line in grid]


def main():
    grid = sheet()
    all_chars = set("".join(LAYERS.values()))
    unknown = set("".join(grid)) - {"."} - all_chars
    assert not unknown, f"caratteri senza livello: {unknown}"
    out = Path(__file__).resolve().parent.parent / "art"
    out.mkdir(exist_ok=True)
    images = {name: pixels(grid, chars) for name, chars in LAYERS.items()}
    # sopra il colono, un foglio 128x64 per voce, uno sotto l'altro: acconciature (tinte), equipaggiamento, in mano
    images["colonist_hair_styles"] = pixels([line for name in HAIR_STYLES for line in still_sheet(HAIR_STYLES[name])])
    images["colonist_gear"] = pixels(gear_sheets(grid))
    images["colonist_hands"] = pixels([line for name in HANDS for line in hand_sheet(name)])
    images["trees"] = pixels(trees_sheet())
    images["icon_wood"], images["icon_stone"], images["icon_veg"] = (pixels(f) for f in frames(ICONS))
    images["plants"] = pixels(side_by_side(frames(PLANTS, count=7)))
    images["icon_build"] = pixels(art(BUILD_ICON, 15, 15))
    images["icon_cancel"] = pixels(art(CANCEL_ICON, 16, 16))
    images["icon_destroy"] = pixels(art(DESTROY_ICON, 15, 15))
    images["icon_mine"] = pixels(art(MINE_ICON, 16, 16))
    images["icon_orders"] = pixels(orders_icon())
    images["icon_views"] = pixels(views_icon())
    images["icon_chop"] = pixels(art(CHOP_ICON, 16, 16))
    images["icon_uproot"] = pixels(art(UPROOT_ICON, 16, 16))
    images["icon_harvest"] = pixels(art(HARVEST_ICON, 16, 16))
    crops = frames(CROPS, count=7) + frames(BEANS, count=3)
    images["crops"] = pixels(side_by_side(crops))
    images["icon_turnip"] = pixels(["." * 16] + crops[3][:15])  # le piante mature, un po' più giù: rapa e cavolo raccolti
    images["icon_cabbage"] = pixels(["." * 16] * 2 + crops[6][:14])
    images["icon_beans"] = pixels(["." * 16] + crops[9][:15])
    images["field_sign"] = pixels(art(FIELD_SIGN, 16, 16))
    images["icon_soil"] = pixels(art(SOIL_ICON, 16, 16))
    images["icon_rot"], images["icon_compost"], images["icon_ash"] = (pixels(f) for f in frames(MANURE_ICONS))
    images["icon_garden"] = pixels(art(GARDEN_ICON, 16, 16))
    images["icon_fishing"] = pixels(art(FISHING_ICON, 16, 16))
    images["icon_hunting"] = pixels(art(HUNTING_ICON, 16, 16))
    images["icon_meat"], images["icon_fish"] = (pixels(f) for f in frames(RAW_ICONS, count=2))
    for name, f in zip(["hide", "ingot", "sickle", "leather_armor", "leather_hood", "helmet", "chainmail"], frames(ITEMS, count=7)):
        images["icon_" + name] = pixels(f)
    images["icon_sword"] = pixels(art(SWORD, 16, 16))
    images["icon_dagger"] = pixels(art(DAGGER, 16, 16))
    images["icon_gold"] = pixels(art(GOLD, 16, 16))
    images["icon_coin"] = pixels(double(art(COIN, 8, 8)))
    for name, rows in ITEM_KINDS.items():
        images["kind_" + name] = pixels(double(rows))
    for name, block in (("chalice", CHALICE), ("old_banner", OLD_BANNER), ("bust", BUST), ("crown", CROWN)):
        images["icon_" + name] = pixels(art(block, 16, 16))
    images["icon_flax"] = pixels(art(FLAX_ICON, 16, 16))
    images["icon_doctor"] = pixels(art(DOCTOR_ICON, 16, 16))
    images["icon_herbs"] = pixels(art(HERBS_ICON, 16, 16))
    images["icon_ointment"] = pixels(art(OINTMENT_ICON, 16, 16))
    images["icon_bowstring"] = pixels(art(BOWSTRING_ICON, 16, 16))
    images["icon_hardtack"] = pixels(art(HARDTACK_ICON, 16, 16))
    images["icon_shield"] = pixels(art(SHIELD_ICON, 16, 16))
    images["icon_parchment"] = pixels(art(PARCHMENT_ICON, 16, 16))
    images["icon_ink"] = pixels(art(INK_ICON, 16, 16))
    ingot = frames(ITEMS, count=7)[1]
    images["icon_steel"] = pixels([line.translate(str.maketrans("urRi", "0QEE")) for line in ingot])  # il lingotto azzurrato
    meat, fish = frames(RAW_ICONS, count=2)  # affumicati: la carne bruna, il pesce dorato
    images["icon_smoked_meat"] = pixels([line.translate(str.maketrans("jJs", "wWc")) for line in meat])
    images["icon_smoked_fish"] = pixels([line.translate(str.maketrans("urR", "c<W")) for line in fish])
    images["animals"] = pixels(art(ANIMALS.replace(" ", ""), 32, 48))
    images["sign"] = pixels(art(SIGN, 16, 16))
    images["structures"] = pixels(structures_sheet())
    images["rock_1x1"] = pixels(art(ROCK_1X1, 16, 16))
    images["rock_2x1"] = pixels(art(ROCK_2X1, 32, 16))
    images["rock_2x2"] = pixels(art(ROCK_2X2, 32, 32))
    images["rock_iron"] = pixels(art(ROCK_IRON, 16, 16))
    images["rock_coal"] = pixels(art(ROCK_COAL, 16, 16))
    images["icon_iron"], images["icon_coal"] = (pixels(f) for f in frames(ORE_ICONS, count=2))
    images["icon_meal"], images["icon_fine_meal"] = (pixels(f) for f in frames(MEALS, count=2))
    feast = ["." * 16] * 2 + [".." + line + ".." for line in art(FEAST_SYMBOL, 12, 12)] + ["." * 16] * 2
    pad12 = lambda f: ["." * 16] * 2 + [".." + line + ".." for line in f] + ["." * 16] * 2  # simbolo 12x12 in 16x16
    pillory, heard = frames(LAW_SYMBOLS_6, 12, 4, 12)[:2]
    # lutto regale (Cond.ROYAL_MOURNING): la corona dei cimeli, grigia su un cuscino nero; incoronazione: quella d'oro
    mourning_crown = [line.translate(str.maketrans("g8</jJ", "ruRuio")) for line in art(CROWN, 16, 16)]
    images["conditions"] = pixels(side_by_side(frames(CONDITIONS, count=6) + [feast, pad12(pillory), pad12(heard),
                                                                              art(WEDDING, 16, 16), art(BABY, 16, 16),
                                                                              mourning_crown, art(CROWN, 16, 16),
                                                                              art(FOREIGNER, 16, 16), art(INSPIRED, 16, 16),
                                                                              art(FEVER, 16, 16), art(TREATED, 16, 16),
                                                                              art(FAREWELL, 16, 16)]))
    images["baby"] = pixels(art(BABY, 16, 16))
    images["ground"] = pixels(ground_sheet())
    images["warehouse_day"] = pixels(art(WAREHOUSE, 64, 32))
    images["warehouse_night"] = pixels(art(WAREHOUSE, 64, 32), palette=night_palette())
    images["furniture"] = pixels(furniture_sheet())
    images["arms"] = pixels(arms_sheet())
    images["banner_drape"] = pixels(banner_drape())
    images["furniture_night"] = pixels(furniture_sheet(), palette=PALETTE | NIGHT_LIGHTS)  # solo le luci cambiano
    images["furniture_glow"] = pixels(furniture_sheet(), chars=NIGHT_LIGHTS, palette=PALETTE | NIGHT_LIGHTS)  # solo le luci
    rotate_icon = art(ROTATE_ICON, 16, 16)
    images["icon_rotate_right"] = pixels(rotate_icon)
    images["icon_dice"] = pixels(art(DICE_ICON, 16, 16))
    images["icon_rotate_left"] = pixels(mirror(rotate_icon))
    images["frame_wood"] = pixels(double(art(WOOD_FRAME, 9, 9)))
    images["frame_selected"] = pixels(double(art(SELECTED_FRAME, 15, 15)))
    images["icon_select"] = pixels(art(SELECT_ICON, 16, 16))
    images["icon_jobs"] = pixels(art(JOBS_ICON, 16, 16))
    images["icon_resources"] = pixels(art(RESOURCES_ICON, 16, 16))
    images["icon_colonists"] = pixels(art(COLONISTS_ICON, 16, 16))
    images["icon_options"] = pixels(art(OPTIONS_ICON, 16, 16))
    images["icon_keybindings"] = pixels(art(KEYBINDINGS_ICON, 16, 16))
    images["icon_game"] = pixels(art(GAME_ICON, 16, 16))
    for name, f in zip(["pause", "play", "fast", "fastest"], frames(SPEED_ICONS, count=4)):
        images["icon_" + name] = pixels(f)
    images["icon_screen"] = pixels(art(SCREEN_ICON, 16, 16))
    images["icon_audio"] = pixels(art(AUDIO_ICON, 16, 16))
    images["icon_debug"] = pixels(art(DEBUG_ICON, 16, 16))
    images["icon_wiki"] = pixels(art(WIKI_ICON, 16, 16))
    images["icon_roofs"] = pixels(art(ROOFS_ICON, 16, 16))
    images["icon_heat"] = pixels(art(HEAT_ICON, 16, 16))
    images["weather"] = pixels(side_by_side(frames(WEATHER_ICONS, count=9) + [art(WOLF_ALERT, 16, 16)]))
    images["roof_wear"] = pixels(side_by_side(frames(ROOF_WEAR)))
    images["chimneys"] = pixels(side_by_side(frames(CHIMNEYS, count=2)))
    block = art(ICE_BLOCK, 16, 16)
    images["icon_ice_block"] = pixels(block)
    images["icon_bucket"] = pixels(art(BUCKET, 16, 16))
    images["icon_ice"] = pixels(["".join(ICE_SAW.get((x, y), ch) for x, ch in enumerate(line)) for y, line in enumerate(block)])
    symbols = [f for block in (TRAITS_1, TRAITS_2, TRAITS_3) for f in frames(block, 12, 5, 12)]
    images["traits"] = pixels(side_by_side([badge(f) for f in symbols]))
    gifts = [f for block in (HERO_TRAITS_1, HERO_TRAITS_2, HERO_TRAITS_3, HERO_TRAITS_4) for f in frames(block, 12, 4, 12)]
    images["hero_traits"] = pixels(side_by_side([badge(f) for f in gifts]))
    images["icon_star"] = pixels(art(STAR, 9, 9))
    images["icon_notebook"], images["icon_tome"], images["icon_codex"] = (pixels(f) for f in frames(BOOK_ICONS))
    images["icon_study"] = pixels(art(STUDY_ICON, 16, 16))
    images["icon_authority"] = pixels(art(AUTHORITY_ICON, 16, 16))
    techs = [f for block in (TECH_SYMBOLS_1, TECH_SYMBOLS_2, TECH_SYMBOLS_3) for f in frames(block, 12, 4, 12)]
    techs += frames(TECH_ASTRONOMY, 12, 1, 12)  # come Tech in main.gd: astronomia, poi le altre
    techs += frames(TECH_SYMBOLS_4, 12, 5, 12) + frames(TECH_SYMBOLS_5, 12, 2, 12) + frames(TECH_SYMBOLS_6, 12, 3, 12) \
        + frames(TECH_SYMBOLS_7, 12, 2, 12) + frames(TECH_SYMBOLS_8, 12, 3, 12) + frames(TECH_SYMBOLS_9, 12, 1, 12) \
        + frames(TECH_SYMBOLS_10, 12, 3, 12) + [art(TECH_GARDEN, 12, 12)] + frames(TECH_SOIL, 12, 3, 12) \
        + [art(TECH_MANURE, 12, 12), art(TECH_COMPANY, 12, 12), art(TECH_BARRACKS, 12, 12),
           art(TECH_HERBALISM, 12, 12), art(TECH_MEDICINE, 12, 12)]
    images["techs"] = pixels(side_by_side([badge(f) for f in techs]))
    laws = [f for block in (LAW_SYMBOLS_1, LAW_SYMBOLS_2, LAW_SYMBOLS_3) for f in frames(block, 12, 3, 12)] + frames(LAW_SYMBOLS_4, 12, 3, 12) + frames(LAW_SYMBOLS_5, 12, 3, 12) + frames(LAW_SYMBOLS_6, 12, 4, 12) \
        + frames(LAW_SYMBOLS_7, 12, 3, 12) + [art(LAW_FUNERALS, 12, 12)]
    images["laws"] = pixels(side_by_side([badge(f, "I", "x", "U") for f in laws]))
    branches = [f for block in (BRANCH_SYMBOLS_1, BRANCH_SYMBOLS_2) for f in frames(block, 12, 3, 12)]
    images["branches"] = pixels(side_by_side([badge(f) for f in branches]))
    images["bar_fill"] = pixels(double(art(BAR_FILL, 6, 6)))
    images["bar_back"] = pixels(double(art(BAR_BACK, 6, 6)))
    images["icon_arrow"] = pixels(art(ARROW, 4, 7))
    images["icon_stress"] = pixels(art(STRESS_ICON, 8, 8))
    images["icon_male"], images["icon_female"] = (pixels(f) for f in frames(SEX_ICONS, 8, 2, 8))
    images["skills"] = pixels(side_by_side(frames(SKILLS, 8, 14, 8)))
    images["equipment"] = pixels(side_by_side(frames(EQUIPMENT, count=4)))
    for name, rows in images.items():
        write_png(out / f"{name}.png", rows)
        print("scritto", out / f"{name}.png")


if __name__ == "__main__":
    main()
