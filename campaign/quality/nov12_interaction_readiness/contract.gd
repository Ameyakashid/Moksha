extends SceneTree
const Caption=preload("res://campaign/views/objective_caption.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true);host.set_physics_process(false)
 var index:=0
 for i in host.sectors.size():
  if host.sectors[i].id=="l3_inundated_market":index=i
 host.load_sector(index);host.set_physics_process(false);host.state="playing";paused=false
 for enemy in host.enemies:enemy.get_node("IntentDriver").automatic_driver=false
 var goal=host.goals[0]
 goal.set_physics_process(false)
 for kind in ["recover","install","route","rescue","terminal","plate","breaker"]:
  goal.kind=kind;goal.completed=false;goal.required_ids.clear()
  for distance in [51.0,52.0,90.0]:
   host.player.position=goal.position+Vector2(0,distance)
   var facts:Dictionary=host.objective_caption_facts(goal)
   var expect:bool=host._nearby_objective()==goal and kind not in ["plate","breaker"]
   check(facts.actionable==expect,"selector parity %s/%s"%[kind,distance])
   for controller in [false,true]:
    var text:Dictionary=Caption.describe(kind,"Identity",false,facts.available,-1,2,true,controller,facts.actionable)
    check(text.title=="Identity" and text.detail.begins_with("OPTIONAL"),"identity and optional preserved")
    if kind not in ["plate","breaker"]:
     var keyboard_action:bool=text.detail.contains("E ·") or text.detail.contains("E →")
     var controller_action:bool=text.detail.contains("Y ·") or text.detail.contains("Y →")
     check(controller_action and not keyboard_action if expect and controller else keyboard_action and not controller_action if expect else not keyboard_action and not controller_action,"device/action truth %s/%s"%[kind,distance])
  goal.completed=true;host.player.position=goal.position
  var done:Dictionary=host.objective_caption_facts(goal)
  check(done.actionable==(kind=="route"),"completed eligibility "+kind)
  var completed_text:Dictionary=Caption.describe(kind,"Identity",true,true,2,2,false,false,done.actionable)
  check(completed_text.detail.contains("E CHANGES") if kind=="route" else completed_text.detail=="COMPLETE","complete label "+kind)
  goal.completed=false;goal.required_ids.assign(["missing_fixture_requirement"])
  var locked:Dictionary=host.objective_caption_facts(goal)
  check(not locked.available and not locked.actionable,"fresh prerequisite check "+kind)
  check(Caption.describe(kind,"Identity",false,locked.available,-1,2,false,false,locked.actionable).detail.begins_with("LOCKED"),"locked text "+kind)
 goal.required_ids.clear();goal.kind="recover"
 goal.available=false;host.player.position=goal.position
 check(host.objective_caption_facts(goal).available,"live prerequisites override stale cached presentation flag")
 var before:Dictionary={"position":host.player.position,"velocity":host.player.velocity,"completed":goal.completed,"setting":goal.setting,"available":goal.available}
 host.objective_caption_facts(goal)
 check(before=={"position":host.player.position,"velocity":host.player.velocity,"completed":goal.completed,"setting":goal.setting,"available":goal.available},"caption query writes no gameplay or objective cache")
 for state in ["title","intro","paused","journal","choice","hearing_choice","upgrade","transition","dead","complete"]:
  host.state=state;check(not host.objective_caption_facts(goal).actionable and not host._ladder_contact_hint(),"inactive "+state)
 host.state="playing";host._pending_retry=true;check(not host.objective_caption_facts(goal).actionable and not host._ladder_contact_hint(),"pending retry");host._pending_retry=false
 host._pending_sector=index+1;check(not host.objective_caption_facts(goal).actionable and not host._ladder_contact_hint(),"pending sector");host._pending_sector=-1
 paused=true;check(not host.objective_caption_facts(goal).actionable and not host._ladder_contact_hint(),"tree pause");paused=false
 var owner=host.hud;var view=owner.get_node("View")
 check(owner.set_snapshot({"ladder_contact":true,"ladder_attached":false}),"typed bool accepted")
 check(not owner.set_snapshot({"ladder_contact":"yes"}),"bad bool rejected")
 check(view.data.ladder_contact,"bad snapshot preserves accepted data")
 check(owner.set_snapshot({}),"omitted fields accepted")
 check(not view.data.ladder_contact,"omission retires hint")
 for controller in [false,true]:
  view.data=host._hud_snapshot()
  view.data.merge({"ladder_contact":true,"ladder_attached":false,"input_device":"controller" if controller else "keyboard"},true)
  var strip:Dictionary=view.control_strip()
  check(strip.left.contains("Up/down") if controller else strip.left.contains("W/S"),"device contact clue")
  check(ThemeDB.fallback_font.get_string_size(strip.left,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x+14<=strip.right_x-12,"bounded footer")
  view.data.ladder_attached=true
  check(view.control_strip().left.contains("jumps off"),"attached teaching takes precedence")
 # Seeded actual local ladder contact; no earned traversal claim.
 var ladder:Node
 for child in host.room.get_children():
  if child.has_method("climb_geometry"):ladder=child;break
 check(ladder!=null,"production ladder")
 if ladder!=null:
  var geometry:Dictionary=ladder.climb_geometry()
  host.player.reset_actor(Vector2(geometry.axis_x,geometry.bottom_y),1)
  for i in 3:await physics_frame;await process_frame
  for blind in [false,true]:
   host.blind=blind
   check(host._ladder_contact_hint() and not host._ladder_controls_active(),"contact clue before attachment both sight states")
  host.player.position.x+=100
  check(not host._ladder_contact_hint(),"moved actor invalidates local clue synchronously")
  host.load_sector(index);host.set_physics_process(false)
  check(not host._hud_snapshot().ladder_contact,"room load retires contact")
 host.free();await process_frame
 print("INTERACTION_READINESS ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Seeded production host/selector/contact plus pure formatting; not natural gameplay or native pixels"}));quit(0 if failures.is_empty() else 1)
