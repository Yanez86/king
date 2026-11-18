# Tetti degli edifici con la loro facciata, calcolati e non disegnati a mano: per ogni rettangolo di tetto (vedi
# update_roofs in main.gd) un'immagine con la facciata in fondo, il timpano se c'è e le falde. Proiezione obliqua come
# il resto del gioco: un punto a terra (x, g) alto z sta a schermo in (x, g - z). Scandole sopra i muri di legno, coppi
# sopra quelli di pietra (decide la maggioranza, le porte contano come legno). Il colmo corre lungo il lato lungo: negli
# edifici più larghi che profondi va da est a ovest, con un timpano sopra la porta se c'è posto; negli altri da nord a
# sud, col timpano in facciata. A parte la stessa immagine innevata, che main.gd vela quanto la neve a terra.
extends RefCounted

const T := 16
const FACADE := 24        # pixel: altezza della facciata coi tetti (senza, i muri sono gli sprite di STRUCTURES)
const OV := 2             # pixel: sporto del tetto oltre i muri
const HOLE := 9           # pixel: raggio del buco nel tetto attorno a chi ci sta dietro (vedi roof_holes in main.gd)...
const HOLE_DITHER := 13   # ...e fin dove arriva il suo bordo a scacchi

enum Mat { SHINGLE, COPPI }
enum Front { WOOD, STONE, DOOR, NONE }  # cosa c'è in ogni casella della fila in fondo: muro di legno, di pietra, porta, niente

# toni dal chiaro allo scuro; la falda al sole parte dal primo, quella in ombra dal terzo (vedi TONES)
const SHINGLE := [Color("b8a07c"), Color("9c8462"), Color("806a4e"), Color("65523c"), Color("4a3c2c"), Color("33291f")]
const COPPI := [Color("e8925c"), Color("cc7046"), Color("ac5636"), Color("8a432a"), Color("683020"), Color("48221a")]
const FADED := [Color("e8925c"), Color("e0a478"), Color("c4865e"), Color("a46c4c"), Color("845238"), Color("48221a")]  # coppi sbiaditi
const BROWN := [Color("e8925c"), Color("b07a50"), Color("92603e"), Color("764a30"), Color("5a3624"), Color("48221a")]  # coppi bruni
const SNOW := [Color("ffffff"), Color("f2f5fa"), Color("e2e8f2"), Color("cad3e2"), Color("a8b4c8"), Color("7a869e")]
const SNOW_STEP := [0, 0, 1, 2, 3, 4]  # tono del materiale -> tono di neve: sotto la neve resta la trama
const MOSS := [Color("8aa64e"), Color("6b8a3c"), Color("4f6b30")]
const PLASTER := [Color("efe6ce"), Color("dacdae")]
const BEAM := [Color("7a5434"), Color("5b3a24"), Color("3b2a1e")]
const STONE := [Color("d0d0d8"), Color("b4b3bd"), Color("9a99a6"), Color("7a7988"), Color("5e5c6c")]
const WOOD := [Color("c08a58"), Color("9a6b40"), Color("7a5434"), Color("53381f")]
const GLASS := [Color("34465a"), Color("6a8aa8")]
const GOLD := Color("e8c34a")
const OUTLINE := Color("1f1a24")
const SHADOW := Color("1f1a2460")
const CLEAR := Color(0, 0, 0, 0)
const TONES := {"back": 0, "left": 0, "front": 1, "right": 2}  # la luce viene da nord-ovest

var mat: int = Mat.SHINGLE
var along_x := true       # colmo est-ovest
var half := 0.0           # pixel a terra dalla gronda al colmo
var rise := 0.0           # pixel: quanto sale il colmo sopra la gronda
var ridge_a := Vector3.ZERO  # le due punte del colmo, in (x, g, z)
var ridge_b := Vector3.ZERO
var ex0 := 0.0            # rettangolo della gronda a terra: x da ex0 a ex1, g da eg0 a eg1
var ex1 := 0.0
var eg0 := 0.0
var eg1 := 0.0
var img: Image            # tetto e facciata
var snowy: Image          # solo le falde, innevate
var marks := PackedByteArray()  # 1 dove c'è falda o gronda: per il contorno e la gronda
var ox := 0               # angolo in alto a sinistra di img nel mondo, in pixel
var oy := 0
var w := 0
var h := 0


# Il tetto sul rettangolo `rect` (in caselle, muri compresi). `front`: Front per ogni colonna della fila in fondo;
# `sign_col`: la colonna col cartello (lì niente finestra), -1 se non c'è; `material`: Mat.
# Ritorna {"rect", "origin" (pixel nel mondo di image), "base" (riga in pixel del piede della facciata), "image", "snowy"}
# e la forma, per disegnarci sopra (vedi lift e on_roof): "along_x", "mid" (a terra, il colmo: g o x), "half", "rise",
# "eaves" (il rettangolo della gronda a terra), "thick" (lo spessore della gronda).
func bake(rect: Rect2i, front: Array, sign_col: int, material: int) -> Dictionary:
	mat = material
	var x0 := rect.position.x * T
	var y0 := rect.position.y * T
	var width := rect.size.x * T
	var depth := rect.size.y * T
	along_x = rect.size.x > rect.size.y
	if along_x:
		half = depth / 2.0 + OV
		rise = half - 6  # la falda dietro si vede appena, il colmo sta in alto
	else:
		half = width / 2.0 + OV
		rise = roundf(half * 0.8)
	ex0 = x0 - OV
	ex1 = x0 + width + OV
	eg0 = y0 - OV
	eg1 = y0 + depth + OV
	var top := minf(eg0 - FACADE, y0 + depth / 2.0 - FACADE - rise) if along_x else eg0 - FACADE - rise
	ox = x0 - OV - 2
	oy = floori(top) - 3
	w = width + 2 * OV + 4
	h = y0 + depth + 3 - oy
	img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	snowy = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	marks.resize(w * h)
	marks.fill(0)
	var stone := mat == Mat.COPPI  # l'ombra a terra sotto la facciata c'è già: è quella dei muri (draw_shadows)
	facade(x0, y0 + depth - FACADE, width, front, sign_col, stone)
	if not along_x:
		gable([scr(Vector3(x0, y0 + depth, FACADE)), scr(Vector3(x0 + width, y0 + depth, FACADE)),
			scr(Vector3(x0 + width / 2.0, y0 + depth, FACADE + rise * (width / 2.0) / half))], stone)
	slopes(x0, y0, width, depth)
	eave()
	outline()
	if along_x:
		var a := scr(ridge_a)
		for x in range(int(a.x), int(scr(ridge_b).x)):  # un filo di luce sul colmo
			if marked(x, int(a.y)) and marked(x, int(a.y) - 1):
				put(x, int(a.y) - 1, palette()[0], SNOW[0])
		var door_col := front.find(Front.DOOR)
		if rect.size.x >= 7 and rect.size.y >= 4 and door_col >= 2 and door_col <= rect.size.x - 3:
			cross_gable(x0, y0, depth, door_col, stone)
	else:
		bargeboards()
	return {"rect": rect, "origin": Vector2i(ox, oy), "base": y0 + depth, "image": img, "snowy": snowy,
		"along_x": along_x, "mid": y0 + depth / 2.0 if along_x else x0 + width / 2.0, "half": half, "rise": rise,
		"eaves": Rect2(ex0, eg0, ex1 - ex0, eg1 - eg0), "thick": 2 if mat == Mat.SHINGLE else 3}


# quanto sta in alto, in pixel, il tetto `look` (quello che ritorna bake) sopra il punto a terra `p`: la gronda a
# FACADE, il colmo FACADE + rise
static func lift(look: Dictionary, p: Vector2) -> float:
	var off: float = absf((p.y if look["along_x"] else p.x) - look["mid"])
	return FACADE + look["rise"] * clampf(1.0 - off / look["half"], 0.0, 1.0)


# dove si vede a schermo il punto del tetto sopra `p`
static func on_roof(look: Dictionary, p: Vector2) -> Vector2:
	return Vector2(p.x, p.y - lift(look, p))


# --- pixel --------------------------------------------------------------------------------------------------------------
func scr(p: Vector3) -> Vector2:
	return Vector2(p.x, p.y - p.z)


# `c` in (x, y) del mondo, sopra quello che c'è se è trasparente; `snow` lo stesso pixel nell'immagine innevata
func put(x: int, y: int, c: Color, snow := CLEAR) -> void:
	var lx := x - ox
	var ly := y - oy
	if lx < 0 or ly < 0 or lx >= w or ly >= h:
		return
	if c.a < 1.0:
		var under := img.get_pixel(lx, ly)
		if under.a > 0.0:
			c = under.blend(c)
	img.set_pixel(lx, ly, c)
	snowy.set_pixel(lx, ly, snow)


func mark(x: int, y: int) -> void:
	var lx := x - ox
	var ly := y - oy
	if lx >= 0 and ly >= 0 and lx < w and ly < h:
		marks[ly * w + lx] = 1


func marked(x: int, y: int) -> bool:
	var lx := x - ox
	var ly := y - oy
	return lx >= 0 and ly >= 0 and lx < w and ly < h and marks[ly * w + lx] == 1


func empty(x: int, y: int) -> bool:
	var lx := x - ox
	var ly := y - oy
	return lx < 0 or ly < 0 or lx >= w or ly >= h or img.get_pixel(lx, ly).a == 0.0


# i pixel col centro dentro il poligono convesso `poly` (punti a schermo), riga per riga
func pixels_in(poly: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var lo := INF
	var hi := -INF
	for p: Vector2 in poly:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	for y in range(floori(lo), ceili(hi) + 1):
		var sy := y + 0.5
		var left := INF
		var right := -INF
		for i in poly.size():
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % poly.size()]
			if a.y == b.y:
				if a.y == sy:  # lato orizzontale proprio su questa riga
					left = minf(left, minf(a.x, b.x))
					right = maxf(right, maxf(a.x, b.x))
			elif (a.y <= sy and sy <= b.y) or (b.y <= sy and sy <= a.y):
				var x := a.x + (sy - a.y) * (b.x - a.x) / (b.y - a.y)
				left = minf(left, x)
				right = maxf(right, x)
		if left > right:
			continue
		for x in range(ceili(left - 0.5), floori(right - 0.5) + 1):
			out.append(Vector2i(x, y))
	return out


func line(p0: Vector2, p1: Vector2, c: Color, width := 1, snow := CLEAR) -> void:
	var steps := maxi(1, int(maxf(absf(p1.x - p0.x), absf(p1.y - p0.y))))
	for i in steps + 1:
		var t := float(i) / steps
		var x := floori(p0.x + (p1.x - p0.x) * t)
		var y := floori(p0.y + (p1.y - p0.y) * t)
		for k in width:
			put(x, y + k, c, snow)


static func hash3(a: int, b: int, c: int) -> int:
	var hh := 2166136261
	for v in [a, b, c]:
		hh = ((hh ^ (v & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
	hh ^= hh >> 13
	hh = (hh * 0x5BD1E995) & 0xFFFFFFFF
	hh ^= hh >> 15
	return hh


func palette() -> Array:
	return COPPI if mat == Mat.COPPI else SHINGLE


func pick(pal: Array, t: int, snow: bool) -> Color:
	t = clampi(t, 0, 5)
	return SNOW[SNOW_STEP[t]] if snow else pal[t]


# --- falde --------------------------------------------------------------------------------------------------------------
# colore di un pixel di falda: u lungo la gronda, v su dalla gronda, dr distanza dal colmo (pixel a schermo)
func tex(u: int, v: float, tone: int, dr: int, snow: bool) -> Color:
	var iv := int(v)
	if mat == Mat.SHINGLE:
		if dr < 2:  # la tavola del colmo
			return SNOW[0] if snow else BEAM[1 if dr < 1 else 2]
		var row := iv / 3
		var off := 2 if row % 2 else 0
		var sh := (u + off) / 4
		var t := tone + hash3(sh, row, 2) % 3
		if iv % 3 == 2:
			t = tone + 3  # l'ombra della fila sopra
		elif (u + off) % 4 == 0:
			t = tone + 2
		if hash3(sh / 2, row / 2, 4) % 41 == 0 and iv % 3 != 2 and v < 24:
			return SNOW[2] if snow else MOSS[mini(2, tone)]
		return pick(SHINGLE, t, snow)
	if dr < 3:  # coppi di colmo, di traverso
		return pick(COPPI, tone + [3, 1, 0, 0, 2][(u + 1) % 5] + (1 if dr == 2 else 0), snow)
	var col := u / 4
	var k := u % 4
	var rowv := iv + (2 if col % 2 else 0)
	var row := rowv / 5
	var r := hash3(col, row, 3) % 9
	var t: int = tone + [0, 1, 1, 3][k]
	if rowv % 5 == 0:
		t = tone + (3 if k != 0 else 2)  # dove un coppo copre quello sotto
	if hash3(col, row, 8) % 47 == 0 and (k == 1 or k == 2) and v < 24:
		return SNOW[2] if snow else MOSS[mini(2, tone)]
	return pick(FADED if r == 0 else (BROWN if r == 1 else COPPI), t, snow)


# le due falde; la gronda davanti sta più in basso di FACADE pixel della linea dei muri a terra
func slopes(x0: int, y0: int, width: int, depth: int) -> void:
	var z := float(FACADE)
	var planes := []
	if along_x:
		var gm := y0 + depth / 2.0
		ridge_a = Vector3(ex0, gm, z + rise)
		ridge_b = Vector3(ex1, gm, z + rise)
		planes = [["back", [Vector3(ex0, eg0, z), Vector3(ex1, eg0, z), ridge_b, ridge_a]],
			["front", [Vector3(ex0, eg1, z), Vector3(ex1, eg1, z), ridge_b, ridge_a]]]
	else:
		var xm := x0 + width / 2.0
		ridge_a = Vector3(xm, eg0, z + rise)
		ridge_b = Vector3(xm, eg1, z + rise)
		planes = [["left", [Vector3(ex0, eg0, z), Vector3(ex0, eg1, z), ridge_b, ridge_a]],
			["right", [Vector3(ex1, eg0, z), Vector3(ex1, eg1, z), ridge_b, ridge_a]]]
	var ridge := scr(ridge_a)
	for plane: Array in planes:
		var pts: Array = plane[1]
		var p0: Vector3 = pts[0]
		var p1: Vector3 = pts[1]
		var p2: Vector3 = pts[2]
		var n := (p1 - p0).cross(p2 - p0)
		if n.z < 0:
			n = -n
		if n.y + n.z <= 0.000001:
			continue  # rivolta dall'altra parte: dietro un tetto ripido non si vede
		var tone: int = TONES[plane[0]]
		var e0 := scr(p0)
		var flat := is_equal_approx(e0.y, scr(p1).y)  # gronda orizzontale a schermo (falde davanti e dietro)
		var poly := []
		for p: Vector3 in pts:
			poly.append(scr(p))
		for p in pixels_in(poly):
			var u := p.x if flat else p.y
			var v := absf(p.y + 0.5 - e0.y) if flat else absf(p.x + 0.5 - e0.x)
			var dr := int(absf(p.y + 0.5 - ridge.y)) if flat else int(absf(p.x + 0.5 - ridge.x))
			put(p.x, p.y, tex(u, v, tone, dr, false), tex(u, v, tone, dr, true))
			mark(p.x, p.y)


# lo spessore della gronda sotto l'ultima riga di falda di ogni colonna, e la sua ombra
func eave() -> void:
	var thick := 2 if mat == Mat.SHINGLE else 3
	for lx in w:
		var bottom := -1
		for ly in h:
			if marks[ly * w + lx] == 1:
				bottom = ly
		if bottom < 0:
			continue
		var x := lx + ox
		for k in range(1, thick + 1):
			var c: Color = BEAM[1] if k < thick else OUTLINE
			if mat == Mat.COPPI:  # le teste dei coppi
				c = COPPI[1 + k] if (x % 4 == 1 or x % 4 == 2) and k < thick else OUTLINE
				if k == 1 and (x % 4 == 0 or x % 4 == 3):
					c = COPPI[4]
			put(x, bottom + oy + k, c, SNOW[2] if k == 1 else CLEAR)
			mark(x, bottom + oy + k)
		for k in [1, 2]:
			put(x, bottom + oy + thick + k, SHADOW)


# il contorno scuro dove la falda dà sul vuoto
func outline() -> void:
	var edge: Array[Vector2i] = []
	for ly in h:
		for lx in w:
			if marks[ly * w + lx] != 1:
				continue
			var x := lx + ox
			var y := ly + oy
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
				if not marked(x + d.x, y + d.y) and empty(x + d.x, y + d.y):
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		put(p.x, p.y, OUTLINE)


# tavole di bordo lungo le falde del timpano in facciata
func bargeboards() -> void:
	var tip := scr(ridge_b)
	var board: Color = BEAM[0] if mat == Mat.SHINGLE else COPPI[2]
	for ex: float in [ex0, ex1]:
		var p0 := scr(Vector3(ex, eg1, FACADE))
		line(p0, tip, board, 2, SNOW[1])
		line(p0 + Vector2.UP, tip + Vector2.UP, OUTLINE)
		line(p0 + Vector2(0, 2), tip + Vector2(0, 2), BEAM[2])
	put(int(tip.x), int(tip.y) - 1, OUTLINE)
	put(int(tip.x) - 1, int(tip.y) - 1, OUTLINE)


# timpano sopra la porta negli edifici larghi, col suo colmo che entra nella falda davanti
func cross_gable(x0: int, y0: int, depth: int, door_col: int, stone: bool) -> void:
	var cx := x0 + door_col * T + T / 2.0
	var hw := 2.0 * T
	var rg := minf(roundf(hw * 0.95), rise - 2)
	var g := y0 + depth
	var meet := rg / rise * (depth / 2.0 + OV)  # dove il colmo del timpano entra nella falda grande
	var apex := Vector3(cx, g + OV, FACADE + rg)
	var back := Vector3(cx, g + OV - meet, FACADE + rg)
	for side in [["left", cx - hw - OV], ["right", cx + hw + OV]]:
		var ex: float = side[1]
		var tone: int = TONES[side[0]]
		for p in pixels_in([scr(Vector3(ex, g + OV, FACADE)), scr(apex), scr(back)]):
			var v := absf(p.x + 0.5 - ex)
			var dr := int(absf(p.x + 0.5 - cx))
			put(p.x, p.y, tex(p.y, v, tone, dr, false), tex(p.y, v, tone, dr, true))
	gable([scr(Vector3(cx - hw, g, FACADE)), scr(Vector3(cx + hw, g, FACADE)),
		scr(Vector3(cx, g, FACADE + rg * hw / (hw + OV)))], stone)
	var board: Color = BEAM[0] if mat == Mat.SHINGLE else COPPI[2]
	for ex: float in [cx - hw - OV, cx + hw + OV]:
		var p0 := scr(Vector3(ex, g + OV, FACADE))
		line(p0, scr(back), palette()[4])  # la valle
		line(p0, scr(apex), board, 2, SNOW[1])
		line(p0 + Vector2.UP, scr(apex) + Vector2.UP, OUTLINE)
	var t := scr(apex)
	put(int(t.x), int(t.y) - 1, OUTLINE)
	put(int(t.x) - 1, int(t.y) - 1, OUTLINE)


# --- muri ---------------------------------------------------------------------------------------------------------------
# pietre a corsi sfalsati: lx da sinistra, fb dal basso
func stone_px(lx: int, fb: int) -> Color:
	var course := fb / 3
	var off := 4 if course % 2 else 0
	if fb % 3 == 0:
		return STONE[4]
	if (lx + off) % 7 == 0:
		return STONE[3]
	var tone := 1 + hash3((lx + off) / 7, course, 11) % 3
	if fb % 3 == 2 and (lx + off) % 7 in [1, 2, 3]:
		tone -= 1
	return STONE[tone]


# Facciata della fila in fondo, alta FACADE: graticcio (travi e intonaco su uno zoccolo di pietra) sul legno, pietra a
# corsi sulla pietra; una finestra ogni due caselle di muro, le porte ad arco
func facade(x0: int, y0: int, width: int, front: Array, sign_col: int, stone: bool) -> void:
	var wins := []
	for i in range(1, front.size() - 1):
		if i % 2 == 1 and i != sign_col and front[i] in [Front.WOOD, Front.STONE]:
			wins.append(i)
	for ly in FACADE:
		for lx in width:
			put(x0 + lx, y0 + ly, wall_px(front, lx, ly, width, wins, stone))
	for ly in FACADE:
		put(x0, y0 + ly, OUTLINE)
		put(x0 + width - 1, y0 + ly, OUTLINE)
	for lx in width:
		put(x0 + lx, y0 + FACADE - 1, OUTLINE)
	for i: int in wins:
		window(x0 + i * T + 4, y0 + FACADE - 13, front[i] == Front.STONE)
	for i in front.size():
		if front[i] == Front.DOOR:
			door(x0 + i * T + 3, y0 + FACADE - 16, stone)


func wall_px(front: Array, lx: int, ly: int, width: int, wins: Array, stone: bool) -> Color:
	var fb := FACADE - 1 - ly
	var cell := lx / T
	var kind: int = front[cell]
	if kind == Front.STONE or (kind != Front.WOOD and stone):
		return stone_px(lx, fb)
	if fb < 3:
		return stone_px(lx, fb)  # zoccolo
	if fb == 3 or ly < 2:
		return BEAM[2] if ly == 1 else BEAM[1]
	var post := lx % T
	if post < 2 or lx >= width - 2:
		return BEAM[1] if post == 0 or lx == width - 2 else BEAM[2]
	if cell in wins:
		if fb == FACADE - 6:
			return BEAM[1]
	elif kind == Front.WOOD:  # croce di sant'Andrea
		var v := fb - 4
		var tall := FACADE - 6
		if v < tall:
			var t := (post - 2) / float(T - 3)
			if absf(v - t * (tall - 1)) < 0.75 or absf(v - (1 - t) * (tall - 1)) < 0.75:
				return BEAM[1]
	return PLASTER[1 if ly < 5 or hash3(lx, ly, 5) % 29 == 0 else 0]


func window(x: int, y: int, stone: bool) -> void:
	var frame: Color = OUTLINE if stone else BEAM[2]
	for yy in 7:
		for xx in 8:
			var c: Color = GLASS[1] if (xx + yy) % 5 == 0 and xx < 4 else GLASS[0]
			if xx == 0 or xx == 7 or yy == 0 or yy == 6 or xx == 4:
				c = frame
			put(x + xx, y + yy, c)
	for xx in range(-1, 9):
		put(x + xx, y + 7, STONE[1] if stone else BEAM[0])  # davanzale
		if stone:
			put(x + xx, y - 1, STONE[0])  # architrave


func door(x: int, y: int, stone: bool) -> void:
	var dw := 10
	var dh := 15
	for yy in dh:
		for xx in dw:
			if yy < 2 and (xx < 2 - yy or xx >= dw - 2 + yy):
				continue  # l'arco
			var c: Color = [WOOD[1], WOOD[2], WOOD[3]][(xx - 1) % 3]
			if xx == 0 or xx == dw - 1 or yy == 0 or (yy == 1 and (xx == 1 or xx == dw - 2)):
				c = OUTLINE
			elif yy == 4 or yy == dh - 4:  # le traverse
				c = OUTLINE if xx == 1 or xx == dw - 2 else WOOD[3]
			put(x + xx, y + yy, c)
	put(x + dw - 3, y + dh / 2 + 1, GOLD)
	if stone:  # stipiti
		for yy in range(1, dh):
			put(x - 1, y + yy, STONE[0])
			put(x + dw, y + yy, STONE[2])


# timpano: graticcio coi puntoni a V sul legno, pietra sulla pietra, e la finestrella del sottotetto
func gable(tri: Array, stone: bool) -> void:
	var a: Vector2 = tri[0]
	var b: Vector2 = tri[1]
	var top: Vector2 = tri[2]
	var mid := (a.x + b.x) / 2.0
	var half_w := (b.x - a.x) / 2.0
	var tall := a.y - top.y
	for p in pixels_in(tri):
		var fb := int(a.y) - p.y
		var c: Color
		if stone:
			c = stone_px(int(p.x - a.x), fb + 1)
		else:
			c = PLASTER[0 if fb > 6 else 1]
			var d := absf(p.x + 0.5 - mid)
			if d < 1 or fb == 1 or fb == 2:
				c = BEAM[2] if fb == 1 else BEAM[1]
			if absf(d - half_w * 0.5 * (1.0 - fb / tall)) < 0.8 and fb < tall * 0.7:
				c = BEAM[1]
			if fb == int(tall * 0.45):
				c = BEAM[1]
		put(p.x, p.y, c)
	var m := int(mid)
	var wy := int(top.y + tall * 0.5)
	for yy in 4:
		for xx in [-1, 0, 1]:
			put(m + xx, wy + yy, OUTLINE if yy == 0 or yy == 3 or xx != 0 else GLASS[0])


# Il timbro del buco nel tetto: opaco dove il tetto si toglie (vedi cut_holes in main.gd). Il bordo è a scacchi sul
# mondo: `odd` (0 o 1) sceglie quali, secondo il centro del buco, così non sfarfallano quando chi c'è dietro si muove.
static func hole_mask(odd: int) -> Image:
	var size := HOLE_DITHER * 2
	var m := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - HOLE_DITHER, y + 0.5 - HOLE_DITHER).length()
			if d < HOLE or (d < HOLE_DITHER and (x + y + odd) % 2 == 0):
				m.set_pixel(x, y, Color.WHITE)
	return m
