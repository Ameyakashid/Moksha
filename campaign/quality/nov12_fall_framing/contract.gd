extends SceneTree
const Rig=preload("res://campaign/presentation/camera_follow.gd")
const Baseline=preload("res://campaign/quality/nov12_fall_framing/baseline.gd")
var checks:=0
var failures:Array[String]=[]
var sector={"width":6400,"top":-1800}
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:
	for hz in [60,120]:run(hz)
	print("FALL_FRAMING_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Deterministic camera trajectories, not gameplay/native acceptance"}))
	quit(0 if failures.is_empty() else 1)
func run(hz:int)->void:
	var dt:=1.0/hz
	for kind in ["ground","ascent","short_jump","ladder"]:
		var rig=Rig.new();var base=Baseline.new()
		var p:=Vector2(1400,-800)
		rig.reset(p,sector);base.reset(p,sector)
		for i in hz*2:
			var v:=Vector2(100,0)
			if kind=="ascent":v.y=-300
			if kind=="ladder":v.y=90
			if kind=="short_jump":v.y=-120*PI*cos(float(i)*dt*PI) if i<hz else 0.0
			p+=v*dt
			var out:Vector2=rig.follow(p,v,sector,dt,kind=="ground")
			check(out.is_equal_approx(base.follow(p,v,sector,dt)),"neutral %s %d/%d"%[kind,hz,i])
	var rig=Rig.new();var base=Baseline.new()
	var p:=Vector2(1400,-1200)
	rig.reset(p,sector);base.reset(p,sector)
	var max_bias:=0.0
	for i in hz:
		p+=Vector2(0,700)*dt
		var previous:float=rig.fall_bias
		var out:Vector2=rig.follow(p,Vector2(0,700),sector,dt,false)
		base.follow(p,Vector2(0,700),sector,dt)
		check(rig.center.is_equal_approx(base.center),"baseline not fed rendered offset %d/%d"%[hz,i])
		check(rig.fall_bias<=96 and rig.fall_bias>=0,"bias bounds")
		check(absf(rig.fall_bias-previous)<=480*dt+0.001,"bias slew")
		check(p.y-out.y+180>=104 and p.y-out.y<=140.001,"feet safe")
		if p.y+1200<160:check(rig.fall_bias==0,"distance arming")
		max_bias=maxf(max_bias,rig.fall_bias)
	check(max_bias==96,"sustained fall reaches cap %d"%hz)
	var frozen:Vector2=rig.output
	var bias:float=rig.fall_bias
	check(rig.follow(p+Vector2(10,20),Vector2(0,700),sector,0,false)==frozen and rig.fall_bias==bias,"paused freezes")
	for i in int(hz*0.05):
		p.y+=50*dt;rig.follow(p,Vector2(0,50),sector,dt,false)
	check(rig.fall_armed,"slow hysteresis short")
	for i in int(hz*0.12):
		p.y+=50*dt;rig.follow(p,Vector2(0,50),sector,dt,false)
	check(not rig.fall_armed,"slow hysteresis exit")
	for i in hz:rig.follow(p,Vector2.ZERO,sector,dt,true)
	check(rig.fall_bias==0 and not rig.fall_armed,"landing settles")
	rig.reset(p,sector)
	check(rig.fall_bias==0 and rig.fall_fast_time==0 and rig.fall_slow_time==0 and not rig.fall_armed,"reset clears temporal state")
	for edge in [Vector2(0,-2000),Vector2(7000,300),Vector2(1400,-1000)]:
		rig.reset(edge,sector)
		var out:Vector2=rig.follow(edge+Vector2(0,200),Vector2(0,700),sector,10,false)
		check(out.x>=320 and out.x<=6080 and out.y>=-1620 and out.y<=180,"room bounds large delta")
		check(rig.fall_bias<=48.001,"large delta cap")
	var tele:Vector2=rig.follow(Vector2(4000,-500),Vector2(0,700),sector,dt,false)
	check(tele==Vector2(4000,-605) and rig.fall_bias==0,"teleport reset")
