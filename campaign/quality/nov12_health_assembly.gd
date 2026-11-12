extends SceneTree
## Assembly/lifetime observations plus authentic gravity-driven lethal contact.
class TracedCampaign:
	extends "res://campaign/logic/campaign.gd"
	var defeat_trace:Array=[]
	func _on_defeat()->void:
		defeat_trace.append({"state":state,"active":player.get_node("DefeatResponse").active})
		super._on_defeat()
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	call_deferred("run")
func bindings(host:Node,label:String,campaign:bool)->void:
	var player:Node=host.player
	var health:Node=host.health
	check(player.find_children("Health","",false,false).size()==1,label+" one health child")
	check(health.get_bound_actor()==player,label+" health bound to actor")
	check(player.get_node("DefeatResponse")._health()==health,label+" defeat authority")
	check(player.get_node("BodyShape/IncomingStrikeReceiver")._health()==health,label+" incoming authority")
	check(player.get_node("PhysicalImpactReceiver")._health()==health,label+" physical authority")
	check(player.get_node("BoundaryReceiver").get_health()==health,label+" boundary authority")
	check(player.get_node("ProjectileReceiver")._health()==health,label+" projectile authority")
	var subscribers:=0
	for connection in player.get_signal_connection_list("damage_resolved"):
		if connection.callable.get_object()==health:subscribers+=1
	check(subscribers==1,label+" one health damage subscriber")
	var depleted:Array=health.get_signal_connection_list("depleted")
	if campaign:
		check(health.get_script().resource_path=="res://campaign/logic/build_health.gd",label+" campaign adapter")
		check(depleted.size()==2 and depleted[0].callable.get_object()==host and depleted[1].callable.get_object()==player.get_node("DefeatResponse"),label+" preserved depletion callback order")
	else:
		check(health.get_script().resource_path=="res://combat_pc/components/health_component.gd" and health.capacity==60,label+" demo health type/capacity")
func run()->void:
	var demo=load("res://demo/mission.tscn").instantiate();demo.save_enabled=false;root.add_child(demo);demo.start_new(true)
	bindings(demo,"demo",false);demo.free();paused=false
	var host:=TracedCampaign.new();host.save_enabled=false;root.add_child(host);host.start_new(true);host.input_override={}
	bindings(host,"campaign",true)
	for lens in ["neutral","agility","strength"]:
		var old:WeakRef=weakref(host.health)
		host.lens=lens;host.load_sector(0)
		check(old.get_ref()==null,"old health retired "+lens)
		bindings(host,"reload "+lens,true)
		var capacity:float={"neutral":60.0,"agility":50.0,"strength":75.0}[lens]
		check(host.health.capacity==capacity and host.health.current_health==capacity,"build capacity/refill "+lens)
	host.save_enabled=true;host._save_checkpoint();host.show_title();host.continue_run();host.save_enabled=false
	bindings(host,"Continue",true)
	host.sectors.assign([{"id":"assembly_gap","title":"ASSEMBLY","subtitle":"","text":"","hint":"","level":1,"level_name":"QA","width":1000,"theme":"interior","platforms":[],"enemies":[],"props":[],"spawn":Vector2(500,200),"gaps":[Vector2(100,900)]}])
	host.load_sector(0);host.defeat_trace.clear()
	var deaths_before:int=host.deaths
	var receipts:Array=[];host.health.damage_processed.connect(func(r):receipts.append(r.duplicate(true)))
	for i in Engine.physics_ticks_per_second*3:
		await physics_frame;await process_frame
		if host.state=="dead":break
	check(host.state=="dead" and host.deaths==deaths_before+1 and receipts.size()==1,"gravity delivers one lethal debit/death")
	check(host.defeat_trace==[{"state":"playing","active":false},{"state":"dead","active":true}],"preserved campaign depletion then defeat policy ordering")
	print("NOV12_ASSEMBLY_RESULT "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"trace":host.defeat_trace,"hz":Engine.physics_ticks_per_second}))
	host.free();paused=false;quit(0 if failures.is_empty() else 1)
