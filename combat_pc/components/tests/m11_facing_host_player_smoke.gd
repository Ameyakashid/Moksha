extends SceneTree
const Player = preload("res://combat_pc/player.tscn")
const Host = preload("res://combat_pc/components/attack_entry_facing_host.gd")
const Target = preload("res://combat_pc/fixtures/chain_target.tscn")
var world: Node2D
var actor: Node2D
var host: Node2D
var target: Node2D
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(label: String, passed: bool, detail: Dictionary={}) -> void:
	checks.append({"name":label,"passed":passed,"detail":detail})
	print("PASS " if passed else "FAIL ", label, " ", detail)
func tick(frame: Dictionary={}) -> void:
	await physics_frame
	actor.physics_tick(1.0/120,frame)
	await process_frame
func reset() -> void:
	actor.reset_actor(Vector2.ZERO,1)
	host.bind_actor(actor)
	host.reset_diagnostics()
	target.reset_target()
	await tick()
func run() -> void:
	Engine.physics_ticks_per_second=120
	world=Node2D.new()
	root.add_child(world)
	var floor_body:=StaticBody2D.new()
	floor_body.position=Vector2(0,5)
	var holder:=CollisionShape2D.new()
	holder.shape=RectangleShape2D.new()
	holder.shape.size=Vector2(500,10)
	floor_body.add_child(holder)
	world.add_child(floor_body)
	actor=Player.instantiate()
	actor.automatic_physics=false
	world.add_child(actor)
	target=Target.instantiate()
	target.position=Vector2(-25,0)
	world.add_child(target)
	host=Host.new()
	world.add_child(host)
	host.bind_actor(actor)
	host.register_candidate(target,{"classification":&"opponent","eligible":true,"perceived":true,"visible":true,"local_anchor":Vector2(0,-15)})
	await reset()
	await tick({"attack":true})
	check("default_off_preserves_manual_baseline",actor.facing==1 and host.query_count==0)
	host.set_assist_enabled(true)
	await reset()
	await tick({"attack":true})
	check("real_motor_queries_and_turns_on_admitted_entry",actor.facing==-1 and host.query_count==1 and host.last_reason==&"offered",{"facing":actor.facing,"host":host.diagnostics(),"phase":actor.weapon_phase})
	for index in range(40):await tick()
	check("ordinary_contact_after_assisted_entry",target.hits==1,{"hits":target.hits})
	host.set_candidate_awareness(false,false)
	target.visible=false
	await reset()
	await tick({"attack":true})
	check("hidden_unperceived_target_does_not_turn",actor.facing==1 and host.last_reason==&"unperceived")
	host.set_candidate_awareness(true,true)
	target.visible=true
	await reset()
	await tick({"attack":true,"right":1.0})
	check("manual_intent_vetoes_provider_query",actor.facing==1 and host.query_count==0)
	var failures:=checks.filter(func(item):return not item.passed).size()
	var output:=FileAccess.open("res://combat_pc/components/tests/m11_facing_host_player_smoke_results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"passed":checks.size()-failures,"failures":failures},"\t"))
	print("HOST_MOTOR_RESULT ",checks.size()-failures,"/",checks.size())
	quit(1 if failures else 0)
