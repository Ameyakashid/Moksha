extends "res://demo/components/mission_prop.gd"
## Test-only admission observer; never supplies successful contact authority.
var before_receive: Callable
var last_packet: Dictionary = {}
var response: Dictionary = {}
func receive_strike(packet: Dictionary) -> Dictionary:
	last_packet = packet.duplicate(true)
	var candidate := packet.duplicate(true)
	if before_receive.is_valid(): before_receive.call(candidate)
	response = super.receive_strike(candidate)
	return response
