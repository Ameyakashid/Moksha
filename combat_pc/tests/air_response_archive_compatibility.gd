extends "res://combat_pc/tests/air_response_regression.gd"
## Compile the actual retained v22 motor, changing only its globally registered name.
## Compare baseline behavior with the new motor under the unchanged approved profile.
const V22_SHA = "ad1450d6451afb9943943d37af3a77dc6f543869635dcd5564867c5c2835a28c"
var archive_path := ""
var archived_script: GDScript
var use_archive := true
var archived_cases := {}
var archived_player_sha := ""

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-zip="):archive_path=argument.trim_prefix("--baseline-zip=")
	if archive_path.is_empty() or FileAccess.get_sha256(archive_path)!=V22_SHA:
		printerr("Required --baseline-zip retained v22 archive is absent or has incorrect pinned SHA256")
		quit(1);return
	var archive:=ZIPReader.new()
	if archive.open(archive_path)!=OK:
		printerr("Could not open retained v22 archive");quit(1);return
	var original:String=archive.read_file("MOKSHA/combat_pc/player.gd").get_string_from_utf8()
	archived_player_sha=original.sha256_text()
	archive.close()
	archived_script=GDScript.new()
	archived_script.source_code=original.replace("class_name MokshaCombatPlayer\n","")
	if archived_script.reload()!=OK:
		printerr("Retained v22 controller could not compile");quit(1);return
	for path in ["res://combat_pc/player.gd","res://combat_pc/player.tscn","res://combat_pc/resources/movement_profile.gd","res://combat_pc/resources/ground_response_agile.tres","res://combat_pc/resources/air_response_profile.gd","res://combat_pc/tests/soft_slope_regression.gd","res://combat_pc/tests/air_response_regression.gd"]:hashes[path]=FileAccess.get_sha256(path)
	variant="baseline"
	selected_profile=BASELINE.duplicate(true)
	for archived in [true,false]:
		use_archive=archived
		for direction in [-1,1]:
			await _response_case(direction)
			await _neutral_case(direction)
			await _analog_taps_case(direction)
			await _native_air_case(direction)
			for kind in ["held","release","air_jump"]:await _jump_case(direction,kind)
			await _correction_case(direction)
			await _coyote_case(direction,true)
			await _coyote_case(direction,false)
			await _one_way_case(direction)
			await _support_departure_case(direction)
		await _buffer_case()
		await _reset_pause_case()
	var stable:=true
	for path in hashes:stable=stable and hashes[path]==FileAccess.get_sha256(path)
	name_="archived parity provenance"
	_check(stable,"controller fixture and resource hashes remain stable during historical execution")
	var result:Dictionary={"milestone":19,"suite":"retained v22 controller parity","physics_hz":hz,"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"scenarios":scenarios,"source_hashes":hashes,"production_hash_stable_during_run":stable,"archived_zip_sha256":V22_SHA,"archived_player_sha256":archived_player_sha,"method":"Compile actual pinned v22 player.gd after removing only its globally registered class_name. Run both controllers through identical real physics callbacks with approved ground_response_agile.tres and compare every complete sampled physical/view state, excluding support instance IDs, plus event names and timing.","limits":["Legacy controller parity on baseline ordinary-air and jump paths; special-owner candidate parity is a separate suite.","Current shared dependencies are used; archive provenance separately verifies protected dependency bytes."]}
	FileAccess.open("res://combat_pc/tests/air_response_archive_results_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(_safe(result),"  ")+"\n")
	print("AIR_RESPONSE_ARCHIVE_M19 %dHz: %d paired cases, %d failures" % [hz,archived_cases.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)

func _begin(label:String,at:Vector2,use_probe:=false) -> void:
	_release_input()
	name_=label;params={};frames=[];events=[];assertions=[];measurements={}
	start_checks=checks;start_failures=failures.size();ticks=0;last_engine_tick=-1;engine_gaps=[];deltas=[]
	terrain=null;terrain_points=[];boxes=[];before_tick=Callable();input_frame={};instrumented=use_probe
	world=Node2D.new();world.name="Case";root.add_child(world)
	actor=PLAYER.instantiate()
	if use_archive:actor.set_script(archived_script)
	actor.profile=BASELINE.duplicate(true);actor.combat_profile=actor.combat_profile.duplicate(true)
	actor.automatic_physics=false;actor.enable_hard_landing=false;actor.position=at
	world.add_child(actor)
	actor.movement_event.connect(func(label_:StringName,data:Dictionary):events.append({"event":String(label_),"tick":ticks,"data":_safe(data)}))
	driver=TickDriver.new();driver.harness=self;driver.process_physics_priority=20;world.add_child(driver)
	await _sync_geometry()
	actor.reset_actor(at,1)

func _finish() -> void:
	var signature:=[]
	for frame in frames:
		var state:Dictionary=frame.after.duplicate(true)
		state.erase("support_id")
		signature.append(state)
	var event_signature:=[]
	for event in events:event_signature.append({"event":event.event,"tick":event.tick})
	if use_archive:archived_cases[name_]={"frames":signature,"events":event_signature}
	else:
		_check(archived_cases[name_].frames==signature,"new motor with absent override exactly matches actual archived v22 motor physical/view samples")
		_check(archived_cases[name_].events==event_signature,"new motor with absent override preserves archived event identities and callback timing")
	measurements.controller="archived v22" if use_archive else "current baseline"
	await super._finish()
