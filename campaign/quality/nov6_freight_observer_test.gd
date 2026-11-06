extends SceneTree
const Observer=preload("res://campaign/quality/nov6_freight_route_input.gd")
class Cargo extends Node2D:
	var alive:=true
	var linear_velocity:=Vector2.ZERO
	var angular_velocity:=0.0
	var hit_count:=3
class Receiver extends Node2D:
	var is_latched:=false
	var status:="in_transit"
class Player extends Node2D:
	var facing:=1
	var grounded:=true
	var velocity:=Vector2.ZERO
	var weapon_phase:=&"idle"
class Cradle extends Node:
	var cargo:Node2D
class Room extends Node:
	var freight_cradle:Node
	var freight_receiver:Node2D
class Host extends Node:
	var state:="playing"
	var room:Node
	var player:Node2D
var checks:=0
var failures:Array[String]=[]
var events:Array[Dictionary]=[]
var hz:=60
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
	run.call_deferred()
func check(condition:bool,label:String)->void:
	checks+=1
	if not condition:failures.append(label);push_error(label)
func run()->void:
	var host=Host.new();root.add_child(host)
	host.room=Room.new();host.add_child(host.room)
	host.player=Player.new();host.add_child(host.player)
	host.room.freight_receiver=Receiver.new();host.room.add_child(host.room.freight_receiver)
	host.room.freight_cradle=Cradle.new();host.room.add_child(host.room.freight_cradle)
	var cargo=Cargo.new();host.room.freight_cradle.add_child(cargo);host.room.freight_cradle.cargo=cargo
	cargo.position=Vector2(3290,226);host.player.position=Vector2(3214,240);host.room.freight_receiver.position=Vector2(3370,270)
	var observer=Observer.new()
	var data:Dictionary={"freight":{"cradle":Vector2(2510,240)}}
	var plan:Dictionary={"target":Vector2(3210,240),"objective":"let delivery settle"}
	var frame:=0
	for property in ["moving","spinning","seating","delivered","inside","paused"]:
		cargo.linear_velocity=Vector2(2,0) if property=="moving" else Vector2.ZERO
		cargo.angular_velocity=1.0 if property=="spinning" else 0.0
		host.room.freight_receiver.status="seating" if property=="seating" else "in_transit"
		host.room.freight_receiver.is_latched=property=="delivered"
		cargo.position.y=256 if property=="inside" else 226
		host.state="paused" if property=="paused" else "playing"
		for tick in hz*4:
			frame+=1
			observer.filter_plan(host,data,plan,frame,hz,events)
		check(events.is_empty() and observer._still_seconds==0,"preserve normal wait while "+property)
	host.state="playing";cargo.position.y=226
	for tick in hz*2:frame+=1;check(observer.filter_plan(host,data,plan,frame,hz,events)==plan,"no recovery before stable wait "+str(tick))
	var answer:Dictionary={}
	for tick in hz+2:frame+=1;answer=observer.filter_plan(host,data,plan,frame,hz,events)
	check(answer.get("target")==Vector2(3250,240),"stationary short cargo gets ordinary approach target")
	host.player.position=Vector2(3250,240);host.player.facing=-1;frame+=1
	check(observer.filter_plan(host,data,plan,frame,hz,events).get("raw")=={"right":1.0},"face cargo with ordinary movement")
	host.player.facing=1;host.player.velocity.x=21;frame+=1
	check(observer.filter_plan(host,data,plan,frame,hz,events).get("raw")=={},"settle actor before strike")
	host.player.velocity=Vector2.ZERO;host.player.weapon_phase=&"active";frame+=1
	check(observer.filter_plan(host,data,plan,frame,hz,events).get("raw")=={},"wait for existing attack to end")
	host.player.weapon_phase=&"idle";frame+=1
	check(observer.filter_plan(host,data,plan,frame,hz,events).get("raw")=={"attack":true},"fresh ordinary strike after stable short delivery")
	frame+=1
	check(observer.filter_plan(host,data,plan,frame,hz,events).get("raw")=={},"do not repeat held strike")
	check(events.size()==1 and events[0].stationary_seconds>=3,"one transparent observer receipt")
	check(cargo.position==Vector2(3290,226) and cargo.hit_count==3 and cargo.alive and not host.room.freight_receiver.is_latched,"observer leaves cargo and receiver untouched")
	check(observer.filter_plan(host,data,{"raw":{}},frame,hz,events)=={"raw":{}} and observer._still_seconds==0,"normal planner output resets recovery")
	print("NOV6_FREIGHT_OBSERVER_RESULT "+JSON.stringify({"hz":hz,"checks":checks,"passed":failures.is_empty(),"failures":failures,"scope":"Explicit lightweight observer-state fixtures; real physical recovery is tested separately."}))
	host.free();quit(0 if failures.is_empty() else 1)
