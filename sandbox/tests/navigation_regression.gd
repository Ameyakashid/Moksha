extends SceneTree
var failures:Array=[]
func frames(n:int)->void:
	for i in n:await process_frame
func press(code:int)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event)
	await frames(3)
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event)
	await frames(2)
func _initialize()->void:run.call_deferred()
func run()->void:
	change_scene_to_file("res://sandbox/assembly.tscn");await frames(5)
	for pair in [[KEY_2,"CombatStation"],[KEY_3,"FreightStation"],[KEY_1,"TraversalStation"]]:
		await press(pair[0])
		if current_scene.name!=pair[1]:failures.append("key navigation "+pair[1])
	var old:int=current_scene.get_instance_id();await press(KEY_R)
	if current_scene.get_instance_id()==old:failures.append("R did not reload station")
	current_scene.get_node("Player").queue_free();await frames(3)
	if not current_scene.status.text.begins_with("Player module absent"):failures.append("removed player not tolerated")
	current_scene.get_node("Overlay").queue_free();await frames(3)
	if not is_instance_valid(current_scene):failures.append("removed overlay altered station")
	FileAccess.open("res://sandbox/evidence/navigation_regression.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"scope":"Actual physical key dispatch changes station scene and resets; missing player module tolerated"},"\t"))
	print("NAVIGATION failures=",failures);quit(0 if failures.is_empty() else 1)
