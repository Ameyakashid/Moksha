extends "res://simulation/tests/campaign_rules_placement.gd"
func run():
 for role in ["PC","NPC"]:
  for phase in [0.05,0.65]:
   label="diagonal carry / "+role+" / phase "+str(phase);begin(Vector2(3000,-300))
   var lift=Lift.instantiate();lift.position=Vector2(200,300);lift.travel=Vector2(200,-160);lift.period=6.0;lift.clock=phase*lift.period;world.add_child(lift);lift.hide()
   check(lift.platform_size==Vector2(100,14),"unmodified production lift size100x14")
   var floor=Floor.instantiate();floor.position=Vector2(350,410);floor.segment_size=Vector2(800,20);world.add_child(floor)
   await frames(3)
   var a=actor(role,lift.position+Vector2(0,-45));var supported:=0;var relative:=Vector2.ZERO;var error:=0.0;var min_x:=INF;var max_x:=-INF;var first_relative:=true
   for i in hz*4:
    await frames(1)
    if a.grounded and a._support==lift:
     supported+=1;var current:Vector2=a.global_position-lift.global_position
     if first_relative:relative=current;first_relative=false
     error=maxf(error,current.distance_to(relative));min_x=minf(min_x,a.position.x);max_x=maxf(max_x,a.position.x)
   check(supported>hz*3,"real drop boarding followed by more than3s lift support")
   check(error<3.5,"support relative position remains stable on diagonal trajectory")
   check(max_x-min_x>100,"lift carries actual actor horizontally over100px")
   # Ordinary movement leaves support. Lower continuous ground is missed-board recovery.
   move(a,role,Vector2.LEFT);await frames(hz);move(a,role,Vector2.ZERO);await frames(hz)
   check(a._support!=lift,"ordinary input leaves diagonal lift")
   check(a.grounded and a._support==floor.get_node("Support"),"missed/left lift recovers onto actual continuous lower landing")
   observations.append({"case":label,"supported_ticks":supported,"relative_drift":error,"horizontal_travel":max_x-min_x,"landing":str(a.position)})
   await finish()
 for role in ["PC","NPC"]:
  for late in [false,true]:await dock(role,late)
 var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"observations":observations,"scope":"Missing diagonal-only capability: existing lift travel200,−160 period6, actual early/late-phase gravity boarding,4s carry and ordinary walk-off to lower stationary landing. Production PC/NPC profiles, deliberate input adapters, not NPC autonomous planner or final Cistern route. Initial actor pose is explicit boarding fixture; no forced support/velocity."}
 FileAccess.open("res://simulation/evidence/campaign_rules_diagonal_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("DIAGONAL ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

func dock(role:String,late:bool):
 label="stationary departure / "+role+" / late="+str(late);begin(Vector2(3000,-300))
 var lift=Lift.instantiate();lift.position=Vector2(220,300);lift.travel=Vector2(200,-160);lift.period=6.0;lift.clock=3.0 if late else 0.0;world.add_child(lift)
 check(lift.platform_size==Vector2(100,14),"unmodified production lift size100x14")
 var pad=Platform.instantiate();pad.position=Vector2(100,289);pad.platform_size=Vector2(200,18);world.add_child(pad)
 var floor=Floor.instantiate();floor.position=Vector2(350,410);floor.segment_size=Vector2(800,20);world.add_child(floor)
 var a=actor(role,Vector2(170,270));await frames(int(hz*0.25))
 check(a.grounded and a._support==pad,"initial actual landing on stationary departure pad")
 move(a,role,Vector2.RIGHT)
 var boarded:=false
 for i in int(hz*0.5):
  await frames(1)
  if a._support==lift:boarded=true
 move(a,role,Vector2.ZERO);await frames(hz)
 if late:
  check(not boarded,"late departure really misses distant lift, no support snapping")
  check(a.grounded and a._support==floor.get_node("Support"),"missed boarding safely recovers to lower physical floor")
 else:
  check(boarded,"ordinary raw walk boards diagonal lift from stationary pad")
  check(a._support==lift and a.position.y<260,"boarded actor carried away from stationary departure")
 observations.append({"case":label,"boarded":boarded,"final_position":str(a.position)})
 await finish()
