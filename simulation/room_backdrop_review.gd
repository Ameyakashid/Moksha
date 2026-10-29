extends Node2D
## Actual reusable view instances, not screenshots. No mission or physical world.
const View=preload("res://demo/views/room_backdrop.tscn")
const Profile=preload("res://demo/views/room_backdrop_profile.gd")
var views: Array[Node2D]=[]
var frozen:=false
func _ready() -> void:
	var title:=Label.new(); title.position=Vector2(12,8);title.text="REUSABLE ROOM BACKDROP / live view instances"
	title.add_theme_font_size_override("font_size",15);add_child(title)
	var hint:=Label.new();hint.position=Vector2(12,30);hint.text="Space: freeze rain   H: hide/show first   R: reset time   F8: stop"
	hint.add_theme_font_size_override("font_size",11);add_child(hint)
	for i in range(4):
		var frame:=SubViewportContainer.new();frame.position=Vector2(12+(i%2)*314,61+(i/2)*143);frame.size=Vector2(302,134);add_child(frame)
		var viewport:=SubViewport.new();viewport.size=Vector2i(302,134);viewport.world_2d=World2D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;frame.add_child(viewport)
		var parent:=Node2D.new();parent.position=Vector2(31,37);parent.scale=Vector2(0.33,0.25)
		if i==2:parent.rotation=-0.10
		if i==3:parent.rotation=0.09;parent.scale=Vector2(0.36,0.23)
		viewport.add_child(parent)
		var view=View.instantiate();var config=Profile.new();config.room_bounds=Rect2(0,-100,700,400);config.theme="city" if i%2==0 else "interior"
		if i==2:config.room_bounds.position=Vector2(35,-75)
		if i==3:config.visual_seed=37
		view.profile=config;view.set_animation_time(i*0.5);parent.add_child(view);views.append(view)
		var label:=Label.new();label.position=Vector2(5,5);label.add_theme_font_size_override("font_size",10)
		label.text=["CITY / seed 0 / live rain","INTERIOR / seed 0","CITY / rotated + translated bounds","INTERIOR / rotated + scaled / seed 37"][i]
		viewport.add_child(label)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():return
	if event.keycode==KEY_SPACE:
		frozen=not frozen
		for view in views:view.automatic_animation=not frozen
	elif event.keycode==KEY_H:views[0].visible=not views[0].visible
	elif event.keycode==KEY_R:
		for view in views:view.set_animation_time(0.0)
