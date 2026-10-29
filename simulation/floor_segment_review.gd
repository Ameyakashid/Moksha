extends Node2D
## Standalone actual supports and detached views; no mission host.
const Floor=preload("res://simulation/world/floor_segment.tscn")
const Actor=preload("res://simulation/actors/shared_actor.tscn")
const InputSource=preload("res://simulation/components/player_input_source.gd")
const NPCSource=preload("res://simulation/components/npc_input_source.gd")
const Patrol=preload("res://simulation/components/patrol_intent_policy.gd")
const View=preload("res://demo/views/floor_view.tscn")
var floors: Array=[]
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("071119"))
	for spec in [[Vector2(160,330),Vector2(280,40)],[Vector2(490,330),Vector2(260,40)],[Vector2(500,260),Vector2(140,30)]]:
		var p=Floor.instantiate();p.position=spec[0];p.segment_size=spec[1];p.hatch_reference_x=p.position.x-p.segment_size.x*0.5;add_child(p);floors.append(p)
	floors[1].appearance.outline=Color("897c70");floors[1].appearance.hatch=Color("28303a")
	var pc=Actor.instantiate();pc.position=Vector2(120,310)
	var input:=InputSource.new();input.name="InputSource";pc.add_child(input);add_child(pc)
	var npc=Actor.instantiate();npc.position=Vector2(500,245)
	var source:=NPCSource.new();source.name="InputSource";npc.add_child(source)
	var policy:=Patrol.new();policy.name="PatrolPolicy";npc.add_child(policy);add_child(npc)
	for i in range(3):
		var parent:=Node2D.new();parent.position=Vector2(120+i*200,135);parent.rotation=-0.18+i*0.18;parent.scale=Vector2(0.8+i*0.1,0.8);add_child(parent)
		var view=View.instantiate();view.segment_size=Vector2(150,25+i*16);view.hatch_reference_x=-40.75+i*20;parent.add_child(view)
	var title:=Label.new();title.position=Vector2(12,8);title.add_theme_font_size_override("font_size",13)
	title.text="PLACEABLE FLOOR SEGMENTS / standalone scene";add_child(title)
	var hint:=Label.new();hint.position=Vector2(12,29);hint.add_theme_font_size_override("font_size",10)
	hint.text="A/D move · Space jump · R reset · H hides left floor paint\nTop: transformed views. Bottom: real PC/NPC supports and gap.\nHidden paint leaves collision intact. Down+Space cannot drop through."
	add_child(hint)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode==KEY_R: get_tree().reload_current_scene()
	if event.keycode==KEY_H: floors[0].get_node("View").visible=not floors[0].get_node("View").visible
