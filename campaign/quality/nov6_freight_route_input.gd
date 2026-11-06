extends RefCounted
## Observer-only recovery for an intact freight body which stopped on the higher
## approach deck. Never changes a body, receiver, objective, actor or world state.
const STILL_SECONDS := 3.0
var _cargo_id:=0
var _still_seconds:=0.0
var _last_strike_frame:=-999999

func filter_plan(host:Node,data:Dictionary,plan:Dictionary,frame:int,hz:int,events:Array[Dictionary])->Dictionary:
	if host.state!="playing" or plan.get("objective","")!="let delivery settle" or not data.has("freight"):
		_still_seconds=0.0
		return plan
	var cargo=host.room.freight_cradle.cargo
	var receiver=host.room.freight_receiver
	if not is_instance_valid(cargo) or not cargo.alive or not is_instance_valid(receiver):
		_still_seconds=0.0
		return plan
	if _cargo_id!=cargo.get_instance_id():
		_cargo_id=cargo.get_instance_id();_still_seconds=0.0;_last_strike_frame=-999999
	var local:Vector2=receiver.to_local(cargo.global_position)
	var short_and_still:bool=not receiver.is_latched and receiver.status!="seating" and local.x<0 and local.y< -25 and cargo.linear_velocity.length()<=1.0 and absf(cargo.angular_velocity)<=0.1
	if not short_and_still:
		_still_seconds=0.0
		return plan
	_still_seconds+=1.0/maxi(1,hz)
	if _still_seconds<STILL_SECONDS:return plan
	var player=host.player
	var stance:=Vector2(cargo.global_position.x-40,float(data.freight.cradle.y))
	if player.position.distance_to(stance)>10:return {"target":stance,"objective":"re-approach motionless short delivery"}
	if player.facing!=1:return {"raw":{"right":1.0}}
	if not player.grounded or absf(player.velocity.x)>20 or player.weapon_phase!=&"idle" or frame-_last_strike_frame<hz/2:return {"raw":{}}
	_last_strike_frame=frame
	events.append({"event":"observer_short_delivery_followup_strike","observer_revision":"nov6_short_delivery_v1","frame":frame,"cargo_position":str(cargo.global_position),"cargo_local_to_receiver":str(local),"hit_count":cargo.hit_count,"actor_position":str(player.position),"stationary_seconds":_still_seconds,"method":"Ordinary approach/facing/strike inputs after motionless undelivered cargo; no actor, cargo, receiver, health or objective writes."})
	return {"raw":{"attack":true}}
