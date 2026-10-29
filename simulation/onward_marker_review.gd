extends Node2D
## Standalone marker review. The indicator never blocks or completes a mission.
const Marker = preload("res://simulation/world/onward_marker.tscn")
var sample: Node2D
func caption(at: Vector2, text: String) -> void:
	var label:=Label.new();label.position=at;label.text=text;label.add_theme_font_size_override("font_size",12);add_child(label)
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("08141c"))
	caption(Vector2(20,20),"ONWARD / LIFT MARKERS · PRESENTATION + NONBLOCKING SONAR CONTOUR")
	caption(Vector2(20,46),"Host supplies open/ending state. No automatic completion or collision barrier.")
	for i in range(4):
		var marker=Marker.instantiate();marker.position=Vector2(90+i*150,180);marker.is_open=i%2==1;marker.ending=i>=2;add_child(marker)
		if i==0:sample=marker
	caption(Vector2(20,215),"O toggles state   L switches label   H hides paint   C recolors   R reloads")
	caption(Vector2(20,245),"All four retain the same enabled 40×76 contour, layer 0 / mask 0.")
	caption(Vector2(20,270),"These markers are separate from the actual relay and freight shutters.")
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.physical_keycode:
		KEY_O:sample.is_open=not sample.is_open
		KEY_L:sample.ending=not sample.ending
		KEY_H:sample.visible=not sample.visible
		KEY_C:sample.appearance.closed_ink=Color.RED if sample.appearance.closed_ink!=Color.RED else Color("cd946a")
		KEY_R:get_tree().reload_current_scene()
