extends Node2D
## A review fixture for ONE component. Guided comparisons drive the ordinary
## PC inputs and the existing swept melee instrument; they never set damage.
const LABELS := ["DIRECT HIT", "HELD GUARD", "TIMED PARRY", "ROLL THROUGH"]
@onready var player = $Player
@onready var health = $Player/Health
@onready var contact = $Contact
var replay := -1
var replay_time := 0.0
var sequence := false
var sent := false
var paused := false
var last_outcome := "READY"
var last_loss := 0.0
var flash := 0.0
var receipts: Array[Dictionary] = []
var frames: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var recording := 0.0
var capture_clock := 0.0
var capture_started := 0

func _ready() -> void:
	health.damage_processed.connect(_on_damage)
	DirAccess.make_dir_recursive_absolute("res://delivery/health_capture")
	FileAccess.open("res://delivery/.gdignore", FileAccess.WRITE).store_string("Generated review captures.\n")
	queue_redraw()

func reset_review() -> void:
	contact.reset_fixture()
	player.reset_actor(Vector2(300, 260), 1)
	last_outcome = "READY"
	last_loss = 0
	flash = 0
	sent = false

func start_replay(index: int, continue_sequence := false) -> void:
	paused = false
	contact.set_fixture_paused(false)
	reset_review()
	replay = clampi(index, 0, 3)
	replay_time = 0
	sequence = continue_sequence

func _physics_process(dt: float) -> void:
	if paused: return
	var inputs: Variant = null
	if replay >= 0:
		replay_time += dt
		inputs = {}
		if not sent and replay_time >= 0.25:
			sent = contact.request_attack()
		if replay == 1: inputs = {"shield": true}
		if replay == 2 and sent and (contact.phase == &"active" or contact.phase == &"telegraph" and contact.elapsed >= 0.60): inputs = {"shield": true}
		if replay == 3 and sent and (contact.phase == &"active" or contact.phase == &"telegraph" and contact.elapsed >= 0.625): inputs = {"roll": true}
		if replay_time >= 2.7:
			if sequence and replay < 3: start_replay(replay + 1, true)
			else:
				replay = -1
				sequence = false
	player.physics_tick(dt, inputs)
	flash = maxf(0, flash - dt)
	queue_redraw()

func _on_damage(receipt: Dictionary) -> void:
	last_outcome = String(receipt.outcome).to_upper()
	last_loss = receipt.applied
	flash = 0.45
	var saved := receipt.duplicate()
	saved["replay"] = replay
	saved["raw_seconds"] = (Time.get_ticks_usec() - capture_started) / 1000000.0
	if recording > 0: receipts.append(saved)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4: start_replay(event.physical_keycode - KEY_1)
		KEY_Q: start_replay(0, true)
		KEY_F:
			if not paused and replay < 0: contact.request_attack()
		KEY_R:
			replay = -1
			sequence = false
			reset_review()
		KEY_ESCAPE:
			paused = not paused
			contact.set_fixture_paused(paused)
		KEY_O:
			recording = 12
			capture_clock = 0
			capture_started = Time.get_ticks_usec()
			frames.clear()
			trace.clear()
			receipts.clear()
		KEY_P: get_viewport().get_texture().get_image().save_png("res://delivery/MOKSHA-Health-Review.png")
	queue_redraw()

func _process(dt: float) -> void:
	if recording <= 0: return
	recording -= dt
	capture_clock += dt
	if capture_clock >= 1.0 / 60.0:
		capture_clock -= 1.0 / 60.0
		var filename := "frame_%04d.png" % frames.size()
		get_viewport().get_texture().get_image().save_png("res://delivery/health_capture/" + filename)
		var elapsed := (Time.get_ticks_usec() - capture_started) / 1000000.0
		frames.append({"file": filename, "raw_seconds": elapsed})
		trace.append({"seconds": elapsed, "replay": replay, "health": health.current_health, "outcome": last_outcome, "loss": last_loss, "fixture_contacts": contact.contacts, "counter_count": contact.counters, "position": player.position, "state": player.main_action, "shield": player.shield_phase, "invulnerable": player.is_roll_invulnerable(), "paused": paused})
	if recording <= 0:
		FileAccess.open("res://delivery/M12-NATIVE-CAPTURE.json", FileAccess.WRITE).store_string(JSON.stringify({"actor_sha256": FileAccess.get_sha256("res://combat_pc/player.gd"), "component_sha256": FileAccess.get_sha256("res://combat_pc/components/health_component.gd"), "review_sha256": FileAccess.get_sha256("res://combat_pc/health_review.gd"), "method": "Native viewport; guided comparisons use normal PC input and actual swept contact fixture; captured monotonic timing", "frames": frames, "trace": trace, "receipts": receipts}, "  "))

func _draw() -> void:
	if not is_instance_valid(health): return
	var font := ThemeDB.fallback_font
	var ink := Color("dce9ee")
	var muted := Color("8099a9")
	var accent := Color("8fe0ca") if last_loss <= 0 else Color("ed917c")
	draw_rect(Rect2(0, 0, 640, 360), Color("091018"))
	draw_string(font, Vector2(28, 30), "MOKSHA / ONE PIECE: HEALTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	draw_string(font, Vector2(28, 49), "DAMAGE FOLLOWS THE DEFENSE OUTCOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, muted)
	draw_string(font, Vector2(28, 82), "HEALTH  %.1f / %.0f" % [health.current_health, health.capacity], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	draw_rect(Rect2(28, 94, 584, 16), Color("22303b"))
	draw_rect(Rect2(28, 94, 584 * health.current_health / health.capacity, 16), accent)
	draw_string(font, Vector2(28, 133), "%s    /    HEALTH LOST  %.1f" % [last_outcome, last_loss], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent)
	draw_string(font, Vector2(28, 155), "REPLAY: " + LABELS[replay] if replay >= 0 else "FREE CONTROL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, muted)
	if flash > 0: draw_circle(player.position + Vector2(0, -17), 23, Color(accent, flash * 0.25))
	draw_line(Vector2(28, 260), Vector2(612, 260), Color("7897a5"), 1)
	draw_string(font, Vector2(239, 281), "ONE PC     /     CONTACT RIG", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, muted)
	draw_string(font, Vector2(28, 310), "1 HIT    2 GUARD    3 PARRY    4 ROLL    Q REPLAY ALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ink)
	draw_string(font, Vector2(28, 329), "A/D MOVE   F SEND HIT   K SHIELD   SHIFT ROLL   R RESET", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, muted)
	draw_string(font, Vector2(28, 348), "ESC PAUSE" + ("   /   HEALTH EMPTY - R RESET" if health.current_health == 0 else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, muted)
	if paused: draw_string(font, Vector2(282, 190), "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
