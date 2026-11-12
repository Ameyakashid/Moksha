extends SceneTree
const View=preload("res://campaign/presentation/foundry_atmosphere.gd")
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var v=View.new();root.add_child(v)
	seed(789);var expected=randi();seed(789)
	v.configure({"id":"l2_thermal_foundry"})
	check(randi()==expected,"No global RNG consumption")
	var key=v.seed_value;var tint=v.plate_tint
	v.configure({"id":"l2_thermal_foundry"})
	check(v.seed_value==key,"Deterministic identity")
	v.configure({"id":"l2_freight"})
	check(v.seed_value!=key and v.plate_tint!=tint,"Thermal versus freight treatment")
	check(v.get_child_count()==0,"No worker physics or per-person nodes")
	check(v.MAX_VISIBLE_WORKERS==9,"Bounded draw population")
	v.hide();var time=v.visual_time;v._process(10)
	check(v.visual_time==time,"Hidden view does not tick")
	v.show();v._process(.1);check(v.visual_time>time,"Visible animation")
	v.set_view(Vector2(1200,-100),Vector2(640,360))
	check(v.camera_center==Vector2(1200,-100),"Explicit camera only")
	v.free()
	print("NOV12_FOUNDRY ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)
