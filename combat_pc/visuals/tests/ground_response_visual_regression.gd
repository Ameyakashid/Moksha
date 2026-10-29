extends "res://combat_pc/tests/soft_slope_regression.gd"
## M18 presentation acceptance: actual production actor and attached view, one
## production call per real callback. Assertions summarize meaningful behaviors.
const VISUAL = preload("res://combat_pc/visuals/wireframe.gd")
const CANDIDATE = preload("res://combat_pc/resources/ground_response_agile.tres")
const PRESENTATION = preload("res://combat_pc/resources/ground_presentation_agile.tres")
var visual: Node
var observer: Node
var variant := "candidate"
var immutable := true
var facing_matches := true
var transformed := false
var last_pose := {}
var original_hashes := {}
var total_samples := 0
var archived_script: GDScript
var archived_view: Node
var null_parity := true
var null_samples := 0
var archive_sha256 := ""

func _run() -> void:
	var archive := ZIPReader.new()
	var archive_path := ProjectSettings.globalize_path("res://../moksha-backups/M18-start-20261005/MOKSHA-Two-Level-Project.zip")
	if archive.open(archive_path)!=OK:
		push_error("Required exact pre-M18 archive is unavailable: "+archive_path); quit(2); return
	var original := archive.read_file("MOKSHA/combat_pc/visuals/wireframe.gd").get_string_from_utf8()
	archive.close()
	archive_sha256=original.sha256_text()
	archived_script=GDScript.new()
	archived_script.source_code=original.replace("class_name MokshaWireframe\n", "")
	if archived_script.reload()!=OK:
		push_error("Archived view failed to compile in memory"); quit(2); return
	for path in ["res://combat_pc/player.gd", "res://combat_pc/player.tscn", "res://combat_pc/visuals/wireframe.gd", "res://combat_pc/visuals/wireframe_keys.gd", "res://combat_pc/visuals/wireframe_pose.gd", "res://combat_pc/resources/ground_presentation_profile.gd", "res://combat_pc/resources/ground_presentation_agile.tres", "res://combat_pc/resources/ground_response_agile.tres", "res://combat_pc/tests/soft_slope_regression.gd"]:
		original_hashes[path] = FileAccess.get_sha256(path)
	for direction in [-1, 1]:
		await _ground_sequence(direction)
		await _rapid_sequence(direction)
		await _landing_sequence(direction)
		await _reset_sequence(direction)
		for owner in ["jump", "roll", "attack", "shield", "hurt", "defeat", "hitpause"]:
			await _owner_priority(direction, owner)
	variant = "null"
	for direction in [-1, 1]: await _default_observation(direction)
	name_ = "global"
	_check(immutable, "passive observer leaves every supplied production snapshot unchanged")
	_check(facing_matches, "attached visual facing agrees with authoritative motor on every callback")
	_check(not transformed, "presentation never changes its local root transform")
	_check(null_parity and null_samples>0, "null attached view produces exact full poses matching archived pre-M18 view on real snapshots")
	var stable := true
	for path in original_hashes: stable = stable and original_hashes[path] == FileAccess.get_sha256(path)
	_check(stable, "runtime and inherited source hashes stable throughout run")
	var report := {"milestone":18, "suite":"ground presentation connected motor", "passed":failures.is_empty(), "physics_hz":hz, "checks":checks, "failures":failures, "scenarios":scenarios, "scenario_count":scenarios.size(), "physics_samples":total_samples, "source_hashes":original_hashes, "archived_view_sha256":archive_sha256, "archived_null_equal_samples":null_samples, "source_hash_stable":stable, "engine":Engine.get_version_info().string, "method":"One physics_tick per consecutive real callback. Actual production child Visual is observed; parallel passive observer tests input snapshot immutability. Assertions are per behavior, not per bone or frame.", "limits":["Headless connected motor/view observations; parent owns native visual judgment.", "Null profile preserves historical presentation quirks; candidate fixes are opt-in.", "No source-game animation or numerical parity claim."]}
	FileAccess.open("res://combat_pc/visuals/tests/ground_response_visual_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(report), "  ")+"\n")
	print("GROUND_PRESENTATION %dHz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _flat_case(label: String, direction: int) -> void:
	await _begin(variant+": "+label+" direction%d" % direction, Vector2(0, 198))
	actor.profile = CANDIDATE.duplicate(true)
	visual = actor.get_node("Visual")
	visual.ground_presentation = PRESENTATION if variant == "candidate" else null
	observer = VISUAL.new()
	observer.ground_presentation = visual.ground_presentation
	actor.movement_event.connect(observer.event)
	if variant=="null":
		archived_view=archived_script.new()
		actor.movement_event.connect(archived_view.event)
	_terrain([Vector2(-4000, 0), Vector2(4000, 0)], Vector2(0,200))
	await _start()
	actor.reset_actor(actor.position, -direction)
	observer.reset_presentation()
	if is_instance_valid(archived_view): archived_view.reset_presentation()
	await _seconds({}, .25)
	_check(actor.grounded and actor.velocity==Vector2.ZERO, "fixture starts at genuine settled floor contact")

func physics_sample(delta: float) -> void:
	if not is_instance_valid(actor): return
	ticks += 1
	var engine_tick := Engine.get_physics_frames()
	if last_engine_tick >= 0: engine_gaps.append(engine_tick-last_engine_tick)
	last_engine_tick=engine_tick; deltas.append(delta)
	if before_tick.is_valid(): before_tick.call(delta)
	actor.physics_tick(delta,input_frame)
	var snapshot: Dictionary = actor.telemetry()
	var before := snapshot.duplicate(true)
	observer.present(delta,snapshot)
	immutable = immutable and snapshot == before
	var pose: Dictionary = visual.get_pose()
	last_pose=pose.duplicate(true)
	if is_instance_valid(archived_view):
		archived_view.present(delta,snapshot)
		null_parity=null_parity and archived_view.get_pose()==pose
		null_samples+=1
	facing_matches = facing_matches and int(pose.facing)==actor.facing
	transformed = transformed or visual.position!=Vector2.ZERO or visual.rotation!=0 or visual.scale!=Vector2.ONE
	frames.append({"tick":ticks,"time":ticks*dt,"x":actor.position.x,"vx":actor.velocity.x,"vy":actor.velocity.y,"move":actor.move_x,"facing":actor.facing,"grounded":actor.grounded,"motor_pose":String(actor.pose),"owner":String(actor.main_action),"weapon":String(actor.weapon_phase),"paused":snapshot.paused,"mode":String(pose.mode),"phase":pose.phase,"key":pose.key,"head":pose.bones.head,"pelvis":pose.bones.pelvis,"gait":visual._gait_phase})
	total_samples += 1

func _finish() -> void:
	_check(engine_gaps.all(func(gap):return gap==1) and deltas.all(func(value):return absf(value-dt)<.0000001), "all observations use consecutive real physics callbacks at requested rate")
	measurements.physics_samples=frames.size()
	scenarios.append({"name":name_,"assertions":assertions,"failures":failures.size()-start_failures,"measurements":measurements,"events":events,"trace":frames})
	driver.enabled=false
	observer.free()
	if is_instance_valid(archived_view): archived_view.free()
	archived_view=null
	world.queue_free()
	await physics_frame; await process_frame
	actor=null; world=null; driver=null; visual=null; observer=null

func _slice(start: int) -> Array:
	return frames.slice(start)
func _mode_seconds(rows: Array, mode: String) -> float:
	var count := 0
	for row in rows:
		if row.mode==mode: count+=1
	return count*dt

func _modes(rows: Array) -> Array:
	var result := []
	for row in rows:
		if result.is_empty() or result.back()!=row.mode: result.append(row.mode)
	return result

func _ground_sequence(direction: int) -> void:
	await _flat_case("start reverse release restart",direction)
	var begin := frames.size()
	await _seconds(_direction(direction),.20)
	var start_rows := _slice(begin)
	_check(start_rows[0].facing==direction and start_rows[0].mode=="start", "opposite-facing rest start immediately faces intent with start, never false turn")
	_check(_modes(start_rows)==["start","run"], "uninterrupted start advances once to run")
	var start_end := 0.0
	for row in start_rows:
		if row.mode=="start": start_end=float(row.time)-float(start_rows[0].time)+dt
	_check(start_end>=PRESENTATION.start_seconds-dt and start_end<=PRESENTATION.start_seconds+dt, "start lifetime fits optional authored duration within one callback")
	var run_rows := start_rows.filter(func(row):return row.mode=="run")
	_check(run_rows.size()>2 and absf(float(run_rows.back().x)-float(run_rows[0].x))>10 and run_rows[0].head!=run_rows.back().head and run_rows[0].gait!=run_rows.back().gait, "steady physical travel advances visible run bones and gait")
	begin=frames.size()
	await _seconds(_direction(-direction), .2)
	var turn_rows := _slice(begin)
	var turn_phase_ok := true; var last_phase := -1.0; var crossed := false; var low_cross_mode := ""
	for row in turn_rows:
		if row.mode=="turn":
			turn_phase_ok = turn_phase_ok and float(row.phase)>=last_phase
			last_phase=float(row.phase)
		if float(row.vx)*direction<=0 and not crossed: crossed=true;low_cross_mode=row.mode
	_check(turn_rows[0].mode=="turn" and turn_rows[0].facing==-direction and float(turn_rows[0].vx)*direction>0, "reversal turns body immediately while old momentum remains")
	_check(_modes(turn_rows)==["turn","run"] and turn_phase_ok and crossed and low_cross_mode=="turn", "turn remains one monotonic phase through velocity zero without pose flicker")
	var turn_seconds := _mode_seconds(turn_rows,"turn")
	_check(absf(turn_seconds-PRESENTATION.turn_seconds)<=dt+.000001, "turn lifetime fits optional authored duration within one callback")
	begin=frames.size()
	await _step(_direction(direction))
	await _step({})
	_check(last_pose.mode=="brake", "neutral input immediately replaces a live turn with brake")
	await _seconds({}, .2)
	var release_rows := _slice(begin+1)
	_check(_modes(release_rows)==["brake","idle"] and actor.velocity.x==0, "neutral release retires turn permanently and reaches a stationary idle")
	var brake_seconds := _mode_seconds(release_rows,"brake")
	_check(absf(brake_seconds-PRESENTATION.brake_seconds)<=dt+.000001, "brake lifetime fits optional authored duration within one callback")
	begin=frames.size()
	await _step(_direction(-direction))
	_check(last_pose.mode=="start", "restart after full stop shows a fresh start rather than old turn or brake")
	await _seconds(_direction(-direction),.16)
	_check(_modes(_slice(begin))==["start","run"], "fresh restart completes without stale transient reappearing")
	measurements={"start_seconds":start_end,"turn_seconds":turn_seconds,"brake_seconds":brake_seconds,"start_modes":_modes(start_rows),"turn_modes":_modes(turn_rows),"crossing_mode":low_cross_mode,"release_modes":_modes(release_rows)}
	await _finish()

func _rapid_sequence(direction: int) -> void:
	await _flat_case("rapid taps and alternating directions",direction)
	var short_restart_ok := true; var stationary_clean := true; var tap_modes := []
	for _n in 6:
		await _step(_direction(direction),2)
		await _step({})
		await _step(_direction(direction))
		short_restart_ok=short_restart_ok and last_pose.mode not in ["brake","idle"]
		tap_modes.append(last_pose.mode)
		await _seconds({},.2)
		stationary_clean=stationary_clean and actor.velocity.x==0 and last_pose.mode=="idle"
	_check(short_restart_ok and stationary_clean, "six interrupted same-direction taps resume movement immediately and settle without stale pose")
	var alternation_ok := true; var release_ok := true
	for n in 20:
		var wanted := direction if n%2==0 else -direction
		await _step(_direction(wanted),maxi(1,roundi(.0333333333/dt)))
		alternation_ok=alternation_ok and actor.facing==wanted and last_pose.mode in ["start","turn","run"]
		await _step({})
		release_ok=release_ok and last_pose.mode!="turn"
	await _seconds({},.2)
	_check(alternation_ok and release_ok and last_pose.mode=="idle" and actor.velocity.x==0, "twenty rapid left/right intentions and neutral interruptions track facing without stale turn")
	measurements={"resumed_tap_modes":tap_modes,"alternations":20}
	await _finish()

func _landing_sequence(direction: int) -> void:
	await _flat_case("jump interrupts turn then landing intent changes",direction)
	await _seconds(_direction(direction),.2)
	await _step(_direction(-direction))
	await _step(_direction(-direction,{"jump":true}))
	_check(not actor.grounded and last_pose.mode in ["jump","jump_rise","jump_apex"], "jump immediately replaces active turn with airborne presentation")
	await _until(func():return actor.grounded,_direction(-direction),2)
	_check(actor.grounded and last_pose.mode in ["land","land_run"], "actual floor contact owns landing presentation")
	var begin:=frames.size()
	await _step({})
	await _seconds(_direction(direction),.25)
	var rows:=_slice(begin)
	_check(rows.all(func(row):return row.mode in ["land","land_run","start","turn","run"]), "release and opposite restart during landing remain in current movement or contact families")
	_check(last_pose.mode=="run" and actor.facing==direction, "interrupted landing retires old jump and turn before steady run")
	var landing_progress := -1.0
	var contact_phase_continuous := true
	for row in rows:
		if row.mode in ["land","land_run"]:
			contact_phase_continuous=contact_phase_continuous and float(row.phase)>=landing_progress
			landing_progress=float(row.phase)
	_check(contact_phase_continuous, "land and land_run threshold switches retain one continuous contact phase")
	measurements.modes=_modes(rows)
	await _finish()

func _owner_priority(direction: int, owner: String) -> void:
	await _flat_case("ground transient interrupted by "+owner,direction)
	await _seconds(_direction(direction),.2)
	await _step(_direction(-direction))
	_check(last_pose.mode=="turn", "fixture contains a live ground turn at interruption")
	var begin:=frames.size()
	if owner=="hurt":
		_check(actor.receive_hit({"damage":1.0,"impulse":Vector2(direction*80,-50),"rollable":false,"hitpause":0.04}), "real damage API admits hurt interruption")
		await _step(_direction(direction))
		_check(last_pose.mode=="hurt", "hurt owns pose immediately despite stale ground intent")
	elif owner=="defeat":
		var requester:=Node.new();world.add_child(requester)
		_check(actor.enter_defeated(requester), "real defeat policy API acquires actor")
		await _seconds(_direction(direction,{"jump":true,"attack":true,"roll":true}),.15)
		_check(_slice(begin).all(func(row):return row.mode in ["defeated","defeated_air"]), "defeat suppresses every old ground transient and conflicting input")
	elif owner=="hitpause":
		var frozen_pose:=last_pose.duplicate(true); var frozen_x:float=actor.position.x; var frozen_gait:float=visual._gait_phase
		actor.apply_hitpause(.08)
		await _step(_direction(direction),maxi(1,floori(.05/dt)))
		_check(last_pose==frozen_pose and actor.position.x==frozen_x and visual._gait_phase==frozen_gait, "actual local hitpause freezes bones phase facing root and gait under opposite input")
		await _seconds(_direction(direction),.2)
		_check(last_pose.mode=="run" and actor.facing==direction, "resume accepts new facing and exits old ground transient")
	else:
		await _step(_direction(direction,{owner:true}))
		if owner=="jump": _check(not actor.grounded and last_pose.mode in ["jump","jump_rise","jump_apex"], "actual jump has priority over pending turn")
		else: _check(String(last_pose.mode).begins_with(owner+"_"), "actual "+owner+" has priority over pending turn")
		await _seconds(_direction(-direction,{owner:true} if owner=="shield" else {}),.15)
		var rows:=_slice(begin)
		var priority_ok:=true
		for row in rows:
			if owner=="jump" and not row.grounded: priority_ok=priority_ok and row.mode in ["jump","jump_rise","jump_apex","fall"]
			elif String(row.motor_pose).begins_with(owner+"_"): priority_ok=priority_ok and row.mode==row.motor_pose
		_check(priority_ok, "authoritative "+owner+" family persists under repeated opposite input")
	measurements.modes=_modes(_slice(begin))
	await _finish()

func _reset_sequence(direction: int) -> void:
	await _flat_case("reset during turn then opposite rest start",direction)
	await _seconds(_direction(direction),.2)
	await _step(_direction(-direction))
	actor.reset_actor(Vector2(300,198),-direction)
	observer.reset_presentation()
	await _seconds({},.25)
	_check(last_pose.mode=="idle" and actor.velocity==Vector2.ZERO, "actor reset retires turn and reaches neutral floor pose")
	await _step(_direction(direction))
	_check(last_pose.mode=="start" and actor.facing==direction, "opposite-facing start after reset remains a fresh start")
	await _seconds(_direction(direction),.15)
	_check(last_pose.mode=="run", "post-reset restart leaves no residual transient")
	await _finish()

func _default_observation(direction: int) -> void:
	await _flat_case("optional-null historical selector",direction)
	_check(visual.ground_presentation==null, "null profile remains truly unset")
	await _step(_direction(direction))
	_check(last_pose.mode=="turn", "null selector retains historical facing-change-at-rest turn behavior")
	await _seconds(_direction(direction),.25)
	await _step(_direction(-direction))
	await _step({})
	_check(last_pose.mode=="turn", "null selector retains historical turn-before-brake priority")
	measurements.note="Historical quirks deliberately retained only for null-resource compatibility. Candidate scenarios require corrected current-intent behavior."
	await _finish()
