extends Node2D
## Presentation-plus-contour reuse fixture, not a trade interaction controller.
const Station = preload("res://simulation/world/exchange_station.tscn")
var sample:Node2D
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("08141c"))
	var label:=Label.new();label.position=Vector2(20,20);label.text="EXCHANGE STATIONS · PRESENTATION + NONBLOCKING CONTOUR\nMission owns E / choice / health / speed / noise. No forced trade.\nH hides paint · C recolors · R reloads";label.add_theme_font_size_override("font_size",12);add_child(label)
	for i in range(4):
		var station=Station.instantiate();station.position=Vector2(90+i*150,180);add_child(station)
		if i==0:sample=station
		if i==2:station.appearance.label="CALIBRATION"
		if i==3:station.appearance.ink=Color.CORAL
func _unhandled_key_input(event:InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.physical_keycode:
		KEY_H:sample.visible=not sample.visible
		KEY_C:sample.appearance.ink=Color.RED if sample.appearance.ink!=Color.RED else Color("e9d2ab")
		KEY_R:get_tree().reload_current_scene()
