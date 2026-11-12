extends "res://campaign/quality/nov12_ladder_teaching/owner_contract.gd"
## Staged actor-only physics in actual Market geometry; host/enemy scheduler stopped.
## No private neutral flag steering. Inputs and observed events retained in receipt.
var evidence:Array=[]
var events:Array=[]
var inputs:Array=[]
var output:="user://market-rail-contract.json"
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 super._initialize()
func capture(name,payload)->void:
 if str(name).begins_with("climb_") or str(name) in ["ground_jump","air_jump","hurt_started"]:events.append({"tick":driver.ticks,"event":str(name),"data":payload.duplicate(true)})
func step(frame:Dictionary,count:=1)->void:
 inputs.append({"tick":driver.ticks,"count":count,"frame":frame.duplicate(true)})
 await super.step(frame,count)
func stage()->void:
 host.player.reset_actor(Vector2(1470,300),1);await step({},ceili(hz*.2));events.clear();inputs.clear()
func climb_to(y:float)->void:
 for i in hz*5:
  if host.player.position.y<=y:break
  await step({"up":1.0})
func run()->void:
 for build in ["neutral","strength","agility"]:
  for senses in [[false,true],[true,true],[false,false],[true,false]]:
   label=build+"/blind="+str(senses[0])+"/hearing="+str(senses[1])
   host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true);host.set_physics_process(false)
   host.lens=build;host.blind=senses[0];host.hearing_retained=senses[1]
   for i in host.sectors.size():
    if host.sectors[i].id=="l3_inundated_market":host.load_sector(i);break
   host.set_physics_process(false);host.state="playing";paused=false
   for enemy in host.enemies:enemy.set_physics_process(false) # Explicit actor-only fixture, not combat acceptance.
   print("MATRIX ",label)
   driver=Driver.new();driver.process_mode=Node.PROCESS_MODE_ALWAYS;driver.actor=host.player;driver.process_physics_priority=20;root.add_child(driver)
   host.player.movement_event.connect(capture)
   check(host.art.visible==not senses[0],"world wayfinding follows existing sight gate")
   var snap:Dictionary=host._hud_snapshot();check(host.hud.set_snapshot(snap),"actual HUD owner accepts authored guidance")
   check(host.hud.get_node("View").data.guidance.contains("above Mended Sails"),"known mission instruction reaches actual painter for all senses")
   var ladders:Array=host.sectors[host.sector].ladders
   check(ladders.has([1470,300,390]) and not ladders.has([1460,110,200]),"exact single continuous rail")
   await stage();await step({"up":1.0},hz*4)
   check(host.player.grounded and absf(host.player.position.y+90)<.2,"continuous held Up reaches supported upper exit")
   check(events.filter(func(e):return e.event=="climb_attached").size()==1,"one acquisition, no neutral/regrab oracle")
   evidence.append({"case":label+"/continuous","position":str(host.player.position),"events":events.duplicate(true),"inputs":inputs.duplicate(true)})
   for above in [false,true]:
    for side in ["left","right"]:
     await stage();await climb_to(103 if above else 116)
     var departure:Vector2=host.player.position
     await step({side:1.0},ceili(hz*.2));await step({},ceili(hz*.35))
     check(host.player.grounded and absf(host.player.position.y-110)<.2 if above else host.player.position.y>130,"midway "+side+" above lands / below falls honestly")
     evidence.append({"case":label+"/"+side+"/above="+str(above),"departure":str(departure),"final":str(host.player.position),"events":events.duplicate(true)})
   await stage();await step({"up":1.0},hz*4);await step({},ceili(hz*.25));await step({"down":1.0},hz*2)
   check(host.player.grounded and absf(host.player.position.y-110)<.2,"descent stops on actual intermediate one-way floor")
   await step({},ceili(hz*.25));await step({"down":1.0},hz*2)
   check(host.player.grounded and absf(host.player.position.y-300)<.2,"ordinary neutral then Down reenters and descends to ground")
   evidence.append({"case":label+"/descent","events":events.duplicate(true),"inputs":inputs.duplicate(true)})
   await stage();await step({"up":1.0},ceili(hz*.5));await step({"jump":true})
   check(host.player.main_action!=&"climb","jump interrupts continuous grip")
   await stage();await step({"up":1.0},ceili(hz*.5));host.player.receive_hit({"rollable":false,"hitpause":.06})
   check(host.player.main_action==&"hurt","actual accepted hit interrupts continuous grip")
   driver.free();host.free();await process_frame
 var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"hz":hz,"evidence":evidence,"scope":"Staged actor-only actual campaign geometry/physics across three builds and four sense states. Enemy/host scheduler stopped; no combat difficulty, natural route or native acceptance claim. No private neutral flag steering."}
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"hz":hz}));quit(0 if failures.is_empty() else 1)
