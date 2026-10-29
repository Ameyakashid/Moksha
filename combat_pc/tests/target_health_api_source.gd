extends Node2D
## Explicit API-only source, never counted as an actual physical contact.
var serial := 1
var active := true
var hook: Callable
func is_strike_current(value: int) -> bool:
	if hook.is_valid(): hook.call()
	return active and value == serial
