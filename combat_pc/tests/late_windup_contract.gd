extends SceneTree
## Seeded controller unit contracts, not human gameplay or hearing integration.
const ACTOR = preload("res://combat_pc/player.tscn")
const STEP = preload("res://combat_pc/resources/melee_step.gd")
var actor: Node
var checks := 0
var failures: Array[String] = []
var token: Dictionary = {}
var mode := "admit"
var duration := 0.56
var hz := 60
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	run.call_deferred()
func fresh(windup := 0.56) -> void:
	if is_instance_valid(actor): actor.free()
	actor = ACTOR.instantiate(); actor.automatic_physics = false; root.add_child(actor)
	actor.movement_event.connect(on_event)
	duration = windup
func start() -> void:
	var step = STEP.new(); step.windup_seconds = duration; step.active_seconds = 0.14; step.recovery_seconds = 0.72
	actor._active_melee_step = step
	actor._start_attack_instance()
func on_event(kind: StringName, _packet: Dictionary) -> void:
	if kind != &"attack_started": return
	token = actor.late_windup_admission_snapshot()
	check(not token.is_empty(), "synchronous admission token exists")
	if mode == "none": return
	if mode == "nested":
		var prior = token.duplicate(true)
		actor._cancel_attack(&"damage")
		mode = "admit"
		start()
		check(not actor.request_late_windup(prior, 0.18, 0.5), "outer dispatch cannot admit against nested replacement")
		return
	if mode == "cancel":
		actor._cancel_attack(&"damage")
		check(not actor.request_late_windup(token, 0.18, 0.5), "cancel invalidates current listener token"); return
	if mode == "reset":
		actor.reset_actor(Vector2.ZERO)
		check(not actor.request_late_windup(token, 0.18, 0.5), "reset invalidates current listener token"); return
	if mode == "reconfigure":
		actor.melee_chain = load("res://demo/resources/sentinel_melee.tres").duplicate(true)
		check(not actor.request_late_windup(token, 0.18, 0.5), "configuration replacement rejects token"); return
	var stale = token.duplicate(); stale.action_generation += 1
	check(not actor.request_late_windup(stale, 0.18, 0.5), "action generation fence")
	check(not actor.request_late_windup(token, NAN, 0.5), "NaN rejected")
	check(not actor.request_late_windup(token, 0.181, 0.5), "oversized tail rejected")
	check(not actor.request_late_windup(token, 0.18, 0.49), "unbounded rate rejected")
	check(actor.request_late_windup(token, 0.18, 0.5), "one bounded admission")
	check(not actor.request_late_windup(token, 0.18, 0.5), "duplicate rejected")
func run() -> void:
	fresh(); start()
	check(actor.late_windup_admission_snapshot().is_empty(), "scope closes after emission")
	check(not actor.request_late_windup(token, 0.18, 0.5), "retained token cannot reopen scope")
	actor._advance_melee(0.30)
	check(is_equal_approx(actor._weapon_elapsed, 0.30), "early windup unchanged")
	actor._advance_melee(0.20)
	check(is_equal_approx(actor._weapon_elapsed, 0.44), "delta crosses start of late tail")
	check(is_equal_approx(actor._attack_step_elapsed, 0.44), "step clock matches attack clock")
	actor._advance_melee(0.24)
	check(actor.weapon_phase == &"active", "tail naturally reaches active")
	check(is_equal_approx(actor.late_windup_snapshot().extra_elapsed, 0.18), "extra bounded at requested cap")
	actor._attack_active_sampled = true; actor._advance_melee(0.14)
	check(actor.weapon_phase == &"recovery" and is_zero_approx(actor._weapon_elapsed), "active duration unchanged")
	actor._advance_melee(0.72)
	check(actor.weapon_phase == &"idle" and actor.late_windup_snapshot().is_empty(), "finish retires lease")
	fresh(); start(); actor._advance_melee(0.80)
	check(actor.weapon_phase == &"active" and is_equal_approx(actor._weapon_elapsed, 0.06), "one delta crosses both boundaries with normal residual")
	actor._advance_melee(0.3)
	check(actor.weapon_phase == &"active", "existing unsampled active barrier retained")
	for short in [0.0, 0.002, 0.1]:
		fresh(short); start()
		var effective = maxf(short, 0.001)
		actor._advance_melee(effective * 1.5)
		check(actor.weapon_phase == &"active", "zero/short authored windup crosses bounded effective tail")
		check(is_equal_approx(actor.late_windup_snapshot().extra_elapsed, effective * 0.5), "short tail capped at half effective duration")
	for interruption in ["cancel", "reset", "reconfigure"]:
		mode = interruption; fresh(); start(); check(actor.late_windup_snapshot().is_empty(), "interruption leaves no timing lease")
	mode = "admit"; fresh(); start()
	actor._action_generation += 1 # Seed a legal locomotion-generation change without canceling the weapon.
	check(not actor.late_windup_snapshot().is_empty(), "later action generation alone does not revoke weapon lease")
	actor._advance_melee(0.5); check(is_equal_approx(actor._weapon_elapsed, 0.44), "continued weapon retains admitted rate")
	var old_token = token.duplicate(); actor._cancel_attack(&"damage"); start()
	check(token.serial != old_token.serial and token.admission_id != old_token.admission_id, "new step has fresh serial and admission identity")
	check(not actor.request_late_windup(old_token, 0.18, 0.5), "prior step token rejected")
	mode = "nested"; fresh(); start()
	check(actor.attack_serial == 2 and actor.late_windup_snapshot().serial == 2, "nested replacement keeps only newer lease")
	check(actor.late_windup_admission_snapshot().is_empty(), "nested and outer admission scopes both closed")
	# Actual capture/admission functions on a deliberately authored test chain.
	fresh()
	var chain = load("res://combat_pc/resources/light_chain.tres").duplicate(true)
	chain.steps[0].windup_seconds = 0.56
	chain.steps[0].followup_open_seconds = 0.4
	chain.steps[0].followup_close_seconds = 0.9
	chain.followup_buffer_seconds = 0.05
	actor.melee_chain = chain
	actor._capture_attack_input()
	check(actor._try_attack(), "authored chain commits through normal attack admission")
	actor._advance_melee(0.4)
	actor._capture_attack_input()
	check(actor._chain_pending.is_empty(), "follow-up stays closed until attack-time threshold, not real-time threshold")
	actor._advance_melee(0.04)
	actor._capture_attack_input()
	check(not actor._chain_pending.is_empty(), "delayed follow-up window admits actual request")
	actor._attack_tick_sequence += 1
	actor._melee_reuse_lock_remaining = 0.1
	actor._advance_chain_clocks(0.06)
	check(actor._chain_pending.is_empty() and actor.weapon_phase == &"windup", "queued request expires in real time even while tail remains")
	check(is_equal_approx(actor._melee_reuse_lock_remaining, 0.04), "reuse lock retains real-time semantics")
	# Hitpause uses the existing physics entry early-return, not the tail integrator.
	var before = actor._weapon_elapsed
	actor.hitpause_remaining = 0.2
	actor.physics_tick(0.05, {})
	check(actor._weapon_elapsed == before and is_equal_approx(actor.hitpause_remaining, 0.15), "local hitpause freezes attack and drains its own real timer")
	check(actor.enter_defeated(root), "defeat authority accepts fixture owner")
	check(actor.late_windup_snapshot().is_empty(), "defeat retires lease")
	mode = "admit"; fresh(); start()
	var before_pause: Dictionary = actor.late_windup_snapshot()
	paused = true
	check(not actor.request_late_windup(token, 0.18, 0.5), "paused tree cannot admit")
	await process_frame
	check(actor.late_windup_snapshot() == before_pause, "paused tree does not consume timing")
	paused = false
	actor.free(); actor = null
	print(JSON.stringify({"checks": checks, "failures": failures, "physics_hz": hz, "scope": "seeded timing contracts"}))
	quit(0 if failures.is_empty() else 1)
