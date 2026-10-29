class_name MokshaSurfacePulse
extends "res://scripts/sensory/sonar_view.gd"
## Optional surface-only adapter. Reuses the preserved contour solver unchanged;
## the host explicitly supplies geometry, an excluded actor and a local bus.
@export_node_path("Node2D") var geometry_root_path := NodePath("")
@export_node_path("Node2D") var excluded_actor_path := NodePath("")
@export_node_path("Node") var event_bus_path := NodePath("")
@export var enabled := true:
	set(value):
		if enabled == value: return
		enabled = value
		_refresh_subscription()
var _event_bus_ref: WeakRef
var _subscription := 0
var _receiver: Callable

func _ready() -> void:
	# Deliberately do not call the older view's autoload-wiring _ready().
	_canvas = Node2D.new()
	_canvas.name = "SurfaceContours"
	_canvas.set_script(CanvasScript)
	_canvas.sonar = self
	add_child(_canvas)
	if not geometry_root_path.is_empty() and not excluded_actor_path.is_empty() and not event_bus_path.is_empty():
		bind_surface(get_node_or_null(geometry_root_path),get_node_or_null(excluded_actor_path),get_node_or_null(event_bus_path))

func _exit_tree() -> void:
	unbind_surface()

func _live(node) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion()

func _event_bus() -> Node:
	return _event_bus_ref.get_ref() if _event_bus_ref != null else null

func bind_surface(world, actor, event_bus) -> bool:
	unbind_surface()
	if not _live(self) or not _live(world) or not _live(actor) or not _live(event_bus): return false
	if not world is Node2D or not actor is Node2D: return false
	if world == actor or not world.is_ancestor_of(actor): return false
	if world.get_tree() != get_tree() or event_bus.get_tree() != get_tree(): return false
	if not event_bus.has_signal("noise_emitted"): return false
	_event_bus_ref = weakref(event_bus)
	bind_level(world,actor)
	_refresh_subscription()
	return true

func unbind_surface() -> void:
	_disconnect_bus()
	_event_bus_ref = null
	_level = null
	_player = null
	geometry.clear()
	clear_pulses()
	event_history.clear()
	accepted_event_count = 0
	dropped_pulse_count = 0
	elapsed = 0.0

func _disconnect_bus() -> void:
	_subscription += 1
	var bus := _event_bus()
	if is_instance_valid(bus) and _receiver.is_valid() and bus.is_connected("noise_emitted",_receiver):
		bus.disconnect("noise_emitted",_receiver)
	_receiver = Callable()

func _refresh_subscription() -> void:
	_disconnect_bus()
	clear_pulses()
	if enabled and _live(self) and _live(_level) and _live(_player) and _live(_event_bus()):
		refresh_geometry()
		_receiver = _receive_noise.bind(_subscription)
		_event_bus().connect("noise_emitted",_receiver)

func _receive_noise(origin: Vector2, kind: StringName, loudness: float, source, subscription: int) -> void:
	if subscription != _subscription or not enabled or not _live(self): return
	if not _live(_level) or not _live(_player) or not _live(_event_bus()) or not _live(source): return
	if String(kind).is_empty(): return
	_on_noise_emitted(origin,kind,loudness,source)

func _process(dt: float) -> void:
	if not _live(_level) or not _live(_player) or not _live(_event_bus()):
		if _level != null or _event_bus_ref != null: unbind_surface()
		return
	if enabled: advance_simulation(dt)

func render_on(canvas: Node2D) -> void:
	# This component has no sight mode, blackout, actor cue or combat markers.
	# It draws only the inherited, noise-timed collision contour fragments.
	blind = false
	preview_when_sighted = enabled and _live(_level) and _live(_player) and _live(_event_bus())
	super.render_on(canvas)

func _draw_origin(_canvas_node: Node2D, _pulse: Dictionary, _transform: Transform2D, _opacity: float) -> void:
	pass
