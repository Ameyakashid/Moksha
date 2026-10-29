extends Node2D
## Standalone decorative sign review; no mission, actor, collision or interaction.
const Sign = preload("res://simulation/world/world_sign.tscn")
var sample: Node2D
func add_sign(at: Vector2, words: String, size:=9) -> Node2D:
	var sign_view=Sign.instantiate();sign_view.position=at;sign_view.text=words;sign_view.appearance.font_size=size;add_child(sign_view);return sign_view
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("08141c"))
	add_sign(Vector2(20,28),"WORLD SIGNS / DECORATIVE ONLY",17)
	add_sign(Vector2(20,48),"No collision, sonar contour, interaction or gameplay",10)
	add_sign(Vector2(20,76),"Original baseline / fallback font / 9 px",11)
	sample=add_sign(Vector2(30,102),"SERVICE <   HUB >")
	add_sign(Vector2(250,102),"DISPATCH RECOVERY ^")
	add_sign(Vector2(20,136),"Custom font + alignment within 180 px",11)
	for i in range(3):
		var sign_view=add_sign(Vector2(30+i*190,165),["LEFT","CENTER","RIGHT"][i],13)
		sign_view.appearance.font=preload("res://fonts/DejaVuSansMono.ttf")
		sign_view.appearance.alignment=i;sign_view.appearance.width=180
		sign_view.appearance.font_color=Color("e9d2ab")
	add_sign(Vector2(20,207),"Repeated nested transforms / isolated local resources",11)
	for i in range(3):
		var holder:=Node2D.new();holder.position=Vector2(90+i*190,253);holder.rotation=-0.18+i*0.18;holder.scale=Vector2(0.9+i*0.1,1);add_child(holder)
		var sign_view=Sign.instantiate();sign_view.text="LIFT CONTROL";sign_view.baseline_offset=Vector2(-30,-4.25);holder.add_child(sign_view)
		if i==1: sign_view.appearance.font_color=Color("e7b779")
	add_sign(Vector2(20,315),"H hides one sign   C recolors it   R reloads",11)
	add_sign(Vector2(20,337),"Changes affect only paint. These are native text assets.",10)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode==KEY_H: sample.visible=not sample.visible
	if event.physical_keycode==KEY_C: sample.appearance.font_color=Color("e7b779") if sample.appearance.font_color==Color("89b2b6") else Color("89b2b6")
	if event.physical_keycode==KEY_R: get_tree().reload_current_scene()
