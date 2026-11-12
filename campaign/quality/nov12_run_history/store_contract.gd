extends SceneTree
const Record=preload("res://campaign/state/completion_record.gd")
const Progress=preload("res://demo/components/checkpoint_codec.gd")
const Store=preload("res://campaign/save/run_history_store.gd")
var checks:=0
var failures:Array[String]=[]
var root_path:=""
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func fixture(id:="0123456789abcdef0123456789abcdef")->Dictionary:
	return {"schema_version":1,"run_id":id,"ending":"public_record","completed_at":123.0,
		"result":{"active_seconds":35.5,"lens":"neutral","upgrades":[],"deaths":0,"kills":2,
		"levels":[{"level":5,"active_seconds":5.0,"completed_district":"crown_final"}],
		"districts":[{"area_id":"crown_final","seconds":5.0,"blind":false,"health":60.0}]},
		"snapshot":{"campaign_version":2,"run_id":id,"run_status":"completed"}}
func write_text(path:String,text:String)->void:
	var file=FileAccess.open(path,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(text);file.close()
func _initialize()->void:call_deferred("run")
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--root="):root_path=arg.trim_prefix("--root=")
	if not root_path.begins_with("/tmp/") or DirAccess.dir_exists_absolute(root_path) or FileAccess.file_exists(root_path):
		push_error("Requires a fresh --root=/tmp/... directory");quit(2);return
	var r:=fixture()
	check(Record.valid(r),"Valid detached record")
	check(not Record.valid_id("../"+r.run_id),"Traversal identity rejected")
	check(not Store.get_record(root_path,"../x").ok,"Traversal cannot read")
	check(not Store.get_record(root_path,r.run_id).found,"Missing distinct from corrupt")
	check(not Store.latest(root_path).found,"Missing history distinct from corrupt")
	for key in ["schema_version","run_id","ending","completed_at","result","snapshot"]:
		var missing:=r.duplicate(true);missing.erase(key)
		check(not Record.valid(missing),"Required "+key)
	for value in [NAN,INF,-1.0,"1"]:
		var bad:=r.duplicate(true);bad.completed_at=value
		check(not Record.valid(bad),"Malformed time rejected")
	for value in ["UPPERCASE0123456789abcdef12345678","short","../0123456789abcdef0123456789abc"]:
		var bad:=r.duplicate(true);bad.run_id=value
		check(not Record.valid(bad),"Malformed identity rejected")
	for key in ["deaths","kills","active_seconds","levels","districts","upgrades","lens"]:
		var bad:=r.duplicate(true);bad.result[key]="invalid"
		check(not Record.valid(bad),"Malformed result "+key)
	var mismatch:=r.duplicate(true);mismatch.snapshot.run_id="ffffffffffffffffffffffffffffffff"
	check(not Record.valid(mismatch),"Snapshot identity must match")
	mismatch=r.duplicate(true);mismatch.snapshot.run_status="active"
	check(not Record.valid(mismatch),"Terminal record requires terminal snapshot")
	mismatch=r.duplicate(true);mismatch.extra=Vector2.ZERO
	check(not Record.valid(mismatch),"Non-JSON variant rejected")
	var cyclic:=r.duplicate(true);cyclic["cycle"]=cyclic
	check(not Record.valid(cyclic),"Cyclic input rejected before stringify")
	cyclic.erase("cycle")
	var wrong_version:=r.duplicate(true);wrong_version.snapshot.campaign_version=1
	check(not Record.valid(wrong_version),"Legacy checkpoint cannot masquerade as terminal v2")
	var fractional:=r.duplicate(true);fractional.result.deaths=0.5
	check(not Record.valid(fractional),"Fractional counter rejected")
	var encoded:=Progress.encode({"sector":0,"metrics":[{"sector":0,"seconds":2.0,"blind":false,"health":60.0}],"caches":[],"kills":1,"deaths":0,"seconds":2.0,"blind":false},[{"id":"fixture_final"}])
	check(encoded.ok,"Actual preserved progress encoder fixture")
	var actual:=r.duplicate(true);actual.snapshot["progress"]=encoded.data
	check(Record.valid(actual),"Actual encoded metric StringName keys accepted")
	check(Record.valid(JSON.parse_string(Record.canonical(actual))),"Actual encoded metrics normalize and round-trip")
	var object_key:=r.duplicate(true);object_key.snapshot[Vector2.ONE]="invalid"
	check(not Record.valid(object_key),"Vector/object-like dictionary key rejected")
	var numeric_key:=r.duplicate(true);numeric_key.snapshot[12]="invalid"
	check(not Record.valid(numeric_key),"Numeric dictionary key rejected")
	var name_value:=r.duplicate(true);name_value.snapshot["extra"]=&"not a JSON string value"
	check(not Record.valid(name_value),"StringName values still rejected")
	var first:=Store.put(root_path,r)
	check(first.ok and not first.already_committed,"First commit creates parents")
	var digest:=FileAccess.get_sha256(first.path)
	var retry:=Store.put(root_path,r)
	check(retry.ok and retry.already_committed,"Identical retry idempotent")
	check(FileAccess.get_sha256(first.path)==digest,"Retry unchanged bytes")
	var changed:=r.duplicate(true);changed.result.kills=3
	check(not Store.put(root_path,changed).ok,"Different result same ID rejected")
	check(FileAccess.get_sha256(first.path)==digest,"Collision original preserved")
	var loaded:=Store.get_record(root_path,r.run_id)
	check(loaded.ok and loaded.found and Record.canonical(loaded.record)==Record.canonical(r),"Read detached normalized record")
	loaded.record.result.kills=99
	check(Store.get_record(root_path,r.run_id).record.result.kills==2,"Returned copy cannot mutate disk")
	var other:=fixture("ffffffffffffffffffffffffffffffff")
	check(Store.put(root_path,other).ok,"Second independent record")
	check(Store.latest(root_path).record.run_id==other.run_id,"Timestamp tie deterministic by run ID")
	var older:=fixture("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");older.completed_at=122
	check(Store.put(root_path,older).ok and Store.latest(root_path).record.run_id==other.run_id,"Later time authoritative")
	var pending_record:=fixture("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
	var pending:String=root_path+"/completed/"+pending_record.run_id+".json.pending"
	write_text(pending,Record.canonical(pending_record))
	check(Store.put(root_path,pending_record).ok,"Interrupted pending identical bytes can finish")
	pending_record=fixture("cccccccccccccccccccccccccccccccc")
	pending=root_path+"/completed/"+pending_record.run_id+".json.pending"
	write_text(pending,"interrupted unknown bytes")
	check(not Store.put(root_path,pending_record).ok and FileAccess.get_file_as_string(pending)=="interrupted unknown bytes","Different pending data retained")
	check(not Store.get_record(root_path,pending_record.run_id).found,"Pending is not completion")
	var invalid_path:=root_path+"/completed/dddddddddddddddddddddddddddddddd.json"
	write_text(invalid_path,"{broken")
	var invalid:=Store.get_record(root_path,"dddddddddddddddddddddddddddddddd")
	check(not invalid.ok and invalid.found,"Corrupt distinct from missing")
	check(not Store.latest(root_path).ok,"Corrupt history surfaced, not skipped")
	check(not Store.put(root_path,fixture("dddddddddddddddddddddddddddddddd")).ok and FileAccess.get_file_as_string(invalid_path)=="{broken","Corrupt collision retained")
	var source:=root_path+"/legacy.json"
	write_text(source,"{ broken legacy raw bytes\n")
	var preserved:=Store.preserve_file(root_path,source,"legacy-results")
	check(preserved.ok and FileAccess.get_file_as_string(preserved.path)==FileAccess.get_file_as_string(source),"Malformed legacy bytes preserved exactly")
	check(Store.preserve_file(root_path,source,"legacy-results").ok,"Preserve retry idempotent")
	check(Store.preserve_file(root_path,root_path+"/absent","legacy-results").ok,"Absent legacy no-op")
	check(not Store.preserve_file(root_path,source,"../escape").ok,"Preserve traversal label rejected")
	write_text(preserved.path,"collision")
	check(not Store.preserve_file(root_path,source,"legacy-results").ok and FileAccess.get_file_as_string(preserved.path)=="collision","Preservation collision not overwritten")
	check(FileAccess.get_file_as_string(source)=="{ broken legacy raw bytes\n","All failures retain legacy source")
	var blocker:=root_path+"/blocked";write_text(blocker,"not a folder")
	check(not Store.put(blocker,r).ok,"File instead of history directory fails")
	check(not Store.preserve_file(blocker,source,"legacy-results").ok,"Failed preservation does not replace source")
	var directory_collision:=root_path+"/directory-collision"
	DirAccess.make_dir_recursive_absolute(directory_collision+"/completed/"+r.run_id+".json")
	check(not Store.put(directory_collision,r).ok,"Directory record destination rejected")
	var mismatch_root:=root_path+"/wrong-id"
	DirAccess.make_dir_recursive_absolute(mismatch_root+"/completed")
	write_text(mismatch_root+"/completed/"+r.run_id+".json",Record.canonical(other))
	check(not Store.get_record(mismatch_root,r.run_id).ok,"Filename identity mismatch rejected")
	var recovery:=root_path+"/recovery"
	DirAccess.make_dir_recursive_absolute(recovery+"/completed")
	var startup:=fixture("eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
	var startup_pending:=recovery+"/completed/"+str(startup.run_id)+".json.pending"
	write_text(startup_pending,Record.canonical(startup))
	var resumed:=Store.reconcile(recovery,startup.run_id)
	check(resumed.ok and resumed.found and Record.canonical(resumed.record)==Record.canonical(startup),"Startup promotes valid pending before resume")
	check(Store.reconcile(recovery,startup.run_id).ok,"Startup final record remains idempotent")
	var corrupt_id:="11111111111111111111111111111111"
	var corrupt_pending:=recovery+"/completed/"+corrupt_id+".json.pending"
	write_text(corrupt_pending,"{broken terminal")
	var blocked:=Store.reconcile(recovery,corrupt_id)
	check(not blocked.ok and blocked.found,"Malformed pending cannot masquerade as active/missing")
	check(FileAccess.get_file_as_string(corrupt_pending)=="{broken terminal","Malformed pending bytes unchanged")
	check(not Store.reconcile(blocker,r.run_id).ok,"Root ancestor file blocks reconciliation")
	var completed_file:=root_path+"/completed-file"
	DirAccess.make_dir_recursive_absolute(completed_file)
	write_text(completed_file+"/completed","file")
	check(not Store.reconcile(completed_file,r.run_id).ok,"Completed ancestor file blocks reconciliation")
	check(Store.reconcile(recovery,"22222222222222222222222222222222").ok and not Store.reconcile(recovery,"22222222222222222222222222222222").found,"Missing final and pending remains active-compatible")
	var wrong_pending:=recovery+"/completed/33333333333333333333333333333333.json.pending"
	write_text(wrong_pending,Record.canonical(startup))
	check(not Store.reconcile(recovery,"33333333333333333333333333333333").ok,"Pending filename identity mismatch fails closed")
	check(FileAccess.get_file_as_string(wrong_pending)==Record.canonical(startup),"Mismatched pending preserved")
	print("RUN_HISTORY_STORE ",checks," checks; failures=",failures," fixture_root=",root_path)
	quit(0 if failures.is_empty() else 1)
