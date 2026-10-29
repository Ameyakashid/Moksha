extends "res://simulation/components/physical_cargo.gd"
## Test-only interruption at the deferred delivery boundary, using an actual
## production-captured contact. Never synthesizes contact or response.
var before_delivery: Callable
func _deliver(target_ref: WeakRef, receiver_ref: WeakRef, packet: Dictionary) -> void:
	if before_delivery.is_valid(): before_delivery.call(target_ref, receiver_ref, packet)
	super._deliver(target_ref, receiver_ref, packet)
