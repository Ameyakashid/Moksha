extends "res://campaign/route_tests/l23_route.gd"
## Explicit checkpoint-start fixture, then ordinary automated player inputs.
const ModalRouteInput=preload("res://campaign/quality/nov6_modal_route_input.gd")
func key(code:int)->void:
 var previous_state:String=host.state
 await super.key(code)
 await ModalRouteInput.release_after_resume(host,previous_state,events,frame)
func decide()->Dictionary:
 var result:Dictionary=super.decide()
 if frame%60==0:print("VIDEO_CHECKPOINT frame=",frame," district=",district_id," position=",host.player.position)
 return result

func run()->void:
 input_dispatch=InputDispatch.new();input_dispatch.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(input_dispatch)
 host=load(scene_path).instantiate();root.add_child(host);host.save_enabled=false
 # Explicit pre-recording district-start fixture, no campaign progression claim.
 host.start_new(true)
 for i in host.sectors.size():
  if str(host.sectors[i].id)==district_id:probe_sector=i
 if probe_sector<0:
  host.free();input_dispatch.free();await process_frame;quit(2);return
 host.load_sector(probe_sector)
 measured_start=host.elapsed
 capture_sources("res://")
 for tick in range(hz*30):
  frame=tick
  if host.sector!=probe_sector or host.state=="upgrade":break
  if host.state=="dead":
   failures.append("Ordinary input route died");break
  if host.state=="archive":await key(KEY_E)
  elif host.state=="choice":
   await key(KEY_K);choice_done=true
  elif host.state=="playing":
   if sector_seen!=host.sector:begin_sector()
   host.input_override=decide()
  await physics_frame;await process_frame
 var drift:Array[String]=[]
 for path in checkpoint_hashes:
  if FileAccess.get_sha256(path)!=checkpoint_hashes[path]:drift.append(path)
 if not drift.is_empty():failures.append("Source drift")
 var report={"district":district_id,"passed":failures.is_empty(),"checkpoint_start_fixture":true,"full_level":false,"full_campaign":false,"active_seconds":host.elapsed-measured_start,"deaths":host.deaths,"failures":failures,"goals_observed":goals_seen,"source_drift":drift,"method":"Explicit district-start seed followed only by ordinary automated inputs. No in-play position/health/goal writes. Linux, 1x playback."}

 print("VIDEO_EXCERPT_RESULT ",report)
 var code:=0 if failures.is_empty() else 1
 host.free();input_dispatch.free();await process_frame;quit(code)
