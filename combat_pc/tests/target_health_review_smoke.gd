extends SceneTree
var review: Node
var failures: Array[String] = []
var observed: Array[Dictionary] = []
var checks := 0
var comparisons: Array[Dictionary] = []
var output_path := ""
var hz := 60
var source_hashes := {}
const SOURCES := ["res://combat_pc/target_health_review.gd", "res://combat_pc/target_health_review.tscn", "res://combat_pc/fixtures/health_target.gd", "res://combat_pc/fixtures/health_target.tscn", "res://combat_pc/components/strike_health.gd", "res://combat_pc/components/health_component.gd", "res://combat_pc/tests/target_health_review_smoke.gd"]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
		if arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
	Engine.physics_ticks_per_second = hz
	call_deferred("_run")
func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	review._unhandled_key_input(event)
func _wait(seconds: float) -> void:
	await create_timer(seconds, true, true).timeout
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _run() -> void:
	for path in SOURCES: source_hashes[path] = FileAccess.get_sha256(path)
	review = load("res://combat_pc/target_health_review.tscn").instantiate()
	root.add_child(review)
	review.health.damage_processed.connect(func(receipt: Dictionary): observed.append(receipt.duplicate(true)))
	await _wait(.15)
	for mirrored in [false, true]:
		if mirrored:
			_key(KEY_F)
			await _wait(.1)
		observed.clear()
		_key(KEY_Q)
		await _wait(6.2)
		comparisons.append({"mirrored":mirrored,"passes":review.comparison.duplicate(true)})
		_check(review.comparison.size() == 2, "Q finishes two passes")
		if review.comparison.size() == 2:
			_check(review.comparison[0].hits == 3 and review.comparison[0].health == 3.0, "OFF: three true contacts, unchanged health")
			_check(review.comparison[1].hits == 3 and is_zero_approx(review.comparison[1].health), "ON: three true contacts, depleted health")
		_check(observed.size() == 3, "exactly three health receipts")
		if observed.size() == 3:
			for i in 3:
				_check(is_equal_approx(float(observed[i].after), [2.0, .85, 0.0][i]), "actual health stage " + str(i))
		_key(KEY_R)
		await _wait(.1)
		_check(review.health.current_health == 3.0 and review.hurtbox.hits == 0 and review.receipts.is_empty(), "reset refills and clears review state")
	_key(KEY_Q)
	await _wait(.42)
	_key(KEY_ESCAPE)
	var t: float = review.guided_time
	var pos: Vector2 = review.target.position
	await _wait(.15)
	_check(review.guided_time == t and review.target.position == pos, "pause freezes trial and target")
	_key(KEY_ESCAPE)
	await _wait(6.2)
	_check(not review.guided and review.comparison.size() == 2, "unpause finishes trial")
	if review.comparison.size() == 2:
		_check(review.comparison[1].hits == 3 and is_zero_approx(review.comparison[1].health), "unpause preserves valid fresh contacts")
	_key(KEY_Q)
	await _wait(.7)
	_key(KEY_Q)
	await _wait(6.2)
	_check(review.comparison.size() == 2 and review.hurtbox.hits == 3 and is_zero_approx(review.health.current_health), "repeated Q resets into clean comparison")
	_key(KEY_1)
	await _wait(.1)
	_check(not review.strike_health.enabled and review.health.current_health == 3.0, "1 selects health off and resets")
	_key(KEY_2)
	await _wait(.1)
	_check(review.strike_health.enabled and review.health.current_health == 3.0, "2 selects health on and resets")
	var stable := true
	for path in source_hashes: stable = stable and source_hashes[path] == FileAccess.get_sha256(path)
	_check(stable, "review source hashes remain stable during run")
	var report := {"physics_hz":hz,"checks":checks,"failures":failures,"comparisons":comparisons,"hashes":source_hashes,"production_hash_stable_during_run":stable,"engine":Engine.get_version_info(),"method":"Actual instantiated review scene, key-handler commands, normal player physics and ContactAdapter. Headless functional checks only; no native rendering or keyboard-event routing claim."}
	if not output_path.is_empty(): FileAccess.open(output_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("TARGET_HEALTH_REVIEW_SMOKE %dHz: %d assertions, %d failures" % [hz,checks,failures.size()])
	for failure in failures: printerr(failure)
	review.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
