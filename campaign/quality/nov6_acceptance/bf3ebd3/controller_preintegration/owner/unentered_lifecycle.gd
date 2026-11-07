extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func run() -> void:
	var packed = load("res://campaign/campaign.tscn")
	var initial := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 100:
		var host = packed.instantiate()
		check(host.gamepad_navigation == null and host._controller_bindings == null,"no eager input Nodes %d"%i)
		check(host._hud_snapshot().input_device == "keyboard","pre-ready HUD keyboard fallback %d"%i)
		check(host._raw_campaign_input() is Dictionary,"pre-ready raw sample fallback %d"%i)
		host.free()
		check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)==initial,"unentered campaign leaves no orphan %d"%i)
	var live = packed.instantiate();live.save_enabled=false;root.add_child(live)
	check(live.gamepad_navigation.get_parent()==live and live._controller_bindings.get_parent()==live,"both live adapters owned by host")
	check(live.hud.get_node("View").data.input_device=="keyboard","first HUD snapshot has bound navigation")
	live.free()
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)==initial,"entered campaign leaves no orphan")
	print("MULTIPAD_UNENTERED_RESULT "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"orphan_before":initial,"orphan_after":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
