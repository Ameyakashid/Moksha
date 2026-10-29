extends Node2D
## Review UI stays above world contours so a floor underside cannot cross text.
func _process(_dt: float) -> void: queue_redraw()
func _draw() -> void:
	var review := get_parent().get_parent()
	if review.has_method("render_hud"): review.render_hud(self)
