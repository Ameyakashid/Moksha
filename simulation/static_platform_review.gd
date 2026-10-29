extends Node2D
## Standalone physical platform composition. Ordinary controls, no mission host.
const Platform=preload("res://simulation/world/static_platform.tscn")
const Actor=preload("res://simulation/actors/shared_actor.tscn")
const InputSource=preload("res://simulation/components/player_input_source.gd")
const NPCSource=preload("res://simulation/components/npc_input_source.gd")
const Patrol=preload("res://simulation/components/patrol_intent_policy.gd")
const View=preload("res://demo/views/platform_view.tscn")
var platforms: Array=[]
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("071119"))
	for spec in [[Vector2(320,330),Vector2(600,40),false],[Vector2(140,264),Vector2(180,18),true],[Vector2(340,209),Vector2(180,18),true],[Vector2(510,280),Vector2(140,60),false]]:
		var p=Platform.instantiate();p.position=spec[0];p.platform_size=spec[1];p.one_way_collision=spec[2];add_child(p);platforms.append(p)
	var pc=Actor.instantiate();pc.position=Vector2(120,310)
	var input:=InputSource.new();input.name="InputSource";pc.add_child(input);add_child(pc)
	var npc=Actor.instantiate();npc.position=Vector2(510,250)
	var source:=NPCSource.new();source.name="InputSource";npc.add_child(source)
	var policy:=Patrol.new();policy.name="PatrolPolicy";npc.add_child(policy);add_child(npc)
	for i in range(3):
		var parent:=Node2D.new();parent.position=Vector2(120+i*200,120);parent.rotation=-0.18+i*0.18;parent.scale=Vector2(0.8+i*0.1,0.8);add_child(parent)
		var view=View.instantiate();view.platform_size=Vector2(150,18+i*16);parent.add_child(view)
	var title:=Label.new();title.position=Vector2(12,8);title.add_theme_font_size_override("font_size",13)
	title.text="PLACEABLE STATIC PLATFORMS / standalone scene";add_child(title)
	var hint:=Label.new();hint.position=Vector2(12,29);hint.add_theme_font_size_override("font_size",10)
	hint.text="A/D move · Space jump · Down+Space drop · R reset
H hides first raised view; its support remains. F8 stops.
Top: transformed appearance views. Below: actual PC/NPC supports.";add_child(hint)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode==KEY_R: get_tree().reload_current_scene()
	if event.keycode==KEY_H: platforms[1].get_node("View").visible=not platforms[1].get_node("View").visible
