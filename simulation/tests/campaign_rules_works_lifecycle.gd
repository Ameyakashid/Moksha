extends SceneTree
const Identity=preload("res://demo/tests/campaign_identity.gd")
const Lift=preload("res://demo/components/mission_lift.gd")
var checks:=0
var failures:Array[String]=[]
var hz:=60
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label)
func frames(n:int):
 for i in n:await physics_frame;await process_frame
func key(host:Node,code:int):
 var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;host._unhandled_key_input(event)
func quiet(host:Node):
 for enemy in host.enemies:enemy.process_mode=Node.PROCESS_MODE_DISABLED
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
 Engine.physics_ticks_per_second=hz;run.call_deferred()
func run():
 var host=preload("res://demo/mission.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true)
 var index=Identity.index(host.sectors,"relay_works");host.load_sector(index);host.input_override={};quiet(host)
 var d=host.sectors[index]
 check(index==6 and host.remaining_enemies()==13,"same stable Works identity/index with original thirteen live guards")
 check(host.player.collision_layer==2 and host.player.collision_mask==9,"production PC contact profile unchanged")
 check(host.enemies.all(func(e):return e.collision_layer==32 and e.collision_mask==9),"production NPC profile shares world contacts, intentionally no mutual blocking")
 var lifts=host.room.get_children().filter(func(node):return node.get_script()==Lift)
 check(not lifts.is_empty(),"authored production lifts present")
 for lift in lifts:
  check(lift.platform_size==Vector2(100,14) and lift.collision_layer==1 and lift.collision_mask==0,"default production lift dimensions/masks")
  var shapes=lift.get_children().filter(func(node):return node is CollisionShape2D)
  check(shapes.size()==1 and shapes[0].one_way_collision and shapes[0].shape.size==Vector2(100,14),"real lift one-way shape unchanged")
 await frames(hz/3)
 var clocks=lifts.map(func(lift):return lift.clock);var positions=lifts.map(func(lift):return lift.position)
 var player_position=host.player.position;var support=host.player._support;var elapsed=host.elapsed
 check(host.player.grounded and is_instance_valid(support),"real spawn support before pause")
 key(host,KEY_ESCAPE);await frames(hz/3)
 check(host.state=="paused" and host.player.position==player_position and host.player._support==support and host.elapsed==elapsed,"pause freezes actor/support identity and mission clock")
 check(lifts.map(func(lift):return lift.clock)==clocks and lifts.map(func(lift):return lift.position)==positions,"pause freezes actual lift motors and transforms")
 key(host,KEY_ESCAPE);await frames(3)
 check(host.state=="playing" and host.elapsed>elapsed and lifts[0].clock>clocks[0],"resume advances same lift and mission clocks")
 # Fixture setup positions only; interactions use normal proximity E.
 host.player.reset_actor(d.station,1);key(host,KEY_E)
 check(host.state=="choice","Works station offers actual retained/traded choice")
 key(host,KEY_K);check(host.state=="playing" and not host.blind,"retained choice returns to play")
 key(host,KEY_E);key(host,KEY_J);check(host.state=="playing" and host.blind and host.sonar.blind,"actual station trade enables blind presentation")
 for i in 3:
  host.player.reset_actor(host._relay_points()[i],1);key(host,KEY_E);await frames(2)
  check(host.relay_states.has(i) and host.room.shutters[i].is_open and host.room.shutters[i].collision_shape.disabled,"proximity relay opens actual matching shutter")
  var count=host.relay_states.size();key(host,KEY_E);await frames(1)
  check(host.relay_states.size()==count,"repeat relay interaction is idempotent")
  check(host.room.gate_open==(i==2),"exit requires exactly all three circuits")
  host.sonar.refresh_geometry()
  check(not host.sonar.geometry.any(func(contour):return contour.anchor.get_ref()==host.room.shutters[i].collision_shape),"opened shutter has no blind collision contour")
 check(host.remaining_enemies()==13 and host.kills==0 and host.room.gate_open,"three circuits unlock exit while all thirteen guards remain alive")
 host.player.reset_actor(d.cache,1);key(host,KEY_E);await frames(2)
 check(host.caches==[index] and host.state=="archive","real E collects Works cache under its existing identity")
 key(host,KEY_ENTER)
 # Explicit below-floor safe-side setup; no health/outcome writes. Gravity crosses real authored boundary.
 host.player.reset_actor(Vector2(float(d.get("spawn",Vector2(1250,300)).x),float(d.get("boundary_y",420))-45),1)
 var old_player=host.player.get_instance_id();var old_enemy=host.enemies[0].get_instance_id()
 for i in hz*3:
  if host.state=="dead":break
  await frames(1)
 check(host.state=="dead" and host.health.current_health==0 and host.player.get_node("DefeatResponse").active and host.deaths==1,"real gravity/boundary causes Health defeat and mission pause")
 key(host,KEY_R);await frames(3);quiet(host)
 check(host.state=="playing" and host.player.get_instance_id()!=old_player and host.health.current_health==60,"R after death creates fresh full-health actor")
 check(host.enemies[0].get_instance_id()!=old_enemy and host.remaining_enemies()==13 and host.kills==0,"retry rebuilds original living roster")
 check(host.relay_states.is_empty() and not host.room.gate_open and host.room.shutters.all(func(s):return not s.is_open and not s.collision_shape.disabled),"retry resets all relays and solid shutters")
 check(host.blind and host.caches==[index],"retry retains actual sight trade and Works cache")
 host.save_enabled=true;host._save_checkpoint();host.save_enabled=false
 var saved=JSON.parse_string(FileAccess.get_file_as_string(host.SAVE))
 check(saved.version==4 and saved.sector_id=="relay_works" and saved.cache_ids==["relay_works"],"checkpoint retains same Works ID/archive rather than positional remap")
 host.queue_free();paused=false;await frames(2)
 host=preload("res://demo/mission.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.continue_run();await frames(2);quiet(host)
 check(host.sector==index and host.sectors[host.sector].id=="relay_works" and host.blind and host.caches==[index],"fresh-host Continue restores same index/ID/cache/choice")
 check(host.relay_states.is_empty() and not host.room.gate_open and host.remaining_enemies()==13,"Continue reconstructs local circuits/guards rather than persisting defeated room state")
 host.queue_free();paused=false;await frames(2)
 var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"module_sha256":FileAccess.get_sha256("res://demo/areas/relay_works.gd"),"scope":"Labelled direct-state setup with normal E/choice/R, real gravity death, pause and fresh Continue. Enemy processing disabled to isolate rules; no AI/route usability or lift boarding claim."}
 FileAccess.open("res://simulation/evidence/works_lifecycle_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("WORKS LIFECYCLE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
