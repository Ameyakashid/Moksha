extends Node
## Campaign-only menu adapter. The preserved actor owns movement/combat InputMap.
## No key is injected into global Input: menu commands share the campaign's key
## handler and modal rearm boundary without manufacturing actor action edges.
const INTENTIONAL_STICK_THRESHOLD := 0.65
const CONTROLLER_BUTTONS := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X,
	JOY_BUTTON_Y, JOY_BUTTON_BACK, JOY_BUTTON_START, JOY_BUTTON_LEFT_SHOULDER,
	JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]
const LENSES := ["neutral", "strength", "agility"]
var input_device := "keyboard"
var active_controller := -1
var _host: WeakRef
var _held_buttons: Dictionary = {}
var _fresh_button_event := 0

func bind(host: Node) -> void:
	_host = weakref(host)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _input(event: InputEvent) -> void:
	# Merely connecting a controller or receiving stick drift must not steal the
	# keyboard legend. Releases and mouse motion do not count as device intent.
	if event is InputEventKey and event.pressed and not event.echo:
		input_device = "keyboard"
		active_controller = -1
	elif event is InputEventMouseButton and event.pressed:
		input_device = "keyboard"
		active_controller = -1
	elif event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] and absf(event.axis_value) >= INTENTIONAL_STICK_THRESHOLD:
			_use_controller(event.device)
	elif event is InputEventJoypadButton:
		var identity := Vector2i(event.device, event.button_index)
		_fresh_button_event = 0
		if not event.pressed:
			_held_buttons.erase(identity)
			return
		if _held_buttons.has(identity): return
		_held_buttons[identity] = true
		_fresh_button_event = event.get_instance_id()
		if event.button_index in CONTROLLER_BUTTONS: _use_controller(event.device)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventJoypadButton or not event.pressed: return
	if event.get_instance_id() != _fresh_button_event: return
	var host: Node = _host.get_ref() if _host != null else null
	if not is_instance_valid(host): return
	var key := _command_key(str(host.state), event.button_index, str(host.lens))
	if key == KEY_NONE: return
	var command := InputEventKey.new()
	command.pressed = true
	command.physical_keycode = key
	host._unhandled_key_input(command)
	get_viewport().set_input_as_handled()

func _use_controller(device: int) -> void:
	input_device = "controller"
	active_controller = device

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected: return
	for identity in _held_buttons.keys():
		if identity.x == device: _held_buttons.erase(identity)
	if device != active_controller: return
	input_device = "keyboard"
	active_controller = -1
	_fresh_button_event = 0
	var host: Node = _host.get_ref() if _host != null else null
	# Reuse the exact focus-loss boundary. Existing menus stay intact, active
	# gameplay pauses, and reconnection never silently resumes the run.
	if is_instance_valid(host): host._on_window_focus_exited()

func _command_key(state: String, button: int, lens: String) -> int:
	match state:
		"title":
			if button in [JOY_BUTTON_A, JOY_BUTTON_START]: return KEY_ENTER
			if button == JOY_BUTTON_X: return KEY_C
			if button in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
				var index := maxi(0, LENSES.find(lens))
				index = posmod(index + (-1 if button == JOY_BUTTON_DPAD_LEFT else 1), LENSES.size())
				return [KEY_1, KEY_2, KEY_3][index]
		"intro":
			if button in [JOY_BUTTON_A, JOY_BUTTON_START]: return KEY_ENTER
		"playing":
			if button == JOY_BUTTON_Y: return KEY_E
			if button == JOY_BUTTON_B: return KEY_Q
			if button == JOY_BUTTON_BACK: return KEY_TAB
			if button == JOY_BUTTON_START: return KEY_ESCAPE
		"journal":
			if button == JOY_BUTTON_DPAD_LEFT: return KEY_LEFT
			if button == JOY_BUTTON_DPAD_RIGHT: return KEY_RIGHT
			if button in [JOY_BUTTON_BACK, JOY_BUTTON_B]: return KEY_TAB
		"archive":
			if button in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_Y]: return KEY_E
		"paused":
			if button in [JOY_BUTTON_START, JOY_BUTTON_B]: return KEY_ESCAPE
			if button == JOY_BUTTON_X: return KEY_R
			if button == JOY_BUTTON_Y: return KEY_N
		"choice":
			if button == JOY_BUTTON_X: return KEY_J
			if button == JOY_BUTTON_B: return KEY_K
		"upgrade":
			if button == JOY_BUTTON_X: return KEY_J
			if button == JOY_BUTTON_Y: return KEY_K
			if button == JOY_BUTTON_B: return KEY_L
		"final_choice":
			if button == JOY_BUTTON_X: return KEY_J
			if button == JOY_BUTTON_Y: return KEY_K
		"dead":
			if button == JOY_BUTTON_A: return KEY_ENTER
			if button == JOY_BUTTON_Y: return KEY_N
		"complete":
			if button in [JOY_BUTTON_A, JOY_BUTTON_START, JOY_BUTTON_Y]: return KEY_ENTER
	return KEY_NONE
