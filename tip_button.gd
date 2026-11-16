extends Control
# Control (pulsante, figurina) col suggerimento costruito da make_tip (Callable che restituisce un Control) al posto
# del testo semplice; Godot lo mette dentro il pannello TooltipPanel del tema. tooltip_text non vuoto, se no non compare

var make_tip: Callable


func _make_custom_tooltip(_for_text: String) -> Object:
	return make_tip.call()
