extends SceneTree
## Actual body sweep and gravity support; no teleport after initial fixture placement.
var hz:=60
var baseline:=false
var checks:Array=[]
var records:Array=[]
var failures:Array=[]
func check(ok:bool,label:String)->void:
	checks.append({"label":label,"passed":ok})
	if not ok:failures.append(label)
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
		if arg=="--baseline":baseline=true
	Engine.physics_ticks_per_second=hz;run.call_deferred()
func run()->void:
	for role in ["player","npc"]:
		var world:=Node2D.new();root.add_child(world)
		var floor=preload("res://simulation/world/static_platform.tscn").instantiate();floor.position=Vector2(300,220);floor.platform_size=Vector2(800,40);world.add_child(floor)
		var cargo=preload("res://simulation/world/mission_cargo.tscn").instantiate();cargo.position=Vector2(200,186);world.add_child(cargo)
		var actor=load("res://sandbox/actors/"+role+".tscn").instantiate();actor.position=Vector2(200,105)
		if role=="npc":actor.get_node("Policy").process_mode=Node.PROCESS_MODE_DISABLED
		world.add_child(actor);await frames(3)
		var contact:=KinematicCollision2D.new()
		var swept:bool=actor.test_move(Transform2D(0,Vector2(120,185)),Vector2(110,0),contact)
		var hit_cargo:bool=swept and contact.get_collider()==cargo
		check(hit_cargo,role+" actual horizontal test_move sees cargo")
		check(actor.collision_mask==9 and actor.terrain_mask==9,role+" production cargo-aware masks applied")
		check(actor.collision_mask&34==0,role+" retains intentional actor body pass-through")
		await frames(hz*2)
		var supported:bool=actor.grounded and actor._support==cargo
		check(supported,role+" lands on and remains supported by unfrozen cargo")
		check(absf(actor.position.y-172)<1.0,role+" feet match actual cargo top")
		records.append({"role":role,"mask":actor.collision_mask,"layer":actor.collision_layer,"sweep_hit_cargo":hit_cargo,"cargo_support":supported,"actor_y":actor.position.y,"cargo_y":cargo.position.y,"cargo_frozen":cargo.freeze})
		world.queue_free();await frames(3)
	var output="res://sandbox/evidence/cargo_contact_%s_%d.json"%["before" if baseline else "after",hz]
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"hz":hz,"checks":checks,"records":records,"failures":failures},"\t"))
	print("CARGO CONTACT ",hz," baseline=",baseline," failures=",failures)
	quit(0 if failures.is_empty() or baseline else 1)
