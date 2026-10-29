extends "res://simulation/tests/campaign_rules_rainline_contract.gd"
## Labelled placements/sight and enemy isolation; not traversal or migration proof.
func quiet(m):
 for e in m.enemies:e.process_mode=Node.PROCESS_MODE_DISABLED
func place(m,p:Vector2):
 m.player.reset_actor(p,1);await frames(2)
func index_of(m,id:String)->int:
 for i in m.sectors.size():
  if m.sectors[i].get("id","")==id:return i
 return -1
func topology(m)->Dictionary:
 var platforms:Array=[];var ladder_count:=0;var thresholds:=0
 for n in m.room.get_children():
  if n.get_script()==load("res://simulation/world/static_platform.gd"):
   platforms.append(n)
   if n.platform_size in [Vector2(160,110),Vector2(170,165),Vector2(150,180)] and not n.one_way_collision:thresholds+=1
  if n.get_script()==load("res://simulation/world/mission_ladder.gd"):ladder_count+=1
 return {"platforms":platforms,"thresholds":thresholds,"ladders":ladder_count}
func run():
 label="Residential isolated lifecycle"
 for traded in [false,true]:
  var m=load("res://demo/mission.tscn").instantiate();root.add_child(m);m.save_enabled=false;m.start_new(true);m.blind=traded
  var idx:=index_of(m,"upper_residential_crossing");m.load_sector(idx);m.input_override={};await frames(4)
  var d:Dictionary=m.sectors[idx];var guards:int=m.enemies.size();var original=topology(m)
  check(idx>=0 and guards==9,"stable-ID selected chapter has nine original guards")
  check(m._relay_points().is_empty() and not d.get("lock",false) and not d.has("freight"),"no relay, kill seal, or freight prerequisite")
  check(m.room.gate_open and m.remaining_enemies()==guards and m.caches.is_empty(),"onward open with all guards alive and optional cache skipped")
  check(original.thresholds==3 and original.ladders==6,"three actual solid thresholds and six ladder instances")
  await key(KEY_ESCAPE)
  var pc:Vector2=m.player.position;var positions:Array=[]
  for e in m.enemies:positions.append(e.position)
  await frames(hz/3)
  check(m.state=="paused" and paused and m.player.position==pc,"actual Escape freezes actor")
  var frozen:=true
  for i in guards:frozen=frozen and m.enemies[i].position==positions[i]
  check(frozen,"pause freezes live guards")
  await key(KEY_ESCAPE);await frames(3)
  check(m.state=="playing" and not paused,"actual Escape resumes play")
  quiet(m)
  await place(m,Vector2(d.width-145,d.gate_y));await key(KEY_E)
  check(m.sector==idx,"out-of-range E does not advance")
  await place(m,Vector2(d.width-45,d.gate_y));await key(KEY_E);await frames(3)
  check(m.sectors[m.sector].id=="relay_works" and m.state=="playing","actual nearby E enters Relay Works by identity")
  check(m.caches.is_empty(),"live-guard onward did not require or collect optional cache")
  m.load_sector(idx);await frames(3);quiet(m)
  await place(m,d.cache);await key(KEY_E)
  check(m.state=="archive" and m.caches==[idx] and m.room.cache_found,"real cache E collects exactly one optional archive")
  await key(KEY_E);await key(KEY_E)
  check(m.caches==[idx] and m.state=="playing","repeat E does not duplicate cache")
  var old_player=weakref(m.player);var old_guard=weakref(m.enemies[0]);var old_platform=weakref(topology(m).platforms[0]);var deaths:int=m.deaths;var speed:float=m.player.profile.run_speed
  await place(m,Vector2(1700,470));await frames(8)
  check(m.state=="dead" and paused and m.deaths==deaths+1,"actual boundary hazard causes death")
  await key(KEY_R);await frames(3);quiet(m)
  check(m.state=="playing" and not paused,"actual R resumes from death")
  check(old_player.get_ref()==null and old_guard.get_ref()==null and old_platform.get_ref()==null,"retry retires former actors and terrain")
  var fresh=topology(m)
  check(fresh.thresholds==3 and fresh.ladders==6 and fresh.platforms.size()==d.platforms.size(),"retry reconstructs authored thresholds, ladders, platforms")
  check(m.remaining_enemies()==guards and m.player.position.distance_to(Vector2(75,300))<5,"retry restores roster and supported spawn")
  check(m.room.gate_open and m._relay_points().is_empty(),"retry preserves zero-objective onward semantics")
  check(m.blind==traded and is_equal_approx(speed,m.player.profile.run_speed) and m.caches==[idx] and m.room.cache_found,"retry preserves sight, movement profile, unique cache")
  m.save_enabled=true;m.show_title();await frames(2)
  var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(m.SAVE))
  check(saved.version==4 and saved.sector_id=="upper_residential_crossing" and saved.cache_ids==["upper_residential_crossing"] and saved.blind==traded,"actual checkpoint records new stable ID and optional cache ID")
  m.queue_free();await frames(3)
 var hashes={}
 for path in ["res://demo/areas/upper_residential_crossing.gd","res://demo/mission.gd","res://demo/mission_data.gd","res://simulation/tests/campaign_rules_residential_lifecycle.gd"]:hashes[path]=FileAccess.get_sha256(path)
 var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"source_hashes":hashes,"scope":"Labelled initial placements/sight; live guards during pause, then disabled for interface isolation. Actual E/Escape/R, boundary hazard death, one serialized stable-ID observation. Not route, migration, Continue matrix, or human pacing evidence."}
 FileAccess.open("res://simulation/evidence/campaign_rules_residential_lifecycle_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("RESIDENTIAL LIFECYCLE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
