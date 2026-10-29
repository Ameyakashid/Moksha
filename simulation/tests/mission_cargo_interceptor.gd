extends "res://demo/components/mission_prop.gd"
## Test-only boundary callback around a genuinely captured contact.
var before_delivery: Callable
func _deliver(target_ref: WeakRef, receiver_ref: WeakRef, packet: Dictionary) -> void:
	if before_delivery.is_valid(): before_delivery.call(target_ref,receiver_ref,packet)
	super._deliver(target_ref,receiver_ref,packet)
