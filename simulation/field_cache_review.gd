extends Node2D
## Isolated cache presentation-and-contour fixture. No mission interaction policy.
const Cache = preload("res://simulation/world/field_cache.tscn")
var sample:Node2D
var status:Label
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("08141c"))
	var label:=Label.new();label.position=Vector2(20,20);label.text="FIELD CACHES · PRESENTATION + NONBLOCKING CONTOUR\nMission owns E / collection / healing / archive / save.\nH hides paint · C recolors · F toggles found · R reloads";label.add_theme_font_size_override("font_size",12);add_child(label)
	for i in range(4):
		var cache=Cache.instantiate();cache.position=Vector2(90+i*150,180);add_child(cache)
		if i==0:sample=cache
		if i==1:cache.scale=Vector2(2,2)
		if i==2:cache.rotation=0.3
		if i==3:cache.appearance.ink=Color.CORAL
	status=Label.new();status.position=Vector2(20,240);status.add_theme_font_size_override("font_size",12);add_child(status);update_status()
func update_status() -> void:
	status.text="First cache: visible=%s · found=%s · sonar_ignore=%s · shape_enabled=%s"%[sample.visible,sample.is_found,sample.get_node("CacheContour").is_in_group("sonar_ignore"),not sample.get_node("CacheContour/Shape").disabled]
func _unhandled_key_input(event:InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.physical_keycode:
		KEY_H:sample.visible=not sample.visible
		KEY_C:sample.appearance.ink=Color.RED if sample.appearance.ink!=Color.RED else Color("b1c9d1")
		KEY_F:sample.is_found=not sample.is_found
		KEY_R:get_tree().reload_current_scene();return
	update_status()
