extends Node2D
## Frozen pose-only parity: old host-coupled echo vs explicit-source echo.
class Host extends Node:
	var blind:=true
	var state:="playing"
	var player:Node2D
var records:Array=[]
var failures:Array[String]=[]
func _ready()->void:run.call_deferred()
func viewport()->SubViewport:
	var v:=SubViewport.new();v.size=Vector2i(640,360);v.world_2d=World2D.new();v.transparent_bg=true;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(v);return v
func run()->void:
	if DisplayServer.get_name()=="headless":push_error("Native rendering required");get_tree().quit(2);return
	for mode in ["idle","run","jump","roll_travel"]:
		for facing in [-1,1]:
			var a:=viewport();var b:=viewport();var host:=Host.new();var echoes:Array=[]
			for v in [a,b]:
				var player:=Node2D.new();player.position=Vector2(320.25,240.5);v.add_child(player)
				var source=preload("res://combat_pc/visuals/lithe_wireframe.gd").new();source.name="Visual";player.add_child(source)
				source._pose=source.evaluate_pose(mode,0.35,{"facing":facing,"grounded":mode in ["idle","run"]});source.hide()
				if v==a:
					host.player=player;var echo=preload("res://demo/components/proprioception.gd").new();echo.host=host;v.add_child(echo);echo._process(0.0);echo.set_process(false);echoes.append(echo)
				else:
					var echo=preload("res://simulation/ui/body_echo.tscn").instantiate();echo.source_visual=source;echo.enabled=true;v.add_child(echo);echo._process(0.0);echo.set_process(false);echoes.append(echo)
			await get_tree().process_frame;await RenderingServer.frame_post_draw
			var ai=a.get_texture().get_image();var bi=b.get_texture().get_image();ai.convert(Image.FORMAT_RGBA8);bi.convert(Image.FORMAT_RGBA8)
			var x:=ai.get_data();var y:=bi.get_data();var count:=0
			for i in range(3,x.size(),4):if x[i]>0:count+=1
			var label:String=mode+"_"+str(facing);var passed:=x==y and count>0
			if not passed:failures.append(label)
			records.append({"label":label,"passed":passed,"exact_rgba":x==y,"content_pixels":count})
			ai.save_png("res://simulation/evidence/body_echo_"+label+"_old.png");bi.save_png("res://simulation/evidence/body_echo_"+label+"_new.png")
			a.free();b.free();host.free()
	var report={"records":records,"failures":failures,"display_server":DisplayServer.get_name(),"scope":"Frozen pose-only native comparison, identical inherited renderer and fractional transform; not gameplay animation or timing."}
	FileAccess.open("res://simulation/evidence/body_echo_pixels.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("BODY ECHO PIXELS ",records.size()," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
