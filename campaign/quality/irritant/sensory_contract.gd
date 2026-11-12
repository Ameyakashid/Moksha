extends SceneTree
## Seeded real campaign adapter checks. Not natural traversal or balance proof.
var host: Node
var field: Node
var failures: Array[String] = []
var checks := 0
var interrupt_next := false
func interrupt_notice(_origin: Vector2, kind: StringName, _loudness: float, _source: Node) -> void:
	if interrupt_next and kind == &"irritant_warning":
		interrupt_next=false
		host.state="journal"
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	run.call_deferred()
func ticks(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func events() -> Array:
	return host.bus.event_history.filter(func(e): return e.kind in [&"irritant_warning", &"irritant_hiss"])
func run() -> void:
	root.get_node("NoiseBus").noise_emitted.connect(interrupt_notice)
	host = load("res://campaign/campaign.tscn").instantiate()
	host.save_enabled = false
	root.add_child(host)
	host.start_new(true)
	host.load_sector(1)
	host.set_physics_process(false)
	for enemy in host.enemies: enemy.get_node("IntentDriver").automatic_driver = false
	host.player.reset_actor(Vector2(90,300),1)
	field = load("res://campaign/logic/irritant_disperser.gd").new()
	field.host=host;field.target=host.player;field.position=Vector2(480,268)
	host.irritant_dispersers.append(field);host.room.add_child(field)
	host.bus.clear_history();host.sonar.clear_pulses();host.sonar.event_history.clear()
	await ticks(4)
	check(not field.armed and events().is_empty(),"far source has no warning clock or whole-map emissions")
	host.player.reset_actor(Vector2(260,300),1)
	await ticks(2)
	check(field.armed and field.phase==&"warning" and field.phase_elapsed<.1,"entering range begins full warning")
	check(events().size()==1 and events()[0].kind==&"irritant_warning","first warning explicitly emitted")
	check(host.audio.last_spatial_sound.get("key","")=="irritant_warning","dedicated warning sound, never STEP fallback")
	check(host.sonar.event_history.any(func(e):return e.kind==&"irritant_warning"),"real NoiseBus reaches sonar")
	check(host.sonar._label(&"irritant_warning")=="GAS WARNING","explicit acoustic identity")
	check(field._view.visible,"sighted field view visible")
	host.blind=true;host._apply_senses()
	check(not field._view.visible,"blind transition immediately hides hardware and cloud")
	await ticks(28)
	check(host.sonar.pulses.any(func(p):return p.kind==&"irritant_warning"),"blind retains bounded real warning pulses")
	host.blind=false;host.hearing_retained=false;host._apply_senses()
	check(field._view.visible,"sighted deaf retains field warning")
	host.audio.last_spatial_sound.clear();await ticks(28)
	check(host.audio.last_spatial_sound.is_empty(),"deaf rejects irritant spatial audio")
	check(host.sonar.pulses.is_empty() and host.sonar.event_history.is_empty(),"deaf rejects irritant sonar")
	check(field.target.irritant_snapshot().susceptible,"hearing loss never grants irritant immunity")
	host.hearing_retained=true;host._apply_senses()
	host.player.reset_actor(Vector2(480,300),1)
	field.phase=&"active";field.phase_elapsed=0;field.activate_exposure()
	check(field.exposure_current(host.player),"playing owner permits actual player exposure")
	for boundary in ["journal","dead","transition"]:
		host.state=boundary
		check(not field.current() and not field.exposure_current(host.player),"nonplaying "+boundary+" blocks exposure")
	host.state="playing";host._pending_retry=true
	check(not field.exposure_current(host.player),"pending retry blocks exposure")
	host._pending_retry=false;host._pending_sector=2
	check(not field.exposure_current(host.player),"pending room blocks exposure")
	host._pending_sector=-1;host._loading_campaign=true
	check(not field.exposure_current(host.player),"loading blocks exposure")
	host._loading_campaign=false
	var before=events().size();host.player.reset_actor(Vector2(1000,300),1);field._emit_notice()
	check(events().size()==before,"remote listener gets no new source broadcast")
	host.sonar.clear_pulses();host.sonar.event_history.clear()
	host.bus.emit_noise(field.global_position,&"irritant_warning",.8,field)
	check(host.sonar.event_history.is_empty(),"sonar independently rejects out-of-range irritant")
	host.player.reset_actor(Vector2(260,300),1)
	field.phase=&"warning";field.phase_elapsed=0
	host.audio.last_spatial_sound.clear();host.sonar.clear_pulses();host.sonar.event_history.clear()
	interrupt_next=true;field._emit_notice()
	check(host.state=="journal" and host.audio.last_spatial_sound.is_empty() and host.sonar.event_history.is_empty(),"earlier synchronous subscriber can invalidate owner before audio/sonar consumption")
	host.state="playing";field._emit_notice()
	check(not host.sonar.pulses.is_empty(),"valid owner resumes explicit warning event")
	var pulse: Dictionary=host.sonar.pulses.back()
	field.phase=&"recovery"
	check(not host.sonar.origin_label_visible(pulse),"expired warning cannot remain a current hazard label")
	field.phase=&"warning";host.session_generation+=1
	check(not field.current() and not field.accepts_notice(field.global_position,&"irritant_warning"),"new run generation retires old same-host adapter")
	field.free();host.irritant_dispersers.clear()
	host.queue_free();paused=false;await process_frame;await process_frame
	print(JSON.stringify({"hz":Engine.physics_ticks_per_second,"checks":checks,"failures":failures,"scope":"Seeded save-disabled campaign sensory/lifecycle adapter; no traversal or human balance claim"}))
	quit(1 if failures.size() else 0)
