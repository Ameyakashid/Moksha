extends SceneTree
## Actual Godot physics-frame acceptance for original MOKSHA movement tuning.
## Dead Cells grounds feature intent only; no numerical or executable parity claim.
const PLAYER = preload("res://combat_pc/player.tscn")
const SURFACE = preload("res://combat_pc/fixtures/test_surface.tscn")
const RAMP = preload("res://combat_pc/fixtures/ramp.gd")
class PhysicsDriver extends Node:
	var actor: Node
	var frame: Variant = {}
	var ticks := 0
	var enabled := true
	var moving_probes: Array = []
	func _physics_process(dt: float) -> void:
		if enabled and is_instance_valid(actor):
			for body in actor.get_parent().get_children():
				if body is AnimatableBody2D and body.get("moving"):
					var x: float=body.global_position.x+body.size.x*.5
					var ray=PhysicsRayQueryParameters2D.create(Vector2(x,body.global_position.y-4),Vector2(x,body.global_position.y+4),1)
					var hit=actor.get_world_2d().direct_space_state.intersect_ray(ray)
					var server: Transform2D=PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
					moving_probes.append({"tick":ticks,"node":body.global_position,"server":server.origin,"ray":hit.get("position",Vector2.INF)})
			if not actor.automatic_physics: actor.physics_tick(dt,frame)
			ticks+=1
var world: Node2D
var actor: Node
var driver: PhysicsDriver
var sync_platforms_override := false
var hz := 120
var dt := 1.0/120.0
var checks := 0
var failures: Array[String] = []
var scenarios: Array[Dictionary] = []
var name_ := ""
var frames: Array[Dictionary] = []
var assertions: Array[Dictionary] = []
var events: Array[Dictionary] = []
var measurements := {}
var one_way_rids: Array[RID] = []
var start_failures := 0
var start_checks := 0
var starting_hashes := {}
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz=int(argument.trim_prefix("--hz="))
		if argument=="--sync-platforms":sync_platforms_override=true
	Engine.physics_ticks_per_second=hz
	dt=1.0/hz
	_run.call_deferred()
func _run() -> void:
	for path in ["res://combat_pc/player.gd","res://combat_pc/resources/movement_profile.gd","res://combat_pc/resources/movement_profile.tres"]:starting_hashes[path]=FileAccess.get_sha256(path)
	await _ground_response()
	await _jump_flow()
	await _coyote_and_buffer()
	await _crouch_and_walls()
	await _one_way_and_slope()
	await _slope_reverse_and_crouch()
	await _ledge_flow()
	await _ledge_adversaries()
	await _extra_adversaries()
	await _permission_and_reset()
	await _native_input()
	var profile_values := {}
	var profile = load("res://combat_pc/resources/movement_profile.tres")
	for property in profile.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: profile_values[property.name]=profile.get(property.name)
	var hashes := {}
	for path in ["res://combat_pc/player.gd","res://combat_pc/player.tscn","res://combat_pc/resources/movement_profile.gd","res://combat_pc/resources/movement_profile.tres","res://combat_pc/tests/movement_regression.gd","res://combat_pc/fixtures/test_surface.gd","res://combat_pc/fixtures/ramp.gd"]: hashes[path]=FileAccess.get_sha256(path)
	var stable := true
	for path in starting_hashes:stable=stable and starting_hashes[path]==hashes[path]
	if not stable:failures.append("Production files changed while test ran; rerun required")
	var report := {"production_hash_stable_during_run":stable,"starting_hashes":starting_hashes,"milestone":1,"target":"Original MOKSHA movement grounded in audited Dead Cells feature intent","numeric_source":"All tuning comes from MOKSHA profile, not recovered Dead Cells constants","physics_hz":hz,"experimental_sync_platforms_override":sync_platforms_override,"engine":Engine.get_version_info(),"generated_utc":Time.get_datetime_string_from_system(true),"execution":"Actual Godot physics callbacks; fixture priority-20, test driver+20; production physics_tick uses engine delta and real space/sweeps","checks":checks,"failures":failures,"scenarios":scenarios,"profile":profile_values,"hashes":hashes,"limits":["No Dead Cells executable comparison or exact-feel claim","Native visual review belongs to parent; this is headless motion/geometry acceptance","Roll, attacks, parry, dive and damage are not implemented or counted here","Hitpause-specific API absent at initial checkpoint; future combat integration remains pending"]}
	FileAccess.open("res://combat_pc/tests/results_%dhz%s.json" % [hz,"_sync_experiment" if sync_platforms_override else ""],FileAccess.WRITE).store_string(JSON.stringify(_safe(report),"  "))
	print("MOKSHA MOVEMENT %dHz: %d scenarios, %d checks, %d failures" % [hz,scenarios.size(),checks,failures.size()])
	for fail in failures:printerr(fail)
	quit(0 if failures.is_empty() else 1)
func _begin(label: String,at:=Vector2(100,200),floor_present:=true) -> void:
	name_=label;frames=[];assertions=[];events=[];measurements={};one_way_rids=[];start_failures=failures.size();start_checks=checks
	world=Node2D.new();root.add_child(world)
	if floor_present:_surface(Vector2(-1000,200),Vector2(3000,40))
	actor=PLAYER.instantiate();actor.position=at;actor.automatic_physics=false;world.add_child(actor)
	actor.movement_event.connect(func(event_name: StringName,payload: Dictionary):events.append({"event":String(event_name),"tick":driver.ticks if is_instance_valid(driver) else 0,"data":_safe(payload)}))
	driver=PhysicsDriver.new();driver.actor=actor;driver.process_physics_priority=20;world.add_child(driver)
	await _step({},2)
func _surface(at: Vector2,size: Vector2,one_way:=false) -> Node:
	var body=SURFACE.instantiate();body.position=at;body.size=size;body.one_way=one_way;world.add_child(body)
	if sync_platforms_override:body.sync_to_physics=true
	if one_way:one_way_rids.append(body.get_rid())
	return body
func _ramp(at: Vector2,width:=96.0,rise:=36.0) -> Node:
	var body=StaticBody2D.new();body.set_script(RAMP);body.position=at;body.width=width;body.rise=rise
	var shape=CollisionPolygon2D.new();shape.name="Shape";body.add_child(shape);world.add_child(body)
	return body
func _step(frame: Variant={},count:=1) -> void:
	driver.frame=frame
	for _i in count:
		var target=driver.ticks+1
		while driver.ticks<target:
			await physics_frame
			await process_frame
		var snapshot: Dictionary=actor.telemetry()
		snapshot["tick"]=driver.ticks;snapshot["input"]=_safe(frame)
		frames.append(_safe(snapshot))
func _seconds(frame: Variant,seconds: float) -> void:
	await _step(frame,maxi(1,ceili(seconds/dt)))
func _finish() -> void:
	if not driver.moving_probes.is_empty():measurements["moving_space_probe"]=_safe(driver.moving_probes)
	scenarios.append({"name":name_,"checks":checks-start_checks,"failures":failures.size()-start_failures,"assertions":assertions,"measurements":measurements,"events":events,"frames":frames})
	driver.enabled=false
	world.queue_free()
	await physics_frame
	await process_frame
	world=null;actor=null;driver=null
func _check(value: bool,label: String) -> void:
	checks+=1;assertions.append({"passed":value,"label":label})
	if not value:
		failures.append(name_+": "+label);printerr("FAIL: "+failures.back())
func _near(value: float,expected: float,tolerance: float,label: String) -> void:
	_check(absf(value-expected)<=tolerance,"%s actual%.4f expected%.4f ±%.4f" % [label,value,expected,tolerance])
func _count(event_name: String) -> int:
	var count:=0
	for event in events:
		if event.event==event_name:count+=1
	return count
func _safe(value: Variant) -> Variant:
	if value is Vector2:return [value.x,value.y]
	if value is Array:
		var a=[]
		for item in value:a.append(_safe(item))
		return a
	if value is Dictionary:
		var d={}
		for key in value:d[str(key)]=_safe(value[key])
		return d
	if value is Object:return str(value)
	return value
func _solid_overlap() -> bool:
	var query=PhysicsShapeQueryParameters2D.new();var shape=RectangleShape2D.new()
	shape.size=Vector2(actor.profile.body_width-0.12,actor.body_height-0.12)
	query.shape=shape;query.transform=Transform2D(0,actor.global_position+Vector2(0,-actor.body_height*.5));query.collision_mask=1
	query.exclude=[actor.get_rid()]
	for rid in one_way_rids:query.exclude.append(rid)
	return not actor.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
func _direction(dir: int,extra: Dictionary={}) -> Dictionary:
	return ({"right":1.0} if dir>0 else {"left":1.0}).merged(extra)
func _ground_response() -> void:
	for dir in [-1,1]:
		await _begin("run brake reverse %d" % dir)
		var p=actor.profile
		await _seconds(_direction(dir),p.run_speed/p.ground_acceleration+2*dt)
		_near(actor.velocity.x,dir*p.run_speed,.01,"run reaches authored cap")
		await _step(_direction(-dir))
		_check(actor.facing==-dir and signf(actor.velocity.x)==dir,"facing follows opposite input while velocity still brakes")
		_check(actor.pose==&"turn","actual reversal selects turn pose")
		await _seconds(_direction(-dir),2*p.run_speed/p.reversal_acceleration+2*dt)
		_near(actor.velocity.x,-dir*p.run_speed,.01,"reversal reaches other run cap")
		var before: Vector2=actor.global_position;var ticks:=0
		while absf(actor.velocity.x)>.01 and ticks<hz:
			await _step();ticks+=1
		measurements={"stop_seconds":ticks*dt,"stop_distance":absf(actor.global_position.x-before.x)}
		_check(ticks*dt<=p.run_speed/p.ground_braking+2*dt,"short stop duration follows authored braking")
		_check(absf(actor.global_position.x-before.x)<=p.run_speed*p.run_speed/(2*p.ground_braking)+p.run_speed*dt,"stop distance bounded by authored deceleration")
		_check(actor.grounded and not _solid_overlap(),"ground support and collision remain coherent")
		await _finish()
func _jump_flow() -> void:
	var apexes:=[]
	for hold in [false,true]:
		await _begin("held jump" if hold else "tap jump")
		var ground_y: float=actor.global_position.y
		await _step({"jump":true},maxi(1,roundi(hz/30.0)))
		_check(_count("ground_jump")==1 and actor.velocity.y<0,"fresh ground press launches once")
		var apex: float=actor.global_position.y;var air_time:=0.0
		for _i in range(hz*2):
			await _step({"jump":hold});air_time+=dt;apex=minf(apex,actor.global_position.y)
			if actor.grounded:break
		apexes.append(ground_y-apex);measurements={"apex_height":ground_y-apex,"air_seconds":air_time}
		_check(actor.grounded and actor.air_jumps_left==actor.profile.air_jump_count,"landing restores finite air jump budget")
		_check(_count("ground_jump")==1 and _count("air_jump")==0,"held press does not auto-consume air jump or repeat on landing")
		if hold:_check(apexes[1]>apexes[0]+actor.profile.standing_height*.4,"held jump rises meaningfully above release-limited tap")
		await _finish()
	await _begin("finite double jump and air steering")
	await _step({"jump":true});await _seconds({},.05)
	await _step({"jump":true,"right":1.0})
	_check(_count("air_jump")==1 and actor.air_jumps_left==actor.profile.air_jump_count-1,"fresh airborne press spends one air jump")
	await _step();await _step({"jump":true})
	_check(_count("air_jump")==1,"third press cannot exceed jump budget")
	await _seconds({"left":1.0},.12)
	_check(actor.facing==-1 and actor.velocity.x<0,"air input changes facing and steering")
	await _finish()
func _coyote_and_buffer() -> void:
	for within in [true,false]:
		await _begin("coyote window " + str(within),Vector2(100,200),false)
		_surface(Vector2(0,200),Vector2(110,30));await _step({},2)
		actor.velocity.x=actor.profile.run_speed
		while actor.grounded:await _step({"right":1.0})
		await _seconds({"right":1.0},actor.profile.coyote_seconds*(.25 if within else 1.5))
		await _step({"right":1.0,"jump":true})
		_check(_count("ground_jump")== (1 if within else 0) and _count("air_jump")== (0 if within else 1),"late input selects ground grace only within authored time window")
		await _finish()
	await _begin("landing jump buffer once",Vector2(100,188),true)
	actor.air_jumps_left=0;actor.velocity.y=140
	await _step({"jump":true})
	await _seconds({"jump":true},actor.profile.jump_buffer_seconds)
	_check(_count("ground_jump")==1 and _count("air_jump")==0,"unavailable airborne press is consumed on first safe landing")
	await _seconds({"jump":true},1.0)
	_check(_count("ground_jump")==1,"buffered held press does not repeat after next landing")
	await _finish()
func _crouch_and_walls() -> void:
	await _begin("crouch tunnel release and safe standing")
	var roof=_surface(Vector2(130,200-22-12),Vector2(80,12));await _step()
	await _seconds({"right":1.0,"down":1.0},.55)
	_check(actor.crouched and actor.global_position.x>140,"crouch passes through22px tunnel")
	await _step()
	_check(actor.crouched and not actor.can_stand() and not _solid_overlap(),"released crouch stays small under blocked headroom")
	roof.queue_free();await _step({},2)
	_check(not actor.crouched and actor.can_stand(),"removing obstruction permits standing")
	await _finish()
	for dir in [-1,1]:
		await _begin("thin wall sweep %d" % dir,Vector2(100,200),true)
		_surface(Vector2(150 if dir==1 else 46,20),Vector2(4,180));await _step()
		await _seconds(_direction(dir),.6)
		_check(actor.global_position.x<=150-actor.profile.body_width*.5+.15 if dir==1 else actor.global_position.x>=50+actor.profile.body_width*.5-.15,"continuous motion cannot tunnel through4px wall")
		_check(not _solid_overlap(),"wall collision does not leave body embedded")
		await _finish()
func _one_way_and_slope() -> void:
	await _begin("one-way upward crossing then landing")
	var platform=_surface(Vector2(40,160),Vector2(140,6),true);await _step()
	await _step({"jump":true});var crossed:=false
	for _i in range(hz*2):
		await _step({"jump":true});crossed=crossed or actor.global_position.y<160
		if actor.grounded and actor.global_position.y<180:break
	_check(crossed and actor.grounded and absf(actor.global_position.y-160)<.2,"jump crosses upward one-way then lands on its top")
	await _finish()
	await _begin("slope ascent support and ground jump",Vector2(105,200),true)
	_ramp(Vector2(120,200));await _step()
	await _seconds({"right":1.0},.32)
	measurements={"position_before_jump":actor.global_position,"grounded_before_jump":actor.grounded,"velocity_before_jump":actor.velocity}
	_check(actor.global_position.y<195 and actor.grounded,"continuous uphill movement remains grounded")
	var jumps=_count("ground_jump");var air=_count("air_jump")
	await _step({"right":1.0,"jump":true})
	_check(_count("ground_jump")==jumps+1 and _count("air_jump")==air,"jump from sustained ascent uses ground jump rather than air budget")
	await _finish()
func _reach_ledge(dir:=1,blocked:=false) -> Node:
	await _begin("ledge setup",Vector2(180-dir*50,200),true)
	var ledge=_surface(Vector2(180 if dir==1 else 100,130),Vector2(80,70))
	if blocked:_surface(Vector2(170 if dir==1 else 90,92),Vector2(100,16))
	await _step()
	for _i in range(hz):
		await _step(_direction(dir,{"jump":true}))
		if actor.main_action==&"ledge":return ledge
	return ledge
func _ledge_flow() -> void:
	for dir in [-1,1]:
		await _reach_ledge(dir);name_="connected jump catch hang pull %d" % dir
		_check(actor.main_action==&"ledge" and _count("ledge_catch")==1,"running jump reaches actual ledge catch")
		var catch_height: float=actor.global_position.y
		await _seconds({},actor.profile.ledge_catch_seconds+.05)
		_check(actor.main_action==&"ledge" and actor.action_phase==&"hang","neutral input holds ledge without automatic pull")
		_check(actor.global_position.y<=catch_height+.1,"near-successful arrival is not pulled downward to a lower nominal hang")
		var hang: Vector2=actor.global_position;var anchor: Vector2=actor.ledge_anchor
		await _seconds({},.12)
		_check(actor.global_position.distance_to(hang)<.2,"neutral hang has stable anchored root")
		var before_tick=driver.ticks;var overlapped:=false;var biggest_step:=0.0
		for _i in range(hz):
			var old: Vector2=actor.global_position
			await _step({"up":1.0});overlapped=overlapped or _solid_overlap();biggest_step=maxf(biggest_step,old.distance_to(actor.global_position))
			if _count("pullup_end")>0:break
		measurements={"pull_seconds":(driver.ticks-before_tick)*dt,"largest_root_step":biggest_step,"anchor":anchor}
		_check(_count("pullup_end")==1 and actor.grounded,"pull and step phases finish supported on the ledge")
		_check(not overlapped and actor.global_position.y<=anchor.y+.2,"mantle path is collision-safe and ends on top")
		_check((driver.ticks-before_tick)*dt>=actor.profile.ledge_pull_seconds+actor.profile.ledge_step_seconds-dt,"pull-up consumes authored phase duration rather than teleporting")
		_near((driver.ticks-before_tick)*dt,(ceili(actor.profile.ledge_pull_seconds/dt)+ceili(actor.profile.ledge_step_seconds/dt)+1)*dt,dt*1.01,"pull time matches frame-quantized authored phase durations")
		await _finish()
func _ledge_adversaries() -> void:
	await _reach_ledge(1,true);name_="blocked headroom remains releasable"
	_check(actor.main_action==&"ledge","blocked top still permits legitimate hang")
	await _seconds({"up":1.0},.5)
	_check(actor.main_action==&"ledge" and _count("pullup_blocked")>0 and not _solid_overlap(),"blocked mantle stays safe and reports blocked pull")
	await _step({"down":1.0,"jump":true})
	_check(actor.main_action!=&"ledge" and _count("ledge_release")==1,"down release wins over simultaneous jump pull request")
	await _finish()
	for variant in ["moving","removed","away","interrupted"]:
		var ledge=await _reach_ledge(1);name_="ledge adversity "+variant
		await _seconds({},actor.profile.ledge_catch_seconds+.03)
		var offset: Vector2=actor.global_position-ledge.global_position
		if variant=="moving":
			ledge._origin=ledge.position;ledge.moving=true;ledge.travel=Vector2(70,-20);ledge.travel_speed=44
			await _seconds({},.3)
			_check(actor.main_action==&"ledge" and (actor.global_position-ledge.global_position).distance_to(offset)<.25,"hanging root follows moving support in local space")
			await _seconds({"up":1.0},.6)
			_check(_count("pullup_end")==1 and not _solid_overlap(),"moving support allows safe completed pull")
		elif variant=="removed":
			ledge.queue_free();await _step({},3)
			_check(actor.main_action!=&"ledge" and _count("ledge_release")==1,"removed support releases once without invisible anchor")
		elif variant=="away":
			await _step({"left":1.0});await _seconds({"right":1.0},actor.profile.ledge_regrab_delay*.5)
			_check(actor.main_action!=&"ledge" and _count("ledge_catch")==1,"away releases and regrab cooldown prevents immediate snap-back")
		else:
			await _seconds({"up":1.0},actor.profile.ledge_pull_seconds*.35)
			await _step({"down":1.0})
			_check(actor.main_action!=&"ledge" and not _solid_overlap(),"release safely interrupts a pull in progress")
		await _finish()
func _permission_and_reset() -> void:
	await _begin("future action permissions and interrupt driver")
	actor.set_weapon_permissions({"can_move":false,"can_turn":true})
	await _step({"left":1.0})
	_check(actor.facing==-1 and actor.velocity.x==0,"turn permission remains independent of movement lock")
	actor.set_weapon_permissions()
	var calls={"count":0}
	actor.begin_main_action(&"test_action",{"interruptible_by":["jump"]},func(_a,_d,_i):calls.count+=1;return false)
	await _step({"jump":true});var at_jump: int=calls.count
	await _step({"jump":true},3)
	_check(actor.main_action==&"jump" and calls.count==at_jump,"jump interruption cancels previous action motion driver")
	for _i in range(8):await _step({"left":1.0 if _i%2==0 else 0.0,"right":1.0 if _i%2==1 else 0.0,"jump":_i%2==0})
	actor.reset_actor(Vector2(100,200),1);await _step({},2)
	_check(actor.main_action==&"locomotion" and actor.grounded and actor.facing==1 and actor.velocity==Vector2.ZERO and not actor.crouched and actor.air_jumps_left==actor.profile.air_jump_count,"reset clears action, velocity, body, input and jump budget")
	await _finish()
func _key(code_: int,pressed: bool) -> void:
	var event=InputEventKey.new();event.physical_keycode=code_;event.pressed=pressed;Input.parse_input_event(event);Input.flush_buffered_events()
func _native_input() -> void:
	await _begin("native parsed input drives physics")
	actor.automatic_physics=true
	_key(KEY_D,true);await _seconds(null,.12)
	_check(actor.velocity.x>0 and actor.facing==1,"parsed D moves actual body through InputMap")
	_key(KEY_D,false);_key(KEY_A,true);await _step(null)
	_check(actor.facing==-1 and actor.velocity.x>0,"parsed reversal turns immediately before residual speed changes sign")
	_key(KEY_A,false);_key(KEY_C,true);await _step(null)
	_check(_count("ground_jump")==1,"parsed C triggers exactly one ground jump")
	_key(KEY_C,false);await _step(null,2)
	await _finish()

func _extra_adversaries() -> void:
	await _begin("expired airborne jump buffer")
	actor.reset_actor(Vector2(100,90));actor.air_jumps_left=0;actor.velocity.y=60
	await _step({"jump":true});await _seconds({"jump":true},1.1)
	_check(actor.grounded and _count("ground_jump")==0 and _count("air_jump")==0,"expired input does not become an unrequested landing jump")
	await _finish()
	await _begin("crouch jump under roof stays collision-safe")
	await _step({"down":1.0},2)
	_surface(Vector2(80,166),Vector2(80,12));await _step({"down":1.0},2)
	await _step({"jump":true,"down":1.0})
	_check(actor.crouched and _count("ground_jump")==0 and not _solid_overlap(),"jump cannot expand crouched body through22px gap")
	await _seconds({"jump":true},actor.profile.jump_buffer_seconds+2*dt)
	_check(actor.crouched and not _solid_overlap(),"expired held jump remains safe under low roof")
	await _finish()
	for dir in [-1,1]:
		await _begin("high-speed thin wall %d" % dir,Vector2(100,200),true)
		_surface(Vector2(150 if dir==1 else 46,20),Vector2(4,180));await _step()
		actor.velocity.x=dir*actor.profile.run_speed*8
		await _seconds(_direction(dir),.08)
		_check(not _solid_overlap() and (actor.global_position.x<150 if dir==1 else actor.global_position.x>50),"8x-run seeded stress still cannot cross thin solid")
		await _finish()
		await _reach_ledge(dir,true);name_="reset from blocked ledge %d" % dir
		await _seconds({"up":1.0},.2)
		_check(_count("pullup_blocked")>0,"fixture reaches blocked-pull state before reset")
		actor.reset_actor(Vector2(180-dir*50,200),-dir)
		var t: Dictionary=actor.telemetry()
		_check(actor.main_action==&"locomotion" and actor.action_phase==&"" and t.support_id==0 and t.support_displacement==Vector2.ZERO,"reset immediately clears support/action telemetry")
		_check(actor._blocked_pull_timer==0 and actor._jump_buffer==0 and actor._coyote==0 and actor.move_x==0 and actor.move_y==0,"reset discards old pull retry and input/grace state")
		await _step({},2)
		_check(actor.grounded and not _solid_overlap(),"reset from blocked traversal restores ordinary supported movement")
		await _finish()
	for mode in ["disabled","rotated","teleported","new_roof","transport_wall"]:
		var ledge=await _reach_ledge(1);name_="dynamic ledge invalidation "+mode
		await _seconds({},actor.profile.ledge_catch_seconds+.03)
		if mode=="disabled":ledge.collision_layer=0
		elif mode=="rotated":ledge.rotation=PI*.5
		elif mode=="teleported":ledge.position+=Vector2(100,0)
		elif mode=="new_roof":
			await _seconds({"up":1.0},actor.profile.ledge_pull_seconds*.25)
			_surface(actor.global_position+Vector2(-25,-actor.body_height-12),Vector2(50,10))
		else:
			_surface(actor.global_position+Vector2(-actor.profile.body_width*.5-8,-actor.body_height-10),Vector2(4,actor.body_height+20))
			ledge._origin=ledge.position;ledge.moving=true;ledge.travel=Vector2(-60,0);ledge.travel_speed=100
		if mode=="transport_wall":
			for _i in range(hz):
				await _step()
				if _count("ledge_release")>0:break
			ledge.moving=false
			var releases=events.filter(func(e):return e.event=="ledge_release")
			_check(not releases.is_empty() and releases.back().data.reason=="transport_blocked","valid moving support releases because swept transport hits obstacle, not stale lost-surface ray")
		else:await _seconds({"up":1.0} if mode=="new_roof" else {},.35)
		_check(actor.main_action!=&"ledge" and _count("ledge_release")==1,"changed/blocked support releases traversal once")
		_check(not _solid_overlap(),"support invalidation or new obstruction leaves safe actor geometry")
		await _finish()
	await _begin("spent air jump is not refreshed by ledge",Vector2(130,240),false)
	_surface(Vector2(-500,240),Vector2(1500,40));_surface(Vector2(180,120),Vector2(80,120));await _step({},2)
	await _seconds({"right":1.0,"jump":true},.14);await _step({"right":1.0})
	await _step({"right":1.0,"jump":true})
	for _i in range(hz*2):
		await _step({"right":1.0,"jump":true})
		if actor.main_action==&"ledge":break
	_check(_count("air_jump")==1 and actor.main_action==&"ledge" and actor.air_jumps_left==0,"actual second jump reaches high ledge with budget spent")
	await _seconds({},.1);await _step({"down":1.0});await _step();await _step({"jump":true})
	_check(actor.main_action!=&"ledge" and _count("air_jump")==1 and actor.air_jumps_left==0,"hang/release cannot grant an extra air jump")
	await _finish()
	await _begin("locked facing cannot flip through ledge catch",Vector2(230,200),true)
	_surface(Vector2(100,130),Vector2(80,70));await _step()
	actor.facing=1;actor.set_weapon_permissions({"can_turn":false})
	for _i in range(hz):
		await _step({"left":1.0,"jump":true})
		if actor.main_action==&"ledge":break
	_check(actor.facing==1,"can_turn=false remains authoritative during assisted ledge entry")
	await _finish()

func _slope_reverse_and_crouch() -> void:
	await _begin("slope reversal descent and crouch",Vector2(100,200),true)
	_ramp(Vector2(120,200));await _step()
	await _seconds({"right":1.0},.42)
	var initial_y: float=actor.global_position.y;var supported:=true
	for _i in range(ceili(.32/dt)):
		await _step({"left":1.0});supported=supported and actor.grounded
	_check(supported and actor.global_position.y>initial_y and actor.facing==-1,"reversal and downhill motion keep floor support")
	await _step({"down":1.0,"left":1.0})
	_check(actor.crouched and actor.grounded and not _solid_overlap(),"crouch on slope keeps grounded clearance")
	await _step()
	_check(not actor.crouched and actor.grounded,"standing again on slope does not falsely lose support")
	await _finish()
