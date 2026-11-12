extends SceneTree
class FakeHealth extends RefCounted:
	var current_health:=60.0
class FakeActor extends Node2D:
	var main_action:=&"locomotion"
	var grounded:=true
	func is_on_floor()->bool:return false # Production custom solver does not use native floor flag.
class FakeEnemy extends Node2D:
	var dead:=false
	var kind:="captain_lancer"
class FakeHost extends Node2D:
	signal companion_presentation_accepted(id:String,blocked:bool)
	var hud:Node
	var session_generation:=0
	var state:="playing"
	var sectors:=[{"id":"city_clinic"}]
	var sector:=0
	var player:=FakeActor.new()
	var camera:=Node2D.new()
	var room:=Node2D.new()
	var health=FakeHealth.new()
	var enemies:Array=[]
	var notice_left:=0.0
	var chapter_left:=0.0
	var blind:=false
	var relay_on:=false
	var done:Dictionary={}
	func goal_done(id:String)->bool:return done.has(id)
	func _nearby_objective()->Node:return null
var checks:=0
var failures:Array[String]=[]
func check(v:bool,label:String)->void:
	checks+=1
	if not v:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var h=FakeHost.new();h.hud=h;root.add_child(h);h.add_child(h.player);h.add_child(h.room);h.add_child(h.camera)
	var o=load("res://campaign/narrative/companion_observer.gd").new();h.add_child(o);o.bind(h)
	check(o.events("city_clinic").is_empty(),"no fabricated cell")
	h.done.cell=true;check(o.events("city_clinic")==["clinic_cell"],"actual cell")
	h.done.generator=true;check(o.events("city_clinic").is_empty(),"goal alone cannot claim open street")
	var door=load("res://campaign/logic/objective_door.tscn").instantiate();door.position.x=2850;h.room.add_child(door)
	door.opened=true;check(o.events("city_clinic").is_empty(),"pending collision cannot claim open street")
	door.get_node("CollisionShape2D").disabled=true
	check(o.events("city_clinic")==["clinic_power"],"actual opened disabled door")
	h.done.patients=true;check(o.events("city_clinic")==["clinic_rescue"],"rescue precedence")
	o.sight_chosen(false);check(o.events("city_clinic").has("sight_kept"),"choice observed")
	check(not o.events("city_tram_depot").has("sight_kept"),"choice room-local")
	o.reset_session();check(o.choice_event.is_empty(),"continue reset")
	o.observed_session=0;o.ui_blocked=false;o._process(3);o._process(3)
	var snapshot={"state":"playing","notice_visible":true,"notice":"IMPORTANT","prompt":""}
	o.decorate(snapshot);check(snapshot.notice=="IMPORTANT" and o.director.seen.is_empty(),"notice wins")
	snapshot={"state":"playing","notice_visible":false,"prompt":"Use relay"};o.decorate(snapshot);check(not snapshot.notice_visible,"interaction wins")
	snapshot={"state":"playing","notice_visible":false,"prompt":""};o.decorate(snapshot);h.companion_presentation_accepted.emit("",false);o._process(3);o._process(3);o.decorate(snapshot)
	check(snapshot.get("notice","").begins_with("Intellect:"),"display eligible")
	check(o.director.seen.is_empty(),"snapshot query does not consume")
	h.companion_presentation_accepted.emit(snapshot.companion_line_id,false)
	check(o.director.seen.has("clinic_rescue"),"HUD accepted ack")
	h.state="paused";o._process(1);check(o.director.text().is_empty() and not o.mote.visible,"pause hides")
	h.state="playing";h.blind=true;o.ui_blocked=false;o._process(1);check(not o.mote.visible,"blind has no visual mote")
	h.health.current_health=50;o._process(.1);check(not o.safe,"damage defers")
	check(h.done=={"cell":true,"generator":true,"patients":true} and h.player.position==Vector2.ZERO and h.health.current_health==50,"observer no gameplay writes")
	h.player.position=Vector2(900,190);h.player.grounded=false
	check(o.events("rainline").is_empty(),"midair not roof traversal")
	h.player.grounded=true;check(o.events("rainline")==["rain_roof"],"supported roof")
	h.player.position.y=300;o.no_progress=19;check(o.events("rainline").is_empty(),"no early nag")
	o.no_progress=21;check(o.events("rainline")==["rain_street"],"stalled supported reminder")
	h.relay_on=true;check(not o.events("rainline").has("rain_street"),"lit relay removes reminder");h.relay_on=false
	var captain=FakeEnemy.new();h.add_child(captain);captain.position=Vector2(2000,300);h.enemies=[captain];h.camera.position=Vector2(1200,180);h.blind=false
	check(not o.events("quarantine_intake").has("captain"),"offscreen captain cannot speak")
	h.camera.position=Vector2(1800,180);check(o.events("quarantine_intake").has("captain"),"onscreen captain")
	h.blind=true;check(not o.events("quarantine_intake").has("captain"),"blind cannot reveal captain")
	h.session_generation+=1;o._process(.1);check(o.director.seen.is_empty(),"same-frame session generation clears seen")
	h.free();print("OBSERVER_FIXTURE_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
