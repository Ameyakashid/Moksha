extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 for name in ["warden_loops_review","warden_displaced_review","warden_right_displaced_review"]:
  var host=load("res://demo/tests/"+name+".tscn").instantiate();root.add_child(host)
  check(str(host.sectors[host.sector].id)=="lift_warden" and host.sector==7,"active Warden wrapper resolves shifted identity")
  if name=="warden_displaced_review":check(host.player.position==Vector2(780,190) and host.enemies[0].position==Vector2(805,190),"western explicit pre-clock setup still targets Warden roster")
  if name=="warden_right_displaced_review":check(host.enemies[2].position==Vector2(1245,245),"eastern explicit pre-clock setup still targets Warden roster")
  host.queue_free();paused=false;await process_frame;await physics_frame
 var report={"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Pre-clock fixture setup only, no measured route claim."}
 print("SHIFTED FIXTURES ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
