extends SceneTree
## Actual raw-input/intent attacks and Godot overlap/ray contact. Explicit
## lifecycle and malformed API probes below are not simulated successful hits.
const Actor = preload("res://simulation/actors/shared_actor.tscn")
const ReceiverScene = preload("res://simulation/components/incoming_strike_receiver.tscn")
const PlayerSource = preload("res://simulation/components/player_input_source.gd")
const NPCSource = preload("res://simulation/components/npc_input_source.gd")
const Capabilities = preload("res://simulation/resources/actor_capabilities.gd")
const ContactProfile = preload("res://simulation/resources/actor_contact_profile.gd")
const Cargo = preload("res://simulation/components/physical_cargo.tscn")
class RawSource extends Node:
	var raw := {}
	func sample_raw(_actor: Node, _dt: float) -> Dictionary: return raw.duplicate(true)
	func reset_intent() -> void: raw.clear()
class Policy extends Node:
	var intent := {}
	func sample_intent(_actor: Node, _dt: float) -> Dictionary: return intent.duplicate(true)
	func reset_intent() -> void: intent.clear()
var hz := 120
var checks := 0
var failures: Array[String] = []
var scenarios: Array[String] = []
var label := ""
var world: Node2D
var left: Node2D
var right: Node2D
var receipts: Array[Dictionary] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()
func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func _until(predicate: Callable, seconds := 1.2) -> bool:
	for i in ceili(hz * seconds):
		await _frames(1)
		if predicate.call(): return true
	return false
func _check(value: bool, detail: String) -> void:
	checks += 1
	if not value: failures.append(label + ": " + detail)
func _surface(at: Vector2, size: Vector2, layer := 1) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = layer
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	return body
func _actor(at: Vector2, mode: String, facing := 1) -> Node2D:
	var actor := Actor.instantiate() as Node2D
	actor.position = at
	actor.initial_facing = facing
	var source: Node = PlayerSource.new() if mode == "PC" else (NPCSource.new() if mode == "NPC" else RawSource.new())
	source.name = "InputSource"
	actor.add_child(source)
	actor.set_meta("mode", mode)
	if mode == "NPC":
		var policy := Policy.new()
		policy.name = "PatrolPolicy"
		actor.add_child(policy)
	world.add_child(actor)
	actor.get_node("BodyShape/IncomingStrikeReceiver").strike_resolved.connect(func(receipt: Dictionary): receipts.append(receipt.duplicate(true)))
	return actor
func _begin(next: String, lm := "PC", rm := "NPC", distance := 36.0) -> void:
	label = next
	scenarios.append(next)
	receipts = []
	world = Node2D.new()
	root.add_child(world)
	_surface(Vector2(300,220), Vector2(1000,40))
	left = _actor(Vector2(200,200), lm)
	right = _actor(Vector2(200 + distance,200), rm, -1)
	await _frames(5)
func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func _request(actor: Node, buttons: Dictionary) -> void:
	match actor.get_meta("mode"):
		"PC":
			for entry in [["attack",KEY_J],["shield",KEY_K],["roll",KEY_SHIFT],["jump",KEY_SPACE],["left",KEY_A],["right",KEY_D],["down",KEY_S]]: _key(entry[1], buttons.get(entry[0], false) == true)
		"NPC": actor.get_node("PatrolPolicy").intent = buttons.duplicate(true)
		_: actor.get_node("InputSource").raw = buttons.duplicate(true)
func _attack(actor: Node) -> void:
	_request(actor, {"attack":true})
	await _frames(1)
	_request(actor, {})
func _receiver(actor: Node) -> Node: return actor.get_node("BodyShape/IncomingStrikeReceiver")
func _health(actor: Node) -> float: return actor.get_node("Health").current_health
func _end() -> void:
	for key in [KEY_J,KEY_K,KEY_SHIFT,KEY_SPACE,KEY_A,KEY_D,KEY_S]: _key(key,false)
	paused = false
	world.queue_free()
	await _frames(3)
func _run() -> void:
	for pair in [["PC","NPC"],["NPC","PC"],["NPC","NPC"]]:
		await _begin("actual %s to %s strike" % pair, pair[0], pair[1])
		_check(left.get_script() == right.get_script(), "same controller script")
		_check(left.collision_layer == 32 and right.collision_layer == 32 and not left.is_in_group("combat_pc") and not right.is_in_group("combat_pc"), "generic common layer/groups")
		await _attack(left)
		_check(await _until(func(): return not receipts.is_empty()), "real source input reaches overlap receiver")
		_check(_health(right) == 29 and _health(left) == 30, "one damage to peer, never own hurtbox")
		_check(receipts.size() == 1 and receipts[0].outcome == &"hurt" and receipts[0].amount == 1, "exact hurt receipt")
		_check(right.velocity.x > 0 and right.main_action == &"hurt", "existing owner applies authored impulse")
		_check(left.get_node("NoiseRelay").forwarded_count > 0 and right.get_node("NoiseRelay").forwarded_count > 0 and left.get_node("HearingSensor").heard_count > 0, "committed attack/hurt noise and actual shared hearing")
		await _frames(ceili(hz * 0.5))
		_check(receipts.size() == 1 and _health(right) == 29, "active frames/held release do not duplicate")
		await _end()
	await _begin("NPC to PC reverse-direction actual strike")
	await _attack(right)
	_check(await _until(func(): return not receipts.is_empty()), "right-facing-left NPC reaches real PC")
	_check(_health(left) == 29 and left.velocity.x < 0 and _health(right) == 30, "reverse geometry and impulse")
	await _end()
	await _defense_cases()
	await _negative_cases()
	await _lifecycle_cases()
	await _identity_cases()
	await _composition_cases()
	await _capture_and_retirement_cases()
	await _autonomous_policy_case()
	await _stage_bounds_case()
	print("SHARED INCOMING STRIKE %d Hz: %d scenarios, %d checks, %d failures" % [hz,scenarios.size(),checks,failures.size()])
	for failure in failures: printerr(failure)
	var report := {"hz":hz,"scenarios":scenarios,"checks":checks,"failures":failures,"execution":"Actual Godot callbacks and input-driven contacts; lifecycle/malformed probes are explicitly labelled."}
	FileAccess.open("res://simulation/evidence/strike_%d.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit(0 if failures.is_empty() else 1)
func _defense_cases() -> void:
	for mode in ["PC", "NPC"]:
		for defense in ["guard", "parry", "absent_shield", "rear_guard", "unblockable"]:
			await _begin(mode + " actual " + defense, "NPC", mode)
			if defense == "absent_shield":
				var caps := Capabilities.new()
				caps.can_shield = false
				right.get_node("IntentDriver").configure_capabilities(caps)
				await _frames(2)
			if defense == "rear_guard": right.reset_actor(right.position,1); await _frames(3)
			if defense == "unblockable": _receiver(right).blockable = false
			_request(right, {"shield":true})
			if defense != "parry": await _frames(ceili(hz * .3))
			await _attack(left)
			_check(await _until(func(): return not receipts.is_empty()), "actual attack physically contacts defense host")
			var expected := "parried" if defense == "parry" else ("guarded" if defense == "guard" else "hurt")
			_check(not receipts.is_empty() and receipts[0].outcome == StringName(expected), "expected " + expected)
			var expected_health := 30.0 if defense == "parry" else (29.75 if defense == "guard" else 29.0)
			_check(_health(right) == expected_health, "same configured scalar outcome")
			_check(right.get_node("ShieldContactAdapter").confirmed_counters == 0, "no unsupported counter advertised")
			await _end()
	for mode in ["PC","NPC"]:
		await _begin(mode + " actual roll contact", "NPC", mode, 66.0)
		_request(right,{"roll":true})
		await _attack(left)
		_check(await _until(func(): return not receipts.is_empty()), "rolling real small body intersects active strike")
		_check(not receipts.is_empty() and receipts[0].outcome == &"evaded" and _health(right) == 30, "existing roll window owns evasion")
		await _end()
func _negative_cases() -> void:
	for condition in ["wall","range","receiver_disabled","receiver_removed","source_disabled","source_unbound","source_processing","host_processing","hurtbox_offmask","body_shape_disabled","source_self"]:
		await _begin("actual rejection / " + condition, "raw", "NPC", 120.0 if condition == "range" else 36.0)
		match condition:
			"wall": _surface(Vector2(220,174),Vector2(4,52))
			"receiver_disabled": _receiver(right).enabled = false
			"receiver_removed": _receiver(right).queue_free()
			"source_disabled": left.get_node("ContactAdapter").enabled = false
			"source_unbound": left.get_node("ContactAdapter").bind_actor(null)
			"source_processing": left.get_node("ContactAdapter").process_mode = Node.PROCESS_MODE_DISABLED
			"host_processing": right.set_physics_process(false)
			"hurtbox_offmask": _receiver(right).collision_layer = 128
			"body_shape_disabled": right.get_node("BodyShape").disabled = true
			"source_self": right.position.x = 500
		await _frames(2)
		await _attack(left)
		await _frames(ceili(hz * .4))
		_check(_health(right) == 30 and _health(left) == 30 and receipts.is_empty(), "no target response")
		if condition == "wall": _check(left.get_node("ContactAdapter").occluded_contacts > 0, "actual obstruction ray rejects overlap")
		await _end()
	await _begin("API foreign bound-source rejection", "raw", "raw")
	left.get_node("ContactAdapter").enabled = false
	left.strike_sample.connect(func(source,packet): right.get_node("ContactAdapter").sample_strike(source,packet))
	await _attack(left)
	await _frames(ceili(hz*.3))
	_check(_health(left) == 30 and _health(right) == 30 and receipts.is_empty(), "peer adapter cannot claim another actor sample")
	await _end()
	for field in ["damage", "center", "impulse"]:
		await _begin("API forged current " + field, "raw", "raw")
		var adapter: Node = left.get_node("ContactAdapter")
		adapter.bind_actor(null)
		var probes: Array[bool] = []
		left.strike_sample.connect(func(source,packet):
			var bad: Dictionary = packet.duplicate(true)
			bad[field] = 99.0 if field == "damage" else Vector2(236,180)
			adapter.sample_strike(source,bad)
			probes.append(_health(right) == 30))
		# Keep normal signal disconnected: only the malformed API call is tried.
		adapter.actor = left
		await _attack(left)
		await _frames(ceili(hz*.3))
		_check(not probes.is_empty() and not probes.has(false) and _health(right) == 30, "same-serial alteration cannot earn contact permit")
		await _end()
func _lifecycle_cases() -> void:
	for operation in ["receiver_reset", "receiver_toggle", "receiver_remove", "receiver_replace", "source_reset", "source_toggle", "adapter_rebind", "mask_change", "shape_remove", "pause_cycle", "always_pause_cycle"]:
		await _begin("confirmation callback / " + operation, "raw", "raw")
		var called: Array[bool] = []
		if operation == "always_pause_cycle":
			left.process_mode = Node.PROCESS_MODE_ALWAYS
			right.process_mode = Node.PROCESS_MODE_ALWAYS
		left.movement_event.connect(func(kind,_payload):
			if kind != &"strike_confirmed" or not called.is_empty(): return
			called.append(true)
			match operation:
				"receiver_reset": right.reset_actor(right.position,-1)
				"receiver_toggle":
					_receiver(right).enabled = false
					_receiver(right).enabled = true
				"receiver_remove": _receiver(right).queue_free()
				"receiver_replace":
					_receiver(right).queue_free()
					var replacement = ReceiverScene.instantiate()
					replacement.name = "Replacement"
					right.get_node("BodyShape").add_child(replacement)
				"source_reset": left.reset_actor(left.position,1)
				"source_toggle":
					left.get_node("ContactAdapter").enabled = false
					left.get_node("ContactAdapter").enabled = true
				"adapter_rebind": left.get_node("ContactAdapter").bind_actor(right)
				"mask_change": left.get_node("ContactAdapter").target_mask = 0
				"shape_remove": _receiver(right).get_node("Shape").queue_free()
				"pause_cycle", "always_pause_cycle":
					paused = true
					paused = false
		)
		await _attack(left)
		await _frames(ceili(hz*.4))
		_check(not called.is_empty(), "real source confirmation invokes lifecycle hook")
		_check(_health(right) == 30 and receipts.is_empty(), "retired capture causes zero target response before dispatch")
		await _end()
	for stage in [&"hurt_started", &"defense_resolved"]:
		for operation in ["source_reset", "receiver_detach", "target_reset"]:
			await _begin("committed response callback / " + String(stage) + "/" + operation,"raw","raw")
			var third := _actor(Vector2(237,200),"raw",-1)
			var called: Array[bool] = []
			right.movement_event.connect(func(kind,_payload):
				if kind != stage or not called.is_empty(): return
				called.append(true)
				match operation:
					"source_reset": left.reset_actor(left.position,1)
					"receiver_detach": _receiver(right).unbind()
					"target_reset": right.reset_actor(right.position,-1)
			)
			# The first receiver queried is deliberately not assumed; either live
			# target may be first in Godot's overlap ordering.
			third.get_node("BodyShape/IncomingStrikeReceiver").enabled = false
			await _attack(left)
			await _frames(ceili(hz*.3))
			_check(not called.is_empty(), "real host operation reaches callback")
			_check(_health(right) == (30 if operation == "target_reset" else 29), "committed operation obeys controller target reset fence")
			_check(receipts.is_empty(), "retirement suppresses bridge feedback")
			await _end()
func _identity_cases() -> void:
	await _begin("actual distinct strikes and source reset", "raw", "raw")
	await _attack(left)
	_check(await _until(func(): return _health(right) == 29), "first real strike")
	var serial: int = left.attack_serial
	left.reset_actor(Vector2(200,200),1)
	right.reset_actor(Vector2(236,200),-1)
	await _frames(5)
	await _attack(left)
	_check(await _until(func(): return _health(right) == 29), "fresh post-reset strike reaches new life")
	_check(left.attack_serial > serial and receipts.size() == 2, "source serial is lifetime monotonic; epoch is separate")
	await _end()
	await _begin("replacement plus reset cannot replay active source", "raw", "raw")
	var replaced: Array[bool] = []
	_receiver(right).strike_resolved.connect(func(_receipt):
		if not replaced.is_empty(): return
		replaced.append(true)
		var old = _receiver(right)
		old.unbind()
		old.get_parent().remove_child(old)
		old.queue_free()
		var replacement = ReceiverScene.instantiate()
		right.get_node("BodyShape").add_child(replacement)
		right.reset_actor(Vector2(236,200),-1))
	await _attack(left)
	await _frames(ceili(hz*.4))
	_check(not replaced.is_empty() and _health(right) == 30, "new receiver/new target life cannot replay old strike")
	_check(left.get_node("ContactAdapter").confirmed_contacts == 1, "stable host ID confirms only once")
	await _end()
	await _begin("one sample can contact two peers through source hitpause", "raw", "raw")
	var third := _actor(Vector2(237,200),"NPC",-1)
	await _frames(5)
	await _attack(left)
	_check(await _until(func(): return _health(right) == 29 and _health(third) == 29), "both actual overlaps survive same admitted hitpause sample")
	_check(left.get_node("ContactAdapter").confirmed_contacts == 2 and receipts.size() == 2, "one receipt per actor")
	await _end()
func _composition_cases() -> void:
	await _begin("actual lethal Health Defeat Noise composition", "PC", "NPC")
	left.combat_profile.strike_damage = 40.0
	await _attack(left)
	_check(await _until(func(): return right.is_defeated()), "real strike depletes Health and existing defeat policy")
	_check(_health(right) == 0 and receipts.size() == 1 and receipts[0].amount == 30, "lethal receipt reports actual bounded debit")
	_check(right.get_node("NoiseRelay").forwarded_count > 0 and _receiver(right).capture_strike_generation().is_empty(), "hurt noise commits; defeated receiver admits no new contact")
	await _end()
	await _begin("generic per-instance masks groups and shape", "raw", "raw")
	var config := ContactProfile.new()
	config.body_layer = 128
	config.hurtbox_layer = 256
	config.strike_target_mask = 256
	config.groups = PackedStringArray(["actors","faction_blue"])
	right.get_node("ContactConfig").configure(config)
	config.body_layer = 512
	_check(right.collision_layer == 128 and left.collision_layer == 32 and right.is_in_group("faction_blue") and not left.is_in_group("faction_blue"), "private adopted config, no role branch or resource leak")
	_request(right,{"down":1.0})
	await _frames(4)
	_check(right.crouched and _receiver(right).get_node("Shape").shape == right.get_node("BodyShape").shape and _receiver(right).global_position == right.get_node("BodyShape").global_position, "real crouch uses exact live shape and inherited transform")
	right.reset_actor(right.position,-1)
	await _frames(3)
	_check(_receiver(right).get_node("Shape").shape == right.get_node("BodyShape").shape, "reset retains exact shape identity")
	left.get_node("ContactAdapter").target_mask = 256
	await _attack(left)
	_check(await _until(func(): return _health(right) == 29), "configured masks still admit actual peer contact")
	await _end()
	await _begin("new actor layer remains physical cargo compatible", "raw", "raw", 130.0)
	var cargo := Cargo.instantiate()
	cargo.position = Vector2(200,65)
	world.add_child(cargo)
	_check(await _until(func(): return _health(left) < 30), "real falling cargo collides with layer32 actor")
	_check(_health(left) == 27 and left.get_node("PhysicalImpactReceiver").accepted_count == 1, "existing shared cargo/health response unchanged")
	await _end()

func _capture_and_retirement_cases() -> void:
	for operation in ["target_reset", "source_reset", "toggle", "remove_shape"]:
		await _begin("capture callback / " + operation,"raw","raw")
		var old := _receiver(right)
		old.unbind()
		old.get_parent().remove_child(old)
		old.queue_free()
		var probe := ReceiverScene.instantiate()
		probe.set_script(preload("res://simulation/tests/strike_capture_probe.gd"))
		right.get_node("BodyShape").add_child(probe)
		var called: Array[bool] = []
		probe.after_capture = func():
			if not called.is_empty(): return
			called.append(true)
			match operation:
				"target_reset": right.reset_actor(right.position,-1)
				"source_reset": left.reset_actor(left.position,1)
				"toggle":
					probe.enabled = false
					probe.enabled = true
				"remove_shape": probe.get_node("Shape").queue_free()
		var first_sample: Array[bool] = []
		left.strike_sample.connect(func(_source,_packet):
			if not called.is_empty() and first_sample.is_empty(): first_sample.append(_health(right) == 30 and left.get_node("ContactAdapter").confirmed_contacts == 0))
		await _frames(3)
		await _attack(left)
		await _frames(ceili(hz*.3))
		_check(not called.is_empty() and first_sample == [true], "captured old token rejects before confirmation/target response")
		_check(_health(right) == (29 if operation in ["target_reset","toggle"] else 30), "later genuine active sample may contact a now-eligible unhit actor")
		await _end()
	for operation in ["receiver_detach","source_reset"]:
		await _begin("committed callback ends multi-target sweep / " + operation,"raw","raw")
		var third := _actor(Vector2(237,200),"raw",-1)
		_install_retirement(right,operation)
		_install_retirement(third,operation)
		var first_sample: Array[bool] = []
		left.strike_sample.connect(func(_source,_packet):
			if first_sample.is_empty() and left.get_node("ContactAdapter").confirmed_contacts > 0:
				first_sample.append(_health(right) + _health(third) == 59 and left.get_node("ContactAdapter").confirmed_contacts == 1))
		await _frames(4)
		await _attack(left)
		await _frames(ceili(hz*.3))
		_check(first_sample == [true], "exactly one operation in retired sample regardless of overlap order")
		_check(_health(right) + _health(third) == (58 if operation == "receiver_detach" else 59), "fresh later sample remains distinct from retired source operation")
		_check(receipts.is_empty(), "retired bridge feedback stays suppressed")
		await _end()
func _install_retirement(target: Node, operation: String) -> void:
	var called: Array[bool] = []
	target.movement_event.connect(func(kind,_payload):
		if kind != &"hurt_started" or not called.is_empty(): return
		called.append(true)
		if operation == "receiver_detach": _receiver(target).unbind()
		else: left.reset_actor(left.position,1))

func _autonomous_policy_case() -> void:
	await _begin("autonomous NPC observed strike choice", "raw", "NPC", 140.0)
	var policy := preload("res://simulation/components/melee_intent_policy.gd").new()
	policy.name = "MeleePolicy"
	policy.target_path = NodePath("../../" + String(left.name))
	policy.stop_distance = 34.0
	right.add_child(policy)
	right.get_node("InputSource").policy_path = NodePath("../MeleePolicy")
	var wall := _surface(Vector2(270,160),Vector2(12,80))
	await _frames(ceili(hz*.4))
	_check(_health(left) == 30 and not policy.sees_target, "real wall prevents autonomous sight/attack choice")
	wall.queue_free()
	_check(await _until(func(): return _health(left) < 30,4.0), "fresh clear sight produces movement and actual raw-input strike")
	_check(right.attack_serial > 0 and _health(left) == 29, "policy never assigns successful hit; shared contact owns debit")
	await _end()

func _stage_bounds_case() -> void:
	label = "standalone stage real idle containment"
	scenarios.append(label)
	change_scene_to_file("res://simulation/strike_sandbox.tscn")
	await _frames(5)
	var player: Node2D = current_scene.get_node("Player")
	var enemy: Node2D = current_scene.get_node("NPC")
	var remained_visible := true
	for i in hz * 12:
		await _frames(1)
		remained_visible = remained_visible and player.position.x >= 8 and player.position.x <= 632 and enemy.position.x >= 8 and enemy.position.x <= 632
	_check(remained_visible, "actual solid boundaries retain both actors after repeated real recoil")
	_check(player.get_node("Health").current_health < 30, "autonomous stage makes real repeated contacts")
	_check(current_scene.get_node("HUD/FloorCaption").position.x >= 8, "caption anchor lies inside viewport")
	current_scene.queue_free()
	await _frames(3)
