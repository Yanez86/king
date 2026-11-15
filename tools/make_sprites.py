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
}

# file -> caratteri che finiscono in quel livello
LAYERS = {
    "colonist_base": "oesSpPblg",
    "colonist_hair": "hH",
    "colonist_tunic": "tT",
    "colonist_cape": "kK",
}

# Ogni blocco: 16 righe, fotogrammi affiancati -> fermo, passo A, passo B.
DOWN = """
................ ................ ................
.....oooooo..... .....oooooo..... .....oooooo.....
....ohhhhhho.... ....ohhhhhho.... ....ohhhhhho....
...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho...
...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHo...
...oHhhhsssHo... ...oHhhhsssHo... ...oHhhhsssHo...
...oHsessesHo... ...oHsessesHo... ...oHsessesHo...
....oSssssSo.... ....oSssssSo.... ....oSssssSo....
..okkkkggkkkko.. ..okkkkggkkkko.. ..okkkkggkkkko..
..oKtTttttTtKo.. ..oKtTttttTtKo.. ..oKtTttttTtKo..
..oKtTttttTtKo.. ..oKtTttttTtKo.. ..oKtTttttTtKo..
..oKsllggllsKo.. ..oKsllggllsKo.. ..oKsllggllsKo..
..oKottttttoKo.. ..oKottttttoKo.. ..oKottttttoKo..
...oopPooPpoo... ...oopPoobboo... ...oobbooPpoo...
....obboobbo.... ....obbooooo.... ....ooooobbo....
....ooo..ooo.... ....ooo......... .........ooo....
"""

UP = """
................ ................ ................
.....oooooo..... .....oooooo..... .....oooooo.....
....ohhhhhho.... ....ohhhhhho.... ....ohhhhhho....
...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho...
...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho...
...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHo...
...oHhhhhhhHo... ...oHhhhhhhHo... ...oHhhhhhhHo...
....oHHHHHHo.... ....oHHHHHHo.... ....oHHHHHHo....
..okkkkkkkkkko.. ..okkkkkkkkkko.. ..okkkkkkkkkko..
..oKkkkkkkkkKo.. ..oKkkkkkkkkKo.. ..oKkkkkkkkkKo..
..oKkkKkkKkkKo.. ..oKkkKkkKkkKo.. ..oKkkKkkKkkKo..
..oKkkKkkKkkKo.. ..oKkkKkkKkkKo.. ..oKkkKkkKkkKo..
..oKKkKkkKkKKo.. ..oKKkKkkKkKKo.. ..oKKkKkkKkKKo..
...oopPooPpoo... ...oopPoobboo... ...oobbooPpoo...
....obboobbo.... ....obbooooo.... ....ooooobbo....
....ooo..ooo.... ....ooo......... .........ooo....
"""

LEFT = """
................ ................ ................
.....oooooo..... .....oooooo..... .....oooooo.....
....ohhhhhho.... ....ohhhhhho.... ....ohhhhhho....
...ohhhhhhhho... ...ohhhhhhhho... ...ohhhhhhhho...
...ohhhhhhhHo... ...ohhhhhhhHo... ...ohhhhhhhHo...
...ohssshhhHo... ...ohssshhhHo... ...ohssshhhHo...
...osessShhHo... ...osessShhHo... ...osessShhHo...
....ossSsHHo.... ....ossSsHHo.... ....ossSsHHo....
....ogkkkkkko... ....ogkkkkkko... ....ogkkkkkko...
....otTttTkko... ....ottTttkko... ....otttTtkko...
....otTttTkKo... ....ottTttkKo... ....otttTtkKo...
....oglsslkKo... ....ogllsskKo... ....osslllkKo...
....ottootkKKo.. ....otttookKKo.. ....oootttkKKo..
.....oppPoooo... ...oppoPPoooo... ...oPPoppoooo...
....obbbbo...... ..obbbobbo...... ..obbbobbo......
....oooooo...... ..oooooooo...... ..oooooooo......
"""


def frames(block):
    """Blocco di testo -> lista di fotogrammi, ognuno 16 righe da 16 caratteri."""
    rows = [line.split() for line in block.strip().splitlines()]
    assert len(rows) == 16, f"servono 16 righe, ce ne sono {len(rows)}"
    for i, r in enumerate(rows):
        assert len(r) == 3 and all(len(f) == 16 for f in r), f"riga {i}: {r}"
    return [[r[i] for r in rows] for i in range(3)]


def sheet():
    """Foglio 48x64. Righe: giù, sinistra, destra (specchio), su. Colonne: fermo, passo A, passo B."""
    left = frames(LEFT)
    right = [[line[::-1] for line in f] for f in left]
    return ["".join(f[y] for f in fs) for fs in (frames(DOWN), left, right, frames(UP)) for y in range(16)]


def write_png(path, rows):
    """rows: righe di pixel (r, g, b, a)."""
    raw = b"".join(b"\0" + bytes(v for px in row for v in px) for row in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    header = struct.pack(">IIBBBBB", len(rows[0]), len(rows), 8, 6, 0, 0, 0)  # 8 bit RGBA
    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
                           + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def rgba(ch):
    return tuple(bytes.fromhex(PALETTE[ch])) + (255,)


def main():
    grid = sheet()
    all_chars = set("".join(LAYERS.values()))
    unknown = set("".join(grid)) - {"."} - all_chars
    assert not unknown, f"caratteri senza livello: {unknown}"
    out = Path(__file__).resolve().parent.parent / "art"
    out.mkdir(exist_ok=True)
    for name, chars in LAYERS.items():
        write_png(out / f"{name}.png",
                  [[rgba(ch) if ch in chars else (0, 0, 0, 0) for ch in line] for line in grid])
        print("scritto", out / f"{name}.png")


if __name__ == "__main__":
    main()
