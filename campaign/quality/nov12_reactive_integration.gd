extends SceneTree
## Isolated host integration fixtures, not traversal or visual evidence.
var host:Node
var checks:=0
var failures:Array[String]=[]
var base:=""
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func key(code:int)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	host._unhandled_key_input(event)
func settle()->void:
	for i in 4:await process_frame
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--root="):base=arg.trim_prefix("--root=")
	if not valid_fixture_root(base,ProjectSettings.globalize_path("res://")) or DirAccess.dir_exists_absolute(base) or FileAccess.file_exists(base):
		push_error("Fresh external --root required");quit(2);return
	DirAccess.make_dir_recursive_absolute(base)
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false
	host.campaign_save_path=base.path_join("checkpoint.json")
	host.history_path=base.path_join("history")
	host.legacy_results_path=base.path_join("legacy.json")
	root.add_child(host);host.save_enabled=true
	key(KEY_ENTER);key(KEY_ENTER);await settle()
	check(host.session_generation==1,"Successful New increments exactly once")
	check(host.companion.observed_session==host.session_generation,"Observer adopts lifecycle identity")
	var first_id:String=host.run_id
	# Only chatter memory is explicitly seeded. No actor/goal/health progression edits.
	host.companion.director.seen.fixture=true
	key(KEY_ESCAPE);await settle()
	check(host.state=="paused" and not host.companion.mote.visible,"Pause suppresses cosmetic companion")
	key(KEY_ESCAPE);key(KEY_R);await settle()
	check(host.run_id==first_id and host.session_generation==1,"Retry retains durable and session identities")
	check(host.companion.director.seen.has("fixture"),"Retry retains delivered chatter memory")
	key(KEY_ESCAPE);key(KEY_N);key(KEY_C)
	check(host.session_generation==2,"Same-frame Title Continue increments exactly once")
	await settle()
	check(host.run_id==first_id and host.companion.director.seen.is_empty(),"Continue retains run identity and resets session chatter")
	host.companion.director.seen.fixture=true
	key(KEY_ESCAPE);key(KEY_N)
	var before_hash:=FileAccess.get_sha256(host.campaign_save_path)
	var blocked:String=host.campaign_save_path+".pending"
	DirAccess.make_dir_recursive_absolute(blocked)
	key(KEY_ENTER);await settle()
	check(host.run_id==first_id and host.session_generation==2,"Failed New does not advance either identity")
	check(host.companion.director.seen.has("fixture"),"Failed New does not consume old chatter memory")
	check(FileAccess.get_sha256(host.campaign_save_path)==before_hash,"Failed New retains previous resume bytes")
	check(not host._checkpoint_write_error.is_empty(),"Failed New remains visible to user")
	DirAccess.remove_absolute(blocked)
	key(KEY_ENTER);key(KEY_ENTER);await settle()
	check(host.session_generation==3 and host.run_id!=first_id,"Successful retry of New gets one new run/session identity")
	check(host.companion.director.seen.is_empty(),"Successful New resets chatter after durable commit")
	var before:Dictionary=host.hud.get_snapshot()
	check(not host.hud.set_snapshot({"state":"playing","last_result_available":"wrong","companion_line_id":"rain_relay"}),"History fields remain typed alongside companion fields")
	check(host.hud.get_snapshot()==before,"Invalid merged HUD snapshot leaves accepted view unchanged")
	check(not host.hud.set_snapshot({"state":"playing","last_result_available":true,"companion_line_id":9}),"Companion fields remain typed alongside history fields")
	print("REACTIVE_INTEGRATION_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Isolated lifecycle/HUD/chatter fixtures, not traversal or pixel proof"}))
	host.free();await process_frame;quit(0 if failures.is_empty() else 1)

static func valid_fixture_root(path:String,source_root:String)->bool:
	if source_root=="/":return false
	if path.is_empty() or not path.is_absolute_path() or path.begins_with("res://") or path.begins_with("user://") or path.simplify_path()!=path:return false
	var source:=source_root.simplify_path().trim_suffix("/")
	return source.is_empty() or (path!=source and not path.begins_with(source+"/"))
