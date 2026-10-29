extends "res://simulation/components/shield_counter_receiver.gd"
var after_capture: Callable
var before_receive: Callable
var captured: Dictionary = {}
func capture_counter_generation() -> Dictionary:
	var token := super.capture_counter_generation()
	if after_capture.is_valid(): after_capture.call()
	return token
func receive_shield_counter(packet: Dictionary) -> Dictionary:
	if before_receive.is_valid(): before_receive.call(packet)
	# Keep the outer actual packet, not an inner intentionally forged probe.
	captured = packet.duplicate(true)
	return super.receive_shield_counter(packet)
