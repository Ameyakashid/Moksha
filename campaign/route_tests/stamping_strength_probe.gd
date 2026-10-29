extends "res://campaign/route_tests/l23_route.gd"
func _initialize() -> void:
 district_id="l2_stamping_galleries"
 super._initialize()
func run() -> void:
 input_dispatch=InputDispatch.new()
 input_dispatch.process_mode=Node.PROCESS_MODE_ALWAYS
 root.add_child(input_dispatch)
 host=load(scene_path).instantiate()
 root.add_child(host)
 host.save_enabled=false
 host.lens="strength" # Explicit isolated pre-run build fixture.
 host.start_new(true)
 host.upgrades.append("force") # First completed-level upgrade fixture.
 for i in host.sectors.size():
  if str(host.sectors[i].id)==district_id: probe_sector=i
 if probe_sector<0:
  push_error("Unknown district: "+district_id);quit(2);return
 host.load_sector(probe_sector)
 if sacrifice:
  host.state="choice" # Explicit PRE-RUN sight fixture, never measured gameplay.
  host.choose_sight(true)
  starting_sight_fixture=true
  choice_done=true
 assert(host.blind==sacrifice,"Requested isolated sight fixture did not apply")
 measured_start=host.elapsed
 events.append({"event":"isolated_start_fixture","district":district_id,"sight_fixture":sacrifice,"not_full_campaign":true})
 capture_sources("res://")
 for tick in range(hz*max_sector_seconds):
  frame=tick
  if host.sector!=probe_sector or host.state=="upgrade":break
  if host.state=="dead":
   failures.append("Ordinary input route died")
   break
  if host.state=="archive":await key(KEY_E)
  elif host.state=="choice":
   await key(KEY_J if sacrifice else KEY_K)
   choice_done=true
  elif host.state=="playing":
   if sector_seen!=host.sector:begin_sector()
   host.input_override=decide()
   if frame%hz==0:
    trace.append(snapshot())
    if trace.size()>60:trace.pop_front()
   if frame%(hz*15)==0:print("L23 ",district_id," ",snapshot())
  await physics_frame
  await process_frame
 var reached:bool=host.sector!=probe_sector or host.state=="upgrade"
 if not reached and failures.is_empty():failures.append("District timeout")
 var drift:Array[String]=[]
 for path in checkpoint_hashes:
  if FileAccess.get_sha256(path)!=checkpoint_hashes[path]:drift.append(path)
 var report={"district":district_id,"passed":reached and failures.is_empty(),"sight":sacrifice,"explicit_start_and_sight_fixture":true,"full_campaign_evidence":false,"bot_active_seconds":host.elapsed-measured_start,"human_duration_validated":false,"failures":failures,"goals_observed":goals_seen,"events":events,"trace":trace,"source_drift":drift,"source_hashes":checkpoint_hashes,"method":"Measured phase: raw ordinary buttons plus proximity E events. No teleport, damage/health/AI writes, forced goals or gate edits. Initial district and sight are explicit isolated fixtures."}
 var path="res://campaign/route_tests/stamping_strength_probe.json"
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("L23_RESULT ",path," passed=",report.passed," bot_seconds=",report.bot_active_seconds," failures=",failures)
 quit(0 if report.passed else 1)
func navigate(target:Vector2,d:Dictionary)->Dictionary:
 if str(d.id)=="l2_stamping_galleries" and not host.goal_done("die") and (host.player.position.y>110 or host.player.main_action==&"climb"):
  return {"target":Vector2(1340,100),"up":true,"jump":false,"drop":false}
 return super.navigate(target,d)
