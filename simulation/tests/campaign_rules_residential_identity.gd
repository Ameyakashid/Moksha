extends SceneTree
const Codec=preload("res://demo/components/checkpoint_codec.gd")
const Identity=preload("res://demo/tests/campaign_identity.gd")
var failures:Array[String]=[]
var checks:=0
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
func run():
 var host=preload("res://demo/mission.tscn").instantiate();host.save_enabled=false;root.add_child(host)
 var areas=host.sectors
 check(Identity.ordered(areas),"exact actual nine-area order")
 check(areas.filter(func(a):return a.get("ending",false)).size()==1 and areas[-1].id=="above_the_rain","one ending remains last")
 var panel=host._hud_snapshot()
 check(panel.authored_area_count==8 and panel.ending_count==1,"host sends dynamic eight authored areas plus one finale")
 check(host.hud.get_snapshot().authored_area_count==8 and host.hud.get_snapshot().ending_count==1,"HUD schema retains count presentation inputs")
 check(not host.hud.set_snapshot({"authored_area_count":-1}),"HUD rejects negative presentation counts")
 var old_areas:Array=[]
 for id in Codec.V3_IDS:old_areas.append(areas[Identity.index(areas,id)])
 for index in 8:
  var caches:Array=[];var metrics:Array=[]
  for i in 8:caches.append(i);metrics.append({"sector":i,"seconds":20.0+i,"blind":true,"health":48.0})
  var old={"version":3,"sector":index,"caches":caches,"metrics":metrics,"blind":true,"kills":9,"deaths":2,"seconds":321.5}
  var prior_v4=Codec.encode(Codec.decode(old,old_areas),old_areas).data
  for source in [old,prior_v4]:
   var decoded=Codec.decode(JSON.parse_string(JSON.stringify(source)),areas)
   check(decoded.ok and areas[decoded.sector].id==Codec.V3_IDS[index],"old v3/v4 area identity survives real insertion")
   for i in 8:
    check(areas[decoded.caches[i]].id==Codec.V3_IDS[i],"old archive identity retained")
    check(areas[decoded.metrics[i].sector].id==Codec.V3_IDS[i] and decoded.metrics[i].seconds==20.0+i,"old history identity retained")
   check(not decoded.caches.has(Identity.index(areas,"upper_residential_crossing")),"old archive never silently assigned to new chapter")
   FileAccess.open(host.SAVE,FileAccess.WRITE).store_string(JSON.stringify(source))
   var bytes=FileAccess.get_file_as_string(host.SAVE)
   host.continue_run();await frames(2)
   check(host.sectors[host.sector].id==Codec.V3_IDS[index] and host.blind and host.caches.size()==8,"actual Continue loads correct old chapter/sight/archive set")
   check(FileAccess.get_file_as_string(host.SAVE)==bytes,"read-only Continue does not rewrite original checkpoint")
   host._pending_retry=true;await frames(3)
   check(host.sectors[host.sector].id==Codec.V3_IDS[index] and host.blind and host.caches==decoded.caches,"actual retry retains mapped area and archives")
   var roundtrip=Codec.decode(JSON.parse_string(JSON.stringify(Codec.encode(decoded,areas).data)),areas)
   check(roundtrip.ok and roundtrip.sector==decoded.sector and roundtrip.caches==decoded.caches and roundtrip.metrics==decoded.metrics,"v4 real-layout roundtrip preserves all identities")
 # Explicit initial positioning only, followed by ordinary proximity interaction.
 host.start_new(true);host.load_sector(Identity.index(areas,"upper_residential_crossing"));host.input_override={}
 var d=host.sectors[host.sector]
 check(d.has("cache"),"new chapter exposes authored cache")
 if d.has("cache"):
  host.player.reset_actor(d.cache,1)
  for enemy in host.enemies:enemy.process_mode=Node.PROCESS_MODE_DISABLED
  var key=InputEventKey.new();key.physical_keycode=KEY_E;key.pressed=true;host._unhandled_key_input(key)
  await frames(2)
  check(host.caches==[host.sector],"real E pickup collects only new chapter archive")
  host._pending_retry=true;await frames(3)
  check(host.caches==[host.sector] and str(host.sectors[host.sector].id)=="upper_residential_crossing","new archive persists through real retry")
  host.save_enabled=true;host._save_checkpoint();host.save_enabled=false
  var saved=JSON.parse_string(FileAccess.get_file_as_string(host.SAVE))
  check(saved.sector_id=="upper_residential_crossing" and saved.cache_ids==["upper_residential_crossing"],"new checkpoint serializes only new chapter identity")
  host.queue_free();paused=false;await frames(2)
  host=preload("res://demo/mission.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.continue_run();await frames(2)
  check(str(host.sectors[host.sector].id)=="upper_residential_crossing" and host.caches==[host.sector] and not host.blind,"fresh host Continue restores new chapter/cache and retained sight")
 host.queue_free();paused=false;await frames(2)
 var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Actual nine-area data; old v3 and previous v4 all8area/cache/history identity meanings; actual Continue/retry; new cache explicit setup then E pickup and fresh-host Continue. Not full route coverage."}
 FileAccess.open("res://simulation/evidence/residential_identity_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("RESIDENTIAL IDENTITY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
