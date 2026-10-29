extends SceneTree
var failures: Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var world:=Node2D.new()
	world.process_mode=Node.PROCESS_MODE_PAUSABLE
	root.add_child(world)
	var lift:=AnimatableBody2D.new()
	lift.set_script(load("res://demo/components/mission_lift.gd"))
	lift.position=Vector2(250,280)
	lift.travel=Vector2(0,-140)
	lift.period=6
	world.add_child(lift)
	var pc=load("res://combat_pc/player.tscn").instantiate()
	pc.automatic_physics=false
	world.add_child(pc)
	pc.reset_actor(Vector2(250,273),1)
	var start:Vector2=pc.position
	var carried:=0
	for i in 150:
		await physics_frame
		pc.physics_tick(1.0/120.0,{})
		if pc.grounded:carried+=1
	check(carried>130,"ordinary motor stays grounded on moving lift")
	check(pc.position.y<start.y-40,"lift transports actual PC upward")
	check(absf(pc.position.y-(lift.position.y-7))<1,"feet match lift collision surface")
	var frozen:Vector2=lift.position
	paused=true
	for i in 20:await physics_frame
	check(lift.position==frozen,"pause freezes lift")
	paused=false
	await physics_frame
	pc.physics_tick(1.0/120.0,{"jump":true,"right":1})
	check(pc.velocity.y<0 and not pc.grounded,"ordinary jump detaches from support")
	world.queue_free()
	await process_frame
	var f=FileAccess.open("res://demo/evidence/lift_regression.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("LIFT ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
