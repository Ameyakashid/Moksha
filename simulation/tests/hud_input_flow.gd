extends SceneTree
## Actual engine-dispatched key events and event-loop UI updates (no manual host process calls).
var checks: Array = []
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func press(code: int) -> void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e)
	await process_frame;await process_frame
	e=InputEventKey.new();e.physical_keycode=code;e.pressed=false;Input.parse_input_event(e)
	await process_frame
func run() -> void:
	var host=preload("res://demo/mission.tscn").instantiate();host.save_enabled=false;root.add_child(host)
	await process_frame;await process_frame
	check(host.hud.get_snapshot().state=="title","title presented in normal loop")
	await press(KEY_ENTER)
	check(host.state=="intro" and host.hud.get_snapshot().state=="intro","dispatched new mission reaches intro")
	await press(KEY_ENTER)
	check(host.state=="playing" and host.hud.get_snapshot().state=="playing","dispatched skip reaches playing")
	await press(KEY_ESCAPE)
	check(paused and host.state=="paused" and host.hud.get_snapshot().state=="paused","paused tree presents pause in normal loop")
	await press(KEY_ESCAPE)
	check(not paused and host.state=="playing" and host.hud.get_snapshot().state=="playing","resume presents play in normal loop")
	host.hud.free()
	await press(KEY_ESCAPE)
	check(paused and host.state=="paused","dispatched input independent of removed HUD")
	host.queue_free();await process_frame;paused=false
	var report={"checks":checks,"failures":failures,"scope":"Actual Input.parse_input_event dispatch and normal event-loop updates; no manual host _process calls."}
	FileAccess.open("res://simulation/evidence/hud_input_flow.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("HUD INPUT FLOW ",checks.size()," failures=",failures.size());quit(0 if failures.is_empty() else 1)
