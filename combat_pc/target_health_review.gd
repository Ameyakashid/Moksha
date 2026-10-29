extends Node2D
## Small health-only comparison. Existing input, strike queries, knockback and
## motor are the only authority for attacks, contacts and physical response.
const TAP_TIMES := [0.35, 0.55, 0.78]
const PASS_SECONDS := 3.0

@onready var player = $Player
@onready var target = $Target
@onready var hurtbox = $Target/Hurtbox
@onready var strike_health = $Target/StrikeHealth
@onready var health = $Target/StrikeHealth/Health

var profile_index := 1
var mirrored := false
var paused := false
var guided := false
var guided_time := 0.0
var guided_pass := 0
var instruction := "FREE CONTROL / J TO STRIKE"
var receipts: Array[Dictionary] = []
var comparison: Array[Dictionary] = []
var _pending_profile := -1
var _pending_reset := false
var _pending_mirror := false
var _tap_index := 0

func _ready() -> void:
	health.damage_processed.connect(_on_damage)
	_reset()

func _reset() -> void:
	# This host reset also fences health before the motor/contact state resets.
	receipts.clear()
	_tap_index = 0
	strike_health.enabled = profile_index == 1
	var direction := -1 if mirrored else 1
	player.reset_actor(Vector2(360, 270) if mirrored else Vector2(280, 270), direction)
	target.reset_at(Vector2(330, 270) if mirrored else Vector2(310, 270))
	target.facing = -direction
	$ImpactWall.position = Vector2(292, 210) if mirrored else Vector2(348, 210)

func _physics_process(dt: float) -> void:
	if paused:
		return
	if _pending_profile >= 0:
		profile_index = _pending_profile
		_pending_profile = -1
		_pending_reset = true
	if _pending_mirror:
		mirrored = not mirrored
		_pending_mirror = false
		_pending_reset = true
	if _pending_reset:
		_pending_reset = false
		_reset()
	var inputs: Variant = null
	if guided:
		if guided_time >= PASS_SECONDS:
			comparison.append({"enabled": profile_index == 1, "hits": hurtbox.hits,
				"health": health.current_health, "receipts": receipts.duplicate(true)})
			if guided_pass == 0:
				guided_pass = 1
				guided_time = 0.0
				profile_index = 1
				_reset()
			else:
				guided = false
				instruction = "COMPARISON FINISHED / J TO CONTINUE"
		if guided:
			inputs = _guided_input(guided_time)
			guided_time += dt
	player.physics_tick(dt, inputs)
	queue_redraw()

func _guided_input(t: float) -> Dictionary:
	# One ordinary fresh press at each threshold, independent of physics rate.
	# Release on the next callback; the unchanged chain decides admission.
	var pressed := false
	if _tap_index < TAP_TIMES.size() and t >= TAP_TIMES[_tap_index]:
		pressed = true
		_tap_index += 1
	instruction = "SAME THREE TAPS / HEALTH " + ("ON" if profile_index == 1 else "OFF")
	return {"attack": pressed}

func _on_damage(receipt: Dictionary) -> void:
	receipts.append(receipt.duplicate(true))
	while receipts.size() > 3:
		receipts.pop_front()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			paused = not paused
			get_tree().paused = paused
		KEY_1, KEY_2:
			if not paused:
				guided = false
				comparison.clear()
				_pending_profile = event.physical_keycode - KEY_1
				instruction = "FREE CONTROL / J TO STRIKE"
		KEY_R:
			if not paused:
				guided = false
				comparison.clear()
				_pending_reset = true
				instruction = "RESET / FULL HEALTH"
		KEY_F:
			if not paused:
				guided = false
				comparison.clear()
				_pending_mirror = true
				instruction = "MIRRORED / FULL HEALTH"
		KEY_Q:
			if not paused:
				guided = true
				guided_time = 0.0
				guided_pass = 0
				comparison.clear()
				_pending_profile = 0
	queue_redraw()

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("070b10"))
	draw_line(Vector2(28, 270), Vector2(612, 270), Color("728694"), 0.8)
	for x in range(40, 615, 22):
		draw_line(Vector2(x, 273), Vector2(x, 277), Color("33434f"), 0.7)
	draw_rect(Rect2($ImpactWall.position - Vector2(4, 60), Vector2(8, 120)), Color("91a5b1"), false, 0.9)
	if is_instance_valid(health):
		var bar := Rect2(target.position + Vector2(-20, -58), Vector2(40, 4))
		draw_rect(bar, Color("24323b"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * health.current_health / health.capacity, bar.size.y)), Color("a4f0d5"))
		draw_string(ThemeDB.fallback_font, bar.position + Vector2(0, -4), "%.2f / %.0f" % [health.current_health, health.capacity], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("dce9ee"))

func render_hud(canvas: Node2D) -> void:
	if not is_instance_valid(health):
		return
	var font := ThemeDB.fallback_font
	var ink := Color("dce9ee")
	var muted := Color("8095a7")
	var accent := Color("a4f0d5") if profile_index == 1 else Color("e6b584")
	canvas.draw_rect(Rect2(0, 0, 640, 125), Color("070b10"))
	canvas.draw_rect(Rect2(0, 290, 640, 70), Color("070b10"))
	canvas.draw_string(font, Vector2(28, 25), "MOKSHA / TARGET HEALTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	canvas.draw_string(font, Vector2(28, 44), "HEALTH " + ("ON" if profile_index == 1 else "OFF") + "    KNOCKBACK ON    " + ("LEFT" if mirrored else "RIGHT") + " WALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, accent)
	canvas.draw_string(font, Vector2(28, 64), "HEALTH %.2f / %.0f    CONTACTS %d" % [health.current_health, health.capacity, hurtbox.hits], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
	canvas.draw_string(font, Vector2(28, 82), instruction, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, muted)
	var history := "Health events appear only after confirmed strike contacts."
	if not receipts.is_empty():
		var parts: PackedStringArray = []
		for receipt in receipts:
			parts.append("%s -%.2f > %.2f" % [receipt.get("step_label", "HIT"), receipt.applied, receipt.after])
		history = "   ".join(parts)
	canvas.draw_string(font, Vector2(28, 103), history, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, accent)
	if comparison.size() == 2:
		canvas.draw_string(font, Vector2(28, 120), "SAME INPUT: OFF %.2f HP / %d hits    ON %.2f HP / %d hits" % [comparison[0].health, comparison[0].hits, comparison[1].health, comparison[1].hits], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, muted)
	canvas.draw_string(font, Vector2(28, 306), "J attack   A/D chase   1 health off / 2 on   R reset", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)
	canvas.draw_string(font, Vector2(28, 325), "Q same-input comparison   F mirror   ESC pause", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, muted)
	canvas.draw_string(font, Vector2(28, 346), "Real strikes + physical wall. Zero health leaves this passive target in place.", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, muted)
	if paused:
		canvas.draw_string(font, Vector2(260, 165), "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
