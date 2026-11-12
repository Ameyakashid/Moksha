extends SceneTree
const View=preload("res://campaign/presentation/cistern_atmosphere.gd")
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var v=View.new();root.add_child(v)
	seed(789);var expected=randi();seed(789)
	v.configure({"id":"l3_homes"})
	check(randi()==expected,"No global RNG consumption")
	check(v.residential_profile,"Homes framing exposes occupied windows")
	var key=v.seed_value;var tint=v.plate_tint
	v.configure({"id":"l3_homes"})
	check(v.seed_value==key,"Deterministic identity")
	v.configure({"id":"l3_cistern"})
	check(not v.residential_profile,"Cistern keeps waterworks framing")
	check(v.seed_value!=key and v.plate_tint!=tint,"Residential versus cistern treatment")
	check(v.get_child_count()==0,"No worker physics or per-person nodes")
	check(v.MAX_DRIPS==6,"Bounded atmospheric motion")
	v.hide();var time=v.visual_time;v._process(10)
	check(v.visual_time==time,"Hidden view does not tick")
	v.show();v._process(.1);check(v.visual_time>time,"Visible animation")
	v.set_view(Vector2(1200,-100),Vector2(640,360))
	check(v.camera_center==Vector2(1200,-100),"Explicit camera only")
	v.free()
	print("NOV12_CISTERN ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)
