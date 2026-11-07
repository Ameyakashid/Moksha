extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func map_state() -> Dictionary:
	var result := {}
	for action in InputMap.get_actions():
		result[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": InputMap.action_get_events(action).map(func(event):return event.get_instance_id())}
	return result
func settle() -> void: await process_frame; await process_frame
func run() -> void:
	preload("res://combat_pc/player.gd").ensure_default_inputs()
	var before := map_state()
	var bridge_script := preload("res://campaign/input/controller_bindings.gd")
	var gate := preload("res://campaign/logic/campaign_input_gate.gd").new()
	# Warm the script and runtime before measuring retained native Objects.
	var warm = bridge_script.new(); root.add_child(warm); warm.extend_frame(gate.sample_device()); warm.free(); await settle()
	var object_before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var resource_before := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var max_held := object_before
	var retained: Array[float] = []
	for cycle in 80:
		var bridge = bridge_script.new(); root.add_child(bridge)
		var sample_before := Performance.get_monitor(Performance.OBJECT_COUNT)
		for i in 1250: bridge.extend_frame(gate.sample_device())
		check(Performance.get_monitor(Performance.OBJECT_COUNT)==sample_before,"sampling retains no Objects cycle %d"%cycle)
		max_held=maxf(max_held,sample_before)
		bridge.free()
		check(map_state()==before,"full action map identity/deadzone restored cycle %d"%cycle)
		await settle()
		retained.append(Performance.get_monitor(Performance.OBJECT_COUNT))
	check(retained.all(func(count):return count == retained[0]),"retained Object count is constant across all 80 lifetimes")
	check(Performance.get_monitor(Performance.OBJECT_COUNT)<=object_before+1,"retained Object count bounded within one Object of warm baseline")
	check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resource_before,"all bridge InputEvent Resources released")
	print("MULTIPAD_SAMPLING_RESULT "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"samples":100000,"cycles":80,"objects_before":object_before,"objects_after":Performance.get_monitor(Performance.OBJECT_COUNT),"resources_before":resource_before,"resources_after":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"max_live_objects":max_held,"retained_counts":retained,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
