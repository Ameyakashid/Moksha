extends "res://combat_pc/tests/held_regression.gd"
## M11 optional first-fresh-entry facing. Original host policy; no target tracking.
class RecordingHost extends MokshaAttackEntryFacingHost:
	var recorder: Callable
	func provide_attack_entry_offer(pc: Node2D, request: Dictionary) -> Dictionary:
		var before: Dictionary = pc.telemetry().duplicate(true)
		var answer: Dictionary = super.provide_attack_entry_offer(pc, request)
		if recorder.is_valid(): recorder.call(pc, request, answer, before)
		return answer

var assist_host: Node
var assist_target: Node2D
var query_records: Array[Dictionary] = []
var host_at_finish: Dictionary = {}
var query_provider: Callable

func _run() -> void:
	source_paths.append_array(["res://project.godot", "res://combat_pc/tests/entry_assist_regression.gd",
		"res://combat_pc/tests/held_regression.gd", "res://combat_pc/tests/combo_regression.gd", "res://combat_pc/tests/shield_regression.gd",
		"res://combat_pc/components/attack_entry_facing_host.gd", "res://combat_pc/components/attack_entry_facing_host.tscn",
		"res://combat_pc/resources/melee_chain.gd", "res://combat_pc/resources/melee_step.gd", "res://combat_pc/resources/light_chain.tres",
		"res://combat_pc/resources/melee_input_profile.gd", "res://combat_pc/resources/held_repeat.tres", "res://combat_pc/resources/held_charge.tres",
		"res://combat_pc/fixtures/contact_target.gd", "res://combat_pc/fixtures/contact_target.tscn"])
	for filename in DirAccess.get_files_at("res://combat_pc/visuals"):
		if filename.ends_with(".gd"): source_paths.append("res://combat_pc/visuals/" + filename)
	for path in source_paths: starting_hashes[path] = FileAccess.get_sha256(path)
	if only_group in ["", "physical"]: await _entry_physical_cases()
	if only_group in ["", "gates"]: await _entry_gate_cases()
	if only_group in ["", "host"]: await _entry_host_cases()
	if only_group in ["", "offers"]: await _entry_offer_cases()
	if only_group in ["", "provenance"]: await _entry_provenance_cases()
	if only_group in ["", "lifecycle"]: await _entry_lifecycle_cases()
	if only_group in ["", "native"]: await _entry_native_cases()
	_release_input()
	var hashes := {}; var stable := true
	for path in source_paths:
		hashes[path] = FileAccess.get_sha256(path)
		stable = stable and hashes[path] == starting_hashes[path]
	if not stable: failures.append("Source changed during entry-assist run; final rerun required")
	var output := {"milestone": 11, "selected_group": only_group, "physics_hz": hz, "checks": checks, "failures": failures,
		"scenarios": scenarios, "engine": Engine.get_version_info(), "generated_utc": Time.get_datetime_string_from_system(true),
		"production_hash_stable_during_run": stable, "starting_hashes": starting_hashes, "hashes": hashes,
		"execution": "One production call per actual Godot physics callback. Production host offers, adversarial provider API probes, actual target effects and contact receipts are distinguished.",
		"numeric_source": "Original MOKSHA optional first-fresh-entry policy. Source establishes an aim family, not this query, geometry or admission scheduler."}
	FileAccess.open("res://combat_pc/tests/entry_assist_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(output), "  "))
	print("MOKSHA ENTRY ASSIST %dHz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _assist_begin(label: String, enabled := true, direction := 1, mode := "null", floor_present := true, chained := true) -> void:
	await _held_begin(label, mode, Vector2(100, 200), floor_present, chained)
	query_records = []; host_at_finish = {}
	actor.reset_actor(actor.position, direction); await _step()
	if actor.melee_chain != null:
		for step in actor.melee_chain.steps: step.active_ground_speed = 0
	actor.combat_profile.attack_active_ground_speed = 0
	assist_target = _target(Vector2(100 - direction * 30, 200), "ApprovedPassiveTarget")
	assist_host = RecordingHost.new()
	assist_host.recorder = _record_offer
	assist_host.actor_path = NodePath(""); world.add_child(assist_host)
	assist_host.register_candidate(assist_target, {"classification": &"opponent", "eligible": true, "perceived": true, "visible": true, "local_anchor": Vector2(0, -15)})
	assist_host.bind_actor(actor); assist_host.set_assist_enabled(enabled)
	params.merge({"assist_enabled": enabled, "initial_facing": direction, "provider_route": "production_host", "stationary_strike": true})
	await _sync_geometry()

func _sample() -> Dictionary:
	var result: Dictionary = super._sample()
	for key in actor.telemetry():
		if String(key).begins_with("entry_assist_"): result[key] = actor.telemetry()[key]
	return result

func _safe(value: Variant) -> Variant:
	if value is Rect2: return {"position": _safe(value.position), "size": _safe(value.size)}
	return super._safe(value)

func _finish() -> void:
	var queries := query_records.duplicate(true)
	var diagnostics: Dictionary = assist_host.diagnostics() if is_instance_valid(assist_host) and assist_host.is_inside_tree() else {}
	var target_hits: int = assist_target.get("hits") if is_instance_valid(assist_target) and assist_target.get("hits") != null else -1
	await super._finish()
	scenarios.back()["provider_queries"] = queries
	scenarios.back()["host_diagnostics"] = diagnostics
	scenarios.back()["actual_target_hits"] = target_hits
	assist_host = null; assist_target = null

func _query_count() -> int: return int(actor.telemetry().entry_assist_query_count)
func _ordinary_done(frame: Variant = {}) -> void:
	await _attack_phase("idle", frame, 1.6)
	await _seconds(frame, .1)
func _offer(request: Dictionary, target: Node2D = assist_target) -> Dictionary:
	return {"token": request.token, "sample_tick": request.sample_tick, "actor_id": request.actor_id, "attack_serial": request.attack_serial,
		"candidate": target, "candidate_id": target.get_instance_id(), "local_anchor": Vector2(0, -15), "anchor_world": target.to_global(Vector2(0, -15)),
		"classification": &"opponent", "eligible": true, "perceived": true, "visible": true}
func _record_offer(pc: Node, request: Dictionary, answer: Variant, before: Dictionary) -> void:
	var candidate: Variant = answer.get("candidate") if answer is Dictionary else null
	var candidate_state := {"valid": is_instance_valid(candidate), "inside_tree": false, "queued_for_deletion": false}
	if is_instance_valid(candidate) and candidate is Node2D:
		candidate_state.merge({"id": candidate.get_instance_id(), "inside_tree": candidate.is_inside_tree(), "queued_for_deletion": candidate.is_queued_for_deletion(), "visible": candidate.is_visible_in_tree(), "is_prop": candidate.is_in_group("props"), "position": _safe(candidate.global_position)}, true)
		if answer.get("local_anchor") is Vector2 and Vector2(answer.local_anchor).is_finite(): candidate_state["current_anchor"] = _safe(candidate.to_global(answer.local_anchor))
	var recorded: Variant = _safe(answer)
	if answer is Dictionary:
		for key in ["local_anchor", "anchor_world"]:
			if answer.get(key) is Vector2 and not Vector2(answer[key]).is_finite(): recorded[key] = {"rejected_nonfinite_vector": true}
	query_records.append({"tick": ticks, "engine_tick": Engine.get_physics_frames(), "request": _safe(request), "before": _safe(before), "returned_offer": recorded, "candidate_after_provider": candidate_state, "actor_after_provider": _safe(pc.telemetry())})
func _direct_provider(callback: Callable) -> void:
	params.provider_route = "adversarial_direct_provider"
	query_provider = func(pc, request):
		var before: Dictionary = pc.telemetry().duplicate(true)
		var answer: Variant = callback.call(pc, request)
		_record_offer(pc, request, answer, before)
		return answer
	actor.set_attack_entry_provider(query_provider)

func _entry_physical_cases() -> void:
	for direction in [-1, 1]:
		for enabled in [false, true]:
			await _assist_begin("neutral behind target direction%d enabled%s" % [direction, enabled], enabled, direction)
			var at: Vector2 = actor.position
			await _step({"attack": true})
			_check(actor.facing == (-direction if enabled else direction), "optional entry changes only the permitted neutral facing decision")
			_check(_query_count() == (1 if enabled else 0), "disabled mode makes no query and enabled fresh admission makes one")
			await _ordinary_done()
			_check(assist_target.hits == (1 if enabled else 0), "the behind-target comparison is resolved by actual production strike contact")
			_check(contact_receipts.size() == (1 if enabled else 0), "host offer cannot fabricate contact confirmation")
			_near(actor.position.distance_to(at), 0, .001, "stationary authored strike assistance adds no translation")
			if not enabled: _check(_count("entry_assist_resolved") == 0, "default-off path adds no decision event")
			await _finish()
	for direction in [-1, 1]:
		await _assist_begin("manual windup override then target movement direction%d" % direction, true, direction)
		await _step({"attack": true}); await _step(_direction(direction))
		_check(actor.facing == direction, "permitted later manual windup direction replaces the entry suggestion")
		await _attack_phase("active", _direction(direction))
		assist_target.position.x = 100 + direction * 30
		await _sync_geometry(); await _step(_direction(-direction)); await _ordinary_done()
		_check(_query_count() == 1 and int(_state().attack_facing) == direction, "moving target and active reversal never trigger tracking or rotate the committed strike")
		_check(assist_target.hits == 1, "ordinary active direction can hit the moved target without another provider query")
		await _finish()
	await _assist_begin("target moves away and perception revoked after entry")
	await _step({"attack": true}); assist_target.position.x -= 300; assist_host.set_candidate_awareness(false, false)
	await _sync_geometry(); await _ordinary_done()
	_check(actor.facing == -1 and _query_count() == 1, "a completed entry suggestion retains no live target tracking")
	_check(assist_target.hits == 0, "a target moved outside ordinary strike range is missed")
	await _finish()
	for enabled in [false, true]:
		await _assist_begin("airborne motion independent enabled%s" % enabled, enabled, 1, "null", false)
		assist_target.queue_free(); await _sync_geometry()
		assist_target = Node2D.new(); assist_target.position = Vector2(70, 200); world.add_child(assist_target)
		assist_host.register_candidate(assist_target, {"classification": "opponent", "eligible": true, "perceived": true, "visible": true})
		params["motion_isolation"] = "host-approved passive anchor without contact receiver"
		actor.velocity = Vector2(47, 120); actor.air_jumps_left = 0; actor.air_roll_available = false; actor.dive_available = false
		var initial: Dictionary = _sample(); await _step({"attack": true}); await _seconds({}, .18)
		_check(actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available, "aim assistance does not grant airborne action budgets")
		_check(actor.velocity.y > initial.velocity.y and float(_state().fall_distance) > initial.fall_distance, "airborne attack keeps ordinary gravity and fall history")
		measurements["air_initial"] = _safe(initial); measurements["air_final"] = _safe(_sample())
		await _finish()

func _entry_gate_cases() -> void:
	for gate in ["manual", "tiny_manual", "movement_locked_manual", "host_turn", "main_input", "step_turn", "input_disabled"]:
		await _assist_begin("entry veto " + gate)
		var frame := {"attack": true}
		if gate == "manual": frame.right = 1.0
		if gate == "tiny_manual": frame.right = .00001
		if gate == "movement_locked_manual": actor.set_weapon_permissions({"can_move": false}); frame.right = .01
		if gate == "host_turn": actor.set_weapon_permissions({"can_turn": false})
		if gate == "main_input": actor.begin_main_action(&"host", {"uses_inputs": false})
		if gate == "step_turn": actor.melee_chain.steps[0].allow_turn_windup = false
		if gate == "input_disabled": actor.allow_input = false
		await _step(frame); await _seconds(frame, .12)
		_check(_query_count() == 0 and actor.facing == 1, "manual intent or a closed turn/input gate cannot be overridden by a provider")
		_check(assist_host.query_count == 0, "the host is not consulted behind a denied decision gate")
		await _finish()
	await _assist_begin("denied buffered press queries only at actual admission")
	actor.set_weapon_permissions({"can_attack": false}); await _step({"attack": true}); await _step()
	_check(_query_count() == 0 and _count("attack_started") == 0, "a buffered denied attack has no provider query")
	actor.set_weapon_permissions(); await _step(); await _ordinary_done()
	_check(_query_count() == 1 and assist_target.hits == 1, "the still-valid fresh buffer queries once when an actual stroke is admitted")
	await _finish()

func _entry_host_cases() -> void:
	for refusal in ["missing", "ineligible", "unperceived", "invisible", "prop", "hidden", "outside", "occluded", "removed"]:
		await _assist_begin("host refuses " + refusal)
		match refusal:
			"missing": assist_host.register_candidate(assist_target, {})
			"ineligible": assist_host.set_candidate_eligible(false)
			"unperceived": assist_host.set_candidate_awareness(false, true)
			"invisible": assist_host.set_candidate_awareness(true, false)
			"prop": assist_host.set_candidate_classification(&"prop")
			"hidden": assist_target.hide()
			"outside": assist_target.position.x -= 200
			"occluded": _box(Vector2(84, 175), Vector2(.5, 60)); await _sync_geometry()
			"removed": world.remove_child(assist_target)
		await _step({"attack": true}); await _ordinary_done()
		_check(actor.facing == 1 and assist_host.offered_count == 0, "unapproved or geometrically unavailable target produces no facing offer")
		_check(not assist_host.diagnostics().has("candidate_id") and not assist_host.diagnostics().has("anchor_world"), "host diagnostic exposes decision facts without hidden target identity or coordinates")
		if refusal == "removed": assist_target.free()
		await _finish()
	for direction in [-1, 1]:
		await _assist_begin("closed preview outer boundary direction%d" % direction, true, -direction)
		var step = actor.melee_chain.steps[0]
		assist_target.position.x = actor.position.x + direction * (step.strike_center_offset.x + step.strike_size.x * .5)
		await _sync_geometry(); await _step({"attack": true})
		_check(actor.facing == direction and assist_host.offered_count == 1, "matching closed outer preview boundaries admit both mirrored anchors")
		await _ordinary_done(); await _finish()
	await _assist_begin("aim eligibility independent from target damage receiver")
	assist_target.queue_free(); await _sync_geometry(); assist_target = Node2D.new(); assist_target.position = Vector2(70, 200); world.add_child(assist_target)
	assist_host.register_candidate(assist_target, {"classification": "opponent", "eligible": true, "perceived": true, "visible": true})
	await _step({"attack": true}); await _ordinary_done()
	_check(actor.facing == -1 and _query_count() == 1, "an explicitly approved opponent does not need a damage method for entry facing")
	_check(contact_receipts.is_empty(), "aiming approval grants no damage or target-receiver authority")
	await _finish()

func _entry_offer_cases() -> void:
	for invalid in ["token", "sample_tick", "actor_id", "attack_serial", "candidate_id", "typed_attestation", "missing_perceived", "classification", "nonfinite_anchor", "stale_anchor", "moved_anchor", "outside", "queued_free", "removed", "terrain", "hidden", "prop_group", "malformed", "no_offer"]:
		await _assist_begin("actor rejects offer " + invalid)
		if invalid == "terrain": _box(Vector2(84, 175), Vector2(.5, 60)); await _sync_geometry()
		_direct_provider(func(_pc, request):
			var answer := _offer(request)
			if invalid == "malformed": return "invalid"
			if invalid == "no_offer": return {}
			match invalid:
				"token", "sample_tick", "actor_id", "attack_serial", "candidate_id": answer[invalid] += 1
				"typed_attestation": answer.visible = 1
				"missing_perceived": answer.erase("perceived")
				"classification": answer.classification = "prop"
				"nonfinite_anchor": answer.local_anchor = Vector2.INF
				"stale_anchor": answer.anchor_world.x += .0001
				"moved_anchor": assist_target.position.x += 1
				"outside": answer.local_anchor = Vector2(-200, -15); answer.anchor_world = assist_target.to_global(answer.local_anchor)
				"queued_free": assist_target.queue_free()
				"removed": world.remove_child(assist_target)
				"hidden": assist_target.hide()
				"prop_group": assist_target.add_to_group("props")
			return answer)
		await _step({"attack": true}); await _ordinary_done()
		_check(actor.facing == 1 and _query_count() == 1, "actor independently rejects invalid, stale, outside or occluded host offers")
		_check(_count("attack_started") == 1, "a rejected optional offer does not erase the admitted ordinary attack")
		if invalid == "removed": assist_target.free()
		await _finish()
	await _assist_begin("equal X current anchor keeps facing")
	actor.melee_chain.steps[0].strike_center_offset.x = 0
	assist_target.position.x = actor.position.x; await _sync_geometry()
	_direct_provider(func(_pc, request): return _offer(request))
	await _step({"attack": true})
	_check(actor.facing == 1 and String(_state().entry_assist_reason) == "equal_x", "equal horizontal anchor has no invented facing choice")
	await _ordinary_done(); await _finish()

func _entry_provenance_cases() -> void:
	for route in ["custom_start", "loop_to_zero", "retained_next", "repeat", "charge", "new_episode"]:
		await _assist_begin("first fresh provenance " + route, true, 1, route if route in ["repeat", "charge"] else "null")
		if route == "custom_start": actor.melee_chain.start_step = 1
		if route == "loop_to_zero": actor.melee_chain.steps[1].next_step = 0
		await _step({"attack": true})
		if route == "custom_start": await _follow_to(2)
		if route == "loop_to_zero": await _follow_to(1); await _follow_to(0)
		if route == "retained_next": await _attack_phase("idle"); await _step({"attack": true})
		if route == "repeat": await _until(func(): return _count("attack_started") >= 4, {"attack": true}, 2.5)
		if route == "charge": await _until(func(): return _charged_starts().size() == 1, {"attack": true}, 1.5)
		if route == "new_episode": await _ordinary_done(); await _seconds({}, actor.melee_chain.idle_retention_seconds + .05); await _step({"attack": true})
		_check(_query_count() == (2 if route == "new_episode" else 1), "entry queries follow genuine initial fresh provenance, never step index or derived requests")
		var starts := _event_rows("attack_started")
		_check(starts.size() >= 2, "the exclusion is exercised through connected real successor admissions")
		await _ordinary_done(); await _finish()

func _entry_lifecycle_cases() -> void:
	for mutation in ["reset", "forced", "replace_provider", "turn_gate", "ability", "position", "recursive_tick", "pause", "configuration_roundtrip", "provider_roundtrip"]:
		await _assist_begin("provider callback " + mutation)
		_direct_provider(func(pc, request):
			var answer := _offer(request)
			match mutation:
				"reset": pc.reset_actor(Vector2(120, 200), 1)
				"forced": pc.begin_main_action(&"forced", {"can_attack": false})
				"replace_provider": pc.set_attack_entry_provider(func(_actor, _request): return {})
				"provider_roundtrip":
					var original: Callable = query_provider
					pc.set_attack_entry_provider(func(_actor, _request): return {})
					pc.set_attack_entry_provider(original)
				"turn_gate": pc.set_weapon_permissions({"can_turn": false})
				"ability": pc.enable_attack_entry_assist = false
				"position": pc.position.x += 2
				"recursive_tick": pc.physics_tick(dt, {"attack": true})
				"pause": pc.apply_hitpause(.05)
				"configuration_roundtrip":
					var resource = pc.melee_chain; pc.melee_chain = null; pc.melee_chain = resource
			return answer)
		await _step({"attack": true})
		_check(actor.facing == 1 and query_records.size() == 1, "provider mutation or reentry cannot apply the stale suggestion or nest a query")
		if mutation == "reset": _check(actor.position == Vector2(120, 200) and actor.weapon_phase == &"idle", "explicit reset aborts the old admitted callback")
		if mutation == "forced": _check(actor.main_action == &"forced", "new forced ownership survives the provider return")
		await _seconds({}, .6)
		_check(query_records.size() == 1, "discarded offers are never retried during the old attack")
		await _finish()
	await _assist_begin("decision callback reset retires old attack")
	actor.movement_event.connect(func(label, _data):
		if label == &"entry_assist_resolved": actor.reset_actor(Vector2(120, 200), 1))
	await _step({"attack": true}); await _seconds({}, .3)
	_check(_count("attack_started") == 0 and actor.weapon_phase == &"idle", "reset from decision callback suppresses stale attack-start events and contact")
	_check(contact_receipts.is_empty(), "retired entry cannot later confirm a hit")
	await _finish()
	await _assist_begin("old host detach cannot revoke replacement")
	var newer = RecordingHost.new()
	newer.recorder = _record_offer
	newer.actor_path = NodePath(""); world.add_child(newer)
	newer.register_candidate(assist_target, {"classification": "opponent", "eligible": true, "perceived": true, "visible": true})
	newer.bind_actor(actor); newer.set_assist_enabled(true)
	assist_host.set_assist_enabled(false); assist_host.unbind_actor()
	await _step({"attack": true}); await _ordinary_done()
	_check(actor.facing == -1 and newer.query_count == 1 and assist_host.query_count == 0, "old host toggles and detachment preserve exact replacement ownership")
	newer.unbind_actor(); await _seconds({}, .4); actor.reset_actor(Vector2(100, 200), 1); await _step({"attack": true}); await _ordinary_done()
	_check(newer.query_count == 1 and actor.facing == 1, "removing the owning host leaves a reusable manual actor")
	await _finish()


	await _assist_begin("same actor resets and toggles host without stale queries")
	var prior_queries := 0
	for cycle in range(4):
		var direction := 1 if cycle % 2 == 0 else -1
		var enabled := cycle % 2 == 0
		actor.reset_actor(Vector2(100, 200), direction)
		assist_target.position = Vector2(100 - direction * 30, 200)
		assist_target.reset_target(); assist_host.set_assist_enabled(enabled)
		await _sync_geometry(); await _step(); await _step({"attack": true}); await _ordinary_done()
		_check(assist_target.hits == (1 if enabled else 0), "each reset cycle uses only its current host enablement and real strike")
		_check(assist_host.query_count == prior_queries + (1 if enabled else 0), "reset and disabled cycles cannot revive or retry an old offer")
		prior_queries = assist_host.query_count
	await _finish()

func _entry_native_cases() -> void:
	for route in ["neutral", "manual", "paused_tap"]:
		await _assist_begin("parsed input entry " + route)
		if route == "paused_tap": actor.apply_hitpause(.05)
		if route == "manual": _entry_key(KEY_D, true)
		_entry_key(KEY_J, true); await _step(null)
		_entry_key(KEY_J, false); await _step(null)
		await _seconds(null, .7)
		_check(_query_count() == (0 if route == "manual" else 1), "actual parsed edges obey neutral/manual and paused-buffer admission")
		_check(_count("attack_started") == 1, "one parsed press produces one admitted strike")
		await _finish()
func _entry_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = pressed
	native_edges.append({"before_case_tick": ticks, "engine_tick": Engine.get_physics_frames(), "physical_keycode": code, "pressed": pressed})
	Input.parse_input_event(event)
