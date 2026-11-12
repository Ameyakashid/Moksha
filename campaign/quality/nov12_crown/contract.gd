extends SceneTree
const View=preload("res://campaign/presentation/crown_atmosphere.gd")
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var v=View.new();root.add_child(v)
	seed(789);var expected=randi();seed(789)
	v.configure({"id":"crown_last_warden"})
	check(randi()==expected,"No global RNG consumption")
	check(v.warden_profile,"Warden uses subdued authority profile")
	var key=v.seed_value;var tint=v.plate_tint
	v.configure({"id":"crown_last_warden"})
	check(v.seed_value==key,"Deterministic identity")
	v.configure({"id":"crown_ascent"})
	check(not v.warden_profile,"Ascent has separate profile")
	check(v.seed_value!=key and v.plate_tint!=tint,"District treatment")
	check(v.get_child_count()==0,"No staff nodes or gameplay children")
	check(not v.is_processing(),"No visible frame ticks")
	v.hide();check(not v.is_processing(),"No hidden frame ticks")
	v.show();check(not v.is_processing(),"Showing does not start simulation")
	v.set_view(Vector2(1200,-900),Vector2(640,360))
	check(v.camera_center==Vector2(1200,-900),"Explicit high camera position")
	check(v.viewport_size==Vector2(640,360),"Explicit viewport bounds")
	v.set_view(Vector2(1e6,300),Vector2(1280,720))
	check(v.camera_center.x==1e6,"Camera does not depend on district width")
	v.free();print("NOV12_CROWN ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
