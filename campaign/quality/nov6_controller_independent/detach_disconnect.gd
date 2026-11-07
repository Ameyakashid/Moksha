extends SceneTree
var rows:Array=[]
func _initialize()->void:run.call_deferred()
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func run()->void:
	for baseline in [true,false]:
		var host:Node=load("res://campaign/quality/independent_multipad/baseline_campaign.gd").new() if baseline else load("res://campaign/campaign.tscn").instantiate()
		host.save_enabled=false;root.add_child(host);host.start_new(true);await frames(2)
		var e:=InputEventJoypadButton.new();e.device=1;e.button_index=JOY_BUTTON_DPAD_RIGHT;e.pressed=true;Input.parse_input_event(e);Input.flush_buffered_events();await frames(2)
		var row:Dictionary={"baseline":baseline,"start_state":host.state,"active":host.gamepad_navigation.active_controller}
		root.remove_child(host)
		Input.joy_connection_changed.emit(3,false)
		row.unrelated_state=host.state
		Input.joy_connection_changed.emit(1,false)
		row.detached_state=host.state;row.tree_paused=paused;row.focus_pause=host._focus_pause_active
		e.pressed=false;Input.parse_input_event(e);Input.flush_buffered_events()
		root.add_child(host);await frames(2)
		row.readded_state=host.state;row.readded_tree_paused=paused
		rows.append(row);host.free();paused=false;await frames(2)
	print("DETACH_DISCONNECT "+JSON.stringify(rows));quit()
