extends Node2D
## Presentation-plus-contour reuse fixture, not a relay interaction controller.
const Relay = preload("res://simulation/world/relay_marker.tscn")
var sample:Node2D
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("08141c"))
	var label:=Label.new();label.position=Vector2(20,20);label.text="RELAY MARKERS · PRESENTATION + NONBLOCKING CONTOUR\nMission owns E / activation / noise / shutters / progression.\nH hides paint · C recolors · A toggles paint state · R reloads";label.add_theme_font_size_override("font_size",12);add_child(label)
	for i in range(4):
		var relay=Relay.instantiate();relay.position=Vector2(90+i*150,180);add_child(relay)
		if i==0:sample=relay
		if i==1:relay.is_active=true
		if i==2:relay.appearance.label="CALIBRATION"
		if i==3:relay.is_active=true;relay.appearance.active_ink=Color.CORAL
func _unhandled_key_input(event:InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.physical_keycode:
		KEY_H:sample.visible=not sample.visible
		KEY_C:
			sample.appearance.inactive_ink=Color.RED if sample.appearance.inactive_ink!=Color.RED else Color("e7b779")
			sample.appearance.active_ink=Color.RED if sample.appearance.active_ink!=Color.RED else Color("9ce5bd")
		KEY_A:sample.is_active=not sample.is_active
		KEY_R:get_tree().reload_current_scene()
