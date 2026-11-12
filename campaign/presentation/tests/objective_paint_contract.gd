extends SceneTree
class Fixture extends Node2D:
	var kind:="breaker"
	var label:="Break the welded tram brake"
	var completed:=false
	var available:=false
	var setting:=-1
	var target:=2
var failures: Array[String]=[]
var checks:=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var fixture:=Fixture.new();root.add_child(fixture)
	var view:=Node2D.new();view.set_script(load("res://campaign/views/objective_view.gd"));fixture.add_child(view)
	check(view.z_index==-1,"machine behind actors0 above terrain-5")
	for kind in ["breaker","plate","rescue","recover","route","terminal","install"]:
		for available in [false,true]:
			for completed in [false,true]:
				fixture.kind=kind;fixture.available=available;fixture.completed=completed
				view.queue_redraw();await process_frame
				check(fixture.kind==kind and fixture.available==available and fixture.completed==completed,"view never mutates objective "+kind)
				check(view.get_child_count()==1 and view.get_node("Caption") is Node2D,"caption-only child, no collision "+kind)
	var Caption=load("res://campaign/views/objective_caption.gd")
	for zoom in [.5,1.0,2.0]:
		for offset in [Vector2(0,0),Vector2(-140,75),Vector2(80,-120)]:
			for screen_x in [-1000.0,-80.0,4.0,320.0,636.0,720.0,1600.0]:
				# Compose camera zoom+translation and objective translation separately.
				var camera:=Transform2D(Vector2(zoom,0),Vector2(0,zoom),offset)
				var world_anchor:Vector2=camera.affine_inverse()*Vector2(screen_x,180)
				var canvas:Transform2D=camera*Transform2D(0,world_anchor)
				var result:Dictionary=Caption.placement(Vector2(-60,-54),200,10,canvas,Rect2(0,0,640,360))
				var expected:bool=screen_x>=-16 and screen_x<=656
				check(result.draw==expected,"real anchor culling with camera/zoom")
				if result.draw:check(result.screen_box.position.x>=7.99 and result.screen_box.end.x<=632.01,"visible edge text clamps within viewport")
	check(view.get_node("Caption").z_index+view.z_index>0,"caption above door/actor while machine stays behind")
	var crate:Node2D=load("res://scenes/props/crate.tscn").instantiate()
	check(view.get_node("Caption").z_index+view.z_index>crate.z_index,"caption clears real foreground crate layer")
	check(view.get_node("Caption").z_as_relative,"caption stays relative to blind-hidden presentation owner")
	crate.free()
	view.visible=false;await process_frame
	check(not view.is_visible_in_tree() and not view.get_node("Caption").is_visible_in_tree(),"whole view/caption obeys authoritative blind hide")
	fixture.queue_free();await process_frame
	if failures.is_empty():print("OBJECTIVE_PAINT_CONTRACT_PASS: ",checks," draw/state/layer checks")
	else:for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)
