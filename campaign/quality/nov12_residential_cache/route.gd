extends "res://campaign/route_tests/l23_route.gd"
## Focused district-start fixture; all measured movement uses ordinary inputs.
const Modal=preload("res://campaign/quality/nov6_modal_route_input.gd")
const Sink=preload("res://campaign/quality/nov12_report_sink.gd")
var destination:=""
var collect_cache:=false
var prompt_receipts:Array=[]
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):destination=arg.trim_prefix("--report=")
 var error:String=Sink.validate(destination)
 if not error.is_empty():push_error(error);quit(2);return
 district_id="l3_homes"
 collect_cache="--collect" in OS.get_cmdline_user_args()
 if collect_cache:
  residential_points.insert(9,Vector2(2840,190))
  residential_points.insert(10,Vector2(2940,300))
 super._initialize()
func key(code:int)->void:
 var previous:String=host.state
 await super.key(code)
 await Modal.release_after_resume(host,previous,events,frame)
func decide()->Dictionary:
 var cache:Vector2=host.sectors[probe_sector].cache
 if host._near(cache):
  var g=host._nearby_objective()
  if is_instance_valid(g) and g.objective_id=="shelter":failures.append("Cache overlaps shelter selector")
  if prompt_receipts.is_empty():prompt_receipts.append({"at":"cache","position":str(host.player.position),"shelter_near":host._near(Vector2(2940,300),52)})
 return super.decide()
func run() -> void:
 input_dispatch=InputDispatch.new()
 input_dispatch.process_mode=Node.PROCESS_MODE_ALWAYS
 root.add_child(input_dispatch)
 host=load(scene_path).instantiate()
 root.add_child(host)
 host.save_enabled=false
 host.start_new(true)
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
 var cache_collected:bool=host.caches.has(probe_sector)
 if cache_collected!=collect_cache:failures.append("Cache collect/skip mismatch")
 if not goals_seen.has("shelter"):failures.append("Mandatory shelter not observed")
 var reached:bool=host.sector!=probe_sector or host.state=="upgrade"
 if not reached and failures.is_empty():failures.append("District timeout")
 var drift:Array[String]=[]
 for path in checkpoint_hashes:
  if FileAccess.get_sha256(path)!=checkpoint_hashes[path]:drift.append(path)
 var report={"collect_cache":collect_cache,"cache_collected":cache_collected,"prompt_receipts":prompt_receipts,"district":district_id,"passed":accepted(reached,failures,drift),"sight":sacrifice,"explicit_start_and_sight_fixture":true,"full_campaign_evidence":false,"bot_active_seconds":host.elapsed-measured_start,"human_duration_validated":false,"failures":failures,"goals_observed":goals_seen,"events":events,"trace":trace,"source_drift":drift,"source_hashes":checkpoint_hashes,"method":"Measured phase: raw ordinary buttons plus proximity E events. No teleport, damage/health/AI writes, forced goals or gate edits. Initial district and sight are explicit isolated fixtures."}
 var path=destination
 var output_error=Sink.write_report(path,report)
 if not output_error.is_empty():
  push_error(output_error)
  report.passed=false
 print("L23_RESULT ",path," passed=",report.passed," bot_seconds=",report.bot_active_seconds," failures=",failures)
 var exit_code:=0 if report.passed else 1
 host.free();input_dispatch.free();await process_frame
 print("RESIDENTIAL_CLEAN_EXIT ",exit_code)
 quit(exit_code)

static func accepted(reached:bool,errors:Array,drift:Array)->bool:
 return reached and errors.is_empty() and drift.is_empty()
