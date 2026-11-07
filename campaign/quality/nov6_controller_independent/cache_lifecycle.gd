extends SceneTree
var checks:=0
var failures:Array=[]
var rows:Array=[]
var output:=""
var hz:=60
var gate=preload("res://campaign/logic/campaign_input_gate.gd").new()
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=" )
	Engine.physics_ticks_per_second=hz
	run.call_deferred()
func check(ok:bool,what:String,detail:Variant=null)->void:
	checks+=1
	if not ok:failures.append({"label":what,"detail":detail})
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func joy(device:int,down:bool)->void:
	var event:=InputEventJoypadButton.new();event.device=device;event.button_index=JOY_BUTTON_DPAD_RIGHT;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()
func axis(device:int,value:float)->void:
	var event:=InputEventJoypadMotion.new();event.device=device;event.axis=JOY_AXIS_LEFT_X;event.axis_value=value
	Input.parse_input_event(event);Input.flush_buffered_events()
func snapshot()->Dictionary:
	var result:Dictionary={}
	for action in InputMap.get_actions():
		result[action]={"deadzone":InputMap.action_get_deadzone(action),"events":InputMap.action_get_events(action).map(func(e):return e.get_instance_id())}
	return result
func run()->void:
	preload("res://combat_pc/player.gd").ensure_default_inputs()
	var native:Dictionary=snapshot()
	var script=load("res://campaign/input/controller_bindings.gd")
	var adapter:Node=script.new();root.add_child(adapter)
	for device in 100:joy(device,false)
	await frames(2)
	var remembered:Array=adapter._remembered_devices.duplicate()
	check(remembered.size()==64,"observed synthetic-device cache is bounded at64",remembered)
	check(remembered[0]==36 and remembered[-1]==99,"cache retains most recently observed integer IDs")
	check(remembered.all(func(value):return typeof(value)==TYPE_INT and value>=0),"cache owns only nonnegative integers")
	joy(77,false);await frames(1)
	check(adapter._remembered_devices.size()==64 and adapter._remembered_devices[-1]==77,"duplicate observations move one ID without growth")
	axis(77,0.9);joy(78,true);await frames(2)
	adapter.free()
	adapter=script.new();root.add_child(adapter)
	check(adapter._remembered_devices.size()==2 and adapter._remembered_devices.has(77) and adapter._remembered_devices.has(78),"exit prunes neutral IDs and keeps only two held devices",adapter._remembered_devices.duplicate())
	check(adapter._initial_devices.has(77) and adapter._initial_devices.has(78),"new lifetime observes held IDs without owning event resources")
	var raw:Dictionary=adapter.extend_frame(gate.sample_device())
	check(raw.right==1.0 and adapter._aliases.cp_right.initial_hold,"new alias exposes preheld raw state to the existing campaign gate",raw)
	axis(77,0);await frames(1)
	raw=adapter.extend_frame(gate.sample_device())
	check(raw.right==1.0,"one initial source release preserves the other")
	joy(78,false);await frames(2)
	raw=adapter.extend_frame(gate.sample_device())
	check(raw.right==0.0 and not adapter._aliases.cp_right.initial_hold,"all initial sources neutral rearms the alias")
	adapter.free();await frames(2)
	var resources_before:int=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for cycle in 10:
		adapter=script.new();root.add_child(adapter)
		check(adapter._remembered_devices.is_empty(),"neutral cache stays empty across lifetimes")
		for device in range(20,36):joy(device,false)
		for sample in 10000:adapter.extend_frame(gate.sample_device())
		adapter.free();await frames(2)
		rows.append({"cycle":cycle,"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT))})
		check(snapshot()==native,"complete InputMap names/identities/deadzones restored after each lifetime")
	check(rows[-1].resources==resources_before,"100000 samples over10 lifetimes add no native resources",{"before":resources_before,"after":rows[-1].resources})
	check(rows.all(func(row):return row.objects==rows[0].objects),"native Object count is flat across repeated lifetimes",rows)
	var result:Dictionary={"passed":failures.is_empty(),"hz":hz,"checks":checks,"failures":failures,"cycles":rows,"harness_sha256":FileAccess.get_sha256(get_script().resource_path),"scope":"Actual parsed synthetic joy events, bounded read-only integer cache, neutral-prune and resource-lifetime API contracts. Does not claim100 physical controllers or native hardware testing."}
	if not output.is_empty():FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CACHE_LIFECYCLE_RESULT "+JSON.stringify(result));quit(0 if failures.is_empty() else 1)
