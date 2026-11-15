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
}

NIGHT_TINT = (0.40, 0.44, 0.62)  # di notte ogni colore si scurisce e vira al blu...
NIGHT_LIGHTS = {                 # ...tranne le luci
    "E": "f2b84a", "Q": "ffe6a0", "Y": "fff0b0",                 # finestre accese, lanterna
    "1": "c8904a", "2": "a06a36", "3": "7a4e28",                 # assi illuminate
}

# file -> caratteri che finiscono in quel livello
LAYERS = {
    "colonist_base": "oesSpPblgwWurR",  # w W, u r R: attrezzo (manico, testa)
    "colonist_hair": "hH",
    "colonist_tunic": "tT",
    "colonist_cape": "kK",
}

# Ogni blocco: 16 righe, fotogrammi affiancati -> fermo, passo A, passo B, carica, colpo.
# Carica e colpo: azione generica per ogni lavoro (taglio, scavo, costruzione); nel colpo il busto si abbassa di 1px.
DOWN = """
................ ................ ................ ............oooo ................
.....oooooo..... .....oooooo..... .....oooooo..... .....oooooo.ouro ................
....ohhhhhho.... ....ohhhhhho.... ....ohhhhhho.... ....ohhhhhhoorRo .....oooooo.....
...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhhoowo ....ohhhhhho....
...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHoowo ...ohhhhhhhho...
...oHhhhsssHo... ...oHhhhsssHo... ...oHhhhsssHo... ...oHhhhsssHoowo ...ohhhhhhhHo...
...oHsessesHo... ...oHsessesHo... ...oHsessesHo... ...oHsessesHoowo ...oHhhhsssHo...
....oSssssSo.... ....oSssssSo.... ....oSssssSo.... ....oSssssSo.oso ...oHsessesHo...
..okkkkggkkkko.. ..okkkkggkkkko.. ..okkkkggkkkko.. ..okkkkggkkkkoso ....oSssssSo....
..oKtTttttTtKo.. ..oKtTttttTtKo.. ..oKtTttttTtKo.. ..oKtTttttTtKoo. ..okkkkggkkkko..
..oKtTttttTtKo.. ..oKtTttttTtKo.. ..oKtTttttTtKo.. ..oKtTttttTtKo.. ..oKtTtsstTtKo..
..oKsllggllsKo.. ..oKsllggllsKo.. ..oKsllggllsKo.. ..oKtllgglltKo.. ..oKtlowWoltKo..
..oKottttttoKo.. ..oKottttttoKo.. ..oKottttttoKo.. ..oKottttttoKo.. ..oKotowWotoKo..
...oopPooPpoo... ...oopPoobboo... ...oobbooPpoo... ...oopPooPpoo... ...ooourrRooo...
....obboobbo.... ....obbooooo.... ....ooooobbo.... ....obboobbo.... ....oorRRRoo....
....ooo..ooo.... ....ooo......... .........ooo.... ....ooo..ooo.... .....oooooo.....
"""

UP = """
................ ................ ................ ............oooo ................
.....oooooo..... .....oooooo..... .....oooooo..... .....oooooo.ouro ................
....ohhhhhho.... ....ohhhhhho.... ....ohhhhhho.... ....ohhhhhhoorRo .....oooooo.....
...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhhoowo ....ohhhhhho....
...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhhoowo ...ohhhhhhhho...
...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHoowo ...ohhhhhhhho...
...oHhhhhhhHo... ...oHhhhhhhHo... ...oHhhhhhhHo... ...oHhhhhhhHoowo ...ohhhhhhhHo...
....oHHHHHHo.... ....oHHHHHHo.... ....oHHHHHHo.... ....oHHHHHHo.oso ...oHhhhhhhHo...
..okkkkkkkkkko.. ..okkkkkkkkkko.. ..okkkkkkkkkko.. ..okkkkkkkkkkoso ....oHHHHHHo....
..oKkkkkkkkkKo.. ..oKkkkkkkkkKo.. ..oKkkkkkkkkKo.. ..oKkkkkkkkkKoo. oookkkkkkkkkko..
..oKkkKkkKkkKo.. ..oKkkKkkKkkKo.. ..oKkkKkkKkkKo.. ..oKkkKkkKkkKo.. ouoKkkkkkkkkKo..
..oKkkKkkKkkKo.. ..oKkkKkkKkkKo.. ..oKkkKkkKkkKo.. ..oKkkKkkKkkKo.. orwskkKkkKkkKo..
..oKKkKkkKkKKo.. ..oKKkKkkKkKKo.. ..oKKkKkkKkKKo.. ..oKKkKkkKkKKo.. oRoKKkKkkKkKKo..
...oopPooPpoo... ...oopPoobboo... ...oobbooPpoo... ...oopPooPpoo... ooooopPooPpoo...
....obboobbo.... ....obbooooo.... ....ooooobbo.... ....obboobbo.... ....obboobbo....
....ooo..ooo.... ....ooo......... .........ooo.... ....ooo..ooo.... ....ooo..ooo....
"""

LEFT = """
................ ................ ................ ...........ooooo ................
.....oooooo..... .....oooooo..... .....oooooo..... .....ooooooourro ................
....ohhhhhho.... ....ohhhhhho.... ....ohhhhhho.... ....ohhhhhhorRRo .....oooooo.....
...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhhowoo ....ohhhhhho....
...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHowo. ...ohhhhhhhho...
...ohssshhhHo... ...ohssshhhHo... ...ohssshhhHo... ...ohssshhhHowo. ...ohhhhhhhHo...
...osessShhHo... ...osessShhHo... ...osessShhHo... ...osessShhHowo. ...ohssshhhHo...
....ossSsHHo.... ....ossSsHHo.... ....ossSsHHo.... ....ossSsHHooso. ...osessShhHo...
....ogkkkkkko... ....ogkkkkkko... ....ogkkkkkko... ....ogkkkkkkoso. ooo.ossSsHHo....
....otTttTkko... ....ottTttkko... ....otttTtkko... ....otTttTkkoo.. ouooogkkkkkko...
....otTttTkKo... ....ottTttkKo... ....otttTtkKo... ....otTttTkKo... orwwssTttTkKo...
....oglsslkKo... ....ogllsskKo... ....osslllkKo... ....ogllllkKo... oRooogllllkKo...
....ottootkKKo.. ....otttookKKo.. ....oootttkKKo.. ....ottootkKKo.. ooo.ottootkKKo..
.....oppPoooo... ...oppoPPoooo... ...oPPoppoooo... .....oppPoooo... .....oppPoooo...
....obbbbo...... ..obbbobbo...... ..obbbobbo...... ....obbbbo...... ....obbbbo......
....oooooo...... ..oooooooo...... ..oooooooo...... ....oooooo...... ....oooooo......
"""


TREES_HEIGHT = 32  # il tronco sta nella sua casella, la chioma sale in quella sopra

# Varianti affiancate -> quercia, pino, betulla.
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
....owwwWWWo.... .....owwWWo..... .....oxxXXo.....
..zzoooooooozz.. ..zzzoooooozzz.. ...zzoooooozz...
..zzzzzzzzzzzz.. ...zzzzzzzzzz... ...zzzzzzzzzz...
................ ................ ................
................ ................ ................
"""


# Icone 16x16 per la barra risorse dell'HUD -> legno, pietra. Base allineata sulla riga 14.
ICONS = """
................ ................
......oooo...... ................
.....owwwWo..... ................
....owccccWo.... ......ooooo.....
....owcCCcWo.... .....ouurrRoo...
....owcCCcWo.... ....ouurrrRRRo..
....owccccWo.... ...ourrrrRRRRo..
..ooooWWWWoooo.. ...ourrrRRRRio..
.owwwWoooowwwWo. ...orrrRRRRiio..
owccccWoowccccWo ..ooooRRRRiiio..
owcCCcWoowcCCcWo .ouurRoRiiiooo..
owcCCcWoowcCCcWo ourrrRRoooourRo.
owccccWoowccccWo orrrRRio.ourrRio
.oWWWWo..oWWWWo. oRRRRiio.orRRiio
..oooo....oooo.. .oooooo...ooooo.
................ ................
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

# Costruzioni 16x16 -> legno, pietra (colonne = Res in main.gd).
WALLS = """
oooooooooooooooo oooooooooooooooo
occcccccccccccco ouuuuuuruuuuuuuo
occcccccccccccco ouuuuuuruuuuuuuo
oCCCCCCCCCCCCCCo orrrrrrrrrrrrrro
occcccccccccccco oooooooooooooooo
oooooooooooooooo ouuuuuuRuuuuuuuo
oBwwWBwwWBwwWBwo orrrrrrRrrrrrrro
oBwwWBwwWBwwWBwo orrrrrrRrrrrrrro
oBwwWBlwWBwwWBlo oRRRRRRRRRRRRRRo
oBwwWBwwWBwwWBwo ouuuRuuuuuuRuuuo
oBwwWBwwWBwwWBwo orrrRrrrrrrRrrro
oBwwWBwwWBwwWBwo orrrRrrrrrrRrrro
oBlwWBwwWBwlWBwo oRRRRRRRRRRRRRRo
oBwwWBwwWBwwWBwo ouuuuuuRuuuuuuuo
oWWWWWWWWWWWWWWo oiiiiiiRiiiiiiio
oooooooooooooooo oooooooooooooooo
"""

# Pavimenti: si ripetono senza giunte visibili tra caselle vicine.
FLOORS = """
BBBBBBBBBBBWBBBB urrrrrrRurrrrrrR
BBBwBBBBBBBWBBBB rrrrrrrRrrrrrrrR
BBBBBBBBBBBWBBwB rrrrrrrRrrrrRrrR
WWWWWWWWWWWWWWWW rrRrrrrRrrrrrrrR
BBBBWBBBBBBBBBBB rrrrrrrRrrrrrrrR
BBBBWBBBBBwBBBBB rrrrrrrRrrrrrrrR
BwBBWBBBBBBBBBBB rrrrrrrRrrrrrrrR
WWWWWWWWWWWWWWWW RRRRRRRRRRRRRRRR
BBBBBBBBWBBBBBBB rrrRurrrrrrRurrr
BBBBBBBBWBBBBwBB rrrRrrrrrrrRrrrr
BBBwBBBBWBBBBBBB rrrRrrrrrRrRrrrr
WWWWWWWWWWWWWWWW rrrRrrrrrrrRrrrr
BBBBBBBBBBBBBBWB rRrRrrrrrrrRrrrr
BBBBBwBBBBBBBBWB rrrRrrrrrrrRrrrr
BBBBBBBBBBBBBBWB rrrRrrrrrrrRrrrr
WWWWWWWWWWWWWWWW RRRRRRRRRRRRRRRR
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


def frames(block, height=16, count=3):
    """Blocco di testo -> lista di fotogrammi, ognuno `height` righe da 16 caratteri."""
    rows = [line.split() for line in block.strip().splitlines()]
    assert len(rows) == height, f"servono {height} righe, ce ne sono {len(rows)}"
    for i, r in enumerate(rows):
        assert len(r) == count and all(len(f) == 16 for f in r), f"riga {i}: {r}"
    return [[r[i] for r in rows] for i in range(count)]


def art(block, width, height):
    rows = block.strip().splitlines()
    assert len(rows) == height, f"servono {height} righe, ce ne sono {len(rows)}"
    for i, r in enumerate(rows):
        assert len(r) == width, f"riga {i}: {len(r)} caratteri invece di {width}"
    return rows


def side_by_side(fs):
    return ["".join(f[y] for f in fs) for y in range(len(fs[0]))]


def sheet():
    """Coloni, foglio 80x64. Righe: giù, sinistra, destra (specchio), su. Colonne: fermo, passo A, passo B, carica, colpo."""
    left = frames(LEFT, count=5)
    right = [[line[::-1] for line in f] for f in left]
    return [row for fs in (frames(DOWN, count=5), left, right, frames(UP, count=5)) for row in side_by_side(fs)]


def rotate(grid):
    """90° in senso orario."""
    return ["".join(row[i] for row in reversed(grid)) for i in range(len(grid[0]))]


def turns(grid):
    """Un pezzo e le sue rotazioni di 90° in senso orario."""
    out = [grid]
    for _ in range(3):
        out.append(rotate(out[-1]))
    return out


def ground_sheet():
    """Terreno, foglio 64x176. Righe: erba, erba sassosa, ghiaia, acqua bassa, acqua alta (4 varianti);
    poi i lati (vicino su, destra, giù, sinistra) e gli angoli (vicino in alto a sx, alto a dx, basso a dx,
    basso a sx) di: erba sulla ghiaia, riva, acqua bassa su quella alta."""
    rows = [frames(b, count=4) for b in (GRASS, STONY_GRASS, GRAVEL, SHALLOW, DEEP)]
    edges = [frames(b, count=2) for b in (GRASS_EDGE, SHORE, SHALLOW_EDGE)]  # [lato, angolo]
    rows += [turns(side) for side, _ in edges] + [turns(corner) for _, corner in edges]
    return [line for fs in rows for line in side_by_side(fs)]


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
    images["trees"] = pixels(trees_sheet())
    images["icon_wood"], images["icon_stone"] = (pixels(f) for f in frames(ICONS, count=2))
    images["icon_build"] = pixels(art(BUILD_ICON, 15, 15))
    images["icon_cancel"] = pixels(art(CANCEL_ICON, 16, 16))
    # foglio 32x32: righe muri, pavimenti (= Build in main.gd); colonne legno, pietra
    images["structures"] = pixels([line for b in (WALLS, FLOORS) for line in side_by_side(frames(b, count=2))])
    images["rock_1x1"] = pixels(art(ROCK_1X1, 16, 16))
    images["rock_2x1"] = pixels(art(ROCK_2X1, 32, 16))
    images["rock_2x2"] = pixels(art(ROCK_2X2, 32, 32))
    images["ground"] = pixels(ground_sheet())
    images["warehouse_day"] = pixels(art(WAREHOUSE, 64, 32))
    images["warehouse_night"] = pixels(art(WAREHOUSE, 64, 32), palette=night_palette())
    for name, rows in images.items():
        write_png(out / f"{name}.png", rows)
        print("scritto", out / f"{name}.png")


if __name__ == "__main__":
    main()
