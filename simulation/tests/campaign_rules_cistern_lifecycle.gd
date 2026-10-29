extends "res://simulation/tests/campaign_rules_rainline_contract.gd"
## Labelled placements and enemy isolation, not traversal/boarding proof.
func quiet(m):
 for e in m.enemies:e.process_mode=Node.PROCESS_MODE_DISABLED
func lifts(m)->Array:
 var result:Array=[]
 for n in m.room.get_children():
  if n is AnimatableBody2D:result.append(n)
 return result
func place(m,p:Vector2):
 m.player.reset_actor(p,1);await frames(2)
func shutter_sweep(m)->bool:
 var transform:Transform2D=m.player.global_transform
 transform.origin=m.room.shutters[0].global_position+Vector2(-60,0)
 return m.player.test_move(transform,Vector2(120,0))
func run():
 label="Cistern isolated lifecycle"
 for traded in [false,true]:
  var m=load("res://demo/mission.tscn").instantiate();root.add_child(m);m.save_enabled=false;m.start_new(true);m.blind=traded;m.load_sector(4);m.input_override={};await frames(4)
  var d:Dictionary=m.sectors[4];var guards:int=m.enemies.size();var current_lifts=lifts(m)
  check(m._relay_points().size()==1 and m.room.shutters.size()==1,"one original relay and one associated shutter")
  check(current_lifts.size()==d.lifts.size() and current_lifts.size()==2,"authored two lift instances")
  check(shutter_sweep(m),"closed shutter blocks actual actor-shape sweep")
  await key(KEY_ESCAPE)
  var pc:Vector2=m.player.position;var clocks:Array=[];var positions:Array=[];var guard_positions:Array=[]
  for lift in current_lifts:clocks.append(lift.clock);positions.append(lift.position)
  for enemy in m.enemies:guard_positions.append(enemy.position)
  await frames(hz/3)
  check(m.state=="paused" and paused,"real Escape pauses")
  var frozen:bool=pc==m.player.position
  for i in current_lifts.size():frozen=frozen and clocks[i]==current_lifts[i].clock and positions[i]==current_lifts[i].position
  check(frozen,"pause freezes actor and both lift clocks/positions")
  var guard_frozen:=true
  for i in m.enemies.size():guard_frozen=guard_frozen and guard_positions[i]==m.enemies[i].position
  check(guard_frozen,"pause freezes live guards")
  await key(KEY_ESCAPE);await frames(hz/4)
  check(m.state=="playing" and not paused and current_lifts[0].clock>clocks[0] and current_lifts[1].clock>clocks[1],"resume restores both lift clocks")
  quiet(m)
  await place(m,Vector2(d.width-45,d.gate_y));await key(KEY_E)
  check(m.sector==4 and not m.room.gate_open,"single missing relay prevents onward despite gate placement")
  await place(m,d.cache);await key(KEY_E)
  check(m.state=="archive" and m.caches==[4] and m.room.cache_found,"real cache E collects exactly one archive")
  await key(KEY_E);await key(KEY_E)
  check(m.caches==[4] and m.state=="playing","repeat cache E does not duplicate archive")
  await place(m,d.relay);await key(KEY_E)
  check(m.relay_states==[0] and m.relay_on and m.room.gate_open,"actual relay E opens onward with living guards")
  check(m.remaining_enemies()==guards,"no all-kills gate added")
  check(m.room.shutters[0].is_open and m.room.shutters[0].collision_shape.disabled and not shutter_sweep(m),"relay removes actual shutter collision")
  await frames(hz)
  var old_player=weakref(m.player);var old_guard=weakref(m.enemies[0]);var old_lifts:Array=[]
  for lift in current_lifts:old_lifts.append(weakref(lift))
  var deaths:int=m.deaths;var speed:float=m.player.profile.run_speed
  await place(m,Vector2(1100,470));await frames(8)
  check(m.state=="dead" and paused and m.deaths==deaths+1,"real boundary hazard causes death and pause")
  await key(KEY_R);await frames(3);quiet(m)
  check(m.state=="playing" and not paused,"real R recovers from death")
  check(old_player.get_ref()==null and old_guard.get_ref()==null,"retry retires former actors")
  var retired:=true
  for ref in old_lifts:retired=retired and ref.get_ref()==null
  check(retired,"retry retires former lift identities")
  current_lifts=lifts(m);var fresh:=current_lifts.size()==2
  for i in current_lifts.size():fresh=fresh and current_lifts[i].clock<0.3 and current_lifts[i].origin==d.lifts[i][0] and current_lifts[i].travel==d.lifts[i][1]
  check(fresh,"retry reconstructs authored lift origins/travel with fresh clocks")
  check(m.remaining_enemies()==guards and m.enemies.size()==guards,"retry restores correct living roster")
  check(m.player.position.distance_to(Vector2(75,300))<5,"retry restores supported sector spawn")
  check(m.relay_states.is_empty() and not m.room.gate_open and not m.room.shutters[0].is_open and shutter_sweep(m),"retry restores missing-relay gate and physical shutter")
  check(m.blind==traded and is_equal_approx(speed,m.player.profile.run_speed),"retry preserves sight and production movement profile")
  check(m.caches==[4] and m.room.cache_found,"retry preserves one collected cache")
  m.save_enabled=true;m.show_title();await frames(2)
  var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(m.SAVE))
  check(saved.version==4 and saved.sector_id=="cistern" and saved.blind==traded and saved.cache_ids==["cistern"],"real checkpoint file records sector/sight/one cache")
  m.queue_free();await frames(3)
  m=load("res://demo/mission.tscn").instantiate();root.add_child(m);await frames(2)
  check(m.continue_available and m.state=="title","fresh mission offers saved checkpoint")
  await key(KEY_C);await frames(3);quiet(m)
  check(m.sector==4 and m.state=="playing" and not paused,"real C resumes Cistern in fresh host")
  check(m.blind==traded and is_equal_approx(speed,m.player.profile.run_speed) and m.caches==[4] and m.room.cache_found,"fresh-host Continue preserves sight/profile/cache exactly")
  check(m.relay_states.is_empty() and not m.room.gate_open and not m.room.shutters[0].is_open,"Continue starts correct closed per-sector objective")
  check(m.enemies.size()==guards and lifts(m).size()==2,"Continue reconstructs roster and lifts")
  m.queue_free();await frames(3)
 var hashes={}
 for path in ["res://demo/areas/cistern_journey.gd","res://demo/mission.gd","res://demo/mission_data.gd","res://demo/components/mission_lift.gd","res://simulation/tests/campaign_rules_cistern_lifecycle.gd"]:hashes[path]=FileAccess.get_sha256(path)
 var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"source_hashes":hashes,"scope":"Labelled initial position/sight fixtures; live guards for pause then disabled for interfaces. Actual E/Escape/R/C, real boundary death and fresh-host saved Continue. Actor-shape queries prove shutter collision only, not route or boarding. No lift clock/state setters. Isolated user storage."}
 FileAccess.open("res://simulation/evidence/campaign_rules_cistern_lifecycle_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("CISTERN LIFECYCLE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
