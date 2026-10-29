extends SceneTree
const Codec=preload("res://demo/components/checkpoint_codec.gd")
const Data=preload("res://demo/mission_data.gd")
var checks:=0
var failures:Array[String]=[]
var hz:=60
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label)
func frames(n:int):
 for i in n:await physics_frame;await process_frame
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
 Engine.physics_ticks_per_second=hz
 run.call_deferred()
func fixture(index:int)->Dictionary:
 var cache:Array=[];var rows:Array=[]
 for i in 8:
  cache.append(i);rows.append({"sector":i,"seconds":20.0+i,"blind":i>=2,"health":48.0})
 return {"version":3,"sector":index,"caches":cache,"metrics":rows,"blind":true,"kills":9,"deaths":2,"seconds":321.5}
func write_save(data:Variant,path:String):FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data))
func run():
 var live=Data.sectors()
 var original:Array[Dictionary]=[]
 for id in Codec.V3_IDS:
  original.append(live.filter(func(area):return str(area.get("id",""))==id)[0])
 check(Codec.layout(original).ok,"historical eight identities remain available for immutable v3 insertion matrix")
 for index in 8:
  var old=fixture(index)
  FileAccess.open("res://simulation/evidence/checkpoint_v3_%d.json"%index,FileAccess.WRITE).store_string(JSON.stringify(old,"\t"))
  for insertion in 9:
   var areas=original.duplicate(true);areas.insert(insertion,{"id":"test_residential"})
   var decoded=Codec.decode(JSON.parse_string(JSON.stringify(old)),areas)
   check(decoded.ok,"v3 decodes every old index across every insertion position")
   if not decoded.ok:continue
   check(areas[decoded.sector].id==Codec.V3_IDS[index],"v3 current area meaning retained")
   for i in 8:
    check(areas[decoded.caches[i]].id==Codec.V3_IDS[i],"v3 cache meaning retained including later and ending positions")
    check(areas[decoded.metrics[i].sector].id==Codec.V3_IDS[i] and decoded.metrics[i].seconds==20.0+i,"v3 history meaning retained")
   check(decoded.blind and decoded.kills==9 and decoded.deaths==2 and decoded.seconds==321.5,"scalar progress retained")
   var encoded=Codec.encode(decoded,areas);var roundtrip=Codec.decode(JSON.parse_string(JSON.stringify(encoded.data)),areas)
   check(encoded.ok and roundtrip.ok and roundtrip.sector==decoded.sector and roundtrip.caches==decoded.caches and roundtrip.metrics==decoded.metrics,"v4 serialized roundtrip preserves migration")
 # Version4 identity resolves arbitrary reordering, not just one insertion index.
 var encoded=Codec.encode(Codec.decode(fixture(6),original),original)
 var reversed=original.duplicate(true);reversed.reverse()
 var reordered=Codec.decode(encoded.data,reversed)
 check(reordered.ok and reversed[reordered.sector].id=="lift_warden","v4 identity survives reordered campaign")
 var bad_layout=original.duplicate(true);bad_layout[0].erase("id")
 check(not Codec.decode(fixture(0),bad_layout).ok,"missing current area ID refused")
 bad_layout=original.duplicate(true);bad_layout[1].id=bad_layout[0].id
 check(not Codec.decode(fixture(0),bad_layout).ok,"duplicate current area IDs refused")
 var bad:Array=[null,[],{"version":99},{"version":"3"},{"version":3,"sector":1.5},{"version":3,"sector":8},{"version":4,"sector_id":"unknown"},{"version":4,"sector_id":"rainline","cache_ids":["unknown"]},{"version":4,"sector_id":"rainline","cache_ids":["rainline","rainline"]},{"version":3,"sector":0,"blind":"yes"},{"version":3,"sector":0,"metrics":[{"sector":6,"seconds":-1}]},{"version":3,"sector":0,"kills":-1}]
 for value in bad:check(not Codec.decode(value,original).ok,"malformed/unknown checkpoint refused")
 # Real mission host: no failed-load mutation, byte-preservation, explicit title UX.
 var host=preload("res://demo/mission.tscn").instantiate();root.add_child(host);host.save_enabled=false
 for value in bad:
  write_save(value,host.SAVE);var previous_bytes=FileAccess.get_file_as_string(host.SAVE)
  host.continue_run()
  check(FileAccess.get_file_as_string(host.SAVE)==previous_bytes and host.state=="title", "every refused version/type leaves save and title untouched")
 var malformed="{not json";FileAccess.open(host.SAVE,FileAccess.WRITE).store_string(malformed)
 check(not host._valid_save(),"real host refuses malformed saved file")
 host.continue_run();check(host.state=="title" and not is_instance_valid(host.player),"failed Continue does not create or change mission")
 check(FileAccess.get_file_as_string(host.SAVE)==malformed,"failed Continue preserves exact original bytes")
 check(host._hud_snapshot().panel_override and host._hud_snapshot().panel_title=="CHECKPOINT UNAVAILABLE","explicit unavailable checkpoint UX offers New mission")
 # Synthetic insertion only in test host; all actual loaded areas are original assets.
 host.sectors=original.duplicate(true);var placeholder=original[0].duplicate(true);placeholder.id="test_residential";host.sectors.insert(5,placeholder)
 for index in 8:
  var old=fixture(index);write_save(old,host.SAVE);var bytes=FileAccess.get_file_as_string(host.SAVE)
  host.continue_run();await frames(2)
  check(host.sectors[host.sector].id==Codec.V3_IDS[index],"actual Continue maps old area, including ending")
  check(host.blind and host.caches.size()==8 and host.deaths==2,"actual Continue restores global progress")
  check(FileAccess.get_file_as_string(host.SAVE)==bytes,"successful load without checkpoint writing leaves v3 untouched")
  host._pending_retry=true;await frames(3)
  check(host.sectors[host.sector].id==Codec.V3_IDS[index] and host.blind and host.caches.size()==8,"retry retains mapped identity/sight/archives")
  for enemy in host.enemies:enemy.process_mode=Node.PROCESS_MODE_DISABLED
 # Normal checkpoint writes v4 atomically and keeps original v3 content-addressed copy.
 var old=fixture(7);write_save(old,host.SAVE);var old_sha=FileAccess.get_sha256(host.SAVE)
 host.save_enabled=true;host.continue_run();await frames(2)
 var saved=JSON.parse_string(FileAccess.get_file_as_string(host.SAVE))
 check(saved.version==4 and saved.sector_id=="above_the_rain","normal checkpoint after Continue writes v4 ending identity")
 var backup=host.SAVE+".preserved-"+old_sha+".json"
 check(FileAccess.file_exists(backup) and FileAccess.get_sha256(backup)==old_sha,"original v3 preserved byte-for-byte on migration")
 var current=host.sector;host.show_title();host.continue_run();await frames(2)
 check(host.sector==current and host.sectors[current].id=="above_the_rain" and host.blind,"v4 real title/Continue roundtrip returns to ending")
 # Explicit New mission can replace invalid active save only after preserving it.
 FileAccess.open(host.SAVE,FileAccess.WRITE).store_string(malformed);var bad_sha=FileAccess.get_sha256(host.SAVE)
 host.save_enabled=false;host.show_title();host.save_enabled=true # Explicit title transition without a normal checkpoint write.
 FileAccess.open(host.SAVE,FileAccess.WRITE).store_string(malformed);host._valid_save();host.start_new(true)
 check(FileAccess.file_exists(host.SAVE+".preserved-"+bad_sha+".json"),"explicit New mission preserves malformed original before replacement")
 check(JSON.parse_string(FileAccess.get_file_as_string(host.SAVE)).sector_id=="rainline","explicit New mission creates clean current checkpoint")
 # A fresh host resolves historical v4 IDs into the actual current layout.
 write_save(Codec.encode(Codec.decode(fixture(7),original),original).data,host.SAVE)
 host.save_enabled=false;host.queue_free();paused=false;await frames(2)
 host=preload("res://demo/mission.tscn").instantiate();root.add_child(host);host.save_enabled=false;host.continue_run();await frames(2)
 check(host.sectors[host.sector].id=="above_the_rain" and host.blind and host.caches.size()==8,"fresh host Continue resolves historical ending identity in current layout")
 # Failed write is non-destructive, including on an otherwise valid checkpoint.
 var valid_bytes=FileAccess.get_file_as_string(host.SAVE)
 DirAccess.make_dir_absolute(ProjectSettings.globalize_path(host.SAVE+".pending"))
 host.save_enabled=true;host._save_checkpoint()
 check(FileAccess.get_file_as_string(host.SAVE)==valid_bytes and not host._checkpoint_write_error.is_empty(),"failed temporary write leaves previous checkpoint byte-for-byte intact")
 host.state="title";paused=true;host.continue_available=host._valid_save()
 var write_panel=host._hud_snapshot()
 check(host.continue_available and write_panel.panel_title=="CHECKPOINT NOT UPDATED" and write_panel.panel_footer.contains("C  Continue previous checkpoint"),"failed save title accurately offers valid previous Continue")
 host.save_enabled=false
 var event=InputEventKey.new();event.physical_keycode=KEY_C;event.pressed=true;Input.parse_input_event(event);await frames(3)
 event=InputEventKey.new();event.physical_keycode=KEY_C;event.pressed=false;Input.parse_input_event(event)
 check(host.state=="playing" and host.sectors[host.sector].id=="above_the_rain" and host.blind,"real C after failed save continues preserved valid checkpoint")
 check(FileAccess.get_file_as_string(host.SAVE)==valid_bytes,"Continue after failed save preserves previous file when saving disabled")
 host.save_enabled=true
 var blocked_backup_bytes="invalid-backup-destination-fixture"
 FileAccess.open(host.SAVE,FileAccess.WRITE).store_string(blocked_backup_bytes)
 var blocked_backup=host.SAVE+".preserved-"+FileAccess.get_sha256(host.SAVE)+".json"
 DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocked_backup))
 host._save_checkpoint()
 check(FileAccess.get_file_as_string(host.SAVE)==blocked_backup_bytes and host._checkpoint_write_error=="Could not preserve the previous checkpoint.","failed backup prevents checkpoint commit and preserves original bytes")
 var corrupted_backup_bytes="invalid-existing-backup-fixture"
 FileAccess.open(host.SAVE,FileAccess.WRITE).store_string(corrupted_backup_bytes)
 var corrupted_backup=host.SAVE+".preserved-"+FileAccess.get_sha256(host.SAVE)+".json"
 FileAccess.open(corrupted_backup,FileAccess.WRITE).store_string("wrong preserved bytes")
 host._save_checkpoint()
 check(FileAccess.get_file_as_string(host.SAVE)==corrupted_backup_bytes and host._checkpoint_write_error=="Previous checkpoint preservation could not be verified.","unverified existing backup prevents destructive commit")
 host.save_enabled=false;host.queue_free();paused=false;await frames(2)
 var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Pure migration all8oldindices×9syntheticinsertpositions, alloldcache/history identities, malformed rejection, real host Continue/retry/newrun and filebackup/roundtrip. Synthetic extra dictionary only in test, no production chapter added."}
 FileAccess.open("res://simulation/evidence/checkpoint_rules_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("CHECKPOINT RULES ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
