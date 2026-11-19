# Contenitore a due colonne per la scheda del colono: il primo figlio (l'intestazione) in alto per tutta la larghezza,
# poi i figli fino a quello di nome `split` (escluso, che non si vede) nella colonna di sinistra e gli altri in quella di
# destra. Ognuno alto quanto chiede, largo quanto la sua colonna. Così la scheda sta nei 720 pixel di altezza anche col
# testo a 22, e i nodi restano dove il codice li cerca (Box/Needs, Box/Skills...)
extends Container

@export var split := "Separator"  # il figlio che divide le colonne
@export var gap := 16               # pixel tra le due colonne
@export var separation := 4         # pixel tra un figlio e l'altro


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var parts := columns()
		var widths := [width_of(parts[1]), width_of(parts[2])]
		var y := 0.0
		for c in parts[0]:
			fit_child_in_rect(c, Rect2(0, y, size.x, c.get_combined_minimum_size().y))
			y += c.get_combined_minimum_size().y + separation
		for i in 2:
			var x: float = 0.0 if i == 0 else widths[0] + gap
			var w: float = widths[0] if i == 0 else size.x - x
			var at := y
			for c in parts[i + 1]:
				fit_child_in_rect(c, Rect2(x, at, w, c.get_combined_minimum_size().y))
				at += c.get_combined_minimum_size().y + separation


func _get_minimum_size() -> Vector2:
	var parts := columns()
	var head := Vector2.ZERO
	for c in parts[0]:
		head.x = maxf(head.x, c.get_combined_minimum_size().x)
		head.y += c.get_combined_minimum_size().y + separation
	var tall := maxf(height_of(parts[1]), height_of(parts[2]))
	return Vector2(maxf(head.x, width_of(parts[1]) + gap + width_of(parts[2])), head.y + tall)


# [in alto, a sinistra, a destra]: i figli visibili (il divisore no)
func columns() -> Array:
	var parts := [[], [], []]
	var at := 0
	for child in get_children():
		var c := child as Control
		if c == null or c.is_set_as_top_level():
			continue
		if c.name == split:
			at = 2
			continue
		if c.visible:
			parts[at].append(c)
		if at == 0:
			at = 1
	return parts


func width_of(list: Array) -> float:
	return list.reduce(func(w, c): return maxf(w, c.get_combined_minimum_size().x), 0.0)


func height_of(list: Array) -> float:
	return list.reduce(func(h, c): return h + c.get_combined_minimum_size().y + separation, 0.0)
