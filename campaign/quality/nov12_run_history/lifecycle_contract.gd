extends SceneTree
## Explicit seeded lifecycle fixtures, not gameplay/completion-route evidence.
const Host=preload("res://campaign/campaign.tscn")
const Store=preload("res://campaign/save/checkpoint_store.gd")
const History=preload("res://campaign/save/run_history_store.gd")
var checks:=0
var failures:Array=[]
var base:=""
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func host_at(label:String,save:=true,read_on_ready:=false)->Node:
 var h=Host.instantiate();h.save_enabled=save if read_on_ready else false
 h.campaign_save_path=base.path_join(label+".json")
 h.history_path=base.path_join(label+"-history")
 h.legacy_results_path=base.path_join(label+"-legacy.json")
 root.add_child(h);h.save_enabled=save
 return h
func press(h:Node,key:int)->void:
 var event=InputEventKey.new();event.pressed=true;event.physical_keycode=key
 h._unhandled_key_input(event)
func final_fixture(h:Node)->void:
 h.load_sector(h.sectors.size()-1)
 h.campaign_ending="public_record"
 h.state="final_choice"
 var event=InputEventKey.new();event.pressed=true;event.physical_keycode=KEY_J
 h._unhandled_key_input(event)
func run()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--root="):base=arg.trim_prefix("--root=")
 if base.is_empty() or not base.is_absolute_path() or base.begins_with(ProjectSettings.globalize_path("res://")) or DirAccess.dir_exists_absolute(base) or FileAccess.file_exists(base):
  push_error("Fresh external --root required");quit(2);return
 DirAccess.make_dir_recursive_absolute(base)
 var h=host_at("roundtrip")
 h.start_new(true);var id:String=h.run_id
 check(id.length()==32 and h.run_status=="active","New owns durable identity")
 var raw=JSON.parse_string(FileAccess.get_file_as_string(h.campaign_save_path))
 check(raw.run_id==id and raw.campaign_version==2,"New checkpoint v2")
 h.load_sector(2);h.load_sector(2)
 check(h.run_id==id,"District retry preserves run identity")
 final_fixture(h)
 check(h.run_status=="completed" and h._completion_error.is_empty(),"First completion durable")
 if not h._completion_error.is_empty():
  print("COMPLETION_DIAGNOSTIC ",h._completion_error," record=",h.completion_record)
  h.free();await process_frame;quit(1);return
 var first=History.get_record(h.history_path,id)
 check(first.ok and first.found,"Immutable completion exists")
 var count:int=h.metrics.size();var receipt_count:int=h.level_receipts.size()
 var frozen:String=FileAccess.get_sha256(first.path)
 h.complete_run();h.retry_completion_save()
 check(h.metrics.size()==count and h.level_receipts.size()==receipt_count,"Repeated finalization does not append")
 check(FileAccess.get_sha256(first.path)==frozen,"Repeated completion bytes identical")
 var checkpoint_hash=FileAccess.get_sha256(h.campaign_save_path)
 h.show_title()
 check(h.state=="title" and not h.continue_available,"Completed Title is nonresumable")
 check(FileAccess.get_sha256(h.campaign_save_path)==checkpoint_hash,"Title does not rewrite completed checkpoint")
 press(h,KEY_C)
 check(h.state=="complete" and h._reviewing_result,"Continue completed opens read-only result")
 check(h.metrics.size()==count,"Result review appends nothing")
 h.free();await process_frame
 h=host_at("roundtrip");h._refresh_run_history()
 check(not h._valid_save() and not h.last_result.is_empty(),"Restart exposes result not replay")
 press(h,KEY_C);check(h.state=="complete" and not is_instance_valid(h.room),"Restart C reviews result without room load")
 h.show_title();h.start_new(true)
 check(h.run_id!=id and h.run_status=="active","New after completion uses distinct identity")
 check(FileAccess.get_sha256(first.path)==frozen,"New preserves completed record")
 var prior_id:String=h.run_id;var prior_sector:int=h.sector;var generation:int=h.session_generation
 var prior_hash=FileAccess.get_sha256(h.campaign_save_path)
 DirAccess.make_dir_recursive_absolute(h.campaign_save_path+".pending")
 h.start_new(true)
 check(h.run_id==prior_id and h.sector==prior_sector and h.session_generation==generation,"Failed New preserves live run")
 check(FileAccess.get_sha256(h.campaign_save_path)==prior_hash and not h._checkpoint_write_error.is_empty(),"Failed New preserves resume and surfaces error")
 DirAccess.remove_absolute(h.campaign_save_path+".pending")
 final_fixture(h)
 h.free();await process_frame
 h=host_at("roundtrip")
 check(not h._valid_save() and not h.last_result.is_empty(),"Direct close from completion also terminal")
 h.free();await process_frame
 # Record durable, completed checkpoint blocked: startup must reconcile active file.
 h=host_at("interrupted");h.start_new(true);id=h.run_id
 DirAccess.make_dir_recursive_absolute(h.campaign_save_path+".pending")
 final_fixture(h)
 check(not h._completion_error.is_empty(),"Second-step checkpoint failure visible")
 check(History.get_record(h.history_path,id).found,"Record committed before checkpoint")
 count=h.metrics.size();h.complete_run();check(h.metrics.size()==count,"Failed retry never appends final metric")
 h.free();await process_frame
 h=host_at("interrupted")
 check(not h._valid_save() and not h.last_result.is_empty(),"Crash after record before checkpoint cannot replay")
 h.continue_run();check(h._reviewing_result,"Interrupted commit reviews result")
 h.free();await process_frame
 # Fully flushed pending record after process interruption is terminal too.
 h=host_at("pending-recovery");h.start_new(true);id=h.run_id
 var active=JSON.parse_string(FileAccess.get_file_as_string(h.campaign_save_path))
 final_fixture(h)
 var record_path:String=History.get_record(h.history_path,id).path
 Store.commit(h.campaign_save_path,active)
 DirAccess.rename_absolute(record_path,record_path+".pending")
 h.free();await process_frame
 h=host_at("pending-recovery")
 check(not h._valid_save() and FileAccess.file_exists(record_path),"Startup promotes valid pending record before resume")
 h.free();await process_frame
 h=host_at("corrupt-pending");h.start_new(true);id=h.run_id
 var pending_path:String=h.history_path.path_join("completed").path_join(id+".json.pending")
 DirAccess.make_dir_recursive_absolute(pending_path.get_base_dir())
 var broken=FileAccess.open(pending_path,FileAccess.WRITE);broken.store_string("{partial");broken.close()
 var broken_hash=FileAccess.get_sha256(pending_path)
 check(not h._valid_save() and not h._checkpoint_error.is_empty(),"Corrupt pending completion prevents ambiguous replay")
 check(FileAccess.get_sha256(pending_path)==broken_hash,"Corrupt pending evidence retained")
 h.free();await process_frame
 # First-step failure retains frozen in-memory completion for an explicit retry.
 h=host_at("failed-history");h.start_new(true)
 var good_root:String=h.history_path
 var occupied=FileAccess.open(good_root,FileAccess.WRITE);occupied.store_string("occupied");occupied.close()
 final_fixture(h);count=h.metrics.size()
 check(not h._completion_error.is_empty(),"History write failure visible")
 var failed_record:Dictionary=h.completion_record.duplicate(true)
 h.start_new(true)
 check(h.state=="complete" and h.completion_record==failed_record,"New cannot discard unsaved ending")
 h.history_path=good_root+"-recovered"
 press(h,KEY_ENTER)
 check(h._completion_error.is_empty() and h.metrics.size()==count,"Ending Enter retries same frozen result")
 h.free();await process_frame
 # Legacy repeated final receipts are preserved as factual prefix, not normalized.
 h=host_at("legacy");h.start_new(true)
 raw=JSON.parse_string(FileAccess.get_file_as_string(h.campaign_save_path))
 raw.campaign_version=1;raw.erase("run_id");raw.erase("run_status");raw.erase("run_origin")
 raw.level_receipts=[{"level":5,"active_seconds":7.0,"completed_district":h.sectors[-1].id},{"level":5,"active_seconds":9.0,"completed_district":h.sectors[-1].id}]
 raw.level_receipts[0].erase("completed_district")
 raw.progress.metrics=[{"area_id":h.sectors[-1].id,"seconds":7.0},{"area_id":h.sectors[-1].id,"seconds":2.0}]
 Store.commit(h.campaign_save_path,raw)
 var legacy_file=FileAccess.open(h.legacy_results_path,FileAccess.WRITE);legacy_file.store_string("{ legacy bytes even if malformed }");legacy_file.close()
 var legacy_hash=FileAccess.get_sha256(h.campaign_save_path);var result_hash=FileAccess.get_sha256(h.legacy_results_path)
 h.continue_run()
 check(h.run_origin=="legacy_resume","Legacy provenance explicit")
 check(h.level_receipts.size()==2 and h.metrics.size()==2,"Legacy duplicate prefix preserved")
 check(FileAccess.file_exists(h.history_path.path_join("preserved/legacy-checkpoint-"+legacy_hash+".json")),"Exact legacy checkpoint archived")
 check(FileAccess.get_sha256(h.legacy_results_path)==result_hash,"Legacy result never overwritten or associated")
 check(h.last_result.is_empty(),"Legacy result not promoted to active run completion")
 check(JSON.parse_string(FileAccess.get_file_as_string(h.campaign_save_path)).campaign_version==2,"Legacy resume migrates explicitly")
 # Missing district identity was explicitly valid in v1; completion preserves it.
 var prefix:Dictionary=h.level_receipts[0].duplicate(true)
 final_fixture(h)
 check(h._completion_error.is_empty(),"Legacy receipt without district remains completable")
 check(h.completion_record.result.levels[0]==prefix,"Legacy missing identity preserved without invention")
 check(h._validated_terminal(h.completion_record),"Legacy completion passes full boundary validation")
 h.free();await process_frame
 h=host_at("history-boundary");h.start_new(true);final_fixture(h)
 var valid:Dictionary=h.completion_record.duplicate(true)
 check(h._validated_terminal(valid),"Valid terminal boundary accepted")
 var malformed:Dictionary=valid.duplicate(true);malformed.snapshot.erase("progress")
 check(not h._validated_terminal(malformed),"Minimal snapshot rejected by full content boundary")
 for field in ["active_seconds","levels","districts","lens","upgrades","deaths","kills"]:
  var changed:Dictionary=valid.duplicate(true)
  match field:
   "active_seconds","deaths","kills":changed.result[field]+=1
   "levels","districts":changed.result[field]=[]
   "lens":changed.result[field]="agility"
   "upgrades":changed.result[field]=["force"]
  check(not h._validated_terminal(changed),"Duplicated result mismatch rejected: "+field)
 malformed=valid.duplicate(true);malformed.snapshot.progress.sector_id="foreign-area"
 check(not h._validated_terminal(malformed),"Foreign snapshot content rejected")
 malformed=valid.duplicate(true);malformed.origin="legacy_resume"
 check(not h._validated_terminal(malformed),"Origin mismatch rejected")
 h.last_result=malformed;h.state="title";h.view_last_result()
 check(h.state=="title" and h.last_result.is_empty(),"Direct review fails closed")
 # Store remains envelope-only; host must reject malformed stored snapshot.
 var other:Dictionary=valid.duplicate(true)
 other.run_id="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";other.snapshot.run_id=other.run_id
 other.completed_at=valid.completed_at+10000
 check(History.put(h.history_path,other).ok,"Future timestamp fixture stored")
 h._refresh_run_history()
 check(h.last_result.run_id==valid.run_id,"Just-completed run wins clock rollback")
 h.completion_record.clear()
 malformed=other.duplicate(true);malformed.run_id="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";malformed.snapshot.run_id=malformed.run_id
 malformed.completed_at=other.completed_at+10000;malformed.snapshot.erase("progress")
 check(History.put(h.history_path,malformed).ok,"Envelope-only malformed snapshot stored for boundary test")
 h._refresh_run_history()
 check(h.last_result.is_empty() and not h._history_error.is_empty(),"Latest invalid history never exposed as completion")
 check(FileAccess.file_exists(h.history_path.path_join("completed/"+malformed.run_id+".json")),"Invalid history bytes retained")
 var bad_checkpoint:Dictionary=valid.snapshot.duplicate(true);bad_checkpoint.run_id=malformed.run_id
 Store.commit(h.campaign_save_path,bad_checkpoint)
 check(not h._valid_save() and not h._checkpoint_error.is_empty(),"Malformed terminal cannot reconcile Continue")
 check(h.last_result.is_empty(),"Failed reconciliation exposes no result")
 h.free();await process_frame
 # Every JSON-shaped optional receipt value accepted by v1 remains factual.
 for optional_value in [null,"",42,{"old":"metadata"},["old"]]:
  h=host_at("legacy-value-"+str(checks));h.start_new(true)
  raw=JSON.parse_string(FileAccess.get_file_as_string(h.campaign_save_path))
  raw.campaign_version=1;raw.erase("run_id");raw.erase("run_status");raw.erase("run_origin")
  raw.level_receipts=[{"level":1,"active_seconds":3,"completed_district":optional_value}]
  var legacy_prefix:Dictionary=raw.level_receipts[0].duplicate(true)
  check(Store.commit(h.campaign_save_path,raw).ok,"Legacy optional value fixture saved")
  h.continue_run();final_fixture(h)
  check(h._completion_error.is_empty() and h._validated_terminal(h.completion_record),"Legacy optional value remains completable")
  check(JSON.stringify(h.completion_record.result.levels[0],"",true,true)==JSON.stringify(JSON.parse_string(JSON.stringify(legacy_prefix)),"",true,true),"Legacy optional value remains exact")
  var strict:Dictionary=h.completion_record.duplicate(true)
  strict.origin="new";strict.snapshot.run_origin="new"
  check(not h._validated_terminal(strict),"New origin rejects malformed historical receipt identity")
  h.free();await process_frame
 h=host_at("terminal-proof");h.start_new(true);final_fixture(h)
 valid=h.completion_record.duplicate(true)
 check(h._validated_terminal(valid),"Authored final suffix accepted")
 malformed=valid.duplicate(true);malformed.snapshot.progress.sector_id=h.sectors[0].id
 check(not h._validated_terminal(malformed),"Initial district tagged completed rejected")
 for remove_kind in ["receipts","metrics","receipt_id","receipt_level","metric_id"]:
  malformed=valid.duplicate(true)
  match remove_kind:
   "receipts":malformed.snapshot.level_receipts=[]
   "metrics":malformed.snapshot.progress.metrics=[]
   "receipt_id":malformed.snapshot.level_receipts[-1].completed_district=h.sectors[0].id
   "receipt_level":malformed.snapshot.level_receipts[-1].level=1
   "metric_id":malformed.snapshot.progress.metrics[-1].area_id=h.sectors[0].id
  malformed.result.levels=malformed.snapshot.level_receipts.duplicate(true)
  malformed.result.districts=malformed.snapshot.progress.metrics.duplicate(true)
  check(not h._validated_terminal(malformed),"Missing final proof rejected: "+remove_kind)
 h.free();await process_frame
 # Fresh _ready must prefer checkpoint-owned terminal over a future-dated older record.
 h=host_at("startup-clock");h.start_new(true);final_fixture(h)
 var current_record:Dictionary=h.completion_record.duplicate(true)
 var current_path:String=History.get_record(h.history_path,h.run_id).path
 var current_hash:=FileAccess.get_sha256(current_path)
 var terminal_hash:=FileAccess.get_sha256(h.campaign_save_path)
 var older:Dictionary=current_record.duplicate(true)
 older.run_id="cccccccccccccccccccccccccccccccc";older.snapshot.run_id=older.run_id
 older.completed_at=current_record.completed_at+86400
 check(History.put(h.history_path,older).ok,"Later-timestamp historical fixture stored")
 var older_path:String=History.get_record(h.history_path,older.run_id).path
 var older_hash:=FileAccess.get_sha256(older_path)
 h.free();await process_frame
 h=host_at("startup-clock",true,true)
 check(h.last_result.get("run_id")==current_record.run_id and not h.continue_available,"Fresh ready prefers current terminal checkpoint under clock rollback")
 check(not is_instance_valid(h.room) and h.session_generation==0,"Fresh terminal Title loads no room or session")
 press(h,KEY_C)
 check(h._reviewing_result and h.last_result.get("run_id")==current_record.run_id and not is_instance_valid(h.room) and h.session_generation==0,"Initial C reviews checkpoint-owned result without replay")
 check(FileAccess.get_sha256(h.campaign_save_path)==terminal_hash and FileAccess.get_sha256(current_path)==current_hash and FileAccess.get_sha256(older_path)==older_hash,"Ready and initial C preserve checkpoint and both immutable records")
 h.free();await process_frame
 h=host_at("startup-clock",false,true)
 check(h.last_result.is_empty() and not h.continue_available and not h._valid_save(),"No-save ready does not discover existing checkpoint or history")
 check(FileAccess.get_sha256(h.campaign_save_path)==terminal_hash and FileAccess.get_sha256(current_path)==current_hash,"No-save ready leaves existing bytes unchanged")
 h.free();await process_frame
 h=host_at("nosave",false);h.start_new(true);final_fixture(h);h.show_title()
 check(not FileAccess.file_exists(h.campaign_save_path) and not DirAccess.dir_exists_absolute(h.history_path),"No-save fixtures write nothing")
 h.free();await process_frame
 print("RUN_LIFECYCLE ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
