extends "res://combat_pc/tests/ground_response_regression.gd"
## M19: replay unchanged M18 ground scenarios using approved v22 versus air candidate.
func _run() -> void:
	for path in ["res://combat_pc/player.gd","res://combat_pc/player.tscn","res://combat_pc/resources/movement_profile.gd","res://combat_pc/resources/ground_response_agile.tres","res://combat_pc/resources/ground_response_profile.gd","res://combat_pc/resources/air_response_agile.tres","res://combat_pc/resources/air_response_profile.gd","res://combat_pc/tests/ground_response_regression.gd","res://combat_pc/tests/soft_slope_regression.gd"]:
		protected_hashes[path]=FileAccess.get_sha256(path)
	for mode in ["baseline","candidate"]:
		variant=mode
		selected_profile=load("res://combat_pc/resources/ground_response_agile.tres" if mode=="baseline" else "res://combat_pc/resources/air_response_agile.tres").duplicate(true)
		for direction in [-1,1]:
			await _response_case(direction)
			await _sequence_case(direction)
			await _native_case(direction)
			await _moving_flat_case(direction)
			for owner in ["crouch","shield","attack","hurt","roll"]:await _owner_case(direction,owner)
		await _continuous_joins()
	var equal:=true
	for index in response_rows.size()/2:
		var old:Dictionary=response_rows[index].duplicate(true)
		var now:Dictionary=response_rows[index+response_rows.size()/2].duplicate(true)
		old.erase("variant");now.erase("variant")
		equal=equal and old==now
	name_="ground profile parity"
	_check(equal,"v22 ground start stop reversal times distances and speed bounds are exactly unchanged by air opt-in")
	var stable:=true
	for path in protected_hashes:stable=stable and protected_hashes[path]==FileAccess.get_sha256(path)
	_check(stable,"runtime and original test sources stable during run")
	var report:Dictionary={"milestone":19,"suite":"approved v22 ground response compatibility","physics_hz":hz,"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"scenarios":scenarios,"response_rows":response_rows,"source_hashes":protected_hashes,"production_hash_stable_during_run":stable,"method":"Unchanged M18 supported response native input moving carrier owner and slope-join scenarios. Both variants use approved ground response; candidate additionally opts into ordinary air steering."}
	FileAccess.open("res://combat_pc/tests/air_response_ground_results_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(_safe(report),"  ")+"\n")
	print("AIR_RESPONSE_GROUND_M19 %dHz: %d scenarios, %d failures" % [hz,scenarios.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
