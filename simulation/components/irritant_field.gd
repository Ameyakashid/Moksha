class_name MokshaIrritantField
extends "res://combat_pc/irritant_source.gd"
## An opt-in, bounded security disperser. No actor writes or save authority.
signal phase_changed(phase: StringName)
@export var profile: MokshaIrritantProfile = preload("res://simulation/resources/irritant_profile.gd").new()
var target: Node2D
var phase: StringName = &"warning"
var phase_elapsed := 0.0
var enabled := true:
	set(value):
		enabled = value
		if not value: deactivate()
var _settings: Dictionary = {}
var _live := false
var _view: Node2D
func _ready() -> void:
	process_physics_priority = 80
	if profile == null or not profile.valid(): return
	_settings = {"size":profile.field_size,"warning":profile.warning_seconds,"active":profile.active_seconds,"recovery":profile.recovery_seconds}
	_live = true
	_view = preload("res://simulation/presentation/irritant_field_view.gd").new()
	_view.source = self
	add_child(_view)
func current() -> bool:
	return _live and enabled and is_inside_tree() and not is_queued_for_deletion() and can_process() and is_physics_processing() and not get_tree().paused and global_transform.is_equal_approx(Transform2D(0, global_position))
func field_rect() -> Rect2:
	return Rect2(global_position - Vector2(_settings.get("size", Vector2.ZERO)) / 2, _settings.get("size", Vector2.ZERO))
func exposure_current(actor: Node2D) -> bool:
	if not current() or phase != &"active" or not is_instance_valid(actor) or actor != target or not actor.is_inside_tree() or actor.is_queued_for_deletion() or not actor.can_process(): return false
	var shape = actor.get_node_or_null("BodyShape")
	if not shape is CollisionShape2D or shape.disabled or not shape.shape is RectangleShape2D: return false
	# Pilot explicitly supports only unrotated/unscaled actor bodies and fields.
	if not shape.global_transform.is_equal_approx(Transform2D(0, shape.global_position)): return false
	return field_rect().intersects(Rect2(shape.global_position - shape.shape.size / 2, shape.shape.size), false)
func deactivate() -> void:
	if not _live: return
	_live = false
	retire_exposure()
	if is_instance_valid(_view): _view.queue_redraw()
func _exit_tree() -> void: deactivate()
func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED: deactivate()
func _physics_process(dt: float) -> void:
	if not current() or dt <= 0: return
	phase_elapsed += dt
	var duration: float = _settings[String(phase)]
	if phase_elapsed >= duration:
		phase_elapsed -= duration
		phase = &"active" if phase == &"warning" else &"recovery" if phase == &"active" else &"warning"
		if phase == &"recovery": retire_exposure()
		elif phase == &"active": activate_exposure()
		phase_changed.emit(phase)
	if is_instance_valid(target) and exposure_current(target) and target.has_method("admit_irritant"):
		target.admit_irritant(self)
	if is_instance_valid(_view): _view.queue_redraw()
func presentation() -> Dictionary:
	return {"live":current(),"phase":phase,"size":_settings.get("size",Vector2.ZERO),"fraction":phase_elapsed / maxf(float(_settings.get(String(phase),1)),0.001)}
