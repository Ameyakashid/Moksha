extends SceneTree
## Isolated geometry negative control: remove live guards before measured input.
var hz:=60
var sacrifice:=false
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
  if arg=="--sacrifice":sacrifice=true
 Engine.physics_ticks_per_second=hz
 run.call_deferred()
func run()->void:
 var host=preload("res://demo/tests/residential_crossing_review.tscn").instantiate()
 root.add_child(host)
 for enemy in host.enemies:enemy.queue_free()
 host.enemies.clear()
 for child in host.room.get_children():
  if child is RigidBody2D:child.queue_free()
 await physics_frame
 await process_frame
 var start:Vector2=host.player.position
 var maximum_x:=start.x
 var tail_min:=INF
 var tail_max:=-INF
 for frame in hz*12:
  host.input_override={"right":1.0}
  await physics_frame
  await process_frame
  maximum_x=maxf(maximum_x,host.player.position.x)
  if frame>hz*9:
   tail_min=minf(tail_min,host.player.position.x)
   tail_max=maxf(tail_max,host.player.position.x)
 var p=host.player
 var hit:=KinematicCollision2D.new()
 var blocked:bool=p.test_move(p.global_transform,Vector2(12,0),hit)
 var actual_first_step:bool=blocked and hit.get_collider() is StaticBody2D and hit.get_collider().global_position.is_equal_approx(Vector2(1000,272.5)) and hit.get_normal().x<-.9
 var failures:=[]
 if maximum_x<850 or maximum_x>960:failures.append("HoldRight did not reach and stop at first real service barrier")
 if tail_max-tail_min>1:failures.append("Player did not remain physically blocked")
 if not actual_first_step:failures.append("No actual actor-shape collision with first solid approach step")
 if host.sector!=5:failures.append("Unexpected onward transition")
 if host.health.current_health!=60:failures.append("Geometry control received unexpected damage")
 var report:={"passed":failures.is_empty(),"failures":failures,"hz":hz,"sacrificed_sight":sacrifice,"fixture":"Sector-start; guards and movable cargo removed before measured controls solely to isolate static navigation. No player transform/velocity/health setters during input.","input":"12seconds continuousRight, nojump/noclimb/noattack","start":str(start),"finish":str(p.position),"maximum_x":maximum_x,"tail_motion":tail_max-tail_min,"actual_first_step_shape_collision":actual_first_step,"module_sha256":FileAccess.get_sha256("res://demo/areas/upper_residential_crossing.gd"),"source_sha256":FileAccess.get_sha256("res://demo/tests/residential_hold_right_control.gd")}
 var path="res://demo/evidence/residential_hold_right_%s_%dhz.json"%["traded" if sacrifice else "retained",hz]
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("RESIDENTIAL HOLD RIGHT ",report)
 quit(0 if failures.is_empty() else 1)
