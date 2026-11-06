extends SceneTree
## Production campaign Health/factory; controlled encounter geometry and placement.
## All damage below comes from autonomous melee, real projectile sweep, J-launched
## rigid cargo, or gravity crossing. No direct receive_hit/damage calls.
class RawSource extends Node:
	var raw:Dictionary={}
	func sample_raw(_actor:Node,_dt:float)->Dictionary:return raw.duplicate(true)
	func reset_intent()->void:raw.clear()
var m:Node
var hz:=60
var failures:Array[String]=[]
var receipts:Array[Dictionary]=[]
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second=hz;call_deferred("run")
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func bindings(label:String)->void:
	var p:Node=m.player
	check(p.get_node("BodyShape/IncomingStrikeReceiver")._health()==m.health,label+" melee Health authority")
	check(p.get_node("ProjectileReceiver")._health()==m.health,label+" projectile Health authority")
	check(p.get_node("PhysicalImpactReceiver")._health()==m.health,label+" cargo Health authority")
	check(p.get_node("BoundaryReceiver").get_health()==m.health,label+" boundary Health authority")
func fresh(gap:=false)->void:
	if is_instance_valid(m):m.free();paused=false;await frames(2)
	m=load("res://campaign/campaign.tscn").instantiate();m.save_enabled=false;root.add_child(m)
	m.sectors.assign([{"id":"qa_contact","title":"QA CONTACT","subtitle":"controlled geometry","text":"","hint":"","level":1,"level_name":"QA","width":1000,"theme":"interior","platforms":[],"enemies":[],"props":[],"spawn":Vector2(500,200) if gap else Vector2(75,300),"gaps":[Vector2(100,900)] if gap else []}])
	m.start_new(true);m.input_override={};receipts=[]
	m.health.damage_processed.connect(func(r):receipts.append(r.duplicate(true)))
	bindings("fixture");await frames(3)
func run()->void:
	m=load("res://campaign/campaign.tscn").instantiate();m.save_enabled=false;root.add_child(m);m.start_new(true)
	for i in m.sectors.size():m.load_sector(i);bindings(m.sectors[i].id)
	var e:=InputEventKey.new();e.physical_keycode=KEY_R;e.pressed=true;m._unhandled_key_input(e);m._physics_process(0);bindings("real retry")
	m.save_enabled=true;m._save_checkpoint();m.show_title();m.continue_run();m.save_enabled=false;bindings("real Continue")
	for ranged in [false,true]:
		await fresh()
		var enemy=load("res://demo/components/shared_sentry.tscn" if ranged else "res://demo/components/shared_sentinel.tscn").instantiate()
		enemy.position=Vector2(300 if ranged else 108,300);enemy.initial_facing=-1;enemy.attack_damage_override=12.0
		m.room.add_child(enemy);enemy.configure(m.player,m.bus)
		var before:float=m.health.current_health
		for i in hz*5:
			await frames(1)
			if not receipts.is_empty():break
		check(not receipts.is_empty() and m.health.current_health<before,("projectile" if ranged else "melee")+" authentic contact debits campaign Health")
		print("CONTACT_RECEIPTS ","projectile" if ranged else "melee"," ",receipts)
	await fresh()
	m.player.reset_actor(Vector2(280,300),-1)
	var launcher=load("res://simulation/actors/shared_actor.tscn").instantiate();launcher.position=Vector2(150,300)
	launcher.get_node("ContactConfig").profile=load("res://demo/resources/player_contact.tres").duplicate(true)
	var source:=RawSource.new();source.name="InputSource";launcher.add_child(source);m.room.add_child(launcher)
	var cargo=load("res://simulation/world/mission_cargo.tscn").instantiate();cargo.position=Vector2(184,286);cargo.collision_mask=43
	cargo.tuning=cargo.tuning.duplicate(true);cargo.tuning.launch_lift=0;cargo.tuning.launch_spin_range=Vector2.ZERO;cargo.tuning.hard_impacts_to_break=1000;m.room.add_child(cargo)
	var launches:=[0];cargo.launched.connect(func(_p):launches[0]+=1)
	await frames(10);source.raw={"attack":true};await frames(1);source.raw={}
	for i in hz*4:
		await frames(1)
		if not receipts.is_empty():break
	check(launches[0]>0,"ordinary J physically launches charged rigid cargo")
	check(not receipts.is_empty() and m.health.current_health<m.health.capacity,"actual launched cargo contact debits campaign Health")
	print("CONTACT_RECEIPTS cargo ",receipts," launches=",launches[0])
	await fresh(true)
	for i in hz*3:
		await frames(1)
		if m.state=="dead":break
	check(m.state=="dead" and m.health.current_health==0 and receipts.size()==1,"actual gravity boundary crossing causes one authenticated lethal debit")
	print("CONTACT_RECEIPTS boundary ",receipts)
	print("INCOMING_HEALTH_FAILURES "+JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
