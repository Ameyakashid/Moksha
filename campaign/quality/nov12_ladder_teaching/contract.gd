extends SceneTree
## Explicitly seeded presentation lifecycle, not an earned climb or native playtest.
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true);host.set_physics_process(false)
 var mill:=0
 for i in host.sectors.size():
  if host.sectors[i].id=="l2_capacitor_mill":mill=i
 host.load_sector(mill);host.set_physics_process(false);host.state="playing";paused=false
 var ladder:Node
 for n in host.room.get_children():
  if n.has_method("climb_geometry") and is_equal_approx(n.position.x,1260):ladder=n;break
 check(is_instance_valid(ladder),"actual Mill ladder found")
 if ladder==null:host.free();quit(1);return
 var player:Node=host.player
 player.position=Vector2(1260,180);player.main_action=&"climb";player._climb_target=ladder;player._climb_signature=Vector2(ladder.width,ladder.height)
 var view=host.hud.get_node("View")
 var facts:Dictionary={"pose":player.position,"velocity":player.velocity,"action":player.main_action,"target":player._climb_target,"senses":host.sense_capabilities().duplicate(true),"metrics":host.metrics.duplicate(true),"run_id":host.run_id,"goals":host.completed_goals.duplicate(true),"sectors":host.sectors.duplicate(true)}
 for blind in [false,true]:
  host.blind=blind
  check(host._hud_snapshot().ladder_attached,"body-known grip available independently of sight")
  for device in ["keyboard","controller"]:
   var snapshot:Dictionary=host._hud_snapshot();snapshot.input_device=device;view.data=snapshot
   var strip:Dictionary=view.control_strip()
   check(strip.left.contains("hold Up to reach top") if device=="controller" else strip.left.contains("hold W to reach top"),"device-correct continued ascent teaching")
   check(strip.left.contains("Left/right lets go") if device=="controller" else strip.left.contains("A/D lets go"),"horizontal release honestly described")
   check(strip.left.contains("A jumps off") if device=="controller" else strip.left.contains("Space jumps off"),"unchanged jump mapping")
   check(ThemeDB.fallback_font.get_string_size(strip.left,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x+14<=strip.right_x-12,"teaching fits before unchanged journal/pause prompts")
   check(strip.right==("BACK journal   START pause" if device=="controller" else "TAB journal   ESC pause"),"journal/pause unchanged")
 host.blind=false
 for state in ["title","intro","paused","journal","choice","hearing_choice","upgrade","transition","dead","final_choice","complete"]:
  host.state=state;check(not host._ladder_controls_active(),"no teaching during "+state)
 host.state="playing";paused=true;check(not host._ladder_controls_active(),"global pause clears teaching");paused=false
 host._loading_campaign=true;check(not host._ladder_controls_active(),"room setup clears teaching");host._loading_campaign=false
 host._pending_retry=true;check(not host._ladder_controls_active(),"pending retry clears teaching");host._pending_retry=false
 host._pending_sector=mill+1;check(not host._ladder_controls_active(),"pending room change clears teaching");host._pending_sector=-1
 for action in [&"locomotion",&"damage",&"roll",&"attack"]:
  player.main_action=action;check(not host._hud_snapshot().ladder_attached,"detach/replacement action clears teaching")
 player.main_action=&"climb"
 var hp:float=host.health.current_health;host.health._current=0;check(host.health.current_health==0,"fixture seeded zero health directly, getter is read only");check(not host._ladder_controls_active(),"zero health clears even before state changes");host.health._current=hp
 ladder.enabled=false;check(not host._ladder_controls_active(),"disabled target clears");ladder.enabled=true
 ladder.position.x+=200;check(not host._ladder_controls_active(),"moved-away target clears");ladder.position.x-=200
 var old_height:float=ladder.height;ladder.height+=10;check(not host._ladder_controls_active(),"changed target signature clears");ladder.height=old_height
 var mask:int=ladder.collision_layer;ladder.collision_layer=0;check(not host._ladder_controls_active(),"disabled sensor mask clears");ladder.collision_layer=mask
 ladder.reparent(root);check(not host._ladder_controls_active(),"foreign room target clears");ladder.reparent(host.room)
 player._climb_target=null;check(not host._hud_snapshot().ladder_attached,"missing grip clears");player._climb_target=ladder
 check(host._ladder_controls_active(),"valid grip restores without cached stale state")
 for i in 20:host._hud_snapshot()
 check(player.position==facts.pose and player.velocity==facts.velocity and player.main_action==facts.action and player._climb_target==facts.target,"snapshot reads do not change physical state or grip")
 check(host.sense_capabilities()==facts.senses and host.metrics==facts.metrics and host.run_id==facts.run_id and host.completed_goals==facts.goals and host.sectors==facts.sectors,"snapshot reads preserve senses/progress/catalog identity")
 for device in ["keyboard","controller"]:
  view.data={"input_device":device,"ladder_attached":false,"hearing_retained":false}
  var strip:Dictionary=view.control_strip()
  check(not strip.left.contains("lets go") and strip.left.contains("move"),"ordinary footer restored immediately")
 ladder.queue_free();check(not host._ladder_controls_active(),"queued target clears before next physics")
 host.load_sector(mill);host.set_physics_process(false);host.state="playing";paused=false
 check(not host._hud_snapshot().ladder_attached,"actual room reload has no retained grip teaching")
 host.free();await process_frame
 print(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Seeded read-only HUD facts, actual font bounds and lifecycle; not native pixels or gameplay acceptance"}));quit(0 if failures.is_empty() else 1)
