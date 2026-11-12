extends SceneTree
## End-to-end owner boundary. Staged Mill entry, then real physics/input climb.
## Device labels are explicitly selected presentation fixtures, not hardware tests.
class Driver extends Node:
 var actor:Node
 var frame:Dictionary={}
 var ticks:=0
 var remaining:=0
 func _physics_process(dt:float)->void:
  if remaining>0 and is_instance_valid(actor):
   actor.physics_tick(dt,frame);ticks+=1;remaining-=1
var checks:=0
var failures:Array[String]=[]
var hz:=60
var host:Node
var driver:Driver
var label:=""
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(label+": "+message);push_error(label+": "+message)
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
 Engine.physics_ticks_per_second=hz;run.call_deferred()
func step(frame:Dictionary,count:=1)->void:
 driver.frame=frame;driver.remaining=count
 var target:=driver.ticks+count
 while driver.ticks<target:await physics_frame;await process_frame
func deliver(device:String,expected:bool)->void:
 host.gamepad_navigation.input_device=device
 var before:Array=[host.player.position,host.player.velocity,host.player.main_action,host.player._climb_target,host.run_id,host.metrics.duplicate(true),host.completed_goals.duplicate(true)]
 var snapshot:Dictionary=host._hud_snapshot()
 check(snapshot.ladder_attached==expected,"host emits correct actual-grip fact")
 check(host.hud.set_snapshot(snapshot),"real owner accepts host snapshot")
 var view=host.hud.get_node("View")
 check(view.data.get("ladder_attached",false)==expected,"owner actually delivers grip to painter")
 check(host.hud.get_snapshot().get("ladder_attached",false)==expected,"owner readback matches")
 var strip:Dictionary=view.control_strip()
 check(strip.left.contains("lets go")==expected,"visible control-strip selection matches actual grip")
 if expected:
  check(strip.left.contains("Up/down climb. Hold Up until standing on the ledge") if device=="controller" else strip.left.contains("W/S climb. Hold W until standing on the ledge"),"real chain delivers device-specific teaching")
  check(ThemeDB.fallback_font.get_string_size(strip.left,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x+14<=strip.right_x-12,"delivered text fits original footer")
 check(strip.right==("BACK journal   START pause" if device=="controller" else "TAB journal   ESC pause"),"journal/pause unchanged through owner")
 var after:Array=[host.player.position,host.player.velocity,host.player.main_action,host.player._climb_target,host.run_id,host.metrics.duplicate(true),host.completed_goals.duplicate(true)]
 check(before==after,"snapshot/owner/view chain is read only")
func run()->void:
 for device in ["keyboard","controller"]:
  label=device
  host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true);host.set_physics_process(false)
  var mill:=0
  for i in host.sectors.size():
   if host.sectors[i].id=="l2_capacitor_mill":mill=i
  host.load_sector(mill);host.set_physics_process(false);host.state="playing";paused=false
  # Only starting pose is staged. Subsequent grip/top exit use ordinary inputs.
  host.player.reset_actor(Vector2(1260,240),1)
  driver=Driver.new();driver.actor=host.player;driver.process_physics_priority=20;root.add_child(driver)
  await step({},ceili(hz*.15));deliver(device,false)
  await step({"up":1.0},ceili(hz*.3))
  check(host.player.main_action==&"climb","ordinary Up commits actual climb")
  deliver(device,true)
  var valid:Dictionary=host._hud_snapshot();var saved:Dictionary=host.hud.get_snapshot()
  for bad in [1,"true",null]:
   var rejected:Dictionary=valid.duplicate(true);rejected.ladder_attached=bad
   check(not host.hud.set_snapshot(rejected),"invalid campaign grip type rejects atomically")
   check(host.hud.get_snapshot()==saved,"invalid grip leaves accepted owner snapshot unchanged")
   check(host.hud.get_node("View").data==saved,"invalid grip leaves painter unchanged")
  var invalid_shared:Dictionary=valid.duplicate(true);invalid_shared.health_capacity=0;invalid_shared.ladder_attached=false
  check(not host.hud.set_snapshot(invalid_shared),"invalid shared field rejects staged campaign change")
  check(host.hud.get_snapshot()==saved and host.hud.get_node("View").data==saved,"shared rejection rolls back both owner snapshots and painter")
  var omitted:Dictionary=valid.duplicate(true);omitted.erase("ladder_attached")
  check(host.hud.set_snapshot(omitted),"omission accepted with safe default")
  check(host.hud.get_snapshot().get("ladder_attached",null)==false and not host.hud.get_node("View").control_strip().left.contains("lets go"),"omission clears prior true at real owner")
  deliver(device,true)
  # Modal safety checked through the same owner, without advancing mechanics.
  host.state="paused";deliver(device,false);host.state="playing";deliver(device,true)
  for i in hz*2:
   if host.player.main_action!=&"climb":break
   await step({"up":1.0})
  check(host.player.main_action!=&"climb" and host.player.grounded and absf(host.player.position.y-130)<.2,"held Up completes supported top exit without jump")
  deliver(device,false)
  # Separate, clearly staged second start; actual hit interrupts actual climb.
  host.player.reset_actor(Vector2(1260,240),1);await step({},ceili(hz*.15));await step({"up":1.0},ceili(hz*.3));deliver(device,true)
  host.player.receive_hit({"rollable":false,"hitpause":.06})
  check(host.player.main_action==&"hurt","real accepted hit cancels physical grip")
  deliver(device,false)
  driver.free();host.free();await process_frame
 var plain=load("res://simulation/ui/mission_hud.gd").new();root.add_child(plain)
 check(plain.set_snapshot({"ladder_attached":true}),"unrelated mission owner accepts unknown-key discard")
 check(not plain.get_snapshot().has("ladder_attached"),"campaign-only grip does not leak into shared mission HUD")
 plain.free();await process_frame
 print(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"physics_hz":Engine.physics_ticks_per_second,"scope":"Real player physics and ordinary held-Up inputs in staged campaign Mill; actual host snapshot -> typed owner -> painter; selected device presentation, not native or hardware gameplay."}))
 quit(0 if failures.is_empty() else 1)
