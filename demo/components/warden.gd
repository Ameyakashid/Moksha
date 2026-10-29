extends "res://demo/components/enemy.gd"
## Optional climax policy around the preserved enemy/contact/health composition.
## Bracing is knockback resistance, never damage resistance. Counter/parry stun
## uses the established long interrupt (0.75 / 0.78 seconds) and breaks it.
signal phase_changed(warden: Node2D, phase: int)

const COUNTER_INTERRUPT_SECONDS := 0.70
const CUT_REACH := 57.0
const SWEEP_REACH := 73.0

var pressure_phase := false
var attack_style: StringName = &"cut"
var committed_attacks := 0
var braced_contacts := 0
var _brace_flash := 0.0

func _apply_archetype() -> void:
	kind = "warden"
	super._apply_archetype()
	_set_attack_style(&"cut")

func is_braced() -> bool:
	return not dead and enabled and ai_state in [&"windup", &"active"]

func _set_attack_style(style: StringName) -> void:
	attack_style = style
	var is_sweep := style == &"sweep"
	_reach = SWEEP_REACH if is_sweep else CUT_REACH
	# Both warnings stay readable in phase two. Only the recovery accelerates;
	# losing health never shortens a windup that is already on screen.
	_windup = (windup_override if windup_override > 0.0 else 0.78) * (1.30 if is_sweep else 1.0)
	_active_duration = 0.18 if is_sweep else 0.14
	_refresh_recovery()

func _refresh_recovery() -> void:
	if attack_style == &"sweep":
		_recovery = 0.80 if pressure_phase else 1.10
	else:
		_recovery = 0.64 if pressure_phase else 0.90

func _begin_attack(direction: int) -> void:
	if dead or stun_left > 0.0 or not _player_available(): return
	_set_attack_style(&"cut" if committed_attacks % 2 == 0 else &"sweep")
	committed_attacks += 1
	super._begin_attack(direction)

func apply_impulse(impulse: Vector2, seconds: float = 0.14) -> void:
	if dead or not impulse.is_finite() or not is_finite(seconds): return
	if is_braced() and seconds < COUNTER_INTERRUPT_SECONDS:
		# StrikeHealth independently receives the same confirmed contact, so the
		# complete hit damage and lethal transition still happen synchronously.
		# Retain the stock copied hitpause; do not repeatedly push the telegraph
		# away or turn a committed attack into an ordinary stunlock target.
		braced_contacts += 1
		_brace_flash = 0.16
		return
	super.apply_impulse(impulse, seconds)

func _on_damage_processed(receipt: Dictionary) -> void:
	super._on_damage_processed(receipt)
	if dead or pressure_phase or float(receipt.get("applied", 0.0)) <= 0.0: return
	if health > 0.0 and health < float(_health.capacity) * 0.5:
		pressure_phase = true
		_refresh_recovery()
		phase_changed.emit(self, 2)

func reset_at(at: Vector2) -> void:
	super.reset_at(at)
	pressure_phase = false
	committed_attacks = 0
	braced_contacts = 0
	_brace_flash = 0.0
	_set_attack_style(&"cut")

func attack_rect_local() -> Rect2:
	# The inherited _try_strike queries exactly this 27-pixel-high rectangle.
	# The stance preview and active fill therefore show the actual reach, not
	# an ornamental arc that promises safety inside a hidden hit rectangle.
	var size := Vector2(_reach, 27.0)
	var center := Vector2(_attack_facing * (_reach * 0.5 + 4.0), -22.0)
	return Rect2(center - size * 0.5, size)

func _process(dt: float) -> void:
	_brace_flash = maxf(0.0, _brace_flash - dt)
	super._process(dt)

func _draw() -> void:
	super._draw()
	if dead: return
	var alpha := clampf(reveal_remaining / 0.2, 0.0, 1.0) if blind_mode else 1.0
	if alpha <= 0.0: return
	var gold := Color(1.0, 0.72, 0.38, alpha)
	if pressure_phase:
		# Broken crown / bright core is persistent phase feedback; no new HP bar.
		draw_line(Vector2(-9, -39), Vector2(-12, -44), gold, 1.8)
		draw_line(Vector2(9, -39), Vector2(12, -44), gold, 1.8)
		draw_circle(Vector2(0, -21), 2.5, gold, false, 1.3)
	if is_braced():
		var brace := Color(1.0, 0.90, 0.64, alpha) if _brace_flash > 0.0 else gold
		# Broad shoulders and planted feet visibly communicate commitment.
		draw_polyline(PackedVector2Array([Vector2(-11, -23), Vector2(-8, -29), Vector2(8, -29), Vector2(11, -23)]), brace, 2.2)
		draw_line(Vector2(-10, -1), Vector2(-3, -1), brace, 2.4)
		draw_line(Vector2(3, -1), Vector2(10, -1), brace, 2.4)
		var attack_rect := attack_rect_local()
		if ai_state == &"windup":
			var charge := clampf(_phase_elapsed / _windup, 0.0, 1.0)
			draw_rect(attack_rect, Color(1.0, 0.54, 0.30, alpha * (0.18 + charge * 0.30)), false, 1.0)
			if attack_style == &"sweep":
				# The longer warning and twin blade marks distinguish the sweep.
				draw_line(Vector2(-_attack_facing * 9, -30), Vector2(-_attack_facing * 24, -39), brace, 1.5)
		else:
			draw_rect(attack_rect, Color(1.0, 0.72, 0.38, alpha * 0.12), true)
			draw_rect(attack_rect, Color(1.0, 0.85, 0.57, alpha * 0.90), false, 1.4)
