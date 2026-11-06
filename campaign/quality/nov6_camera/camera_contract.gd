extends SceneTree
const Rig=preload("res://campaign/presentation/camera_follow.gd")
var count:=0
var failures:Array[String]=[]
var sector:={"width":6400,"top":-800}
func _initialize()->void:
	for hz in [60,120]:_run(hz)
	print("CAMERA_CONTRACT_RESULT ",JSON.stringify({"checks":count,"failures":failures,"passed":failures.is_empty(),"scope":"Presentation-only mathematical trajectory checks; not native motion acceptance"}))
	quit(0 if failures.is_empty() else 1)
func check(ok:bool,label:String)->void:
	count+=1
	if not ok:failures.append(label)
func _run(hz:int)->void:
	var dt:=1.0/hz
	var rig=Rig.new()
	check(rig.reset(Vector2(75,300),sector)==Vector2(320,180),"spawn bounds %d"%hz)
	check(rig.reset(Vector2(6380,300),sector)==Vector2(6080,180),"right bounds %d"%hz)
	check(rig.reset(Vector2(1500,-1000),sector)==Vector2(1500,-620),"top bounds %d"%hz)
	check(rig.reset(Vector2(20,20),{"width":200,"top":300})==Vector2(320,180),"small district bounds %d"%hz)
	rig.reset(Vector2(1500,300),sector)
	var initial:Vector2=rig.center
	for i in hz:
		var foot:=300.0-120.0*sin(float(i)/float(hz)*PI)
		rig.follow(Vector2(1500,foot),Vector2.ZERO,sector,dt)
	check(is_equal_approx(rig.center.y,initial.y),"120px jump stays inside framing window %d"%hz)
	var position:=Vector2(1500,300)
	for i in hz:
		position.x+=218.0*dt;rig.follow(position,Vector2(218,0),sector,dt)
	var before:Vector2=rig.center
	position.x-=218.0*dt
	var after:Vector2=rig.follow(position,Vector2(-218,0),sector,dt)
	check(absf(after.x-before.x)<6,"direction reversal camera step under six pixels %d"%hz)
	check(rig.lookahead>0,"lookahead does not flip in one tick %d"%hz)
	for i in hz:
		position.x-=218.0*dt;rig.follow(position,Vector2(-218,0),sector,dt)
	check(rig.lookahead<0,"lookahead follows sustained reversal %d"%hz)
	check(absf(position.x-rig.center.x)<40,"sustained run keeps actor near horizontal center %d"%hz)
	var saved:Vector2=rig.center
	rig.follow(position+Vector2(50,-50),Vector2(218,-300),sector,0)
	check(rig.center==saved,"zero delta does not move camera %d"%hz)
	rig.reset(Vector2(1500,-400),sector)
	position=Vector2(1500,-400)
	for i in hz:
		position.y+=700.0*dt
		var camera_position:Vector2=rig.follow(position,Vector2(0,700),sector,dt)
		check(position.y-camera_position.y<=140.001,"fast fall remains in safe viewport %d/%d"%[hz,i])
		check(camera_position.y>=-620 and camera_position.y<=180,"fall vertical bounds %d/%d"%[hz,i])
	var teleported:Vector2=rig.follow(Vector2(5000,-300),Vector2.ZERO,sector,dt)
	check(teleported==Vector2(5000,-405),"large respawn snaps without flythrough %d"%hz)
	var input_position:=Vector2(2000,-100)
	var input_velocity:=Vector2(280,-200)
	var data_before:=sector.duplicate(true)
	rig.follow(input_position,input_velocity,sector,dt)
	check(input_position==Vector2(2000,-100) and input_velocity==Vector2(280,-200) and sector==data_before,"presentation has no gameplay writes %d"%hz)
