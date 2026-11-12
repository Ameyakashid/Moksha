extends SceneTree
var host:Node
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(v:bool,label:String)->void:
	if not v:failures.append(label)
func key(code:int)->void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=true;host._unhandled_key_input(e)
func settle()->void:
	for i in 4:await process_frame
func run()->void:
	host=load("res://campaign/campaign.tscn").instantiate();root.add_child(host)
	key(KEY_ENTER);key(KEY_ENTER);await settle()
	var generation:int=host.session_generation
	check(generation==1,"New increments")
	# Explicit chatter-memory fixture only; no actor/goal/progression/health edits.
	host.companion.director.seen.fixture=true
	key(KEY_ESCAPE);await settle();check(host.state=="paused" and not host.companion.mote.visible,"pause hides mote")
	key(KEY_ESCAPE);key(KEY_R);await settle()
	check(host.session_generation==generation and host.companion.director.seen.has("fixture"),"retry retains session chatter")
	key(KEY_ESCAPE);key(KEY_N);key(KEY_C);await settle()
	check(host.session_generation==generation+1 and host.companion.director.seen.is_empty(),"same-frame Title Continue clears chatter")
	host.companion.director.seen.fixture=true
	key(KEY_ESCAPE);key(KEY_N);key(KEY_ENTER);key(KEY_ENTER);await settle()
	check(host.session_generation==generation+2 and host.companion.director.seen.is_empty(),"same-frame Title New clears chatter")
	print("COMPANION_SESSION_RESULT ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"method":"Real host and production checkpoint with ordinary menu keys; explicit chatter-only seen fixture, not traversal proof."}))
	host.free();await process_frame;quit(0 if failures.is_empty() else 1)
