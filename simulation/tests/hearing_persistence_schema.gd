extends SceneTree
## Pure v3/schema2 boundary tests. No host, disk migration, or gameplay claims.
const Codec=preload("res://campaign/logic/checkpoint_codec.gd")
const Record=preload("res://campaign/state/completion_record.gd")
const Store=preload("res://campaign/save/checkpoint_store.gd")
const History=preload("res://campaign/save/run_history_store.gd")
const Senses=preload("res://campaign/state/sense_state.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label)
func fixture(version:int,blind:=false)->Dictionary:
 var raw={"campaign_version":version,"lens":"neutral","upgrades":[],"rewards":{},"level_seconds":{"1":3.5},"level_receipts":[{"level":1,"active_seconds":3.5,"custom":{"legacy":[1,"untouched"]}}],"progress":{"version":4,"sector_id":"room","cache_ids":[],"metrics":[{"area_id":"room","seconds":1.0,"metadata":{"legacy":[1,2]}}],"blind":blind,"seconds":3.5,"kills":0,"deaths":0}}
 if version>=2:raw.merge({"run_id":"0123456789abcdef0123456789abcdef","run_status":"active","run_origin":"legacy_resume"})
 if version>=3:raw.senses=Senses.create(blind,false)
 return raw
func completion(schema:int)->Dictionary:
 var snapshot=fixture(2 if schema==1 else 3)
 snapshot.run_status="completed"
 var result={"active_seconds":3.5,"lens":"neutral","deaths":0,"kills":0,"upgrades":[],"levels":snapshot.level_receipts.duplicate(true),"districts":snapshot.progress.metrics.duplicate(true)}
 if schema==2:result.senses=snapshot.senses.duplicate(true)
 return {"schema_version":schema,"run_id":snapshot.run_id,"ending":"public_record","completed_at":1.0,"origin":"legacy_resume","snapshot":snapshot,"result":result}
func _initialize():
 var areas=[{"id":"room"}]
 for version in [1,2,3]:
  for blind in [false,true]:
   var raw=fixture(version,blind);var bytes=JSON.stringify(raw)
   var decoded=Codec.decode(raw,areas)
   check(decoded.ok,"valid envelope v%d sight %s"%[version,blind])
   check(JSON.stringify(raw)==bytes,"decode never mutates caller")
   check(decoded.campaign==raw,"raw envelope and old metric prefixes preserved")
   check(Codec.decode(JSON.parse_string(bytes),areas).ok,"JSON roundtrip")
   decoded.campaign.progress.metrics[0].metadata.legacy.append(99)
   decoded.metrics[0].metadata.legacy.append(98)
   decoded.campaign.level_receipts[0].custom.legacy.append(97)
   check(JSON.stringify(raw)==bytes,"decoded dictionaries deeply detached")
 for version in [2,3]:
  for field in ["run_id","run_status","run_origin"]:
   var raw=fixture(version);raw.erase(field)
   check(not Codec.decode(raw,areas).ok,"v2+ identity field required")
 for version in [null,"3",true,0,1.5,4]:
  var raw=fixture(3);raw.campaign_version=version
  check(not Codec.decode(raw,areas).ok,"invalid envelope version")
 var invalid_senses=[null,{},[],{"version":1,"sight":"retained","hearing":"missing"},{"version":2,"sight":"retained","hearing":"traded"},{"version":true,"sight":"retained","hearing":"traded"},{"version":1.5,"sight":"retained","hearing":"traded"},{"version":1,"sight":"traded","hearing":"traded"},{"version":1,"sight":"retained","hearing":"traded","cache":1}]
 for sense in invalid_senses:
  var raw=fixture(3);raw.senses=sense;var before=JSON.stringify(raw)
  check(not Codec.decode(raw,areas).ok,"malformed/inconsistent sensory state rejected")
  check(JSON.stringify(raw)==before,"failed validation does not mutate")
 var missing=fixture(3);missing.erase("senses")
 check(not Codec.decode(missing,areas).ok,"v3 requires senses")
 for version in [1,2]:
  var legacy=fixture(version)
  check(not Codec.decode(legacy,areas).campaign.has("senses"),"legacy decoding does not invent new fields")
 for version in [1,2]:
  var downgraded=fixture(version);downgraded.senses=Senses.create(false,false)
  check(not Codec.decode(downgraded,areas).ok,"reserved senses require v3, never silently restore hearing")
 for field in ["result","snapshot"]:
  var downgraded=completion(1);downgraded[field].senses=Senses.create(false,false)
  check(not Record.valid(downgraded),"reserved completion senses require schema2")
 for schema in [1,2]:
  var record=completion(schema);var before=JSON.stringify(record)
  check(Record.valid(record),"valid completion schema%d"%schema)
  check(Record.valid(JSON.parse_string(before)),"completion JSON roundtrip")
  check(JSON.stringify(record)==before,"completion validation preserves bytes/old prefix")
  check(Record.canonical(record)==Record.canonical(JSON.parse_string(before)),"canonical roundtrip")
  var crossed=record.duplicate(true);crossed.snapshot.campaign_version=3 if schema==1 else 2
  check(not Record.valid(crossed),"schema and snapshot version cannot cross")
 var record=completion(2)
 for field in ["result","snapshot"]:
  for sense in invalid_senses:
   var bad=record.duplicate(true);bad[field].senses=sense
   check(not Record.valid(bad),"schema2 refuses malformed senses in "+field)
  var bad=record.duplicate(true);bad[field].erase("senses")
  check(not Record.valid(bad),"schema2 requires senses in "+field)
 var mismatched=record.duplicate(true);mismatched.result.senses.hearing="retained"
 check(not Record.valid(mismatched),"result must match snapshot sensory facts")
 var dual=completion(2);dual.snapshot.progress.blind=true;dual.snapshot.senses=Senses.create(true,false);dual.result.senses=dual.snapshot.senses.duplicate(true)
 check(Record.valid(dual),"dual loss is representable, not silently restored")
 for version in [null,"2",true,0,1.5,3]:
  var bad=record.duplicate(true);bad.schema_version=version
  check(not Record.valid(bad),"invalid completion schema")
 # Existing disk boundaries retain exact old bytes through failed replacement.
 var path="user://schema-test.json"
 var old_bytes=JSON.stringify(fixture(2),"  ")+"\n"
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(old_bytes);file.close()
 var preserved=History.preserve_file("user://schema-history",path,"v2")
 check(preserved.ok and FileAccess.get_file_as_string(preserved.path)==old_bytes,"v2 backup byte exact")
 DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path+".pending"))
 check(not Store.commit(path,fixture(3)).ok,"blocked replacement fails")
 check(FileAccess.get_file_as_string(path)==old_bytes,"failed v3 commit retains original bytes")
 check(Store.read(path,areas).ok,"v2 checkpoint remains readable after failure")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".pending"))
 check(Store.commit(path,fixture(3)).ok and Store.read(path,areas).ok,"v3 checkpoint store roundtrip")
 for schema in [1,2]:
  var historic=completion(schema);var history_root="user://completion-%d"%schema
  var stored=History.put(history_root,historic)
  check(stored.ok,"store completion schema%d"%schema)
  var bytes=FileAccess.get_file_as_string(stored.path)
  check(History.get_record(history_root,historic.run_id).ok,"read completion schema%d"%schema)
  check(History.put(history_root,historic).get("already_committed",false),"idempotent same completion")
  var conflict=historic.duplicate(true);conflict.result.kills=99
  check(not History.put(history_root,conflict).ok,"conflicting completion refused")
  check(FileAccess.get_file_as_string(stored.path)==bytes,"immutable completion bytes unchanged")
 print(JSON.stringify({"suite":"hearing_persistence_schema","checks":checks,"failures":failures,"passed":failures.is_empty()}))
 quit(0 if failures.is_empty() else 1)
