extends Control
# Control (pulsante, figurina) col suggerimento costruito da make_tip (Callable che restituisce un Control) al posto
# del testo semplice; Godot lo mette dentro il pannello TooltipPanel del tema. tooltip_text non vuoto, se no non compare.
# Senza make_tip valido, il suggerimento è tooltip_text

var make_tip: Callable


func _make_custom_tooltip(_for_text: String) -> Object:
	return make_tip.call() if make_tip.is_valid() else null  # senza make_tip, il testo semplice
