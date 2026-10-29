extends SceneTree
## Independent differential fixture. Both views bind the SAME actual mission room
## and receive the SAME physical-source bus events. The preserved view is oracle.
## All world mutations here are isolated fixture actions, never production edits.
const BaseView=preload("res://scripts/sensory/sonar_view.gd")
const Geometry=preload("res://scripts/sensory/sonar_geometry.gd")
var host
var candidate
var baseline
var checks: Array[Dictionary]=[]
var failures: Array[String]=[]
var stages: Array[Dictionary]=[]
var raw_events: Array[Dictionary]=[]
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String,detail:String="") -> void:
	checks.append({"label":label,"passed":ok,"detail":detail if not ok else ""})
	if not ok:
		failures.append(label+": "+detail)
		push_error(label+": "+detail)
func first_geometry_error() -> String:
	if baseline.geometry.size()!=candidate.geometry.size(): return "record count %d != %d"%[baseline.geometry.size(),candidate.geometry.size()]
	for i in baseline.geometry.size():
		var left:Dictionary=baseline.geometry[i]
		var right:Dictionary=candidate.geometry[i]
		for key in ["key","body_id","a","b","arc","length","closed","dynamic","enemy","fingerprint","index"]:
			if left[key]!=right[key]: return "record %d %s differs: %s != %s"%[i,key,str(left[key]),str(right[key])]
		if left.anchor.get_ref()!=right.anchor.get_ref() or left.body.get_ref()!=right.body.get_ref(): return "record %d live anchors differ"%i
	return ""
func first_pulse_error() -> String:
	if baseline.event_history!=candidate.event_history: return "accepted source event history differs"
	if baseline.pulses.size()!=candidate.pulses.size(): return "pulse count %d != %d"%[baseline.pulses.size(),candidate.pulses.size()]
	for i in baseline.pulses.size():
		var left:Dictionary=baseline.pulses[i]
		var right:Dictionary=candidate.pulses[i]
		for key in left:
			if key=="tracks": continue
			if left[key]!=right.get(key): return "pulse %d %s differs: %s != %s"%[i,key,str(left[key]),str(right.get(key))]
		if left.tracks.keys()!=right.tracks.keys(): return "pulse %d tracked contours differ: %s != %s"%[i,str(left.tracks.keys()),str(right.tracks.keys())]
		for key in left.tracks:
			var a:Dictionary=left.tracks[key]
			var b:Dictionary=right.tracks[key]
			for field in ["arrivals","attenuation","first_arrival","last_arrival"]:
				if a[field]!=b[field]: return "pulse %d contour %s field %s differs"%[i,key,field]
			if a.geometry.fingerprint!=b.geometry.fingerprint: return "pulse %d contour %s geometry fingerprint differs"%[i,key]
	return ""
func first_alpha_error() -> String:
	var records:Dictionary={}
	for g in candidate.geometry: records[g.key]=g
	for g in baseline.geometry:
		if not records.has(g.key): return "missing alpha record "+g.key
		if baseline._segment_alphas(g)!=candidate._segment_alphas(records[g.key]): return "fragment alpha values differ for "+g.key
	return ""
func visible_fragments(view:Node,world_to_screen:Transform2D,cull:bool) -> Array:
	var result:Array=[]
	if not view.blind and not view.preview_when_sighted: return result
	var viewport:=Rect2(Vector2(-20,-20),Vector2(680,400))
	var opacity:float=1.0 if view.blind else view.tuning.quiet_preview_opacity
	for record in view.geometry:
		if not Geometry.is_live(record): continue
		var anchor:Node2D=record.anchor.get_ref()
		var transform:=world_to_screen*anchor.global_transform
		if cull and not viewport.intersects(transform*view._local_bounds(record)): continue
		var alphas:PackedFloat32Array=view._segment_alphas(record)
		for i in alphas.size():
			var alpha:float=alphas[i]*opacity
			if alpha<0.015: continue
			var a:Vector2=transform*record.a[i]
			var b:Vector2=transform*record.b[i]
			if not viewport.has_point(a) and not viewport.has_point(b): continue
			if result.size()>=view.tuning.max_draw_segments: break
			result.append([record.key,i,a,b,alpha])
		if result.size()>=view.tuning.max_draw_segments: break
	return result
func compare(label:String) -> void:
	var error:=first_geometry_error()
	check(error.is_empty(),label+" geometry exact parity",error)
	error=first_pulse_error()
	check(error.is_empty(),label+" emitted-event and track exact parity",error)
	error=first_alpha_error()
	check(error.is_empty(),label+" fragment alpha exact parity",error)
	var visibility_error:=""
	for origin in [Vector2.ZERO,Vector2(-400,300),Vector2(-1000,700)]:
		var transform:=Transform2D(0,origin)
		if visible_fragments(baseline,transform,false)!=visible_fragments(candidate,transform,true):
			visibility_error="candidate bounds cull changes visible fragments at camera offset "+str(origin)
			break
	check(visibility_error.is_empty(),label+" visible-fragment cull parity",visibility_error)
	var segments:=0
	for g in baseline.geometry: segments+=g.a.size()
	stages.append({"label":label,"geometry_records":baseline.geometry.size(),"segments":segments,"pulses":baseline.pulses.size()})
func refresh_pair(label:String) -> void:
	baseline.refresh_geometry()
	candidate.refresh_geometry()
	compare(label)
func advance_pair(dt:float,label:String) -> void:
	baseline.advance_simulation(dt)
	candidate.advance_simulation(dt)
	compare(label)
func emit_at(at:Vector2,kind:StringName=&"weapon_tap",loudness:float=1.0,source:Node=null) -> void:
	host.bus.emit_noise(at,kind,loudness,source if source!=null else host.room)
	raw_events.append({"origin":str(at),"kind":String(kind),"loudness":loudness})
func add_shape(at:Vector2,shape:Shape2D) -> CollisionShape2D:
	var body:=StaticBody2D.new()
	body.position=at
	body.collision_layer=1
	body.collision_mask=0
	var anchor:=CollisionShape2D.new()
	anchor.shape=shape
	body.add_child(anchor)
	host.room.add_child(body)
	return anchor
func create_box(at:Vector2,size:Vector2) -> CollisionShape2D:
	var shape:=RectangleShape2D.new()
	shape.size=size
	return add_shape(at,shape)
func clear_pair() -> void:
	baseline.clear_pulses()
	candidate.clear_pulses()
func set_tuning(property:String,value:Variant) -> void:
	baseline.tuning.set(property,value)
	candidate.tuning.set(property,value)
func bind_pair() -> void:
	baseline.bind_level(host.room,host.player)
	candidate.bind_level(host.room,host.player)
func run() -> void:
	host=load("res://demo/mission.tscn").instantiate()
	host.save_enabled=false
	root.add_child(host)
	host.start_new(true)
	var lift_sector:=-1
	for i in host.sectors.size():
		if host.sectors[i].has("lifts"):
			lift_sector=i
			break
	check(lift_sector>=0,"actual authored room contains moving lifts")
	if lift_sector<0: finish();return
	host.load_sector(lift_sector)
	host.set_process(false)
	host.set_physics_process(false)
	host.room.process_mode=Node.PROCESS_MODE_DISABLED
	candidate=host.sonar
	candidate.set_process(false)
	baseline=CanvasLayer.new()
	baseline.set_script(BaseView)
	baseline.tuning=candidate.tuning.duplicate(true)
	baseline.preview_when_sighted=candidate.preview_when_sighted
	root.add_child(baseline)
	baseline.set_process(false)
	bind_pair()
	compare("initial authored cistern")
	for p in [Vector2(75,280),Vector2(1040,130),Vector2(800,-470),Vector2(1810,-750),Vector2(-500,-1500)]: emit_at(p)
	compare("near and far source emissions")
	for dt in [0.03,0.08,0.2,0.35,0.7]: advance_pair(dt,"propagation %.2f"%dt)
	# Move real lift anchors with active waves; prior arrival schedules must remain.
	var lift:Node2D
	for child in host.room.get_children():
		if child.get_script()!=null and child.get_script().resource_path=="res://demo/components/mission_lift.gd": lift=child;break
	check(is_instance_valid(lift),"actual lift component selected")
	if is_instance_valid(lift):
		lift.sync_to_physics=false
		var before:Vector2=lift.position
		lift._physics_process(0.75)
		check(lift.position!=before,"authored lift function translates real contour anchor")
		refresh_pair("moving lift preserves old arrival schedule")
		emit_at(lift.global_position+Vector2(0,-30),&"lift_motor",0.45,lift)
		compare("new event at moved lift origin")
		lift.rotation=0.37
		refresh_pair("rotated lift")
		emit_at(lift.global_position+Vector2(70,20))
		compare("new event beside rotated lift")
	# Existing prop and cache lifecycle must invalidate geometry without ghosts.
	var prop:Node2D
	for child in host.room.get_children():
		if child.is_in_group("props"): prop=child;break
	check(is_instance_valid(prop),"actual mission prop selected")
	if is_instance_valid(prop):
		emit_at(prop.global_position,&"prop_impact",1.6,prop)
		prop._break_apart()
		await process_frame
		refresh_pair("destroyed prop removed")
	host.room.set_cache_found(true)
	refresh_pair("collected cache sonar ignore")
	host.room.set_cache_found(false)
	refresh_pair("restored cache contour")
	var anchor:=create_box(Vector2(800,-350),Vector2(80,24))
	refresh_pair("new collider")
	emit_at(Vector2(800,-350))
	compare("event inside new collider")
	anchor.disabled=true
	refresh_pair("disabled collider")
	anchor.disabled=false
	refresh_pair("reenabled collider")
	anchor.shape.size=Vector2(180,65)
	refresh_pair("in-place shape resize")
	emit_at(Vector2(890,-315),&"prop_impact",0.1)
	compare("event at resized shape edge")
	anchor.scale=Vector2(1.7,0.6)
	refresh_pair("nonuniform collider scale")
	anchor.rotation=0.71
	refresh_pair("nonuniform scaled rotated collider")
	var circle:=CircleShape2D.new()
	circle.radius=47
	anchor.shape=circle
	refresh_pair("shape resource replacement")
	circle.radius=63
	refresh_pair("in-place circle radius change")
	anchor.get_parent().queue_free()
	await process_frame
	refresh_pair("deleted collider")
	var polygon_body:=StaticBody2D.new()
	polygon_body.position=Vector2(900,-250)
	var polygon:=CollisionPolygon2D.new()
	polygon.polygon=PackedVector2Array([Vector2(-70,-20),Vector2(60,-30),Vector2(80,35),Vector2(-40,50)])
	polygon_body.add_child(polygon)
	host.room.add_child(polygon_body)
	refresh_pair("new collision polygon")
	emit_at(polygon_body.global_position)
	polygon.polygon[1]=Vector2(120,-60)
	check(polygon.polygon[1]==Vector2(120,-60),"collision-polygon mutation actually committed")
	refresh_pair("edited collision polygon")
	polygon.disabled=true
	refresh_pair("disabled collision polygon")
	polygon.disabled=false
	refresh_pair("reenabled collision polygon")
	# Rebind forces caches cold, then test partial-sampling budgets growing again.
	clear_pair()
	set_tuning("max_geometry_segments",64)
	set_tuning("sample_spacing",6.0)
	set_tuning("base_range",40.0)
	bind_pair()
	emit_at(Vector2(40,300)) # Warms bounded-track local-bounds cache on a partial floor.
	compare("64-segment geometry budget")
	set_tuning("max_geometry_segments",9000)
	refresh_pair("expanded geometry budget")
	emit_at(Vector2(470,300),&"weapon_tap",0.1)
	compare("expanded budget newly covered floor edge")
	set_tuning("sample_spacing",13.0)
	refresh_pair("coarser sample spacing")
	emit_at(Vector2(470,380),&"weapon_tap",0.1)
	compare("coarse contour far edge")
	set_tuning("sample_spacing",3.0)
	refresh_pair("finer sample spacing")
	# Shared state behavior: mode toggles clear old waves and retain exact new waves.
	set_tuning("base_range",440.0)
	for blind_value in [true,false]:
		baseline.set_blind(blind_value)
		candidate.set_blind(blind_value)
		check(baseline.blind==candidate.blind and baseline.pulses.is_empty() and candidate.pulses.is_empty(),"blind=%s clears prior waves identically"%str(blind_value))
		for preview in [false,true]:
			baseline.preview_when_sighted=preview
			candidate.preview_when_sighted=preview
			emit_at(Vector2(920,-140),&"enemy_windup",0.8,host.enemies[0])
			advance_pair(0.12,"blind=%s preview=%s"%[str(blind_value),str(preview)])
	set_tuning("max_active_pulses",3)
	set_tuning("history_limit",6)
	for i in 8: emit_at(Vector2(500+i*60,-200),&"prop_impact",0.1+i*0.1)
	compare("bounded pulse and event retention")
	check(baseline.pulses.size()==3 and baseline.event_history.size()==6 and baseline.dropped_pulse_count==candidate.dropped_pulse_count,"pulse dropping and retained history match")
	# Pause, invalid provenance and retirement keep the same acceptance boundary.
	var count:int=baseline.accepted_event_count
	paused=true
	emit_at(Vector2(900,-200))
	advance_pair(0.5,"paused simulation")
	check(baseline.accepted_event_count==count and candidate.accepted_event_count==count,"paused event rejected by both views")
	paused=false
	host.bus.emit_noise(Vector2(20,20),&"weapon_tap",1.0,null)
	host.bus.emit_noise(Vector2(20,20),&"weapon_tap",1.0,baseline)
	compare("invalid provenance rejected")
	check(baseline.accepted_event_count==count and candidate.accepted_event_count==count,"unscoped and foreign-source events rejected")
	baseline.bind_level(null,null)
	candidate.bind_level(null,null)
	compare("unbound retired room")
	check(baseline.geometry.is_empty() and candidate.geometry.is_empty(),"unbinding drops all contours")
	finish()
func finish() -> void:
	var report={"checks":checks,"failures":failures,"stages":stages,"emitted_events":raw_events,"engine":Engine.get_version_info().string,"scope":"Exact differential geometry, event, track, alpha and endpoint-visibility cull parity against preserved SonarView on one shared real mission room. Mutations are isolated fixture probes. Blind/preview state semantics tested; rendered raster/frame time and full gameplay are separate QA."}
	FileAccess.open("res://demo/evidence/sonar_optimization_regression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SONAR OPTIMIZATION ",checks.size()," checks; ",failures.size()," failures")
	paused=false
	if is_instance_valid(baseline): baseline.queue_free()
	if is_instance_valid(host): host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
