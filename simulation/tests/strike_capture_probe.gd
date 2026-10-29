extends "res://simulation/components/incoming_strike_receiver.gd"
## Explicit callback/lifecycle fixture; never fabricates an accepted contact.
var after_capture: Callable
func capture_strike_generation() -> Dictionary:
	var token := super.capture_strike_generation()
	if not token.is_empty() and after_capture.is_valid(): after_capture.call()
	return token
