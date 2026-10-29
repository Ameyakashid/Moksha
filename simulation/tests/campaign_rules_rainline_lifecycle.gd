extends "res://simulation/tests/campaign_rules_rainline_contract.gd"
## Lifecycle-only initial placements; isolated user:// required by runner.
func quiet(mission):
 for enemy in mission.enemies:enemy.process_mode=Node.PROCESS_MODE_DISABLED
func run():
 label="Rainline lifecycle"
 var mission=load("res://demo/mission.tscn").instantiate();root.add_child(mission);mission.save_enabled=false;mission.start_new(true);await frames(8)
 var guard_count:int=mission.enemies.size()
 var lift:Node2D
 for child in mission.room.get_children():
  if child is AnimatableBody2D:lift=child;break
 check(is_instance_valid(lift),"authored lift exists")
 await key(KEY_ESCAPE)
 var pc:Vector2=mission.player.position;var lp:Vector2=lift.position;var guards:Array=[]
 for enemy in mission.enemies:guards.append(enemy.position)
 await frames(int(hz*0.5))
 check(mission.state=="paused" and paused,"Escape pauses mission")
 check(pc==mission.player.position and lp==lift.position,"pause freezes actor and moving lift")
 var frozen:=true
 for i in guards.size():frozen=frozen and guards[i]==mission.enemies[i].position
 check(frozen,"pause freezes all live guard positions")
 await key(KEY_ESCAPE);await frames(int(hz*0.2))
 check(mission.state=="playing" and not paused and lp!=lift.position,"resume restores lift simulation")
 quiet(mission);mission.input_override={}
 mission.player.reset_actor(Vector2(2530,-160),1);await frames(2);await key(KEY_E)
 check(mission.caches.has(0) and mission.room.cache_found and mission.state=="archive","real E collects authored cache and opens archive")
 await key(KEY_E)
 mission.player.reset_actor(Vector2(3480,-280),1);await frames(2);await key(KEY_E)
 check(mission.relay_on and mission.room.shutters[0].is_open,"real E establishes pre-death relay state")
 var old_player:WeakRef=weakref(mission.player);var old_guard:WeakRef=weakref(mission.enemies[0]);var deaths:int=mission.deaths
 # Initial placement below the authored hazard invokes real boundary admission.
 mission.player.reset_actor(Vector2(1000,460),1);await frames(8)
 check(mission.state=="dead" and paused and mission.deaths==deaths+1,"authored boundary produces real death and pause")
 await key(KEY_R);await frames(4)
 check(mission.state=="playing" and not paused,"real R leaves death state")
 check(old_player.get_ref()==null and old_guard.get_ref()==null,"retry retires old actor and guards")
 check(mission.enemies.size()==guard_count and mission.remaining_enemies()==guard_count,"retry restores all live guards")
 check(not mission.relay_on and mission.relay_states.is_empty() and not mission.room.shutters[0].is_open,"death retry resets relay and physical shutter")
 check(mission.caches.has(0) and mission.room.cache_found,"collected archive persists through retry")
 quiet(mission);mission.save_enabled=true
 for sector_index in [0,1]:
  if sector_index==1:mission.load_sector(1);quiet(mission)
  mission.show_title();await frames(2)
  check(mission.continue_available,"checkpoint available for sector "+str(sector_index))
  var saved=JSON.parse_string(FileAccess.get_file_as_string(mission.SAVE))
  check(saved.sector==sector_index and saved.caches.has(0.0),"checkpoint stores exact sector and archive")
  await key(KEY_C);await frames(3)
  check(mission.sector==sector_index and mission.state=="playing" and not paused,"real C continues exact sector "+str(sector_index))
  check(mission.caches.has(0) and (sector_index!=0 or mission.room.cache_found),"continue restores archive ownership")
  check(mission.relay_states.is_empty(),"continue starts fresh per-sector relay state")
  quiet(mission)
 mission.queue_free();await frames(3)
 var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Lifecycle with labelled initial placements, actual E/Escape/R/C input and boundary death. Enemies live for pause check then disabled to isolate interactions. Sector1 initially selected via load_sector, not claimed onward traversal. Dedicated isolated user storage; save/continue exercised with actual files."}
 FileAccess.open("res://simulation/evidence/campaign_rules_lifecycle_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("LIFECYCLE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
