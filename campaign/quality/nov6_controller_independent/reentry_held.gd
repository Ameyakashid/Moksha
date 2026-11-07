extends SceneTree
func _initialize()->void:run.call_deferred()
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func event(down:bool)->void:
	var e:=InputEventJoypadButton.new();e.device=1;e.button_index=JOY_BUTTON_DPAD_RIGHT;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func run()->void:
	preload("res://combat_pc/player.gd").ensure_default_inputs()
	var adapter:Node=load("res://campaign/input/controller_bindings.gd").new();root.add_child(adapter)
	var old:String=adapter._aliases.cp_right.name
	event(true);await frames(2)
	var before:float=Input.get_action_strength(old)
	root.remove_child(adapter)
	var removed:bool=not InputMap.has_action(old)
	event(false);await frames(2)
	root.add_child(adapter);await frames(2)
	var now:String=adapter._aliases.cp_right.name
	var after:float=Input.get_action_strength(now)
	print("REENTRY_HELD "+JSON.stringify({"before":before,"removed":removed,"same_name":old==now,"after_release_while_detached":after,"native_cp_right":Input.get_action_strength("cp_right")}))
	adapter.free();quit(0 if after==0 else 1)
