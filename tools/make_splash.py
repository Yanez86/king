#!/usr/bin/env python3
"""Splash screen e schermata del titolo di "Colonia: Long Live the King".
Le scene usano gli sprite di make_sprites.py; il logo è disegnato qui, sempre a griglie di caratteri.
Esegui dalla cartella del progetto: python3 tools/make_splash.py [--scale N]
- art/title_scene.png: la scena di notte del titolo, TITLE_FRAMES fotogrammi 320x180 uno sotto l'altro (vedi title.gd)
- art/title_logo.png: il logo, 320x180 trasparente, da mettere sopra la scena
- art/splash/: le quattro prove di splash (--scale 1 = 320x180, la risoluzione del gioco ÷4; di default 4 = 1280x720)
"""
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_sprites as ms  # noqa: E402

W, H = 320, 180
TILE = 16


def hexrgb(h):
    return tuple(bytes.fromhex(h[:6]))


# ---------------------------------------------------------------- logo

# Lettere del titolo su una griglia "grossa": ogni # diventa 2x2 pixel; luci, ombre e contorni si fanno dopo, a 1 pixel.
LETTERS = {
    "C": """
..######.
.##....##
##......#
##.......
##.......
##.......
##.......
##.......
##......#
.##....##
..######.
""",
    "O": """
..#####..
.##...##.
##.....##
##.....##
##.....##
##.....##
##.....##
##.....##
##.....##
.##...##.
..#####..
""",
    "L": """
####....
.##.....
.##.....
.##.....
.##.....
.##.....
.##.....
.##.....
.##....#
.##...##
########
""",
    "N": """
###.....###
.##......#.
.###.....#.
.#.##....#.
.#..##...#.
.#...##..#.
.#....##.#.
.#.....###.
.#......##.
.#.......#.
###......#.
""",
    "I": """
####
.##.
.##.
.##.
.##.
.##.
.##.
.##.
.##.
.##.
####
""",
    "A": """
.....##.....
.....##.....
....#.##....
....#.##....
...#...##...
...#...##...
..########..
..#.....##..
.#.......##.
.#.......##.
###.....####
""",
}

# Caratteri piccoli per il motto, 5 righe.
SMALL = {
    "L": ["#...", "#...", "#...", "#...", "####"],
    "O": [".##.", "#..#", "#..#", "#..#", ".##."],
    "N": ["#..#", "##.#", "#.##", "#..#", "#..#"],
    "G": [".###", "#...", "#.##", "#..#", ".###"],
    "I": ["###", ".#.", ".#.", ".#.", "###"],
    "V": ["#...#", "#...#", ".#.#.", ".#.#.", "..#.."],
    "E": ["####", "#...", "###.", "#...", "####"],
    "T": ["#####", "..#..", "..#..", "..#..", "..#.."],
    "H": ["#..#", "#..#", "####", "#..#", "#..#"],
    "K": ["#..#", "#.#.", "##..", "#.#.", "#..#"],
    "A": [".##.", "#..#", "####", "#..#", "#..#"],
    "R": ["###.", "#..#", "###.", "#.#.", "#..#"],
    "U": ["#..#", "#..#", "#..#", "#..#", ".##."],
    " ": ["..", "..", "..", "..", ".."],
}

# Corona, sulla stessa griglia grossa delle lettere: tre punte con le perle, la fascia sotto.
CROWN = """
.#........#........#.
###......###......###
.#........#........#.
.##......###......##.
.###....#####....###.
.####..#######..####.
.#####.#######.#####.
.###################.
.###################.
.###################.
.###################.
"""
CROWN_GEMS = [(6, "j"), (20, "/"), (34, "j")]  # x del centro di ogni gemma sulla fascia, colore

INK = "1f1a24"


class Canvas:
    def __init__(self, w=W, h=H, fill=(0, 0, 0)):
        self.w, self.h = w, h
        fill = tuple(fill) + (255,) * (4 - len(fill))
        self.px = [[list(fill) for _ in range(w)] for _ in range(h)]
        self.glow = [[False] * w for _ in range(h)]  # pixel che di notte restano accesi

    def put(self, x, y, rgba, glow=False):
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        r, g, b, *a = rgba
        a = a[0] / 255 if a else 1.0
        if a <= 0:
            return
        p = self.px[y][x]
        pa = p[3] / 255
        out = a + pa * (1 - a)
        for i, c in enumerate((r, g, b)):
            p[i] = round((c * a + p[i] * pa * (1 - a)) / out)
        p[3] = round(out * 255)
        if a >= 1:
            self.glow[y][x] = glow

    def grid(self, grid, x, y, palette=ms.PALETTE, tint=None, glow_chars="", flip=False):
        """Disegna una griglia di caratteri; tint = {carattere: colore} moltiplica i bianchi (come modulate)."""
        for dy, line in enumerate(grid):
            if flip:
                line = line[::-1]
            for dx, ch in enumerate(line):
                if ch == ".":
                    continue
                c = ms.rgba(ch, palette)
                if tint and ch in tint:
                    t = hexrgb(tint[ch])
                    c = tuple(round(v * k / 255) for v, k in zip(c[:3], t)) + c[3:]
                self.put(x + dx, y + dy, c, ch in glow_chars)

    def rows(self, scale=1):
        out = []
        for line in self.px:
            out += [[tuple(p) for p in line for _ in range(scale)]] * scale
        return out

    def save(self, path, scale=1):
        ms.write_png(path, self.rows(scale))


def big_mask(blocks):
    """Griglie grosse affiancate (1 colonna vuota tra l'una e l'altra) -> insieme di pixel (x, y) e larghezza;
    ogni # diventa 2x2 pixel."""
    cells, x = set(), 0
    for block in blocks:
        rows = block.strip().splitlines()
        for y, line in enumerate(rows):
            for dx, c in enumerate(line):
                if c == "#":
                    cells |= {((x + dx) * 2 + sx, y * 2 + sy) for sx in (0, 1) for sy in (0, 1)}
        x += len(rows[0]) + 1
    return cells, (x - 1) * 2


def small_mask(text):
    cells, x = set(), 0
    for ch in text:
        g = SMALL[ch]
        for y, line in enumerate(g):
            for dx, c in enumerate(line):
                if c == "#":
                    cells.add((x + dx, y))
        x += len(g[0]) + 1
    return cells, x - 1, 5


def around(cells, diag=True):
    dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)] + ([(1, 1), (-1, 1), (1, -1), (-1, -1)] if diag else [])
    return {(x + dx, y + dy) for x, y in cells for dx, dy in dirs} - cells


def draw_gold(cv, mask, w, cx, top, glow=False):
    """Oro in rilievo: fascia di luce in alto, spessore scuro sotto, contorno e ombra portata."""
    ox = cx - w // 2
    depth = {}
    for d in (1, 2, 3):
        for (x, y) in mask:
            if (x, y + d) not in mask and (x, y + d) not in depth:
                depth[(x, y + d)] = d
    body = mask | set(depth)
    outline = around(body)
    shadow = {(x + 1, y + 2) for x, y in body | outline} - body - outline
    for x, y in shadow:
        cv.put(ox + x, top + y, (31, 26, 36, 140))
    for x, y in outline:
        cv.put(ox + x, top + y, hexrgb(INK))
    for (x, y), d in depth.items():
        cv.put(ox + x, top + y, hexrgb(["7a4e28", "5b3a24", "3b2a1e"][d - 1]))
    bands = ["fff0b0", "ffe6a0", "ffe6a0", "f2d77a", "f2d77a", "e8c34a", "e8c34a", "e8c34a", "e8c34a", "e8c34a",
             "e8c34a", "e0b440", "e0b440", "d9a83a", "d9a83a", "c99a36", "c99a36", "b88a32", "b88a32", "a87a2e",
             "a87a2e", "8f6626"]
    for x, y in mask:
        c = bands[y]
        if (x, y - 1) not in mask:
            c = "fff6d0"
        elif (x - 1, y) not in mask and y < 14:
            c = "ffe6a0"
        elif (x + 1, y) not in mask:
            c = "a87a2e"
        cv.put(ox + x, top + y, hexrgb(c), glow)
    return ox


def draw_title(cv, text, cx, top, glow=False):
    mask, w = big_mask(LETTERS[ch] for ch in text)
    ox = draw_gold(cv, mask, w, cx, top, glow)
    for gx, gy in ((ox + 5, top + 3), (ox + w - 9, top + 5)):  # luccichio sulla C e sulla A
        cv.put(gx, gy, (255, 255, 255), glow)
        cv.put(gx + 1, gy, (255, 250, 230), glow)


def draw_crown(cv, cx, top, glow=False):
    mask, w = big_mask([CROWN])
    ox = draw_gold(cv, mask, w, cx, top, glow)
    for x in range(2, w - 2):  # filo scuro tra le punte e la fascia
        cv.put(ox + x, top + 13, hexrgb("8f6626"), glow)
    for gx, ch in CROWN_GEMS:  # gemme 3x3 con il riflesso
        light, dark = {"j": ("d84a3a", "9a2a24"), "/": ("7a8ae0", "4a5a9a")}[ch]
        for dx in range(-1, 2):
            for dy in range(3):
                cv.put(ox + gx + dx, top + 16 + dy, hexrgb(dark if dx == 1 or dy == 2 else light), glow)
        cv.put(ox + gx - 1, top + 16, (255, 255, 255), glow)
        for dx, dy in ((-2, 0), (-2, 1), (-2, 2), (2, 0), (2, 1), (2, 2), (-1, -1), (0, -1), (1, -1), (-1, 3), (0, 3),
                       (1, 3)):
            cv.put(ox + gx + dx, top + 16 + dy, hexrgb(INK), glow)


def draw_ribbon(cv, text, cx, top, cloth=("d84a3a", "9a2a24", "6e1f1f"), ink="f4ecd8"):
    """Nastro con le code a coda di rondine e il motto in piccolo."""
    mask, tw, _ = small_mask(text)
    w = tw + 14
    x0 = cx - w // 2
    light, dark, darker = (hexrgb(c) for c in cloth)
    o = hexrgb(INK)
    # code dietro, più in basso
    for side in (-1, 1):
        tail_x = x0 - 12 if side < 0 else x0 + w - 2
        for dy in range(11):
            for dx in range(14):
                notch = (dx < 4 - min(abs(dy - 5), 4)) if side < 0 else (dx > 9 + min(abs(dy - 5), 4))
                if notch:
                    continue
                edge = dy in (0, 10) or (side < 0 and dx == 4 - min(abs(dy - 5), 4)) or \
                    (side > 0 and dx == 9 + min(abs(dy - 5), 4))
                cv.put(tail_x + dx, top + 4 + dy, o if edge else (darker if dy > 6 else dark))
        # piega: la coda passa dietro il nastro, un filo scuro sotto
        fx = x0 if side < 0 else x0 + w - 1
        for dy in range(4):
            cv.put(fx, top + 11 + dy, o)
    # nastro davanti
    for dy in range(12):
        for dx in range(w):
            edge = dy in (0, 11) or dx in (0, w - 1)
            c = o if edge else (light if dy < 3 else (dark if dy > 8 else hexrgb("c43f33")))
            if dy == 1 and not edge:
                c = hexrgb("e8735f")
            cv.put(x0 + dx, top + dy, c)
    # ombra e testo
    tx = cx - tw // 2
    for x, y in mask:
        cv.put(tx + x, top + 4 + y, hexrgb("5a1a18"))
    for x, y in mask:
        cv.put(tx + x, top + 3 + y, hexrgb(ink))


def draw_logo(cv, cx, top, glow=False):
    """Corona, titolo e nastro, impilati e centrati su cx. Restituisce il fondo del logo."""
    draw_crown(cv, cx, top, glow)
    y = top + 27
    draw_title(cv, "COLONIA", cx, y, glow)
    draw_ribbon(cv, "LONG LIVE THE KING", cx, y + 29)
    return y + 29 + 15


# ---------------------------------------------------------------- scene

GROUND_ROWS = {"grass": 0, "stony": 1, "gravel": 2, "shallow": 3, "deep": 4}
GROUND_SHEET = ms.ground_sheet()
STRUCT_SHEET = ms.structures_sheet()
TREES = ms.frames(ms.TREES, ms.TREES_HEIGHT)
SIDES = [(0, -1), (1, 0), (0, 1), (-1, 0)]
CORNERS = [(-1, -1), (1, -1), (1, 1), (-1, 1)]


def tile(sheet, col, row, w=16, h=16):
    return [line[col * w:(col + 1) * w] for line in sheet[row * h:(row + 1) * h]]


def edge_row(own, other):
    """Come edge_row in main.gd: il bordo che il terreno `other` disegna su `own`."""
    if other is None:
        return -1
    order = ["grass", "stony", "gravel", "shallow", "deep"]
    o, n = order.index(own), order.index(other)
    if o >= 3 and n < 3:
        return 6  # riva
    if own == "deep" and other == "shallow":
        return 7
    if own == "gravel" and other in ("grass", "stony"):
        return 5
    return -1


def draw_ground(cv, ground, floors, rng, palette=ms.PALETTE):
    cols, rows = W // TILE + 1, H // TILE + 1
    for ty in range(rows):
        for tx in range(cols):
            own = ground.get((tx, ty), "grass")
            cv.grid(tile(GROUND_SHEET, rng.randrange(4), GROUND_ROWS[own]), tx * TILE, ty * TILE, palette)
            for i in range(4):
                n = ground.get((tx + SIDES[i][0], ty + SIDES[i][1]), "grass")
                side = edge_row(own, n)
                if side >= 0:
                    cv.grid(tile(GROUND_SHEET, i, side), tx * TILE, ty * TILE, palette)
                d = CORNERS[i]
                corner = edge_row(own, ground.get((tx + d[0], ty + d[1]), "grass"))
                if corner >= 0 and edge_row(own, ground.get((tx + d[0], ty), "grass")) != corner \
                        and edge_row(own, ground.get((tx, ty + d[1]), "grass")) != corner:
                    cv.grid(tile(GROUND_SHEET, i, corner + 3), tx * TILE, ty * TILE, palette)
    # pavimenti (0 legno, 1 pietra, 2 sentiero) con l'erba che sborda, come draw_grass_over
    for (tx, ty), kind in floors.items():
        cv.grid(tile(STRUCT_SHEET, kind, 2), tx * TILE, ty * TILE, palette)
        lawn = lambda c: c not in floors and ground.get(c, "grass") == "grass"  # noqa: E731
        row = 4 + 2 * ((tx + ty) % 2)
        for i in range(4):
            if lawn((tx + SIDES[i][0], ty + SIDES[i][1])):
                cv.grid(tile(STRUCT_SHEET, i, row), tx * TILE, ty * TILE, palette)
            d = CORNERS[i]
            if lawn((tx + d[0], ty + d[1])) and not lawn((tx + d[0], ty)) and not lawn((tx, ty + d[1])):
                cv.grid(tile(STRUCT_SHEET, i, row + 1), tx * TILE, ty * TILE, palette)


COLONIST = ms.sheet()
COLONIST_LOOKS = [  # tunica, mantello, capelli (da TUNIC_COLORS, CAPE_COLORS, HAIR_COLORS in main.gd)
    ("a33b3b", "2f4a6e", "3b2a1e"), ("3b5ea3", "6e2f2f", "d9b35b"), ("c9a23b", "5a3b6e", "a8462f"),
    ("6e3ba3", "4a4a4a", "8b5a2b"), ("d8d0c0", "7a5a2f", "2a2a2a"), ("a33b3b", "5a3b6e", "d9b35b"),
]


def draw_colonist(cv, x, y, look, facing=0, frame=0, palette=ms.PALETTE):
    """facing: 0 giù, 1 sinistra, 2 destra, 3 su; frame: 0 fermo, 1-2 passo, 3 carica, 4 colpo, 5 respiro."""
    g = [line[frame * 16:(frame + 1) * 16] for line in COLONIST[facing * 16:(facing + 1) * 16]]
    tunic, cape, hair = look
    tint = {"t": tunic, "T": tunic, "k": cape, "K": cape, "h": hair, "H": hair}
    shadow = ["................"] * 15 + ["....zzzzzzzz...."]
    cv.grid(shadow, x, y + 1, palette)
    cv.grid(g, x, y, palette, tint=tint)


def furniture(name, frame=0):
    block = getattr(ms, name)
    sizes = {"STATUE": (32, 32), "FOUNTAIN": (32, 32), "BENCH": (32, 16), "WAREHOUSE": (64, 32)}
    w, h = sizes.get(name, (16, 16))
    if name in ("CAMPFIRE", "BANNER", "FOUNTAIN"):
        return ms.frames(block, height=h, count=4, width=w)[frame]
    return ms.art(block, w, h)


def tree(kind):
    return TREES[kind]


def night(cv, lights, tint=(0.30, 0.34, 0.56), warm=(1.0, 0.78, 0.5), steps=4, wash=None):
    """Notte: tutto si scurisce e vira al blu, tranne i pixel accesi; attorno alle luci cerchi caldi a gradini,
    con una sfumatura a pixel alterni sul bordo di ogni gradino. wash = (colore, quanto) velo sopra a tutto."""
    for y in range(cv.h):
        for x in range(cv.w):
            p = cv.px[y][x]
            if cv.glow[y][x]:
                continue
            light = 0.0
            for lx, ly, radius, power in lights:
                d = ((x - lx) ** 2 + ((y - ly) * 1.15) ** 2) ** 0.5
                if d < radius:
                    light = max(light, power * (1 - d / radius))
            level = light * steps
            q = int(level)
            if (level - q) > 0.75 and (x + y) % 2 == 0:  # dithering
                q += 1
            k = min(q / steps, 1.0)
            for i in range(3):
                f = tint[i] + (warm[i] * 1.15 - tint[i]) * k
                p[i] = min(255, round(p[i] * f))
                if wash:
                    p[i] = round(p[i] * (1 - wash[1]) + hexrgb(wash[0])[i] * wash[1])


def vignette(cv, strength=0.55, top_band=None, left_band=None):
    """Bordi più scuri, a gradini; top_band = (altezza, forza) scurisce in più la parte alta dove va il logo,
    left_band = (larghezza, forza) la parte a sinistra dove va il menu del titolo."""
    cx, cy = cv.w / 2, cv.h / 2
    for y in range(cv.h):
        for x in range(cv.w):
            dx, dy = (x - cx) / cx, (y - cy) / cy
            d = (dx * dx * 0.8 + dy * dy) ** 0.5
            k = max(0.0, d - 0.55) / 0.6
            k = round(min(k, 1.0) * 5) / 5 * strength
            if top_band and y < top_band[0]:
                k = max(k, round((1 - y / top_band[0]) * 4) / 4 * top_band[1])
            if left_band and x < left_band[0]:
                k = max(k, round((1 - x / left_band[0]) * 4) / 4 * left_band[1])
            p = cv.px[y][x]
            for i, base in enumerate(hexrgb(INK)):
                p[i] = round(p[i] * (1 - k) + base * k)


# ---------------------------------------------------------------- splash

def splash_day():
    """Giorno: la piazza col monumento al re, il magazzino, i coloni al lavoro."""
    rng = random.Random(7)
    cv = Canvas()
    ground = {}
    for c in [(16, 0), (17, 0), (18, 0), (19, 0), (17, 1), (18, 1), (19, 1), (20, 0), (20, 1), (18, 2), (19, 2),
              (20, 2)]:
        ground[c] = "shallow"
    for c in [(18, 0), (19, 0), (20, 0), (19, 1), (20, 1)]:
        ground[c] = "deep"
    for c in [(0, 9), (1, 9), (0, 10), (1, 10), (2, 10), (0, 11), (1, 11), (2, 11), (3, 11)]:
        ground[c] = "stony"
    floors = {(x, y): 1 for x in range(7, 13) for y in range(6, 11)}
    floors.update({(9, 11): 2, (10, 11): 2, (13, 8): 2, (14, 8): 2, (15, 8): 2, (16, 9): 2, (16, 8): 2, (6, 8): 2,
                   (5, 8): 2})
    draw_ground(cv, ground, floors, rng)
    # alberi sul fondo e ai lati: prima quelli più in alto, così chi sta sotto copre
    things = []
    for tx, ty, k in [(0, 1, 1), (1, 0, 0), (2, 2, 1), (3, 0, 2), (5, 1, 0), (13, 1, 1), (14, 0, 0), (15, 2, 2),
                      (0, 4, 0), (1, 6, 1), (18, 5, 0), (19, 7, 1), (17, 9, 2), (19, 10, 0), (0, 12, 1), (4, 11, 2),
                      (14, 11, 0), (16, 12, 1), (6, 0, 1), (11, 0, 2), (8, 1, 0), (10, 0, 1)]:
        things.append((ty * TILE + 15, lambda tx=tx, ty=ty, k=k: cv.grid(tree(k), tx * TILE, (ty - 1) * TILE)))
    things.append((9 * TILE + 15, lambda: cv.grid(furniture("WAREHOUSE"), 1 * TILE, 8 * TILE)))
    things.append((8 * TILE + 31, lambda: cv.grid(furniture("STATUE"), 9 * TILE, 7 * TILE)))
    for x in (8, 11):
        things.append((7 * TILE + 15, lambda x=x: cv.grid(furniture("BANNER", 1), x * TILE, 7 * TILE)))
    for x, y in ((7, 6), (12, 6), (7, 10), (12, 10)):
        things.append((y * TILE + 15, lambda x=x, y=y: cv.grid(furniture("LANTERN"), x * TILE, y * TILE)))
    for x in (8, 11):
        things.append((10 * TILE + 15, lambda x=x: cv.grid(furniture("FLOWER_BED"), x * TILE, 10 * TILE)))
    things.append((6 * TILE + 15, lambda: cv.grid(furniture("BENCH"), 9 * TILE, 6 * TILE - 4)))
    things.append((9 * TILE + 15, lambda: cv.grid(furniture("CAMPFIRE"), 15 * TILE, 9 * TILE)))
    for x, y, look, face, frame in [(13 * TILE + 4, 7 * TILE + 6, 0, 1, 1), (6 * TILE + 2, 9 * TILE + 2, 1, 2, 2),
                                    (14 * TILE + 8, 9 * TILE + 4, 2, 2, 0), (16 * TILE + 6, 10 * TILE, 3, 1, 5),
                                    (11 * TILE + 2, 9 * TILE + 8, 1, 3, 0), (4 * TILE + 4, 6 * TILE + 8, 5, 0, 3)]:
        things.append((y + 15, lambda x=x, y=y, look=look, face=face, frame=frame:
                       draw_colonist(cv, x, y, COLONIST_LOOKS[look], face, frame)))
    for _, draw in sorted(things, key=lambda t: t[0]):
        draw()
    vignette(cv, 0.6, top_band=(80, 0.55))
    draw_logo(cv, W // 2, 8)
    return cv


NIGHT_LAYOUTS = {
    # splash: il fuoco al centro sotto il logo
    "splash": dict(
        stony=[(3, 10), (4, 10), (4, 11), (5, 11), (14, 3), (15, 3)],
        paths=[(x, 10) for x in range(6, 21)] + [(9, 9), (9, 8)],
        trees=[(0, 1, 1), (1, 0, 0), (2, 2, 2), (3, 0, 1), (16, 0, 1), (17, 1, 0), (18, 0, 2), (19, 2, 1), (0, 5, 0),
               (1, 7, 1), (0, 9, 2), (19, 6, 0), (18, 8, 1), (19, 10, 2), (2, 12, 0), (6, 12, 1), (12, 12, 2),
               (15, 12, 0), (17, 12, 1), (5, 1, 2), (14, 1, 0), (7, 0, 1), (12, 0, 0)],
        warehouse=(3, 7), fire=(11 * TILE + 8, 8 * TILE), lanterns=[(15, 9), (7, 9)], banner=(15, 7),
        bench=(12 * TILE, 10 * TILE - 6)),
    # titolo: il fuoco più a destra, a sinistra il prato libero per il menu
    "title": dict(
        stony=[(14, 3), (15, 3), (18, 11), (19, 11)],
        paths=[(x, 10) for x in range(7, 21)] + [(7, 11), (10, 9), (10, 8)],
        trees=[(0, 1, 1), (1, 0, 0), (2, 2, 2), (3, 0, 1), (5, 1, 2), (7, 0, 1), (12, 0, 0), (14, 1, 0), (16, 0, 1),
               (17, 1, 0), (18, 0, 2), (19, 2, 1), (1, 4, 1), (4, 3, 0), (0, 6, 0), (0, 9, 2), (0, 12, 1), (19, 5, 0),
               (18, 7, 1), (19, 9, 0), (19, 12, 2), (15, 12, 0), (11, 12, 2), (17, 12, 1), (13, 3, 2), (6, 3, 1)],
        warehouse=(8, 6), fire=(13 * TILE, 8 * TILE), lanterns=[(8, 9), (17, 9)], banner=(17, 7), bench=None),
}
TITLE_FRAMES = 16  # 0.15 s l'uno, come il fuoco in gioco (ANIMATED in main.gd)
FIRE_FLICKER = [0, 2, 1, 3, 1, -1, 2, 0, 3, 1, -1, 0, 2, 3, 0, 1]  # pixel in più nel raggio della luce, per fotogramma
SPARKS = [(6, 0, 1), (9, 3, -1), (4, 6, 1), (11, 9, 0), (7, 12, -1)]  # x nel fuoco, fotogramma in cui nasce, deriva


def night_scene(layout="splash", frame=0, logo=True):
    """Notte: i coloni attorno al fuoco da campo, il magazzino con le finestre accese. Con frame si anima: fuoco,
    stendardo, respiro dei coloni, luce che tremola, scintille."""
    lay = NIGHT_LAYOUTS[layout]
    rng = random.Random(3)
    cv = Canvas()
    ground = {c: "stony" for c in lay["stony"]}
    draw_ground(cv, ground, {c: 2 for c in lay["paths"]}, rng)
    night_pal = ms.PALETTE | ms.NIGHT_LIGHTS
    things = []
    for tx, ty, k in lay["trees"]:
        things.append((ty * TILE + 15, lambda tx=tx, ty=ty, k=k: cv.grid(tree(k), tx * TILE, (ty - 1) * TILE)))
    wx, wy = lay["warehouse"]
    things.append(((wy + 1) * TILE + 15, lambda: cv.grid(furniture("WAREHOUSE"), wx * TILE, wy * TILE, night_pal,
                                                         glow_chars="EQY")))
    fire_x, fire_y = lay["fire"]
    things.append((fire_y + 15, lambda: cv.grid(furniture("CAMPFIRE", (frame + 2) % 4), fire_x, fire_y,
                                                glow_chars="89=")))
    for x, y in lay["lanterns"]:
        things.append((y * TILE + 15, lambda x=x, y=y: cv.grid(furniture("LANTERN"), x * TILE, y * TILE, night_pal,
                                                              glow_chars="EQY")))
    if lay["bench"]:
        things.append((lay["bench"][1] + 15, lambda: cv.grid(furniture("BENCH"), *lay["bench"])))
    bx, by = lay["banner"]
    things.append((by * TILE + 15, lambda: cv.grid(furniture("BANNER", (frame // 2 + 3) % 4), bx * TILE, by * TILE)))
    for i, (dx, dy, look, face) in enumerate([(-19, 1, 0, 2), (19, 1, 1, 1), (-10, -13, 2, 0), (11, -13, 3, 0),
                                              (-9, 13, 4, 3), (10, 14, 5, 3)]):
        x, y = fire_x + dx, fire_y + dy
        breath = 5 if (frame + i * 5) // 8 % 2 else 0  # respiro lento, ognuno col suo passo
        things.append((y + 15, lambda x=x, y=y, look=look, face=face, breath=breath:
                       draw_colonist(cv, x, y, COLONIST_LOOKS[look], face, breath)))
    for _, draw in sorted(things, key=lambda t: t[0]):
        draw()
    flicker = FIRE_FLICKER[frame % len(FIRE_FLICKER)]
    lights = [(fire_x + 8, fire_y + 8, 74 + flicker, 1.0 + flicker * 0.01),
              (wx * TILE + 32, wy * TILE + 20, 26, 0.55)]
    lights += [(x * TILE + 8, y * TILE + 5, 30, 0.6) for x, y in lay["lanterns"]]
    night(cv, lights)
    for sx, born, drift in SPARKS:  # scintille che salgono dal fuoco e si spengono
        age = (frame - born) % TITLE_FRAMES
        if age < 7:
            color = "ffe6a0" if age < 2 else ("f2a03a" if age < 5 else "d8562f")
            cv.put(fire_x + sx + drift * (age // 3), fire_y + 2 - age * 4, hexrgb(color), True)
    vignette(cv, 0.5, top_band=(84, 0.45), left_band=(120, 0.35) if layout == "title" else None)
    if logo:
        draw_logo(cv, W // 2, 8)
    return cv


def splash_night():
    return night_scene()


def title_logo():
    """Il logo da solo, su fondo trasparente, nella stessa posizione che ha negli splash."""
    cv = Canvas(fill=(0, 0, 0, 0))
    draw_logo(cv, W // 2, 8)
    return cv


def splash_crest():
    """Stemma: fondo scuro e solo il logo. Va bene come boot splash di Godot."""
    cv = Canvas(fill=hexrgb(INK))
    rng = random.Random(11)
    # trama leggera di stelle/polvere
    for _ in range(70):
        x, y = rng.randrange(W), rng.randrange(H)
        cv.put(x, y, (77, 72, 98, rng.choice((60, 110))))
    # cerchio di luce dietro il logo, a gradini
    for y in range(H):
        for x in range(W):
            d = (((x - W / 2) / 1.6) ** 2 + (y - 92) ** 2) ** 0.5
            for r, a in ((70, 30), (54, 30), (38, 30)):
                if d < r:
                    cv.put(x, y, (77, 72, 98, a))
    draw_logo(cv, W // 2, 54)
    return cv


def splash_dusk():
    """Tramonto: la piazza con la fontana, la luce arancione della sera (SKY in main.gd), i lampioni accesi."""
    rng = random.Random(5)
    cv = Canvas()
    floors = {(x, y): 1 for x in range(6, 14) for y in range(7, 12)}
    floors.update({(9, y): 2 for y in range(0, 7)} | {(10, y): 2 for y in range(0, 7)})
    draw_ground(cv, {}, floors, rng)
    things = []
    for tx, ty, k in [(0, 1, 0), (2, 0, 1), (4, 2, 2), (6, 1, 0), (7, 3, 1), (12, 3, 2), (13, 1, 0), (15, 2, 1),
                      (17, 0, 2), (19, 1, 0), (1, 4, 1), (18, 4, 0), (0, 7, 2), (2, 9, 0), (19, 8, 1), (17, 10, 2),
                      (3, 12, 1), (16, 12, 0), (1, 11, 0), (18, 12, 2), (4, 6, 1), (15, 6, 0)]:
        things.append((ty * TILE + 15, lambda tx=tx, ty=ty, k=k: cv.grid(tree(k), tx * TILE, (ty - 1) * TILE)))
    things.append((9 * TILE + 31, lambda: cv.grid(furniture("FOUNTAIN", 1), 9 * TILE, 8 * TILE)))
    for x, y in ((6, 7), (13, 7), (6, 11), (13, 11)):
        things.append((y * TILE + 15, lambda x=x, y=y: cv.grid(furniture("LANTERN"), x * TILE, y * TILE,
                                                              ms.PALETTE | ms.NIGHT_LIGHTS, glow_chars="EQY")))
    for x in (7, 12):
        things.append((7 * TILE + 15, lambda x=x: cv.grid(furniture("BANNER", 2), x * TILE, 7 * TILE)))
    for x, y, look, face, frame in [(7 * TILE + 4, 9 * TILE + 10, 0, 2, 0), (11 * TILE + 6, 9 * TILE + 12, 1, 1, 5),
                                    (9 * TILE + 8, 4 * TILE, 2, 0, 1), (7 * TILE + 8, 8 * TILE + 6, 3, 3, 2)]:
        things.append((y + 15, lambda x=x, y=y, look=look, face=face, frame=frame:
                       draw_colonist(cv, x, y, COLONIST_LOOKS[look], face, frame)))
    for _, draw in sorted(things, key=lambda t: t[0]):
        draw()
    lights = [(x * TILE + 8, y * TILE + 5, 34, 0.75) for x, y in ((6, 7), (13, 7), (6, 11), (13, 11))]
    night(cv, lights, tint=(0.95, 0.66, 0.5), warm=(1.05, 0.95, 0.7), steps=3, wash=("d8562f", 0.16))
    vignette(cv, 0.55, top_band=(84, 0.5))
    draw_logo(cv, W // 2, 8)
    return cv


SPLASHES = {"day": splash_day, "night": splash_night, "crest": splash_crest, "dusk": splash_dusk}


def main():
    scale = int(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 4
    art = Path(__file__).resolve().parent.parent / "art"
    out = Path(sys.argv[sys.argv.index("--out") + 1]) if "--out" in sys.argv else art / "splash"
    out.mkdir(parents=True, exist_ok=True)
    for name, make in SPLASHES.items():
        make().save(out / f"splash_{name}.png", scale)
        print("scritto", out / f"splash_{name}.png")
    frames = [night_scene("title", f, logo=False) for f in range(TITLE_FRAMES)]
    ms.write_png(art / "title_scene.png", [row for cv in frames for row in cv.rows()])
    title_logo().save(art / "title_logo.png")
    print("scritto", art / "title_scene.png", art / "title_logo.png")


if __name__ == "__main__":
    main()
