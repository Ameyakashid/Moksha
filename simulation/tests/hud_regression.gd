extends SceneTree
## Presentation lifecycle and host input checks, not full-route timing evidence.
var checks: Array = []
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func key(host: Node, code: int) -> void:
	var event := InputEventKey.new(); event.physical_keycode=code; event.pressed=true
	host._unhandled_key_input(event)
	host._process(0.0)
func run() -> void:
	var scene = preload("res://simulation/ui/mission_hud.tscn")
	var a = scene.instantiate(); var b = scene.instantiate(); root.add_child(a); root.add_child(b)
	check(a.appearance!=b.appearance,"default styles are instance-local")
	var before: Dictionary=a.get_snapshot()
	check(not a.set_snapshot({"state":root}),"object rejected")
	check(not a.set_snapshot({"elapsed":NAN}),"nonfinite clock rejected")
	check(not a.set_snapshot({"health_capacity":0.0}),"zero health denominator rejected")
	check(a.get_snapshot()==before,"invalid snapshot is atomic")
	check(a.set_snapshot({"authored_area_count":7,"ending_count":1}) and a.get_snapshot().authored_area_count==7,"explicit historical eight-area presentation input retained")
	check(a.set_snapshot({"authored_area_count":8,"ending_count":1}) and a.get_node("View").data.authored_area_count==8,"current nine-area count reaches independent view")
	check(not a.set_snapshot({"ending_count":-1}),"negative ending count rejected")
	var data: Dictionary={"state":"playing","player_present":true,"health_current":25.0,"health_capacity":100.0,"notice":"first"}
	check(a.set_snapshot(data),"valid snapshot accepted")
	data.notice="external mutation"
	check(a.get_snapshot().notice=="first","input snapshot copy")
	var leaked: Dictionary=a.get_snapshot(); leaked.notice="returned mutation"
	check(a.get_snapshot().notice=="first","output snapshot copy")
	var view=a.get_node("View");var old_style=a.appearance
	var style=preload("res://demo/views/hud_appearance.gd").new();a.appearance=style
	check(not old_style.changed.is_connected(view._refresh),"retired style disconnected")
	check(style.changed.is_connected(view._refresh),"new style subscribed")
	a.appearance=null;check(view.appearance==null,"null paint supported")
	a.remove_child(view);view.free()
	check(a.set_snapshot({"state":"paused"}) and a.get_snapshot().state=="paused","missing view retains presentation data")
	root.remove_child(a);check(a.set_snapshot({"state":"dead"}),"detached snapshot accepted");root.add_child(a)
	check(a.get_snapshot().state=="dead","reattached state retained")
	a.free();b.free()
	var host = preload("res://demo/mission.tscn").instantiate();host.save_enabled=false;root.add_child(host)
	host.set_physics_process(false)
	check(host.hud.get_snapshot().state=="title","initial title snapshot without player")
	key(host,KEY_ENTER);check(host.state=="intro" and host.hud.get_snapshot().state=="intro","new mission enters intro")
	key(host,KEY_ENTER);check(host.state=="playing" and host.hud.get_snapshot().state=="playing","skip enters playing")
	key(host,KEY_ESCAPE);check(host.state=="paused" and host.hud.get_snapshot().state=="paused","pause snapshot updates while tree paused")
	key(host,KEY_ESCAPE);check(host.state=="playing" and host.hud.get_snapshot().state=="playing","resume snapshot")
	# Direct state fixtures below isolate presentation; they are not progression evidence.
	for state in ["archive","choice","dead","complete"]:
		host.state=state;host._process(0.0)
		check(host.hud.get_snapshot().state==state,"fixture modal "+state)
	host.state="playing";host.blind=true;host._process(0.0);host.body_echo._process(0.0)
	check(host.body_echo.enabled and host.body_echo.source_visual==host.player.get_node("Visual"),"echo explicit actual Visual binding")
	check(host.body_echo.get_node("View").get_pose()==host.player.get_node("Visual").get_pose(),"echo copies current real pose")
	var old_echo=host.body_echo
	host.blind=false;host._process(0.0);old_echo._process(0.0)
	check(not old_echo.get_node("View").visible,"echo disabled without changing actor")
	host.state="playing";host.blind=true;host._process(0.0);var removed_echo=old_echo.get_node("View");old_echo.remove_child(removed_echo);removed_echo.free();old_echo._process(0.0)
	check(host.state=="playing" and is_instance_valid(host.player),"missing echo view does not alter gameplay")
	# Removing UI cannot intercept mission input.
	host.hud.free();key(host,KEY_ESCAPE);check(host.state=="paused","input survives absent HUD")
	host.queue_free();await process_frame;paused=false
	var report={"checks":checks,"failures":failures,"scope":"Presentation lifecycle, explicit pose binding and genuine host-key transitions; modal state fixtures labelled separately."}
	FileAccess.open("res://simulation/evidence/hud_regression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("HUD CHECKS ",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
